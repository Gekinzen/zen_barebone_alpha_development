import QtQuick
import QtQuick.Layouts

/*
 * ZenSysMonitor — compact bar system monitor
 *
 * v6.8: Binds to SystemMonitorService for live stats.
 * Shows: CPU% + temp + RAM% (compact pill-style).
 * Hover tooltip shows full details (GPU, network, etc.)
 * Install as SysMonitor.qml in ~/.config/quickshell/zen-shell/
 * Then add "sysmonitor" to Theme.barLayout.right.
 */
Item {
    id: sysRoot
    implicitWidth: sysRow.implicitWidth + 16
    implicitHeight: parent ? parent.height : 40

    RowLayout {
        id: sysRow
        anchors.centerIn: parent
        spacing: 8

        // ── CPU pill ──
        RowLayout {
            spacing: 4
            Text {
                text: "\uf2db"  // cpu icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
            }
            Text {
                text: SystemMonitorService.cpuPercent + "%"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
            }
            // CPU temp (if available)
            Text {
                visible: SystemMonitorService.cpuTemp > 0
                text: SystemMonitorService.cpuTemp + "°"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 10
                color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp)
            }
        }

        // Separator dot
        Text {
            text: "·"
            font.pixelSize: 10
            color: ThemeService.grey2
        }

        // ── RAM pill ──
        RowLayout {
            spacing: 4
            Text {
                text: "\uf233"  // memory icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
            }
            Text {
                text: SystemMonitorService.ramUsedGb.toFixed(1) + "G"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
            }
        }

        // ── GPU temp (if available, compact) ──
        RowLayout {
            visible: SystemMonitorService.gpuTemp > 0
            spacing: 4
            Text {
                text: "·"
                font.pixelSize: 10
                color: ThemeService.grey2
            }
            Text {
                text: "\uf26c"  // gpu
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp)
            }
            Text {
                text: SystemMonitorService.gpuTemp + "°"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 10
                color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp)
            }
        }
    }

    // Hover detail popup (no ToolTip in Quickshell)
    Rectangle {
        id: sysTip
        visible: tipArea.containsMouse
        x: -40
        y: sysRoot.height + 4
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
            Text { text: "── " + SystemMonitorService.cpuName + " ──"; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: ThemeService.fg }
            Text { text: "Usage: " + SystemMonitorService.cpuPercent + "%" + (SystemMonitorService.cpuTemp > 0 ? "  •  Temp: " + SystemMonitorService.cpuTemp + "°C" : ""); font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey0 }
            Text { text: "── " + SystemMonitorService.gpuName + " ──"; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: ThemeService.fg }
            Text { text: "Usage: " + SystemMonitorService.gpuUsage + "%" + (SystemMonitorService.gpuTemp > 0 ? "  •  Temp: " + SystemMonitorService.gpuTemp + "°C" : ""); font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey0 }
            Text { visible: SystemMonitorService.gpuVramTotal > 0; text: "VRAM: " + SystemMonitorService.gpuVramUsed.toFixed(1) + " / " + SystemMonitorService.gpuVramTotal.toFixed(1) + " GB"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1 }
            Text { text: "── RAM ──"; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: ThemeService.fg }
            Text { text: SystemMonitorService.ramUsedGb.toFixed(1) + " / " + SystemMonitorService.ramTotalGb.toFixed(1) + " GB (" + SystemMonitorService.ramPercent + "%)"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey0 }
            Text { text: "── Network ──"; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: ThemeService.fg }
            Text { text: "↓ " + SystemMonitorService.netDown + "  •  ↑ " + SystemMonitorService.netUp; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey0 }
        }
    }

    MouseArea {
        id: tipArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
