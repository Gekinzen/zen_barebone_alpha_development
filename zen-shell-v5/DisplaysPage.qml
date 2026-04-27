import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * DisplaysPage v6.9.2
 *
 * v6.9.2: Fixed drag feedback loop from v6.9.1. Per-monitor
 * MouseAreas caused coordinate-space compounding (monRect.x
 * includes dragOffsetX → next dragOffsetX computed from that
 * → exponential drift). Replaced with single parent-level
 * MouseArea + hit-testing (same pattern as original Canvas
 * v6.8.1, but rendering with GPU-composited QML Items).
 *
 * v6.9.1: Major preview rewrite + disable display + zoom.
 *
 * CHANGELOG from v6.8.1:
 *   ┌─ SMOOTH DRAG ──────────────────────────────────────────┐
 *   │ Replaced Canvas-based preview with QML Rectangle items │
 *   │ (Repeater). Each monitor is a GPU-accelerated Item with│
 *   │ its own MouseArea — drag offset is tracked via separate │
 *   │ properties (not model mutation per-frame) so there's no │
 *   │ binding cascade on every mouse-move. Result: buttery    │
 *   │ smooth repositioning. Snapping + anti-overlap still run │
 *   │ at 10px grid, applied only on mouse-release.            │
 *   └────────────────────────────────────────────────────────┘
 *   ┌─ ZOOM CONTROLS ───────────────────────────────────────┐
 *   │ User-adjustable zoom on the preview area. Auto-fit     │
 *   │ calculates base scale from bounding box; user zoom     │
 *   │ multiplies on top (0.3× – 2.0× range). +/- buttons    │
 *   │ and "Fit" reset. Preview area enlarged to 280px.       │
 *   └────────────────────────────────────────────────────────┘
 *   ┌─ DISABLE DISPLAY ─────────────────────────────────────┐
 *   │ Per-monitor "Enabled" toggle (HMSwitch). Toggling off  │
 *   │ sends `hyprctl keyword monitor <n>,disable`. Toggle    │
 *   │ on re-applies current resolution/hz/scale/transform.   │
 *   │ Persisted to hyprland-monitors.conf. Disabled monitors │
 *   │ show dimmed in preview with strikethrough overlay.      │
 *   │ Guards against disabling the LAST enabled monitor.     │
 *   └────────────────────────────────────────────────────────┘
 *
 * WALA TAYONG BABAWASAN.
 */
ScrollView {
    id: root
    clip: true

    property var monitors: []
    property int selectedIdx: -1
    property string applyStatus: ""

    // Drag state
    property bool dragging: false
    property int dragIdx: -1
    property real dragStartMouseX: 0
    property real dragStartMouseY: 0
    property int dragStartMonX: 0
    property int dragStartMonY: 0
    // v6.9.1: Live drag offset — tracked separately from model to avoid
    // binding cascade on every mouse-move (was the main source of jank
    // in v6.8.1 Canvas approach).
    property real dragOffsetX: 0
    property real dragOffsetY: 0

    // v6.9.1: Zoom
    property real userZoom: 1.0
    readonly property real minZoom: 0.3
    readonly property real maxZoom: 2.0

    // Layout cache (recomputed in updatePreviewLayout)
    property real cScale: 1.0
    property real cOx: 0
    property real cOy: 0
    property real cMinX: 0
    property real cMinY: 0

    function refreshMonitors() { monitorsFetcher.running = true }

    Process {
        id: monitorsFetcher
        command: ["hyprctl", "monitors", "all", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(this.text)
                    if (root.selectedIdx < 0 && root.monitors.length > 0) root.selectedIdx = 0
                    root.updatePreviewLayout()
                } catch (e) { root.monitors = [] }
            }
        }
    }

    Process {
        id: applyProc; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyStatus = this.text.trim() === "ok" || !this.text.trim() ? "✓ Applied" : "⚠ " + this.text.trim()
                refreshDelay.running = true
                // v6.16.4.4: Re-apply SettingsStateV2 after monitor
                // keyword change. Paul reported: "nung nag palit ako
                // ng scale etc yung mga gaps ko nawala."
                //
                // Root cause: `hyprctl keyword monitor ...` internally
                // bumps Hyprland's monitor state and re-creates the
                // output's workspace layout. When that happens, some
                // runtime keywords (particularly gaps_in/gaps_out,
                // rounding, blur radius) that were set via keyword
                // rather than via conf file silently fall back to
                // whatever hyprland.conf has on disk.
                //
                // Paul's workaround was re-selecting a theme, which
                // made ZenSettings trigger applyToHyprland() as a
                // side effect. We replicate that side effect directly
                // here so the workaround isn't needed.
                //
                // Qt.callLater queues it after the current event
                // loop tick — gives Hyprland a moment to finish the
                // monitor reconfiguration before we re-assert all
                // the runtime keywords on top.
                Qt.callLater(function() {
                    if (typeof SettingsStateV2 !== "undefined"
                        && typeof SettingsStateV2.applyToHyprland === "function") {
                        SettingsStateV2.applyToHyprland()
                    }
                })
            }
        }
    }
    Process { id: primarySetter; running: false }
    Timer { id: refreshDelay; interval: 400; repeat: false; onTriggered: root.refreshMonitors() }

    // v6.8: Persistence — save to hyprland-monitors.conf so config survives logout
    Process { id: persistProc; running: false }
    readonly property string monitorConfPath: Quickshell.env("HOME") + "/.config/hypr/hyprland-monitors.conf"

    function applyMonitor(name, w, h, hz, scale, transform, px, py) {
        const cmd = name + "," + w + "x" + h + "@" + hz.toFixed(2) + "," + px + "x" + py + "," + scale.toFixed(2) +
                    (transform > 0 ? ",transform," + transform : "")
        // 1. Apply live via hyprctl
        applyProc.command = ["hyprctl", "keyword", "monitor", cmd]
        applyProc.running = true
        applyStatus = "Applying..."

        // 2. Persist to hyprland-monitors.conf
        // This file should be `source`d from hyprland.conf:
        //   source = ~/.config/hypr/hyprland-monitors.conf
        _persistMonitorLine(name, cmd)
    }

    // v6.9.1: Disable a monitor
    function disableMonitor(name) {
        applyProc.command = ["hyprctl", "keyword", "monitor", name + ",disable"]
        applyProc.running = true
        applyStatus = "Disabling " + name + "..."
        _persistMonitorLine(name, name + ",disable")
    }

    // v6.9.1: Count how many monitors are currently enabled
    function enabledCount() {
        let count = 0
        for (let i = 0; i < monitors.length; i++) {
            if (!monitors[i].disabled) count++
        }
        return count
    }

    // v6.16.4.12: Count physically-connected monitors (have availableModes).
    // A monitor with empty availableModes is unplugged.
    function physicallyConnectedCount() {
        let count = 0
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i]
            if (m.availableModes && m.availableModes.length > 0) count++
        }
        return count
    }

    // v6.16.4.12: Count enabled AND physically-connected.
    // This is the real "do I have a working display" count.
    function workingDisplayCount() {
        let count = 0
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i]
            if (!m.disabled && m.availableModes && m.availableModes.length > 0) count++
        }
        return count
    }

    function _persistMonitorLine(name, fullLine) {
        // Read existing file, replace/add the line for this monitor name, write back
        persistProc.command = ["bash", "-c",
            "CONF='" + monitorConfPath + "'; " +
            "mkdir -p \"$(dirname \"$CONF\")\"; " +
            "touch \"$CONF\"; " +
            // Remove existing line for this monitor name
            "grep -v '^monitor\\s*=\\s*" + name + ",' \"$CONF\" > \"$CONF.tmp\" 2>/dev/null || true; " +
            // Add new line
            "echo 'monitor = " + fullLine + "' >> \"$CONF.tmp\"; " +
            // Replace
            "mv \"$CONF.tmp\" \"$CONF\"; " +
            // Also ensure hyprland.conf sources it (idempotent)
            "HYPR=\"$HOME/.config/hypr/hyprland.conf\"; " +
            "if [ -f \"$HYPR\" ] && ! grep -q 'hyprland-monitors.conf' \"$HYPR\" 2>/dev/null; then " +
            "  echo '' >> \"$HYPR\"; " +
            "  echo '# Zen Shell display persistence' >> \"$HYPR\"; " +
            "  echo 'source = ~/.config/hypr/hyprland-monitors.conf' >> \"$HYPR\"; " +
            "fi"
        ]
        persistProc.running = true
    }

    // Effective display size (accounting for rotation)
    function effectiveW(m) {
        const t = m.transform || 0
        return (t === 1 || t === 3) ? m.height / (m.scale || 1) : m.width / (m.scale || 1)
    }
    function effectiveH(m) {
        const t = m.transform || 0
        return (t === 1 || t === 3) ? m.width / (m.scale || 1) : m.height / (m.scale || 1)
    }

    // Apply drag result — snap to 10px grid, push via hyprctl
    function applyDragPosition(idx) {
        if (idx < 0 || idx >= monitors.length) return
        const m = monitors[idx]
        const hz = m.refreshRate || 60
        applyMonitor(m.name, m.width, m.height, hz, m.scale || 1, m.transform || 0,
                     m.x || 0, m.y || 0)
    }

    // Position helper — snap selected monitor relative to another
    function positionMonitor(direction) {
        if (selectedIdx < 0 || monitors.length < 2) return
        const sel = monitors[selectedIdx]
        let other = null
        for (let i = 0; i < monitors.length; i++) { if (i !== selectedIdx) { other = monitors[i]; break } }
        if (!other) return
        const sw = effectiveW(sel), sh = effectiveH(sel)
        const ow = effectiveW(other), oh = effectiveH(other)
        let nx = sel.x, ny = sel.y
        switch (direction) {
            case "left":  nx = other.x - sw; ny = other.y; break
            case "right": nx = other.x + ow; ny = other.y; break
            case "above": nx = other.x; ny = other.y - sh; break
            case "below": nx = other.x; ny = other.y + oh; break
        }
        const hz = sel.refreshRate || 60
        applyMonitor(sel.name, sel.width, sel.height, hz, sel.scale || 1, sel.transform || 0,
                     Math.round(nx), Math.round(ny))
    }

    Process { id: nwgLauncher; running: false }
    function launchNwgDisplays() {
        nwgLauncher.command = ["bash", "-c",
            "command -v nwg-displays >/dev/null 2>&1 && setsid nwg-displays >/dev/null 2>&1 & disown || true"]
        nwgLauncher.running = true
    }

    // ═════════════════════════════════════════════════════════
    // v6.9.1: Compute preview layout from monitors bounding box.
    // Called on monitors change + zoom change + area resize.
    // Sets cScale, cOx, cOy, cMinX, cMinY for the preview items.
    // ═════════════════════════════════════════════════════════
    function updatePreviewLayout() {
        const mons = root.monitors
        if (mons.length === 0) return

        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        for (const m of mons) {
            if (m.disabled) continue  // skip disabled from bounding box
            const ew = root.effectiveW(m), eh = root.effectiveH(m)
            if (m.x < minX) minX = m.x
            if (m.y < minY) minY = m.y
            if (m.x + ew > maxX) maxX = m.x + ew
            if (m.y + eh > maxY) maxY = m.y + eh
        }
        // If all disabled, fall back to including all
        if (minX === Infinity) {
            for (const m of mons) {
                const ew = root.effectiveW(m), eh = root.effectiveH(m)
                if (m.x < minX) minX = m.x
                if (m.y < minY) minY = m.y
                if (m.x + ew > maxX) maxX = m.x + ew
                if (m.y + eh > maxY) maxY = m.y + eh
            }
        }
        const tw = maxX - minX, th = maxY - minY
        if (tw === 0 || th === 0) return

        const areaW = previewArea.width - 32
        const areaH = previewArea.height - 32
        if (areaW <= 0 || areaH <= 0) return

        const baseScale = Math.min(areaW / tw, areaH / th)
        const s = baseScale * root.userZoom
        const ox = (areaW - tw * s) / 2 + 16
        const oy = (areaH - th * s) / 2 + 16

        root.cScale = s
        root.cOx = ox
        root.cOy = oy
        root.cMinX = minX
        root.cMinY = minY
    }

    onUserZoomChanged: updatePreviewLayout()

    Component.onCompleted: refreshMonitors()
    readonly property int dropdownWidth: 240

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24; spacing: 16

        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "Displays"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: ThemeService.fg }
            Text { text: "Drag monitors to reposition • click to select"; font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
        }

        // ═══════════════════════════════════════════════════════
        // v6.9.1: VISUAL MONITOR PREVIEW — QML Items + zoom
        //
        // Replaced Canvas with Repeater of Rectangle delegates.
        // Each monitor is a separate QML Item = GPU-composited,
        // smooth transforms, no per-frame JS repaint. Drag
        // offset tracked separately so model isn't mutated on
        // every mouse-move (eliminates binding cascade stutter).
        // ═══════════════════════════════════════════════════════
        Rectangle {
            id: previewArea
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1, 0.5)
            border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.08)
            clip: true

            onWidthChanged: root.updatePreviewLayout()
            onHeightChanged: root.updatePreviewLayout()

            // Monitor items — GPU-composited rectangles (purely visual, no MouseArea)
            Repeater {
                id: monitorRepeater
                model: root.monitors

                delegate: Rectangle {
                    id: monRect
                    required property var modelData
                    required property int index

                    readonly property bool isSel: index === root.selectedIdx
                    readonly property bool isDragging: index === root.dragIdx && root.dragging
                    readonly property bool isDisabled: modelData.disabled || false

                    // Position from layout computation
                    readonly property real baseX: root.cOx + (modelData.x - root.cMinX) * root.cScale
                    readonly property real baseY: root.cOy + (modelData.y - root.cMinY) * root.cScale

                    x: isDragging ? baseX + root.dragOffsetX : baseX
                    y: isDragging ? baseY + root.dragOffsetY : baseY
                    width: root.effectiveW(modelData) * root.cScale
                    height: root.effectiveH(modelData) * root.cScale

                    // Smooth position when NOT dragging (e.g. after snap buttons, zoom change)
                    Behavior on x { enabled: !monRect.isDragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !monRect.isDragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    z: isDragging ? 10 : (isSel ? 5 : 1)
                    radius: 4

                    color: {
                        if (isDisabled) return ThemeService.alpha(ThemeService.fg, 0.03)
                        if (isSel || isDragging)
                            return ThemeService.alpha(ThemeService.blue, isDragging ? 0.3 : 0.18)
                        return ThemeService.alpha(ThemeService.fg, 0.05)
                    }
                    border.width: isSel ? 2.5 : 1.5
                    border.color: {
                        if (isDisabled) return ThemeService.alpha(ThemeService.fg, 0.08)
                        if (isSel) return ThemeService.alpha(ThemeService.blue, 0.8)
                        return ThemeService.alpha(ThemeService.fg, 0.18)
                    }
                    opacity: isDisabled ? 0.5 : 1.0

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // Monitor name label
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -10
                        text: monRect.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Math.min(parent.width, parent.height) * 0.16)
                        font.weight: Font.Bold
                        color: {
                            if (monRect.isDisabled) return ThemeService.alpha(ThemeService.fg, 0.25)
                            if (monRect.isSel) return ThemeService.alpha(ThemeService.blue, 0.9)
                            return ThemeService.alpha(ThemeService.fg, 0.45)
                        }
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Resolution + hz info label
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 8
                        text: {
                            if (monRect.isDisabled) return "Disabled"
                            const m = monRect.modelData
                            const rotLabel = (m.transform || 0) > 0 ? " R" + [0,90,180,270][m.transform||0] + "°" : ""
                            return m.width + "×" + m.height + "@" + (m.refreshRate||60).toFixed(0) + "Hz" + rotLabel
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Math.min(parent.width, parent.height) * 0.11)
                        color: monRect.isDisabled
                               ? ThemeService.alpha(ThemeService.red, 0.5)
                               : ThemeService.alpha(ThemeService.fg, 0.3)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // v6.9.1: Disabled strikethrough overlay
                    Rectangle {
                        visible: monRect.isDisabled
                        anchors.centerIn: parent
                        width: parent.width * 0.7
                        height: 2
                        radius: 1
                        color: ThemeService.alpha(ThemeService.red, 0.35)
                        rotation: -15
                    }
                }
            }

            // ── v6.9.2: Single parent-level MouseArea for all drag/click ──
            //
            // v6.9.1 had per-monitor MouseAreas but that caused a coordinate
            // feedback loop: monRect.x includes dragOffsetX, so computing
            // the next dragOffsetX from (mouse.x + monRect.x) compounds the
            // offset recursively → monitors fly off screen.
            //
            // Fix: one MouseArea at the previewArea level. Coordinates are
            // always in previewArea-space (stable, never moves). Hit-test
            // done via the same AABB check as the old Canvas approach.
            MouseArea {
                id: previewMouse
                anchors.fill: parent
                z: 50  // above monitor rectangles but below zoom controls
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
                hoverEnabled: true

                // Hit-test: which monitor (if any) is under (mx, my)?
                function hitTest(mx, my) {
                    const s = root.cScale
                    if (s === 0) return -1
                    // Check in reverse order so topmost (highest z) wins
                    for (let i = root.monitors.length - 1; i >= 0; i--) {
                        const m = root.monitors[i]
                        const ew = root.effectiveW(m), eh = root.effectiveH(m)
                        const rx = root.cOx + (m.x - root.cMinX) * s
                        const ry = root.cOy + (m.y - root.cMinY) * s
                        if (mx >= rx && mx <= rx + ew*s && my >= ry && my <= ry + eh*s) return i
                    }
                    return -1
                }

                onPressed: function(mouse) {
                    const idx = hitTest(mouse.x, mouse.y)
                    if (idx >= 0) {
                        root.selectedIdx = idx
                        const m = root.monitors[idx]
                        if (!(m.disabled || false)) {
                            root.dragIdx = idx
                            root.dragging = true
                            // mouse.x/y are in previewArea-space — stable!
                            root.dragStartMouseX = mouse.x
                            root.dragStartMouseY = mouse.y
                            root.dragStartMonX = m.x
                            root.dragStartMonY = m.y
                            root.dragOffsetX = 0
                            root.dragOffsetY = 0
                        }
                    } else {
                        root.selectedIdx = -1
                    }
                }

                onPositionChanged: function(mouse) {
                    if (!root.dragging || root.dragIdx < 0) return
                    // Pure delta from press point — no coordinate-space issues
                    root.dragOffsetX = mouse.x - root.dragStartMouseX
                    root.dragOffsetY = mouse.y - root.dragStartMouseY
                }

                onReleased: function(mouse) {
                    if (root.dragging && root.dragIdx >= 0) {
                        const s = root.cScale
                        if (s > 0) {
                            // Convert pixel offset to monitor-space, snap to 10px grid
                            const dx = root.dragOffsetX / s
                            const dy = root.dragOffsetY / s
                            let nx = Math.round((root.dragStartMonX + dx) / 10) * 10
                            let ny = Math.round((root.dragStartMonY + dy) / 10) * 10

                            // Simple collision avoidance — push out of overlap
                            const dm = root.monitors[root.dragIdx]
                            const dw = root.effectiveW(dm), dh = root.effectiveH(dm)
                            for (let i = 0; i < root.monitors.length; i++) {
                                if (i === root.dragIdx) continue
                                const om = root.monitors[i]
                                if (om.disabled) continue
                                const ow = root.effectiveW(om), oh = root.effectiveH(om)
                                // AABB overlap?
                                if (nx < om.x + ow && nx + dw > om.x && ny < om.y + oh && ny + dh > om.y) {
                                    const pushL = om.x - (nx + dw)
                                    const pushR = (om.x + ow) - nx
                                    const pushU = om.y - (ny + dh)
                                    const pushD = (om.y + oh) - ny
                                    const minH = Math.abs(pushL) < Math.abs(pushR) ? pushL : pushR
                                    const minV = Math.abs(pushU) < Math.abs(pushD) ? pushU : pushD
                                    if (Math.abs(minH) < Math.abs(minV)) {
                                        nx += minH
                                    } else {
                                        ny += minV
                                    }
                                }
                            }

                            // Update model with final snapped position
                            let updated = []
                            for (let i = 0; i < root.monitors.length; i++) {
                                const m = root.monitors[i]
                                if (i === root.dragIdx) {
                                    const copy = Object.assign({}, m)
                                    copy.x = nx; copy.y = ny
                                    updated.push(copy)
                                } else {
                                    updated.push(m)
                                }
                            }
                            root.monitors = updated
                            root.updatePreviewLayout()
                            root.applyDragPosition(root.dragIdx)
                        }
                    }
                    root.dragging = false
                    root.dragIdx = -1
                    root.dragOffsetX = 0
                    root.dragOffsetY = 0
                }
            }

            // Hint text
            Text {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 4
                text: root.monitors.length > 1 ? "Drag to reposition • positions snap to 10px grid" : ""
                font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1
            }

            // ── v6.9.1: Zoom controls (top-right corner) ──
            Row {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 8; anchors.rightMargin: 8
                spacing: 4
                z: 60  // above previewMouse (z:50)

                Repeater {
                    model: [
                        { label: "\uf068", action: "out" },
                        { label: "Fit",    action: "fit" },
                        { label: "\uf067", action: "in" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: modelData.action === "fit" ? 36 : 28; height: 26; radius: 6
                        color: zoomMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.12)
                               : ThemeService.alpha(ThemeService.bg2, 0.6)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: modelData.action === "fit" ? Theme.fontFamily : "JetBrainsMono Nerd Font"
                            font.pixelSize: modelData.action === "fit" ? 10 : 11
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }
                        MouseArea {
                            id: zoomMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "in") {
                                    root.userZoom = Math.min(root.maxZoom, root.userZoom + 0.15)
                                } else if (modelData.action === "out") {
                                    root.userZoom = Math.max(root.minZoom, root.userZoom - 0.15)
                                } else {
                                    root.userZoom = 1.0
                                }
                            }
                        }
                    }
                }
            }

            // v6.9.1: Zoom level indicator (bottom-right, only when zoomed)
            Text {
                anchors.bottom: parent.bottom; anchors.right: parent.right
                anchors.bottomMargin: 6; anchors.rightMargin: 10
                visible: Math.abs(root.userZoom - 1.0) > 0.05
                text: (root.userZoom * 100).toFixed(0) + "%"
                font.family: Theme.fontFamily; font.pixelSize: 9; color: ThemeService.grey1
            }
        }

        // ── Position snap + nwg-displays ──
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 10
            color: ThemeService.alpha(ThemeService.bg1, 0.35)
            border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.06)
            visible: root.monitors.length > 1

            RowLayout {
                anchors.centerIn: parent; spacing: 10
                Text { text: "Snap:"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.grey0 }
                Repeater {
                    model: [
                        { dir: "left",  icon: "\uf060" },
                        { dir: "right", icon: "\uf061" },
                        { dir: "above", icon: "\uf062" },
                        { dir: "below", icon: "\uf063" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 70; height: 30; radius: 7
                        color: pBtn.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.16) : ThemeService.alpha(ThemeService.bg2, 0.4)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.08)
                        RowLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: ThemeService.fg }
                            Text { text: modelData.dir.charAt(0).toUpperCase() + modelData.dir.slice(1); font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.fg }
                        }
                        MouseArea { id: pBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.positionMonitor(modelData.dir) }
                    }
                }
                Rectangle {
                    width: nwgR.implicitWidth + 16; height: 30; radius: 7
                    color: nwgB.containsMouse ? ThemeService.alpha(ThemeService.purple, 0.16) : ThemeService.alpha(ThemeService.bg2, 0.3)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.purple, 0.15)
                    RowLayout { id: nwgR; anchors.centerIn: parent; spacing: 4
                        Text { text: "\uf26c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: ThemeService.purple }
                        Text { text: "nwg-displays"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.purple }
                    }
                    MouseArea { id: nwgB; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launchNwgDisplays() }
                }
            }
        }

        Text { visible: root.applyStatus.length > 0; text: root.applyStatus; font.family: Theme.fontFamily; font.pixelSize: 11; color: root.applyStatus.startsWith("✓") ? ThemeService.green : ThemeService.yellow; Layout.alignment: Qt.AlignHCenter }

        RowLayout { Layout.fillWidth: true; Item { Layout.fillWidth: true }
            Button { text: "\uf021 Refresh"; font.family: "JetBrainsMono Nerd Font"; onClicked: root.refreshMonitors() }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 80; radius: 12; color: ThemeService.alpha(ThemeService.bg1, 0.4); visible: root.monitors.length === 0
            Text { anchors.centerIn: parent; text: "No monitors detected."; font.family: Theme.fontFamily; font.pixelSize: 13; color: ThemeService.grey1 }
        }

        // ═══ Per-monitor config cards ═══
        Repeater {
            model: root.monitors
            delegate: HMSection {
                required property var modelData
                required property int index

                title: modelData.name + (modelData.focused ? "  ● Primary" : "") + (index === root.selectedIdx ? "  ◆ Selected" : "") + ((modelData.disabled || false) ? "  ○ Disabled" : "")
                subtitle: (modelData.description || "") + "  •  " + modelData.width + "×" + modelData.height +
                          "@" + (modelData.refreshRate||60).toFixed(0) + "Hz  •  pos " + (modelData.x||0) + "," + (modelData.y||0) +
                          ((modelData.transform||0) > 0 ? "  •  rot " + [0,90,180,270][modelData.transform||0] + "°" : "") +
                          ((modelData.disabled || false) ? "  •  DISABLED" : "")

                // v6.9.1: Enable/Disable toggle
                HMRow { label: "Enabled"; description: "Turn display on or off"; icon: "\uf26c"; separator: true
                    HMSwitch {
                        checked: !(modelData.disabled || false)
                        activeColor: ThemeService.green
                        onToggled: {
                            if (modelData.disabled) {
                                // Re-enable: apply current settings
                                const hz = modelData.refreshRate || 60
                                root.applyMonitor(modelData.name, modelData.width, modelData.height,
                                                  hz, modelData.scale || 1, modelData.transform || 0,
                                                  modelData.x || 0, modelData.y || 0)
                            } else {
                                // v6.16.4.12: Stronger guard.
                                // Refuse if disabling this would leave NO enabled
                                // physically-connected monitors. The old check only
                                // counted enabled — but a "phantom" enabled monitor
                                // (e.g. previously-connected DP-1 that's now unplugged)
                                // doesn't actually give the user a screen.
                                if (root.workingDisplayCount() <= 1) {
                                    root.applyStatus = "⚠ Cannot disable — this is your only working display"
                                    checked = true
                                    return
                                }
                                root.disableMonitor(modelData.name)
                            }
                        }
                    }
                }

                HMRow { label: "Resolution"; description: "Output resolution"; icon: "\uf26c"; separator: true
                    ZenComboBox { id: resCombo; width: root.dropdownWidth
                        enabled: !(modelData.disabled || false)

                        // ─────────────────────────────────────────────
                        // v6.16.3.3 — Resolution enumeration fix
                        //
                        // Previous (buggy) regex: /(\d+)x(\d+)@/
                        //   Required an "@" terminator, which dropped
                        //   any mode Hyprland emitted as a bare
                        //   "1920x1080" (no refresh-rate suffix).
                        //   Paul reported: "the resolution dropdown is
                        //   missing some valid modes the monitor
                        //   actually supports."
                        //
                        // Hyprland's `hyprctl monitors all -j` returns
                        // `.availableModes` as an array of strings,
                        // formats observed across hardware/versions:
                        //   "1920x1080@60.000Hz"   (typical EDID)
                        //   "1920x1080@60.00000"   (no Hz suffix)
                        //   "1920x1080@60"         (integer Hz)
                        //   "1920x1080"            (raw, no refresh)
                        //   "2560x1440@144.00Hz"
                        //   "3840x2160@29.981Hz"   (28.98 rounded to 30 elsewhere)
                        //
                        // New regex: /^(\d+)x(\d+)/
                        //   Anchored at start, doesn't care what comes
                        //   after the height. Matches every variant.
                        //
                        // Plus: we also add the CURRENT resolution
                        //   (modelData.width × modelData.height) to the
                        //   list even if it's not in availableModes
                        //   (Hyprland sometimes omits the current mode
                        //   from the list when user forces a custom
                        //   mode via `monitor = ...` override — so the
                        //   dropdown used to show an empty current
                        //   index).
                        //
                        // Plus: results are sorted descending by total
                        //   pixels (width × height) so native/best mode
                        //   appears at the top.
                        // ─────────────────────────────────────────────
                        // ─────────────────────────────────────────────
                        // v6.16.4.2 — Enumeration 3-tier fallback
                        //
                        // Some panels (notably eDP OLEDs and high-refresh
                        // laptop IPS screens) only expose their native
                        // mode via DRM — `availableModes` returns just
                        // one entry. Paul reported this on his ROG
                        // laptop: 2560x1440@165Hz panel, dropdown showed
                        // only 2560x1440 with nothing else to pick.
                        //
                        // 3-tier fallback to guarantee a useful list:
                        //   Tier 1: hyprctl `availableModes` (primary)
                        //   Tier 2: scaled aspect-ratio fallbacks
                        //           — native divided by common factors
                        //           (100%, 75%, 67%, 50%)
                        //           gives the "downscale for games" set
                        //   Tier 3: common standard resolutions that
                        //           fit within the native bounds
                        //           (1920x1080, 1680x1050, 1600x900,
                        //            1440x900, 1366x768, 1280x720)
                        //
                        // Tiers are merged (no duplicates), then sorted
                        // descending by pixel count. User can pick any
                        // of these — Hyprland will accept them even if
                        // they're "synthetic" modes via GPU scaling.
                        // ─────────────────────────────────────────────
                        property var uniqueRes: {
                            const seen = {}, list = []

                            // Tier 1: availableModes from hyprctl
                            for (let m of (modelData.availableModes || [])) {
                                const mt = m.match(/^(\d+)x(\d+)/)
                                if (!mt) continue
                                const w = parseInt(mt[1]), h = parseInt(mt[2])
                                const k = w + "x" + h
                                if (!seen[k]) { seen[k] = true; list.push({ w:w, h:h, k:k }) }
                            }

                            const nativeW = modelData.width || 0
                            const nativeH = modelData.height || 0

                            // Ensure current mode is in the list
                            if (nativeW > 0) {
                                const curK = nativeW + "x" + nativeH
                                if (!seen[curK]) {
                                    list.push({ w:nativeW, h:nativeH, k:curK }); seen[curK] = true
                                }
                            }

                            // Tier 2: scaled fallbacks — native × fraction.
                            // Only add if the result looks like a "real"
                            // resolution (even pixels, reasonable size).
                            if (nativeW >= 1280) {
                                for (const frac of [0.75, 0.667, 0.5]) {
                                    const sw = Math.round(nativeW * frac / 2) * 2
                                    const sh = Math.round(nativeH * frac / 2) * 2
                                    if (sw < 640 || sh < 360) continue
                                    const k = sw + "x" + sh
                                    if (!seen[k]) { seen[k] = true; list.push({ w:sw, h:sh, k:k }) }
                                }
                            }

                            // Tier 3: common standard resolutions that
                            // fit within the native panel. Filter to
                            // ones that actually downscale cleanly.
                            const standards = [
                                [3840,2160],[2560,1600],[2560,1440],[2560,1080],
                                [1920,1200],[1920,1080],[1680,1050],[1600,1200],
                                [1600,900],[1440,900],[1366,768],[1280,1024],
                                [1280,800],[1280,720],[1024,768]
                            ]
                            for (const [sw, sh] of standards) {
                                if (sw > nativeW || sh > nativeH) continue
                                const k = sw + "x" + sh
                                if (!seen[k]) { seen[k] = true; list.push({ w:sw, h:sh, k:k }) }
                            }

                            // Descending by pixel count (native first)
                            list.sort(function(a,b){ return (b.w*b.h) - (a.w*a.h) })
                            const keys = list.map(function(x){ return x.k })
                            const curK = nativeW + "x" + nativeH
                            return keys.length > 0 ? keys : [curK]
                        }
                        model: uniqueRes
                        currentIndex: {
                            const k = (modelData.width||0) + "x" + (modelData.height||0)
                            return Math.max(0, uniqueRes.indexOf(k))
                        }
                    }
                }

                HMRow { label: "Refresh rate"; description: "Monitor Hz"; icon: "\uf0e4"; separator: true
                    ZenComboBox { id: hzCombo; width: root.dropdownWidth
                        enabled: !(modelData.disabled || false)

                        // ─────────────────────────────────────────────
                        // v6.16.3.3 — Refresh rate enumeration fix
                        //
                        // Companion to the resolution fix above. Was:
                        //   new RegExp(rp[0]+"x"+rp[1]+"@([\\d.]+)")
                        // which required an "@<number>" suffix. Missed
                        //   "1920x1080"         → no @ at all
                        //   "1920x1080@60Hz"    → @ but regex matched
                        //                         fine here; still
                        //   "1920x1080@60.00000Hz" — fine
                        //
                        // New regex: /@\s*([\d.]+)/
                        //   Allows optional whitespace after @. If no
                        //   @ present at all, defaults to 60 Hz as a
                        //   sensible fallback so the mode isn't hidden.
                        //
                        // Plus: ALWAYS include the monitor's current
                        //   refresh rate in the list (previous code
                        //   would default to {hz:60,label:"60 Hz"} if
                        //   no matches — hiding whatever the panel was
                        //   actually running at).
                        //
                        // Plus: dedupe by ROUNDED Hz so "59.934" and
                        //   "60.000" don't both show up as "60 Hz"
                        //   twice.
                        // ─────────────────────────────────────────────
                        property var hzList: {
                            const rp = (resCombo.currentText || "").split("x")
                            if (rp.length < 2) {
                                return [{ hz: modelData.refreshRate||60,
                                          label: (modelData.refreshRate||60).toFixed(0) + " Hz" }]
                            }
                            const seen = {}, list = []
                            const prefix = rp[0] + "x" + rp[1]
                            for (let m of (modelData.availableModes || [])) {
                                // Must start with our selected WxH
                                if (m.indexOf(prefix) !== 0) continue
                                // Extract Hz if present
                                const mt = m.match(/@\s*([\d.]+)/)
                                const h = mt ? parseFloat(mt[1]) : 60.0
                                if (!isFinite(h) || h <= 0) continue
                                const k = h.toFixed(0)
                                if (!seen[k]) { seen[k] = true; list.push({ hz:h, label:k + " Hz" }) }
                            }
                            // Always include the current rate if it's
                            // for this selected resolution and missing
                            const curK = (modelData.refreshRate||60).toFixed(0)
                            const isCurrentRes = (rp[0] == (modelData.width||0).toString())
                                              && (rp[1] == (modelData.height||0).toString())
                            if (isCurrentRes && !seen[curK]) {
                                list.push({ hz: modelData.refreshRate||60, label: curK + " Hz" })
                            }
                            list.sort(function(a,b){ return b.hz - a.hz })
                            return list.length > 0 ? list
                                 : [{ hz: modelData.refreshRate||60, label: curK + " Hz" }]
                        }
                        model: { const m=[]; for(const h of hzList) m.push(h.label); return m }
                        currentIndex: {
                            const c = (modelData.refreshRate||60).toFixed(0)
                            for (let i = 0; i < hzList.length; i++)
                                if (hzList[i].hz.toFixed(0) === c) return i
                            return 0
                        }
                    }
                }

                HMRow { label: "Scale"; description: "HiDPI scaling"; icon: "\uf00e"; separator: true
                    ZenComboBox { id: scaleCombo; width: root.dropdownWidth
                        enabled: !(modelData.disabled || false)
                        property var scales: ["1.0","1.25","1.5","1.75","2.0"]; model: scales
                        currentIndex: { const s=(modelData.scale||1.0).toFixed(2); for(let i=0;i<scales.length;i++) if(Math.abs(parseFloat(scales[i])-parseFloat(s))<0.05) return i; return 0 }
                    }
                }

                HMRow { label: "Rotation"; description: "Transform"; icon: "\uf2f1"; separator: true
                    ZenComboBox { id: rotCombo; width: root.dropdownWidth; model: ["Normal (0°)","90°","180°","270°"]
                        enabled: !(modelData.disabled || false)
                        currentIndex: Math.min(3, modelData.transform || 0)
                    }
                }

                // v6.9: Primary monitor toggle
                HMRow { label: "Primary display"; description: "Set as main monitor for cursor focus"; icon: "\uf005"
                    Rectangle {
                        width: primaryLabel.implicitWidth + 24; height: 30; radius: 6
                        color: modelData.focused
                               ? ThemeService.alpha(ThemeService.green, 0.15)
                               : (primaryMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent")
                        border.width: 1
                        border.color: modelData.focused ? ThemeService.alpha(ThemeService.green, 0.3) : ThemeService.alpha(ThemeService.fg, 0.1)
                        opacity: (modelData.disabled || false) ? 0.4 : 1.0

                        Text {
                            id: primaryLabel; anchors.centerIn: parent
                            text: modelData.focused ? "\uf00c  Primary" : "Set as primary"
                            font.family: Theme.fontFamily; font.pixelSize: 11
                            color: modelData.focused ? ThemeService.green : ThemeService.grey0
                        }
                        MouseArea {
                            id: primaryMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: !(modelData.disabled || false)
                            onClicked: {
                                if (!modelData.focused) {
                                    primarySetter.command = ["hyprctl", "dispatch", "focusmonitor", modelData.name]
                                    primarySetter.running = true
                                    refreshDelay.running = true
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.topMargin: 4
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        Item { Layout.fillWidth: true }
                        Rectangle { Layout.preferredWidth: applyR.implicitWidth + 32; Layout.preferredHeight: 36; radius: 8
                            color: applyM.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.28) : ThemeService.alpha(ThemeService.blue, 0.16)
                            border.width: 1; border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                            opacity: (modelData.disabled || false) ? 0.4 : 1.0
                            RowLayout { id: applyR; anchors.centerIn: parent; spacing: 6
                                Text { text: "\uf00c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: ThemeService.blue }
                                Text { text: "Apply " + modelData.name; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: ThemeService.blue }
                            }
                            MouseArea { id: applyM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: !(modelData.disabled || false)
                                onClicked: { const p=resCombo.currentText.split("x"); root.applyMonitor(modelData.name, parseInt(p[0]), parseInt(p[1]),
                                    hzCombo.hzList[Math.max(0,hzCombo.currentIndex)].hz, parseFloat(scaleCombo.currentText), rotCombo.currentIndex, modelData.x||0, modelData.y||0) }
                            }
                        }
                    }
                }
            }
        }

        PageFooter { description: "Drag monitors in preview or use snap buttons • nwg-displays for advanced layout"; onResetRequested: root.refreshMonitors() }
        Item { Layout.preferredHeight: 24 }
    }
}
