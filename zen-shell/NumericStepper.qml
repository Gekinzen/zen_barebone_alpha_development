import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * NumericStepper — HyprMod-style  [−  8  +]  stepper
 *
 * Replaces Sliders in the General/Decoration pages to match the HyprMod UI
 * where most int fields are steppers, not sliders.
 *
 * Supports both int and real values via `decimals`. Emits valueChanged when
 * the user modifies the value.
 */
Rectangle {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string suffix: ""

    signal valueEdited(real newValue)

    implicitWidth: 120
    implicitHeight: 32
    radius: 8
    color: LookService.surfaceColor(ThemeService.bg2, 0.6)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.1)

    function _clamp(v) {
        if (v < from) return from
        if (v > to) return to
        return v
    }

    function _fmt(v) {
        if (decimals <= 0) return Math.round(v).toString()
        return v.toFixed(decimals)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // minus
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 28
            color: minusArea.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.1)
                   : "transparent"
            radius: 8

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: "−"
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: ThemeService.fg
            }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const v = root._clamp(root.value - root.stepSize)
                    if (v !== root.value) {
                        root.value = v
                        root.valueEdited(v)
                    }
                }
            }
        }

        // Value
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root._fmt(root.value) + root.suffix
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeService.fg
        }

        // plus
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 28
            color: plusArea.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.1)
                   : "transparent"
            radius: 8

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: "+"
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: ThemeService.fg
            }

            MouseArea {
                id: plusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const v = root._clamp(root.value + root.stepSize)
                    if (v !== root.value) {
                        root.value = v
                        root.valueEdited(v)
                    }
                }
            }
        }
    }
}
