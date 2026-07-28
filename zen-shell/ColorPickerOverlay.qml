import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ColorPickerOverlay v7.0.0-beta.1-hf99 — Karui (軽い)
 *
 * Global color picker overlay. Mounted ONCE inside ZenSettings root
 * (NOT a QML Popup — just a Rectangle, so it's GUARANTEED to stay
 * inside the panel's visible bounds).
 *
 * Listens to ColorPickerState.openRequested. When fired:
 *   - Reads initial hex
 *   - Initializes HSL state from hex
 *   - Becomes visible (centered in Settings panel)
 *   - User can drag the picker around via the header bar
 *   - User picks a color (canvas + slider)
 *   - User clicks Apply → calls ColorPickerState.commit(hex)
 *   - Or clicks ✕ / clicks outside → ColorPickerState.cancel()
 *
 * Replaces the per-swatch Popup mechanism. Single instance shared
 * across all ColorSwatch components → no more popup escaping outside
 * the Settings panel.
 *
 * hf99 fixes (additive — no behaviour removed):
 *   1. DRAG on the saturation/hue plane now works, not just click.
 *      Root cause: an unqualified `pressed` inside a function(){}
 *      onPositionChanged handler didn't resolve to the MouseArea, so
 *      moves were ignored. Now references svMouse.pressed explicitly
 *      and sets preventStealing so no ancestor Flickable steals it.
 *   2. COLOR ACCURACY: the plane is painted at the CURRENT lightness
 *      (was hard-pinned to 0.5) using exact per-saturation HSL stops
 *      (was a single linear-RGB gradient). What you see under the
 *      cursor is now exactly what Apply emits. Repaints on L change.
 *
 * Wala tayong babawasan.
 */
Item {
    id: overlay

    visible: false
    z: 9999  // above ALL Settings panel content

    // Bound state — set when openRequested fires
    property real pickerHue: 0.0
    property real pickerSat: 1.0
    property real pickerLightness: 0.5

    // v7.0.0-beta.1-hf99: the SV plane is painted at the current lightness,
    // so it must repaint whenever L changes (slider drag / hex entry) to stay
    // WYSIWYG. Guarded because hsCanvas may not exist on the very first set.
    onPickerLightnessChanged: {
        if (typeof hsCanvas !== "undefined" && hsCanvas.available)
            hsCanvas.requestPaint()
    }

    // Reads current hex from picker state
    readonly property string currentHex: {
        const c = Qt.hsla(pickerHue, pickerSat, pickerLightness, 1.0)
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    // ─────────────────────────────────────────────────────────────
    // Listen for open requests from any ColorSwatch
    // ─────────────────────────────────────────────────────────────
    Connections {
        target: ColorPickerState
        function onOpenRequested(initialHex) {
            // Parse HSL from incoming hex
            let hex = (initialHex || "#ffffffff").replace(/^#/, "")
            if (hex.length >= 6) {
                const rr = parseInt(hex.substring(0, 2), 16) / 255
                const gg = parseInt(hex.substring(2, 4), 16) / 255
                const bb = parseInt(hex.substring(4, 6), 16) / 255
                const max = Math.max(rr, gg, bb)
                const min = Math.min(rr, gg, bb)
                let h = 0, s = 0, l = (max + min) / 2
                if (max !== min) {
                    const d = max - min
                    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
                    if (max === rr) h = ((gg - bb) / d + (gg < bb ? 6 : 0)) / 6
                    else if (max === gg) h = ((bb - rr) / d + 2) / 6
                    else h = ((rr - gg) / d + 4) / 6
                }
                overlay.pickerHue = h
                overlay.pickerSat = s
                overlay.pickerLightness = l
                hsCanvas.requestPaint()
            }

            // Center the picker frame in the Settings panel
            pickerFrame.x = (overlay.width - pickerFrame.width) / 2
            pickerFrame.y = (overlay.height - pickerFrame.height) / 2

            overlay.visible = true
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Dim background — clicking outside cancels
    // ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                ColorPickerState.cancel()
                overlay.visible = false
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // The picker frame — draggable via header bar
    // ─────────────────────────────────────────────────────────────
    Rectangle {
        id: pickerFrame
        width: 320
        height: 380
        radius: 12
        color: LookService.surfaceColor(ThemeService.bg0, 0.99)
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.22)

        // Block click-through to the dim backdrop's MouseArea
        MouseArea { anchors.fill: parent; preventStealing: true }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Header (draggable) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf53f"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: ThemeService.blue
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Color Picker"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                        Layout.fillWidth: true
                    }

                    // Close button (×)
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: closeMa.containsMouse
                               ? ThemeService.alpha(ThemeService.red, 0.25)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "×"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: closeMa.containsMouse
                                   ? ThemeService.red
                                   : ThemeService.grey0
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ColorPickerState.cancel()
                                overlay.visible = false
                            }
                        }
                    }
                }

                // Drag region — the header bar (excluding the close button)
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 32
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: pickerFrame
                    drag.axis: Drag.XAndYAxis
                    // Clamp drag to overlay bounds
                    drag.minimumX: 8
                    drag.maximumX: overlay.width - pickerFrame.width - 8
                    drag.minimumY: 8
                    drag.maximumY: overlay.height - pickerFrame.height - 8
                    preventStealing: true
                }
            }

            // ── HSL Canvas ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                clip: true

                Canvas {
                    id: hsCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d")
                        const w = width, h = height
                        if (w <= 0 || h <= 0) return
                        // v7.0.0-beta.1-hf99: paint at the CURRENT lightness (not a
                        // fixed 0.5) with exact per-sat HSL stops, so the plane shows
                        // precisely the colors Apply will emit — WYSIWYG accuracy.
                        // Top row = full saturation, bottom row = zero saturation.
                        const L = overlay.pickerLightness
                        const STOPS = 8
                        for (let x = 0; x < w; x += 2) {
                            const hueVal = x / w
                            const grad = ctx.createLinearGradient(x, 0, x, h)
                            for (let i = 0; i <= STOPS; i++) {
                                const t = i / STOPS          // 0 = top .. 1 = bottom
                                const sat = 1.0 - t          // top=1.0 sat, bottom=0.0
                                grad.addColorStop(t, Qt.hsla(hueVal, sat, L, 1.0))
                            }
                            ctx.fillStyle = grad
                            ctx.fillRect(x, 0, 2, h)
                        }
                    }

                    // Crosshair indicator
                    Rectangle {
                        x: Math.max(0, Math.min(hsCanvas.width - 14,
                                                overlay.pickerHue * hsCanvas.width - 7))
                        y: Math.max(0, Math.min(hsCanvas.height - 14,
                                                (1.0 - overlay.pickerSat) * hsCanvas.height - 7))
                        width: 14
                        height: 14
                        radius: 7
                        color: "transparent"
                        border.width: 2
                        border.color: "#ffffff"
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: "transparent"
                            border.width: 1
                            border.color: "#000000"
                        }
                    }

                    MouseArea {
                        id: svMouse
                        anchors.fill: parent
                        // v7.0.0-beta.1-hf99: preventStealing so no ancestor
                        // (Flickable/ScrollView) can hijack the drag mid-gesture,
                        // and reference svMouse.pressed explicitly — an unqualified
                        // `pressed` inside a function(){} handler doesn't reliably
                        // resolve to the MouseArea, which broke drag (click-only).
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton
                        function pick(mx, my) {
                            overlay.pickerHue = Math.max(0, Math.min(1, mx / hsCanvas.width))
                            overlay.pickerSat = Math.max(0, Math.min(1, 1.0 - my / hsCanvas.height))
                        }
                        onPressed: function(mouse) {
                            overlay.forceActiveFocus()
                            pick(mouse.x, mouse.y)
                        }
                        onPositionChanged: function(mouse) {
                            if (svMouse.pressed) pick(mouse.x, mouse.y)
                        }
                    }

                    Component.onCompleted: requestPaint()
                }
            }

            // ── Lightness slider ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "L"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                }

                ZenSlider {
                    id: lightnessSlider
                    Layout.fillWidth: true
                    from: 0.05
                    to: 0.95
                    value: overlay.pickerLightness
                    // v7.0.0-beta.1-hf99b: use onMoved (mirrors the proven audio
                    // slider) instead of onValueChanged so dragging drives the
                    // value cleanly without the binding fighting the drag.
                    onMoved: overlay.pickerLightness = value
                }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: (overlay.pickerLightness * 100).toFixed(0) + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                    Layout.preferredWidth: 36
                }
            }

            // ── Preview + hex + Apply (right) ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 32
                    radius: 6
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                    color: Qt.hsla(overlay.pickerHue,
                                   overlay.pickerSat,
                                   overlay.pickerLightness, 1.0)
                }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: overlay.currentHex
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.fg
                    Layout.fillWidth: true
                }

                // Apply — RIGHT side, big and obvious
                Rectangle {
                    Layout.preferredWidth: 78
                    Layout.preferredHeight: 32
                    radius: 6
                    color: applyMa.pressed
                           ? ThemeService.alpha(ThemeService.blue, 0.45)
                           : applyMa.containsMouse
                             ? ThemeService.alpha(ThemeService.blue, 0.30)
                             : ThemeService.alpha(ThemeService.blue, 0.20)
                    border.width: 1.5
                    border.color: ThemeService.alpha(ThemeService.blue, 0.5)

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: "Apply"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: ThemeService.blue
                    }

                    MouseArea {
                        id: applyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // v8.0.0-alpha-hf120 — commit the canonical 6-hex.
                            //
                            // This used to be `currentHex + "ff"`, producing
                            // #RRGGBBAA. ColorSwatch reads 8-hex as #AARRGGBB and
                            // so does Qt's color type, so every applied colour had
                            // its channels rotated: pick #ff1010, get #1010ff.
                            // Alpha belongs to the swatch (Hyprland border colours
                            // carry it); the picker only ever chooses RGB.
                            ColorPickerState.commit(overlay.currentHex)
                            overlay.visible = false
                        }
                    }
                }
            }
        }
    }

    // Esc closes
    Keys.onEscapePressed: {
        ColorPickerState.cancel()
        overlay.visible = false
    }
}
