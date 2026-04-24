import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * PaletteBox v6.16.4.12 — compact clickable palette swatch
 *
 * 60×60 rounded box + label underneath. Clicking the box opens a
 * Quickshell PopupWindow with HS canvas + lightness slider + live
 * hex input + Apply/Cancel buttons. Same picker UX as ColorSwatch
 * but compact presentation for Theme Palette Preview grids.
 *
 * Commits edits via:
 *   ThemeService.setAccent(paletteKey, hex)
 *
 * Marks palette dirty so the Themes page "Save as custom" flow
 * knows there are pending changes. That flag is consumed by the
 * Custom Themes section's Save-as button.
 *
 * WALA TAYONG BABAWASAN — this is a NEW additive component.
 */
ColumnLayout {
    id: root

    // Label shown under the box (e.g. "bg0", "red", "accent")
    property string label: ""

    // Key passed to ThemeService.setAccent()
    property string paletteKey: ""

    // Current color (bound to ThemeService.<key>)
    property var value: "#ffffff"

    // Live preview hex in the picker (reverts on Cancel)
    property string _pickerHex: ""

    spacing: 4

    // ── The clickable color box ──────────────────────────────
    Rectangle {
        id: box
        Layout.preferredWidth: 60
        Layout.preferredHeight: 60
        radius: 8
        color: root.value
        border.width: 1
        border.color: boxMa.containsMouse
            ? ThemeService.alpha(ThemeService.blue, 0.6)
            : ThemeService.alpha(ThemeService.fg, 0.15)
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Edit hint on hover
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#000000"
            opacity: boxMa.containsMouse ? 0.25 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Text {
            anchors.centerIn: parent
            text: "\uf044"  // nerd font edit icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: "#ffffff"
            opacity: boxMa.containsMouse ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            id: boxMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root._pickerHex = _toHex(root.value)
                pickerPop.visible = !pickerPop.visible
                if (pickerPop.visible) _syncPickerFromHex(root._pickerHex)
            }
        }
    }

    // ── Label under box ──────────────────────────────────────
    Text {
        text: root.label
        font.family: Theme.monoFont
        font.pixelSize: 10
        color: ThemeService.grey1
        Layout.alignment: Qt.AlignHCenter
    }

    // ═══════════════════════════════════════════════════════════
    // Picker — Quickshell PopupWindow (same pattern as ColorSwatch)
    // ═══════════════════════════════════════════════════════════
    PopupWindow {
        id: pickerPop
        anchor.item: box
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left
        visible: false
        width: 290
        height: 340
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g,
                           ThemeService.bg0.b, 0.97)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.18)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "\uf53f  " + (root.label || "Color")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root._pickerHex
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: ThemeService.grey0
                    }
                }

                // Hex input — live-updates
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 6
                    color: ThemeService.alpha(ThemeService.bg2, 0.6)
                    border.width: 1
                    border.color: hexInput.activeFocus
                        ? ThemeService.alpha(ThemeService.blue, 0.5)
                        : ThemeService.alpha(ThemeService.fg, 0.1)

                    TextInput {
                        id: hexInput
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: root._pickerHex
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        selectByMouse: true
                        validator: RegularExpressionValidator {
                            regularExpression: /^#?[0-9a-fA-F]{0,8}$/
                        }
                        onTextChanged: {
                            const raw = text.replace(/^#/, "")
                            if (raw.length === 6 || raw.length === 8) {
                                let v = "#" + raw.toLowerCase()
                                if (v.length === 7) v = v + "ff"
                                if (v !== root._pickerHex) {
                                    root._pickerHex = v
                                    _syncPickerFromHex(v)
                                }
                            }
                        }
                    }
                }

                // HS canvas
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    clip: true

                    Canvas {
                        id: hsCanvas
                        anchors.fill: parent
                        property real pickerHue: 0.0
                        property real pickerSat: 1.0

                        onPaint: {
                            const ctx = getContext("2d")
                            const w = width, h = height
                            if (w <= 0 || h <= 0) return
                            for (let x = 0; x < w; x += 2) {
                                const hueVal = x / w
                                const grad = ctx.createLinearGradient(x, 0, x, h)
                                grad.addColorStop(0, Qt.hsla(hueVal, 1.0, 0.5, 1.0))
                                grad.addColorStop(1, Qt.hsla(hueVal, 0.0, 0.5, 1.0))
                                ctx.fillStyle = grad
                                ctx.fillRect(x, 0, 2, h)
                            }
                        }

                        Rectangle {
                            x: Math.max(0, Math.min(hsCanvas.width - 12, hsCanvas.pickerHue * hsCanvas.width - 6))
                            y: Math.max(0, Math.min(hsCanvas.height - 12, (1.0 - hsCanvas.pickerSat) * hsCanvas.height - 6))
                            width: 12; height: 12; radius: 6
                            color: "transparent"
                            border.width: 2; border.color: "#ffffff"
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: 8; radius: 4
                                color: "transparent"
                                border.width: 1; border.color: "#000000"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            function pick(mouse) {
                                hsCanvas.pickerHue = Math.max(0, Math.min(1, mouse.x / hsCanvas.width))
                                hsCanvas.pickerSat = Math.max(0, Math.min(1, 1.0 - mouse.y / hsCanvas.height))
                                _updatePickerHex()
                            }
                            onPressed: function(mouse) { pick(mouse) }
                            onPositionChanged: function(mouse) { if (pressed) pick(mouse) }
                        }

                        Component.onCompleted: requestPaint()
                    }
                }

                // Lightness slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "L"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey0
                    }
                    Slider {
                        id: lightnessSlider
                        Layout.fillWidth: true
                        from: 0; to: 1; value: 0.5
                        onMoved: _updatePickerHex()
                    }
                    Text {
                        text: Math.round(lightnessSlider.value * 100) + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: ThemeService.grey0
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Action row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 28
                        radius: 6
                        color: root._pickerHex
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 28
                        radius: 6
                        color: cancelMa.containsMouse
                            ? ThemeService.alpha(ThemeService.fg, 0.1)
                            : ThemeService.alpha(ThemeService.bg2, 0.5)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.fg
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pickerPop.visible = false
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 28
                        radius: 6
                        color: applyMa.containsMouse
                            ? ThemeService.alpha(ThemeService.blue, 0.95)
                            : ThemeService.alpha(ThemeService.blue, 0.8)

                        Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: applyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Commit to ThemeService live (setAccent
                                // accepts "#rrggbb" — strip alpha if present)
                                const rgb = root._pickerHex.length === 9
                                    ? root._pickerHex.substring(0, 7)
                                    : root._pickerHex
                                ThemeService.setAccent(root.paletteKey, rgb)
                                pickerPop.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════════

    function _toHex(c) {
        if (typeof c === "string") {
            const h = c.replace(/^#/, "")
            if (h.length === 6) return "#" + h.toLowerCase() + "ff"
            if (h.length === 8) return "#" + h.toLowerCase()
            return "#ffffff"
        }
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b + "ff"
    }

    function _updatePickerHex() {
        const h = hsCanvas.pickerHue
        const s = hsCanvas.pickerSat
        const l = lightnessSlider.value
        let r, g, b
        if (s === 0) {
            r = g = b = l
        } else {
            const hue2rgb = (p, q, t) => {
                if (t < 0) t += 1
                if (t > 1) t -= 1
                if (t < 1/6) return p + (q - p) * 6 * t
                if (t < 1/2) return q
                if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
                return p
            }
            const q = l < 0.5 ? l * (1 + s) : l + s - l * s
            const p = 2 * l - q
            r = hue2rgb(p, q, h + 1/3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1/3)
        }
        const toHex = n => Math.round(n * 255).toString(16).padStart(2, "0")
        let alpha = "ff"
        const cur = (typeof root.value === "string")
            ? root.value.replace(/^#/, "")
            : ""
        if (cur.length === 8) alpha = cur.substring(6, 8)
        root._pickerHex = "#" + toHex(r) + toHex(g) + toHex(b) + alpha
    }

    function _syncPickerFromHex(hex) {
        let h = hex.replace(/^#/, "")
        if (h.length < 6) return
        const rr = parseInt(h.substring(0, 2), 16) / 255
        const gg = parseInt(h.substring(2, 4), 16) / 255
        const bb = parseInt(h.substring(4, 6), 16) / 255
        const max = Math.max(rr, gg, bb)
        const min = Math.min(rr, gg, bb)
        let hue = 0, sat = 0, light = (max + min) / 2
        if (max !== min) {
            const d = max - min
            sat = light > 0.5 ? d / (2 - max - min) : d / (max + min)
            if (max === rr) hue = ((gg - bb) / d + (gg < bb ? 6 : 0)) / 6
            else if (max === gg) hue = ((bb - rr) / d + 2) / 6
            else hue = ((rr - gg) / d + 4) / 6
        }
        hsCanvas.pickerHue = hue
        hsCanvas.pickerSat = sat
        lightnessSlider.value = light
        hsCanvas.requestPaint()
    }
}
