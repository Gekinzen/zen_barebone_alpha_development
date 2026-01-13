/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Pinned Manager - Implementation
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include "pinned_manager.hpp"

#include <gio/gio.h>
#include <gio/gdesktopappinfo.h>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <algorithm>
#include <cstdlib>

namespace fs = std::filesystem;

PinnedManager::PinnedManager() {
    std::string home = getenv("HOME");
    m_config_path = home + "/.config/hypr-control-center/preferences/taskbar.json";
    
    // Create directory if needed
    fs::path config_dir = fs::path(m_config_path).parent_path();
    if (!fs::exists(config_dir)) {
        fs::create_directories(config_dir);
    }
    
    load();
}

PinnedManager::~PinnedManager() {}

void PinnedManager::load() {
    m_pinned.clear();
    
    if (!fs::exists(m_config_path)) {
        // Create defaults
        std::vector<std::string> defaults = {"firefox", "kitty", "nautilus", "code"};
        for (size_t i = 0; i < defaults.size(); i++) {
            pin_app(defaults[i]);
        }
        return;
    }
    
    std::ifstream file(m_config_path);
    if (!file.is_open()) return;
    
    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());
    file.close();
    
    // Parse JSON - support both old format {"pinned": [...]} and new format {"pinned_apps": [...]}
    
    // Check for old format: "pinned": ["app1", "app2", ...]
    size_t pinned_pos = content.find("\"pinned\"");
    if (pinned_pos == std::string::npos) {
        pinned_pos = content.find("\"pinned_apps\"");
    }
    
    if (pinned_pos == std::string::npos) return;
    
    // Find the array start
    size_t array_start = content.find("[", pinned_pos);
    if (array_start == std::string::npos) return;
    
    size_t array_end = content.find("]", array_start);
    if (array_end == std::string::npos) return;
    
    std::string array_content = content.substr(array_start + 1, array_end - array_start - 1);
    
    // Check if it's simple format ["app1", "app2"] or object format [{...}, {...}]
    if (array_content.find("{") != std::string::npos) {
        // Object format - parse each object
        size_t pos = 0;
        while ((pos = array_content.find("{", pos)) != std::string::npos) {
            size_t end = array_content.find("}", pos);
            if (end == std::string::npos) break;
            
            std::string obj = array_content.substr(pos, end - pos + 1);
            
            PinnedApp app;
            
            auto extract = [&obj](const std::string& key) -> std::string {
                std::string search = "\"" + key + "\":\"";
                size_t p = obj.find(search);
                if (p == std::string::npos) {
                    // Try without quotes for the value
                    search = "\"" + key + "\":";
                    p = obj.find(search);
                    if (p == std::string::npos) return "";
                    p += search.length();
                    // Skip whitespace
                    while (p < obj.length() && (obj[p] == ' ' || obj[p] == '"')) p++;
                    size_t e = p;
                    while (e < obj.length() && obj[e] != '"' && obj[e] != ',' && obj[e] != '}') e++;
                    return obj.substr(p, e - p);
                }
                p += search.length();
                size_t e = obj.find("\"", p);
                if (e == std::string::npos) return "";
                return obj.substr(p, e - p);
            };
            
            app.app_id = extract("app_id");
            if (app.app_id.empty()) app.app_id = extract("id");
            app.wm_class = extract("wm_class");
            app.exec_cmd = extract("exec_cmd");
            app.icon = extract("icon");
            app.desktop_file = extract("desktop_file");
            app.order = m_pinned.size();
            
            if (app.wm_class.empty()) app.wm_class = app.app_id;
            
            if (!app.app_id.empty()) {
                m_pinned.push_back(app);
            }
            
            pos = end + 1;
        }
    } else {
        // Simple format - just app names: ["firefox", "kitty", ...]
        size_t pos = 0;
        int order = 0;
        while ((pos = array_content.find("\"", pos)) != std::string::npos) {
            size_t end = array_content.find("\"", pos + 1);
            if (end == std::string::npos) break;
            
            std::string app_id = array_content.substr(pos + 1, end - pos - 1);
            
            if (!app_id.empty()) {
                // Create PinnedApp from app_id
                std::string desktop_file = find_desktop_file(app_id);
                PinnedApp app = parse_desktop_file(desktop_file, app_id);
                app.order = order++;
                m_pinned.push_back(app);
            }
            
            pos = end + 1;
        }
    }
}

void PinnedManager::save() {
    std::ofstream file(m_config_path);
    if (!file.is_open()) return;
    
    // Save in simple format for compatibility
    file << "{\n";
    file << "  \"pinned\": [\n";
    
    for (size_t i = 0; i < m_pinned.size(); i++) {
        const auto& app = m_pinned[i];
        file << "    \"" << app.app_id << "\"";
        if (i < m_pinned.size() - 1) file << ",";
        file << "\n";
    }
    
    file << "  ]\n";
    file << "}\n";
    
    file.close();
}

std::vector<PinnedApp> PinnedManager::get_pinned_apps() {
    return m_pinned;
}

bool PinnedManager::is_pinned(const std::string& app_id) {
    std::string lower_id = app_id;
    std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
    
    for (const auto& app : m_pinned) {
        std::string lower_pinned = app.app_id;
        std::transform(lower_pinned.begin(), lower_pinned.end(), lower_pinned.begin(), ::tolower);
        
        if (lower_pinned == lower_id) return true;
        
        std::string lower_wm = app.wm_class;
        std::transform(lower_wm.begin(), lower_wm.end(), lower_wm.begin(), ::tolower);
        
        if (lower_wm == lower_id) return true;
    }
    
    return false;
}

std::string PinnedManager::find_desktop_file(const std::string& app_id) {
    std::vector<std::string> paths = {
        std::string(getenv("HOME")) + "/.local/share/applications",
        "/usr/share/applications",
        "/usr/local/share/applications",
    };
    
    std::string lower_id = app_id;
    std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
    
    std::vector<std::string> variations = {
        app_id + ".desktop",
        lower_id + ".desktop",
    };
    
    for (const auto& path : paths) {
        if (!fs::exists(path)) continue;
        
        for (const auto& variation : variations) {
            fs::path desktop_file = fs::path(path) / variation;
            if (fs::exists(desktop_file)) {
                return desktop_file.string();
            }
        }
        
        // Search by partial match
        try {
            for (const auto& entry : fs::directory_iterator(path)) {
                if (entry.path().extension() == ".desktop") {
                    std::string filename = entry.path().stem().string();
                    std::transform(filename.begin(), filename.end(), filename.begin(), ::tolower);
                    
                    if (filename.find(lower_id) != std::string::npos) {
                        return entry.path().string();
                    }
                }
            }
        } catch (...) {}
    }
    
    return "";
}

PinnedApp PinnedManager::parse_desktop_file(const std::string& path, const std::string& app_id) {
    PinnedApp app;
    app.app_id = app_id;
    app.desktop_file = path;
    app.order = m_pinned.size();
    
    if (path.empty()) {
        app.wm_class = app_id;
        app.exec_cmd = app_id;
        return app;
    }
    
    GDesktopAppInfo* info = g_desktop_app_info_new_from_filename(path.c_str());
    if (!info) {
        app.wm_class = app_id;
        app.exec_cmd = app_id;
        return app;
    }
    
    const char* exec = g_app_info_get_executable(G_APP_INFO(info));
    if (exec) app.exec_cmd = exec;
    
    const char* icon = g_desktop_app_info_get_string(info, "Icon");
    if (icon) app.icon = icon;
    
    const char* wm_class = g_desktop_app_info_get_startup_wm_class(info);
    if (wm_class) {
        app.wm_class = wm_class;
    } else {
        app.wm_class = app_id;
    }
    
    g_object_unref(info);
    
    return app;
}

void PinnedManager::pin_app(const std::string& app_id, const std::string& wm_class) {
    if (is_pinned(app_id)) return;
    
    std::string desktop_file = find_desktop_file(app_id);
    PinnedApp app = parse_desktop_file(desktop_file, app_id);
    
    if (!wm_class.empty()) {
        app.wm_class = wm_class;
    }
    
    m_pinned.push_back(app);
    save();
}

void PinnedManager::unpin_app(const std::string& app_id) {
    std::string lower_id = app_id;
    std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
    
    m_pinned.erase(
        std::remove_if(m_pinned.begin(), m_pinned.end(),
            [&lower_id](const PinnedApp& app) {
                std::string lower_pinned = app.app_id;
                std::transform(lower_pinned.begin(), lower_pinned.end(), lower_pinned.begin(), ::tolower);
                return lower_pinned == lower_id;
            }
        ),
        m_pinned.end()
    );
    
    save();
}

void PinnedManager::reorder(const std::vector<std::string>& new_order) {
    std::vector<PinnedApp> reordered;
    
    for (const auto& id : new_order) {
        for (const auto& app : m_pinned) {
            if (app.app_id == id) {
                reordered.push_back(app);
                break;
            }
        }
    }
    
    // Add any remaining
    for (const auto& app : m_pinned) {
        bool found = false;
        for (const auto& r : reordered) {
            if (r.app_id == app.app_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            reordered.push_back(app);
        }
    }
    
    m_pinned = reordered;
    save();
}

void PinnedManager::launch_app(const std::string& app_id) {
    // Find desktop file
    std::string desktop_file = find_desktop_file(app_id);
    
    if (!desktop_file.empty()) {
        // Launch via GIO
        GDesktopAppInfo* info = g_desktop_app_info_new_from_filename(desktop_file.c_str());
        if (info) {
            GError* error = nullptr;
            g_app_info_launch(G_APP_INFO(info), nullptr, nullptr, &error);
            
            if (error) {
                g_error_free(error);
            }
            
            g_object_unref(info);
            return;
        }
    }
    
    // Fallback: exec directly
    std::string cmd = app_id + " &";
    system(cmd.c_str());
}