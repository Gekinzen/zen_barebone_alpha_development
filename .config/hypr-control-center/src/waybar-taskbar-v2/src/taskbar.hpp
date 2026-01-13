/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Waybar Taskbar v2 - Nerd Font Icons + Python Popup
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
    std::string app_id;
    std::string wm_class;
    std::string icon_path;
    std::string nerd_icon;
    std::string tooltip;
    bool is_pinned;
    bool is_running;
    bool is_focused;
    int window_count;
    int index;
};

class Taskbar {
public:
    Taskbar();
    
    /**
     * Get JSON output for Waybar custom module
     */
    std::string get_waybar_json();
    
    /**
     * Get all items as JSON (for Python popup)
     */
    std::string get_items_json();
    
    /**
     * Get all taskbar items
     */
    std::vector<TaskbarItem> get_items();
    
    /**
     * Handle click - launch Python popup
     */
    void handle_click(int index);
    
    /**
     * Focus window by app_id
     */
    void focus_app(const std::string& app_id);
    
    /**
     * Launch app by app_id
     */
    void launch_app(const std::string& app_id);
    
    /**
     * Close app by app_id
     */
    void close_app(const std::string& app_id);
    
    /**
     * Pin/Unpin app
     */
    void toggle_pin(const std::string& app_id);
    
    /**
     * Save state to temp file (for Python popup)
     */
    void save_state();

private:
    HyprlandIPC m_ipc;
    PinnedManager m_pinned;
    IconResolver m_icons;
    
    std::vector<TaskbarItem> m_items;
    
    void refresh_items();
    std::string build_waybar_text();
    std::string build_tooltip();
    std::string escape_json(const std::string& str);
};

#endif