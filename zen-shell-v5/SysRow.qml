import QtQuick
import QtQuick.Layouts
import Quickshell.Io

/*
 * SysRow v6.16.0 — Waybar-style expandable system tray
 *
 * v6.16.0: + Battery icon. Double-gated: shows only when
 *   SystemMonitorService.batteryPresent === true AND
 *   SysRowState.showBattery === true. On desktops, batteryPresent
 *   is false so the toggle has no visible effect (graceful).
 *   Click opens Control Panel (has the Power Profile section).
 *
 * Exact waybar icon mapping:
 *   CPU:    \uf2db (U+F2DB) → "format": " {icon}"
 *   RAM:    \uefc5 (U+F538) → "format": " {icon}"
 *   Temp:   \uf2c9 (U+F2C9) → "format": " {icon}"
 *   Sound:  \uf028 (U+F028) → "format": " {icon}"
 *   Network: 󰤯󰤟󰤢󰤥󰤨 (5-tier signal) / 󰈀 (ethernet) / 󰤮 (disconnected)
 *   BT:     \uf293 (U+F293) →  /  disabled /  connected
 *   Battery (v6.16.0): \uf240..\uf244 (5 levels) + \uf0e7 bolt charging
 *
 * Bar-graph glyphs: ▁▂▃▄▅▆▇█ (same as waybar format-icons)
 *
 * State-driven via SysRowState singleton:
 *   - Per-module visibility toggles
 *   - Display mode: "icon" (icon + bargraph) or "text" (icon + value text)
 *   - Custom per-module colors (empty = theme-reactive auto)
 *   - Collapse delay configurable
 *   - Theme changes → colors update live
 *
 * Click actions (toggle pattern from Zen Alpha scripts):
 *   Sound   → pavucontrol (toggle kill/launch)
 *   CPU/RAM → alacritty -e btm (toggle)
 *   Temp    → alacritty -e btm (toggle)
 *   Network → alacritty -e nmtui (toggle)
 *   BT      → blueman-manager (toggle)
 */
Item {
    id: sysRoot

    implicitWidth: expanded ? mainRow.implicitWidth + 8 : arrowBtn.width + 4
    implicitHeight: parent ? parent.height : 40

    property bool expanded: false
    property bool hovered: false

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // ── Bar-graph glyphs (waybar format-icons) ──
    readonly property var barGlyphs: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    function barGlyph(pct) {
        const clamped = Math.min(100, Math.max(0, pct))
        const idx = Math.min(7, Math.floor(clamped / 12.5))
        return barGlyphs[idx]
    }

    // ── WiFi signal icons (waybar network format-icons.wifi) ──
    function wifiGlyph(signal) {
        if (signal >= 80) return "󰤨"
        if (signal >= 60) return "󰤥"
        if (signal >= 40) return "󰤢"
        if (signal >= 20) return "󰤟"
        return "󰤯"
    }

    // ── Format helpers for icon vs text mode ──
    function fmtModule(icon, glyph, textVal) {
        if (SysRowState.displayMode === "text") return icon + " " + textVal
        return icon + " " + glyph
    }

    // ── Auto-collapse timer ──
    Timer {
        id: collapseTimer
        interval: SysRowState.collapseDelay
        onTriggered: {
            if (!sysRoot.hovered) sysRoot.expanded = false
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
            sysRoot.hovered = containsMouse
            if (!containsMouse) collapseTimer.restart()
            else collapseTimer.stop()
        }
    }

    RowLayout {
        id: mainRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 2

        // ═══════════════════════════════════════════════
        // EXPAND ARROW — ❮ collapsed / ❯ expanded
        // ═══════════════════════════════════════════════
        Rectangle {
            id: arrowBtn
            Layout.preferredWidth: 24
            Layout.preferredHeight: 28
            radius: 6
            color: arrowMouse.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.1) : "transparent"

            Text {
                anchors.centerIn: parent
                text: sysRoot.expanded ? SysRowState.arrowExpanded : SysRowState.arrowCollapsed
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: ThemeService.grey0
            }

            MouseArea {
                id: arrowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sysRoot.expanded = !sysRoot.expanded
                    if (sysRoot.expanded) collapseTimer.stop()
                }
            }
        }

        // ═══════════════════════════════════════════════
        // SOUND —  (U+F028) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showSound
            opacity: sysRoot.expanded ? 1 : 0
            icon: ConnectivityService.audioMuted
                  ? "\uf026"
                  : sysRoot.fmtModule(
                        "\uf028",
                        sysRoot.barGlyph(Math.min(100, ConnectivityService.audioVolume)),
                        ConnectivityService.audioVolume + "%"
                    )
            tipTitle: "Audio"
            tipDetail: (ConnectivityService.audioMuted ? "Muted" : ("Volume: " + ConnectivityService.audioVolume + "%"))
                       + "\nDevice: " + ConnectivityService.audioSinkName
            iconColor: SysRowState.resolveColor(
                SysRowState.soundColor,
                ConnectivityService.audioMuted ? ThemeService.grey2 : ThemeService.aqua
            )
            onClicked: {
                audioProc.command = ["bash", "-c",
                    "if pgrep -f pavucontrol >/dev/null; then pkill -f pavucontrol; else pavucontrol & fi"]
                audioProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // CPU —  (U+F2DB) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showCpu
            opacity: sysRoot.expanded ? 1 : 0
            icon: sysRoot.fmtModule(
                "\uf2db",
                sysRoot.barGlyph(SystemMonitorService.cpuPercent),
                SystemMonitorService.cpuPercent + "%"
            )
            tipTitle: SystemMonitorService.cpuName
            tipDetail: "CPU Status:\n" + SystemMonitorService.cpuPercent + "% Used"
                       + (SystemMonitorService.cpuTemp > 0
                          ? "\nTemp: " + SystemMonitorService.cpuTemp + "°C" : "")
            iconColor: SysRowState.resolveColor(
                SysRowState.cpuColor,
                ThemeService.blue
            )
            onClicked: {
                btmProc.command = ["bash", "-c",
                    "if pgrep -x btm >/dev/null; then pkill -x btm; pkill -f 'alacritty.*btm'; " +
                    "else alacritty --title btmWindow -e btm & fi"]
                btmProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // RAM —  (U+F538) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showRam
            opacity: sysRoot.expanded ? 1 : 0
            icon: sysRoot.fmtModule(
                "\uefc5",
                sysRoot.barGlyph(SystemMonitorService.ramPercent),
                SystemMonitorService.ramUsedGb.toFixed(1) + "G"
            )
            tipTitle: "Memory"
            tipDetail: "Memory:\n" + SystemMonitorService.ramUsedGb.toFixed(1) + "G / " +
                       SystemMonitorService.ramTotalGb.toFixed(0) + "G\n" +
                       SystemMonitorService.ramPercent + "% Used"
            iconColor: SysRowState.resolveColor(
                SysRowState.ramColor,
                ThemeService.green
            )
            onClicked: {
                btmProc.command = ["bash", "-c",
                    "if pgrep -x btm >/dev/null; then pkill -x btm; pkill -f 'alacritty.*btm'; " +
                    "else alacritty --title btmWindow -e btm & fi"]
                btmProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // TEMPERATURE —  (U+F2C9) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showTemp && SystemMonitorService.cpuTemp > 0
            opacity: sysRoot.expanded ? 1 : 0
            icon: sysRoot.fmtModule(
                "\uf2c9",
                sysRoot.barGlyph(Math.min(100, SystemMonitorService.cpuTemp)),
                SystemMonitorService.cpuTemp + "°"
            )
            tipTitle: "Temperature"
            tipDetail: "Temperature: " + SystemMonitorService.cpuTemp + "°C"
                       + (SystemMonitorService.gpuTemp > 0
                          ? "\nGPU: " + SystemMonitorService.gpuTemp + "°C" : "")
            iconColor: SysRowState.resolveColor(
                SysRowState.tempColor,
                ThemeService.orange
            )
            onClicked: {
                btmProc.command = ["bash", "-c",
                    "if pgrep -x btm >/dev/null; then pkill -x btm; pkill -f 'alacritty.*btm'; " +
                    "else alacritty --title btmWindow -e btm & fi"]
                btmProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // NETWORK — 󰤯󰤟󰤢󰤥󰤨 (WiFi) / 󰈀 (Ethernet) / 󰤮 (disconnected)
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showNetwork
            opacity: sysRoot.expanded ? 1 : 0
            icon: {
                if (ConnectivityService.wifiConnected)
                    return " " + sysRoot.wifiGlyph(ConnectivityService.wifiSignal) + " "
                if (ConnectivityService.lanConnected)
                    return " 󰈀 "
                return "󰤮"
            }
            tipTitle: ConnectivityService.wifiConnected
                      ? "WiFi Connected" : (ConnectivityService.lanConnected ? "Ethernet Connected" : "Network Disconnected")
            tipDetail: {
                if (ConnectivityService.wifiConnected)
                    return ConnectivityService.wifiSSID +
                           "\nSignal: " + ConnectivityService.wifiSignal + "%" +
                           "\n↓ " + SystemMonitorService.netDown + "  ↑ " + SystemMonitorService.netUp
                if (ConnectivityService.lanConnected)
                    return ConnectivityService.lanInterface +
                           "\nIP: " + ConnectivityService.lanIP +
                           "\n↓ " + SystemMonitorService.netDown + "  ↑ " + SystemMonitorService.netUp
                return "Click to select WiFi"
            }
            iconColor: SysRowState.resolveColor(
                SysRowState.networkColor,
                (ConnectivityService.wifiConnected || ConnectivityService.lanConnected)
                    ? ThemeService.purple : ThemeService.grey2
            )
            onClicked: {
                // Open Control Panel (same as Super+C)
                wifiProc.command = ["bash", "-c",
                    "qs -c zen-shell ipc call zen toggleControlCenter"]
                wifiProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // BLUETOOTH —  (U+F293) /  disabled /  N connected
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showBluetooth
            opacity: sysRoot.expanded ? 1 : 0
            icon: {
                if (ConnectivityService.btConnected)
                    return "\uf293 " + ConnectivityService.btDevices.length
                if (ConnectivityService.btPowered)
                    return "\uf293 "
                return "\uf293 "
            }
            tipTitle: "Bluetooth: " + (ConnectivityService.btPowered
                      ? (ConnectivityService.btConnected
                         ? "Connected" : "On") : "Off")
            tipDetail: ConnectivityService.btConnected
                       ? ("Bluetooth Connected:\n" + ConnectivityService.btConnectedName +
                          "\n" + ConnectivityService.btDevices.length + " device(s)")
                       : (ConnectivityService.btPowered
                          ? "No devices connected" : "Bluetooth is off")
            iconColor: SysRowState.resolveColor(
                SysRowState.btColor,
                ConnectivityService.btConnected ? ThemeService.yellow
                    : (ConnectivityService.btPowered ? ThemeService.grey0 : ThemeService.grey2)
            )
            onClicked: {
                btProc.command = ["bash", "-c",
                    "if pgrep -x blueman-manager >/dev/null; then pkill -x blueman-manager; " +
                    "else blueman-manager & fi"]
                btProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // BATTERY (v6.16.0) —  (U+F240-F244) based on capacity
        // Only visible on laptops AND when SysRowState.showBattery is on.
        // Double-gated: batteryPresent (hardware) + showBattery (user pref).
        // Click → opens Control Panel (same as tray Battery module).
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded
                     && SysRowState.showBattery
                     && SystemMonitorService.batteryPresent
            opacity: sysRoot.expanded ? 1 : 0
            icon: {
                const cap = SystemMonitorService.batteryCapacity
                const charging = SystemMonitorService.batteryCharging
                // Icon glyph (nf-fa-battery_*) — u+f240..f244
                let glyph
                if      (cap >= 90) glyph = "\uf240"   // battery-full
                else if (cap >= 65) glyph = "\uf241"   // battery-three-quarters
                else if (cap >= 40) glyph = "\uf242"   // battery-half
                else if (cap >= 15) glyph = "\uf243"   // battery-quarter
                else                glyph = "\uf244"   // battery-empty
                // Charging prefix — bolt
                const prefix = charging ? "\uf0e7 " : ""
                return sysRoot.fmtModule(
                    prefix + glyph,
                    sysRoot.barGlyph(cap),
                    cap + "%"
                )
            }
            tipTitle: "Battery: " + SystemMonitorService.batteryCapacity + "%"
                      + (SystemMonitorService.batteryCharging ? " (charging)" : "")
            tipDetail: {
                let s = "Status: " + SystemMonitorService.batteryStatus
                if (SystemMonitorService.batteryTimeRemaining.length > 0) {
                    s += "\n" + SystemMonitorService.batteryTimeRemaining
                }
                if (SystemMonitorService.batteryPowerDraw > 0) {
                    s += "\nPower: " + SystemMonitorService.batteryPowerDraw.toFixed(1) + "W"
                }
                // Append current power profile if available
                if (typeof PowerProfileService !== "undefined" && PowerProfileService.available) {
                    s += "\nProfile: " + PowerProfileService.profileLabel(PowerProfileService.currentProfile)
                }
                return s
            }
            iconColor: SysRowState.resolveColor(
                SysRowState.batteryColor,
                // Auto color by capacity + charging state
                SystemMonitorService.batteryCharging ? ThemeService.green
                    : (SystemMonitorService.batteryCapacity <= 10 ? ThemeService.red
                    : (SystemMonitorService.batteryCapacity <= 30 ? ThemeService.orange
                    : (SystemMonitorService.batteryCapacity <= 50 ? ThemeService.yellow
                    : ThemeService.fg)))
            )
            onClicked: {
                // Open Control Panel (Super+C) — has Power Profile section
                batteryProc.command = ["bash", "-c",
                    "qs -c zen-shell ipc call zen toggleControlCenter"]
                batteryProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ── End separator (waybar custom/endpoint) ──
        Text {
            visible: sysRoot.expanded
            opacity: sysRoot.expanded ? 1 : 0
            text: "|"
            font.family: Theme.fontFamily
            font.pixelSize: 14
            color: ThemeService.grey2
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // ── Process launchers ──
    Process { id: audioProc; running: false }
    Process { id: btmProc; running: false }
    Process { id: wifiProc; running: false }
    Process { id: btProc; running: false }
    Process { id: batteryProc; running: false }   // v6.16.0
}
