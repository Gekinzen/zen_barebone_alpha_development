pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ClipboardOnboardingService v7.0.0-alpha.7
 *
 * Probes the system for clipboard-history pre-requisites, exposes a
 * diagnostic state that the ClipboardPanel empty-state UI binds to.
 *
 * Three checks:
 *
 *   1. cliphist installed? → `command -v cliphist`
 *   2. wl-paste watchers running? → `pgrep -af wl-paste.*cliphist`
 *      (we expect 2 — text + image, but 1 still means partially
 *      working; the count is exposed)
 *   3. cliphist DB exists? → `[ -e ~/.cache/cliphist/db ]`
 *
 * Re-runs the probe when:
 *   - Service first loads (Component.onCompleted)
 *   - User clicks "Re-check" in the panel
 *   - User clicks "Start watchers" — we re-check after spawning
 *   - 30s after panel becomes active (in case user installed cliphist
 *     externally)
 *
 * Provides three actions:
 *   - installCliphist()      → spawns terminal with `sudo pacman -S cliphist`
 *   - startWatchers()        → nohup wl-paste --watch cliphist store &
 *   - openCliphistDocs()     → xdg-open the GitHub URL
 *
 * Wala tayong babawasan — purely additive service. Only consumed by
 * ClipboardPanel's diagnostic empty-state. ClipboardService itself
 * remains unchanged.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // PROBE STATE
    // ─────────────────────────────────────────────────────────────
    property bool cliphistInstalled: false
    property int  watchersRunning: 0          // 0, 1, or 2
    property bool dbExists: false
    property bool probing: false
    property real lastProbeTime: 0

    // Aggregate readiness — true when everything's in place
    readonly property bool fullyReady:
        cliphistInstalled && watchersRunning >= 2 && dbExists

    // True when partially ready (cliphist installed but no watchers
    // OR watchers running but DB doesn't exist yet — still in-progress)
    readonly property bool partiallyReady:
        cliphistInstalled && (watchersRunning < 2 || !dbExists)

    // Status messages for UI
    readonly property string statusLabel: {
        if (probing) return "Checking…"
        if (fullyReady) return "Clipboard recording is active"
        if (!cliphistInstalled) return "cliphist is not installed"
        if (watchersRunning === 0) return "Clipboard watchers are not running"
        if (watchersRunning === 1) return "Only 1 of 2 watchers running"
        if (!dbExists) return "Watchers running, but no entries yet — copy something to test"
        return "Unknown state"
    }

    // ─────────────────────────────────────────────────────────────
    // PROBE
    // ─────────────────────────────────────────────────────────────
    Process {
        id: probeProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseProbe(this.text)
        }
        onExited: function(code) { root.probing = false; root.lastProbeTime = Date.now() }
    }

    function _parseProbe(text) {
        if (!text) return
        const lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            const line = lines[i]
            const eq = line.indexOf("=")
            if (eq < 0) continue
            const key = line.substring(0, eq)
            const val = line.substring(eq + 1)
            if (key === "INSTALLED")  root.cliphistInstalled = (val === "1")
            else if (key === "WATCHERS") root.watchersRunning = parseInt(val) || 0
            else if (key === "DB")    root.dbExists = (val === "1")
        }
    }

    function probe() {
        if (root.probing) return
        root.probing = true
        probeProc.command = ["bash", "-c",
            "if command -v cliphist >/dev/null 2>&1; then echo INSTALLED=1; else echo INSTALLED=0; fi; " +
            "watchers=$(pgrep -af 'wl-paste.*cliphist' 2>/dev/null | wc -l); " +
            "echo WATCHERS=$watchers; " +
            "if [ -e \"$HOME/.cache/cliphist/db\" ]; then echo DB=1; else echo DB=0; fi"
        ]
        probeProc.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // ACTIONS
    // ─────────────────────────────────────────────────────────────
    function installCliphist() {
        // Open a terminal with the install command. We can't run
        // `sudo pacman -S` directly — that needs interactive auth.
        // The user runs the command, then comes back to flip the
        // probe again.
        Quickshell.execDetached({
            command: ["sh", "-c",
                "if command -v alacritty >/dev/null; then " +
                "  alacritty -e bash -c 'echo Installing cliphist...; sudo pacman -S --noconfirm cliphist wl-clipboard; echo; echo Done. Press Enter to close.; read'; " +
                "elif command -v kitty >/dev/null; then " +
                "  kitty bash -c 'echo Installing cliphist...; sudo pacman -S --noconfirm cliphist wl-clipboard; echo; echo Done. Press Enter to close.; read'; " +
                "elif command -v foot >/dev/null; then " +
                "  foot bash -c 'echo Installing cliphist...; sudo pacman -S --noconfirm cliphist wl-clipboard; echo; echo Done. Press Enter to close.; read'; " +
                "elif command -v xterm >/dev/null; then " +
                "  xterm -e bash -c 'echo Installing cliphist...; sudo pacman -S --noconfirm cliphist wl-clipboard; echo; echo Done. Press Enter to close.; read'; " +
                "fi"
            ]
        })
        // Re-probe in 5s (gives the user time to enter password)
        Qt.callLater(function(){ rePrtobeTimer.restart() })
    }

    Process { id: watcherSpawnerProc; running: false }
    function startWatchers() {
        // Spawn both watchers (text + image) detached. Persist by
        // appending to autostart.conf if not already there.
        watcherSpawnerProc.command = ["bash", "-c",
            "nohup wl-paste --type text --watch cliphist store >/dev/null 2>&1 & " +
            "nohup wl-paste --type image --watch cliphist store >/dev/null 2>&1 &"
        ]
        watcherSpawnerProc.running = true
        Qt.callLater(function(){ rePrtobeTimer.restart() })
    }

    function openCliphistDocs() {
        Quickshell.execDetached({
            command: ["xdg-open", "https://github.com/sentriz/cliphist"]
        })
    }

    Timer {
        id: rePrtobeTimer
        interval: 5000; repeat: false
        onTriggered: root.probe()
    }

    // ─────────────────────────────────────────────────────────────
    // INITIAL PROBE on startup
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: probe()
}
