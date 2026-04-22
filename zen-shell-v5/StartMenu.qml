import QtQuick
import Quickshell

/*
 * StartMenu.qml v6.9
 *
 * v6.9: Fixed start menu alignment in island mode. Layer shell windows
 * report win.x=0 regardless of actual screen position, so for island
 * mode we compute the bar's actual X offset from the bar width +
 * screen width. Also made the button slightly larger (configurable).
 *
 * v6.4: Dynamic positioning via PanelState.reportStartButtonPosition()
 */
Rectangle {
    id: startBtn

    // v6.9: Slightly larger button — user can adjust via Theme.moduleHeight
    width: Theme.moduleHeight + 4
    height: Theme.moduleHeight + 4

    radius: (PanelState.propagateStyleToModules && Theme.styleMode === "round")
            ? width / 2
            : Math.min(width / 2, Theme.barRadius > 0 ? Theme.barRadius : 10)

    color: ma.containsMouse ? Theme.alpha(Theme.blue, 0.3) : Theme.alpha(Theme.bg0, 0.6)
    border.width: 1
    border.color: ma.containsMouse ? Theme.blue : Theme.bg1
    Behavior on color { ColorAnimation { duration: 200 } }

    // v6.16.2: Custom logo support with auto-fit.
    // Mode "auto" → distribution icon (original behavior).
    // Mode "custom" → user-picked image at startButtonLogoPath, scaled
    // to fit the button with preserved aspect ratio.
    Image {
        id: logoImg
        anchors.centerIn: parent
        width: PanelState.startButtonIconSize
        height: PanelState.startButtonIconSize
        source: PanelState.startButtonLogoMode === "custom" && PanelState.startButtonLogoPath
                ? "file://" + PanelState.startButtonLogoPath
                : Quickshell.iconPath("distributor-logo-archlinux")
        // v6.16.2: auto-fit preserves aspect ratio of user's custom image
        // (PNG/SVG/JPG). For the distro icon this is a no-op since the
        // icon is already square. smooth=true for better downscaling of
        // high-res user images.
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        // Render at 2x internal resolution for crisp scaling
        sourceSize: Qt.size(PanelState.startButtonIconSize * 2, PanelState.startButtonIconSize * 2)
        // Optional theme tint for monochrome SVGs — opacity blend with
        // the button's background color gives a tinted effect without
        // requiring QtGraphicalEffects ColorOverlay or shader fragments
        // that may not be available across all Quickshell builds.
        opacity: PanelState.startButtonLogoMode === "custom" && PanelState.startButtonLogoTint
                 ? 0.85
                 : 1.0
        // Fallback to distro icon if the user's custom image fails to load
        onStatusChanged: if (status === Image.Error && PanelState.startButtonLogoMode === "custom") {
            console.warn("[StartMenu] custom logo failed to load:", source, "falling back")
            source = Quickshell.iconPath("distributor-logo-archlinux")
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const win = QsWindow.window
            if (win) {
                const screenW = win.screen ? win.screen.width : 1920
                const screenH = win.screen ? win.screen.height : 1080

                // Map button center to bar-local coordinates
                const localCenter = startBtn.mapToItem(null, startBtn.width / 2, startBtn.height / 2)

                // v6.9: Compute the bar's actual screen X offset.
                // Layer shell windows always report win.x = 0.
                // For island mode, the bar is centered: barX = (screenW - barW) / 2
                // For floating mode, barX = panelMarginSide
                // For fullwidth, barX = 0
                let barScreenX = 0
                if (PanelState.panelMode === "island") {
                    // In island mode, the PanelWindow width is dynamic
                    // and it's centered on screen. We can approximate:
                    const barW = win.width || screenW
                    barScreenX = (screenW - barW) / 2
                } else if (PanelState.panelMode === "floating") {
                    barScreenX = PanelState.panelMarginSide
                }
                // else fullwidth: barScreenX = 0

                const globalX = barScreenX + localCenter.x
                const globalY = screenH - PanelState.barHeight
                PanelState.reportStartButtonPosition(globalX, globalY, screenW, screenH)
            }

            if (win && win.screen) {
                root.toggleStartMenuOn(win.screen)
            } else {
                Quickshell.execDetached({command: ["qs", "-c", "zen-shell", "ipc", "call", "zen", "toggleStartMenu"]})
            }
        }
    }
}
