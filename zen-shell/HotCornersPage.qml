import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * HotCornersPage v7.0.0-alpha.14 — Karui (軽い)
 *
 * Settings page for HotCornerService config. User can:
 *   - Toggle hot corners globally
 *   - Pick action per corner (4 corners × 5 actions)
 *   - See live status indicator (cursor entered which corner)
 *
 * Mounted in Settings sidebar via SettingsRouter (alpha.14 wires it).
 */
Item {
    id: root

    readonly property var availableActions: [
        { id: "toggleSearch",            label: "Spotlight Search" },
        { id: "toggleNotifications",     label: "Notifications" },
        { id: "toggleControlCenter",     label: "Control Panel" },
        { id: "toggleClipboard",         label: "Clipboard" },
        { id: "toggleWorkspaceOverview", label: "Workspace Overview" },
        { id: "showDesktop",             label: "Show Desktop" },
        { id: "",                        label: "(disabled)" }
    ]

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 24
            spacing: 16

            // ── Header ──
            DenshoPageHeader {
                Layout.fillWidth: true
                title: "Hot Corners"
                subtitle: "Trigger actions when cursor enters screen corners"
                kanji: "角"
                romaji: "Kado"
            }

            // ── Master toggle ──
            SettingsSection {
                title: ""
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf0a4"   // Nerd Font hand pointer
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: HotCornerService.enabled
                               ? ThemeService.blue
                               : ThemeService.alpha(ThemeService.fg, 0.4)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Enable hot corners"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: HotCornerService.enabled
                                  ? "Active — move cursor to any corner to trigger"
                                  : "Disabled — corners do nothing"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.alpha(ThemeService.fg, 0.6)
                        }
                    }

                    // Switch
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 22
                        radius: 11
                        color: HotCornerService.enabled
                               ? ThemeService.blue
                               : ThemeService.alpha(ThemeService.fg, 0.18)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: ThemeService.fg
                            y: 2
                            x: HotCornerService.enabled ? 20 : 2
                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                HotCornerService.enabled = !HotCornerService.enabled
                                HotCornerService.save()
                            }
                        }
                    }
                }
            }

            // ── 2×2 corner action grid ──
            SettingsSection {
                title: "Corner Actions"
                subtitle: "Pick what happens when cursor enters each corner"
                Layout.fillWidth: true

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: [
                            { id: "tl", label: "Top-Left",     icon: "\uf062\uf060",
                              prop: "actionTopLeft" },
                            { id: "tr", label: "Top-Right",    icon: "\uf062\uf061",
                              prop: "actionTopRight" },
                            { id: "bl", label: "Bottom-Left",  icon: "\uf063\uf060",
                              prop: "actionBottomLeft" },
                            { id: "br", label: "Bottom-Right", icon: "\uf063\uf061",
                              prop: "actionBottomRight" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 88
                            radius: 10
                            color: LookService.surfaceColor(ThemeService.bg2, 0.55)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: modelData.icon
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: ThemeService.blue
                                    }

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: ThemeService.fg
                                        Layout.fillWidth: true
                                    }
                                }

                                // v8.0.0-alpha-hf133 — was a bare QQC2 ComboBox,
                                // the only one left in the shell. It rendered with
                                // the platform style: a native arrow, square
                                // corners, no hover fade, no bounds-aware popup.
                                //
                                // ZenDropdown is a drop-in — it extends ComboBox,
                                // normalizes `{id, label}` entries to `{value, text}`,
                                // and emits `activated(realIndex)` against the same
                                // model. currentIndex resolution is unchanged.
                                ZenDropdown {
                                    id: actionCombo
                                    Layout.fillWidth: true
                                    model: root.availableActions

                                    Component.onCompleted: {
                                        const cur = HotCornerService[modelData.prop]
                                        for (let i = 0; i < root.availableActions.length; i++) {
                                            if (root.availableActions[i].id === cur) {
                                                currentIndex = i
                                                break
                                            }
                                        }
                                    }

                                    onActivated: {
                                        HotCornerService[modelData.prop] =
                                            root.availableActions[currentIndex].id
                                        HotCornerService.save()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
