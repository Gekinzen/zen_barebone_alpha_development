/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Waybar Taskbar v2 - Nerd Font + Python Popup
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include <iostream>
#include <string>
#include <cstdlib>

#include "taskbar.hpp"
#include "hypr_ipc.hpp"
#include "pinned_manager.hpp"

void print_usage() {
    std::cout << R"(
╔═══════════════════════════════════════════════════════════════════╗
║          WAYBAR TASKBAR v2 - Nerd Font + Python Popup             ║
╚═══════════════════════════════════════════════════════════════════╝

USAGE:
  waybar-taskbar              Output JSON for Waybar (default)
  waybar-taskbar click <idx>  Show popup for item at index
  waybar-taskbar focus <app>  Focus app window
  waybar-taskbar launch <app> Launch app
  waybar-taskbar close <app>  Close all windows of app
  waybar-taskbar pin <app>    Toggle pin state
  waybar-taskbar list         List all items as JSON
  waybar-taskbar --help       Show this help

WAYBAR CONFIG:
  "custom/taskbar": {
      "exec": "waybar-taskbar",
      "return-type": "json",
      "interval": 1,
      "on-click": "waybar-taskbar click {}",
      "escape": true
  }

)";
}

int main(int argc, char* argv[]) {
    Taskbar taskbar;
    
    if (argc < 2) {
        // Default: output Waybar JSON
        std::cout << taskbar.get_waybar_json() << std::endl;
        return 0;
    }
    
    std::string cmd = argv[1];
    
    if (cmd == "--help" || cmd == "-h") {
        print_usage();
        return 0;
    }
    
    if (cmd == "--test" || cmd == "test") {
        std::cout << "🧪 Running tests...\n\n";
        
        // Test Hyprland IPC
        std::cout << "═══ Hyprland IPC ═══\n";
        HyprlandIPC ipc;
        
        auto windows = ipc.get_windows();
        std::cout << "   📋 Windows found: " << windows.size() << "\n";
        
        for (const auto& win : windows) {
            std::cout << "      - class: " << win.wm_class 
                      << ", title: " << win.title.substr(0, 30)
                      << (win.is_focused ? " [FOCUSED]" : "") << "\n";
        }
        
        auto groups = ipc.get_app_groups();
        std::cout << "\n   📦 App groups: " << groups.size() << "\n";
        for (const auto& [name, group] : groups) {
            std::cout << "      - " << name << ": " << group.window_count() << " windows"
                      << (group.has_focus ? " [FOCUSED]" : "") << "\n";
        }
        
        // Test Pinned Manager
        std::cout << "\n═══ Pinned Manager ═══\n";
        PinnedManager pinned;
        auto apps = pinned.get_pinned_apps();
        std::cout << "   📌 Pinned: " << apps.size() << "\n";
        for (const auto& app : apps) {
            std::cout << "      - " << app.app_id << " (wm_class: " << app.wm_class << ")\n";
        }
        
        std::cout << "\n✅ Tests complete!\n";
        return 0;
    }
    
    if (cmd == "click" && argc >= 3) {
        int index = std::stoi(argv[2]);
        taskbar.handle_click(index);
        return 0;
    }
    
    if (cmd == "focus" && argc >= 3) {
        taskbar.focus_app(argv[2]);
        return 0;
    }
    
    if (cmd == "launch" && argc >= 3) {
        taskbar.launch_app(argv[2]);
        return 0;
    }
    
    if (cmd == "close" && argc >= 3) {
        taskbar.close_app(argv[2]);
        return 0;
    }
    
    if (cmd == "pin" && argc >= 3) {
        taskbar.toggle_pin(argv[2]);
        return 0;
    }
    
    if (cmd == "list") {
        std::cout << taskbar.get_items_json();
        return 0;
    }
    
    if (cmd == "debug") {
        // Debug: show raw hyprctl output
        FILE* pipe = popen("hyprctl clients -j", "r");
        if (pipe) {
            char buffer[4096];
            std::cout << "=== RAW HYPRCTL OUTPUT ===\n";
            while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
                std::cout << buffer;
            }
            pclose(pipe);
        }
        return 0;
    }
    
    // Unknown command - output JSON
    std::cout << taskbar.get_waybar_json() << std::endl;
    return 0;
}