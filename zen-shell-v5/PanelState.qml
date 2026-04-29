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
    // "bottom" (default) or "top". Left/right reserved for future vertical bar.
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
        if (panelPosition === "top") return 0
        return panelMode === "fullwidth" ? 0 : 8
    }

    // v6.16.4.12: Top margin (only used when position is "top")
    property int panelMarginTop: {
        if (panelPosition === "bottom") return 0
        return panelMode === "fullwidth" ? 0 : 8
    }

    // v6.16.4.12: Convenience — true when bar is at the top of screen
    readonly property bool isTop: panelPosition === "top"

    // ── Border ──
    property bool borderEnabled: false
    property int borderWidth: 1
    property color borderColor: "#414868"

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

    function saveState() {
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
            if (s.panelPosition && (s.panelPosition === "top" || s.panelPosition === "bottom"))
                panelPosition = s.panelPosition
            if (s.barHeight) barHeight = s.barHeight
            if (typeof s.borderEnabled === "boolean") borderEnabled = s.borderEnabled
            if (s.borderWidth) borderWidth = s.borderWidth
            if (s.borderColor) borderColor = s.borderColor
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

    Component.onCompleted: {
        stateLoader.reload()
    }
}
