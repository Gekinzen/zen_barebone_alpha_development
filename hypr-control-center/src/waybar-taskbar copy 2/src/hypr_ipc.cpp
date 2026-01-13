/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Hyprland IPC - Implementation
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#include "hypr_ipc.hpp"

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <algorithm>

// Simple JSON parsing (we'll use basic string parsing to avoid dependency)
// In production, use nlohmann/json

HyprlandIPC::HyprlandIPC() : m_connected(false) {
    m_socket_path = get_socket_path();
    m_connected = !m_socket_path.empty();
}

HyprlandIPC::~HyprlandIPC() {}

std::string HyprlandIPC::get_socket_path() {
    const char* his = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!his) {
        return "";
    }
    
    const char* xdg_runtime = getenv("XDG_RUNTIME_DIR");
    std::string runtime_dir = xdg_runtime ? xdg_runtime : "/tmp";
    
    return runtime_dir + "/hypr/" + his + "/.socket.sock";
}

bool HyprlandIPC::is_connected() const {
    return m_connected;
}

std::string HyprlandIPC::send_command(const std::string& cmd) {
    // Use hyprctl for reliability instead of raw socket
    std::string hyprctl_cmd = "hyprctl " + cmd + " -j 2>/dev/null";
    
    FILE* pipe = popen(hyprctl_cmd.c_str(), "r");
    if (!pipe) return "";
    
    std::string response;
    char buffer[4096];
    
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        response += buffer;
    }
    
    pclose(pipe);
    return response;
}

// Simple JSON value extractor
static std::string extract_json_string(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\":";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    
    pos += search.length();
    
    // Skip whitespace
    while (pos < json.length() && (json[pos] == ' ' || json[pos] == '\t')) pos++;
    
    if (pos >= json.length()) return "";
    
    if (json[pos] == '"') {
        // String value
        pos++;
        size_t end = json.find('"', pos);
        if (end == std::string::npos) return "";
        return json.substr(pos, end - pos);
    } else if (json[pos] == 't' || json[pos] == 'f') {
        // Boolean
        return json.substr(pos, 4) == "true" ? "true" : "false";
    } else {
        // Number
        size_t end = pos;
        while (end < json.length() && (isdigit(json[end]) || json[end] == '-' || json[end] == '.')) end++;
        return json.substr(pos, end - pos);
    }
}

static int extract_json_int(const std::string& json, const std::string& key) {
    std::string val = extract_json_string(json, key);
    if (val.empty()) return 0;
    try {
        return std::stoi(val);
    } catch (...) {
        return 0;
    }
}

static bool extract_json_bool(const std::string& json, const std::string& key) {
    return extract_json_string(json, key) == "true";
}

std::vector<HyprWindow> HyprlandIPC::get_windows() {
    std::vector<HyprWindow> windows;
    
    std::string response = send_command("clients");
    if (response.empty()) return windows;
    
    // Parse JSON array - find each window object properly
    // Handle nested objects by counting braces
    size_t pos = 0;
    while ((pos = response.find('{', pos)) != std::string::npos) {
        // Find matching closing brace (handle nested)
        int depth = 1;
        size_t end = pos + 1;
        while (end < response.length() && depth > 0) {
            if (response[end] == '{') depth++;
            else if (response[end] == '}') depth--;
            end++;
        }
        
        if (depth != 0) break;
        
        std::string obj = response.substr(pos, end - pos);
        
        HyprWindow win;
        win.address = extract_json_string(obj, "address");
        win.wm_class = extract_json_string(obj, "class");
        win.title = extract_json_string(obj, "title");
        
        // Extract workspace ID
        std::string ws_id_str = extract_json_string(obj, "id");
        // Find the workspace id more carefully
        size_t ws_pos = obj.find("\"workspace\"");
        if (ws_pos != std::string::npos) {
            size_t id_pos = obj.find("\"id\":", ws_pos);
            if (id_pos != std::string::npos && id_pos < ws_pos + 100) {
                win.workspace = extract_json_int(obj.substr(ws_pos, 100), "id");
            }
        }
        
        // Check focus
        int focus_id = extract_json_int(obj, "focusHistoryID");
        win.is_focused = (focus_id == 0);
        
        // Skip empty wm_class
        if (!win.wm_class.empty()) {
            windows.push_back(win);
        }
        
        pos = end;
    }
    
    // Get focused window
    std::string active = send_command("activewindow");
    if (!active.empty()) {
        std::string focused_addr = extract_json_string(active, "address");
        for (auto& win : windows) {
            win.is_focused = (win.address == focused_addr);
        }
    }
    
    return windows;
}

std::map<std::string, AppGroup> HyprlandIPC::get_app_groups() {
    std::map<std::string, AppGroup> groups;
    
    auto windows = get_windows();
    
    for (const auto& win : windows) {
        std::string key = win.wm_class;
        std::transform(key.begin(), key.end(), key.begin(), ::tolower);
        
        if (groups.find(key) == groups.end()) {
            groups[key] = AppGroup{win.wm_class, {}, false};
        }
        
        groups[key].windows.push_back(win);
        if (win.is_focused) {
            groups[key].has_focus = true;
        }
    }
    
    return groups;
}

void HyprlandIPC::focus_window(const std::string& address) {
    send_command("dispatch focuswindow address:" + address);
}

void HyprlandIPC::close_window(const std::string& address) {
    send_command("dispatch closewindow address:" + address);
}

void HyprlandIPC::close_app(const std::string& wm_class) {
    auto windows = get_windows();
    for (const auto& win : windows) {
        if (win.wm_class == wm_class) {
            close_window(win.address);
        }
    }
}

int HyprlandIPC::get_active_workspace() {
    std::string response = send_command("j/activeworkspace");
    return extract_json_int(response, "id");
}