import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * PageFooter — Bottom action bar with Reset to Default button
 * Auto-apply means no Apply button — all changes are live.
 * Reset restores defaults for that specific page.
 */
RowLayout {
    id: root

    property string description: "Changes apply automatically"
    signal resetRequested()

    Layout.fillWidth: true
    Layout.topMargin: 16
    spacing: 12

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: ThemeService.alpha(ThemeService.fg, 0.08)
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        text: "\uf0eb  " + root.description
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: ThemeService.grey1
    }

    Button {
        text: "\uf0e2  Reset to Default"
        font.family: "JetBrainsMono Nerd Font"
        onClicked: root.resetRequested()

        background: Rectangle {
            color: parent.hovered
                   ? ThemeService.alpha(ThemeService.red, 0.18)
                   : LookService.surfaceColor(ThemeService.bg2, 0.6)
            radius: 6
            border.width: 1
            border.color: parent.parent.hovered
                          ? ThemeService.alpha(ThemeService.red, 0.5)
                          : ThemeService.alpha(ThemeService.fg, 0.15)
        }

        contentItem: Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: parent.text
            font: parent.font
            color: parent.hovered ? ThemeService.red : ThemeService.fg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
