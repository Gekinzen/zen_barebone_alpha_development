pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DarkModeService — Modori v6.16.4.12.9.8
 *
 * Reactive QML wrapper around `~/.local/bin/zen-darkmode.sh`.
 *
 * Responsibilities:
 *   - Probe current state at startup (reads ~/.local/share/zen-shell/
 *     darkmode.state, falls back to gsettings if state file missing).
 *   - Expose `isDark` boolean — reactive, updates whenever state changes.
 *   - Provide `toggle()` / `setDark(bool)` methods that spawn the
 *     script, then re-probe to confirm the new state landed.
 *
 * The script is the source of truth for application: it handles
 * gsettings + GTK3 settings.ini + GTK4 settings.ini + state-file
 * persistence atomically. This QML singleton just reads + dispatches.
 */
Singleton {
    id: root

    // ───── Public state ─────
    property bool isDark: false
    property bool available: true   // false only if script missing
    property bool busy: false       // true while toggle is in flight

    signal toggled(bool nowDark)

    readonly property string scriptPath:
        (Quickshell.env("HOME") || "") + "/.local/bin/zen-darkmode.sh"

    // ───── Initial probe at startup ─────
    Component.onCompleted: {
        probeAvailability.running = true
    }

    // Probe whether the script exists. If it does, run a state read.
    Process {
        id: probeAvailability
        command: ["bash", "-c", "test -x \"$HOME/.local/bin/zen-darkmode.sh\" && echo yes || echo no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes") {
                    root.available = true
                    stateReader.running = true
                } else {
                    root.available = false
                    console.warn("[DarkModeService] zen-darkmode.sh not found at " + root.scriptPath)
                }
            }
        }
    }

    // Read current state via the script. Result is "dark" or "light".
    Process {
        id: stateReader
        command: ["bash", "-c", "$HOME/.local/bin/zen-darkmode.sh state"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim()
                root.isDark = (v === "dark")
                root.busy = false
                console.log("[DarkModeService] state probed → " + v)
            }
        }
    }

    // Apply a specific mode. Wraps the script's "dark" / "light" args.
    Process {
        id: applier
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // Re-probe after the script returns. The script echoes the
                // applied mode on stdout, but we trust the script's own
                // state-file write for the source of truth.
                stateReader.running = true
            }
        }
    }

    // ───── Public API ─────

    function setDark(targetDark) {
        if (!available || busy) return
        if (root.isDark === targetDark) return   // no-op
        busy = true
        applier.command = ["bash", "-c",
            "$HOME/.local/bin/zen-darkmode.sh " + (targetDark ? "dark" : "light")]
        applier.running = true
        // Optimistically update for snappy UI; stateReader confirms after.
        root.isDark = targetDark
        toggled(targetDark)
    }

    function toggle() {
        setDark(!root.isDark)
    }
}
