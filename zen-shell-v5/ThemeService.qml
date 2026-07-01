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

    // ─────────────────────────────────────────────────────────────
    // v6.16.4.12.6: Matugen wallpaper-driven theming
    // ─────────────────────────────────────────────────────────────
    //
    // When `matugenEnabled` is true, every WallpaperServiceV5.wallpaperApplied
    // signal triggers `applyMatugenFromWallpaper(path)`. That runs:
    //   matugen image <path> --json hex
    // which returns a Material You palette as JSON. We map M3 tokens to our
    // bg0..bg4 / fg / accent palette, write the result to
    //   ~/.config/hypr-control-center/themes/custom/matugen-auto.json
    // and apply it via the normal applyTheme() path so terminal/swaync
    // regen scripts also fire.
    //
    // When the toggle is off, the user's previously-selected theme is
    // preserved untouched (we don't restore on toggle-off because the
    // current-theme.json on disk already holds whatever was active before
    // matugen overwrote it; user just picks again from the dropdown).
    //
    // matugen is detected at init via `command -v matugen`. If absent,
    // matugenAvailable stays false and the ThemesPage hides the toggle.
    // Recommended install: `paru -S matugen-bin`.
    //
    // State persisted at: ~/.config/hypr-control-center/matugen.state
    // Single line, "1" = on, "0" = off.
    property bool matugenEnabled: false
    property bool matugenAvailable: false
    property string matugenStatus: ""
    readonly property string matugenStatePath: configDir + "/matugen.state"

    // v6.16.4.12.6.7: counter + last-event tracking so Themes page can
    // surface auto-hook activity. Bumps every time shell.qml's wallpaper
    // Connections fires, regardless of whether the matugen toggle is on.
    // Lets the user verify the hook is wired without grepping journalctl.
    property int wallpaperHookCount: 0
    property string wallpaperHookLastPath: ""
    property string wallpaperHookLastAt: ""

    function recordWallpaperHook(path) {
        wallpaperHookCount += 1
        wallpaperHookLastPath = path || ""
        wallpaperHookLastAt = Qt.formatDateTime(new Date(), "hh:mm:ss")
    }

    signal matugenAppliedFor(string wallpaperPath)

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

        // v7.0.0-beta.1-hf44: snapshot the FULL theme state, not just
        // colors. Previously the saved profile contained only the
        // `colors` object so reloading the profile restored colors
        // BUT lost everything else (bar opacity, bar radius, style
        // mode, bar module layout, Densho settings, fonts, etc.).
        // That broke the "save my exact setup as a named profile"
        // expectation — user would tweak panel radius + brush
        // separators, save profile, switch theme, switch back → lose
        // all those tweaks.
        //
        // The schema is backward-compatible: old profiles without
        // these fields still load correctly (applyJson uses
        // `if (data.X !== undefined)` checks). New profiles get the
        // full snapshot.
        const data = {
            id: id,
            name: displayName,
            description: "Custom profile saved from Zen Shell on " + new Date().toLocaleString(),
            is_builtin: false,
            // v7.0.0-beta.1-hf44: format version stamp. Lets future
            // hotfixes evolve the schema without breaking older saves.
            schemaVersion: 2,
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
            },
            // v7.0.0-beta.1-hf44: Theme.qml visual + layout properties.
            // These are the bar/panel surface knobs the user can tweak
            // via Settings → Panel, Settings → General, etc.
            theme: (function() {
                try {
                    if (typeof Theme === "undefined") return {}
                    return {
                        styleMode:   Theme.styleMode,
                        barOpacity:  Theme.barOpacity,
                        barRadius:   Theme.barRadius,
                        fontFamily:  Theme.fontFamily,
                        monoFont:    Theme.monoFont,
                        fontSize:    Theme.fontSizeBase,
                        iconSize:    Theme.iconSizeBase,
                        barLayout:   Theme.barLayout
                    }
                } catch (e) {
                    console.warn("[ThemeService] Could not snapshot Theme props:", e)
                    return {}
                }
            })(),
            // v7.0.0-beta.1-hf44: Densho (traditional Japanese style)
            // sub-toggles. Brush-stroke separators shown in the
            // screenshot are one of these. Without this block, toggling
            // brush separators off and saving the profile then
            // restoring it would silently turn them back on.
            densho: (function() {
                try {
                    if (typeof DenshoService === "undefined") return {}
                    return {
                        denshoMode:      DenshoService.denshoMode,
                        kanjiWorkspaces: DenshoService.kanjiWorkspaces,
                        verticalDate:    DenshoService.verticalDate,
                        seasonalKanji:   DenshoService.seasonalKanji,
                        brushSeparators: DenshoService.brushSeparators
                    }
                } catch (e) {
                    console.warn("[ThemeService] Could not snapshot Densho:", e)
                    return {}
                }
            })()
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
                    syncSddmIfEnabled()
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

    // ═══════════════════════════════════════════════════════════════
    // v6.16.4.12.9.4 (Modori) — Smart contrast auto-correction
    //
    // Themes ship with colors that may or may not have been tested
    // for WCAG-style readability. Light themes especially are prone
    // to subtle traps: a designer picks a light grey for `grey0` that
    // looks fine against the dark `bg0` they were designing on, but
    // when applied against a LIGHT bg0 the contrast collapses and
    // text becomes unreadable.
    //
    // This helper layer computes the BACKGROUND luminance (via WCAG
    // relative-luminance formula), detects whether the theme is
    // effectively light or dark, then auto-adjusts foreground tones
    // (fg + grey0/1/2) to ensure a minimum 4.5:1 contrast ratio
    // against bg0. If a theme already has good contrast, it passes
    // through unchanged.
    //
    // We deliberately DON'T auto-correct accent colors (red, orange,
    // yellow, green, aqua, blue, purple). Those are used as fills,
    // borders, and badges — not primary readable text — and the
    // accent's HUE is part of the theme's identity. Foreground tones
    // on the other hand are pure greyscale-functional and always
    // safe to nudge.
    //
    // The correction is conservative: we lerp toward black/white
    // only enough to reach 4.5:1, not all the way. Light themes
    // keep their warmth, dark themes keep their depth.
    // ═══════════════════════════════════════════════════════════════

    function _hexToRgb(h) {
        const s = String(h).replace("#", "")
        if (s.length !== 6) return [0, 0, 0]
        return [
            parseInt(s.substr(0, 2), 16),
            parseInt(s.substr(2, 2), 16),
            parseInt(s.substr(4, 2), 16),
        ]
    }

    function _rgbToHex(rgb) {
        const c = (n) => {
            const clamped = Math.max(0, Math.min(255, Math.round(n)))
            const h = clamped.toString(16)
            return h.length === 1 ? "0" + h : h
        }
        return "#" + c(rgb[0]) + c(rgb[1]) + c(rgb[2])
    }

    // WCAG relative luminance — input is sRGB 0-255, output is 0..1
    function _luminance(rgb) {
        const linearize = (c) => {
            const cs = c / 255
            return cs <= 0.03928 ? cs / 12.92 : Math.pow((cs + 0.055) / 1.055, 2.4)
        }
        const r = linearize(rgb[0])
        const g = linearize(rgb[1])
        const b = linearize(rgb[2])
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    function _contrastRatio(rgb1, rgb2) {
        const l1 = _luminance(rgb1)
        const l2 = _luminance(rgb2)
        const bright = Math.max(l1, l2)
        const dark   = Math.min(l1, l2)
        return (bright + 0.05) / (dark + 0.05)
    }

    // Lerp two RGB colors. t=0 returns a, t=1 returns b.
    function _lerpRgb(a, b, t) {
        return [
            a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t,
        ]
    }

    // Push `fg` toward black (light bg) or white (dark bg) just
    // enough to clear `targetRatio` against `bg`. Returns hex string.
    // Conservative: stops AT the threshold rather than overshooting.
    function _ensureContrast(fgHex, bgHex, targetRatio) {
        const fgRgb = _hexToRgb(fgHex)
        const bgRgb = _hexToRgb(bgHex)
        const current = _contrastRatio(fgRgb, bgRgb)
        if (current >= targetRatio) return fgHex   // already readable

        // Decide push direction based on bg luminance
        const bgLum = _luminance(bgRgb)
        const target = bgLum > 0.5 ? [0, 0, 0] : [255, 255, 255]

        // Binary search for the smallest lerp that reaches targetRatio
        let lo = 0.0
        let hi = 1.0
        for (let i = 0; i < 14; i++) {
            const mid = (lo + hi) / 2
            const candidate = _lerpRgb(fgRgb, target, mid)
            const ratio = _contrastRatio(candidate, bgRgb)
            if (ratio >= targetRatio) {
                hi = mid
            } else {
                lo = mid
            }
        }
        return _rgbToHex(_lerpRgb(fgRgb, target, hi))
    }

    // Apply smart-contrast pass to a parsed colors object IN PLACE.
    // Returns the same object so callers can chain. Modifies fg +
    // grey0/1/2 only; bg* and accents pass through.
    function _autoContrast(c) {
        if (!c.bg0) return c   // nothing to anchor against
        const bg = c.bg0

        // Foreground: 4.5:1 (WCAG AA for body text)
        if (c.fg) c.fg = _ensureContrast(c.fg, bg, 4.5)

        // grey0 = primary secondary text (subtitles, descriptions).
        // Keep at 4.5:1 — these are still meant to be read.
        if (c.grey0) c.grey0 = _ensureContrast(c.grey0, bg, 4.5)

        // grey1 = tertiary text (placeholders, helper text). 3:1 is
        // WCAG AA for "large text" — acceptable for short labels but
        // we'd rather err high. Use 3.5:1.
        if (c.grey1) c.grey1 = _ensureContrast(c.grey1, bg, 3.5)

        // grey2 = decorative dim (borders, dividers, disabled states).
        // Don't push too hard or borders disappear into bg. 2.5:1.
        if (c.grey2) c.grey2 = _ensureContrast(c.grey2, bg, 2.5)

        return c
    }

    function applyJson(text) {
        if (!text) return
        try {
            const data = JSON.parse(text)
            if (data.id) themeId = data.id
            if (data.name) themeName = data.name
            if (data.description !== undefined) themeDescription = data.description
            if (typeof data.is_builtin === "boolean") currentIsBuiltin = data.is_builtin

            // Run the smart-contrast pass before applying. Themes that
            // already have good contrast pass through unchanged; themes
            // with traps (light-on-light, dark-on-dark) get nudged toward
            // readability without losing the designer's intent.
            const c = _autoContrast(data.colors || {})

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

            // v7.0.0-beta.1-hf44: restore non-color theme state when
            // the saved profile includes it. Old profiles (schemaVersion
            // missing or 1) don't have these blocks and that's fine —
            // we just skip the restore for those, preserving the user's
            // currently-applied non-color settings. New profiles
            // (schemaVersion >= 2) restore the full snapshot.
            //
            // The `data.theme` block contains Theme.qml visual + layout
            // properties (bar opacity, radius, style mode, fonts, bar
            // module layout). The `data.densho` block contains
            // DenshoService toggles (densho mode + sub-features).
            //
            // We use `if (X !== undefined)` checks so falsy values like
            // `false` and `0` are still applied correctly — naive
            // truthy checks would skip them.
            if (data.theme && typeof Theme !== "undefined") {
                try {
                    if (typeof data.theme.styleMode === "string")
                        Theme.styleMode = data.theme.styleMode
                    if (typeof data.theme.barOpacity === "number")
                        Theme.barOpacity = data.theme.barOpacity
                    if (typeof data.theme.barRadius === "number")
                        Theme.barRadius = data.theme.barRadius
                    if (typeof data.theme.fontFamily === "string"
                        && data.theme.fontFamily.length > 0)
                        Theme.fontFamily = data.theme.fontFamily
                    if (typeof data.theme.monoFont === "string"
                        && data.theme.monoFont.length > 0)
                        Theme.monoFont = data.theme.monoFont
                    if (typeof data.theme.fontSize === "number"
                        && data.theme.fontSize > 0)
                        Theme.fontSizeBase = data.theme.fontSize
                    if (typeof data.theme.iconSize === "number"
                        && data.theme.iconSize > 0)
                        Theme.iconSizeBase = data.theme.iconSize
                    if (data.theme.barLayout
                        && typeof data.theme.barLayout === "object") {
                        Theme.barLayout = data.theme.barLayout
                    }
                    console.log("[ThemeService] hf44: restored Theme props from profile")
                } catch (e) {
                    console.warn("[ThemeService] Theme restore error:", e)
                }
            }

            if (data.densho && typeof DenshoService !== "undefined") {
                try {
                    if (typeof data.densho.denshoMode === "boolean")
                        DenshoService.denshoMode = data.densho.denshoMode
                    if (typeof data.densho.kanjiWorkspaces === "boolean")
                        DenshoService.kanjiWorkspaces = data.densho.kanjiWorkspaces
                    if (typeof data.densho.verticalDate === "boolean")
                        DenshoService.verticalDate = data.densho.verticalDate
                    if (typeof data.densho.seasonalKanji === "boolean")
                        DenshoService.seasonalKanji = data.densho.seasonalKanji
                    if (typeof data.densho.brushSeparators === "boolean")
                        DenshoService.brushSeparators = data.densho.brushSeparators
                    console.log("[ThemeService] hf44: restored Densho prefs from profile")
                } catch (e) {
                    console.warn("[ThemeService] Densho restore error:", e)
                }
            }

            // Persist non-color restored state. PanelState.saveState()
            // writes Theme props (barOpacity/Radius/Layout/styleMode) to
            // panel-state.json so the next shell launch sees them as
            // defaults. DenshoService has its own auto-save via
            // property bindings, so no explicit call needed.
            if ((data.theme || data.densho)
                && typeof PanelState !== "undefined"
                && typeof PanelState.saveState === "function") {
                try { Qt.callLater(PanelState.saveState) }
                catch (e) {}
            }

            themeChanged()
            console.log("[ThemeService] Current:", themeName,
                        data.schemaVersion ? "(schema v" + data.schemaVersion + ")" : "(legacy)")
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
                    syncSddmIfEnabled()
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

    // v7.0.0-beta.1-hf95.11: Re-sync the Zen Tokyo SDDM greeter to the
    // newly-applied theme, so the login screen follows the user's colour
    // choice (not just at logout/login). Fire-and-forget via pkexec; the
    // polkit rule installed by zen-sddm-install.sh allows it without a
    // prompt. Completely no-op if the SDDM theme/sync isn't installed
    // (the `-x` guard), so users who never set up the greeter are
    // unaffected. Wala tayong babawasan.
    Process {
        id: sddmThemer
        command: ["bash", "-c",
            "if [ -x /usr/local/bin/zen-sddm-sync.sh ]; then " +
            "  pkexec /usr/local/bin/zen-sddm-sync.sh \"--user=$USER\" " +
            "    > /tmp/zen-sddm-sync.log 2>&1 || true; " +
            "else " +
            "  echo 'zen-sddm-sync.sh not installed, skipping'; " +
            "fi"]
        running: false
    }
    // hf95.12: only push to the greeter when the user enabled it in
    // Settings → Login Screen. Wrapper so the three apply sites stay one
    // line and the gate lives in one place.
    function syncSddmIfEnabled() {
        if (typeof SettingsState !== "undefined" && SettingsState.sddmLoginEnabled)
            sddmThemer.running = true
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

    // ═════════════════════════════════════════════════════════════
    // v6.16.4.12.6: Matugen plumbing
    // ═════════════════════════════════════════════════════════════

    function setMatugenEnabled(on) {
        matugenEnabled = on
        // Persist
        matugenStateSaver.command = ["bash", "-c",
            "mkdir -p '" + configDir + "' && " +
            "echo " + (on ? "1" : "0") + " > '" + matugenStatePath + "'"]
        matugenStateSaver.running = true
        matugenStatus = on ? "Matugen ON — wallpaper drives theme"
                           : "Matugen OFF — manual themes"
    }

    Process { id: matugenStateSaver; running: false }

    // Probe `matugen` once at startup. Fills matugenAvailable.
    Process {
        id: matugenProbe
        command: ["bash", "-c", "command -v matugen >/dev/null 2>&1 && echo OK || echo MISSING"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.matugenAvailable = this.text.trim() === "OK"
                if (!root.matugenAvailable && root.matugenEnabled) {
                    root.matugenStatus = "matugen binary missing — install via paru -S matugen-bin"
                }
            }
        }
    }

    // Load persisted matugen toggle state at init
    FileView {
        id: matugenStateFile
        path: matugenStatePath
        blockLoading: false
        onLoaded: {
            const v = (this.text() || "").trim()
            root.matugenEnabled = (v === "1")
        }
    }

    // Run matugen against a wallpaper path, parse the JSON, write a custom
    // theme JSON, and apply it. Map of Material You → our palette is below.
    //
    // v6.16.4.12.6.1 fix: stderr to /tmp/zen-matugen.log, multi-variant
    //                     fallback so different matugen versions just work.
    // v6.16.4.12.6.2 fix: per-variant log markers so diagnostic UI can
    //                     surface the actual first-failure stderr.
    // v6.16.4.12.6.3 fix: SELF-CONTAINED CONFIG. matugen 2.x requires a
    //                     `[templates]` section in its config.toml; users
    //                     who installed v6.16.4.12.6 before the bootstrap
    //                     fix had a config without it → "missing field
    //                     `templates`" failure on every Re-apply. We now
    //                     ALWAYS pass --config <tempfile> with a known-good
    //                     minimal config, so the user's
    //                     ~/.config/matugen/config.toml is irrelevant for
    //                     our palette-extraction call. (The user's config
    //                     still drives matugen's other workflows when they
    //                     run it manually for other apps.)
    function applyMatugenFromWallpaper(path) {
        if (!matugenEnabled || !matugenAvailable) return
        if (!path) return
        matugenStatus = "Generating palette from wallpaper..."
        const escaped = path.replace(/'/g, "'\\''")
        matugenRunner.command = ["bash", "-c",
            "LOG=/tmp/zen-matugen.log; " +
            ": > \"$LOG\"; " +
            "echo \"=== zen-matugen run @ $(date -Iseconds) ===\" >> \"$LOG\"; " +
            "echo \"=== image: " + escaped + " ===\" >> \"$LOG\"; " +
            "echo \"=== matugen --version: $(matugen --version 2>&1 || echo 'NOT FOUND') ===\" >> \"$LOG\"; " +
            "echo \"\" >> \"$LOG\"; " +
            // Build a self-contained, known-good config so we never
            // depend on the user's ~/.config/matugen/config.toml state.
            // matugen 2.x requires [templates] (even empty) — that was
            // the v6.16.4.12.6.2 failure mode caught by Paul's logs.
            "TMPCFG=$(mktemp --suffix=-zen-matugen.toml 2>/dev/null || echo /tmp/zen-matugen-config.toml); " +
            "trap 'rm -f \"$TMPCFG\"' EXIT; " +
            "cat > \"$TMPCFG\" <<'ZMTGCFGEOF'\n" +
            "[config]\n" +
            "reload_apps = false\n" +
            "set_wallpaper = false\n" +
            "\n" +
            "[templates]\n" +
            "ZMTGCFGEOF\n" +
            "echo \"=== using tempconfig: $TMPCFG ===\" >> \"$LOG\"; " +
            // v6.16.4.12.6.4: --prefer added because matugen errors on
            //                 multi-color images without a TTY.
            // v6.16.4.12.6.5: matugen 4.x's actual valid --prefer values.
            // v6.16.4.12.6.8: --type scheme-fidelity / scheme-content
            //                 added at the front because matugen's default
            //                 scheme-tonal-spot produces SOFT muted tonal
            //                 variations (Material 3 surfaces). For Zen's
            //                 8-color accent palette we want vivid
            //                 distinguishable colors, so scheme-fidelity
            //                 (closest to source) and scheme-content
            //                 (image-content driven) give a much more
            //                 "wallpaper-driven" feel. Falls through to
            //                 the older variants if --type isn't
            //                 recognized in some matugen build.
            "for args in '--type scheme-fidelity --json hex --prefer saturation' " +
            "            '--type scheme-content --json hex --prefer saturation' " +
            "            '--type scheme-vibrant --json hex --prefer saturation' " +
            "            '--type scheme-fruit-salad --json hex --prefer saturation' " +
            "            '--json hex --prefer saturation' " +
            "            '--json hex --mode dark --prefer saturation' " +
            "            '--json hex --prefer darkness' " +
            "            '--json hex --prefer value' " +
            "            '--json hex --prefer lightness' " +
            "            '--json hex --prefer closest-to-fallback'; do " +
            "  echo \"=== VARIANT: matugen --config <tempcfg> image '<path>' $args ===\" >> \"$LOG\"; " +
            "  out=$(matugen --config \"$TMPCFG\" image '" + escaped + "' $args 2>>\"$LOG\"); " +
            "  if [ -n \"$out\" ]; then " +
            "    echo \"=== SUCCESS with: $args ===\" >> \"$LOG\"; " +
            // v6.16.4.12.6.8: ALSO dump the full JSON to a side file so
            // we can inspect available M3 tokens & tune the mapping.
            "    echo \"$out\" > /tmp/zen-matugen-output.json; " +
            "    echo \"$out\"; " +
            "    exit 0; " +
            "  fi; " +
            "  echo \"=== EMPTY stdout with: $args ===\" >> \"$LOG\"; " +
            "  echo \"\" >> \"$LOG\"; " +
            "done; " +
            "echo \"=== ALL VARIANTS FAILED ===\" >> \"$LOG\"; " +
            "exit 1"]
        matugenRunner.running = true
    }

    Process {
        id: matugenRunner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (!out) {
                    // All variants failed → surface the FIRST variant's
                    // stderr (the most relevant one — later variants are
                    // just noise from trying alternatives).
                    matugenLogReader.running = true
                    return
                }
                try {
                    const parsed = JSON.parse(out)
                    // v6.16.4.12.6.9: matugen 4.x structure is:
                    //   parsed.colors.primary.dark.color = "#hex"
                    // NOT the older 2.x:
                    //   parsed.colors.dark.primary = "#hex"
                    // The old parser silently fell through to fallbacks
                    // for EVERY field → all wallpapers produced identical
                    // Tokyo Night defaults. Now we walk both shapes.
                    const colors = root._extractColorsForDarkMode(parsed)
                    const palettes = root._extractPalettesByTone(parsed)
                    if (!colors || Object.keys(colors).length === 0) {
                        root.matugenStatus = "matugen JSON: no usable colors found"
                        console.error("[Matugen] empty colors after extract; raw head:",
                                      out.substring(0, 300))
                        return
                    }
                    root._writeMatugenTheme(colors, palettes)
                } catch (e) {
                    root.matugenStatus = "matugen JSON parse failed: " + e
                    console.error("[Matugen] parse error:", e, "raw head:", out.substring(0, 200))
                }
            }
        }
    }

    // v6.16.4.12.6.9: Robust extractor that handles the three matugen
    // output formats we've seen in the wild.
    //
    //   matugen 4.x  (current — what Paul's running):
    //     { colors: { primary: { dark: { color: "#hex" }, ... }, ... } }
    //
    //   matugen 2.x:
    //     { colors: { dark: { primary: "#hex", ... }, light: {...} } }
    //
    //   matugen 1.x / older:
    //     { colors: { primary: "#hex", ... } }
    //     OR: { dark: {...}, light: {...} }
    //     OR: { primary: "#hex", ... } (flat)
    //
    // Returns a flat { primary, secondary, surface, ... } map of hex
    // strings for the dark scheme. Anything missing simply isn't in the
    // returned object — _writeMatugenTheme falls back to defaults for
    // any token that's absent.
    function _extractColorsForDarkMode(parsed) {
        const result = {}

        // Try matugen 4.x first: parsed.colors.X.dark.color
        if (parsed.colors && typeof parsed.colors === "object") {
            const sample = Object.values(parsed.colors)[0]

            // Detect 4.x by the .dark.color shape on a sample entry
            if (sample && typeof sample === "object"
                && sample.dark && typeof sample.dark === "object"
                && sample.dark.color) {
                for (const name in parsed.colors) {
                    const c = parsed.colors[name]
                    if (!c) continue
                    if (c.dark && c.dark.color) result[name] = c.dark.color
                    else if (c.default && c.default.color) result[name] = c.default.color
                    else if (c.color) result[name] = c.color
                    else if (typeof c === "string") result[name] = c
                }
                return result
            }

            // 2.x: parsed.colors.dark = { primary: "#hex", ... }
            if (parsed.colors.dark && typeof parsed.colors.dark === "object") {
                for (const name in parsed.colors.dark) {
                    const v = parsed.colors.dark[name]
                    if (typeof v === "string") result[name] = v
                    else if (v && v.color) result[name] = v.color
                }
                return result
            }

            // 1.x flat: parsed.colors = { primary: "#hex", ... }
            if (typeof sample === "string") {
                for (const name in parsed.colors) result[name] = parsed.colors[name]
                return result
            }
        }

        // Top-level dark/flat fallbacks
        if (parsed.dark && typeof parsed.dark === "object") {
            for (const name in parsed.dark) {
                const v = parsed.dark[name]
                if (typeof v === "string") result[name] = v
                else if (v && v.color) result[name] = v.color
            }
            return result
        }

        // Last resort — assume `parsed` itself is flat hex map
        for (const name in parsed) {
            const v = parsed[name]
            if (typeof v === "string" && v.match(/^#[0-9a-fA-F]{6,8}$/)) {
                result[name] = v
            }
        }
        return result
    }

    // v6.16.4.12.6.9: Pull matugen's tonal palette ladders. Each named
    // palette (primary/secondary/tertiary/error/neutral/neutral_variant)
    // has tones 0..100 in steps of 10 (plus 5/15/25/...). For accent
    // generation we mostly want tone 70-80 (vivid mid-light values that
    // pop on dark backgrounds) and 50-60 for darker variants.
    //
    // Returns: { primary: { 80: "#hex", 70: "#hex", ... }, ... } or
    // null if no palettes section is present in the matugen output.
    function _extractPalettesByTone(parsed) {
        if (!parsed.palettes || typeof parsed.palettes !== "object") return null
        const out = {}
        for (const name in parsed.palettes) {
            const tones = parsed.palettes[name]
            if (!tones) continue
            out[name] = {}
            for (const tone in tones) {
                const v = tones[tone]
                if (v && v.color) out[name][tone] = v.color
                else if (typeof v === "string") out[name][tone] = v
            }
        }
        return out
    }

    // v6.16.4.12.6.2: When all variants fail, parse the structured log to
    // pull out just the first variant's stderr lines (the actionable error,
    // before the rest of the variants pile on noise). Also extracts the
    // matugen --version so the user can tell us which release they have.
    Process {
        id: matugenLogReader
        running: false
        command: ["bash", "-c",
            "LOG=/tmp/zen-matugen.log; " +
            "if [ ! -f \"$LOG\" ]; then echo 'NOLOG'; exit 0; fi; " +
            // Print version line + just the first variant's stderr block
            "VER=$(grep -m1 '^=== matugen --version:' \"$LOG\" | sed 's/^=== matugen --version: //; s/ ===$//'); " +
            "echo \"VERSION:$VER\"; " +
            "awk '/^=== VARIANT:/{n++; if(n>1) exit; next} " +
            "     /^=== EMPTY/{exit} " +
            "     /^=== /{next} " +
            "     /^$/{next} " +
            "     {print}' \"$LOG\" | head -10"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").split("\n")
                let version = ""
                let stderrLines = []
                for (const l of lines) {
                    if (l.startsWith("VERSION:")) version = l.substring(8).trim()
                    else if (l.trim().length > 0 && l !== "NOLOG") stderrLines.push(l)
                }
                let msg = ""
                if (version && version !== "NOT FOUND") msg += "matugen " + version + ": "
                else if (version === "NOT FOUND") msg += "matugen binary not callable: "
                if (stderrLines.length > 0) {
                    // Strip ANSI color codes that matugen sometimes emits
                    const clean = stderrLines
                        .map(l => l.replace(/\x1b\[[0-9;]*m/g, ""))
                        .filter(l => l.length > 0)
                        .join(" | ")
                        .substring(0, 360)
                    msg += clean
                } else {
                    msg += "no stderr captured. Run manually: matugen image <wallpaper> --json hex"
                }
                root.matugenStatus = msg + "  (full log: /tmp/zen-matugen.log)"
            }
        }
    }

    // M3 → Zen palette mapping. Material 3 token names per spec; we fall
    // back through alternates because matugen's flag aliases vary across
    // versions (some emit `surface_container_high`, others `surfaceContainerHigh`).
    function _pick(obj, keys, fallback) {
        for (const k of keys) {
            if (obj[k] !== undefined && obj[k] !== null && obj[k] !== "") return obj[k]
        }
        return fallback
    }

    // v6.16.4.12.6.8: HSL helpers + accent-from-primary derivation.
    //
    // Strategy: Material 3 only gives us 3 distinct accent hues
    // (primary/secondary/tertiary) plus error. For Zen's 8-accent
    // palette (red orange yellow green aqua blue purple), we anchor
    // each slot at its STANDARD hue position on the color wheel
    // (so red is always red-ish, blue is always blue-ish — not
    // remapped if the wallpaper happens to be blue) but borrow the
    // SATURATION and LIGHTNESS from M3's primary. Result: all 8
    // accents stay distinguishable, AND the whole palette has a
    // unified "feel" matching the wallpaper's overall tonal mood.
    //
    // Vivid wallpaper → vivid accents. Muted wallpaper → muted accents.
    // Dark wallpaper → readable mid-light accents (clamped).
    function _hexToHsl(hex) {
        const h = hex.replace(/^#/, "")
        if (h.length < 6) return { h: 0, s: 0, l: 0.5 }
        const r = parseInt(h.substring(0, 2), 16) / 255
        const g = parseInt(h.substring(2, 4), 16) / 255
        const b = parseInt(h.substring(4, 6), 16) / 255
        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        let hue = 0, sat = 0, lit = (max + min) / 2
        if (max !== min) {
            const d = max - min
            sat = lit > 0.5 ? d / (2 - max - min) : d / (max + min)
            if (max === r) hue = ((g - b) / d + (g < b ? 6 : 0)) / 6
            else if (max === g) hue = ((b - r) / d + 2) / 6
            else hue = ((r - g) / d + 4) / 6
        }
        return { h: hue, s: sat, l: lit }
    }

    function _hslToHex(h, s, l) {
        const c = Qt.hsla(h, s, l, 1.0)
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    // Build an accent at `targetHueDeg` (0-360) using the saturation
    // and lightness profile of `sourceHex` (the M3 primary). Saturation
    // is boosted so accents stay punchy even when the source is moody;
    // lightness is clamped to a readable range for terminal use.
    function _accentFromPrimary(sourceHex, targetHueDeg) {
        const hsl = _hexToHsl(sourceHex)
        const sat = Math.min(1.0, Math.max(0.55, hsl.s * 1.45))
        let lit = hsl.l
        if (lit < 0.50) lit = 0.55
        if (lit > 0.72) lit = 0.65
        return _hslToHex(targetHueDeg / 360.0, sat, lit)
    }

    function _writeMatugenTheme(d, palettes) {
        // Vivid M3 source — never the *_container surface variants.
        const primary   = _pick(d, ["primary"],   "#7aa2f7")
        const secondary = _pick(d, ["secondary"], "#bb9af7")
        const tertiary  = _pick(d, ["tertiary"],  "#7dcfff")
        const errorCol  = _pick(d, ["error"],     "#f7768e")

        // v6.16.4.12.6.9: PALETTE-FIRST accent picks. matugen's palette
        // ladders give us already-vivid tones for primary/secondary/
        // tertiary/error scales. Tone 70-80 is the sweet spot for
        // dark-mode accents (high enough lightness to pop on dark bg,
        // saturated enough to look "alive"). Falls through to my
        // hue-rotation derivation if a palette tone isn't available
        // OR if the palette's hue doesn't match the accent slot.
        function _paletteTone(paletteName, tone) {
            if (!palettes || !palettes[paletteName]) return null
            return palettes[paletteName][tone] || palettes[paletteName][String(tone)] || null
        }

        // Helper: detect if a palette's mid-tone falls in a hue range.
        // Used to decide whether to use a palette directly OR derive.
        function _paletteHueDeg(paletteName) {
            const t = _paletteTone(paletteName, "70") || _paletteTone(paletteName, "60")
            if (!t) return -1
            const h = _hexToHsl(t).h * 360
            return h
        }

        function _inHueBand(hue, minDeg, maxDeg) {
            if (hue < 0) return false
            if (minDeg <= maxDeg) return hue >= minDeg && hue <= maxDeg
            // Wrapping band (e.g. 330..30 for red)
            return hue >= minDeg || hue <= maxDeg
        }

        // Standard accent hues — used when palette doesn't fit the slot.
        function _slotHue(name) {
            switch (name) {
                case "red":    return 0
                case "orange": return 30
                case "yellow": return 55
                case "green":  return 135
                case "aqua":   return 180
                case "blue":   return 210
                case "purple": return 280
                default:       return 0
            }
        }

        // Primary slot resolver: prefer a vivid palette tone IF that
        // palette's hue matches the slot, else derive from primary's
        // tonality.
        function _accent(slot, paletteName, hueBandLo, hueBandHi) {
            const palHue = _paletteHueDeg(paletteName)
            if (_inHueBand(palHue, hueBandLo, hueBandHi)) {
                const t = _paletteTone(paletteName, "80") || _paletteTone(paletteName, "70")
                if (t) return t
            }
            return _accentFromPrimary(primary, _slotHue(slot))
        }

        const m = {
            // Backgrounds: M3 surface tonal variants
            bg0: _pick(d, ["surface_dim", "surface", "background"], "#1a1b26"),
            bg1: _pick(d, ["surface_container_low", "surface", "background"], "#24283b"),
            bg2: _pick(d, ["surface_container", "surface_variant"], "#292e42"),
            bg3: _pick(d, ["surface_container_high"], "#414868"),
            bg4: _pick(d, ["surface_container_highest", "surface_bright"], "#545c7e"),
            // Foreground / greys (high-contrast, taken directly from M3)
            fg:    _pick(d, ["on_surface", "on_background"], "#c0caf5"),
            grey0: _pick(d, ["on_surface_variant", "outline"], "#9aa5ce"),
            grey1: _pick(d, ["outline"], "#737aa2"),
            grey2: _pick(d, ["outline_variant"], "#565f89"),

            // Accents — palette-first when hue matches slot, else derived.
            // Hue bands are generous (±25°) so a palette in the right
            // ballpark gets used directly for max wallpaper character.
            red:    _accent("red",    "error",     335, 25),    // wraps over 0
            orange: _accent("orange", "secondary",  10, 50),
            yellow: _accent("yellow", "primary",    35, 75),
            green:  _accent("green",  "tertiary",   85, 165),
            aqua:   _accent("aqua",   "tertiary",  155, 200),
            blue:   _accent("blue",   "primary",   195, 240),
            purple: _accent("purple", "secondary", 255, 320)
        }

        const data = {
            id: "matugen-auto",
            name: "Matugen (Auto from Wallpaper)",
            description: "Generated from current wallpaper. Re-runs every wallpaper switch while toggle is ON.",
            is_builtin: false,
            colors: m
        }

        const json = JSON.stringify(data, null, 2)
        const targetPath = customDir + "/matugen-auto.json"

        // v6.16.4.12.6.6 fix: switched from `cat <<'HEREDOC'` to base64
        // piping. Heredoc was failing because the terminator line in the
        // generated bash command had ` && cp ...` appended after it, so
        // bash never recognized the end of the heredoc and the cat hung
        // → "Matugen write failed:" with empty error. base64 contains
        // only [A-Za-z0-9+/=] — totally shell-safe, no quote-escaping
        // needed for arbitrary JSON content.
        const b64 = Qt.btoa(json)
        matugenWriter.command = ["bash", "-c",
            "mkdir -p '" + customDir + "' && " +
            "echo '" + b64 + "' | base64 -d > '" + targetPath + "' && " +
            "cp '" + targetPath + "' '" + currentThemePath + "' && " +
            "echo OK:" + targetPath]
        matugenWriter.running = true
    }

    Process {
        id: matugenWriter
        running: false
        // v6.16.4.12.6.6: stderr capture added so write failures surface
        // their actual reason instead of "Matugen write failed:" with
        // empty trailing colon.
        stdout: StdioCollector {
            onStreamFinished: {
                const out = (this.text || "").trim()
                if (out.startsWith("OK:")) {
                    root.matugenStatus = "✓ Matugen applied — palette synced from wallpaper"
                    root.statusMsg = "Matugen applied"
                    root.refreshThemeList()
                    root.reload()
                    root.themeChanged()
                    terminalThemer.running = true
                    swayncThemer.running = true
                    syncSddmIfEnabled()
                    if (root.autoReloadOnApply) shellReloadTimer.start()
                    root.matugenAppliedFor(root.matugenStatePath) // generic ping
                } else {
                    root.matugenStatus = "Matugen write failed: " +
                        (out.length > 0 ? out : "(no stdout — check stderr below)")
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = (this.text || "").trim()
                if (err.length > 0) {
                    const cur = root.matugenStatus
                    if (cur.indexOf("write failed") >= 0) {
                        root.matugenStatus = cur + " | stderr: " + err.substring(0, 240)
                    }
                    console.error("[Matugen write] stderr:", err)
                }
            }
        }
    }

    Component.onCompleted: {
        dirInit.running = true
        Qt.callLater(function() {
            refreshThemeList()
            currentThemeFile.reload()
            // v6.16.4.12.6 matugen init
            matugenProbe.running = true
            matugenStateFile.reload()
        })
    }
}
