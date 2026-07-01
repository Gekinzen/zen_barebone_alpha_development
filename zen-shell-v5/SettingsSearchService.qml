pragma Singleton

import QtQuick

/*
 * SettingsSearchService v7.0.0-alpha.6-hf1 — search index for Settings + Control Center
 *
 * Hardcoded index (not runtime QML reflection) of every settings page,
 * its sections, and notable rows — keyed for fuzzy search. Returns
 * navigation targets that the search bar consumer (ZenSettings,
 * ControlPanel) uses to jump to the matching page/section.
 *
 * Each entry shape:
 *   {
 *     id: "themes-densho",            // unique row key
 *     title: "Densho mode",           // user-visible label
 *     subtitle: "Traditional Japanese aesthetic toggles",
 *     keywords: "japanese kanji washi sumi vermillion shu-iro",
 *     surface: "settings",            // "settings" | "controlpanel"
 *     page: "themes",                 // ZenSettings.currentPage value
 *     anchor: "densho-section"        // optional: scroll target inside page
 *   }
 *
 * Consumers call `search(query)` → returns array of matched entries
 * ranked by relevance. `navigateTo(entry)` is a helper that tells the
 * caller surface to flip to the right page.
 *
 * Why hardcoded vs reflection: the page set is stable and small (~16
 * pages × ~80 rows ≈ 1300 keywords-worth). A static index is faster,
 * deterministic, and translatable. Adding a new page = add a few
 * lines here.
 *
 * Wala tayong babawasan — purely additive. Existing surfaces don't
 * need to use this; they continue to work via direct currentPage
 * setters as before.
 *
 * hf1: changed root from `Singleton { ... }` (Quickshell-only type)
 * to QtObject. Pure data + functions, no Quickshell APIs needed.
 */
QtObject {
    id: root

    // ─────────────────────────────────────────────────────────────
    // INDEX — every entry is searchable
    //
    // Conventions:
    //   - title:    most likely query word
    //   - subtitle: short helper
    //   - keywords: alternate query words (synonyms, related terms)
    //   - icon:     Material Symbols icon name (resolved via MaterialIcons)
    //
    // For Densho mode, keywords include both English + romaji + kanji
    // so user can search either way (e.g. "kanji workspaces" finds
    // the Densho kanji workspace toggle).
    // ─────────────────────────────────────────────────────────────
    readonly property var index: [
        // ── GENERAL ──
        { id: "general",            title: "General",            subtitle: "Basic shell preferences",
          keywords: "general settings preferences misc",
          surface: "settings", page: "general", icon: "tune" },
        { id: "general-locale",     title: "Locale",             subtitle: "Language and region",
          keywords: "language region timezone country",
          surface: "settings", page: "general", icon: "tune" },

        // ── DECORATION ──
        { id: "decoration",         title: "Decoration",         subtitle: "Bar shape, blur, transparency",
          keywords: "decoration radius transparency blur shape rounded square",
          surface: "settings", page: "decoration", icon: "brush" },
        { id: "decoration-blur",    title: "Background blur",    subtitle: "Bar/panel blur strength",
          keywords: "blur transparency frosted glass",
          surface: "settings", page: "decoration", icon: "brush" },
        { id: "decoration-radius",  title: "Corner radius",      subtitle: "Square vs rounded UI",
          keywords: "rounded square corner radius shape",
          surface: "settings", page: "decoration", icon: "brush" },

        // ── ANIMATIONS ──
        { id: "animations",         title: "Animations",         subtitle: "Transition speed and easing",
          keywords: "animations duration easing motion transitions",
          surface: "settings", page: "animations", icon: "animation" },

        // ── THEMES ──
        { id: "themes",             title: "Themes",             subtitle: "Color palette switcher",
          keywords: "themes colors palette dark light matugen wallpaper",
          surface: "settings", page: "themes", icon: "palette" },
        { id: "themes-matugen",     title: "Matugen",            subtitle: "Generate theme from wallpaper",
          keywords: "matugen wallpaper extract material you generate",
          surface: "settings", page: "themes", icon: "palette" },
        { id: "themes-densho",      title: "Densho mode",        subtitle: "Traditional Japanese aesthetic toggles",
          keywords: "densho 伝承 japanese kanji washi sumi shu-iro vermillion traditional",
          surface: "settings", page: "themes", icon: "palette" },
        { id: "themes-densho-kanji", title: "Kanji workspaces",  subtitle: "Densho: workspace labels as 一二三四",
          keywords: "kanji workspaces 一 二 三 densho japanese numbers",
          surface: "settings", page: "themes", icon: "palette" },
        { id: "themes-densho-vdate", title: "Vertical kanji date", subtitle: "Densho: vertical year column",
          keywords: "vertical date kanji densho 二〇二六 year column",
          surface: "settings", page: "themes", icon: "palette" },
        { id: "themes-densho-sekki", title: "Seasonal kanji column", subtitle: "Densho: 24-sekki rotation",
          keywords: "sekki seasonal kanji 立夏 rikka 24 二十四節気 densho",
          surface: "settings", page: "themes", icon: "palette" },

        // ── DISPLAYS ──
        { id: "displays",           title: "Displays",           subtitle: "Monitor configuration",
          keywords: "displays monitors resolution scale refresh rate hdr",
          surface: "settings", page: "displays", icon: "monitor" },

        // ── INPUT ──
        { id: "input",              title: "Input",              subtitle: "Mouse, keyboard, touchpad",
          keywords: "input mouse keyboard touchpad sensitivity scroll",
          surface: "settings", page: "input", icon: "mouse" },

        // ── PANEL ──
        { id: "panel",              title: "Panel",              subtitle: "Bar position, layout, modules",
          keywords: "panel bar position top bottom left right layout modules borders",
          surface: "settings", page: "panel", icon: "view_quilt" },
        { id: "panel-position",     title: "Bar position",       subtitle: "Top, bottom, left, right",
          keywords: "panel bar position top bottom left right",
          surface: "settings", page: "panel", icon: "view_quilt" },
        { id: "panel-modules",      title: "Bar modules",        subtitle: "Add/remove bar widgets",
          keywords: "modules bar widgets clock weather workspaces clipboard taskbar tray battery",
          surface: "settings", page: "panel", icon: "widgets" },
        { id: "panel-border",       title: "Bar border",         subtitle: "Border width and color",
          keywords: "border width color outline",
          surface: "settings", page: "panel", icon: "view_quilt" },

        // ── BAR MODULES (separate page) ──
        { id: "barmodules",         title: "Bar modules",        subtitle: "Clock format, fonts, start menu",
          keywords: "bar modules clock fonts workspaces start menu",
          surface: "settings", page: "barmodules", icon: "widgets" },
        { id: "barmodules-clock",   title: "Clock format",       subtitle: "12h/24h, date display",
          keywords: "clock time 12h 24h date format",
          surface: "settings", page: "barmodules", icon: "widgets" },
        { id: "barmodules-startmenu", title: "Start Menu pinned grid", subtitle: "Cols/rows + border mode",
          keywords: "start menu pinned grid cols rows border match bar",
          surface: "settings", page: "barmodules", icon: "widgets" },
        { id: "barmodules-clipboard", title: "Clipboard module", subtitle: "Show clipboard icon in bar",
          keywords: "clipboard cliphist history paste copy",
          surface: "settings", page: "barmodules", icon: "content_paste" },

        // ── SYSTEM TRAY ──
        { id: "sysrow",             title: "System Tray",        subtitle: "Tray icons + sysrow density",
          keywords: "system tray sysrow icons density notification area",
          surface: "settings", page: "sysrow", icon: "memory" },

        // ── CONNECTIVITY ──
        { id: "connectivity",       title: "Sound & Network",    subtitle: "Audio, wifi, bluetooth",
          keywords: "connectivity sound audio volume wifi network bluetooth",
          surface: "settings", page: "connectivity", icon: "wifi" },

        // ── NOTIFICATIONS ──
        { id: "notifications",      title: "Notifications",      subtitle: "DND, app filter, position",
          keywords: "notifications dnd do not disturb popup toast",
          surface: "settings", page: "notifications", icon: "notifications" },

        // ── BATTERY & POWER ──
        { id: "battery",            title: "Battery & Power",    subtitle: "Battery, brightness, laptop mode",
          keywords: "battery power brightness laptop endurance balanced charge limit",
          surface: "settings", page: "battery", icon: "battery_full" },
        { id: "battery-laptop",     title: "Laptop Mode",        subtitle: "Adaptive polling + battery saver",
          keywords: "laptop mode endurance balanced battery polling power-saver governor",
          surface: "settings", page: "battery", icon: "battery_full" },
        { id: "battery-charge",     title: "Charge limit 80%",   subtitle: "Halve battery cycle wear",
          keywords: "charge limit 80 battery health cycle wear",
          surface: "settings", page: "battery", icon: "bolt" },

        // ── USER PROFILE ──
        { id: "userprofile",        title: "User Profile",       subtitle: "Avatar, username, sysinfo",
          keywords: "user profile avatar username name picture",
          surface: "settings", page: "userprofile", icon: "person" },

        // ── UPDATES ──
        { id: "updates",            title: "Updates",            subtitle: "Check + rollback shell version",
          keywords: "updates check version rollback snapshot upgrade",
          surface: "settings", page: "updates", icon: "refresh" },

        // ── DESKTOP WIDGETS ──
        { id: "widgets",            title: "Desktop Widgets",    subtitle: "Floating clock, weather, sysmon",
          keywords: "desktop widgets clock weather system monitor floating",
          surface: "settings", page: "widgets", icon: "widgets" },

        // ── WALLPAPER ──
        { id: "wallpaper",          title: "Wallpaper",          subtitle: "Image picker + slideshow",
          keywords: "wallpaper background image slideshow rotate",
          surface: "settings", page: "wallpaper", icon: "image" },

        // ────────────────────────────────────────────────────────────
        // CONTROL CENTER — quick toggles surface
        // ────────────────────────────────────────────────────────────
        { id: "cc-wifi",            title: "Wi-Fi",              subtitle: "Quick wifi toggle / network picker",
          keywords: "wifi network signal connection",
          surface: "controlpanel", page: "wifi", icon: "wifi" },
        { id: "cc-bluetooth",       title: "Bluetooth",          subtitle: "BT toggle / device picker",
          keywords: "bluetooth bt headphones devices",
          surface: "controlpanel", page: "bluetooth", icon: "wifi" },
        { id: "cc-audio",           title: "Audio",              subtitle: "Volume + output device",
          keywords: "audio volume sound output speaker headphones",
          surface: "controlpanel", page: "audio", icon: "wifi" },
        { id: "cc-input",           title: "Input",              subtitle: "Mouse sensitivity / scroll",
          keywords: "input mouse sensitivity scroll cursor",
          surface: "controlpanel", page: "input", icon: "mouse" },
        { id: "cc-power",           title: "Power profile",      subtitle: "Performance / Balanced / Saver",
          keywords: "power profile performance balanced saver",
          surface: "controlpanel", page: "power", icon: "power_settings" },
        { id: "cc-brightness",      title: "Brightness",         subtitle: "Display brightness slider",
          keywords: "brightness display screen dim",
          surface: "controlpanel", page: "audio", icon: "speed" }
    ]

    // ─────────────────────────────────────────────────────────────
    // SEARCH — three-tier ranked match
    //
    //   1. Exact title prefix    (highest)
    //   2. Title contains        (medium)
    //   3. Subtitle/keywords      (lowest)
    //
    // Empty query returns the full index. Single-character queries
    // also return everything (typing one letter shouldn't filter
    // aggressively — too jarring).
    // ─────────────────────────────────────────────────────────────
    function search(query) {
        if (!query || query.length < 2) return index
        const q = query.toLowerCase().trim()

        const titlePrefix = []
        const titleContains = []
        const otherMatch = []

        for (var i = 0; i < index.length; i++) {
            const e = index[i]
            const title = (e.title || "").toLowerCase()
            const subtitle = (e.subtitle || "").toLowerCase()
            const keywords = (e.keywords || "").toLowerCase()

            if (title.indexOf(q) === 0) {
                titlePrefix.push(e)
            } else if (title.indexOf(q) >= 0) {
                titleContains.push(e)
            } else if (subtitle.indexOf(q) >= 0 || keywords.indexOf(q) >= 0) {
                otherMatch.push(e)
            }
        }

        const settingsResults = titlePrefix.concat(titleContains).concat(otherMatch)

        // ─────────────────────────────────────────────────────────
        // v7.0.0-alpha.10 — Spotlight palette extensions
        //
        // Settings results come first (they're the focused use-case),
        // then apps (filtered by prefix-match on app name), then
        // calculator result (if query parses as math expression),
        // then file results (deferred to alpha.11 — file search needs
        // a separate FileSearchService that watches ~/Documents et al).
        // ─────────────────────────────────────────────────────────

        // App results — pull from AppLauncherService.apps array
        const appResults = []
        if (typeof AppLauncherService !== "undefined"
            && AppLauncherService.apps) {
            const apps = AppLauncherService.apps
            for (var j = 0; j < apps.length; j++) {
                const app = apps[j]
                const appName = (app.name || "").toLowerCase()
                if (appName.indexOf(q) === 0 || appName.indexOf(q) >= 0) {
                    appResults.push({
                        id: "app:" + app.id,
                        title: app.name,
                        subtitle: app.comment || "Application",
                        icon: "rocket_launch",
                        surface: "app",
                        page: "",
                        _appData: app    // attached for navigation handler
                    })
                    if (appResults.length >= 5) break   // cap apps to 5
                }
            }
        }

        // Calculator result — detect math expressions (digits + operators + spaces)
        const calcResults = _evaluateMath(q)

        // v7.0.0-alpha.11: File results — pull from FileSearchService
        // if available. Up to 8 file matches returned; appended at the
        // end so Settings + Apps still take priority for short queries.
        const fileResults = []
        if (typeof FileSearchService !== "undefined"
            && FileSearchService.search) {
            const files = FileSearchService.search(q)
            for (var k = 0; k < files.length; k++) {
                fileResults.push(files[k])
                if (fileResults.length >= 5) break
            }
        }

        return calcResults.concat(settingsResults).concat(appResults).concat(fileResults)
    }

    // ─────────────────────────────────────────────────────────────
    // CALCULATOR
    //
    // Detects if the query looks like a math expression (e.g. "2+2",
    // "100*1.08", "(3+4)*5"). If yes, evaluates it safely and
    // returns a single result entry with the answer.
    //
    // Safety: we whitelist the input to digits, operators, parens,
    // and decimal points only. NEVER eval user input directly.
    // Use Function() constructor with the sanitized string so it
    // runs in an isolated scope.
    // ─────────────────────────────────────────────────────────────
    function _evaluateMath(query) {
        // Quick reject: no digits = not math
        if (!/\d/.test(query)) return []

        // Whitelist: digits, +-*/.()% spaces, and optional leading minus
        const sanitized = query.replace(/\s+/g, "")
        if (!/^[\d+\-*/.()%]+$/.test(sanitized)) return []

        // Reject expressions that are JUST a number (not really a calc)
        if (/^-?\d+(\.\d+)?$/.test(sanitized)) return []

        try {
            // Using Function() instead of eval() — runs in isolated
            // scope, no access to closure variables. Sanitized input
            // means only valid arithmetic survives.
            const result = (new Function("return (" + sanitized + ")"))()

            // Guard: NaN/Infinity = invalid expression
            if (typeof result !== "number" || !isFinite(result)) return []

            // Format result: integers as-is, decimals to 6 places max
            const formatted = (result === Math.floor(result))
                ? result.toString()
                : parseFloat(result.toFixed(6)).toString()

            return [{
                id: "calc:" + sanitized,
                title: formatted,
                subtitle: sanitized + " = " + formatted,
                icon: "calculator",
                surface: "calculator",
                page: "",
                _calcResult: formatted
            }]
        } catch (e) {
            return []
        }
    }

    // Pretty surface label for grouping in UI
    function surfaceLabel(s) {
        if (s === "settings")    return "Settings"
        if (s === "controlpanel") return "Control Center"
        if (s === "app")          return "App"
        if (s === "calculator")   return "Calc"
        if (s === "file")         return "File"
        return s || ""
    }
}
