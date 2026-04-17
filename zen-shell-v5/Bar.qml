import QtQuick
import QtQuick.Layouts

/*
 * Bar.qml v6.3
 *
 * Changes from v6.0:
 * - Exposes proper `implicitWidth` so island mode can hug content.
 * - Bridges ThemeService → Theme for live color updates. Since Theme is a
 *   separate pre-existing singleton on the user's system, and ThemeService
 *   is the source-of-truth (reads current-theme.json + watches for changes),
 *   we bind bar bg/border to ThemeService directly when PanelState overrides
 *   are not enabled. This way, apply a theme from ThemesPage → bar color
 *   updates instantly without needing a qs restart.
 * - Defensive: still never crashes if barLayout has unknown modules.
 */
Rectangle {
    id: barRoot
    radius: Theme.styleMode === "round" ? 22 : Theme.barRadius

    // Natural content width — sum of three row widths + spacers. shell.qml
    // reads this as `bar.contentImplicitWidth` to size the island-mode
    // PanelWindow. NOT bound to implicitWidth so fullwidth/floating modes
    // (which use anchors.fill) can stretch freely without fighting this
    // value. If we bound implicitWidth, the Bar would refuse to grow
    // past content-size and everything right-of-center would clip.
    readonly property int contentImplicitWidth: {
        const lw = leftRow.implicitWidth
        const cw = centerRow.implicitWidth
        const rw = rightRow.implicitWidth
        const spacer = (cw > 0 ? 48 : 24) * 2
        return lw + cw + rw + spacer + 16
    }

    // Background: three-tier fallback
    //   1. PanelState override (user-forced color/opacity)
    //   2. ThemeService (live theme — responds to theme apply)
    //   3. Theme singleton (legacy fallback, rarely hit)
    color: {
        if (PanelState.bgOverrideEnabled) {
            return Qt.rgba(
                PanelState.bgOverrideColor.r,
                PanelState.bgOverrideColor.g,
                PanelState.bgOverrideColor.b,
                PanelState.bgOverrideOpacity
            )
        }
        // ThemeService is live — Theme.barOpacity is still the user's
        // configured translucency, independent of bg color.
        return Qt.rgba(
            ThemeService.bg0.r,
            ThemeService.bg0.g,
            ThemeService.bg0.b,
            Theme.barOpacity
        )
    }

    // Border from PanelState (user-toggleable)
    border.width: PanelState.borderEnabled ? PanelState.borderWidth : 0
    border.color: PanelState.borderColor

    // ── Module factory (defensive) ──
    Component { id: cStartMenu; StartMenu {} }
    Component { id: cTaskbar; Taskbar {} }
    Component { id: cWorkspaces; Workspaces {} }
    Component { id: cWindowTitle; WindowTitle {} }
    Component { id: cMusic; MusicWidget {} }
    Component { id: cSysRow; SysRow {} }
    Component { id: cTray; SystemTray {} }
    Component { id: cNotif; NotificationIcon {} }
    Component { id: cClock; Clock {} }
    // v6.8: new modules — weather + system monitor
    Component { id: cWeather; ZenWeather {} }
    Component { id: cSysMonitor; ZenSysMonitor {} }

    function getComponent(name) {
        switch(name) {
            case "start": return cStartMenu
            case "taskbar": return cTaskbar
            case "workspaces": return cWorkspaces
            case "window": return cWindowTitle
            case "music": return cMusic
            case "sysrow": return cSysRow
            case "tray": return cTray
            case "notifications": return cNotif
            case "clock": return cClock
            // v6.8
            case "weather": return cWeather
            case "sysmonitor": return cSysMonitor
        }
        console.warn("[Bar] Unknown module:", name)
        return null
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        // ── LEFT ──
        RowLayout {
            id: leftRow
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.left || []
                Loader {
                    sourceComponent: barRoot.getComponent(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    active: sourceComponent !== null
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ── CENTER ──
        RowLayout {
            id: centerRow
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.center || []
                Loader {
                    sourceComponent: barRoot.getComponent(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    active: sourceComponent !== null
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ── RIGHT ──
        RowLayout {
            id: rightRow
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.right || []
                Loader {
                    sourceComponent: barRoot.getComponent(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    active: sourceComponent !== null
                }
            }
        }
    }
}
