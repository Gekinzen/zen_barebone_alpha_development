import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * ZenSettings — Unified settings window (v6.2)
 *
 * Changes from v6.1:
 * - Added "General" and "Decoration" nav entries (HyprMod-style)
 *   AppearancePage kept as "Appearance (legacy)" for backward compat —
 *   walang sinira, may dagdag lang.
 * - Fixed fullscreen UI:
 *     * Sidebar width scales (220 windowed / 260 fullscreen) para pantay
 *       ang spacing across resolutions.
 *     * Inner content area gets a max-content-width clamp (1000px) and
 *       horizontal centering when fullscreen, so yung UI hindi ma-stretch
 *       at ma-irregular sa wide monitor.
 *     * Consistent 24px inner padding top/bottom across all pages.
 *
 * Layout (sidebar / content):
 * ┌──────────────────────────────────────────────┐
 * │ [⚙] Settings                          [□] [×]│
 * ├─────────────┬────────────────────────────────┤
 * │ APPEARANCE  │                                 │
 * │ • General   │                                 │
 * │ • Decoration│       [active page content]    │
 * │ • Animations│                                 │
 * │ • Themes    │                                 │
 * │ INPUT/DISPLAY                                 │
 * │ • Displays  │                                 │
 * │ • Panel     │                                 │
 * │ OTHER                                         │
 * │ • Wallpaper │                                 │
 * │ • Appearance(legacy)                          │
 * └─────────────┴────────────────────────────────┘
 */
Rectangle {
    id: root

    signal closeRequested()
    signal toggleFullscreen()

    property bool isFullscreen: false
    property bool hasBeenDragged: false  // v6.13: set true on drag to break anchors.centerIn

    color: ThemeService.alpha(ThemeService.bg0, 0.96)
    // v6.4: honor Theme.styleMode — rounded style gives 22, pill gives 16
    radius: isFullscreen
            ? 0
            : ((PanelState.propagateStyleToModules && Theme.styleMode === "round") ? 22 : 16)
    border.width: isFullscreen ? 0 : 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)
    clip: true

    // ── Nav state ──
    property string currentPage: "general"

    // Sidebar structure: header + items. Use null header entries to break
    // the list into sections (APPEARANCE / INPUT & DISPLAY / OTHER).
    readonly property var navItems: [
        { header: "APPEARANCE" },
        { id: "general",     label: "General",            icon: "\uf0c9" },  // bars
        { id: "decoration",  label: "Decoration",         icon: "\uf1fc" },  // paintbrush
        { id: "animations",  label: "Animations",         icon: "\uf021" },  // refresh
        { id: "themes",      label: "Themes",             icon: "\uf53f" },  // paint-brush
        { header: "INPUT & DISPLAY" },
        { id: "displays",    label: "Displays",           icon: "\uf26c" },  // tv
        { id: "panel",       label: "Panel",              icon: "\uf03a" },  // list
        { id: "barmodules",  label: "Bar Modules",        icon: "\uf017" },  // clock
        { header: "OTHER" },
        { id: "widgets",     label: "Desktop Widgets",    icon: "\uf1b2" },  // cube
        { id: "wallpaper",   label: "Wallpaper",          icon: "\uf03e" },  // image
        { id: "appearance",  label: "Appearance (legacy)", icon: "\uf1fc" }
    ]

    // Fullscreen-aware sidebar width
    readonly property int sidebarWidth: isFullscreen ? 260 : 220
    readonly property int contentInnerMaxWidth: 1100  // clamp content when fullscreen

    Keys.onEscapePressed: closeRequested()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════════
        // SIDEBAR — v6.8: rounded left corners match parent radius
        // ═══════════════════════════════════════════════
        Item {
            Layout.preferredWidth: root.sidebarWidth
            Layout.fillHeight: true
            clip: true

            Rectangle {
                anchors.fill: parent
                // Extend right edge past clip boundary to hide right corners
                anchors.rightMargin: -root.radius
                radius: root.radius
                color: ThemeService.alpha(ThemeService.bg1, 0.85)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 2

                // Header — v6.13: also serves as drag handle for the panel
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // v6.13: Drag handle — covers gear icon + "Settings" text only.
                        // Close/maximize buttons are outside this Item so they stay clickable.
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 0
                                spacing: 10

                                Text {
                                    text: "\uf013"  // gear
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: ThemeService.blue
                                }

                                Text {
                                    text: "Settings"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    color: ThemeService.fg
                                    Layout.fillWidth: true
                                }
                            }

                            // Drag MouseArea — LAST child = highest input priority.
                            // Covers the gear+Settings text area for dragging.
                            // Sets hasBeenDragged=true on press to break anchors.centerIn
                            // so drag.target can freely move the panel.
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.isFullscreen
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: root
                                drag.axis: Drag.XAndYAxis
                                drag.minimumX: 0
                                drag.minimumY: 0
                                preventStealing: true
                                onPressed: root.hasBeenDragged = true
                            }
                        }

                        // Maximize / Restore button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: maxBtnArea.containsMouse
                                   ? ThemeService.alpha(ThemeService.green, 0.2)
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: root.isFullscreen ? "\uf066" : "\uf065"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ThemeService.fg
                            }

                            MouseArea {
                                id: maxBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleFullscreen()
                            }
                        }

                        // Close button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: closeBtnArea.containsMouse
                                   ? ThemeService.alpha(ThemeService.red, 0.2)
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }

                            MouseArea {
                                id: closeBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeRequested()
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.08)
                    Layout.bottomMargin: 6
                    Layout.topMargin: 4
                }

                // Nav items (with section headers)
                Repeater {
                    model: root.navItems
                    delegate: Item {
                        id: navEntry
                        required property var modelData

                        readonly property bool isHeader: modelData.header !== undefined
                        readonly property bool active: !isHeader && root.currentPage === modelData.id

                        Layout.fillWidth: true
                        implicitHeight: isHeader ? 28 : 38

                        // SECTION HEADER (uppercase small text)
                        Text {
                            visible: navEntry.isHeader
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 4
                            anchors.bottomMargin: 4
                            text: navEntry.modelData.header || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                            color: ThemeService.grey0
                        }

                        // NAV ITEM
                        Rectangle {
                            visible: !navEntry.isHeader
                            anchors.fill: parent
                            radius: 8
                            color: navEntry.active
                                   ? ThemeService.alpha(ThemeService.blue, 0.18)
                                   : (navMouse.containsMouse
                                      ? ThemeService.alpha(ThemeService.fg, 0.06)
                                      : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: navEntry.isHeader ? "" : (navEntry.modelData.icon || "")
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: navEntry.active ? ThemeService.blue : ThemeService.grey0
                                    Layout.preferredWidth: 18
                                }

                                Text {
                                    text: navEntry.isHeader ? "" : (navEntry.modelData.label || "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: navEntry.active ? Font.DemiBold : Font.Normal
                                    color: navEntry.active ? ThemeService.fg : ThemeService.grey0
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!navEntry.isHeader) root.currentPage = navEntry.modelData.id
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Footer — current theme indicator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 6
                    color: ThemeService.alpha(ThemeService.bg2, 0.6)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10
                            radius: 5
                            color: ThemeService.blue
                        }

                        Text {
                            text: ThemeService.themeName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // CONTENT AREA
        // ═══════════════════════════════════════════════
        Rectangle {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // When fullscreen, center content with max-width clamp so it doesn't
            // sprawl awkwardly on wide monitors. When windowed, use full width.
            Item {
                id: contentClamp
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.isFullscreen
                       ? Math.min(parent.width - 48, root.contentInnerMaxWidth + 48)
                       : parent.width

                StackLayout {
                    id: pageStack
                    anchors.fill: parent
                    anchors.margins: 0

                    currentIndex: {
                        switch (root.currentPage) {
                            case "general":    return 0
                            case "decoration": return 1
                            case "animations": return 2
                            case "themes":     return 3
                            case "displays":   return 4
                            case "panel":      return 5
                            case "barmodules": return 6
                            case "widgets":    return 7
                            case "wallpaper":  return 8
                            case "appearance": return 9
                            default:           return 0
                        }
                    }

                    GeneralPage { }
                    DecorationPage { }
                    AnimationsPage { }
                    ThemesPage { }
                    DisplaysPage { }
                    PanelPage { }
                    BarModulesPage { }
                    WidgetsPage { }
                    WallpaperPage { }
                    AppearancePage { }
                }
            }
        }
    }
}

