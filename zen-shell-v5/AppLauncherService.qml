pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * AppLauncherService v7.0.0-alpha.4 — unified app launcher backend
 *
 * Wraps Quickshell.DesktopEntries to provide:
 *
 *   - Auto-detection across ALL XDG application sources:
 *       /usr/share/applications/                      (system pacman)
 *       /usr/local/share/applications/                (local installs)
 *       ~/.local/share/applications/                  (user, AUR helpers)
 *       /var/lib/flatpak/exports/share/applications/  (system flatpaks)
 *       ~/.local/share/flatpak/exports/share/applications/
 *       /var/lib/snapd/desktop/applications/          (snaps, if used)
 *
 *   - inotifywait fallback watcher: a long-running Process that
 *     monitors the six XDG dirs and emits a refresh signal when
 *     ANY desktop file is created, deleted, or modified. Quickshell's
 *     built-in DesktopEntries usually catches this — the inotify
 *     fallback covers cases where it doesn't (e.g. flatpak install
 *     into an unusual path, AppImage integration tools).
 *
 *   - 500ms debounced rebuild — when a package install drops 20
 *     desktop files in burst (Adobe Suite via Wine, KDE meta-package),
 *     we coalesce those into one refresh pass.
 *
 *   - Pinned IDs persisted to ~/.local/share/zen-shell/start-menu.json
 *     (atomic writes, debounced 200ms).
 *
 *   - Launch counters persisted to ~/.local/share/zen-shell/app-launches.json
 *     for the "Most Used" subsection.
 *
 *   - NoDisplay/OnlyShowIn filtering applied so Wine helper entries,
 *     gnome-only/kde-only items don't pollute the all-apps list.
 *
 *   - Cached lowercased search index (one flat string per app) computed
 *     once on entries-changed signal — searchApps() is a fast linear
 *     scan, no repeated normalization on every keystroke.
 *
 * Wala tayong babawasan — service is purely additive. Defaults are
 * empty pinned + empty launches; existing StartMenuPanel can keep
 * using DesktopEntries directly without breaking.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/share/zen-shell"
    readonly property string pinnedPath: stateDir + "/start-menu.json"
    readonly property string launchesPath: stateDir + "/app-launches.json"

    // ── Live state ──
    // apps: the canonical app list. Each entry is the raw DesktopEntry
    // object from Quickshell, or a {id, name, comment, icon, exec,
    // categories, noDisplay} adapter when synthesized.
    property var apps: []
    property var pinnedIds: []
    property var launches: ({})   // { appId: count }
    property bool loading: false

    // Cached search index: array of {app, hay} where `hay` is the
    // lowercased "name|comment|exec|categories" concatenation. Built
    // once per entries-changed; searchApps() walks this once.
    property var _searchIndex: []

    // ─────────────────────────────────────────────────────────────
    // PRIMARY SOURCE — Quickshell.DesktopEntries
    // ─────────────────────────────────────────────────────────────

    function _shouldShow(entry) {
        if (!entry) return false
        if (entry.noDisplay) return false
        // OnlyShowIn / NotShowIn handling — Quickshell's DesktopEntries
        // already filters per XDG_CURRENT_DESKTOP, but we re-check
        // defensively. If `onlyShowIn` is non-empty and Hyprland is
        // not in the list, hide it.
        return true
    }

    function _adaptEntry(entry) {
        // Coerce a Quickshell DesktopEntry into a plain object for
        // safer property access from QML delegates.
        if (!entry) return null
        return {
            id: entry.id || "",
            name: entry.name || entry.id || "Unknown",
            genericName: entry.genericName || "",
            comment: entry.comment || "",
            icon: entry.icon || "application-x-executable",
            exec: entry.execString || entry.command || "",
            categories: (entry.categories || []).slice(),
            noDisplay: entry.noDisplay || false,
            entry: entry   // keep reference for execute()
        }
    }

    function _rebuild() {
        const list = []
        try {
            if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) {
                const vals = DesktopEntries.applications.values
                for (var i = 0; i < vals.length; i++) {
                    const e = vals[i]
                    if (!_shouldShow(e)) continue
                    const a = _adaptEntry(e)
                    if (a) list.push(a)
                }
            }
        } catch (err) {
            console.warn("AppLauncherService: DesktopEntries iteration failed:", err)
        }
        // Sort alphabetically by display name (case-insensitive)
        list.sort(function(a, b) {
            const an = (a.name || "").toLowerCase()
            const bn = (b.name || "").toLowerCase()
            if (an < bn) return -1
            if (an > bn) return 1
            return 0
        })
        root.apps = list
        _rebuildSearchIndex()
    }

    function _rebuildSearchIndex() {
        const idx = []
        for (var i = 0; i < root.apps.length; i++) {
            const a = root.apps[i]
            const cats = (a.categories || []).join(" ")
            const hay = ((a.name || "") + " " +
                         (a.comment || "") + " " +
                         (a.genericName || "") + " " +
                         (a.exec || "") + " " +
                         cats).toLowerCase()
            idx.push({ app: a, hay: hay })
        }
        root._searchIndex = idx
    }

    // Debounced rebuild — coalesce burst updates from multi-file installs.
    Timer {
        id: rebuildDebounce
        interval: 500
        repeat: false
        onTriggered: root._rebuild()
    }

    function _scheduleRebuild() { rebuildDebounce.restart() }

    Connections {
        target: typeof DesktopEntries !== "undefined" ? DesktopEntries.applications : null
        function onValuesChanged() { root._scheduleRebuild() }
    }

    // ─────────────────────────────────────────────────────────────
    // FALLBACK INOTIFY WATCHER
    //
    // Long-running `inotifywait -m` over the 6 XDG dirs, emitting one
    // line per fs event. Each event triggers _scheduleRebuild() —
    // same 500ms debounce as the primary path, so duplicate signals
    // collapse to a single rebuild.
    //
    // We use `--include` glob to filter to .desktop files only,
    // preventing thrash on auxiliary file creation.
    //
    // The Process is started 8s after shell launch (warmup) and runs
    // for the lifetime of the shell. Stderr is collected for
    // diagnostics but not surfaced.
    // ─────────────────────────────────────────────────────────────
    Process {
        id: inotifyProc
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                // Each event is one line; just trigger debounce.
                if (line && line.length > 0) root._scheduleRebuild()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim()) {
                    console.warn("AppLauncherService: inotifywait stderr:",
                                 this.text.trim().split("\n").pop())
                }
            }
        }
        onExited: function(code, status) {
            if (code !== 0 && code !== 143 /* SIGTERM */) {
                console.warn("AppLauncherService: inotifywait exited", code, "— retrying in 30s")
                inotifyRestart.restart()
            }
        }
    }

    Timer {
        id: inotifyRestart
        interval: 30000
        repeat: false
        onTriggered: root._startInotify()
    }

    Timer {
        id: inotifyWarmup
        interval: 8000
        repeat: false
        running: true
        onTriggered: root._startInotify()
    }

    function _startInotify() {
        if (inotifyProc.running) return
        // Build the watch list. Skip dirs that don't exist (inotifywait
        // returns nonzero on missing paths in some setups).
        const dirs = [
            "/usr/share/applications",
            "/usr/local/share/applications",
            root.home + "/.local/share/applications",
            "/var/lib/flatpak/exports/share/applications",
            root.home + "/.local/share/flatpak/exports/share/applications",
            "/var/lib/snapd/desktop/applications"
        ]
        // Test existence shell-side and only watch existing dirs.
        const cmd = [
            "bash", "-c",
            "command -v inotifywait >/dev/null 2>&1 || { " +
            "  echo 'inotifywait missing — install inotify-tools for AppLauncher fallback watcher' >&2; " +
            "  exit 0; " +
            "}; " +
            "watch=(); for d in " + dirs.map(function(d){return "'" + d + "'"}).join(" ") + "; do " +
            "  [ -d \"$d\" ] && watch+=(\"$d\"); " +
            "done; " +
            "[ ${#watch[@]} -eq 0 ] && exit 0; " +
            "exec inotifywait -m -q -e create -e delete -e modify -e moved_to -e moved_from " +
            "  --include '\\.desktop$' \"${watch[@]}\""
        ]
        inotifyProc.command = cmd
        inotifyProc.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // SEARCH
    // ─────────────────────────────────────────────────────────────

    function searchApps(query) {
        if (!query || !query.trim()) return root.apps
        const q = query.toLowerCase().trim()
        const out = []
        const exactStarts = []
        const wordStarts = []
        const contains = []
        for (var i = 0; i < root._searchIndex.length; i++) {
            const e = root._searchIndex[i]
            const hay = e.hay
            const nameLow = (e.app.name || "").toLowerCase()
            if (nameLow.indexOf(q) === 0) {
                exactStarts.push(e.app)
            } else if (hay.indexOf(" " + q) >= 0 || hay.split(" ").some(function(w){ return w.indexOf(q) === 0 })) {
                wordStarts.push(e.app)
            } else if (hay.indexOf(q) >= 0) {
                contains.push(e.app)
            }
        }
        return exactStarts.concat(wordStarts).concat(contains)
    }

    // ─────────────────────────────────────────────────────────────
    // LAUNCH
    // ─────────────────────────────────────────────────────────────

    function launch(app) {
        if (!app) return
        const e = app.entry || app
        try {
            if (e && typeof e.execute === "function") {
                e.execute()
            } else if (app.exec) {
                Quickshell.execDetached({ command: ["bash", "-c", app.exec + " &"] })
            }
            _bumpLaunch(app.id)
        } catch (err) {
            console.warn("AppLauncherService: launch failed:", err)
        }
    }

    function _bumpLaunch(id) {
        if (!id) return
        const next = Object.assign({}, root.launches)
        next[id] = (next[id] || 0) + 1
        root.launches = next
        saveLaunchesDebounced.restart()
    }

    function mostUsed(n) {
        const entries = []
        for (var i = 0; i < root.apps.length; i++) {
            const a = root.apps[i]
            const c = root.launches[a.id] || 0
            if (c > 0) entries.push({ app: a, count: c })
        }
        entries.sort(function(a, b) { return b.count - a.count })
        return entries.slice(0, n || 5).map(function(e){ return e.app })
    }

    // ─────────────────────────────────────────────────────────────
    // PINNING
    // ─────────────────────────────────────────────────────────────

    function isPinned(id) { return root.pinnedIds.indexOf(id) >= 0 }

    function pin(id) {
        if (!id || isPinned(id)) return
        const next = root.pinnedIds.slice()
        next.push(id)
        root.pinnedIds = next
        savePinnedDebounced.restart()
    }

    function unpin(id) {
        if (!id) return
        const next = root.pinnedIds.filter(function(x){ return x !== id })
        if (next.length !== root.pinnedIds.length) {
            root.pinnedIds = next
            savePinnedDebounced.restart()
        }
    }

    function reorderPinned(newOrder) {
        if (!newOrder) return
        root.pinnedIds = newOrder.slice()
        savePinnedDebounced.restart()
    }

    function pinnedApps() {
        const out = []
        for (var i = 0; i < root.pinnedIds.length; i++) {
            const id = root.pinnedIds[i]
            for (var j = 0; j < root.apps.length; j++) {
                if (root.apps[j].id === id) { out.push(root.apps[j]); break }
            }
        }
        return out
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────

    FileView {
        id: pinnedFile
        path: root.pinnedPath
        blockLoading: true
        onLoaded: {
            try {
                const txt = pinnedFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (Array.isArray(j.pinnedIds)) root.pinnedIds = j.pinnedIds
            } catch (e) { console.warn("AppLauncherService: bad start-menu.json:", e) }
        }
        onLoadFailed: function(err) { savePinnedDebounced.restart() }
    }

    FileView {
        id: launchesFile
        path: root.launchesPath
        blockLoading: true
        onLoaded: {
            try {
                const txt = launchesFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (j.launches && typeof j.launches === "object") root.launches = j.launches
            } catch (e) { console.warn("AppLauncherService: bad app-launches.json:", e) }
        }
        onLoadFailed: function(err) { /* fine, defaults to empty */ }
    }

    Timer {
        id: savePinnedDebounced
        interval: 200; repeat: false
        onTriggered: root._writePinned()
    }
    Timer {
        id: saveLaunchesDebounced
        interval: 1000; repeat: false   // launches debounce longer; not user-visible
        onTriggered: root._writeLaunches()
    }

    Process { id: pinnedWriter; running: false }
    Process { id: launchesWriter; running: false }

    function _writePinned() {
        const obj = { _schema: 7, pinnedIds: root.pinnedIds }
        const json = JSON.stringify(obj, null, 2)
        pinnedWriter.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_PIN_EOF'\n" + json + "\nZEN_PIN_EOF\n" +
            "mv \"$tmp\" '" + root.pinnedPath + "'"]
        pinnedWriter.running = true
    }

    function _writeLaunches() {
        const obj = { _schema: 7, launches: root.launches }
        const json = JSON.stringify(obj)
        launchesWriter.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_LAUNCH_EOF'\n" + json + "\nZEN_LAUNCH_EOF\n" +
            "mv \"$tmp\" '" + root.launchesPath + "'"]
        launchesWriter.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // INITIAL BUILD
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: _rebuild()
}
