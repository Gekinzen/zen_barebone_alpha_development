pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * BatteryHealthService v7.0.0-alpha.15 — Karui (軽い)
 *
 * Reads battery health metrics from /sys/class/power_supply.
 * Exposes current capacity vs design capacity, charge cycles,
 * estimated wear percentage, and time-to-empty / time-to-full.
 *
 * Refreshes every 60 seconds (battery health changes slowly).
 *
 * Public API:
 *   readonly designFullUah: int       — original design capacity
 *   readonly currentFullUah: int      — current full charge capacity
 *   readonly wearPercent: real        — 0-100, lower = healthier
 *   readonly cycleCount: int          — charge cycles
 *   readonly chargeNowUah: int
 *   readonly currentDrawUa: int       — negative when charging
 *   readonly timeToEmptyHours: real
 *   readonly timeToFullHours: real
 *   readonly health: string           — "Excellent" | "Good" | "Fair" | "Poor"
 *
 * Wala tayong babawasan. Used by BatterySettingsPage to display
 * battery health card. Doesn't override any existing service.
 */
Singleton {
    id: root

    readonly property string batteryPath: "/sys/class/power_supply/BAT0"

    property int  designFullUah: 0
    property int  currentFullUah: 0
    property int  chargeNowUah: 0
    property int  currentDrawUa: 0
    property int  cycleCount: 0
    property bool present: false

    readonly property real wearPercent: {
        if (!designFullUah || designFullUah === 0) return 0
        return Math.max(0, (1 - currentFullUah / designFullUah) * 100)
    }

    readonly property string health: {
        if (!present) return "Unknown"
        if (wearPercent < 5)  return "Excellent"
        if (wearPercent < 15) return "Good"
        if (wearPercent < 30) return "Fair"
        return "Poor"
    }

    readonly property real timeToEmptyHours: {
        if (currentDrawUa <= 0) return 0
        return chargeNowUah / currentDrawUa
    }

    readonly property real timeToFullHours: {
        if (currentDrawUa >= 0) return 0
        const remaining = currentFullUah - chargeNowUah
        return remaining / Math.abs(currentDrawUa)
    }

    // ─────────────────────────────────────────────────────────────
    // POLLER
    // ─────────────────────────────────────────────────────────────
    Timer {
        interval: 60000   // 1min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refresh()
    }

    Process {
        id: refresher
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function _refresh() {
        const path = root.batteryPath
        const cmd =
            "[ -d '" + path + "' ] && " +
            "for f in charge_full_design charge_full charge_now current_now cycle_count; do " +
            "  v=$(cat '" + path + "/'$f 2>/dev/null || echo 0); " +
            "  echo $f=$v; " +
            "done || echo present=false"
        refresher.command = ["bash", "-c", cmd]
        refresher.running = true
    }

    function _parse(text) {
        if (!text || text.indexOf("present=false") >= 0) {
            root.present = false
            return
        }
        root.present = true

        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const eq = lines[i].indexOf("=")
            if (eq < 0) continue
            const k = lines[i].substring(0, eq)
            const v = parseInt(lines[i].substring(eq + 1)) || 0

            switch (k) {
                case "charge_full_design": root.designFullUah = v; break
                case "charge_full":         root.currentFullUah = v; break
                case "charge_now":          root.chargeNowUah = v; break
                case "current_now":         root.currentDrawUa = v; break
                case "cycle_count":         root.cycleCount = v; break
            }
        }
    }
}
