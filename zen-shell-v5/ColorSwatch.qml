import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ColorSwatch v7.0.0-alpha.11-hf4 — color chip + hex input
 *
 * Simplified architecture: clicking the swatch delegates to the
 * global ColorPickerOverlay (via ColorPickerState singleton). No
 * more per-swatch QML Popup — the picker is a single shared
 * instance mounted INSIDE ZenSettings root, guaranteed to stay
 * within the visible Settings panel bounds.
 *
 * Public API (unchanged from v6.8.1):
 *   - property string value: "#RRGGBBAA"
 *   - signal valueEdited(string hex)
 *
 * All existing consumers (GeneralPage borders, ThemePalette,
 * ZenStrings, etc.) work without changes.
 *
 * History:
 *   v7.0.0-alpha.11-hf4: replaced Popup with global overlay
 *   v6.8.1: Popup-based picker (escape-from-panel bug)
 *   v6.8: HSL canvas + lightness slider
 *   v6.6: Original hex-only input
 *
 * WALA TAYONG BABAWASAN.
 */
RowLayout {
    id: root

    property string value: "#ffffffff"
    signal valueEdited(string hex)

    spacing: 8

    // ── Clickable color swatch — opens global picker overlay ──
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
                // Delegate to global picker overlay via singleton.
                // Pass current hex as initial state + a callback that
                // updates this swatch's value when user applies.
                ColorPickerState.requestOpen(root.value, function(hex){
                    if (hex && hex !== root.value) {
                        root.value = hex
                        root.valueEdited(hex)
                    }
                })
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
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            text: root.value
            color: ThemeService.fg
            font.family: Theme.fontFamily
            font.pixelSize: 12
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
