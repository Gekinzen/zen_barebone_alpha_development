import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * WallpaperPicker — compact picker for Super+W / control-panel overlay
 *
 * v6.5 — previously referenced in shell.qml but the component file was
 * missing (came from an older v5 install that did ship it). QML silently
 * failed to resolve `WallpaperPicker {}` → overlay appeared but click-to-apply
 * was a no-op. This provides the missing component.
 *
 * Uses the same WallpaperServiceV5 backend as WallpaperPage, just a
 * tighter UI meant for a modal/overlay context.
 */
Rectangle {
    id: root

    signal closeRequested()

    color: Qt.rgba(
        ThemeService.bg0.r,
        ThemeService.bg0.g,
        ThemeService.bg0.b,
        0.96
    )
    radius: (PanelState.propagateStyleToModules && Theme.styleMode === "round") ? 22 : 16
    border.width: 1
    border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)
    clip: true

    readonly property int thumbWidth: 180
    readonly property int thumbHeight: 110

    // v6.16.2.3.2: Online repo browser toggle. When true, the grid shows
    // wallpapers from WallpaperRepoService (Gekinzen/images-demo) instead
    // of the local folder.
    property bool onlineMode: false

    Keys.onEscapePressed: closeRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "\uf03e"   // image
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: ThemeService.blue
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Wallpaper"
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "•"
                color: ThemeService.grey1
                Layout.leftMargin: 6
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                Layout.fillWidth: true
                text: WallpaperServiceV5.activeList.length + " images in "
                      + WallpaperServiceV5.localFolder
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
                elide: Text.ElideLeft
            }

            // Random button
            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 34
                radius: 8
                color: randomBtn.containsMouse
                       ? Qt.rgba(ThemeService.purple.r, ThemeService.purple.g, ThemeService.purple.b, 0.22)
                       : Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.6)
                border.width: 1
                border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf074"  // shuffle
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: ThemeService.fg
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Random"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.fg
                    }
                }

                MouseArea {
                    id: randomBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WallpaperServiceV5.randomWallpaper()
                }
            }

            // v6.16.2.3.2: Online repo browser (Gekinzen/images-demo).
            // Toggles a panel below the header that lists wallpapers
            // from the GitHub repo. Cached locally; one-click apply.
            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 34
                radius: 8
                color: onlineBtn.containsMouse
                       ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.22)
                       : (root.onlineMode
                          ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.32)
                          : Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.6))
                border.width: 1
                border.color: root.onlineMode
                              ? ThemeService.blue
                              : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf0c2"  // cloud
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: ThemeService.fg
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: root.onlineMode ? "Local" : "Online"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.fg
                    }
                }

                MouseArea {
                    id: onlineBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.onlineMode = !root.onlineMode
                        if (root.onlineMode
                            && !WallpaperRepoService.hasFetchedOnce) {
                            WallpaperRepoService.refresh()
                        }
                    }
                }
            }

            // Refresh button
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 8
                color: refreshBtn.containsMouse
                       ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.18)
                       : "transparent"
                border.width: 1
                border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "\uf021"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: ThemeService.fg
                }

                MouseArea {
                    id: refreshBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // v7.0.0-beta.1-hf96: in Online mode this forces a fresh
                    // repo pull (bypassing the TTL cache) so the user can
                    // manually recover an empty/stale Online tab; in Local
                    // mode it rescans the local folder as before.
                    onClicked: {
                        if (root.onlineMode)
                            WallpaperRepoService.refresh(true)
                        else
                            WallpaperServiceV5.refresh()
                    }
                }
            }

            // Close
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: closeBtn.containsMouse
                       ? Qt.rgba(ThemeService.red.r, ThemeService.red.g, ThemeService.red.b, 0.22)
                       : "transparent"

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: ThemeService.fg
                }

                MouseArea {
                    id: closeBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── Search bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 8
            color: Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.5)
            border.width: 1
            border.color: searchInput.activeFocus
                          ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.4)
                          : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.1)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "\uf002"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: ThemeService.grey0
                }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: ThemeService.fg
                    clip: true
                    selectByMouse: true
                    onTextChanged: {
                        WallpaperServiceV5.searchQuery = text
                        WallpaperServiceV5.resetPage()
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.fill: parent
                        visible: !searchInput.text
                        text: "Filter wallpapers by name..."
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.grey1
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // ── Thumbnail grid — v6.13: strict 4-row cap, dynamic columns ──
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            // v6.13: Column count from available width, then cap page size to cols × 4
            readonly property int columns: Math.max(1, Math.floor(width / (root.thumbWidth + 8)))
            cellWidth: width / columns
            cellHeight: root.thumbHeight + 32
            clip: true
            // v6.16.2.3.2: Model switches with onlineMode. The local list
            // and the online repo list are mapped to a unified shape
            // {url, path, name, cached?} so the same delegate works.
            model: root.onlineMode
                ? WallpaperRepoService.items.map(it => ({
                      url:  it.cached ? ("file://" + it.localPath)
                                      : it.downloadUrl,
                      path: it.localPath,
                      name: it.name,
                      cached: it.cached,
                      downloadUrl: it.downloadUrl
                  }))
                : WallpaperServiceV5.pagedList

            // v6.13: Push columns × 4 back to service so pagedList slices correctly
            onColumnsChanged: WallpaperServiceV5.wallpapersPerPage = columns * 4
            Component.onCompleted: WallpaperServiceV5.wallpapersPerPage = columns * 4

            delegate: Rectangle {
                required property var modelData
                width: root.thumbWidth
                height: root.thumbHeight + 26
                color: "transparent"

                readonly property bool isCurrent: {
                    const p = modelData.path || ""
                    return p.length > 0 && p === WallpaperServiceV5.currentWallpaper
                }

                Rectangle {
                    id: thumbFrame
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.thumbHeight
                    radius: 10
                    color: Qt.rgba(ThemeService.bg1.r, ThemeService.bg1.g, ThemeService.bg1.b, 0.4)
                    border.width: parent.isCurrent ? 3 : 1
                    border.color: parent.isCurrent
                                  ? ThemeService.blue
                                  : (hoverArea.containsMouse
                                     ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.5)
                                     : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.08))
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: modelData.url || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 360
                        sourceSize.height: 240
                    }

                    // "Current" badge
                    Rectangle {
                        visible: parent.parent.isCurrent
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: currentLbl.implicitWidth + 12
                        height: 20
                        radius: 10
                        color: ThemeService.blue

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            id: currentLbl
                            anchors.centerIn: parent
                            text: "✓ Current"
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.onlineMode) {
                                // v6.16.2.3.2: Online item — download (or
                                // use cached) then apply via WallpaperServiceV5.
                                if (modelData.cached) {
                                    WallpaperServiceV5.selectWallpaper({
                                        path: modelData.path,
                                        url:  "file://" + modelData.path,
                                        name: modelData.name
                                    })
                                } else {
                                    // Find index in repo items + download
                                    const items = WallpaperRepoService.items
                                    let idx = -1
                                    for (let i = 0; i < items.length; i++) {
                                        if (items[i].name === modelData.name) {
                                            idx = i; break
                                        }
                                    }
                                    if (idx >= 0) {
                                        WallpaperRepoService.download(idx, function(localPath) {
                                            if (localPath && localPath.length > 0) {
                                                WallpaperServiceV5.selectWallpaper({
                                                    path: localPath,
                                                    url:  "file://" + localPath,
                                                    name: modelData.name
                                                })
                                            }
                                        })
                                    }
                                }
                            } else {
                                WallpaperServiceV5.selectWallpaper(modelData)
                            }
                        }
                    }
                }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.top: thumbFrame.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 4
                    text: modelData.name || ""
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    color: ThemeService.grey0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            // Empty state — v7.0.0-beta.1-hf96: online-aware. In Online
            // mode the previous text wrongly said "No wallpapers found in
            // <local folder>", masking the real cause (GitHub rate-limit /
            // offline). Now it reflects repo loading/error and points at
            // the refresh button.
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                width: parent.width - 48
                visible: grid.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: {
                    if (root.onlineMode) {
                        if (WallpaperRepoService.loading)
                            return "Loading online wallpapers…"
                        if (WallpaperRepoService.lastError.length > 0)
                            return WallpaperRepoService.lastError
                                 + "\n\nTap the refresh icon to retry."
                        return "No online wallpapers yet.\n"
                             + "Tap the refresh icon to fetch the list."
                    }
                    return WallpaperServiceV5.loading
                         ? "Loading…"
                         : ("No wallpapers found in\n" + WallpaperServiceV5.localFolder)
                }
                color: ThemeService.grey1
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

        // ── Pagination ──
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: 8
                color: prevBtn.containsMouse
                       ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.08)
                       : "transparent"
                border.width: 1
                border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.15)
                opacity: WallpaperServiceV5.currentPage > 0 ? 1.0 : 0.4

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "\u2039  Prev"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    id: prevBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: WallpaperServiceV5.currentPage > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: WallpaperServiceV5.prevPage()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Page " + (WallpaperServiceV5.currentPage + 1) + " / "
                      + WallpaperServiceV5.totalPages
                color: ThemeService.grey0
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: 8
                color: nextBtn.containsMouse
                       ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.08)
                       : "transparent"
                border.width: 1
                border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.15)
                opacity: WallpaperServiceV5.currentPage < WallpaperServiceV5.totalPages - 1 ? 1.0 : 0.4

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "Next  \u203a"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    id: nextBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: WallpaperServiceV5.currentPage < WallpaperServiceV5.totalPages - 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: WallpaperServiceV5.nextPage()
                }
            }
        }
    }

    Component.onCompleted: {
        // Ensure daemon is ready the moment picker opens
        WallpaperServiceV5.startSwwwDaemon()
        // Refresh folder in case it changed from outside
        WallpaperServiceV5.refresh()
    }
}
