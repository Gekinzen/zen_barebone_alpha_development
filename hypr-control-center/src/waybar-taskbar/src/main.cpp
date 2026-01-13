/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Waybar Taskbar - Main Entry Point
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * Usage:
 *   waybar-taskbar daemon          Run as daemon (updates icons continuously)
 *   waybar-taskbar generate-config Generate Waybar config snippet
 *   waybar-taskbar click <type> <n>  Handle click (called by Waybar)
 *   waybar-taskbar --test          Test mode
 */

#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <fstream>
#include <cstdlib>
#include <unistd.h>

#include "taskbar.hpp"
#include "hypr_ipc.hpp"
#include "pinned_manager.hpp"
#include "icon_resolver.hpp"

void print_usage() {
    std::cout << R"(
╔══════════════════════════════════════════════════════════════════════════════╗
║                    WAYBAR TASKBAR - Real PNG Icons                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
  waybar-taskbar daemon              Run as daemon (required for icons)
  waybar-taskbar generate-config     Generate Waybar config snippet  
  waybar-taskbar generate-script     Generate click handler script
  waybar-taskbar click <type> <idx>  Handle left click
  waybar-taskbar middle <type> <idx> Handle middle click (close)
  waybar-taskbar right <type> <idx>  Handle right click (pin/unpin)
  waybar-taskbar status              Show current status
  waybar-taskbar --test              Run tests
  waybar-taskbar --help              Show this help

SETUP:
  1. Run: waybar-taskbar generate-config >> ~/.config/waybar/config.jsonc
  2. Run: waybar-taskbar generate-script
  3. Add 'group/taskbar' to your modules-left/center/right
  4. Start daemon: waybar-taskbar daemon &
  5. Restart Waybar

)";
}

void run_tests() {
    std::cout << "🧪 Running tests...\n\n";
    
    // Test Icon Resolver
    std::cout << "═══ Icon Resolver ═══\n";
    IconResolver resolver;
    std::cout << "   Theme: " << resolver.get_current_theme() << "\n";
    
    std::vector<std::string> test_apps = {"firefox", "kitty", "code", "nautilus", "spotify", "discord"};
    for (const auto& app : test_apps) {
        std::string icon_path = resolver.get_icon_path(app, 24);
        std::string nerd_icon = resolver.get_nerd_icon(app);
        
        if (!icon_path.empty()) {
            std::cout << "   ✅ " << app << ": " << icon_path << "\n";
        } else {
            std::cout << "   ⚠️ " << app << ": No icon, nerd: " << nerd_icon << "\n";
        }
    }
    
    // Test Hyprland IPC
    std::cout << "\n═══ Hyprland IPC ═══\n";
    HyprlandIPC ipc;
    
    if (ipc.is_connected()) {
        std::cout << "   ✅ Connected to Hyprland\n";
        
        auto windows = ipc.get_windows();
        std::cout << "   📋 Windows: " << windows.size() << "\n";
        
        for (const auto& win : windows) {
            std::cout << "      - " << win.wm_class << ": " 
                      << win.title.substr(0, 40) 
                      << (win.is_focused ? " [FOCUSED]" : "") << "\n";
        }
    } else {
        std::cout << "   ❌ Not connected to Hyprland\n";
    }
    
    // Test Pinned Manager
    std::cout << "\n═══ Pinned Manager ═══\n";
    PinnedManager pinned;
    
    auto apps = pinned.get_pinned_apps();
    std::cout << "   📌 Pinned apps: " << apps.size() << "\n";
    for (const auto& app : apps) {
        std::cout << "      - " << app.app_id;
        if (!app.wm_class.empty() && app.wm_class != app.app_id) {
            std::cout << " (" << app.wm_class << ")";
        }
        std::cout << "\n";
    }
    
    // Test Taskbar
    std::cout << "\n═══ Taskbar ═══\n";
    Taskbar taskbar;
    if (taskbar.init()) {
        taskbar.update();
        
        auto pinned_items = taskbar.get_pinned_items();
        auto running_items = taskbar.get_running_items();
        
        std::cout << "   📌 Pinned slots: " << pinned_items.size() << "\n";
        for (const auto& item : pinned_items) {
            std::cout << "      [" << item.slot_index << "] " << item.app_id;
            std::cout << (item.is_running ? " ▶" : "");
            std::cout << (item.is_focused ? " ●" : "");
            std::cout << " → " << (item.icon_path.empty() ? "no icon" : item.icon_path) << "\n";
        }
        
        std::cout << "   🏃 Running slots: " << running_items.size() << "\n";
        for (const auto& item : running_items) {
            std::cout << "      [" << item.slot_index << "] " << item.wm_class;
            std::cout << (item.is_focused ? " ●" : "");
            std::cout << " → " << (item.icon_path.empty() ? "no icon" : item.icon_path) << "\n";
        }
        
        std::cout << "   📁 Temp dir: " << taskbar.get_temp_dir() << "\n";
        
        // Don't cleanup in test mode so user can inspect
        std::cout << "\n   ℹ️ Temp files preserved for inspection.\n";
        std::cout << "   Run 'rm -rf " << taskbar.get_temp_dir() << "' to clean.\n";
    }
    
    std::cout << "\n✅ Tests complete!\n";
}

void run_daemon() {
    std::cout << "[Daemon] Starting waybar-taskbar daemon...\n";
    
    Taskbar taskbar;
    if (!taskbar.init()) {
        std::cerr << "[Daemon] Failed to initialize taskbar\n";
        return;
    }
    
    // Generate click script
    std::string script_path = taskbar.get_temp_dir() + "/click.sh";
    std::ofstream script(script_path);
    if (script.is_open()) {
        script << "#!/bin/bash\n";
        script << "# Auto-generated click handler\n\n";
        script << "TASKBAR_BIN=\"$(which waybar-taskbar 2>/dev/null)\"\n";
        script << "if [[ -z \"$TASKBAR_BIN\" ]]; then\n";
        script << "    TASKBAR_BIN=\"$HOME/.config/hypr-control-center/src/waybar-taskbar/waybar-taskbar\"\n";
        script << "fi\n\n";
        script << "case \"$1\" in\n";
        script << "    middle)\n";
        script << "        \"$TASKBAR_BIN\" middle \"$2\" \"$3\"\n";
        script << "        ;;\n";
        script << "    right)\n";
        script << "        \"$TASKBAR_BIN\" right \"$2\" \"$3\"\n";
        script << "        ;;\n";
        script << "    *)\n";
        script << "        \"$TASKBAR_BIN\" click \"$1\" \"$2\"\n";
        script << "        ;;\n";
        script << "esac\n";
        script.close();
        system(("chmod +x \"" + script_path + "\"").c_str());
    }
    
    std::cout << "[Daemon] ✅ Ready! Icons at: " << taskbar.get_temp_dir() << "/icons/\n";
    std::cout << "[Daemon] Press Ctrl+C to stop.\n\n";
    
    // Main loop
    while (true) {
        bool changed = taskbar.update();
        if (changed) {
            std::cout << "[Daemon] 🔄 State updated\n";
        }
        
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
}

void generate_config() {
    Taskbar taskbar;
    if (!taskbar.init()) {
        std::cerr << "Failed to initialize taskbar\n";
        return;
    }
    
    taskbar.update();
    std::cout << taskbar.generate_waybar_config();
}

void generate_script() {
    std::string home = getenv("HOME");
    std::string script_dir = home + "/.config/waybar/scripts";
    std::string script_path = script_dir + "/taskbar-click.sh";
    
    // Create directory
    system(("mkdir -p \"" + script_dir + "\"").c_str());
    
    std::ofstream script(script_path);
    if (!script.is_open()) {
        std::cerr << "Failed to create script at " << script_path << "\n";
        return;
    }
    
    script << "#!/bin/bash\n";
    script << "# Waybar Taskbar Click Handler\n";
    script << "# Generated by waybar-taskbar\n\n";
    script << "RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/tmp}\"\n";
    script << "STATE_FILE=\"$RUNTIME_DIR/waybar-taskbar/state.json\"\n\n";
    script << "if [[ ! -f \"$STATE_FILE\" ]]; then\n";
    script << "    echo \"Taskbar daemon not running!\"\n";
    script << "    exit 1\n";
    script << "fi\n\n";
    script << "ACTION=\"$1\"\n";
    script << "SLOT_TYPE=\"$2\"\n";
    script << "SLOT_IDX=\"$3\"\n\n";
    script << "# Find the waybar-taskbar binary\n";
    script << "TASKBAR_BIN=\"$(which waybar-taskbar 2>/dev/null)\"\n";
    script << "if [[ -z \"$TASKBAR_BIN\" ]]; then\n";
    script << "    TASKBAR_BIN=\"$HOME/.config/waybar/scripts/waybar-taskbar\"\n";
    script << "fi\n";
    script << "if [[ -z \"$TASKBAR_BIN\" ]] || [[ ! -x \"$TASKBAR_BIN\" ]]; then\n";
    script << "    TASKBAR_BIN=\"$HOME/.config/hypr-control-center/src/waybar-taskbar/waybar-taskbar\"\n";
    script << "fi\n\n";
    script << "case \"$ACTION\" in\n";
    script << "    click|left)\n";
    script << "        \"$TASKBAR_BIN\" click \"$SLOT_TYPE\" \"$SLOT_IDX\"\n";
    script << "        ;;\n";
    script << "    middle)\n";
    script << "        \"$TASKBAR_BIN\" middle \"$SLOT_TYPE\" \"$SLOT_IDX\"\n";
    script << "        ;;\n";
    script << "    right)\n";
    script << "        \"$TASKBAR_BIN\" right \"$SLOT_TYPE\" \"$SLOT_IDX\"\n";
    script << "        ;;\n";
    script << "    *)\n";
    script << "        echo \"Usage: $0 {click|middle|right} {pin|run} <index>\"\n";
    script << "        exit 1\n";
    script << "        ;;\n";
    script << "esac\n";
    
    script.close();
    system(("chmod +x \"" + script_path + "\"").c_str());
    
    std::cout << "✅ Script created: " << script_path << "\n";
}

void show_status() {
    const char* xdg_runtime = getenv("XDG_RUNTIME_DIR");
    std::string state_path;
    if (xdg_runtime) {
        state_path = std::string(xdg_runtime) + "/waybar-taskbar/state.json";
    } else {
        state_path = "/tmp/waybar-taskbar-" + std::to_string(getuid()) + "/state.json";
    }
    
    std::ifstream file(state_path);
    if (!file.is_open()) {
        std::cout << "❌ Daemon not running (no state file)\n";
        return;
    }
    
    std::cout << "✅ Daemon running\n";
    std::cout << "📁 State: " << state_path << "\n\n";
    
    std::string line;
    while (std::getline(file, line)) {
        std::cout << line << "\n";
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        print_usage();
        return 0;
    }
    
    std::string cmd = argv[1];
    
    if (cmd == "--help" || cmd == "-h") {
        print_usage();
        return 0;
    }
    
    if (cmd == "--test" || cmd == "test") {
        run_tests();
        return 0;
    }
    
    if (cmd == "daemon" || cmd == "start" || cmd == "-d") {
        run_daemon();
        return 0;
    }
    
    if (cmd == "generate-config" || cmd == "config") {
        generate_config();
        return 0;
    }
    
    if (cmd == "generate-script" || cmd == "script") {
        generate_script();
        return 0;
    }
    
    if (cmd == "status") {
        show_status();
        return 0;
    }
    
    if (cmd == "click" && argc >= 4) {
        std::string slot_type = argv[2];
        int slot_idx = std::stoi(argv[3]);
        
        Taskbar taskbar;
        taskbar.set_skip_cleanup(true);  // Don't cleanup - daemon owns the icons
        taskbar.init();
        taskbar.update();
        taskbar.handle_click(slot_type, slot_idx);
        return 0;
    }
    
    if (cmd == "middle" && argc >= 4) {
        std::string slot_type = argv[2];
        int slot_idx = std::stoi(argv[3]);
        
        Taskbar taskbar;
        taskbar.set_skip_cleanup(true);  // Don't cleanup - daemon owns the icons
        taskbar.init();
        taskbar.update();
        taskbar.handle_middle_click(slot_type, slot_idx);
        return 0;
    }
    
    if (cmd == "right" && argc >= 4) {
        std::string slot_type = argv[2];
        int slot_idx = std::stoi(argv[3]);
        
        Taskbar taskbar;
        taskbar.set_skip_cleanup(true);  // Don't cleanup - daemon owns the icons
        taskbar.init();
        taskbar.update();
        taskbar.handle_right_click(slot_type, slot_idx);
        return 0;
    }
    
    std::cerr << "Unknown command: " << cmd << "\n";
    print_usage();
    return 1;
}