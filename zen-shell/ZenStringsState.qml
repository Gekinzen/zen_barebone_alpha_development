pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ZenStringsState v6.15 — State for ZenStrings music module
 *
 * Kapag enabled = true, yung music module sa bar ay magiging ZenStrings.
 * Kapag may nag-play na track → animated bezier (cava-reactive).
 * Kapag wala / paused → static decorative line (always visible).
 *
 * Color modes:
 *   "theme"   = auto blue→purple from ThemeService (default)
 *   "synced"  = specific ThemeService color keys
 *   "custom"  = user-defined hex colors
 *
 * Persists to ~/.config/quickshell/zen-shell/strings-state.json
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/strings-state.json"

    // ── Master toggle — replaces music widget when true ──
    property bool enabled: false

    // ── Cava segments ──
    property int segments: 10

    // ── Stroke thickness ──
    property real strokeWidth: 4.0

    // ── Beat bow amplitude — how far curves bow per beat ──
    // Does NOT affect string position or bar slot height
    property int curveHeight: 60

    // ── Vertical padding — overflow space above/below bar slot ──
    // 0 = auto: uses curveHeight so curves always have room to bow
    // >0 = fixed px each side (above + below)
    property int verticalPadding: 0

    // ── Width of string inside bar slot ──
    // 0 = fill available slot width (recommended)
    // >0 = fixed px centered in slot
    property int stringLength: 0

    // ── Glow ──
    property bool glowEnabled: true
    property int glowRadius: 12

    // ── Color mode ──
    property string colorMode: "theme"
    property string syncedColor1Key: "blue"
    property string syncedColor2Key: "purple"
    property string customColor1: "#ff9e64"
    property string customColor2: "#cec991"

    // ── Live audio state — written by MusicStrings, read by overlay ──
    property bool isAudioActive: false
    property var  cavaData: []

    // v6.15.1: Track info shared for stringsWindow hover tooltip
    property string trackInfo: ""
    property bool mediaPlaying: false
    property bool cavaHasAudio: false

    // ── Music slot screen position — written by Bar.qml, read by overlay ──
    // musicSlotLocalX: X of music slot relative to Bar rectangle
    // musicSlotLocalWidth: width of music slot
    // barWindowLeft: bar window's left edge in screen coords (mode-aware)
    // All written at runtime — overlay PanelWindow reads these.
    property real musicSlotLocalX: -1
    property real musicSlotLocalWidth: 200
    property real barWindowLeft: 0
    // v7.0.0-beta.1-hf98f — island bar's hug-content width, published by
    // barWindow. The strings overlay centres itself with this PLUS its own
    // screen width, instead of trusting a pre-baked barWindowLeft that could
    // be computed against a transient-0 screen width during a lock→unlock
    // (the "island-only far-left after login" bug). -1 = not yet published.
    property real barIslandWidth: -1

    // v7.0.0-beta.1-hf95.5: vertical-bar counterparts. On a vertical
    // (left/right) bar there is no horizontal music slot — the slot
    // stacks in the column instead — so the strings overlay needs the
    // slot's Y position + height to center the (rotated) string on it.
    // Written by BarVertical.qml's music host, read by the vertical
    // strings overlay (stringsWindowV) in shell.qml. The vertical bar
    // window is anchored full-height at the screen edge, so musicSlotLocalY
    // doubles as the slot's screen-space Y. Defaults: -1 / 0 keep the
    // overlay hidden until a real position is reported.
    property real musicSlotLocalY: -1
    property real musicSlotLocalHeight: 0

    // v7.0.0-beta.1-hf95.7: global vertical-bar scale-to-fit factor,
    // written by BarVertical (1.0 = fits, <1 = column was scaled down to
    // fit). The vertical strings overlay multiplies the string by this so
    // it shrinks in sync with the bar's modules.
    property real verticalFitScale: 1.0

    // v7.0.0-beta.1-hf95.8: the vertical string is SHORTER than the
    // horizontal one. On a vertical bar a full-length string sprawls over
    // neighbouring modules, so we cap it to a compact run (~4 module
    // heights) and never longer than the configured stringLength. Both
    // the BarVertical music slot (which reserves this as its height so the
    // string gets its own space) and the strings overlay read this single
    // value, so they always agree. It tracks Theme.moduleHeight, so it
    // also shrinks when the bar scales — "shortens by itself".
    readonly property real verticalStringLength: {
        const base = stringLength > 0 ? stringLength : 200
        const cap = (typeof Theme !== "undefined" && Theme.moduleHeight > 0)
                    ? Theme.moduleHeight * 4 : 160
        return Math.max(40, Math.min(base, cap))
    }

    // v6.15.2: Position readiness signal.
    // Written by stringsWindow (shell.qml) — true when the music slot
    // position has been stable for 600ms (i.e. bar has finished its
    // initial layout AND any runtime reflow from sysrow/taskbar loads).
    // Read by MusicStrings.qml to show a Loading placeholder in the
    // bar slot while positionReady = false, so the user doesn't see
    // the string visualizer floating at the wrong spot on login.
    // Runtime-only — not persisted.
    property bool positionReady: false

    // ── v8.0.0-alpha-hf118: ONE screen owns the strings ─────────────
    //
    // musicSlotLocalX / musicSlotLocalWidth are BAR-LOCAL coordinates, but
    // they live here as ONE global pair. With barTargetDisplay = "all" there
    // is one Bar per monitor, and every one of them writes that pair.
    //
    //   fullwidth, 3440px screen: centred 280px slot → localX = 1580
    //   fullwidth, 1920px screen: centred 280px slot → localX =  820
    //
    // The two bars overwrite each other; the 760px swing trips shell.qml's
    // `bigJump` guard (threshold 200) and positionReady re-settles forever.
    // The bar hangs on "Loading…".
    //
    // Island mode hides the bug completely: the bar hugs its content, so both
    // monitors produce the SAME bar width and therefore the same local X. The
    // two writers agree by accident. That is exactly why strings worked in
    // island and died in fullwidth / floating.
    //
    // Fix: one screen owns the strings. Deterministic — no claim, no
    // construction-order race. The other bars fall back to MusicWidget.
    readonly property string stringScreen: {
        const t = PanelState.barTargetDisplay
        if (t === "all" || t === "primary")
            return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
        return t
    }
    function ownsStrings(name) { return name.length > 0 && name === stringScreen }

    // Transition log. Cheap (fires only on edges) and this is an alpha:
    //   qs -c zen-shell 2>&1 | grep ZenStrings
    onPositionReadyChanged: console.log("[ZenStrings] positionReady →", positionReady,
                                        "screen=" + (stringScreen.length ? stringScreen : "<none>"),
                                        "slotX=" + musicSlotLocalX,
                                        "slotW=" + musicSlotLocalWidth)

    // ── Derived colors (used by ZenStrings + ZenRope + overlay) ──
    // Automatically computed from colorMode + theme.
    function _resolveKey(key) {
        switch(key) {
            case "red":    return ThemeService.red
            case "orange": return ThemeService.orange
            case "yellow": return ThemeService.yellow
            case "green":  return ThemeService.green
            case "aqua":   return ThemeService.aqua
            case "blue":   return ThemeService.blue
            case "purple": return ThemeService.purple
            case "fg":     return ThemeService.fg
            case "grey0":  return ThemeService.grey0
            default:       return ThemeService.blue
        }
    }
    // v8.0.0-alpha-hf120 — never hand a #rrggbbaa string to Qt's color type.
    //
    // Qt parses 8-hex as #AARRGGBB (alpha first). Until hf120 the picker
    // committed #RRGGBBAA, so any custom colour saved before then is stored
    // with a trailing "ff" and coerces to the wrong colour. Strip to 6 hex
    // here and the old values heal themselves on the next read.
    function _rgb6(v) {
        const h = ("" + v).replace(/^#/, "")
        return "#" + (h.length >= 6 ? h.substring(0, 6) : "ffffff")
    }

    readonly property color color1: {
        if (colorMode === "custom") return _rgb6(customColor1)
        if (colorMode === "theme")  return ThemeService.blue
        return _resolveKey(syncedColor1Key)
    }
    readonly property color color2: {
        if (colorMode === "custom") return _rgb6(customColor2)
        if (colorMode === "theme")  return ThemeService.purple
        return _resolveKey(syncedColor2Key)
    }


    // ── Screenshot rope (carried from v6.14.2) ──
    // v6.15.1: reverted to flicko-original values — 10 segments × 5px
    // rest length gives smooth catenary drape. Previous 30×50 was too
    // stiff — rope looked like rigid springs instead of soft string.
    property bool screenshotRopeEnabled: true
    property int ropeSegments: 10
    property int ropeSegmentLength: 5

    // ── v8.0.0-alpha-hf129 — FREEZE FRAME ──
    //
    // Grab the whole focused monitor with grim BEFORE the overlay window maps,
    // paint that still behind the ropes, and crop it at capture time instead of
    // re-grimming the live screen 300ms later.
    //
    // Why it matters: the overlay takes exclusive keyboard focus the instant it
    // appears, which dismisses every surface that holds a HyprlandFocusGrab —
    // the Control Center, the Start Menu, dock popups, the tray menu. Those are
    // exactly the things you usually want a picture of. Freezing first means
    // they are already in the pixels. "Para walang takas."
    //
    // Costs one full-monitor PNG in tmpfs per screenshot (deleted on the next
    // one). Off = the hf128 behaviour, unchanged, for anyone who wants a live
    // grab or is short on /tmp.
    property bool screenshotFreeze: true

    // ── v8.0.0-alpha-hf130 — ROPE ORIGIN ──
    //
    // "band"    (default) — the monitor is split into three vertical bands and
    //                       the four ropes pin to the corners of whichever band
    //                       the cursor is in. The rig follows you instead of
    //                       always dangling from the far corner of an ultrawide.
    // "corners" (classic) — the pre-hf130 look: anchors welded to the four
    //                       screen corners, so a rope can span 3440px.
    property string ropeOriginMode: "band"

    // ── v7.0.0-beta.1-hf82j — SCREENSHOT ROPE COLORS ──
    //
    // User request:
    //   "yung sa string colors pati screenshot ropes dapat pwd din
    //    palitan ng colors and yung colors dapat accurate yun coloring"
    //
    // Before hf82j: ScreenshotRope used `ZenStringsState.color1` —
    // sharing whatever the music-strings color was. There was no way
    // to set a different color for the rope, and the "theme" mode
    // forced ThemeService.blue regardless of user pick.
    //
    // hf82j adds independent rope color config that mirrors the
    // strings color shape:
    //   - ropeColorMode: "inherit" | "theme" | "synced" | "custom"
    //     - "inherit" (default): use whatever color1 is (preserves
    //       pre-hf82j behavior for users who never touch rope color).
    //     - "theme": fixed accent (ThemeService.blue).
    //     - "synced": pick from palette key (red/orange/.../grey0).
    //     - "custom": user hex string.
    //   - ropeSyncedColorKey: which palette key for "synced".
    //   - ropeCustomColor: hex string for "custom".
    //
    // ScreenshotRope.qml reads `ropeColor` (a new resolved binding
    // below) instead of `color1` directly.
    property string ropeColorMode: "inherit"
    property string ropeSyncedColorKey: "blue"
    property string ropeCustomColor: "#ff9e64"

    // Resolved rope color. Single color (no gradient) because the
    // physics rope is a single stroke, unlike the bezier strings.
    //
    // "accurate" coloring: when ropeColorMode is "custom" or "synced",
    // returns the exact resolved color WITHOUT going through any
    // theme-overridden lookup that might remap the color. ThemeService
    // resolution only kicks in for "theme" and "synced" modes; "custom"
    // is direct hex passthrough.
    readonly property color ropeColor: {
        if (ropeColorMode === "custom")  return _rgb6(ropeCustomColor)
        if (ropeColorMode === "theme")   return ThemeService.blue
        if (ropeColorMode === "synced")  return _resolveKey(ropeSyncedColorKey)
        // "inherit" or any unknown value — fall back to color1
        // (preserves pre-hf82j behavior).
        return color1
    }

    property bool dirty: false

    Timer {
        id: saveTimer; interval: 500; repeat: false
        onTriggered: root.saveState()
    }

    function markDirty() { dirty = true; saveTimer.restart() }

    function saveState() {
        const state = {
            enabled, segments, strokeWidth, curveHeight, verticalPadding, stringLength,
            glowEnabled, glowRadius, colorMode,
            syncedColor1Key, syncedColor2Key,
            customColor1, customColor2,
            screenshotRopeEnabled, ropeSegments, ropeSegmentLength,
            // hf129: persist the freeze-frame toggle
            screenshotFreeze,
            // hf130: persist the rope origin mode
            ropeOriginMode,
            // hf82j: persist rope color config
            ropeColorMode, ropeSyncedColorKey, ropeCustomColor
        }
        const json = JSON.stringify(state, null, 2)
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSVEOF'\n" + json + "\nZSVEOF"]
        saver.running = true
        dirty = false
    }

    Process { id: saver; running: false }

    function loadFromJson(text) {
        if (!text || text.trim().length === 0) return
        try {
            const s = JSON.parse(text)
            if (typeof s.enabled === "boolean") enabled = s.enabled
            if (s.segments !== undefined) segments = s.segments
            if (s.strokeWidth !== undefined) strokeWidth = s.strokeWidth
            if (s.curveHeight !== undefined) curveHeight = s.curveHeight
            if (s.verticalPadding !== undefined) verticalPadding = s.verticalPadding
            if (s.stringLength !== undefined) stringLength = s.stringLength
            if (typeof s.glowEnabled === "boolean") glowEnabled = s.glowEnabled
            if (s.glowRadius !== undefined) glowRadius = s.glowRadius
            if (s.colorMode) colorMode = s.colorMode
            if (s.syncedColor1Key) syncedColor1Key = s.syncedColor1Key
            if (s.syncedColor2Key) syncedColor2Key = s.syncedColor2Key
            // hf120: normalise legacy #rrggbbaa values written by the old picker
            if (s.customColor1) customColor1 = _rgb6(s.customColor1)
            if (s.customColor2) customColor2 = _rgb6(s.customColor2)
            if (typeof s.screenshotRopeEnabled === "boolean") screenshotRopeEnabled = s.screenshotRopeEnabled
            if (typeof s.screenshotFreeze === "boolean") screenshotFreeze = s.screenshotFreeze
            if (s.ropeOriginMode === "band" || s.ropeOriginMode === "corners") ropeOriginMode = s.ropeOriginMode
            if (s.ropeSegments !== undefined) ropeSegments = s.ropeSegments
            if (s.ropeSegmentLength !== undefined) ropeSegmentLength = s.ropeSegmentLength
            // hf82j: rope color config
            if (s.ropeColorMode) ropeColorMode = s.ropeColorMode
            if (s.ropeSyncedColorKey) ropeSyncedColorKey = s.ropeSyncedColorKey
            if (s.ropeCustomColor) ropeCustomColor = _rgb6(s.ropeCustomColor)
        } catch(e) { console.error("[ZenStringsState] Parse error:", e) }
    }

    FileView {
        id: stateFile; path: root.statePath; blockLoading: false
        onLoaded: root.loadFromJson(this.text())
    }

    function resetDefaults() {
        enabled = false; segments = 10; strokeWidth = 4.0
        curveHeight = 60; verticalPadding = 0; stringLength = 0
        glowEnabled = true; glowRadius = 12
        colorMode = "theme"
        syncedColor1Key = "blue"; syncedColor2Key = "purple"
        customColor1 = "#ff9e64"; customColor2 = "#cec991"
        screenshotRopeEnabled = true; ropeSegments = 10; ropeSegmentLength = 5
        screenshotFreeze = true                       // hf129
        ropeOriginMode = "band"                       // hf130
        // hf82j: rope color defaults
        ropeColorMode = "inherit"
        ropeSyncedColorKey = "blue"
        ropeCustomColor = "#ff9e64"
        markDirty()
    }
}
