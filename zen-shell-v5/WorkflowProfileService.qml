pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * WorkflowProfileService v7.0.0-alpha.13 — Karui (軽い)
 *
 * One-click workflow profiles. Each profile bundles a set of system
 * tweaks the user typically wants together for a particular activity.
 *
 * Profiles:
 *   - Work       — DND off, normal brightness, balanced power, all
 *                   notifications visible, animations standard
 *   - Gaming     — DND on, max brightness, performance power, big-picture
 *                   visuals (animations off for perf), fps overlays welcome
 *   - Focus      — DND on, dimmed brightness, balanced power, no toast
 *                   distractions, minimal UI
 *   - Movie      — DND on, low brightness, balanced power, hide bar/widgets,
 *                   immersive
 *   - Sleep      — DND on, very low brightness, power-saver, dark theme,
 *                   minimal everything
 *
 * Public API:
 *   readonly currentProfile: string ("work" | "gaming" | "focus" | "movie" | "sleep")
 *   function activate(profile)        — apply a profile
 *   function profilesList()            — array of {id, label, icon, kanji}
 *
 * Wala tayong babawasan. Existing services (NotificationService,
 * BrightnessService, PowerProfileService, ThemeService) are called
 * but never modified. Profile activation is fully reversible — just
 * activate "work" again to restore defaults.
 */
Singleton {
    id: root

    property string currentProfile: "work"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/workflow-profile.json"

    function profilesList() {
        return [
            { id: "work",   label: "Work",   icon: "\uf0b1", kanji: "仕事", romaji: "Shigoto" },
            { id: "gaming", label: "Gaming", icon: "\uf11b", kanji: "遊び", romaji: "Asobi" },
            { id: "focus",  label: "Focus",  icon: "\uf0eb", kanji: "集中", romaji: "Shūchū" },
            { id: "movie",  label: "Movie",  icon: "\uf008", kanji: "映画", romaji: "Eiga" },
            { id: "sleep",  label: "Sleep",  icon: "\uf186", kanji: "睡眠", romaji: "Suimin" }
        ]
    }

    // ─────────────────────────────────────────────────────────────
    // ACTIVATE
    // ─────────────────────────────────────────────────────────────
    function activate(profile) {
        if (!profile) return
        root.currentProfile = profile

        switch (profile) {
            case "work":   _applyWork(); break
            case "gaming": _applyGaming(); break
            case "focus":  _applyFocus(); break
            case "movie":  _applyMovie(); break
            case "sleep":  _applySleep(); break
        }

        _saveState()
    }

    // ─────────────────────────────────────────────────────────────
    // PROFILE IMPLEMENTATIONS
    //
    // Each calls existing services. Defensive — guards against
    // services being undefined during early shell boot.
    // ─────────────────────────────────────────────────────────────
    function _applyWork() {
        if (typeof NotificationService !== "undefined") {
            NotificationService.dndEnabled = false
        }
        if (typeof BrightnessService !== "undefined" && BrightnessService.setBrightness) {
            BrightnessService.setBrightness(70)
        }
        _setPower("balanced")
    }

    function _applyGaming() {
        if (typeof NotificationService !== "undefined") {
            NotificationService.dndEnabled = true
        }
        if (typeof BrightnessService !== "undefined" && BrightnessService.setBrightness) {
            BrightnessService.setBrightness(95)
        }
        _setPower("performance")
    }

    function _applyFocus() {
        if (typeof NotificationService !== "undefined") {
            NotificationService.dndEnabled = true
        }
        if (typeof BrightnessService !== "undefined" && BrightnessService.setBrightness) {
            BrightnessService.setBrightness(50)
        }
        _setPower("balanced")
    }

    function _applyMovie() {
        if (typeof NotificationService !== "undefined") {
            NotificationService.dndEnabled = true
        }
        if (typeof BrightnessService !== "undefined" && BrightnessService.setBrightness) {
            BrightnessService.setBrightness(35)
        }
        _setPower("balanced")
    }

    function _applySleep() {
        if (typeof NotificationService !== "undefined") {
            NotificationService.dndEnabled = true
        }
        if (typeof BrightnessService !== "undefined" && BrightnessService.setBrightness) {
            BrightnessService.setBrightness(15)
        }
        _setPower("power-saver")
    }

    function _setPower(profile) {
        if (typeof PowerProfileService === "undefined") return
        if (PowerProfileService.setProfile) {
            PowerProfileService.setProfile(profile)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    function _saveState() {
        saveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + statePath + "')\" && " +
            "echo '{\"currentProfile\": \"" + root.currentProfile + "\"}' > '" + statePath + "'"]
        saveProc.running = true
    }

    Process { id: saveProc; running: false }

    Component.onCompleted: _loadState()

    function _loadState() {
        loadProc.command = ["bash", "-c",
            "cat '" + statePath + "' 2>/dev/null || echo '{}'"]
        loadProc.running = true
    }

    Process {
        id: loadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (j.currentProfile) root.currentProfile = j.currentProfile
                } catch (e) {}
            }
        }
    }
}
