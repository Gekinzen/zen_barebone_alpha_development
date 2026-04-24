pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DarkModeService v6.16.4.7 — unified dark/light mode state
 *
 * Surfaces a single reactive `isDark` boolean to the rest of the
 * shell, driven by ~/.local/bin/zen-darkmode.sh. Components bind
 * to DarkModeService.isDark and call toggle() / setDark(bool) to
 * flip it.
 *
 * The actual work (gsettings, GTK3/4 settings.ini, libadwaita
 * color-scheme) lives in zen-darkmode.sh — this singleton is just
 * the reactive bridge.
 *
 * Initial state is probed on load via `zen-darkmode.sh status`.
 */
Singleton {
    id: root

    property bool isDark: true   // conservative default until probe resolves
    property bool available: true // false if script is missing

    // ── Initial probe on load ──────────────────────────────────
    Process {
        id: probeProc
        running: true
        command: ["bash", "-c",
            "~/.local/bin/zen-darkmode.sh status 2>/dev/null || echo dark"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                if (s === "dark" || s === "light") {
                    root.isDark = (s === "dark")
                } else {
                    // Script missing or failed — disable UI surface
                    root.available = false
                }
            }
        }
    }

    // ── Applier process (reused for each toggle) ───────────────
    Process {
        id: applyProc
        running: false
    }

    // ── Public API ─────────────────────────────────────────────
    function toggle() {
        setDark(!root.isDark)
    }

    function setDark(wantDark) {
        const mode = wantDark ? "dark" : "light"
        // Optimistic update — UI feels instant, actual gsettings
        // call finishes in the background
        root.isDark = wantDark
        applyProc.command = ["bash", "-c",
            "~/.local/bin/zen-darkmode.sh " + mode]
        applyProc.running = true
    }
}
