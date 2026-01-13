/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Hyprland IPC - Window Tracking via Unix Socket
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#ifndef HYPR_IPC_HPP
#define HYPR_IPC_HPP

#include <string>
#include <vector>
#include <map>

struct HyprWindow {
    std::string address;
    std::string wm_class;
    std::string title;
    int workspace;
    bool is_focused;
    std::string monitor;
};

struct AppGroup {
    std::string wm_class;
    std::vector<HyprWindow> windows;
    bool has_focus;
    
    int window_count() const { return windows.size(); }
};

class HyprlandIPC {
public:
    HyprlandIPC();
    ~HyprlandIPC();
    
    /**
     * Check if connected to Hyprland
     */
    bool is_connected() const;
    
    /**
     * Get all windows
     */
    std::vector<HyprWindow> get_windows();
    
    /**
     * Get windows grouped by wm_class
     */
    std::map<std::string, AppGroup> get_app_groups();
    
    /**
     * Focus a window by address
     */
    void focus_window(const std::string& address);
    
    /**
     * Close a window by address
     */
    void close_window(const std::string& address);
    
    /**
     * Close all windows of an app
     */
    void close_app(const std::string& wm_class);
    
    /**
     * Get active workspace
     */
    int get_active_workspace();

private:
    std::string m_socket_path;
    bool m_connected;
    
    std::string send_command(const std::string& cmd);
    std::string get_socket_path();
};

#endif // HYPR_IPC_HPP