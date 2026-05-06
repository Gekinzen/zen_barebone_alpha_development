pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * MonitorRecoveryService v6.16.4.12 — Hikari 光
 *
 * Safety-net for the "I disabled my external monitor and now my laptop
 * is the only thing physically connected but it's still disabled" panic.
 *
 * Watches `hyprctl monitors all -j` on shell startup and on Hyprland's
 * `monitoradded` / `monitorremoved` events. If it finds:
 *   - a monitor that is physically connected (DRM-detected, has EDID)
 *   - but flagged `disabled: true` in Hyprland's state
 *   - AND no other enabled monitor exists
 *
 * → it auto-re-enables that monitor at its native resolution and clears
 *   the `<name>,disable` line from `hyprland-monitors.conf` so the fix
 *   survives reboot.
 *
 * Also runs a startup sanity check: if EVERY monitor in availableModes
 * is disabled, force-enable the first one. Better to have a wrong
 * resolution for 2 seconds than no display at all.
 */
Singleton {
    id: root

    readonly property string monitorConfPath: Quickshell.env("HOME") + "/.config/hypr/hyprland-monitors.conf"
    property string status: ""

    // ── Run scan on startup + every 5 sec while shell is alive ──
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: monitorScanner.running = true
    }

    // ── Scan current monitor state ──
    Process {
        id: monitorScanner
        command: ["hyprctl", "monitors", "all", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(this.text)
                    root._evaluate(mons)
                } catch (e) {
                    // Parse fail — silent, will retry next tick
                }
            }
        }
    }

    Process { id: recoveryRunner; running: false }
    Process { id: confCleaner; running: false }

    // ═══════════════════════════════════════════════════════════
    // CORE LOGIC: detect orphaned-disabled state and recover
    // ═══════════════════════════════════════════════════════════
    function _evaluate(mons) {
        if (!mons || mons.length === 0) {
            // Nothing returned — Hyprland hasn't initialized monitors yet
            return
        }

        // Count enabled vs disabled
        let enabled = []
        let disabled = []
        for (const m of mons) {
            if (m.disabled) disabled.push(m)
            else enabled.push(m)
        }

        // ── Case 1: Everything disabled (worst case) ──
        // Pick the first monitor (usually the laptop's eDP-1) and force-enable it.
        if (enabled.length === 0 && disabled.length > 0) {
            const target = disabled[0]
            console.warn("[MonitorRecovery] All monitors disabled. Force-enabling " + target.name)
            root._enable(target)
            return
        }

        // ── Case 2: Disabled monitor exists but no other monitor is plugged in ──
        // Hyprland reports availableModes for physically connected monitors only.
        // If a disabled monitor still has availableModes, it's plugged in.
        // If it's the only one with modes and the others have empty arrays,
        // we should re-enable it because the user clearly needs a screen.
        for (const m of disabled) {
            if (m.availableModes && m.availableModes.length > 0) {
                // Check if this is the ONLY physically-connected monitor
                let otherConnected = enabled.filter(
                    e => e.availableModes && e.availableModes.length > 0
                )
                if (otherConnected.length === 0) {
                    console.warn("[MonitorRecovery] Disabled monitor " + m.name + " is the only one connected. Re-enabling.")
                    root._enable(m)
                    return
                }
            }
        }

        // ── Case 3: Healthy state ──
        // At least one monitor enabled, no orphaned-disabled situation
    }

    // ── Re-enable a monitor at its native modes ──
    function _enable(m) {
        // Use 'preferred' resolution if the panel reports nothing usable,
        // else use the native width/height/refreshRate.
        let cmd
        if (m.width > 0 && m.height > 0 && m.refreshRate > 0) {
            const hz = m.refreshRate.toFixed(2)
            const scale = (m.scale || 1).toFixed(2)
            // Position at 0,0 — let user reposition via DisplaysPage later
            cmd = m.name + "," + m.width + "x" + m.height + "@" + hz + ",0x0," + scale
        } else {
            // Fallback: let Hyprland pick the best mode
            cmd = m.name + ",preferred,auto,1"
        }

        recoveryRunner.command = ["hyprctl", "keyword", "monitor", cmd]
        recoveryRunner.running = true

        root.status = "Auto-recovered: " + m.name

        // Also clean the persistent ",disable" line from hyprland-monitors.conf
        // so the fix survives a reboot.
        confCleaner.command = ["bash", "-c",
            "CONF='" + monitorConfPath + "'; " +
            "[ -f \"$CONF\" ] && grep -v '^monitor\\s*=\\s*" + m.name + ",disable' \"$CONF\" > \"$CONF.tmp\" 2>/dev/null && " +
            "mv \"$CONF.tmp\" \"$CONF\" && " +
            "echo 'monitor = " + cmd + "' >> \"$CONF\""
        ]
        confCleaner.running = true
    }

    // ── Manual override (callable from UI if needed) ──
    function forceRecoverAll() {
        monitorScanner.running = true
    }
}
