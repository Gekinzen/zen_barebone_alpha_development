import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * InputPage v6.16.2.3.2-hotfix
 *
 * Main-Settings counterpart to the compact Input tab in Control Panel.
 * Same backing service (MouseSettingsService) → changes here reflect
 * instantly in the Control Panel sliders and vice-versa (both bind to
 * the same singleton).
 *
 * This page exposes:
 *   - Mouse sensitivity (Hyprland input:sensitivity, -1.0..+1.0)
 *   - Scroll factor (Hyprland input:scroll_factor, 0.1..3.0)
 *   - Mouse natural scroll
 *   - Touchpad natural scroll
 *   - Reset all to Hyprland defaults
 *   - Helpful explanation of what each setting does + the Hyprland
 *     keyword each maps to (so power users can verify with hyprctl)
 *
 * Lives in Settings → INPUT & DISPLAY → Input.
 */
Flickable {
    id: root

    property int availableWidth: width

    contentWidth: width
    contentHeight: contentCol.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: contentCol
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 20

        // ═══ Header ═══
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Input"
                color: ThemeService.fg
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Mouse, scroll, and touchpad behavior. Changes apply " +
                      "live via hyprctl and persist to ~/.config/hypr/zen-mouse.conf."
                color: ThemeService.grey0
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // ═══ Mouse section ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: mouseSection.implicitHeight + 32
            radius: 12
            color: LookService.surfaceColor(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: mouseSection
                anchors.fill: parent
                anchors.margins: 16
                spacing: 18

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Mouse"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                // ── Sensitivity ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Pointer sensitivity"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: MouseSettingsService.sensitivity.toFixed(2)
                            color: ThemeService.blue
                            font.family: Theme.monoFont
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Negative = slower, positive = faster. Maps to " +
                              "Hyprland input:sensitivity. Range -1.0 to +1.0."
                        color: ThemeService.grey0
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    ZenSlider {
                        Layout.fillWidth: true
                        from: -1.0; to: 1.0; stepSize: 0.05
                        value: MouseSettingsService.sensitivity
                        onMoved: {
                            MouseSettingsService.sensitivity = value
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Scroll factor ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Scroll speed"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: MouseSettingsService.scrollFactor.toFixed(2) + "×"
                            color: ThemeService.blue
                            font.family: Theme.monoFont
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Multiplier for scroll wheel. Maps to " +
                              "Hyprland input:scroll_factor. Range 0.1 to 3.0."
                        color: ThemeService.grey0
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    ZenSlider {
                        Layout.fillWidth: true
                        from: 0.1; to: 3.0; stepSize: 0.1
                        value: MouseSettingsService.scrollFactor
                        onMoved: {
                            MouseSettingsService.scrollFactor = value
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Natural scroll (mouse) ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Natural scroll (mouse wheel)"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Inverts wheel direction (macOS-style). " +
                                  "Maps to input:natural_scroll."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    // v6.16.3.4.4: swap stock Qt Switch for HMSwitch so the
                    // toggle design matches System Tray / Bar Modules pages.
                    // Same API surface: `checked` for the initial value,
                    // `onToggled` to react. HMSwitch mutates external state
                    // explicitly (no auto-write-through) so we flip the
                    // service property ourselves.
                    HMSwitch {
                        checked: MouseSettingsService.naturalScroll
                        onToggled: {
                            MouseSettingsService.naturalScroll = !MouseSettingsService.naturalScroll
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Cursor doesn't steal monitor focus (v8.0.0-alpha-hf171) ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Cursor doesn't steal monitor focus"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "When on, moving the cursor to another monitor won't focus it — new "
                                  + "windows (e.g. Steam) open on the monitor you're working on, not wherever "
                                  + "the cursor happens to be. Maps to misc:mouse_move_focuses_monitor (inverted)."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    HMSwitch {
                        // ON = cursor does NOT move focus, i.e. the inverse of the Hyprland option.
                        checked: !MouseSettingsService.mouseMoveFocusesMonitor
                        onToggled: {
                            MouseSettingsService.mouseMoveFocusesMonitor = !MouseSettingsService.mouseMoveFocusesMonitor
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Floating popups keep focus (v8.0.0-alpha-hf177) ──
                // The Lark/Zoom fix. Hyprland's documented quirk is that focus ALWAYS
                // changes on mouse enter when crossing between a floating window and a
                // tiled one — which is exactly a call popup over your normal windows.
                // Setting float_switch_override_focus to 0 is what stops it; upstream
                // reports floating dialogs then "retain focus even if the mouse leaves".
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Floating popups keep focus"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Turn ON if call popups (Lark, Zoom) close before you can hit the "
                                  + "smiley or End call. Stops focus jumping to the window behind the "
                                  + "moment the cursor drifts off. Maps to input:float_switch_override_focus."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    HMSwitch {
                        // ON = 0 = don't hand focus over on a float/tile crossing.
                        checked: MouseSettingsService.floatSwitchOverrideFocus === 0
                        onToggled: {
                            MouseSettingsService.floatSwitchOverrideFocus =
                                (MouseSettingsService.floatSwitchOverrideFocus === 0) ? 1 : 0
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Apps may take focus when they ask (v8.0.0-alpha-hf177) ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Apps may take focus when they ask"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Hyprland ignores activation requests by default, so a popup that "
                                  + "asks for focus as it opens never gets it — and hides again. "
                                  + "WARNING: this is global, and games are the reason the default is "
                                  + "off — Wine/Proton titles re-request activation constantly, which "
                                  + "turns into a focus war (the screen flickers and clicks don't land). "
                                  + "If a game starts blinking, this is the toggle. Maps to "
                                  + "misc:focus_on_activate."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    HMSwitch {
                        checked: MouseSettingsService.focusOnActivate
                        onToggled: {
                            MouseSettingsService.focusOnActivate = !MouseSettingsService.focusOnActivate
                            MouseSettingsService.apply(true)
                        }
                    }
                }

                // ── Focus follows mouse (v8.0.0-alpha-hf177) ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Focus follows mouse"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Full = hovering focuses (Hyprland default). Loose = the mouse focuses "
                                  + "but the keyboard stays put. Click to focus = hovering never steals "
                                  + "focus. Maps to input:follow_mouse."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    ZenDropdown {
                        Layout.preferredWidth: 150
                        model: ["Full (default)", "Loose", "Click to focus"]
                        currentIndex: MouseSettingsService.followMouse === 1 ? 0
                                    : (MouseSettingsService.followMouse === 2 ? 1 : 2)
                        onActivated: function(i) {
                            MouseSettingsService.followMouse = (i === 0) ? 1 : (i === 1 ? 2 : 0)
                            MouseSettingsService.apply(true)
                        }
                    }
                }
            }
        }

        // ═══ Touchpad section ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: tpSection.implicitHeight + 32
            radius: 12
            color: LookService.surfaceColor(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: tpSection
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Touchpad"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Natural scroll (touchpad)"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Separate from mouse natural scroll. " +
                                  "Maps to input:touchpad:natural_scroll."
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    HMSwitch {
                        checked: MouseSettingsService.touchpadNaturalScroll
                        onToggled: {
                            MouseSettingsService.touchpadNaturalScroll = !MouseSettingsService.touchpadNaturalScroll
                            MouseSettingsService.apply(true)
                        }
                    }
                }
            }
        }

        // ═══ Reset section ═══
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 12

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 38
                radius: 8
                color: resetMa.containsMouse
                    ? ThemeService.alpha(ThemeService.fg, 0.14)
                    : ThemeService.alpha(ThemeService.fg, 0.06)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.18)

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "Reset all to defaults"
                    color: ThemeService.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        MouseSettingsService.sensitivity = 0.0
                        MouseSettingsService.scrollFactor = 1.0
                        MouseSettingsService.naturalScroll = false
                        MouseSettingsService.touchpadNaturalScroll = false
                        // v8.0.0-alpha-hf180 — the focus settings belong here too. hf171
                        // and hf177 added four of them and never taught this button about
                        // them, so the one control you'd hit when something goes wrong
                        // (a game flickering, focus behaving oddly) quietly left the
                        // culprit switched on. These are Hyprland's own defaults.
                        MouseSettingsService.mouseMoveFocusesMonitor = true
                        MouseSettingsService.followMouse = 1
                        MouseSettingsService.floatSwitchOverrideFocus = 1
                        MouseSettingsService.focusOnActivate = false
                        MouseSettingsService.apply(true)
                    }
                }
            }
        }

        // ═══ Diagnostics ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: diagCol.implicitHeight + 24
            radius: 10
            color: LookService.surfaceColor(ThemeService.bg1 || ThemeService.bg0, 0.35)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.06)

            ColumnLayout {
                id: diagCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Verify in terminal"
                    color: ThemeService.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "hyprctl getoption input:sensitivity"
                    color: ThemeService.grey0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "hyprctl getoption input:scroll_factor"
                    color: ThemeService.grey0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "cat ~/.config/hypr/zen-mouse.conf"
                    color: ThemeService.grey0
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }
        }
    }
}
