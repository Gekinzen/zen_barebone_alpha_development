pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ZenStringsState v6.15 — State for ZenStrings music module
 *
 * Kapag enabled = true, yung music module sa bar ay magiging ZenStrings.
 * Kapag may nag-play na track → animated bezier (cava-reactive).
 * Kapag wala / paused → static decorative line (always visible).
 *
 * Color modes:
 *   "theme"   = auto blue→purple from ThemeService (default)
 *   "synced"  = specific ThemeService color keys
 *   "custom"  = user-defined hex colors
 *
 * Persists to ~/.config/quickshell/zen-shell/strings-state.json
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/strings-state.json"

    // ── Master toggle — replaces music widget when true ──
    property bool enabled: false

    // ── Cava segments ──
    property int segments: 10

    // ── Stroke thickness ──
    property real strokeWidth: 4.0

    // ── Beat bow amplitude — how far curves bow per beat ──
    // Does NOT affect string position or bar slot height
    property int curveHeight: 60

    // ── Vertical padding — overflow space above/below bar slot ──
    // 0 = auto: uses curveHeight so curves always have room to bow
    // >0 = fixed px each side (above + below)
    property int verticalPadding: 0

    // ── Width of string inside bar slot ──
    // 0 = fill available slot width (recommended)
    // >0 = fixed px centered in slot
    property int stringLength: 0

    // ── Glow ──
    property bool glowEnabled: true
    property int glowRadius: 12

    // ── Color mode ──
    property string colorMode: "theme"
    property string syncedColor1Key: "blue"
    property string syncedColor2Key: "purple"
    property string customColor1: "#ff9e64"
    property string customColor2: "#cec991"

    // ── Live audio state — written by MusicStrings, read by overlay ──
    property bool isAudioActive: false
    property var  cavaData: []

    // v6.15.1: Track info shared for stringsWindow hover tooltip
    property string trackInfo: ""
    property bool mediaPlaying: false
    property bool cavaHasAudio: false

    // ── Music slot screen position — written by Bar.qml, read by overlay ──
    // musicSlotLocalX: X of music slot relative to Bar rectangle
    // musicSlotLocalWidth: width of music slot
    // barWindowLeft: bar window's left edge in screen coords (mode-aware)
    // All written at runtime — overlay PanelWindow reads these.
    property real musicSlotLocalX: -1
    property real musicSlotLocalWidth: 200
    property real barWindowLeft: 0

    // v6.15.2: Position readiness signal.
    // Written by stringsWindow (shell.qml) — true when the music slot
    // position has been stable for 600ms (i.e. bar has finished its
    // initial layout AND any runtime reflow from sysrow/taskbar loads).
    // Read by MusicStrings.qml to show a Loading placeholder in the
    // bar slot while positionReady = false, so the user doesn't see
    // the string visualizer floating at the wrong spot on login.
    // Runtime-only — not persisted.
    property bool positionReady: false

    // ── Derived colors (used by ZenStrings + ZenRope + overlay) ──
    // Automatically computed from colorMode + theme.
    function _resolveKey(key) {
        switch(key) {
            case "red":    return ThemeService.red
            case "orange": return ThemeService.orange
            case "yellow": return ThemeService.yellow
            case "green":  return ThemeService.green
            case "aqua":   return ThemeService.aqua
            case "blue":   return ThemeService.blue
            case "purple": return ThemeService.purple
            case "fg":     return ThemeService.fg
            case "grey0":  return ThemeService.grey0
            default:       return ThemeService.blue
        }
    }
    readonly property color color1: {
        if (colorMode === "custom") return customColor1
        if (colorMode === "theme")  return ThemeService.blue
        return _resolveKey(syncedColor1Key)
    }
    readonly property color color2: {
        if (colorMode === "custom") return customColor2
        if (colorMode === "theme")  return ThemeService.purple
        return _resolveKey(syncedColor2Key)
    }


    // ── Screenshot rope (carried from v6.14.2) ──
    // v6.15.1: reverted to flicko-original values — 10 segments × 5px
    // rest length gives smooth catenary drape. Previous 30×50 was too
    // stiff — rope looked like rigid springs instead of soft string.
    property bool screenshotRopeEnabled: true
    property int ropeSegments: 10
    property int ropeSegmentLength: 5

    property bool dirty: false

    Timer {
        id: saveTimer; interval: 500; repeat: false
        onTriggered: root.saveState()
    }

    function markDirty() { dirty = true; saveTimer.restart() }

    function saveState() {
        const state = {
            enabled, segments, strokeWidth, curveHeight, verticalPadding, stringLength,
            glowEnabled, glowRadius, colorMode,
            syncedColor1Key, syncedColor2Key,
            customColor1, customColor2,
            screenshotRopeEnabled, ropeSegments, ropeSegmentLength
        }
        const json = JSON.stringify(state, null, 2)
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSVEOF'\n" + json + "\nZSVEOF"]
        saver.running = true
        dirty = false
    }

    Process { id: saver; running: false }

    function loadFromJson(text) {
        if (!text || text.trim().length === 0) return
        try {
            const s = JSON.parse(text)
            if (typeof s.enabled === "boolean") enabled = s.enabled
            if (s.segments !== undefined) segments = s.segments
            if (s.strokeWidth !== undefined) strokeWidth = s.strokeWidth
            if (s.curveHeight !== undefined) curveHeight = s.curveHeight
            if (s.verticalPadding !== undefined) verticalPadding = s.verticalPadding
            if (s.stringLength !== undefined) stringLength = s.stringLength
            if (typeof s.glowEnabled === "boolean") glowEnabled = s.glowEnabled
            if (s.glowRadius !== undefined) glowRadius = s.glowRadius
            if (s.colorMode) colorMode = s.colorMode
            if (s.syncedColor1Key) syncedColor1Key = s.syncedColor1Key
            if (s.syncedColor2Key) syncedColor2Key = s.syncedColor2Key
            if (s.customColor1) customColor1 = s.customColor1
            if (s.customColor2) customColor2 = s.customColor2
            if (typeof s.screenshotRopeEnabled === "boolean") screenshotRopeEnabled = s.screenshotRopeEnabled
            if (s.ropeSegments !== undefined) ropeSegments = s.ropeSegments
            if (s.ropeSegmentLength !== undefined) ropeSegmentLength = s.ropeSegmentLength
        } catch(e) { console.error("[ZenStringsState] Parse error:", e) }
    }

    FileView {
        id: stateFile; path: root.statePath; blockLoading: false
        onLoaded: root.loadFromJson(this.text())
    }

    function resetDefaults() {
        enabled = false; segments = 10; strokeWidth = 4.0
        curveHeight = 60; verticalPadding = 0; stringLength = 0
        glowEnabled = true; glowRadius = 12
        colorMode = "theme"
        syncedColor1Key = "blue"; syncedColor2Key = "purple"
        customColor1 = "#ff9e64"; customColor2 = "#cec991"
        screenshotRopeEnabled = true; ropeSegments = 10; ropeSegmentLength = 5
        markDirty()
    }
}
