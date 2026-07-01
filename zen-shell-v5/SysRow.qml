import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * SysRow v7.0.0-beta.1-hf95.4 — Waybar-style expandable system tray
 *
 * v7.0.0-beta.1-hf95.3: click-to-expand is now STICKY. Clicking the
 *   arrow pins the cluster open; moving the mouse away no longer
 *   auto-collapses it. Click the arrow again to collapse + unpin. The
 *   configurable hover auto-collapse is kept for non-pinned expansion.
 *
 * SysRow v6.16.0 — earlier history
 *
 * v6.16.0: + Battery icon. Double-gated: shows only when
 *   SystemMonitorService.batteryPresent === true AND
 *   SysRowState.showBattery === true. On desktops, batteryPresent
 *   is false so the toggle has no visible effect (graceful).
 *   Click opens Control Panel (has the Power Profile section).
 *
 * Exact waybar icon mapping:
 *   CPU:    \uf2db (U+F2DB) → "format": " {icon}"
 *   RAM:    \uefc5 (U+F538) → "format": " {icon}"
 *   Temp:   \uf2c9 (U+F2C9) → "format": " {icon}"
 *   Sound:  \uf028 (U+F028) → "format": " {icon}"
 *   Network: 󰤯󰤟󰤢󰤥󰤨 (5-tier signal) / 󰈀 (ethernet) / 󰤮 (disconnected)
 *   BT:     \uf293 (U+F293) →  /  disabled /  connected
 *   Battery (v6.16.0): \uf240..\uf244 (5 levels) + \uf0e7 bolt charging
 *
 * Bar-graph glyphs: ▁▂▃▄▅▆▇█ (same as waybar format-icons)
 *
 * State-driven via SysRowState singleton:
 *   - Per-module visibility toggles
 *   - Display mode: "icon" (icon + bargraph) or "text" (icon + value text)
 *   - Custom per-module colors (empty = theme-reactive auto)
 *   - Collapse delay configurable
 *   - Theme changes → colors update live
 *
 * Click actions (toggle pattern from Zen Alpha scripts):
 *   Sound   → pavucontrol (toggle kill/launch)
 *   CPU/RAM → alacritty -e btm (toggle)
 *   Temp    → alacritty -e btm (toggle)
 *   Network → alacritty -e nmtui (toggle)
 *   BT      → blueman-manager (toggle)
 */
Item {
    id: sysRoot

    // v7.0.0-beta.1-hf84: scale main-row glyphs with the bar when
    // Fit-contents is on (1.0 otherwise). Popup/tooltip internals are
    // intentionally left at their fixed sizes.
    readonly property real _fit: (typeof Theme !== "undefined" && Theme.barContentScale)
                                 ? Theme.barContentScale : 1.0

    // v7.0.0-beta.1-hf93: explicit vertical mode (end-4 style). On a
    // vertical bar the icon cluster stacks in a COLUMN and the expand
    // arrow points up/down instead of left/right. Default false →
    // original horizontal behavior, byte-identical.
    property bool zenVertical: false

    // v7.0.0-beta.1-hf95: cap the vertical expanded height. Uncapped, an
    // expanded SysRow column grew tall enough to push neighbouring bar
    // modules (the clock!) off the bar.
    //
    // v7.0.0-beta.1-hf95.3: instead of CLIPPING the cluster to the cap
    // (which cut off the bottom icons — "putol"), we now SCALE the whole
    // cluster down to fit the cap when it would overflow. Every module
    // (CPU / RAM / volume / …) stays fully visible — just slightly
    // smaller when there are many — and the bar is still never pushed
    // around. When the cluster already fits, scale stays 1.0 (no change).
    readonly property int vMaxExpandedH: 260
    readonly property real _vContentH: mainRow.implicitHeight + 8
    readonly property real _vFitScale: (zenVertical && expanded && _vContentH > vMaxExpandedH)
                                       ? (vMaxExpandedH / _vContentH)
                                       : 1.0
    implicitWidth: zenVertical
        ? Math.round(Theme.moduleHeight)
        : (expanded ? mainRow.implicitWidth + 8 : arrowBtn.width + 4)
    implicitHeight: zenVertical
        ? (expanded ? Math.min(mainRow.implicitHeight + 8, vMaxExpandedH) : arrowBtn.height + 4)
        : Math.round(Theme.moduleHeight)   // v7.0.0-beta.1-hf88: uniform module height
    // hf95.3: no clipping — the scale-to-fit above keeps everything inside
    // the band, so nothing needs to be cut off.
    clip: false

    property bool expanded: false
    property bool hovered: false
    // v7.0.0-beta.1-hf95.3: when the user EXPLICITLY expands the cluster
    // by clicking the arrow, pin it open. While pinned, moving the mouse
    // away must NOT auto-collapse it (the old behaviour closed it the
    // moment the pointer left, which felt broken). Clicking the arrow
    // again collapses and unpins. The configurable hover auto-collapse is
    // preserved for any non-pinned expansion. Wala tayong babawasan.
    property bool pinned: false

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // ── Bar-graph glyphs (waybar format-icons) ──
    readonly property var barGlyphs: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    function barGlyph(pct) {
        const clamped = Math.min(100, Math.max(0, pct))
        const idx = Math.min(7, Math.floor(clamped / 12.5))
        return barGlyphs[idx]
    }

    // ── WiFi signal icons (waybar network format-icons.wifi) ──
    function wifiGlyph(signal) {
        if (signal >= 80) return "󰤨"
        if (signal >= 60) return "󰤥"
        if (signal >= 40) return "󰤢"
        if (signal >= 20) return "󰤟"
        return "󰤯"
    }

    // ── Format helpers for icon vs text mode ──
    function fmtModule(icon, glyph, textVal) {
        if (SysRowState.displayMode === "text") return icon + " " + textVal
        return icon + " " + glyph
    }

    // ── Auto-collapse timer ──
    Timer {
        id: collapseTimer
        interval: SysRowState.collapseDelay
        onTriggered: {
            if (!sysRoot.hovered && !sysRoot.pinned) sysRoot.expanded = false
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
            sysRoot.hovered = containsMouse
            if (!containsMouse && !sysRoot.pinned) collapseTimer.restart()
            else collapseTimer.stop()
        }
    }

    // v7.0.0-beta.1-hf94.2: GridLayout flips orientation. Vertical → 1
    // column (icons stack). Horizontal → columns = the actual child
    // count so every child sits on ONE row (identical to the original
    // RowLayout). NOTE: do NOT use a giant constant like 999 here — Qt's
    // GridLayout pre-allocates internal structures per column and a huge
    // count can crash the scene graph. visibleChildren.length is the
    // real, small child count.
    GridLayout {
        id: mainRow
        anchors.verticalCenter: sysRoot.zenVertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: sysRoot.zenVertical ? parent.horizontalCenter : undefined
        anchors.left: sysRoot.zenVertical ? undefined : parent.left
        anchors.top: sysRoot.zenVertical ? parent.top : undefined
        // hf95.3: shrink-to-fit when the vertical expanded column would
        // overflow the cap, so every icon stays visible (not clipped).
        // Item.Top origin keeps it centered horizontally and pinned at the
        // top edge while scaling. 1.0 in every other case → no change.
        scale: sysRoot._vFitScale
        transformOrigin: Item.Top
        columns: sysRoot.zenVertical ? 1 : 32
        rowSpacing: 2
        columnSpacing: 2

        // v7.0.0-alpha.7: Memory pressure badge — only visible when
        // free RAM < ZenCleanupService.freeRamThreshold. Collapses
        // to zero width when memory is healthy, so SysRow stays
        // compact during normal operation.
        MemoryPressureBadge {}

        // ═══════════════════════════════════════════════
        // EXPAND ARROW — ❮ collapsed / ❯ expanded
        //
        // v7.0.0-beta.1-hf9: restyled to match the Taskbar overflow
        // chevrons (filled pill, theme-reactive colors). User wanted
        // a unified look across the bar — same chevron treatment in
        // taskbar AND sysrow. Also switched to ThemeService bindings
        // so live theme changes repaint the chevron immediately.
        // ═══════════════════════════════════════════════
        Rectangle {
            id: arrowBtn
            Layout.preferredWidth: 24
            Layout.preferredHeight: 32
            radius: 8
            color: arrowMouse.containsMouse
                   ? ThemeService.bg3
                   : ThemeService.alpha(ThemeService.bg2, 0.85)
            Behavior on color { ColorAnimation { duration: 160 } }

            Text {
                anchors.centerIn: parent
                // v7.0.0-beta.1-hf94.5: vertical arrow — ▲ when collapsed
                // (points up toward the cluster), ▼ when expanded (points
                // down, the direction the icons grow). Horizontal keeps the
                // configured left/right arrows.
                text: sysRoot.zenVertical
                      ? (sysRoot.expanded ? "\u25BC" : "\u25B2")
                      : (sysRoot.expanded ? SysRowState.arrowExpanded : SysRowState.arrowCollapsed)
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(14 * sysRoot._fit)
                font.bold: true
                color: ThemeService.fg
            }

            MouseArea {
                id: arrowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sysRoot.expanded = !sysRoot.expanded
                    sysRoot.pinned = sysRoot.expanded   // hf95.3: pin open when user expands; unpin when they collapse
                    if (sysRoot.expanded) collapseTimer.stop()
                }
            }
        }

        // ═══════════════════════════════════════════════
        // SOUND —  (U+F028) + bar glyph
        //
        // v7.0.0-beta.1-hf15: complete rewrite of the sound slot.
        //
        // Previous version (hf10) wrapped SysRowIcon inside an Item with
        // a sibling WheelHandler. Problem: SysRowIcon has its own internal
        // MouseArea (iconMouse) which consumed click + hover events
        // before they could reach the wrapper's WheelHandler. End result:
        // scroll didn't work AND click sometimes didn't toggle.
        //
        // New design: self-contained Rectangle widget with its OWN
        // MouseArea that handles wheel + click in one place. No nested
        // event-eating components.
        //
        // Plus: popup now includes BOTH speaker AND mic sliders with
        // quick-settings-style layout (icon + label + slider + %).
        // ═══════════════════════════════════════════════
        Rectangle {
            id: soundSlot
            visible: sysRoot.expanded && SysRowState.showSound
            opacity: sysRoot.expanded ? 1 : 0
            Layout.preferredWidth: soundLabel.implicitWidth + 12
            Layout.preferredHeight: 28
            implicitWidth: soundLabel.implicitWidth + 12
            implicitHeight: 28
            radius: 6
            color: soundMa.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.08)
                   : "transparent"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            // Icon + percentage label, matching SysRowIcon visual style
            Text {
                id: soundLabel
                anchors.centerIn: parent
                text: ConnectivityService.audioMuted
                      ? "\uf026"
                      : sysRoot.fmtModule(
                            "\uf028",
                            sysRoot.barGlyph(Math.min(100, ConnectivityService.audioVolume)),
                            ConnectivityService.audioVolume + "%"
                        )
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(14 * sysRoot._fit)
                color: SysRowState.resolveColor(
                    SysRowState.soundColor,
                    ConnectivityService.audioMuted ? ThemeService.grey2 : ThemeService.aqua
                )
            }

            // Single MouseArea handles BOTH click (toggle popup) AND
            // wheel (adjust volume). No nested event-eating components.
            MouseArea {
                id: soundMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        // Right-click → toggle mute (convenience)
                        ConnectivityService.toggleMute()
                    } else {
                        volPopup.visible = !volPopup.visible
                    }
                }
                onWheel: function(wheel) {
                    const step = 5
                    const cur = ConnectivityService.audioVolume
                    const next = wheel.angleDelta.y > 0
                                 ? Math.min(100, cur + step)
                                 : Math.max(0, cur - step)
                    ConnectivityService.setVolume(next)
                    wheel.accepted = true
                }
            }

            // ── Tooltip on hover (when popup is closed) ──
            PopupWindow {
                id: soundTip
                anchor.item: soundSlot
                anchor.edges: PanelState.popupAnchorEdges
                anchor.gravity: PanelState.popupAnchorGravity
                visible: soundMa.containsMouse && !volPopup.visible
                implicitWidth: Math.max(tipColSound.implicitWidth + 24, 140)
                implicitHeight: tipColSound.implicitHeight + 16
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g,
                                   ThemeService.bg0.b, 0.95)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                    Column {
                        id: tipColSound
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: "Audio"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }
                        Text {
                            text: (ConnectivityService.audioMuted
                                   ? "Muted"
                                   : ("Volume: " + ConnectivityService.audioVolume + "%"))
                                  + "\nDevice: " + ConnectivityService.audioSinkName
                                  + "\n• Click for slider\n• Scroll to adjust\n• Right-click to mute"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.alpha(ThemeService.fg, 0.7)
                        }
                    }
                }
            }

            // ── Volume slider popup (speaker + mic) ──
            //
            // Quick-Settings-style layout: each row is icon + label +
            // slider + %. Click anywhere on track to set. Drag the knob
            // to scrub. Scroll on either slider adjusts that one.
            PopupWindow {
                id: volPopup
                anchor.item: soundSlot
                anchor.edges: PanelState.popupAnchorEdges
                anchor.gravity: PanelState.popupAnchorGravity
                visible: false
                implicitWidth: 320
                implicitHeight: 160
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g,
                                   ThemeService.bg0.b, 0.96)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // ── Speaker row ──
                        Item {
                            width: parent.width
                            height: 56

                            // Icon box
                            Rectangle {
                                id: spkIconBox
                                width: 32; height: 32; radius: 8
                                color: spkMuteMa.containsMouse
                                       ? ThemeService.bg3
                                       : ThemeService.alpha(ThemeService.bg2, 0.7)
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: ConnectivityService.audioMuted ? "\uf026" : "\uf028"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                    color: ConnectivityService.audioMuted
                                           ? ThemeService.grey2
                                           : ThemeService.aqua
                                }
                                MouseArea {
                                    id: spkMuteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.toggleMute()
                                }
                            }

                            // Right column: label + slider
                            Column {
                                anchors.left: spkIconBox.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Row {
                                    width: parent.width
                                    Text {
                                        text: "Speaker"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: ThemeService.fg
                                        width: parent.width - spkPctText.width
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: spkPctText
                                        text: ConnectivityService.audioVolume + "%"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: ConnectivityService.audioMuted
                                               ? ThemeService.grey2
                                               : ThemeService.fg
                                    }
                                }

                                // Custom slider (matches Quick Settings style)
                                Item {
                                    id: spkSliderTrack
                                    width: parent.width
                                    height: 16
                                    readonly property real ratio:
                                        Math.max(0, Math.min(1,
                                            ConnectivityService.audioVolume / 100))

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width; height: 4; radius: 2
                                        color: ThemeService.alpha(ThemeService.fg, 0.15)
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * spkSliderTrack.ratio
                                        height: 4; radius: 2
                                        color: ConnectivityService.audioMuted
                                               ? ThemeService.grey2
                                               : ThemeService.blue
                                        Behavior on width { NumberAnimation { duration: 80 } }
                                    }
                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        y: (parent.height - height) / 2
                                        x: Math.max(0, parent.width * spkSliderTrack.ratio - width / 2)
                                        color: ThemeService.fg
                                        border.width: 1
                                        border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                                        Behavior on x { NumberAnimation { duration: 80 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        preventStealing: true
                                        function _set(x) {
                                            const r = Math.max(0, Math.min(1, x / width))
                                            ConnectivityService.setVolume(Math.round(r * 100))
                                        }
                                        onPressed: function(m) { _set(m.x) }
                                        onPositionChanged: function(m) {
                                            if (pressed) _set(m.x)
                                        }
                                        onWheel: function(w) {
                                            const cur = ConnectivityService.audioVolume
                                            const next = w.angleDelta.y > 0
                                                         ? Math.min(100, cur + 5)
                                                         : Math.max(0, cur - 5)
                                            ConnectivityService.setVolume(next)
                                            w.accepted = true
                                        }
                                    }
                                }
                            }
                        }

                        // ── Mic row ──
                        Item {
                            width: parent.width
                            height: 56

                            Rectangle {
                                id: micIconBox
                                width: 32; height: 32; radius: 8
                                color: micMuteMa.containsMouse
                                       ? ThemeService.bg3
                                       : ThemeService.alpha(ThemeService.bg2, 0.7)
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Text {
                                    anchors.centerIn: parent
                                    // \uf131 = mic, \uf131 with slash variant for mute
                                    text: ConnectivityService.micMuted ? "\udb80\ude36" : "\uf130"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                    color: ConnectivityService.micMuted
                                           ? ThemeService.grey2
                                           : ThemeService.purple
                                }
                                MouseArea {
                                    id: micMuteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.toggleMicMute()
                                }
                            }

                            Column {
                                anchors.left: micIconBox.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Row {
                                    width: parent.width
                                    Text {
                                        text: "Microphone"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: ThemeService.fg
                                        width: parent.width - micPctText.width
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: micPctText
                                        text: ConnectivityService.micVolume + "%"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: ConnectivityService.micMuted
                                               ? ThemeService.grey2
                                               : ThemeService.fg
                                    }
                                }

                                Item {
                                    id: micSliderTrack
                                    width: parent.width
                                    height: 16
                                    readonly property real ratio:
                                        Math.max(0, Math.min(1,
                                            ConnectivityService.micVolume / 100))

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width; height: 4; radius: 2
                                        color: ThemeService.alpha(ThemeService.fg, 0.15)
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * micSliderTrack.ratio
                                        height: 4; radius: 2
                                        color: ConnectivityService.micMuted
                                               ? ThemeService.grey2
                                               : ThemeService.purple
                                        Behavior on width { NumberAnimation { duration: 80 } }
                                    }
                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        y: (parent.height - height) / 2
                                        x: Math.max(0, parent.width * micSliderTrack.ratio - width / 2)
                                        color: ThemeService.fg
                                        border.width: 1
                                        border.color: ThemeService.alpha(ThemeService.bg0, 0.4)
                                        Behavior on x { NumberAnimation { duration: 80 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        preventStealing: true
                                        function _set(x) {
                                            const r = Math.max(0, Math.min(1, x / width))
                                            ConnectivityService.setMicVolume(Math.round(r * 100))
                                        }
                                        onPressed: function(m) { _set(m.x) }
                                        onPositionChanged: function(m) {
                                            if (pressed) _set(m.x)
                                        }
                                        onWheel: function(w) {
                                            const cur = ConnectivityService.micVolume
                                            const next = w.angleDelta.y > 0
                                                         ? Math.min(100, cur + 5)
                                                         : Math.max(0, cur - 5)
                                            ConnectivityService.setMicVolume(next)
                                            w.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // CPU —  (U+F2DB) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showCpu
            opacity: sysRoot.expanded ? 1 : 0
            icon: sysRoot.fmtModule(
                "\uf2db",
                sysRoot.barGlyph(SystemMonitorService.cpuPercent),
                SystemMonitorService.cpuPercent + "%"
            )
            tipTitle: SystemMonitorService.cpuName
            tipDetail: "CPU Status:\n" + SystemMonitorService.cpuPercent + "% Used"
                       + (SystemMonitorService.cpuTemp > 0
                          ? "\nTemp: " + SystemMonitorService.cpuTemp + "°C" : "")
            iconColor: SysRowState.resolveColor(
                SysRowState.cpuColor,
                ThemeService.blue
            )
            onClicked: {
                btmProc.command = ["bash", "-c",
                    "if pgrep -x btm >/dev/null; then pkill -x btm; pkill -f 'alacritty.*btm'; " +
                    "else alacritty --title btmWindow -e btm & fi"]
                btmProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // RAM —  (U+F538) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showRam
            opacity: sysRoot.expanded ? 1 : 0
            icon: sysRoot.fmtModule(
                "\uefc5",
                sysRoot.barGlyph(SystemMonitorService.ramPercent),
                SystemMonitorService.ramUsedGb.toFixed(1) + "G"
            )
            tipTitle: "Memory"
            tipDetail: "Memory:\n" + SystemMonitorService.ramUsedGb.toFixed(1) + "G / " +
                       SystemMonitorService.ramTotalGb.toFixed(0) + "G\n" +
                       SystemMonitorService.ramPercent + "% Used"
            iconColor: SysRowState.resolveColor(
                SysRowState.ramColor,
                ThemeService.green
            )
            onClicked: {
                btmProc.command = ["bash", "-c",
                    "if pgrep -x btm >/dev/null; then pkill -x btm; pkill -f 'alacritty.*btm'; " +
                    "else alacritty --title btmWindow -e btm & fi"]
                btmProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // TEMPERATURE —  (U+F2C9) + bar glyph
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showTemp && SystemMonitorService.cpuTemp > 0
            opacity: sysRoot.expanded ? 1 : 0
            icon: sysRoot.fmtModule(
                "\uf2c9",
                sysRoot.barGlyph(Math.min(100, SystemMonitorService.cpuTemp)),
                SystemMonitorService.cpuTemp + "°"
            )
            tipTitle: "Temperature"
            tipDetail: "Temperature: " + SystemMonitorService.cpuTemp + "°C"
                       + (SystemMonitorService.gpuTemp > 0
                          ? "\nGPU: " + SystemMonitorService.gpuTemp + "°C" : "")
            iconColor: SysRowState.resolveColor(
                SysRowState.tempColor,
                ThemeService.orange
            )
            onClicked: {
                btmProc.command = ["bash", "-c",
                    "if pgrep -x btm >/dev/null; then pkill -x btm; pkill -f 'alacritty.*btm'; " +
                    "else alacritty --title btmWindow -e btm & fi"]
                btmProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // NETWORK — 󰤯󰤟󰤢󰤥󰤨 (WiFi) / 󰈀 (Ethernet) / 󰤮 (disconnected)
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showNetwork
            opacity: sysRoot.expanded ? 1 : 0
            icon: {
                if (ConnectivityService.wifiConnected)
                    return " " + sysRoot.wifiGlyph(ConnectivityService.wifiSignal) + " "
                if (ConnectivityService.lanConnected)
                    return " 󰈀 "
                return "󰤮"
            }
            tipTitle: ConnectivityService.wifiConnected
                      ? "WiFi Connected" : (ConnectivityService.lanConnected ? "Ethernet Connected" : "Network Disconnected")
            tipDetail: {
                if (ConnectivityService.wifiConnected)
                    return ConnectivityService.wifiSSID +
                           "\nSignal: " + ConnectivityService.wifiSignal + "%" +
                           "\n↓ " + SystemMonitorService.netDown + "  ↑ " + SystemMonitorService.netUp
                if (ConnectivityService.lanConnected)
                    return ConnectivityService.lanInterface +
                           "\nIP: " + ConnectivityService.lanIP +
                           "\n↓ " + SystemMonitorService.netDown + "  ↑ " + SystemMonitorService.netUp
                return "Click to select WiFi"
            }
            iconColor: SysRowState.resolveColor(
                SysRowState.networkColor,
                (ConnectivityService.wifiConnected || ConnectivityService.lanConnected)
                    ? ThemeService.purple : ThemeService.grey2
            )
            onClicked: {
                // Open Control Panel (same as Super+C)
                wifiProc.command = ["bash", "-c",
                    "qs -c zen-shell ipc call zen toggleControlCenter"]
                wifiProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // BLUETOOTH —  (U+F293) /  disabled /  N connected
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded && SysRowState.showBluetooth
            opacity: sysRoot.expanded ? 1 : 0
            icon: {
                if (ConnectivityService.btConnected)
                    return "\uf293 " + ConnectivityService.btDevices.length
                if (ConnectivityService.btPowered)
                    return "\uf293 "
                return "\uf293 "
            }
            tipTitle: "Bluetooth: " + (ConnectivityService.btPowered
                      ? (ConnectivityService.btConnected
                         ? "Connected" : "On") : "Off")
            tipDetail: ConnectivityService.btConnected
                       ? ("Bluetooth Connected:\n" + ConnectivityService.btConnectedName +
                          "\n" + ConnectivityService.btDevices.length + " device(s)")
                       : (ConnectivityService.btPowered
                          ? "No devices connected" : "Bluetooth is off")
            iconColor: SysRowState.resolveColor(
                SysRowState.btColor,
                ConnectivityService.btConnected ? ThemeService.yellow
                    : (ConnectivityService.btPowered ? ThemeService.grey0 : ThemeService.grey2)
            )
            onClicked: {
                btProc.command = ["bash", "-c",
                    "if pgrep -x blueman-manager >/dev/null; then pkill -x blueman-manager; " +
                    "else blueman-manager & fi"]
                btProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ═══════════════════════════════════════════════
        // BATTERY (v6.16.0) —  (U+F240-F244) based on capacity
        // Only visible on laptops AND when SysRowState.showBattery is on.
        // Double-gated: batteryPresent (hardware) + showBattery (user pref).
        // Click → opens Control Panel (same as tray Battery module).
        // ═══════════════════════════════════════════════
        SysRowIcon {
            visible: sysRoot.expanded
                     && SysRowState.showBattery
                     && SystemMonitorService.batteryPresent
            opacity: sysRoot.expanded ? 1 : 0
            icon: {
                const cap = SystemMonitorService.batteryCapacity
                const charging = SystemMonitorService.batteryCharging
                // Icon glyph (nf-fa-battery_*) — u+f240..f244
                let glyph
                if      (cap >= 90) glyph = "\uf240"   // battery-full
                else if (cap >= 65) glyph = "\uf241"   // battery-three-quarters
                else if (cap >= 40) glyph = "\uf242"   // battery-half
                else if (cap >= 15) glyph = "\uf243"   // battery-quarter
                else                glyph = "\uf244"   // battery-empty
                // Charging prefix — bolt
                const prefix = charging ? "\uf0e7 " : ""
                return sysRoot.fmtModule(
                    prefix + glyph,
                    sysRoot.barGlyph(cap),
                    cap + "%"
                )
            }
            tipTitle: "Battery: " + SystemMonitorService.batteryCapacity + "%"
                      + (SystemMonitorService.batteryCharging ? " (charging)" : "")
            tipDetail: {
                let s = "Status: " + SystemMonitorService.batteryStatus
                if (SystemMonitorService.batteryTimeRemaining.length > 0) {
                    s += "\n" + SystemMonitorService.batteryTimeRemaining
                }
                if (SystemMonitorService.batteryPowerDraw > 0) {
                    s += "\nPower: " + SystemMonitorService.batteryPowerDraw.toFixed(1) + "W"
                }
                // Append current power profile if available
                if (typeof PowerProfileService !== "undefined" && PowerProfileService.available) {
                    s += "\nProfile: " + PowerProfileService.profileLabel(PowerProfileService.currentProfile)
                }
                return s
            }
            iconColor: SysRowState.resolveColor(
                SysRowState.batteryColor,
                // Auto color by capacity + charging state
                SystemMonitorService.batteryCharging ? ThemeService.green
                    : (SystemMonitorService.batteryCapacity <= 10 ? ThemeService.red
                    : (SystemMonitorService.batteryCapacity <= 30 ? ThemeService.orange
                    : (SystemMonitorService.batteryCapacity <= 50 ? ThemeService.yellow
                    : ThemeService.fg)))
            )
            onClicked: {
                // Open Control Panel (Super+C) — has Power Profile section
                batteryProc.command = ["bash", "-c",
                    "qs -c zen-shell ipc call zen toggleControlCenter"]
                batteryProc.running = true
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ── End separator (waybar custom/endpoint) ──
        Text {
            visible: sysRoot.expanded
            opacity: sysRoot.expanded ? 1 : 0
            text: "|"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(14 * sysRoot._fit)
            color: ThemeService.grey2
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // ── Process launchers ──
    Process { id: audioProc; running: false }
    Process { id: btmProc; running: false }
    Process { id: wifiProc; running: false }
    Process { id: btProc; running: false }
    Process { id: batteryProc; running: false }   // v6.16.0
}
