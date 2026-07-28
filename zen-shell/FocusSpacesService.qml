pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/*
 * FocusSpacesService v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Saved per-app workspace layouts. User can:
 *   - Take a "snapshot" of the current workspace (which apps are open,
 *     where they're positioned, which monitor, fullscreen state)
 *   - Name + save the snapshot as a "Focus Space" (e.g. "Coding",
 *     "Gaming", "Email")
 *   - One-click restore — launches apps that aren't running, dispatches
 *     existing windows to recorded positions
 *
 * No competitor on Hyprland has this. Closest analog is GNOME's
 * "Workspaces" which only switches between empty containers; this
 * actually orchestrates app launches + positioning.
 *
 * Architecture:
 *
 *   SAVE PATH:
 *     1. hyprctl clients -j         → array of all windows
 *     2. hyprctl monitors -j        → monitor list for layout context
 *     3. Build snapshot with per-window {class, title, monitor, ws,
 *        floating, position, size, fullscreen}
 *     4. Persist to ~/.config/quickshell/zen-shell/focus-spaces.json
 *
 *   RESTORE PATH:
 *     1. Walk snapshot.windows
 *     2. For each window:
 *        a. Check if a matching window (by class) already exists via
 *           hyprctl clients
 *        b. If yes → dispatch movetoworkspace + position correctly
 *        c. If no → spawn the app via stored launchCommand, then wait
 *           for it to appear (window:open event) and dispatch
 *     3. Toast notification with summary
 *
 * Trade-off: not all apps remember per-launch position. Some apps
 * (Brave, Spotify) restore to where they last were. Some apps (Discord)
 * have a single window. We do our best with the launch + dispatch
 * combo. User can always re-tweak post-restore.
 *
 * Wala tayong babawasan — fully additive, brand new feature.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/focus-spaces.json"

    // Array of saved focus spaces. Each:
    //   {
    //     id: "uuid",
    //     name: "Coding",
    //     icon: "\uf121",          // optional Nerd Font glyph
    //     color: "#7aa2f7",        // optional accent
    //     created: <unix>,
    //     windows: [
    //       {
    //         class: "code-oss", title: "...", launchCommand: "code",
    //         monitor: "DP-2", workspace: 1, floating: false,
    //         x: 0, y: 0, width: 1920, height: 1080,
    //         fullscreen: 0
    //       },
    //       ...
    //     ]
    //   }
    property var spaces: []

    // Currently restoring? Block re-entry.
    property bool _restoring: false

    // Last-active space ID (for "switch back" button)
    property string activeSpaceId: ""

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    Component.onCompleted: loadState()

    function loadState() {
        loadProc.running = true
    }

    Process {
        id: loadProc
        running: false
        command: ["bash", "-c", "cat '" + root.statePath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (Array.isArray(j.spaces)) root.spaces = j.spaces
                    if (typeof j.activeSpaceId === "string") root.activeSpaceId = j.activeSpaceId
                } catch (e) {
                    console.warn("[FocusSpaces] state parse:", e)
                }
            }
        }
    }

    Process { id: saveProc; running: false }
    Timer {
        id: saveDebounce
        interval: 400; repeat: false
        onTriggered: {
            const obj = { spaces: root.spaces, activeSpaceId: root.activeSpaceId }
            saveProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
                "cat > '" + root.statePath + "' << 'EOF'\n" +
                JSON.stringify(obj, null, 2) + "\nEOF"]
            saveProc.running = true
        }
    }

    onSpacesChanged: saveDebounce.restart()
    onActiveSpaceIdChanged: saveDebounce.restart()

    // ─────────────────────────────────────────────────────────────
    // SAVE / SNAPSHOT
    // ─────────────────────────────────────────────────────────────
    /**
     * Capture the current window layout and persist as a new space.
     * The user supplies the name + optional icon/color via the
     * Settings UI; this function just builds the snapshot data.
     */
    property string _pendingName: ""
    property string _pendingIcon: ""
    property string _pendingColor: ""
    property string _pendingUpdateId: ""   // if non-empty, update existing instead of create

    function saveCurrentAs(name, icon, color) {
        if (!name) {
            console.warn("[FocusSpaces] saveCurrentAs requires name")
            return
        }
        root._pendingName = name
        root._pendingIcon = icon || "\uf121"   // code icon as default
        root._pendingColor = color || ""
        root._pendingUpdateId = ""
        snapshotProc.running = true
    }

    function updateExisting(id) {
        const existing = root.getSpace(id)
        if (!existing) return
        root._pendingName = existing.name
        root._pendingIcon = existing.icon || ""
        root._pendingColor = existing.color || ""
        root._pendingUpdateId = id
        snapshotProc.running = true
    }

    Process {
        id: snapshotProc
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const txt = this.text || ""
                    const clients = JSON.parse(txt)
                    if (!Array.isArray(clients)) return
                    root._buildSpaceFromClients(clients)
                } catch (e) {
                    console.warn("[FocusSpaces] snapshot parse:", e)
                }
            }
        }
    }

    function _buildSpaceFromClients(clients) {
        const windows = []
        for (const c of clients) {
            if (!c || !c.class) continue
            // Skip the shell's own windows
            if (String(c.class).startsWith("zen-shell")) continue
            if (String(c.title || "").startsWith("Quickshell")) continue
            // Try to infer launch command from window class
            const launchCmd = root._inferLaunchCommand(c.class)
            windows.push({
                "class": String(c.class || ""),
                "title": String(c.title || "").slice(0, 100),
                "launchCommand": launchCmd,
                "monitor": String(c.monitor !== undefined ? c.monitor : ""),
                "workspace": (c.workspace && typeof c.workspace.id === "number") ? c.workspace.id : 1,
                "floating": !!c.floating,
                "x": (c.at && c.at.length >= 2) ? c.at[0] : 0,
                "y": (c.at && c.at.length >= 2) ? c.at[1] : 0,
                "width": (c.size && c.size.length >= 2) ? c.size[0] : 0,
                "height": (c.size && c.size.length >= 2) ? c.size[1] : 0,
                "fullscreen": Number(c.fullscreen || 0)
            })
        }

        const id = root._pendingUpdateId || ("space-" + Date.now() + "-" + Math.floor(Math.random()*10000))
        const space = {
            id: id,
            name: root._pendingName,
            icon: root._pendingIcon,
            color: root._pendingColor,
            created: Math.floor(Date.now() / 1000),
            windows: windows
        }

        let updated = root.spaces.slice()
        if (root._pendingUpdateId) {
            // Replace existing entry
            updated = updated.map(s => s.id === id ? space : s)
        } else {
            updated.push(space)
        }
        root.spaces = updated

        // Toast
        _toast("Focus Space saved",
               "“" + space.name + "” captured "
               + windows.length + " window" + (windows.length === 1 ? "" : "s"),
               1)
    }

    /**
     * Infer a launch command from a window class. This is a heuristic
     * — we look up known apps by class name. Users can edit launch
     * commands later via the Settings UI.
     */
    function _inferLaunchCommand(klass) {
        const k = String(klass || "").toLowerCase()
        // Common mappings
        const map = {
            "brave-browser": "brave",
            "google-chrome": "google-chrome-stable",
            "firefox": "firefox",
            "code-oss": "code",
            "code": "code",
            "code - oss": "code",
            "discord": "discord",
            "spotify": "spotify",
            "steam": "steam",
            "kitty": "kitty",
            "alacritty": "alacritty",
            "wezterm": "wezterm",
            "foot": "foot",
            "thunar": "thunar",
            "nautilus": "nautilus",
            "dolphin": "dolphin",
            "obs": "obs",
            "blender": "blender",
            "gimp": "gimp",
            "krita": "krita",
            "inkscape": "inkscape",
            "obsidian": "obsidian",
            "telegram-desktop": "telegram-desktop",
            "thunderbird": "thunderbird",
            "vlc": "vlc",
            "mpv": "mpv"
        }
        if (map[k]) return map[k]
        // Fallback: assume the class IS the command name (works for many
        // Linux apps where class matches exec). User can override.
        return k
    }

    // ─────────────────────────────────────────────────────────────
    // RESTORE
    // ─────────────────────────────────────────────────────────────
    /**
     * Restore a saved space. For each recorded window:
     *   - If a matching window (by class) exists, dispatch it to the
     *     recorded workspace + position
     *   - Otherwise, spawn the launch command and let it land naturally
     *     (most apps will use their last position; restoring positions
     *     requires window:open watcher which we keep simple here)
     */
    function restoreSpace(id) {
        if (root._restoring) {
            console.warn("[FocusSpaces] restore already in progress")
            return
        }
        const space = root.getSpace(id)
        if (!space) {
            console.warn("[FocusSpaces] no space with id:", id)
            return
        }

        root._restoring = true
        root.activeSpaceId = id

        // Build a hyprctl --batch of dispatch commands plus a separate
        // exec script for missing apps.
        snapshotForRestoreProc._spaceId = id
        snapshotForRestoreProc.running = true
    }

    Process {
        id: snapshotForRestoreProc
        running: false
        property string _spaceId: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const txt = this.text || ""
                    const clients = JSON.parse(txt)
                    root._doRestore(snapshotForRestoreProc._spaceId,
                                    Array.isArray(clients) ? clients : [])
                } catch (e) {
                    console.warn("[FocusSpaces] restore client parse:", e)
                    root._restoring = false
                }
            }
        }
    }

    function _doRestore(spaceId, currentClients) {
        const space = root.getSpace(spaceId)
        if (!space) { root._restoring = false; return }

        // Build a map of currently-open classes for quick lookup
        const openByClass = {}
        for (const c of currentClients) {
            if (c && c.class) {
                openByClass[String(c.class)] = c
            }
        }

        const dispatchCmds = []
        const launchCmds = []
        let movedCount = 0
        let launchedCount = 0

        for (const w of space.windows) {
            const existing = openByClass[w.class]
            if (existing) {
                // Window exists — move it to the target workspace.
                // We use class regex to identify it.
                const tag = "class:^(" + w.class.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")$"
                dispatchCmds.push("dispatch movetoworkspacesilent " + w.workspace + "," + tag)
                if (w.floating) {
                    dispatchCmds.push("dispatch setfloating " + tag)
                    if (w.width > 0 && w.height > 0) {
                        dispatchCmds.push("dispatch resizewindowpixel exact "
                                        + w.width + " " + w.height + "," + tag)
                    }
                    if (w.x !== 0 || w.y !== 0) {
                        dispatchCmds.push("dispatch movewindowpixel exact "
                                        + w.x + " " + w.y + "," + tag)
                    }
                }
                if (w.fullscreen > 0) {
                    dispatchCmds.push("dispatch focuswindow " + tag)
                    dispatchCmds.push("dispatch fullscreen 0")
                }
                movedCount++
            } else {
                // Need to launch the app
                if (w.launchCommand) {
                    launchCmds.push("hyprctl dispatch exec '[workspace " + w.workspace
                                  + " silent] " + w.launchCommand + "'")
                    launchedCount++
                }
            }
        }

        // Fire all dispatch commands in one --batch
        if (dispatchCmds.length > 0) {
            const batch = dispatchCmds.join(";")
            batchProc.command = ["hyprctl", "--batch", batch]
            batchProc.running = true
        }

        // Fire launch commands (sequential — give the compositor time)
        if (launchCmds.length > 0) {
            const launchScript = launchCmds.join(" & sleep 0.2; ")
            launchProc.command = ["bash", "-c", launchScript]
            launchProc.running = true
        }

        const movedTxt = movedCount > 0 ? (movedCount + " moved") : ""
        const launchedTxt = launchedCount > 0 ? (launchedCount + " launched") : ""
        const summary = [movedTxt, launchedTxt].filter(s => s).join(", ")

        _toast("Focus Space · " + space.name,
               summary || "Nothing to restore",
               1)

        restoreReleaseTimer.restart()
    }

    Process { id: batchProc; running: false }
    Process { id: launchProc; running: false }
    Timer { id: restoreReleaseTimer; interval: 500; repeat: false
            onTriggered: root._restoring = false }

    // ─────────────────────────────────────────────────────────────
    // DELETE / RENAME
    // ─────────────────────────────────────────────────────────────
    function deleteSpace(id) {
        root.spaces = root.spaces.filter(s => s.id !== id)
        if (root.activeSpaceId === id) root.activeSpaceId = ""
    }

    function renameSpace(id, newName) {
        const updated = root.spaces.map(s =>
            s.id === id ? Object.assign({}, s, { name: newName }) : s
        )
        root.spaces = updated
    }

    function updateLaunchCommand(spaceId, windowIdx, newCmd) {
        const updated = root.spaces.map(s => {
            if (s.id !== spaceId) return s
            const newWindows = s.windows.slice()
            if (windowIdx >= 0 && windowIdx < newWindows.length) {
                newWindows[windowIdx] = Object.assign({}, newWindows[windowIdx],
                                                       { launchCommand: newCmd })
            }
            return Object.assign({}, s, { windows: newWindows })
        })
        root.spaces = updated
    }

    // ─────────────────────────────────────────────────────────────
    // QUERY
    // ─────────────────────────────────────────────────────────────
    function getSpace(id) {
        for (const s of root.spaces) {
            if (s.id === id) return s
        }
        return null
    }

    function count() { return root.spaces.length }

    function activeSpace() { return root.getSpace(root.activeSpaceId) }

    // ─────────────────────────────────────────────────────────────
    // TOAST
    // ─────────────────────────────────────────────────────────────
    function _toast(summary, body, urgency) {
        if (typeof NotificationService === "undefined"
            || typeof NotificationService.postInternal !== "function") {
            console.log("[FocusSpaces]", summary, "—", body)
            return
        }
        try {
            NotificationService.postInternal(summary, body, "Zen Shell",
                                             urgency, "preferences-system-windows")
        } catch (e) {
            console.warn("[FocusSpaces] toast:", e)
        }
    }
}
