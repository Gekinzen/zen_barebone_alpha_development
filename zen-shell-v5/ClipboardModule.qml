import QtQuick
import QtQuick.Controls
import Quickshell

/*
 * ClipboardModule v7.0.0-alpha.6 — bar widget for clipboard history
 *
 * Compact bar item showing a clipboard icon with a small badge for
 * recent-entry count. Clicking toggles the ClipboardPanel via
 * PanelState.clipboardVisible. Right-click immediately pastes the
 * most recent non-pinned entry (power-user shortcut).
 *
 * Pulse animation on entry-count change so user gets visual feedback
 * that something landed in clipboard (subtle, not jarring).
 *
 * Wala tayong babawasan — entirely new module. Registered in Bar.qml's
 * componentForModule case list as "clipboard"; selectable in
 * Settings → Panel → Module Layout dropdowns.
 */
Item {
    id: cm

    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight

    // Trigger a small pulse when entries[] grows
    property int _lastCount: 0
    Connections {
        target: ClipboardService
        function onEntriesChanged() {
            const n = ClipboardService.entries.length
            if (n > cm._lastCount) pulseAnim.start()
            cm._lastCount = n
        }
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: bg; property: "scale"; from: 1.0; to: 1.18; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: bg; property: "scale"; from: 1.18; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
    }

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        radius: 8
        color: ma.containsMouse || PanelState.clipboardVisible
               ? ThemeService.alpha(ThemeService.blue, 0.14)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: MaterialIcons.icon("assignment")
            font.family: MaterialIcons.fontFamily
            font.pixelSize: 16
            color: ma.containsMouse || PanelState.clipboardVisible
                   ? ThemeService.blue
                   : ThemeService.fg
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Count badge (top-right corner, only when entries > 0)
        Rectangle {
            visible: ClipboardService.entries.length > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.rightMargin: 1
            width: badgeText.implicitWidth + 6
            height: 12
            radius: 6
            color: ThemeService.blue

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: Math.min(99, ClipboardService.entries.length)
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: ThemeService.bg0
            }
        }
    }

    ToolTip.visible: ma.containsMouse && !PanelState.clipboardVisible
    ToolTip.delay: 600
    ToolTip.text: ClipboardService.cliphistAvailable
                  ? "Clipboard · " + ClipboardService.entries.length + " items"
                  : "Clipboard · cliphist not running"

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(m) {
            if (m.button === Qt.RightButton) {
                // Power-user shortcut: paste most recent non-pinned
                const recent = ClipboardService.entries.filter(function(e){
                    return !e.isPinned
                })
                if (recent.length > 0) ClipboardService.paste(recent[0].id)
                return
            }

            // v7.0.0-alpha.6-hf4: report the bar module's position
            // BEFORE triggering the IPC, so shell.qml's clipboardWindow
            // can anchor the panel directly under (or over) the icon
            // — same pattern as StartMenu.
            const win = QsWindow.window
            if (win) {
                const screenW = win.screen ? win.screen.width : 1920
                const localCenter = cm.mapToItem(null, cm.width / 2, cm.height / 2)
                const localRight  = cm.mapToItem(null, cm.width,     cm.height / 2)

                // Compute bar's screen X offset (same logic as StartMenu)
                let barScreenX = 0
                if (PanelState.panelMode === "island") {
                    const barW = win.width || screenW
                    barScreenX = (screenW - barW) / 2
                } else if (PanelState.panelMode === "floating") {
                    barScreenX = PanelState.panelMarginSide
                }

                const globalCenter = barScreenX + localCenter.x
                const globalRight  = barScreenX + localRight.x
                PanelState.reportClipboardButtonPosition(globalCenter, globalRight)
            }

            // v7.0.0-beta.1-hf28: emit signal so shell.qml's
            // toggleClipboardOnScreen() runs with the right monitor.
            // No subprocess spawn → no risk of second instance.
            // hf29: reuse the `win` already declared above (not redeclare).
            if (win && win.screen) {
                PanelState.toggleClipboardOnScreenRequested(win.screen)
            } else {
                // Fallback: emit with first screen
                if (Quickshell.screens.length > 0) {
                    PanelState.toggleClipboardOnScreenRequested(Quickshell.screens[0])
                }
            }
        }
    }
}
