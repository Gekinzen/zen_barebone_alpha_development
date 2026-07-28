pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ClipboardService v7.0.0-alpha.6 — cliphist-backed clipboard history
 *
 * Wraps the user's existing `cliphist` daemon (https://github.com/sentriz/cliphist)
 * which is the standard Wayland clipboard history tool. cliphist must
 * be running as a wl-paste --watch service — install.sh adds the
 * autostart entry on first run if absent.
 *
 * This service:
 *   - Reads `cliphist list` periodically + on demand
 *   - Parses entries (each line is "ID\tcontent-preview")
 *   - Detects image entries (cliphist marks them as binary)
 *   - Provides paste(id), delete(id), wipe() actions
 *   - Persists pinned IDs to ~/.local/share/zen-shell/clipboard-pins.json
 *
 * UI consumer (ClipboardPanel.qml) binds to entries[] + pinnedIds[]
 * for reactive rendering. The bar module (ClipboardModule.qml) shows
 * a pulse indicator when new content arrives.
 *
 * Wala tayong babawasan — entirely new service. If cliphist isn't
 * installed, refresh fails silently and entries[] stays empty;
 * the UI shows "cliphist not running" with an install hint.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/share/zen-shell"
    readonly property string pinsPath: stateDir + "/clipboard-pins.json"

    // Live state
    property var entries: []     // [{ id, preview, isImage, isPinned }]
    property var pinnedIds: []
    property bool loading: false
    property bool cliphistAvailable: true   // turns false on first failed run
    property string lastError: ""

    // Tunables
    property int maxEntries: 100
    property bool active: false   // panel sets this true while visible

    // ─────────────────────────────────────────────────────────────
    // LIST (reads cliphist's current store)
    // ─────────────────────────────────────────────────────────────
    Process {
        id: listProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseList(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = (this.text || "").trim()
                if (!t) return
                root.lastError = t.split("\n").pop()
                if (t.indexOf("not found") >= 0
                    || t.indexOf("No such file") >= 0
                    || t.indexOf("command not found") >= 0)
                    root.cliphistAvailable = false
            }
        }
        onExited: function(code, status) {
            root.loading = false
            if (code !== 0 && code !== 1) {
                console.warn("ClipboardService: cliphist list exit", code)
            }
        }
    }

    function _parseList(text) {
        if (!text) { root.entries = []; return }
        const out = []
        const lines = text.split("\n")
        for (var i = 0; i < lines.length && out.length < root.maxEntries; i++) {
            const line = lines[i]
            if (!line || !line.length) continue
            // cliphist format: "12345\tcontent-preview"
            const tab = line.indexOf("\t")
            if (tab < 0) continue
            const id = line.substring(0, tab).trim()
            const preview = line.substring(tab + 1)
            // cliphist marks images as "[[ binary data N png ]]" or similar
            const isImage = preview.indexOf("[[ binary data") === 0
            out.push({
                id: id,
                preview: preview,
                isImage: isImage,
                isPinned: root.pinnedIds.indexOf(id) >= 0
            })
        }
        root.entries = out
        root.cliphistAvailable = true
    }

    function refresh() {
        if (root.loading) return
        root.loading = true
        root.lastError = ""
        listProc.command = ["cliphist", "list"]
        listProc.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // PASTE — decode entry by ID and pipe to wl-copy
    // ─────────────────────────────────────────────────────────────
    Process { id: pasteProc; running: false }

    function paste(id) {
        if (!id) return
        // Pipeline: cliphist decode <id> | wl-copy
        // After this, the next ctrl-v / paste in the focused app uses it.
        pasteProc.command = ["bash", "-c",
            "cliphist decode '" + id + "' | wl-copy"]
        pasteProc.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // DELETE / WIPE
    // ─────────────────────────────────────────────────────────────
    Process { id: deleteProc; running: false }

    function deleteEntry(id) {
        if (!id) return
        deleteProc.command = ["bash", "-c",
            "cliphist decode '" + id + "' | cliphist delete"]
        deleteProc.running = true
        // Optimistic UI update: remove from entries immediately
        root.entries = root.entries.filter(function(e){ return e.id !== id })
        unpin(id)
        // Refresh after a beat to catch any cascade effects
        Qt.callLater(refreshTimer.restart)
    }

    Process { id: wipeProc; running: false }
    function wipe() {
        wipeProc.command = ["bash", "-c", "cliphist wipe"]
        wipeProc.running = true
        root.entries = []
        root.pinnedIds = []
        savePins.restart()
    }

    Timer {
        id: refreshTimer
        interval: 200; repeat: false
        onTriggered: root.refresh()
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
        // Update entries' isPinned flags
        root.entries = root.entries.map(function(e){
            return e.id === id ? Object.assign({}, e, { isPinned: true }) : e
        })
        savePins.restart()
    }

    function unpin(id) {
        if (!id) return
        const next = root.pinnedIds.filter(function(x){ return x !== id })
        if (next.length === root.pinnedIds.length) return
        root.pinnedIds = next
        root.entries = root.entries.map(function(e){
            return e.id === id ? Object.assign({}, e, { isPinned: false }) : e
        })
        savePins.restart()
    }

    // Pinned entries always at top of UI list
    function pinnedFirst() {
        const pinned = root.entries.filter(function(e){ return e.isPinned })
        const rest   = root.entries.filter(function(e){ return !e.isPinned })
        return pinned.concat(rest)
    }

    // ─────────────────────────────────────────────────────────────
    // SEARCH
    // ─────────────────────────────────────────────────────────────
    function search(query) {
        if (!query || !query.trim()) return root.entries
        const q = query.toLowerCase().trim()
        return root.entries.filter(function(e){
            return (e.preview || "").toLowerCase().indexOf(q) >= 0
        })
    }

    // ─────────────────────────────────────────────────────────────
    // POLLING — only while panel is visible
    // ─────────────────────────────────────────────────────────────
    Timer {
        // 5s polling when panel open (covers external app copies);
        // if user prefers true event-driven, they can wire a wl-paste
        // --watch-fired notification but cliphist itself doesn't emit
        // signals.
        interval: 5000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    // Refresh on first activation
    onActiveChanged: if (active) refresh()

    // Initial probe at startup (single shot, after warmup) so the bar
    // module knows whether cliphist is available before the panel is
    // ever opened.
    Timer {
        interval: 6000
        repeat: false
        running: true
        onTriggered: root.refresh()
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    FileView {
        id: pinsFile
        path: root.pinsPath
        blockLoading: true
        onLoaded: {
            try {
                const txt = pinsFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (Array.isArray(j.pinnedIds)) root.pinnedIds = j.pinnedIds
            } catch (e) {
                console.warn("ClipboardService: bad clipboard-pins.json:", e)
            }
        }
        onLoadFailed: function(err) { savePins.restart() }
    }

    Timer {
        id: savePins
        interval: 250; repeat: false
        onTriggered: root._writePins()
    }

    Process { id: pinsWriter; running: false }

    function _writePins() {
        const obj = { _schema: 7, pinnedIds: root.pinnedIds }
        const json = JSON.stringify(obj, null, 2)
        pinsWriter.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_CLIPPIN_EOF'\n" + json + "\nZEN_CLIPPIN_EOF\n" +
            "mv \"$tmp\" '" + root.pinsPath + "'"]
        pinsWriter.running = true
    }
}
