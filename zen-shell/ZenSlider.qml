import QtQuick
import QtQuick.Controls

/*
 * ZenSlider v7.0.0-beta.1-hf99 — Karui (軽い)
 *
 * The one true Zen slider. Circle handle, not square.
 *
 * This is a drop-in replacement for a bare QtQuick.Controls `Slider {}`.
 * It bakes in the exact circular-handle + themed-track styling we already
 * ship on the audio / mic volume sliders in ConnectivityPage, so every
 * slider across the whole control panel looks identical:
 *
 *   - Track:  4px tall, radius 2, fg @ 12% alpha
 *   - Fill:   accent colour (default ThemeService.blue), radius 2
 *   - Handle: 14×14 circle (radius 7), fg fill, 2px bg0 @ 50% border
 *
 * WHY A COMPONENT (not inline handle: blocks everywhere)
 * ──────────────────────────────────────────────────────
 * There were 37 bare `Slider {}` instances scattered across 11 pages, all
 * falling back to the default QQC2 (square-ish) handle. Instead of pasting
 * a background:/handle: block into each one — 37 copies to keep in sync —
 * we centralise the look here once. Bump the handle size / accent in ONE
 * place and every consumer refreshes.
 *
 * DROP-IN CONTRACT
 * ────────────────
 * Inherits `Slider`, so every property/signal a consumer already sets keeps
 * working untouched:
 *
 *   ZenSlider {
 *       from: 0; to: 100; stepSize: 1
 *       value: ConnectivityService.audioVolume
 *       onMoved: ...            // and onValueChanged, width:, Layout.*, etc.
 *   }
 *
 * Consumers that need a different fill colour just set `accent`:
 *
 *   ZenSlider { accent: ThemeService.purple; ... }   // e.g. mic
 *
 * THEME SAFETY
 * ────────────
 * Falls back to sane literals if ThemeService isn't resolved yet (same
 * defensive pattern as ZenDivider) so it never hard-errors on load-order.
 *
 * Wala tayong babawasan — additive component; no behaviour changed, only
 * the handle stopped being a square.
 */
Slider {
    id: control

    // ── Public knobs ──────────────────────────────────────────────
    // Fill colour of the "played" portion of the track.
    property color accent: (typeof ThemeService !== "undefined")
                           ? ThemeService.blue
                           : "#7aa2f7"
    // Handle diameter (kept identical to the audio slider reference).
    property real handleSize: 14
    // hf197 — value-space position of an optional track tick (-1 = none).
    property real tickAt: -1
    // Track thickness.
    property real trackHeight: 4

    // Sensible default so a slider dropped into a Row (no explicit width)
    // still has a usable length. Overridden by width: / Layout.fillWidth.
    implicitWidth: 180

    // v7.0.0-beta.1-hf99b — CRITICAL height fix. A QQC2 Slider derives its
    // implicitHeight from the handle/background implicit sizes. Our custom
    // handle/background set width/height but NOT implicit sizes, so the
    // control collapsed to ~0 available height inside a plain Row — the
    // track vanished and there was no hit-area to drag (the "L stuck at
    // 13%" + "background opacity slider disappeared" regression). Give the
    // control a real implicit height + comfortable interactive band.
    implicitHeight: Math.max(handleSize, trackHeight) + 12
    topPadding: 6
    bottomPadding: 6

    // ── Theme helpers (defensive against undefined ThemeService) ──
    readonly property color _fg: (typeof ThemeService !== "undefined")
                                 ? ThemeService.fg : "#c0caf5"
    readonly property color _bg0: (typeof ThemeService !== "undefined")
                                  ? ThemeService.bg0 : "#1a1b26"
    function _alpha(c, a) {
        return (typeof ThemeService !== "undefined")
               ? ThemeService.alpha(c, a)
               : Qt.rgba(c.r, c.g, c.b, a)
    }

    // ── Track (background + fill) ─────────────────────────────────
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: control.trackHeight
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: control.trackHeight
        radius: height / 2
        antialiasing: true
        color: control._alpha(control._fg, 0.12)

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            antialiasing: true
            color: control.enabled
                   ? control.accent
                   : control._alpha(control._fg, 0.25)
        }

        // v8.1.0-alpha-hf197 — optional tick marker. Consumers with a
        // boost range (volume 0..300) set `tickAt: 100` so the safe/boost
        // boundary is visible on the track. tickAt < from ⇒ hidden.
        Rectangle {
            visible: control.tickAt >= control.from && control.tickAt <= control.to
            x: (control.to > control.from)
               ? ((control.tickAt - control.from) / (control.to - control.from)) * parent.width - width / 2
               : 0
            y: -3
            width: 2
            height: parent.height + 6
            radius: 1
            antialiasing: true
            color: control._alpha(control._fg, 0.45)
        }
    }

    // ── Circle handle ─────────────────────────────────────────────
    // CRITICAL: antialiasing must be true. Qt Rectangles do NOT antialias
    // rounded corners by default, so a radius=width/2 "circle" renders
    // blocky/square at small sizes (this was the whole bug — the knobs were
    // mathematically circular but visually square). See CHANGELOG.
    handle: Rectangle {
        implicitWidth: control.handleSize
        implicitHeight: control.handleSize
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.handleSize
        height: control.handleSize
        radius: width / 2
        antialiasing: true
        color: control._fg
        border.width: 2
        border.color: control._alpha(control._bg0, 0.5)

        // Subtle press feedback — same look at rest, just a little life.
        scale: control.pressed ? 1.15 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
        }
    }
}
