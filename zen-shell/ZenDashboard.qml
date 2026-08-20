import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/*
 * ZenDashboard v7.0.0-beta.1-hf99zp — Karui (軽い)
 *
 * "Zen Control Center" — the merged Quick Settings + Hyprland Control Center
 * dashboard: Quick-Settings styling at Control-Center size.
 *
 *   ┌──────────┬──────────────────────────────┬────────────┐
 *   │ sidebar  │ main (Dashboard / settings)  │ right rail │
 *   │  nav     │  hero · sysmon · clocks ·    │  toggles · │
 *   │  …       │  weather · workspaces        │  power ·   │
 *   │ profile  │                              │  uptime    │
 *   └──────────┴──────────────────────────────┴────────────┘
 *
 * Profile card sits at the BOTTOM of the sidebar (per the mockup).
 * Everything is glass-aware: when the Shell Look is "glass" the cards go
 * translucent so Hyprland's layer blur reads through.
 *
 * Reuses existing services (no duplication): UserProfileService,
 * WeatherService, SystemMonitorService, PowerProfileService,
 * ConnectivityService, WidgetsState (desktop-widget look), LookService.
 *
 * Settings pages are the SAME components the Settings window uses
 * (ThemesPage / ShellLookPage / WidgetsPage / PanelPage) — merged, not copied.
 */
Rectangle {
    id: dash

    // v8.0.0-alpha-hf133 — this rectangle IS the window's input mask
    // (`mask: Region { item: … }` in shell.qml). ZenDropdown walks up for
    // this flag and clamps its popup inside these bounds; anything drawn
    // outside is click-through and would dismiss the panel instead of
    // selecting. Set it on any surface that masks itself.
    property bool zenPopupBounds: true

    // ── Glass-aware surface ────────────────────────────────────
    readonly property bool glassLook: LookService.activeLook === "glass"
    readonly property color cardBg: glassLook ? LookService.surfaceColor(ThemeService.bg1, 0.28)
                                              : LookService.surfaceColor(ThemeService.bg1, 0.62)
    readonly property color cardBorder: glassLook ? ThemeService.alpha(ThemeService.fg, 0.22)
                                                  : ThemeService.alpha(ThemeService.fg, 0.08)
    readonly property int cardRadius: glassLook ? 18 : 14

    property int currentPage: 0
    // v7.0.0-beta.1-hf99zs: dashboard reorder mode (toggled by the Edit button)
    property bool editMode: false
    // v8.0.0-alpha-hf103: card selected for keyboard moves (edit mode)
    property int selectedIndex: -1

    // v8.0.0-alpha-hf105: UI scale + the minimum the three columns need.
    // 232 sidebar + 288 rail + 420 readable main + margins/spacing ≈ 986.
    // v8.0.0-alpha-hf109: below `compactWidth` the right rail is dropped rather
    // than scaled into illegibility (a rotated 1080-wide panel can't hold three
    // columns). Below `narrowWidth` the sidebar collapses to icons.
    readonly property int railWidth: 288
    readonly property int sidebarWidth: narrow ? 62 : 232
    readonly property bool compact: width < 980
    readonly property bool narrow: width < 720

    // hf127: the sidebar is outside the scaled area, so it is not part of the
    // content that has to fit. What must fit: [main][gap][rail 288].
    //
    // hf198 — the main term was 420. Real settings pages (label + description
    // + value control on one SettingRow) need ~620 before the controls start
    // painting PAST the column — QML Layouts don't clip, so on a portrait
    // monitor the spinners slid UNDER the right rail and looked amputated
    // ("d ko padin makita yun mga settings sa gitna"). 620 makes fitScale
    // engage on widths where 420 wrongly said "everything fits".
    readonly property int minContentWidth:
        (compact ? 0 : railWidth + 12) + 620

    // The width dashFlick actually gets. Derived from `width`, not from
    // dashFlick.width, so fitScale -> uiScale -> contentRoot can't feed back.
    // sidebar: 14 left margin + sidebarWidth. gap: 12. flick right margin: 14.
    readonly property int contentAvailWidth:
        Math.max(1, width - (14 + sidebarWidth + 12) - 14)
    readonly property int minContentHeight: 560

    // v8.0.0-alpha-hf107: the content never runs off the edge. `fitScale` is the
    // largest scale where the three columns still fit the window; the user's
    // scale acts as a ceiling, so zooming out always works and zooming in stops
    // at the fit. (Before, anything over the fit simply overflowed to the right.)
    //
    // hf198 — READABILITY FLOOR + AUTOMATIC HORIZONTAL SCROLL. Auto-shrink now
    // stops at `hscrollFloor` (0.85): squeezing a portrait monitor further just
    // made 10px text nobody can read. Below the floor, fitScale holds at 0.85,
    // contentRoot keeps its minContentWidth — which is now WIDER than the
    // viewport — and dashFlick's AlwaysOn-when-overflow horizontal scrollbar
    // (there since hf127) switches on by itself. So: mildly tight → gentle
    // shrink; genuinely tight → pan sideways, nothing hidden. Manual zoom via
    // PanelState.dashScale below 0.85 still works — the floor only binds the
    // AUTOMATIC fit, not your own zoom (that keeps the old 0.5 hard floor).
    readonly property real hscrollFloor: 0.85
    readonly property real fitScale: (width > 0)
        ? Math.min(1.0, Math.max(hscrollFloor, contentAvailWidth / minContentWidth))
        : 1.0
    readonly property real uiScale: Math.max(0.5, Math.min(PanelState.dashScale, fitScale))
    readonly property bool scaleClampedToFit: PanelState.dashScale > fitScale + 0.001
    onEditModeChanged: if (!editMode) selectedIndex = -1

    // Move the selected card with the arrow keys. Left/Right step one slot,
    // Up/Down jump by a full row (dashColumns / span), which is what "move it
    // above" means in a packed grid.
    function moveSelected(dir) {
        if (selectedIndex < 0 || selectedIndex >= PanelState.dashOrder.length) return
        const n = PanelState.dashOrder.length
        let to = selectedIndex
        if (dir === "left")  to = selectedIndex - 1
        if (dir === "right") to = selectedIndex + 1
        if (dir === "up")    to = 0
        if (dir === "down")  to = n - 1
        to = Math.max(0, Math.min(n - 1, to))
        if (to === selectedIndex) return
        PanelState.dashMove(selectedIndex, to, true)
        selectedIndex = to
    }
    property bool maximized: false
    // v7.0.0-beta.1-hf99zw: window drag (shell.qml drops centerIn once dragged)
    property bool hasBeenDragged: false
    property string railTab: "wifi"

    // v7.0.0-beta.1-hf99zy: active window (hyprctl, 1.5s poll — no extra service)
    property string activeWinTitle: ""
    property string activeWinClass: ""
    Process {
        id: _activeWin
        running: false
        command: ["bash", "-c", "command -v hyprctl >/dev/null 2>&1 && hyprctl activewindow -j 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(this.text || "{}")
                    dash.activeWinTitle = w.title || ""
                    dash.activeWinClass = w.class || ""
                } catch (e) { dash.activeWinTitle = ""; dash.activeWinClass = "" }
            }
        }
    }
    Timer { interval: 1500; repeat: true; running: dash.visible; triggeredOnStart: true
            onTriggered: if (!_activeWin.running) _activeWin.running = true }
    property string searchText: ""

    // ═══════════════════════════════════════════════════════════════════════
    // One source of truth for the system-monitor cards, so the Pills and the
    // Classic bars render exactly the same numbers.
    //
    // ══ v8.0.0-alpha-hf129 — WHY THE LIVE VALUES LEFT THIS ARRAY ══
    //
    // The bug: every second the dashboard's System Monitor bars snapped back
    // to zero and re-grew. Not an easing artefact — the bars genuinely started
    // over, so a 300ms animation never finished before the next tick reset it.
    // Flicker.
    //
    // The cause: `sysModel` was a `var` binding over a JS array literal whose
    // elements read SystemMonitorService.cpuPercent, .gpuUsage, .netUp and a
    // dozen more. Touch ANY of them and the binding re-runs and produces a
    // brand-new array of brand-new objects. A Repeater cannot know the new
    // array describes the same five cards — it sees a different model, so it
    // destroys all five delegates and builds five more. The fill Rectangle is
    // born at width 0, `Behavior on width` catches the jump to the real
    // width, and you watch every bar run from scratch, 60 times a minute.
    //
    // The fix: the model is now CONSTANT — five cards, identity, no readings.
    // It has no dependency on SystemMonitorService, so it is evaluated exactly
    // once and the delegates live for the lifetime of the card. The readings
    // come from sysPct/sysS1/sysS2, called from inside each delegate: QML's
    // dependency capture follows the call and subscribes the delegate's own
    // property to just the service values it actually read. Now a CPU tick
    // updates one number and animates one bar, instead of rebuilding the row.
    //
    // Wala tayong babawasan — same five cards, same glyphs, same accents, same
    // Pills / Classic switch, same numbers.
    // ═══════════════════════════════════════════════════════════════════════
    readonly property var sysModel: [
        { key: "cpu",  label: "CPU",  glyph: "\uf2db", accent: "#1268d3" },
        { key: "gpu",  label: "GPU",  glyph: "\uf1b2", accent: "#1e8e3e" },
        { key: "ram",  label: "RAM",  glyph: "\uefc5", accent: "#1a56db" },
        { key: "vram", label: "VRAM", glyph: "\uefc5", accent: "#7c3aed" },
        { key: "net",  label: "NET",  glyph: "\uf1eb", accent: "#ea580c" }
    ]

    /** Percentage for a card, or -1 for cards that have none (NET). */
    function sysPct(key) {
        if (key === "cpu")  return SystemMonitorService.cpuPercent
        if (key === "gpu")  return SystemMonitorService.gpuUsage
        if (key === "ram")  return SystemMonitorService.ramPercent
        if (key === "vram") return SystemMonitorService.gpuVramTotal > 0
                                   ? Math.round(SystemMonitorService.gpuVramUsed
                                                / SystemMonitorService.gpuVramTotal * 100)
                                   : 0
        return -1
    }
    /** Primary sub-line (temperature / used memory / upstream). */
    function sysS1(key) {
        if (key === "cpu")  return SystemMonitorService.cpuTemp > 0 ? (SystemMonitorService.cpuTemp + "\u00b0") : "\u2014"
        if (key === "gpu")  return SystemMonitorService.gpuTemp > 0 ? (SystemMonitorService.gpuTemp + "\u00b0") : "\u2014"
        if (key === "ram")  return SystemMonitorService.ramUsedGb.toFixed(1) + "G"
        if (key === "vram") return SystemMonitorService.gpuVramUsed.toFixed(1) + "G"
        return "\u2191 " + SystemMonitorService.netUp
    }
    /** Secondary sub-line (clock speed / free memory / downstream). */
    function sysS2(key) {
        if (key === "cpu")  return SystemMonitorService.cpuMhz > 0 ? ((SystemMonitorService.cpuMhz / 1000).toFixed(1) + " GHz") : "\u2014"
        if (key === "gpu")  return SystemMonitorService.gpuMhz > 0 ? (SystemMonitorService.gpuMhz + " MHz") : "\u2014"
        if (key === "ram")  return (SystemMonitorService.ramTotalGb - SystemMonitorService.ramUsedGb).toFixed(1) + "G free"
        if (key === "vram") return (SystemMonitorService.gpuVramTotal - SystemMonitorService.gpuVramUsed).toFixed(1) + "G free"
        return "\u2193 " + SystemMonitorService.netDown
    }

    // v8.0.0-alpha-hf112: the Control Center has its own opacity now, written by
    // the Shell Look preset and editable from Shell Look → Control Center opacity.
    // v8.0.0-alpha-hf149 — the whole Control Center follows the look: frosted
    // white glass on Glass+, its dashOpacity tint otherwise.
    color: LookService.bodyColor(LookService.surfaceColor(ThemeService.bg0, PanelState.dashOpacity))
    radius: 20
    antialiasing: true
    border.width: LookService.bodyBorderWidth(1)
    border.color: LookService.bodyBorderColor(cardBorder)
    Behavior on color { ColorAnimation { duration: 180 } }

    // 1s clock shared by the hero card
    property date now: new Date()
    Timer { interval: 1000; running: dash.visible; repeat: true; onTriggered: dash.now = new Date() }

    // v7.0.0-beta.1-hf99zt: every Settings module now lives in the dashboard.
    // Index 0 is the Dashboard page; 1..32 map 1:1 to the page components in
    // the StackLayout below (same components the Settings window mounts).
    readonly property var navCategories: ({
        "dashboard": "",           // no header
        "appearance": "APPEARANCE", "display": "INPUT & DISPLAY", "connectivity": "CONNECTIVITY",
        "system": "SYSTEM", "other": "OTHER", "productivity": "PRODUCTIVITY"
    })
    // page index → category (indices match navItems below)
    readonly property var navCatFor: [
        "dashboard",
        "appearance",   // General
        "appearance",   // Decoration
        "appearance",   // Animations
        "appearance",   // Themes
        "display",      // Displays
        "display",      // Input
        "appearance",   // Panel
        "appearance",   // Bar Modules
        "appearance",   // System Tray
        "appearance",   // Hot Corners
        "connectivity", // Sound & Network
        "connectivity", // Notifications
        "system",       // Battery & Power
        "system",       // User Profile
        "system",       // Updates
        "other",        // Desktop Widgets
        "other",        // Wallpaper
        "productivity", // Focus Spaces
        "productivity", // Quick Notes
        "productivity", // Network Pulse
        "productivity", // Smart Dim
        "productivity", // Title Translator
        "appearance",   // Hyprbars
        "system",       // Game Detection
        "appearance",   // Dock
        "system",       // Default Apps
        "system",       // App Float Rules
        "other",        // Desktop
        "system",       // User Management
        "system",       // Login Screen
        "appearance",   // Shell Look
        "appearance",   // Cursor (v8.0.0-alpha-hf168)
        "appearance",   // Taskbar (v8.0.0-alpha-hf182)
        "system"        // Panasonic (v8.0.0-alpha-hf185)
    ]

    // v7.0.0-beta.1-hf99zw: subsequence fuzzy match with a small score —
    // consecutive hits and word-start hits rank higher ("bmod" → Bar Modules).
    function _fuzzy(needle, hay) {
        const n = needle.toLowerCase(), h = hay.toLowerCase()
        if (n.length === 0) return 0
        let hi = 0, score = 0, streak = 0
        for (let ni = 0; ni < n.length; ni++) {
            const ch = n[ni]
            let found = -1
            for (let k = hi; k < h.length; k++) { if (h[k] === ch) { found = k; break } }
            if (found < 0) return -1                       // not a subsequence → no match
            const wordStart = found === 0 || h[found - 1] === " " || h[found - 1] === "&"
            score += 1 + (wordStart ? 4 : 0) + (found === hi ? (2 + streak) : 0)
            streak = (found === hi) ? streak + 1 : 0
            hi = found + 1
        }
        return score - Math.floor(h.length / 12)           // mild preference for shorter names
    }

    // The sidebar always shows EVERY module (search no longer hides it).
    // hf129: still the source for the narrow (icon-only) sidebar, which has no
    // room for group headers and stays a flat list.
    readonly property var filteredNav: {
        const out = []
        for (let i = 0; i < navItems.length; i++)
            out.push({ idx: i, label: navItems[i].label, icon: navItems[i].icon, cat: navCatFor[i] || "other" })
        return out
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf129 — GROUPED, COLLAPSIBLE SIDEBAR NAV
    //
    // The old sidebar drew a category header whenever the *previous* item had
    // a different category. Because navCatFor interleaves — appearance ×4,
    // display ×2, appearance ×4, connectivity, system ×3, other ×2, … — that
    // printed APPEARANCE four times, SYSTEM three times and OTHER twice, in a
    // list you had to scroll to reach Shell Look.
    //
    // Now each category appears exactly once and owns its modules. Groups are
    // built FROM navCatFor rather than hand-listed, so adding a module to the
    // table below files it automatically — no second list to forget.
    //
    // Accordion rules (Paul's spec):
    //   · Dashboard is a top-level row, never inside a group
    //   · every group starts collapsed
    //   · clicking a header opens that group and closes the other one
    //   · clicking an open header closes it
    //   · navigating by search or a quick action opens the owning group
    // ═══════════════════════════════════════════════════════════════════════
    readonly property var navGroupOrder: ["appearance", "display", "connectivity",
                                          "system", "productivity", "other"]
    readonly property var navGroups: {
        const bucket = ({})
        for (let g = 0; g < navGroupOrder.length; g++) bucket[navGroupOrder[g]] = []
        // idx 0 is Dashboard — it lives outside the groups.
        for (let i = 1; i < navItems.length; i++) {
            // v8.0.0-alpha-hf185 — hardware-gated modules. Filtering HERE covers
            // the grouped nav, the narrow rail and the Ctrl+K search index at
            // once, because all three read navGroups.
            if (navItems[i].id === "p34" && !dash.panasonicPresent) continue
            const cat = navCatFor[i] || "other"
            if (!bucket[cat]) bucket[cat] = []
            bucket[cat].push({ idx: i, label: navItems[i].label, icon: navItems[i].icon })
        }
        const out = []
        for (let g = 0; g < navGroupOrder.length; g++) {
            const key = navGroupOrder[g]
            if (bucket[key] && bucket[key].length > 0)
                out.push({ key: key,
                           label: navCategories[key] || key.toUpperCase(),
                           items: bucket[key] })
        }
        return out
    }

    /** Which category key is expanded. "" = every group closed (the default). */
    property string navOpenGroup: ""
    function navGroupOf(pageIdx) { return navCatFor[pageIdx] || "other" }

    // Landing on a page from anywhere that isn't the nav itself — the search
    // dropdown, a quick-action button, the profile card — reveals the group
    // that owns it. Without this you'd see a selection you can't find.
    onCurrentPageChanged: {
        if (currentPage <= 0) return
        const g = navGroupOf(currentPage)
        if (navOpenGroup !== g) navOpenGroup = g
    }

    // Fresh session = collapsed, per spec. If the panel reopens on a settings
    // page, reveal that page's group instead of stranding the selection.
    onVisibleChanged: {
        if (!visible) return
        navOpenGroup = (currentPage <= 0) ? "" : navGroupOf(currentPage)
        // v8.0.0-alpha-hf165 — if the forecast/hourly strips have no data yet (stale or
        // empty cache), kick a fetch on open so they fill in. The 30-min timer still runs.
        if (typeof WeatherService !== "undefined"
            && ((!WeatherService.forecast || WeatherService.forecast.length === 0)
                || (!WeatherService.hourly || WeatherService.hourly.length === 0)))
            WeatherService.refresh()
    }

    // Search results — every page that fuzzy-matches, ranked, shown as a
    // dropdown under the search box (not just a sidebar filter).
    readonly property var searchResults: {
        const q = searchText.trim()
        if (q.length === 0) return []
        const hits = []
        for (let i = 1; i < navItems.length; i++) {
            if (navItems[i].id === "p34" && !dash.panasonicPresent) continue   // hf185
            const sc = _fuzzy(q, navItems[i].label)
            if (sc >= 0) hits.push({ idx: i, label: navItems[i].label, icon: navItems[i].icon,
                                     cat: navCategories[navCatFor[i]] || "", score: sc })
        }
        hits.sort((a, b) => b.score - a.score)
        return hits.slice(0, 8)
    }

    readonly property var navItems: [
        { id: "dashboard", label: "Dashboard",      icon: "\uf015" },
        { id: "p0", label: "General", icon: "\uf013" },
        { id: "p1", label: "Decoration", icon: "\uf1fc" },
        { id: "p2", label: "Animations", icon: "\uf021" },
        { id: "p3", label: "Themes", icon: "\udb80\udd0e" },
        { id: "p4", label: "Displays", icon: "\uf108" },
        { id: "p5", label: "Input", icon: "\uf245" },
        { id: "p6", label: "Panel", icon: "\uf07e" },
        { id: "p7", label: "Bar Modules", icon: "\uf017" },
        { id: "p8", label: "System Tray", icon: "\uf0ca" },
        { id: "p9", label: "Hot Corners", icon: "\uf0a9" },
        { id: "p10", label: "Sound & Network", icon: "\uf1eb" },
        { id: "p11", label: "Notifications", icon: "\uf0f3" },
        { id: "p12", label: "Battery & Power", icon: "\uf240" },
        { id: "p13", label: "User Profile", icon: "\uf007" },
        { id: "p14", label: "Updates", icon: "\uf021" },
        { id: "p15", label: "Desktop Widgets", icon: "\uf0e4" },
        { id: "p16", label: "Wallpaper", icon: "\uf03e" },
        { id: "p18", label: "Focus Spaces", icon: "\uf0db" },
        { id: "p19", label: "Quick Notes", icon: "\uf249" },
        { id: "p20", label: "Network Pulse", icon: "\uf0ec" },
        { id: "p21", label: "Smart Dim", icon: "\uf186" },
        { id: "p22", label: "Title Translator", icon: "\uf1ab" },
        { id: "p23", label: "Hyprbars", icon: "\uf2d0" },
        { id: "p24", label: "Game Detection", icon: "\uf11b" },
        { id: "p25", label: "Dock", icon: "\uf0ca" },
        { id: "p26", label: "Default Apps", icon: "\uf085" },
        { id: "p27", label: "App Float Rules", icon: "\uf2d2" },
        { id: "p28", label: "Desktop", icon: "\uf108" },
        { id: "p29", label: "User Management", icon: "\uf0c0" },
        { id: "p30", label: "Login Screen", icon: "\uf090" },
        { id: "p31", label: "Shell Look", icon: "\udb81\udd9c" },
        { id: "p32", label: "Cursor & Icons", icon: "\uf245" },
        { id: "p33", label: "Taskbar", icon: "\uf009" },
        // v8.0.0-alpha-hf185 — Panasonic Let's Note. Note the index: the
        // parallel hf179 branch had this at p33, but hf182 had already taken
        // p33 for Taskbar. navCatFor is POSITIONAL, so shipping both at p33
        // would have re-filed Taskbar into the wrong category and pointed its
        // loader at the wrong page. Panasonic is p34 here.
        { id: "p34", label: "Panasonic", icon: "\uf109" }
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf185 — DENSHO + HARDWARE LOOKUPS, GUARDED
    //
    // ZenDashboard had never touched DenshoService or PanasonicService. This
    // file is 190KB of bindings, where one unresolved singleton name costs the
    // whole Control Center rather than one label — so every lookup is
    // typeof-guarded and falls back to the existing Nerd Font glyphs.
    // ═══════════════════════════════════════════════════════════════════════
    function denshoKanjiFor(label) {
        if (typeof DenshoService === "undefined") return ""
        return DenshoService.navKanji(label) || ""
    }
    function denshoRomajiFor(label) {
        if (typeof DenshoService === "undefined") return ""
        return DenshoService.navRomaji(label) || ""
    }
    function denshoCatKanjiFor(key) {
        if (typeof DenshoService === "undefined") return ""
        return DenshoService.categoryKanji(key) || ""
    }
    readonly property bool denshoOn: (typeof DenshoService !== "undefined")
                                     && DenshoService.denshoMode
    // v8.0.0-alpha-hf186 — gate on pageVisible, not isPanasonic, so the dev
    // override can surface the page on non-Panasonic hardware. isPanasonic
    // stays pure hardware truth for everything else.
    readonly property bool panasonicPresent: (typeof PanasonicService !== "undefined")
                                             && PanasonicService.pageVisible


    // ═══════════════════════════════════════════════════════════
    // v7.0.0-beta.1-hf99zz — card contents, one Component per id.
    // The grid Loader picks by id, so adding a card = one component
    // + one id in PanelState.dashCardIds.
    // ═══════════════════════════════════════════════════════════
    // v7.0.0-beta.1-hf99zza: find a page by its nav label, so the profile card
    // opening "User Profile" can't drift when modules are added or removed.
    function pageIndexFor(label) {
        for (let i = 1; i < navItems.length; i++)
            if (navItems[i].label === label) return i
        return 0
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf129 — the order the GRID actually draws.
    //
    // Edit mode shows every card, hidden ones included but dimmed and marked,
    // because a card you can't see is a card you can't get back. Leave edit
    // mode and the hidden ones drop out; the packer closes the gap they leave
    // and the survivors reflow.
    //
    // A hidden card keeps its slot in PanelState.dashOrder and its span/height
    // in PanelState.dashCards, so un-hiding it lands it exactly where it was.
    // ═══════════════════════════════════════════════════════════════════════
    readonly property var gridOrder:
        editMode ? PanelState.dashOrder : PanelState.dashVisibleOrder()

    // v8.0.0-alpha-hf101: FIRST-FIT PACKING. A GridLayout auto-flow leaves a
    // hole whenever the next card doesn't fit the remaining columns. We place
    // each card ourselves into the first free slot that fits, so two half-width
    // cards sit shoulder-to-shoulder and no gaps open up.
    readonly property var placement: {
        const cols = PanelState.dashColumns
        const order = dash.gridOrder
        const rows = []                                   // rows[r][c] = taken?
        const out = []
        function ensure(r) { while (rows.length <= r) rows.push(new Array(cols).fill(false)) }
        for (let i = 0; i < order.length; i++) {
            const span = Math.min(cols, PanelState.dashSpan(order[i]))
            let placed = false
            for (let r = 0; !placed; r++) {
                ensure(r)
                for (let c = 0; c + span <= cols; c++) {
                    let free = true
                    for (let k = 0; k < span; k++) if (rows[r][c + k]) { free = false; break }
                    if (!free) continue
                    for (let k = 0; k < span; k++) rows[r][c + k] = true
                    out.push({ row: r, col: c, span: span })
                    placed = true
                    break
                }
            }
        }
        // Every card in a row takes that row's tallest height, so a row reads as
        // one band instead of a ragged staircase.
        const rowH = {}
        for (let i = 0; i < out.length; i++) {
            const h = PanelState.dashHeight(order[i])
            rowH[out[i].row] = Math.max(rowH[out[i].row] || 0, h)
        }
        for (let i = 0; i < out.length; i++) out[i].h = rowH[out[i].row]
        return out
    }

    function cardComponent(id) {
        if (id === "time")       return cmpTime
        if (id === "calendar")   return cmpCalendar
        if (id === "sysmon")     return cmpSysmon
        if (id === "clocks")     return cmpClocks
        if (id === "weather")    return cmpWeather
        if (id === "workspaces") return cmpWorkspaces
        if (id === "activewin")  return cmpActiveWin
        if (id === "workflow")   return cmpWorkflow
        if (id === "audio")      return cmpAudio
        return cmpUnknown
    }

    Component { id: cmpUnknown
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
             text: "?"; color: ThemeService.grey2 }
    }

    // ── TIME (its own card now) ──
    Component { id: cmpTime
        ColumnLayout {
            id: timeRoot
            spacing: 0
            // v8.0.0-alpha-hf124 — the face follows the card. It was a hard 100px,
            // so on a narrow card the Loader's clip sliced it down the middle.
            // `timeRoot.width` comes from the Loader (anchors.fill), never from
            // these children, so there's no binding loop.
            readonly property int face: Math.max(48, Math.min(100, Math.min(width, height - 26)))
            WavyAnalogClock {
                visible: WidgetsState.clockStyle === "analog"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: timeRoot.face; Layout.preferredHeight: timeRoot.face
                hours: dash.now.getHours(); minutes: dash.now.getMinutes()
                dayLabel: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][dash.now.getDay()] + " " + dash.now.getDate()
            }
            RowLayout {
                visible: WidgetsState.clockStyle !== "analog"
                Layout.fillWidth: true
                spacing: 6
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    Layout.fillWidth: true
                    text: WidgetsState.clockStyle === "stacked"
                          ? Qt.formatDateTime(dash.now, "HH") + "\n" + Qt.formatDateTime(dash.now, "mm")
                          : Qt.formatDateTime(dash.now, "HH:mm")
                    lineHeight: WidgetsState.clockStyle === "stacked" ? 0.82 : 1.0
                    color: ThemeService.fg; font.pixelSize: 46; font.bold: true
                    // hf124: shrink rather than spill
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: 18
                    font.family: WidgetsState.clockStyle === "mono" ? "JetBrainsMono Nerd Font" : WidgetsState.clockFont
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 8
                       text: Qt.formatDateTime(dash.now, "AP"); color: ThemeService.grey2
                       font.pixelSize: 12; font.family: WidgetsState.clockFont }
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: Qt.formatDateTime(dash.now, "dddd, d MMMM yyyy")
                color: ThemeService.grey1; font.pixelSize: 12; font.family: WidgetsState.clockFont
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── CALENDAR ──
    Component { id: cmpCalendar
        ColumnLayout {
            id: calRoot
            spacing: 4
            readonly property int _todayY: dash.now.getFullYear()
            readonly property int _todayM: dash.now.getMonth()
            readonly property int todayD: dash.now.getDate()
            property int _y: _todayY
            property int _m: _todayM
            readonly property bool _isThisMonth: _y === _todayY && _m === _todayM
            readonly property int _offset: new Date(_y, _m, 1).getDay()
            readonly property int _dim: new Date(_y, _m + 1, 0).getDate()
            function _shift(d) { let m = _m + d, y = _y
                                 while (m < 0) { m += 12; y -= 1 }
                                 while (m > 11) { m -= 12; y += 1 }
                                 _m = m; _y = y }

            RowLayout {
                Layout.fillWidth: true
                Rectangle { Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 6; color: "transparent"
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "\u2039"; color: ThemeService.grey1; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calRoot._shift(-1) } }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                       text: ["January","February","March","April","May","June","July","August","September","October","November","December"][calRoot._m] + " " + calRoot._y
                       color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                Rectangle { Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 6; color: "transparent"
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "\u203a"; color: ThemeService.grey1; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calRoot._shift(1) } }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 7; rowSpacing: 1; columnSpacing: 1
                Repeater {
                    model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                    delegate: Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         required property string modelData
                                     Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                                     text: modelData; color: ThemeService.grey2; font.pixelSize: 8; font.bold: true; font.family: Theme.fontFamily }
                }
                Repeater {
                    model: 42
                    delegate: Item {
                        id: dCell
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        readonly property int _n: index - calRoot._offset + 1
                        readonly property bool _ok: _n >= 1 && _n <= calRoot._dim
                        readonly property bool _today: _ok && calRoot._isThisMonth && _n === calRoot.todayD
                        Rectangle {
                            visible: dCell._ok
                            anchors.centerIn: parent
                            width: 18; height: 18; radius: 9; antialiasing: true
                            color: dCell._today ? ThemeService.blue : "transparent"
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: dCell._ok ? dCell._n : ""
                                   color: dCell._today ? ThemeService.bg0 : ThemeService.fg
                                   font.pixelSize: 9; font.family: Theme.fontFamily }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── WEATHER (now: temp + condition + hourly/7-day) ──
    // ── WEATHER (mirrors the desktop widget, hf132) ──
    //
    // "tas yun sa dashboard pre dapat ganito din sana detailed per hourly
    //  tas sa ibaba yun daily 7 days"
    //
    // The card had a header and an hourly strip. The desktop widget also carries
    // feels-like / humidity / wind, an "Updated" stamp, and the 7-day row. Those
    // are here now, in the same order, reading the same service.
    //
    // The card is user-resizable, so the sections appear as the height allows
    // rather than being clipped by the Loader. The thresholds are MEASURED, not
    // guessed — an offscreen QQuickView with the same children reports:
    //
    //     header + updated   70px content box
    //     + hourly strip    163px
    //     + 7-day row       248px
    //
    // so, with a little headroom for a taller font than the probe's:
    //
    //     >= 172px   hourly strip
    //     >= 262px   7-day row
    //
    // My first pass shipped 150 and 240, which clip by 13px and 8px.
    //
    // Note `Layout.fillHeight: false` on the header and the 7-day row. A NESTED
    // LAYOUT DEFAULTS TO fillHeight: true (a plain Item defaults to false), so
    // without those pins the header and the day cells both stretched to eat the
    // leftover space and the thresholds meant nothing. The `spring` Item at the
    // bottom is the only thing that should absorb slack.
    //
    // Default height went 190 → 300 (content box 272 ≥ 248). Anyone who has
    // already dragged the grip keeps their own height — dashCards only stores
    // cards you changed. Shrink it and the sections retire cleanly.
    Component { id: cmpWeather
        ColumnLayout {
            id: wxRoot
            spacing: 6

            readonly property bool showHourly: height >= 150   // hf165: was 172, show sooner
            readonly property bool showDaily:  height >= 234   // hf165: was 262, show sooner
            // A cell needs ~54px to hold "28°/24°" at 9px with its margins;
            // measured 56px each across a span-2 card, which fits. Below that,
            // drop days from the end rather than squeezing them illegibly.
            readonly property int  dayCount:
                Math.max(3, Math.min(7, Math.floor(width / 54)))

            // ── header: icon · temp · condition · location   |   stats ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false      // nested layouts default to TRUE
                spacing: 10
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: WeatherService.emojiIcon; font.pixelSize: 34 }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.temperature + "\u00b0"
                           color: WidgetsState.weatherAccentMode === "default" ? ThemeService.fg : WidgetsState.weatherAccent
                           font.pixelSize: 26; font.bold: true; font.family: WidgetsState.weatherFont }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.condition; color: ThemeService.grey1; font.pixelSize: 10; font.family: WidgetsState.weatherFont
                           elide: Text.ElideRight; Layout.fillWidth: true }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.locationName; color: ThemeService.grey2; font.pixelSize: 9; font.family: WidgetsState.weatherFont
                           elide: Text.ElideRight; Layout.fillWidth: true }
                }
                // hf132: feels-like / humidity / wind, right-aligned — the same
                // three the desktop widget shows.
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    spacing: 2
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         Layout.alignment: Qt.AlignRight; text: WeatherService.feelsLike + "\u00b0"
                           color: ThemeService.grey1; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.weatherFont }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         Layout.alignment: Qt.AlignRight; text: WeatherService.humidity + "%"
                           color: ThemeService.grey1; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.weatherFont }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         Layout.alignment: Qt.AlignRight
                           text: WeatherService.windSpeed + "km/h"
                           // The wind number is the one that decides "windy" —
                           // colour it when it crosses the threshold.
                           color: WeatherService.windy ? WeatherService.iconTint : ThemeService.grey1
                           font.pixelSize: 10; font.bold: true; font.family: WidgetsState.weatherFont }
                }
            }

            // ── updated stamp ──
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: WeatherService.lastUpdated !== ""
                Layout.fillWidth: true
                text: "Updated " + WeatherService.lastUpdated
                color: ThemeService.grey2; font.pixelSize: 8; font.family: WidgetsState.weatherFont
            }

            Rectangle { visible: wxRoot.showHourly; Layout.fillWidth: true
                        Layout.preferredHeight: 1; color: dash.cardBorder }

            // ── hourly ──
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: wxRoot.showHourly && WeatherService.hourly.length > 0
                text: "Hourly forecast"
                color: ThemeService.fg; font.pixelSize: 10; font.bold: true
                font.family: WidgetsState.weatherFont
            }
            Flickable {
                visible: wxRoot.showHourly && WeatherService.hourly.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                contentWidth: hrRow.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: hrRow
                    spacing: 12
                    Repeater {
                        model: WeatherService.hourly
                        delegate: Column {
                            required property var modelData
                            spacing: 1; width: 40
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp + "\u00b0"
                                   color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: WidgetsState.weatherFont }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.emoji; font.pixelSize: 15 }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.precip + "%"
                                   color: modelData.precip >= 50 ? WidgetsState.weatherAccent : ThemeService.alpha(WidgetsState.weatherAccent, 0.75)
                                   font.pixelSize: 8; font.bold: true; font.family: WidgetsState.weatherFont }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hour
                                   color: ThemeService.grey2; font.pixelSize: 8; font.family: WidgetsState.weatherFont }
                        }
                    }
                }
            }

            Rectangle { visible: wxRoot.showDaily; Layout.fillWidth: true
                        Layout.preferredHeight: 1; color: dash.cardBorder }

            // ── 7-day, Today first ──
            RowLayout {
                visible: wxRoot.showDaily
                Layout.fillWidth: true
                Layout.fillHeight: false      // nested layouts default to TRUE
                Layout.preferredHeight: 72
                spacing: 4

                Repeater {
                    model: {
                        const fc = WeatherService.forecast
                        if (!fc || fc.length === 0) return []
                        return fc.slice(0, wxRoot.dayCount)
                    }
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        antialiasing: true
                        // Today is the one you actually look at.
                        color: index === 0 ? ThemeService.alpha(WidgetsState.weatherAccent, 0.18)
                                           : LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.3 : 0.5)
                        border.width: 1
                        border.color: index === 0 ? ThemeService.alpha(WidgetsState.weatherAccent, 0.45)
                                                  : dash.cardBorder

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 6
                            spacing: 1
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.day || "?"
                                color: index === 0 ? ThemeService.fg : ThemeService.grey1
                                font.pixelSize: 9; font.bold: true; font.family: WidgetsState.weatherFont
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.emoji || "\u2601\ufe0f"
                                font.pixelSize: 16
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: (modelData.maxTemp !== undefined ? modelData.maxTemp : "--") + "\u00b0/"
                                    + (modelData.minTemp !== undefined ? modelData.minTemp : "--") + "\u00b0"
                                color: ThemeService.fg
                                font.pixelSize: 9; font.bold: true; font.family: WidgetsState.weatherFont
                            }
                        }
                    }
                }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: !WeatherService.forecast || WeatherService.forecast.length === 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Loading forecast\u2026"
                    color: ThemeService.grey2; font.pixelSize: 10; font.family: WidgetsState.weatherFont
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ── ACTIVE WINDOW ──
    Component { id: cmpActiveWin
        RowLayout {
            spacing: 10
            Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 8
                        color: ThemeService.alpha(ThemeService.blue, 0.2); antialiasing: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             anchors.centerIn: parent; text: "\uf2d0"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.blue } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: "Active Window"; color: ThemeService.grey1; font.pixelSize: 9; font.family: Theme.fontFamily }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.fillWidth: true; elide: Text.ElideRight; text: dash.activeWinTitle || "\u2014"
                       color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.fillWidth: true; elide: Text.ElideRight; text: dash.activeWinClass
                       color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily }
            }
        }
    }


    // ── SYSTEM MONITOR (mirrors the desktop widget design) ──
    Component { id: cmpSysmon
        ColumnLayout {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle { width: 3; height: 18; radius: 2; color: WidgetsState.sysmonAccentFor("#0a84ff") }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: "System Monitor"; color: ThemeService.fg; font.pixelSize: 13; font.bold: true; font.family: WidgetsState.sysmonFont }
                Item { Layout.fillWidth: true }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: SystemMonitorService.cpuName + "  \u00b7  " + SystemMonitorService.gpuName
                       color: ThemeService.grey2; font.pixelSize: 9; font.family: WidgetsState.sysmonFont
                       elide: Text.ElideRight; Layout.maximumWidth: 240 }
            }

            // PILLS
            RowLayout {
                visible: WidgetsState.sysmonStyle === "pills"
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 8
                Repeater {
                    model: dash.sysModel
                    delegate: Rectangle {
                        id: pill
                        required property var modelData
                        readonly property color _a: WidgetsState.sysmonAccentFor(modelData.accent)
                        // hf129: live readings, bound per-delegate. The delegate
                        // itself is now permanent — only these three re-evaluate.
                        readonly property int    _pct: dash.sysPct(pill.modelData.key)
                        readonly property string _s1:  dash.sysS1(pill.modelData.key)
                        readonly property string _s2:  dash.sysS2(pill.modelData.key)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumWidth: 150
                        Layout.alignment: Qt.AlignHCenter
                        radius: Math.min(width, height) / 2
                        antialiasing: true
                        color: WidgetsState.sysmonCardBg
                        border.width: 1; border.color: WidgetsState.sysmonCardLine
                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            spacing: 3
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter
                                        width: 28; height: 28; radius: 14; color: pill._a; antialiasing: true
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             anchors.centerIn: parent; text: pill.modelData.glyph
                                               font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#ffffff" } }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: pill.modelData.label
                                   color: pill._a; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.sysmonFont }

                            // v8.0.0-alpha-hf108: every pill keeps the SAME vertical
                            // rhythm — badge · label · value-slot · s1 · s2 · bar-slot.
                            // NET has no percentage, so it fills the value slot with its
                            // arrows and the bar slot with a spacer instead of collapsing
                            // (that's why it used to sit out of line with the others).
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                height: 30
                                Row {
                                    visible: pill._pct >= 0
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: pill._pct; color: pill._a; font.pixelSize: 24; font.bold: true; font.family: WidgetsState.sysmonFont }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.top: parent.top; text: "%"; color: pill._a; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.sysmonFont }
                                }
                                Column {
                                    visible: pill._pct < 0
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.horizontalCenter: parent.horizontalCenter; text: pill._s1
                                           color: pill._a; font.pixelSize: 11; font.bold: true; font.family: WidgetsState.sysmonFont }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.horizontalCenter: parent.horizontalCenter; text: pill._s2
                                           color: pill._a; font.pixelSize: 11; font.bold: true; font.family: WidgetsState.sysmonFont }
                                }
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 visible: pill._pct >= 0
                                   anchors.horizontalCenter: parent.horizontalCenter; text: pill._s1
                                   color: WidgetsState.sysmonCardText; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.sysmonFont }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 visible: pill._pct >= 0
                                   anchors.horizontalCenter: parent.horizontalCenter; text: pill._s2
                                   color: WidgetsState.sysmonCardSubText; font.pixelSize: 9; font.family: WidgetsState.sysmonFont }
                            // NET keeps the two text slots as blank space so the bar line
                            // below lands at exactly the same y as its neighbours.
                            Item { visible: pill._pct < 0; width: 1; height: 12 + 11 }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 10
                                height: 5
                                Rectangle { visible: pill._pct >= 0
                                            anchors.fill: parent; radius: 2.5
                                            color: WidgetsState.sysmonCardLine; antialiasing: true
                                            Rectangle { width: Math.max(parent.height, parent.width * Math.min(1, pill._pct / 100))
                                                        height: parent.height; radius: parent.radius; color: pill._a; antialiasing: true
                                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } } }
                                // NET: a thin accent rule keeps the slot visually filled
                                Rectangle { visible: pill._pct < 0
                                            anchors.centerIn: parent
                                            width: parent.width * 0.5; height: 2; radius: 1
                                            color: ThemeService.alpha(pill._a, 0.55); antialiasing: true }
                            }
                        }
                    }
                }
            }

            // CLASSIC
            ColumnLayout {
                visible: WidgetsState.sysmonStyle !== "pills"
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 6
                Repeater {
                    model: dash.sysModel
                    delegate: RowLayout {
                        id: bar
                        required property var modelData
                        // hf129: live reading, bound per-delegate (see sysModel).
                        readonly property int _pct: dash.sysPct(bar.modelData.key)
                        visible: bar._pct >= 0
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: bar.modelData.label; color: ThemeService.grey1; font.pixelSize: 11; font.family: WidgetsState.sysmonFont; Layout.preferredWidth: 48 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                                    color: ThemeService.alpha(ThemeService.fg, 0.12)
                                    Rectangle { width: parent.width * Math.max(0, Math.min(1, bar._pct / 100))
                                                height: parent.height; radius: parent.radius
                                                color: WidgetsState.sysmonAccentFor(bar.modelData.accent)
                                                Behavior on width { NumberAnimation { duration: 300 } } } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: bar._pct + "%"; color: ThemeService.fg; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── CLOCKS (one card per configured clock) ──
    Component { id: cmpClocks
        ColumnLayout {
            id: clocksRoot
            spacing: 8
            // v8.0.0-alpha-hf103: tap to expand into a scrollable hour strip,
            // same interaction as the weather card.
            property bool expanded: false
            TapHandler { onTapped: clocksRoot.expanded = !clocksRoot.expanded }
            RowLayout {
                Layout.fillWidth: true
                Rectangle { width: 3; height: 16; radius: 2; color: ThemeService.blue }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.fillWidth: true; Layout.leftMargin: 6; text: "Clocks"
                       color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: WidgetsState.clockFont }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: clocksRoot.expanded ? "\u25b4 tap to collapse" : "\u25be tap for hours"
                       color: ThemeService.grey2; font.pixelSize: 9; font.family: WidgetsState.clockFont }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 8
                Repeater {
                    model: WidgetsState.clocks
                    delegate: Rectangle {
                        id: ccard
                        required property var modelData
                        required property int index
                        readonly property string _style: WidgetsState.clockStyleFor(index)
                        readonly property var _t: WidgetsState.timeFor(index, dash.now)
                        visible: modelData.enabled !== false
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 10; antialiasing: true
                        // v8.0.0-alpha-hf124: a cell can never leak into its neighbour.
                        clip: true
                        color: LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.3 : 0.5)
                        border.width: 1; border.color: dash.cardBorder

                        // hf124 — six fillWidth cells in a 2-column card are ~60px
                        // wide. The face was pinned at 72, so the centred column
                        // hung 6px off each side and the card's Loader clip chopped
                        // it. Derive the face from the cell instead.
                        readonly property int face:
                            Math.max(26, Math.min(72, Math.min(width - 10, height - 30)))

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            spacing: 1
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 Layout.fillWidth: true
                                   horizontalAlignment: Text.AlignHCenter
                                   elide: Text.ElideRight
                                   text: ccard.index === 0 ? "Local" : WidgetsState.clockLabelFor(ccard.index)
                                   color: ThemeService.fg; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.clockFont }
                            WavyAnalogClock { visible: ccard._style === "analog"; Layout.alignment: Qt.AlignHCenter
                                              Layout.preferredWidth: ccard.face; Layout.preferredHeight: ccard.face
                                              hours: ccard._t.hours; minutes: ccard._t.minutes; dayLabel: "" }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 visible: ccard._style !== "analog"; Layout.fillWidth: true; Layout.topMargin: 4
                                   horizontalAlignment: Text.AlignHCenter
                                   text: { const pad = n => String(n).padStart(2, "0")
                                           const h = ccard._t.hours, m = ccard._t.minutes
                                           if (ccard.modelData.format24h === false) { const x = h === 0 ? 12 : (h > 12 ? h - 12 : h); return pad(x) + ":" + pad(m) }
                                           return pad(h) + ":" + pad(m) }
                                   color: ThemeService.fg; font.pixelSize: 24; font.bold: true
                                   fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11
                                   font.family: ccard._style === "mono" ? "JetBrainsMono Nerd Font" : WidgetsState.clockFont }
                        }
                    }
                }
            }

            // ── expanded: scrollable next-12-hours per clock ──
            Repeater {
                model: clocksRoot.expanded ? WidgetsState.clocks : 0
                delegate: ColumnLayout {
                    id: hrRoot
                    required property var modelData
                    required property int index
                    readonly property var _t: WidgetsState.timeFor(index, dash.now)
                    visible: modelData.enabled !== false
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: hrRoot.index === 0 ? "Local" : WidgetsState.clockLabelFor(hrRoot.index)
                           color: ThemeService.grey1; font.pixelSize: 9; font.family: WidgetsState.clockFont }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        contentWidth: hourRow.width
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        Row {
                            id: hourRow
                            spacing: 4
                            Repeater {
                                model: 12
                                delegate: Rectangle {
                                    id: hcell
                                    required property int index
                                    readonly property int _h: (hrRoot._t.hours + index) % 24
                                    readonly property bool _now: index === 0
                                    width: 40; height: 26; radius: 7
                                    antialiasing: true
                                    color: _now ? ThemeService.alpha(ThemeService.blue, 0.3) : ThemeService.alpha(ThemeService.fg, 0.06)
                                    border.width: 1; border.color: _now ? ThemeService.blue : "transparent"
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.centerIn: parent
                                           text: String(hcell._h).padStart(2, "0") + ":00"
                                           color: hcell._now ? ThemeService.fg : ThemeService.grey1
                                           font.pixelSize: 9; font.family: WidgetsState.clockFont }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── WORKSPACES ──
    Component { id: cmpWorkspaces
        ColumnLayout {
            spacing: 8
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: "Workspaces"; color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: 10
                    delegate: Rectangle {
                        id: wsc
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool isActive: {
                            if (!Hyprland.focusedMonitor) return wsId === 1
                            const ws = Hyprland.focusedMonitor.activeWorkspace
                            return ws ? ws.id === wsId : wsId === 1
                        }
                        width: 28; height: 28; radius: 8; antialiasing: true
                        color: isActive ? ThemeService.alpha(ThemeService.blue, 0.35) : ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1; border.color: isActive ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.1)
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             anchors.centerIn: parent; text: wsc.wsId; color: wsc.isActive ? ThemeService.fg : ThemeService.grey2
                               font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + wsc.wsId) }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── WORKFLOW / AUDIO (same components the panel uses) ──
    Component { id: cmpWorkflow
        ColumnLayout { WorkflowProfilePicker { Layout.fillWidth: true } Item { Layout.fillHeight: true } }
    }
    Component { id: cmpAudio
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: "\uf028"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                       color: ConnectivityService.audioMuted ? ThemeService.grey2 : ThemeService.blue
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ConnectivityService.toggleMute() } }
                // hf197 — boost range (0..300), zone-colored fill, tick at 100%
                ZenSlider { Layout.fillWidth: true; from: 0; to: ConnectivityService.maxVolume; stepSize: 1; tickAt: 100
                            accent: ConnectivityService.volumeColor(ConnectivityService.audioVolume)
                            value: ConnectivityService.audioVolume; onMoved: ConnectivityService.setVolume(value) }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: ConnectivityService.audioVolume + "%"
                       color: ConnectivityService.audioVolume > 100
                              ? ConnectivityService.volumeColor(ConnectivityService.audioVolume)
                              : ThemeService.fg
                       font.pixelSize: 10; font.family: Theme.fontFamily }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: "\uf130"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                       color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.purple }
                ZenSlider { Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; value: ConnectivityService.micVolume; onMoved: ConnectivityService.setMicVolume(value) }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: ConnectivityService.micVolume + "%"
                       color: ThemeService.fg; font.pixelSize: 10; font.family: Theme.fontFamily }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // v7.0.0-beta.1-hf99zx: QtQuick Controls default to a LIGHT palette
    // (black text, black placeholders) — unreadable on a dark shell, and
    // `palette` doesn't exist on a plain Item/Rectangle (qmllint: "palette is
    // used but it is not resolved"). A Controls `Pane` does have one, and it
    // propagates to every descendant control — including the settings pages.
    Pane {
        anchors.fill: parent
        padding: 0
        background: null

        // arrow keys / Home / End move the selected card while editing
        focus: dash.editMode
        Keys.onPressed: (e) => {
            if (!dash.editMode || dash.selectedIndex < 0) return
            if (e.key === Qt.Key_Left)  { dash.moveSelected("left");  e.accepted = true }
            else if (e.key === Qt.Key_Right) { dash.moveSelected("right"); e.accepted = true }
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Home)   { dash.moveSelected("up");   e.accepted = true }
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_End)  { dash.moveSelected("down"); e.accepted = true }
            else if (e.key === Qt.Key_Escape) { dash.selectedIndex = -1; e.accepted = true }
        }
        Shortcut { sequence: StandardKey.ZoomIn;  onActivated: PanelState.dashSetScale(PanelState.dashScale + 0.05) }
        Shortcut { sequence: StandardKey.ZoomOut; onActivated: PanelState.dashSetScale(PanelState.dashScale - 0.05) }
        Shortcut { sequence: "Ctrl+0";            onActivated: PanelState.dashSetScale(1.0) }

        palette.text: ThemeService.fg
        palette.windowText: ThemeService.fg
        palette.buttonText: ThemeService.fg
        palette.brightText: ThemeService.fg
        palette.placeholderText: ThemeService.grey2
        palette.base: ThemeService.alpha(ThemeService.bg2, 0.6)
        palette.window: ThemeService.bg0
        palette.button: ThemeService.alpha(ThemeService.bg2, 0.6)
        palette.highlight: ThemeService.blue
        palette.highlightedText: ThemeService.bg0
        palette.mid: ThemeService.grey2
        palette.dark: ThemeService.grey1

    // v8.0.0-alpha-hf105: scroll + scale surface.
    //
    // On a narrow (vertical) monitor the three columns simply don't fit —
    // 232 sidebar + 288 rail + a readable 420 main = ~980px minimum. Rather
    // than crush the layout, the content keeps its minimum size and the view
    // scrolls horizontally. The whole thing is also scaled by dashScale, so
    // you can shrink it to fit or blow it up on a 4K.
    Rectangle {
        id: dashSidebar
        // v8.0.0-alpha-hf127 — HOISTED OUT of dashFlick/contentRoot.
        //
        // It used to be the first child of the RowLayout inside `contentRoot`,
        // which carries `transform: Scale { xScale: uiScale }`. So the sidebar
        // was zoomed with the content, and it lived inside a Flickable whose
        // contentRoot can be taller than the viewport (minContentHeight = 560).
        // Both give you a sidebar that changes size and can run past the panel.
        //
        // The sidebar is chrome. It belongs to the window, not to the scrolled,
        // zoomable content. Anchored to the panel now: fixed width, exactly the
        // panel's height, never scaled, never scrolled, impossible to overflow.
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 14
        width: dash.sidebarWidth
        radius: dash.cardRadius
        color: dash.cardBg
        border.width: 1
        border.color: dash.cardBorder
        antialiasing: true
        // v8.0.0-alpha-hf126: the sidebar had no clip, so when its column's
        // fixed children (brand, divider, user card, button row) added up to
        // more than the available height, the bottom block was laid out past
        // the rectangle — and past the panel, since dashFlick's clip is
        // rectangular and doesn't follow the panel's rounded corner.
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // brand — doubles as the title bar (drag to move the window)
            //
            // ══ v8.0.0-alpha-hf129 — WHY THIS IS WRAPPED IN A PLAIN Item ══
            //
            // The bug: with the Dashboard page selected, the nav's selection
            // pill, the profile card and the four quick-action buttons ALL ran
            // past the sidebar's right border and got sliced by its `clip`.
            // Pick any other page and everything sat correctly inset. hf128
            // fixed the pill's own binding, so this was something else.
            //
            // The cause: the Edit button is `visible: currentPage === 0`. A
            // QQuickLayout skips invisible children, so on page 0 — and ONLY
            // page 0 — the brand RowLayout gained 28px of button + 10px of
            // spacing. That pushed its minimum width to
            //
            //     44 (badge) + 10 + 130 (unelided "Zen Control Center")
            //   + 10 + 28 (edit)  =  218px
            //
            // against a 204px content box (232 sidebar − 2×14 margins). A
            // single-column ColumnLayout sizes its column to the WIDEST child
            // minimum and then hands that width to every `fillWidth` child —
            // so one over-wide header dragged the pill, the profile card and
            // the button row 14px out with it.
            //
            // The fix is the idiom ZenSettings has used since v6.13
            // (ZenSettings.qml:387): put the header inside a plain Item and
            // anchor the RowLayout to it. An Item's Layout.minimumWidth is 0,
            // so the header can never widen the column again — no matter what
            // is added to it later.
            //
            // Belt and braces: the title now elides, the edit slot is reserved
            // on EVERY page (it just fades out), and the pencil moved onto the
            // version line where there was already room for it. Geometry is now
            // byte-identical across all 32 pages. Wala tayong babawasan — the
            // Edit button, the drag handle and the logo cycler all still work.
            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 44

                // Drag handle. Hoisted out of the RowLayout: it was a layout
                // child carrying `anchors.fill`, which QQuickLayout warns about
                // and lays out unpredictably. As a z:-1 sibling it covers the
                // whole header and still sits under the logo + edit hit areas.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: dash.maximized ? Qt.ArrowCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    enabled: !dash.maximized
                    drag.target: dash
                    drag.axis: Drag.XAndYAxis
                    drag.threshold: 6
                    // v8.0.0-alpha-hf113: on MOVEMENT, not on press.
                    onPositionChanged: if (drag.active) dash.hasBeenDragged = true
                }

            RowLayout {
                anchors.fill: parent
                spacing: 10

                // v8.0.0-alpha-hf103: brand mark — hex logo or the written 禅.
                // Click to switch; the choice persists in panel-state.json.
                // v8.0.0-alpha-hf106: the mark is the brand — make it read.
                // 44px badge, 34px glyph (was 34/20, smaller than the title).
                // Click cycles: colour → mono → 禅 → colour.
                Rectangle {
                    width: 44; height: 44; radius: 13
                    // v8.0.0-alpha-hf185 — Densho shows the written 禅 mark WITHOUT
                    // touching PanelState.dashLogoStyle, so turning Densho off brings
                    // the user's own choice straight back. Click-to-cycle still works
                    // and still persists.
                    readonly property bool _isKanji: PanelState.dashLogoStyle === "kanji"
                                                     || dash.denshoOn
                    // The colour mark carries its own palette, so give it a
                    // neutral plate instead of the blue tint.
                    color: PanelState.dashLogoStyle === "color"
                           ? LookService.surfaceColor(ThemeService.bg0, logoMa.containsMouse ? 0.55 : 0.35)
                           : (logoMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.35)
                                                   : ThemeService.alpha(ThemeService.blue, 0.22))
                    border.width: 1
                    border.color: PanelState.dashLogoStyle === "color"
                                  ? ThemeService.alpha(ThemeService.fg, 0.18)
                                  : ThemeService.alpha(ThemeService.blue, 0.5)
                    antialiasing: true
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Image {
                        id: logoImg
                        visible: !parent._isKanji && status === Image.Ready
                        anchors.centerIn: parent
                        width: 34; height: 34
                        source: Qt.resolvedUrl(PanelState.dashLogoStyle === "color"
                                               ? "assets/zen-logo-color.svg"
                                               : "assets/zen-logo.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true; antialiasing: true; asynchronous: true
                    }
                    // Fallback: if the SVG can't load (missing file, no QtSvg),
                    // the written mark is shown instead of an empty badge.
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        visible: parent._isKanji || logoImg.status !== Image.Ready
                        anchors.centerIn: parent
                        text: "禅"; color: ThemeService.blue; font.pixelSize: 22; font.bold: true
                    }

                    MouseArea {
                        id: logoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 450
                        ToolTip.text: PanelState.dashLogoStyle === "color" ? "Mono mark"
                                    : (PanelState.dashLogoStyle === "hex" ? "Written 禅 mark" : "Colour mark")
                        onClicked: {
                            const next = PanelState.dashLogoStyle === "color" ? "hex"
                                       : (PanelState.dashLogoStyle === "hex" ? "kanji" : "color")
                            PanelState.dashLogoStyle = next
                            PanelState.saveState()
                        }
                    }
                }
                ColumnLayout {
                    visible: !dash.narrow
                    spacing: 0
                    Layout.fillWidth: true
                    // hf129: an Item's minimum is 0, but a *layout's* minimum is
                    // computed from its children — and a Text with no `elide` is
                    // a Fixed-policy item whose minimum IS its implicit width.
                    // Say 0 out loud so nothing here can widen the sidebar.
                    Layout.minimumWidth: 0
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "Zen Control Center"; color: ThemeService.fg
                        font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily
                    }
                    Text {
                        // 制御中枢 — "control nerve-centre". Densho only. Own Text so the
                        // CJK face and the UI face never fight over one string's metrics.
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        visible: dash.denshoOn
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        text: "禅 · 制御中枢 · Seigyo Chūsū"
                        color: ThemeService.alpha(ThemeService.fg, 0.6)
                        font.pixelSize: 9; font.family: "Noto Sans CJK JP"
                    }
                    // hf129: the version line and the Edit button share a row.
                    // The pencil used to sit on the title line, where it cost
                    // 38px the title didn't have. Down here it eats into a
                    // string that has elided since the day it shipped.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 6
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: ZenVersion.version + " · " + LookService.current.name
                            color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily
                            elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                        }

                        // v7.0.0-beta.1-hf99zs: Edit (reorder) — Google Material Symbols
                        // hf129: the SLOT is always reserved (fade, don't collapse),
                        // so the header's geometry no longer changes with the page.
                        Item {
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                opacity: dash.currentPage === 0 ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: 130 } }
                                color: dash.editMode ? ThemeService.alpha(ThemeService.blue, 0.25)
                                                     : (editBtnMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.1) : "transparent")
                                antialiasing: true
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.centerIn: parent
                                    text: "edit"                       // Material Symbols ligature
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 14
                                    color: dash.editMode ? ThemeService.blue : ThemeService.grey1
                                }
                                MouseArea {
                                    id: editBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: dash.currentPage === 0
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 450
                                    ToolTip.text: dash.editMode ? "Done editing" : "Edit dashboard — reorder, resize, hide cards"
                                    onClicked: dash.editMode = !dash.editMode
                                }
                            }
                        }
                    }
                }
            }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dash.cardBorder }

            // nav (scrollable — there are 30+ modules)
            Flickable {
                id: navFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                // hf126: a ColumnLayout hands leftover space to fillHeight
                // children only after every fixed child has its minimum. Say
                // out loud that the nav may shrink to nothing — it scrolls —
                // so the bottom block is never the thing that gets pushed out.
                Layout.minimumHeight: 0
                Layout.preferredHeight: 0

                // v8.0.0-alpha-hf128 — pin the content item to the viewport.
                //
                // `contentWidth` was never set, and navCol used `width: parent.width`.
                // Inside a Flickable, `parent` is the contentItem — and with
                // contentWidth unset, the contentItem is NOT the viewport width. So
                // navCol sized itself from its own children, the `Layout.fillWidth`
                // selection pill grew past the column's 14px right margin, and it
                // sat flush against the sidebar's border: 13px of inset on the left,
                // 1px on the right.
                //
                // You only ever notice it on the selected row, because that's the
                // only row with a fill. ZenSettings' nav has done this correctly
                // since forever (ZenSettings.qml:530) — that's the row you sent as
                // the reference.
                contentWidth: navFlick.width
                contentHeight: navCol.implicitHeight
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // hf197 — "kapag tight yun screen ... hindi makikita pre".
                // The nav has scrolled since hf126, but with no scrollbar a
                // short window looked like the modules below the fold simply
                // don't exist. Same AlwaysOn-when-overflow policy dashFlick
                // has used since hf127 — thin 4px pill, hugging the right edge.
                ScrollBar.vertical: ScrollBar {
                    policy: navFlick.contentHeight > navFlick.height + 1
                            ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    width: 4
                }

                ColumnLayout {
                    id: navCol
                    width: navFlick.width
                    spacing: 2

                    // ── Dashboard — top-level, outside every group ──
                    ZenDashNavRow {
                        visible: !dash.narrow
                        Layout.fillWidth: true
                        label: dash.navItems[0].label
                        icon: dash.navItems[0].icon
                        kanji: dash.denshoKanjiFor(dash.navItems[0].label)     // hf185
                        romaji: dash.denshoRomajiFor(dash.navItems[0].label)   // hf185
                        selected: dash.currentPage === 0
                        tooltip: dash.navItems[0].label
                        onActivated: dash.currentPage = 0
                    }

                    // ── Collapsible category groups ──
                    Repeater {
                        model: dash.narrow ? [] : dash.navGroups

                        delegate: ColumnLayout {
                            id: navGroup
                            required property var modelData
                            required property int index

                            readonly property bool expanded: dash.navOpenGroup === navGroup.modelData.key
                            readonly property bool holdsCurrent: {
                                const it = navGroup.modelData.items
                                for (let i = 0; i < it.length; i++)
                                    if (it[i].idx === dash.currentPage) return true
                                return false
                            }
                            // hf129: the body's height is ARITHMETIC, not measured.
                            // That is what lets the rows live behind a Loader that
                            // only exists while the group is open — a closed group
                            // costs one Rectangle, not eleven delegates. With 31
                            // modules across six groups that is the difference
                            // between 31 nav rows built on every Control Center
                            // open and, typically, zero.
                            readonly property int rowH: 32
                            readonly property int rowGap: 2
                            readonly property int bodyH:
                                navGroup.modelData.items.length * rowH
                                + (navGroup.modelData.items.length - 1) * rowGap

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2

                            // ── header ──
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: navGroup.index === 0 ? 8 : 4
                                Layout.preferredHeight: 26
                                radius: 8
                                antialiasing: true
                                color: navGroupMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.06)
                                                                : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    // v8.0.0-alpha-hf185 — Densho category kanji, in its
                                    // OWN Text so it keeps the CJK face and does not inherit
                                    // the header's letterSpacing: 1, which pulls kanji apart
                                    // into two unrelated characters.
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        visible: text.length > 0
                                        text: dash.denshoCatKanjiFor(navGroup.modelData.key)
                                        font.family: "Noto Sans CJK JP"
                                        font.pixelSize: 10; font.bold: true
                                        color: (navGroup.expanded || navGroup.holdsCurrent)
                                               ? ThemeService.blue : ThemeService.grey2
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight
                                        text: navGroup.modelData.label
                                        color: (navGroup.expanded || navGroup.holdsCurrent)
                                               ? ThemeService.blue : ThemeService.grey2
                                        font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                                        font.family: Theme.fontFamily
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }
                                    // How many modules are folded away in here.
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        opacity: navGroup.expanded ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                        text: navGroup.modelData.items.length
                                        color: ThemeService.grey2
                                        font.pixelSize: 8; font.family: Theme.fontFamily
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf078"                      // chevron-down
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 8
                                        color: (navGroup.expanded || navGroup.holdsCurrent)
                                               ? ThemeService.blue : ThemeService.grey2
                                        rotation: navGroup.expanded ? 0 : -90
                                        Behavior on rotation { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                                    }
                                }

                                MouseArea {
                                    id: navGroupMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 550
                                    ToolTip.text: navGroup.expanded
                                                  ? ("Collapse " + navGroup.modelData.label)
                                                  : (navGroup.modelData.label + " \u00b7 " + navGroup.modelData.items.length + " modules")
                                    // One open group at a time; click the open one to close it.
                                    onClicked: dash.navOpenGroup = navGroup.expanded ? "" : navGroup.modelData.key
                                }
                            }

                            // ── body (animated reveal) ──
                            Item {
                                id: navGroupBody
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                clip: true

                                property real revealH: navGroup.expanded ? navGroup.bodyH : 0
                                Behavior on revealH { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

                                Layout.preferredHeight: revealH
                                // A ColumnLayout skips invisible children entirely,
                                // so a closed group contributes exactly 0px — no
                                // stray spacing, no rounding fuzz.
                                visible: revealH > 0.5
                                opacity: Math.min(1, revealH / Math.max(1, navGroup.bodyH))

                                Loader {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    active: navGroupBody.visible
                                    sourceComponent: navGroupRows
                                }

                                Component {
                                    id: navGroupRows
                                    Column {
                                        // The Loader hands down its width (it is
                                        // anchored left/right). WITHOUT this the
                                        // Column would size itself from its children
                                        // while the children bind to parent.width —
                                        // a binding loop, and rows of width 0.
                                        width: parent ? parent.width : 0
                                        spacing: navGroup.rowGap
                                        Repeater {
                                            model: navGroup.modelData.items
                                            delegate: ZenDashNavRow {
                                                required property var modelData
                                                width: parent.width
                                                indent: 6
                                                label: modelData.label
                                                icon: modelData.icon
                                                kanji: dash.denshoKanjiFor(modelData.label)     // hf185
                                                romaji: dash.denshoRomajiFor(modelData.label)   // hf185
                                                selected: dash.currentPage === modelData.idx
                                                tooltip: modelData.label + "  \u00b7  " + navGroup.modelData.label
                                                onActivated: dash.currentPage = modelData.idx
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── narrow sidebar (62px): flat icon list, no headers ──
                    Repeater {
                        model: dash.narrow ? dash.filteredNav : []
                        delegate: ZenDashNavRow {
                            required property var modelData
                            Layout.fillWidth: true
                            narrow: true
                            label: modelData.label
                            icon: modelData.icon
                            kanji: dash.denshoKanjiFor(modelData.label)     // hf185
                            romaji: dash.denshoRomajiFor(modelData.label)   // hf185
                            selected: dash.currentPage === modelData.idx
                            tooltip: modelData.label + (modelData.cat !== "dashboard"
                                     ? ("  \u00b7  " + (dash.navCategories[modelData.cat] || "")) : "")
                            onActivated: dash.currentPage = modelData.idx
                        }
                    }
                }
            }

            // ── PROFILE (bottom of the sidebar, per the mockup) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: 14
                color: profMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.15)
                                            : LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.35 : 0.6)
                border.width: 1; border.color: profMa.containsMouse ? ThemeService.blue : dash.cardBorder
                antialiasing: true

                // Click the profile → jump straight to the User Profile page.
                MouseArea {
                    id: profMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 450
                    ToolTip.text: "Open User Profile"
                    onClicked: dash.currentPage = dash.pageIndexFor("User Profile")
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: ThemeService.alpha(ThemeService.blue, 0.2)
                            clip: true; antialiasing: true
                            Image {
                                anchors.fill: parent
                                source: (typeof UserProfileService !== "undefined") ? UserProfileService.effectiveAvatarSource : ""
                                visible: source != ""
                                fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; visible: (typeof UserProfileService === "undefined") || UserProfileService.effectiveAvatarSource === ""
                                   text: "\uf007"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: ThemeService.blue }
                        }
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true; elide: Text.ElideRight
                                text: UserProfileService.userName + (UserProfileService.hostname ? "@" + UserProfileService.hostname : "")
                                color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily
                            }
                            RowLayout {
                                spacing: 5
                                Rectangle { width: 6; height: 6; radius: 3; color: ThemeService.green !== undefined ? ThemeService.green : "#30d158" }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "Online"; color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily }
                            }
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: UserProfileService.osName
                        color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily
                    }
                }
            }

            // ── v7.0.0-beta.1-hf99zy: quick actions ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [
                        { g: "dark_mode",   tip: "Toggle dark mode", act: "dark" },
                        { g: "desktop_windows", tip: "Displays",     act: "displays" },
                        { g: "settings",    tip: "General settings", act: "settings" },
                        { g: "power_settings_new", tip: "Lock screen", act: "lock" }
                    ]
                    delegate: Rectangle {
                        id: qaBtn
                        required property var modelData
                        // hf197 — the dark-mode button is now STATEFUL, like the
                        // Quick Settings tile: glyph flips moon/sun with
                        // DarkModeService.isDark and the tile gets an accent
                        // highlight while dark mode is on. The old delegate drew
                        // the static model glyph and only *called* toggle() — the
                        // state changed underneath but nothing on the button did.
                        readonly property bool isDarkBtn: modelData.act === "dark"
                        readonly property bool darkOn: isDarkBtn && DarkModeService.isDark
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 10
                        antialiasing: true
                        color: qaMa.containsMouse
                               ? (qaBtn.modelData.act === "lock" ? ThemeService.alpha(ThemeService.red, 0.2) : ThemeService.alpha(ThemeService.fg, 0.1))
                               : (qaBtn.darkOn
                                  ? ThemeService.alpha(ThemeService.blue, 0.22)
                                  : LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.3 : 0.5))
                        border.width: 1
                        border.color: qaBtn.darkOn
                                      ? ThemeService.alpha(ThemeService.blue, 0.5)
                                      : dash.cardBorder
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: qaBtn.isDarkBtn
                                  ? (DarkModeService.isDark ? "dark_mode" : "light_mode")
                                  : qaBtn.modelData.g
                            font.family: "Material Symbols Rounded"; font.pixelSize: 15
                            color: (qaMa.containsMouse && qaBtn.modelData.act === "lock")
                                   ? ThemeService.red
                                   : (qaBtn.darkOn ? ThemeService.blue : ThemeService.grey1)
                        }
                        MouseArea {
                            id: qaMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 400
                            ToolTip.text: qaBtn.isDarkBtn
                                          ? (DarkModeService.isDark ? "Switch to light mode" : "Switch to dark mode")
                                          : qaBtn.modelData.tip
                            onClicked: {
                                const a = qaBtn.modelData.act
                                if (a === "dark") DarkModeService.toggle()
                                else if (a === "displays") dash.currentPage = 5     // Displays
                                else if (a === "settings") dash.currentPage = 1     // General
                                else Quickshell.execDetached(["bash", "-c", "loginctl lock-session 2>/dev/null || hyprlock"])
                            }
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: dashFlick
        // hf127: everything right of the sidebar. The sidebar owns its own
        // 14px margins; this owns the rest.
        anchors.left: dashSidebar.right
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        clip: true
        contentWidth: contentRoot.width * dash.uiScale
        contentHeight: contentRoot.height * dash.uiScale
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.horizontal: ScrollBar {
            policy: dashFlick.contentWidth > dashFlick.width + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }
        ScrollBar.vertical: ScrollBar {
            policy: dashFlick.contentHeight > dashFlick.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        Item {
            id: contentRoot
            // never smaller than the layout actually needs
            width: Math.max(dash.minContentWidth, dashFlick.width / dash.uiScale)
            height: Math.max(dash.minContentHeight, dashFlick.height / dash.uiScale)
            transform: Scale { origin.x: 0; origin.y: 0; xScale: dash.uiScale; yScale: dash.uiScale }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 0     // hf127: dashFlick carries the margins now
        spacing: 12


        // ── MAIN AREA ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // hf198 — must match minContentWidth's main term (620). At 420
            // the RowLayout could squeeze this column below what a
            // SettingRow needs, and un-clipped children painted under the
            // right rail.
            Layout.minimumWidth: 620
            spacing: 10

            // v7.0.0-beta.1-hf99zu: search + window controls
            RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 1500
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 12
                    color: LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.35 : 0.6)
                    border.width: 1
                    border.color: searchField.activeFocus ? ThemeService.blue : dash.cardBorder
                    antialiasing: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 10
                        spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "search"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: ThemeService.grey1 }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Search modules…"
                            color: ThemeService.fg
                            placeholderTextColor: ThemeService.grey2
                            selectionColor: ThemeService.alpha(ThemeService.blue, 0.4)
                            selectedTextColor: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            background: null
                            onTextChanged: dash.searchText = text
                            onAccepted: {
                                if (dash.searchResults.length > 0) {
                                    dash.currentPage = dash.searchResults[0].idx
                                    text = ""
                                }
                            }
                        }
                        Rectangle {
                            visible: dash.searchText.length > 0
                            Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10
                            color: ThemeService.alpha(ThemeService.fg, 0.1)
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: "\uf00d"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: ThemeService.grey1 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchField.text = "" }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             visible: dash.searchText.length === 0; text: "Ctrl K"; color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily }
                    }
                }

                // v8.0.0-alpha-hf105: UI scale (shrink to fit a vertical monitor)
                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 30
                    radius: 9
                    color: LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.35 : 0.6)
                    border.width: 1; border.color: dash.cardBorder
                    antialiasing: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 0
                        Rectangle {
                            Layout.preferredWidth: 26; Layout.fillHeight: true; radius: 7
                            color: zoomOutMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: "remove"; font.family: "Material Symbols Rounded"; font.pixelSize: 13; color: ThemeService.grey1 }
                            MouseArea { id: zoomOutMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        ToolTip.visible: containsMouse; ToolTip.delay: 400; ToolTip.text: "Smaller"
                                        onClicked: PanelState.dashSetScale(PanelState.dashScale - 0.05) }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: dash.scaleClampedToFit ? ("Fit " + Math.round(dash.uiScale * 100) + "%")
                                                         : (Math.round(PanelState.dashScale * 100) + "%")
                            color: dash.scaleClampedToFit ? ThemeService.blue : ThemeService.grey1
                            font.pixelSize: 10; font.family: Theme.fontFamily
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        ToolTip.visible: containsMouse; ToolTip.delay: 400; ToolTip.text: "Reset to 100%"
                                        hoverEnabled: true
                                        onClicked: PanelState.dashSetScale(1.0) }
                        }
                        Rectangle {
                            Layout.preferredWidth: 26; Layout.fillHeight: true; radius: 7
                            color: zoomInMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: "add"; font.family: "Material Symbols Rounded"; font.pixelSize: 13; color: ThemeService.grey1 }
                            MouseArea { id: zoomInMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        ToolTip.visible: containsMouse; ToolTip.delay: 400; ToolTip.text: "Bigger"
                                        onClicked: PanelState.dashSetScale(PanelState.dashScale + 0.05) }
                        }
                    }
                }

                // window controls
                Repeater {
                    model: [
                        { g: "crop_square", act: "max" },
                        { g: "close",       act: "close" }
                    ]
                    delegate: Rectangle {
                        id: winBtn
                        required property var modelData
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                        antialiasing: true
                        color: winMa.containsMouse
                               ? (winBtn.modelData.act === "close" ? ThemeService.alpha(ThemeService.red, 0.25) : ThemeService.alpha(ThemeService.fg, 0.12))
                               : "transparent"
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: winBtn.modelData.g
                            font.family: "Material Symbols Rounded"; font.pixelSize: 15
                            color: (winMa.containsMouse && winBtn.modelData.act === "close") ? ThemeService.red : ThemeService.grey1
                        }
                        MouseArea {
                            id: winMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (winBtn.modelData.act === "close") PanelState.dashboardVisible = false
                                else dash.maximized = !dash.maximized
                            }
                        }
                    }
                }
            }

            // v7.0.0-beta.1-hf99zw: fuzzy search results — every matching page,
            // ranked, straight under the box (not just a sidebar filter).
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dash.searchResults.length > 0 ? (resCol.implicitHeight + 12) : 0
                visible: dash.searchResults.length > 0
                radius: 12
                color: LookService.surfaceColor(ThemeService.bg1, dash.glassLook ? 0.5 : 0.92)
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true

                ColumnLayout {
                    id: resCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: dash.searchResults
                        delegate: Rectangle {
                            id: resRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 8
                            antialiasing: true
                            color: resMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.18) : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: resRow.modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.blue }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     Layout.fillWidth: true; elide: Text.ElideRight; text: resRow.modelData.label
                                       color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: resRow.modelData.cat; color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily }
                            }
                            MouseArea {
                                id: resMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { dash.currentPage = resRow.modelData.idx; searchField.text = "" }
                            }
                        }
                    }
                }
            }

        StackLayout {
            // v8.0.0-alpha-hf104: on an ultrawide / maximized window the pages
            // and the grid used to stretch edge-to-edge, which wrecks the
            // proportions the design assumes. Cap the content and centre it.
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 1500
            Layout.alignment: Qt.AlignHCenter
            currentIndex: dash.currentPage

            // 0 — Dashboard
            //
            // v7.0.0-beta.1-hf99zz: model-driven GRID. Cards come from
            // PanelState.dashOrder, so reordering is just moving the model —
            // no code moves. Each card carries its own column span (1–2) and
            // height, both resizable in Edit mode by dragging the grip.
            Flickable {
                contentHeight: dashGrid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // hf129: hide every section and the dashboard is a blank page.
                // Say where the way back is instead of leaving a void.
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 320)
                    spacing: 8
                    visible: dash.gridOrder.length === 0
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        Layout.alignment: Qt.AlignHCenter
                        text: "visibility_off"
                        font.family: "Material Symbols Rounded"; font.pixelSize: 30
                        color: ThemeService.grey2
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Every section is hidden.\nOpen Edit \u2014 the pencil up top \u2014 and tap the eye on a card to bring it back."
                        color: ThemeService.grey2
                        font.pixelSize: 11; font.family: Theme.fontFamily
                    }
                }

                GridLayout {
                    id: dashGrid
                    width: parent.width
                    columns: PanelState.dashColumns
                    rowSpacing: 12
                    columnSpacing: 12
                    readonly property real colWidth: (width - (columns - 1) * columnSpacing) / columns

                    Repeater {
                        id: cardRepeater
                        model: dash.gridOrder            // hf129: hidden cards filtered out

                        delegate: Rectangle {
                            id: card
                            required property string modelData
                            required property int index

                            // hf129: only ever true while editMode is on — outside
                            // edit mode a hidden card is not in gridOrder at all.
                            readonly property bool cardHidden: PanelState.dashIsHidden(card.modelData)

                            readonly property var _pl: dash.placement[index] || ({ row: 0, col: 0, span: 2, h: 150 })
                            Layout.row: _pl.row
                            Layout.column: _pl.col
                            Layout.columnSpan: _pl.span
                            Layout.fillWidth: true
                            Layout.fillHeight: true          // no vertical gap inside a row
                            // v8.0.0-alpha-hf107: the ROW's height, not this card's,
                            // so neighbours line up exactly.
                            Layout.preferredHeight: _pl.h
                            Behavior on Layout.preferredHeight { enabled: !gripMa.pressed; NumberAnimation { duration: 140 } }

                            radius: dash.cardRadius
                            color: dash.cardBg
                            border.width: dragMa.pressed ? 2 : 1
                            border.color: dragMa.pressed ? ThemeService.blue : dash.cardBorder
                            antialiasing: true
                            z: dragMa.pressed ? 10 : (selected ? 5 : 0)
                            scale: dragMa.pressed ? 1.03 : 1.0
                            opacity: dragMa.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 110 } }

                            // v8.0.0-alpha-hf103: a GridLayout snaps items to their new
                            // slots instantly — that's the "matigas" feel. Animating x/y
                            // makes the whole grid glide, exactly like the desktop widgets.
                            // Skipped for the card you're holding, so it tracks the cursor.
                            Behavior on x { enabled: !dragMa.pressed; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: !dragMa.pressed; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                            Behavior on width  { enabled: !hGripMa.pressed && !cGripMa.pressed; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            readonly property bool selected: dash.selectedIndex === index

                            Loader {
                                anchors.fill: parent
                                anchors.margins: 14
                                clip: true
                                sourceComponent: dash.cardComponent(card.modelData)
                                // hf129: a hidden card is a ghost of itself while
                                // you're editing — obviously present, obviously off.
                                opacity: card.cardHidden ? 0.22 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }

                            // ── Edit-mode chrome ──────────────────────────
                            Rectangle {
                                visible: dash.editMode
                                anchors.fill: parent
                                radius: parent.radius
                                color: card.cardHidden
                                       ? ThemeService.alpha(ThemeService.fg, 0.05)
                                       : ThemeService.alpha(ThemeService.blue, dragMa.pressed ? 0.10 : 0.05)
                                border.width: card.selected ? 2 : 1
                                border.color: card.cardHidden
                                              ? ThemeService.alpha(ThemeService.fg, card.selected ? 0.55 : 0.28)
                                              : ThemeService.alpha(ThemeService.blue, card.selected ? 0.8 : 0.35)
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            // drag handle (top-left) — drag the card onto another to swap
                            Rectangle {
                                visible: dash.editMode
                                anchors.left: parent.left; anchors.top: parent.top
                                anchors.margins: 6
                                width: 26; height: 26; radius: 8
                                color: dragMa.pressed ? ThemeService.blue : LookService.surfaceColor(ThemeService.bg0, 0.7)
                                border.width: 1; border.color: dash.cardBorder
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: "drag_indicator"
                                       font.family: "Material Symbols Rounded"; font.pixelSize: 14
                                       color: dragMa.pressed ? ThemeService.bg0 : ThemeService.grey1 }
                                MouseArea {
                                    id: dragMa
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    // select this card so the arrow keys can move it
                                    onPressed: dash.selectedIndex = card.index
                                    // v7.0.0-beta.1-hf99zza: reorder live, but DON'T write the
                                    // state file per frame (that was the "matigas" drag). We also
                                    // require the pointer to be clearly inside the target card
                                    // (hysteresis) so cards don't ping-pong on the boundary.
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        const p = mapToItem(dashGrid, mouse.x, mouse.y)
                                        for (let i = 0; i < cardRepeater.count; i++) {
                                            if (i === card.index) continue
                                            const it = cardRepeater.itemAt(i)
                                            if (!it) continue
                                            const inset = 18
                                            if (p.x > it.x + inset && p.x < it.x + it.width - inset &&
                                                p.y > it.y + inset && p.y < it.y + it.height - inset) {
                                                PanelState.dashMove(card.index, i, false)   // no save yet
                                                break
                                            }
                                        }
                                    }
                                    onReleased: PanelState.saveState()                      // one write
                                }
                            }

                            // width badge (top-right) — shows the current span
                            Rectangle {
                                visible: dash.editMode
                                anchors.right: parent.right; anchors.top: parent.top
                                anchors.margins: 6
                                width: 34; height: 22; radius: 7
                                color: LookService.surfaceColor(ThemeService.bg0, 0.7)
                                border.width: 1; border.color: dash.cardBorder
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent
                                       text: PanelState.dashSpan(card.modelData) + "/" + PanelState.dashColumns
                                       color: ThemeService.grey1; font.pixelSize: 9; font.family: Theme.fontFamily }
                            }

                            // ── v8.0.0-alpha-hf129: HIDE / SHOW this card ──
                            //
                            // Sits just left of the span badge. Persists on the
                            // click (one small write, same as a span change) —
                            // hidden cards survive a shell restart. Un-hide from
                            // the same button; the card never leaves edit mode.
                            Rectangle {
                                visible: dash.editMode
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 6 + 34 + 6
                                anchors.topMargin: 6
                                width: 26; height: 22; radius: 7
                                color: eyeMa.containsMouse
                                       ? ThemeService.alpha(card.cardHidden ? ThemeService.blue : ThemeService.red, 0.25)
                                       : LookService.surfaceColor(ThemeService.bg0, 0.7)
                                border.width: 1
                                border.color: card.cardHidden ? ThemeService.alpha(ThemeService.fg, 0.30) : dash.cardBorder
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.centerIn: parent
                                    text: card.cardHidden ? "visibility_off" : "visibility"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: card.cardHidden ? ThemeService.grey2 : ThemeService.grey1
                                }
                                MouseArea {
                                    id: eyeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 400
                                    ToolTip.text: card.cardHidden
                                                  ? "Show this section on the dashboard"
                                                  : "Hide this section (stays here while editing)"
                                    onClicked: PanelState.dashToggleHidden(card.modelData)
                                }
                            }

                            // HORIZONTAL resize — drag the right edge, snaps to columns
                            Rectangle {
                                visible: dash.editMode
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10; height: 46; radius: 5
                                color: hGripMa.pressed ? ThemeService.blue : LookService.surfaceColor(ThemeService.bg0, 0.75)
                                border.width: 1; border.color: dash.cardBorder
                                MouseArea {
                                    id: hGripMa
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.SizeHorCursor
                                    property real startX: 0
                                    property int startSpan: 2
                                    onPressed: (mouse) => { startX = mapToItem(dashGrid, mouse.x, mouse.y).x
                                                            startSpan = PanelState.dashSpan(card.modelData) }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        const x = mapToItem(dashGrid, mouse.x, mouse.y).x
                                        const step = dashGrid.colWidth + dashGrid.columnSpacing
                                        const delta = Math.round((x - startX) / step)
                                        const want = Math.max(1, Math.min(PanelState.dashColumns, startSpan + delta))
                                        if (want !== PanelState.dashSpan(card.modelData))
                                            PanelState.dashSetCard(card.modelData, want, PanelState.dashHeight(card.modelData), false)
                                    }
                                    onReleased: PanelState.saveState()
                                }
                            }

                            // CORNER resize — width + height together
                            Rectangle {
                                visible: dash.editMode
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                anchors.margins: 26
                                width: 16; height: 16; radius: 4
                                color: cGripMa.pressed ? ThemeService.blue : LookService.surfaceColor(ThemeService.bg0, 0.75)
                                border.width: 1; border.color: dash.cardBorder
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: "open_in_full"
                                       font.family: "Material Symbols Rounded"; font.pixelSize: 10
                                       color: cGripMa.pressed ? ThemeService.bg0 : ThemeService.grey1 }
                                MouseArea {
                                    id: cGripMa
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.SizeFDiagCursor
                                    property real startX: 0
                                    property real startY: 0
                                    property int  startSpan: 2
                                    property real startH: 0
                                    onPressed: (mouse) => { const p = mapToItem(dashGrid, mouse.x, mouse.y)
                                                            startX = p.x; startY = p.y
                                                            startSpan = PanelState.dashSpan(card.modelData)
                                                            startH = PanelState.dashHeight(card.modelData) }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        const p = mapToItem(dashGrid, mouse.x, mouse.y)
                                        const step = dashGrid.colWidth + dashGrid.columnSpacing
                                        const want = Math.max(1, Math.min(PanelState.dashColumns, startSpan + Math.round((p.x - startX) / step)))
                                        PanelState.dashSetCard(card.modelData, want, startH + (p.y - startY), false)
                                    }
                                    onReleased: PanelState.saveState()
                                }
                            }

                            // resize grip (bottom-right) — drag to change height
                            Rectangle {
                                visible: dash.editMode
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                anchors.margins: 4
                                width: 22; height: 22; radius: 6
                                color: gripMa.pressed ? ThemeService.blue : LookService.surfaceColor(ThemeService.bg0, 0.7)
                                border.width: 1; border.color: dash.cardBorder
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: "height"
                                       font.family: "Material Symbols Rounded"; font.pixelSize: 12
                                       color: gripMa.pressed ? ThemeService.bg0 : ThemeService.grey1 }
                                MouseArea {
                                    id: gripMa
                                    anchors.fill: parent
                                    cursorShape: Qt.SizeVerCursor
                                    property real startY: 0
                                    property real startH: 0
                                    onPressed: (mouse) => { startY = mapToItem(dashGrid, mouse.x, mouse.y).y
                                                            startH = PanelState.dashHeight(card.modelData) }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        const y = mapToItem(dashGrid, mouse.x, mouse.y).y
                                        PanelState.dashSetCard(card.modelData,
                                                               PanelState.dashSpan(card.modelData),
                                                               startH + (y - startY), false)   // live, no write
                                    }
                                    onReleased: PanelState.saveState()                          // one write
                                }
                            }

                            // card label while editing
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                visible: dash.editMode
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: (PanelState.dashCardLabels[card.modelData] || card.modelData)
                                      + (card.cardHidden ? "  \u00b7  hidden" : "")   // hf129
                                color: ThemeService.alpha(ThemeService.fg, 0.6)
                                font.pixelSize: 9; font.family: Theme.fontFamily
                            }
                        }
                    }
                }
            }

            // 1..32 — the SAME settings pages the Settings window uses (merged)
            // v7.0.0-beta.1-hf99zza: LAZY pages. A StackLayout builds every child
            // eagerly — all 31 settings pages were constructed the moment the
            // dashboard opened (that's the stall). Each is a Loader now, created
            // asynchronously only when you actually navigate to it.
            Loader { active: dash.currentPage === 1; asynchronous: true; visible: active
                     source: active ? "GeneralPage.qml" : "" }
            Loader { active: dash.currentPage === 2; asynchronous: true; visible: active
                     source: active ? "DecorationPage.qml" : "" }
            Loader { active: dash.currentPage === 3; asynchronous: true; visible: active
                     source: active ? "AnimationsPage.qml" : "" }
            Loader { active: dash.currentPage === 4; asynchronous: true; visible: active
                     source: active ? "ThemesPage.qml" : "" }
            Loader { active: dash.currentPage === 5; asynchronous: true; visible: active
                     source: active ? "DisplaysPage.qml" : "" }
            Loader { active: dash.currentPage === 6; asynchronous: true; visible: active
                     source: active ? "InputPage.qml" : "" }
            Loader { active: dash.currentPage === 7; asynchronous: true; visible: active
                     source: active ? "PanelPage.qml" : "" }
            Loader { active: dash.currentPage === 8; asynchronous: true; visible: active
                     source: active ? "BarModulesPage.qml" : "" }
            Loader { active: dash.currentPage === 9; asynchronous: true; visible: active
                     source: active ? "SysRowPage.qml" : "" }
            Loader { active: dash.currentPage === 10; asynchronous: true; visible: active
                     source: active ? "HotCornersPage.qml" : "" }
            Loader { active: dash.currentPage === 11; asynchronous: true; visible: active
                     source: active ? "ConnectivityPage.qml" : "" }
            Loader { active: dash.currentPage === 12; asynchronous: true; visible: active
                     source: active ? "NotificationPage.qml" : "" }
            Loader { active: dash.currentPage === 13; asynchronous: true; visible: active
                     source: active ? "BatterySettingsPage.qml" : "" }
            Loader { active: dash.currentPage === 14; asynchronous: true; visible: active
                     source: active ? "UserProfilePage.qml" : "" }
            Loader { active: dash.currentPage === 15; asynchronous: true; visible: active
                     source: active ? "UpdatesPage.qml" : "" }
            Loader { active: dash.currentPage === 16; asynchronous: true; visible: active
                     source: active ? "WidgetsPage.qml" : "" }
            Loader { active: dash.currentPage === 17; asynchronous: true; visible: active
                     source: active ? "WallpaperPage.qml" : "" }
            Loader { active: dash.currentPage === 18; asynchronous: true; visible: active
                     source: active ? "FocusSpacesPage.qml" : "" }
            Loader { active: dash.currentPage === 19; asynchronous: true; visible: active
                     source: active ? "QuickNotesPage.qml" : "" }
            Loader { active: dash.currentPage === 20; asynchronous: true; visible: active
                     source: active ? "NetworkPulsePage.qml" : "" }
            Loader { active: dash.currentPage === 21; asynchronous: true; visible: active
                     source: active ? "SmartDimPage.qml" : "" }
            Loader { active: dash.currentPage === 22; asynchronous: true; visible: active
                     source: active ? "TitleTranslatorPage.qml" : "" }
            Loader { active: dash.currentPage === 23; asynchronous: true; visible: active
                     source: active ? "HyprbarsSettingsPage.qml" : "" }
            Loader { active: dash.currentPage === 24; asynchronous: true; visible: active
                     source: active ? "GamingPage.qml" : "" }
            Loader { active: dash.currentPage === 25; asynchronous: true; visible: active
                     source: active ? "DockPage.qml" : "" }
            Loader { active: dash.currentPage === 26; asynchronous: true; visible: active
                     source: active ? "DefaultAppsPage.qml" : "" }
            Loader { active: dash.currentPage === 27; asynchronous: true; visible: active
                     source: active ? "AppFloatRulesPage.qml" : "" }
            Loader { active: dash.currentPage === 28; asynchronous: true; visible: active
                     source: active ? "DesktopPage.qml" : "" }
            Loader { active: dash.currentPage === 29; asynchronous: true; visible: active
                     source: active ? "UserManagementPage.qml" : "" }
            Loader { active: dash.currentPage === 30; asynchronous: true; visible: active
                     source: active ? "SddmLoginPage.qml" : "" }
            Loader { active: dash.currentPage === 31; asynchronous: true; visible: active
                     source: active ? "ShellLookPage.qml" : "" }
            Loader { active: dash.currentPage === 32; asynchronous: true; visible: active
                     source: active ? "CursorPage.qml" : "" }
            Loader { active: dash.currentPage === 33; asynchronous: true; visible: active
                     source: active ? "TaskbarPage.qml" : "" }
            // v8.0.0-alpha-hf185 — Panasonic Let's Note
            Loader { active: dash.currentPage === 34; asynchronous: true; visible: active
                     source: active ? "PanasonicPage.qml" : "" }
        }
        }

        // ── RIGHT RAIL ─────────────────────────────────────────
        ColumnLayout {
            visible: !dash.compact
            Layout.preferredWidth: dash.railWidth
            Layout.minimumWidth: dash.railWidth
            Layout.maximumWidth: dash.railWidth
            Layout.fillHeight: true
            spacing: 12

            // quick toggles
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 172
                radius: dash.cardRadius
                color: dash.cardBg
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Quick Settings"; color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: [
                                { label: "Wi-Fi",     sub: ConnectivityService.wifiEnabled ? "On" : "Off", icon: "\uf1eb", on: ConnectivityService.wifiEnabled, act: "wifi" },
                                { label: "Bluetooth", sub: ConnectivityService.btPowered ? "On" : "Off",   icon: "\uf294", on: ConnectivityService.btPowered, act: "bt" },
                                { label: "Audio",     sub: ConnectivityService.audioMuted ? "Muted" : (ConnectivityService.audioVolume + "%"), icon: "\uf028", on: !ConnectivityService.audioMuted, act: "mute" },
                                { label: "Dark Mode", sub: DarkModeService.isDark ? "On" : "Off",          icon: "\uf186", on: DarkModeService.isDark, act: "dark" }
                            ]
                            delegate: Rectangle {
                                id: qTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                antialiasing: true
                                color: qTile.modelData.on ? ThemeService.alpha(ThemeService.blue, 0.28)
                                                          : LookService.surfaceColor(ThemeService.bg2, dash.glassLook ? 0.3 : 0.55)
                                border.width: 1
                                border.color: qTile.modelData.on ? ThemeService.alpha(ThemeService.blue, 0.55) : dash.cardBorder
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 8
                                    spacing: 8
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: qTile.modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                           color: qTile.modelData.on ? ThemeService.fg : ThemeService.grey1 }
                                    ColumnLayout {
                                        spacing: 0
                                        Layout.fillWidth: true
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             text: qTile.modelData.label; color: ThemeService.fg; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             text: qTile.modelData.sub; color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const a = qTile.modelData.act
                                        if (a === "wifi") ConnectivityService.toggleWifi()
                                        else if (a === "bt") ConnectivityService.toggleBluetooth()
                                        else if (a === "mute") ConnectivityService.toggleMute()
                                        else if (a === "dark") DarkModeService.toggle()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // power profile
            Rectangle {
                visible: PowerProfileService.available
                Layout.fillWidth: true
                Layout.preferredHeight: 108
                radius: dash.cardRadius
                color: dash.cardBg
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             Layout.fillWidth: true; text: "Power Profile"; color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: PowerProfileService.currentProfile; color: ThemeService.blue; font.pixelSize: 10; font.family: Theme.fontFamily }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        Repeater {
                            model: [
                                { id: "performance", label: "Performance", icon: "\uf0e7" },
                                { id: "balanced",    label: "Balanced",    icon: "\uf24e" },
                                { id: "power-saver", label: "Power Save",  icon: "\uf06c" }
                            ]
                            delegate: Rectangle {
                                id: ppTile
                                required property var modelData
                                readonly property bool isActive: PowerProfileService.currentProfile === modelData.id
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                antialiasing: true
                                color: isActive ? ThemeService.alpha(ThemeService.blue, 0.25) : LookService.surfaceColor(ThemeService.bg2, 0.5)
                                border.width: 1; border.color: isActive ? ThemeService.blue : dash.cardBorder

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         Layout.alignment: Qt.AlignHCenter; text: ppTile.modelData.icon; font.family: "JetBrainsMono Nerd Font"
                                           font.pixelSize: 13; color: ppTile.isActive ? ThemeService.blue : ThemeService.grey1 }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         Layout.alignment: Qt.AlignHCenter; text: ppTile.modelData.label; color: ppTile.isActive ? ThemeService.fg : ThemeService.grey2
                                           font.pixelSize: 9; font.family: Theme.fontFamily }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: PowerProfileService.setProfile(ppTile.modelData.id) }
                            }
                        }
                    }
                }
            }

            // ── v7.0.0-beta.1-hf99zy: Media Controls (MPRIS via playerctl) ──
            Rectangle {
                visible: MprisService.available
                Layout.fillWidth: true
                Layout.preferredHeight: 152
                radius: dash.cardRadius
                color: dash.cardBg
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "\uf001"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.green }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             Layout.fillWidth: true; text: "Media Controls"; color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: MprisService.playerName; color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.maximumWidth: 70; Layout.fillWidth: false }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 8
                            color: LookService.surfaceColor(ThemeService.bg2, 0.6); clip: true; antialiasing: true
                            Image {
                                anchors.fill: parent
                                source: MprisService.artUrl
                                visible: MprisService.artUrl !== ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; visible: MprisService.artUrl === ""
                                   text: "\uf001"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: ThemeService.grey2 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 Layout.fillWidth: true; elide: Text.ElideRight; text: MprisService.title || "Nothing playing"
                                   color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 Layout.fillWidth: true; elide: Text.ElideRight; text: MprisService.artist
                                   color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily }
                        }
                    }

                    // progress
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.14)
                            Rectangle {
                                width: parent.width * MprisService.progress
                                height: parent.height; radius: parent.radius
                                color: ThemeService.blue
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: MprisService.positionText; color: ThemeService.grey2; font.pixelSize: 8; font.family: Theme.fontFamily }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: MprisService.lengthText; color: ThemeService.grey2; font.pixelSize: 8; font.family: Theme.fontFamily }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14
                        Repeater {
                            model: [
                                { g: "skip_previous", act: "prev", big: false },
                                { g: MprisService.playing ? "pause" : "play_arrow", act: "toggle", big: true },
                                { g: "skip_next",     act: "next", big: false }
                            ]
                            delegate: Rectangle {
                                id: mBtn
                                required property var modelData
                                Layout.preferredWidth: mBtn.modelData.big ? 34 : 28
                                Layout.preferredHeight: mBtn.modelData.big ? 34 : 28
                                radius: width / 2
                                antialiasing: true
                                color: mBtn.modelData.big ? ThemeService.blue
                                                          : (mMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent")
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.centerIn: parent
                                    text: mBtn.modelData.g
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: mBtn.modelData.big ? 18 : 15
                                    color: mBtn.modelData.big ? ThemeService.bg0 : ThemeService.grey1
                                }
                                MouseArea {
                                    id: mMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const a = mBtn.modelData.act
                                        if (a === "toggle") MprisService.playPause()
                                        else if (a === "next") MprisService.next()
                                        else MprisService.previous()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Active window ──
            Rectangle {
                visible: dash.activeWinTitle !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: dash.cardRadius
                color: dash.cardBg
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10
                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: ThemeService.alpha(ThemeService.blue, 0.2); antialiasing: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             anchors.centerIn: parent; text: "\uf2d0"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.blue }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "Active Window"; color: ThemeService.grey1; font.pixelSize: 9; font.family: Theme.fontFamily }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             Layout.fillWidth: true; Layout.maximumWidth: 200; elide: Text.ElideRight; text: dash.activeWinTitle
                               color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             Layout.fillWidth: true; Layout.maximumWidth: 200; elide: Text.ElideRight; text: dash.activeWinClass
                               color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily }
                    }
                }
            }

            // v7.0.0-beta.1-hf99zw: the classic Quick Settings "expand" panel,
            // brought over: Wi-Fi networks, Bluetooth devices, Audio, Notifs.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                radius: dash.cardRadius
                color: dash.cardBg
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // tab bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: [
                                { id: "wifi",  icon: "\uf1eb" },
                                { id: "bt",    icon: "\uf294" },
                                { id: "audio", icon: "\uf028" },
                                { id: "notif", icon: "\uf0f3" }
                            ]
                            delegate: Rectangle {
                                id: qsTab
                                required property var modelData
                                readonly property bool sel: dash.railTab === qsTab.modelData.id
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: 8
                                antialiasing: true
                                color: sel ? ThemeService.alpha(ThemeService.blue, 0.25)
                                           : (qsTabMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent")
                                border.width: 1; border.color: sel ? ThemeService.blue : "transparent"
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: qsTab.modelData.icon
                                       font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                       color: qsTab.sel ? ThemeService.blue : ThemeService.grey1 }
                                MouseArea { id: qsTabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: dash.railTab = qsTab.modelData.id }
                            }
                        }
                    }

                    // ── Wi-Fi ──
                    Flickable {
                        visible: dash.railTab === "wifi"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: wifiCol.implicitHeight; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: wifiCol
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     // v8.0.0-alpha-hf185 — wifiStatusText covers off /
                                     // connecting / connected+SSID+signal / needs-password.
                                     Layout.fillWidth: true; elide: Text.ElideRight
                                     text: ConnectivityService.wifiStatusText
                                       color: ConnectivityService.wifiConnected ? ThemeService.green : ThemeService.grey1
                                       font.pixelSize: 10; font.family: Theme.fontFamily
                                       font.bold: ConnectivityService.wifiConnected }
                                Rectangle {
                                    Layout.preferredWidth: 48; Layout.preferredHeight: 22; radius: 7
                                    color: ThemeService.alpha(ThemeService.fg, 0.08); border.width: 1; border.color: dash.cardBorder
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.centerIn: parent; text: "Scan"; color: ThemeService.grey1; font.pixelSize: 9; font.family: Theme.fontFamily }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ConnectivityService.scanWifi() }
                                }
                                // ── v8.0.0-alpha-hf195 — the full GTK selector ──
                                // The rail is deliberately a summary: pick a network,
                                // see state, done. Anything past that — hidden SSIDs,
                                // a profile that needs editing, a password that has to
                                // be retyped — belongs in a real window, and Paul
                                // already wrote one. Same launcher as the bar icon.
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 22; radius: 7
                                    color: wsMa.containsMouse
                                           ? ThemeService.alpha(ThemeService.blue, 0.28)
                                           : ThemeService.alpha(ThemeService.fg, 0.08)
                                    border.width: 1; border.color: dash.cardBorder
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf0c9"          // hamburger — "more, elsewhere"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: ThemeService.grey1
                                    }
                                    MouseArea {
                                        id: wsMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConnectivityService.openWifiSelector()
                                        ToolTip.visible: containsMouse
                                        ToolTip.delay: 400
                                        ToolTip.text: "Open the full Wi-Fi selector"
                                    }
                                }
                            }
                            Repeater {
                                // v8.0.0-alpha-hf185 — the network you are ON sorts to the
                                // top, so it is the first row rather than the ninth.
                                model: {
                                    const list = (ConnectivityService.wifiNetworks || []).slice()
                                    list.sort(function(a, b) {
                                        const aa = ConnectivityService.isConnectedTo(a.ssid) ? 1 : 0
                                        const bb = ConnectivityService.isConnectedTo(b.ssid) ? 1 : 0
                                        if (aa !== bb) return bb - aa
                                        return (b.signal || 0) - (a.signal || 0)
                                    })
                                    return list
                                }
                                delegate: Rectangle {
                                    id: wRow
                                    required property var modelData
                                    // v8.0.0-alpha-hf183 — this rail row used to be a silent
                                    // click that fired connectWifi with no button, no state,
                                    // no way to disconnect or forget. Paul couldn't tell it
                                    // was clickable. It's an expander now: tap to open an
                                    // action row with explicit Connect / Disconnect / Forget.
                                    // v8.0.0-alpha-hf185 — routed through the shared
                                    // predicate so the rail, the Control Center tab and the
                                    // bar glyph can never disagree. The model flag is kept
                                    // as a belt-and-braces OR.
                                    readonly property bool isActive: wRow.modelData.active === true
                                                                     || ConnectivityService.isConnectedTo(wRow.modelData.ssid)
                                    readonly property bool isBusy: ConnectivityService.isBusyOn(wRow.modelData.ssid)
                                    readonly property bool isSaved: (ConnectivityService.savedWifiNetworks || [])
                                                                    .indexOf(wRow.modelData.ssid) !== -1
                                    property bool expanded: false
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: expanded ? 62 : 30
                                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    radius: 7
                                    clip: true
                                    color: wRow.isActive ? ThemeService.alpha(ThemeService.green, 0.14)
                                           : (wMa.containsMouse || expanded ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent")
                                    border.width: wRow.isActive ? 1 : 0          // hf185
                                    border.color: wRow.isActive ? ThemeService.alpha(ThemeService.green, 0.45) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 30
                                            Layout.leftMargin: 8; Layout.rightMargin: 8; spacing: 6
                                            Text {
                                                style: LookService.isClear ? Text.Outline : Text.Normal
                                                styleColor: LookService.clearTextOutline
                                                text: wRow.isActive ? "\uf00c" : (wRow.isBusy ? "\uf021" : "\uf1eb")
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                                                color: wRow.isActive ? ThemeService.green
                                                       : (wRow.isBusy ? ThemeService.blue : ThemeService.grey2) }
                                            Text {
                                                style: LookService.isClear ? Text.Outline : Text.Normal
                                                styleColor: LookService.clearTextOutline
                                                Layout.fillWidth: true; elide: Text.ElideRight; text: wRow.modelData.ssid
                                                font.bold: wRow.isActive                     // hf185
                                                color: ThemeService.fg; font.pixelSize: 10; font.family: Theme.fontFamily }
                                            Text {
                                                visible: wRow.modelData.security && wRow.modelData.security.length > 0
                                                style: LookService.isClear ? Text.Outline : Text.Normal
                                                styleColor: LookService.clearTextOutline
                                                text: "\uf023"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: ThemeService.grey2 }
                                            // v8.0.0-alpha-hf185 — a green check alone is easy
                                            // to misread as "saved". The word is not.
                                            Rectangle {
                                                visible: wRow.isActive || wRow.isBusy
                                                Layout.preferredWidth: pillTxt.implicitWidth + 12
                                                Layout.preferredHeight: 16
                                                radius: 8
                                                color: wRow.isActive ? ThemeService.alpha(ThemeService.green, 0.22)
                                                                     : ThemeService.alpha(ThemeService.blue, 0.22)
                                                Text {
                                                    id: pillTxt
                                                    anchors.centerIn: parent
                                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                                    styleColor: LookService.clearTextOutline
                                                    text: wRow.isActive ? "Connected"
                                                                        : ConnectivityService.wifiBusyVerb + "\u2026"
                                                    font.pixelSize: 8; font.bold: true; font.family: Theme.fontFamily
                                                    color: wRow.isActive ? ThemeService.green : ThemeService.blue
                                                }
                                            }
                                            // One SSID carried by more than one radio: the
                                            // duplicate row is folded away, but the second
                                            // radio is not hidden.
                                            Text {
                                                visible: (wRow.modelData.bssCount || 1) > 1
                                                style: LookService.isClear ? Text.Outline : Text.Normal
                                                styleColor: LookService.clearTextOutline
                                                text: (wRow.modelData.bssCount || 1) + " AP"
                                                color: ThemeService.grey2; font.pixelSize: 8; font.family: Theme.fontFamily }
                                            Text {
                                                style: LookService.isClear ? Text.Outline : Text.Normal
                                                styleColor: LookService.clearTextOutline
                                                text: (wRow.modelData.signal || 0) + "%"
                                                color: wRow.isActive ? ThemeService.green : ThemeService.grey2
                                                font.pixelSize: 9; font.family: Theme.fontFamily }
                                        }

                                        // Action row — only when expanded
                                        RowLayout {
                                            Layout.fillWidth: true; Layout.preferredHeight: 30
                                            Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 2; spacing: 6
                                            visible: wRow.expanded

                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 6
                                                color: cMa.containsMouse
                                                       ? ThemeService.alpha(wRow.isActive ? ThemeService.yellow : ThemeService.green, 0.22)
                                                       : ThemeService.alpha(wRow.isActive ? ThemeService.yellow : ThemeService.green, 0.12)
                                                Text {
                                                    anchors.centerIn: parent
                                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                                    styleColor: LookService.clearTextOutline
                                                    text: wRow.isActive ? "Disconnect" : "Connect"
                                                    color: wRow.isActive ? ThemeService.yellow : ThemeService.green
                                                    font.pixelSize: 10; font.family: Theme.fontFamily; font.weight: Font.DemiBold }
                                                MouseArea {
                                                    id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    enabled: !wRow.isBusy                    // hf185
                                                    onClicked: {
                                                        if (wRow.isActive) ConnectivityService.disconnectWifi()
                                                        else ConnectivityService.connectWifi(wRow.modelData.ssid, wRow.modelData.security)
                                                        wRow.expanded = false
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                visible: wRow.isSaved
                                                Layout.preferredWidth: 74; Layout.preferredHeight: 26; radius: 6
                                                color: fMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.22) : ThemeService.alpha(ThemeService.red, 0.10)
                                                Text {
                                                    anchors.centerIn: parent
                                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                                    styleColor: LookService.clearTextOutline
                                                    text: "Forget"; color: ThemeService.red
                                                    font.pixelSize: 10; font.family: Theme.fontFamily; font.weight: Font.DemiBold }
                                                MouseArea {
                                                    id: fMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: { ConnectivityService.forgetWifi(wRow.modelData.ssid); wRow.expanded = false }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        // ══ v8.0.0-alpha-hf187 — THE CONNECT BUTTON WAS
                                        //    NOT CLICKABLE ══
                                        //
                                        // This was `anchors.fill: parent` AND `height: 30`
                                        // together. anchors.fill sets width AND height, so
                                        // the explicit height conflicts and loses — QML
                                        // logs "Cannot specify height for items anchored
                                        // with fill" and the anchor wins. The comment said
                                        // "only the top 30px toggles"; the code covered all
                                        // 62px of the expanded row.
                                        //
                                        // And this MouseArea is the LAST child of wRow, so
                                        // it sits above the ColumnLayout in z-order and got
                                        // every click first. Tapping Connect never reached
                                        // cMa — it hit this, which just collapsed the
                                        // expander. The button looked dead because it was.
                                        //
                                        // Anchored to the header strip only now, so the
                                        // action row's own MouseAreas get their clicks.
                                        id: wMa
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        height: 30
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wRow.expanded = !wRow.expanded
                                    }
                                }
                            }
                        }
                    }

                    // ── Bluetooth ──
                    Flickable {
                        visible: dash.railTab === "bt"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: btCol.implicitHeight; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: btCol
                            width: parent.width
                            spacing: 4
                            // ── v8.0.0-alpha-hf192 — header row: live count + open ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    // "0 device(s)" is not wrong, but it is also not useful.
                                    // Say what is connected when something is; say the count
                                    // only when it is worth counting.
                                    text: {
                                        if (!ConnectivityService.btPowered) return "Bluetooth is off"
                                        const list = ConnectivityService.btDevices || []
                                        const conn = list.filter(function(d) { return d.connected })
                                        if (conn.length === 1) return conn[0].name
                                        if (conn.length > 1) return conn.length + " connected"
                                        if (list.length > 0) return list.length + " paired · none connected"
                                        return "No devices paired"
                                    }
                                    color: {
                                        if (!ConnectivityService.btPowered) return ThemeService.grey1
                                        const conn = (ConnectivityService.btDevices || [])
                                                     .filter(function(d) { return d.connected })
                                        return conn.length > 0 ? ThemeService.blue : ThemeService.grey1
                                    }
                                    font.pixelSize: 10; font.family: Theme.fontFamily
                                }
                                // Opens the system Bluetooth manager, and closes it on a
                                // second click — the same toggle Paul's bluetoothrun.sh does.
                                Rectangle {
                                    Layout.preferredWidth: 54; Layout.preferredHeight: 20
                                    radius: 6
                                    color: btOpenMa.containsMouse
                                           ? ThemeService.alpha(ThemeService.blue, 0.28)
                                           : ThemeService.alpha(ThemeService.fg, 0.10)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "Manage"
                                        font.pixelSize: 8; font.bold: true; font.family: Theme.fontFamily
                                        color: ThemeService.fg
                                    }
                                    MouseArea {
                                        id: btOpenMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConnectivityService.openBluetoothManager()
                                    }
                                }
                            }
                            Repeater {
                                model: ConnectivityService.btDevices
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: "\uf294"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: ThemeService.blue }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.name
                                           color: ThemeService.fg; font.pixelSize: 10; font.family: Theme.fontFamily }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: modelData.connected ? "connected" : ""; color: ThemeService.grey2; font.pixelSize: 9; font.family: Theme.fontFamily }
                                }
                            }
                        }
                    }

                    // ── Audio ──
                    ColumnLayout {
                        visible: dash.railTab === "audio"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 8
                        // hf197 — sink name doubles as the device dropdown trigger
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: ConnectivityService.audioSinkName
                                   + (ConnectivityService.audioSinks.length > 1
                                      ? (railSinkList.expanded ? "  \uf077" : "  \uf078") : "")
                             color: railSinkMa.containsMouse ? ThemeService.blue : ThemeService.grey1
                             font.pixelSize: 10; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true
                             MouseArea { id: railSinkMa; anchors.fill: parent; hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: railSinkList.expanded = !railSinkList.expanded } }
                        ColumnLayout {
                            id: railSinkList
                            property bool expanded: false
                            visible: expanded && ConnectivityService.audioSinks.length > 0
                            Layout.fillWidth: true; spacing: 2
                            Repeater {
                                model: railSinkList.expanded ? ConnectivityService.audioSinks : []
                                delegate: Rectangle {
                                    id: railSinkRow
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 24; radius: 6
                                    color: railSinkRowMa.containsMouse
                                           ? ThemeService.alpha(ThemeService.blue, 0.15)
                                           : (railSinkRow.modelData.isDefault
                                              ? ThemeService.alpha(ThemeService.blue, 0.08) : "transparent")
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: railSinkRow.modelData.isDefault ? "\uf192" : "\uf10c"
                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                                            color: railSinkRow.modelData.isDefault ? ThemeService.blue : ThemeService.grey2 }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: railSinkRow.modelData.name
                                            font.family: Theme.fontFamily; font.pixelSize: 9
                                            color: railSinkRow.modelData.isDefault ? ThemeService.fg : ThemeService.grey0
                                            elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                    MouseArea { id: railSinkRowMa; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { ConnectivityService.setDefaultSink(railSinkRow.modelData.id)
                                                             railSinkList.expanded = false } }
                                }
                            }
                        }
                        ZenSlider { Layout.fillWidth: true; from: 0; to: ConnectivityService.maxVolume; stepSize: 1; tickAt: 100
                                    accent: ConnectivityService.volumeColor(ConnectivityService.audioVolume)
                                    value: ConnectivityService.audioVolume; onMoved: ConnectivityService.setVolume(value) }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: ConnectivityService.micSourceName; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                        ZenSlider { Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; value: ConnectivityService.micVolume; onMoved: ConnectivityService.setMicVolume(value) }

                        // ── v8.0.0-alpha-hf192 — the same escape hatch as Bluetooth ──
                        // Two sliders cover the common case; everything else —
                        // per-app routing, profiles, DSP — lives in the real tools.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 6
                            Repeater {
                                model: [
                                    { label: "Mixer",       act: "mixer" },
                                    { label: "EasyEffects", act: "fx" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    radius: 6
                                    color: aMa.containsMouse
                                           ? ThemeService.alpha(ThemeService.blue, 0.28)
                                           : ThemeService.alpha(ThemeService.fg, 0.10)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: parent.modelData.label
                                        font.pixelSize: 8; font.bold: true; font.family: Theme.fontFamily
                                        color: ThemeService.fg
                                    }
                                    MouseArea {
                                        id: aMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (parent.modelData.act === "mixer")
                                                ConnectivityService.openAudioManager()
                                            else
                                                ConnectivityService.openEasyEffects()
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // ── Notifications ──
                    Flickable {
                        visible: dash.railTab === "notif"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: nCol.implicitHeight; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: nCol
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     Layout.fillWidth: true; text: NotificationService.notifications.length > 0
                                       ? (NotificationService.notifications.length + " notification(s)") : "You're all caught up"
                                       color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily }
                                Rectangle {
                                    visible: NotificationService.notifications.length > 0
                                    Layout.preferredWidth: 50; Layout.preferredHeight: 22; radius: 7
                                    color: ThemeService.alpha(ThemeService.fg, 0.08); border.width: 1; border.color: dash.cardBorder
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.centerIn: parent; text: "Clear"; color: ThemeService.grey1; font.pixelSize: 9; font.family: Theme.fontFamily }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.clearAll() }
                                }
                            }
                            Repeater {
                                model: NotificationService.notifications
                                delegate: Rectangle {
                                    id: nRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: nInner.implicitHeight + 10
                                    radius: 7
                                    color: LookService.surfaceColor(ThemeService.bg2, 0.5)
                                    ColumnLayout {
                                        id: nInner
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8; anchors.rightMargin: 8
                                        spacing: 1
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             text: (nRow.modelData && nRow.modelData.appName) || "Notification"; color: ThemeService.blue; font.pixelSize: 9; font.bold: true; font.family: Theme.fontFamily }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             Layout.fillWidth: true; elide: Text.ElideRight; text: (nRow.modelData && nRow.modelData.summary) || ""
                                               color: ThemeService.fg; font.pixelSize: 10; font.family: Theme.fontFamily }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // uptime
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: dash.cardRadius
                color: dash.cardBg
                border.width: 1; border.color: dash.cardBorder
                antialiasing: true
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10
                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: ThemeService.alpha(ThemeService.blue, 0.2); antialiasing: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             anchors.centerIn: parent; text: "\uf017"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.blue }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "System Uptime"; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: UserProfileService.uptime; color: ThemeService.fg; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
        }
    }
    }

    // ═══════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf114 — global ColorPickerOverlay
    //
    // ColorSwatch delegates every swatch click to ColorPickerState.requestOpen().
    // Exactly ONE ColorPickerOverlay has ever listened for that signal, and it
    // lives inside ZenSettings. The dashboard hosts the SAME settings pages
    // (GeneralPage, ThemesPage, WidgetsPage...) but never mounted an overlay —
    // so since the dashboard became the default UI (legacyUiEnabled = false),
    // clicking a colour swatch has fired the signal into the void. The hex
    // TextField still worked, which is why this looked like "colours don't
    // apply" rather than "the picker doesn't open".
    //
    // Additive: one instance, filling the dashboard, above everything.
    // ColorPickerState is a singleton, so both overlays can coexist when
    // legacy UI is re-enabled — whichever panel is visible handles the click.
    // ═══════════════════════════════════════════════════════════════
    ColorPickerOverlay {
        anchors.fill: parent
        z: 9999
    }
}
