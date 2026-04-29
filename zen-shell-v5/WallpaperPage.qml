import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * WallpaperPage v5 — Port of Python WallpaperPage to QML
 *
 * Features matching GTK version:
 * - Folder selection (via zenity/kdialog fallback — no native picker in QML)
 * - Slideshow toggle + interval dropdown (10s, 1m, 30m, 1h)
 * - Transition type selector
 * - Random transition toggle
 * - Paginated thumbnail grid (10 per page, 5 cols x 2 rows)
 * - Current wallpaper highlight (blue border + badge)
 * - Prev/Next pagination controls with page label
 */
ScrollView {
    id: root
    clip: true

    readonly property int thumbWidth: 180
    readonly property int thumbHeight: 120

    // ── Folder picker (uses zenity which is commonly installed) ──
    Process {
        id: folderPicker
        command: ["bash", "-c",
            "if command -v zenity > /dev/null; then " +
            "  zenity --file-selection --directory --title='Select Wallpaper Folder' 2>/dev/null; " +
            "elif command -v kdialog > /dev/null; then " +
            "  kdialog --getexistingdirectory '" + Quickshell.env("HOME") + "' 2>/dev/null; " +
            "else " +
            "  echo ''; " +
            "fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim()
                if (p && p.length > 0) {
                    WallpaperServiceV5.setFolder(p)
                }
            }
        }
    }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24
        y: 24
        spacing: 16

        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "Wallpaper"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Quick wallpaper selector — unified manager in Hypr Control Center"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        ControlCenterBanner {
            feature: "Wallpaper Manager (SWWW)"
            description: "Full SWWW integration, theme sync, color extraction"
        }

        // ── Folder section ──
        SettingsSection {
            title: "Wallpaper Folder"

            SettingRow {
                label: "Folder Path"

                RowLayout {
                    spacing: 8

                    TextField {
                        id: folderField
                        Layout.preferredWidth: 280
                        text: WallpaperServiceV5.localFolder
                        readOnly: true
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                    }

                    Button {
                        text: "Browse"
                        highlighted: true
                        onClicked: folderPicker.running = true
                    }

                    Button {
                        text: "\uf021"
                        font.family: "JetBrainsMono Nerd Font"
                        onClicked: WallpaperServiceV5.refresh()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: WallpaperServiceV5.activeList.length > 0
                      ? ("Found " + WallpaperServiceV5.activeList.length + " wallpapers in folder")
                      : (WallpaperServiceV5.loading ? "Loading..." : "No wallpapers found")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.grey1
                Layout.leftMargin: 12
            }

            SettingRow {
                label: "Transition Effect"

                ZenDropdown {
                    width: 160
                    model: ["Random", "Fade", "Wipe", "Grow", "Outer", "Wave"]
                    currentIndex: {
                        const m = { "random": 0, "fade": 1, "wipe": 2, "grow": 3, "outer": 4, "wave": 5 }
                        return m[WallpaperServiceV5.transitionType] || 1
                    }
                    onActivated: {
                        WallpaperServiceV5.setTransition(currentText.toLowerCase())
                    }
                }
            }
        }

        // ── Slideshow section ──
        SettingsSection {
            title: "Slideshow"

            SettingRow {
                label: "Auto Change Wallpaper"
                description: "Randomly cycle at intervals"

                HMSwitch {
                    checked: WallpaperServiceV5.slideshowEnabled
                    onToggled: WallpaperServiceV5.setSlideshow(checked)
                }
            }

            SettingRow {
                label: "Change Interval"

                ZenDropdown {
                    width: 160
                    model: ["10 seconds", "1 minute", "30 minutes", "1 hour"]
                    property var values: [10, 60, 1800, 3600]
                    currentIndex: {
                        for (let i = 0; i < values.length; i++) {
                            if (values[i] === WallpaperServiceV5.slideshowInterval) return i
                        }
                        return 1
                    }
                    onActivated: WallpaperServiceV5.setSlideshowInterval(values[currentIndex])
                }
            }

            SettingRow {
                label: "Random Transition"
                description: "Different effect each change"

                HMSwitch {
                    checked: WallpaperServiceV5.randomTransition
                    onToggled: WallpaperServiceV5.setRandomTransition(checked)
                }
            }
        }

        // ── Grid + pagination ──
        SettingsSection {
            title: "Select Wallpaper"
            subtitle: "Click to apply. Blue border = currently applied."

            // Thumbnail grid
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 12
                columnSpacing: 12

                // v6.16.4.6: 5→4 columns per Paul's request — 5 columns
                // made thumbnails cramped at 1.25x monitor scale and on
                // narrower Settings-window widths. Page size recomputed
                // as columns × 4 rows = 16 wallpapers per page.
                Component.onCompleted: WallpaperServiceV5.wallpapersPerPage = 4 * 4

                Repeater {
                    model: WallpaperServiceV5.pagedList

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool isCurrent: {
                            if (modelData.isRemote) {
                                return WallpaperServiceV5.currentWallpaper.endsWith("/" + modelData.name)
                            }
                            return WallpaperServiceV5.currentWallpaper === modelData.path
                        }

                        Layout.preferredWidth: root.thumbWidth
                        Layout.preferredHeight: root.thumbHeight + 28
                        radius: 10
                        color: "transparent"
                        border.width: isCurrent ? 3 : 1
                        border.color: isCurrent
                                      ? ThemeService.blue
                                      : (thumbMouse.containsMouse
                                         ? ThemeService.alpha(ThemeService.fg, 0.3)
                                         : ThemeService.alpha(ThemeService.fg, 0.1))

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.thumbHeight
                                radius: 6
                                color: ThemeService.bg2
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.url
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: root.thumbWidth * 2
                                    sourceSize.height: root.thumbHeight * 2
                                }

                                // Current badge
                                Rectangle {
                                    visible: parent.parent.parent.isCurrent
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: currentBadge.width + 12
                                    height: 20
                                    radius: 10
                                    color: ThemeService.blue

                                    Text {
                                        id: currentBadge
                                        anchors.centerIn: parent
                                        text: "✓ Current"
                                        color: "#ffffff"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: ThemeService.grey0
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WallpaperServiceV5.selectWallpaper(modelData)
                        }
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                visible: WallpaperServiceV5.filteredList.length === 0

                Text {
                    anchors.centerIn: parent
                    text: WallpaperServiceV5.loading ? "Loading wallpapers..." : "No wallpapers to show"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.grey1
                }
            }

            // Pagination controls
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: "← Previous"
                    enabled: WallpaperServiceV5.currentPage > 0
                    onClicked: WallpaperServiceV5.prevPage()
                }

                Text {
                    text: "Page " + (WallpaperServiceV5.currentPage + 1) +
                          " of " + WallpaperServiceV5.totalPages
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.fg
                    Layout.minimumWidth: 120
                    horizontalAlignment: Text.AlignHCenter
                }

                Button {
                    text: "Next →"
                    enabled: WallpaperServiceV5.currentPage < WallpaperServiceV5.totalPages - 1
                    onClicked: WallpaperServiceV5.nextPage()
                }

                Item { Layout.fillWidth: true }
            }
        }

        PageFooter {
            description: "Settings auto-save to wallpaper-v5.json"
            onResetRequested: {
                WallpaperServiceV5.setSlideshow(false)
                WallpaperServiceV5.setSlideshowInterval(60)
                WallpaperServiceV5.setTransition("fade")
                WallpaperServiceV5.setRandomTransition(false)
                WallpaperServiceV5.setFolder(Quickshell.env("HOME") + "/Pictures/Wallpapers")
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
