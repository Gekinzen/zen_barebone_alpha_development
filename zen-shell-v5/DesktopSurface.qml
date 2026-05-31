import QtQuick

/*
 * DesktopSurface v7.0.0-beta.1-hf82r — Karui (軽い)
 *
 * Renders desktop file/folder icons from DesktopIconsService.entries
 * as DesktopIcon instances. Mounted as sibling of DesktopWidgets +
 * DesktopStickyNotes in the existing widgetWindow.
 *
 * hf82r additions:
 *   - Collision-aware auto-flow: skips cells whose bounding box would
 *     overlap any DesktopIconsState.collisionRegions entry. Widgets
 *     (clock, weather, sysmon) self-register their regions so icons
 *     don't get placed on top of them.
 *   - Auto-arrange mode: when arrangeMode === "auto", ALL icons use
 *     flow positions (saved positions ignored, drag visually allowed
 *     but doesn't persist).
 *   - Grid mode: drag still works, but drops snap to gridSize.
 *
 * Wala tayong babawasan — existing widget layers untouched.
 */
Item {
    id: surface

    // Padding from screen edges for the icon auto-flow
    readonly property int padLeft: 60
    readonly property int padTop: 60

    visible: DesktopIconsState.enabled

    // ── Collision-aware flow ──
    //
    // Walks (col, row) cells top-to-bottom, left-to-right, returning
    // the first cell whose bounding box does NOT intersect any
    // collisionRegion. `index` is just for stable per-icon assignment
    // when the entry list grows/shrinks (newly added entries don't
    // shuffle existing ones).
    function _flowPosition(index) {
        const cellW = DesktopIconsState.iconSize + 24 + 16   // iconSize + label horiz pad + spacing
        const cellH = DesktopIconsState.iconSize + 48 + 16   // iconSize + label space + spacing
        const rowsPerCol = Math.max(1, Math.floor((height - padTop * 2) / cellH))

        // Find the Nth "free" cell — accounting for collisions.
        // We walk in column-major order so icons fill left-to-right.
        let cellsSeen = 0
        const maxCols = Math.max(1, Math.floor((width - padLeft * 2) / cellW))
        for (let col = 0; col < maxCols; col++) {
            for (let row = 0; row < rowsPerCol; row++) {
                const cx = padLeft + col * cellW
                const cy = padTop + row * cellH
                // Skip if this cell overlaps a collision region
                if (DesktopIconsState.rectIntersectsCollision &&
                    DesktopIconsState.rectIntersectsCollision(cx, cy, cellW, cellH)) {
                    continue
                }
                if (cellsSeen === index) {
                    return { "x": cx, "y": cy }
                }
                cellsSeen++
            }
        }
        // Fell off the grid — wrap around to bottom-right area
        return { "x": padLeft, "y": padTop }
    }

    // hf82w: Filter regular icons so folder members are HIDDEN from the
    // main desktop (they show inside the folder popup instead). Only
    // applies in squircle style; default/pixel show all icons.
    readonly property var visibleEntries: {
        const all = DesktopIconsService.entries || []
        if (DesktopIconsState.style !== "squircle") return all
        // Filter out entries that are members of any folder
        const out = []
        for (let i = 0; i < all.length; i++) {
            const e = all[i]
            const f = DesktopFoldersState.folderForMember
                ? DesktopFoldersState.folderForMember(e.name) : null
            if (!f) out.push(e)
        }
        return out
    }

    // ── Icons layer ──
    //
    // v7.0.0-beta.1-hf83: the scattered free-form icons only render in
    // the classic (non-widget) mode. When DesktopIconsState.widgetMode
    // is on, the single DesktopIconsWidget panel below takes over.
    Repeater {
        id: iconRepeater
        model: DesktopIconsState.widgetMode ? [] : surface.visibleEntries
        delegate: DesktopIcon {
            id: iconDel
            required property var modelData
            required property int index
            entry: modelData

            // Compute the auto-flow fallback once per delegate. The
            // DesktopIcon uses this when DesktopIconsState has no
            // saved position for this entry — OR when arrangeMode is
            // "auto" (in which case fallback always wins).
            readonly property var _flowPos: surface._flowPosition(index)
            fallbackX: _flowPos.x
            fallbackY: _flowPos.y
        }
    }

    // hf82w: Folder icons layer (squircle style only)
    Repeater {
        id: folderRepeater
        model: (!DesktopIconsState.widgetMode && DesktopIconsState.style === "squircle")
            ? (DesktopFoldersState.folders || [])
            : []
        delegate: Rectangle {
            id: folderIcon
            required property var modelData
            required property int index
            // Position: use stored x/y or flow into available slot
            x: modelData.x || (surface._flowPosition(
                surface.visibleEntries.length + index).x)
            y: modelData.y || (surface._flowPosition(
                surface.visibleEntries.length + index).y)
            width: DesktopIconsState.effectiveIconSize + 24
            height: DesktopIconsState.effectiveIconSize +
                (DesktopIconsState.labelAlwaysVisible ? 48 : 12)
            color: "transparent"

            Rectangle {
                id: folderBg
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: DesktopIconsState.effectiveIconSize
                height: DesktopIconsState.effectiveIconSize
                radius: DesktopIconsState.effectiveIconSize * 0.28  // squircle
                color: folderMa.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.18)
                    : Qt.rgba(1, 1, 1, 0.10)
                border.color: Qt.rgba(1, 1, 1, 0.20)
                border.width: 1

                // 2×2 grid of mini-thumbnails of first 4 members
                Grid {
                    anchors.centerIn: parent
                    rows: 2; columns: 2
                    spacing: 4
                    Repeater {
                        model: Math.min(4, (folderIcon.modelData.members || []).length)
                        delegate: Image {
                            required property int index
                            width: (DesktopIconsState.effectiveIconSize - 16) / 2
                            height: (DesktopIconsState.effectiveIconSize - 16) / 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: {
                                const memberName = folderIcon.modelData.members[index]
                                if (!memberName || !Quickshell.iconPath) return ""
                                // Try name-based icon-theme lookup (taskbar pattern)
                                const lower = memberName.replace(/\.desktop$/, "").toLowerCase()
                                return Quickshell.iconPath(lower, true)
                                    || Quickshell.iconPath("application-x-executable")
                                    || ""
                            }
                        }
                    }
                }

                MouseArea {
                    id: folderMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        folderPopup.folderId = folderIcon.modelData.id
                        folderPopup.open()
                    }
                }
            }

            // Label
            Text {
                anchors.top: folderBg.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: folderIcon.modelData.name || "Folder"
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: 11
                font.bold: true
                color: "#ffffff"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.85)
                visible: DesktopIconsState.labelAlwaysVisible
            }
        }
    }

    // hf82w: Squircle folder popup (one shared instance, opened by any folder)
    DesktopFolderPopup {
        id: folderPopup
    }

    // ── Empty-state hint shows only when ENABLED but no entries ──
    Rectangle {
        anchors.centerIn: parent
        width: hint.implicitWidth + 32
        height: hint.implicitHeight + 24
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: DesktopIconsState.enabled
              && !DesktopIconsState.widgetMode
              && DesktopIconsService.entries.length === 0
        Text {
            id: hint
            anchors.centerIn: parent
            text: "Desktop icons enabled but " + DesktopIconsState.scanPath +
                  " is empty.\nDrop files there to see them here."
            color: "white"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── Single-widget mode (v7.0.0-beta.1-hf83) ──
    //
    // One movable + resizable panel holding all icons in a reflowing
    // grid. Self-gates on DesktopIconsState.widgetMode, so it's inert
    // (visible:false) in the classic scattered mode above.
    DesktopIconsWidget {
        anchors.fill: parent
    }
}
