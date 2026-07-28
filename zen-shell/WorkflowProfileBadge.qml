import QtQuick
import Quickshell

/*
 * WorkflowProfileBadge v7.0.0-alpha.13 — Karui (軽い)
 *
 * Compact bar widget showing the current workflow profile's icon.
 * Theme-aware. Click to open Control Panel (where the full picker
 * lives). Right-click to cycle to next profile.
 *
 * Designed to fit in the existing bar module slot — 24×24 area.
 */
Item {
    id: badge

    implicitWidth: 28
    implicitHeight: 28

    readonly property var currentProfileData: {
        const list = WorkflowProfileService.profilesList()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === WorkflowProfileService.currentProfile) return list[i]
        }
        return list[0]   // fallback to Work
    }

    readonly property string iconGlyph: badge.currentProfileData
                                        ? badge.currentProfileData.icon
                                        : "\uf0b1"

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: ma.containsMouse
               ? ThemeService.alpha(ThemeService.blue, 0.18)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        anchors.centerIn: parent
        text: badge.iconGlyph
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: ThemeService.fg
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // Open Control Panel (workflow picker is at top)
                Quickshell.execDetached({command: ["bash", "-c",
                    "qs -c zen-shell ipc call zen toggleControlCenter"]})
            } else {
                // Cycle to next profile
                const list = WorkflowProfileService.profilesList()
                let idx = -1
                for (let i = 0; i < list.length; i++) {
                    if (list[i].id === WorkflowProfileService.currentProfile) {
                        idx = i; break
                    }
                }
                const nextIdx = (idx + 1) % list.length
                WorkflowProfileService.activate(list[nextIdx].id)
            }
        }
    }
}
