/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Taskbar - Main Waybar Module Interface
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#ifndef TASKBAR_HPP
#define TASKBAR_HPP

#include <string>
#include <vector>
#include <map>

#include "hypr_ipc.hpp"
#include "pinned_manager.hpp"
#include "icon_resolver.hpp"

struct TaskbarItem {
    std::string id;
    std::string wm_class;
    std::string icon_path;
    std::string nerd_icon;
    std::string tooltip;
    bool is_pinned;
    bool is_running;
    bool is_focused;
    int window_count;
};

class Taskbar {
public:
    Taskbar();
    ~Taskbar();
    
    /**
     * Get JSON output for Waybar custom module
     * Format: {"text": "icons...", "tooltip": "...", "class": "..."}
     */
    std::string get_waybar_json();
    
    /**
     * Get all taskbar items
     */
    std::vector<TaskbarItem> get_items();
    
    /**
     * Handle click on an item
     */
    void handle_click(const std::string& app_id);
    
    /**
     * Handle right-click (context menu)
     */
    void handle_right_click(const std::string& app_id);

private:
    HyprlandIPC m_ipc;
    PinnedManager m_pinned;
    IconResolver m_icons;
    
    std::string build_text(const std::vector<TaskbarItem>& items);
    std::string build_tooltip(const std::vector<TaskbarItem>& items);
    std::string escape_json(const std::string& str);
};

#endif // TASKBAR_HPP
