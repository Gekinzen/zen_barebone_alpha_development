pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * RecentFilesService v7.0.0-alpha.4 — recently-used.xbel parser
 *
 * Parses ~/.local/share/recently-used.xbel (XDG recent files spec —
 * the same file GNOME, Nautilus, GTK file dialogs, KDE, and most
 * other Linux apps write to). Surfaces the most-recently-modified
 * entries for the StartMenu panel's "Recent" section.
 *
 * Design notes:
 *
 *   - We do NOT use Quickshell's FileView for this because the file
 *     can be 200KB+ on heavy users; instead we shell-out to a tiny
 *     bash+grep pipeline that emits compact TSV. This keeps the QML
 *     parser path simple and avoids loading the full XML into the
 *     scene-graph context.
 *
 *   - The parser reads only the latest N entries (default 12) sorted
 *     by `modified` timestamp descending — most-recent-first.
 *
 *   - Refresh on:
 *       (1) shell start (5s warmup)
 *       (2) FileSystemWatcher would be ideal but requires a Process;
 *           we instead poll every 60s while the StartMenu panel is
 *           visible, plus a manual `refresh()` API the panel calls
 *           on its `onVisibleChanged`.
 *
 *   - Each entry surfaces: { name, uri, path, mimeType, modified,
 *     application, exists }. `exists` is computed by `test -e` — if
 *     a file was deleted, it still appears in xbel but we mark it
 *     so the UI can dim/hide it.
 *
 *   - The icon string returned is a freedesktop icon name derived
 *     from MIME (e.g. text/markdown → "text-x-generic"). The QML
 *     side resolves via Quickshell.iconPath() with a generic
 *     fallback.
 *
 * Wala tayong babawasan — service is purely additive. Absence of the
 * recently-used.xbel file just yields an empty model; no errors.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string xbelPath: home + "/.local/share/recently-used.xbel"

    // Tunable: how many recent entries to keep in memory. UI typically
    // shows 5-8; we keep a few extra for filtering.
    property int maxEntries: 12

    // Active poll only when StartMenu is open — saves CPU otherwise.
    property bool active: false

    // Output: array of { name, uri, path, mimeType, modified,
    //                    application, iconName, exists }
    property var entries: []
    property bool loading: false
    property string lastError: ""

    // ─────────────────────────────────────────────────────────────
    // PARSER (shell-side, TSV out)
    //
    // The xbel grammar:
    //   <bookmark href="file:///path/to/file" added="..." modified="..." visited="...">
    //     <info><metadata owner="..."><mime:mime-type type="text/plain"/>
    //       <bookmark:applications>
    //         <bookmark:application name="kitty" exec="..." count="3"/>
    //       </bookmark:applications>
    //     </metadata></info>
    //   </bookmark>
    //
    // We use awk to scan line-by-line: when we hit <bookmark href=, we
    // start a record; we track the most-recent <mime:mime-type and
    // <bookmark:application name from within; on </bookmark> we emit
    // the record. Then sort by modified desc, take top N.
    // ─────────────────────────────────────────────────────────────
    Process {
        id: parseProc
        running: false
        stdout: StdioCollector { onStreamFinished: root._parseTsv(this.text) }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text || ""
                if (t.trim()) root.lastError = t.trim().split("\n").pop()
            }
        }
        onExited: function(code, status) {
            root.loading = false
        }
    }

    function _parseTsv(text) {
        if (!text) { root.entries = []; return }
        const out = []
        const lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (!line || !line.trim()) continue
            const f = line.split("\t")
            if (f.length < 5) continue
            const uri = f[0]
            const modified = f[1]
            const mimeType = f[2]
            const application = f[3]
            const exists = f[4] === "1"
            // Decode file:// URI to a clean path for display
            var path = uri
            if (uri.indexOf("file://") === 0) {
                path = decodeURIComponent(uri.substring(7))
            }
            const slash = path.lastIndexOf("/")
            const name = slash >= 0 ? path.substring(slash + 1) : path
            out.push({
                name: name,
                uri: uri,
                path: path,
                mimeType: mimeType || "application/octet-stream",
                modified: modified,
                application: application || "",
                iconName: _iconForMime(mimeType),
                exists: exists
            })
        }
        root.entries = out
    }

    function _iconForMime(mime) {
        if (!mime) return "text-x-generic"
        if (mime.indexOf("image/") === 0) return "image-x-generic"
        if (mime.indexOf("video/") === 0) return "video-x-generic"
        if (mime.indexOf("audio/") === 0) return "audio-x-generic"
        if (mime === "application/pdf") return "application-pdf"
        if (mime.indexOf("text/") === 0) return "text-x-generic"
        if (mime === "application/zip" || mime.indexOf("compressed") >= 0) return "package-x-generic"
        return "text-x-generic"
    }

    function refresh() {
        if (root.loading) return
        root.loading = true
        root.lastError = ""
        // The bash+awk pipeline:
        //   1. Test xbel exists. If not, emit nothing.
        //   2. Stream xbel into awk; emit per-bookmark TSV lines:
        //        uri \t modified \t mime \t application \t exists
        //   3. Sort by modified DESC, take top N.
        const cmd = [
            "bash", "-c",
            "if [ ! -f '" + root.xbelPath + "' ]; then exit 0; fi; " +
            "awk '" +
            "  /<bookmark / { " +
            "    rec=1; href=\"\"; modified=\"\"; mime=\"\"; app=\"\"; " +
            "    if (match($0, /href=\"[^\"]*\"/)) href=substr($0,RSTART+6,RLENGTH-7); " +
            "    if (match($0, /modified=\"[^\"]*\"/)) modified=substr($0,RSTART+10,RLENGTH-11); " +
            "  } " +
            "  rec==1 && /<mime:mime-type/ { " +
            "    if (match($0, /type=\"[^\"]*\"/)) mime=substr($0,RSTART+6,RLENGTH-7); " +
            "  } " +
            "  rec==1 && /<bookmark:application/ && app==\"\" { " +
            "    if (match($0, /name=\"[^\"]*\"/)) app=substr($0,RSTART+6,RLENGTH-7); " +
            "  } " +
            "  /<\\/bookmark>/ && rec==1 { " +
            "    if (href != \"\") print href \"\\t\" modified \"\\t\" mime \"\\t\" app; " +
            "    rec=0; " +
            "  } " +
            "' '" + root.xbelPath + "' | " +
            // Sort by modified field (col 2) desc, take top N
            "sort -t$'\\t' -k2,2r | head -n " + (root.maxEntries) + " | " +
            // For each entry, append exists flag (1 if file readable, 0 else)
            "while IFS=$'\\t' read -r uri modi mime app; do " +
            "  path=\"${uri#file://}\"; " +
            "  path=$(printf '%b' \"${path//%/\\\\x}\"); " +
            "  ex=0; [ -e \"$path\" ] && ex=1; " +
            "  printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$uri\" \"$modi\" \"$mime\" \"$app\" \"$ex\"; " +
            "done"
        ]
        parseProc.command = cmd
        parseProc.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // POLLING — only while panel is open (active=true)
    // ─────────────────────────────────────────────────────────────
    Timer {
        interval: 60000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    // Initial load 5s after shell start (post-warmup so we don't
    // race the file system).
    Timer {
        interval: 5000
        repeat: false
        running: true
        onTriggered: root.refresh()
    }

    onActiveChanged: if (active) refresh()

    // ─────────────────────────────────────────────────────────────
    // OPEN — uses xdg-open to launch the file with the default app.
    // ─────────────────────────────────────────────────────────────
    function openEntry(entry) {
        if (!entry || !entry.uri) return
        Quickshell.execDetached({ command: ["xdg-open", entry.uri] })
    }

    // Format relative time string for UI ("2h ago", "3d ago")
    function relativeAge(iso) {
        if (!iso) return ""
        const t = new Date(iso).getTime()
        if (isNaN(t)) return ""
        const diff = Date.now() - t
        if (diff < 60000)         return "just now"
        if (diff < 3600000)       return Math.floor(diff / 60000) + "m ago"
        if (diff < 86400000)      return Math.floor(diff / 3600000) + "h ago"
        if (diff < 30 * 86400000) return Math.floor(diff / 86400000) + "d ago"
        return new Date(iso).toLocaleDateString()
    }
}
