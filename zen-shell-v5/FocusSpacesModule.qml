import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/*
 * FocusSpacesModule v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Bar widget for Focus Spaces. Shows the active space name (or "No
 * space" placeholder). Click → toggle the FocusSpacesPanel popover.
 * Right-click → save current layout as a new Focus Space (prompts
 * for name in Settings).
 *
 * Hides itself completely if user has 0 saved spaces AND hasn't
 * opted in via Settings — module appears as soon as you save your
 * first space.
 */
Item {
    id: fm

    implicitWidth: Math.max(Theme.moduleHeight, contentRow.implicitWidth + 16)
    implicitHeight: Theme.moduleHeight

    // Hide until user has at least one space (or this is in their
    // explicit barLayout — handled by Bar.qml which always shows
    // listed modules regardless)
    property bool hasSpaces: FocusSpacesService.count() > 0

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
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: {
                const s = FocusSpacesService.activeSpace()
                if (s && s.icon) return s.icon
                return "\uf2bb"   // address-book icon as default
            }
            font.family: Theme.iconFontFamily
            font.pixelSize: 13
            color: PanelState.focusSpacesVisible
                   ? ThemeService.blue
                   : ThemeService.fg
        }

        Text {
            text: {
                const s = FocusSpacesService.activeSpace()
                if (s) return s.name
                if (FocusSpacesService.count() === 0) return "Focus"
                return "Spaces"
            }
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            color: PanelState.focusSpacesVisible
                   ? ThemeService.blue
                   : ThemeService.fg
            visible: fm.implicitWidth > Theme.moduleHeight + 20
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
                // Open Settings on the Focus Spaces page directly
                PanelState.openSettingsPage("focusspaces")
            } else {
                PanelState.focusSpacesVisible = !PanelState.focusSpacesVisible
            }
        }
    }
}
