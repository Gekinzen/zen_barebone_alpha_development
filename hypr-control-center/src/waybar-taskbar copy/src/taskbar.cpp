/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Taskbar - Implementation
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include "taskbar.hpp"

#include <sstream>
#include <algorithm>
#include <set>

Taskbar::Taskbar() {}

Taskbar::~Taskbar() {}

std::vector<TaskbarItem> Taskbar::get_items() {
    std::vector<TaskbarItem> items;
    
    // Get pinned apps
    auto pinned_apps = m_pinned.get_pinned_apps();
    
    // Get running apps
    auto app_groups = m_ipc.get_app_groups();
    
    // Track which apps we've added
    std::set<std::string> added;
    
    // Add pinned apps first (maintains order)
    for (const auto& pinned : pinned_apps) {
        TaskbarItem item;
        item.id = pinned.app_id;
        item.wm_class = pinned.wm_class;
        item.is_pinned = true;
        item.is_running = false;
        item.is_focused = false;
        item.window_count = 0;
        
        // Check if running
        std::string lower_wm = pinned.wm_class;
        std::transform(lower_wm.begin(), lower_wm.end(), lower_wm.begin(), ::tolower);
        
        std::string lower_id = pinned.app_id;
        std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
        
        for (const auto& [wm_class, group] : app_groups) {
            std::string lower_group = wm_class;
            std::transform(lower_group.begin(), lower_group.end(), lower_group.begin(), ::tolower);
            
            if (lower_group == lower_wm || lower_group == lower_id) {
                item.is_running = true;
                item.is_focused = group.has_focus;
                item.window_count = group.window_count();
                added.insert(lower_group);
                break;
            }
        }
        
        // Get icon
        item.icon_path = m_icons.get_icon_path(item.wm_class, 24);
        item.nerd_icon = m_icons.get_nerd_icon(item.wm_class);
        
        // Tooltip
        item.tooltip = pinned.app_id;
        if (item.window_count > 1) {
            item.tooltip += " (" + std::to_string(item.window_count) + " windows)";
        }
        
        items.push_back(item);
        added.insert(lower_id);
        added.insert(lower_wm);
    }
    
    // Add running apps that aren't pinned
    for (const auto& [wm_class, group] : app_groups) {
        std::string lower = wm_class;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        
        if (added.find(lower) != added.end()) continue;
        
        TaskbarItem item;
        item.id = wm_class;
        item.wm_class = group.wm_class;
        item.is_pinned = false;
        item.is_running = true;
        item.is_focused = group.has_focus;
        item.window_count = group.window_count();
        
        // Get icon
        item.icon_path = m_icons.get_icon_path(group.wm_class, 24);
        item.nerd_icon = m_icons.get_nerd_icon(group.wm_class);
        
        // Tooltip
        item.tooltip = group.wm_class;
        if (item.window_count > 1) {
            item.tooltip += " (" + std::to_string(item.window_count) + " windows)";
        }
        
        items.push_back(item);
        added.insert(lower);
    }
    
    return items;
}

std::string Taskbar::build_text(const std::vector<TaskbarItem>& items) {
    std::stringstream ss;
    
    bool has_pinned = false;
    bool has_running_unpinned = false;
    
    // Check for pinned and running
    for (const auto& item : items) {
        if (item.is_pinned) has_pinned = true;
        if (item.is_running && !item.is_pinned) has_running_unpinned = true;
    }
    
    // Colors (Tokyo Night theme - adjust as needed)
    const char* color_focused = "#7aa2f7";   // Blue - focused
    const char* color_running = "#c0caf5";   // White - running
    const char* color_pinned = "#565f89";    // Gray - pinned but not running
    const char* color_separator = "#414868"; // Dark gray - separator
    
    bool added_separator = false;
    
    for (size_t i = 0; i < items.size(); i++) {
        const auto& item = items[i];
        
        // Add separator between pinned and non-pinned running apps
        if (has_pinned && has_running_unpinned && !item.is_pinned && item.is_running && !added_separator) {
            ss << "<span color=\\\"" << color_separator << "\\\">│</span> ";
            added_separator = true;
        }
        
        // Determine color based on state
        const char* color;
        if (item.is_focused) {
            color = color_focused;
        } else if (item.is_running) {
            color = color_running;
        } else {
            color = color_pinned;
        }
        
        // Output icon with color
        ss << "<span color=\\\"" << color << "\\\">" << item.nerd_icon << "</span> ";
    }
    
    return ss.str();
}

std::string Taskbar::build_tooltip(const std::vector<TaskbarItem>& items) {
    std::stringstream ss;
    
    ss << "Taskbar\\n";
    ss << "────────────\\n";
    
    for (const auto& item : items) {
        if (item.is_focused) {
            ss << "● ";
        } else if (item.is_running) {
            ss << "○ ";
        } else {
            ss << "  ";
        }
        
        ss << item.wm_class;
        
        if (item.window_count > 1) {
            ss << " (" << item.window_count << ")";
        }
        
        if (item.is_pinned) {
            ss << " 📌";
        }
        
        ss << "\\n";
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

std::string Taskbar::get_waybar_json() {
    auto items = get_items();
    
    std::string text = build_text(items);
    std::string tooltip = build_tooltip(items);
    
    // Count states for CSS class
    bool has_focused = false;
    int running_count = 0;
    
    for (const auto& item : items) {
        if (item.is_focused) has_focused = true;
        if (item.is_running) running_count++;
    }
    
    std::string css_class = "taskbar";
    if (has_focused) css_class += " has-focused";
    if (running_count > 0) css_class += " has-running";
    
    // Build JSON
    std::stringstream json;
    json << "{";
    json << "\"text\": \"" << text << "\", ";
    json << "\"tooltip\": \"" << escape_json(tooltip) << "\", ";
    json << "\"class\": \"" << css_class << "\"";
    json << "}";
    
    return json.str();
}

void Taskbar::handle_click(const std::string& app_id) {
    // Get app groups
    auto groups = m_ipc.get_app_groups();
    
    std::string lower_id = app_id;
    std::transform(lower_id.begin(), lower_id.end(), lower_id.begin(), ::tolower);
    
    // Find matching group
    for (const auto& [wm_class, group] : groups) {
        std::string lower = wm_class;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        
        if (lower == lower_id || group.wm_class == app_id) {
            if (group.window_count() == 1) {
                // Focus single window
                m_ipc.focus_window(group.windows[0].address);
            } else if (group.window_count() > 1) {
                // Focus most recent (first in list)
                m_ipc.focus_window(group.windows[0].address);
            }
            return;
        }
    }
    
    // Not running - launch
    m_pinned.launch_app(app_id);
}

void Taskbar::handle_right_click(const std::string& app_id) {
    // For now, just toggle pin state
    if (m_pinned.is_pinned(app_id)) {
        m_pinned.unpin_app(app_id);
    } else {
        m_pinned.pin_app(app_id);
    }
}