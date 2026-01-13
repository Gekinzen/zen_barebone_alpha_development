/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Waybar Taskbar Module - Main Entry Point
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * Custom taskbar for Waybar with:
 * - Real PNG icons from GTK theme
 * - Hyprland IPC window tracking
 * - Pin/Unpin functionality
 * - Click to focus/launch
 * 
 * Usage:
 *   waybar-taskbar              # Output JSON for Waybar
 *   waybar-taskbar click <id>   # Handle click on item
 *   waybar-taskbar pin <app>    # Pin an app
 *   waybar-taskbar unpin <app>  # Unpin an app
 *   waybar-taskbar --test       # Test mode
 */

#include <iostream>
#include <string>
#include <cstring>

#include "taskbar.hpp"
#include "hypr_ipc.hpp"
#include "pinned_manager.hpp"
#include "icon_resolver.hpp"

void print_usage() {
    std::cout << "Waybar Taskbar Module\n"
              << "═══════════════════════════════════════════════\n"
              << "\n"
              << "Usage:\n"
              << "  waybar-taskbar              Output JSON for Waybar\n"
              << "  waybar-taskbar click <id>   Handle click on item\n"
              << "  waybar-taskbar pin <app>    Pin an app\n"
              << "  waybar-taskbar unpin <app>  Unpin an app\n"
              << "  waybar-taskbar list         List pinned apps\n"
              << "  waybar-taskbar --test       Run tests\n"
              << "  waybar-taskbar --help       Show this help\n"
              << "\n"
              << "Waybar config.jsonc:\n"
              << "  \"custom/taskbar\": {\n"
              << "      \"exec\": \"~/.config/waybar/scripts/waybar-taskbar\",\n"
              << "      \"return-type\": \"json\",\n"
              << "      \"interval\": 1\n"
              << "  }\n";
}

void run_tests() {
    std::cout << "🧪 Running tests...\n\n";
    
    // Test Icon Resolver
    std::cout << "═══ Icon Resolver ═══\n";
    IconResolver resolver;
    
    std::vector<std::string> test_apps = {"firefox", "kitty", "code", "nautilus", "spotify"};
    for (const auto& app : test_apps) {
        std::string icon_path = resolver.get_icon_path(app, 24);
        std::string nerd_icon = resolver.get_nerd_icon(app);
        
        if (!icon_path.empty()) {
            std::cout << "  ✅ " << app << ": " << icon_path << "\n";
        } else {
            std::cout << "  ⚠️ " << app << ": Nerd fallback: " << nerd_icon << "\n";
        }
    }
    
    // Test Hyprland IPC
    std::cout << "\n═══ Hyprland IPC ═══\n";
    HyprlandIPC ipc;
    
    if (ipc.is_connected()) {
        std::cout << "  ✅ Connected to Hyprland\n";
        
        auto windows = ipc.get_windows();
        std::cout << "  📋 Windows: " << windows.size() << "\n";
        
        for (const auto& win : windows) {
            std::cout << "     - " << win.wm_class << ": " << win.title.substr(0, 30) << "\n";
        }
    } else {
        std::cout << "  ❌ Not connected to Hyprland\n";
    }
    
    // Test Pinned Manager
    std::cout << "\n═══ Pinned Manager ═══\n";
    PinnedManager pinned;
    
    auto apps = pinned.get_pinned_apps();
    std::cout << "  📌 Pinned apps: " << apps.size() << "\n";
    for (const auto& app : apps) {
        std::cout << "     - " << app.app_id << " (" << app.wm_class << ")\n";
    }
    
    std::cout << "\n✅ Tests complete!\n";
}

int main(int argc, char* argv[]) {
    // Parse arguments
    if (argc > 1) {
        std::string cmd = argv[1];
        
        if (cmd == "--help" || cmd == "-h") {
            print_usage();
            return 0;
        }
        
        if (cmd == "--test") {
            run_tests();
            return 0;
        }
        
        if (cmd == "click" && argc > 2) {
            std::string app_id = argv[2];
            Taskbar taskbar;
            taskbar.handle_click(app_id);
            return 0;
        }
        
        if (cmd == "pin" && argc > 2) {
            std::string app_id = argv[2];
            PinnedManager pinned;
            pinned.pin_app(app_id);
            std::cout << "📌 Pinned: " << app_id << "\n";
            return 0;
        }
        
        if (cmd == "unpin" && argc > 2) {
            std::string app_id = argv[2];
            PinnedManager pinned;
            pinned.unpin_app(app_id);
            std::cout << "📍 Unpinned: " << app_id << "\n";
            return 0;
        }
        
        if (cmd == "list") {
            PinnedManager pinned;
            auto apps = pinned.get_pinned_apps();
            std::cout << "📌 Pinned Apps:\n";
            for (const auto& app : apps) {
                std::cout << "  - " << app.app_id << "\n";
            }
            return 0;
        }
    }
    
    // Default: Output JSON for Waybar
    Taskbar taskbar;
    std::cout << taskbar.get_waybar_json() << std::endl;
    
    return 0;
}
