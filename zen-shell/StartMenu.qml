import QtQuick
import Quickshell

/*
 * StartMenu.qml v6.16.4.12.6.52 (Hiraki 開き)
 *
 * v6.16.4.12.6.52 (Hiraki): Click-only behaviour confirmed and
 * documented as the canonical pattern. Hover highlights the button
 * visually (background + border tint), but the start menu only opens
 * on explicit left-click. Same approach the Clock module adopted in
 * this drop. Also added `z: 1` so the start button always wins click
 * hits over any sibling Loader/Item in the bar's left zone — matching
 * the user's request that the trigger modules sit on top of the bar
 * row's stacking order.
 *
 * v6.9: Fixed start menu alignment in island mode. Layer shell windows
 * report win.x=0 regardless of actual screen position, so for island
 * mode we compute the bar's actual X offset from the bar width +
 * screen width. Also made the button slightly larger (configurable).
 *
 * v6.4: Dynamic positioning via PanelState.reportStartButtonPosition()
 *
 * Wala tayong babawasan — all v6.9 / v6.16.2 / v6.16.3.5 logic
 * (logo resolver, fallback chain, auto-fit, opacity tint, status
 * fallback) preserved verbatim.
 */
Rectangle {
    id: startBtn

    // v6.16.4.12.6.52 (Hiraki): z-stack — start button always on top
    // of the bar's left zone. Same value used on Clock.
    z: 1

    // v6.9: Slightly larger button — user can adjust via Theme.moduleHeight
    width: Theme.moduleHeight + 4
    height: Theme.moduleHeight + 4

    radius: (PanelState.propagateStyleToModules && Theme.styleMode === "round")
            ? width / 2
            : Math.min(width / 2, Theme.barRadius > 0 ? Theme.barRadius : 10)

    color: ma.containsMouse ? Theme.alpha(Theme.blue, 0.3) : Theme.alpha(Theme.bg0, 0.6)

    // v6.16.4.12.7 (Tachiagari): Border can now adopt the panel's
    // borderColor when `PanelState.startButtonUseBorderColor` is on,
    // letting the start button visually tie into a colored panel
    // border. Hover state still flips to blue accent so the click
    // affordance remains obvious. Default off → identical look to
    // pre-Tachiagari (1px Theme.bg1 idle border).
    border.width: PanelState.startButtonBorderWidth > 0
                  ? PanelState.startButtonBorderWidth
                  : 1
    border.color: ma.containsMouse
                  ? Theme.blue
                  : (PanelState.startButtonUseBorderColor
                     ? PanelState.borderColor
                     : Theme.bg1)
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // v6.16.2: Custom logo support with auto-fit.
    // v6.16.3.5: three modes now — auto / builtin / custom. The
    // resolver on PanelState encapsulates the lookup logic; here we
    // just bind to its result with a sensible fallback for the empty
    // case (e.g. auto mode on a distro without a matching builtin).
    //
    // Fallback chain:
    //   PanelState.resolveStartButtonLogo()   ← user's effective choice
    //     → if empty, Quickshell.iconPath("distributor-logo-<osLogo>")
    //     → if that 404s, Quickshell.iconPath("distributor-logo-archlinux")
    Image {
        id: logoImg
        anchors.centerIn: parent
        width: PanelState.startButtonIconSize
        height: PanelState.startButtonIconSize

        // v7.0.0-alpha.3 (Densho Surfaces): hide the distro logo when
        // Densho mode is on — the kanji 禅 overlay below replaces it.
        visible: !DenshoService.denshoMode

        readonly property string _resolved: PanelState.resolveStartButtonLogo()
        readonly property string _osTag: UserProfileService
            ? String(UserProfileService.osLogo || "").toLowerCase()
            : ""

        source: _resolved !== ""
            ? _resolved
            : (_osTag
                ? Quickshell.iconPath("distributor-logo-" + _osTag)
                : Quickshell.iconPath("distributor-logo-archlinux"))

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
        opacity: (PanelState.startButtonLogoMode === "custom" && PanelState.startButtonLogoTint)
                 ? 0.85
                 : 1.0
        // Fallback to Arch icon if the resolved image fails to load
        onStatusChanged: if (status === Image.Error) {
            console.warn("[StartMenu] logo failed to load:", source, "falling back to Arch")
            source = Quickshell.iconPath("distributor-logo-archlinux")
        }
    }

    // v7.0.0-alpha.3 (Densho Surfaces): kanji 禅 overlay shown only
    // when DenshoService.denshoMode is on. Sits in the same anchored
    // center as logoImg. Thin shu-iro circle ring + kanji center.
    Item {
        id: denshoLogoOverlay
        visible: DenshoService.denshoMode
        anchors.centerIn: parent
        width: PanelState.startButtonIconSize
        height: PanelState.startButtonIconSize

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: ThemeService ? ThemeService.red : "#B85540"
            border.width: 1.4
            opacity: ma.containsMouse ? 0.95 : 0.85
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.centerIn: parent
            text: "禅"
            color: ThemeService ? ThemeService.red : "#B85540"
            font.family: "Noto Serif CJK JP, serif"
            font.pixelSize: Math.round(parent.width * 0.6)
            font.weight: Font.Medium
        }
    }

    // ─────────────────────────────────────────────────────────────
    // INPUT — hover (visual only), click opens menu
    // ─────────────────────────────────────────────────────────────
    // Same pattern as Clock.qml in this drop: hoverEnabled drives
    // the visual highlight, but the start menu only opens on
    // explicit left-click. No onEntered / onExited handlers.
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true                     // ← still true, for visual highlight
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
                // v6.16.4.12: Position-aware — bar at top vs bottom
                const globalY = PanelState.isTop ? PanelState.barHeight : (screenH - PanelState.barHeight)
                PanelState.reportStartButtonPosition(globalX, globalY, screenW, screenH)
            }

            if (win && win.screen) {
                root.toggleStartMenuOn(win.screen)
            } else {
                // v7.0.0-beta.1-hf25: was Quickshell.execDetached([qs ipc...])
                // which could spawn a new shell instance if current
                // instance is mid-crash. Use direct PanelState toggle.
                PanelState.startMenuVisible = !PanelState.startMenuVisible
            }
        }
    }
}
