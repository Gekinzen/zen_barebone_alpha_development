pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * SettingsState — Central persistence for the older Appearance page.
 *
 * On init: reads current Hyprland values via `hyprctl getoption -j`
 *          ONLY if no saved JSON exists (v6.16.3.2.1 fix — see below).
 * On change: writes to ~/.config/quickshell/zen-shell/settings-state.json
 * On restart: loads from JSON (values survive restarts).
 *
 * Each page binds to these properties instead of local ones.
 *
 * ════════════════════════════════════════════════════════════════
 * v6.16.3.2.1 — Init bug fix (gap-wipe regression)
 * ────────────────────────────────────────────────────────────────
 * Symptom Paul reported on 2026-04-22:
 *   "kapag nag change ako ng [mouse sensitivity] values nawawla
 *    yun current settings ko sa gap naging default ganun"
 *
 * Root cause:
 *   Component.onCompleted previously did:
 *       stateFile.reload()
 *       Qt.callLater(readFromHyprland)   ← unconditional
 *
 *   That second call always queried `hyprctl getoption general:gaps_in`
 *   (and friends) and OVERWROTE the user's saved values with whatever
 *   Hyprland was currently reporting. If anything had triggered a
 *   `hyprctl reload` in between (theme change, animation preset, lid
 *   handler, hypridle restart, etc.), Hyprland's effective values
 *   would have already reverted to the hyprland.conf defaults — and
 *   `readFromHyprland` would dutifully save those defaults BACK to
 *   the user's JSON. Cosmetic trigger looked like "mouse sensitivity
 *   wiped my gaps" but really it was: anything that re-instantiated
 *   the SettingsState singleton after a reload.
 *
 *   SettingsStateV2 already had this fix (v6.15.6). V1 (this file)
 *   was missed because at the time AppearancePage was scheduled to
 *   migrate to V2 — that migration never happened, so V1 stayed
 *   buggy in production.
 *
 * Fix (porting V2's pattern):
 *   - Move the readFromHyprland call from Component.onCompleted into
 *     stateFile.onLoaded
 *   - Inside onLoaded: if JSON has actual data, loadFromJson + push
 *     state TO Hyprland (defensive). If JSON is empty / missing
 *     (genuine first run), THEN read FROM Hyprland as the seed.
 *
 * Wala tayong binawasan — every property, every function, every
 * existing call signature is preserved. Only the init-time order
 * of operations changed.
 * ════════════════════════════════════════════════════════════════
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

    // ── SDDM login screen (v7.0.0-beta.1-hf95.12) ──
    // Master switch: when false, theme changes do NOT push to the greeter
    // (the sddmThemer in ThemeService no-ops). When true, the greeter is
    // kept in sync on theme apply / login.
    property bool sddmLoginEnabled: false
    // Background source for the greeter:
    //   "wallpaper" → user's current wallpaper, blurred (default)
    //   "matugen"   → solid colour derived from the active scheme (bg0)
    property string sddmBackgroundMode: "wallpaper"
    onSddmLoginEnabledChanged: if (initialized) saveTimer.restart()
    onSddmBackgroundModeChanged: if (initialized) saveTimer.restart()

    // ── Flags ──
    property bool initialized: false
    property bool dirty: false
    // v6.16.3.2.1: tracks whether saved JSON had actual data
    property bool _jsonLoaded: false

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
            },
            sddm: {
                loginEnabled: sddmLoginEnabled,
                backgroundMode: sddmBackgroundMode
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

            const sd = s.sddm || {}
            if (typeof sd.loginEnabled === "boolean") sddmLoginEnabled = sd.loginEnabled
            if (sd.backgroundMode) sddmBackgroundMode = sd.backgroundMode

            console.log("[SettingsState] Loaded from JSON")
        } catch(e) {
            console.error("[SettingsState] Parse error:", e)
        }
    }

    // v6.16.3.2.1: Defensive push of saved values back to Hyprland.
    // Called from stateFile.onLoaded once JSON has been parsed.
    // Mirror of SettingsStateV2.applyToHyprland() but scoped to V1's
    // smaller set of properties.
    function applyToHyprland() {
        const batch = ""
            + "keyword general:gaps_in " + gapsIn + ";"
            + "keyword general:gaps_out " + gapsOut + ";"
            + "keyword general:border_size " + borderSize + ";"
            + "keyword decoration:rounding " + rounding + ";"
            + "keyword decoration:active_opacity " + activeOpacity.toFixed(2) + ";"
            + "keyword decoration:inactive_opacity " + inactiveOpacity.toFixed(2) + ";"
            + "keyword decoration:blur:enabled " + (blurEnabled ? "true" : "false") + ";"
            + "keyword decoration:blur:size " + blurSize + ";"
            + "keyword decoration:blur:passes " + blurPasses
        hyprProc.command = ["hyprctl", "--batch", batch]
        hyprProc.running = true
        console.log("[SettingsState] Applied saved state to Hyprland (v6.16.3.2.1)")
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        // v6.16.3.2.1: removed inline onLoaded — moved to Connections
        // block below for the apply-vs-read decision tree.
    }

    // v6.16.3.2.1: After stateFile loads, decide:
    //   - If JSON had content → loadFromJson + push to Hyprland
    //   - If JSON empty/missing → readFromHyprland as seed
    Connections {
        target: stateFile
        function onLoaded() {
            const text = stateFile.text()
            if (text && text.trim().length > 2) {
                root.loadFromJson(text)
                root._jsonLoaded = true
                // Push saved values to Hyprland so they take effect even
                // if hyprland.conf has different defaults or a recent
                // `hyprctl reload` reset live state.
                Qt.callLater(root.applyToHyprland)
                root.initialized = true
            } else {
                // Genuine first run — no saved state. Read whatever
                // Hyprland is currently using as our seed values.
                root._jsonLoaded = false
                Qt.callLater(root.readFromHyprland)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ CURRENT VALUES from Hyprland
    // (only called on genuine first run — see Connections above)
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
                    root.saveState()  // Persist Hyprland current state as our new seed
                    console.log("[SettingsState] Seeded from Hyprland: gaps=" + root.gapsIn + "/" + root.gapsOut)
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
    // INIT (v6.16.3.2.1 — simplified)
    // The Connections{target:stateFile} block above now handles the
    // apply-vs-read decision. Component.onCompleted just kicks the
    // file load.
    // ─────────────────────────────────────────────────────────────

    Component.onCompleted: {
        stateFile.reload()
    }
}
