import QtQuick
import Quickshell
import Quickshell.Io

/*
 * ControlCenterButton v7.0.0-beta.1-hf82k — Karui (軽い)
 *
 * Stub button widget for the dock's "controlcenter" module slot. In
 * hf82k this is intentionally a placeholder — clicking it fires a
 * notify-send pointing the user at the upcoming popup. The button
 * itself is final visual quality (icon, hover, theme integration) so
 * the dock looks complete; only the popup is deferred.
 *
 * In hf82l the click handler will be wired to open ZenControlCenter,
 * a new quick-settings popup (volume sliders, wifi/bt toggles, power
 * profile picker, brightness, etc.). Until then this stub keeps the
 * visual slot in the dock with a discoverable hint to the user.
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
    Process { id: notifier; running: false }

    function _fire() {
        notifier.command = ["notify-send",
            "-a", "Zen Shell",
            "-i", "preferences-system",
            "Control Center",
            "Coming in hf82l — quick-settings popup with volume, wifi, BT, power profile, brightness."]
        notifier.running = true
    }
}
