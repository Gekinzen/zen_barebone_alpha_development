import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * ZenSysMonitor v6.16.3.6 — compact bar system monitor + hover popup
 *
 * v6.8: Binds to SystemMonitorService for live stats.
 * Shows: CPU% + temp + RAM% (compact pill-style).
 * v6.16.3.6: Hover popup rewritten to use PopupWindow (same pattern
 *            as ZenClock peek) so it renders above the bar's layer
 *            surface instead of clipping inside it. 350ms hover-intent
 *            delay matches ZenClock. Identical visual language —
 *            bg0 @ 96% alpha, 15% fg border, Theme.panelRadius (min 14).
 *            Content is sectioned with DemiBold section headers +
 *            grey0 body rows for scannability.
 *
 * Install as SysMonitor.qml in ~/.config/quickshell/zen-shell/
 * Then add "sysmonitor" to Theme.barLayout.right.
 */
Item {
    id: sysRoot
    implicitWidth: sysRow.implicitWidth + 16
    implicitHeight: parent ? parent.height : 40

    // v6.16.3.6 — hover-intent delay (matches ZenClock)
    property bool _peekPending: false
    Timer {
        id: peekDelay
        interval: 350
        repeat: false
        onTriggered: sysRoot._peekPending = tipArea.containsMouse
    }

    RowLayout {
        id: sysRow
        anchors.centerIn: parent
        spacing: 8

        // ── CPU pill ──
        RowLayout {
            spacing: 4
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "\uf2db"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: SystemMonitorService.cpuPercent + "%"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: SystemMonitorService.cpuTemp > 0
                text: SystemMonitorService.cpuTemp + "°"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 10
                color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp)
            }
        }

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: "·"
            font.pixelSize: 10
            color: ThemeService.grey2
        }

        // ── RAM pill ──
        RowLayout {
            spacing: 4
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "\uefc5"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
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
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "·"
                font.pixelSize: 10
                color: ThemeService.grey2
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "\uf26c"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: SystemMonitorService.gpuTemp + "°"
                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                font.pixelSize: 10
                color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp)
            }
        }
    }

    // v6.16.3.6: hover-intent MouseArea. acceptedButtons: Qt.NoButton
    // means clicks still pass through to any interactive child, only
    // hover events are captured for popup triggering.
    MouseArea {
        id: tipArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: peekDelay.restart()
        onExited: { peekDelay.stop(); sysRoot._peekPending = false }
    }

    // ═══════════════════════════════════════════════════════════════
    // v6.16.3.6 HOVER PEEK POPUP
    //
    // Renders via PopupWindow anchored to sysRoot, same as ZenClock.
    // Opens ABOVE the bar (Edges.Top) on Wayland — Quickshell handles
    // the positioning math, so it works correctly across floating,
    // island, and fullwidth bar modes.
    //
    // Replaces the old v6.8 inline `Rectangle { y: sysRoot.height+4 }`
    // tooltip which clipped at the bar's layer surface boundary.
    //
    // Styling mirrors ZenClock hover popup byte-identical (bg0 @ 96%,
    // 15% fg border, Theme.panelRadius ≤14, 350ms intent delay) so
    // every bar-module hover popup feels like one cohesive system.
    // ═══════════════════════════════════════════════════════════════
    PopupWindow {
        id: peekPopup
        anchor.item: sysRoot
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        visible: sysRoot._peekPending && tipArea.containsMouse
        width: Math.max(tipCol.implicitWidth + 28, 260)
        height: tipCol.implicitHeight + 20
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.panelRadius !== undefined ? Math.min(Theme.panelRadius, 14) : 10
            color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

            Column {
                id: tipCol
                anchors.centerIn: parent
                spacing: 6

                // ── CPU section ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: SystemMonitorService.cpuName
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: {
                        let s = "Usage: " + SystemMonitorService.cpuPercent + "%"
                        if (SystemMonitorService.cpuTemp > 0) {
                            s += "   ·   Temp: " + SystemMonitorService.cpuTemp + "°C"
                        }
                        return s
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tipCol.width * 0.6
                    height: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.1)
                }

                // ── GPU section ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: SystemMonitorService.gpuName
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                    visible: SystemMonitorService.gpuName.length > 0
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: {
                        let s = "Usage: " + SystemMonitorService.gpuUsage + "%"
                        if (SystemMonitorService.gpuTemp > 0) {
                            s += "   ·   Temp: " + SystemMonitorService.gpuTemp + "°C"
                        }
                        return s
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                    visible: SystemMonitorService.gpuName.length > 0
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: SystemMonitorService.gpuVramTotal > 0
                    text: "VRAM: " + SystemMonitorService.gpuVramUsed.toFixed(1) +
                          " / " + SystemMonitorService.gpuVramTotal.toFixed(1) + " GB"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tipCol.width * 0.6
                    height: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.1)
                }

                // ── Memory section ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Memory"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: SystemMonitorService.ramUsedGb.toFixed(1) +
                          " / " + SystemMonitorService.ramTotalGb.toFixed(1) +
                          " GB  (" + SystemMonitorService.ramPercent + "%)"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tipCol.width * 0.6
                    height: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.1)
                }

                // ── Network section ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Network"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "↓ " + SystemMonitorService.netDown +
                          "   ·   ↑ " + SystemMonitorService.netUp
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey0
                }
            }
        }
    }
}
