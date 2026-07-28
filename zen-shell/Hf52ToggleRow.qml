import QtQuick
import QtQuick.Layouts

/*
 * Hf52ToggleRow — reusable label + sublabel + pill toggle row.
 *
 * Same rounded pill design as Bluetooth/WiFi/Audio toggles in
 * ControlPanel and the hf43 Input tab toggles. Used by the hf52
 * HyprbarsSettingsPage and pwedeng gamitin sa ibang settings pages
 * that need a label + sublabel + toggle layout.
 *
 * Usage:
 *   Hf52ToggleRow {
 *       label: "Show close button"
 *       sublabel: "Kills active window"
 *       active: HyprbarsService.showClose
 *       onToggled: HyprbarsService.showClose = !HyprbarsService.showClose
 *   }
 */
RowLayout {
    id: row
    Layout.fillWidth: true
    spacing: 12

    property string label: ""
    property string sublabel: ""
    property bool active: false
    signal toggled()

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: row.label
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: ThemeService.fg
        }
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            visible: row.sublabel.length > 0
            text: row.sublabel
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: ThemeService.grey1
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.preferredWidth: 42
        Layout.preferredHeight: 22
        radius: 11
        color: row.active
               ? ThemeService.alpha(ThemeService.green || "#98c379", 0.85)
               : ThemeService.alpha(ThemeService.fg, 0.15)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 18; height: 18; radius: 9
            color: ThemeService.fg
            y: 2
            x: row.active ? parent.width - width - 2 : 2
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }
}
