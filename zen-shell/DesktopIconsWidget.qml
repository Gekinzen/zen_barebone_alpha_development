import QtQuick
import QtQuick.Layouts
import Quickshell.Io

/*
 * DesktopIconsWidget v7.0.0-beta.1-hf83 — Karui (軽い)
 *
 * Single MOVABLE + RESIZABLE panel that holds every desktop icon in a
 * reflowing grid — the "one widget" alternative to the scattered
 * free-form icons in DesktopSurface.qml. Mounted by DesktopSurface
 * when DesktopIconsState.widgetMode is true.
 *
 * Behavior:
 *   - Drag the title bar  → move the panel (x/y persisted)
 *   - Drag the ◢ handle   → resize the panel (w/h persisted, grid reflows)
 *   - Double-click a tile → launch via DesktopIconsService.open(entry)
 *   - Scroll              → flick the icon grid when it overflows
 *
 * Icon resolution mirrors the TASKBAR exactly — the same staged lookup
 * DesktopIcon.qml uses (hf82x/hf82y):
 *   0. entry.iconAbsPath  (filesystem-resolved abs path from the scan)
 *   1. Icon= absolute path inline
 *   2. theme lookup by resolved iconName
 *   3. match against AppLauncherService.apps (Quickshell.DesktopEntries)
 *      by Name=/id, then a substring pass — catches Steam/Lutris game
 *      launchers whose Icon= is a non-theme name
 *   4. theme lookup by lowercased basename / first word
 *   5. glyph fallback
 * Pulled into one resolveIcon() helper here so the grid delegate stays
 * thin and the logic stays identical to the bar's app icons.
 *
 * Wala tayong babawasan — additive component. The scattered icon path
 * in DesktopSurface is untouched; this panel only shows when the user
 * opts into widgetMode.
 */
Item {
    id: root
    visible: DesktopIconsState.enabled && DesktopIconsState.widgetMode

    // The panel lives at the persisted geometry. Live x/y/w/h are held
    // on the panel Rectangle below and only committed back to the
    // singleton on drag/resize release (so we don't thrash the debounced
    // save on every mouse-move tick).
    anchors.fill: parent

    // ── Shared icon resolver (taskbar parity) ──
    function resolveIcon(entry) {
        if (!entry) return ""
        const n = entry.iconName || entry.icon || ""
        const absPath = entry.iconAbsPath || ""
        const baseRaw = (entry.name || "").replace(/\.desktop$/, "")

        // Stage -1 (v7.0.0-beta.1-hf85): user's custom PNG override wins
        // over everything. Set via right-click → "Set custom icon…".
        const custom = DesktopIconsState.customIcons
            ? DesktopIconsState.customIcons[entry.name] : ""
        if (custom && custom.length > 0) {
            return custom.charAt(0) === "/" ? "file://" + custom : custom
        }

        // Stage 0: filesystem-resolved absolute path from the scan
        if (absPath && absPath.length > 0) return "file://" + absPath
        // Stage 1: absolute path inline in Icon=
        if (n && n.charAt(0) === "/") return "file://" + n
        // Stage 2: theme lookup by resolved name
        if (n && Quickshell.iconPath) {
            const themed = Quickshell.iconPath(n, true)
            if (themed && themed.length > 0) return themed
        }
        // Stage 3: match installed .desktop entries (same source as taskbar)
        if (baseRaw && baseRaw.length > 0 && typeof AppLauncherService !== "undefined") {
            const baseLower = baseRaw.toLowerCase()
            const apps = AppLauncherService.apps || []
            // 3a — exact Name=/id
            for (let i = 0; i < apps.length; i++) {
                const a = apps[i]
                if (!a) continue
                const aName = (a.name || "").toLowerCase()
                const aId = (a.id || "").toLowerCase()
                if (aName === baseLower || aId === baseLower) {
                    if (a.icon && Quickshell.iconPath) {
                        if (a.icon.charAt(0) === "/") return "file://" + a.icon
                        const resolved = Quickshell.iconPath(a.icon, true)
                        if (resolved && resolved.length > 0) return resolved
                    }
                }
            }
            // 3b — substring
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
        // Stage 4: theme by lowercased basename / first word
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
        // Stage 5: glyph fallback handled by the delegate
        return ""
    }

    // ── Custom-icon file picker (v7.0.0-beta.1-hf85) ──
    //
    // Right-click a tile → spawn a desktop file picker (zenity, with
    // kdialog fallback). The chosen image path is saved per-entry via
    // DesktopIconsState.setCustomIcon(). Shift+right-click clears the
    // override instead.
    property string _pickTarget: ""
    function pickIconFor(entryName) {
        _pickTarget = entryName
        iconPicker.running = false
        iconPicker.running = true
    }

    Process {
        id: iconPicker
        running: false
        command: ["bash", "-c",
            "zenity --file-selection " +
            "--title='Pick an icon image' " +
            "--file-filter='Images | *.png *.svg *.jpg *.jpeg *.webp *.ico' " +
            "2>/dev/null || " +
            "kdialog --getopenfilename ~ '*.png *.svg *.jpg *.jpeg *.webp *.ico' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = (this.text || "").trim()
                if (path.length > 0 && root._pickTarget.length > 0) {
                    DesktopIconsState.setCustomIcon(root._pickTarget, path)
                }
                root._pickTarget = ""
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // THE PANEL
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: panel

        x: DesktopIconsState.widgetX
        y: DesktopIconsState.widgetY
        width:  DesktopIconsState.widgetW
        height: DesktopIconsState.widgetH

        // v8.0.0-alpha-hf144 — the desktop panel now follows the Shell Look,
        // like every other surface. hf134 gave it its own widgetLightGlass
        // toggle; that still works as a manual override when the look is not
        // being applied here, but with "Apply to → Desktop icons" on (default)
        // the active look drives it. Glass+ makes it fully clear.
        readonly property bool _followLook:
            (typeof LookService !== "undefined") && DesktopIconsState.lookApplyDesktop
        radius: _followLook ? Math.round(20 * LookService.radiusScale) : 20
        antialiasing: true
        color: _followLook
               ? LookService.panelColor(ThemeService.bg0, LookService.panelOpacity)
               : (DesktopIconsState.widgetLightGlass ? Qt.rgba(1, 1, 1, 0.13)
                                                     : Qt.rgba(0, 0, 0, 0.42))
        border.color: _followLook
               ? (LookService.isClear ? Qt.rgba(1, 1, 1, 0.30)
                                      : ThemeService.alpha(ThemeService.fg, LookService.borderAlpha))
               : (DesktopIconsState.widgetLightGlass ? Qt.rgba(1, 1, 1, 0.26)
                                                     : Qt.rgba(1, 1, 1, 0.12))
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }

        // Clamp into the surface so the panel can't be lost off-screen.
        function _clampInto() {
            if (!root.width || !root.height) return
            if (x < 0) x = 0
            if (y < 0) y = 0
            if (x > root.width  - width)  x = Math.max(0, root.width  - width)
            if (y > root.height - height) y = Math.max(0, root.height - height)
        }
        Component.onCompleted: _clampInto()
        Connections {
            target: root
            function onWidthChanged()  { panel._clampInto() }
            function onHeightChanged() { panel._clampInto() }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ── Title bar (drag handle) ──
            Rectangle {
                id: titleBar
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                topLeftRadius: 19
                topRightRadius: 19
                color: Qt.rgba(1, 1, 1, DesktopIconsState.widgetLightGlass ? 0.10 : 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "\uf07c"   // folder-open glyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: "#cfe3ff"
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: "Desktop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: (DesktopIconsService.entries
                               ? DesktopIconsService.entries.length : 0) + " items"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.6)
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // ══ v8.0.0-alpha-hf134 — THE PANEL SHOOK BECAUSE IT MOVED ══
                //
                // "prang nangingig kasi now hahaha"
                //
                // The old handler was:
                //
                //     onPressed:  _px = m.x;  _ox = panel.x
                //     onMove:     panel.x = _ox + (m.x - _px)
                //
                // `m.x` is LOCAL to this MouseArea, and this MouseArea lives
                // inside `panel`. So the moment you move the panel, the mouse
                // area moves with it and the same cursor position reports a
                // different `m.x`. The handler feeds its own output back in.
                //
                // Solve it and the fixed point is
                //
                //     P = 2·P0 + C − C0 − P     →     P = P0 + (C − C0)/2
                //
                // The panel tracks exactly HALF the cursor, and stalls every
                // other event on the way there. Simulated over ten 20px steps
                // it ends 100px behind. That is the shake.
                //
                // `drag.target` is what DesktopWidgets' clock, weather and
                // system-monitor widgets have used since v6.11e — Qt tracks the
                // cursor in the scene frame, which the panel cannot perturb.
                // The same file's own comment says it: "removed x/y property
                // bindings that fought with drag.target."
                MouseArea {
                    id: moveArea
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: panel
                    drag.axis: Drag.XAndYAxis
                    drag.threshold: 0
                    // Hand the bounds to Qt instead of clamping x/y behind its
                    // back. Qt drives the drag from its own accumulator, so a
                    // clamp written inside onPositionChanged is overwritten on
                    // the next frame and the panel rubber-bands at the edge.
                    drag.minimumX: 0
                    drag.minimumY: 0
                    drag.maximumX: Math.max(0, root.width  - panel.width)
                    drag.maximumY: Math.max(0, root.height - panel.height)
                    onReleased: {
                        panel._clampInto()
                        DesktopIconsState.setWidgetGeometry(
                            panel.x, panel.y, panel.width, panel.height)
                    }
                }
            }

            // ── Icon grid (flickable, reflowing Flow) ──
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: iconFlow.implicitHeight + 20
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: iconFlow
                    x: 10; y: 10
                    width: flick.width - 20
                    spacing: 10

                    Repeater {
                        model: DesktopIconsService.entries || []
                        delegate: Item {
                            id: tile
                            required property var modelData
                            readonly property int cell: DesktopIconsState.widgetIconSize + 28
                            width: cell
                            height: cell + 26

                            readonly property string _src: root.resolveIcon(tile.modelData)

                            Rectangle {
                                id: tileBg
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: DesktopIconsState.widgetIconSize + 16
                                height: DesktopIconsState.widgetIconSize + 16
                                radius: 12
                                color: tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                border.color: tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 110 } }

                                Image {
                                    id: tileImg
                                    anchors.centerIn: parent
                                    width: DesktopIconsState.widgetIconSize
                                    height: DesktopIconsState.widgetIconSize
                                    source: tile._src
                                    sourceSize.width: DesktopIconsState.widgetIconSize
                                    sourceSize.height: DesktopIconsState.widgetIconSize
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: status === Image.Ready
                                }
                                // Glyph fallback (same as DesktopIcon)
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.centerIn: parent
                                    text: tile.modelData.isDir ? "\uf07b" : "\uf15b"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: DesktopIconsState.widgetIconSize * 0.55
                                    color: "#dddddd"
                                    visible: !tileImg.visible
                                }
                            }

                            Text {
                                anchors.top: tileBg.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 4
                                text: tile.modelData.isDesktopFile
                                    ? tile.modelData.name.replace(/\.desktop$/, "")
                                    : tile.modelData.name
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.85)
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onDoubleClicked: DesktopIconsService.open(tile.modelData)
                                onClicked: (m) => {
                                    if (m.button === Qt.RightButton) {
                                        // Shift+right-click clears the override;
                                        // plain right-click opens the picker.
                                        if (m.modifiers & Qt.ShiftModifier) {
                                            DesktopIconsState.clearCustomIcon(tile.modelData.name)
                                        } else {
                                            root.pickIconFor(tile.modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty-state hint inside the panel
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    visible: !DesktopIconsService.entries
                             || DesktopIconsService.entries.length === 0
                    text: "No icons in\n" + DesktopIconsState.scanPath
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                }
            }

            // ── v8.0.0-alpha-hf134 — "Open Folder", from the mockup ──
            //
            // Sits below the grid, hides itself when the panel is too short to
            // hold it. The grid is `fillHeight`, so it simply gives the footer
            // its 52px and keeps the rest.
            Item {
                id: footer
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 52 : 0
                visible: panel.height >= DesktopIconsState.widgetMinH + 40

                Rectangle {
                    id: openBtn
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 230)
                    height: 36
                    radius: 18
                    antialiasing: true
                    color: openMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22)
                                                : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.28)
                    Behavior on color { ColorAnimation { duration: 130 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 9
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "\uf07b"                 // folder
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Open Folder"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: openMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DesktopIconsService.openFolder(DesktopIconsState.scanPath)
                    }
                }
            }
        }

        // ── Resize handle (bottom-right) ──
        Rectangle {
            id: resizeHandle
            width: 18
            height: 18
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            radius: 5
            color: resizeArea.containsMouse || resizeArea.pressed
                   ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: "\uf0b2"   // arrows / resize glyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: "#ffffff"
            }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                anchors.margins: -6   // larger hit area than the visible nub
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                // hf134: the SAME feedback loop as the move handler. This nub is
                // anchored to the panel's bottom-right, so growing the panel
                // moves the nub, which changes `m.x` for an unmoved cursor. The
                // panel resized at half speed and juddered.
                //
                // Measure in the SCENE frame, which nothing here can perturb.
                // `mapToItem` is called per event — not a binding — so it is
                // always fresh, and deltas are identical to the parent frame.
                property real _sx: 0
                property real _sy: 0
                property real _ow: 0
                property real _oh: 0
                onPressed: (m) => {
                    const p = mapToItem(null, m.x, m.y)
                    _sx = p.x; _sy = p.y
                    _ow = panel.width; _oh = panel.height
                }
                onPositionChanged: (m) => {
                    if (!pressed) return
                    const p = mapToItem(null, m.x, m.y)
                    panel.width  = Math.max(DesktopIconsState.widgetMinW, _ow + (p.x - _sx))
                    panel.height = Math.max(DesktopIconsState.widgetMinH, _oh + (p.y - _sy))
                }
                onReleased: {
                    panel._clampInto()
                    DesktopIconsState.setWidgetGeometry(
                        panel.x, panel.y, panel.width, panel.height)
                }
            }
        }
    }
}
