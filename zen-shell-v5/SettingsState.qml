pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * SettingsState — Central persistence for all settings pages
 *
 * On init: reads current Hyprland values via `hyprctl getoption -j`
 * On change: writes to ~/.config/quickshell/zen-shell/settings-state.json
 * On restart: loads from JSON (values survive restarts)
 *
 * Each page binds to these properties instead of local ones.
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/settings-state.json"

    // ── Appearance ──
    property int gapsIn: 5
    property int gapsOut: 20
    property int borderSize: 2
    property int rounding: 10
    property real activeOpacity: 1.0
    property real inactiveOpacity: 0.95
    property bool blurEnabled: true
    property int blurSize: 8
    property int blurPasses: 2

    // ── Animations ──
    property string currentAnimPreset: "Default (Current)"

    // ── Flags ──
    property bool initialized: false
    property bool dirty: false

    // ── Debounced save ──
    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: root.saveState()
    }

    function markDirty() {
        dirty = true
        saveTimer.restart()
    }

    // ── Hyprctl apply (debounced) ──
    property string pendingHyprctl: ""

    Timer {
        id: hyprTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.pendingHyprctl.length > 0) {
                hyprProc.command = ["hyprctl", "--batch", root.pendingHyprctl]
                hyprProc.running = true
                root.pendingHyprctl = ""
            }
        }
    }

    function scheduleHyprctl(cmd) {
        pendingHyprctl = (pendingHyprctl.length > 0 ? pendingHyprctl + ";" : "") + cmd
        hyprTimer.restart()
        markDirty()
    }

    function hyprctlNow(key, val) {
        hyprProc.command = ["hyprctl", "keyword", key, "" + val]
        hyprProc.running = true
        markDirty()
    }

    Process { id: hyprProc; running: false }

    // ─────────────────────────────────────────────────────────────
    // SAVE / LOAD
    // ─────────────────────────────────────────────────────────────

    function saveState() {
        const state = {
            appearance: {
                gapsIn: gapsIn, gapsOut: gapsOut, borderSize: borderSize,
                rounding: rounding, activeOpacity: activeOpacity,
                inactiveOpacity: inactiveOpacity, blurEnabled: blurEnabled,
                blurSize: blurSize, blurPasses: blurPasses
            },
            animations: {
                currentPreset: currentAnimPreset
            }
        }
        const json = JSON.stringify(state, null, 2)
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSEOF'\n" + json + "\nZSEOF"]
        saver.running = true
        dirty = false
    }

    Process { id: saver; running: false }

    function loadFromJson(text) {
        if (!text) return
        try {
            const s = JSON.parse(text)
            const a = s.appearance || {}
            if (a.gapsIn !== undefined) gapsIn = a.gapsIn
            if (a.gapsOut !== undefined) gapsOut = a.gapsOut
            if (a.borderSize !== undefined) borderSize = a.borderSize
            if (a.rounding !== undefined) rounding = a.rounding
            if (a.activeOpacity !== undefined) activeOpacity = a.activeOpacity
            if (a.inactiveOpacity !== undefined) inactiveOpacity = a.inactiveOpacity
            if (typeof a.blurEnabled === "boolean") blurEnabled = a.blurEnabled
            if (a.blurSize !== undefined) blurSize = a.blurSize
            if (a.blurPasses !== undefined) blurPasses = a.blurPasses

            const an = s.animations || {}
            if (an.currentPreset) currentAnimPreset = an.currentPreset

            console.log("[SettingsState] Loaded from JSON")
        } catch(e) {
            console.error("[SettingsState] Parse error:", e)
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        onLoaded: root.loadFromJson(this.text())
    }

    // ─────────────────────────────────────────────────────────────
    // READ CURRENT VALUES from Hyprland on init
    // ─────────────────────────────────────────────────────────────

    function readFromHyprland() {
        hyprReader.command = ["bash", "-c",
            "echo '{'; " +
            "echo '\"gaps_in\":'; hyprctl getoption general:gaps_in -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"gaps_out\":'; hyprctl getoption general:gaps_out -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"border_size\":'; hyprctl getoption general:border_size -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"rounding\":'; hyprctl getoption decoration:rounding -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"active_opacity\":'; hyprctl getoption decoration:active_opacity -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"inactive_opacity\":'; hyprctl getoption decoration:inactive_opacity -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_enabled\":'; hyprctl getoption decoration:blur:enabled -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_size\":'; hyprctl getoption decoration:blur:size -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_passes\":'; hyprctl getoption decoration:blur:passes -j 2>/dev/null || echo '{}'; " +
            "echo '}'"]
        hyprReader.running = true
    }

    Process {
        id: hyprReader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    // hyprctl getoption returns {"int": N} or {"float": N} or {"set": bool}
                    if (d.gaps_in && d.gaps_in.int !== undefined) root.gapsIn = d.gaps_in.int
                    if (d.gaps_out && d.gaps_out.int !== undefined) root.gapsOut = d.gaps_out.int
                    if (d.border_size && d.border_size.int !== undefined) root.borderSize = d.border_size.int
                    if (d.rounding && d.rounding.int !== undefined) root.rounding = d.rounding.int
                    if (d.active_opacity && d.active_opacity.float !== undefined) root.activeOpacity = d.active_opacity.float
                    if (d.inactive_opacity && d.inactive_opacity.float !== undefined) root.inactiveOpacity = d.inactive_opacity.float
                    if (d.blur_enabled && d.blur_enabled.set !== undefined) root.blurEnabled = d.blur_enabled.set
                    if (d.blur_size && d.blur_size.int !== undefined) root.blurSize = d.blur_size.int
                    if (d.blur_passes && d.blur_passes.int !== undefined) root.blurPasses = d.blur_passes.int

                    root.initialized = true
                    root.saveState()  // Persist hyprland current state
                    console.log("[SettingsState] Read from Hyprland: gaps=" + root.gapsIn + "/" + root.gapsOut)
                } catch(e) {
                    console.log("[SettingsState] hyprctl read fallback (not in Hyprland?)")
                    root.initialized = true
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // DEFAULTS
    // ─────────────────────────────────────────────────────────────

    function resetAppearanceDefaults() {
        gapsIn = 5; gapsOut = 20; borderSize = 2; rounding = 10
        activeOpacity = 1.0; inactiveOpacity = 0.95
        blurEnabled = true; blurSize = 8; blurPasses = 2

        hyprProc.command = ["hyprctl", "--batch",
            "keyword general:gaps_in 5;" +
            "keyword general:gaps_out 20;" +
            "keyword general:border_size 2;" +
            "keyword decoration:rounding 10;" +
            "keyword decoration:active_opacity 1.0;" +
            "keyword decoration:inactive_opacity 0.95;" +
            "keyword decoration:blur:enabled true;" +
            "keyword decoration:blur:size 8;" +
            "keyword decoration:blur:passes 2"]
        hyprProc.running = true
        saveState()
    }

    // ─────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────

    Component.onCompleted: {
        stateFile.reload()
        // After JSON load, also try reading live Hyprland values
        Qt.callLater(readFromHyprland)
    }
}
