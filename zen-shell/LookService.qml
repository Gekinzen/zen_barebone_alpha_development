pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/*
 * LookService v7.0.0-beta.1-hf99l — Karui (軽い)
 *
 * Shell Look presets — one UI "personality" applied across surfaces
 * (bar / control panel / start menu / dock / notifications / OSD).
 *
 * ADDITIVE. Zen (the current v7 default) is untouched — it's just one
 * look among several. Switching looks only re-reads the token set below;
 * nothing is removed. The active look + per-surface apply flags live in
 * PanelState (persisted with everything else), so this service stays a
 * thin, stateless token layer.
 *
 * A "look" is a token set:
 *   name          display name
 *   desc          one-liner for the picker
 *   radiusScale   multiplier on each surface's base corner radius
 *                 (1.0 = as designed, <1 = squarer, ~0.35 = classic flat)
 *   panelOpacity  panel background opacity (glass = more transparent)
 *   borderAlpha   panel border alpha
 *   blur          wants Hyprland layer blur (Glass; injected via
 *                 look_and_feel.conf when applied — see note in the page)
 *   glow          soft outer glow / depth
 *   animated      enable the shell's motion (Zen/Glass) vs still (Classic)
 *
 * Surfaces read `LookService.current.<token>` and gate it on their own
 * apply flag, e.g.:
 *   radius: PanelState.lookApplyControlPanel
 *           ? Math.round(16 * LookService.current.radiusScale) : 16
 */
Singleton {
    id: root

    // The active look id, mirrored from PanelState (single source of truth).
    readonly property string activeLook: PanelState.shellLook

    // v8.0.0-alpha-hf112: a look is now a PRESET, not an override.
    // Picking one WRITES these values into the real settings (bar opacity,
    // radius, dock, panels). After that the user's own sliders are the single
    // source of truth again — before this, the look silently swallowed them and
    // the Bar Opacity slider appeared dead.
    readonly property var looks: ({
        "classic": {
            id: "classic", name: "Classic — Stock",
            desc: "Flat, square, opaque — stock bar vibe",
            radiusScale: 0.18, panelOpacity: 1.0, borderAlpha: 0.28,
            barRadius: 4, panelRadius: 6,
            blur: false, glow: false, animated: false
        },
        "zen": {
            id: "zen", name: "Zen — Dynamic",
            desc: "Rounded, animated, theme-driven",
            radiusScale: 1.0, panelOpacity: 0.96, borderAlpha: 0.12,
            barRadius: 22, panelRadius: 16,
            blur: true, glow: false, animated: true
        },
        "glass": {
            id: "glass", name: "Glass — Advanced",
            desc: "Frosted layer blur + depth + glow",
            radiusScale: 1.35, panelOpacity: 0.58, borderAlpha: 0.30,
            barRadius: 24, panelRadius: 20,
            blur: true, glow: true, animated: true
        },
        // v8.0.0-alpha-hf144 — "wala na anything colors, as in clear siya."
        //
        // Glass+ is the clear one. Glass sits at 0.58 fill and still shows theme
        // tint; Glass+ drops the fill to almost nothing and lets Hyprland's blur
        // be the whole material. Its fill and blur are NOT fixed here — they are
        // driven live by PanelState.glassStrength via glassFill/glassBlur below,
        // so the single slider on the Shell Look page moves the entire frost.
        // panelOpacity here is only what the preset WRITES on first pick.
        "glassplus": {
            id: "glassplus", name: "Glass — Advanced+",
            desc: "Fully clear · blur is the material · draggable frost",
            radiusScale: 1.35, panelOpacity: 0.068, borderAlpha: 0.22,
            barRadius: 24, panelRadius: 22,
            blur: true, glow: true, animated: true,
            clear: true
        },
        "minimal": {
            id: "minimal", name: "Minimal — Focus",
            desc: "Quiet, low-contrast, distraction-free",
            radiusScale: 0.6, panelOpacity: 0.90, borderAlpha: 0.05,
            barRadius: 12, panelRadius: 10,
            blur: false, glow: false, animated: false
        },
        "custom": {
            id: "custom", name: "Custom",
            desc: "Your current sliders — nothing is overwritten",
            radiusScale: 1.0, panelOpacity: 0.96, borderAlpha: 0.12,
            barRadius: 22, panelRadius: 16,
            blur: true, glow: false, animated: true
        }
    })

    // Ordered ids for pickers.
    readonly property var order: ["classic", "zen", "glass", "glassplus", "minimal", "custom"]

    // The active token set (falls back to Zen if an unknown id sneaks in).
    readonly property var current: looks[activeLook] || looks["zen"]

    // Explicit, individually-reactive tokens. Surfaces bind to these
    // directly (LookService.panelOpacity, etc.) so there's zero doubt about
    // property-var reactivity across the singleton — they update the instant
    // PanelState.shellLook changes.
    readonly property real radiusScale: current.radiusScale
    readonly property real panelOpacity: current.panelOpacity
    readonly property real borderAlpha: current.borderAlpha
    readonly property bool glow: current.glow
    readonly property bool blur: current.blur
    readonly property bool animated: current.animated

    // v8.0.0-alpha-hf144 — Glass+ extras.
    //
    // `isClear` is the flag surfaces gate on to drop their theme tint to a
    // neutral white frost. `glassFill` / `glassBlur` map PanelState.glassStrength
    // through the curve tuned in hf144: strength 0 → a faint 0.14 pane, 1 → a
    // near-invisible 0.04 with almost everything behind it blurred. The border
    // is deliberately NOT on this curve — panels must stay legible at full glass.
    readonly property bool isClear: current.clear === true

    // v8.0.0-alpha-hf146 — "white lahat ng icons?" A monochrome-icon mode for the
    // dock and bar taskbars. It is a toggle, mirrored from PanelState. Glass+ turns
    // it ON by default (see applyPreset) because the clear look wants uniform white
    // icons; every other look leaves your colourful icons alone. The toggle is
    // independent of the look, though — you can force white on any look, or keep
    // colour on Glass+.
    readonly property bool monoIcons: PanelState.monoIcons
    readonly property bool taskbarIconBackgrounds: PanelState.taskbarIconBackgrounds
    // The colour to tint them. On the clear look it AUTO-CONTRASTS with the panel
    // (v8.0.0-alpha-hf160) — same clearInk the text uses — so icons never end up white
    // on a light panel while the text went dark. On other looks, the theme foreground.
    readonly property color iconTint: isClear ? clearInk : ThemeService.fg

    readonly property real glassFill: {
        // v8.0.0-alpha-hf146 — the floor was 0.04 at 100%, which read as "the
        // panel disappeared", especially where Hyprland blur isn't catching the
        // layer. Floor lifted to 0.10 and the whole range nudged up: even at max
        // frost there is a visible pane. 0% 0.22 (clearly a card) → 100% 0.10.
        const st = Math.max(0, Math.min(1, PanelState.glassStrength))
        return 0.22 - 0.12 * st
    }
    // Hyprland layerrule ignore_alpha: lower blurs more of the translucent panel.
    readonly property real glassBlur: {
        const st = Math.max(0, Math.min(1, PanelState.glassStrength))
        return 0.60 - 0.50 * st
    }

    // v8.0.0-alpha-hf158 — SMART READABILITY on the clear look.
    //
    // The clear frost is white. Over a dark wallpaper that's fine (white text/icons
    // read against the dark blur). Over a bright/white wallpaper it's white-on-white
    // and the text vanishes — exactly what Paul hit. Rather than pick one look, we
    // read the wallpaper's mean luminance (WallpaperServiceV5.wallpaperLuminance) and
    // ramp a dark "smoke" into the frost ONLY as the wallpaper gets bright:
    //   L ≤ 0.50  → smoke 0   → the same white glass as before (nothing changes)
    //   L ≥ 0.82  → smoke 1   → a smoked panel, so white text/icons stay legible
    // and a smooth blend in between. Not a hard switch, and dark wallpapers are
    // completely untouched.
    // v8.0.0-alpha-hf160 — Glass+ keeps its WHITE glass (Paul: "maganda glass feels
    // padin katulad ng current"); readability now comes from DYNAMIC TEXT instead of
    // darkening the frost. Effective panel luminance = the wallpaper, lightened by the
    // white frost on top. Text auto-contrasts against THAT: dark ink on a light panel,
    // white ink on a dark one. ThemeService.fg / grey0 / grey1 / grey2 read these on
    // the clear look, so the WHOLE shell adapts from one place — no per-component edits.
    // (Reads only PanelState + WallpaperServiceV5, never ThemeService, so no cycle.)
    readonly property real clearPanelLuma: {
        if (!isClear) return 0
        const L = WallpaperServiceV5.wallpaperLuminance
        return L * (1 - glassFill) + 1.0 * glassFill
    }
    // Pivot 0.42 is the contrast-optimal split: on a light/medium panel dark text reads
    // far better than white (e.g. on a 0.51 panel, near-black scores ~3.7 vs white ~1.8),
    // so anything but a genuinely dark panel takes DARK ink; a dark panel keeps crisp
    // WHITE. (Paul's instinct was "white on bright", but white-on-light is the low-contrast
    // case — dark-on-light is what actually reads. Tunable if it leans wrong.)
    readonly property color clearInk:      Qt.rgba(1, 1, 1, 0.98)   // v8.0.0-alpha-hf163 — white text; outline gives contrast
    readonly property color clearInkDim:   Qt.rgba(1, 1, 1, 0.78)
    readonly property color clearInkFaint: Qt.rgba(1, 1, 1, 0.60)

    // The clear look's panel fill — plain white frost, the glass feel Paul wants back.
    function clearFill() {
        return Qt.rgba(1, 1, 1, glassFill)
    }

    // v8.0.0-alpha-hf162 — Paul's idea: WHITE text + a dark OUTLINE, so it reads over any
    // wallpaper WITHOUT darkening the glass (white-on-light fails; white-on-light-WITH-a-
    // dark-outline does not). QML has no global Text style, so components opt in per Text:
    //     color:      LookService.textColor(ThemeService.fg)      // white on clear
    //     style:      LookService.isClear ? Text.Outline : Text.Normal
    //     styleColor: LookService.clearTextOutline
    // On every other look these fall straight back to the passed value / Text.Normal, so
    // nothing regresses. Rolled out surface by surface; anything not yet converted keeps
    // the auto-contrast fg (still readable) until it is.
    readonly property color clearTextOutline: Qt.rgba(0, 0, 0, 0.60)
    function textColor(base)      { return isClear ? Qt.rgba(1, 1, 1, 0.98) : base }
    function textDimColor(base)   { return isClear ? Qt.rgba(1, 1, 1, 0.78) : base }
    function textFaintColor(base) { return isClear ? Qt.rgba(1, 1, 1, 0.60) : base }

    // v8.0.0-alpha-hf173 — ONE SURFACE RULE for the clear look.
    //
    // The outer frost was already neutral white (clearFill), but 221 inner surfaces
    // painted ThemeService.bgN straight, so a cream theme (Yousai) or a sage one
    // (Light Paper) turned every card and row into a solid sheet of that colour —
    // the glass vanished and the text stopped reading. Paul: "dapat may isa lang
    // tayo colour ... medyo may mix nung current theme pero mas malakas yun glass".
    //
    // surfaceColor() is the one rule they all route through now:
    //   • non-clear looks -> ThemeService.alpha(base, opacity): byte-identical to before
    //   • clear look      -> white tinted by `clearTint` of the theme's own bg4 (its most
    //                        characteristic colour), at an alpha SCALED from the caller's
    //                        intended opacity — so the depth hierarchy the pages were
    //                        designed with survives, but every surface lands in the glass
    //                        range instead of going opaque.
    // The theme still reads properly through ACCENTS (selected nav, toggles, sliders,
    // the palette swatches) — none of those go through here. That's the "kunting mixture".
    //
    // Two numbers to taste, both live here: clearTint (how much theme in the white) and
    // clearSurfaceScale (how much of the caller's opacity survives).
    readonly property real clearTint: 0.14
    readonly property real clearSurfaceScale: 0.20

    readonly property color clearSurfaceBase: {
        const a = ThemeService.bg4          // raw theme colour, never clear-modified
        const k = clearTint
        return Qt.rgba(1 - k + a.r * k, 1 - k + a.g * k, 1 - k + a.b * k, 1)
    }

    function surfaceColor(base, opacity) {
        if (!isClear) return ThemeService.alpha(base, opacity)
        const s = clearSurfaceBase
        const o = (opacity === undefined) ? 1.0 : opacity
        return Qt.rgba(s.r, s.g, s.b, Math.max(0.05, Math.min(0.22, o * clearSurfaceScale)))
    }

    // v8.0.0-alpha-hf174 — AUTOMATIC INK for surfaces that carry their own opaque
    // background (dropdown lists, menus, tooltips, search overlays).
    //
    // hf163 made every text white, which is right ON GLASS: the panel is mostly blurred
    // wallpaper, so white + the dark outline always reads. But a dropdown popup is NOT
    // glass — it paints its own near-opaque sheet (ZenDropdown did Qt.rgba(bg1…, 0.98)).
    // On a light theme that sheet is cream, and white-on-cream is invisible. That's the
    // theme list Paul couldn't read.
    //
    // So: anything with its own background asks what colour to write on it, instead of
    // assuming. inkOn() measures the background's relative luminance and returns white or
    // near-black accordingly — automatic on every theme, light or dark, forever.
    //
    // This is NOT the hf160 auto-contrast that got rejected: that darkened text on the
    // GLASS panels. This only touches surfaces that are opaque in the first place. Glass
    // keeps white + outline exactly as you approved it.
    function _lum(c) {
        function f(v) { return (v <= 0.03928) ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function inkOn(bg)    { return _lum(bg) > 0.42 ? Qt.rgba(0.09, 0.10, 0.12, 0.97) : Qt.rgba(1, 1, 1, 0.97) }
    function inkDimOn(bg) { return _lum(bg) > 0.42 ? Qt.rgba(0.09, 0.10, 0.12, 0.68) : Qt.rgba(1, 1, 1, 0.70) }

    // Popup sheets (menus/lists) need real body to stay legible over whatever is behind
    // them, so they don't take the low-alpha glass treatment. On the clear look they use
    // the same white-dominant tint as every other surface — one colour, still — just
    // opaque enough to read. popupInk/popupInkDim are the matching text colours.
    readonly property color popupBase: isClear ? clearSurfaceBase : ThemeService.bg1
    readonly property color popupInk: isClear ? inkOn(popupBase) : ThemeService.fg
    readonly property color popupInkDim: isClear ? inkDimOn(popupBase) : ThemeService.grey1
    // Borders, hover washes and separators inside a popup were all built from
    // ThemeService.fg at a low alpha, on the assumption fg contrasts with the sheet.
    // On the clear look fg is WHITE, so on a light sheet every one of them vanished —
    // not just the text: the hover feedback and the row separators went too. This is
    // the same ink at whatever alpha the caller wanted.
    function popupInkAlpha(a) {
        const c = popupInk
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    function popupColor(opacity) {
        const o = (opacity === undefined) ? 0.98 : opacity
        return Qt.rgba(popupBase.r, popupBase.g, popupBase.b, isClear ? Math.max(0.92, o) : o)
    }

    // A surface's panel fill: the clear look uses neutral white at glassFill;
    // every other look uses its own bg tint at the given opacity. One call.
    function panelColor(baseColor, opacity) {
        if (isClear)
            return clearFill()
        return ThemeService.alpha(baseColor, opacity)
    }

    // v8.0.0-alpha-hf147 — bar/dock BODY helpers.
    //
    // The dock and bars paint their body as bg0 × barOpacity. Glass+ wrote
    // barOpacity down to ~0.07, so the body went almost fully transparent —
    // "butas-butas", the wallpaper straight through. These give the panel bodies
    // the SAME frosted treatment the desktop panel already has: one neutral white
    // fill (no theme tint), and no border, but ONLY on the clear look. On every
    // other look they return the caller's own colour/border untouched, so nothing
    // regresses.
    //
    //   bodyColor(fallbackColor)  -> white frost on clear, else fallbackColor
    //   bodyBorderColor(fb)       -> transparent on clear, else fb
    //   bodyBorderWidth(fb)       -> 0 on clear, else fb
    function bodyColor(fallback) {
        if (isClear) return clearFill()
        return fallback
    }
    function bodyBorderColor(fallback) {
        if (isClear) return Qt.rgba(0, 0, 0, 0)
        return fallback
    }
    function bodyBorderWidth(fallback) {
        if (isClear) return 0
        return fallback
    }

    // Convenience — a surface passes its base radius; returns the
    // look-adjusted value when `on` (its apply flag) is true.
    function radiusFor(base, on) {
        return on ? Math.round(base * current.radiusScale) : base
    }

    // Set the active look. "custom" only records the choice — it never touches
    // your sliders. Every other look writes its preset into the real settings
    // for whichever surfaces you enabled under "Apply To".
    property bool _wasClear: isClear
    function setLook(id) {
        if (!looks[id]) return
        PanelState.shellLook = id
        if (id !== "custom") applyPreset(id)
        PanelState.saveState()
    }

    // Writes the preset into the actual settings, honouring the apply flags.
    function applyPreset(id) {
        const L = looks[id]
        if (!L) return
        if (PanelState.lookApplyBar) {
            Theme.barOpacity = L.panelOpacity
            Theme.barRadius = L.barRadius
            if (PanelState.bgOverrideEnabled) PanelState.bgOverrideOpacity = L.panelOpacity
        }
        if (PanelState.lookApplyDock && typeof DockState !== "undefined") {
            // When the dock mirrors the bar it already picks up Theme.barOpacity
            // above; only the independent dock needs its own values written.
            if (!DockState.syncFromBar) {
                DockState.overrideBgOpacity = L.panelOpacity
                DockState.overrideCornerRadius = L.barRadius
            }
        }
        if (PanelState.lookApplyControlPanel) PanelState.controlPanelOpacity = L.panelOpacity
        if (PanelState.lookApplyStartMenu)    PanelState.startMenuOpacity = L.panelOpacity
        if (PanelState.lookApplyNotifications) PanelState.notificationOpacity = L.panelOpacity
        // The Control Center window follows the panel look too.
        PanelState.dashOpacity = L.panelOpacity
        // v8.0.0-alpha-hf144 — Glass+ seeds the frost slider so first pick looks
        // right immediately; the user's drags own it afterward. Only seed when
        // switching INTO the clear look from a non-clear one, so re-picking
        // Glass+ doesn't stomp a frost the user has since tuned.
        if (L.clear === true && !_wasClear) {
            // v8.0.0-alpha-hf147 — seed a mid frost, and DON'T force white icons.
            // Paul wants colourful Apple-style icons on the glass; mono stays a
            // manual choice (the toggle is still there, just off by default).
            PanelState.glassStrength = 0.5
        }
        _wasClear = (L.clear === true)
    }

    // ── Glass frost: Hyprland layer blur ──────────────────────────
    // v7.0.0-beta.1-hf99n: apply a blur layerrule to all zen-shell-* layer
    // surfaces so Glass reads as TRUE frosted glass (not just transparent).
    // Blur is left on for every look — the panel opacity decides whether it
    // shows (Glass = transparent → frosted; Classic/Zen = opaque → hidden),
    // so no fragile runtime toggling is needed. This covers popups that
    // remap on open (Control Panel / Notifications / Start Menu) immediately;
    // persistent layers (Bar / Dock) also need the shipped
    // hypr-config/zen-shell-look.conf sourced in hyprland.conf (survives a
    // Hyprland restart). ignorealpha keeps text crisp over the blur.
    // v8.0.0-alpha-hf144 — the ignore_alpha now tracks glassBlur, so dragging
    // the frost slider actually reblurs the panels live (not just recolours
    // them). 0.35 was the fixed value; Glass+ sweeps it via glassBlur.
    property real _ignoreAlpha: isClear ? glassBlur : 0.35
    Process {
        id: _blurApply
        // v7.0.0-beta.1-hf99zr: Hyprland 0.55 changed layerrule syntax —
        // elements are now "key value" (space-separated), matchers take a
        // `match:` prefix, and `ignorealpha` was renamed `ignore_alpha`.
        // Try the new form first; if hyprctl rejects it (0.54 and older),
        // fall back to the legacy comma form. `hyprctl keyword` prints "ok"
        // on success, so that's the probe.
        command: ["bash", "-c",
            "command -v hyprctl >/dev/null 2>&1 || exit 0; " +
            "IA=" + root._ignoreAlpha.toFixed(2) + "; " +
            "if hyprctl keyword layerrule \"blur 1, ignore_alpha $IA, match:namespace ^(zen-shell-.*)$\" 2>/dev/null | grep -qi '^ok'; then " +
            "  exit 0; " +
            "fi; " +
            "hyprctl keyword layerrule 'blur, zen-shell-' >/dev/null 2>&1 || true; " +
            "hyprctl keyword layerrule \"ignorealpha $IA, zen-shell-\" >/dev/null 2>&1 || true"]
        running: false
    }
    // Re-fire when the frost changes (debounced so a slider drag doesn't spawn
    // a hyprctl per pixel).
    Timer {
        id: _blurDebounce
        interval: 120; repeat: false
        onTriggered: { _blurApply.running = false; _blurApply.running = true }
    }
    onGlassBlurChanged: if (isClear) _blurDebounce.restart()
    onIsClearChanged:   _blurDebounce.restart()

    // v8.0.0-alpha-hf155 — the login race. At first paint the zen-shell-* layer
    // surfaces aren't mapped yet, so the single Component.onCompleted hyprctl below
    // can apply the blur layerrule to nothing — the glass then shows at the wrong
    // strength until the frost slider is nudged (which re-fires _blurApply). This
    // re-sends the keyword a handful of times over the first few seconds, so the
    // rule lands the moment the layers exist. Idempotent: each run just re-issues
    // the same `hyprctl keyword layerrule` with the current IA, whatever the look.
    Timer {
        id: _blurStartup
        property int _tries: 0
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            _blurApply.running = false
            _blurApply.running = true
            _tries += 1
            if (_tries >= 5) running = false   // fires ~0.7s → 3.5s after login
        }
    }

    Component.onCompleted: _blurApply.running = true

    // v8.0.0-alpha-hf166 — the RELOAD race. A `hyprctl reload` (theme change, animation
    // preset, or any settings apply — SettingsState issues one) makes Hyprland re-read
    // its config and drop the LIVE blur layerrule we pushed via _blurApply, reverting to
    // the conf's static value and often remapping the zen-shell-* layers. At 100% glass
    // that reads as "the frost vanished, panels went transparent" (Paul's report). So on
    // every config reload we re-run the same startup re-apply burst, which re-pushes the
    // layerrule at the CURRENT glassiness once the layers are back. glassStrength itself
    // is the shell's own persisted state, untouched by the reload — only the Hyprland-
    // side rule was lost — so re-firing restores exactly the strength the user had.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "configreloaded") {
                _blurStartup._tries = 0
                _blurStartup.running = true
            }
        }
    }
}
