pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * MimeAppsService v7.0.0-beta.1-hf82n — Karui (軽い)
 *
 * Singleton wrapping ~/.config/mimeapps.list. Reads + writes the
 * [Default Applications] section using `xdg-mime` (the canonical
 * tool — handles both KDE and GNOME formats, also updates the
 * desktop-file-utils cache).
 *
 * Why xdg-mime over direct file editing:
 *   - It writes BOTH the `[Default Applications]` section AND keeps
 *     the `[Added Associations]` cross-referenced cleanly
 *   - Triggers any per-desktop notifications (some DEs cache)
 *   - Handles the case where the user has separate KDE/GNOME files
 *
 * Categories exposed match the most-asked-about defaults:
 *   browser, pdf, video, image, music, email, terminal, text-editor,
 *   archive (file roller / ark), file-manager
 *
 * Each category maps to ONE PRIMARY mime-type that all sensible apps
 * register for. Setting that primary mime usually cascades the rest
 * (xdg-mime defaults handle the "if browser X handles text/html,
 * also handles application/xhtml+xml" expansion).
 *
 * Wala tayong babawasan — additive singleton; no existing file edited.
 */
Singleton {
    id: root

    // ── Category → primary MIME type ──
    //
    // The "anchor" MIME for each category. xdg-mime usually auto-
    // associates secondary MIMEs (e.g. setting a browser as the
    // text/html handler typically also sets application/xhtml+xml).
    // For categories where one anchor isn't enough (video, image),
    // we list secondaries in `_secondaryMimes` and set them too.
    readonly property var categoryAnchors: ({
        "browser":      "x-scheme-handler/https",
        "pdf":          "application/pdf",
        "video":        "video/mp4",
        "image":        "image/jpeg",
        "music":        "audio/mpeg",
        "email":        "x-scheme-handler/mailto",
        "terminal":     "x-scheme-handler/terminal",
        "text-editor":  "text/plain",
        "archive":      "application/zip",
        "file-manager": "inode/directory"
    })

    // Secondary MIMEs to set for each category so "set my default
    // video player" actually catches mkv/webm/avi too. Empty array
    // for categories whose anchor cascades naturally via xdg-mime.
    readonly property var categorySecondaries: ({
        "browser":      ["x-scheme-handler/http", "text/html", "application/xhtml+xml"],
        "pdf":          [],
        "video":        ["video/x-matroska", "video/webm", "video/x-msvideo",
                         "video/quicktime", "video/x-flv", "video/mpeg"],
        "image":        ["image/png", "image/gif", "image/webp", "image/bmp",
                         "image/tiff", "image/svg+xml"],
        "music":        ["audio/flac", "audio/ogg", "audio/wav", "audio/aac",
                         "audio/x-m4a", "audio/opus"],
        "email":        [],
        "terminal":     [],
        "text-editor":  ["text/x-csrc", "text/x-c++src", "text/x-shellscript",
                         "text/markdown", "application/json", "text/x-python"],
        "archive":      ["application/x-7z-compressed", "application/x-tar",
                         "application/x-rar", "application/gzip"],
        "file-manager": []
    })

    readonly property var categoryLabels: ({
        "browser":      "Web Browser",
        "pdf":          "PDF Viewer",
        "video":        "Video Player",
        "image":        "Image Viewer",
        "music":        "Music Player",
        "email":        "Email Client",
        "terminal":     "Terminal",
        "text-editor":  "Text Editor",
        "archive":      "Archive Manager",
        "file-manager": "File Manager"
    })

    readonly property var categoryDescriptions: ({
        "browser":      "Default handler for http:// and https:// URLs",
        "pdf":          "Default opener for .pdf files",
        "video":        "MP4, MKV, WebM, AVI, MOV and other video formats",
        "image":        "JPEG, PNG, GIF, WebP and other image formats",
        "music":        "MP3, FLAC, OGG, WAV, AAC and other audio formats",
        "email":        "Default mailto: handler",
        "terminal":     "Default terminal emulator for 'open in terminal' actions",
        "text-editor":  "Default opener for .txt, .md, .json, source code files",
        "archive":      "ZIP, 7z, TAR, RAR and other archive formats",
        "file-manager": "Default opener for directories"
    })

    // ── Current defaults (cached, refreshed via _refreshAll()) ──
    //
    // Map of category → currently-set .desktop file name (e.g.
    // "firefox.desktop"). Empty string means "no default set" or
    // "xdg-mime returned an error".
    property var currentDefaults: ({})

    // ── Last-action result for UI feedback ──
    property string lastAction: ""
    property string lastError: ""

    Component.onCompleted: _refreshAll()

    function _refreshAll() {
        // Query xdg-mime for each category's current default. We
        // batch via a single bash invocation that prints "category|app"
        // pairs to stdout, so we don't fire 10 processes in parallel.
        const cats = Object.keys(categoryAnchors)
        let cmd = ""
        for (let i = 0; i < cats.length; i++) {
            const cat = cats[i]
            const anchor = categoryAnchors[cat]
            cmd += "echo -n '" + cat + "|'; "
            cmd += "xdg-mime query default '" + anchor + "' 2>/dev/null || echo ''; "
        }
        queryProc.command = ["bash", "-c", cmd]
        queryProc.running = false
        queryProc.running = true
    }

    Process {
        id: queryProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {}
                const lines = this.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line) continue
                    const pipe = line.indexOf("|")
                    if (pipe < 0) continue
                    const cat = line.substring(0, pipe)
                    const app = line.substring(pipe + 1).trim()
                    result[cat] = app
                }
                root.currentDefaults = result
            }
        }
    }

    // ── Setter: set the default app for a category ──
    //
    // `appDesktopId` is e.g. "firefox.desktop" or "org.mozilla.firefox.desktop".
    // Sets the anchor + all secondaries in one xdg-mime invocation
    // batch (still one Process, multiple commands chained).
    function setDefault(category, appDesktopId) {
        if (!category || !appDesktopId) return
        const anchor = categoryAnchors[category]
        if (!anchor) return
        const secondaries = categorySecondaries[category] || []
        const allMimes = [anchor].concat(secondaries)
        let cmd = ""
        for (let i = 0; i < allMimes.length; i++) {
            cmd += "xdg-mime default '" + appDesktopId + "' '" + allMimes[i] + "' && "
        }
        cmd += "true"
        setterProc.command = ["bash", "-c", cmd]
        root.lastAction = "Setting " + appDesktopId + " as " + category + "…"
        root.lastError = ""
        setterProc.running = false
        setterProc.running = true
    }

    Process {
        id: setterProc
        running: false
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim().length > 0) {
                    root.lastError = this.text.trim()
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.lastAction = "✓ Default updated"
            } else {
                root.lastAction = "✗ xdg-mime failed (exit " + exitCode + ")"
            }
            // Refresh to confirm the change took
            root._refreshAll()
        }
    }

    // ── Clear: remove the default for a category ──
    //
    // xdg-mime doesn't have a direct "clear" command; we set the
    // default to an empty desktop ID via direct file edit. Safer
    // approach: just leave the default alone, but if user really
    // wants to unset, we use sed on mimeapps.list directly.
    function clearDefault(category) {
        const anchor = categoryAnchors[category]
        if (!anchor) return
        const secondaries = categorySecondaries[category] || []
        const allMimes = [anchor].concat(secondaries)
        // Build a sed pattern that removes ALL matching lines
        let sedPattern = ""
        for (let i = 0; i < allMimes.length; i++) {
            const escaped = allMimes[i].replace(/[\/&]/g, "\\$&")
            sedPattern += "/^" + escaped + "=/d;"
        }
        const mimeFile = Quickshell.env("HOME") + "/.config/mimeapps.list"
        clearProc.command = ["bash", "-c",
            "[ -f '" + mimeFile + "' ] && sed -i -E '" + sedPattern + "' '" + mimeFile + "' || true"]
        root.lastAction = "Clearing " + category + " default…"
        clearProc.running = false
        clearProc.running = true
    }

    Process {
        id: clearProc
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.lastAction = "✓ Default cleared"
            } else {
                root.lastAction = "✗ clear failed (exit " + exitCode + ")"
            }
            root._refreshAll()
        }
    }
}
