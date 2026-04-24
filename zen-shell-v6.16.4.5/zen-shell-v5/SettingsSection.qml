import QtQuick
import QtQuick.Layouts

/*
 * SettingsSection — Grouped card for related settings
 * Matches GTK SettingsGroup style
 */
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: contentLayout.data

    Layout.fillWidth: true
    color: ThemeService.alpha(ThemeService.bg1, 0.6)
    radius: 12
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.08)
    implicitHeight: outerLayout.implicitHeight + 24

    ColumnLayout {
        id: outerLayout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.title.length > 0

            Text {
                text: root.title
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: ThemeService.fg
                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                visible: root.subtitle.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // Content
        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: 8
        }
    }
}
