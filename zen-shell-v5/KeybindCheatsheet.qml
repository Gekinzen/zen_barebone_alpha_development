import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * KeybindCheatsheet v6.11 — Keybind reference popup
 *
 * Triggered by Super+/ (or Super+F2)
 * Smart-detects keybinds from hyprland config files.
 * Groups by category with human-readable descriptions.
 * Reads live from disk — always shows current bindings.
 */
Rectangle {
    id: cheatsheet
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.6)
    visible: false

    signal closeRequested()

    MouseArea {
        anchors.fill: parent
        onClicked: cheatsheet.closeRequested()
    }

    // ── Smart keybind descriptions ──
    function describeAction(key, mods, dispatcher, args) {
        const k = key.toUpperCase()
        const m = mods.toUpperCase()

        // Exec commands — smart detect
        if (dispatcher === "exec") {
            const a = args.toLowerCase()
            if (a.indexOf("kitty") >= 0) return "Open Kitty terminal"
            if (a.indexOf("thunar") >= 0) return "Open Thunar file manager"
            if (a.indexOf("fuzzel") >= 0) return "App launcher (Fuzzel)"
            if (a.indexOf("termrun") >= 0) return "Toggle dropdown terminal"
            if (a.indexOf("btm-toggle") >= 0) return "Toggle system monitor (btm)"
            if (a.indexOf("wifi-toggle") >= 0) return "Toggle WiFi on/off"
            if (a.indexOf("blueman") >= 0) return "Toggle Bluetooth manager"
            if (a.indexOf("togglestartmenu") >= 0) return "Open/close Start Menu"
            if (a.indexOf("togglesettings") >= 0) return "Open/close Zen Settings"
            if (a.indexOf("togglewallpaperpicker") >= 0) return "Open wallpaper picker"
            if (a.indexOf("randomwallpaper") >= 0) return "Random wallpaper"
            if (a.indexOf("cycletheme") >= 0) return "Cycle to next theme"
            if (a.indexOf("togglestyle") >= 0) return "Toggle round/pill style"
            if (a.indexOf("reloadtheme tokyo") >= 0) return "Load Tokyo Night theme"
            if (a.indexOf("reloadtheme catppuccin") >= 0) return "Load Catppuccin Mocha theme"
            if (a.indexOf("reloadtheme dracula") >= 0) return "Load Dracula theme"
            if (a.indexOf("powerlock") >= 0) return "Lock screen (hyprlock)"
            if (a.indexOf("powerlogout") >= 0) return "Logout from Hyprland"
            if (a.indexOf("powerreboot") >= 0) return "Reboot system"
            if (a.indexOf("powershutdown") >= 0) return "Shutdown system"
            if (a.indexOf("screenshot") >= 0 && a.indexOf("region") >= 0) return "Screenshot: select region"
            if (a.indexOf("screenshot") >= 0 && a.indexOf("full") >= 0) return "Screenshot: full monitor"
            if (a.indexOf("screenshot") >= 0 && a.indexOf("clipboard") >= 0) return "Screenshot: monitor → clipboard"
            if (a.indexOf("screenshot") >= 0 && a.indexOf("allscreens") >= 0) return "Screenshot: all monitors"
            if (a.indexOf("screenshot") >= 0 && a.indexOf("flameshot") >= 0) return "Screenshot: Flameshot GUI"
            if (a.indexOf("wpctl") >= 0 && a.indexOf("5%+") >= 0) return "Volume up 5%"
            if (a.indexOf("wpctl") >= 0 && a.indexOf("5%-") >= 0) return "Volume down 5%"
            if (a.indexOf("wpctl") >= 0 && a.indexOf("toggle") >= 0) return "Mute/unmute audio"
            if (a.indexOf("brightnessctl") >= 0 && a.indexOf("+") >= 0) return "Brightness up 5%"
            if (a.indexOf("brightnessctl") >= 0 && a.indexOf("-") >= 0) return "Brightness down 5%"
            // v7.0.0-beta.1-hf18: zen-volume-notify.sh — superset of wpctl
            // that adds OSD + sound effect tick. Detect by action arg.
            if (a.indexOf("zen-volume-notify") >= 0 && a.indexOf("vol-up") >= 0)
                return "Volume up 5% (+ tick sound)"
            if (a.indexOf("zen-volume-notify") >= 0 && a.indexOf("vol-down") >= 0)
                return "Volume down 5% (+ tick sound)"
            if (a.indexOf("zen-volume-notify") >= 0 && a.indexOf("vol-mute") >= 0)
                return "Mute/unmute speaker"
            if (a.indexOf("zen-volume-notify") >= 0 && a.indexOf("mic-mute") >= 0)
                return "Mute/unmute microphone"
            if (a.indexOf("zen-volume-notify") >= 0 && a.indexOf("bright-up") >= 0)
                return "Brightness up 5%"
            if (a.indexOf("zen-volume-notify") >= 0 && a.indexOf("bright-down") >= 0)
                return "Brightness down 5%"
            if (a.indexOf("playerctl next") >= 0) return "Next track"
            if (a.indexOf("playerctl play") >= 0) return "Play/Pause"
            if (a.indexOf("playerctl prev") >= 0) return "Previous track"
            if (a.indexOf("control-center") >= 0) return "Legacy GTK control center"
            // v7.0.0-beta.1-hf18: recent IPC keybinds (Karui era)
            if (a.indexOf("zen togglesearch") >= 0) return "Open/close Spotlight search"
            if (a.indexOf("zen toggleclipboard") >= 0) return "Clipboard history (cliphist)"
            if (a.indexOf("zen toggleworkspaceoverview") >= 0)
                return "Workspace Overview (Exposé-style grid)"
            if (a.indexOf("zen togglenotifications") >= 0)
                return "Notifications panel"
            if (a.indexOf("zen togglecontrolcenter") >= 0)
                return "Quick Settings panel"
            if (a.indexOf("zen togglekeybindcheatsheet") >= 0)
                return "This keybind cheatsheet"
            if (a.indexOf("zen-panic.sh") >= 0)
                return "Panic recovery (escape from frozen lock/shell)"
            if (a.indexOf("zen-screenshot.sh") >= 0 && a.indexOf("region") >= 0)
                return "Screenshot: select region"
            if (a.indexOf("zen-screenshot.sh") >= 0 && a.indexOf("full") >= 0)
                return "Screenshot: full active monitor"
            if (a.indexOf("zen-screenshot.sh") >= 0 && a.indexOf("clipboard") >= 0)
                return "Screenshot: monitor → clipboard"
            if (a.indexOf("zen-screenshot.sh") >= 0 && a.indexOf("allscreens") >= 0)
                return "Screenshot: all monitors"
            if (a.indexOf("flameshot") >= 0) return "Screenshot: Flameshot GUI"
            return "Run: " + args.split("/").pop().split(" ")[0]
        }

        // Hyprland dispatchers
        if (dispatcher === "killactive") return "Close active window"
        if (dispatcher === "exit") return "Exit Hyprland"
        if (dispatcher === "pseudo") return "Toggle pseudo-tiling"
        if (dispatcher === "togglesplit") return "Toggle split direction"
        if (dispatcher === "movefocus") return "Move focus " + args
        if (dispatcher === "workspace") {
            if (args.match(/^[0-9]+$/)) return "Switch to workspace " + args
            if (args === "e+1") return "Next workspace (scroll)"
            if (args === "e-1") return "Previous workspace (scroll)"
            return "Workspace: " + args
        }
        if (dispatcher === "movetoworkspace") {
            if (args.match(/^[0-9]+$/)) return "Move window to workspace " + args
            if (args === "special:magic") return "Move window to scratchpad"
            return "Move to: " + args
        }
        if (dispatcher === "togglespecialworkspace") return "Toggle scratchpad"
        if (dispatcher === "fullscreen") {
            if (args === "1") return "Toggle maximize"
            if (args === "0") return "Toggle true fullscreen"
            return "Toggle fullscreen"
        }
        if (dispatcher === "togglefloating") return "Toggle floating window"
        if (dispatcher === "cyclenext") return args === "prev" ? "Alt+Tab: previous window" : "Alt+Tab: next window"
        if (dispatcher === "movewindow") return "Move window (mouse drag)"
        if (dispatcher === "resizewindow") return "Resize window (mouse drag)"

        return dispatcher + " " + args
    }

    // Categorize a bind
    function categorize(key, mods, dispatcher, args) {
        const a = (args || "").toLowerCase()
        if (dispatcher === "killactive" || dispatcher === "exit" || dispatcher === "pseudo" ||
            dispatcher === "togglesplit" || dispatcher === "movefocus" ||
            dispatcher === "fullscreen" || dispatcher === "togglefloating" ||
            dispatcher === "cyclenext" || dispatcher === "movewindow" || dispatcher === "resizewindow")
            return "Window Management"
        if (dispatcher === "workspace" || dispatcher === "movetoworkspace" || dispatcher === "togglespecialworkspace")
            return "Workspaces"
        if (a.indexOf("screenshot") >= 0) return "Screenshots"
        if (a.indexOf("kitty") >= 0 || a.indexOf("thunar") >= 0 || a.indexOf("fuzzel") >= 0 ||
            a.indexOf("termrun") >= 0 || a.indexOf("btm-toggle") >= 0 || a.indexOf("wifi-toggle") >= 0)
            return "Apps & Utilities"
        if (a.indexOf("togglestartmenu") >= 0 || a.indexOf("togglesettings") >= 0 ||
            a.indexOf("togglewallpaperpicker") >= 0 || a.indexOf("randomwallpaper") >= 0 ||
            a.indexOf("cycletheme") >= 0 || a.indexOf("togglestyle") >= 0 || a.indexOf("reloadtheme") >= 0 ||
            // v7.0.0-beta.1-hf18: all "zen ipc call zen <action>" overlays belong here
            a.indexOf("zen togglesearch") >= 0 || a.indexOf("zen toggleclipboard") >= 0 ||
            a.indexOf("zen toggleworkspaceoverview") >= 0 || a.indexOf("zen togglenotifications") >= 0 ||
            a.indexOf("zen togglecontrolcenter") >= 0 || a.indexOf("zen togglekeybindcheatsheet") >= 0)
            return "Zen Shell"
        if (a.indexOf("power") >= 0) return "Power"
        if (a.indexOf("zen-panic") >= 0) return "Power"   // recovery is power-adjacent
        if (a.indexOf("wpctl") >= 0 || a.indexOf("brightnessctl") >= 0 || a.indexOf("playerctl") >= 0 ||
            a.indexOf("zen-volume-notify") >= 0 ||   // hf18: route OSD script here
            key.indexOf("XF86") >= 0) return "Media & Hardware"
        if (dispatcher === "exec") return "Apps & Utilities"
        return "Other"
    }

    // Format key combo for display
    function formatCombo(mods, key) {
        let parts = []
        const m = mods.replace(/\$mainMod/g, "").trim()
        parts.push("Super")
        if (m.indexOf("SHIFT") >= 0) parts.push("Shift")
        if (m.indexOf("CTRL") >= 0) parts.push("Ctrl")
        if (m.indexOf("ALT") >= 0 && m.indexOf("$mainMod") < 0) parts.push("Alt")

        // Clean up key name
        let k = key.trim()
        if (k === "comma") k = ","
        else if (k === "grave") k = "`"
        else if (k === "RETURN") k = "Enter"
        else if (k === "mouse_down") k = "Scroll ↓"
        else if (k === "mouse_up") k = "Scroll ↑"
        else if (k === "mouse:272") k = "Left Click"
        else if (k === "mouse:273") k = "Right Click"
        else if (k.startsWith("XF86Audio")) k = k.replace("XF86Audio", "🔊 ")
        else if (k.startsWith("XF86Mon")) k = k.replace("XF86Mon", "🔆 ")
        else k = k.toUpperCase()

        // If no $mainMod in original mods, remove Super
        if (mods.indexOf("$mainMod") < 0 && mods.indexOf("SUPER") < 0) {
            parts.shift()
            if (mods.indexOf("ALT") >= 0) parts.unshift("Alt")
        }

        parts.push(k)
        return parts.join(" + ")
    }

    // Parse keybind config text into structured array
    property var parsedBinds: []

    function parseKeybinds(text) {
        const lines = text.split("\n")
        const results = []
        const seen = {}

        for (const line of lines) {
            const trimmed = line.trim()
            if (!trimmed || trimmed.startsWith("#") || trimmed.startsWith("$")) continue

            const match = trimmed.match(/^bind[eml]*\s*=\s*(.+)/)
            if (!match) continue

            const parts = match[1].split(",").map(s => s.trim())
            if (parts.length < 3) continue

            const mods = parts[0]
            const key = parts[1]
            const dispatcher = parts[2]
            const args = parts.slice(3).join(",").trim()

            // Dedupe
            const dedupKey = mods + "|" + key + "|" + dispatcher
            if (seen[dedupKey]) continue
            seen[dedupKey] = true

            const combo = formatCombo(mods, key)
            const desc = describeAction(key, mods, dispatcher, args)
            const cat = categorize(key, mods, dispatcher, args)

            results.push({ combo: combo, description: desc, category: cat })
        }

        return results
    }

    // Load keybind files
    Process {
        id: bindLoader
        running: false
        command: ["bash", "-c",
            "cat ~/.config/hypr/modules/binds.conf 2>/dev/null; " +
            "echo ''; " +
            "cat ~/.config/quickshell/zen-shell/config/keybinds-update.conf 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                cheatsheet.parsedBinds = cheatsheet.parseKeybinds(this.text)
            }
        }
    }

    function show() {
        bindLoader.running = true
        visible = true
    }
    function hide() {
        visible = false
    }

    // Category order
    readonly property var categoryOrder: [
        "Window Management", "Workspaces", "Apps & Utilities",
        "Zen Shell", "Screenshots", "Power", "Media & Hardware", "Other"
    ]

    // Grouped binds
    function bindsForCategory(cat) {
        const result = []
        for (let i = 0; i < parsedBinds.length; i++) {
            if (parsedBinds[i].category === cat) result.push(parsedBinds[i])
        }
        return result
    }

    // ── UI ──
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(900, parent.width - 80)
        height: Math.min(700, parent.height - 80)
        radius: 16
        color: Qt.rgba(0.08, 0.08, 0.09, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "⌨"
                    font.pixelSize: 28
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Keyboard Shortcuts"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        text: "Zen Shell — " + cheatsheet.parsedBinds.length + " keybinds detected"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Press Esc or click outside to close"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.3)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // Scrollable content — 2 column grid of categories
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    contentWidth: parent.width
                    contentHeight: catFlow.implicitHeight

                    Flow {
                        id: catFlow
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: cheatsheet.categoryOrder
                            delegate: ColumnLayout {
                                required property string modelData
                                width: (catFlow.width - 16) / 2
                                spacing: 6

                                property var binds: cheatsheet.bindsForCategory(modelData)
                                visible: binds.length > 0

                                // Category header
                                RowLayout {
                                    spacing: 6
                                    Rectangle {
                                        width: 3
                                        height: 14
                                        radius: 2
                                        color: {
                                            if (modelData === "Window Management") return "#ff453a"
                                            if (modelData === "Workspaces") return "#5e5ce6"
                                            if (modelData === "Apps & Utilities") return "#30d158"
                                            if (modelData === "Zen Shell") return "#64d2ff"
                                            if (modelData === "Screenshots") return "#ffd60a"
                                            if (modelData === "Power") return "#ff9f0a"
                                            if (modelData === "Media & Hardware") return "#bf5af2"
                                            return "#8e8e93"
                                        }
                                    }
                                    Text {
                                        text: modelData
                                        font.family: "Adwaita Sans"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        color: Qt.rgba(1, 1, 1, 0.9)
                                    }
                                    Text {
                                        text: "(" + binds.length + ")"
                                        font.family: "Adwaita Sans"
                                        font.pixelSize: 10
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                    }
                                }

                                // Bind rows
                                Repeater {
                                    model: binds
                                    delegate: RowLayout {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 160
                                            Layout.preferredHeight: 24
                                            radius: 4
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.08)

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.combo
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                color: Qt.rgba(1, 1, 1, 0.85)
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.description
                                            font.family: "Adwaita Sans"
                                            font.pixelSize: 11
                                            color: Qt.rgba(1, 1, 1, 0.6)
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Spacer after category
                                Item { width: 1; height: 8 }
                            }
                        }
                    }
                }
            }
        }
    }

    // Escape to close
    Keys.onEscapePressed: cheatsheet.closeRequested()
}
