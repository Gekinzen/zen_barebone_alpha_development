/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Taskbar - Implementation
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include "taskbar.hpp"

#include <filesystem>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <iostream>
#include <set>

namespace fs = std::filesystem;

// Helper function for string ends_with (C++17 compatible)
static bool str_ends_with(const std::string& str, const std::string& suffix) {
    if (suffix.size() > str.size()) return false;
    return str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

// Static instance for signal handler
Taskbar* Taskbar::s_instance = nullptr;

Taskbar::Taskbar() {
    s_instance = this;
    
    // Setup temp directory path
    const char* xdg_runtime = getenv("XDG_RUNTIME_DIR");
    if (xdg_runtime) {
        m_temp_dir = std::string(xdg_runtime) + "/waybar-taskbar";
    } else {
        m_temp_dir = "/tmp/waybar-taskbar-" + std::to_string(getuid());
    }
    m_icons_dir = m_temp_dir + "/icons";
    m_empty_icon = m_icons_dir + "/empty.png";
}

Taskbar::~Taskbar() {
    cleanup();
    s_instance = nullptr;
}

void Taskbar::signal_cleanup(int sig) {
    if (s_instance) {
        s_instance->cleanup();
    }
    std::_Exit(sig == SIGINT ? 0 : 1);
}

bool Taskbar::init() {
    // Setup signal handlers
    std::signal(SIGINT, signal_cleanup);
    std::signal(SIGTERM, signal_cleanup);
    std::signal(SIGHUP, signal_cleanup);
    
    if (!setup_temp_dir()) {
        std::cerr << "[Taskbar] Failed to setup temp directory\n";
        return false;
    }
    
    create_empty_icon();
    
    std::cout << "[Taskbar] ✅ Initialized\n";
    std::cout << "[Taskbar] 📁 Temp dir: " << m_temp_dir << "\n";
    std::cout << "[Taskbar] 🎨 Icon theme: " << m_icons.get_current_theme() << "\n";
    
    return true;
}

bool Taskbar::setup_temp_dir() {
    try {
        // Only create if doesn't exist - don't delete existing!
        if (!fs::exists(m_icons_dir)) {
            fs::create_directories(m_icons_dir);
        }
        return true;
    } catch (const std::exception& e) {
        std::cerr << "[Taskbar] Error creating temp dir: " << e.what() << "\n";
        return false;
    }
}

void Taskbar::create_empty_icon() {
    // Create a 1x1 transparent PNG
    // PNG header for 1x1 transparent image
    unsigned char empty_png[] = {
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    };
    
    std::ofstream file(m_empty_icon, std::ios::binary);
    if (file.is_open()) {
        file.write(reinterpret_cast<char*>(empty_png), sizeof(empty_png));
        file.close();
    }
}

void Taskbar::copy_icon_to_slot(const std::string& src_path, const std::string& slot_name) {
    std::string dest_path = m_icons_dir + "/" + slot_name + ".png";
    
    try {
        if (src_path.empty() || !fs::exists(src_path)) {
            // Create empty placeholder directly
            if (fs::exists(m_empty_icon)) {
                fs::copy_file(m_empty_icon, dest_path, fs::copy_options::overwrite_existing);
            } else {
                // Recreate empty icon if missing
                create_empty_icon();
                if (fs::exists(m_empty_icon)) {
                    fs::copy_file(m_empty_icon, dest_path, fs::copy_options::overwrite_existing);
                }
            }
            return;
        }
        
        // Check if SVG - needs conversion
        if (str_ends_with(src_path, ".svg")) {
            // Use rsvg-convert or magick to convert SVG to PNG
            std::string cmd = "rsvg-convert -w 24 -h 24 \"" + src_path + "\" -o \"" + dest_path + "\" 2>/dev/null";
            int ret = system(cmd.c_str());
            
            if (ret != 0) {
                // Try ImageMagick
                cmd = "magick convert -background none -resize 24x24 \"" + src_path + "\" \"" + dest_path + "\" 2>/dev/null";
                ret = system(cmd.c_str());
            }
            
            if (ret != 0) {
                // Try convert directly
                cmd = "convert -background none -resize 24x24 \"" + src_path + "\" \"" + dest_path + "\" 2>/dev/null";
                ret = system(cmd.c_str());
            }
            
            // Verify file was created
            if (ret != 0 || !fs::exists(dest_path)) {
                // Fallback to empty
                if (fs::exists(m_empty_icon)) {
                    fs::copy_file(m_empty_icon, dest_path, fs::copy_options::overwrite_existing);
                }
            }
        } else {
            // Direct copy for PNG
            fs::copy_file(src_path, dest_path, fs::copy_options::overwrite_existing);
        }
    } catch (const std::exception& e) {
        std::cerr << "[Taskbar] Error copying icon: " << e.what() << "\n";
        // Try to create empty placeholder
        try {
            if (fs::exists(m_empty_icon)) {
                fs::copy_file(m_empty_icon, dest_path, fs::copy_options::overwrite_existing);
            }
        } catch (...) {}
    }
}

void Taskbar::clear_slot(const std::string& slot_name) {
    std::string dest_path = m_icons_dir + "/" + slot_name + ".png";
    try {
        if (!fs::exists(m_empty_icon)) {
            create_empty_icon();
        }
        if (fs::exists(m_empty_icon)) {
            fs::copy_file(m_empty_icon, dest_path, fs::copy_options::overwrite_existing);
        }
    } catch (...) {}
}

bool Taskbar::update() {
    m_pinned_items.clear();
    m_running_items.clear();
    m_slot_map.clear();
    
    // Get pinned apps
    auto pinned_apps = m_pinned.get_pinned_apps();
    
    // Get running apps
    auto app_groups = m_ipc.get_app_groups();
    
    // Track which apps are accounted for
    std::set<std::string> accounted;
    
    // Process pinned apps
    int pin_index = 0;
    for (const auto& pinned : pinned_apps) {
        if (pin_index >= MAX_PINNED_SLOTS) break;
        
        TaskbarItem item;
        item.id = pinned.app_id;
        item.app_id = pinned.app_id;
        item.wm_class = pinned.wm_class.empty() ? pinned.app_id : pinned.wm_class;
        item.is_pinned = true;
        item.is_running = false;
        item.is_focused = false;
        item.window_count = 0;
        item.slot_index = pin_index;
        
        // Check if running
        std::string lower_wm = item.wm_class;
        std::transform(lower_wm.begin(), lower_wm.end(), lower_wm.begin(), ::tolower);
        
        std::string lower_id = item.app_id;
        std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
        
        for (const auto& [wm_class, group] : app_groups) {
            std::string lower_group = wm_class;
            std::transform(lower_group.begin(), lower_group.end(), lower_group.begin(), ::tolower);
            
            if (lower_group == lower_wm || lower_group == lower_id ||
                group.wm_class == item.wm_class || group.wm_class == item.app_id) {
                item.is_running = true;
                item.is_focused = group.has_focus;
                item.window_count = group.window_count();
                accounted.insert(lower_group);
                break;
            }
        }
        
        // Get icon
        item.icon_path = m_icons.get_icon_path(item.wm_class, 24);
        if (item.icon_path.empty()) {
            item.icon_path = m_icons.get_icon_path(item.app_id, 24);
        }
        item.nerd_icon = m_icons.get_nerd_icon(item.wm_class);
        
        // Tooltip
        item.tooltip = item.app_id;
        if (item.window_count > 1) {
            item.tooltip += " (" + std::to_string(item.window_count) + " windows)";
        }
        
        // Copy icon to slot
        std::string slot_name = "pin_" + std::to_string(pin_index);
        copy_icon_to_slot(item.icon_path, slot_name);
        item.slot_icon_path = m_icons_dir + "/" + slot_name + ".png";
        
        // Store mapping
        m_slot_map[slot_name] = item.app_id;
        
        m_pinned_items.push_back(item);
        accounted.insert(lower_id);
        accounted.insert(lower_wm);
        pin_index++;
    }
    
    // Clear remaining pinned slots
    for (int i = pin_index; i < MAX_PINNED_SLOTS; i++) {
        clear_slot("pin_" + std::to_string(i));
    }
    
    // Process running (non-pinned) apps
    int run_index = 0;
    for (const auto& [wm_class, group] : app_groups) {
        if (run_index >= MAX_RUNNING_SLOTS) break;
        
        std::string lower = wm_class;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        
        // Skip if already in pinned
        if (accounted.count(lower) > 0) continue;
        
        std::string lower_wm_class = group.wm_class;
        std::transform(lower_wm_class.begin(), lower_wm_class.end(), lower_wm_class.begin(), ::tolower);
        if (accounted.count(lower_wm_class) > 0) continue;
        
        TaskbarItem item;
        item.id = wm_class;
        item.app_id = wm_class;
        item.wm_class = group.wm_class;
        item.is_pinned = false;
        item.is_running = true;
        item.is_focused = group.has_focus;
        item.window_count = group.window_count();
        item.slot_index = run_index;
        
        // Get icon
        item.icon_path = m_icons.get_icon_path(group.wm_class, 24);
        if (item.icon_path.empty()) {
            item.icon_path = m_icons.get_icon_path(wm_class, 24);
        }
        item.nerd_icon = m_icons.get_nerd_icon(group.wm_class);
        
        // Tooltip
        item.tooltip = group.wm_class;
        if (item.window_count > 1) {
            item.tooltip += " (" + std::to_string(item.window_count) + " windows)";
        }
        
        // Copy icon to slot
        std::string slot_name = "run_" + std::to_string(run_index);
        copy_icon_to_slot(item.icon_path, slot_name);
        item.slot_icon_path = m_icons_dir + "/" + slot_name + ".png";
        
        // Store mapping
        m_slot_map[slot_name] = item.app_id;
        
        m_running_items.push_back(item);
        run_index++;
    }
    
    // Clear remaining running slots
    for (int i = run_index; i < MAX_RUNNING_SLOTS; i++) {
        clear_slot("run_" + std::to_string(i));
    }
    
    // Save state for click handlers
    save_state();
    
    // Check if state changed
    std::string current_hash = compute_state_hash();
    bool changed = (current_hash != m_last_state_hash);
    m_last_state_hash = current_hash;
    
    return changed;
}

std::string Taskbar::compute_state_hash() {
    std::stringstream ss;
    for (const auto& item : m_pinned_items) {
        ss << item.app_id << ":" << item.is_running << ":" << item.is_focused << ";";
    }
    ss << "|";
    for (const auto& item : m_running_items) {
        ss << item.app_id << ":" << item.is_focused << ";";
    }
    return ss.str();
}

std::vector<TaskbarItem> Taskbar::get_items() {
    std::vector<TaskbarItem> all;
    all.insert(all.end(), m_pinned_items.begin(), m_pinned_items.end());
    all.insert(all.end(), m_running_items.begin(), m_running_items.end());
    return all;
}

std::vector<TaskbarItem> Taskbar::get_pinned_items() {
    return m_pinned_items;
}

std::vector<TaskbarItem> Taskbar::get_running_items() {
    return m_running_items;
}

void Taskbar::handle_click(const std::string& slot_type, int slot_index) {
    std::string slot_name = slot_type + "_" + std::to_string(slot_index);
    
    auto it = m_slot_map.find(slot_name);
    if (it == m_slot_map.end()) return;
    
    std::string app_id = it->second;
    
    // Find the item
    TaskbarItem* item = nullptr;
    if (slot_type == "pin") {
        for (auto& i : m_pinned_items) {
            if (i.slot_index == slot_index) {
                item = &i;
                break;
            }
        }
    } else {
        for (auto& i : m_running_items) {
            if (i.slot_index == slot_index) {
                item = &i;
                break;
            }
        }
    }
    
    if (!item) return;
    
    if (item->is_running) {
        // Focus the window
        auto groups = m_ipc.get_app_groups();
        for (const auto& [wm_class, group] : groups) {
            std::string lower = wm_class;
            std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
            
            std::string lower_id = item->app_id;
            std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
            
            if (lower == lower_id || group.wm_class == item->wm_class) {
                if (!group.windows.empty()) {
                    m_ipc.focus_window(group.windows[0].address);
                }
                return;
            }
        }
    } else {
        // Launch the app
        m_pinned.launch_app(app_id);
    }
}

void Taskbar::handle_middle_click(const std::string& slot_type, int slot_index) {
    std::string slot_name = slot_type + "_" + std::to_string(slot_index);
    
    auto it = m_slot_map.find(slot_name);
    if (it == m_slot_map.end()) return;
    
    std::string app_id = it->second;
    
    // Close all windows
    auto groups = m_ipc.get_app_groups();
    for (const auto& [wm_class, group] : groups) {
        std::string lower = wm_class;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        
        std::string lower_id = app_id;
        std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
        
        if (lower == lower_id || group.wm_class == app_id) {
            m_ipc.close_app(group.wm_class);
            return;
        }
    }
}

void Taskbar::handle_right_click(const std::string& slot_type, int slot_index) {
    std::string slot_name = slot_type + "_" + std::to_string(slot_index);
    
    auto it = m_slot_map.find(slot_name);
    if (it == m_slot_map.end()) return;
    
    std::string app_id = it->second;
    
    // Toggle pin state
    if (m_pinned.is_pinned(app_id)) {
        m_pinned.unpin_app(app_id);
        std::cout << "[Taskbar] 📍 Unpinned: " << app_id << "\n";
    } else {
        m_pinned.pin_app(app_id);
        std::cout << "[Taskbar] 📌 Pinned: " << app_id << "\n";
    }
}

void Taskbar::save_state() {
    std::string state_path = m_temp_dir + "/state.json";
    std::ofstream file(state_path);
    if (!file.is_open()) return;
    
    file << "{\n";
    file << "  \"pinned\": [\n";
    for (size_t i = 0; i < m_pinned_items.size(); i++) {
        const auto& item = m_pinned_items[i];
        file << "    {\"slot\": " << item.slot_index 
             << ", \"app_id\": \"" << escape_json(item.app_id) << "\""
             << ", \"wm_class\": \"" << escape_json(item.wm_class) << "\""
             << ", \"running\": " << (item.is_running ? "true" : "false")
             << ", \"focused\": " << (item.is_focused ? "true" : "false")
             << ", \"windows\": " << item.window_count
             << "}";
        if (i < m_pinned_items.size() - 1) file << ",";
        file << "\n";
    }
    file << "  ],\n";
    file << "  \"running\": [\n";
    for (size_t i = 0; i < m_running_items.size(); i++) {
        const auto& item = m_running_items[i];
        file << "    {\"slot\": " << item.slot_index 
             << ", \"app_id\": \"" << escape_json(item.app_id) << "\""
             << ", \"wm_class\": \"" << escape_json(item.wm_class) << "\""
             << ", \"focused\": " << (item.is_focused ? "true" : "false")
             << ", \"windows\": " << item.window_count
             << "}";
        if (i < m_running_items.size() - 1) file << ",";
        file << "\n";
    }
    file << "  ],\n";
    file << "  \"icons_dir\": \"" << escape_json(m_icons_dir) << "\"\n";
    file << "}\n";
    
    file.close();
}

std::string Taskbar::generate_waybar_config() {
    std::stringstream ss;
    
    ss << "// ═══════════════════════════════════════════════════════════════\n";
    ss << "// AUTO-GENERATED WAYBAR TASKBAR CONFIG\n";
    ss << "// Add these to your config.jsonc\n";
    ss << "// ═══════════════════════════════════════════════════════════════\n\n";
    
    // Modules list
    ss << "// Add to modules-left, modules-center, or modules-right:\n";
    ss << "// \"group/taskbar\",\n\n";
    
    // Group config
    ss << "\"group/taskbar\": {\n";
    ss << "    \"orientation\": \"horizontal\",\n";
    ss << "    \"modules\": [\n";
    
    // Pinned modules
    for (int i = 0; i < MAX_PINNED_SLOTS; i++) {
        ss << "        \"image#pin" << i << "\"";
        if (i < MAX_PINNED_SLOTS - 1 || MAX_RUNNING_SLOTS > 0) ss << ",";
        ss << "\n";
    }
    
    // Separator (optional)
    // ss << "        \"custom/taskbar-sep\",\n";
    
    // Running modules
    for (int i = 0; i < MAX_RUNNING_SLOTS; i++) {
        ss << "        \"image#run" << i << "\"";
        if (i < MAX_RUNNING_SLOTS - 1) ss << ",";
        ss << "\n";
    }
    
    ss << "    ]\n";
    ss << "},\n\n";
    
    // Individual image modules - Pinned
    for (int i = 0; i < MAX_PINNED_SLOTS; i++) {
        ss << "\"image#pin" << i << "\": {\n";
        ss << "    \"path\": \"" << m_icons_dir << "/pin_" << i << ".png\",\n";
        ss << "    \"size\": 24,\n";
        ss << "    \"on-click\": \"" << m_temp_dir << "/click.sh pin " << i << "\",\n";
        ss << "    \"on-click-middle\": \"" << m_temp_dir << "/click.sh middle pin " << i << "\",\n";
        ss << "    \"on-click-right\": \"" << m_temp_dir << "/click.sh right pin " << i << "\"\n";
        ss << "},\n";
    }
    
    ss << "\n";
    
    // Individual image modules - Running
    for (int i = 0; i < MAX_RUNNING_SLOTS; i++) {
        ss << "\"image#run" << i << "\": {\n";
        ss << "    \"path\": \"" << m_icons_dir << "/run_" << i << ".png\",\n";
        ss << "    \"size\": 24,\n";
        ss << "    \"on-click\": \"" << m_temp_dir << "/click.sh run " << i << "\",\n";
        ss << "    \"on-click-middle\": \"" << m_temp_dir << "/click.sh middle run " << i << "\",\n";
        ss << "    \"on-click-right\": \"" << m_temp_dir << "/click.sh right run " << i << "\"\n";
        ss << "}";
        if (i < MAX_RUNNING_SLOTS - 1) ss << ",";
        ss << "\n";
    }
    
    return ss.str();
}

std::string Taskbar::escape_json(const std::string& str) {
    std::string result;
    for (char c : str) {
        switch (c) {
            case '"': result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\n': result += "\\n"; break;
            case '\t': result += "\\t"; break;
            default: result += c;
        }
    }
    return result;
}

void Taskbar::cleanup() {
    if (m_skip_cleanup) {
        return;
    }
    std::cout << "[Taskbar] 🧹 Cleaning up...\n";
    try {
        if (fs::exists(m_temp_dir)) {
            fs::remove_all(m_temp_dir);
        }
    } catch (const std::exception& e) {
        std::cerr << "[Taskbar] Cleanup error: " << e.what() << "\n";
    }
}