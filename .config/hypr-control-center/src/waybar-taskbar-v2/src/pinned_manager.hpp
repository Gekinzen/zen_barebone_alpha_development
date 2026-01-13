/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Pinned Manager - Pin/Unpin Apps to Taskbar
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#ifndef PINNED_MANAGER_HPP
#define PINNED_MANAGER_HPP

#include <string>
#include <vector>

struct PinnedApp {
    std::string app_id;
    std::string wm_class;
    std::string exec_cmd;
    std::string icon;
    std::string desktop_file;
    int order;
};

class PinnedManager {
public:
    PinnedManager();
    ~PinnedManager();
    
    /**
     * Get list of pinned apps
     */
    std::vector<PinnedApp> get_pinned_apps();
    
    /**
     * Check if app is pinned
     */
    bool is_pinned(const std::string& app_id);
    
    /**
     * Pin an app
     */
    void pin_app(const std::string& app_id, const std::string& wm_class = "");
    
    /**
     * Unpin an app
     */
    void unpin_app(const std::string& app_id);
    
    /**
     * Reorder pinned apps
     */
    void reorder(const std::vector<std::string>& new_order);
    
    /**
     * Launch an app
     */
    void launch_app(const std::string& app_id);

private:
    std::string m_config_path;
    std::vector<PinnedApp> m_pinned;
    
    void load();
    void save();
    
    std::string find_desktop_file(const std::string& app_id);
    PinnedApp parse_desktop_file(const std::string& path, const std::string& app_id);
};

#endif // PINNED_MANAGER_HPP