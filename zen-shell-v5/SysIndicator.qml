import QtQuick

Rectangle {
    id: indicator
    implicitWidth: iconLabel.implicitWidth + 14
    height: 32
    radius: Theme.styleMode === "round" ? height / 2 : 16
    color: ma.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12) : "transparent"
    Behavior on color { ColorAnimation { duration: 200 } }

    property string iconText: ""
    property color accentColor: Theme.fg

    Text {
        id: iconLabel
        anchors.centerIn: parent
        text: indicator.iconText
        color: indicator.accentColor
        font.family: Theme.monoFont
        font.pixelSize: Theme.iconSize
        font.bold: true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
