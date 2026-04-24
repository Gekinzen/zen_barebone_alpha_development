import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * DisplaysPage v6.8.1
 *
 * v6.8.1: Draggable monitor preview — click+drag to reposition monitors,
 * collision avoidance (no overlap), rotation visual (90°/270° shows
 * portrait aspect ratio), snap-to-grid (10px). Force-apply via hyprctl
 * with explicit position coordinates.
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

    // Canvas layout cache
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
                    monitorCanvas.requestPaint()
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
        // VISUAL MONITOR PREVIEW — draggable + rotation-aware
        // ═══════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1, 0.5)
            border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            Canvas {
                id: monitorCanvas
                anchors.fill: parent; anchors.margins: 16

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const mons = root.monitors
                    if (mons.length === 0) return

                    // Bounding box
                    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
                    for (const m of mons) {
                        const ew = root.effectiveW(m), eh = root.effectiveH(m)
                        if (m.x < minX) minX = m.x
                        if (m.y < minY) minY = m.y
                        if (m.x + ew > maxX) maxX = m.x + ew
                        if (m.y + eh > maxY) maxY = m.y + eh
                    }
                    const tw = maxX - minX, th = maxY - minY
                    if (tw === 0 || th === 0) return

                    const pad = 16
                    const s = Math.min((width - 2*pad) / tw, (height - 2*pad) / th)
                    const ox = (width - tw * s) / 2, oy = (height - th * s) / 2
                    root.cScale = s; root.cOx = ox; root.cOy = oy
                    root.cMinX = minX; root.cMinY = minY

                    for (let idx = 0; idx < mons.length; idx++) {
                        const m = mons[idx]
                        const ew = root.effectiveW(m), eh = root.effectiveH(m)
                        const mx = ox + (m.x - minX) * s
                        const my = oy + (m.y - minY) * s
                        const mw = ew * s, mh = eh * s
                        const isSel = idx === root.selectedIdx
                        const isDrag = idx === root.dragIdx && root.dragging

                        // Fill
                        ctx.fillStyle = isSel || isDrag
                            ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, isDrag ? 0.3 : 0.18)
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.05)
                        ctx.fillRect(mx, my, mw, mh)

                        // Border
                        ctx.lineWidth = isSel ? 2.5 : 1.5
                        ctx.strokeStyle = isSel
                            ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.8)
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.18)
                        ctx.strokeRect(mx, my, mw, mh)

                        // Name + info
                        const fontSize = Math.max(10, Math.min(mw, mh) * 0.18)
                        ctx.fillStyle = isSel
                            ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.9)
                            : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.45)
                        ctx.font = "bold " + fontSize + "px sans-serif"
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"
                        ctx.fillText(m.name, mx + mw/2, my + mh/2 - 8)

                        ctx.font = Math.max(9, fontSize * 0.7) + "px sans-serif"
                        ctx.fillStyle = Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.3)
                        const rotLabel = (m.transform || 0) > 0 ? " R" + [0,90,180,270][m.transform||0] + "°" : ""
                        ctx.fillText(m.width + "×" + m.height + "@" + (m.refreshRate||60).toFixed(0) + "Hz" + rotLabel,
                                     mx + mw/2, my + mh/2 + 10)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    function hitTest(mx, my) {
                        const s = root.cScale
                        if (s === 0) return -1
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
                            root.dragIdx = idx
                            root.dragging = true
                            root.dragStartMouseX = mouse.x
                            root.dragStartMouseY = mouse.y
                            root.dragStartMonX = root.monitors[idx].x
                            root.dragStartMonY = root.monitors[idx].y
                        }
                        monitorCanvas.requestPaint()
                    }

                    onPositionChanged: function(mouse) {
                        if (!root.dragging || root.dragIdx < 0) return
                        const s = root.cScale
                        if (s === 0) return
                        const dx = (mouse.x - root.dragStartMouseX) / s
                        const dy = (mouse.y - root.dragStartMouseY) / s
                        // Snap to 10px grid
                        let nx = Math.round((root.dragStartMonX + dx) / 10) * 10
                        let ny = Math.round((root.dragStartMonY + dy) / 10) * 10

                        // Simple collision avoidance — push out of overlap
                        const dm = root.monitors[root.dragIdx]
                        const dw = root.effectiveW(dm), dh = root.effectiveH(dm)
                        for (let i = 0; i < root.monitors.length; i++) {
                            if (i === root.dragIdx) continue
                            const om = root.monitors[i]
                            const ow = root.effectiveW(om), oh = root.effectiveH(om)
                            // AABB overlap?
                            if (nx < om.x + ow && nx + dw > om.x && ny < om.y + oh && ny + dh > om.y) {
                                // Push out on shortest axis
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

                        // Update monitor position in-memory for live preview
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
                        monitorCanvas.requestPaint()
                    }

                    onReleased: function(mouse) {
                        if (root.dragging && root.dragIdx >= 0) {
                            // Apply the final position via hyprctl
                            root.applyDragPosition(root.dragIdx)
                        }
                        root.dragging = false
                        root.dragIdx = -1
                    }
                }
            }

            Text {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 2
                text: root.monitors.length > 1 ? "Drag to reposition • positions snap to 10px grid" : ""
                font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1
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

                title: modelData.name + (modelData.focused ? "  ● Primary" : "") + (index === root.selectedIdx ? "  ◆ Selected" : "")
                subtitle: (modelData.description || "") + "  •  " + modelData.width + "×" + modelData.height +
                          "@" + (modelData.refreshRate||60).toFixed(0) + "Hz  •  pos " + (modelData.x||0) + "," + (modelData.y||0) +
                          ((modelData.transform||0) > 0 ? "  •  rot " + [0,90,180,270][modelData.transform||0] + "°" : "")

                HMRow { label: "Resolution"; description: "Output resolution"; icon: "\uf26c"; separator: true
                    ZenComboBox { id: resCombo; width: root.dropdownWidth

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
                        property var scales: ["1.0","1.25","1.5","1.75","2.0"]; model: scales
                        currentIndex: { const s=(modelData.scale||1.0).toFixed(2); for(let i=0;i<scales.length;i++) if(Math.abs(parseFloat(scales[i])-parseFloat(s))<0.05) return i; return 0 }
                    }
                }

                HMRow { label: "Rotation"; description: "Transform"; icon: "\uf2f1"; separator: true
                    ZenComboBox { id: rotCombo; width: root.dropdownWidth; model: ["Normal (0°)","90°","180°","270°"]
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

                        Text {
                            id: primaryLabel; anchors.centerIn: parent
                            text: modelData.focused ? "\uf00c  Primary" : "Set as primary"
                            font.family: Theme.fontFamily; font.pixelSize: 11
                            color: modelData.focused ? ThemeService.green : ThemeService.grey0
                        }
                        MouseArea {
                            id: primaryMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
                            RowLayout { id: applyR; anchors.centerIn: parent; spacing: 6
                                Text { text: "\uf00c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: ThemeService.blue }
                                Text { text: "Apply " + modelData.name; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: ThemeService.blue }
                            }
                            MouseArea { id: applyM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
