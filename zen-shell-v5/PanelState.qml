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

    // v6.10: Bar target display — "all", "primary", or specific monitor name
    property string barTargetDisplay: "all"

    // v6.11: Start button icon size (default 26)
    property int startButtonIconSize: 26

    // v6.16.2.3: Calendar visibility state — shared singleton prop so
    // Clock.qml (loaded in Bar context) can toggle without needing IPC.
    // shell.qml binds calendarWindow.visible to this property.
    property bool calendarVisible: false
    function toggleCalendar() { calendarVisible = !calendarVisible }
    function closeCalendar()  { calendarVisible = false }
    function openCalendar()   { calendarVisible = true }

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

    function _doSaveState() {
        const state = {
            // v6.16.0: version stamp used by applyState migration checks.
            // Bump this when introducing a non-idempotent data migration.
            saveVersion: "6.16.0",
            panelMode: panelMode,
            panelPosition: panelPosition,
            barHeight: barHeight,
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
        const json = JSON.stringify(state, null, 2)
        stateSaver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSEOF'\n" + json + "\nZSEOF"]
        stateSaver.running = true
        stateChanged()
    }

    function applyState(text) {
        if (!text) return
        try {
            const s = JSON.parse(text)
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
            if (s.panelPosition && (s.panelPosition === "top" || s.panelPosition === "bottom")) {
                panelPosition = s.panelPosition
            } else if (s.panelPosition === "left" || s.panelPosition === "right") {
                panelPosition = "bottom"
                Qt.callLater(saveState)   // persist the migration
            }
            if (s.barHeight) barHeight = s.barHeight
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
                Theme.barLayout = _layout
            }
            if (typeof s.barOpacity === "number") Theme.barOpacity = s.barOpacity
            if (typeof s.barRadius === "number") Theme.barRadius = s.barRadius
            if (s.styleMode) Theme.styleMode = s.styleMode
        } catch (e) {
            console.error("[PanelState] Parse error:", e)
        }
    }

    Process { id: stateSaver; running: false }

    FileView {
        id: stateLoader
        path: root.statePath
        blockLoading: false
        onLoaded: {
            root.applyState(this.text())
            // v6.16.2.3.1: Signal the shell that we've loaded. Used to
            // gate nuclear-restart logic against startup transitions.
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
}
