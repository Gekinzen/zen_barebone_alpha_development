pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Color tokens ──
    property color bg0: "#1a1b26"
    property color bg1: "#24283b"
    property color bg2: "#292e42"
    property color bg3: "#414868"
    property color fg:  "#c0caf5"
    property color fgDim: "#565f89"
    property color blue:   "#7aa2f7"
    property color green:  "#9ece6a"
    property color red:    "#f7768e"
    property color yellow: "#e0af68"
    property color orange: "#ff9e64"
    property color purple: "#bb9af7"
    property color cyan:   "#7dcfff"
    property color pink:   "#f5c2e7"

    // ── Style mode ──
    // "round" = circular modules (new)
    // "pill" = elongated pills (old/Waybar-style)
    property string styleMode: "round"

    // ── Bar config ──
    property real barOpacity: 0.50
    property real barRadius: 16
    property string fontFamily: "Adwaita Sans"
    property string monoFont: "JetBrainsMono Nerd Font Propo"
    property int fontSize: 14
    property int iconSize: 20

    // Style-dependent properties
    property real moduleRadius: styleMode === "round" ? 20 : 45
    property real moduleHeight: 40
    property real workspaceRadius: styleMode === "round" ? 20 : 26

    // ── Bar layout config ──
    // v6.16.0: battery added to right row. Hides itself on desktops
    // (SystemMonitorService.batteryPresent === false).
    property var barLayout: ({
        "left": ["start", "taskbar"],
        "center": ["workspaces", "window"],
        "right": ["music", "sysrow", "tray", "battery", "notifications", "clock"]
    })

    // ── Theme schemes ──
    property string currentScheme: "tokyo-night"
    property var availableSchemes: ["tokyo-night", "catppuccin-mocha", "dracula"]

    function loadScheme(name: string) {
        currentScheme = name
        schemeLoader.path = Qt.resolvedUrl("theme/schemes/" + name + ".json")
        schemeLoader.reload()
    }

    function cycleTheme() {
        const idx = availableSchemes.indexOf(currentScheme)
        const next = availableSchemes[(idx + 1) % availableSchemes.length]
        loadScheme(next)
    }

    function applyScheme(jsonText: string) {
        if (!jsonText) return
        try {
            const s = JSON.parse(jsonText)
            if (s.bg0) bg0 = s.bg0
            if (s.bg1) bg1 = s.bg1
            if (s.bg2) bg2 = s.bg2
            if (s.bg3) bg3 = s.bg3
            if (s.fg)  fg  = s.fg
            if (s.fgDim) fgDim = s.fgDim
            if (s.blue)   blue   = s.blue
            if (s.green)  green  = s.green
            if (s.red)    red    = s.red
            if (s.yellow) yellow = s.yellow
            if (s.orange) orange = s.orange
            if (s.purple) purple = s.purple
            if (s.cyan)   cyan   = s.cyan
            if (s.pink)   pink   = s.pink
            console.log("[zen] Loaded scheme:", currentScheme)
        } catch (e) {
            console.error("[zen] Scheme parse error:", e)
        }
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function toggleStyle() {
        styleMode = styleMode === "round" ? "pill" : "round"
    }

    FileView {
        id: schemeLoader
        path: Qt.resolvedUrl("theme/schemes/tokyo-night.json")
        blockLoading: true
        onLoaded: root.applyScheme(this.text())
    }

    // ── Layout config loader ──
    FileView {
        id: layoutLoader
        path: Quickshell.dataPath("bar-layout.json")
        blockLoading: true
        onLoaded: {
            try {
                const d = JSON.parse(this.text())
                if (d.layout) root.barLayout = d.layout
                if (d.style) root.styleMode = d.style
            } catch (e) {}
        }
    }
}
