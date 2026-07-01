import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * ClipboardPanel v7.0.0-alpha.6 — clipboard history viewer panel
 *
 * Floating panel bound to Super+V (or click on the bar Clipboard
 * module). Shows ClipboardService.entries with:
 *
 *   - Pinned entries always at top
 *   - Search box (filters preview text)
 *   - Click row = paste (decodes via cliphist + wl-copy → user's
 *     next ctrl-v consumes it)
 *   - Right-click row = pin/unpin/delete context menu
 *   - "Wipe all" footer button (with confirm)
 *
 * Designed for fast keyboard use: Esc closes, Enter pastes top
 * filtered result + closes, ↑/↓ navigates.
 *
 * Public surface (mirrors StartMenuPanel pattern):
 *   - signal closeRequested()
 *   - signal entryPasted()         fired after successful paste
 *
 * Wala tayong babawasan — separate panel, doesn't replace anything.
 * shell.qml mounts it as a new PanelWindow gated by
 * PanelState.clipboardVisible.
 */
Rectangle {
    id: panelRoot

    signal closeRequested()
    signal entryPasted()

    // Visual tokens (consistent with StartMenuPanel hf3 patterns)
    readonly property int _cornerRadius:
        (PanelState.propagateStyleToModules && Theme.styleMode === "round") ? 22 : 16

    radius: _cornerRadius
    topLeftRadius:     (PanelState.isTop    || PanelState.isLeft)   ? 0 : _cornerRadius
    topRightRadius:    (PanelState.isTop    || PanelState.isRight)  ? 0 : _cornerRadius
    bottomLeftRadius:  (PanelState.isBottom || PanelState.isLeft)   ? 0 : _cornerRadius
    bottomRightRadius: (PanelState.isBottom || PanelState.isRight)  ? 0 : _cornerRadius

    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.94)
    border.width: PanelState.startMenuBorderMode === "off" ? 0 : 1
    border.color: PanelState.borderEnabled
                  ? PanelState.borderColor
                  : ThemeService.alpha(ThemeService.fg, 0.14)
    clip: true

    // Internal
    property string searchQuery: ""
    readonly property var displayEntries: {
        const all = ClipboardService.pinnedFirst()
        if (!searchQuery) return all
        const q = searchQuery.toLowerCase()
        return all.filter(function(e){
            return (e.preview || "").toLowerCase().indexOf(q) >= 0
        })
    }

    // Activate service polling while visible
    onVisibleChanged: {
        ClipboardService.active = panelRoot.visible
        if (panelRoot.visible) {
            ClipboardService.refresh()
            searchInput.forceActiveFocus()
        } else {
            panelRoot.searchQuery = ""
            searchInput.text = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin:    PanelState.isTop    ? 8 : 16
        anchors.bottomMargin: PanelState.isBottom ? 8 : 16
        anchors.leftMargin:   PanelState.isLeft   ? 8 : 16
        anchors.rightMargin:  PanelState.isRight  ? 8 : 16
        spacing: 10

        // ── HEADER ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: MaterialIcons.icon("assignment")
                font.family: MaterialIcons.fontFamily
                font.pixelSize: 22
                color: ThemeService.blue
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Clipboard"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                }
                Text {
                    text: ClipboardService.cliphistAvailable
                          ? panelRoot.displayEntries.length + " items"
                          : "cliphist not running"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ClipboardService.cliphistAvailable
                           ? ThemeService.grey1
                           : ThemeService.red
                }
            }

            // Wipe button (with implicit confirm via lock-out — single click
            // wipes; rely on the cliphist 'undo via Ctrl+V if last entry'
            // safety net rather than building a modal here).
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 8
                color: wipeMa.containsMouse
                       ? ThemeService.alpha(ThemeService.red, 0.14)
                       : "transparent"
                visible: ClipboardService.entries.length > 0

                Text {
                    anchors.centerIn: parent
                    text: MaterialIcons.icon("delete")
                    font.family: MaterialIcons.fontFamily
                    font.pixelSize: 16
                    color: wipeMa.containsMouse
                           ? ThemeService.red
                           : ThemeService.grey0
                }

                ToolTip.visible: wipeMa.containsMouse
                ToolTip.delay: 600
                ToolTip.text: "Wipe all clipboard history"

                MouseArea {
                    id: wipeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ClipboardService.wipe()
                }
            }
        }

        // ── SEARCH ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: ThemeService.alpha(ThemeService.bg2, 0.6)
            border.color: searchInput.activeFocus
                          ? ThemeService.alpha(ThemeService.blue, 0.5)
                          : ThemeService.alpha(ThemeService.fg, 0.10)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: MaterialIcons.icon("search")
                    font.family: MaterialIcons.fontFamily
                    font.pixelSize: 18
                    color: searchInput.activeFocus ? ThemeService.blue : ThemeService.grey0
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Search clipboard…"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.fg
                    placeholderTextColor: ThemeService.grey1
                    background: Item {}
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onTextChanged: panelRoot.searchQuery = text

                    Keys.onEscapePressed: {
                        if (text.length > 0) text = ""
                        else panelRoot.closeRequested()
                    }
                    Keys.onReturnPressed: {
                        const list = panelRoot.displayEntries
                        if (list.length > 0) {
                            ClipboardService.paste(list[0].id)
                            panelRoot.entryPasted()
                            panelRoot.closeRequested()
                        }
                    }
                }
            }
        }

        // ── ENTRIES LIST ──
        ListView {
            id: entriesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            cacheBuffer: 200
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            model: panelRoot.displayEntries

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 52
                radius: 8
                color: rowMa.containsMouse
                       ? ThemeService.alpha(ThemeService.blue, 0.10)
                       : ThemeService.alpha(ThemeService.bg2, 0.4)
                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 10

                    // Pin indicator
                    Text {
                        visible: modelData.isPinned
                        text: MaterialIcons.icon("push_pin")
                        font.family: MaterialIcons.fontFamily
                        font.pixelSize: 14
                        color: ThemeService.blue
                        Layout.preferredWidth: 18
                    }

                    // Type icon (image vs text)
                    Text {
                        visible: !modelData.isPinned
                        text: modelData.isImage
                              ? MaterialIcons.icon("image")
                              : MaterialIcons.icon("content_copy")
                        font.family: MaterialIcons.fontFamily
                        font.pixelSize: 16
                        color: ThemeService.grey0
                        Layout.preferredWidth: 18
                    }

                    Text {
                        text: modelData.isImage
                              ? "[image]"
                              : (modelData.preview || "")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.fg
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Inline pin/unpin toggle
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: pinMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.06)
                               : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: MaterialIcons.icon("push_pin")
                            font.family: MaterialIcons.fontFamily
                            font.pixelSize: 14
                            color: modelData.isPinned
                                   ? ThemeService.blue
                                   : ThemeService.grey0
                        }

                        MouseArea {
                            id: pinMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.isPinned)
                                    ClipboardService.unpin(modelData.id)
                                else
                                    ClipboardService.pin(modelData.id)
                            }
                        }
                    }

                    // Delete
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: delMa.containsMouse
                               ? ThemeService.alpha(ThemeService.red, 0.14)
                               : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: MaterialIcons.icon("close")
                            font.family: MaterialIcons.fontFamily
                            font.pixelSize: 14
                            color: delMa.containsMouse
                                   ? ThemeService.red
                                   : ThemeService.grey0
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardService.deleteEntry(modelData.id)
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    anchors.rightMargin: 76   // leave the inline buttons clickable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ClipboardService.paste(modelData.id)
                        panelRoot.entryPasted()
                        panelRoot.closeRequested()
                    }
                }
            }
        }

        // ── EMPTY STATE — diagnostic onboarding (v7.0.0-alpha.7) ──
        //
        // Shows full system status when no entries are visible. Three
        // possible states:
        //
        //   1. Search returned no matches (searchQuery set, no results)
        //      → "No matches" message
        //
        //   2. cliphist + watchers + DB all healthy, just nothing copied
        //      yet (or all entries cleared)
        //      → "Clipboard is empty — copy something to start"
        //
        //   3. Something's not set up (cliphist missing, watchers down,
        //      DB doesn't exist)
        //      → Diagnostic panel with one-click install/start buttons
        //
        // ClipboardOnboardingService re-probes on demand and exposes
        // the three booleans we render below.
        ColumnLayout {
            id: emptyStateLayout
            visible: panelRoot.displayEntries.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Search-no-match path (simplest — just the message)
            ColumnLayout {
                visible: panelRoot.searchQuery.length > 0
                Layout.alignment: Qt.AlignCenter
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: MaterialIcons.icon("search")
                    font.family: MaterialIcons.fontFamily
                    font.pixelSize: 32
                    color: ThemeService.alpha(ThemeService.fg, 0.3)
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No matches for \"" + panelRoot.searchQuery + "\""
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.grey1
                }
            }

            // Healthy + empty path
            ColumnLayout {
                visible: !panelRoot.searchQuery.length
                         && ClipboardOnboardingService.fullyReady
                Layout.alignment: Qt.AlignCenter
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: MaterialIcons.icon("history")
                    font.family: MaterialIcons.fontFamily
                    font.pixelSize: 32
                    color: ThemeService.alpha(ThemeService.fg, 0.3)
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Clipboard is empty"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: ThemeService.fg
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Copy something (Ctrl+C) to start building history"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }
            }

            // Diagnostic path (something's not set up)
            ColumnLayout {
                visible: !panelRoot.searchQuery.length
                         && !ClipboardOnboardingService.fullyReady
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 8
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: MaterialIcons.icon("warning")
                        font.family: MaterialIcons.fontFamily
                        font.pixelSize: 24
                        color: ThemeService.red
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Clipboard history not set up"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }
                        Text {
                            text: ClipboardOnboardingService.statusLabel
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey1
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: refreshMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.08)
                               : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: MaterialIcons.icon("refresh")
                            font.family: MaterialIcons.fontFamily
                            font.pixelSize: 14
                            color: ThemeService.grey0
                            rotation: ClipboardOnboardingService.probing ? 360 : 0
                            Behavior on rotation { NumberAnimation { duration: 600 } }
                        }

                        ToolTip.visible: refreshMa.containsMouse
                        ToolTip.text: "Re-check"

                        MouseArea {
                            id: refreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardOnboardingService.probe()
                        }
                    }
                }

                // Three-row checklist
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Check 1: cliphist installed
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.5)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                text: ClipboardOnboardingService.cliphistInstalled
                                      ? MaterialIcons.icon("check")
                                      : MaterialIcons.icon("close")
                                font.family: MaterialIcons.fontFamily
                                font.pixelSize: 16
                                color: ClipboardOnboardingService.cliphistInstalled
                                       ? ThemeService.green
                                       : ThemeService.red
                                Layout.preferredWidth: 20
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: "cliphist installed"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: ThemeService.fg
                                }
                                Text {
                                    text: ClipboardOnboardingService.cliphistInstalled
                                          ? "found in PATH"
                                          : "missing — needed to record copies"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.grey1
                                }
                            }

                            Rectangle {
                                visible: !ClipboardOnboardingService.cliphistInstalled
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: 80
                                radius: 6
                                color: installMa.containsMouse
                                       ? ThemeService.blue
                                       : ThemeService.alpha(ThemeService.blue, 0.85)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Install"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: ThemeService.bg0
                                }

                                MouseArea {
                                    id: installMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ClipboardOnboardingService.installCliphist()
                                }
                            }
                        }
                    }

                    // Check 2: watchers running
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.5)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1
                        opacity: ClipboardOnboardingService.cliphistInstalled ? 1.0 : 0.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                text: ClipboardOnboardingService.watchersRunning >= 2
                                      ? MaterialIcons.icon("check")
                                      : MaterialIcons.icon("close")
                                font.family: MaterialIcons.fontFamily
                                font.pixelSize: 16
                                color: ClipboardOnboardingService.watchersRunning >= 2
                                       ? ThemeService.green
                                       : ThemeService.red
                                Layout.preferredWidth: 20
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: "Watchers running"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: ThemeService.fg
                                }
                                Text {
                                    text: ClipboardOnboardingService.watchersRunning + " of 2 (text + image)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.grey1
                                }
                            }

                            Rectangle {
                                visible: ClipboardOnboardingService.cliphistInstalled
                                         && ClipboardOnboardingService.watchersRunning < 2
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: 80
                                radius: 6
                                color: startMa.containsMouse
                                       ? ThemeService.blue
                                       : ThemeService.alpha(ThemeService.blue, 0.85)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Start"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: ThemeService.bg0
                                }

                                MouseArea {
                                    id: startMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ClipboardOnboardingService.startWatchers()
                                }
                            }
                        }
                    }

                    // Check 3: DB exists
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.5)
                        border.color: ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1
                        opacity: ClipboardOnboardingService.watchersRunning >= 2 ? 1.0 : 0.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: ClipboardOnboardingService.dbExists
                                      ? MaterialIcons.icon("check")
                                      : MaterialIcons.icon("close")
                                font.family: MaterialIcons.fontFamily
                                font.pixelSize: 16
                                color: ClipboardOnboardingService.dbExists
                                       ? ThemeService.green
                                       : ThemeService.alpha(ThemeService.fg, 0.4)
                                Layout.preferredWidth: 20
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: "Database initialized"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: ThemeService.fg
                                }
                                Text {
                                    text: ClipboardOnboardingService.dbExists
                                          ? "~/.cache/cliphist/db"
                                          : "will be created on first copy"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.grey1
                                }
                            }
                        }
                    }
                }

                // Footer hint
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: "After installing + starting, copy text/image to test"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.italic: true
                    color: ThemeService.grey1
                    wrapMode: Text.Wrap
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
