import QtQuick
import Quickshell

/*
 * ControlCenterButton v7.0.0-beta.1-hf82k — Karui (軽い)
 *
 * Button widget for the dock's "controlcenter" module slot.
 *
 * v8.0.0-alpha-hf126: this was a stub — clicking it fired a notify-send
 * promising a popup "in hf82l". That popup arrived, it's just called the
 * Zen Control Center and it opens from SUPER+C. The button routes there
 * now, same as the bar's control-center entry and the IPC endpoint.
 *
 * Theme-aware: hover and pressed states pull from ThemeService.blue
 * with alpha overlays.
 *
 * Wala tayong babawasan — additive widget; no consumer changes
 * required to test (button works fine if you slot "controlcenter"
 * anywhere a Rectangle child works — bar layout, dock layout, etc).
 */
Item {
    id: root

    readonly property int btnSize: 36
    implicitWidth: btnSize
    implicitHeight: btnSize

    // ── Visual root ──
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2

        readonly property real hoverAlpha: ma.containsMouse
            ? (ma.pressed ? 0.30 : 0.18) : 0.0
        color: (typeof ThemeService !== "undefined")
            ? Qt.rgba(
                ThemeService.blue.r,
                ThemeService.blue.g,
                ThemeService.blue.b,
                hoverAlpha
              )
            : Qt.rgba(0.4, 0.6, 1.0, hoverAlpha)

        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        // Icon: Font Awesome gear-cog (\uf013) — instantly readable as
        // "settings / control center". Falls back gracefully if the
        // font isn't loaded.
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.centerIn: parent
            text: "\uf013"
            font.family: (typeof Theme !== "undefined")
                ? Theme.iconFontFamily : "Font Awesome 6 Free"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: (typeof ThemeService !== "undefined")
                ? ThemeService.fg : "#ffffff"
            opacity: ma.containsMouse ? 1.0 : 0.85
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._fire()
        }
    }

    // ── Stub click handler ──
    //
    // hf82k: just emit a notification telling the user the popup is
    // coming in hf82l. Replacing this with a real popup mount is a
    // one-line change in hf82l (the rest of the visual stays).
    // v8.0.0-alpha-hf126 — open the Zen Control Center, don't advertise it.
    // Toggle rather than open: clicking the dock button while it's up should
    // put it away, which is what every other launcher affordance does.
    function _fire() {
        PanelState.dashboardVisible = !PanelState.dashboardVisible
    }
}
