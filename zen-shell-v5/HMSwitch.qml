import QtQuick
import QtQuick.Controls

/*
 * HMSwitch v6.16.1.4 — Modern pill toggle for Zen Shell Settings
 *
 * Drop-in replacement for stock `Switch { checked: ... onToggled: ... }`.
 * Matches the inline Rectangle-based toggle design used in WidgetsPage,
 * BatterySettingsPage, ControlPanel Gaming Boost, etc.
 *
 * v6.16.1.4: Centralized toggle component. Previously each settings
 * page had either a stock QQC2 Switch (ugly platform-native look) or
 * an inline pill Rectangle (modern look but copy-pasted). This unifies
 * all toggles to the modern pill design — edit once, update everywhere.
 *
 * Usage:
 *   HMSwitch {
 *       checked: someState
 *       onToggled: { someState = !someState; save() }
 *   }
 *
 * The signal is named `toggled` (not `clicked` / `onCheckedChanged`)
 * to match QQC2 Switch's API — easy to swap at call sites.
 *
 * Design:
 *   - Pill 50×26, radius 13
 *   - Dot 22×22, radius 11, white
 *   - ON: ThemeService.blue fill, dot slides right
 *   - OFF: translucent fg fill (0.15), dot at left
 *   - 150ms cubic animations on both color + dot x
 *   - Hover: subtle scale 1.05, cursor PointingHandCursor
 */
Rectangle {
    id: root

    property bool checked: false
    // v6.16.1.4: compact variant for tighter UI (Control Panel, SysRow).
    // Default size 50×26, compact 42×22. Same visual style, just smaller.
    property bool compact: false
    // v6.16.1.4: custom active color. Defaults to ThemeService.blue but
    // lazily resolved (empty string → computed via binding below). This
    // avoids touching ThemeService at type-registration time which caused
    // "HMSwitch is not a type" cascading load failures in v6.16.1.6.
    // Pages with semantic meaning can override this — green for "enabled/
    // visible", red for "urgent/gaming", etc.
    property color activeColor: "transparent"
    readonly property color _resolvedActive: {
        if (activeColor === "transparent" || activeColor.a === 0) {
            return ThemeService.blue
        }
        return activeColor
    }
    signal toggled()

    // Stock-Switch API compatibility layer — lets consumers write
    // `HMSwitch { checked: foo; onCheckedChanged: bar }` too.
    onCheckedChanged: if (_userToggled) { _userToggled = false; root.toggled() }
    property bool _userToggled: false

    width: compact ? 42 : 50
    height: compact ? 22 : 26
    radius: compact ? 11 : 13
    color: checked
        ? _resolvedActive
        : ThemeService.alpha(ThemeService.fg, 0.15)
    border.width: checked ? 0 : 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.1)

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

    scale: mouseArea.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
        id: knob
        width: root.compact ? 18 : 22
        height: root.compact ? 18 : 22
        radius: root.compact ? 9 : 11
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        color: "#ffffff"
        // Subtle drop-shadow illusion via a lower-z layer rectangle.
        // Avoids requiring QtGraphicalEffects (not always available
        // in Quickshell).
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 2
            height: parent.height + 2
            radius: parent.radius + 1
            color: "#000000"
            opacity: 0.15
            z: -1
        }
        Behavior on x {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root._userToggled = true
            root.checked = !root.checked
            root.toggled()
        }
    }
}
