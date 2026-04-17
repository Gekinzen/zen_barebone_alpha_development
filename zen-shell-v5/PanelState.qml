pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * PanelState — Extended panel configuration
 *
 * Complements existing Theme.qml barLayout/barOpacity/barRadius.
 * Persists to ~/.config/quickshell/zen-shell/panel-state.json
 *
 * Panel modes:
 *   "fullwidth" — traditional bar spanning entire screen width
 *   "floating"  — bar with margins on both sides (small gap)
 *   "island"    — compact centered bar with large margins
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/panel-state.json"

    // ── Panel style mode ──
    property string panelMode: "fullwidth"   // "fullwidth" | "floating" | "island"

    // ── Bar height ──
    property int barHeight: 60

    // ── Computed margins/width based on mode ──
    property int panelMarginSide: {
        if (panelMode === "floating") return 12
        if (panelMode === "island") return 240
        return 0
    }

    property int panelMarginBottom: panelMode === "fullwidth" ? 0 : 8

    // ── Border ──
    property bool borderEnabled: false
    property int borderWidth: 1
    property color borderColor: "#414868"

    // ── Background override (null = use Theme.bg0) ──
    property bool bgOverrideEnabled: false
    property color bgOverrideColor: "#1a1b26"
    property real bgOverrideOpacity: 0.85

    // ── v6.4: Dynamic start menu positioning ──
    // Updated by StartMenu.qml on every click. Stored as the button's
    // center-X in GLOBAL (screen) coordinates. Runtime-only — not persisted,
    // since it changes every time the bar layout rearranges.
    property real startButtonCenterX: -1   // -1 = unknown, use default left-anchor
    property real startButtonCenterY: -1

    // Screen dimensions of the monitor the start button was last clicked on.
    // Used by shell.qml to clamp the menu within the viewport.
    property int screenWidth: 1920
    property int screenHeight: 1080

    // ── v6.4: Style-mode propagation flag ──
    // When true (default), derived modules (start menu, taskbar wrapper,
    // settings window) read their radius/shape from Theme.barRadius +
    // Theme.styleMode instead of hardcoding. Gives uniform look when user
    // switches to "round" style via Panel page.
    property bool propagateStyleToModules: true

    // ── v6.6: Bar module format selections ──
    // Clock format index (into ZenConstants.clockFormats array).
    // Default 6 = "Date + 12h multiline".
    property int clockFormatIndex: 6

    // Workspace number format preset id (keys from ZenConstants.workspaceFormats)
    // Default "numbers".
    property string workspaceFormat: "numbers"

    // Active font family id (from ZenConstants.fontFamilies).
    // Default "jetbrains".
    property string fontFamilyId: "jetbrains"

    // v6.8: Workspace visible count limit (default 5).
    property int workspaceLimit: 5

    // v6.10: Bar target display — "all", "primary", or specific monitor name
    property string barTargetDisplay: "all"

    // v6.11: Start button icon size (default 26)
    property int startButtonIconSize: 26

    // v6.11: Workspace dot sizes — active/inactive
    property int workspaceDotActive: 32
    property int workspaceDotInactive: 26
    property int workspaceFontActive: 13
    property int workspaceFontInactive: 11

    // ── Signals ──
    signal stateChanged()

    function saveState() {
        const state = {
            panelMode: panelMode,
            barHeight: barHeight,
            borderEnabled: borderEnabled,
            borderWidth: borderWidth,
            borderColor: "" + borderColor,
            bgOverrideEnabled: bgOverrideEnabled,
            bgOverrideColor: "" + bgOverrideColor,
            bgOverrideOpacity: bgOverrideOpacity,
            // v6.6
            clockFormatIndex: clockFormatIndex,
            workspaceFormat: workspaceFormat,
            fontFamilyId: fontFamilyId,
            // v6.8
            workspaceLimit: workspaceLimit,
            // v6.10
            barTargetDisplay: barTargetDisplay,
            // v6.11
            startButtonIconSize: startButtonIconSize,
            workspaceDotActive: workspaceDotActive,
            workspaceDotInactive: workspaceDotInactive,
            workspaceFontActive: workspaceFontActive,
            workspaceFontInactive: workspaceFontInactive
        }
        const json = JSON.stringify(state, null, 2)
        stateSaver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSEOF'\n" + json + "\nZSEOF"]
        stateSaver.running = true
        stateChanged()
    }

    function applyState(text) {
        if (!text) return
        try {
            const s = JSON.parse(text)
            if (s.panelMode) panelMode = s.panelMode
            if (s.barHeight) barHeight = s.barHeight
            if (typeof s.borderEnabled === "boolean") borderEnabled = s.borderEnabled
            if (s.borderWidth) borderWidth = s.borderWidth
            if (s.borderColor) borderColor = s.borderColor
            if (typeof s.bgOverrideEnabled === "boolean") bgOverrideEnabled = s.bgOverrideEnabled
            if (s.bgOverrideColor) bgOverrideColor = s.bgOverrideColor
            if (s.bgOverrideOpacity !== undefined) bgOverrideOpacity = s.bgOverrideOpacity
            // v6.6
            if (typeof s.clockFormatIndex === "number") clockFormatIndex = s.clockFormatIndex
            if (s.workspaceFormat) workspaceFormat = s.workspaceFormat
            if (s.fontFamilyId) fontFamilyId = s.fontFamilyId
            // v6.8
            if (typeof s.workspaceLimit === "number") workspaceLimit = s.workspaceLimit
            // v6.10
            if (s.barTargetDisplay) barTargetDisplay = s.barTargetDisplay
            // v6.11
            if (typeof s.startButtonIconSize === "number") startButtonIconSize = s.startButtonIconSize
            if (typeof s.workspaceDotActive === "number") workspaceDotActive = s.workspaceDotActive
            if (typeof s.workspaceDotInactive === "number") workspaceDotInactive = s.workspaceDotInactive
            if (typeof s.workspaceFontActive === "number") workspaceFontActive = s.workspaceFontActive
            if (typeof s.workspaceFontInactive === "number") workspaceFontInactive = s.workspaceFontInactive
        } catch (e) {
            console.error("[PanelState] Parse error:", e)
        }
    }

    Process { id: stateSaver; running: false }

    FileView {
        id: stateLoader
        path: root.statePath
        blockLoading: false
        onLoaded: root.applyState(this.text())
    }

    function setMode(mode) {
        if (mode === "fullwidth" || mode === "floating" || mode === "island") {
            panelMode = mode
            saveState()
        }
    }

    function setBorder(enabled, width, color) {
        borderEnabled = enabled
        borderWidth = width
        borderColor = color
        saveState()
    }

    function setBackground(enabled, color, opacity) {
        bgOverrideEnabled = enabled
        bgOverrideColor = color
        bgOverrideOpacity = opacity
        saveState()
    }

    function resetDefaults() {
        panelMode = "fullwidth"
        barHeight = 60
        borderEnabled = false
        borderWidth = 1
        borderColor = "#414868"
        bgOverrideEnabled = false
        bgOverrideColor = "#1a1b26"
        bgOverrideOpacity = 0.85
        saveState()
    }

    // Called by StartMenu.qml when clicked. x/y are in GLOBAL screen
    // coordinates (i.e. mapped through the button's parent chain).
    // sw/sh are the screen dimensions (from QsWindow.window.screen).
    function reportStartButtonPosition(x: real, y: real, sw: int, sh: int) {
        startButtonCenterX = x
        startButtonCenterY = y
        if (sw > 0) screenWidth = sw
        if (sh > 0) screenHeight = sh
    }

    Component.onCompleted: {
        stateLoader.reload()
    }
}
