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

    // ── Module content sizing (v7.0.0-beta.1-hf84) ──
    //
    // The *Base values are the user/theme preference (written by
    // ThemeService when a theme is loaded). The VISIBLE sizes below
    // (fontSize / iconSize / moduleHeight) derive from these times
    // barContentScale, so when "Fit contents to bar" is on, every bar
    // module that reads Theme.iconSize / Theme.fontSize / Theme.moduleHeight
    // scales to the bar height automatically — no per-module change.
    // Default scale is 1.0, so with the toggle off these equal their
    // base values exactly (nothing changes for existing users).
    property int fontSizeBase: 14
    property int iconSizeBase: 20

    // barContentScale: 1.0 unless PanelState.barFitContents is on, in
    // which case it tracks the FIXED barHeight slider relative to the
    // 60px baseline the default sizes were tuned for. Derived from the
    // slider value (never the auto-computed height) so it can't feed
    // back into barAutoHeight. Guarded + clamped for legibility.
    readonly property real barContentScale: {
        if (typeof PanelState === "undefined") return 1.0
        // Manual multiplier always applies; fit-to-height adds on top.
        const manual = (PanelState.barModuleScale && PanelState.barModuleScale > 0)
                       ? PanelState.barModuleScale : 1.0
        let s = manual
        if (PanelState.barFitContents) {
            const ref = 60
            const h = (PanelState.barHeight && PanelState.barHeight > 0)
                      ? PanelState.barHeight : ref
            s = s * (h / ref)
        }
        if (s < 0.6) s = 0.6
        if (s > 2.4) s = 2.4
        return s
    }

    readonly property int fontSize: Math.max(8, Math.round(fontSizeBase * barContentScale))
    readonly property int iconSize: Math.max(10, Math.round(iconSizeBase * barContentScale))

    // Style-dependent properties
    // v6.16.4.12.7 (Tachiagari): pill mode now uses a SMALL radius (10)
    // for a true rectangular-pill look. Old value (45) was clamped by
    // QML to height/2 (=20) because moduleHeight is 40 — making pill
    // mode visually IDENTICAL to round mode. The whole point of pill is
    // a flatter, Waybar-style elongated module — the small radius is
    // what gives it that look. workspaceRadius gets the same treatment
    // so workspace dots also look rectangular in pill mode.
    property real moduleRadius: styleMode === "round" ? 20 : 10
    // v7.0.0-beta.1-hf84: scales with barContentScale (see above) so
    // module pills grow/shrink to fill the bar when Fit-contents is on.
    // Base 40 preserved when scale is 1.0.
    readonly property real moduleHeightBase: 40
    readonly property real moduleHeight: moduleHeightBase * barContentScale
    property real workspaceRadius: styleMode === "round" ? 20 : 6

    // ── Bar layout config ──
    // v6.16.0: battery added to right row. Hides itself on desktops
    // (SystemMonitorService.batteryPresent === false).
    // v6.16.3.4: powerbadge added between battery and notifications.
    // Hides itself when neither powerprofilesctl nor multi-GPU is
    // available, so it's invisible on systems where it'd be useless.
    // EXISTING USERS: this only affects fresh installs. If you have
    // a saved ~/.config/quickshell/bar-layout.json it overrides this
    // default. Add "powerbadge" to that file's right array if you
    // want the badge on an existing install.
    property var barLayout: ({
        "left": ["start", "taskbar"],
        "center": ["workspaces", "window"],
        "right": ["music", "sysrow", "tray", "workflow", "clipboard", "quicknotes", "titletranslator", "battery", "powerbadge", "notifications", "clock"]
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
    //
    // v6.16.4.12.9 (Modori) — settings persistence fix.
    //
    // This loader USED to also read `style` from bar-layout.json and
    // write it to `root.styleMode`. That created a clobber bug: PanelState
    // saves styleMode (along with barOpacity/barRadius) to its OWN file
    // panel-state.json, but bar-layout.json still had a stale `style`
    // field from earlier shell versions. When `reloadBarLayout()` fired
    // (e.g. after a Power Badge toggle from Bar Modules settings), it
    // would re-read the stale value and overwrite the user's actual
    // choice. The user would see their pill setting silently revert to
    // round on the next slider drag (which would then save the now-
    // wrong styleMode back to panel-state.json) or on the next shell
    // restart.
    //
    // Fix: PanelState owns `styleMode` exclusively now (saved as part
    // of panel-state.json, applied via PanelState.applyState()). This
    // FileView ONLY reads `barLayout` — the actual module list. The
    // `style` field in bar-layout.json (if present) is ignored. Old
    // files that still have it remain readable; the field is just no
    // longer consumed.
    FileView {
        id: layoutLoader
        path: Quickshell.dataPath("bar-layout.json")
        blockLoading: true
        onLoaded: {
            try {
                const d = JSON.parse(this.text())
                if (d.layout) root.barLayout = d.layout
                // d.style intentionally NOT applied — see comment above.
            } catch (e) {}
        }
    }

    // v6.16.3.4.5: exposed so UI surfaces that mutate bar-layout.json
    // (e.g. BarModulesPage's PowerBadge toggle) can force a re-read
    // after the file changes on disk. Avoids the need for FileView
    // watchChanges (which would fire on every write).
    function reloadBarLayout() {
        layoutLoader.reload()
    }
}
