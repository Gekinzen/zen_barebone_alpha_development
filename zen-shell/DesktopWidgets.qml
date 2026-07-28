import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

/*
 * DesktopWidgets v6.16.1.3 — Desktop overlay
 *
 * v6.16.1.3 HOTFIX (ghost widget):
 *   v6.16.1 added layer.enabled + external shadow Rectangles to
 *   smooth the drag. Both broke: toggling layer.enabled mid-drag
 *   creates framebuffer swap glitches (old position ghosts until
 *   next full paint), and shadows bound to widget.x/y created
 *   stale duplicates during position updates. Removed both.
 *   Kept drag.threshold 5px + scale animation (transform-based,
 *   no ghost). Drag is still smooth — just no more trail.
 *
 * v6.16.1:
 *   - sysmonWidget: multi-GPU tabs (Overview / CPU / GPU0 / GPU1 / NET),
 *     btop quick-launch button (toggle-kill pattern), auto-adapts to
 *     SystemMonitorService.gpuCount. Overview grid unchanged.
 *
 * v6.11e: Fixed drag delay — removed x/y property bindings that
 * fought with drag.target. Positions set imperatively via onChanged
 * handlers instead of declarative bindings.
 */
Item {
    id: dw
    anchors.fill: parent

    // v7.0.0-alpha.3 (Densho Surfaces): seasonal kanji column.
    // Mounted on the right edge, vertically centered. Collapses to
    // zero size when DenshoService.useSeasonalKanji is false, so the
    // widget surface is unaffected when Densho mode is off.
    DenshoSeasonal {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        z: 0   // sits behind interactive widgets but above wallpaper
    }

    readonly property string configDir: Quickshell.env("HOME") + "/.config/quickshell/zen-shell"
    readonly property string configPath: configDir + "/widgets-state.json"

    // v6.16.3.7: Universal widget scale multiplier.
    // Binds live to PanelState.widgetScale (set via Settings →
    // Widgets → Widget Scale slider). Every font.pixelSize and
    // container dimension in this file multiplies by dw._scale,
    // so changing the Settings slider resizes all three widgets
    // (clocks, weather, sysmon) in lockstep — instantly, no
    // shell restart.
    //
    // Clamped to 0.5-2.0 defensively in case someone hand-edits
    // panel-state.json with a nonsense value. Lower bound 0.5
    // keeps text readable; upper bound 2.0 keeps widgets from
    // eating the entire screen on HiDPI displays.
    // v6.16.4.2: Enhanced scale computation with multiple safety
    // layers to prevent widgets from becoming unusable:
    //
    //   1. _userScale       — raw slider value (0.5-2.0)
    //   2. _monitorScale    — Hyprland's per-monitor scale factor
    //                         (1.0 on 1080p, 1.25 on small 1440p,
    //                         1.5 on 4K 13" panels, etc.)
    //   3. _effectiveScale  — combined value clamped to a safe
    //                         minimum that preserves readability
    //   4. _scale           — public API, what widgets multiply by
    //
    // Why combine monitor + user scales:
    //   When Hyprland monitor scale = 1.25 and user scale = 1.0,
    //   the logical resolution shrinks to 80% of physical. Without
    //   compensating, 400px widgets that looked right at scale=1.0
    //   now only cover 500 physical pixels — too small on HiDPI.
    //   We bump the effective scale slightly upward so visual size
    //   roughly tracks physical pixels instead of logical ones.
    //
    // Why minimum clamp at 0.65:
    //   Below ~0.65x, fonts drop below 6px and become unreadable;
    //   container padding (which is absolute, not scaled) eats
    //   more usable area than the content itself. 0.5 slider
    //   position still renders but forces minimum of 0.65 applied.
    readonly property real _userScale: {
        const s = PanelState.widgetScale !== undefined ? PanelState.widgetScale : 1.0
        return Math.max(0.5, Math.min(2.0, s))
    }

    // Monitor scale — picked from the primary monitor where widgets
    // live. Not all Quickshell Screen bindings expose this cleanly,
    // so we read it from Hyprland's own monitor list through a Process.
    property real _monitorScale: 1.0

    // Combined safe scale — floor at 0.65 to keep widgets readable
    // even if user slides to 0.5. Monitor scale applied as a mild
    // compensation (sqrt avoids over-magnifying on high-density
    // displays where the user already picked a small user scale).
    readonly property real _effectiveScale: {
        const combined = _userScale * Math.sqrt(_monitorScale)
        return Math.max(0.65, Math.min(2.4, combined))
    }

    // Public property — every widget in this file multiplies
    // dimensions by dw._scale. Bound to _effectiveScale so updates
    // propagate through automatically when user or monitor scale
    // changes (via onMonitorScaleChanged or Settings slider).
    readonly property real _scale: _effectiveScale

    // v7.0.0-beta.1-hf99z: per-widget scale multipliers (on top of the global
    // widget scale). WidgetsPage sets clockScale/weatherScale/sysmonScale;
    // each widget renders at _scale × its own multiplier.
    property real clockScale: 1.0
    property real weatherScale: 1.0
    property real sysmonScale: 1.0
    // v7.0.0-beta.1-hf99zc: linkedScale ON → the global scale drives all
    // widgets (per-widget disabled); OFF → each widget uses its own slider
    // (× monitor scale) and the global slider is disabled.
    property bool linkedScale: true
    readonly property real _clockScale: linkedScale ? _scale : (clockScale * _monitorScale)
    readonly property real _weatherScale: linkedScale ? _scale : (weatherScale * _monitorScale)
    readonly property real _sysmonScale: linkedScale ? _scale : (sysmonScale * _monitorScale)

    // v6.16.4.2: inner padding multiplier — scales the absolute
    // padding values inside widgets (anchors.margins: 24, etc.)
    // down with the scale factor, so content area ratio stays
    // consistent at any scale. Ratio 0.7-1.3 of _scale prevents
    // over-compression at extreme ends.
    readonly property real _padScale: Math.max(0.6, Math.min(1.3, _scale))

    // v6.16.4.2: Poll monitor scale via hyprctl when DesktopWidgets
    // loads and on monitor changes. Running `hyprctl -j monitors`
    // is cheap (~1ms).
    //
    // v6.16.4.3 FIX: removed the 3s Timer that was causing widget
    // "oscillation" — every 3 seconds the probe would fire, the
    // value might fluctuate by 0.001 due to float parsing precision,
    // and the on_ScaleChanged hook would re-reflow widgets. Paul:
    // "bigla nag babago bago yun scaling."
    //
    // New policy: probe ONCE on load, plus whenever PanelState.
    // widgetScale changes (Settings slider moved). That's enough
    // — monitor scale changes rarely and usually trigger a full
    // Hyprland config reload which re-initializes DesktopWidgets
    // from scratch anyway.
    Process {
        id: monitorScaleProbe
        running: true
        command: ["bash", "-c",
            "hyprctl -j monitors 2>/dev/null | jq -r '[.[] | select(.focused==true)][0].scale // 1.0' 2>/dev/null || echo 1.0"]
        stdout: SplitParser {
            onRead: (line) => {
                const v = parseFloat(line.trim())
                // Round to 2 decimal places so float-parsing noise
                // (1.2499999 vs 1.25) doesn't trigger reflow loops.
                if (!isNaN(v) && v > 0.1 && v < 5.0) {
                    const rounded = Math.round(v * 100) / 100
                    if (Math.abs(dw._monitorScale - rounded) > 0.005) {
                        dw._monitorScale = rounded
                    }
                }
            }
        }
    }

    // v6.16.4.3: Re-probe when user slider changes — covers cases
    // where user changed monitor scale in DisplaysPage then the
    // widget scale slider. No periodic Timer anymore.
    Connections {
        target: PanelState
        function onWidgetScaleChanged() {
            monitorScaleProbe.running = true
        }
    }

    property var clocks: [
        { enabled: true, timezone: "Asia/Manila", format24h: true, label: "Manila" },
        { enabled: false, timezone: "America/Winnipeg", format24h: true, label: "Winnipeg" }
    ]

    property bool weatherEnabled: true
    property bool sysmonEnabled: true
    property string widgetDisplay: "primary"
    // v6.9.3: Per-monitor array — which monitors show widgets
    property var widgetMonitors: []
    property bool clockGlow: true
    // v7.0.0-beta.1-hf99o: desktop clock design variant.
    //   outline — bold Adwaita Black with dark outline (the original)
    //   solid   — clean solid-colour bold, no outline (Bolder look)
    //   raised  — solid bold with a soft drop shadow (chunky/embossed)
    //   mono    — tabular JetBrainsMono, lighter weight, understated
    property string clockStyle: "outline"
    // v7.0.0-beta.1-hf99zb: per-clock style — a clock's own `style` overrides
    // the global clockStyle; "" or "inherit" means follow the global.
    function _styleFor(idx) {
        const c = (idx >= 0 && idx < dw.clocks.length) ? dw.clocks[idx] : null
        return (c && c.style && c.style !== "inherit" && c.style.length > 0) ? c.style : dw.clockStyle
    }
    // v7.0.0-beta.1-hf99y: when true, each clock is its own draggable widget
    // (per-clock posX/posY) instead of one stacked group.
    property bool independentClocks: false
    // v7.0.0-beta.1-hf99ze: system monitor design — "classic" (tabs +
    // sparklines) or "bars" (modern slanted bars with numbers, Pixel-ish).
    // v7.0.0-beta.1-hf99zh: per-widget font family (independently selectable)
    property string clockFont: "Adwaita Sans"
    property string weatherFont: "Adwaita Sans"
    property string sysmonFont: "Adwaita Sans"

    property string sysmonStyle: "classic"
    // v7.0.0-beta.1-hf99zg: Pills theming — card colour/opacity + accent mode.
    // Text colour is derived from the card's luminance so it always stays
    // readable, whatever colour (or transparency) the user picks.
    property string sysmonCardColor: "#f2f2f5"
    property real   sysmonCardOpacity: 1.0
    property string sysmonAccentMode: "multi"     // multi | theme | custom
    property string sysmonAccentColor: "#0a84ff"
    // v7.0.0-beta.1-hf99zi: weather gets its own accent too.
    property string weatherAccentMode: "default"  // default | theme | custom
    property string weatherAccentColor: "#7ab8ff"
    readonly property color _weatherAccent: {
        if (weatherAccentMode === "theme") return ThemeService.blue
        if (weatherAccentMode === "custom") return weatherAccentColor
        return "#7ab8ff"                          // default (unchanged look)
    }
    // Big temperature keeps its plain white unless an accent is chosen.
    readonly property color _weatherTempColor: weatherAccentMode === "default"
                                               ? Qt.rgba(1, 1, 1, 1) : _weatherAccent

    // ── v8.0.0-alpha-hf156 ──
    // weatherMode/Location: passthrough only. DesktopWidgets and WidgetsPage both
    // write the WHOLE widgets-state.json; without these two here, a drag/expand
    // save from this side would drop weather.mode / weather.location. Not consumed.
    property string weatherMode: "auto"
    property string weatherLocation: ""
    // Weather widget style. "standard" = the card; "pixel" = a weather-only
    // ZenGlanceWidget blob (the merged blob's look, weather only — no sysmon; the
    // system face is unreachable because toggleFace() no-ops when sysmon is off).
    property string weatherStyle: "standard"        // standard | pixel
    // Open-state persistence (survives restart — "kung open yan dapat open padin").
    // Owned here; WidgetsPage only round-trips them so a settings save can't clobber.
    property bool   _openWeatherExpanded: false     // standard card expanded?
    property string _openWeatherPixelView: "blob"   // pixel weather: blob|compact|detail
    property string _openGlanceView: "blob"         // merged blob:   blob|compact|detail
    property bool   _applyingOpen: false            // true while restoring open-state (suppresses re-save)
    // Pixel-weather surface follows the weather widget's OWN background setting, so
    // "theme" flows through: theme → ThemeService.bg1, custom → the picked colour,
    // else porcelain. Ink auto-contrasts in the blob; accent is the weather accent.
    readonly property color _weatherPixelSurface: {
        if (weatherBgMode === "theme")  return ThemeService.bg1
        if (weatherBgMode === "custom") return weatherBgCustomColor
        return "#fbede8"
    }

    // ── v8.0.0-alpha-hf113: merged Glance blob ──
    // merged=true  → one ZenGlanceWidget (Pixel blob, cloud/thermostat switcher)
    // merged=false → the original weatherWidget + sysmonWidget, untouched.
    property bool   glanceMerged: false
    property string glanceSurfaceMode: "default"    // default | theme | custom
    property string glanceSurfaceColor: "#fbede8"   // porcelain
    property real   glanceSurfaceOpacity: 0.96
    property string glanceInkMode: "auto"           // auto | theme | custom
    property string glanceInkColor: "#6e2a14"
    property string glanceAccentMode: "default"     // default | theme | custom
    property string glanceAccentColor: "#5dc4e8"
    property string glanceFont: "Adwaita Sans"
    property real   glancePosX: -1
    property real   glancePosY: 40

    readonly property color _glanceSurface: {
        if (glanceSurfaceMode === "theme")  return ThemeService.bg1
        if (glanceSurfaceMode === "custom") return glanceSurfaceColor
        return "#fbede8"
    }
    readonly property color _glanceAccent: {
        if (glanceAccentMode === "theme")  return ThemeService.blue
        if (glanceAccentMode === "custom") return glanceAccentColor
        return "#5dc4e8"
    }

    // ═══════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf125 — EXPANSION LIFT
    //
    // A widget that grows keeps its top-left corner, so expanding one near
    // the screen edge ran it off-screen, and expanding one next to a
    // neighbour buried it. You had to drag it out of the way and back.
    //
    // Design, and why:
    //
    //   The EXPANDING widget moves. Its neighbours never do.
    //
    // 1. Reversibility. A widget has exactly one saved home. If neighbours
    //    moved too, collapsing would have to unwind N moves in the right
    //    order — and any drag in between makes "the old position"
    //    ambiguous. One mover, one undo.
    // 2. Least surprise. Widgets you didn't touch shouldn't jump.
    // 3. Determinism. The solver runs against STATIC obstacles. With moving
    //    obstacles you need a fixed point that may not exist (three widgets
    //    wedged in a corner) and the result depends on iteration order.
    //
    // The saved position is never written during a lift. Expanding and
    // collapsing must not drift your layout — that's the same class of bug
    // as a state clobber, just slower.
    //
    // If a widget is genuinely boxed in, it stays put and raises `z`.
    // Overlapping is better than teleporting.
    // ═══════════════════════════════════════════════════════════
    readonly property int _liftMargin: 12
    property bool _liftAnim: false            // gates the x/y Behaviors

    function _hit(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah
    }

    function _resolveLift(self, hx, hy, w, h) {
        const m = dw._liftMargin
        let x = Math.max(m, Math.min(hx, dw.width - w - m))
        let y = Math.max(m, Math.min(hy, dw.height - h - m))

        const others = []
        const all = [clockWidget, weatherWidget, sysmonWidget, glanceWidget]
        for (let i = 0; i < all.length; i++) {
            const c = all[i]
            if (!c || c === self || !c.visible || c.width < 2) continue
            others.push({ x: c.x, y: c.y, w: c.width, h: c.height })
        }

        for (let iter = 0; iter < 6; iter++) {
            let moved = false
            for (let j = 0; j < others.length; j++) {
                const o = others[j]
                if (!dw._hit(x, y, w, h, o.x, o.y, o.w, o.h)) continue
                // Minimal translation: push out along the axis of least penetration,
                // discarding any move that would leave the desktop.
                const cands = [
                    { dx: (o.x - w) - x,        dy: 0 },
                    { dx: (o.x + o.w) - x,      dy: 0 },
                    { dx: 0, dy: (o.y - h) - y      },
                    { dx: 0, dy: (o.y + o.h) - y    }
                ]
                let best = null
                for (let k = 0; k < cands.length; k++) {
                    const c = cands[k]
                    const nx = x + c.dx, ny = y + c.dy
                    if (nx < m || ny < m) continue
                    if (nx + w > dw.width - m || ny + h > dw.height - m) continue
                    const cost = Math.abs(c.dx) + Math.abs(c.dy)
                    if (!best || cost < best.cost) best = { dx: c.dx, dy: c.dy, cost: cost }
                }
                if (!best) continue              // boxed in — let it overlap, z wins
                x += best.dx; y += best.dy
                moved = true
            }
            if (!moved) break
        }
        return Qt.point(Math.round(x), Math.round(y))
    }

    readonly property color _sysmonCardBg: {
        const c = sysmonCardColor
        return Qt.rgba(parseInt(c.substr(1,2),16)/255, parseInt(c.substr(3,2),16)/255,
                       parseInt(c.substr(5,2),16)/255, sysmonCardOpacity)
    }
    // Perceived luminance of the card (ignoring alpha) → pick dark or light text.
    readonly property bool _cardIsLight: {
        const c = sysmonCardColor
        const r = parseInt(c.substr(1,2),16)/255, g = parseInt(c.substr(3,2),16)/255, b = parseInt(c.substr(5,2),16)/255
        return (0.2126*r + 0.7152*g + 0.0722*b) > 0.55
    }
    // If the card is mostly transparent, fall back to the widget text colour
    // (it sits on the wallpaper/widget bg, not on the card).
    readonly property color _cardText: sysmonCardOpacity < 0.35
                                       ? dw.widgetTextColor
                                       : (_cardIsLight ? Qt.rgba(0.10,0.10,0.11,1) : Qt.rgba(1,1,1,0.95))
    readonly property color _cardSubText: Qt.rgba(_cardText.r, _cardText.g, _cardText.b, 0.5)
    readonly property color _cardLine: Qt.rgba(_cardText.r, _cardText.g, _cardText.b, 0.15)

    function _accentFor(defaultColor) {
        if (sysmonAccentMode === "theme") return ThemeService.blue
        if (sysmonAccentMode === "custom") return sysmonAccentColor
        return defaultColor
    }

    property real clockPosX: 40
    property real clockPosY: 60
    property real weatherPosX: -1
    property real weatherPosY: 40
    property real sysmonPosX: -1
    property real sysmonPosY: 300

    property string colorMode: "default"
    property string customColor: "#ffffff"

    // v6.16.1.5: per-widget background colors (loaded from widgets-state.json)
    property string weatherBgMode: "default"         // default|theme|custom
    property string weatherBgCustomColor: "#1c1c1e"
    property real   weatherBgOpacity: 0.92
    property string sysmonBgMode: "default"
    property string sysmonBgCustomColor: "#1c1c1e"
    property real   sysmonBgOpacity: 0.92

    // Reactive computed colors — widgets bind to these. Auto-update when
    // user changes the mode or color in Settings and saveState() rewrites
    // widgets-state.json (FileView reload triggers _applyConfig → these).
    readonly property color weatherBgColor: {
        // v7.0.0-beta.1-hf99zh: "none" → fully transparent
        if (weatherBgMode === "none") return Qt.rgba(0, 0, 0, 0)
        if (weatherBgMode === "theme")
            return LookService.surfaceColor(ThemeService.bg0, weatherBgOpacity)
        if (weatherBgMode === "custom") {
            const c = weatherBgCustomColor
            return Qt.rgba(
                parseInt(c.substr(1,2), 16) / 255,
                parseInt(c.substr(3,2), 16) / 255,
                parseInt(c.substr(5,2), 16) / 255,
                weatherBgOpacity)
        }
        return Qt.rgba(0.11, 0.11, 0.118, 0.92)   // default (unchanged)
    }
    readonly property color sysmonBgColor: {
        // v7.0.0-beta.1-hf99zg: "none" → fully transparent (widget floats)
        if (sysmonBgMode === "none") return Qt.rgba(0, 0, 0, 0)
        if (sysmonBgMode === "theme")
            return LookService.surfaceColor(ThemeService.bg0, sysmonBgOpacity)
        if (sysmonBgMode === "custom") {
            const c = sysmonBgCustomColor
            return Qt.rgba(
                parseInt(c.substr(1,2), 16) / 255,
                parseInt(c.substr(3,2), 16) / 255,
                parseInt(c.substr(5,2), 16) / 255,
                sysmonBgOpacity)
        }
        return Qt.rgba(0.11, 0.11, 0.118, 0.92)   // default (unchanged)
    }

    // ══════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf153 — Glass — Advanced+ awareness (weather + sysmon)
    //
    // The shell surfaces (dock, bars, Control Center, start menu,
    // notifications, desktop panel) already frost on the clear look through
    // LookService (hf144–hf152). These two DESKTOP cards — the weather widget
    // and the system-monitor widget — never read the look, so on Glass+ they
    // stayed solid dark boxes floating over the frosted desktop. They now
    // follow the exact same material: a neutral white frost body (Hyprland
    // blur is the material, no theme tint), with the inner metric / forecast
    // tiles a touch brighter so they lift off it.
    //
    // Gated ENTIRELY on LookService.isClear. On every other look (Zen /
    // Classic / Glass / Minimal / Custom) each helper returns the caller's
    // ORIGINAL value verbatim, so the widgets render byte-for-byte identical
    // to hf152 — wala tayong sinira. The MERGED Glance blob (ZenGlanceWidget)
    // is deliberately NOT touched — "except sa merged nila."
    readonly property bool _glassClear: (typeof LookService !== "undefined") && LookService.isClear
    readonly property real _glassFill:  (typeof LookService !== "undefined") ? LookService.glassFill : 0.16

    // Outer card body: white frost on clear, else the caller's own bg colour.
    // v8.0.0-alpha-hf158 — uses LookService.clearFill() so the desktop widget bodies
    // get the SAME smart smoke as the shell panels (dark tint ramps in on a bright
    // wallpaper). _glassClear already guarantees LookService exists + isClear here.
    function _bodyBg(fallback)      { return _glassClear ? LookService.clearFill() : fallback }
    // Outer card border: gone on clear (edge is the Hyprland blur, same as the
    // shell panels); off clear the caller keeps its own border.
    function _bodyBorderC(fallback) { return _glassClear ? Qt.rgba(0, 0, 0, 0) : fallback }
    function _bodyBorderW(fallback) { return _glassClear ? 0 : fallback }
    // Inner tile (metric card / forecast day): +0.06 over the body frost so it
    // reads as a raised frosted tile; off clear it returns its own dark fill.
    function _tile(fallback)        { return _glassClear ? Qt.rgba(1, 1, 1, Math.min(0.90, _glassFill + 0.06)) : fallback }

    readonly property color widgetTextColor: {
        if (colorMode === "theme") return ThemeService.fg
        if (colorMode === "custom") return customColor
        return "#ffffff"
    }
    readonly property color widgetAccentColor: {
        if (colorMode === "theme") return ThemeService.blue
        if (colorMode === "custom") return customColor
        return Qt.rgba(0.53, 0.81, 0.92, 1.0)
    }

    // ── Position apply (imperative, no bindings) ──
    // v6.16.1.9 GHOST-WIDGET FIX:
    //   Previous versions called _applyPositions() on width/height change
    //   without guarding against active drags. If anything caused dw.width
    //   or dw.height to change during a drag (a sparkline repaint, a
    //   weather text update causing content reflow, monitor config event),
    //   this function forcibly reset widget.x/y back to the *saved* position
    //   — mid-drag. Result: the widget snapped back to origin while the
    //   drag.target's pending updates still had the cursor position ready
    //   for the next frame, producing two visible widget copies until
    //   release.
    //   Fix: check `_anyDragActive` before applying positions. If any of
    //   the three drag areas is active, skip the re-apply — let drag.target
    //   own the position until release.
    readonly property bool _anyDragActive:
        (typeof clockDragArea   !== "undefined" && clockDragArea.drag.active) ||
        (typeof weatherDragArea !== "undefined" && weatherDragArea.drag.active) ||
        (typeof sysmonDragArea  !== "undefined" && sysmonDragArea.drag.active)

    function _applyPositions() {
        // Guard: don't apply if window hasn't sized yet
        if (dw.width <= 0 || dw.height <= 0) return
        // v6.16.1.9: don't clobber drag.target's live position
        if (_anyDragActive) return
        // v8.0.0-alpha-hf125: startup / monitor-change placement is instant.
        // Without this the widgets would visibly fly in from 0,0.
        dw._liftAnim = false

        // v6.16.4.2: Clamp loaded positions into the current logical
        // screen bounds. Two scenarios this fixes:
        //
        //   1. Monitor scale change — user bumps Scale from 1.0 to
        //      1.25 in DisplaysPage → logical resolution shrinks
        //      from e.g. 2560x1440 to 2048x1152. Old positions at
        //      (x=2100, y=1300) would leave widgets off-screen.
        //   2. Widget scale change — slider from 1.0 to 1.5 grows
        //      widgets by 50%. A widget anchored at the right edge
        //      would now overflow past screen width.
        //
        // Formula: clamp each widget's top-left so that the entire
        // widget (including its new scaled width/height) fits
        // within dw.width × dw.height with a 16px margin.
        //
        // Widgets with negative stored X (sentinel for "right-align")
        // keep their right-align behavior.
        const margin = 16
        const clampX = (pos, w) => {
            if (pos < 0) return pos   // preserve right-align sentinel
            return Math.max(margin, Math.min(pos, dw.width - w - margin))
        }
        const clampY = (pos, h) => Math.max(margin, Math.min(pos, dw.height - h - margin))

        clockWidget.x = clampX(clockPosX, clockWidget.width)
        clockWidget.y = clampY(clockPosY, clockWidget.height)
        if (weatherPosX < 0)
            weatherWidget.x = dw.width - weatherWidget.width - 40
        else
            weatherWidget.x = clampX(weatherPosX, weatherWidget.width)
        weatherWidget.y = clampY(weatherPosY, weatherWidget.height)
        if (sysmonPosX < 0)
            sysmonWidget.x = dw.width - sysmonWidget.width - 40
        else
            sysmonWidget.x = clampX(sysmonPosX, sysmonWidget.width)
        sysmonWidget.y = clampY(sysmonPosY, sysmonWidget.height)

        // v8.0.0-alpha-hf113
        if (glancePosX < 0)
            glanceWidget.x = dw.width - glanceWidget.width - 40
        else
            glanceWidget.x = clampX(glancePosX, glanceWidget.width)
        glanceWidget.y = clampY(glancePosY, glanceWidget.height)

        // v8.0.0-alpha-hf156 — pixel weather shares the weather slot (weatherPosX/Y),
        // so Standard⇄Pixel keeps the same spot.
        if (weatherPosX < 0)
            weatherPixelWidget.x = dw.width - weatherPixelWidget.width - 40
        else
            weatherPixelWidget.x = clampX(weatherPosX, weatherPixelWidget.width)
        weatherPixelWidget.y = clampY(weatherPosY, weatherPixelWidget.height)

        // hf125: a freshly placed widget is at home, by definition. And an
        // expanded widget that survives a monitor change re-solves from there.
        weatherWidget.homeX = weatherWidget.x
        weatherWidget.homeY = weatherWidget.y
        weatherPixelWidget.homeX = weatherPixelWidget.x
        weatherPixelWidget.homeY = weatherPixelWidget.y
        glanceWidget.homeX = glanceWidget.x
        glanceWidget.homeY = glanceWidget.y
        Qt.callLater(function() {
            dw._liftAnim = true
            if (weatherWidget.weatherExpanded) weatherWidget._lift()
            if (glanceWidget.view !== "blob") glanceWidget._lift()
        })
    }

    onWidthChanged: containerReflowTimer.restart()
    onHeightChanged: containerReflowTimer.restart()

    // v6.16.4.3: debounce container-size-change reflows so opening/
    // closing Control Panel (which briefly changes the reserved
    // screen area) doesn't cascade into widget position oscillation.
    // Previous code called _applyPositions() directly on every
    // width/height change — during Control Panel fade-out animation,
    // dw.width ticks through dozens of intermediate values and each
    // one clobbers positions.
    Timer {
        id: containerReflowTimer
        interval: 150
        repeat: false
        onTriggered: _applyPositions()
    }

    // v6.16.4.2: Reflow positions whenever the effective scale
    // changes. This catches:
    //   - User dragging the Settings → Widgets → Widget Scale slider
    //   - Hyprland monitor scale change via DisplaysPage
    //   - Dock plug/unplug changing which monitor widgets live on
    //
    // v6.16.4.3 hardening: dampened the cascade.
    //   - Changed from on_ScaleChanged hooks (fire on ANY float change)
    //     to explicit Connections that only react when the SOURCE
    //     properties change by a meaningful amount (>0.005)
    //   - Reflow timer interval 120ms → 180ms to further coalesce
    //   - Ignore scale events during Control Panel / Settings panel
    //     transitions (detected via a short "cooling" period after
    //     widget geometry last changed by itself)
    Connections {
        target: PanelState
        function onWidgetScaleChanged() {
            scaleReflowTimer.restart()
        }
    }

    on_MonitorScaleChanged: scaleReflowTimer.restart()

    Timer {
        id: scaleReflowTimer
        interval: 180
        repeat: false
        onTriggered: {
            // Widget widths/heights are already bound to _scale, so
            // by the time this fires they've re-layouted. Just
            // re-clamp positions into new bounds.
            _applyPositions()
        }
    }

    FileView {
        id: cfgLoader
        path: dw.configPath
        blockLoading: false
        onLoaded: dw._applyConfig(this.text())
    }
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: cfgLoader.reload()
    }

    function _applyConfig(text) {
        try {
            const s = JSON.parse(text)
            if (s.clocks && Array.isArray(s.clocks)) {
                dw.clocks = s.clocks
            } else {
                const c1 = s.clock || {}
                const c2 = s.clock2 || {}
                dw.clocks = [
                    { enabled: c1.enabled !== false, timezone: c1.timezone || "Asia/Manila", format24h: c1.format24h !== false, label: (c1.timezone||"Asia/Manila").split("/").pop().replace(/_/g," ") },
                    { enabled: c2.enabled === true, timezone: c2.timezone || "America/Winnipeg", format24h: c2.format24h !== false, label: (c2.timezone||"America/Winnipeg").split("/").pop().replace(/_/g," ") }
                ]
            }
            if (s.weather) {
                weatherEnabled = s.weather.enabled !== false
                if (typeof s.weather.mode === "string")     weatherMode = s.weather.mode
                if (typeof s.weather.location === "string")  weatherLocation = s.weather.location
                if (typeof s.weather.style === "string")     weatherStyle = s.weather.style
            }
            if (s.sysmon) sysmonEnabled = s.sysmon.enabled !== false
            if (s.widgetDisplay) widgetDisplay = s.widgetDisplay
            // v6.9.3: per-monitor array
            if (s.widgetMonitors && Array.isArray(s.widgetMonitors)) widgetMonitors = s.widgetMonitors
            if (typeof s.clockGlow === "boolean") clockGlow = s.clockGlow
            if (typeof s.clockStyle === "string") clockStyle = s.clockStyle
            if (typeof s.independentClocks === "boolean") independentClocks = s.independentClocks
            if (typeof s.sysmonStyle === "string") sysmonStyle = (s.sysmonStyle === "bars" ? "pills" : s.sysmonStyle)
            if (typeof s.clockFont === "string") clockFont = s.clockFont
            if (typeof s.weatherFont === "string") weatherFont = s.weatherFont
            if (typeof s.sysmonFont === "string") sysmonFont = s.sysmonFont
            if (typeof s.sysmonCardColor === "string") sysmonCardColor = s.sysmonCardColor
            if (typeof s.sysmonCardOpacity === "number") sysmonCardOpacity = s.sysmonCardOpacity
            // v8.0.0-alpha-hf113
            if (s.glance) {
                if (typeof s.glance.merged === "boolean")         glanceMerged = s.glance.merged
                if (typeof s.glance.surfaceMode === "string")     glanceSurfaceMode = s.glance.surfaceMode
                if (typeof s.glance.surfaceColor === "string")    glanceSurfaceColor = s.glance.surfaceColor
                if (typeof s.glance.surfaceOpacity === "number")  glanceSurfaceOpacity = s.glance.surfaceOpacity
                if (typeof s.glance.inkMode === "string")         glanceInkMode = s.glance.inkMode
                if (typeof s.glance.inkColor === "string")        glanceInkColor = s.glance.inkColor
                if (typeof s.glance.accentMode === "string")      glanceAccentMode = s.glance.accentMode
                if (typeof s.glance.accentColor === "string")     glanceAccentColor = s.glance.accentColor
                if (typeof s.glance.font === "string")            glanceFont = s.glance.font
            }
            if (typeof s.sysmonAccentMode === "string") sysmonAccentMode = s.sysmonAccentMode
            if (typeof s.sysmonAccentColor === "string") sysmonAccentColor = s.sysmonAccentColor
            if (typeof s.weatherAccentMode === "string") weatherAccentMode = s.weatherAccentMode
            if (typeof s.weatherAccentColor === "string") weatherAccentColor = s.weatherAccentColor
            if (typeof s.clockScale === "number") clockScale = s.clockScale
            if (typeof s.weatherScale === "number") weatherScale = s.weatherScale
            if (typeof s.sysmonScale === "number") sysmonScale = s.sysmonScale
            if (typeof s.linkedScale === "boolean") linkedScale = s.linkedScale
            if (s.positions) {
                if (typeof s.positions.clockX === "number") clockPosX = s.positions.clockX
                if (typeof s.positions.clockY === "number") clockPosY = s.positions.clockY
                if (typeof s.positions.glanceX === "number") glancePosX = s.positions.glanceX
                if (typeof s.positions.glanceY === "number") glancePosY = s.positions.glanceY
                if (typeof s.positions.weatherX === "number") weatherPosX = s.positions.weatherX
                if (typeof s.positions.weatherY === "number") weatherPosY = s.positions.weatherY
                if (typeof s.positions.sysmonX === "number") sysmonPosX = s.positions.sysmonX
                if (typeof s.positions.sysmonY === "number") sysmonPosY = s.positions.sysmonY
            }
            if (s.colorMode) colorMode = s.colorMode
            if (s.customColor) customColor = s.customColor

            // v6.16.1.5: per-widget background settings
            if (s.weatherBg) {
                if (s.weatherBg.mode) weatherBgMode = s.weatherBg.mode
                if (s.weatherBg.color) weatherBgCustomColor = s.weatherBg.color
                if (typeof s.weatherBg.opacity === "number") weatherBgOpacity = s.weatherBg.opacity
            }
            if (s.sysmonBg) {
                if (s.sysmonBg.mode) sysmonBgMode = s.sysmonBg.mode
                if (s.sysmonBg.color) sysmonBgCustomColor = s.sysmonBg.color
                if (typeof s.sysmonBg.opacity === "number") sysmonBgOpacity = s.sysmonBg.opacity
            }

            // v8.0.0-alpha-hf156 — open-state (survives restart). Load the values,
            // then push them onto the live widgets so an expanded widget comes back
            // expanded. Assigning the same value the widgets already hold is a no-op,
            // so the save→reload loop settles.
            if (s.open) {
                if (typeof s.open.weatherExpanded === "boolean") _openWeatherExpanded = s.open.weatherExpanded
                if (typeof s.open.weatherPixelView === "string")  _openWeatherPixelView = s.open.weatherPixelView
                if (typeof s.open.glanceView === "string")        _openGlanceView = s.open.glanceView
            }

            // Apply positions imperatively after loading
            _applyPositions()

            // v8.0.0-alpha-hf156 — restore open-state AFTER positions, so a widget
            // that was left expanded lifts against its real resting x/y. Guarded so
            // these assignments don't echo back into a save.
            dw._applyingOpen = true
            weatherWidget.weatherExpanded = _openWeatherExpanded
            weatherPixelWidget.view       = _openWeatherPixelView
            glanceWidget.view             = _openGlanceView
            dw._applyingOpen = false
        } catch (e) {}
    }

    Timer {
        id: posSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            // v6.16.3.4.3: STATE-CLOBBER FIX
            //
            // Old payload was missing weatherBg + sysmonBg, so every drag
            // wrote a JSON that dropped those fields. On next shell restart
            // the FileView would load the clobbered JSON and fall back to
            // the default background mode — user complaint:
            //   "pinalitan ko color pag ka restart ko babalik sa default
            //    nanaman"
            //
            // The complete widget-state schema is owned by WidgetsPage.qml's
            // saveState(); both serializers must agree on it. Keep this
            // payload in sync whenever a new field is added to WidgetsPage.
            const state = {
                clocks: dw.clocks,
                weather: { enabled: dw.weatherEnabled, mode: dw.weatherMode, location: dw.weatherLocation, style: dw.weatherStyle },
                sysmon: { enabled: dw.sysmonEnabled },
                widgetDisplay: dw.widgetDisplay,
                widgetMonitors: dw.widgetMonitors,
                clockGlow: dw.clockGlow,
                clockStyle: dw.clockStyle,
                independentClocks: dw.independentClocks,
                sysmonStyle: dw.sysmonStyle,
                clockFont: dw.clockFont,
                weatherFont: dw.weatherFont,
                sysmonFont: dw.sysmonFont,
                sysmonCardColor: dw.sysmonCardColor,
                sysmonCardOpacity: dw.sysmonCardOpacity,
                sysmonAccentMode: dw.sysmonAccentMode,
                sysmonAccentColor: dw.sysmonAccentColor,
                weatherAccentMode: dw.weatherAccentMode,
                weatherAccentColor: dw.weatherAccentColor,
                // v8.0.0-alpha-hf113 — MUST be here or dragging nukes the glance settings
                glance: {
                    merged: dw.glanceMerged,
                    surfaceMode: dw.glanceSurfaceMode,
                    surfaceColor: dw.glanceSurfaceColor,
                    surfaceOpacity: dw.glanceSurfaceOpacity,
                    inkMode: dw.glanceInkMode,
                    inkColor: dw.glanceInkColor,
                    accentMode: dw.glanceAccentMode,
                    accentColor: dw.glanceAccentColor,
                    font: dw.glanceFont
                },
                clockScale: dw.clockScale,
                weatherScale: dw.weatherScale,
                sysmonScale: dw.sysmonScale,
                linkedScale: dw.linkedScale,
                positions: { clockX: dw.clockPosX, clockY: dw.clockPosY, weatherX: dw.weatherPosX, weatherY: dw.weatherPosY, sysmonX: dw.sysmonPosX, sysmonY: dw.sysmonPosY, glanceX: dw.glancePosX, glanceY: dw.glancePosY },
                colorMode: dw.colorMode,
                customColor: dw.customColor,
                // v6.16.3.4.3: per-widget background fields — MUST be included
                // or dragging a widget nukes the user's custom colors
                weatherBg: { mode: dw.weatherBgMode, color: dw.weatherBgCustomColor, opacity: dw.weatherBgOpacity },
                sysmonBg:  { mode: dw.sysmonBgMode,  color: dw.sysmonBgCustomColor,  opacity: dw.sysmonBgOpacity },
                // v8.0.0-alpha-hf156 — open-state, so a restart keeps widgets open
                open: { weatherExpanded: dw._openWeatherExpanded, weatherPixelView: dw._openWeatherPixelView, glanceView: dw._openGlanceView }
            }
            posSaver.command = ["bash", "-c", "mkdir -p '" + dw.configDir + "' && cat > '" + dw.configPath + "' << 'ZENEOF'\n" + JSON.stringify(state, null, 2) + "\nZENEOF"]
            posSaver.running = true
        }
    }
    Process { id: posSaver; running: false }
    function _savePositions() { posSaveTimer.restart() }

    Component.onCompleted: {
        cfgLoader.reload()
        // Delay initial position apply to let layout settle
        Qt.callLater(_applyPositions)
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: dw.now = new Date()
    }
    property var now: new Date()

    // v7.0.0-beta.1-hf99t: reliable timezone conversion.
    // Intl.DateTimeFormat is NOT supported by the Quickshell JS engine — it
    // silently returned local time, so every clock showed the same time.
    // Instead we ask the OS zoneinfo via `TZ=<zone> date` (100% correct,
    // DST-aware) on a short timer and cache the result here.
    property var tzTimes: ({})           // { "America/Los_Angeles": "14:22", … }

    function convertTime(targetTz) {
        const s = dw.tzTimes[targetTz]
        if (s) {
            const p = s.split(":")
            const hh = parseInt(p[0], 10)
            const mm = parseInt(p[1], 10)
            if (!isNaN(hh) && !isNaN(mm)) return { hours: hh, minutes: mm }
        }
        // Not fetched yet (first ~1s) → show local time as a placeholder.
        return { hours: dw.now.getHours(), minutes: dw.now.getMinutes() }
    }

    function _refreshTz() {
        const zones = {}
        for (let i = 0; i < dw.clocks.length; i++) {
            const tz = dw.clocks[i] ? dw.clocks[i].timezone : ""
            if (tz) zones[tz] = true
        }
        let script = ""
        for (const tz in zones) {
            // only safe IANA-zone characters
            if (!/^[A-Za-z0-9_\/+.-]+$/.test(tz)) continue
            script += "printf '%s|%s\\n' '" + tz + "' \"$(TZ='" + tz + "' date +%H:%M)\"; "
        }
        if (script === "") return
        tzProc.command = ["bash", "-c", script]
        tzProc.running = true
    }

    Process {
        id: tzProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                const lines = this.text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("|")
                    if (parts.length === 2) map[parts[0]] = parts[1].trim()
                }
                dw.tzTimes = map
            }
        }
    }

    // Refresh on start, whenever the clock set changes, and every 20s so the
    // minute rollover + any DST change is picked up promptly.
    onClocksChanged: dw._refreshTz()
    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dw._refreshTz()
    }


    // v7.0.0-beta.1-hf99y: persist a single clock's position (independent mode)
    function _saveClockPos(idx, px, py) {
        let arr = JSON.parse(JSON.stringify(dw.clocks))
        if (idx >= 0 && idx < arr.length) {
            arr[idx].posX = px
            arr[idx].posY = py
            dw.clocks = arr
            dw._savePositions()
        }
    }

    // ═══════════════════════════════════════════════════════════
    // CLOCK — NO x/y binding, drag.target owns position
    // v6.16.1.3: GHOST-WIDGET FIX
    //   v6.16.1 added `layer.enabled: drag.active` + external shadow
    //   Rectangle bound to clockWidget.x/y. Two problems:
    //     1. Toggling layer.enabled mid-drag swaps the render pipeline
    //        (software → offscreen framebuffer). The old position's
    //        texture doesn't get invalidated cleanly → ghost trail.
    //     2. The shadow Rectangle was a sibling that tracked widget.x/y
    //        via property binding, so during drag the shadow updated
    //        per-frame from the binding but the widget's old position
    //        still had a stale render pass → two widgets visible.
    //
    //   Fix: keep scale animation (works via matrix transform, not
    //   position) + drag.threshold. Drop the layer-toggle and external
    //   shadow entirely. If we want a shadow later, it'll be via
    //   DropShadow effect inside the widget item (moves as one unit).
    // ═══════════════════════════════════════════════════════════

    Rectangle {
        id: clockWidget
        visible: dw.clocks.length > 0 && dw.clocks[0].enabled && !dw.independentClocks
        // NO x: or y: binding here — set imperatively via _applyPositions()
        width: clockLayout.width + 40
        height: clockLayout.implicitHeight + 20
        color: "transparent"
        antialiasing: true

        // v7.0.0-beta.1-hf99v: dynamic content alignment from screen position.
        // Left third of the screen → left-align; centre third → centre;
        // right third → right-align. Reacts live to dragging (x changes).
        readonly property string clockAlign: {
            const cx = clockWidget.x + clockWidget.width / 2
            const w = dw.width > 0 ? dw.width : 1920
            if (cx < w * 0.38) return "left"
            if (cx > w * 0.62) return "right"
            return "center"
        }
        readonly property int alignH: clockAlign === "left" ? Text.AlignLeft
                                      : (clockAlign === "right" ? Text.AlignRight : Text.AlignHCenter)
        // v6.16.1.8: REMOVED scale + Behavior on scale during drag.
        // Even though scale is a transform (not position), Qt's repaint
        // cycle during the Behavior animation window creates stale render
        // artifacts when combined with drag.target's rapid x/y updates.
        // The scale pop was nice-to-have; widget stability is essential.
        // Drag now uses threshold-only (no visual feedback on press) —
        // simplest, most reliable path. Cursor change via ClosedHandCursor
        // gives enough tactile feedback.

        MouseArea {
            id: clockDragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: clockWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - clockWidget.width
            drag.maximumY: dw.height - clockWidget.height
            drag.threshold: 5     // ignore <5px jitter
            onReleased: {
                dw.clockPosX = clockWidget.x
                dw.clockPosY = clockWidget.y
                dw._savePositions()
            }
        }

        Column {
            id: clockLayout
            x: 20
            y: 10
            spacing: 0
            // v7.0.0-beta.1-hf99v: explicit content width (max of natural
            // element widths) so children can fill + align without a binding
            // loop (child.width ← this ← child.implicitWidth only).
            width: Math.max(pTime.implicitWidth, dateText.implicitWidth, subGrid.implicitWidth)

            // v7.0.0-beta.1-hf99r: Google-Pixel wavy analog clock design.
            // Shows the primary (local) time; digital list hides in this mode.
            WavyAnalogClock {
                visible: dw._styleFor(0) === "analog"
                width: 220 * dw._clockScale
                height: 220 * dw._clockScale
                hours: dw.now.getHours()
                minutes: dw.now.getMinutes()
                dayLabel: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][dw.now.getDay()] + " " + dw.now.getDate()
            }

            // ── Primary clock (index 0) ──────────────────────────
            Item {
                id: primaryClock
                visible: dw.clocks.length > 0 && dw.clocks[0].enabled && dw._styleFor(0) !== "analog"
                implicitWidth: pTime.implicitWidth
                implicitHeight: pTime.implicitHeight
                width: clockLayout.width
                height: pTime.implicitHeight

                Rectangle {
                    visible: dw.clockGlow
                    anchors.centerIn: pTime
                    width: pTime.implicitWidth + 80
                    height: pTime.implicitHeight + 40
                    radius: 30
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                        GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.15) }
                        GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.15) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                    }
                }
                Text {
                    id: pTime
                    width: parent.width
                    horizontalAlignment: clockWidget.alignH
                    text: {
                        const h = dw.now.getHours(), m = dw.now.getMinutes()
                        const pad = n => String(n).padStart(2, "0")
                        const c0 = dw.clocks.length > 0 ? dw.clocks[0] : {}
                        const sep = (dw._styleFor(0) === "stacked") ? "\n" : ":"
                        if (c0.format24h) return pad(h) + sep + pad(m)
                        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h)
                        return pad(h12) + sep + pad(m)
                    }
                    lineHeight: dw._styleFor(0) === "stacked" ? 0.82 : 1.0
                    font.family: dw._styleFor(0) === "mono" ? "JetBrainsMono Nerd Font" : "Adwaita Sans"
                    font.pixelSize: 120 * dw._clockScale
                    font.weight: dw._styleFor(0) === "mono" ? Font.DemiBold : Font.Black
                    font.letterSpacing: dw._styleFor(0) === "mono" ? 0 : -4
                    color: dw.widgetTextColor
                    style: (dw._styleFor(0) === "outline" || dw._styleFor(0) === "stacked") ? Text.Outline
                           : (dw._styleFor(0) === "raised" ? Text.Raised : Text.Normal)
                    styleColor: dw._styleFor(0) === "outline" ? Qt.rgba(0, 0, 0, 0.8)
                                : (dw._styleFor(0) === "raised" ? Qt.rgba(0, 0, 0, 0.45) : "transparent")
                }
            }

            // date — follows the widget's alignment
            Text {
                id: dateText
                visible: primaryClock.visible
                width: clockLayout.width
                horizontalAlignment: clockWidget.alignH
                text: {
                    const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                    const months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
                    return days[dw.now.getDay()] + ", " + months[dw.now.getMonth()] + " " + String(dw.now.getDate()).padStart(2, "0")
                }
                font.family: dw.clockFont
                font.pixelSize: 24 * dw._clockScale
                font.weight: Font.ExtraBold
                font.letterSpacing: 0.5
                color: dw.widgetTextColor
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.8)
            }
            Text {
                visible: primaryClock.visible && dw.clocks.length > 0 && !dw.clocks[0].format24h
                width: clockLayout.width
                horizontalAlignment: clockWidget.alignH
                text: dw.now.getHours() < 12 ? "AM" : "PM"
                font.family: dw.clockFont
                font.pixelSize: 18 * dw._clockScale
                font.weight: Font.Bold
                color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.7)
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.5)
            }

            Item { width: 1; height: 8 * dw._clockScale }

            // ── Secondary clocks (index 1+) — 2-column grid, aligned ──
            Item {
                visible: dw._styleFor(0) !== "analog"
                implicitWidth: subGrid.implicitWidth
                implicitHeight: subGrid.implicitHeight
                width: clockLayout.width
                height: subGrid.height

                Grid {
                    id: subGrid
                    // v7.0.0-beta.1-hf99x: explicit x per alignment — more
                    // reliable than switching anchors on/off (which left the
                    // grid stuck when set to right).
                    x: clockWidget.clockAlign === "right" ? (parent.width - width)
                       : (clockWidget.clockAlign === "center" ? (parent.width - width) / 2 : 0)
                    columns: 2
                    columnSpacing: 26 * dw._clockScale
                    rowSpacing: 8 * dw._clockScale

                    Repeater {
                        model: dw.clocks
                        delegate: Column {
                            required property var modelData
                            required property int index
                            visible: index > 0 && modelData.enabled
                            spacing: 0

                            Text {
                                id: subTime
                                width: Math.max(subTime.implicitWidth, subName.implicitWidth)
                                horizontalAlignment: clockWidget.alignH
                                text: {
                                    const t = dw.convertTime(modelData.timezone)
                                    const pad = n => String(n).padStart(2, "0")
                                    if (modelData.format24h) return pad(t.hours) + ":" + pad(t.minutes)
                                    const h12 = t.hours === 0 ? 12 : (t.hours > 12 ? t.hours - 12 : t.hours)
                                    return pad(h12) + ":" + pad(t.minutes)
                                }
                                font.family: dw.clockFont
                                font.pixelSize: 26 * dw._clockScale
                                font.weight: Font.Black
                                font.letterSpacing: -1
                                color: dw.widgetAccentColor
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.5)
                            }
                            Text {
                                id: subName
                                width: Math.max(subTime.implicitWidth, subName.implicitWidth)
                                horizontalAlignment: clockWidget.alignH
                                // v7.0.0-beta.1-hf99u: custom name if set, else auto label
                                text: (modelData.name && modelData.name.length > 0)
                                      ? modelData.name
                                      : (modelData.label || modelData.timezone.split("/").pop().replace(/_/g, " "))
                                font.family: dw.clockFont
                                font.pixelSize: 11 * dw._clockScale
                                font.weight: Font.DemiBold
                                color: Qt.rgba(dw.widgetAccentColor.r, dw.widgetAccentColor.g, dw.widgetAccentColor.b, 0.7)
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.4)
                            }
                        }
                    }
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════
    // INDEPENDENT CLOCKS (hf99y) — each clock is its own draggable
    // widget with its own posX/posY, shown when dw.independentClocks.
    // ═══════════════════════════════════════════════════════════
    Repeater {
        model: dw.independentClocks ? dw.clocks : 0
        delegate: Rectangle {
            id: indClock
            required property var modelData
            required property int index
            // v7.0.0-beta.1-hf99zb: this clock's own style (or global)
            readonly property string _style: dw._styleFor(index)
            visible: modelData.enabled
            color: "transparent"
            antialiasing: true
            width: indCol.implicitWidth + 30
            height: indCol.implicitHeight + 20

            // position from the clock's own posX/posY (staggered default the
            // first time). Drag overrides x/y; onReleased persists it.
            x: (typeof modelData.posX === "number") ? modelData.posX : (60 + index * 60)
            y: (typeof modelData.posY === "number") ? modelData.posY : (60 + index * 150)

            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: indClock
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: dw.width - indClock.width
                drag.maximumY: dw.height - indClock.height
                drag.threshold: 5
                onReleased: dw._saveClockPos(index, indClock.x, indClock.y)
            }

            Column {
                id: indCol
                x: 15
                y: 10
                spacing: 2

                WavyAnalogClock {
                    visible: indClock._style === "analog"
                    width: (index === 0 ? 200 : 130) * dw._clockScale
                    height: (index === 0 ? 200 : 130) * dw._clockScale
                    hours: index === 0 ? dw.now.getHours() : dw.convertTime(modelData.timezone).hours
                    minutes: index === 0 ? dw.now.getMinutes() : dw.convertTime(modelData.timezone).minutes
                    dayLabel: index === 0
                              ? (["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][dw.now.getDay()] + " " + dw.now.getDate())
                              : ((modelData.name && modelData.name.length > 0) ? modelData.name : (modelData.label || modelData.timezone.split("/").pop().replace(/_/g, " ")))
                }

                Text {
                    visible: indClock._style !== "analog"
                    text: {
                        let h, m
                        if (index === 0) { h = dw.now.getHours(); m = dw.now.getMinutes() }
                        else { const t = dw.convertTime(modelData.timezone); h = t.hours; m = t.minutes }
                        const pad = n => String(n).padStart(2, "0")
                        const sep = (index === 0 && indClock._style === "stacked") ? "\n" : ":"
                        if (modelData.format24h) return pad(h) + sep + pad(m)
                        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h)
                        return pad(h12) + sep + pad(m)
                    }
                    lineHeight: (index === 0 && indClock._style === "stacked") ? 0.82 : 1.0
                    font.family: indClock._style === "mono" ? "JetBrainsMono Nerd Font" : "Adwaita Sans"
                    font.pixelSize: (index === 0 ? 96 : 44) * dw._clockScale
                    font.weight: indClock._style === "mono" ? Font.DemiBold : Font.Black
                    font.letterSpacing: index === 0 ? (indClock._style === "mono" ? 0 : -3) : -1
                    color: index === 0 ? dw.widgetTextColor : dw.widgetAccentColor
                    style: (indClock._style === "outline" || indClock._style === "stacked") ? Text.Outline
                           : (indClock._style === "raised" ? Text.Raised : Text.Normal)
                    styleColor: indClock._style === "outline" ? Qt.rgba(0, 0, 0, 0.8)
                                : (indClock._style === "raised" ? Qt.rgba(0, 0, 0, 0.45) : "transparent")
                }

                Text {
                    visible: index === 0 && indClock._style !== "analog"
                    text: {
                        const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                        const months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
                        return days[dw.now.getDay()] + ", " + months[dw.now.getMonth()] + " " + String(dw.now.getDate()).padStart(2, "0")
                    }
                    font.family: dw.clockFont
                    font.pixelSize: 20 * dw._clockScale
                    font.weight: Font.ExtraBold
                    color: dw.widgetTextColor
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                }
                Text {
                    visible: index > 0 && indClock._style !== "analog"
                    text: (modelData.name && modelData.name.length > 0)
                          ? modelData.name
                          : (modelData.label || modelData.timezone.split("/").pop().replace(/_/g, " "))
                    font.family: dw.clockFont
                    font.pixelSize: 13 * dw._clockScale
                    font.weight: Font.DemiBold
                    color: Qt.rgba(dw.widgetAccentColor.r, dw.widgetAccentColor.g, dw.widgetAccentColor.b, 0.7)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.4)
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════
    // WEATHER — NO x/y binding, stats forced right
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: weatherWidget
        visible: dw.weatherEnabled && !dw.glanceMerged && dw.weatherStyle !== "pixel"   // v8.0.0-alpha-hf113 · pixel gate hf156
        // v7.0.0-beta.1-hf99zd: click to expand (hourly + 7-day)
        property bool weatherExpanded: false

        // v8.0.0-alpha-hf125 — expansion lift. `home` is the resting position and
        // is the ONLY thing ever persisted; the lifted x/y are transient.
        property real homeX: 0
        property real homeY: 0
        z: weatherExpanded ? 30 : 1
        Behavior on x { enabled: dw._liftAnim && !weatherDragArea.drag.active
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: dw._liftAnim && !weatherDragArea.drag.active
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        function _lift() {
            const p = dw._resolveLift(weatherWidget, homeX, homeY, width, height)
            x = p.x; y = p.y
        }
        onWeatherExpandedChanged: {
            dw._liftAnim = true
            if (weatherExpanded) {
                homeX = x; homeY = y
                // width/height rebind from weatherExpanded; wait a tick so the
                // solver sees the expanded size, not the collapsed one.
                Qt.callLater(weatherWidget._lift)
            } else {
                x = homeX; y = homeY
            }
            // v8.0.0-alpha-hf156 — remember open/closed across restart.
            if (!dw._applyingOpen) { dw._openWeatherExpanded = weatherExpanded; dw._savePositions() }
        }
        // NO x: or y: binding — set imperatively
        // v6.16.4.3: Content-aware sizing.
        //
        // Previously (v6.16.3.7): width/height were hardcoded
        // 400 × 260 multiplied by dw._weatherScale. Problem: at small
        // scales (0.5x), the container shrinks uniformly but the
        // inner ColumnLayout's content (Text elements, forecast
        // row with 7 delegates) can't compress below its intrinsic
        // implicitWidth/Height. Result: content overflows or
        // collides, widget "looks broken."
        //
        // Now: use an intermediate `_targetW/H` that's the maximum
        // of scaled-target and content-implicit. Widget grows to
        // fit its content, never clips. At 2.0x the target wins
        // (widget grows as expected). At 0.5x the content-implicit
        // wins (widget stays readable).
        readonly property real _targetW: (weatherExpanded ? 400 : 300) * dw._weatherScale
        readonly property real _targetH: (weatherExpanded ? 300 : 150) * dw._weatherScale
        width: Math.max(_targetW, weatherContent.implicitWidth + (16 * dw._padScale * 2))
        height: Math.max(_targetH, weatherContent.implicitHeight + (16 * dw._padScale * 2))
        radius: 28
        // v6.16.1.5: reactive background from WidgetsPage settings
        // v8.0.0-alpha-hf153: white frost on Glass+, your own bg on every other look.
        color: dw._bodyBg(dw.weatherBgColor)
        // v6.16.1.8: disable color Behavior during drag — color-animation
        // repaints combined with fast x/y updates = ghost frames.
        Behavior on color {
            enabled: !weatherDragArea.drag.active
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        border.width: dw._bodyBorderW(1)
        border.color: dw._bodyBorderC(Qt.rgba(1, 1, 1, 0.12))
        antialiasing: true

        // v6.16.1.8: REMOVED scale + Behavior on scale during drag
        // (see clockWidget comment for full rationale).

        MouseArea {
            id: weatherDragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: weatherWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - weatherWidget.width
            drag.maximumY: dw.height - weatherWidget.height
            drag.threshold: 5
            onClicked: weatherWidget.weatherExpanded = !weatherWidget.weatherExpanded
            onReleased: {
                // hf125: dragging while expanded re-homes the widget, so collapsing
                // leaves it where you put it. Either way we persist HOME, never a
                // lifted coordinate.
                weatherWidget.homeX = weatherWidget.x
                weatherWidget.homeY = weatherWidget.y
                dw.weatherPosX = weatherWidget.homeX
                dw.weatherPosY = weatherWidget.homeY
                dw._savePositions()
            }
        }

        ColumnLayout {
            id: weatherContent
            anchors.fill: parent
            anchors.margins: 16 * dw._padScale
            spacing: 8 * dw._padScale

            // Top section — emoji+temp left, stats forced right
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 90 * dw._weatherScale

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 12 * dw._padScale

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: WeatherService.emojiIcon
                        font.pixelSize: 48 * dw._weatherScale
                    }

                    Column {
                        spacing: 1

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: WeatherService.temperature + "°C"
                            font.family: dw.weatherFont
                            font.pixelSize: 42 * dw._weatherScale
                            font.weight: Font.ExtraBold
                            color: dw._weatherTempColor
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: WeatherService.locationName
                            font.family: dw.weatherFont
                            font.pixelSize: 13 * dw._weatherScale
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                    }
                }

                // Stats forced to right edge
                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 4

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.right: parent.right
                        text: WeatherService.feelsLike + "°"
                        font.family: dw.weatherFont
                        font.pixelSize: 12 * dw._weatherScale
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.right: parent.right
                        text: WeatherService.humidity + "%"
                        font.family: dw.weatherFont
                        font.pixelSize: 12 * dw._weatherScale
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.right: parent.right
                        text: WeatherService.windSpeed + "km/h"
                        font.family: dw.weatherFont
                        font.pixelSize: 12 * dw._weatherScale
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }
            }

            // Condition + updated
            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: WeatherService.condition
                    font.family: dw.weatherFont
                    font.pixelSize: 14 * dw._weatherScale
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: WeatherService.lastUpdated !== ""
                    text: "Updated " + WeatherService.lastUpdated
                    font.family: dw.weatherFont
                    font.pixelSize: 10 * dw._weatherScale
                    color: Qt.rgba(1, 1, 1, 0.4)
                }
            }

            // Tap hint (collapsed)
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: !weatherWidget.weatherExpanded
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "▾ tap for hourly + 7-day"
                font.family: dw.weatherFont
                font.pixelSize: 10 * dw._weatherScale
                color: Qt.rgba(1, 1, 1, 0.45)
            }

            Rectangle {
                visible: weatherWidget.weatherExpanded
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // v7.0.0-beta.1-hf99zd: Hourly forecast (expanded)
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: weatherWidget.weatherExpanded && WeatherService.hourly.length > 0
                text: "Hourly forecast"
                font.family: dw.weatherFont
                font.pixelSize: 12 * dw._weatherScale
                font.weight: Font.Bold
                color: Qt.rgba(1, 1, 1, 0.85)
            }
            Flickable {
                visible: weatherWidget.weatherExpanded && WeatherService.hourly.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 96 * dw._weatherScale
                contentWidth: hourlyRow.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: hourlyRow
                    spacing: 12 * dw._padScale
                    Repeater {
                        model: WeatherService.hourly
                        delegate: Column {
                            required property var modelData
                            spacing: 3
                            width: 42 * dw._weatherScale
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp + "°"; font.family: dw.weatherFont; font.pixelSize: 14 * dw._weatherScale; font.weight: Font.Bold; color: "#ffffff" }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.emoji; font.pixelSize: 20 * dw._weatherScale }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.precip + "%"; font.family: dw.weatherFont; font.pixelSize: 10 * dw._weatherScale; font.weight: Font.Bold; color: modelData.precip >= 50 ? dw._weatherAccent : Qt.rgba(dw._weatherAccent.r, dw._weatherAccent.g, dw._weatherAccent.b, 0.75) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hour; font.family: dw.weatherFont; font.pixelSize: 10 * dw._weatherScale; color: Qt.rgba(1, 1, 1, 0.5) }
                        }
                    }
                }
            }

            Rectangle {
                visible: weatherWidget.weatherExpanded
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // Forecast: Today + 6 days with emoji cloud/sun icons
            RowLayout {
                visible: weatherWidget.weatherExpanded
                Layout.fillWidth: true
                spacing: 4 * dw._padScale

                Repeater {
                    model: {
                        const fc = WeatherService.forecast
                        if (!fc || fc.length === 0) return []
                        return fc.slice(0, 7)
                    }
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 72 * dw._weatherScale
                        radius: 8
                        color: index === 0 ? Qt.rgba(dw._weatherAccent.r, dw._weatherAccent.g, dw._weatherAccent.b, 0.18) : dw._tile(Qt.rgba(0.18, 0.18, 0.19, 0.4))
                        border.width: 1
                        border.color: index === 0 ? Qt.rgba(dw._weatherAccent.r, dw._weatherAccent.g, dw._weatherAccent.b, 0.45) : Qt.rgba(1, 1, 1, 0.05)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.day || "?"
                                font.family: dw.weatherFont
                                font.pixelSize: 10 * dw._weatherScale
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, index === 0 ? 0.9 : 0.6)
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.emoji || "☁️"
                                font.pixelSize: 18 * dw._weatherScale
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: (modelData.maxTemp !== undefined ? modelData.maxTemp : "--") + "°/" + (modelData.minTemp !== undefined ? modelData.minTemp : "--") + "°"
                                font.family: dw.weatherFont
                                font.pixelSize: 10 * dw._weatherScale
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, 0.8)
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: !WeatherService.forecast || WeatherService.forecast.length === 0
                    text: "Loading forecast..."
                    font.family: dw.weatherFont
                    font.pixelSize: 11 * dw._weatherScale
                    color: Qt.rgba(1, 1, 1, 0.4)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════
    // SYSTEM MONITOR — NO x/y binding, sparklines
    //
    // v6.16.1 additions:
    //   - Smooth drag (scale-only — no layer toggle, no external shadow,
    //     v6.16.1.3 ghost fix)
    //   - btop quick-launch button (upper-right corner)
    //   - Tab bar for multi-GPU: Overview | CPU | GPU0 | GPU1... | NET
    //     Overview is the original 2×2 grid (unchanged).
    //     Per-GPU tabs show full-screen sparkline + stats for that GPU.
    // ═══════════════════════════════════════════════════════════

    // Tab state — Overview by default. Valid values:
    //   "overview" | "cpu" | "gpu0" | "gpu1" | ... | "net"
    property string sysmonActiveTab: "overview"

    Rectangle {
        id: sysmonWidget
        visible: dw.sysmonEnabled && !dw.glanceMerged    // v8.0.0-alpha-hf113
        // NO x: or y: binding — set imperatively
        // v6.16.4.3: content-aware sizing (same as weather widget).
        // At low scales, grows to fit the 2×2 stats grid + tab bar
        // instead of clipping content. At high scales, _targetW/H
        // wins.
        readonly property real _targetW: (dw.sysmonStyle === "pills" ? 660 : 420) * dw._sysmonScale
        readonly property real _targetH: (dw.sysmonStyle === "pills" ? 470 : 420) * dw._sysmonScale
        width: Math.max(_targetW, sysmonContent.implicitWidth + (14 * dw._padScale * 2))
        height: Math.max(_targetH, sysmonContent.implicitHeight + (14 * dw._padScale * 2))
        radius: 16
        // v6.16.1.5: reactive background from WidgetsPage settings
        // v8.0.0-alpha-hf153: white frost on Glass+, your own bg on every other look.
        color: dw._bodyBg(dw.sysmonBgColor)
        // v6.16.1.8: disable color Behavior during drag
        Behavior on color {
            enabled: !sysmonDragArea.drag.active
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        border.width: dw._bodyBorderW(1)
        border.color: dw._bodyBorderC(Qt.rgba(1, 1, 1, 0.1))
        antialiasing: true

        // v6.16.1.8: REMOVED scale + Behavior on scale during drag

        MouseArea {
            id: sysmonDragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: sysmonWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - sysmonWidget.width
            drag.maximumY: dw.height - sysmonWidget.height
            drag.threshold: 5
            onReleased: {
                dw.sysmonPosX = sysmonWidget.x
                dw.sysmonPosY = sysmonWidget.y
                dw._savePositions()
            }
        }

        ColumnLayout {
            id: sysmonContent
            visible: dw.sysmonStyle === "classic"
            anchors.fill: parent
            anchors.margins: 14 * dw._padScale
            spacing: 8 * dw._padScale

            // ── Header row: title + btop button ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle { width: 3; height: 16; radius: 2; color: dw._accentFor("#ff453a") }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "SYSTEM MONITOR"
                    font.family: dw.sysmonFont
                    font.pixelSize: 12 * dw._sysmonScale
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
                Item { Layout.fillWidth: true }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: SystemMonitorService.cpuName
                    font.family: dw.sysmonFont
                    font.pixelSize: 10 * dw._sysmonScale
                    color: Qt.rgba(1, 1, 1, 0.5)
                    visible: dw.sysmonActiveTab === "overview"
                }

                // v6.16.1: btop button — upper-right corner.
                // Launches `alacritty --title btopWindow -e btop`
                // (or kitty/foot fallback). Toggle-kill pattern same as SysRow.
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 22
                    radius: 6
                    color: btopBtn.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12)
                        : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: "\uf2db"  // microchip / process icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13 * dw._sysmonScale
                        color: Qt.rgba(1, 1, 1, 0.9)
                    }

                    MouseArea {
                        id: btopBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Toggle-kill: close btop if already open, else launch.
                            // Prefer alacritty → kitty → foot.
                            btopProc.command = ["bash", "-c",
                                "if pgrep -f 'btop|btm' >/dev/null 2>&1 && "
                                + "pgrep -f 'alacritty.*btop\\|alacritty.*btm\\|kitty.*btop\\|foot.*btop' >/dev/null 2>&1; "
                                + "then pkill -f 'alacritty.*btop\\|alacritty.*btm\\|kitty.*btop\\|foot.*btop'; "
                                + "else "
                                + "  if command -v alacritty >/dev/null; then "
                                + "    alacritty --title btopWindow -e btop 2>/dev/null & "
                                + "  elif command -v kitty >/dev/null; then "
                                + "    kitty --title btopWindow btop 2>/dev/null & "
                                + "  elif command -v foot >/dev/null; then "
                                + "    foot --title btopWindow btop 2>/dev/null & "
                                + "  elif command -v alacritty >/dev/null; then "
                                + "    alacritty --title btopWindow -e btm 2>/dev/null & "
                                + "  fi; "
                                + "fi"]
                            btopProc.running = true
                        }
                    }
                }
            }

            // ── v6.16.1: Tab bar ──
            // Shows Overview + CPU + per-GPU + NET tabs. Auto-adapts to
            // the number of detected GPUs (SystemMonitorService.gpuCount).
            // On single-GPU systems collapses to 4 tabs.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Static tabs: Overview, CPU
                Repeater {
                    model: [
                        { id: "overview", label: "Overview" },
                        { id: "cpu",      label: "CPU" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: dw.sysmonActiveTab === modelData.id
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: tabLbl.implicitWidth + 16
                        radius: 6
                        color: isActive
                            ? Qt.rgba(0.3, 0.55, 0.9, 0.35)
                            : (tabMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : Qt.rgba(1, 1, 1, 0.03))
                        border.width: isActive ? 1 : 0
                        border.color: Qt.rgba(0.48, 0.78, 1.0, 0.6)

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            id: tabLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: dw.sysmonFont
                            font.pixelSize: 9 * dw._sysmonScale
                            font.weight: Font.DemiBold
                            color: parent.isActive ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.55)
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dw.sysmonActiveTab = modelData.id
                        }
                    }
                }

                // Per-GPU tabs — one per detected GPU
                Repeater {
                    model: SystemMonitorService.gpuCount
                    delegate: Rectangle {
                        required property int index
                        readonly property string tabId: "gpu" + index
                        readonly property bool isActive: dw.sysmonActiveTab === tabId
                        readonly property var gpu: SystemMonitorService.gpus[index] || {}
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: gpuTabLbl.implicitWidth + 16
                        radius: 6
                        color: isActive
                            ? Qt.rgba(0.3, 0.55, 0.9, 0.35)
                            : (gpuTabMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : Qt.rgba(1, 1, 1, 0.03))
                        border.width: isActive ? 1 : 0
                        border.color: Qt.rgba(0.48, 0.78, 1.0, 0.6)

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            id: gpuTabLbl
                            anchors.centerIn: parent
                            text: SystemMonitorService.gpuCount > 1
                                ? ("GPU" + index)
                                : "GPU"
                            font.family: dw.sysmonFont
                            font.pixelSize: 9 * dw._sysmonScale
                            font.weight: Font.DemiBold
                            color: parent.isActive ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.55)
                        }

                        MouseArea {
                            id: gpuTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dw.sysmonActiveTab = tabId
                        }
                    }
                }

                // NET tab
                Rectangle {
                    readonly property bool isActive: dw.sysmonActiveTab === "net"
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: netLbl.implicitWidth + 16
                    radius: 6
                    color: isActive
                        ? Qt.rgba(0.3, 0.55, 0.9, 0.35)
                        : (netTabMouse.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.rgba(1, 1, 1, 0.03))
                    border.width: isActive ? 1 : 0
                    border.color: Qt.rgba(0.48, 0.78, 1.0, 0.6)

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        id: netLbl
                        anchors.centerIn: parent
                        text: "NET"
                        font.family: dw.sysmonFont
                        font.pixelSize: 9 * dw._sysmonScale
                        font.weight: Font.DemiBold
                        color: parent.isActive ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.55)
                    }

                    MouseArea {
                        id: netTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dw.sysmonActiveTab = "net"
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Content area: GridLayout (overview) or tab detail ──
            // Overview: the original 2×2 grid (unchanged — wala tayong babawasan)
            GridLayout {
                visible: dw.sysmonActiveTab === "overview"
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                // CPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * dw._padScale
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "CPU"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "USAGE"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
                        }
                        Canvas {
                            id: cpuCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.cpuHistory
                            property color lc: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(cpuCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "TEMP"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°C" : "--"; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Bold; color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "USAGE"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.cpuPercent + "%"; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Bold; color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent) }
                        }
                    }
                }

                // GPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * dw._padScale
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "GPU"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "VRAM"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
                        }
                        Canvas {
                            id: gpuCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.gpuHistory
                            property color lc: SystemMonitorService.usageColor(SystemMonitorService.gpuUsage)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(gpuCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "TEMP"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.gpuTemp > 0 ? SystemMonitorService.gpuTemp + "°C" : "--"; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Bold; color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "VRAM"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.gpuVramUsed.toFixed(1) + "GB"; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.8) }
                        }
                    }
                }

                // RAM
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * dw._padScale
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "RAM"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "TOTAL"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
                        }
                        Canvas {
                            id: ramCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.ramHistory
                            property color lc: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(ramCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "USAGE"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.ramPercent + "%"; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Bold; color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "TOTAL"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.ramTotalGb.toFixed(0) + "GB"; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.8) }
                        }
                    }
                }

                // Network
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * dw._padScale
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "NETWORK"
                            font.family: dw.sysmonFont
                            font.pixelSize: 10 * dw._sysmonScale
                            font.weight: Font.DemiBold
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }
                        Canvas {
                            id: netCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.netHistory
                            property color lc: Qt.rgba(0.19, 0.82, 0.35, 0.9)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(netCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "DOWN"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.netDown; font.family: dw.sysmonFont; font.pixelSize: 12 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(0.19,0.82,0.35,0.9) }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "UP"; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.netUp; font.family: dw.sysmonFont; font.pixelSize: 12 * dw._sysmonScale; font.weight: Font.Bold; color: Qt.rgba(0.48,0.81,1.0,0.9) }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────
            // v6.16.1: Per-tab detail views (CPU / GPUn / NET)
            // Each is a single large sparkline + big stat readout.
            // Only one is visible at a time (matches the active tab).
            // ─────────────────────────────────────────────────────

            // CPU detail
            Rectangle {
                visible: dw.sysmonActiveTab === "cpu"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14 * dw._padScale
                    spacing: 6

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: SystemMonitorService.cpuName
                        font.family: dw.sysmonFont
                        font.pixelSize: 12 * dw._sysmonScale
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1,1,1,0.9)
                    }

                    Canvas {
                        id: cpuBigCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        property var hd: SystemMonitorService.cpuHistory
                        property color lc: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                        onHdChanged: requestPaint()
                        onPaint: dw.drawSparkline(cpuBigCanvas, hd, lc)
                        visible: parent.visible
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "TEMP"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°C" : "--"
                            font.family: dw.sysmonFont; font.pixelSize: 20 * dw._sysmonScale; font.weight: Font.Bold
                            color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp)
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "USAGE"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: SystemMonitorService.cpuPercent + "%"
                            font.family: dw.sysmonFont; font.pixelSize: 20 * dw._sysmonScale; font.weight: Font.Bold
                            color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                        }
                    }
                }
            }

            // Per-GPU detail (Repeater — one Rectangle per GPU)
            Repeater {
                model: SystemMonitorService.gpuCount
                delegate: Rectangle {
                    required property int index
                    readonly property string tabId: "gpu" + index
                    readonly property var g: SystemMonitorService.gpus[index] || {}
                    visible: dw.sysmonActiveTab === tabId
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * dw._padScale
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                // v7.0.0-beta.1: null guards on g.* access. Repeater
                                // delegates sometimes evaluate bindings before modelData
                                // is fully bound, causing repeated TypeErrors that pile
                                // up memory.
                                text: (parent.parent.g && parent.parent.g.name)
                                      || ("GPU " + (parent.parent.index || 0))
                                font.family: dw.sysmonFont
                                font.pixelSize: 12 * dw._sysmonScale
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1,1,1,0.9)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: ((parent.parent.g && parent.parent.g.type) || "").toUpperCase()
                                font.family: dw.sysmonFont
                                font.pixelSize: 9 * dw._sysmonScale
                                font.weight: Font.Bold
                                color: {
                                    const t = (parent.parent.g && parent.parent.g.type) || ""
                                    if (t === "nvidia") return "#76b900"
                                    if (t === "amd") return "#ed1c24"
                                    if (t === "intel") return "#0071c5"
                                    return Qt.rgba(1,1,1,0.5)
                                }
                            }
                        }

                        Canvas {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property var hd: parent.parent.g.history || []
                            property color lc: SystemMonitorService.usageColor(parent.parent.g.usage || 0)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(this, hd, lc)
                        }

                        // "No metrics" placeholder for secondary GPUs
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: !parent.parent.g.hasMetrics
                            text: "(no live metrics for secondary GPU)"
                            font.family: dw.sysmonFont
                            font.pixelSize: 10 * dw._sysmonScale
                            color: Qt.rgba(1,1,1,0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            visible: parent.parent.g.hasMetrics

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "TEMP"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: (parent.parent.parent.g.temp || 0) > 0 ? (parent.parent.parent.g.temp + "°C") : "--"
                                font.family: dw.sysmonFont; font.pixelSize: 20 * dw._sysmonScale; font.weight: Font.Bold
                                color: SystemMonitorService.tempColor(parent.parent.parent.g.temp || 0)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "USAGE"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: (parent.parent.parent.g.usage || 0) + "%"
                                font.family: dw.sysmonFont; font.pixelSize: 20 * dw._sysmonScale; font.weight: Font.Bold
                                color: SystemMonitorService.usageColor(parent.parent.parent.g.usage || 0)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            visible: parent.parent.g.hasMetrics && (parent.parent.g.vramTotal || 0) > 0

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "VRAM"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: (parent.parent.parent.g.vramUsed || 0).toFixed(1) + " / "
                                      + (parent.parent.parent.g.vramTotal || 0).toFixed(0) + " GB"
                                font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.DemiBold
                                color: Qt.rgba(1,1,1,0.85)
                            }
                        }
                    }
                }
            }

            // NET detail
            Rectangle {
                visible: dw.sysmonActiveTab === "net"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: dw._tile(Qt.rgba(0.14, 0.14, 0.16, 0.6))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14 * dw._padScale
                    spacing: 6

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "NETWORK"; font.family: dw.sysmonFont; font.pixelSize: 12 * dw._sysmonScale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.9) }

                    Canvas {
                        id: netBigCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        property var hd: SystemMonitorService.netHistory
                        property color lc: Qt.rgba(0.19, 0.82, 0.35, 0.9)
                        onHdChanged: requestPaint()
                        onPaint: dw.drawSparkline(netBigCanvas, hd, lc)
                        visible: parent.visible
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "DOWN"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: SystemMonitorService.netDown
                            font.family: dw.sysmonFont; font.pixelSize: 20 * dw._sysmonScale; font.weight: Font.Bold
                            color: Qt.rgba(0.19,0.82,0.35,0.9)
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "UP"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: SystemMonitorService.netUp
                            font.family: dw.sysmonFont; font.pixelSize: 20 * dw._sysmonScale; font.weight: Font.Bold
                            color: Qt.rgba(0.48,0.81,1.0,0.9)
                        }
                    }
                }
            }
        }

        // ── v7.0.0-beta.1-hf99zf: PILLS design (capsule cards, Pixel-ish) ──
        ColumnLayout {
            id: sysmonPills
            visible: dw.sysmonStyle === "pills"
            anchors.fill: parent
            anchors.margins: 18 * dw._sysmonScale
            spacing: 12 * dw._sysmonScale

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { width: 4; height: 26 * dw._sysmonScale; radius: 2; color: dw._accentFor("#0a84ff") }
                ColumnLayout {
                    spacing: 0
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "SYSTEM MONITOR"; font.family: dw.sysmonFont; font.pixelSize: 19 * dw._sysmonScale; font.weight: Font.Black; font.letterSpacing: 0.5; color: dw.widgetTextColor }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Real-time overview of your system performance"; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.6) }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 3
                    Repeater {
                        model: [
                            { g: "\uf2db", n: "CPU", v: SystemMonitorService.cpuName, c: "#1268d3" },
                            { g: "\uf1b2", n: "GPU", v: SystemMonitorService.gpuName, c: "#1e8e3e" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: chipRow.implicitWidth + 20 * dw._sysmonScale
                            implicitHeight: 28 * dw._sysmonScale
                            radius: height / 2
                            color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.06)
                            border.width: 1; border.color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.15)
                            antialiasing: true
                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6 * dw._sysmonScale
                                Rectangle {
                                    width: 20 * dw._sysmonScale; height: width; radius: width / 2
                                    color: dw._accentFor(modelData.c); antialiasing: true
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.centerIn: parent; text: modelData.g; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 * dw._sysmonScale; color: "#ffffff" }
                                }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: modelData.n; font.family: dw.sysmonFont; font.pixelSize: 11 * dw._sysmonScale; font.weight: Font.Black; color: dw._accentFor(modelData.c) }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: modelData.v; font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale; color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.8); elide: Text.ElideRight; Layout.maximumWidth: 120 * dw._sysmonScale }
                            }
                        }
                    }
                }
            }

            // the 5 capsule cards
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10 * dw._sysmonScale

                Repeater {
                    model: [
                        { key: "cpu",  label: "CPU",     accent: "#1268d3", glyph: "\uf2db",
                          pct: SystemMonitorService.cpuPercent,
                          s1v: (SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°" : "—"), s1l: "Temperature",
                          s2v: (SystemMonitorService.cpuMhz > 0 ? (SystemMonitorService.cpuMhz / 1000).toFixed(1) + " GHz" : "—"), s2l: "Clock Speed",
                          spark: true, hist: SystemMonitorService.cpuHistory },
                        { key: "gpu",  label: "GPU",     accent: "#1e8e3e", glyph: "\uf1b2",
                          pct: SystemMonitorService.gpuUsage,
                          s1v: (SystemMonitorService.gpuTemp > 0 ? SystemMonitorService.gpuTemp + "°" : "—"), s1l: "Temperature",
                          s2v: (SystemMonitorService.gpuMhz > 0 ? SystemMonitorService.gpuMhz + " MHz" : "—"), s2l: "Clock Speed",
                          spark: true, hist: SystemMonitorService.gpuHistory },
                        { key: "ram",  label: "RAM",     accent: "#1a56db", glyph: "\uefc5",
                          pct: SystemMonitorService.ramPercent,
                          s1v: SystemMonitorService.ramUsedGb.toFixed(1) + " / " + SystemMonitorService.ramTotalGb.toFixed(0) + "G", s1l: "Used",
                          s2v: (SystemMonitorService.ramTotalGb - SystemMonitorService.ramUsedGb).toFixed(1) + " GB", s2l: "Available",
                          spark: false, hist: [] },
                        { key: "vram", label: "VRAM",    accent: "#7c3aed", glyph: "\uefc5",
                          pct: (SystemMonitorService.gpuVramTotal > 0 ? Math.round(SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100) : 0),
                          s1v: SystemMonitorService.gpuVramUsed.toFixed(1) + " / " + SystemMonitorService.gpuVramTotal.toFixed(0) + "G", s1l: "Used",
                          s2v: (SystemMonitorService.gpuVramTotal - SystemMonitorService.gpuVramUsed).toFixed(1) + " GB", s2l: "Available",
                          spark: false, hist: [] },
                        { key: "net",  label: "NETWORK", accent: "#ea580c", glyph: "\uf1eb",
                          pct: -1,
                          s1v: SystemMonitorService.netUp, s1l: "Upload",
                          s2v: SystemMonitorService.netDown, s2l: "Download",
                          spark: true, hist: SystemMonitorService.netHistory }
                    ]

                    delegate: Rectangle {
                        id: pillCard
                        required property var modelData
                        // v8.0.0-alpha-hf104: cap the capsule so a tall card gives
                        // breathing room instead of stretching into a sausage.
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumHeight: 300 * dw._sysmonScale
                        Layout.maximumWidth: 170 * dw._sysmonScale
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        radius: Math.min(width, height) / 2
                        color: dw._sysmonCardBg
                        antialiasing: true
                        border.width: 1
                        border.color: dw._cardLine

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 22 * dw._sysmonScale
                            width: parent.width - 24 * dw._sysmonScale
                            spacing: 6 * dw._sysmonScale

                            // icon badge
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 44 * dw._sysmonScale; height: width; radius: width / 2
                                color: dw._accentFor(pillCard.modelData.accent)
                                antialiasing: true
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: pillCard.modelData.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 * dw._sysmonScale; color: "#ffffff" }
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pillCard.modelData.label
                                font.family: dw.sysmonFont; font.pixelSize: 13 * dw._sysmonScale
                                font.weight: Font.Black; color: dw._accentFor(pillCard.modelData.accent)
                            }

                            // big % (or net arrows)
                            Row {
                                visible: pillCard.modelData.pct >= 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 1
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    text: pillCard.modelData.pct
                                    font.family: dw.sysmonFont; font.pixelSize: 40 * dw._sysmonScale
                                    font.weight: Font.Black; color: dw._accentFor(pillCard.modelData.accent)
                                }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    text: "%"; anchors.top: parent.top
                                    font.family: dw.sysmonFont; font.pixelSize: 15 * dw._sysmonScale
                                    font.weight: Font.Bold; color: dw._accentFor(pillCard.modelData.accent)
                                }
                            }
                            Column {
                                visible: pillCard.modelData.pct < 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2 * dw._sysmonScale
                                Row {
                                    spacing: 5
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: "\u2191"; font.pixelSize: 17 * dw._sysmonScale; font.weight: Font.Black; color: dw._accentFor(pillCard.modelData.accent) }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: SystemMonitorService.netUp; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Black; color: dw._accentFor(pillCard.modelData.accent) }
                                }
                                Row {
                                    spacing: 5
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: "\u2193"; font.pixelSize: 17 * dw._sysmonScale; font.weight: Font.Black; color: dw._accentFor(pillCard.modelData.accent) }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: SystemMonitorService.netDown; font.family: dw.sysmonFont; font.pixelSize: 14 * dw._sysmonScale; font.weight: Font.Black; color: dw._accentFor(pillCard.modelData.accent) }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.8; height: 1
                                color: dw._cardLine
                            }

                            // stats (two columns) — hidden for net (arrows already show it)
                            Row {
                                visible: pillCard.modelData.pct >= 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 10 * dw._sysmonScale
                                Column {
                                    spacing: 0
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.horizontalCenter: parent.horizontalCenter; text: pillCard.modelData.s1v; font.family: dw.sysmonFont; font.pixelSize: 11 * dw._sysmonScale; font.weight: Font.Bold; color: dw._cardText }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.horizontalCenter: parent.horizontalCenter; text: pillCard.modelData.s1l; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; color: dw._cardSubText }
                                }
                                Column {
                                    spacing: 0
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.horizontalCenter: parent.horizontalCenter; text: pillCard.modelData.s2v; font.family: dw.sysmonFont; font.pixelSize: 11 * dw._sysmonScale; font.weight: Font.Bold; color: dw._cardText }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.horizontalCenter: parent.horizontalCenter; text: pillCard.modelData.s2l; font.family: dw.sysmonFont; font.pixelSize: 8 * dw._sysmonScale; color: dw._cardSubText }
                                }
                            }
                        }

                        // graph area + footer, pinned to the bottom of the capsule
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 26 * dw._sysmonScale
                            width: parent.width - 30 * dw._sysmonScale
                            spacing: 8 * dw._sysmonScale

                            // sparkline (cpu/gpu/net)
                            Canvas {
                                id: pillSpark
                                visible: pillCard.modelData.spark
                                width: parent.width; height: 34 * dw._sysmonScale
                                antialiasing: true
                                property var hd: pillCard.modelData.hist
                                property color lc: dw._accentFor(pillCard.modelData.accent)
                                onHdChanged: requestPaint()
                                onPaint: dw.drawSparkline(this, hd, lc)
                            }

                            // progress bar (ram/vram)
                            Rectangle {
                                visible: !pillCard.modelData.spark
                                width: parent.width; height: 12 * dw._sysmonScale
                                radius: height / 2
                                color: dw._cardLine
                                antialiasing: true
                                Rectangle {
                                    width: Math.max(parent.height, parent.width * Math.min(1, pillCard.modelData.pct / 100))
                                    height: parent.height; radius: height / 2
                                    color: dw._accentFor(pillCard.modelData.accent)
                                    antialiasing: true
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pillCard.modelData.pct >= 0 ? (pillCard.modelData.pct + "% Usage") : "Network Traffic"
                                font.family: dw.sysmonFont; font.pixelSize: 10 * dw._sysmonScale
                                font.weight: Font.Bold; color: dw._accentFor(pillCard.modelData.accent)
                            }
                        }
                    }
                }
            }
        }

        Process { id: btopProc; running: false }
    }

    // ═══════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf113 — GLANCE (merged weather + system blob)
    //
    // Only alive when glance.merged is true; weatherWidget/sysmonWidget
    // are gated off above in that case. Position is stored separately
    // (positions.glanceX/Y) so toggling merge back and forth doesn't
    // move the classic widgets.
    // ═══════════════════════════════════════════════════════════
    ZenGlanceWidget {
        id: glanceWidget
        visible: dw.glanceMerged && (dw.weatherEnabled || dw.sysmonEnabled)

        // v8.0.0-alpha-hf125 — same lift, driven by the blob→card→detail view.
        property real homeX: 0
        property real homeY: 0
        property string _prevView: "blob"
        z: view === "blob" ? 1 : 30
        Behavior on x { enabled: dw._liftAnim; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: dw._liftAnim; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        function _lift() {
            // targetWidth/Height, not width/height: the blob has a 620ms size
            // Behavior and we'd otherwise solve against a half-grown box.
            const p = dw._resolveLift(glanceWidget, homeX, homeY, targetWidth, targetHeight)
            x = p.x; y = p.y
        }
        onViewChanged: {
            dw._liftAnim = true
            if (_prevView === "blob" && view !== "blob") { homeX = x; homeY = y }
            if (view === "blob") { x = homeX; y = homeY }
            else Qt.callLater(glanceWidget._lift)
            _prevView = view
            // v8.0.0-alpha-hf156 — remember open/closed across restart.
            if (!dw._applyingOpen) { dw._openGlanceView = view; dw._savePositions() }
        }

        scaleFactor: dw._scale
        fontFamily: dw.glanceFont

        surfaceColor:   dw._glanceSurface
        surfaceOpacity: dw.glanceSurfaceOpacity
        inkMode:        dw.glanceInkMode
        inkCustom:      dw.glanceInkColor
        accentColor:    dw._glanceAccent

        weatherEnabled: dw.weatherEnabled
        sysmonEnabled:  dw.sysmonEnabled

        onMoved: (px, py) => {
            glanceWidget.homeX = px
            glanceWidget.homeY = py
            dw.glancePosX = px
            dw.glancePosY = py
            dw._savePositions()
        }
    }

    // ═══════════════════════════════════════════════════════════
    // WEATHER — PIXEL STYLE  (v8.0.0-alpha-hf156)
    // A weather-only ZenGlanceWidget blob: the merged glance's look, but
    // sysmonEnabled:false, so it shows only weather (the porcelain 27° blob) and
    // the system face is unreachable — toggleFace() no-ops when sysmon is off.
    // Shares the weather widget's position slot (weatherPosX/Y) so switching
    // Standard⇄Pixel never moves it. Standalone only (hidden when merged).
    // ═══════════════════════════════════════════════════════════
    ZenGlanceWidget {
        id: weatherPixelWidget
        visible: dw.weatherEnabled && !dw.glanceMerged && dw.weatherStyle === "pixel"

        property real homeX: 0
        property real homeY: 0
        property string _prevView: "blob"
        z: view === "blob" ? 1 : 30
        Behavior on x { enabled: dw._liftAnim; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: dw._liftAnim; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        function _lift() {
            const p = dw._resolveLift(weatherPixelWidget, homeX, homeY, targetWidth, targetHeight)
            x = p.x; y = p.y
        }
        onViewChanged: {
            dw._liftAnim = true
            if (_prevView === "blob" && view !== "blob") { homeX = x; homeY = y }
            if (view === "blob") { x = homeX; y = homeY }
            else Qt.callLater(weatherPixelWidget._lift)
            _prevView = view
            if (!dw._applyingOpen) { dw._openWeatherPixelView = view; dw._savePositions() }
        }

        scaleFactor: dw._weatherScale
        fontFamily:  dw.weatherFont

        // Theme flows through the weather widget's own colour settings.
        surfaceColor:   dw._weatherPixelSurface
        surfaceOpacity: 0.96
        inkMode:        "auto"
        accentColor:    dw._weatherAccent

        weatherEnabled: true
        sysmonEnabled:  false

        onMoved: (px, py) => {
            weatherPixelWidget.homeX = px
            weatherPixelWidget.homeY = py
            dw.weatherPosX = px
            dw.weatherPosY = py
            dw._savePositions()
        }
    }

    // ═══════════════════════════════════════════════════════════
    // SPARKLINE
    // ═══════════════════════════════════════════════════════════
    function drawSparkline(canvas, data, lineColor) {
        const ctx = canvas.getContext("2d")
        const w = canvas.width
        const h = canvas.height
        if (!ctx || w <= 0 || h <= 0) return
        ctx.clearRect(0, 0, w, h)
        if (!data || data.length < 2) return

        const len = data.length
        const stepX = w / (len - 1)

        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
        ctx.lineWidth = 0.5
        for (let g = 1; g < 4; g++) {
            ctx.beginPath()
            ctx.moveTo(0, h * g / 4)
            ctx.lineTo(w, h * g / 4)
            ctx.stroke()
        }

        const grad = ctx.createLinearGradient(0, 0, 0, h)
        grad.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.25))
        grad.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.02))
        ctx.beginPath()
        ctx.moveTo(0, h)
        for (let i = 0; i < len; i++) {
            ctx.lineTo(i * stepX, h - (Math.min(data[i], 100) / 100) * h)
        }
        ctx.lineTo(w, h)
        ctx.closePath()
        ctx.fillStyle = grad
        ctx.fill()

        ctx.beginPath()
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        for (let i = 0; i < len; i++) {
            const x = i * stepX
            const y = h - (Math.min(data[i], 100) / 100) * h
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
        ctx.stroke()
    }

    // ═════════════════════════════════════════════════════════════
    // v7.0.0-beta.1-hf82r — Collision-region registration
    // ═════════════════════════════════════════════════════════════
    //
    // The new DesktopSurface (also mounted in this widgetWindow as
    // sibling) auto-flows file/folder icons across the screen.
    // Without coordination it'd happily place icons on top of the
    // clock / weather / sysmon widgets that we render below.
    //
    // Fix: each visible widget self-registers its bounding box in
    // DesktopIconsState.collisionRegions. The DesktopSurface flow
    // algorithm consults this and skips cells that would overlap.
    //
    // Connections-based — no edits to the widget Rectangle blocks
    // themselves, purely additive. Re-fires on x/y/visible change so
    // dragging a widget updates the collision map live.
    //
    // Region id format: "<type>-<screenName>" so multi-monitor users
    // get one entry per (widget, monitor) pair without ID collisions.

    function _regionId(widgetType) {
        // Best-effort screen name. The dw root sits inside a
        // PanelWindow with `screen: modelData` — Qt exposes it as
        // the parent surface name via Window.window?.screen.name.
        let scr = ""
        try {
            if (Window && Window.window && Window.window.screen) {
                scr = Window.window.screen.name || ""
            }
        } catch (e) {}
        return widgetType + "-" + (scr || "default")
    }

    Connections {
        target: clockWidget
        function _update() {
            if (typeof DesktopIconsState === "undefined") return
            const id = _regionId("clock")
            if (clockWidget.visible && clockWidget.width > 0) {
                DesktopIconsState.registerCollisionRegion(
                    id, clockWidget.x, clockWidget.y,
                    clockWidget.width, clockWidget.height)
            } else {
                DesktopIconsState.unregisterCollisionRegion(id)
            }
        }
        function onXChanged()       { _update() }
        function onYChanged()       { _update() }
        function onWidthChanged()   { _update() }
        function onHeightChanged()  { _update() }
        function onVisibleChanged() { _update() }
    }

    Connections {
        target: weatherWidget
        function _update() {
            if (typeof DesktopIconsState === "undefined") return
            const id = _regionId("weather")
            if (weatherWidget.visible && weatherWidget.width > 0) {
                DesktopIconsState.registerCollisionRegion(
                    id, weatherWidget.x, weatherWidget.y,
                    weatherWidget.width, weatherWidget.height)
            } else {
                DesktopIconsState.unregisterCollisionRegion(id)
            }
        }
        function onXChanged()       { _update() }
        function onYChanged()       { _update() }
        function onWidthChanged()   { _update() }
        function onHeightChanged()  { _update() }
        function onVisibleChanged() { _update() }
    }

    Connections {
        target: sysmonWidget
        function _update() {
            if (typeof DesktopIconsState === "undefined") return
            const id = _regionId("sysmon")
            if (sysmonWidget.visible && sysmonWidget.width > 0) {
                DesktopIconsState.registerCollisionRegion(
                    id, sysmonWidget.x, sysmonWidget.y,
                    sysmonWidget.width, sysmonWidget.height)
            } else {
                DesktopIconsState.unregisterCollisionRegion(id)
            }
        }
        function onXChanged()       { _update() }
        function onYChanged()       { _update() }
        function onWidthChanged()   { _update() }
        function onHeightChanged()  { _update() }
        function onVisibleChanged() { _update() }
    }
}
