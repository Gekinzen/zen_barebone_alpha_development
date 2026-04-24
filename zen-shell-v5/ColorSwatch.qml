import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * ColorSwatch v6.16.4.10 — hex input + Quickshell PopupWindow picker
 *
 * Rewrite #4. Previous iterations used Qt Quick Popup which
 * kept bugging out on coord-system transforms — popup ended up
 * outside the Settings window bounds, Apply unreachable.
 *
 * v6.16.4.10 abandons Qt Popup entirely and uses Quickshell's
 * PopupWindow primitive. This is a real Wayland popup — the
 * compositor positions it, not Qt. anchor.item + anchor.gravity
 * makes it reliably attach to the swatch with correct screen
 * positioning, no Overlay/parent coord juggling required.
 *
 * Same pattern SysRowIcon.qml has used since v6.14 for tooltips
 * without a single positioning bug.
 *
 * Also: hex textbox now auto-updates color LIVE as you type.
 * Previously only committed on Enter/Tab (editingFinished).
 *
 * WALA TAYONG BABAWASAN.
 */
RowLayout {
    id: root

    property string value: "#ffffffff"
    signal valueEdited(string hex)

    // Live-preview color being edited in the picker (reverts on Cancel)
    property string _pickerHex: value

    spacing: 8

    // ── Clickable color swatch — opens PopupWindow ──
    Rectangle {
        id: swatchRect
        Layout.preferredWidth: 32
        Layout.preferredHeight: 22
        radius: 6
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.25)
        color: {
            let h = root.value.replace(/^#/, "")
            if (h.length === 8) return "#" + h.substring(0, 6)
            if (h.length === 6) return "#" + h
            return "#ffffff"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root._pickerHex = root.value
                pickerPop.visible = !pickerPop.visible
                if (pickerPop.visible) _syncPickerFromHex(root.value)
            }
        }
    }

    // ── Hex input (live-updating) ──
    Rectangle {
        Layout.preferredWidth: 110
        Layout.preferredHeight: 28
        radius: 6
        color: ThemeService.alpha(ThemeService.bg2, 0.6)
        border.width: 1
        border.color: hexInput.activeFocus
                      ? ThemeService.alpha(ThemeService.blue, 0.5)
                      : ThemeService.alpha(ThemeService.fg, 0.1)

        TextInput {
            id: hexInput
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            text: root.value
            color: ThemeService.fg
            font.family: Theme.fontFamily; font.pixelSize: 12
            selectByMouse: true
            validator: RegularExpressionValidator {
                regularExpression: /^#?[0-9a-fA-F]{0,8}$/
            }

            // v6.16.4.10: live-update on every valid keystroke.
            // If the user types a complete 6 or 8 char hex code,
            // commit immediately so the swatch + downstream
            // theming refresh.
            onTextChanged: {
                const raw = text.replace(/^#/, "")
                if (raw.length === 6 || raw.length === 8) {
                    let v = "#" + raw.toLowerCase()
                    if (v.length === 7) v = v + "ff"
                    if (v !== root.value) {
                        root.value = v
                        root.valueEdited(v)
                    }
                }
            }

            onEditingFinished: {
                let v = text.startsWith("#") ? text : "#" + text
                v = v.toLowerCase()
                if (v.length === 7) v = v + "ff"
                if (v !== root.value && (v.length === 7 || v.length === 9)) {
                    root.value = v
                    root.valueEdited(v)
                }
                text = root.value
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // PICKER — Quickshell PopupWindow (Wayland-native)
    // ═══════════════════════════════════════════════════════════
    // anchor.item attaches the popup to the swatch; Wayland
    // compositor handles positioning with proper edge detection.
    // Screen-space clipping is automatic — no coord math needed.
    PopupWindow {
        id: pickerPop
        anchor.item: swatchRect
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left
        visible: false
        width: 290
        height: 310
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
                        text: "\uf53f  Color Picker"
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

                // ── Hue-Saturation canvas ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
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

                // ── Lightness slider ──
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

                // ── Preview + action buttons ──
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

                    // Cancel button
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

                    // Apply button
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
                                if (root._pickerHex !== root.value) {
                                    root.value = root._pickerHex
                                    root.valueEdited(root._pickerHex)
                                }
                                pickerPop.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // Helper functions
    // ═══════════════════════════════════════════════════════════

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
        const cur = root.value.replace(/^#/, "")
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
        root._pickerHex = hex
    }
}
