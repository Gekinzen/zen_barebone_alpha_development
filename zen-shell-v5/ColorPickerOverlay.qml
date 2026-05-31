import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ColorPickerOverlay v7.0.0-alpha.11-hf4
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
 */
Item {
    id: overlay

    visible: false
    z: 9999  // above ALL Settings panel content

    // Bound state — set when openRequested fires
    property real pickerHue: 0.0
    property real pickerSat: 1.0
    property real pickerLightness: 0.5

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
        color: ThemeService.alpha(ThemeService.bg0, 0.99)
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
                        text: "\uf53f"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: ThemeService.blue
                    }

                    Text {
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
                        anchors.fill: parent
                        function pick(mouse) {
                            overlay.pickerHue = Math.max(0, Math.min(1, mouse.x / hsCanvas.width))
                            overlay.pickerSat = Math.max(0, Math.min(1, 1.0 - mouse.y / hsCanvas.height))
                        }
                        onPressed: function(mouse) {
                            forceActiveFocus()
                            pick(mouse)
                        }
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
                    from: 0.05
                    to: 0.95
                    value: overlay.pickerLightness
                    onValueChanged: overlay.pickerLightness = value
                }

                Text {
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
                            ColorPickerState.commit(overlay.currentHex + "ff")
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
