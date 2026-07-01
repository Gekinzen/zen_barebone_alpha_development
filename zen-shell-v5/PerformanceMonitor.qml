pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * PerformanceMonitor v7.0.0-beta.1 — Karui (軽い)
 *
 * Lightweight self-diagnostics for the shell. Tracks frame timing
 * approximation, memory usage, and surfaces a "shell health" status
 * users can toggle on for troubleshooting.
 *
 * Polls every 5 seconds. Memory read from /proc/<self>/status.
 * Surface: ControlPanel diagnostics tile (alpha.13+).
 *
 * No-cost when disabled (timer not running). Fully passive — never
 * mutates anything, just measures.
 */
Singleton {
    id: root

    property bool enabled: false      // off by default — user toggles in Settings → System

    // ─────────────────────────────────────────────────────────────
    // METRICS
    // ─────────────────────────────────────────────────────────────
    property int memRssMb: 0          // shell's RSS in MB
    property int memVszMb: 0          // virtual size MB
    property int qmlObjectCount: 0    // approximate object count

    // Health: compound metric
    readonly property string health: {
        if (memRssMb > 600) return "High memory"
        if (memRssMb > 350) return "Normal"
        return "Healthy"
    }

    readonly property color healthColor: {
        if (memRssMb > 600) return ThemeService.red
        if (memRssMb > 350) return ThemeService.yellow
        return ThemeService.green
    }

    // ─────────────────────────────────────────────────────────────
    // POLLER
    // ─────────────────────────────────────────────────────────────
    Timer {
        interval: 5000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refresh()
    }

    Process {
        id: poller
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function _refresh() {
        // Read shell PID's status — assumes single quickshell with name "zen-shell"
        const cmd =
            "pid=$(pgrep -nf 'quickshell.*zen-shell' || pgrep -n quickshell || echo 0); " +
            "[ \"$pid\" != \"0\" ] && grep -E '^(VmRSS|VmSize):' /proc/$pid/status 2>/dev/null || echo no-pid"
        poller.command = ["bash", "-c", cmd]
        poller.running = true
    }

    function _parse(text) {
        if (!text || text.indexOf("no-pid") >= 0) return
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(VmRSS|VmSize):\s+(\d+)\s+kB/)
            if (m) {
                const mb = Math.round(parseInt(m[2]) / 1024)
                if (m[1] === "VmRSS")  root.memRssMb = mb
                if (m[1] === "VmSize") root.memVszMb = mb
            }
        }
    }
}
