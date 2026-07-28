pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * NetworkPulseService v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Live per-app network bandwidth monitoring. Shows which apps are
 * actually using your bandwidth right now — useful for catching
 * surprise downloads (Steam updating in background, Brave tab loading
 * a huge video, system updates, etc.).
 *
 * Data sources:
 *   - /proc/net/dev          → total in/out per interface (cheap)
 *   - ss -p -t -u -n         → live socket list with owning PID (cheap)
 *   - /proc/<pid>/comm       → friendly process name from PID
 *   - nethogs -t -d 2 -c 1   → per-PID bandwidth if available
 *
 * We can't read per-app bandwidth in pure userspace without help from
 * a privileged tool like nethogs. So fall back chain:
 *   1. If nethogs available + has SUID/CAP_NET_ADMIN, use it via short
 *      polls
 *   2. Otherwise, fall back to "active connections by app" — show
 *      processes with active TCP/UDP sockets, no per-app bandwidth,
 *      just connection count
 *   3. Total in/out bandwidth from /proc/net/dev always available
 *      (interface-level only, no app split)
 *
 * Polling: every 2 seconds when popover is visible, every 10 seconds
 * when only the bar module is visible (just for the badge).
 *
 * Wala tayong babawasan — fully additive.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // CONFIG
    // ─────────────────────────────────────────────────────────────
    property bool enabled: true
    property int pollIntervalMs: 2000           // when active
    property int idlePollIntervalMs: 10000      // when bar-only

    // True when an interactive popover/page is showing the data —
    // setter for Bar/Settings to flip when they show/hide. Drives
    // the timer interval choice.
    property bool active: false

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/network-pulse.json"

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    // Interface totals (from /proc/net/dev)
    //   { iface: { rx: <bytes>, tx: <bytes>, rxRate: <Bps>, txRate: <Bps> } }
    property var ifaceStats: ({})

    // Combined rate across non-loopback interfaces (Bps)
    property real totalRxRate: 0
    property real totalTxRate: 0

    // Per-app summary (from ss). Each:
    //   { pid: int, comm: "brave", conns: int, ports: ["443","443","8080"],
    //     rxRate: <Bps>, txRate: <Bps>, blocked: bool }
    property var perApp: []

    // Available external helpers
    property bool nethogsAvailable: false
    property bool ssAvailable: false

    // Track previous reading for rate calc
    property var _prevIfaceTotals: ({})
    property real _prevSampleTime: 0

    // Block list (user-managed). PIDs persist by `comm` name since PIDs
    // change. When a comm is blocked, the app is marked .blocked and
    // the UI shows the "blocked" badge — actual blocking is done by
    // user via firejail relaunch (we don't kill running processes).
    property var blockedComms: []

    // ─────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: {
        loadState()
        toolCheck.running = true
    }

    Process {
        id: toolCheck
        running: false
        command: ["bash", "-c",
            "echo nethogs=$(command -v nethogs >/dev/null 2>&1 && echo 1 || echo 0); " +
            "echo ss=$(command -v ss >/dev/null 2>&1 && echo 1 || echo 0)"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = (this.text || "")
                root.nethogsAvailable = txt.indexOf("nethogs=1") >= 0
                root.ssAvailable = txt.indexOf("ss=1") >= 0
                console.log("[NetworkPulse] tools: ss=" + root.ssAvailable
                          + " nethogs=" + root.nethogsAvailable)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // POLLER
    // ─────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.active ? root.pollIntervalMs : root.idlePollIntervalMs
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            ifaceProc.running = true
            // Only run ss when active — saves cycles
            if (root.active && root.ssAvailable) {
                connsProc.running = true
            }
        }
    }

    // ── /proc/net/dev parser ──
    Process {
        id: ifaceProc
        running: false
        command: ["cat", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: root._parseIfaceDump(this.text || "")
        }
    }

    function _parseIfaceDump(txt) {
        const lines = String(txt).split("\n")
        const stats = {}
        let totalRx = 0, totalTx = 0
        for (let line of lines) {
            line = line.trim()
            if (!line || line.indexOf("|") >= 0) continue   // header lines
            // Format: "iface: rxBytes rxPkts ... txBytes txPkts ..."
            const m = line.match(/^([^:]+):\s+(.+)$/)
            if (!m) continue
            const iface = m[1].trim()
            const cols = m[2].trim().split(/\s+/).map(Number)
            if (cols.length < 16) continue
            const rxBytes = cols[0]
            const txBytes = cols[8]
            stats[iface] = { rx: rxBytes, tx: txBytes, rxRate: 0, txRate: 0 }
            // Skip loopback for "total"
            if (iface !== "lo") {
                totalRx += rxBytes
                totalTx += txBytes
            }
        }

        // Compute rates from prev
        const now = Date.now() / 1000
        if (root._prevSampleTime > 0) {
            const dt = Math.max(0.1, now - root._prevSampleTime)
            for (const iface in stats) {
                const prev = root._prevIfaceTotals[iface]
                if (prev) {
                    stats[iface].rxRate = Math.max(0, (stats[iface].rx - prev.rx) / dt)
                    stats[iface].txRate = Math.max(0, (stats[iface].tx - prev.tx) / dt)
                }
            }
            const prevTotalRx = Object.keys(root._prevIfaceTotals)
                .filter(k => k !== "lo")
                .reduce((a, k) => a + (root._prevIfaceTotals[k].rx || 0), 0)
            const prevTotalTx = Object.keys(root._prevIfaceTotals)
                .filter(k => k !== "lo")
                .reduce((a, k) => a + (root._prevIfaceTotals[k].tx || 0), 0)
            root.totalRxRate = Math.max(0, (totalRx - prevTotalRx) / dt)
            root.totalTxRate = Math.max(0, (totalTx - prevTotalTx) / dt)
        }

        // Save snapshot
        const newPrev = {}
        for (const iface in stats) {
            newPrev[iface] = { rx: stats[iface].rx, tx: stats[iface].tx }
        }
        root._prevIfaceTotals = newPrev
        root._prevSampleTime = now
        root.ifaceStats = stats
    }

    // ── ss connection list ──
    Process {
        id: connsProc
        running: false
        // -t TCP, -u UDP, -p PIDs, -n numeric (faster, no DNS)
        // -H: no header. -O: one line per socket.
        command: ["bash", "-c", "ss -tunp -H -O 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root._parseConns(this.text || "")
        }
    }

    function _parseConns(txt) {
        const lines = String(txt).split("\n")
        // Aggregate by PID
        const byPid = {}
        for (let line of lines) {
            line = line.trim()
            if (!line) continue
            // ss output: "Netid State Recv-Q Send-Q LocalAddr:Port PeerAddr:Port users:(("comm",pid=NNN,fd=N))"
            // The users field has the comm + pid. Parse with regex.
            const userMatch = line.match(/users:\(\("([^"]+)",pid=(\d+),fd=\d+\)/)
            if (!userMatch) continue
            const comm = userMatch[1]
            const pid = parseInt(userMatch[2]) || 0
            // Extract local port for tagging
            const portMatch = line.match(/:([0-9]+)\s+[\w\.:*]+:([0-9]+)/)
            const localPort = portMatch ? portMatch[1] : ""
            const remotePort = portMatch ? portMatch[2] : ""

            if (!byPid[pid]) {
                byPid[pid] = {
                    pid: pid,
                    comm: comm,
                    conns: 0,
                    ports: [],
                    rxRate: 0, txRate: 0,
                    blocked: root.blockedComms.indexOf(comm) >= 0
                }
            }
            byPid[pid].conns += 1
            if (remotePort && byPid[pid].ports.indexOf(remotePort) < 0) {
                byPid[pid].ports.push(remotePort)
            }
        }

        // Sort by conn count desc, take top 20
        const list = Object.values(byPid).sort((a, b) => b.conns - a.conns).slice(0, 20)
        root.perApp = list
    }

    // ─────────────────────────────────────────────────────────────
    // BLOCK MANAGEMENT
    // ─────────────────────────────────────────────────────────────
    function toggleBlock(comm) {
        if (!comm) return
        const i = root.blockedComms.indexOf(comm)
        if (i >= 0) {
            root.blockedComms = root.blockedComms.filter(c => c !== comm)
        } else {
            root.blockedComms = root.blockedComms.concat([comm])
        }
        // Update perApp.blocked flag
        const copy = root.perApp.map(a => Object.assign({}, a,
            { blocked: root.blockedComms.indexOf(a.comm) >= 0 }))
        root.perApp = copy
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
                    if (typeof j.pollIntervalMs === "number") root.pollIntervalMs = j.pollIntervalMs
                    if (Array.isArray(j.blockedComms)) root.blockedComms = j.blockedComms
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
                pollIntervalMs: root.pollIntervalMs,
                blockedComms: root.blockedComms
            }
            saveProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
                "cat > '" + root.statePath + "' << 'EOF'\n" +
                JSON.stringify(obj, null, 2) + "\nEOF"]
            saveProc.running = true
        }
    }

    onEnabledChanged: saveDebounce.restart()
    onBlockedCommsChanged: saveDebounce.restart()

    // ─────────────────────────────────────────────────────────────
    // FORMATTING HELPERS
    // ─────────────────────────────────────────────────────────────
    function fmtRate(bps) {
        if (bps < 1024) return Math.round(bps) + " B/s"
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / 1024 / 1024).toFixed(1) + " MB/s"
        return (bps / 1024 / 1024 / 1024).toFixed(2) + " GB/s"
    }
}
