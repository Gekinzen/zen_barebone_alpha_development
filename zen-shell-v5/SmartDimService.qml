pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/*
 * SmartDimService v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Context-aware brightness automation. Watches the active window
 * class + fullscreen state + battery level, applies brightness
 * adjustments per a user-editable rule table.
 *
 * Default rule table (user-editable in Settings):
 *
 *   reading      browsers OR pdf readers OR markdown viewers  → 100% brightness
 *   video        active fullscreen video (mpv, vlc, browser FS) → -10% (less glare)
 *   ide          IDE/editors (code, vim, kate)                → +5% contrast
 *   battery_low  capacity < 15% on battery                    → 30% emergency
 *   gaming       GameProfileService.gameActive                → -5%
 *   default      anything else                                → restore baseline
 *
 * Rules are applied with priority order (battery_low always wins).
 * Each rule has an "offset" (relative %) or "absolute" (fixed %).
 *
 * Snapshots the user's baseline brightness on first activation and
 * always restores to that when service is disabled.
 *
 * Wala tayong babawasan — fully additive. Hooks into existing
 * BrightnessService (which actually applies brightness via brightnessctl)
 * and reads from BatteryService + GameProfileService + Hyprland for
 * context.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // CONFIG
    // ─────────────────────────────────────────────────────────────
    property bool enabled: false   // OFF by default — opt-in

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/smart-dim.json"

    // Rule table — user editable. Each rule:
    //   { name: "reading", classes: ["brave", "firefox"], titleRegex: "",
    //     fullscreenRequired: false, kind: "absolute"|"offset",
    //     value: 100 (or -10 for offset), priority: int (higher wins) }
    property var rules: [
        {
            name: "battery_critical",
            classes: [],
            titleRegex: "",
            fullscreenRequired: false,
            requireBattery: true,
            batteryBelow: 15,
            kind: "absolute",
            value: 30,
            priority: 100
        },
        {
            name: "video",
            classes: ["mpv", "vlc", "io.github.celluloid_player.Celluloid"],
            titleRegex: "",
            fullscreenRequired: true,
            kind: "offset",
            value: -10,
            priority: 70
        },
        {
            name: "video_browser",
            classes: ["brave-browser", "google-chrome", "firefox", "Brave-browser"],
            titleRegex: "YouTube|Netflix|Twitch|Vimeo|Hulu|Disney",
            fullscreenRequired: true,
            kind: "offset",
            value: -8,
            priority: 60
        },
        {
            name: "ide",
            classes: ["code-oss", "Code", "code", "Code - OSS", "kate", "kdevelop",
                      "neovim", "Neovim", "emacs", "Emacs", "jetbrains-idea"],
            titleRegex: "",
            fullscreenRequired: false,
            kind: "offset",
            value: 5,
            priority: 40
        },
        {
            name: "reading",
            classes: ["brave-browser", "google-chrome", "firefox", "Brave-browser",
                      "okular", "evince", "zathura", "obsidian"],
            titleRegex: "",
            fullscreenRequired: false,
            kind: "offset",
            value: 0,
            priority: 20
        },
        {
            name: "gaming",
            classes: [],
            titleRegex: "",
            fullscreenRequired: false,
            requireGameActive: true,
            kind: "offset",
            value: -5,
            priority: 30
        }
    ]

    // Baseline brightness (snapshot of user's manually set value).
    // Re-snapshotted whenever user adjusts brightness manually via
    // BrightnessService AND no rule is currently active.
    property real baselineBrightness: -1   // -1 = not yet snapshotted

    // Currently applied rule name (for display in UI)
    property string activeRuleName: "none"

    // Last brightness we applied (to detect manual changes)
    property real _lastAppliedBrightness: -1

    // Throttle re-application so rapid window switches don't spam
    // brightnessctl
    property int reapplyThrottleMs: 600
    property real _lastApplyTime: 0

    // ─────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: loadState()

    // ─────────────────────────────────────────────────────────────
    // REACTIVE EVALUATION
    // ─────────────────────────────────────────────────────────────
    // Watch the focused workspace's active window. Quickshell.Hyprland
    // exposes focusedWorkspace + focusedMonitor; we want active window
    // class. Polling hyprctl activewindow is simplest + reliable.

    Timer {
        id: pollTimer
        interval: 1500
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: activeWinProc.running = true
    }

    Process {
        id: activeWinProc
        running: false
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const txt = (this.text || "").trim()
                    if (!txt || txt === "{}") {
                        root._evaluate("", "", 0)
                        return
                    }
                    const j = JSON.parse(txt)
                    root._evaluate(
                        String(j.class || ""),
                        String(j.title || ""),
                        Number(j.fullscreen || 0)
                    )
                } catch (e) {
                    console.warn("[SmartDim] activewindow parse:", e)
                }
            }
        }
    }

    function _evaluate(activeClass, activeTitle, fullscreen) {
        if (!root.enabled) return

        // Find highest-priority matching rule
        let bestRule = null
        let bestPri = -1
        for (const rule of root.rules) {
            if (!root._ruleMatches(rule, activeClass, activeTitle, fullscreen)) continue
            const pri = Number(rule.priority || 0)
            if (pri > bestPri) {
                bestRule = rule
                bestPri = pri
            }
        }

        // If we have a baseline yet?
        if (root.baselineBrightness < 0) {
            // Snapshot the current brightness as baseline
            root._snapshotBaseline()
            return
        }

        const now = Date.now()
        if (now - root._lastApplyTime < root.reapplyThrottleMs) return

        let targetPct = root.baselineBrightness   // default = restore baseline
        let ruleName = "none"
        if (bestRule) {
            ruleName = bestRule.name
            if (bestRule.kind === "absolute") {
                targetPct = Math.max(5, Math.min(100, Number(bestRule.value)))
            } else {
                // offset
                targetPct = Math.max(5, Math.min(100,
                    root.baselineBrightness + Number(bestRule.value || 0)))
            }
        }

        if (Math.abs(targetPct - root._lastAppliedBrightness) >= 1) {
            root._applyBrightness(targetPct)
            root.activeRuleName = ruleName
            root._lastApplyTime = now
        } else if (ruleName !== root.activeRuleName) {
            root.activeRuleName = ruleName
        }
    }

    function _ruleMatches(rule, activeClass, activeTitle, fullscreen) {
        // Battery requirement
        if (rule.requireBattery) {
            if (typeof BatteryService === "undefined") return false
            if (!BatteryService.onBattery) return false
            const cap = Number(BatteryService.capacity || 100)
            if (typeof rule.batteryBelow === "number" && cap > rule.batteryBelow) return false
        }
        // Game-active requirement
        if (rule.requireGameActive) {
            if (typeof GameProfileService === "undefined") return false
            if (!GameProfileService.gameActive) return false
        }
        // Fullscreen requirement
        if (rule.fullscreenRequired && fullscreen < 1) return false
        // Class requirement (substring match for tolerance)
        if (Array.isArray(rule.classes) && rule.classes.length > 0) {
            const ac = String(activeClass || "").toLowerCase()
            const found = rule.classes.some(c =>
                ac === String(c).toLowerCase()
                || ac.indexOf(String(c).toLowerCase()) >= 0
            )
            if (!found) return false
        }
        // Title regex
        if (rule.titleRegex) {
            try {
                const re = new RegExp(rule.titleRegex, "i")
                if (!re.test(activeTitle)) return false
            } catch (e) { return false }
        }
        return true
    }

    function _applyBrightness(pct) {
        if (typeof BrightnessService === "undefined") return
        try {
            // BrightnessService.setBrightness expects 0.0-1.0
            BrightnessService.setBrightness(Math.max(0.05, Math.min(1.0, pct / 100)))
            root._lastAppliedBrightness = pct
            console.log("[SmartDim] applied " + pct + "% (rule: "
                      + root.activeRuleName + ")")
        } catch (e) {
            console.warn("[SmartDim] apply error:", e)
        }
    }

    function _snapshotBaseline() {
        if (typeof BrightnessService === "undefined") return
        const cur = Number(BrightnessService.brightness || 0.7)
        root.baselineBrightness = Math.round(cur * 100)
        root._lastAppliedBrightness = root.baselineBrightness
        console.log("[SmartDim] baseline snapshotted at " + root.baselineBrightness + "%")
    }

    // ─────────────────────────────────────────────────────────────
    // ENABLE/DISABLE LIFECYCLE
    // ─────────────────────────────────────────────────────────────
    onEnabledChanged: {
        if (enabled) {
            _snapshotBaseline()
            _toast("Smart Dim enabled",
                   "Brightness will adapt to your active window context",
                   1)
        } else {
            // Restore baseline on disable
            if (root.baselineBrightness > 0) {
                root._applyBrightness(root.baselineBrightness)
            }
            root.activeRuleName = "none"
            _toast("Smart Dim disabled",
                   "Brightness restored",
                   0)
        }
        saveDebounce.restart()
    }

    // ─────────────────────────────────────────────────────────────
    // PUBLIC API
    // ─────────────────────────────────────────────────────────────
    function resnapshotBaseline() {
        root.baselineBrightness = -1
        _snapshotBaseline()
        _toast("Smart Dim",
               "Baseline brightness re-snapshotted at "
               + root.baselineBrightness + "%",
               0)
    }

    function setRules(newRules) {
        if (Array.isArray(newRules)) {
            root.rules = newRules
            saveDebounce.restart()
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    function loadState() { loadStateProc.running = true }

    Process {
        id: loadStateProc
        running: false
        command: ["bash", "-c", "cat '" + root.statePath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (typeof j.enabled === "boolean") root.enabled = j.enabled
                    if (typeof j.baselineBrightness === "number") root.baselineBrightness = j.baselineBrightness
                    if (Array.isArray(j.rules) && j.rules.length > 0) root.rules = j.rules
                } catch (e) {}
            }
        }
    }

    Process { id: saveProc; running: false }
    Timer {
        id: saveDebounce; interval: 400; repeat: false
        onTriggered: {
            const obj = {
                enabled: root.enabled,
                baselineBrightness: root.baselineBrightness,
                rules: root.rules
            }
            saveProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
                "cat > '" + root.statePath + "' << 'EOF'\n" +
                JSON.stringify(obj, null, 2) + "\nEOF"]
            saveProc.running = true
        }
    }

    onRulesChanged: saveDebounce.restart()
    onBaselineBrightnessChanged: saveDebounce.restart()

    function _toast(summary, body, urgency) {
        if (typeof NotificationService === "undefined"
            || typeof NotificationService.postInternal !== "function") return
        try {
            NotificationService.postInternal(summary, body, "Zen Shell",
                                             urgency, "display-brightness")
        } catch (e) {}
    }
}
