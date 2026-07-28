pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * WidgetsState v7.0.0-beta.1-hf99zj — Karui (軽い)
 *
 * A tiny read-only mirror of ~/.config/quickshell/zen-shell/widgets-state.json
 * (the file DesktopWidgets renders from and WidgetsPage writes).
 *
 * Why: the Quick Settings panel wants the SAME look the user configured for
 * the desktop widgets — the clock design/font, the weather accent, the system
 * monitor accent/font — but ControlPanel can't reach into the DesktopWidgets
 * instance (it's per-screen, not a singleton). This singleton reads the same
 * file with `watchChanges: true`, so changing a setting updates the desktop
 * widget AND the Quick Settings card live, with no restart.
 *
 * Read-only by design: nothing here writes the file.
 */
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME")
        + "/.config/quickshell/zen-shell/widgets-state.json"

    // ── Clock ──
    property string clockStyle: "outline"     // outline|solid|raised|mono|stacked|analog
    property string clockFont: "Adwaita Sans"

    // ── Weather ──
    property string weatherFont: "Adwaita Sans"
    property string weatherAccentMode: "default"   // default|theme|custom
    property string weatherAccentColor: "#7ab8ff"

    // ── System monitor ──
    property string sysmonFont: "Adwaita Sans"
    property string sysmonStyle: "classic"
    property string sysmonAccentMode: "multi"      // multi|theme|custom
    property string sysmonAccentColor: "#0a84ff"
    // v7.0.0-beta.1-hf99zt: the Pills card colours, so the dashboard and the
    // Quick Settings render EXACTLY like the desktop widget.
    property string sysmonCardColor: "#f2f2f5"
    property real   sysmonCardOpacity: 1.0

    // ── Clocks (per-clock design + timezones), mirrored for the dashboard ──
    property var clocks: []
    property var tzTimes: ({})

    // ── Glance (merged blob) — v8.0.0-alpha-hf113 ──
    property bool   glanceMerged: false
    property string glanceSurfaceMode: "default"
    property string glanceSurfaceColor: "#fbede8"
    property string glanceInkMode: "auto"
    property string glanceInkColor: "#6e2a14"
    property string glanceAccentMode: "default"
    property string glanceAccentColor: "#5dc4e8"
    property string glanceFont: "Adwaita Sans"

    readonly property color glanceSurface: {
        if (glanceSurfaceMode === "theme")  return ThemeService.bg1
        if (glanceSurfaceMode === "custom") return glanceSurfaceColor
        return "#fbede8"
    }
    readonly property color glanceAccent: {
        if (glanceAccentMode === "theme")  return ThemeService.blue
        if (glanceAccentMode === "custom") return glanceAccentColor
        return "#5dc4e8"
    }

    // ── Shared widget colours ──
    property string widgetColorMode: "default"     // default|theme|custom
    property string widgetCustomColor: "#ffffff"

    // Resolved accents, same rules as DesktopWidgets.
    readonly property color weatherAccent: {
        if (weatherAccentMode === "theme") return ThemeService.blue
        if (weatherAccentMode === "custom") return weatherAccentColor
        return "#7ab8ff"
    }
    function sysmonAccentFor(defaultColor) {
        if (sysmonAccentMode === "theme") return ThemeService.blue
        if (sysmonAccentMode === "custom") return sysmonAccentColor
        return defaultColor
    }

    // Same maths as DesktopWidgets: card colour + auto-contrasting text.
    readonly property color sysmonCardBg: {
        const c = sysmonCardColor
        return Qt.rgba(parseInt(c.substr(1,2),16)/255, parseInt(c.substr(3,2),16)/255,
                       parseInt(c.substr(5,2),16)/255, sysmonCardOpacity)
    }
    readonly property bool sysmonCardIsLight: {
        const c = sysmonCardColor
        const r = parseInt(c.substr(1,2),16)/255, g = parseInt(c.substr(3,2),16)/255, b = parseInt(c.substr(5,2),16)/255
        return (0.2126*r + 0.7152*g + 0.0722*b) > 0.55
    }
    readonly property color sysmonCardText: sysmonCardOpacity < 0.35
        ? ThemeService.fg
        : (sysmonCardIsLight ? Qt.rgba(0.10,0.10,0.11,1) : Qt.rgba(1,1,1,0.95))
    readonly property color sysmonCardSubText: Qt.rgba(sysmonCardText.r, sysmonCardText.g, sysmonCardText.b, 0.5)
    readonly property color sysmonCardLine: Qt.rgba(sysmonCardText.r, sysmonCardText.g, sysmonCardText.b, 0.15)

    // Per-clock resolved style ("" / "inherit" → the global clockStyle)
    function clockStyleFor(idx) {
        const c = (idx >= 0 && idx < clocks.length) ? clocks[idx] : null
        return (c && c.style && c.style !== "inherit" && c.style.length > 0) ? c.style : clockStyle
    }
    function clockLabelFor(idx) {
        const c = (idx >= 0 && idx < clocks.length) ? clocks[idx] : null
        if (!c) return ""
        if (c.name && c.name.length > 0) return c.name
        if (c.label && c.label.length > 0) return c.label
        return (c.timezone || "").split("/").pop().replace(/_/g, " ")
    }
    // Time for a clock: index 0 is local, the rest come from the OS zoneinfo
    // cache below (Intl is not supported by the Quickshell JS engine).
    function timeFor(idx, now) {
        if (idx === 0 || !clocks[idx]) return { hours: now.getHours(), minutes: now.getMinutes() }
        const s = tzTimes[clocks[idx].timezone]
        if (s) {
            const p = s.split(":")
            const hh = parseInt(p[0], 10), mm = parseInt(p[1], 10)
            if (!isNaN(hh) && !isNaN(mm)) return { hours: hh, minutes: mm }
        }
        return { hours: now.getHours(), minutes: now.getMinutes() }
    }

    function _refreshTz() {
        const zones = {}
        for (let i = 0; i < clocks.length; i++) if (clocks[i] && clocks[i].timezone) zones[clocks[i].timezone] = true
        let script = ""
        for (const tz in zones) {
            if (!/^[A-Za-z0-9_\/+.-]+$/.test(tz)) continue
            script += "printf '%s|%s\\n' '" + tz + "' \"$(TZ='" + tz + "' date +%H:%M)\"; "
        }
        if (script === "") return
        tzProc.command = ["bash", "-c", script]
        tzProc.running = true
    }
    Process {
        id: tzProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                const lines = this.text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("|")
                    if (parts.length === 2) map[parts[0]] = parts[1].trim()
                }
                root.tzTimes = map
            }
        }
    }
    onClocksChanged: root._refreshTz()
    Timer { interval: 20000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root._refreshTz() }

    FileView {
        id: stateFile
        path: root.configPath
        blockLoading: false
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root._apply(this.text())
    }
    // Belt-and-braces: reload on start and every 5s (matches DesktopWidgets),
    // in case the file is replaced rather than modified in place.
    Component.onCompleted: stateFile.reload()
    Timer { interval: 5000; repeat: true; running: true; onTriggered: stateFile.reload() }

    function _apply(txt) {
        try {
            const s = JSON.parse(txt)
            if (typeof s.clockStyle === "string") clockStyle = s.clockStyle
            if (typeof s.clockFont === "string") clockFont = s.clockFont
            if (typeof s.weatherFont === "string") weatherFont = s.weatherFont
            if (typeof s.weatherAccentMode === "string") weatherAccentMode = s.weatherAccentMode
            if (typeof s.weatherAccentColor === "string") weatherAccentColor = s.weatherAccentColor
            if (typeof s.sysmonFont === "string") sysmonFont = s.sysmonFont
            if (typeof s.sysmonStyle === "string") sysmonStyle = s.sysmonStyle
            if (typeof s.sysmonAccentMode === "string") sysmonAccentMode = s.sysmonAccentMode
            if (typeof s.sysmonAccentColor === "string") sysmonAccentColor = s.sysmonAccentColor
            if (typeof s.sysmonCardColor === "string") sysmonCardColor = s.sysmonCardColor
            if (typeof s.sysmonCardOpacity === "number") sysmonCardOpacity = s.sysmonCardOpacity
            if (s.clocks && Array.isArray(s.clocks)) clocks = s.clocks
            if (typeof s.colorMode === "string") widgetColorMode = s.colorMode
            if (typeof s.customColor === "string") widgetCustomColor = s.customColor
            // v8.0.0-alpha-hf113
            if (s.glance) {
                if (typeof s.glance.merged === "boolean")      glanceMerged = s.glance.merged
                if (typeof s.glance.surfaceMode === "string")  glanceSurfaceMode = s.glance.surfaceMode
                if (typeof s.glance.surfaceColor === "string") glanceSurfaceColor = s.glance.surfaceColor
                if (typeof s.glance.inkMode === "string")      glanceInkMode = s.glance.inkMode
                if (typeof s.glance.inkColor === "string")     glanceInkColor = s.glance.inkColor
                if (typeof s.glance.accentMode === "string")   glanceAccentMode = s.glance.accentMode
                if (typeof s.glance.accentColor === "string")  glanceAccentColor = s.glance.accentColor
                if (typeof s.glance.font === "string")         glanceFont = s.glance.font
            }
        } catch (e) {
            console.warn("[WidgetsState] parse error:", e)
        }
    }
}
