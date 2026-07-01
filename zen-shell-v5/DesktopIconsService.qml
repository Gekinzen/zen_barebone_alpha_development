pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DesktopIconsService v7.0.0-beta.1-hf82r — Karui (軽い)
 *
 * Scans the desktop scan path (DesktopIconsState.scanPath, defaults
 * to ~/Desktop) and exposes a list of file/folder entries for the
 * DesktopSurface to render.
 *
 * Each entry is a plain object:
 * {
 *   name:    "Documents",                              // display name
 *   path:    "/home/paul/Desktop/Documents",           // absolute path
 *   isDir:   true,                                     // bool
 *   isDesktopFile: false,                              // bool (.desktop file)
 *   iconName:    "folder",                             // freedesktop icon NAME (theme lookup)
 *   mimeType:    "inode/directory",                    // MIME type for extra context
 *   execApp: null                                      // for .desktop files only
 * }
 *
 * hf82r: parses .desktop files to extract Icon= field (so Steam.desktop
 * shows the Steam logo, not a generic file glyph). For raw files,
 * uses `file --mime-type` + a small MIME→icon map. Falls back to
 * "text-x-generic" if nothing matches.
 *
 * Rescans every 30s + on shell startup. Cheap (single `find` + xargs
 * with awk over .desktop files for Icon= extraction).
 *
 * Wala tayong babawasan — additive singleton.
 */
Singleton {
    id: root

    property var entries: []
    property bool _scanning: false

    Component.onCompleted: refresh()

    function refresh() {
        if (_scanning) return
        _scanning = true
        const path = DesktopIconsState.scanPath
        console.log("[DesktopIconsService] refresh() starting, scanPath=" + path)
        // Simplified scan: dump file list + types via find -printf using
        // a NULL byte separator (\0) — safer than tabs because filenames
        // never contain NUL but can contain tabs and any printable
        // character including spaces and unicode. We use a 4-field
        // format: type<NUL>name<NUL>path<NUL>basename<NUL> with
        // double-NUL between records.
        //
        // hf82s rewrite: previous version had a complex inline `while
        // read | case | done | sort` pipeline. That worked in standalone
        // bash but failed silently in Quickshell's Process context for
        // reasons we couldn't reproduce. New version: do the listing
        // ONLY in bash (no parsing), and do the icon resolution
        // SEPARATELY in QML JS where we have proper control + can debug.
        scanProc.command = ["bash", "-c",
            "scandir='" + path + "'; " +
            "if [ ! -d \"$scandir\" ]; then exit 0; fi; " +
            "find \"$scandir\" -maxdepth 1 -mindepth 1 -printf '%y|%f\\n' 2>/dev/null"]
        scanProc.running = false
        scanProc.running = true
    }

    // Auto-refresh every 30s
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Connections {
        target: DesktopIconsState
        function onScanPathChanged() { root.refresh() }
        function onShowFolderIconsChanged() { root.refresh() }
        function onEnabledChanged() { if (DesktopIconsState.enabled) root.refresh() }
    }

    Process {
        id: scanProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || ""
                console.log("[DesktopIconsService] scan returned " + text.length + " bytes")
                const lines = text.split("\n")
                const list = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line || line.length === 0) continue
                    // Split on FIRST pipe only (filename may contain pipes)
                    const pipeIdx = line.indexOf("|")
                    if (pipeIdx < 0) continue
                    const type = line.substring(0, pipeIdx)
                    const name = line.substring(pipeIdx + 1)
                    if (!name || name.length === 0) continue
                    const isDir = (type === "d")
                    if (isDir && !DesktopIconsState.showFolderIcons) continue
                    const isDesktopFile = name.endsWith(".desktop")
                    const path = DesktopIconsState.scanPath + "/" + name

                    // Initial icon assignment (refined async for .desktop files)
                    let iconName = "text-x-generic"
                    if (isDir) {
                        iconName = "folder"
                    } else if (isDesktopFile) {
                        // Provisional — overwritten when _resolveDesktopIcon finishes
                        iconName = "application-x-executable"
                    } else {
                        // Guess from extension (cheaper than spawning `file` per entry)
                        iconName = root._iconFromExtension(name)
                    }

                    list.push({
                        "name": name,
                        "path": path,
                        "isDir": isDir,
                        "isDesktopFile": isDesktopFile,
                        "iconName": iconName,
                        "mimeType": "",
                        "execApp": null
                    })
                }
                // Sort by name (case-insensitive)
                list.sort((a, b) =>
                    (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()))
                root.entries = list
                root._scanning = false
                console.log("[DesktopIconsService] parsed " + list.length + " entries")

                // For .desktop entries, resolve real icon name from Icon= line
                // asynchronously (one Process per .desktop file — usually <10
                // on a typical user's Desktop folder so this is cheap).
                for (let i = 0; i < list.length; i++) {
                    if (list[i].isDesktopFile) {
                        root._resolveDesktopIcon(i, list[i].path)
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim().length > 0) {
                    console.warn("[DesktopIconsService] scan stderr:", this.text)
                }
            }
        }
    }

    // Map file extension → freedesktop icon-theme name. Fast, no
    // subprocess. Covers the common cases; falls back to text-x-generic.
    function _iconFromExtension(name) {
        const lower = name.toLowerCase()
        // image
        if (/\.(png|jpe?g|gif|webp|bmp|tiff?|svg|ico)$/i.test(lower)) return "image-x-generic"
        // video
        if (/\.(mp4|mkv|webm|avi|mov|flv|wmv|m4v|mpg|mpeg)$/i.test(lower)) return "video-x-generic"
        // audio
        if (/\.(mp3|flac|ogg|wav|aac|m4a|opus|wma)$/i.test(lower)) return "audio-x-generic"
        // pdf
        if (/\.pdf$/i.test(lower)) return "application-pdf"
        // archive
        if (/\.(zip|tar|gz|bz2|xz|7z|rar|tgz|tbz)$/i.test(lower)) return "package-x-generic"
        // code/text
        if (/\.(c|cpp|h|hpp|py|sh|fish|bash|zsh|js|ts|tsx|jsx|rb|go|rs|java|kt|swift|json|xml|yaml|yml|toml|ini|conf)$/i.test(lower))
            return "text-x-script"
        if (/\.(txt|md|rst|log|csv|tsv)$/i.test(lower)) return "text-x-generic"
        // executable
        if (/\.(appimage|run|exe|msi|deb|rpm|pkg)$/i.test(lower)) return "application-x-executable"
        return "text-x-generic"
    }

    // Async-resolve a .desktop file's Icon= field, then ALSO resolve
    // that icon name to an absolute file path if possible. This handles
    // Steam game icons (steam_icon_<gameid>) and other icons that live
    // in ~/.local/share/icons/ but aren't always discoverable via
    // Quickshell.iconPath theme lookup.
    //
    // Bash output format (NUL-separated to allow paths with spaces):
    //   <icon-name>\n<absolute-path-or-empty>
    //
    // Example for Crimson Desert.desktop:
    //   icon name: steam_icon_3321460
    //   absolute:  /home/paul/.local/share/icons/hicolor/256x256/apps/steam_icon_3321460.png
    //
    // The search order matches the freedesktop icon theme spec:
    //   1. $XDG_DATA_HOME/icons/hicolor/*/apps/<name>.{png,svg,xpm}
    //   2. $HOME/.icons/hicolor/*/apps/<name>.{png,svg,xpm}
    //   3. /usr/local/share/icons/hicolor/*/apps/<name>.{png,svg,xpm}
    //   4. /usr/share/icons/hicolor/*/apps/<name>.{png,svg,xpm}
    //   5. /usr/share/pixmaps/<name>.{png,svg,xpm}
    function _resolveDesktopIcon(index, path) {
        const proc = iconResolverComp.createObject(root, {
            "targetIndex": index,
            "command": ["bash", "-c",
                "set -u; " +
                "icon=$(grep -m1 '^Icon=' '" + path.replace(/'/g, "'\\''") +
                "' 2>/dev/null | cut -d= -f2- | tr -d '\\r'); " +
                "echo \"${icon:-application-x-executable}\"; " +
                // If icon already absolute, emit it directly
                "if [ \"${icon:0:1}\" = '/' ] && [ -f \"$icon\" ]; then echo \"$icon\"; exit 0; fi; " +
                // Otherwise scan known dirs for <icon>.{png,svg,xpm}
                "if [ -n \"$icon\" ] && [ \"${icon:0:1}\" != '/' ]; then " +
                  "for dir in " +
                    "\"${XDG_DATA_HOME:-$HOME/.local/share}/icons\" " +
                    "\"$HOME/.icons\" " +
                    "/usr/local/share/icons " +
                    "/usr/share/icons; do " +
                    "[ -d \"$dir\" ] || continue; " +
                    "found=$(find \"$dir\" -type f \\( " +
                      "-name \"${icon}.png\" -o " +
                      "-name \"${icon}.svg\" -o " +
                      "-name \"${icon}.xpm\" " +
                    "\\) 2>/dev/null | head -1); " +
                    "if [ -n \"$found\" ]; then echo \"$found\"; exit 0; fi; " +
                  "done; " +
                  // Pixmaps fallback
                  "for ext in png svg xpm; do " +
                    "[ -f \"/usr/share/pixmaps/${icon}.${ext}\" ] && " +
                      "{ echo \"/usr/share/pixmaps/${icon}.${ext}\"; exit 0; }; " +
                  "done; " +
                "fi; " +
                "echo ''"]
        })
        proc.running = true
    }

    Component {
        id: iconResolverComp
        Process {
            property int targetIndex: -1
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = (this.text || "").split("\n")
                    const iconName = (lines[0] || "").trim()
                    const absPath = (lines[1] || "").trim()
                    if (parent.targetIndex >= 0) {
                        root._patchEntryIcon(parent.targetIndex, iconName, absPath)
                    }
                    parent.destroy()
                }
            }
        }
    }

    function _patchEntryIcon(index, iconName, absPath) {
        if (index < 0 || index >= entries.length) return
        const next = entries.slice()
        const merged = {}
        for (const k in next[index]) merged[k] = next[index][k]
        merged.iconName = iconName
        if (absPath && absPath.length > 0) {
            merged.iconAbsPath = absPath
        }
        next[index] = merged
        entries = next
    }

    // ── Launch helpers ──

    function open(entry) {
        if (!entry) return
        if (entry.isDesktopFile) {
            // Use gtk-launch which handles the .desktop file's Exec
            // line + StartupNotify properly. Falls back to xdg-open
            // if gtk-launch isn't installed.
            const desktopBaseName = entry.name.replace(/\.desktop$/, "")
            launcher.command = ["bash", "-c",
                "gtk-launch '" + desktopBaseName + "' 2>/dev/null || " +
                "xdg-open '" + entry.path + "'"]
        } else {
            // Folders + regular files: xdg-open delegates to the
            // user's default file manager / handler.
            launcher.command = ["xdg-open", entry.path]
        }
        launcher.running = false
        launcher.running = true
    }

    Process { id: launcher; running: false }
}
