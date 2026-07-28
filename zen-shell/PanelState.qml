pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * PanelState — Extended panel configuration
 *
 * Complements existing Theme.qml barLayout/barOpacity/barRadius.
 * Persists to ~/.config/quickshell/zen-shell/panel-state.json
 *
 * Panel modes:
 *   "fullwidth" — traditional bar spanning entire screen width
 *   "floating"  — bar with margins on both sides (small gap)
 *   "island"    — compact centered bar with large margins
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/panel-state.json"

    // ── Panel style mode ──
    property string panelMode: "fullwidth"   // "fullwidth" | "floating" | "island"

    // ── v6.16.4.12: Panel position ──
    // v6.16.4.12.7.1 (Tachiagari hotfix 1): Now accepts all four
    // values — "bottom" (default), "top", "left", "right". For this
    // drop, the BAR ITSELF still renders horizontally regardless of
    // position; what changes is the POPUP behaviour. Vertical bar
    // rendering (rotating the bar's RowLayout to a ColumnLayout, etc.)
    // is a separate larger drop. The point of accepting left/right
    // here NOW is so popup widgets can adopt 4-direction-aware
    // positioning today, and so when the vertical-bar drop lands the
    // popup logic is already in place.
    //
    // Why split it this way: changing PanelState (the source of
    // truth) is cheap — every consumer gets the new value reactively.
    // Changing every popup widget to be 4-direction-aware is also
    // cheap and additive (each popup gains a ternary chain). Changing
    // Bar.qml + every bar module to render vertically is a big audit
    // (Layout.alignment, MusicStrings curves that are fundamentally
    // horizontal, Taskbar wrapping, etc.) — so we ship the popup
    // upgrade today and stage the layout rotation for next.
    property string panelPosition: "bottom"

    // ── Bar height ──
    property int barHeight: 60

    // v7.0.0-beta.1-hf95.31 — taskbar overflow cap. How wide the
    // horizontal taskbar may grow before chevron < > scroll arrows appear.
    // Was hardcoded 440 in Taskbar.qml; now a slider (240–900).
    property int taskbarMaxWidth: 440

    // ── Auto bar height (v7.0.0-beta.1-hf83) ──
    //
    // When true, the bar window's height is driven by the tallest
    // module currently in the bar (Bar.contentImplicitHeight) plus
    // barAutoHeightPadding on top + bottom — instead of the fixed
    // `barHeight` pixel value. This makes the bar hug its contents:
    // add a taller module and the bar grows; remove it and the bar
    // shrinks back. The manual `barHeight` slider is preserved (and
    // still used when this is false) so nothing is lost — wala tayong
    // babawasan. Default false keeps every existing install on its
    // saved fixed height until the user opts in.
    property bool barAutoHeight: false

    // Top+bottom breathing room added around the measured content
    // height when barAutoHeight is on. 8px each side by default.
    property int barAutoHeightPadding: 8

    // ── Fit contents to bar (v7.0.0-beta.1-hf84) ──
    //
    // When true, bar module content (icons, text, pills) scales to the
    // bar height instead of staying a fixed size — Theme.iconSize /
    // fontSize / moduleHeight all multiply by Theme.barContentScale,
    // which tracks this barHeight slider relative to a 60px baseline.
    // Set a taller bar → bigger icons; shorter bar → smaller icons.
    // Default false keeps every module at its existing fixed size.
    property bool barFitContents: false

    // ── Manual module scale (v7.0.0-beta.1-hf86) ──
    //
    // Direct multiplier on bar module content size, applied ON TOP of
    // the dynamic Fit-contents scale (and on its own when Fit-contents
    // is off). Lets the user size icons/text without changing bar
    // height. 1.0 = stock. Feeds Theme.barContentScale.
    property real barModuleScale: 1.0

    // ── Settings sidebar hover style (v7.0.0-beta.1-hf86) ──
    // "rounded" → pill/rounded hover highlight on left-panel nav items
    // "square"  → sharp-cornered hover highlight
    property string settingsHoverStyle: "rounded"

    // ── Quick Settings / Control Center position (v7.0.0-beta.1-hf88) ──
    // Where the Control Panel (quick settings) popup anchors when it
    // hasn't been manually dragged: "center" (default, prior behavior),
    // "top", or "bottom". Lets it sit near a top- or bottom-anchored bar.
    property string controlPanelPosition: "center"
    property int    controlPanelEdgeMargin: 12
    // v7.0.0-beta.1-hf99j: Attached mode (Caelestia-style). When true, the
    // Quick Settings hugs the bar edge (flush, corners squared on the bar
    // side) instead of floating with a margin. Overrides position to follow
    // the bar (top/bottom).
    property bool   controlPanelAttached: false

    // v7.0.0-beta.1-hf99zj: Quick Settings section order (drag-to-reorder).
    // Ids must match the sections declared in ControlPanel.qml.
    readonly property var qsSectionIds: ["profile", "weathersys", "timecal", "workflow", "audio", "connectivity", "power"]
    readonly property var qsSectionLabels: ({
        "profile": "Profile / system info", "weathersys": "Weather + System stats",
        "timecal": "Time + Calendar", "workflow": "Workflow profiles",
        "audio": "Audio sliders", "connectivity": "Connectivity", "power": "Power profile"
    })
    property var qsOrder: ["profile", "weathersys", "timecal", "workflow", "audio", "connectivity", "power"]
    // v7.0.0-beta.1-hf99zo: Glass — Advanced puts the profile/user card at the
    // bottom of the panel (like the mockup) instead of the top.
    property bool qsProfileAtBottom: false

    function qsRowFor(id) {
        const i = qsOrder.indexOf(id)
        return i >= 0 ? i : qsSectionIds.indexOf(id)
    }
    function qsMove(from, to) {
        if (from === to || from < 0 || to < 0) return
        let arr = qsOrder.slice()
        if (from >= arr.length || to >= arr.length) return
        const item = arr.splice(from, 1)[0]
        arr.splice(to, 0, item)
        qsOrder = arr
        saveState()
    }
    function qsResetOrder() { qsOrder = qsSectionIds.slice(); saveState() }

    // v7.0.0-beta.1-hf99zs: Zen Control Center dashboard card order
    // v7.0.0-beta.1-hf99zz: time and weather are separate cards; each card
    // carries its own column span (1..2) and height, both user-resizable.
    readonly property var dashCardIds: ["time", "calendar", "sysmon", "clocks", "weather",
                                        "workspaces", "activewin", "workflow", "audio"]
    readonly property var dashCardLabels: ({
        "time": "Time", "calendar": "Calendar", "sysmon": "System Monitor", "clocks": "Clocks",
        "weather": "Weather", "workspaces": "Workspaces", "activewin": "Active Window",
        "workflow": "Workflow profiles", "audio": "Audio sliders"
    })
    // v8.0.0-alpha-hf101: the dashboard grid is 4 columns wide, so a card can
    // be a quarter / half / three-quarters / full. Spans are 1..4.
    readonly property int dashColumns: 4
    readonly property var dashCardDefaults: ({
        "time":       { span: 2, h: 150 },
        "calendar":   { span: 2, h: 150 },
        "sysmon":     { span: 4, h: 236 },
        "clocks":     { span: 2, h: 190 },
        "weather":    { span: 2, h: 300 },   // hf132: hourly + 7-day fit at 300
        "workspaces": { span: 2, h: 96  },
        "activewin":  { span: 2, h: 96  },
        "workflow":   { span: 2, h: 110 },
        "audio":      { span: 2, h: 110 }
    })
    // { id: { span, h } } — only user-changed cards are stored.
    property var dashCards: ({})

    function dashSpan(id) {
        const c = dashCards[id]
        if (c && typeof c.span === "number") {
            // migrate the old 2-column scheme (1 = half, 2 = full)
            const v = (c.span <= 2 && !c.v4) ? c.span * 2 : c.span
            return Math.max(1, Math.min(dashColumns, v))
        }
        const d = dashCardDefaults[id]
        return d ? d.span : 2
    }
    function dashHeight(id) {
        const c = dashCards[id]
        if (c && typeof c.h === "number") return Math.max(70, Math.min(600, c.h))
        const d = dashCardDefaults[id]
        return d ? d.h : 140
    }
    function dashSetCard(id, span, h, commit) {
        let m = JSON.parse(JSON.stringify(dashCards))
        // v4 marks the new 1..4 span scheme so dashSpan() doesn't re-migrate it
        m[id] = { span: Math.max(1, Math.min(dashColumns, Math.round(span))),
                  h: Math.max(70, Math.min(700, Math.round(h))), v4: true }
        dashCards = m
        if (commit !== false) saveState()
    }
    function dashResetCards() { dashCards = ({}); saveState() }
    property var dashOrder: ["time", "calendar", "sysmon", "clocks", "weather", "workspaces", "activewin", "workflow", "audio"]
    function dashRowFor(id) {
        const i = dashOrder.indexOf(id)
        return i >= 0 ? i : dashCardIds.indexOf(id)
    }
    // v7.0.0-beta.1-hf99zza: `commit` lets a drag reorder dozens of times per
    // second without writing panel-state.json each frame (that write was what
    // made dragging feel like glue). The caller saves once, on release.
    function dashMove(from, to, commit) {
        if (from === to || from < 0 || to < 0) return
        let arr = dashOrder.slice()
        if (from >= arr.length || to >= arr.length) return
        const it = arr.splice(from, 1)[0]
        arr.splice(to, 0, it)
        dashOrder = arr
        if (commit !== false) saveState()
    }
    function dashResetOrder() { dashOrder = dashCardIds.slice(); dashCards = ({}); saveState() }

    // ─────────────────────────────────────────────────────────────
    // v8.0.0-alpha-hf129 — HIDDEN DASHBOARD CARDS
    //
    // A card you never use (say, Clocks) shouldn't have to be dragged to
    // the bottom of the grid — it should be able to leave. `dashHidden` is
    // the list of card ids that are skipped when the grid is built.
    //
    // Deliberately a separate list from `dashOrder`: a hidden card keeps
    // its slot, its span and its height, so un-hiding it puts it back
    // exactly where it was. Wala tayong babawasan.
    //
    // Edit mode still renders hidden cards (dimmed, with a struck-through
    // eye) so there is always a way back — you never lose a card into a
    // menu you can't find.
    // ─────────────────────────────────────────────────────────────
    property var dashHidden: []

    function dashIsHidden(id) {
        return dashHidden.indexOf(id) >= 0
    }
    // The order with hidden cards removed — what the grid renders when the
    // dashboard is NOT in edit mode.
    function dashVisibleOrder() {
        const out = []
        for (let i = 0; i < dashOrder.length; i++)
            if (dashHidden.indexOf(dashOrder[i]) < 0) out.push(dashOrder[i])
        return out
    }
    // `commit` mirrors dashMove/dashSetCard: false = live, no disk write.
    function dashSetHidden(id, hidden, commit) {
        if (dashCardIds.indexOf(id) < 0) return
        let arr = dashHidden.slice()
        const i = arr.indexOf(id)
        if (hidden && i < 0) arr.push(id)
        else if (!hidden && i >= 0) arr.splice(i, 1)
        else return                                   // no change — no write
        dashHidden = arr
        if (commit !== false) saveState()
    }
    function dashToggleHidden(id) { dashSetHidden(id, !dashIsHidden(id), true) }
    function dashShowAllCards() { dashHidden = []; saveState() }

    // ── v8.0.0-alpha-hf131 — bar/dock weather icon style ──
    //
    // The desktop widgets don't agree with each other: the Glance blob draws
    // Material Symbols, while the classic widget, the dashboard card and the
    // Quick Settings card draw emoji. Rather than pick for you, ZenWeather
    // reads this. Default `material` — monochrome, themeable, and the glyph
    // set the rest of v8's chrome already uses.
    //
    //   "material" | "emoji" | "nerd"
    property string weatherIconStyle: "material"

    // v8.0.0-alpha-hf132 — how the bar/dock weather glyph is coloured.
    //   "condition" (default) — a fixed weather palette, surface-adaptive
    //   "accent"              — one colour for everything (the pre-hf132 look)
    // Ignored for the emoji style: emoji carry their own palette.
    property string weatherIconTint: "condition"

    // v7.0.0-beta.1-hf99l: Shell Look preset (Classic / Zen / Glass / …).
    // LookService reads this + exposes the token set. Apply-to flags gate
    // which surfaces follow the look. Additive — Zen is the current default.
    property string shellLook: "zen"                 // classic|zen|glass|minimal|custom
    property bool   lookApplyBar: true
    property bool   lookApplyControlPanel: true
    property bool   lookApplyStartMenu: true
    property bool   lookApplyDock: true
    property bool   lookApplyNotifications: true
    property bool   lookApplyOsd: false

    // v8.0.0-alpha-hf112: real, user-editable opacities. The Shell Look presets
    // WRITE these; the sliders EDIT them. Nothing overrides them at render time.
    property real controlPanelOpacity: 0.96
    // v8.0.0-alpha-hf181 — the dock's own plate, the thing Paul actually circled. Its
    // alpha was hardcoded at 0.32 in Taskbar.qml with no way to reach it. hf178 removed
    // the per-icon pills, which was the wrong plate. Unlike the other opacity sliders
    // this one goes all the way to 0: at 0 the plate, its border and its inner highlight
    // all stop drawing, and the icons float straight on the wallpaper — the macOS look
    // he's after. Defaults to 0.32 so nothing changes until he drags it.
    property real taskbarOpacity: 0.32
    // v8.0.0-alpha-hf182 — Taskbar.qml is ONE component mounted in three places:
    // Bar, BarVertical and ZenDock. So hf181's taskbarOpacity was silently changing the
    // QML bar's taskbar as well as the dock's. It now knows which surface it's on, and
    // these are the dock's / the bar's own values. linkSurfaces on (default) keeps the
    // old one-number behaviour; off lets them differ.
    property real taskbarBarOpacity: 0.32
    property bool taskbarLinkSurfaces: true
    // Scales the icon INSIDE its button box rather than the box itself, so growing the
    // icons can't push the bar's layout around or trigger overflow.
    property real taskbarIconScale: 1.0
    property real startMenuOpacity: 0.92
    property real notificationOpacity: 0.96

    // v8.0.0-alpha-hf144 — "kung gaano ka-glassy, ganun."
    //
    // A single 0..1 knob the Glass+ look reads. It is NOT another opacity field;
    // it drives fill AND blur together (see LookService.glassFill / glassBlur),
    // so one slider moves the whole frost. Border stays crisp on purpose — the
    // panels have to remain readable at full glass. 0 = a whisper of fill, 1 =
    // the frostiest the look goes. Persisted like everything else.
    property real glassStrength: 1.0     // hf173: default = level 5 (Paul: "default naka 100 percent")

    // v8.0.0-alpha-hf146 — monochrome (white) app icons in the dock and bar
    // taskbars. Off by default; Glass+ turns it on when you switch into it, and
    // the Shell Look page has the toggle. Persisted.
    property bool monoIcons: false
    // v8.0.0-alpha-hf178 — Paul: "prang pang macbook prang naka float nga yun design e
    // kaya ko pinapaalis yun background nung taskbar ko sa dock". Off = the icons sit
    // straight on the dock with no pill behind them; the running-dot and the hover wash
    // still say what's open and what you're pointing at. Nothing is removed — the pills
    // are one toggle away, and every other look is untouched.
    property bool taskbarIconBackgrounds: false
    property real dashOpacity: 0.96

    // ── Vertical content padding (v7.0.0-beta.1-hf85) ──
    //
    // Guaranteed breathing room above + below the bar's module row, so
    // modules stay vertically centered with an even gap top and bottom
    // no matter the bar height. Bar.qml insets its content RowLayout by
    // this amount on top and bottom; the three module zones fillHeight
    // within the reduced area and each module is AlignVCenter, so they
    // stay centered with symmetric padding when the height changes.
    property int barContentPaddingV: 4

    // ── Computed margins/width based on mode ──
    property int panelMarginSide: {
        if (panelMode === "floating") return 12
        if (panelMode === "island") return 240
        return 0
    }

    property int panelMarginBottom: {
        if (panelPosition !== "bottom") return 0
        return panelMode === "fullwidth" ? 0 : 8
    }

    // v6.16.4.12: Top margin (only used when position is "top")
    property int panelMarginTop: {
        if (panelPosition !== "top") return 0
        return panelMode === "fullwidth" ? 0 : 8
    }

    // v6.16.4.12.7.1 (Tachiagari hotfix 1): Left/right gutters,
    // mirroring the top/bottom margin pattern. Only meaningful when
    // panelPosition is the matching side. fullwidth strips the
    // gutter (bar flush against the edge); floating/island add the
    // same 8px breathing room as the horizontal counterparts. These
    // are ZERO-VALUED for horizontal bars, so no existing horizontal
    // anchor math breaks if a consumer accidentally adds them in.
    property int panelMarginLeft: {
        if (panelPosition !== "left") return 0
        return panelMode === "fullwidth" ? 0 : 8
    }
    property int panelMarginRight: {
        if (panelPosition !== "right") return 0
        return panelMode === "fullwidth" ? 0 : 8
    }

    // ── v6.16.4.12.7.1: Position convenience flags ──
    // Each readonly property makes the intent at the consumer site
    // self-documenting — `PanelState.isLeft` reads better than
    // `PanelState.panelPosition === "left"` in a popup's anchor
    // ternary, and gives us one place to change the underlying
    // representation if we ever migrate to an enum.
    readonly property bool isTop:    panelPosition === "top"
    readonly property bool isBottom: panelPosition === "bottom"
    readonly property bool isLeft:   panelPosition === "left"
    readonly property bool isRight:  panelPosition === "right"
    readonly property bool isVertical:   isLeft || isRight
    readonly property bool isHorizontal: isTop  || isBottom

    // ── Border ──
    property bool borderEnabled: false
    property int borderWidth: 1
    property color borderColor: "#414868"

    // ── v6.16.4.12.7 (Tachiagari): Start-button border ──
    // When `startButtonUseBorderColor` is true, the start menu button
    // adopts the panel's `borderColor` for its idle border instead of
    // the muted Theme.bg1 default. Hover state still flips to blue
    // accent so the click affordance remains obvious. Lets the start
    // button visually tie into a colored panel border (e.g. neon green
    // border + matching green start button outline).
    //
    // Independent toggle from `borderEnabled` — user can run with NO
    // panel border and STILL want the button outlined in a custom hue.
    // `startButtonBorderWidth` defaults to 1 (matches old hardcoded
    // value) but is exposed so themes/users can crank it to 2 for a
    // bolder rim without affecting the panel border thickness.
    property bool startButtonUseBorderColor: false
    property int  startButtonBorderWidth: 1

    // ── Background override (null = use Theme.bg0) ──
    property bool bgOverrideEnabled: false
    property color bgOverrideColor: "#1a1b26"
    property real bgOverrideOpacity: 0.85

    // ── v6.4: Dynamic start menu positioning ──
    // Updated by StartMenu.qml on every click. Stored as the button's
    // center-X in GLOBAL (screen) coordinates. Runtime-only — not persisted,
    // since it changes every time the bar layout rearranges.
    property real startButtonCenterX: -1   // -1 = unknown, use default left-anchor
    property real startButtonCenterY: -1

    // v7.0.0-alpha.6-hf4: clipboard module button position (mirror
    // of startButton — used by shell.qml clipboardWindow to anchor
    // the panel directly under/over the clipboard icon in the bar,
    // wherever the user placed it in their bar layout).
    property real clipboardButtonCenterX: -1
    property real clipboardButtonRightX: -1   // for right-side anchoring

    // Screen dimensions of the monitor the start button was last clicked on.
    // Used by shell.qml to clamp the menu within the viewport.
    property int screenWidth: 1920
    property int screenHeight: 1080

    // ── v6.16.4.12.6.53 (Hiraki hotfix 1): Dynamic calendar positioning ──
    // Updated by Clock.qml on every click. Stored as the clock's
    // CENTER-X and RIGHT-EDGE-X in GLOBAL (screen) coordinates so
    // shell.qml's `calendarWindow` can anchor its right edge to the
    // clock instead of the screen edge. Runtime-only — not persisted.
    // -1 = unknown → calendarWindow falls back to the historical
    // 12px-from-right-screen-edge anchor.
    property real clockCenterX:    -1
    property real clockRightEdgeX: -1

    // ── v6.4: Style-mode propagation flag ──
    // When true (default), derived modules (start menu, taskbar wrapper,
    // settings window) read their radius/shape from Theme.barRadius +
    // Theme.styleMode instead of hardcoding. Gives uniform look when user
    // switches to "round" style via Panel page.
    property bool propagateStyleToModules: true

    // ── v6.6: Bar module format selections ──
    // Clock format index (into ZenConstants.clockFormats array).
    // Default 6 = "Date + 12h multiline".
    property int clockFormatIndex: 6

    // Workspace number format preset id (keys from ZenConstants.workspaceFormats)
    // Default "numbers".
    property string workspaceFormat: "numbers"

    // Active font family id (from ZenConstants.fontFamilies).
    // Default "jetbrains".
    property string fontFamilyId: "jetbrains"

    // v6.8: Workspace visible count limit (default 5).
    property int workspaceLimit: 5

    // v7.0.0-alpha.4 (StartMenu V2): pinned-grid dynamic dimensions
    // for the dual-pane StartMenuPanel. Cols clamped 3-6, rows 1-8 by
    // the panel itself. Defaults give a 4x4 grid (16 slots).
    property int pinnedGridCols: 4
    property int pinnedGridRows: 4

    // v7.0.0-alpha.4-hf2: StartMenu border mode.
    //   "off"       — borderless panel
    //   "match-bar" — same border color/width as the bar (so the two
    //                 form one continuous line when the panel is
    //                 sticky-anchored to the bar — see shell.qml gap)
    //   "thick"     — 2× bar border width, same color (emphasized)
    // Default "match-bar" reads from existing borderEnabled +
    // borderWidth + borderColor. When bar border is off, panel falls
    // back to a subtle ThemeService outline.
    property string startMenuBorderMode: "match-bar"

    // v7.0.0-alpha.6: ClipboardPanel visibility (Super+V toggle).
    // shell.qml mounts a PanelWindow gated on this flag.
    property bool clipboardVisible: false

    // v7.0.0-alpha.6-hf2: SettingsSearchOverlay visibility (Ctrl+F).
    // Bound to a global PanelWindow at WlrLayer.Overlay so the search
    // is summonable from anywhere — not just inside Settings.
    property bool searchOverlayVisible: false

    // v7.0.0-beta.1-hf25: direct-toggle properties so callers don't
    // need to spawn `qs ipc call` (which can launch a second instance
    // if current is mid-crash).
    property bool startMenuVisible: false
    property bool settingsVisible: false
    // v7.0.0-beta.1-hf99zp: merged Quick Settings + Control Center dashboard
    property bool dashboardVisible: false
    // v7.0.0-beta.1-hf99zu: the merged dashboard replaces the classic Quick
    // Settings popup and Settings window. Set true (or `ipc call zen
    // toggleLegacyUi`) to bring the old windows back.
    property bool legacyUiEnabled: false
    // v8.0.0-alpha-hf106: dashboard brand mark —
    //   "color" (the six-facet logo in full colour, default)
    //   "hex"   (the same mark, mono)
    //   "kanji" (the written 禅 mark)
    property string dashLogoStyle: "color"
    // v8.0.0-alpha-hf105: Control Center UI scale (0.70–1.40). Lets the whole
    // dashboard shrink to fit a vertical / small monitor, or grow on a 4K.
    property real dashScale: 1.0

    // v8.0.0-alpha-hf113: notification-style placement for the floating
    // windows. See ZenWindowPlacement.modes — nine anchors. "Reopen where I
    // dragged it" is dashRememberDrag / settingsRememberDrag. Default: center.
    property string dashPlacement: "center"
    property int    dashMargin: 24
    property string settingsPlacement: "center"
    property int    settingsMargin: 24
    // v8.0.0-alpha-hf123 — "reopen where I dragged it" is its own question,
    // not a tenth anchor. See ZenWindowPlacement.modes.
    property bool   dashRememberDrag: false
    property bool   settingsRememberDrag: false
    // v8.0.0-alpha-hf117: notification-style entrance for both windows.
    property bool   windowSlideIn: true
    function dashSetScale(v) {
        dashScale = Math.max(0.70, Math.min(1.40, Math.round(v * 100) / 100))
        saveState()
    }

    // v7.0.0-beta.1-hf41: persisted collapse/expand state for the
    // FloatingSettingsSearch component in ZenSettings. Defaults to
    // false (collapsed) — user must explicitly click the search
    // glyph to expand the bar. State survives Settings panel
    // close/reopen within the same shell session (not persisted
    // to disk — intentional, prevents weird "I left this open"
    // surprises across reboots).
    property bool settingsSearchExpanded: false

    // v6.10: Bar target display — "all", "primary", or specific monitor name
    property string barTargetDisplay: "all"

    // v6.11: Start button icon size (default 26)
    property int startButtonIconSize: 26

    // v6.16.2.3: Calendar visibility state — shared singleton prop so
    // Clock.qml (loaded in Bar context) can toggle without needing IPC.
    // shell.qml binds calendarWindow.visible to this property.
    property bool calendarVisible: false
    // v8: set by the clock module so the global calendarWindow
    // anchors to the DOCK edge (not the bar) when the clock is docked.
    property bool calendarFromDock: false
    function toggleCalendar() { calendarVisible = !calendarVisible }
    function closeCalendar()  { calendarVisible = false }
    function openCalendar()   { calendarVisible = true }

    // v7.0.0-beta.1-hf5: Singleton-backed notification panel visibility.
    //
    // The bell icon (NotificationIcon.qml) used to fire external IPC
    // via `qs -c zen-shell ipc call zen toggleNotifications` — every
    // click spawned a bash subprocess + ipc roundtrip. On rapid clicks
    // or under load, the bash latency raced with QML binding updates,
    // causing the notifPanelWindow to render multiple stacked QML
    // surfaces and eventually crash.
    //
    // Now the bell flips this PanelState property directly (no IPC, no
    // process spawn, no race). shell.qml's notifPanelWindow keeps its
    // existing root.notifPanelVisible binding AND a forwarder to this
    // singleton — both stay in sync.
    property bool notifPanelVisible: false
    function toggleNotifPanel() { notifPanelVisible = !notifPanelVisible }
    function closeNotifPanel()  { notifPanelVisible = false }
    function openNotifPanel()   { notifPanelVisible = true }

    // v7.0.0-beta.1-hf7: Singleton-backed visibility for Control Panel
    // + Workspace Overview, mirroring shell.qml root properties.
    // Used by HotCornerService to invoke actions directly (no external
    // bash/IPC roundtrip = no race condition).
    property bool controlPanelVisible: false
    function toggleControlCenter() { controlPanelVisible = !controlPanelVisible }
    function closeControlCenter()  { controlPanelVisible = false }
    function openControlCenter()   { controlPanelVisible = true }

    property bool workspaceOverviewVisible: false
    function toggleWorkspaceOverview() { workspaceOverviewVisible = !workspaceOverviewVisible }
    function closeWorkspaceOverview()  { workspaceOverviewVisible = false }
    function openWorkspaceOverview()   { workspaceOverviewVisible = true }

    // v7.0.0-beta.1-hf39 — visibility properties for the five new
    // feature modules (Focus Spaces, Quick Notes, Network Pulse).
    // Smart Dim has no popover (toggle-only). Title Translator uses
    // hover tooltip only. These three needed flip flags for their
    // panels.
    property bool focusSpacesVisible: false
    function toggleFocusSpaces() { focusSpacesVisible = !focusSpacesVisible }

    property bool quickNotesVisible: false
    function toggleQuickNotes() { quickNotesVisible = !quickNotesVisible }

    property bool networkPulseVisible: false
    function toggleNetworkPulse() { networkPulseVisible = !networkPulseVisible }

    // v7.0.0-beta.1-hf39 — settings page deep-link.
    // Used by bar modules' right-click handlers to jump directly to
    // their config page. ZenSettings.qml watches pendingSettingsPage,
    // applies it to its currentPage, then resets pendingSettingsPage
    // to "" so the watcher fires correctly on subsequent navigations.
    property string pendingSettingsPage: ""

    function openSettingsPage(pageId) {
        if (typeof pageId === "string" && pageId) {
            pendingSettingsPage = pageId
        }
        settingsVisible = true
    }

    // v6.16.2.3.1: Calendar month navigation nudge. Clock's scroll wheel
    // increments/decrements this; ZenCalendar watches it and applies the
    // delta to its viewMonth/viewYear. A counter (not a direct month
    // value) because ZenCalendar maintains its own view state and we
    // just want to nudge it. Reset to 0 isn't needed — ZenCalendar
    // consumes the delta then updates its own state.
    property int calendarMonthDelta: 0

    // v6.16.3.7: universal desktop widget scale factor.
    // Multiplies all widget font sizes + derived container bounds
    // in DesktopWidgets.qml. Range clamped to 0.5-2.0 in the UI.
    // Default 1.0 = baseline sizes Paul designed around for his
    // 1440p / 4K development setup. Bump to 1.25-1.5 on very large
    // screens, drop to 0.75-0.85 on 1080p to match visual density.
    property real widgetScale: 1.0

    // v6.16.3.8: Idle cascade timeouts (seconds).
    // 0 = never (disabled). UI offers: 30s, 1m, 30m, 1h, 3h, 5h, never.
    // Defaults mirror the old static hypridle.conf values to preserve
    // behavior for existing installs — 5min lock, no auto-sleep.
    //   idleLockSeconds  = seconds of user idle before screen locks
    //   idleSleepSeconds = seconds of user idle before systemctl suspend
    //
    // zen-hypridle-sync.sh reads these values, rewrites hypridle.conf
    // listener timeouts via sed (matching # ZEN_IDLE_LOCK /
    // # ZEN_IDLE_SLEEP markers), and restarts hypridle.
    property int idleLockSeconds: 300         // 5 minutes
    property int idleSleepSeconds: 0          // never

    // v6.16.3.8: System action on laptop lid close (separate from
    // the monitor-mirroring behavior in SettingsStateV2.lidCloseBehavior).
    //   "suspend" — lock + systemctl suspend (wake to lock screen)
    //   "lock"    — lock screen only, no suspend
    //   "ignore"  — noop; user controls power manually
    // Read by zen-lid-handler.sh alongside monitor behavior.
    property string lidCloseAction: "suspend"

    // v6.16.3.6: user gender preference for lock-screen message
    // flavor. "neutral" uses gender-agnostic phrasings (default).
    // "male" / "female" pull from pools that address the user
    // directly (e.g. "What's up, man!" / "What's up, miss!").
    // Stored here rather than in UserProfileService because it's
    // a user preference, not a system-detected attribute.
    property string userGender: "neutral"

    // v6.16.2: Start button logo customization
    // v6.16.3.5: expanded — three modes instead of two:
    //   "auto"    — auto-detect from UserProfileService.osLogo (reads
    //               /etc/os-release $LOGO or $ID). Falls back to Arch
    //               if no match.
    //   "builtin" — user picks from the bundled logo set (Arch, CachyOS,
    //               EndeavourOS, Fedora, Ubuntu, NixOS, Linux fallback).
    //               Logos live at ~/.local/share/quickshell/zen-shell/
    //               logos/<id>.svg, installed by install.sh from
    //               zen-shell-v5/assets/logos/.
    //   "custom"  — user-supplied file (existing v6.16.2 behavior,
    //               unchanged).
    //
    // startButtonLogoBuiltinId holds the chosen builtin when mode = "builtin".
    // Ignored in other modes.
    property string startButtonLogoMode: "auto"     // "auto" | "builtin" | "custom"
    property string startButtonLogoPath: ""          // absolute path to PNG/SVG/JPG (custom mode)
    property string startButtonLogoBuiltinId: "arch" // id key into builtinLogos (builtin mode)
    property bool   startButtonLogoTint: false       // if true, colorize with Theme.fg (for monochrome SVGs)

    // v6.16.3.5: Bundled logo library.
    //   - id         → filename stem (matches <id>.svg under logos/)
    //   - label      → display text in the picker grid
    //   - osReleaseIds → array of strings matched against os-release $LOGO/$ID
    //                    for the "auto" mode detection
    readonly property var builtinLogos: [
        { id: "arch",        label: "Arch Linux",    osReleaseIds: ["arch", "archlinux", "distributor-logo-archlinux"] },
        { id: "cachyos",     label: "CachyOS",       osReleaseIds: ["cachyos", "cachy", "cachyos-linux"] },
        { id: "endeavouros", label: "EndeavourOS",   osReleaseIds: ["endeavouros", "endeavour"] },
        { id: "fedora",      label: "Fedora",        osReleaseIds: ["fedora", "fedora-linux"] },
        { id: "ubuntu",      label: "Ubuntu",        osReleaseIds: ["ubuntu"] },
        { id: "nixos",       label: "NixOS",         osReleaseIds: ["nixos"] },
        { id: "linux",       label: "Linux (generic)", osReleaseIds: [] }
    ]

    readonly property string _logosDir: Quickshell.env("HOME") + "/.local/share/quickshell/zen-shell/logos"

    // v6.16.3.5: resolve the effective logo path for the currently-
    // selected mode. Returns a QML-ready URL ("file://...") or empty
    // string if nothing is configured (caller falls back to
    // Quickshell.iconPath("distributor-logo-archlinux") in that case).
    function resolveStartButtonLogo() {
        switch (startButtonLogoMode) {
            case "custom":
                return startButtonLogoPath ? "file://" + startButtonLogoPath : ""
            case "builtin":
                return "file://" + _logosDir + "/" + startButtonLogoBuiltinId + ".svg"
            case "auto":
            default:
                // Try to match os-release against the builtin library
                const tag = (typeof UserProfileService !== "undefined")
                    ? String(UserProfileService.osLogo || "").toLowerCase()
                    : ""
                if (tag) {
                    for (let i = 0; i < builtinLogos.length; i++) {
                        const entry = builtinLogos[i]
                        for (let j = 0; j < entry.osReleaseIds.length; j++) {
                            if (tag.indexOf(entry.osReleaseIds[j]) >= 0) {
                                return "file://" + _logosDir + "/" + entry.id + ".svg"
                            }
                        }
                    }
                }
                // No match — return empty so caller uses Quickshell.iconPath
                return ""
        }
    }

    // v6.11: Workspace dot sizes — active/inactive
    property int workspaceDotActive: 32
    property int workspaceDotInactive: 26
    property int workspaceFontActive: 13
    property int workspaceFontInactive: 11

    // ── Signals ──
    signal stateChanged()
    // v6.16.2.3.1: Emitted ONCE after the first successful JSON load.
    // shell.qml listens for this to flip _shellReady (gating nuclear
    // restart). Emitted from FileView.onLoaded after applyState runs.
    signal panelStateLoaded()

    // v7.0.0-beta.1-hf28: clipboard toggle signal. Bar module emits
    // with caller's screen; shell.qml listens and calls its internal
    // toggleClipboardOnScreen(). No `qs ipc call` subprocess → no
    // risk of second-instance spawn during a crash recovery.
    signal toggleClipboardOnScreenRequested(var screen)

    // v6.16.4.12.9 (Modori) — Debounced save.
    //
    // Sliders in PanelPage call PanelState.saveState() on every
    // onValueChanged tick while the user is dragging — that's
    // ~30-60 fires per second on a smooth drag. Each fire spawns
    // a bash process via `stateSaver.command = [...]`. Because
    // we reuse the SAME Process Item, a new `running = true`
    // assignment while the previous bash is still mid-write
    // truncates the heredoc and leaves a corrupt file. On next
    // shell start, applyState's JSON.parse throws → silent default
    // fallback → user's settings appear "lost."
    //
    // Fix: route every saveState() call through a single 200ms
    // debounce timer. Each call resets the timer; only the last
    // call (after the user stops moving the slider) actually fires
    // the file write. End result: one bash spawn per UI gesture
    // instead of dozens, no overlapping writes, no corruption.
    //
    // The 200ms window is long enough to absorb a typical drag
    // (sliders fire ~16ms apart at 60fps) and short enough that
    // the user's perception of "settings save instantly" stays
    // intact — they let go of the slider, ~1/5 of a second later
    // the disk write happens, and the next launch reads it back.
    Timer {
        id: saveDebounce
        interval: 200
        repeat: false
        onTriggered: root._doSaveState()
    }
    function saveState() {
        // Public entry point — debounced.
        saveDebounce.restart()
    }
    function saveStateImmediate() {
        // Escape hatch for the rare cases where we need a sync save
        // (e.g. before a deliberate shell restart). Bypasses debounce.
        saveDebounce.stop()
        _doSaveState()
    }

    // v7.0.0-beta.1-hf97 — load-complete guard. See FileView below.
    // Until panel-state.json has finished its async load at startup,
    // ANY saveState() call would write the still-DEFAULT in-memory
    // values over the user's saved bar config. The concrete trigger:
    // ThemeService.applyJson() runs on the theme file's onLoaded at
    // login and queues `Qt.callLater(PanelState.saveState)`; the shell's
    // theme-apply and nuclear-restart timers can fire too. Both
    // FileViews (theme + panel-state) load concurrently, so when the
    // theme path wins the race, panel-state.json gets clobbered with
    // defaults — the intermittent "bar settings nag-reset, dunno why"
    // bug. Suppressing writes until _loaded flips closes the whole
    // race class. No feature touched — wala tayong binawasan.
    property bool _loaded: false
    // v8.0.0-alpha-hf110 — DATA-LOSS GUARDS.
    //
    // applyState() catches its own exceptions, so a single bad/unknown field
    // aborted the rest of the assignments and left DEFAULTS in memory — while
    // onLoaded still flipped _loaded, letting the next save overwrite the
    // user's real panel-state.json (bar position, colours, everything).
    //
    //   _loadDegraded : a load parsed/applied only partially → never write.
    //   _rawState     : the file exactly as it was read, so keys this build
    //                   doesn't know about survive a round-trip (important
    //                   when a client's config was written by a newer shell).
    property bool _loadDegraded: false
    property bool _restoreTried: false
    property var  _rawState: ({})

    function _doSaveState() {
        if (!root._loaded) {
            console.warn("[PanelState] hf97: save suppressed — panel-state.json not loaded yet (prevents default clobber)")
            return
        }
        if (root._loadDegraded) {
            console.warn("[PanelState] hf110: save suppressed — the last load was only partial. "
                       + "Refusing to overwrite your settings with defaults. "
                       + "Check ~/.config/quickshell/zen-shell/panel-state.json (a .bak sits next to it).")
            return
        }
        const state = {
            // v6.16.0: version stamp used by applyState migration checks.
            // Bump this when introducing a non-idempotent data migration.
            // v7.0.0-beta.1-hf42: bumped so the quicknotes + titletranslator
            // injection migration runs at most once per upgrade.
            saveVersion: "7.0.0-beta.1-hf42",
            panelMode: panelMode,
            panelPosition: panelPosition,
            barHeight: barHeight,
            taskbarMaxWidth: taskbarMaxWidth,
            // v7.0.0-beta.1-hf83: auto-height opt-in + its padding
            barAutoHeight: barAutoHeight,
            barAutoHeightPadding: barAutoHeightPadding,
            barFitContents: barFitContents,
            barContentPaddingV: barContentPaddingV,
            barModuleScale: barModuleScale,
            settingsHoverStyle: settingsHoverStyle,
            controlPanelPosition: controlPanelPosition,
            controlPanelEdgeMargin: controlPanelEdgeMargin,
            controlPanelAttached: controlPanelAttached,
            qsOrder: qsOrder,
            qsProfileAtBottom: qsProfileAtBottom,
            legacyUiEnabled: legacyUiEnabled,
            // v8.0.0-alpha-hf113
            dashPlacement: dashPlacement,
            dashMargin: dashMargin,
            settingsPlacement: settingsPlacement,
            settingsMargin: settingsMargin,
            dashRememberDrag: dashRememberDrag,
            settingsRememberDrag: settingsRememberDrag,
            windowSlideIn: windowSlideIn,
            dashLogoStyle: dashLogoStyle,
            dashScale: dashScale,
            dashOrder: dashOrder,
            dashCards: dashCards,
            // v8.0.0-alpha-hf129
            dashHidden: dashHidden,
            // v8.0.0-alpha-hf131 / hf132
            weatherIconStyle: weatherIconStyle,
            weatherIconTint: weatherIconTint,
            shellLook: shellLook,
            lookApplyBar: lookApplyBar,
            lookApplyControlPanel: lookApplyControlPanel,
            lookApplyStartMenu: lookApplyStartMenu,
            lookApplyDock: lookApplyDock,
            lookApplyNotifications: lookApplyNotifications,
            lookApplyOsd: lookApplyOsd,
            dashOpacity: dashOpacity,
            notificationOpacity: notificationOpacity,
            glassStrength: glassStrength,
            monoIcons: monoIcons,
            taskbarIconBackgrounds: taskbarIconBackgrounds,
            startMenuOpacity: startMenuOpacity,
            controlPanelOpacity: controlPanelOpacity,
            taskbarOpacity: taskbarOpacity,
            taskbarBarOpacity: taskbarBarOpacity,
            taskbarLinkSurfaces: taskbarLinkSurfaces,
            taskbarIconScale: taskbarIconScale,
            borderEnabled: borderEnabled,
            borderWidth: borderWidth,
            borderColor: "" + borderColor,
            // v6.16.4.12.7 (Tachiagari): start-button border tint
            startButtonUseBorderColor: startButtonUseBorderColor,
            startButtonBorderWidth: startButtonBorderWidth,
            bgOverrideEnabled: bgOverrideEnabled,
            bgOverrideColor: "" + bgOverrideColor,
            bgOverrideOpacity: bgOverrideOpacity,
            // v6.6
            clockFormatIndex: clockFormatIndex,
            workspaceFormat: workspaceFormat,
            fontFamilyId: fontFamilyId,
            // v6.8
            workspaceLimit: workspaceLimit,
            // v7.0.0-alpha.4 (StartMenu V2)
            pinnedGridCols: pinnedGridCols,
            pinnedGridRows: pinnedGridRows,
            // v7.0.0-alpha.4-hf2
            startMenuBorderMode: startMenuBorderMode,
            // v6.10
            barTargetDisplay: barTargetDisplay,
            // v6.11
            startButtonIconSize: startButtonIconSize,
            // v6.16.2
            startButtonLogoMode: startButtonLogoMode,
            startButtonLogoPath: startButtonLogoPath,
            startButtonLogoTint: startButtonLogoTint,
            // v6.16.3.5: bundled logo selection (mode="builtin")
            startButtonLogoBuiltinId: startButtonLogoBuiltinId,
            // v6.16.3.6: gender for lock screen message flavor
            userGender: userGender,
            // v6.16.3.7: desktop widget scale multiplier
            widgetScale: widgetScale,
            // v6.16.3.8: idle/lid cascade
            idleLockSeconds: idleLockSeconds,
            idleSleepSeconds: idleSleepSeconds,
            lidCloseAction: lidCloseAction,
            workspaceDotActive: workspaceDotActive,
            workspaceDotInactive: workspaceDotInactive,
            workspaceFontActive: workspaceFontActive,
            workspaceFontInactive: workspaceFontInactive,
            // v6.15.1: Theme properties that live on Theme object but
            // need to persist across restarts. Without this, barLayout
            // resets to theme defaults on every restart.
            barLayout: Theme.barLayout,
            barOpacity: Theme.barOpacity,
            barRadius: Theme.barRadius,
            styleMode: Theme.styleMode
        }
        // v8.0.0-alpha-hf110: keep any key this build doesn't know about
        // (written by a newer shell, or a client's own field) instead of
        // silently dropping it on the next save.
        let merged = {}
        try {
            for (const k in root._rawState) merged[k] = root._rawState[k]
        } catch (e) { merged = {} }
        for (const k in state) merged[k] = state[k]

        const json = JSON.stringify(merged, null, 2)

        // Never write something we can't read back.
        try { JSON.parse(json) }
        catch (e) {
            console.error("[PanelState] hf110: refusing to write malformed state:", e)
            return
        }

        // Atomic: write a temp file, fsync-ish, rotate the backup, then mv into
        // place. A truncated heredoc can no longer leave a corrupt state file.
        stateSaver.command = ["bash", "-c",
            "set -e; d=$(dirname '" + statePath + "'); mkdir -p \"$d\"; " +
            "tmp='" + statePath + ".tmp'; " +
            "cat > \"$tmp\" << 'ZSEOF'\n" + json + "\nZSEOF\n" +
            // Validate only when python3 exists — otherwise a machine without it
            // could never save at all. The JSON was already parsed in QML above.
            "if command -v python3 >/dev/null 2>&1; then " +
            "  python3 -c \"import json,sys;json.load(open(sys.argv[1]))\" \"$tmp\" 2>/dev/null || " +
            "    { rm -f \"$tmp\"; exit 1; }; " +
            "fi; " +
            "[ -f '" + statePath + "' ] && cp -f '" + statePath + "' '" + statePath + ".bak' 2>/dev/null || true; " +
            "mv -f \"$tmp\" '" + statePath + "'"]
        stateSaver.running = true
        stateChanged()
    }

    // Returns true only when the WHOLE payload applied cleanly.
    function applyState(text) {
        if (!text) return false
        try {
            const s = JSON.parse(text)
            root._rawState = s
            if (s.panelMode) panelMode = s.panelMode
            // v6.16.4.12: panel position
            // v6.16.4.12.9.2 (Modori) hotfix: only accept top/bottom.
            //
            // Tachiagari .7.1 added "left" and "right" as valid values
            // for popup-direction-aware behavior, but the actual
            // vertical bar rendering was rolled back in Modori .9 due
            // to crashes. Even with the bar staying horizontal, a
            // value of "left" or "right" caused the Settings sidebar
            // user row to disappear (the cross-axis layout in
            // ZenSettings reacts to PanelState.isVertical).
            //
            // Migration safety: if a user's saved panel-state.json
            // still has "left" or "right" from a previous session,
            // auto-migrate it back to "bottom" on load. This prevents
            // users who tested vertical-bar variants from being stuck
            // in a broken state with no way to recover from the
            // Settings UI (since the Left/Right cards in PanelPage
            // are now hidden).
            //
            // Will be reinstated when the proper vertical-bar drop
            // lands with full sidebar / module-rotation support.
            // v7.0.0-beta.1-hf90: vertical bar (Tategaki) Phase 1 — all
            // four positions are now valid and persisted. Left/Right
            // render a vertical bar (see shell.qml + Bar.qml). No more
            // migrate-to-bottom.
            if (s.panelPosition === "top" || s.panelPosition === "bottom"
                || s.panelPosition === "left" || s.panelPosition === "right") {
                panelPosition = s.panelPosition
            }
            if (s.barHeight) barHeight = s.barHeight
            if (s.taskbarMaxWidth) taskbarMaxWidth = Math.max(240, Math.min(900, s.taskbarMaxWidth))
            // v7.0.0-beta.1-hf83: auto-height opt-in + its padding
            if (typeof s.barAutoHeight === "boolean") barAutoHeight = s.barAutoHeight
            if (typeof s.barAutoHeightPadding === "number")
                barAutoHeightPadding = Math.max(0, Math.min(40, s.barAutoHeightPadding))
            if (typeof s.barFitContents === "boolean") barFitContents = s.barFitContents
            if (typeof s.barContentPaddingV === "number") barContentPaddingV = Math.max(0, Math.min(64, s.barContentPaddingV))
            if (typeof s.barModuleScale === "number") barModuleScale = Math.max(0.6, Math.min(2.0, s.barModuleScale))
            if (s.settingsHoverStyle === "rounded" || s.settingsHoverStyle === "square") settingsHoverStyle = s.settingsHoverStyle
            if (s.controlPanelPosition === "center" || s.controlPanelPosition === "top" || s.controlPanelPosition === "bottom") controlPanelPosition = s.controlPanelPosition
            if (typeof s.controlPanelEdgeMargin === "number") controlPanelEdgeMargin = Math.max(0, Math.min(120, s.controlPanelEdgeMargin))
            if (typeof s.controlPanelAttached === "boolean") controlPanelAttached = s.controlPanelAttached
            if (typeof s.qsProfileAtBottom === "boolean") qsProfileAtBottom = s.qsProfileAtBottom
            if (typeof s.legacyUiEnabled === "boolean") legacyUiEnabled = s.legacyUiEnabled
            // v8.0.0-alpha-hf114 — REGRESSION FIX.
            //
            // hf113 called ZenWindowPlacement.isValid() right here. applyState()
            // is one big try/catch: if that singleton is not resolvable at parse
            // time, the ReferenceError is swallowed and EVERY key after this
            // line silently keeps its default — borderColor, the palette, the
            // module layout, all of it. Then the next saveState() writes the
            // defaults back over the user's file. Exactly the hf110 failure mode.
            //
            // applyState() must never depend on another singleton. Validate
            // against a local literal instead.
            const _placements = ["top-left","top-center","top-right",
                                 "center-left","center","center-right",
                                 "bottom-left","bottom-center","bottom-right"]
            // hf123 migration: "free" was an anchor value until now. Split it back
            // into (anchor = center, rememberDrag = true) and never lose the flag.
            if (typeof s.dashPlacement === "string") {
                if (s.dashPlacement === "free") { dashPlacement = "center"; dashRememberDrag = true }
                else if (_placements.indexOf(s.dashPlacement) >= 0) dashPlacement = s.dashPlacement
            }
            if (typeof s.settingsPlacement === "string") {
                if (s.settingsPlacement === "free") { settingsPlacement = "center"; settingsRememberDrag = true }
                else if (_placements.indexOf(s.settingsPlacement) >= 0) settingsPlacement = s.settingsPlacement
            }
            if (typeof s.dashRememberDrag === "boolean") dashRememberDrag = s.dashRememberDrag
            if (typeof s.settingsRememberDrag === "boolean") settingsRememberDrag = s.settingsRememberDrag
            if (typeof s.dashMargin === "number") dashMargin = Math.max(0, Math.min(200, s.dashMargin))
            if (typeof s.settingsMargin === "number") settingsMargin = Math.max(0, Math.min(200, s.settingsMargin))
            if (typeof s.windowSlideIn === "boolean") windowSlideIn = s.windowSlideIn
            if (typeof s.dashLogoStyle === "string") dashLogoStyle = s.dashLogoStyle
            if (typeof s.dashScale === "number") dashScale = Math.max(0.70, Math.min(1.40, s.dashScale))
            if (s.dashCards && typeof s.dashCards === "object") dashCards = s.dashCards
            if (s.dashOrder && Array.isArray(s.dashOrder)) {
                const kn = s.dashOrder.filter(id => dashCardIds.indexOf(id) >= 0)
                for (const id of dashCardIds) if (kn.indexOf(id) < 0) kn.push(id)
                dashOrder = kn
            }
            // v8.0.0-alpha-hf129: hidden cards. Unknown ids are dropped so a
            // card removed from a future build can't hide a card that exists.
            if (s.dashHidden && Array.isArray(s.dashHidden))
                dashHidden = s.dashHidden.filter(id => dashCardIds.indexOf(id) >= 0)
            // hf131 — unknown values fall back to the default rather than
            // handing ZenWeather a font name it has never heard of.
            if (["material", "emoji", "nerd"].indexOf(s.weatherIconStyle) >= 0)
                weatherIconStyle = s.weatherIconStyle
            if (["condition", "accent"].indexOf(s.weatherIconTint) >= 0)   // hf132
                weatherIconTint = s.weatherIconTint
            if (s.qsOrder && Array.isArray(s.qsOrder)) {
                // keep only known ids, then append any missing (forward-compat)
                const known = s.qsOrder.filter(id => qsSectionIds.indexOf(id) >= 0)
                for (const id of qsSectionIds) if (known.indexOf(id) < 0) known.push(id)
                qsOrder = known
            }
            if (typeof s.shellLook === "string") shellLook = s.shellLook
            if (typeof s.lookApplyBar === "boolean") lookApplyBar = s.lookApplyBar
            if (typeof s.lookApplyControlPanel === "boolean") lookApplyControlPanel = s.lookApplyControlPanel
            if (typeof s.lookApplyStartMenu === "boolean") lookApplyStartMenu = s.lookApplyStartMenu
            if (typeof s.lookApplyDock === "boolean") lookApplyDock = s.lookApplyDock
            if (typeof s.lookApplyNotifications === "boolean") lookApplyNotifications = s.lookApplyNotifications
            if (typeof s.lookApplyOsd === "boolean") lookApplyOsd = s.lookApplyOsd
            if (typeof s.dashOpacity === "number") dashOpacity = Math.max(0.1, Math.min(1.0, s.dashOpacity))
            if (typeof s.notificationOpacity === "number") notificationOpacity = Math.max(0.1, Math.min(1.0, s.notificationOpacity))
            if (typeof s.glassStrength === "number") glassStrength = Math.max(0.0, Math.min(1.0, s.glassStrength))   // hf144
            if (typeof s.monoIcons === "boolean") monoIcons = s.monoIcons   // hf146
            if (typeof s.taskbarIconBackgrounds === "boolean") taskbarIconBackgrounds = s.taskbarIconBackgrounds   // hf178
            if (typeof s.startMenuOpacity === "number") startMenuOpacity = Math.max(0.1, Math.min(1.0, s.startMenuOpacity))
            if (typeof s.controlPanelOpacity === "number") controlPanelOpacity = Math.max(0.1, Math.min(1.0, s.controlPanelOpacity))
            if (typeof s.taskbarOpacity === "number") taskbarOpacity = Math.max(0.0, Math.min(1.0, s.taskbarOpacity))   // hf181: 0 is legal here
            if (typeof s.taskbarBarOpacity === "number") taskbarBarOpacity = Math.max(0.0, Math.min(1.0, s.taskbarBarOpacity))   // hf182
            if (typeof s.taskbarLinkSurfaces === "boolean") taskbarLinkSurfaces = s.taskbarLinkSurfaces   // hf182
            if (typeof s.taskbarIconScale === "number") taskbarIconScale = Math.max(0.6, Math.min(1.4, s.taskbarIconScale))   // hf182
            if (typeof s.borderEnabled === "boolean") borderEnabled = s.borderEnabled
            if (s.borderWidth) borderWidth = s.borderWidth
            if (s.borderColor) borderColor = s.borderColor
            // v6.16.4.12.7 (Tachiagari): start-button border tint
            if (typeof s.startButtonUseBorderColor === "boolean")
                startButtonUseBorderColor = s.startButtonUseBorderColor
            if (typeof s.startButtonBorderWidth === "number")
                startButtonBorderWidth = Math.max(0, Math.min(4, s.startButtonBorderWidth))
            if (typeof s.bgOverrideEnabled === "boolean") bgOverrideEnabled = s.bgOverrideEnabled
            if (s.bgOverrideColor) bgOverrideColor = s.bgOverrideColor
            if (s.bgOverrideOpacity !== undefined) bgOverrideOpacity = s.bgOverrideOpacity
            // v6.6
            if (typeof s.clockFormatIndex === "number") clockFormatIndex = s.clockFormatIndex
            if (s.workspaceFormat) workspaceFormat = s.workspaceFormat
            if (s.fontFamilyId) fontFamilyId = s.fontFamilyId
            // v6.8
            if (typeof s.workspaceLimit === "number") workspaceLimit = s.workspaceLimit

            // v7.0.0-alpha.4 (StartMenu V2)
            if (typeof s.pinnedGridCols === "number") pinnedGridCols = s.pinnedGridCols
            if (typeof s.pinnedGridRows === "number") pinnedGridRows = s.pinnedGridRows

            // v7.0.0-alpha.4-hf2
            if (typeof s.startMenuBorderMode === "string") startMenuBorderMode = s.startMenuBorderMode
            // v6.10
            if (s.barTargetDisplay) barTargetDisplay = s.barTargetDisplay
            // v6.11
            if (typeof s.startButtonIconSize === "number") startButtonIconSize = s.startButtonIconSize
            // v6.16.2
            if (typeof s.startButtonLogoMode === "string") startButtonLogoMode = s.startButtonLogoMode
            if (typeof s.startButtonLogoPath === "string") startButtonLogoPath = s.startButtonLogoPath
            if (typeof s.startButtonLogoTint === "boolean") startButtonLogoTint = s.startButtonLogoTint
            // v6.16.3.5: bundled logo selection
            if (typeof s.startButtonLogoBuiltinId === "string") startButtonLogoBuiltinId = s.startButtonLogoBuiltinId
            // v6.16.3.6: user gender for lock screen
            if (typeof s.userGender === "string") userGender = s.userGender
            // v6.16.3.7: widget scale multiplier (clamped on load)
            if (typeof s.widgetScale === "number")
                widgetScale = Math.max(0.5, Math.min(2.0, s.widgetScale))
            // v6.16.3.8: idle/lid settings (clamped)
            if (typeof s.idleLockSeconds === "number")
                idleLockSeconds = Math.max(0, Math.min(86400, Math.floor(s.idleLockSeconds)))
            if (typeof s.idleSleepSeconds === "number")
                idleSleepSeconds = Math.max(0, Math.min(86400, Math.floor(s.idleSleepSeconds)))
            if (typeof s.lidCloseAction === "string"
                && ["suspend", "lock", "ignore"].indexOf(s.lidCloseAction) >= 0)
                lidCloseAction = s.lidCloseAction
            if (typeof s.workspaceDotActive === "number") workspaceDotActive = s.workspaceDotActive
            if (typeof s.workspaceDotInactive === "number") workspaceDotInactive = s.workspaceDotInactive
            if (typeof s.workspaceFontActive === "number") workspaceFontActive = s.workspaceFontActive
            if (typeof s.workspaceFontInactive === "number") workspaceFontInactive = s.workspaceFontInactive
            // v6.15.1: Restore Theme properties that need to survive restart
            if (s.barLayout && typeof s.barLayout === "object") {
                // v6.16.0 MIGRATION: inject "battery" into right row if the
                // saved layout predates v6.16.0. Without this, upgraders
                // never see the battery module — their existing panel-state.json
                // overrides the new Theme.qml default that has "battery" in it.
                //
                // Insert position: before "notifications" if present (natural
                // spot next to tray/clock), else append to end of right row.
                // Migration is idempotent (checks for existing "battery") and
                // self-stamps with saveVersion so it only runs once per save.
                var _layout = s.barLayout
                var _savedVer = s.saveVersion || ""
                var _needsBatt = !_savedVer || _savedVer < "6.16.0"
                if (_needsBatt && _layout.right && _layout.right.indexOf("battery") < 0) {
                    var _right = _layout.right.slice()
                    var _notifIdx = _right.indexOf("notifications")
                    if (_notifIdx >= 0) {
                        _right.splice(_notifIdx, 0, "battery")
                    } else {
                        _right.push("battery")
                    }
                    _layout.right = _right
                    console.log("[PanelState] v6.16.0 migration: injected 'battery' into barLayout.right")
                    // Persist immediately so this runs only once
                    Qt.callLater(root.saveState)
                }

                // v7.0.0-alpha.13: workflow profile badge migration
                var _needsWorkflow = !_savedVer || _savedVer < "7.0.0-alpha.13"
                if (_needsWorkflow && _layout.right && _layout.right.indexOf("workflow") < 0) {
                    var _right2 = _layout.right.slice()
                    var _trayIdx = _right2.indexOf("tray")
                    if (_trayIdx >= 0) {
                        _right2.splice(_trayIdx + 1, 0, "workflow")
                    } else {
                        _right2.push("workflow")
                    }
                    _layout.right = _right2
                    console.log("[PanelState] v7.0.0-alpha.13 migration: injected 'workflow' into barLayout.right")
                    Qt.callLater(root.saveState)
                }

                // v7.0.0-beta.1-hf42 migration: inject the daily-use
                // productivity modules ("quicknotes" + "titletranslator")
                // into existing barLayouts. User report from hf41:
                //   "sa panel kala ko ba add mo yun mga toggle like
                //    translator and kung panu sila gamitn pala and
                //    sticky notes ?"
                //
                // hf39 created the modules + registered them in Bar.qml's
                // switch, but never added them to default barLayout, so
                // upgraders had to manually add via Settings → Panel.
                // We auto-inject the 2 most-useful ones here.
                //
                // The other 3 (focusspaces, networkpulse, smartdim) stay
                // OPT-IN — they're available in the +Add picker but not
                // forced into the bar, since their use cases are more
                // niche and Smart Dim should never be enabled without
                // the user knowing about it.
                //
                // Idempotent (checks for existing tokens).
                var _needsHf42 = !_savedVer || _savedVer < "7.0.0-beta.1-hf42"
                if (_needsHf42 && _layout.right) {
                    var _right3 = _layout.right.slice()
                    var _changed = false
                    // Insert quicknotes after clipboard, or before notifications, or at end
                    if (_right3.indexOf("quicknotes") < 0) {
                        var _clipIdx = _right3.indexOf("clipboard")
                        var _notifIdx2 = _right3.indexOf("notifications")
                        if (_clipIdx >= 0) {
                            _right3.splice(_clipIdx + 1, 0, "quicknotes")
                        } else if (_notifIdx2 >= 0) {
                            _right3.splice(_notifIdx2, 0, "quicknotes")
                        } else {
                            _right3.push("quicknotes")
                        }
                        _changed = true
                    }
                    // Insert titletranslator after quicknotes (or after clipboard)
                    if (_right3.indexOf("titletranslator") < 0) {
                        var _qnIdx = _right3.indexOf("quicknotes")
                        if (_qnIdx >= 0) {
                            _right3.splice(_qnIdx + 1, 0, "titletranslator")
                        } else {
                            _right3.push("titletranslator")
                        }
                        _changed = true
                    }
                    if (_changed) {
                        _layout.right = _right3
                        console.log("[PanelState] v7.0.0-beta.1-hf42 migration: "
                                  + "injected 'quicknotes' + 'titletranslator' into barLayout.right")
                        Qt.callLater(root.saveState)
                    }
                }
                Theme.barLayout = _layout
            }
            if (typeof s.barOpacity === "number") Theme.barOpacity = s.barOpacity
            if (typeof s.barRadius === "number") Theme.barRadius = s.barRadius
            if (s.styleMode) Theme.styleMode = s.styleMode
            return true
        } catch (e) {
            console.error("[PanelState] hf110: state applied only partially:", e)
            return false
        }
    }

    Process { id: stateSaver; running: false }

    // v7.0.0-beta.1-hf97 — last-known-good backup. Whenever a non-empty
    // panel-state.json loads cleanly we stash a .bak copy. If a later
    // boot ever loses the race (or hits a truncated write) and
    // onLoadFailed fires, the .bak is the user's fallback. We only back
    // up real payloads (length > 2) so an empty/"{}" file can never
    // overwrite a good backup. Strictly additive — wala tayong binawasan.
    Process { id: stateBackup; running: false }
    // v8.0.0-alpha-hf121 — the restore path used to copy .bak to a
    // `.restored` file and stop there. Nothing ever read it, so a corrupted
    // panel-state.json meant defaults on every boot, for ever, in silence.
    // Now it swaps the good backup in and reloads.
    Process {
        id: stateRestore
        running: false
        onExited: {
            console.warn("[PanelState] hf121: panel-state.json restored from .bak — reloading")
            stateLoader.reload()
        }
    }
    function _backupState() {
        stateBackup.command = ["bash", "-c",
            "cp -f '" + statePath + "' '" + statePath + ".bak' 2>/dev/null || true"]
        stateBackup.running = true
    }

    FileView {
        id: stateLoader
        path: root.statePath
        blockLoading: false
        onLoaded: {
            // hf97: capture the text once, apply it, THEN flip _loaded so
            // _doSaveState is allowed to run. Ordering matters — _loaded
            // must go true only after applyState has populated the real
            // values, else the next queued save would still write defaults.
            const t = this.text()
            const ok = root.applyState(t)
            if (!ok && t && t.trim().length > 2 && !root._restoreTried) {
                // A real payload we could not fully apply — a truncated write, or
                // an installer migration that produced invalid JSON (the hf121
                // calendar-sed bug). Saves stay suppressed so we never write
                // defaults over it. Swap in the last known-good backup, keep the
                // broken file for inspection, and reload. `_restoreTried` means
                // this happens at most once per session, so a bad .bak can't loop.
                root._loadDegraded = true
                root._restoreTried = true
                console.warn("[PanelState] hf121: bad panel-state.json — restoring from .bak")
                stateRestore.command = ["bash", "-c",
                    "set -e; [ -s '" + statePath + ".bak' ] || exit 1; "
                    + "cp -f '" + statePath + "' '" + statePath + ".corrupt' 2>/dev/null || true; "
                    + "cp -f '" + statePath + ".bak' '" + statePath + "'"]
                stateRestore.running = true
            } else if (ok) {
                root._loadDegraded = false
            }
            if (ok && t && t.trim().length > 2) root._backupState()
            root._loaded = true
            // v6.16.2.3.1: Signal the shell that we've loaded. Used to
            // gate nuclear-restart logic against startup transitions.
            root.panelStateLoaded()
        }
        onLoadFailed: {
            // hf97: first run (file not created yet) or a transient read
            // error. We still flip _loaded so the user can save fresh
            // settings; the .bak from the previous good boot is the
            // recovery path if this was transient. Mirrors DockState idiom.
            root._loaded = true
            root.panelStateLoaded()
        }
    }

    function setMode(mode) {
        if (mode === "fullwidth" || mode === "floating" || mode === "island") {
            panelMode = mode
            saveState()
        }
    }

    function setBorder(enabled, width, color) {
        borderEnabled = enabled
        borderWidth = width
        borderColor = color
        saveState()
    }

    function setBackground(enabled, color, opacity) {
        bgOverrideEnabled = enabled
        bgOverrideColor = color
        bgOverrideOpacity = opacity
        saveState()
    }

    function resetDefaults() {
        panelMode = "fullwidth"
        panelPosition = "bottom"
        barHeight = 60
        barAutoHeight = false
        barAutoHeightPadding = 8
        barFitContents = false
        barContentPaddingV = 4
        barModuleScale = 1.0
        settingsHoverStyle = "rounded"
        controlPanelPosition = "center"
        controlPanelEdgeMargin = 12
        controlPanelAttached = false
        qsOrder = qsSectionIds.slice()
        qsProfileAtBottom = false
        dashOrder = dashCardIds.slice()
        dashCards = ({})
        dashHidden = []
        weatherIconStyle = "material"          // hf131
        weatherIconTint = "condition"          // hf132
        shellLook = "zen"
        lookApplyBar = true
        lookApplyControlPanel = true
        lookApplyStartMenu = true
        lookApplyDock = true
        lookApplyNotifications = true
        lookApplyOsd = false
        borderEnabled = false
        borderWidth = 1
        borderColor = "#414868"
        bgOverrideEnabled = false
        bgOverrideColor = "#1a1b26"
        bgOverrideOpacity = 0.85
        saveState()
    }

    // Called by StartMenu.qml when clicked. x/y are in GLOBAL screen
    // coordinates (i.e. mapped through the button's parent chain).
    // sw/sh are the screen dimensions (from QsWindow.window.screen).
    function reportStartButtonPosition(x: real, y: real, sw: int, sh: int) {
        startButtonCenterX = x
        startButtonCenterY = y
        if (sw > 0) screenWidth = sw
        if (sh > 0) screenHeight = sh
    }

    // v7.0.0-alpha.6-hf4: Same pattern as reportStartButtonPosition,
    // for the clipboard module. Called by ClipboardModule.qml on
    // click, just before triggering the IPC. shell.qml's
    // clipboardWindow uses centerX/rightX to anchor the panel under
    // (or over) the icon — so the panel pops up directly from where
    // the user clicked, regardless of whether they put the clipboard
    // module on the left, center, or right of their bar.
    function reportClipboardButtonPosition(centerX: real, rightX: real) {
        clipboardButtonCenterX = centerX
        clipboardButtonRightX = rightX
    }

    // v6.16.4.12.6.53 (Hiraki hotfix 1): Called by Clock.qml when
    // clicked, just before the calendar opens. centerX is the clock
    // module's center-X in GLOBAL (screen) coordinates, rightX is its
    // right-edge X. shell.qml's calendarWindow uses rightX to set
    // `margins.right` so the popup's right edge aligns with the
    // clock's right edge — i.e. the calendar appears directly above
    // (or below for top bars) the clock instead of pinned to the
    // screen edge. sw is the screen width, used for clamping logic.
    function reportClockPosition(centerX: real, rightX: real, sw: int) {
        clockCenterX    = centerX
        clockRightEdgeX = rightX
        if (sw > 0) screenWidth = sw
    }

    // ── v6.16.4.12.7 (Tachiagari): Popup edge helpers ──
    // ── v6.16.4.12.7.1: Extended to 4 directions ──
    // Convenience values for any PopupWindow / PanelWindow that emerges
    // FROM the bar — tooltips, drawer popups, calendar, music strings,
    // etc. Centralising the policy here means we set position once on
    // PanelState and every popup follows.
    //
    // The mapping (from a popup's viewpoint, "where to attach to the
    // bar module" and "which way to grow"):
    //
    //   Bar at BOTTOM → popup attaches to module's TOP, grows UP
    //   Bar at TOP    → popup attaches to module's BOTTOM, grows DOWN
    //   Bar at LEFT   → popup attaches to module's RIGHT, grows RIGHT
    //   Bar at RIGHT  → popup attaches to module's LEFT, grows LEFT
    //
    // In every case the popup grows AWAY from the bar — so it never
    // gets clipped by the screen edge the bar is anchored to, and
    // never visually fights with the bar by overlapping it.
    //
    // Edges constants come from Quickshell:
    //   Edges.Top    = 1
    //   Edges.Bottom = 2
    //   Edges.Left   = 4
    //   Edges.Right  = 8
    // Why these values: the underlying enum is a bitflag (so callers
    // can OR them for corner anchoring), but our popups always pick
    // exactly one cardinal edge. We expose them as `int` so consumers
    // can `import Quickshell` and bind directly without re-deriving.
    //
    // Two parallel helpers because Quickshell's PopupWindow takes
    // both `anchor.edges` and `anchor.gravity` and they encode
    // slightly different things (anchor point vs growth direction).
    // For our popup pattern they're always the same value, but we
    // name them properly so consumer code stays readable.
    readonly property int popupAnchorEdges: {
        if (isTop)    return 2   // Edges.Bottom
        if (isLeft)   return 8   // Edges.Right
        if (isRight)  return 4   // Edges.Left
        return 1                  // Edges.Top (default — bottom bar)
    }
    readonly property int popupAnchorGravity: {
        if (isTop)    return 2   // Edges.Bottom
        if (isLeft)   return 8   // Edges.Right
        if (isRight)  return 4   // Edges.Left
        return 1                  // Edges.Top (default — bottom bar)
    }

    Component.onCompleted: {
        stateLoader.reload()
    }

    // v7.0.0-beta.1-hf45 — Sync panel-state.json when Theme props
    // change from ANY source.
    //
    // BUG FIX: Until hf45, bar layout edits made by external scripts
    // (e.g. ~/.local/bin/zen-bar-add-powerbadge.sh writing to
    // bar-layout.json) updated `Theme.barLayout` via `Theme.reloadBarLayout()`,
    // but PanelState.saveState() was NEVER called to mirror the change
    // into panel-state.json.
    //
    // On the NEXT shell launch, applyState() reads panel-state.json
    // and OVERWRITES Theme.barLayout with the stale value from before
    // the toggle. Result: user toggles a module on, restarts shell,
    // toggle appears to "revert" because panel-state.json's stale
    // barLayout wins.
    //
    // Same applies to ANY external mutation of Theme.barLayout /
    // barOpacity / barRadius / styleMode — without this watcher,
    // panel-state.json silently goes stale.
    //
    // Watcher approach: PanelState now monitors Theme's relevant
    // properties via Connections + onXxxChanged. Each change schedules
    // a debounced saveState() — same 200ms debounce timer used by
    // direct saveState() calls, so rapid drags still result in one
    // disk write.
    //
    // Initial-load guard: we don't fire saveState() during the brief
    // moment between PanelState construction and stateLoader's
    // onLoaded — that would write the DEFAULT Theme.barLayout to
    // disk BEFORE applyState had a chance to restore the user's saved
    // value. The `panelStateLoaded` signal flips a flag once safe.
    property bool _hf45_loaded: false

    Connections {
        target: root
        function onPanelStateLoaded() {
            // Loaded — from now on Theme changes are user-initiated
            // and should be persisted.
            root._hf45_loaded = true
        }
    }

    Connections {
        target: (typeof Theme !== "undefined") ? Theme : null
        ignoreUnknownSignals: true
        function onBarLayoutChanged() {
            if (root._hf45_loaded) {
                console.log("[PanelState] hf45: Theme.barLayout changed externally, syncing to panel-state.json")
                root.saveState()
            }
        }
        function onBarOpacityChanged() {
            if (root._hf45_loaded) root.saveState()
        }
        function onBarRadiusChanged() {
            if (root._hf45_loaded) root.saveState()
        }
        function onStyleModeChanged() {
            if (root._hf45_loaded) root.saveState()
        }
    }

    // ════════════════════════════════════════════════════════════════
    // v7.0.0-beta.1-hf98 — SESSION LOCK WATCHER (music-string re-align)
    // ════════════════════════════════════════════════════════════════
    // Why this lives here: PanelState is the session/panel singleton that
    // BOTH music-string overlays (horizontal stringsWindow + vertical
    // stringsWindowV) already watch via `Connections { target: PanelState }`.
    // Putting one lock detector here = a SINGLE pgrep poll for the whole
    // shell (no per-monitor duplication across Paul's 3 displays), and the
    // overlays get a clean re-settle trigger through a signal shaped exactly
    // like the panelModeChanged one they already handle.
    //
    // Bug it fixes — Paul: "kapag nag log off / lock tas nag login ulit yun
    // music string ko napupunta sa dulo, hindi naka-align sa proper place."
    //
    // A lock→unlock cycle tears down NO shell window. The bar window and the
    // strings overlay stay alive with positionReady=true, so when the desktop
    // is revealed the bar re-publishes musicSlotLocalX / barWindowLeft
    // asynchronously and the overlay's `Behavior on margins.left` glides
    // through the inconsistent intermediates → a visible swing that can land
    // off-slot. hf97 added a reactive bigJump guard, but it only fires when a
    // watched coordinate NUMERICALLY changes — if the bar republishes the
    // same value, or drifts < 200px, the guard misses and the string sticks
    // in the wrong place.
    //
    // hf98 makes it deterministic: detect the unlock edge directly by watching
    // the hyprlock process. On the locked→unlocked edge we emit
    // sessionUnlocked(); the overlays then do a full clean re-settle
    // (positionReady=false → Behavior disabled → SNAP, not glide) just like a
    // panel-mode change. Covers Zen-initiated locks, hypridle locks, AND
    // suspend/resume (which relocks), because all of them run hyprlock.
    //
    // Adaptive interval: poll slowly (1500ms) while unlocked to stay cheap,
    // fast (400ms) while locked so the unlock snaps in promptly behind
    // hyprlock before the user even sees the bar. Strictly additive — no
    // existing PanelState behaviour is touched.

    // true while a hyprlock instance is running. Runtime-only, never saved.
    property bool sessionLocked: false
    // Emitted once on each locked→unlocked edge (hyprlock just exited).
    signal sessionUnlocked()

    Timer {
        id: lockWatchTimer
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: lockProbe.running = true
    }

    Process {
        id: lockProbe
        running: false
        // Always echoes exactly one line so the parser has a clean signal,
        // regardless of pgrep's exit code.
        command: ["bash", "-c",
            "pgrep -x hyprlock >/dev/null 2>&1 && echo locked || echo unlocked"]
        stdout: SplitParser {
            onRead: data => {
                const nowLocked = (data.trim() === "locked")
                if (nowLocked === root.sessionLocked) return   // no edge
                const wasLocked = root.sessionLocked
                root.sessionLocked = nowLocked
                if (nowLocked) {
                    // Just locked → speed up so we catch the unlock fast.
                    lockWatchTimer.interval = 400
                } else if (wasLocked) {
                    // Unlock edge → back to the cheap cadence and tell the
                    // music-string overlays to re-align cleanly.
                    lockWatchTimer.interval = 1500
                    root.sessionUnlocked()
                }
            }
        }
    }
}
