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

    // v8.0.0-alpha-hf120 — ONE hex convention: #RRGGBB, optionally + AA.
    //
    // This is what ColorPickerOverlay's own parser assumes (it reads
    // substring(0,2) as red) and what Hyprland wants (rgba(RRGGBBAA)).
    // The old code read 8-hex as #AARRGGBB — alpha-first — so an 8-hex value
    // came back with its channels rotated one byte left.
    //
    // Careful: a "#rrggbbaa" string must NEVER be handed to Qt's color type,
    // which parses #aarrggbb. Always feed it `_rgb()`.
    function _rgb(v) {
        const h = ("" + v).replace(/^#/, "")
        return "#" + (h.length >= 6 ? h.substring(0, 6) : "ffffff")
    }
    // Alpha byte if the value carries one — preserved across edits so the
    // Hyprland border colours keep their #595959aa transparency.
    function _alpha(v) {
        const h = ("" + v).replace(/^#/, "")
        return h.length === 8 ? h.substring(6, 8) : ""
    }
    function _compose(rgb6) { return _rgb(rgb6) + _alpha(root.value) }

    spacing: 8

    // ── Clickable color swatch — opens global picker overlay ──
    Rectangle {
        id: swatchRect
        Layout.preferredWidth: 32
        Layout.preferredHeight: 22
        radius: 6
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.25)
        color: root._rgb(root.value)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Delegate to global picker overlay via singleton.
                // Pass current hex as initial state + a callback that
                // updates this swatch's value when user applies.
                // Seed the picker with plain RGB; take back plain RGB; re-attach
                // whatever alpha this swatch was carrying.
                ColorPickerState.requestOpen(root._rgb(root.value), function(hex){
                    const next = root._compose(hex)
                    if (next && next !== root.value) {
                        root.value = next
                        root.valueEdited(next)
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
        color: LookService.surfaceColor(ThemeService.bg2, 0.6)
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
            text: root._rgb(root.value)
            color: ThemeService.fg
            font.family: Theme.fontFamily
            font.pixelSize: 12
            selectByMouse: true
            validator: RegularExpressionValidator {
                regularExpression: /^#?[0-9a-fA-F]{6,8}$/
            }
            onEditingFinished: {
                // Typed text is RGB. Keep the swatch's existing alpha.
                const v = root._compose(text.toLowerCase())
                if (v !== root.value) {
                    root.value = v
                    root.valueEdited(v)
                }
            }
        }
    }
}
