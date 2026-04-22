import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * BarModulesPage v6.8
 *
 * v6.8: Uniform 320px dropdown widths, HMRow icons, separators.
 * Auto-apply: PanelState properties are bound live by ZenClock.qml
 * and ZenWorkspaces.qml (shipped in tarball). User copies them
 * to ~/.config/quickshell/zen-shell/ as Clock.qml / Workspaces.qml
 * and changes apply instantly — no shell restart needed.
 *
 * WALA TAYONG BABAWASAN from v6.6 originals.
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    Timer {
        id: clockTick; interval: 1000; repeat: true; running: true
        onTriggered: previewDate = new Date()
    }
    property var previewDate: new Date()
    readonly property int dropdownWidth: 320

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 20
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "Bar Modules"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: ThemeService.fg }
            Text { text: "Format options for clock, workspaces, and font family"; font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
        }

        // Auto-apply install hint
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: autoCol.implicitHeight + 20
            radius: 10
            color: ThemeService.alpha(ThemeService.green, 0.08)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.green, 0.25)

            ColumnLayout {
                id: autoCol
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 4

                Text {
                    text: "\uf0e7  Auto-apply: copy ZenClock.qml → Clock.qml and ZenWorkspaces.qml → Workspaces.qml"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.green
                }
                Text {
                    text: "in ~/.config/quickshell/zen-shell/ — changes apply instantly, no restart"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }
            }
        }

        // ═══ CLOCK ═══
        HMSection {
            title: "Clock"

            HMRow {
                label: "Format"; description: "How the clock displays time and date"
                icon: "\uf017"; separator: true
                ComboBox {
                    id: clockCombo; width: root.dropdownWidth
                    model: { const m=[]; for(const f of ZenConstants.clockFormats) m.push(f.label); return m }
                    currentIndex: PanelState.clockFormatIndex
                    onActivated: { PanelState.clockFormatIndex = currentIndex; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Preview"; description: "Live preview"; icon: "\uf06e"
                Rectangle {
                    width: root.dropdownWidth; height: 56; radius: 10
                    color: Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.6)
                    border.width: 1; border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.1)
                    Text {
                        anchors.centerIn: parent
                        text: { const idx=Math.max(0,Math.min(ZenConstants.clockFormats.length-1,PanelState.clockFormatIndex))
                            return ZenConstants.formatClock(root.previewDate, ZenConstants.clockFormats[idx].format, true) }
                        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                        font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; color: ThemeService.fg
                    }
                }
            }
        }

        // ═══ WORKSPACES ═══
        HMSection {
            title: "Workspaces"

            HMRow {
                label: "Number format"; description: "Icons for workspace 1-10"
                icon: "\uf24d"; separator: true
                ComboBox {
                    id: wsCombo; width: root.dropdownWidth
                    property var presetIds: ["numbers","korean","chinese","japanese","roman",
                                             "nerd-dots","nerd-circles","nerd-squares","symbols","empty","custom"]
                    model: { const m=[]; for(const id of presetIds) m.push(ZenConstants.workspaceFormats[id].name); return m }
                    currentIndex: { const idx=presetIds.indexOf(PanelState.workspaceFormat); return idx>=0?idx:0 }
                    onActivated: { PanelState.workspaceFormat = presetIds[currentIndex]; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Visible count"; description: "How many workspaces shown in bar (3-10)"
                icon: "\uf0c8"; separator: true
                ComboBox {
                    width: root.dropdownWidth
                    model: ["3", "4", "5", "6", "7", "8", "9", "10"]
                    currentIndex: Math.max(0, Math.min(7, (PanelState.workspaceLimit || 5) - 3))
                    onActivated: { PanelState.workspaceLimit = currentIndex + 3; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Preview"; description: "How workspaces will look in bar"; icon: "\uf06e"
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: PanelState.workspaceLimit || 5
                        delegate: Rectangle {
                            required property int index
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                            color: index===0 ? Qt.rgba(ThemeService.blue.r,ThemeService.blue.g,ThemeService.blue.b,0.3)
                                             : Qt.rgba(ThemeService.bg2.r,ThemeService.bg2.g,ThemeService.bg2.b,0.5)
                            border.width: 1; border.color: Qt.rgba(ThemeService.fg.r,ThemeService.fg.g,ThemeService.fg.b,0.08)
                            Text {
                                anchors.centerIn: parent
                                text: ZenConstants.workspaceIcon(PanelState.workspaceFormat, index+1)
                                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                                font.pixelSize: 11; color: ThemeService.fg
                            }
                        }
                    }
                }
            }
        }

        // ═══ FONT ═══
        HMSection {
            title: "Font"

            HMRow {
                label: "Font family"; description: "Primary bar font. Falls back to JetBrainsMono Nerd Font Propo."
                icon: "\uf031"; separator: true
                ComboBox {
                    id: fontCombo; width: root.dropdownWidth
                    model: { const m=[]; for(const f of ZenConstants.fontFamilies) m.push(f.label); return m }
                    currentIndex: { for(let i=0;i<ZenConstants.fontFamilies.length;i++)
                        if(ZenConstants.fontFamilies[i].id===PanelState.fontFamilyId) return i; return 0 }
                    onActivated: { PanelState.fontFamilyId = ZenConstants.fontFamilies[currentIndex].id; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Preview"; description: "Sample text"; icon: "\uf06e"
                Rectangle {
                    width: root.dropdownWidth; height: 48; radius: 10
                    color: Qt.rgba(ThemeService.bg2.r,ThemeService.bg2.g,ThemeService.bg2.b,0.6)
                    border.width: 1; border.color: Qt.rgba(ThemeService.fg.r,ThemeService.fg.g,ThemeService.fg.b,0.1)
                    Text {
                        anchors.centerIn: parent
                        text: "The quick brown fox  \uf017  \uf015  \uf1e5"
                        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                        font.pixelSize: 14; color: ThemeService.fg
                    }
                }
            }
        }

        PageFooter {
            description: "Changes auto-save • copy ZenClock.qml + ZenWorkspaces.qml for instant bar updates"
            onResetRequested: {
                PanelState.clockFormatIndex = 6
                PanelState.workspaceFormat = "numbers"
                PanelState.fontFamilyId = "jetbrains"
                PanelState.saveState()
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
