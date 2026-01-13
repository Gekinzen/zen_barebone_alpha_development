/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Icon Resolver - GTK Theme Icon Resolution
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#ifndef ICON_RESOLVER_HPP
#define ICON_RESOLVER_HPP

#include <string>
#include <map>
#include <vector>

class IconResolver {
public:
    IconResolver();
    ~IconResolver();
    
    /**
     * Get icon path for an application
     * @param app_id Application ID or wm_class
     * @param size Desired icon size
     * @return Path to icon file, or empty string if not found
     */
    std::string get_icon_path(const std::string& app_id, int size = 24);
    
    /**
     * Get Nerd Font icon fallback
     * @param app_id Application ID
     * @return Nerd Font icon character
     */
    std::string get_nerd_icon(const std::string& app_id);
    
    /**
     * Get current GTK icon theme name
     */
    std::string get_current_theme();
    
    /**
     * Clear icon cache
     */
    void clear_cache();

private:
    std::string m_current_theme;
    std::map<std::string, std::string> m_cache;
    std::map<std::string, std::string> m_nerd_icons;
    std::map<std::string, std::string> m_wm_class_map;
    
    void init_nerd_icons();
    void init_wm_class_map();
    void detect_icon_theme();
    
    std::string normalize_app_id(const std::string& app_id);
    std::string find_in_theme(const std::string& app_id, int size);
    std::string find_in_hicolor(const std::string& app_id, int size);
    std::string find_in_pixmaps(const std::string& app_id);
    std::string find_desktop_icon(const std::string& app_id);
};

#endif // ICON_RESOLVER_HPP