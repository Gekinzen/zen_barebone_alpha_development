import QtQuick
import QtQuick.Controls
import Quickshell

/*
 * QuickNotesModule v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Bar widget for Quick Notes. Compact notepad icon with a small badge
 * showing total note count. Click → toggle the QuickNotesPanel popover
 * via PanelState.quickNotesVisible. Right-click → create a new note
 * immediately + open panel.
 *
 * Registered in Bar.qml as module id "quicknotes". Add to barLayout
 * to enable.
 */
Item {
    id: qm

    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: 2
        radius: 6
        color: ma.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.10)
               : "transparent"
        border.color: ma.containsMouse
                      ? ThemeService.alpha(ThemeService.fg, 0.15)
                      : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }

        // Sticky pulse on new sticky added
        transform: Scale {
            id: bgScale
            origin.x: bg.width / 2
            origin.y: bg.height / 2
            xScale: 1.0
            yScale: 1.0
        }
    }

    // Icon: notepad
    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        anchors.centerIn: parent
        text: "\uf249"   // sticky-note
        font.family: Theme.iconFontFamily
        font.pixelSize: 14
        color: PanelState.quickNotesVisible
               ? ThemeService.blue
               : ThemeService.fg
    }

    // Badge — total count, only shown if > 0
    Rectangle {
        visible: QuickNotesService.totalCount() > 0
        width: countText.implicitWidth + 6
        height: 12
        radius: 6
        color: ThemeService.alpha(ThemeService.blue, 0.85)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 1
        anchors.topMargin: 1

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            id: countText
            anchors.centerIn: parent
            text: QuickNotesService.totalCount()
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.Bold
            color: "white"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // Create new note + open panel
                if (QuickNotesService.notes.length === 0
                    || !QuickNotesService.getCurrentNote()) {
                    QuickNotesService.createNote()
                } else {
                    QuickNotesService.createNote()
                }
                PanelState.quickNotesVisible = true
            } else {
                PanelState.quickNotesVisible = !PanelState.quickNotesVisible
            }
        }
    }

    // Tooltip via simple Text on hover (lightweight, no Popup)
    Rectangle {
        visible: ma.containsMouse && !PanelState.quickNotesVisible
        z: 100
        radius: 4
        color: LookService.surfaceColor(ThemeService.bg1, 0.95)
        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
        border.width: 1
        width: tooltipText.implicitWidth + 12
        height: tooltipText.implicitHeight + 6
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            id: tooltipText
            anchors.centerIn: parent
            text: "Quick Notes (" + QuickNotesService.totalCount() + ")"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: ThemeService.fg
        }
    }
}
