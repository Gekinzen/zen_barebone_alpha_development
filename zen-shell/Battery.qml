import QtQuick
import QtQuick.Layouts
import Quickshell.Io

/*
 * Battery.qml v6.16.0.1 — bar battery module
 *
 * v6.16.0.1 HOTFIX:
 *   - Removed ToolTip attached property (requires QtQuick.Controls
 *     which isn't universally available in Quickshell — caused
 *     "Non-existent attached object" load failure). Replaced with
 *     ZenWeather-style hover-popup Rectangle (batTip) matching the
 *     existing convention noted in ZenWeather.qml: "no ToolTip in
 *     Quickshell".
 *
 * v6.16.0 NEW:
 *   - Three display modes (persisted via SettingsStateV2.batteryDisplayMode):
 *       "icon"    → Nerd Font glyph only (default)
 *       "text"    → "87%" text
 *       "bar"     → mini graphical progress bar
 *   - Reads capacity + status from SystemMonitorService.batteryCapacity /
 *     batteryStatus / batteryCharging / batteryPresent.
 *   - Gracefully hides itself on desktops (batteryPresent === false), so
 *     Paul can ship the same bar layout to both his 5950X desktop and
 *     laptops without branching config.
 *   - Click → opens ControlPanel's power section.
 *   - Hover popup shows capacity + status + time-to-empty/full.
 *
 * Wala tayong babawasan. Drop-in ready.
 */
Item {
    id: batteryRoot

    // ── Visibility: desktops have no battery, hide cleanly ──
    visible: SystemMonitorService.batteryPresent
    implicitWidth: visible ? (
        SettingsStateV2.batteryDisplayMode === "bar" ? 52 :
        SettingsStateV2.batteryDisplayMode === "text" ? (textLabel.implicitWidth + 24) :
        iconLabel.implicitWidth + 20
    ) : 0
    implicitHeight: parent ? parent.height : 40

    // Shortcut bindings
    readonly property int cap:   SystemMonitorService.batteryCapacity
    readonly property bool charging: SystemMonitorService.batteryCharging
    readonly property string status: SystemMonitorService.batteryStatus

    // Dynamic color: critical/warning/normal/charging
    readonly property color fgColor: {
        if (charging) return ThemeService.green
        if (cap <= 10) return ThemeService.red
        if (cap <= 30) return ThemeService.orange
        if (cap <= 50) return ThemeService.yellow
        return ThemeService.fg
    }

    // Nerd Font icon chosen by capacity (+ charging variant)
    readonly property string iconGlyph: {
        if (charging) {
            // Charging icons (nf-md-battery_charging_*)
            if (cap >= 90) return "\uf0084"   // battery-charging-100
            if (cap >= 70) return "\uf0085"   // charging-80
            if (cap >= 50) return "\uf0086"   // charging-60
            if (cap >= 30) return "\uf089f"   // charging-40
            return "\uf089e"                  // charging-20
        }
        // Discharging icons (nf-md-battery_*)
        if (cap >= 95) return "\uf0079"   // battery (full)
        if (cap >= 80) return "\uf0082"   // battery-90
        if (cap >= 65) return "\uf0081"   // battery-70
        if (cap >= 50) return "\uf0080"   // battery-60
        if (cap >= 35) return "\uf007f"   // battery-40
        if (cap >= 20) return "\uf007e"   // battery-20
        if (cap >= 10) return "\uf007a"   // battery-10
        return "\uf007c"                  // battery-alert
    }

    // ── ICON mode (default) ──
    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        id: iconLabel
        anchors.centerIn: parent
        visible: SettingsStateV2.batteryDisplayMode === "icon"
        text: batteryRoot.iconGlyph
        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
        font.pixelSize: 18
        color: batteryRoot.fgColor
    }

    // ── TEXT mode ──
    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        id: textLabel
        anchors.centerIn: parent
        visible: SettingsStateV2.batteryDisplayMode === "text"
        text: batteryRoot.cap + "%"
        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: batteryRoot.fgColor
    }

    // ── BAR mode ──
    Item {
        anchors.centerIn: parent
        visible: SettingsStateV2.batteryDisplayMode === "bar"
        width: 42
        height: 18

        // Outer battery body
        Rectangle {
            id: batBody
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 16
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(batteryRoot.fgColor.r, batteryRoot.fgColor.g,
                                  batteryRoot.fgColor.b, 0.6)

            // Fill
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 2
                width: Math.max(0, (parent.width - 4) * batteryRoot.cap / 100)
                radius: 1
                color: batteryRoot.fgColor

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            // Lightning bolt when charging
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                visible: batteryRoot.charging
                text: "\u26A1"
                font.pixelSize: 11
                color: LookService.surfaceColor(ThemeService.bg0, 1.0)
            }
        }

        // Battery tip (the little nub on the right)
        Rectangle {
            anchors.left: batBody.right
            anchors.verticalCenter: parent.verticalCenter
            width: 3; height: 8
            radius: 1
            color: Qt.rgba(batteryRoot.fgColor.r, batteryRoot.fgColor.g,
                           batteryRoot.fgColor.b, 0.6)
        }
    }

    // Hover highlight
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: batMouse.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.06) : "transparent"
        visible: batteryRoot.visible
    }

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Open Control Panel (quick settings)
            ccToggle.command = ["bash", "-c",
                "qs -c zen-shell ipc call zen toggleControlCenter"]
            ccToggle.running = true
        }
    }

    // Hover detail popup (no ToolTip in Quickshell — matches ZenWeather pattern)
    // Rendered below the bar module, pinned by x so it stays on-screen even
    // when Battery sits near the right edge of the bar.
    Rectangle {
        id: batTip
        visible: batMouse.containsMouse && batteryRoot.visible
        x: -20
        y: batteryRoot.height + 4
        width: tipCol.implicitWidth + 24
        height: tipCol.implicitHeight + 16
        radius: 8
        color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.95)
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.12)
        z: 999

        Column {
            id: tipCol
            anchors.centerIn: parent
            spacing: 2
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Battery: " + batteryRoot.cap + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: ThemeService.fg
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Status: " + batteryRoot.status
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.grey0
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: SystemMonitorService.batteryTimeRemaining.length > 0
                text: SystemMonitorService.batteryTimeRemaining
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.grey1
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: SystemMonitorService.batteryPowerDraw > 0
                text: "Power: " + SystemMonitorService.batteryPowerDraw.toFixed(1) + "W"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: ThemeService.grey1
            }
        }
    }

    Process { id: ccToggle; running: false }
}
