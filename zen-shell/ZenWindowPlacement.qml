pragma Singleton

import QtQuick

/*
 * ZenWindowPlacement v8.0.0-alpha-hf113
 *
 * Notification-style placement for the floating shell windows (Zen Control
 * Center, Settings). Nine anchor points. "Reopen where I dragged it" is a
 * separate boolean on PanelState, not a tenth anchor — see modes below.
 *
 * Why this exists — the anchors trap:
 *
 *   anchors.centerIn: (!fullscreen && !hasBeenDragged) ? parent : undefined
 *
 * The moment that ternary flips to `undefined`, Qt tears the anchor down and
 * the item falls back to its BASE x/y — which is 0,0, because nothing ever
 * assigned them. Result: the panel snaps to the upper-left corner. And
 * ZenSettings sets `hasBeenDragged = true` on *press*, not on actual movement,
 * so a single click on the header is enough to trigger it.
 *
 * Declaring `anchors.fill` and `anchors.centerIn` on the same item (as
 * shell.qml currently does for zenSettingsPanel) is also invalid — Qt logs
 * "Cannot specify centerIn and fill" and the layout result is undefined.
 *
 * Fix: no anchors at all. Compute x/y explicitly, exactly the way
 * DesktopWidgets._applyPositions() already does for the desktop overlays.
 * One code path, no binding races, and placement becomes a user setting.
 *
 * Usage:
 *
 *   function _place() {
 *       if (!parent) return
 *       if (rememberDrag && hasBeenDragged) return
 *       x = ZenWindowPlacement.px(mode, parent.width,  width,  margin)
 *       y = ZenWindowPlacement.py(mode, parent.height, height, margin)
 *   }
 */
QtObject {
    id: root

    readonly property string defaultMode: "center"
    readonly property int    defaultMargin: 24

    // v8.0.0-alpha-hf123 — nine anchors, and nothing else.
    //
    // hf113 shipped a tenth entry, "free", meaning "reopen where you dragged it".
    // That is not an anchor; it's a separate question. Cramming it into the same
    // property made the UI lie: with placement == "free" no grid cell matched, so
    // the picker looked unset; flipping the toggle off silently rewrote the anchor
    // to "center"; clicking a cell silently flipped the toggle off.
    // It's a boolean of its own now — PanelState.dashRememberDrag.
    readonly property var modes: [
        { id: "top-left",      label: "Top left",      row: 0, col: 0 },
        { id: "top-center",    label: "Top center",    row: 0, col: 1 },
        { id: "top-right",     label: "Top right",     row: 0, col: 2 },
        { id: "center-left",   label: "Center left",   row: 1, col: 0 },
        { id: "center",        label: "Center",        row: 1, col: 1 },
        { id: "center-right",  label: "Center right",  row: 1, col: 2 },
        { id: "bottom-left",   label: "Bottom left",   row: 2, col: 0 },
        { id: "bottom-center", label: "Bottom center", row: 2, col: 1 },
        { id: "bottom-right",  label: "Bottom right",  row: 2, col: 2 }
    ]
    function isValid(mode) {
        for (let i = 0; i < modes.length; i++) if (modes[i].id === mode) return true
        return false
    }
    function indexOf(mode) {
        for (let i = 0; i < modes.length; i++) if (modes[i].id === mode) return i
        return 4   // "center"
    }
    function labelFor(mode) {
        const i = indexOf(mode)
        return modes[i].label
    }

    // Horizontal band of the mode: "left" | "center" | "right"
    function _hband(mode) {
        if (mode === "top-left" || mode === "center-left" || mode === "bottom-left") return "left"
        if (mode === "top-right" || mode === "center-right" || mode === "bottom-right") return "right"
        return "center"
    }
    // Vertical band: "top" | "center" | "bottom"
    function _vband(mode) {
        if (mode === "top-left" || mode === "top-center" || mode === "top-right") return "top"
        if (mode === "bottom-left" || mode === "bottom-center" || mode === "bottom-right") return "bottom"
        return "center"
    }

    /*
     * px / py — the placed top-left corner, always clamped inside the parent.
     *
     * `margin` is the gap from the screen edge for the edge-anchored modes.
     * Centered axes ignore it. If the window is larger than the parent on an
     * axis (rotated monitor, 720p laptop panel), we clamp to 0 rather than
     * emitting a negative coordinate — a negative x on a layer-shell surface
     * puts content off-screen with no way to drag it back.
     */
    function px(mode, parentW, w, margin) {
        const m = (margin === undefined) ? defaultMargin : margin
        const free = Math.max(0, parentW - w)
        let v
        switch (_hband(mode)) {
            case "left":  v = m;                        break
            case "right": v = parentW - w - m;          break
            default:      v = (parentW - w) / 2;        break
        }
        return Math.round(Math.max(0, Math.min(v, free)))
    }

    function py(mode, parentH, h, margin) {
        const m = (margin === undefined) ? defaultMargin : margin
        const free = Math.max(0, parentH - h)
        let v
        switch (_vband(mode)) {
            case "top":    v = m;                       break
            case "bottom": v = parentH - h - m;         break
            default:       v = (parentH - h) / 2;       break
        }
        return Math.round(Math.max(0, Math.min(v, free)))
    }

    /*
     * Clamp an already-placed (dragged) window back inside the parent.
     * Call from onXChanged / onYChanged / onWidthChanged when remembering a drag.
     */
    function clampX(x, parentW, w) { return Math.round(Math.max(0, Math.min(x, Math.max(0, parentW - w)))) }
    function clampY(y, parentH, h) { return Math.round(Math.max(0, Math.min(y, Math.max(0, parentH - h)))) }

    /*
     * Entrance offset — the direction a notification-style window should slide
     * in from. Returns { dx, dy } in pixels; add it to the resting position for
     * the "before" frame of a slide-in animation. Centered windows just fade.
     */
    function entranceOffset(mode, distance) {
        const d = (distance === undefined) ? 18 : distance
        let dx = 0, dy = 0
        if (_hband(mode) === "left")  dx = -d
        if (_hband(mode) === "right") dx =  d
        if (_vband(mode) === "top")    dy = -d
        if (_vband(mode) === "bottom") dy =  d
        if (dx === 0 && dy === 0) dy = d * 0.5   // pure-center: small rise
        return { dx: dx, dy: dy }
    }
}
