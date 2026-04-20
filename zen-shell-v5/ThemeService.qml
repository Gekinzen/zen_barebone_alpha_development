pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ThemeService v6 — Full theme management
 * Directory: ~/.config/hypr-control-center/themes/{builtin,custom}/
 * Active theme: ~/.config/hypr-control-center/current-theme.json
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: home + "/.config/hypr-control-center"
    readonly property string themesDir: configDir + "/themes"
    readonly property string builtinDir: themesDir + "/builtin"
    readonly property string customDir: themesDir + "/custom"
    readonly property string currentThemePath: configDir + "/current-theme.json"

    property string themeId: "tokyo-night"
    property string themeName: "Tokyo Night"
    property string themeDescription: ""
    property bool currentIsBuiltin: true

    property color bg0: "#1a1b26"
    property color bg1: "#24283b"
    property color bg2: "#292e42"
    property color bg3: "#414868"
    property color bg4: "#545c7e"
    property color fg:    "#c0caf5"
    property color grey0: "#9aa5ce"
    property color grey1: "#737aa2"
    property color grey2: "#565f89"
    property color red:    "#f7768e"
    property color orange: "#ff9e64"
    property color yellow: "#e0af68"
    property color green:  "#9ece6a"
    property color aqua:   "#7dcfff"
    property color blue:   "#7aa2f7"
    property color purple: "#bb9af7"

    property color fgDim: grey2
    property color cyan: aqua
    property color pink: purple

    property var availableThemes: []
    property string statusMsg: ""
    property bool loading: false

    signal themeChanged()
    signal themeListRefreshed()

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // v6.6: Save current color state as a custom theme profile.
    //
    // Called by General/Decoration pages when user edits a color manually —
    // the edit gets persisted to ~/.config/hypr-control-center/themes/custom/
    // <name>.json so it survives restarts and shows up in Themes page.
    //
    // name: "custom-<timestamp>" if not provided
    function colorToHex(c: color): string {
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    function saveAsCustomTheme(customName: string) {
        const ts = new Date().toISOString().replace(/[-:T]/g, "").split(".")[0]
        const id = customName && customName.length > 0
                   ? customName.replace(/[^a-zA-Z0-9_-]/g, "-").toLowerCase()
                   : ("custom-" + ts)
        const displayName = customName && customName.length > 0
                            ? customName
                            : ("Custom " + ts.substring(0, 8))

        const data = {
            id: id,
            name: displayName,
            description: "Custom profile saved from Zen Shell on " + new Date().toLocaleString(),
            is_builtin: false,
            colors: {
                bg0: colorToHex(bg0),
                bg1: colorToHex(bg1),
                bg2: colorToHex(bg2),
                bg3: colorToHex(bg3),
                bg4: colorToHex(bg4),
                fg:    colorToHex(fg),
                grey0: colorToHex(grey0),
                grey1: colorToHex(grey1),
                grey2: colorToHex(grey2),
                red:    colorToHex(red),
                orange: colorToHex(orange),
                yellow: colorToHex(yellow),
                green:  colorToHex(green),
                aqua:   colorToHex(aqua),
                blue:   colorToHex(blue),
                purple: colorToHex(purple)
            }
        }

        const json = JSON.stringify(data, null, 2)
        const targetPath = customDir + "/" + id + ".json"

        customThemeSaver.command = ["bash", "-c",
            "mkdir -p '" + customDir + "' && " +
            "cat > '" + targetPath + "' << 'ZCTEOF'\n" + json + "\nZCTEOF" +
            "&& cp '" + targetPath + "' '" + currentThemePath + "' && " +
            "echo OK:" + targetPath]
        customThemeSaver.running = true
        statusMsg = "Saving custom profile..."
    }

    Process {
        id: customThemeSaver
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out.startsWith("OK:")) {
                    root.statusMsg = "Custom profile saved"
                    root.refreshThemeList()
                    // Cascade the side-effects — terminal + swaync regen
                    // etc. get triggered because `current-theme.json` was
                    // overwritten with the new custom theme.
                    root.reload()
                    root.themeChanged()
                    terminalThemer.running = true
                    swayncThemer.running = true
                } else {
                    root.statusMsg = "Failed to save custom profile"
                }
            }
        }
    }

    // Quick override helpers — called by individual color-picker rows on
    // the General / Decoration pages. Updates the in-memory color (so the
    // live bar/settings repaint immediately) but DOES NOT yet persist.
    // Call saveAsCustomTheme() after the user confirms the edit.
    function setAccent(name: string, hex: string) {
        // accepts "bg0", "fg", "blue", etc.
        if (!hex) return
        if (name === "bg0")        bg0 = hex
        else if (name === "bg1")   bg1 = hex
        else if (name === "bg2")   bg2 = hex
        else if (name === "bg3")   bg3 = hex
        else if (name === "bg4")   bg4 = hex
        else if (name === "fg")    fg = hex
        else if (name === "grey0") grey0 = hex
        else if (name === "grey1") grey1 = hex
        else if (name === "grey2") grey2 = hex
        else if (name === "red")    red = hex
        else if (name === "orange") orange = hex
        else if (name === "yellow") yellow = hex
        else if (name === "green")  green = hex
        else if (name === "aqua")   aqua = hex
        else if (name === "blue")   blue = hex
        else if (name === "purple") purple = hex
        else return
        themeChanged()
    }

    Process {
        id: dirInit
        command: ["bash", "-c", "mkdir -p '" + root.builtinDir + "' '" + root.customDir + "'"]
        running: false
    }

    function refreshThemeList() {
        loading = true
        themeScanner.command = ["bash", "-c",
            "echo '===BUILTIN==='; " +
            "find '" + root.builtinDir + "' -maxdepth 1 -name '*.json' 2>/dev/null | sort; " +
            "echo '===CUSTOM==='; " +
            "find '" + root.customDir + "' -maxdepth 1 -name '*.json' 2>/dev/null | sort"]
        themeScanner.running = true
    }

    Process {
        id: themeScanner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const lines = this.text.split("\n")
                const list = []
                let mode = ""
                for (const line of lines) {
                    if (line === "===BUILTIN===") { mode = "builtin"; continue }
                    if (line === "===CUSTOM===") { mode = "custom"; continue }
                    if (!line.trim() || !line.endsWith(".json")) continue

                    const filename = line.substring(line.lastIndexOf("/") + 1)
                    const id = filename.replace(".json", "")
                    list.push({
                        id: id, path: line,
                        is_builtin: mode === "builtin",
                        name: id, description: ""
                    })
                }
                root.availableThemes = list
                console.log("[ThemeService] Found", list.length, "themes")

                if (list.length > 0) {
                    metaLoader.command = ["bash", "-c",
                        list.map(t => "echo '---" + t.path + "---'; cat '" + t.path + "' 2>/dev/null || echo '{}'").join("; ")]
                    metaLoader.running = true
                } else {
                    root.themeListRefreshed()
                }
            }
        }
    }

    Process {
        id: metaLoader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const updated = root.availableThemes.slice()
                for (const t of updated) {
                    const marker = "---" + t.path + "---"
                    const idx = text.indexOf(marker)
                    if (idx < 0) continue
                    const nextIdx = text.indexOf("---", idx + marker.length)
                    const jsonBlob = (nextIdx > 0
                                      ? text.substring(idx + marker.length, nextIdx)
                                      : text.substring(idx + marker.length)).trim()
                    try {
                        const data = JSON.parse(jsonBlob)
                        if (data.name) t.name = data.name
                        if (data.description) t.description = data.description
                    } catch(e) {}
                }
                root.availableThemes = updated
                root.themeListRefreshed()
            }
        }
    }

    FileView {
        id: currentThemeFile
        path: root.currentThemePath
        blockLoading: false
        watchChanges: true
        onLoaded: root.applyJson(this.text())
        onFileChanged: this.reload()
    }

    function applyJson(text) {
        if (!text) return
        try {
            const data = JSON.parse(text)
            if (data.id) themeId = data.id
            if (data.name) themeName = data.name
            if (data.description !== undefined) themeDescription = data.description
            if (typeof data.is_builtin === "boolean") currentIsBuiltin = data.is_builtin

            const c = data.colors || {}
            if (c.bg0) bg0 = c.bg0
            if (c.bg1) bg1 = c.bg1
            if (c.bg2) bg2 = c.bg2
            if (c.bg3) bg3 = c.bg3
            if (c.bg4) bg4 = c.bg4
            if (c.fg)    fg    = c.fg
            if (c.grey0) grey0 = c.grey0
            if (c.grey1) grey1 = c.grey1
            if (c.grey2) grey2 = c.grey2
            if (c.red)    red    = c.red
            if (c.orange) orange = c.orange
            if (c.yellow) yellow = c.yellow
            if (c.green)  green  = c.green
            if (c.aqua)   aqua   = c.aqua
            if (c.blue)   blue   = c.blue
            if (c.purple) purple = c.purple

            themeChanged()
            console.log("[ThemeService] Current:", themeName)
        } catch (e) {
            console.error("[ThemeService] Parse error:", e)
        }
    }

    // ── v6.3/v6.4: Auto-reload shell after theme apply ──
    // Theme colors live in a separate Theme.qml singleton on the user's system
    // that we don't control from zen-shell-v5. When ThemeService.applyTheme()
    // writes to current-theme.json, Theme.qml's FileView may not propagate
    // every color binding to already-rendered modules without a soft reload.
    //
    // v6.4 strategy:
    //   1. Reload our own FileView (ThemeService is now live internally).
    //   2. Touch the theme file so any external FileWatcher on it refires.
    //   3. Broadcast a themeChanged signal that modules can connect to.
    //   4. Call `qs ipc call zen reloadThemeFromFile` so the shell re-runs
    //      ThemeService.reload() and any extra Theme propagation hooks.
    //
    // Default: true (safe). Disable via ThemesPage toggle if you have a
    // custom Theme.qml with its own live bindings.
    property bool autoReloadOnApply: true

    function applyTheme(theme) {
        if (!theme || !theme.path) return
        statusMsg = "Applying " + theme.name + "..."
        applier.command = ["bash", "-c",
            "cp '" + theme.path + "' '" + root.currentThemePath + "' && " +
            // Touch parent dir mtime too, so file watchers that watch the
            // dir (not just the file) also fire.
            "touch '" + root.currentThemePath + "' && " +
            "echo OK"]
        applier.running = true
    }

    Process {
        id: applier
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "OK") {
                    root.statusMsg = "Theme applied"
                    root.reload()
                    // Re-emit themeChanged explicitly so any bound module
                    // that missed the FileView onLoaded still gets a shot.
                    root.themeChanged()
                    notifyApps.running = true
                    // v6.5: regenerate terminal configs (alacritty btm/nmtui/
                    // termi tomls + fuzzel.ini) so launched terminals pick up
                    // the new theme colors on next launch.
                    terminalThemer.running = true
                    // v6.6: regenerate SwayNC style.css + reload daemon
                    // (notifications now match theme colors).
                    swayncThemer.running = true
                    if (root.autoReloadOnApply) {
                        shellReloadTimer.start()
                    }
                }
            }
        }
    }

    // v6.5: Regenerates ~/.config/alacritty/*.toml + fuzzel.ini from the
    // current-theme.json. Installed by install.sh to ~/.local/bin/.
    Process {
        id: terminalThemer
        command: ["bash", "-c",
            "if [ -x \"$HOME/.local/bin/regen-terminal-themes.sh\" ]; then " +
            "  \"$HOME/.local/bin/regen-terminal-themes.sh\" > /tmp/zen-theme-regen.log 2>&1; " +
            "else " +
            "  echo 'regen-terminal-themes.sh not installed, skipping'; " +
            "fi"]
        running: false
    }

    // v6.6: Regenerates SwayNC style.css from current-theme.json + reloads
    // notification daemon. So notifications (volume change, etc.) match the
    // selected theme. Installed by install.sh to ~/.local/bin/.
    Process {
        id: swayncThemer
        command: ["bash", "-c",
            "if [ -x \"$HOME/.local/bin/regen-swaync-theme.sh\" ]; then " +
            "  \"$HOME/.local/bin/regen-swaync-theme.sh\" > /tmp/zen-swaync-regen.log 2>&1; " +
            "else " +
            "  echo 'regen-swaync-theme.sh not installed, skipping'; " +
            "fi"]
        running: false
    }

    // Deferred shell reload — gives the FS + FileView time to settle
    Timer {
        id: shellReloadTimer
        interval: 250
        repeat: false
        onTriggered: shellReloader.running = true
    }

    Process {
        id: shellReloader
        command: ["qs", "-c", "zen-shell", "ipc", "call", "zen", "reloadThemeFromFile"]
        running: false
    }

    Process {
        id: notifyApps
        command: ["bash", "-c",
            "pkill -SIGUSR2 waybar 2>/dev/null; " +
            "pkill -SIGUSR1 kitty 2>/dev/null; true"]
        running: false
    }

    function importTheme(externalPath) {
        if (!externalPath) return
        statusMsg = "Importing..."
        importer.command = ["bash", "-c",
            "if [ ! -f '" + externalPath + "' ]; then echo 'ERR: file not found'; exit 1; fi; " +
            "mkdir -p '" + root.customDir + "' && " +
            "filename=$(basename '" + externalPath + "'); " +
            "target='" + root.customDir + "/'\"$filename\"; " +
            "cp '" + externalPath + "' \"$target\" && echo \"OK:$target\""]
        importer.running = true
    }

    Process {
        id: importer
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out.startsWith("OK:")) {
                    root.statusMsg = "Imported"
                    root.refreshThemeList()
                } else {
                    root.statusMsg = "Import failed: " + out
                }
            }
        }
    }

    function exportCurrentTheme(externalPath) {
        if (!externalPath) return
        exporter.command = ["bash", "-c",
            "cp '" + root.currentThemePath + "' '" + externalPath + "' && echo OK"]
        exporter.running = true
    }

    Process {
        id: exporter
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.statusMsg = this.text.trim() === "OK" ? "Exported" : "Export failed"
            }
        }
    }

    function deleteCustomTheme(theme) {
        if (!theme || theme.is_builtin) {
            statusMsg = "Cannot delete builtin"
            return
        }
        deleter.command = ["bash", "-c", "rm -f '" + theme.path + "' && echo OK"]
        deleter.running = true
    }

    Process {
        id: deleter
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "OK") {
                    root.statusMsg = "Deleted"
                    root.refreshThemeList()
                }
            }
        }
    }

    function reload() { currentThemeFile.reload() }

    Component.onCompleted: {
        dirInit.running = true
        Qt.callLater(function() {
            refreshThemeList()
            currentThemeFile.reload()
        })
    }
}
