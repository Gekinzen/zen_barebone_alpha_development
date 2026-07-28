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
    // v7.0.0-beta.1-hf99zo: opt-in "Glass — Advanced" card treatment. Off by
    // default, so every existing use (settings pages) is untouched.
    property bool glass: false
    default property alias content: contentLayout.data

    Layout.fillWidth: true
    color: glass ? LookService.surfaceColor(ThemeService.bg1, 0.28)
                 : LookService.surfaceColor(ThemeService.bg1, 0.6)
    radius: glass ? 18 : 12
    border.width: 1
    border.color: glass ? ThemeService.alpha(ThemeService.fg, 0.22)
                        : ThemeService.alpha(ThemeService.fg, 0.08)
    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: root.title
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: ThemeService.fg
                Layout.fillWidth: true
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
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
