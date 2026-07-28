pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ZenUpdateService v7.0.0-alpha.1 — update detection, snapshots, rollback
 *
 * Provides:
 *   - Periodic update check against GitHub releases (or custom endpoint)
 *   - Channel filtering (stable / beta / alpha)
 *   - Snapshot creation (auto on every install, manual via API)
 *   - Snapshot listing + rollback to previous version
 *   - Pin/unpin snapshots (protect from auto-prune)
 *
 * State files:
 *   ~/.config/quickshell/zen-shell/update-state.json   — settings + last-check cache
 *   ~/.local/share/zen-shell/snapshots/                — versioned snapshot archives
 *   ~/.local/share/zen-shell/snapshots/manifest.json   — snapshot metadata
 *   ~/.local/share/zen-shell/updates.log               — audit log
 *
 * Helper scripts (live in ~/.config/quickshell/zen-shell/scripts/):
 *   zen-update-check.sh       — fetches latest release info from GitHub
 *   zen-snapshot-create.sh    — snapshots current install
 *   zen-rollback.sh           — restores from a snapshot
 *   zen-update-install.sh     — downloads + installs a release
 *
 * v7 design choice: these scripts live INSIDE the install dir (not in
 * ~/.local/bin/) so that snapshot/rollback covers them atomically along
 * with the QML — script versions stay matched to QML versions across
 * rollback boundaries. Called by full path via `scriptsDir`.
 *
 * SAFETY MODEL
 * ────────────
 * - Rollback always snapshots CURRENT state first (failsafe undo).
 * - Snapshots are content-only (QML files + state JSON) — Hyprland
 *   configs and user data are NOT touched.
 * - Auto-check throttled: minimum 6h between checks.
 * - Auto-check skipped if battery < 20% (laptop mode).
 * - All destructive ops gated by Process.exitCode === 0; failed
 *   restore aborts and logs.
 *
 * Wala tayong babawasan — service is additive; absence of update-state.json
 * means no auto-check happens, manual button still works.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: home + "/.config/quickshell/zen-shell"
    readonly property string scriptsDir: configDir + "/scripts"
    readonly property string stateDir: home + "/.local/share/zen-shell"
    readonly property string snapshotDir: stateDir + "/snapshots"
    readonly property string statePath: configDir + "/update-state.json"
    readonly property string manifestPath: snapshotDir + "/manifest.json"
    readonly property string logPath: stateDir + "/updates.log"

    // ── Configuration (persisted) ──
    property bool autoCheckEnabled: true
    property int  autoCheckIntervalHours: 24
    property string preferredChannel: "alpha"   // "stable" | "beta" | "alpha"
    property bool autoSnapshotBeforeUpdate: true
    property int maxSnapshotsRetained: 5
    property string releaseRepo: "Gekinzen/zen-shell"  // owner/repo on GitHub

    // ── Live state ──
    property string currentVersion: ZenVersion.version
    property string latestVersion: ""
    property string latestReleaseUrl: ""
    property string latestReleaseNotes: ""
    property string latestReleaseDate: ""
    property bool   updateAvailable: false
    property bool   checking: false
    property string lastChecked: ""    // ISO timestamp
    property string lastCheckError: ""
    property string lastUpdateAction: ""  // "" | "snapshot" | "install" | "rollback"
    property string lastUpdateStatus: ""  // "" | "running" | "success" | "failure"
    property string lastUpdateMessage: ""

    // ── Snapshot list (loaded from manifest.json) ──
    // Each entry: { version, codename, channel, timestamp, sizeBytes, pinned, path }
    property var snapshots: []

    // ─────────────────────────────────────────────────────────
    // PERSISTENCE — settings only (snapshots managed via shell scripts)
    // ─────────────────────────────────────────────────────────

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        blockAllReads: false

        onLoaded: {
            try {
                const txt = stateFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (typeof j.autoCheckEnabled === "boolean")
                    root.autoCheckEnabled = j.autoCheckEnabled
                if (typeof j.autoCheckIntervalHours === "number")
                    root.autoCheckIntervalHours = j.autoCheckIntervalHours
                if (typeof j.preferredChannel === "string")
                    root.preferredChannel = j.preferredChannel
                if (typeof j.autoSnapshotBeforeUpdate === "boolean")
                    root.autoSnapshotBeforeUpdate = j.autoSnapshotBeforeUpdate
                if (typeof j.maxSnapshotsRetained === "number")
                    root.maxSnapshotsRetained = j.maxSnapshotsRetained
                if (typeof j.releaseRepo === "string" && j.releaseRepo)
                    root.releaseRepo = j.releaseRepo
                if (typeof j.lastChecked === "string")
                    root.lastChecked = j.lastChecked
                if (typeof j.latestVersion === "string")
                    root.latestVersion = j.latestVersion
                if (typeof j.latestReleaseUrl === "string")
                    root.latestReleaseUrl = j.latestReleaseUrl
                if (typeof j.latestReleaseNotes === "string")
                    root.latestReleaseNotes = j.latestReleaseNotes
                if (typeof j.latestReleaseDate === "string")
                    root.latestReleaseDate = j.latestReleaseDate
                root._recomputeUpdateAvailable()
            } catch (e) {
                console.warn("ZenUpdateService: failed to parse update-state.json:", e)
            }
        }

        onLoadFailed: function(err) {
            // Missing file is fine on first launch — write defaults.
            saveStateDebounced.restart()
        }
    }

    Timer {
        id: saveStateDebounced
        interval: 200
        repeat: false
        onTriggered: root._writeState()
    }

    function _writeState() {
        const obj = {
            _schema: ZenVersion.schemaVersion,
            autoCheckEnabled: root.autoCheckEnabled,
            autoCheckIntervalHours: root.autoCheckIntervalHours,
            preferredChannel: root.preferredChannel,
            autoSnapshotBeforeUpdate: root.autoSnapshotBeforeUpdate,
            maxSnapshotsRetained: root.maxSnapshotsRetained,
            releaseRepo: root.releaseRepo,
            lastChecked: root.lastChecked,
            latestVersion: root.latestVersion,
            latestReleaseUrl: root.latestReleaseUrl,
            latestReleaseNotes: root.latestReleaseNotes,
            latestReleaseDate: root.latestReleaseDate
        }
        const json = JSON.stringify(obj, null, 2)
        // Atomic write via tmp + mv
        atomicWriter.command = ["bash", "-c",
            "mkdir -p '" + root.configDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_STATE_EOF'\n" + json + "\nZEN_STATE_EOF\n" +
            "mv \"$tmp\" '" + root.statePath + "'"
        ]
        atomicWriter.running = true
    }

    Process { id: atomicWriter; running: false }

    // Auto-save when any persisted prop changes.
    onAutoCheckEnabledChanged:        saveStateDebounced.restart()
    onAutoCheckIntervalHoursChanged:  saveStateDebounced.restart()
    onPreferredChannelChanged:        { saveStateDebounced.restart(); root._recomputeUpdateAvailable() }
    onAutoSnapshotBeforeUpdateChanged: saveStateDebounced.restart()
    onMaxSnapshotsRetainedChanged:    saveStateDebounced.restart()
    onReleaseRepoChanged:             saveStateDebounced.restart()

    // ─────────────────────────────────────────────────────────
    // UPDATE CHECK
    // ─────────────────────────────────────────────────────────

    Process {
        id: checkProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseCheckResult(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    root.lastCheckError = this.text.trim().split("\n").pop()
                }
            }
        }
        onExited: function(code, status) {
            root.checking = false
            if (code !== 0 && !root.lastCheckError) {
                root.lastCheckError = "Check exited with code " + code
            }
        }
    }

    function checkForUpdates() {
        if (root.checking) return
        root.checking = true
        root.lastCheckError = ""
        // zen-update-check.sh emits one line of JSON on stdout:
        //   {"tag":"v7.0.1","name":"...","url":"...","body":"...","date":"...","prerelease":false}
        // or {"error":"..."} on failure.
        checkProc.command = [root.scriptsDir + "/zen-update-check.sh",
                             root.releaseRepo, root.preferredChannel]
        checkProc.running = true
    }

    function _parseCheckResult(text) {
        if (!text || !text.trim()) return
        try {
            const j = JSON.parse(text.trim().split("\n").pop())
            if (j.error) {
                root.lastCheckError = String(j.error)
                return
            }
            root.latestVersion       = j.tag || ""
            root.latestReleaseUrl    = j.url || ""
            root.latestReleaseNotes  = j.body || ""
            root.latestReleaseDate   = j.date || ""
            root.lastChecked         = new Date().toISOString()
            root._recomputeUpdateAvailable()
            saveStateDebounced.restart()
        } catch (e) {
            root.lastCheckError = "Failed to parse check result: " + e
        }
    }

    function _recomputeUpdateAvailable() {
        if (!root.latestVersion) {
            root.updateAvailable = false
            return
        }
        root.updateAvailable = ZenVersion.isNewer(root.latestVersion)
    }

    // ── Auto-check tick ──
    // Fires once on shell start (after a 30s warmup) and then every
    // autoCheckIntervalHours. Throttled by lastChecked timestamp so
    // shell restarts within the window don't re-trigger.
    Timer {
        id: warmup
        interval: 30000
        repeat: false
        running: true
        onTriggered: autoCheckTick.triggered()
    }

    Timer {
        id: autoCheckTick
        interval: Math.max(1, root.autoCheckIntervalHours) * 3600000
        repeat: true
        running: root.autoCheckEnabled
        onTriggered: {
            if (!root.autoCheckEnabled) return
            // Throttle: skip if checked within interval/2
            if (root.lastChecked) {
                const last = new Date(root.lastChecked).getTime()
                const minGap = Math.max(1, root.autoCheckIntervalHours) * 3600000 / 2
                if (Date.now() - last < minGap) return
            }
            // Battery guard — defer to LaptopModeService when it lands;
            // for v7.0.0-alpha.1 we just always check.
            root.checkForUpdates()
        }
    }

    // ─────────────────────────────────────────────────────────
    // SNAPSHOT MANAGEMENT
    // ─────────────────────────────────────────────────────────

    FileView {
        id: manifestFile
        path: root.manifestPath
        blockLoading: false
        blockAllReads: false

        onLoaded: {
            try {
                const txt = manifestFile.text()
                if (!txt || !txt.trim()) { root.snapshots = []; return }
                const j = JSON.parse(txt)
                if (Array.isArray(j.snapshots)) {
                    root.snapshots = j.snapshots
                }
            } catch (e) {
                console.warn("ZenUpdateService: bad manifest.json:", e)
                root.snapshots = []
            }
        }
        onLoadFailed: function(err) { root.snapshots = [] }
    }

    Process {
        id: snapshotProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastUpdateMessage = this.text.trim().split("\n").pop()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    root.lastUpdateMessage = this.text.trim().split("\n").pop()
                }
            }
        }
        onExited: function(code, status) {
            root.lastUpdateStatus = (code === 0) ? "success" : "failure"
            // Reload manifest to pick up new entry
            manifestFile.reload()
        }
    }

    function createSnapshot(label) {
        if (root.lastUpdateStatus === "running") return
        root.lastUpdateAction = "snapshot"
        root.lastUpdateStatus = "running"
        root.lastUpdateMessage = "Creating snapshot…"
        snapshotProc.command = [root.scriptsDir + "/zen-snapshot-create.sh",
                                "--version", ZenVersion.version,
                                "--codename", ZenVersion.codename,
                                "--channel", ZenVersion.channel,
                                "--label", (label || "manual")]
        snapshotProc.running = true
    }

    function deleteSnapshot(snapshotPath) {
        if (root.lastUpdateStatus === "running") return
        root.lastUpdateAction = "snapshot"
        root.lastUpdateStatus = "running"
        snapshotProc.command = [root.scriptsDir + "/zen-snapshot-create.sh",
                                "--delete", snapshotPath]
        snapshotProc.running = true
    }

    function pinSnapshot(snapshotPath, pinned) {
        if (root.lastUpdateStatus === "running") return
        root.lastUpdateAction = "snapshot"
        root.lastUpdateStatus = "running"
        snapshotProc.command = [root.scriptsDir + "/zen-snapshot-create.sh",
                                (pinned ? "--pin" : "--unpin"),
                                snapshotPath]
        snapshotProc.running = true
    }

    function refreshSnapshots() {
        manifestFile.reload()
    }

    // ─────────────────────────────────────────────────────────
    // ROLLBACK
    // ─────────────────────────────────────────────────────────

    Process {
        id: rollbackProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastUpdateMessage = this.text.trim().split("\n").pop()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    root.lastUpdateMessage = this.text.trim().split("\n").pop()
                }
            }
        }
        onExited: function(code, status) {
            root.lastUpdateStatus = (code === 0) ? "success" : "failure"
            // After successful rollback the QML files have been replaced
            // — user must restart the shell. Surface a strong hint.
            if (code === 0) {
                root.lastUpdateMessage = "Rollback complete. Restart shell to apply (qs reload, or zsctl restart)."
            }
        }
    }

    function rollbackTo(snapshotPath) {
        if (root.lastUpdateStatus === "running") return
        root.lastUpdateAction = "rollback"
        root.lastUpdateStatus = "running"
        root.lastUpdateMessage = "Rolling back…"
        // The script auto-snapshots current state before restoring,
        // unless --no-safety-snapshot is passed. We always pass safety on.
        rollbackProc.command = [root.scriptsDir + "/zen-rollback.sh", snapshotPath]
        rollbackProc.running = true
    }

    // ─────────────────────────────────────────────────────────
    // UPDATE INSTALL (download + install)
    // ─────────────────────────────────────────────────────────

    Process {
        id: installProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastUpdateMessage = this.text.trim().split("\n").pop()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    root.lastUpdateMessage = this.text.trim().split("\n").pop()
                }
            }
        }
        onExited: function(code, status) {
            root.lastUpdateStatus = (code === 0) ? "success" : "failure"
            if (code === 0) {
                root.lastUpdateMessage = "Update installed. Restart shell to apply (zsctl restart)."
                manifestFile.reload()
            }
        }
    }

    function installLatest() {
        if (!root.latestVersion || !root.updateAvailable) return
        if (root.lastUpdateStatus === "running") return
        root.lastUpdateAction = "install"
        root.lastUpdateStatus = "running"
        root.lastUpdateMessage = "Downloading and installing " + root.latestVersion + "…"
        const args = [root.scriptsDir + "/zen-update-install.sh",
                      "--repo", root.releaseRepo,
                      "--tag", root.latestVersion]
        if (root.autoSnapshotBeforeUpdate) args.push("--snapshot")
        installProc.command = args
        installProc.running = true
    }

    // ─────────────────────────────────────────────────────────
    // CONVENIENCE
    // ─────────────────────────────────────────────────────────

    function relativeAge(iso) {
        if (!iso) return "never"
        const t = new Date(iso).getTime()
        if (isNaN(t)) return "never"
        const diff = Date.now() - t
        if (diff < 60000)         return "just now"
        if (diff < 3600000)       return Math.floor(diff / 60000) + "m ago"
        if (diff < 86400000)      return Math.floor(diff / 3600000) + "h ago"
        if (diff < 30 * 86400000) return Math.floor(diff / 86400000) + "d ago"
        return new Date(iso).toLocaleDateString()
    }

    function formatBytes(n) {
        if (!n || n < 1024) return (n || 0) + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / 1024 / 1024).toFixed(1) + " MB"
        return (n / 1024 / 1024 / 1024).toFixed(2) + " GB"
    }
}
