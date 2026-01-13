/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Taskbar - Waybar Image Module Manager
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * Manages dynamic taskbar with real PNG icons via Waybar image modules.
 * - Copies icons from GTK theme to temp directory
 * - Generates Waybar config for image modules
 * - Handles click events
 * - Cleanup on exit
 */

#ifndef TASKBAR_HPP
#define TASKBAR_HPP

#include <string>
#include <vector>
#include <map>
#include <csignal>

#include "hypr_ipc.hpp"
#include "pinned_manager.hpp"
#include "icon_resolver.hpp"

// Max slots for taskbar
constexpr int MAX_PINNED_SLOTS = 12;
constexpr int MAX_RUNNING_SLOTS = 12;

struct TaskbarItem {
    std::string id;
    std::string app_id;
    std::string wm_class;
    std::string icon_path;      // Source icon from theme
    std::string slot_icon_path; // Copied icon in temp dir
    std::string nerd_icon;
    std::string tooltip;
    bool is_pinned;
    bool is_running;
    bool is_focused;
    int window_count;
    int slot_index;             // Position in taskbar
};

class Taskbar {
public:
    Taskbar();
    ~Taskbar();
    
    /**
     * Initialize - setup temp directory, signal handlers
     */
    bool init();
    
    /**
     * Update taskbar state - call this periodically
     * Returns true if state changed
     */
    bool update();
    
    /**
     * Get all taskbar items (pinned + running)
     */
    std::vector<TaskbarItem> get_items();
    
    /**
     * Get only pinned items
     */
    std::vector<TaskbarItem> get_pinned_items();
    
    /**
     * Get only running (non-pinned) items
     */
    std::vector<TaskbarItem> get_running_items();
    
    /**
     * Handle click on slot
     * @param slot_type "pin" or "run"
     * @param slot_index Index of the slot
     */
    void handle_click(const std::string& slot_type, int slot_index);
    
    /**
     * Handle middle click (close app)
     */
    void handle_middle_click(const std::string& slot_type, int slot_index);
    
    /**
     * Handle right click (context menu / pin toggle)
     */
    void handle_right_click(const std::string& slot_type, int slot_index);
    
    /**
     * Generate Waybar config snippet (JSON)
     */
    std::string generate_waybar_config();
    
    /**
     * Generate state.json for click handlers
     */
    void save_state();
    
    /**
     * Get temp directory path
     */
    std::string get_temp_dir() const { return m_temp_dir; }
    
    /**
     * Set skip cleanup flag (for click handlers)
     */
    void set_skip_cleanup(bool skip) { m_skip_cleanup = skip; }
    
    /**
     * Cleanup temp files
     */
    void cleanup();
    
    /**
     * Static cleanup for signal handler
     */
    static void signal_cleanup(int sig);
    static Taskbar* s_instance;

private:
    HyprlandIPC m_ipc;
    PinnedManager m_pinned;
    IconResolver m_icons;
    
    std::string m_temp_dir;
    std::string m_icons_dir;
    std::string m_empty_icon;
    
    std::vector<TaskbarItem> m_pinned_items;
    std::vector<TaskbarItem> m_running_items;
    
    // Slot to app_id mapping
    std::map<std::string, std::string> m_slot_map;
    
    // Previous state for change detection
    std::string m_last_state_hash;
    
    // Skip cleanup flag
    bool m_skip_cleanup = false;
    
    bool setup_temp_dir();
    void create_empty_icon();
    void copy_icon_to_slot(const std::string& src_path, const std::string& slot_name);
    void clear_slot(const std::string& slot_name);
    std::string compute_state_hash();
    std::string escape_json(const std::string& str);
};

#endif // TASKBAR_HPP