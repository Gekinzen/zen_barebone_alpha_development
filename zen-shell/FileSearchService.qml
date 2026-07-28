pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * FileSearchService v7.0.0-alpha.11
 *
 * Lightweight file index for the Spotlight palette. Scans the user's
 * common directories (~/Documents, ~/Downloads, ~/Desktop, ~/Pictures)
 * and provides fuzzy filename search.
 *
 * Strategy:
 *   - On startup + every 5 minutes, run `find` on the watched dirs
 *     with `-maxdepth 3` to avoid blowing up on huge trees
 *   - Result limit: 5000 files (enough for typical home use)
 *   - Each entry: { id, name, path, mime, lastModified }
 *   - search(q) returns up to 8 matches, prefix-match boosted
 *
 * This service is read-only — it doesn't write the index to disk.
 * Refresh on shell start is fast (under 1s for typical setups via
 * `find` + maxdepth limit).
 *
 * Wala tayong babawasan — purely additive. SettingsSearchService
 * will call FileSearchService.search() to surface file results in
 * the Spotlight overlay alongside Settings + Apps + Calc.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property var watchedDirs: [
        home + "/Documents",
        home + "/Downloads",
        home + "/Desktop",
        home + "/Pictures"
    ]

    // ─────────────────────────────────────────────────────────────
    // INDEX
    // ─────────────────────────────────────────────────────────────
    property var entries: []
    property bool indexing: false
    property real lastIndexTime: 0
    property int  indexCount: 0

    // Indexing process — uses `find` with -maxdepth 3 + -type f
    // and outputs TAB-separated path|name|mtime. Newer entries win
    // when sorted by mtime descending.
    Process {
        id: indexProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseIndex(this.text)
        }
        onExited: function(code) {
            root.indexing = false
            root.lastIndexTime = Date.now()
        }
    }

    function refresh() {
        if (root.indexing) return
        root.indexing = true

        // Build the find expression: walk each watchedDir up to 3
        // levels deep, output `<mtime>\t<path>` for each file.
        // Skip hidden files (.git, .cache, etc) — they're noise.
        const findCmd = "for d in " +
            watchedDirs.map(function(d){ return "'" + d + "'" }).join(" ") + "; do " +
            "  [ -d \"$d\" ] && find \"$d\" -maxdepth 3 -type f " +
            "    ! -path '*/.*' " +
            "    ! -name '*.tmp' " +
            "    ! -name '*.swp' " +
            "    -printf '%T@\\t%p\\n' 2>/dev/null; " +
            "done | sort -rn | head -5000"

        indexProc.command = ["bash", "-c", findCmd]
        indexProc.running = true
    }

    function _parseIndex(text) {
        if (!text) {
            root.entries = []
            root.indexCount = 0
            return
        }
        const lines = text.trim().split("\n")
        const out = []
        for (var i = 0; i < lines.length; i++) {
            const tab = lines[i].indexOf("\t")
            if (tab < 0) continue
            const mtime = parseFloat(lines[i].substring(0, tab))
            const path  = lines[i].substring(tab + 1)
            const slash = path.lastIndexOf("/")
            const name  = slash >= 0 ? path.substring(slash + 1) : path
            out.push({
                id: "file:" + path,
                name: name,
                path: path,
                lastModified: mtime,
                _basename: name.toLowerCase()
            })
        }
        root.entries = out
        root.indexCount = out.length
    }

    // ─────────────────────────────────────────────────────────────
    // SEARCH
    //
    // Prefix match on basename gets top score, contains match gets
    // mid score, no match excluded. Up to 8 results returned, ordered
    // by score then by recency (newer first).
    // ─────────────────────────────────────────────────────────────
    function search(query) {
        if (!query || query.length < 2) return []
        const q = query.toLowerCase()

        const prefix = []
        const contains = []
        for (var i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]
            if (e._basename.indexOf(q) === 0) {
                prefix.push(e)
                if (prefix.length >= 16) break
            } else if (e._basename.indexOf(q) >= 0) {
                contains.push(e)
            }
        }

        // Take up to 8 total, prefix-match preferred
        const all = prefix.concat(contains).slice(0, 8)

        // Format as Spotlight result entries
        return all.map(function(e){
            return {
                id: e.id,
                title: e.name,
                subtitle: e.path.replace(root.home, "~"),
                icon: "description",   // Nerd Font \uf15b document icon
                surface: "file",
                page: "",
                _filePath: e.path
            }
        })
    }

    // ─────────────────────────────────────────────────────────────
    // OPEN — invoked when user picks a file result
    //
    // Uses xdg-open which routes to the user's configured handler
    // for the file's MIME type (text → editor, image → viewer, etc.)
    // ─────────────────────────────────────────────────────────────
    function open(filePath) {
        if (!filePath) return
        Quickshell.execDetached({
            command: ["xdg-open", filePath]
        })
    }

    // ─────────────────────────────────────────────────────────────
    // PERIODIC REFRESH
    //
    // Refresh every 5 minutes to catch new files. Hot-reload triggers
    // (inotify) are intentionally NOT used — they're complex and the
    // 5min cadence is fine for the "find a file I worked on recently"
    // use case.
    // ─────────────────────────────────────────────────────────────
    Timer {
        interval: 300000   // 5min
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
