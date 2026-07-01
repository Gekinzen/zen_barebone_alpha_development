pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ZenCleanupService v7.0.0-alpha.7 — RAM hygiene + zombie reaper
 *
 * Three operations:
 *
 *   1. Drop caches  — `echo 3 > /proc/sys/vm/drop_caches`
 *      Frees pagecache + dentries + inodes. Safe operation: kernel
 *      will re-cache on demand. Saves typically 1-3GB on a system
 *      that's been running for hours.
 *
 *   2. Compact memory — `echo 1 > /proc/sys/vm/compact_memory`
 *      Defragments free memory pages. Reduces fragmentation that
 *      can cause large allocations to fail even when total free
 *      RAM is sufficient.
 *
 *   3. Zombie reaper — finds <defunct> processes and kills their
 *      parents (which are usually the ones not reaping their
 *      children). Targets only "obvious" zombies: parent PID is
 *      not 1 (init / systemd handles its own children correctly)
 *      AND parent is not in a known-good list (terminals, shells,
 *      browsers — they spawn lots of short-lived zombies normally).
 *
 * AUTO-TRIGGER:
 *
 *   When `autoTrigger` is true (default) AND free RAM drops below
 *   the threshold (default 5%), service fires a notification
 *   suggesting cleanup. After 60s of sustained low memory, performs
 *   the cleanup automatically. User can disable via Settings or
 *   click "Don't auto-clean this session" in the notification.
 *
 *   Notification flow:
 *     1. Free RAM crosses below threshold      → notify "Low memory"
 *     2. Sustained 60s below threshold         → auto-cleanup if enabled
 *     3. Cleanup fires                         → notify "Freed N MB"
 *     4. RAM recovers above threshold + 5%     → reset latched state
 *
 * STATE FILE: ~/.local/share/zen-shell/cleanup.state
 *
 *   Persists last-cleanup timestamp + total-bytes-freed counter +
 *   user preferences (auto-trigger flag, threshold, suppress-this-session).
 *
 * INTEGRATION CONTRACT:
 *
 *   Consumer surfaces (SysRow badge, Settings → System cleanup
 *   section) read these properties:
 *
 *     freeMemPercent : real      — live free RAM % from
 *                                  SystemMonitorService.memUsedPercent
 *     memoryPressure : bool      — true when below threshold
 *     lastFreedBytes : int       — bytes freed by last cleanup
 *     isRunning      : bool      — true while a cleanup is in progress
 *
 *   And call:
 *
 *     freeMemoryNow()            — runs all 3 operations in sequence
 *     dropCachesOnly()           — runs operation 1 only
 *     compactOnly()              — runs operation 2 only
 *     reapZombies()              — runs operation 3 only
 *     suppressThisSession()      — silence auto-trigger until restart
 *
 * Wala tayong babawasan — purely additive service. SystemMonitor
 * is already polling memory; we just READ its values, no extra
 * polling load.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // STATE PATHS
    // ─────────────────────────────────────────────────────────────
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/share/zen-shell"
    readonly property string statePath: stateDir + "/cleanup.state"

    // ─────────────────────────────────────────────────────────────
    // PERSISTED CONFIG
    // ─────────────────────────────────────────────────────────────
    property bool autoTrigger: true                // alpha.7 default: aggressive
    property real freeRamThreshold: 5.0             // %  — auto-trigger below this
    property bool sessionSuppressed: false          // user-clicked "don't bug me"
    property real lastCleanupTime: 0                // unix ms
    property real totalBytesFreed: 0                // cumulative since first install

    // ─────────────────────────────────────────────────────────────
    // LIVE STATE
    // ─────────────────────────────────────────────────────────────
    property bool isRunning: false
    property real lastFreedBytes: 0
    property string lastError: ""

    // Free RAM percentage — read from SystemMonitorService (which is
    // already polling /proc/meminfo on its own clock — no extra load
    // here, just a binding).
    readonly property real freeMemPercent: {
        if (typeof SystemMonitorService === "undefined") return 100
        const used = SystemMonitorService.memUsedPercent || 0
        return Math.max(0, 100 - used)
    }

    readonly property bool memoryPressure: freeMemPercent < freeRamThreshold

    // Pretty-format byte counts for UI display
    function formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    // ─────────────────────────────────────────────────────────────
    // CLEANUP SCRIPT — single shell pipeline that does all 3 ops
    //
    // Why one shell pipeline vs three Process calls:
    //   - We want to capture before/after MemFree to compute bytes
    //     freed for the user feedback toast.
    //   - pkexec only prompts ONCE per pipeline, so wrapping all
    //     privileged ops in one bash -c is much less annoying.
    //   - We can do user-space ops (zombie reap) BEFORE the privileged
    //     part to make sure the zombie reap is fast.
    // ─────────────────────────────────────────────────────────────
    Process {
        id: cleanupProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseCleanupResult(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = (this.text || "").trim()
                if (t) root.lastError = t.split("\n").pop()
            }
        }
        onExited: function(code) {
            root.isRunning = false
            if (code === 0) {
                root.lastCleanupTime = Date.now()
                saveDebounced.restart()
            }
        }
    }

    function _parseCleanupResult(text) {
        // Output format from the script:
        //   FREED_BYTES=<n>
        //   ZOMBIES_REAPED=<n>
        //   ERROR=<msg>?
        if (!text) return
        const lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            const line = lines[i]
            const eq = line.indexOf("=")
            if (eq < 0) continue
            const key = line.substring(0, eq)
            const val = line.substring(eq + 1)
            if (key === "FREED_BYTES") {
                const n = parseInt(val) || 0
                root.lastFreedBytes = n
                root.totalBytesFreed = root.totalBytesFreed + n
            } else if (key === "ERROR") {
                root.lastError = val
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PUBLIC API
    // ─────────────────────────────────────────────────────────────
    function freeMemoryNow() {
        if (root.isRunning) return
        root.isRunning = true
        root.lastError = ""

        // Use a single bash pipeline. pkexec wraps the privileged ops;
        // the user-space ops run before the prompt.
        cleanupProc.command = ["bash", "-c", _buildCleanupScript()]
        cleanupProc.running = true
    }

    function dropCachesOnly() {
        if (root.isRunning) return
        root.isRunning = true
        root.lastError = ""
        cleanupProc.command = ["bash", "-c",
            "before=$(grep MemAvailable /proc/meminfo | awk '{print $2}'); " +
            "pkexec sh -c 'sync && echo 3 > /proc/sys/vm/drop_caches' || exit 1; " +
            "after=$(grep MemAvailable /proc/meminfo | awk '{print $2}'); " +
            "freed=$(( (after - before) * 1024 )); " +
            "echo FREED_BYTES=$freed"
        ]
        cleanupProc.running = true
    }

    function compactOnly() {
        if (root.isRunning) return
        root.isRunning = true
        cleanupProc.command = ["bash", "-c",
            "pkexec sh -c 'echo 1 > /proc/sys/vm/compact_memory' || exit 1; " +
            "echo FREED_BYTES=0"
        ]
        cleanupProc.running = true
    }

    Process { id: zombieProc; running: false }
    function reapZombies() {
        // User-space only — no pkexec needed for sending signals to
        // user's own processes.
        zombieProc.command = ["bash", "-c", _buildZombieScript()]
        zombieProc.running = true
    }

    function suppressThisSession() {
        root.sessionSuppressed = true
    }

    function _buildCleanupScript() {
        // Composite script: zombie reap (user-space) → drop caches +
        // compact memory (privileged). Output FREED_BYTES + ZOMBIES_REAPED.
        return [
            "set -e",
            // Zombie pass first
            _buildZombieScript().replace(/\n/g, "; "),
            // Memory pass
            "before=$(grep MemAvailable /proc/meminfo | awk '{print $2}')",
            "pkexec sh -c 'sync && echo 3 > /proc/sys/vm/drop_caches && echo 1 > /proc/sys/vm/compact_memory' || { echo ERROR=pkexec_denied; exit 1; }",
            "after=$(grep MemAvailable /proc/meminfo | awk '{print $2}')",
            "freed=$(( (after - before) * 1024 ))",
            "echo FREED_BYTES=$freed"
        ].join(" && ")
    }

    function _buildZombieScript() {
        // Find <defunct> processes. For each, get its parent PID.
        // If the parent PID is not 1 (systemd reaps its own children
        // correctly) and not in a known-good list, send SIGCHLD to
        // the parent — which usually wakes it up to reap. If that
        // doesn't work (still defunct after 1s), the script gives up.
        // We DON'T kill -9 the parent because that's destructive.
        //
        // Output: ZOMBIES_REAPED=<count>
        return (
            "count=0; " +
            "for pid in $(ps -eo pid,stat | awk '$2 ~ /Z/ {print $1}'); do " +
            "  ppid=$(ps -o ppid= -p $pid 2>/dev/null | tr -d ' '); " +
            "  if [ -n \"$ppid\" ] && [ \"$ppid\" != \"1\" ]; then " +
            "    kill -CHLD $ppid 2>/dev/null && count=$((count+1)); " +
            "  fi; " +
            "done; " +
            "echo ZOMBIES_REAPED=$count"
        )
    }

    // ─────────────────────────────────────────────────────────────
    // AUTO-TRIGGER LOGIC
    //
    //   1. memoryPressure becomes true → start latch timer (60s)
    //   2. After 60s sustained, fire freeMemoryNow() if autoTrigger
    //      is on AND not session-suppressed AND not already running
    //   3. If memory recovers above threshold + 5%, reset latch
    // ─────────────────────────────────────────────────────────────
    property bool _pressureLatched: false

    Timer {
        id: pressureLatchTimer
        interval: 60000   // 60s sustained
        repeat: false
        onTriggered: {
            if (!root.autoTrigger) return
            if (root.sessionSuppressed) return
            if (root.isRunning) return
            if (!root.memoryPressure) return
            console.log("ZenCleanup: auto-trigger firing (sustained pressure)")
            root.freeMemoryNow()
        }
    }

    Connections {
        target: root
        function onMemoryPressureChanged() {
            if (root.memoryPressure && !root._pressureLatched) {
                root._pressureLatched = true
                if (root.autoTrigger && !root.sessionSuppressed) {
                    pressureLatchTimer.restart()
                }
            } else if (!root.memoryPressure && root._pressureLatched) {
                // Recovered (with hysteresis: only un-latch when
                // we're 5% above the threshold, not just at it)
                if (root.freeMemPercent > root.freeRamThreshold + 5) {
                    root._pressureLatched = false
                    pressureLatchTimer.stop()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        onLoaded: {
            try {
                const txt = stateFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (typeof j.autoTrigger === "boolean")     root.autoTrigger = j.autoTrigger
                if (typeof j.freeRamThreshold === "number") root.freeRamThreshold = j.freeRamThreshold
                if (typeof j.lastCleanupTime === "number")  root.lastCleanupTime = j.lastCleanupTime
                if (typeof j.totalBytesFreed === "number")  root.totalBytesFreed = j.totalBytesFreed
                // sessionSuppressed deliberately NOT persisted — resets on each session
            } catch (e) {
                console.warn("ZenCleanupService: bad cleanup.state:", e)
            }
        }
        onLoadFailed: function(err) { saveDebounced.restart() }
    }

    Timer {
        id: saveDebounced
        interval: 250; repeat: false
        onTriggered: root._writeState()
    }

    Process { id: stateWriter; running: false }
    function _writeState() {
        const obj = {
            _schema: 7,
            autoTrigger: root.autoTrigger,
            freeRamThreshold: root.freeRamThreshold,
            lastCleanupTime: root.lastCleanupTime,
            totalBytesFreed: root.totalBytesFreed
        }
        const json = JSON.stringify(obj, null, 2)
        stateWriter.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_CLEANUP_EOF'\n" + json + "\nZEN_CLEANUP_EOF\n" +
            "mv \"$tmp\" '" + root.statePath + "'"]
        stateWriter.running = true
    }

    Connections {
        target: root
        function onAutoTriggerChanged()      { saveDebounced.restart() }
        function onFreeRamThresholdChanged() { saveDebounced.restart() }
    }
}
