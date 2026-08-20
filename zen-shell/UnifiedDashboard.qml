import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

/*
 * UnifiedDashboard.qml  —  Zen Unified Dashboard (v8)
 *
 * A single glass panel combining Quick Settings + Notifications (+ media),
 * Caelestia-style. Frosted look from the v8 mockup: translucent fills,
 * accent border, top sheen. Pairs with Hyprland layer blur (namespace
 * "zen-dash") for the real frost.
 *
 * ISOLATED: new panel, own toggle (SUPER+SHIFT+D / `dash` IPC). Your
 * existing Control Center (SUPER+C) is untouched — test alongside it.
 *
 * Wired to real services: ConnectivityService, BrightnessService,
 * NotificationService, Mpris, ThemeService (colors). Every self-reference
 * uses an explicit id (no fragile parent.parent chains).
 */
PanelWindow {
    id: win

    required property var modelData
    screen: modelData
    visible: DashState.screenName === modelData.name

    anchors { top: true; right: true }
    margins { top: 48; right: 12 }
    implicitWidth: 384
    implicitHeight: 592
    color: "transparent"
    WlrLayershell.namespace: "zen-dash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property color panelBase: Qt.rgba(0.06, 0.07, 0.10, 0.62)
    readonly property color cardFill:  Qt.rgba(1, 1, 1, 0.07)
    readonly property color cardEdge:  Qt.rgba(1, 1, 1, 0.14)
    readonly property color accent:    ThemeService.blue

    Item {
        anchors.fill: parent
        focus: win.visible
        Keys.onEscapePressed: DashState.close()
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 22
        color: win.panelBase
        border.color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1

        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: "transparent"
            border.color: ThemeService.alpha(win.accent, 0.35); border.width: 1.4
        }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
                GradientStop { position: 0.22; color: Qt.rgba(1, 1, 1, 0.03) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.01) }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── header ──
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9; color: win.accent
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "禅"; font.pixelSize: 15; color: "#0a0a0f" }
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Dashboard"; font.pixelSize: 16; font.bold: true; color: ThemeService.fg }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: Qt.formatDateTime(new Date(), "dddd, MMM d"); font.pixelSize: 11; color: ThemeService.grey1 }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: dndBtn
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10
                    color: NotificationService.dndEnabled ? ThemeService.alpha(ThemeService.red, 0.24) : win.cardFill
                    border.color: NotificationService.dndEnabled ? ThemeService.red : win.cardEdge; border.width: 1
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "\u25CF"; font.pixelSize: 13
                           color: NotificationService.dndEnabled ? ThemeService.red : ThemeService.grey1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.dndEnabled = !NotificationService.dndEnabled }
                }
                Rectangle {
                    id: closeBtn
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10
                    color: win.cardFill; border.color: win.cardEdge; border.width: 1
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 13; color: ThemeService.grey1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DashState.close() }
                }
            }

            // ── tab bar ──
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12; color: Qt.rgba(1, 1, 1, 0.05)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 4; spacing: 4
                    Repeater {
                        model: [ { id: "controls", label: "Controls" }, { id: "notifs", label: "Notifications" } ]
                        delegate: Rectangle {
                            id: tabItem
                            required property var modelData
                            readonly property bool active: DashState.tab === modelData.id
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: 9
                            color: active ? ThemeService.alpha(win.accent, 0.9) : "transparent"
                            RowLayout {
                                anchors.centerIn: parent; spacing: 6
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: tabItem.modelData.label; font.pixelSize: 13; font.bold: tabItem.active
                                       color: tabItem.active ? "#0a0a0f" : ThemeService.grey1 }
                                Rectangle {
                                    visible: tabItem.modelData.id === "notifs" && NotificationService.unreadCount > 0
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: 9
                                    color: tabItem.active ? Qt.rgba(0,0,0,0.25) : ThemeService.red
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.centerIn: parent; text: NotificationService.unreadCount
                                           font.pixelSize: 10; font.bold: true; color: tabItem.active ? "#0a0a0f" : "#ffffff" }
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DashState.tab = tabItem.modelData.id }
                        }
                    }
                }
            }

            // ══════════ CONTROLS TAB ══════════
            ColumnLayout {
                Layout.fillWidth: true
                visible: DashState.tab === "controls"
                spacing: 12

                GridLayout {
                    Layout.fillWidth: true; columns: 2; rowSpacing: 10; columnSpacing: 10

                    Rectangle {
                        id: wifiTile
                        Layout.fillWidth: true; Layout.preferredHeight: 66; radius: 14
                        readonly property bool on: ConnectivityService.wifiEnabled
                        color: on ? ThemeService.alpha(ThemeService.blue, 0.22) : win.cardFill
                        border.color: on ? ThemeService.blue : win.cardEdge; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\u25B2"; font.pixelSize: 16; color: wifiTile.on ? ThemeService.blue : ThemeService.grey1 }
                            ColumnLayout {
                                spacing: 0; Layout.fillWidth: true
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "Wi-Fi"; font.pixelSize: 13; font.bold: true; color: ThemeService.fg }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: wifiTile.on ? (ConnectivityService.wifiSSID || "On") : "Off"
                                       font.pixelSize: 10; color: ThemeService.grey1; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ConnectivityService.toggleWifi() }
                    }

                    Rectangle {
                        id: btTile
                        Layout.fillWidth: true; Layout.preferredHeight: 66; radius: 14
                        readonly property bool on: ConnectivityService.btPowered
                        color: on ? ThemeService.alpha(ThemeService.purple, 0.22) : win.cardFill
                        border.color: on ? ThemeService.purple : win.cardEdge; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\u2733"; font.pixelSize: 16; color: btTile.on ? ThemeService.purple : ThemeService.grey1 }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "Bluetooth"; font.pixelSize: 13; font.bold: true; color: ThemeService.fg }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: btTile.on ? "On" : "Off"; font.pixelSize: 10; color: ThemeService.grey1 }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ConnectivityService.toggleBluetooth() }
                    }

                    Rectangle {
                        id: dndTile
                        Layout.fillWidth: true; Layout.preferredHeight: 66; radius: 14
                        readonly property bool on: NotificationService.dndEnabled
                        color: on ? ThemeService.alpha(ThemeService.red, 0.22) : win.cardFill
                        border.color: on ? ThemeService.red : win.cardEdge; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\u25CF"; font.pixelSize: 15; color: dndTile.on ? ThemeService.red : ThemeService.grey1 }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "Do Not Disturb"; font.pixelSize: 13; font.bold: true; color: ThemeService.fg }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: dndTile.on ? "On" : "Off"; font.pixelSize: 10; color: ThemeService.grey1 }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.dndEnabled = !NotificationService.dndEnabled }
                    }

                    Rectangle {
                        id: muteTile
                        Layout.fillWidth: true; Layout.preferredHeight: 66; radius: 14
                        property bool on: false
                        color: on ? ThemeService.alpha(ThemeService.orange, 0.22) : win.cardFill
                        border.color: on ? ThemeService.orange : win.cardEdge; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\u25C4"; font.pixelSize: 15; color: muteTile.on ? ThemeService.orange : ThemeService.grey1 }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "Mute"; font.pixelSize: 13; font.bold: true; color: ThemeService.fg }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: muteTile.on ? "Muted" : "On"; font.pixelSize: 10; color: ThemeService.grey1 }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { ConnectivityService.toggleMute(); muteTile.on = !muteTile.on } }
                    }
                }

                // Brightness (hidden without brightnessctl)
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    visible: BrightnessService.hasBrightnessctl
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Brightness"; font.pixelSize: 11; color: ThemeService.grey1 }
                    Rectangle {
                        id: brTrack
                        Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 5
                        color: ThemeService.alpha(ThemeService.fg, 0.14)
                        property bool dragging: false
                        property real dragPct: 0
                        readonly property real pct: dragging ? dragPct : Math.max(0, Math.min(1, BrightnessService.brightness / 100))
                        Rectangle { width: brTrack.width * brTrack.pct; height: brTrack.height; radius: brTrack.radius; color: win.accent }
                        Rectangle { x: Math.max(0, brTrack.width * brTrack.pct - 9); y: -4; width: 18; height: 18; radius: 9
                                    color: "#ffffff"; border.color: Qt.rgba(0,0,0,0.18); border.width: 1 }
                        MouseArea {
                            anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
                            onPressed: (mouse) => { brTrack.dragging = true; brTrack.dragPct = Math.max(0, Math.min(1, mouse.x / brTrack.width)); BrightnessService.setBrightness(Math.round(brTrack.dragPct * 100)) }
                            onReleased: brTrack.dragging = false
                            onPositionChanged: (mouse) => { brTrack.dragPct = Math.max(0, Math.min(1, mouse.x / brTrack.width)); BrightnessService.setBrightness(Math.round(brTrack.dragPct * 100)) }
                        }
                    }
                }

                // Volume (set-only; local position → setVolume)
                // hf197 — track now spans 0..maxVolume (300); fill goes
                // orange past 100 and red past 200; tick marks 100%.
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Volume"; font.pixelSize: 11; color: ThemeService.grey1 }
                    Rectangle {
                        id: volTrack
                        Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 5
                        color: ThemeService.alpha(ThemeService.fg, 0.14)
                        property real pct: 0.5
                        Rectangle { width: volTrack.width * volTrack.pct; height: volTrack.height; radius: volTrack.radius
                                    color: ConnectivityService.audioVolume > 100
                                           ? ConnectivityService.volumeColor(ConnectivityService.audioVolume)
                                           : win.accent }
                        Rectangle { x: volTrack.width * (100 / ConnectivityService.maxVolume) - 1; y: -2
                                    width: 2; height: volTrack.height + 4; radius: 1; antialiasing: true
                                    color: ThemeService.alpha(ThemeService.fg, 0.45) }
                        Rectangle { x: Math.max(0, volTrack.width * volTrack.pct - 9); y: -4; width: 18; height: 18; radius: 9
                                    color: "#ffffff"; border.color: Qt.rgba(0,0,0,0.18); border.width: 1 }
                        MouseArea {
                            anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
                            onPressed: (mouse) => { volTrack.pct = Math.max(0, Math.min(1, mouse.x / volTrack.width)); ConnectivityService.setVolume(Math.round(volTrack.pct * ConnectivityService.maxVolume)) }
                            onPositionChanged: (mouse) => { volTrack.pct = Math.max(0, Math.min(1, mouse.x / volTrack.width)); ConnectivityService.setVolume(Math.round(volTrack.pct * ConnectivityService.maxVolume)) }
                        }
                    }
                }

                // Media card
                Rectangle {
                    id: mediaCard
                    Layout.fillWidth: true; Layout.preferredHeight: 84; radius: 14
                    color: win.cardFill; border.color: win.cardEdge; border.width: 1
                    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
                    readonly property bool playing: player ? player.playbackState === MprisPlaybackState.Playing : false

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 10
                            color: ThemeService.alpha(win.accent, 0.25)
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: "\u266B"; font.pixelSize: 22; color: win.accent }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: mediaCard.player ? (mediaCard.player.trackTitle || "Nothing playing") : "Nothing playing"
                                   font.pixelSize: 13; font.bold: true; color: ThemeService.fg; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: mediaCard.player ? (mediaCard.player.trackArtist || "") : ""
                                   font.pixelSize: 11; color: ThemeService.grey1; elide: Text.ElideRight; Layout.fillWidth: true }
                            RowLayout {
                                spacing: 16
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "\u25C4\u25C4"; font.pixelSize: 13; color: ThemeService.fg
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (mediaCard.player) mediaCard.player.previous() } }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: mediaCard.playing ? "\u2759\u2759" : "\u25B6"; font.pixelSize: 14; color: win.accent
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (mediaCard.player) mediaCard.player.playPause() } }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "\u25BA\u25BA"; font.pixelSize: 13; color: ThemeService.fg
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (mediaCard.player) mediaCard.player.next() } }
                            }
                        }
                    }
                }

                // System monitoring (v8) — live CPU / GPU / RAM / VRAM meters
                Rectangle {
                    Layout.fillWidth: true; radius: 14
                    color: win.cardFill; border.color: win.cardEdge; border.width: 1
                    implicitHeight: sysCol.implicitHeight + 24
                    ColumnLayout {
                        id: sysCol
                        anchors.fill: parent; anchors.margins: 12; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 7; height: 7; radius: 4; color: ThemeService.green }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "System \u00b7 Live"; font.pixelSize: 12; font.bold: true; color: ThemeService.fg }
                            Item { Layout.fillWidth: true }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: SystemMonitorService.cpuTemp > 0 ? (SystemMonitorService.cpuTemp + "\u00b0 / " + SystemMonitorService.gpuTemp + "\u00b0") : ""
                                   font.pixelSize: 9; font.family: "monospace"; color: ThemeService.grey1 }
                        }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "CPU"; font.pixelSize: 10; color: ThemeService.grey1; Layout.preferredWidth: 40 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                            color: ThemeService.alpha(ThemeService.fg, 0.12)
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, (SystemMonitorService.cpuPercent) / 100))
                                height: parent.height; radius: parent.radius
                                color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(SystemMonitorService.cpuPercent) + "%"; font.pixelSize: 10; font.family: "monospace"
                                color: ThemeService.fg; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "GPU"; font.pixelSize: 10; color: ThemeService.grey1; Layout.preferredWidth: 40 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                            color: ThemeService.alpha(ThemeService.fg, 0.12)
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, (SystemMonitorService.gpuUsage) / 100))
                                height: parent.height; radius: parent.radius
                                color: SystemMonitorService.usageColor(SystemMonitorService.gpuUsage)
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(SystemMonitorService.gpuUsage) + "%"; font.pixelSize: 10; font.family: "monospace"
                                color: ThemeService.fg; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "RAM"; font.pixelSize: 10; color: ThemeService.grey1; Layout.preferredWidth: 40 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                            color: ThemeService.alpha(ThemeService.fg, 0.12)
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, (SystemMonitorService.ramPercent) / 100))
                                height: parent.height; radius: parent.radius
                                color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(SystemMonitorService.ramPercent) + "%"; font.pixelSize: 10; font.family: "monospace"
                                color: ThemeService.fg; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "VRAM"; font.pixelSize: 10; color: ThemeService.grey1; Layout.preferredWidth: 40 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                            color: ThemeService.alpha(ThemeService.fg, 0.12)
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, ((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0)) / 100))
                                height: parent.height; radius: parent.radius
                                color: SystemMonitorService.usageColor((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0))
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0)) + "%"; font.pixelSize: 10; font.family: "monospace"
                                color: ThemeService.fg; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ══════════ NOTIFICATIONS TAB ══════════
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: DashState.tab === "notifs"
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: NotificationService.notifications.length + " notification" + (NotificationService.notifications.length === 1 ? "" : "s")
                           font.pixelSize: 12; color: ThemeService.grey1 }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        id: clearBtn
                        visible: NotificationService.notifications.length > 0
                        Layout.preferredHeight: 26; Layout.preferredWidth: clearRow.implicitWidth + 20
                        radius: 13; color: ThemeService.alpha(ThemeService.red, 0.16)
                        RowLayout { id: clearRow; anchors.centerIn: parent; spacing: 6
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "Clear all"; font.pixelSize: 11; font.bold: true; color: ThemeService.red } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.clearAll() }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: NotificationService.notifications.length === 0
                    Item { Layout.fillHeight: true }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         Layout.alignment: Qt.AlignHCenter; text: "\u25CB"; font.pixelSize: 40; color: ThemeService.alpha(ThemeService.fg, 0.3) }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         Layout.alignment: Qt.AlignHCenter; text: "No notifications"; font.pixelSize: 13; color: ThemeService.grey1 }
                    Item { Layout.fillHeight: true }
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: NotificationService.notifications.length > 0
                    clip: true; spacing: 8
                    model: NotificationService.notifications
                    delegate: Rectangle {
                        id: nItem
                        required property var modelData
                        width: ListView.view ? ListView.view.width : 0
                        implicitHeight: nCol.implicitHeight + 20
                        radius: 12; color: win.cardFill; border.color: win.cardEdge; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 8; Layout.alignment: Qt.AlignTop
                                color: ThemeService.alpha(win.accent, 0.22)
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: "\u25C9"; font.pixelSize: 13; color: win.accent }
                            }
                            ColumnLayout {
                                id: nCol; Layout.fillWidth: true; spacing: 2
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: nItem.modelData.appName || "Notification"; font.pixelSize: 10; color: ThemeService.grey1 }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: nItem.modelData.summary || ""; font.pixelSize: 13; font.bold: true; color: ThemeService.fg
                                       wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: nItem.modelData.body || ""; visible: text.length > 0
                                       font.pixelSize: 11; color: ThemeService.grey1; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                       maximumLineCount: 3; elide: Text.ElideRight }
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\u2715"; font.pixelSize: 12; color: ThemeService.grey1; Layout.alignment: Qt.AlignTop
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.dismiss(nItem.modelData.id) } }
                        }
                    }
                }
            }
        }
    }
}
