import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ColorSwatch v6.8.1 — color chip + hex input + popup color picker
 *
 * v6.8.1: Fixed z-order — uses QML Popup for correct stacking above
 * all siblings (previously a child Rectangle that got clipped by parent
 * ScrollView and overlapped by sibling rows). Responsive width.
 *
 * v6.8: Popup color picker (HSL canvas + lightness slider)
 * v6.6: Original hex-only input
 *
 * WALA TAYONG BABAWASAN.
 */
RowLayout {
    id: root

    property string value: "#ffffffff"
    signal valueEdited(string hex)

    spacing: 8

    // ── Clickable color swatch — opens picker popup ──
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
            onClicked: colorPopup.open()
        }
    }

    // ── Color Picker as Popup — proper z-order, no clipping ──
    Popup {
        id: colorPopup
        x: swatchRect.x
        y: swatchRect.y + swatchRect.height + 6
        width: 270
        height: 310
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            radius: 12
            color: ThemeService.alpha(ThemeService.bg0, 0.97)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.18)

            // Shadow
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: 14
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(0, 0, 0, 0.15)
                z: -1
            }
        }

        onOpened: {
            // Initialize picker from current hex value
            let hex = root.value.replace(/^#/, "")
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
                hsCanvas.pickerHue = h
                hsCanvas.pickerSat = s
                lightnessSlider.value = l
                hsCanvas.requestPaint()
            }
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: "\uf53f  Color Picker"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }

            // ── Hue-Saturation canvas ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
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

                        // Hue gradient left→right, saturation top→bottom
                        for (let x = 0; x < w; x += 2) {
                            const hueVal = x / w
                            const grad = ctx.createLinearGradient(x, 0, x, h)
                            grad.addColorStop(0, Qt.hsla(hueVal, 1.0, 0.5, 1.0))
                            grad.addColorStop(1, Qt.hsla(hueVal, 0.0, 0.5, 1.0))
                            ctx.fillStyle = grad
                            ctx.fillRect(x, 0, 2, h)
                        }
                    }

                    // Crosshair indicator
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
                        }
                        onPressed: function(mouse) { pick(mouse) }
                        onPositionChanged: function(mouse) { if (pressed) pick(mouse) }
                    }

                    Component.onCompleted: requestPaint()
                }
            }

            // ── Lightness slider ──
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                Text { text: "L"; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }

                Slider {
                    id: lightnessSlider
                    Layout.fillWidth: true
                    from: 0.05; to: 0.95; value: 0.5
                }

                Text {
                    text: (lightnessSlider.value * 100).toFixed(0) + "%"
                    font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0
                    Layout.preferredWidth: 34
                }
            }

            // ── Preview + hex + apply ──
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                // Color preview
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 28; radius: 6
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                    color: Qt.hsla(hsCanvas.pickerHue, hsCanvas.pickerSat, lightnessSlider.value, 1.0)
                }

                // Hex label
                Text {
                    text: {
                        const c = Qt.hsla(hsCanvas.pickerHue, hsCanvas.pickerSat, lightnessSlider.value, 1.0)
                        const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
                        const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
                        const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
                        return "#" + r + g + b
                    }
                    font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.fg
                    Layout.fillWidth: true
                }

                // Apply button
                Rectangle {
                    Layout.preferredWidth: 64; Layout.preferredHeight: 28; radius: 6
                    color: applyBtn.containsMouse
                           ? ThemeService.alpha(ThemeService.blue, 0.25)
                           : ThemeService.alpha(ThemeService.blue, 0.15)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.blue, 0.3)

                    Text {
                        anchors.centerIn: parent; text: "Apply"
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                        color: ThemeService.blue
                    }

                    MouseArea {
                        id: applyBtn; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const c = Qt.hsla(hsCanvas.pickerHue, hsCanvas.pickerSat, lightnessSlider.value, 1.0)
                            const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
                            const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
                            const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
                            const hex = "#" + r + g + b + "ff"
                            root.value = hex
                            root.valueEdited(hex)
                            colorPopup.close()
                        }
                    }
                }
            }
        }
    }

    // ── Hex input (preserved from v6.6) ──
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
                regularExpression: /^#?[0-9a-fA-F]{6,8}$/
            }
            onEditingFinished: {
                let v = text.startsWith("#") ? text : "#" + text
                v = v.toLowerCase()
                if (v.length === 7) v = v + "ff"
                if (v !== root.value) {
                    root.value = v
                    root.valueEdited(v)
                }
            }
        }
    }
}
