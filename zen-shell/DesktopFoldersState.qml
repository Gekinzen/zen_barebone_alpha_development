pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DesktopFoldersState v7.0.0-beta.1-hf82w — Karui (軽い)
 *
 * squircle homescreen–style folder grouping for desktop icons.
 *
 * Folder data model:
 *   { id, name, members[], x, y }
 *
 *   id      — auto-assigned "f_001", "f_002" etc.
 *   name    — display label, default "New folder", user-editable
 *   members — array of entry names (e.g. ["steam", "Lutris"]) referencing
 *             DesktopIconsService.entries[].name. Order matters for the
 *             popup grid display.
 *   x, y    — fallback position (used when arrangeMode === "free"; in
 *             other modes the folder flows like any other icon)
 *
 * Persisted to: ~/.local/share/quickshell/zen-shell/desktop-folders.json
 *
 * Folders are ONLY rendered when DesktopIconsState.style === "squircle".
 * Switching back to default/pixel hides them but doesn't delete — state
 * is preserved so re-enabling squircle restores all folders.
 *
 * Public API:
 *   folderForMember(name)     → folder object or null
 *   visibleFolders()          → folders for current style
 *   createFolder(a, b)        → merge two icons into a new folder
 *   addToFolder(id, name)     → put an icon into existing folder
 *   removeFromFolder(id, name)→ take icon out (auto-deletes folder if <2 left)
 *   renameFolder(id, name)    → set display label
 *   deleteFolder(id)          → remove folder + un-orphan its members
 *   setFolderPos(id, x, y)    → update fallback position
 */
Singleton {
    id: root

    readonly property string statePath:
        Quickshell.dataPath("desktop-folders.json")

    property var folders: []        // array of folder objects
    property bool _loaded: false
    property int _nextId: 1

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        onLoaded: {
            const raw = (typeof text === "function") ? text() : text
            root._loadFromJson(raw)
            root._loaded = true
        }
        onLoadFailed: {
            // No existing file → start with empty folders
            root._loaded = true
        }
    }

    function _loadFromJson(raw) {
        if (!raw || raw.trim().length === 0) return
        try {
            const s = JSON.parse(raw)
            if (Array.isArray(s.folders)) {
                root.folders = s.folders
                // Find highest existing id so new ones don't collide
                let maxId = 0
                for (let i = 0; i < s.folders.length; i++) {
                    const m = (s.folders[i].id || "").match(/^f_(\d+)$/)
                    if (m && parseInt(m[1]) > maxId) maxId = parseInt(m[1])
                }
                root._nextId = maxId + 1
            }
        } catch (e) {
            console.error("[DesktopFoldersState] JSON parse error:", e)
        }
    }

    // ── Save (debounced) ──
    onFoldersChanged: { if (_loaded) saveTimer.restart() }
    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root._save()
    }
    function _save() {
        const json = JSON.stringify({ "folders": folders }, null, 2)
        const escaped = json.replace(/'/g, "'\\''")
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "tmp=$(mktemp) && printf '%s' '" + escaped + "' > \"$tmp\" && " +
            "mv \"$tmp\" '" + statePath + "'"]
        saver.running = true
    }
    Process { id: saver; running: false }

    // ── Public API ──

    function folderForMember(entryName) {
        if (!entryName) return null
        for (let i = 0; i < folders.length; i++) {
            const f = folders[i]
            if (f.members && f.members.indexOf(entryName) >= 0) return f
        }
        return null
    }

    function _findIndex(folderId) {
        for (let i = 0; i < folders.length; i++) {
            if (folders[i].id === folderId) return i
        }
        return -1
    }

    function createFolder(memberA, memberB, dropX, dropY) {
        if (!memberA || !memberB || memberA === memberB) return null
        // If either is ALREADY in a folder, just add the other into it
        // (don't nest folders).
        const fA = folderForMember(memberA)
        const fB = folderForMember(memberB)
        if (fA && !fB) { addToFolder(fA.id, memberB); return fA }
        if (fB && !fA) { addToFolder(fB.id, memberA); return fB }
        if (fA && fB)  { return null }  // both already foldered, no-op

        // Brand new folder
        const id = "f_" + String(_nextId++).padStart(3, "0")
        const newFolder = {
            "id": id,
            "name": _suggestName(memberA, memberB),
            "members": [memberA, memberB],
            "x": dropX || 0,
            "y": dropY || 0
        }
        const next = folders.slice()
        next.push(newFolder)
        folders = next

        notifier.command = ["notify-send", "-a", "Zen Shell",
            "-i", "folder", "-t", "2500",
            "Folder created",
            newFolder.name + "  ·  2 items"]
        notifier.running = true
        return newFolder
    }

    function addToFolder(folderId, entryName) {
        const idx = _findIndex(folderId)
        if (idx < 0 || !entryName) return
        // Skip if already a member
        if ((folders[idx].members || []).indexOf(entryName) >= 0) return
        const next = folders.slice()
        const merged = {}
        for (const k in next[idx]) merged[k] = next[idx][k]
        merged.members = (merged.members || []).slice()
        merged.members.push(entryName)
        next[idx] = merged
        folders = next
    }

    function removeFromFolder(folderId, entryName) {
        const idx = _findIndex(folderId)
        if (idx < 0) return
        const next = folders.slice()
        const merged = {}
        for (const k in next[idx]) merged[k] = next[idx][k]
        merged.members = (merged.members || []).filter(m => m !== entryName)
        // Auto-delete folder if only 0 or 1 member remains (no point keeping)
        if (merged.members.length < 2) {
            next.splice(idx, 1)
        } else {
            next[idx] = merged
        }
        folders = next
    }

    function renameFolder(folderId, newName) {
        const idx = _findIndex(folderId)
        if (idx < 0) return
        const next = folders.slice()
        const merged = {}
        for (const k in next[idx]) merged[k] = next[idx][k]
        merged.name = newName || "Folder"
        next[idx] = merged
        folders = next
    }

    function deleteFolder(folderId) {
        const idx = _findIndex(folderId)
        if (idx < 0) return
        const next = folders.slice()
        next.splice(idx, 1)
        folders = next
    }

    function setFolderPos(folderId, x, y) {
        const idx = _findIndex(folderId)
        if (idx < 0) return
        const next = folders.slice()
        const merged = {}
        for (const k in next[idx]) merged[k] = next[idx][k]
        merged.x = x
        merged.y = y
        next[idx] = merged
        folders = next
    }

    function clearAll() {
        folders = []
    }

    // Suggest a folder name based on common substring between two member names
    // (e.g. "Surviving Mars" + "Surviving Forest" → "Surviving")
    function _suggestName(a, b) {
        const aClean = (a || "").replace(/\.desktop$/, "")
        const bClean = (b || "").replace(/\.desktop$/, "")
        if (!aClean || !bClean) return "New folder"
        // Longest common prefix
        let i = 0
        while (i < aClean.length && i < bClean.length
               && aClean[i].toLowerCase() === bClean[i].toLowerCase()) i++
        const prefix = aClean.substring(0, i).trim()
        if (prefix.length >= 3) return prefix
        return "New folder"
    }

    Process { id: notifier; running: false }
}
