import QtQuick

/*
 * DesktopIcon v7.0.0-beta.1-hf82o — Karui (軽い)
 *
 * Single draggable desktop icon. Renders an icon glyph + label.
 *
 * Drag behavior (Android-style free-form):
 *   - Press-and-hold 350ms OR move 8px → drag engages
 *   - Visual: icon scales up to 1.1× and gets a subtle shadow ring
 *   - Drop: position saved via DesktopIconsState.setIconPosition()
 *
 * Double-click: launch via DesktopIconsService.open(entry).
 *
 * Position: bound to DesktopIconsState.iconPositions[entry.name]
 * if set; otherwise the parent (DesktopSurface) auto-flows it.
 *
 * Wala tayong babawasan — additive component.
 */
Item {
    id: root

    required property var entry        // { name, path, isDir, isDesktopFile, iconName, mimeType }
    property int fallbackX: 0          // used when no saved position OR auto mode
    property int fallbackY: 0

    // hf82r: in "auto" arrange mode, ALWAYS use fallback (auto-flow)
    // positions — saved iconPositions are ignored visually. Drag is
    // visually allowed (user can still slide an icon around) but the
    // position never persists, so on next refresh the icon snaps back
    // to its flowed slot.
    readonly property bool _autoMode: DesktopIconsState.arrangeMode === "auto"

    readonly property bool hasSavedPosition: {
        if (_autoMode) return false
        const pos = DesktopIconsState.iconPositions[entry.name]
        return pos && typeof pos.x === "number" && typeof pos.y === "number"
    }

    x: hasSavedPosition ? DesktopIconsState.iconPositions[entry.name].x : fallbackX
    y: hasSavedPosition ? DesktopIconsState.iconPositions[entry.name].y : fallbackY

    width: DesktopIconsState.effectiveIconSize + 24
    height: DesktopIconsState.effectiveIconSize + (DesktopIconsState.labelAlwaysVisible ? 48 : 12)

    // ── Drag state ──
    property bool _dragging: false
    property real _pressX: 0
    property real _pressY: 0
    property real _grabX: 0
    property real _grabY: 0

    Timer {
        id: holdTimer
        interval: 350
        repeat: false
        onTriggered: root._dragging = true
    }

    // ── Visual ──

    Rectangle {
        id: iconBg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        width: DesktopIconsState.effectiveIconSize
        height: DesktopIconsState.effectiveIconSize
        // hf82w: squircle style → squircle (superellipse approx via larger radius)
        // compact style → smaller corner
        // default → original 12/14
        radius: {
            if (DesktopIconsState.style === "squircle") {
                return DesktopIconsState.effectiveIconSize * 0.28  // squircle-ish
            }
            if (DesktopIconsState.style === "compact") {
                return entry.isDir ? 6 : 8
            }
            return entry.isDir ? 12 : 14
        }
        color: ma.containsMouse
            ? Qt.rgba(1, 1, 1, 0.12)
            : "transparent"
        border.color: ma.containsMouse
            ? Qt.rgba(1, 1, 1, 0.18)
            : "transparent"
        border.width: 1

        scale: root._dragging ? 1.10 : (ma.pressed ? 0.95 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on color { ColorAnimation { duration: 120 } }

        // Drop-shadow ring when dragging
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: parent.radius + 6
            color: "transparent"
            border.color: Qt.rgba(0.4, 0.6, 1.0, 0.45)
            border.width: 2
            visible: root._dragging
        }

        // Icon resolution (hf82x — proper Name → Icon matching via DesktopEntries):
        //   1. Absolute path Icon=/path/foo.png  → use directly
        //   2. entry.iconName via theme  → existing path
        //   3. ★ NEW hf82x ★ Match against AppLauncherService.apps
        //      (which wraps Quickshell.DesktopEntries — same source the
        //      taskbar uses to find icons for running apps). For each
        //      app entry, compare:
        //         - app.name vs file basename (case-insensitive)
        //         - app.id   vs file basename (case-insensitive)
        //      First match wins. Then use app.icon as the theme name.
        //      This is what catches "Surviving Mars" → /usr/share/applications/
        //      net.lutris.surviving-mars.desktop → icon: lutris_surviving-mars
        //   4. Last-ditch: lowercase basename via theme (legacy hf82t path)
        //   5. Empty → fall back to glyph
        readonly property string _iconSource: {
            const n = root.entry.iconName || root.entry.icon || ""
            const absPath = root.entry.iconAbsPath || ""
            const baseRaw = (root.entry.name || "").replace(/\.desktop$/, "")
            // hf82y: debug logging
            console.log("[DesktopIcon] resolving file='" + (root.entry.name || "") +
                "' iconName='" + n + "' iconAbsPath='" + absPath + "'")
            // Stage 0: iconAbsPath set by DesktopIconsService scan (hf82y)
            // This is the FILE-SYSTEM-RESOLVED absolute path. Highest
            // priority because we know the file exists.
            if (absPath && absPath.length > 0) {
                console.log("  → Stage 0 (iconAbsPath): file://" + absPath)
                return "file://" + absPath
            }
            // Stage 1: absolute path inline in Icon= field
            if (n && n.charAt(0) === "/") {
                console.log("  → Stage 1 (absolute): file://" + n)
                return "file://" + n
            }
            // Stage 2: theme by resolved name
            if (n && Quickshell.iconPath) {
                const themed = Quickshell.iconPath(n, true)
                if (themed && themed.length > 0) {
                    console.log("  → Stage 2 (theme by iconName): " + themed)
                    return themed
                }
            }
            // Stage 3: match against installed .desktop entries by Name=
            if (baseRaw && baseRaw.length > 0 && typeof AppLauncherService !== "undefined") {
                const baseLower = baseRaw.toLowerCase()
                const apps = AppLauncherService.apps || []
                for (let i = 0; i < apps.length; i++) {
                    const a = apps[i]
                    if (!a) continue
                    const aName = (a.name || "").toLowerCase()
                    const aId = (a.id || "").toLowerCase()
                    if (aName === baseLower || aId === baseLower) {
                        if (a.icon && Quickshell.iconPath) {
                            if (a.icon.charAt(0) === "/") return "file://" + a.icon
                            const resolved = Quickshell.iconPath(a.icon, true)
                            if (resolved && resolved.length > 0) {
                                console.log("  → Stage 3 MATCH: " + resolved)
                                return resolved
                            }
                        }
                    }
                }
                // Stage 3b: substring match
                for (let i = 0; i < apps.length; i++) {
                    const a = apps[i]
                    if (!a || !a.name || a.name.length < 5) continue
                    const aName = (a.name || "").toLowerCase()
                    if (baseLower.indexOf(aName) >= 0 || aName.indexOf(baseLower) >= 0) {
                        if (a.icon && Quickshell.iconPath) {
                            if (a.icon.charAt(0) === "/") return "file://" + a.icon
                            const resolved = Quickshell.iconPath(a.icon, true)
                            if (resolved && resolved.length > 0) return resolved
                        }
                    }
                }
            }
            // Stage 4: theme by lowercased basename
            if (Quickshell.iconPath && baseRaw) {
                const lower = baseRaw.toLowerCase()
                const byLower = Quickshell.iconPath(lower, true)
                if (byLower && byLower.length > 0) return byLower
                const firstWord = lower.split(/[\s\-_]/)[0]
                if (firstWord && firstWord !== lower) {
                    const byFirst = Quickshell.iconPath(firstWord, true)
                    if (byFirst && byFirst.length > 0) return byFirst
                }
            }
            console.log("  → NO ICON FOUND for '" + (root.entry.name || "") + "', glyph fallback")
            return ""
        }

        Image {
            id: iconImg
            anchors.fill: parent
            anchors.margins: 8
            source: iconBg._iconSource
            sourceSize.width: DesktopIconsState.effectiveIconSize - 16
            sourceSize.height: DesktopIconsState.effectiveIconSize - 16
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: status === Image.Ready
        }

        // Fallback glyph if icon-theme lookup failed (icon not in
        // theme + not an absolute path, or path doesn't exist)
        Text {
            anchors.centerIn: parent
            text: root.entry.isDir ? "\uf07b" : "\uf15b"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: DesktopIconsState.effectiveIconSize * 0.55
            color: "#dddddd"
            visible: !iconImg.visible
        }
    }

    // ── Label ──
    Text {
        // hf82w: visible always in default/squircle, hover-only in compact mode
        visible: DesktopIconsState.labelAlwaysVisible || ma.containsMouse
        opacity: DesktopIconsState.labelAlwaysVisible ? 1.0 : (ma.containsMouse ? 1.0 : 0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
        anchors.top: iconBg.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 8
        text: root.entry.isDesktopFile
            ? root.entry.name.replace(/\.desktop$/, "")
            : root.entry.name
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.pixelSize: 11
        font.bold: true
        // Auto-detect label color: assume dark wallpaper → light text.
        // Future: sample wallpaper pixel under the label.
        color: DesktopIconsState.labelColor === "auto"
            ? "#ffffff"
            : (DesktopIconsState.labelColor === "dark"
               ? "#000000"
               : (DesktopIconsState.labelColor === "light"
                  ? "#ffffff"
                  : DesktopIconsState.labelColor))
        // Text shadow for legibility on busy wallpapers
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.85)
    }

    // ── Mouse handling: drag + double-click to open ──
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root._dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: (mouse) => {
            root._pressX = mouse.x
            root._pressY = mouse.y
            root._grabX = root.x
            root._grabY = root.y
            holdTimer.restart()
        }
        onReleased: {
            holdTimer.stop()
            if (root._dragging) {
                // hf82w: squircle-style drop-to-folder gesture.
                // When squircle style is active, check if this icon's center
                // overlaps another icon's bounds. If yes → create a folder.
                let didMerge = false
                if (DesktopIconsState.style === "squircle" && root.parent) {
                    const myCenterX = root.x + root.width / 2
                    const myCenterY = root.y + root.height / 2
                    // Iterate sibling icons (DesktopIcon instances) on the same parent
                    const siblings = root.parent.children
                    for (let i = 0; i < siblings.length; i++) {
                        const s = siblings[i]
                        if (!s || s === root) continue
                        // Only test against entries with a 'name' (icons) — skip folders
                        // (folder drop would mean "add to folder" but we handle that
                        //  separately by checking modelData.members below)
                        if (!s.entry || !s.entry.name) continue
                        // Bounds-overlap test
                        if (myCenterX >= s.x && myCenterX <= s.x + s.width &&
                            myCenterY >= s.y && myCenterY <= s.y + s.height) {
                            // Create folder from these two icons
                            DesktopFoldersState.createFolder(
                                root.entry.name, s.entry.name, s.x, s.y)
                            didMerge = true
                            break
                        }
                    }
                }
                if (!didMerge) {
                    if (!root._autoMode) {
                        DesktopIconsState.setIconPosition(root.entry.name, root.x, root.y)
                        // ^ setIconPosition handles grid snap internally
                        //   when arrangeMode === "grid"
                    } else {
                        // Snap back to fallback (auto-flow) position
                        root.x = root.fallbackX
                        root.y = root.fallbackY
                    }
                }
                root._dragging = false
            }
        }
        onPositionChanged: (mouse) => {
            if (ma.pressed) {
                const dx = mouse.x - root._pressX
                const dy = mouse.y - root._pressY
                if (!root._dragging && Math.sqrt(dx*dx + dy*dy) > 8) {
                    root._dragging = true
                    holdTimer.stop()
                }
                if (root._dragging) {
                    root.x = root._grabX + dx
                    root.y = root._grabY + dy
                    // Clamp inside parent bounds with small margin
                    if (root.parent) {
                        if (root.x < 0) root.x = 0
                        if (root.y < 0) root.y = 0
                        const maxX = root.parent.width - root.width
                        const maxY = root.parent.height - root.height
                        if (root.x > maxX) root.x = maxX
                        if (root.y > maxY) root.y = maxY
                    }
                }
            }
        }
        onDoubleClicked: {
            if (!root._dragging) {
                DesktopIconsService.open(root.entry)
            }
        }
    }
}
