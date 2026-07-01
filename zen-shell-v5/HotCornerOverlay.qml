import QtQuick
import Quickshell
import Quickshell.Wayland

/*
 * HotCornerOverlay v7.0.0-beta.1-hf37 — Karui (軽い)
 *
 * Per-screen event-driven hot corner triggers.
 *
 * Architecture:
 *   - Mounted by shell.qml via Variants { model: Quickshell.screens }
 *     so each connected monitor gets its own set of 4 corner triggers.
 *   - Each corner is a tiny invisible PanelWindow at WlrLayer.Overlay,
 *     anchored to one screen edge pair (top+left, top+right, etc.).
 *   - HoverHandler inside each window fires the moment the cursor
 *     enters the surface. No polling. Wayland delivers the event.
 *   - PanelWindow's `color: "transparent"` + small size + no content =
 *     completely invisible to the user but still receives cursor events.
 *   - WlrLayer.Overlay means the surface stays above fullscreen
 *     windows — so hot corners work even in fullscreen apps (browser
 *     YouTube, games via gamescope, etc.) which was a known weak spot
 *     of the old polling approach.
 *
 * Why one PanelWindow PER CORNER instead of one big transparent overlay?
 *   - A whole-screen transparent overlay would intercept ALL clicks
 *     and ALL hover events, breaking every other interaction.
 *   - Wayland layer surfaces with `aboveWindows: true` still pass
 *     pointer events through to the layer below ONLY IF the surface
 *     uses an input region. Quickshell sets the input region based on
 *     the OPAQUE BOUNDS of child items — so making the corner window
 *     just 16×16 pixels means only 16×16 of input is captured per
 *     corner, everything else passes through normally.
 *
 * Per-screen scaling:
 *   The size of the trigger zone is derived from each monitor's
 *   width. A 16 px corner on a 1920×1080 laptop screen is the same
 *   "visual reach" as a 32 px corner on a 3440-wide ultrawide.
 *   Computed from HotCornerService.cornerSize as base.
 *
 * Wala tayong babawasan — additive component, doesn't modify shell.qml
 * existing structures except to add one Variants block.
 */
Item {
    id: root
    required property var screen   // Quickshell.screens entry

    // Per-screen effective trigger size — scales with monitor width.
    // Falls back to 16 px if screen geometry isn't reported (shouldn't
    // happen but defensive).
    readonly property int effSize: {
        const w = screen && screen.width ? screen.width : 1920
        const base = HotCornerService.cornerSize
        if (w > 3440) return base * 2.5
        if (w > 2560) return base * 2.0
        if (w > 1920) return base * 1.5
        return base
    }

    readonly property string screenName: (screen && screen.name) ? screen.name : "?"

    // Master enable — when HotCornerService.enabled is false, none of
    // the 4 corner windows are visible/responsive. Per-corner enable
    // is checked inside HotCornerService.triggerCorner so the windows
    // can still listen for hover events (cheap) but the service
    // ignores them if disabled.
    readonly property bool overlayEnabled: HotCornerService.enabled

    // ─────────────────────────────────────────────────────────────
    // TOP-LEFT CORNER
    // ─────────────────────────────────────────────────────────────
    PanelWindow {
        id: tlWindow
        screen: root.screen
        visible: root.overlayEnabled

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zen-hotcorner-tl"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.left: true

        implicitWidth: root.effSize
        implicitHeight: root.effSize

        color: "transparent"

        // MouseArea with hoverEnabled is the reliable Qt Quick primitive
        // for hover detection on Wayland layer surfaces. HoverHandler
        // exists but has had inconsistent behavior in some Quickshell/Qt
        // versions when attached to fully transparent surfaces; MouseArea
        // works everywhere our existing codebase uses it (Battery.qml,
        // CalendarButton.qml, ClipboardModule.qml — see hoverEnabled
        // pattern throughout).
        //
        // acceptedButtons: Qt.NoButton means clicks pass through to
        // whatever's beneath — only hover events are captured.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: HotCornerService.triggerCorner("tl", root.screenName)
            onExited: HotCornerService.cornerExited("tl")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // TOP-RIGHT CORNER
    // ─────────────────────────────────────────────────────────────
    PanelWindow {
        id: trWindow
        screen: root.screen
        visible: root.overlayEnabled

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zen-hotcorner-tr"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.right: true

        implicitWidth: root.effSize
        implicitHeight: root.effSize

        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: HotCornerService.triggerCorner("tr", root.screenName)
            onExited: HotCornerService.cornerExited("tr")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // BOTTOM-LEFT CORNER
    // ─────────────────────────────────────────────────────────────
    PanelWindow {
        id: blWindow
        screen: root.screen
        visible: root.overlayEnabled

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zen-hotcorner-bl"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors.bottom: true
        anchors.left: true

        implicitWidth: root.effSize
        implicitHeight: root.effSize

        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: HotCornerService.triggerCorner("bl", root.screenName)
            onExited: HotCornerService.cornerExited("bl")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // BOTTOM-RIGHT CORNER
    // ─────────────────────────────────────────────────────────────
    PanelWindow {
        id: brWindow
        screen: root.screen
        visible: root.overlayEnabled

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zen-hotcorner-br"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors.bottom: true
        anchors.right: true

        implicitWidth: root.effSize
        implicitHeight: root.effSize

        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: HotCornerService.triggerCorner("br", root.screenName)
            onExited: HotCornerService.cornerExited("br")
        }
    }

    Component.onCompleted: {
        if (HotCornerService.debug) {
            console.log("[HotCornerOverlay] Mounted on " + root.screenName
                      + " — effSize=" + root.effSize)
        }
    }
}
