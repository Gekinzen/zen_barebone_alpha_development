import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/*
 * PowerBadge v6.16.3.4 — Bar module: power profile + GPU mode at a glance
 * ────────────────────────────────────────────────────────────────────────
 *
 * Renders as a small pill in the bar showing two glyphs:
 *
 *   ┌──────────────┐
 *   │  ⚡  🎮       │   ← profile glyph (left), gpu glyph (right)
 *   └──────────────┘
 *
 * Visibility rules (additive, never crashes):
 *   - Profile half is hidden if PowerProfileService.available === false
 *     (i.e. powerprofilesctl not installed).
 *   - GPU half is hidden if GPUSwitcherService.isMultiGpu === false
 *     (single-GPU systems don't need a switcher indicator).
 *   - If BOTH are unavailable, the whole module collapses to width 0
 *     so it doesn't waste bar space. Bar.qml's Loader{active: ...}
 *     check handles total module hiding too — this is defense-in-depth.
 *
 * Click action:
 *   - Left click  → opens ControlPanel (which has both profile + GPU toggles)
 *   - Right click → cycles power profile (saver → balanced → performance)
 *   - Middle      → toggles Gaming Boost
 *
 * Hover popup:
 *   Wayland layer-shell popup that appears below the bar when hovering
 *   the badge for >300ms. Shows full label text + current state. Hides
 *   on mouse-exit with 200ms grace window so micro-jitters don't
 *   flicker the popup.
 *
 * Theme integration:
 *   Border + accent color follow PowerProfileService.currentProfile:
 *     power-saver  → Theme.green
 *     balanced     → Theme.blue
 *     performance  → Theme.orange
 *     gaming-boost → Theme.red (overrides whichever profile is active)
 *
 * Module registration:
 *   Add "powerbadge" anywhere in Theme.barLayout.{left,center,right}.
 *   Default layout in v6.16.3.4 places it in `right` between battery
 *   and notifications. Existing users keep their saved layout (additive
 *   policy) — they can hand-add "powerbadge" to bar-layout.json.
 *
 * Wala tayong binawasan — no existing module touched.
 */
Rectangle {
    id: badgeRoot

    // ── Visibility computation ──
    // (Both services are singletons defined elsewhere in the shell.)
    readonly property bool profileVisible: PowerProfileService.available
    readonly property bool gpuVisible: GPUSwitcherService.isMultiGpu
    readonly property bool anyVisible: profileVisible || gpuVisible

    // ── Sizing ──
    // Width auto-grows based on which halves are visible. Each glyph
    // gets ~22px; spacer is 6px. If neither shows, width collapses to 0.
    width:  anyVisible
            ? (profileVisible ? 22 : 0)
              + (gpuVisible ? 22 : 0)
              + ((profileVisible && gpuVisible) ? 6 : 0)
              + 16     // pill horizontal padding
            : 0
    height: Theme.moduleHeight
    visible: anyVisible
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    // v6.16.4.12.6: Frosted bg matching the rest of the right-side modules.
    // Bar bg @ 0.50 + this @ 0.32 composites to ~0.66 → above
    // `ignore_alpha 0.5` blur threshold, so Hyprland blur applies.
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.32)
    border.width: 1
    border.color: badgeRoot._accentColor
    Behavior on border.color { ColorAnimation { duration: 220 } }
    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    // ── Accent color picker ──
    // Gaming Boost wins over profile; "auto-gaming" GPU mode also reds.
    readonly property color _accentColor: {
        if (PowerProfileService.gamingBoostActive) return Theme.red
        if (GPUSwitcherService.currentMode === "auto-gaming") return Theme.red
        switch (PowerProfileService.currentProfile) {
            case "power-saver": return Theme.green
            case "balanced":    return Theme.blue
            case "performance": return Theme.orange
        }
        return Theme.fg
    }

    // ── Glyphs (FontAwesome via Theme.monoFont — same convention as
    //   the rest of the bar). PowerProfileService.profileIcon() and
    //   GPUSwitcherService.modeIcon() already return the right strings. ──
    RowLayout {
        anchors.centerIn: parent
        spacing: 6

        // Profile half
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            visible: badgeRoot.profileVisible
            text: PowerProfileService.profileIcon(PowerProfileService.currentProfile)
            color: badgeRoot._accentColor
            font.family: Theme.monoFont
            font.pixelSize: 14
            font.bold: true
            Behavior on color { ColorAnimation { duration: 220 } }
        }

        // GPU half
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            visible: badgeRoot.gpuVisible
            text: GPUSwitcherService.modeIcon(GPUSwitcherService.currentMode)
            color: badgeRoot._accentColor
            font.family: Theme.monoFont
            font.pixelSize: 14
            font.bold: true
            Behavior on color { ColorAnimation { duration: 220 } }
        }
    }

    // ── Hover / click ──
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: hoverShowTimer.restart()
        onExited:  { hoverShowTimer.stop(); hoverHideTimer.restart() }

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // Open Control Panel (has both toggles in one place)
                if (typeof zen !== "undefined" && typeof zen.toggleControlCenter === "function") {
                    zen.toggleControlCenter()
                }
            } else if (mouse.button === Qt.RightButton) {
                // Cycle profile saver → balanced → performance → saver
                if (!PowerProfileService.available) return
                const order = ["power-saver", "balanced", "performance"]
                const i = order.indexOf(PowerProfileService.currentProfile)
                const next = order[(i + 1) % order.length]
                PowerProfileService.setProfile(next)
            } else if (mouse.button === Qt.MiddleButton) {
                // Toggle Gaming Boost
                if (PowerProfileService.available
                    && typeof PowerProfileService.toggleGamingBoost === "function") {
                    PowerProfileService.toggleGamingBoost()
                }
            }
        }
    }

    Timer {
        id: hoverShowTimer
        interval: 300
        repeat: false
        onTriggered: if (ma.containsMouse) hoverPopup.visible = true
    }
    Timer {
        id: hoverHideTimer
        interval: 200
        repeat: false
        onTriggered: if (!ma.containsMouse) hoverPopup.visible = false
    }

    // ────────────────────────────────────────────────────────────
    // HOVER POPUP — Wayland layer-shell, anchored under the bar
    // ────────────────────────────────────────────────────────────
    PanelWindow {
        id: hoverPopup
        visible: false

        // Sized to content
        implicitWidth:  popupCol.implicitWidth + 28
        implicitHeight: popupCol.implicitHeight + 20

        color: "transparent"

        anchors {
            top: true
            left: true
        }

        // Position below the badge. badgeRoot.mapToGlobal-style trick:
        // we read the bar position from PanelState. The badge's own X
        // within the bar is added via parent.x walk.
        margins.top: PanelState.barHeight + 4
        margins.left: badgeRoot._popupGlobalX

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.alpha(Theme.bg0, 0.96)
            border.width: 1
            border.color: Theme.alpha(badgeRoot._accentColor, 0.5)

            ColumnLayout {
                id: popupCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 6

                // ── Profile row ──
                RowLayout {
                    visible: badgeRoot.profileVisible
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: PowerProfileService.profileIcon(PowerProfileService.currentProfile)
                        color: badgeRoot._accentColor
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Profile:"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: PowerProfileService.profileLabel(PowerProfileService.currentProfile)
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                // ── Gaming Boost row (shown only when active) ──
                RowLayout {
                    visible: PowerProfileService.gamingBoostActive
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf0e7"               // bolt
                        color: Theme.red
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Gaming Boost active"
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                // ── GPU row ──
                RowLayout {
                    visible: badgeRoot.gpuVisible
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: GPUSwitcherService.modeIcon(GPUSwitcherService.currentMode)
                        color: badgeRoot._accentColor
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "GPU:"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: GPUSwitcherService.modeLabel(GPUSwitcherService.currentMode)
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                // ── Hint footer ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    Layout.topMargin: 4
                    text: "L-click: open · R-click: cycle profile · M-click: boost"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.italic: true
                }
            }
        }

        // Mirror the badge's hover state — keep popup alive while
        // mouse is over EITHER the badge or the popup itself.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: hoverHideTimer.stop()
            onExited:  hoverHideTimer.restart()
        }
    }

    // Compute popup's global X by walking parent chain (same trick
    // ZenStrings uses for its sibling layer-surface alignment — see
    // Bar.qml v6.15.4 comments). We need the bar-local X plus the
    // bar's own offset on the screen to place the popup beneath
    // this badge specifically.
    property real _popupGlobalX: 0
    function _recomputePopupX() {
        var x = 0, item = badgeRoot
        // Walk up to the topmost panel/window
        while (item && item.parent) {
            x += item.x
            item = item.parent
        }
        // Center popup under the badge
        _popupGlobalX = Math.max(8, x - (hoverPopup.implicitWidth - badgeRoot.width) / 2)
    }
    onXChanged: Qt.callLater(_recomputePopupX)
    onWidthChanged: Qt.callLater(_recomputePopupX)
    Component.onCompleted: Qt.callLater(_recomputePopupX)
}
