/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Icon Resolver - Implementation
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include "icon_resolver.hpp"

#include <gtk/gtk.h>
#include <gio/gio.h>
#include <gio/gdesktopappinfo.h>
#include <filesystem>
#include <algorithm>
#include <fstream>
#include <cstdlib>

namespace fs = std::filesystem;

IconResolver::IconResolver() {
    init_nerd_icons();
    init_wm_class_map();
    detect_icon_theme();
}

IconResolver::~IconResolver() {}

void IconResolver::init_nerd_icons() {
    // Browsers
    m_nerd_icons["firefox"] = "";
    m_nerd_icons["chromium"] = "";
    m_nerd_icons["google-chrome"] = "";
    m_nerd_icons["brave-browser"] = "󰖟";
    m_nerd_icons["zen-browser"] = "󰖟";
    
    // Terminals
    m_nerd_icons["kitty"] = "";
    m_nerd_icons["alacritty"] = "";
    m_nerd_icons["foot"] = "";
    m_nerd_icons["wezterm"] = "";
    m_nerd_icons["konsole"] = "";
    
    // Development
    m_nerd_icons["code"] = "󰨞";
    m_nerd_icons["visual-studio-code"] = "󰨞";
    m_nerd_icons["code-oss"] = "󰨞";
    m_nerd_icons["neovim"] = "";
    m_nerd_icons["vim"] = "";
    
    // Files
    m_nerd_icons["nautilus"] = "";
    m_nerd_icons["thunar"] = "";
    m_nerd_icons["dolphin"] = "";
    m_nerd_icons["pcmanfm"] = "";
    m_nerd_icons["nemo"] = "";
    
    // Media
    m_nerd_icons["spotify"] = "";
    m_nerd_icons["vlc"] = "󰕼";
    m_nerd_icons["mpv"] = "";
    
    // Communication
    m_nerd_icons["discord"] = "󰙯";
    m_nerd_icons["slack"] = "󰒱";
    m_nerd_icons["telegram-desktop"] = "";
    m_nerd_icons["signal-desktop"] = "󰭹";
    
    // System
    m_nerd_icons["pavucontrol"] = "󰕾";
    m_nerd_icons["blueman-manager"] = "";
    
    // Graphics
    m_nerd_icons["gimp"] = "";
    m_nerd_icons["inkscape"] = "";
    m_nerd_icons["blender"] = "󰂫";
    
    // Games
    m_nerd_icons["steam"] = "";
    m_nerd_icons["lutris"] = "";
    
    // Default
    m_nerd_icons["default"] = "󰣆";
}

void IconResolver::init_wm_class_map() {
    m_wm_class_map["Firefox"] = "firefox";
    m_wm_class_map["firefox"] = "firefox";
    m_wm_class_map["Google-chrome"] = "google-chrome";
    m_wm_class_map["Brave-browser"] = "brave-browser";
    m_wm_class_map["Code"] = "visual-studio-code";
    m_wm_class_map["code"] = "visual-studio-code";
    m_wm_class_map["code-oss"] = "code-oss";
    m_wm_class_map["kitty"] = "kitty";
    m_wm_class_map["Alacritty"] = "Alacritty";
    m_wm_class_map["org.gnome.Nautilus"] = "org.gnome.Nautilus";
    m_wm_class_map["Thunar"] = "Thunar";
    m_wm_class_map["thunar"] = "Thunar";
    m_wm_class_map["Discord"] = "discord";
    m_wm_class_map["discord"] = "discord";
    m_wm_class_map["Spotify"] = "spotify";
    m_wm_class_map["spotify"] = "spotify";
    m_wm_class_map["Steam"] = "steam";
    m_wm_class_map["steam"] = "steam";
    m_wm_class_map["TelegramDesktop"] = "telegram";
    m_wm_class_map["Gimp-2.10"] = "gimp";
    m_wm_class_map["Zen Browser"] = "zen-browser";
}

void IconResolver::detect_icon_theme() {
    m_current_theme = "Adwaita"; // Default
    
    // Try gsettings
    GSettings* settings = g_settings_new("org.gnome.desktop.interface");
    if (settings) {
        gchar* theme = g_settings_get_string(settings, "icon-theme");
        if (theme) {
            m_current_theme = theme;
            g_free(theme);
        }
        g_object_unref(settings);
    }
}

std::string IconResolver::get_current_theme() {
    return m_current_theme;
}

std::string IconResolver::normalize_app_id(const std::string& app_id) {
    // Check wm_class map first
    auto it = m_wm_class_map.find(app_id);
    if (it != m_wm_class_map.end()) {
        return it->second;
    }
    
    // Lowercase and replace underscores
    std::string normalized = app_id;
    std::transform(normalized.begin(), normalized.end(), normalized.begin(), ::tolower);
    std::replace(normalized.begin(), normalized.end(), '_', '-');
    
    return normalized;
}

std::string IconResolver::get_icon_path(const std::string& app_id, int size) {
    // Check cache
    std::string cache_key = app_id + ":" + std::to_string(size);
    auto it = m_cache.find(cache_key);
    if (it != m_cache.end()) {
        return it->second;
    }
    
    std::string normalized = normalize_app_id(app_id);
    std::string path;
    
    // Search order
    path = find_in_theme(normalized, size);
    if (path.empty()) path = find_in_hicolor(normalized, size);
    if (path.empty()) path = find_in_pixmaps(normalized);
    if (path.empty()) path = find_desktop_icon(app_id);
    
    // Cache result
    m_cache[cache_key] = path;
    
    return path;
}

std::string IconResolver::find_in_theme(const std::string& app_id, int size) {
    std::vector<std::string> theme_paths = {
        std::string(getenv("HOME")) + "/.local/share/icons/" + m_current_theme,
        std::string(getenv("HOME")) + "/.icons/" + m_current_theme,
        "/usr/share/icons/" + m_current_theme,
    };
    
    std::vector<std::string> size_dirs = {
        std::to_string(size) + "x" + std::to_string(size) + "/apps",
        "scalable/apps",
        "48x48/apps",
        "32x32/apps",
        "24x24/apps",
        "22x22/apps",
    };
    
    std::vector<std::string> extensions = {".svg", ".png", ".xpm"};
    
    // Try variations of app_id
    std::vector<std::string> app_ids = {
        app_id,
        normalize_app_id(app_id),
    };
    
    // Add org.gnome variant
    std::string capitalized = app_id;
    if (!capitalized.empty()) {
        capitalized[0] = std::toupper(capitalized[0]);
    }
    app_ids.push_back("org.gnome." + capitalized);
    
    for (const auto& theme_path : theme_paths) {
        if (!fs::exists(theme_path)) continue;
        
        for (const auto& size_dir : size_dirs) {
            fs::path icon_dir = fs::path(theme_path) / size_dir;
            if (!fs::exists(icon_dir)) continue;
            
            for (const auto& aid : app_ids) {
                for (const auto& ext : extensions) {
                    fs::path icon_path = icon_dir / (aid + ext);
                    if (fs::exists(icon_path)) {
                        return icon_path.string();
                    }
                }
            }
        }
    }
    
    return "";
}

std::string IconResolver::find_in_hicolor(const std::string& app_id, int size) {
    std::vector<std::string> hicolor_paths = {
        "/usr/share/icons/hicolor",
        std::string(getenv("HOME")) + "/.local/share/icons/hicolor",
    };
    
    std::vector<std::string> size_dirs = {
        std::to_string(size) + "x" + std::to_string(size) + "/apps",
        "scalable/apps",
        "48x48/apps",
        "32x32/apps",
    };
    
    std::vector<std::string> extensions = {".svg", ".png", ".xpm"};
    
    for (const auto& hicolor_path : hicolor_paths) {
        if (!fs::exists(hicolor_path)) continue;
        
        for (const auto& size_dir : size_dirs) {
            fs::path icon_dir = fs::path(hicolor_path) / size_dir;
            if (!fs::exists(icon_dir)) continue;
            
            for (const auto& ext : extensions) {
                fs::path icon_path = icon_dir / (app_id + ext);
                if (fs::exists(icon_path)) {
                    return icon_path.string();
                }
            }
        }
    }
    
    return "";
}

std::string IconResolver::find_in_pixmaps(const std::string& app_id) {
    std::vector<std::string> extensions = {".png", ".svg", ".xpm"};
    
    for (const auto& ext : extensions) {
        fs::path icon_path = fs::path("/usr/share/pixmaps") / (app_id + ext);
        if (fs::exists(icon_path)) {
            return icon_path.string();
        }
    }
    
    return "";
}

std::string IconResolver::find_desktop_icon(const std::string& app_id) {
    // Try to find .desktop file and get icon from there
    std::vector<std::string> desktop_paths = {
        std::string(getenv("HOME")) + "/.local/share/applications",
        "/usr/share/applications",
    };
    
    std::vector<std::string> variations = {
        app_id + ".desktop",
        normalize_app_id(app_id) + ".desktop",
    };
    
    for (const auto& desktop_path : desktop_paths) {
        if (!fs::exists(desktop_path)) continue;
        
        for (const auto& variation : variations) {
            fs::path desktop_file = fs::path(desktop_path) / variation;
            if (fs::exists(desktop_file)) {
                // Parse desktop file for Icon=
                GDesktopAppInfo* app_info = g_desktop_app_info_new_from_filename(desktop_file.c_str());
                if (app_info) {
                    const char* icon_name = g_desktop_app_info_get_string(app_info, "Icon");
                    if (icon_name) {
                        std::string icon_str = icon_name;
                        g_object_unref(app_info);
                        
                        // If it's a full path, return it
                        if (icon_str[0] == '/') {
                            return icon_str;
                        }
                        
                        // Otherwise search for it
                        return find_in_theme(icon_str, 24);
                    }
                    g_object_unref(app_info);
                }
            }
        }
    }
    
    return "";
}

std::string IconResolver::get_nerd_icon(const std::string& app_id) {
    std::string normalized = normalize_app_id(app_id);
    
    // Direct match
    auto it = m_nerd_icons.find(normalized);
    if (it != m_nerd_icons.end()) {
        return it->second;
    }
    
    // Partial match
    for (const auto& [key, icon] : m_nerd_icons) {
        if (normalized.find(key) != std::string::npos || key.find(normalized) != std::string::npos) {
            return icon;
        }
    }
    
    return m_nerd_icons["default"];
}

void IconResolver::clear_cache() {
    m_cache.clear();
}
