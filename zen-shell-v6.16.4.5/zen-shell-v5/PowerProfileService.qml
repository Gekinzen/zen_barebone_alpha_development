pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * PowerProfileService v6.16.0 — system power profile manager
 *
 * Wraps `powerprofilesctl` (power-profiles-daemon) on distros that
 * ship it (CachyOS, Arch with power-profiles-daemon installed,
 * Fedora, Ubuntu, etc).
 *
 * Profiles: "power-saver" | "balanced" | "performance"
 *
 * Behavior:
 *   - On startup: polls current profile with `powerprofilesctl get`
 *   - On setProfile(): fires `powerprofilesctl set <profile>`, re-polls,
 *     emits swaync notification, persists choice to SettingsStateV2.
 *   - If powerprofilesctl is NOT installed, `available` stays false and
 *     UI pages hide the section. No crash.
 *   - Persisted choice reapplies on every login via
 *     ~/.local/bin/zen-power-profile-restore.sh (triggered by
 *     autostart.conf), so "kapag nag restart ng pc dapat applied padin"
 *     is covered at the system level too, not just QML.
 *
 * Used by: ControlPanel (quick toggle), SystemSettingsPage, Battery module.
 *
 * Wala tayong babawasan.
 */
Singleton {
    id: root

    // ── State ──
    property bool available: false            // is powerprofilesctl installed?
    property string currentProfile: "balanced"
    property var availableProfiles: ["power-saver", "balanced", "performance"]

    // v6.16.1: Gaming Boost — toggleable "go fast now" mode.
    //   When ON:
    //     - powerprofilesctl set performance
    //     - Hyprland: disable blur + inactive dimming (GPU savings)
    //     - Hyprland: disable animations (subjective preference — can
    //       be turned off via setGamingBoostAnimations(true))
    //   When OFF:
    //     - Restore saved pre-boost profile
    //     - Re-enable blur + dim + animations (from SettingsStateV2 values)
    //
    // Remembers the profile that was active BEFORE boost so turning
    // boost off returns to whatever the user had (balanced, power-saver,
    // or even custom). Persists across shell restarts via SettingsStateV2.
    property bool gamingBoostActive: false
    property string _preBoostProfile: ""

    // ── Labels (for UI) ──
    function profileLabel(p) {
        switch(p) {
            case "power-saver":  return "Power Saver"
            case "balanced":     return "Balanced"
            case "performance":  return "Performance"
        }
        return p
    }

    function profileIcon(p) {
        switch(p) {
            case "power-saver":  return "\uf06c"   // fa-leaf
            case "balanced":     return "\uf24e"   // fa-balance-scale
            case "performance":  return "\uf0e7"   // fa-bolt
        }
        return "\uf2db"
    }

    // ── Availability probe ──
    Process {
        id: probe
        command: ["bash", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && echo yes || echo no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                root.available = (t === "yes")
                if (root.available) {
                    refresh()
                } else {
                    console.log("[PowerProfileService] powerprofilesctl not installed — disabled")
                }
            }
        }
    }

    // ── Read current profile ──
    Process {
        id: reader
        command: ["powerprofilesctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim()
                if (p === "power-saver" || p === "balanced" || p === "performance") {
                    root.currentProfile = p
                }
            }
        }
    }

    function refresh() {
        if (!root.available) return
        reader.running = true
    }

    // ── Set profile + notify ──
    Process {
        id: setter
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // Re-read actual current profile (source of truth)
                Qt.callLater(root.refresh)
            }
        }
    }

    Process { id: notifier; running: false }

    function setProfile(profile) {
        if (!root.available) {
            console.warn("[PowerProfileService] powerprofilesctl not available")
            return
        }
        if (profile !== "power-saver" && profile !== "balanced" && profile !== "performance") {
            console.warn("[PowerProfileService] Invalid profile:", profile)
            return
        }

        // Fire-and-forget via bash so a failure in setter doesn't poison Qt
        setter.command = ["bash", "-c", "powerprofilesctl set " + profile]
        setter.running = true

        // Optimistically update UI while re-read is pending
        root.currentProfile = profile

        // Persist to SettingsStateV2 so it survives restarts
        if (typeof SettingsStateV2 !== "undefined") {
            SettingsStateV2.powerProfile = profile
            SettingsStateV2.markDirty()
        }

        // swaync notification
        const icon = profileIcon(profile)
        const label = profileLabel(profile)
        notifier.command = ["bash", "-c",
            "notify-send -a 'Zen Shell' -i battery " +
            "'Power Profile' 'Switched to " + label + "'"]
        notifier.running = true
    }

    // ── Init ──
    Component.onCompleted: {
        probe.running = true
        // v6.16.1: Restore gaming boost state from SettingsStateV2 if it
        // was active when the shell last exited. Delay 1s so SettingsStateV2
        // has time to load from JSON first.
        restoreBoostTimer.start()
    }

    Timer {
        id: restoreBoostTimer
        interval: 1200
        running: false
        repeat: false
        onTriggered: {
            if (typeof SettingsStateV2 === "undefined") return
            if (!SettingsStateV2.gamingBoostActive) return
            if (!root.available) return  // ppd not installed, skip silently
            // Restore the pre-boost profile memory + flag, then re-apply
            root._preBoostProfile = SettingsStateV2.gamingBoostPreProfile || "balanced"
            root.gamingBoostActive = true
            // Re-assert Performance + compositor settings
            boostProc.command = ["bash", "-c",
                "powerprofilesctl set performance; "
                + "hyprctl --batch \""
                + "keyword decoration:blur:enabled false;"
                + "keyword decoration:dim_inactive false;"
                + "keyword animations:enabled 0\""]
            boostProc.running = true
            console.log("[PowerProfileService] Restored gaming boost from previous session")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // v6.16.1: Gaming Boost
    // ─────────────────────────────────────────────────────────────
    // toggleGamingBoost() — flips the boost state.
    // setGamingBoost(bool) — explicit set.
    //
    // On: saves current profile, forces Performance, disables
    //     expensive compositor effects (blur + inactive_dim).
    // Off: restores saved profile, re-applies user's blur/dim
    //      settings from SettingsStateV2 so nothing is lost.
    //
    // Uses hyprctl --batch for atomic apply. All state transitions
    // emit a swaync notification with 🎮 icon.

    Process { id: boostProc; running: false }

    function toggleGamingBoost() {
        setGamingBoost(!gamingBoostActive)
    }

    function setGamingBoost(enable) {
        if (!root.available && enable) {
            console.warn("[PowerProfileService] Cannot enable gaming boost — "
                         + "powerprofilesctl not available")
            notifier.command = ["bash", "-c",
                "notify-send -a 'Zen Shell' -i dialog-warning " +
                "'Gaming Boost' 'powerprofilesctl not installed'"]
            notifier.running = true
            return
        }

        if (enable && !gamingBoostActive) {
            // ── TURN ON ──
            _preBoostProfile = currentProfile || "balanced"
            if (typeof SettingsStateV2 !== "undefined") {
                SettingsStateV2.gamingBoostPreProfile = _preBoostProfile
                SettingsStateV2.gamingBoostActive = true
                SettingsStateV2.markDirty()
            }

            // Performance profile + compositor tuning
            var batch = "powerprofilesctl set performance; "
                      + "hyprctl --batch \""
                      + "keyword decoration:blur:enabled false;"
                      + "keyword decoration:dim_inactive false;"
                      + "keyword animations:enabled 0"
                      + "\""
            boostProc.command = ["bash", "-c", batch]
            boostProc.running = true

            gamingBoostActive = true
            currentProfile = "performance"

            notifier.command = ["bash", "-c",
                "notify-send -a 'Zen Shell' -i input-gaming -u normal " +
                "'🎮 Gaming Boost ON' " +
                "'Performance mode + effects off for max FPS.\nPrevious: "
                + _preBoostProfile + "'"]
            notifier.running = true

        } else if (!enable && gamingBoostActive) {
            // ── TURN OFF ──
            var restore = _preBoostProfile || "balanced"

            // Restore compositor settings from SettingsStateV2
            var blurOn = true, dimOn = false, animOn = true
            if (typeof SettingsStateV2 !== "undefined") {
                blurOn = SettingsStateV2.blurEnabled
                dimOn  = SettingsStateV2.dimInactive
                animOn = true  // animations always come back on
                SettingsStateV2.gamingBoostActive = false
                SettingsStateV2.markDirty()
            }

            var batch2 = "powerprofilesctl set " + restore + "; "
                       + "hyprctl --batch \""
                       + "keyword decoration:blur:enabled " + (blurOn ? "true" : "false") + ";"
                       + "keyword decoration:dim_inactive " + (dimOn ? "true" : "false") + ";"
                       + "keyword animations:enabled 1"
                       + "\""
            boostProc.command = ["bash", "-c", batch2]
            boostProc.running = true

            gamingBoostActive = false
            currentProfile = restore

            notifier.command = ["bash", "-c",
                "notify-send -a 'Zen Shell' -i input-gaming -u low " +
                "'Gaming Boost OFF' 'Restored " + restore + " + effects'"]
            notifier.running = true
        }
    }
}
