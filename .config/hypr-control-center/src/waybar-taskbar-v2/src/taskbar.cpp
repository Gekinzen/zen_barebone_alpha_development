/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Taskbar v2 - Implementation
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include "taskbar.hpp"

#include <fstream>
#include <sstream>
#include <algorithm>
#include <cstdlib>
#include <set>

Taskbar::Taskbar() {}

void Taskbar::refresh_items() {
    m_items.clear();
    
    auto pinned_apps = m_pinned.get_pinned_apps();
    auto app_groups = m_ipc.get_app_groups();
    
    std::set<std::string> added;
    int index = 0;
    
    // Add pinned apps first
    for (const auto& pinned : pinned_apps) {
        TaskbarItem item;
        item.app_id = pinned.app_id;
        item.wm_class = pinned.wm_class.empty() ? pinned.app_id : pinned.wm_class;
        item.is_pinned = true;
        item.is_running = false;
        item.is_focused = false;
        item.window_count = 0;
        item.index = index++;
        
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
                added.insert(lower_group);
                break;
            }
        }
        
        // Get icons
        item.icon_path = m_icons.get_icon_path(item.wm_class, 48);
        if (item.icon_path.empty()) {
            item.icon_path = m_icons.get_icon_path(item.app_id, 48);
        }
        item.nerd_icon = m_icons.get_nerd_icon(item.wm_class);
        
        // Tooltip
        item.tooltip = item.app_id;
        if (item.window_count > 1) {
            item.tooltip += " (" + std::to_string(item.window_count) + ")";
        }
        
        m_items.push_back(item);
        added.insert(lower_id);
        added.insert(lower_wm);
    }
    
    // Add running (non-pinned) apps
    for (const auto& [wm_class, group] : app_groups) {
        std::string lower = wm_class;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        
        if (added.count(lower) > 0) continue;
        
        std::string lower_wm = group.wm_class;
        std::transform(lower_wm.begin(), lower_wm.end(), lower_wm.begin(), ::tolower);
        if (added.count(lower_wm) > 0) continue;
        
        TaskbarItem item;
        item.app_id = wm_class;
        item.wm_class = group.wm_class;
        item.is_pinned = false;
        item.is_running = true;
        item.is_focused = group.has_focus;
        item.window_count = group.window_count();
        item.index = index++;
        
        item.icon_path = m_icons.get_icon_path(group.wm_class, 48);
        if (item.icon_path.empty()) {
            item.icon_path = m_icons.get_icon_path(wm_class, 48);
        }
        item.nerd_icon = m_icons.get_nerd_icon(group.wm_class);
        
        item.tooltip = group.wm_class;
        if (item.window_count > 1) {
            item.tooltip += " (" + std::to_string(item.window_count) + ")";
        }
        
        m_items.push_back(item);
        added.insert(lower);
    }
}

std::vector<TaskbarItem> Taskbar::get_items() {
    refresh_items();
    return m_items;
}

std::string Taskbar::build_waybar_text() {
    std::stringstream ss;
    
    // Colors
    const char* color_focused = "#7aa2f7";
    const char* color_running = "#c0caf5";
    const char* color_pinned = "#565f89";
    const char* color_separator = "#414868";
    
    bool has_pinned = false;
    bool has_running_unpinned = false;
    
    for (const auto& item : m_items) {
        if (item.is_pinned) has_pinned = true;
        if (!item.is_pinned && item.is_running) has_running_unpinned = true;
    }
    
    bool added_separator = false;
    
    for (const auto& item : m_items) {
        // Separator between pinned and running
        if (has_pinned && has_running_unpinned && !item.is_pinned && !added_separator) {
            ss << "<span color='" << color_separator << "'>│</span> ";
            added_separator = true;
        }
        
        const char* color;
        if (item.is_focused) {
            color = color_focused;
        } else if (item.is_running) {
            color = color_running;
        } else {
            color = color_pinned;
        }
        
        ss << "<span color='" << color << "'>" << item.nerd_icon << "</span>";
        if (item.window_count > 1) {
            ss << "<span color='#9aa5ce'>(" << item.window_count << ")</span>";
        }
        ss << " ";
    }
    
    return ss.str();
}

std::string Taskbar::build_tooltip() {
    std::stringstream ss;
    ss << "Taskbar - Click for options";
    return ss.str();
}

std::string Taskbar::escape_json(const std::string& str) {
    std::string result;
    for (char c : str) {
        switch (c) {
            case '"': result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\n': result += "\\n"; break;
            default: result += c;
        }
    }
    return result;
}

std::string Taskbar::get_waybar_json() {
    refresh_items();
    
    std::string text = build_waybar_text();
    std::string tooltip = build_tooltip();
    
    std::stringstream json;
    json << "{";
    json << "\"text\": \"" << text << "\", ";
    json << "\"tooltip\": \"" << escape_json(tooltip) << "\", ";
    json << "\"class\": \"taskbar\"";
    json << "}";
    
    // Save state for popup
    save_state();
    
    return json.str();
}

std::string Taskbar::get_items_json() {
    refresh_items();
    
    std::stringstream json;
    json << "[\n";
    
    for (size_t i = 0; i < m_items.size(); i++) {
        const auto& item = m_items[i];
        json << "  {\n";
        json << "    \"index\": " << item.index << ",\n";
        json << "    \"app_id\": \"" << escape_json(item.app_id) << "\",\n";
        json << "    \"wm_class\": \"" << escape_json(item.wm_class) << "\",\n";
        json << "    \"icon_path\": \"" << escape_json(item.icon_path) << "\",\n";
        json << "    \"nerd_icon\": \"" << escape_json(item.nerd_icon) << "\",\n";
        json << "    \"is_pinned\": " << (item.is_pinned ? "true" : "false") << ",\n";
        json << "    \"is_running\": " << (item.is_running ? "true" : "false") << ",\n";
        json << "    \"is_focused\": " << (item.is_focused ? "true" : "false") << ",\n";
        json << "    \"window_count\": " << item.window_count << "\n";
        json << "  }";
        if (i < m_items.size() - 1) json << ",";
        json << "\n";
    }
    
    json << "]\n";
    return json.str();
}

void Taskbar::save_state() {
    const char* xdg_runtime = getenv("XDG_RUNTIME_DIR");
    std::string state_dir = xdg_runtime ? std::string(xdg_runtime) + "/waybar-taskbar" 
                                         : "/tmp/waybar-taskbar";
    
    system(("mkdir -p \"" + state_dir + "\"").c_str());
    
    std::string state_path = state_dir + "/state.json";
    std::ofstream file(state_path);
    if (file.is_open()) {
        file << get_items_json();
        file.close();
    }
}

void Taskbar::handle_click(int index) {
    refresh_items();
    
    // Launch Python popup
    const char* xdg_runtime = getenv("XDG_RUNTIME_DIR");
    std::string state_dir = xdg_runtime ? std::string(xdg_runtime) + "/waybar-taskbar" 
                                         : "/tmp/waybar-taskbar";
    
    std::string popup_script = std::string(getenv("HOME")) + 
                               "/.config/waybar/scripts/taskbar-popup.py";
    
    std::string cmd = popup_script + " " + std::to_string(index) + " &";
    system(cmd.c_str());
}

void Taskbar::focus_app(const std::string& app_id) {
    auto groups = m_ipc.get_app_groups();
    
    std::string lower_id = app_id;
    std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
    
    for (const auto& [wm_class, group] : groups) {
        std::string lower = wm_class;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        
        if (lower == lower_id || group.wm_class == app_id) {
            if (!group.windows.empty()) {
                m_ipc.focus_window(group.windows[0].address);
            }
            return;
        }
    }
}

void Taskbar::launch_app(const std::string& app_id) {
    m_pinned.launch_app(app_id);
}

void Taskbar::close_app(const std::string& app_id) {
    m_ipc.close_app(app_id);
}

void Taskbar::toggle_pin(const std::string& app_id) {
    if (m_pinned.is_pinned(app_id)) {
        m_pinned.unpin_app(app_id);
    } else {
        m_pinned.pin_app(app_id);
    }
}