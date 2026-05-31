import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * GamingPage v7.0.0-beta.1-hf82 — Settings page for Game Detection.
 *
 * Shows auto-detection controls, learned games list (smart memory),
 * and cache management. Connected to GameProfileService singleton.
 */
Item {
    id: root

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 24
            spacing: 16

            DenshoPageHeader {
                Layout.fillWidth: true
                title: "Game Detection"
                subtitle: "Smart auto-detect for games and heavy 3D apps"
                kanji: "遊戯"
                romaji: "Yūgi"
            }

            // ── STATUS ──
            HMSection {
                title: "Detection"

                HMRow {
                    label: "Enable game detection"
                    description: "Auto-switch to Gaming workflow profile when a game launches. "
                               + "Three detection tiers: window class/title, process name, GPU load."
                    icon: "\uf11b"
                    separator: true

                    HMSwitch {
                        checked: GameProfileService.enabled
                        onToggled: GameProfileService.enabled = checked
                    }
                }

                // ── hf82: opt-in Auto-Performance ──
                //
                // User report:
                //   "tas yung sa power profile kapag nag gaming kapag
                //    hindi naman naka auto wag mag auto performance
                //    mode pre"
                //
                // Was implicit before — detecting a game always flipped
                // the power profile to "performance" via
                // WorkflowProfileService.activate("gaming"). Now it's
                // an explicit toggle, off by default. Detection still
                // runs and the bar badge / workflow tagging still
                // updates; the power profile is only touched when this
                // is on. See GameProfileService.autoPowerSwitch.
                HMRow {
                    label: "Auto-switch to Performance"
                    description: "When ON: detecting a game flips the system power profile to "
                               + "Performance, then restores your previous profile when the game exits. "
                               + "When OFF: detection still runs (DND, brightness via workflow profile "
                               + "are unaffected here) but the power profile is left alone — useful if "
                               + "you manage performance manually via the Gaming Boost pill or you don't "
                               + "want a desktop AAA game to override a power-saver setting."
                    icon: "\uf0e7"   // fa-bolt
                    separator: true

                    HMSwitch {
                        checked: GameProfileService.autoPowerSwitch
                        onToggled: GameProfileService.autoPowerSwitch = checked
                    }
                }

                HMRow {
                    label: "GPU busy threshold"
                    description: "Tier 3 detection: if GPU usage exceeds this and the focused app "
                               + "isn't a known desktop app, assume it's a game. Current GPU: "
                               + (typeof SystemMonitorService !== "undefined"
                                  ? SystemMonitorService.gpuUsage + "%"
                                  : "N/A")
                    icon: "\uf26c"
                    separator: true

                    RowLayout {
                        spacing: 8
                        Slider {
                            Layout.preferredWidth: 120
                            from: 40; to: 95; stepSize: 5
                            value: GameProfileService.gpuBusyThreshold
                            onMoved: GameProfileService.gpuBusyThreshold = value
                        }
                        Text {
                            text: GameProfileService.gpuBusyThreshold + "%"
                            font.family: Theme.fontFamily; font.pixelSize: 12
                            color: ThemeService.fg
                        }
                    }
                }
            }

            // ── ACTIVE GAME ──
            HMSection {
                title: "Current Status"
                visible: GameProfileService.gameActive

                HMRow {
                    label: GameProfileService.activeGameTitle || "Unknown game"
                    description: "Class: " + GameProfileService.activeGameClass
                               + " · Detected via: " + GameProfileService.detectionTier
                    icon: "\uf04b"
                    separator: false
                }
            }

            // ── SMART MEMORY (learned games list) ──
            HMSection {
                title: "Smart Memory — " + GameProfileService._learnedGames.length + " games"

                // List header
                HMRow {
                    label: "Learned games"
                    description: "Games auto-detected during play. The more you play, the "
                               + "faster detection gets — learned games are caught within 500ms."
                    icon: "\uf0eb"
                    separator: GameProfileService._learnedGames.length > 0
                }

                // Game list
                Repeater {
                    model: GameProfileService._learnedGames

                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: gameRow.implicitHeight + 16
                        radius: 6
                        color: gameMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.05)
                               : "transparent"

                        RowLayout {
                            id: gameRow
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            // Game info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || modelData.class || "Unknown"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: ThemeService.fg
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        let parts = []
                                        if (modelData.class) parts.push("class: " + modelData.class)
                                        if (modelData.process) parts.push("proc: " + modelData.process)
                                        parts.push("via " + (modelData.detectedVia || "?"))
                                        return parts.join(" · ")
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    color: ThemeService.grey1
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: {
                                        let info = []
                                        if (modelData.timesDetected)
                                            info.push("played " + modelData.timesDetected + "×")
                                        if (modelData.lastSeen)
                                            info.push("last: " + modelData.lastSeen)
                                        if (modelData.firstSeen && modelData.firstSeen !== modelData.lastSeen)
                                            info.push("first: " + modelData.firstSeen)
                                        return info.join(" · ")
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    color: ThemeService.grey2
                                }
                            }

                            // Delete button
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 6
                                color: delMa.containsMouse
                                       ? ThemeService.alpha(ThemeService.red, 0.2)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "🗑"
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const updated = GameProfileService._learnedGames.slice()
                                        updated.splice(index, 1)
                                        GameProfileService._learnedGames = updated
                                        GameProfileService._compilePatterns()
                                        GameProfileService._queueSave()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: gameMa
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }

                // ── Clear all + info row ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 12

                    // Clear all button
                    Rectangle {
                        Layout.preferredWidth: clearTxt.implicitWidth + 24
                        Layout.preferredHeight: 32
                        radius: 6
                        color: clearMa.containsMouse
                               ? ThemeService.alpha(ThemeService.red, 0.15)
                               : ThemeService.alpha(ThemeService.bg2, 0.5)
                        border.width: 1
                        border.color: clearMa.containsMouse
                                      ? ThemeService.alpha(ThemeService.red, 0.4)
                                      : ThemeService.alpha(ThemeService.fg, 0.1)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            id: clearTxt
                            anchors.centerIn: parent
                            text: "Clear All Learned"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: clearMa.containsMouse ? ThemeService.red : ThemeService.grey0
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                GameProfileService._learnedGames = []
                                GameProfileService._compilePatterns()
                                GameProfileService._queueSave()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Stored in ~/.config/quickshell/zen-shell/games.json"
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: ThemeService.grey2
                    }
                }
            }

            // ── BUILT-IN PATTERNS (info only) ──
            HMSection {
                title: "Built-in Detection Patterns"

                HMRow {
                    label: "Window class patterns"
                    description: "steam_app_*, lutris-*, heroic-*, gamescope, .exe, "
                               + "UnrealEditor, Godot, RetroArch, pcsx2, rpcs3, "
                               + "dolphin-emu, ppsspp, yuzu, cemu, ryujinx, citra, wine"
                    icon: "\uf2d2"
                    separator: true
                }
                HMRow {
                    label: "Window title patterns"
                    description: "Vulkan, DirectX, DX10/11/12, OpenGL, Unreal Engine, "
                               + "FPS counter, Gamescope"
                    icon: "\uf022"
                    separator: true
                }
                HMRow {
                    label: "Process patterns"
                    description: "wine, wine64, proton, gamescope, mangohud, gamemode"
                    icon: "\uf085"
                    separator: false
                }
            }
        }
    }
}
