pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * QuickNotesService v7.0.0-beta.1-hf82e — Karui (軽い)
 *
 * Instant markdown scratchpad. Triggered via:
 *   - Hot corner action: "toggleQuickNotes"
 *   - Global keybind: Super+N (defined in hyprland binds)
 *   - Bar module: QuickNotesModule (click → toggle panel)
 *
 * Each note is a small markdown file under:
 *   ~/.local/share/zen-notes/YYYY-MM-DD-HHMM.md
 *
 * Filename = creation timestamp so notes self-sort chronologically
 * in the sidebar. First non-empty line is used as the display title.
 *
 * Auto-save on every keystroke (debounced 500ms) — Paul never has to
 * Ctrl+S anything. Notes can be:
 *   - Pinned to top of sidebar (priority sorting)
 *   - Pinned-to-screen sticky mode (always-on-top floating window)
 *   - Tagged with #hashtags inline (parsed for sidebar filter)
 *
 * State file at ~/.config/quickshell/zen-shell/quick-notes.json holds
 * meta (pinned IDs, sticky IDs, current note ID). The actual note
 * content lives in the .md files themselves so they're greppable
 * outside the shell.
 *
 * Wala tayong babawasan — fully additive, brand new service.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // CONFIG / STATE
    // ─────────────────────────────────────────────────────────────
    property string notesDir: Quickshell.env("HOME") + "/.local/share/zen-notes"
    property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/quick-notes.json"

    // List of all loaded notes. Each entry:
    //   { id: "2026-05-16-1432", title: "...", body: "...",
    //     pinned: bool, sticky: bool, mtime: int, tags: [strings] }
    property var notes: []

    // Currently selected note ID (for the editor pane)
    property string currentNoteId: ""

    // Sticky notes — show as floating windows on top of everything
    property var stickyIds: []

    // v7.0.0-beta.1-hf46 — per-sticky position + draggable state.
    //
    // stickyPositions: { noteId: {x: int, y: int} }
    //   Saved position for each sticky. Loaded on shell start and
    //   on drag release. If a noteId has no entry, the sticky uses
    //   a stable hash-based fallback position (so multiple stickies
    //   spread out instead of perfectly stacking).
    //
    // stickyDraggable: { noteId: bool }
    //   Per-sticky widget-mode toggle. When true, the sticky is
    //   rendered as a desktop widget on the WlrLayer.Bottom surface
    //   (alongside clock/weather/CPU temp) — full drag system,
    //   below regular windows. When false, the sticky is an
    //   anchored overlay on WlrLayer.Overlay.
    //
    //   v7.0.0-beta.1-hf47: position is SHARED between modes — last
    //   position the user dragged to is remembered regardless of
    //   which mode it was in. User reported: "dapat maalala niya if
    //   san last position siya."
    property var stickyPositions: ({})
    property var stickyDraggable: ({})

    // v7.0.0-beta.1-hf47 — highlight signal.
    //
    // Fired by the Super+Shift+N IPC handler when toggle-panel is
    // invoked AND at least one sticky is currently in widget mode.
    // QuickNotesSticky / DesktopStickyNotes connect to this signal
    // and run a shake + glow + bounce animation so the user can
    // visually spot their widget-mode stickies among the rest of
    // the desktop.
    signal highlightWidgetStickies()

    function pulseHighlight() {
        highlightWidgetStickies()
    }

    // Count of stickies currently in widget mode — used by IPC
    // handler to decide whether to fire highlight.
    function widgetStickyCount() {
        let n = 0
        for (const id of root.stickyIds) {
            if (root.isStickyDraggable(id)) n++
        }
        return n
    }

    // Pinned notes — sort to top of sidebar
    property var pinnedIds: []

    // Search filter (live)
    property string searchQuery: ""

    // ─────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: {
        ensureDir.running = true
    }

    Process {
        id: ensureDir
        running: false
        command: ["bash", "-c", "mkdir -p '" + root.notesDir + "'"]
        onExited: {
            // After dir exists, scan + load meta
            scanProc.running = true
            loadStateProc.running = true
        }
    }

    // ─────────────────────────────────────────────────────────────
    // SCAN FILESYSTEM
    // ─────────────────────────────────────────────────────────────
    Process {
        id: scanProc
        running: false
        // List files with mtime. Format: <mtime>\t<id>\t<first_line>
        //
        // v7.0.0-beta.1-hf82e — TITLE EXTRACTION FIX.
        //
        // User report:
        //   "heto pre nagiging date siya ehh may mga notes ako jan
        //    dapat nakikita padin . lalabas lang yun actual messages
        //    kapag open ko yun sticky note natin"
        //
        // Calendar notes are created with body
        //   "📅 2026-05-23\nMy actual title\n..."
        // The previous extraction (`grep -m1 .`) grabbed the first
        // non-empty line — which for calendar notes is the 📅 date
        // line, not the user's typed text. Result: every calendar
        // note showed up as "📅 2026-05-23" in both the calendar
        // list AND the sticky notes panel sidebar, instead of the
        // actual title the user typed.
        //
        // hf82d only fixed the EDITOR INPUT display path. The list
        // rendering paths (calendar entry repeater + sticky panel
        // sidebar) read straight from `notes[].title`, which is set
        // here at scan time — so the stored .title was wrong, and
        // the QML side fallback `n.title || "(untitled)"` then
        // showed the bad value.
        //
        // Fix: use awk to find the first non-empty line that does
        // NOT start with 📅 (the calendar prefix). Fall back to the
        // 📅 line if there is no other content (legacy/empty notes).
        //
        // Wala tayong babawasan — the mtime + id + tags pipeline
        // is preserved; only the title extraction is corrected.
        command: ["bash", "-c",
            "cd '" + root.notesDir + "' 2>/dev/null && " +
            "for f in *.md; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  id=\"${f%.md}\"; " +
            "  mtime=$(stat -c%Y \"$f\" 2>/dev/null || echo 0); " +
            // hf82e: prefer first non-📅 non-empty line; fall back to
            // first non-empty line (covers legacy / non-calendar notes).
            "  title=$(awk 'NF && !/^📅/ {print; exit}' \"$f\" 2>/dev/null | head -c 80 | tr '\\n' ' '); " +
            "  if [ -z \"$title\" ]; then " +
            "    title=$(grep -m1 . \"$f\" 2>/dev/null | head -c 80 | tr '\\n' ' '); " +
            "  fi; " +
            "  echo \"$mtime|$id|$title\"; " +
            "done | sort -rn"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = (this.text || "").trim()
                const list = []
                if (txt) {
                    const lines = txt.split("\n")
                    for (let line of lines) {
                        const parts = line.split("|")
                        if (parts.length < 2) continue
                        const mtime = parseInt(parts[0]) || 0
                        const id = parts[1]
                        const titleRaw = parts.slice(2).join("|").trim()
                        list.push({
                            id: id,
                            title: titleRaw || "(untitled)",
                            body: "",   // loaded on demand when selected
                            pinned: root.pinnedIds.indexOf(id) >= 0,
                            sticky: root.stickyIds.indexOf(id) >= 0,
                            mtime: mtime,
                            tags: root._extractTags(titleRaw)
                        })
                    }
                }
                root.notes = list

                // v7.0.0-beta.1-hf74 — restore bodies from JSON backup.
                //
                // If a .md file is empty/untitled BUT the JSON state
                // has body content (from the last successful save),
                // restore the .md file from the backup. This recovers
                // content lost when `pkill quickshell` killed the
                // process before the body-write debounce flushed.
                if (Object.keys(root._loadedBodies).length > 0) {
                    let restored = 0
                    for (let i = 0; i < list.length; i++) {
                        const note = list[i]
                        const backup = root._loadedBodies[note.id]
                        if (backup && backup.length > 0
                            && (note.title === "(untitled)" || note.title === "(new note)" || note.title === "")) {
                            // Restore .md file from JSON backup
                            try {
                                root._writeBodyFile(note.id, backup)
                                // Update in-memory
                                const firstLine = backup.split("\n")[0].trim().slice(0, 80)
                                list[i] = Object.assign({}, note, {
                                    body: backup,
                                    title: firstLine || "(restored)",
                                    tags: root._extractTags(backup)
                                })
                                restored++
                            } catch (e) {
                                console.warn("[QuickNotes] restore error for", note.id, ":", e)
                            }
                        }
                    }
                    if (restored > 0) {
                        root.notes = list
                        console.log("[QuickNotes hf74] restored", restored, "note(s) from JSON backup")
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // STATE PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    // v7.0.0-beta.1-hf74 — cached body backup from JSON state file.
    // Populated on state load, consumed by post-scan restore.
    property var _loadedBodies: ({})

    Process {
        id: loadStateProc
        running: false
        command: ["bash", "-c", "cat '" + root.statePath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (Array.isArray(j.pinnedIds)) root.pinnedIds = j.pinnedIds
                    if (Array.isArray(j.stickyIds)) root.stickyIds = j.stickyIds
                    if (typeof j.currentNoteId === "string") root.currentNoteId = j.currentNoteId
                    // v7.0.0-beta.1-hf46 — per-sticky position + draggable
                    // restore. Both default to empty objects if the
                    // saved file predates hf46.
                    if (j.stickyPositions && typeof j.stickyPositions === "object")
                        root.stickyPositions = j.stickyPositions
                    if (j.stickyDraggable && typeof j.stickyDraggable === "object")
                        root.stickyDraggable = j.stickyDraggable
                    // v7.0.0-beta.1-hf74 — body backup cache
                    if (j.bodies && typeof j.bodies === "object")
                        root._loadedBodies = j.bodies
                    // v7.0.0-beta.1-hf75 — calendar note metadata
                    if (j.notesMeta && typeof j.notesMeta === "object")
                        root.notesMeta = j.notesMeta
                } catch (e) {
                    console.warn("[QuickNotes] state parse:", e)
                }
            }
        }
    }

    Process { id: saveStateProc; running: false }
    Timer {
        id: saveStateDebounce
        interval: 400
        repeat: false
        onTriggered: root._doSaveState()
    }

    // v7.0.0-beta.1-hf74 — bodies backup in JSON state file.
    //
    // Problem: `pkill quickshell` sends SIGKILL which kills the
    // process before the body-write debounce flushes to disk. User
    // loses unsaved text.
    //
    // Fix: every state save also includes a `bodies` object mapping
    // note ID → body content for all notes with loaded body. This
    // serves as a crash-safe backup:
    //   - Normal operation: .md files are the source of truth
    //   - After crash/SIGKILL: on next load, if .md file is empty
    //     or missing but JSON has body content, restore from JSON
    //
    // Also: saveBody() now triggers an immediate state save (not
    // just the 500ms body-write debounce) so the JSON backup is
    // always at most 400ms stale.
    function _doSaveState() {
        // Collect body backup for all notes with loaded content
        const bodies = {}
        for (const note of root.notes) {
            if (note.body && note.body.length > 0) {
                bodies[note.id] = note.body
            }
        }
        const obj = {
            pinnedIds: root.pinnedIds,
            stickyIds: root.stickyIds,
            currentNoteId: root.currentNoteId,
            // v7.0.0-beta.1-hf46 — sticky window state persistence
            stickyPositions: root.stickyPositions,
            stickyDraggable: root.stickyDraggable,
            // v7.0.0-beta.1-hf74 — body backup (crash-safe)
            bodies: bodies,
            // v7.0.0-beta.1-hf75 — calendar note metadata
            notesMeta: root.notesMeta
        }
        saveStateProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
            "cat > '" + root.statePath + "' << 'EOF'\n" +
            JSON.stringify(obj, null, 2) + "\nEOF"]
        saveStateProc.running = true
    }

    // v7.0.0-beta.1-hf74 — force flush all pending saves NOW.
    // Called before shutdown, before export, etc.
    function flushAll() {
        // Force body write if pending
        if (root._pendingBodyId) {
            try {
                root._writeBodyFile(root._pendingBodyId, root._pendingBodyContent)
            } catch (e) {
                console.warn("[QuickNotes] flush body error:", e)
            }
        }
        // Force state save (includes bodies backup)
        root._doSaveState()
    }

    // v7.0.0-beta.1-hf74 — export all notes to JSON file.
    // Returns the export path. Preserves all content.
    function exportToJson() {
        root.flushAll()
        const exportData = {
            exportedAt: new Date().toISOString(),
            zenShellVersion: (typeof ZenVersion !== "undefined") ? ZenVersion.version : "unknown",
            notes: root.notes.map(function(n) {
                return {
                    id: n.id,
                    title: n.title,
                    body: n.body || "",
                    pinned: n.pinned || false,
                    sticky: n.sticky || false,
                    mtime: n.mtime || 0,
                    tags: n.tags || []
                }
            })
        }
        const exportPath = root.notesDir + "/zen-notes-export-"
                         + new Date().toISOString().replace(/[:.]/g, "-") + ".json"
        exportWriter.path = exportPath
        exportWriter.setText(JSON.stringify(exportData, null, 2))
        console.log("[QuickNotes] exported to:", exportPath)
        return exportPath
    }

    FileView {
        id: exportWriter
        path: ""
        atomicWrites: true
        blockWrites: false
    }

    onPinnedIdsChanged: saveStateDebounce.restart()
    onStickyIdsChanged: saveStateDebounce.restart()
    onCurrentNoteIdChanged: saveStateDebounce.restart()
    onStickyPositionsChanged: saveStateDebounce.restart()
    onStickyDraggableChanged: saveStateDebounce.restart()

    // ─────────────────────────────────────────────────────────────
    // PUBLIC API
    // ─────────────────────────────────────────────────────────────
    /**
     * Create a new note now. Returns the new note ID (timestamp).
     * Selects the new note as current. The note starts empty —
     * editor pane will autosave content as user types.
     */
    function createNote() {
        const now = new Date()
        const pad = (n) => (n < 10 ? "0" + n : "" + n)
        const id = now.getFullYear() + "-"
                 + pad(now.getMonth() + 1) + "-"
                 + pad(now.getDate()) + "-"
                 + pad(now.getHours())
                 + pad(now.getMinutes())
                 + pad(now.getSeconds())

        createProc.command = ["bash", "-c",
            "touch '" + root.notesDir + "/" + id + ".md'"]
        createProc.running = true

        // Optimistically prepend to notes list
        const newNote = {
            id: id,
            title: "(new note)",
            body: "",
            pinned: false,
            sticky: false,
            mtime: Math.floor(Date.now() / 1000),
            tags: []
        }
        const copy = [newNote].concat(root.notes)
        root.notes = copy
        root.currentNoteId = id
        return id
    }

    Process { id: createProc; running: false }

    /**
     * Load body content of a note from disk into the notes[] entry.
     */
    function loadBody(id) {
        loadBodyProc.command = ["cat", root.notesDir + "/" + id + ".md"]
        loadBodyProc._targetId = id
        loadBodyProc.running = true
    }

    Process {
        id: loadBodyProc
        running: false
        property string _targetId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text || ""
                const id = loadBodyProc._targetId
                // Update the body of the matching note
                const copy = root.notes.slice()
                for (let i = 0; i < copy.length; i++) {
                    if (copy[i].id === id) {
                        copy[i] = Object.assign({}, copy[i], {
                            body: txt,
                            tags: root._extractTags(txt)
                        })
                        break
                    }
                }
                root.notes = copy
            }
        }
    }

    /**
     * Save body content to disk. Debounced via saveBodyDebounce.
     */
    property string _pendingBodyId: ""
    property string _pendingBodyContent: ""

    function saveBody(id, content) {
        root._pendingBodyId = id
        root._pendingBodyContent = content
        // Update in-memory immediately for snappy UI
        const copy = root.notes.slice()
        for (let i = 0; i < copy.length; i++) {
            if (copy[i].id === id) {
                const firstLine = (content || "").split("\n")[0].trim().slice(0, 80)
                copy[i] = Object.assign({}, copy[i], {
                    body: content,
                    title: firstLine || "(untitled)",
                    mtime: Math.floor(Date.now() / 1000),
                    tags: root._extractTags(content)
                })
                break
            }
        }
        root.notes = copy
        saveBodyDebounce.restart()
        // hf74 — also save state (includes bodies backup in JSON)
        // so even if pkill kills us before bodyDebounce fires,
        // the JSON has the content.
        saveStateDebounce.restart()
    }

    Timer {
        id: saveBodyDebounce
        interval: 500
        repeat: false
        onTriggered: {
            if (!root._pendingBodyId) return
            // Use bash heredoc with a unique delimiter to avoid escape hell
            const id = root._pendingBodyId
            const path = root.notesDir + "/" + id + ".md"
            // Pass content via stdin to bash, not as argv (avoids shell escape)
            saveBodyProc.command = ["bash", "-c",
                "cat > '" + path + "'"
            ]
            saveBodyProc.stdinEnabled = true
            saveBodyProc.running = true
        }
    }

    Process {
        id: saveBodyProc
        running: false
        // We'd use stdinEnabled if available, but for compatibility
        // we use a different approach: write via temp file + mv atomic
    }

    // Simpler save approach using FileView so we don't have to worry
    // about stdin or shell escape. FileView.setText is atomic with
    // atomicWrites: true. Below is the per-note write loop.
    function _writeBodyFile(id, content) {
        // Set up the FileView temporarily
        bodyWriter.path = root.notesDir + "/" + id + ".md"
        bodyWriter.setText(content)
    }

    FileView {
        id: bodyWriter
        path: ""
        atomicWrites: true
        blockWrites: false
    }

    // Override saveBodyDebounce.onTriggered to use the FileView path
    Connections {
        target: saveBodyDebounce
        function onTriggered() {
            if (!root._pendingBodyId) return
            try {
                root._writeBodyFile(root._pendingBodyId, root._pendingBodyContent)
            } catch (e) {
                console.warn("[QuickNotes] save error:", e)
            }
        }
    }

    function deleteNote(id) {
        if (!id) return
        deleteProc.command = ["rm", "-f", root.notesDir + "/" + id + ".md"]
        deleteProc.running = true
        // Drop from arrays
        root.notes = root.notes.filter(n => n.id !== id)
        root.pinnedIds = root.pinnedIds.filter(x => x !== id)
        root.stickyIds = root.stickyIds.filter(x => x !== id)
        if (root.currentNoteId === id) {
            root.currentNoteId = root.notes.length > 0 ? root.notes[0].id : ""
        }
    }

    Process { id: deleteProc; running: false }

    function togglePin(id) {
        const i = root.pinnedIds.indexOf(id)
        if (i >= 0) {
            root.pinnedIds = root.pinnedIds.filter(x => x !== id)
        } else {
            root.pinnedIds = root.pinnedIds.concat([id])
        }
        // Update in-memory note's pinned flag
        const copy = root.notes.slice()
        for (let k = 0; k < copy.length; k++) {
            if (copy[k].id === id) {
                copy[k] = Object.assign({}, copy[k], { pinned: root.pinnedIds.indexOf(id) >= 0 })
                break
            }
        }
        root.notes = copy
    }

    function toggleSticky(id) {
        const i = root.stickyIds.indexOf(id)
        if (i >= 0) {
            root.stickyIds = root.stickyIds.filter(x => x !== id)
        } else {
            root.stickyIds = root.stickyIds.concat([id])
        }
        const copy = root.notes.slice()
        for (let k = 0; k < copy.length; k++) {
            if (copy[k].id === id) {
                copy[k] = Object.assign({}, copy[k], { sticky: root.stickyIds.indexOf(id) >= 0 })
                break
            }
        }
        root.notes = copy
    }

    // ─────────────────────────────────────────────────────────────
    // STICKY POSITION + DRAGGABLE API (hf46)
    // ─────────────────────────────────────────────────────────────
    //
    // These mirror the per-widget pattern in DesktopWidgets.qml —
    // each sticky stores its position imperatively (not via
    // declarative binding) so it doesn't fight with drag.target
    // during an active drag gesture.
    //
    // setStickyPosition(id, x, y):
    //   Called by QuickNotesSticky.qml on drag release to persist the
    //   new top-left coords. We replace the WHOLE stickyPositions map
    //   in one assignment so QML's `onStickyPositionsChanged` fires —
    //   property change detection on `var` objects only triggers on
    //   reassignment, not in-place mutation.
    //
    // getStickyPosition(id):
    //   Returns {x, y} for the given note, or null if none saved.
    //   Caller falls back to a hash-based offset.
    //
    // setStickyDraggable(id, bool):
    //   Toggle per-sticky draggable. UI pill toggle calls this.
    //
    // isStickyDraggable(id):
    //   Returns the per-sticky bool, defaulting to false. Defaulting
    //   to false matches the user's request: "kapag activate natin
    //   yun draggable din siya" — meaning the toggle starts OFF and
    //   the user opts in per sticky.

    function setStickyPosition(id, x, y) {
        if (!id) return
        const copy = Object.assign({}, root.stickyPositions)
        copy[id] = { x: Math.round(x), y: Math.round(y) }
        root.stickyPositions = copy
    }

    function getStickyPosition(id) {
        if (!id) return null
        const p = root.stickyPositions[id]
        if (p && typeof p.x === "number" && typeof p.y === "number") {
            return p
        }
        return null
    }

    function setStickyDraggable(id, value) {
        if (!id) return
        const copy = Object.assign({}, root.stickyDraggable)
        copy[id] = !!value
        root.stickyDraggable = copy
    }

    function isStickyDraggable(id) {
        if (!id) return false
        return root.stickyDraggable[id] === true
    }

    function selectNote(id) {
        root.currentNoteId = id
        // If body not loaded yet, load it
        const n = root.getNote(id)
        if (n && (!n.body || n.body.length === 0)) {
            loadBody(id)
        }
    }

    function getNote(id) {
        for (let n of root.notes) {
            if (n.id === id) return n
        }
        return null
    }

    function getCurrentNote() {
        return root.getNote(root.currentNoteId)
    }

    /**
     * Filtered note list — applies pinned-first sort + search filter.
     */
    function filteredNotes() {
        const q = (root.searchQuery || "").toLowerCase()
        let list = root.notes.slice()
        if (q) {
            list = list.filter(n =>
                (n.title || "").toLowerCase().indexOf(q) >= 0
                || (n.body || "").toLowerCase().indexOf(q) >= 0
                || (n.tags || []).some(t => t.toLowerCase().indexOf(q) >= 0)
            )
        }
        // Pinned first, then mtime desc
        list.sort((a, b) => {
            if (a.pinned && !b.pinned) return -1
            if (!a.pinned && b.pinned) return 1
            return b.mtime - a.mtime
        })
        return list
    }

    // ─────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────
    function _extractTags(text) {
        if (!text) return []
        const matches = String(text).match(/#[\w-]+/g) || []
        return matches.map(t => t.slice(1))
    }

    // ─────────────────────────────────────────────────────────────
    // v7.0.0-beta.1-hf75 — CALENDAR + STICKY NOTES INTEGRATION
    //
    // Adds optional per-note metadata for calendar integration:
    //   - calendarDate: "YYYY-MM-DD" string (which date this note is linked to)
    //   - notifyTime: "HH:MM" string (when to fire notification, empty = no notify)
    //   - completed: bool (past events auto-marked, stops re-notifying)
    //   - notified: bool (already fired this session, prevents spam)
    //
    // Stored in quick-notes.json as notesMeta: { noteId: {...}, ... }
    // Fully backward compatible — missing notesMeta = empty object.
    //
    // EXISTING NOTES ARE NEVER TOUCHED — this is purely additive.
    // Notes without calendarDate work exactly as before (plain sticky notes).
    // ─────────────────────────────────────────────────────────────

    // Per-note calendar metadata. Populated from state file on load.
    // { "note-id": { calendarDate: "2026-05-18", notifyTime: "09:00",
    //                completed: false, notified: false }, ... }
    property var notesMeta: ({})

    // Computed: map of "YYYY-MM-DD" → count of notes on that date.
    // Used by calendar grid to show dot indicators on days with notes.
    property var notesByDate: {
        const map = {}
        const meta = root.notesMeta || {}
        for (const noteId in meta) {
            const d = meta[noteId].calendarDate || ""
            if (d) {
                if (!map[d]) map[d] = 0
                map[d]++
            }
        }
        return map
    }

    // Get all notes for a specific date.
    function getNotesForDate(dateStr) {
        const result = []
        const meta = root.notesMeta || {}
        for (const note of root.notes) {
            const m = meta[note.id]
            if (m && m.calendarDate === dateStr) {
                result.push(note)
            }
        }
        return result
    }

    // Create a new note linked to a calendar date.
    // Returns the note ID. The note appears in both the calendar
    // AND the sticky notes sidebar — fully synced.
    function createCalendarNote(dateStr, title, notifyTime) {
        const id = root.createNote()
        // Set the initial body to include the date + title
        const body = "📅 " + dateStr + "\n" + (title || "") + "\n"
        root.saveBody(id, body)
        // Store calendar metadata
        const meta = Object.assign({}, root.notesMeta)
        meta[id] = {
            calendarDate: dateStr,
            notifyTime: notifyTime || "",
            completed: false,
            notified: false
        }
        root.notesMeta = meta
        saveStateDebounce.restart()
        return id
    }

    // Mark a calendar note as completed. Stops re-notifying.
    function markCompleted(noteId) {
        const meta = Object.assign({}, root.notesMeta)
        if (meta[noteId]) {
            meta[noteId] = Object.assign({}, meta[noteId], { completed: true })
            root.notesMeta = meta
            saveStateDebounce.restart()
        }
    }

    // Check if a date has any notes.
    function hasNotesOnDate(dateStr) {
        return (root.notesByDate[dateStr] || 0) > 0
    }

    onNotesMetaChanged: saveStateDebounce.restart()

    // ── Notification scheduler ──
    //
    // Every 60s, scans notesMeta for notes where:
    //   - calendarDate is today
    //   - notifyTime is within the next 5 minutes
    //   - completed=false AND notified=false
    //
    // Fires notify-send and marks notified=true for this session.
    // Past events (calendarDate < today) are auto-completed.
    Process { id: notifyProc; running: false }

    Timer {
        id: calendarNotifyTimer
        interval: 60000   // 1 minute
        repeat: true
        running: true
        onTriggered: root._checkCalendarNotifications()
    }

    // Also check on boot (after a short delay for notes to load)
    Timer { interval: 5000; running: true; repeat: false; onTriggered: root._checkCalendarNotifications() }

    function _checkCalendarNotifications() {
        const now = new Date()
        const todayStr = _dateToStr(now)
        const nowMinutes = now.getHours() * 60 + now.getMinutes()
        const meta = Object.assign({}, root.notesMeta)
        let changed = false

        for (const noteId in meta) {
            const m = meta[noteId]
            if (!m || !m.calendarDate) continue

            // Auto-complete past events
            if (m.calendarDate < todayStr && !m.completed) {
                meta[noteId] = Object.assign({}, m, { completed: true })
                changed = true
                continue
            }

            // Skip completed or already notified
            if (m.completed || m.notified) continue

            // Check if today + within notification window
            if (m.calendarDate === todayStr && m.notifyTime) {
                const parts = m.notifyTime.split(":")
                const targetMinutes = parseInt(parts[0] || "0") * 60 + parseInt(parts[1] || "0")
                const diff = targetMinutes - nowMinutes
                // Notify if within 5 minutes or up to 10 minutes late
                if (diff >= -10 && diff <= 5) {
                    // Find the note title
                    let title = "Calendar reminder"
                    for (const n of root.notes) {
                        if (n.id === noteId) { title = n.title || title; break }
                    }
                    // Fire notification
                    notifyProc.command = ["notify-send",
                        "-u", "normal",
                        "-a", "Zen Shell Calendar",
                        "📅 " + m.notifyTime + " — " + title,
                        m.calendarDate]
                    notifyProc.running = true
                    meta[noteId] = Object.assign({}, m, { notified: true })
                    changed = true
                }
            }
        }

        if (changed) {
            root.notesMeta = meta
            saveStateDebounce.restart()
        }
    }

    function _dateToStr(d) {
        const pad = (n) => (n < 10 ? "0" + n : "" + n)
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    }

    /**
     * Total unread / recent count for the bar module badge.
     * Currently just returns total note count, but could be extended
     * to track "viewed since last bar click."
     */
    function totalCount() {
        return root.notes.length
    }

    function stickyCount() {
        return root.stickyIds.length
    }
}
