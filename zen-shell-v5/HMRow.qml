import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * HMRow — HyprMod-style settings row
 *
 * Differs from the original SettingRow.qml:
 * - Larger minHeight (56 vs 48) so controls breathe (para pantay pag fullscreen)
 * - Right-aligned control slot with fixed Layout.alignment
 * - Explicit anchors.leftMargin 16 / rightMargin 16 (was 12)
 * - Subtle bottom separator line (optional, toggle via `separator`)
 * - Optional leading icon (Nerd Font glyph)
 *
 * Drop-in compatible: kept the same `label` + `description` + default content
 * slot API so kung may page na gumagamit ng SettingRow, kaya rin yun palitan
 * ng HMRow without code changes beyond the component name.
 */
Rectangle {
    id: root

    property string label: ""
    property string description: ""
    property string icon: ""               // optional Nerd Font glyph
    property bool separator: false         // draw thin divider at bottom
    default property alias control: controlSlot.data

    Layout.fillWidth: true
    implicitHeight: 56
    color: rowMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.04) : "transparent"
    radius: 8

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 14

        // Optional leading icon
        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: ThemeService.grey0
            Layout.preferredWidth: 20
            Layout.alignment: Qt.AlignVCenter
        }

        // Text column: label + description
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: ThemeService.fg
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: root.description
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                visible: root.description.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // Right-aligned control slot
        Item {
            id: controlSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
    }

    // Optional bottom separator
    Rectangle {
        visible: root.separator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: 1
        color: ThemeService.alpha(ThemeService.fg, 0.06)
    }
}
