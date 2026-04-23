import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * DesktopWidgets v6.16.1.3 — Desktop overlay
 *
 * v6.16.1.3 HOTFIX (ghost widget):
 *   v6.16.1 added layer.enabled + external shadow Rectangles to
 *   smooth the drag. Both broke: toggling layer.enabled mid-drag
 *   creates framebuffer swap glitches (old position ghosts until
 *   next full paint), and shadows bound to widget.x/y created
 *   stale duplicates during position updates. Removed both.
 *   Kept drag.threshold 5px + scale animation (transform-based,
 *   no ghost). Drag is still smooth — just no more trail.
 *
 * v6.16.1:
 *   - sysmonWidget: multi-GPU tabs (Overview / CPU / GPU0 / GPU1 / NET),
 *     btop quick-launch button (toggle-kill pattern), auto-adapts to
 *     SystemMonitorService.gpuCount. Overview grid unchanged.
 *
 * v6.11e: Fixed drag delay — removed x/y property bindings that
 * fought with drag.target. Positions set imperatively via onChanged
 * handlers instead of declarative bindings.
 */
Item {
    id: dw
    anchors.fill: parent

    readonly property string configDir: Quickshell.env("HOME") + "/.config/quickshell/zen-shell"
    readonly property string configPath: configDir + "/widgets-state.json"

    // v6.16.3.7: Universal widget scale multiplier.
    // Binds live to PanelState.widgetScale (set via Settings →
    // Widgets → Widget Scale slider). Every font.pixelSize and
    // container dimension in this file multiplies by dw._scale,
    // so changing the Settings slider resizes all three widgets
    // (clocks, weather, sysmon) in lockstep — instantly, no
    // shell restart.
    //
    // Clamped to 0.5-2.0 defensively in case someone hand-edits
    // panel-state.json with a nonsense value. Lower bound 0.5
    // keeps text readable; upper bound 2.0 keeps widgets from
    // eating the entire screen on HiDPI displays.
    readonly property real _scale: {
        const s = PanelState.widgetScale !== undefined ? PanelState.widgetScale : 1.0
        return Math.max(0.5, Math.min(2.0, s))
    }

    property var clocks: [
        { enabled: true, timezone: "Asia/Manila", format24h: true, label: "Manila" },
        { enabled: false, timezone: "America/Winnipeg", format24h: true, label: "Winnipeg" }
    ]

    property bool weatherEnabled: true
    property bool sysmonEnabled: true
    property string widgetDisplay: "primary"
    property bool clockGlow: true

    property real clockPosX: 40
    property real clockPosY: 60
    property real weatherPosX: -1
    property real weatherPosY: 40
    property real sysmonPosX: -1
    property real sysmonPosY: 300

    property string colorMode: "default"
    property string customColor: "#ffffff"

    // v6.16.1.5: per-widget background colors (loaded from widgets-state.json)
    property string weatherBgMode: "default"         // default|theme|custom
    property string weatherBgCustomColor: "#1c1c1e"
    property real   weatherBgOpacity: 0.92
    property string sysmonBgMode: "default"
    property string sysmonBgCustomColor: "#1c1c1e"
    property real   sysmonBgOpacity: 0.92

    // Reactive computed colors — widgets bind to these. Auto-update when
    // user changes the mode or color in Settings and saveState() rewrites
    // widgets-state.json (FileView reload triggers _applyConfig → these).
    readonly property color weatherBgColor: {
        if (weatherBgMode === "theme")
            return ThemeService.alpha(ThemeService.bg0, weatherBgOpacity)
        if (weatherBgMode === "custom") {
            const c = weatherBgCustomColor
            return Qt.rgba(
                parseInt(c.substr(1,2), 16) / 255,
                parseInt(c.substr(3,2), 16) / 255,
                parseInt(c.substr(5,2), 16) / 255,
                weatherBgOpacity)
        }
        return Qt.rgba(0.11, 0.11, 0.118, 0.92)   // default (unchanged)
    }
    readonly property color sysmonBgColor: {
        if (sysmonBgMode === "theme")
            return ThemeService.alpha(ThemeService.bg0, sysmonBgOpacity)
        if (sysmonBgMode === "custom") {
            const c = sysmonBgCustomColor
            return Qt.rgba(
                parseInt(c.substr(1,2), 16) / 255,
                parseInt(c.substr(3,2), 16) / 255,
                parseInt(c.substr(5,2), 16) / 255,
                sysmonBgOpacity)
        }
        return Qt.rgba(0.11, 0.11, 0.118, 0.92)   // default (unchanged)
    }

    readonly property color widgetTextColor: {
        if (colorMode === "theme") return ThemeService.fg
        if (colorMode === "custom") return customColor
        return "#ffffff"
    }
    readonly property color widgetAccentColor: {
        if (colorMode === "theme") return ThemeService.blue
        if (colorMode === "custom") return customColor
        return Qt.rgba(0.53, 0.81, 0.92, 1.0)
    }

    // ── Position apply (imperative, no bindings) ──
    // v6.16.1.9 GHOST-WIDGET FIX:
    //   Previous versions called _applyPositions() on width/height change
    //   without guarding against active drags. If anything caused dw.width
    //   or dw.height to change during a drag (a sparkline repaint, a
    //   weather text update causing content reflow, monitor config event),
    //   this function forcibly reset widget.x/y back to the *saved* position
    //   — mid-drag. Result: the widget snapped back to origin while the
    //   drag.target's pending updates still had the cursor position ready
    //   for the next frame, producing two visible widget copies until
    //   release.
    //   Fix: check `_anyDragActive` before applying positions. If any of
    //   the three drag areas is active, skip the re-apply — let drag.target
    //   own the position until release.
    readonly property bool _anyDragActive:
        (typeof clockDragArea   !== "undefined" && clockDragArea.drag.active) ||
        (typeof weatherDragArea !== "undefined" && weatherDragArea.drag.active) ||
        (typeof sysmonDragArea  !== "undefined" && sysmonDragArea.drag.active)

    function _applyPositions() {
        // Guard: don't apply if window hasn't sized yet
        if (dw.width <= 0 || dw.height <= 0) return
        // v6.16.1.9: don't clobber drag.target's live position
        if (_anyDragActive) return

        clockWidget.x = clockPosX
        clockWidget.y = clockPosY
        if (weatherPosX < 0)
            weatherWidget.x = dw.width - weatherWidget.width - 40
        else
            weatherWidget.x = weatherPosX
        weatherWidget.y = weatherPosY
        if (sysmonPosX < 0)
            sysmonWidget.x = dw.width - sysmonWidget.width - 40
        else
            sysmonWidget.x = sysmonPosX
        sysmonWidget.y = sysmonPosY
    }

    onWidthChanged: _applyPositions()
    onHeightChanged: _applyPositions()

    FileView {
        id: cfgLoader
        path: dw.configPath
        blockLoading: false
        onLoaded: dw._applyConfig(this.text())
    }
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: cfgLoader.reload()
    }

    function _applyConfig(text) {
        try {
            const s = JSON.parse(text)
            if (s.clocks && Array.isArray(s.clocks)) {
                dw.clocks = s.clocks
            } else {
                const c1 = s.clock || {}
                const c2 = s.clock2 || {}
                dw.clocks = [
                    { enabled: c1.enabled !== false, timezone: c1.timezone || "Asia/Manila", format24h: c1.format24h !== false, label: (c1.timezone||"Asia/Manila").split("/").pop().replace(/_/g," ") },
                    { enabled: c2.enabled === true, timezone: c2.timezone || "America/Winnipeg", format24h: c2.format24h !== false, label: (c2.timezone||"America/Winnipeg").split("/").pop().replace(/_/g," ") }
                ]
            }
            if (s.weather) weatherEnabled = s.weather.enabled !== false
            if (s.sysmon) sysmonEnabled = s.sysmon.enabled !== false
            if (s.widgetDisplay) widgetDisplay = s.widgetDisplay
            if (typeof s.clockGlow === "boolean") clockGlow = s.clockGlow
            if (s.positions) {
                if (typeof s.positions.clockX === "number") clockPosX = s.positions.clockX
                if (typeof s.positions.clockY === "number") clockPosY = s.positions.clockY
                if (typeof s.positions.weatherX === "number") weatherPosX = s.positions.weatherX
                if (typeof s.positions.weatherY === "number") weatherPosY = s.positions.weatherY
                if (typeof s.positions.sysmonX === "number") sysmonPosX = s.positions.sysmonX
                if (typeof s.positions.sysmonY === "number") sysmonPosY = s.positions.sysmonY
            }
            if (s.colorMode) colorMode = s.colorMode
            if (s.customColor) customColor = s.customColor

            // v6.16.1.5: per-widget background settings
            if (s.weatherBg) {
                if (s.weatherBg.mode) weatherBgMode = s.weatherBg.mode
                if (s.weatherBg.color) weatherBgCustomColor = s.weatherBg.color
                if (typeof s.weatherBg.opacity === "number") weatherBgOpacity = s.weatherBg.opacity
            }
            if (s.sysmonBg) {
                if (s.sysmonBg.mode) sysmonBgMode = s.sysmonBg.mode
                if (s.sysmonBg.color) sysmonBgCustomColor = s.sysmonBg.color
                if (typeof s.sysmonBg.opacity === "number") sysmonBgOpacity = s.sysmonBg.opacity
            }

            // Apply positions imperatively after loading
            _applyPositions()
        } catch (e) {}
    }

    Timer {
        id: posSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            // v6.16.3.4.3: STATE-CLOBBER FIX
            //
            // Old payload was missing weatherBg + sysmonBg, so every drag
            // wrote a JSON that dropped those fields. On next shell restart
            // the FileView would load the clobbered JSON and fall back to
            // the default background mode — user complaint:
            //   "pinalitan ko color pag ka restart ko babalik sa default
            //    nanaman"
            //
            // The complete widget-state schema is owned by WidgetsPage.qml's
            // saveState(); both serializers must agree on it. Keep this
            // payload in sync whenever a new field is added to WidgetsPage.
            const state = {
                clocks: dw.clocks,
                weather: { enabled: dw.weatherEnabled },
                sysmon: { enabled: dw.sysmonEnabled },
                widgetDisplay: dw.widgetDisplay,
                clockGlow: dw.clockGlow,
                positions: { clockX: dw.clockPosX, clockY: dw.clockPosY, weatherX: dw.weatherPosX, weatherY: dw.weatherPosY, sysmonX: dw.sysmonPosX, sysmonY: dw.sysmonPosY },
                colorMode: dw.colorMode,
                customColor: dw.customColor,
                // v6.16.3.4.3: per-widget background fields — MUST be included
                // or dragging a widget nukes the user's custom colors
                weatherBg: { mode: dw.weatherBgMode, color: dw.weatherBgCustomColor, opacity: dw.weatherBgOpacity },
                sysmonBg:  { mode: dw.sysmonBgMode,  color: dw.sysmonBgCustomColor,  opacity: dw.sysmonBgOpacity }
            }
            posSaver.command = ["bash", "-c", "mkdir -p '" + dw.configDir + "' && cat > '" + dw.configPath + "' << 'ZENEOF'\n" + JSON.stringify(state, null, 2) + "\nZENEOF"]
            posSaver.running = true
        }
    }
    Process { id: posSaver; running: false }
    function _savePositions() { posSaveTimer.restart() }

    Component.onCompleted: {
        cfgLoader.reload()
        // Delay initial position apply to let layout settle
        Qt.callLater(_applyPositions)
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: dw.now = new Date()
    }
    property var now: new Date()

    function convertTime(targetTz) {
        const h = dw.now.getHours()
        const m = dw.now.getMinutes()
        const offsets = {
            "Asia/Manila":0,"Asia/Singapore":0,"Asia/Hong_Kong":0,"Asia/Shanghai":0,
            "Asia/Tokyo":1,"Asia/Seoul":1,"Asia/Kolkata":-2.5,"Asia/Dubai":-4,
            "Europe/London":-7,"Europe/Paris":-6,
            "America/New_York":-12,"America/Toronto":-12,
            "America/Chicago":-13,"America/Winnipeg":-13,
            "America/Los_Angeles":-15,"America/Vancouver":-15,
            "Australia/Sydney":3,"Pacific/Auckland":5,"UTC":-8
        }
        let offset = offsets[targetTz] || 0
        let adjH = h + offset
        let adjM = m
        if (offset % 1 !== 0) {
            adjM = m + (offset > 0 ? 30 : -30)
            adjH = Math.floor(h + offset)
            if (adjM >= 60) { adjM -= 60; adjH += 1 }
            if (adjM < 0) { adjM += 60; adjH -= 1 }
        }
        if (adjH < 0) adjH += 24
        if (adjH >= 24) adjH -= 24
        return { hours: Math.floor(adjH), minutes: adjM }
    }


    // ═══════════════════════════════════════════════════════════
    // CLOCK — NO x/y binding, drag.target owns position
    // v6.16.1.3: GHOST-WIDGET FIX
    //   v6.16.1 added `layer.enabled: drag.active` + external shadow
    //   Rectangle bound to clockWidget.x/y. Two problems:
    //     1. Toggling layer.enabled mid-drag swaps the render pipeline
    //        (software → offscreen framebuffer). The old position's
    //        texture doesn't get invalidated cleanly → ghost trail.
    //     2. The shadow Rectangle was a sibling that tracked widget.x/y
    //        via property binding, so during drag the shadow updated
    //        per-frame from the binding but the widget's old position
    //        still had a stale render pass → two widgets visible.
    //
    //   Fix: keep scale animation (works via matrix transform, not
    //   position) + drag.threshold. Drop the layer-toggle and external
    //   shadow entirely. If we want a shadow later, it'll be via
    //   DropShadow effect inside the widget item (moves as one unit).
    // ═══════════════════════════════════════════════════════════

    Rectangle {
        id: clockWidget
        visible: dw.clocks.length > 0 && dw.clocks[0].enabled
        // NO x: or y: binding here — set imperatively via _applyPositions()
        width: clockLayout.implicitWidth + 40
        height: clockLayout.implicitHeight + 20
        color: "transparent"
        antialiasing: true

        // v6.16.1.8: REMOVED scale + Behavior on scale during drag.
        // Even though scale is a transform (not position), Qt's repaint
        // cycle during the Behavior animation window creates stale render
        // artifacts when combined with drag.target's rapid x/y updates.
        // The scale pop was nice-to-have; widget stability is essential.
        // Drag now uses threshold-only (no visual feedback on press) —
        // simplest, most reliable path. Cursor change via ClosedHandCursor
        // gives enough tactile feedback.

        MouseArea {
            id: clockDragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: clockWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - clockWidget.width
            drag.maximumY: dw.height - clockWidget.height
            drag.threshold: 5     // ignore <5px jitter
            onReleased: {
                dw.clockPosX = clockWidget.x
                dw.clockPosY = clockWidget.y
                dw._savePositions()
            }
        }

        Column {
            id: clockLayout
            x: 20
            y: 10
            spacing: 0

            Repeater {
                model: dw.clocks
                delegate: Column {
                    required property var modelData
                    required property int index
                    visible: modelData.enabled
                    spacing: 0

                    Item {
                        width: timeText.implicitWidth
                        height: timeText.implicitHeight

                        Rectangle {
                            visible: dw.clockGlow && index === 0
                            anchors.centerIn: parent
                            width: parent.width + 80
                            height: parent.height + 40
                            radius: 30
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.15) }
                                GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.15) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                            }
                        }

                        Text {
                            id: timeText
                            text: {
                                let h, m
                                if (index === 0) { h = dw.now.getHours(); m = dw.now.getMinutes() }
                                else { const t = dw.convertTime(modelData.timezone); h = t.hours; m = t.minutes }
                                const pad = n => String(n).padStart(2, "0")
                                if (modelData.format24h) return pad(h) + ":" + pad(m)
                                const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h)
                                return pad(h12) + ":" + pad(m)
                            }
                            font.family: "Adwaita Sans"
                            font.pixelSize: (index === 0 ? 120 : 36) * dw._scale
                            font.weight: Font.Black
                            font.letterSpacing: index === 0 ? -4 : -1
                            color: index === 0 ? dw.widgetTextColor : dw.widgetAccentColor
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }
                    }

                    Text {
                        visible: index === 0
                        text: {
                            const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                            const months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
                            return days[dw.now.getDay()] + ", " + months[dw.now.getMonth()] + " " + String(dw.now.getDate()).padStart(2, "0")
                        }
                        font.family: "Adwaita Sans"
                        font.pixelSize: 24 * dw._scale
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 0.5
                        color: dw.widgetTextColor
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }

                    Text {
                        visible: !modelData.format24h && index === 0
                        text: dw.now.getHours() < 12 ? "AM" : "PM"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 18 * dw._scale
                        font.weight: Font.Bold
                        color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.7)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }

                    Text {
                        visible: index > 0
                        text: modelData.label || modelData.timezone.split("/").pop().replace(/_/g, " ")
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14 * dw._scale
                        font.weight: Font.DemiBold
                        color: Qt.rgba(dw.widgetAccentColor.r, dw.widgetAccentColor.g, dw.widgetAccentColor.b, 0.7)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.4)
                    }

                    Item {
                        width: 1
                        height: index < dw.clocks.length - 1 ? 8 : 0
                    }
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════
    // WEATHER — NO x/y binding, stats forced right
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: weatherWidget
        visible: dw.weatherEnabled
        // NO x: or y: binding — set imperatively
        // v6.16.3.7: scaled via dw._scale so the whole weather widget
        // resizes with the user's Settings → Widgets → Widget Scale.
        width: 400 * dw._scale
        height: 260 * dw._scale
        radius: 16
        // v6.16.1.5: reactive background from WidgetsPage settings
        color: dw.weatherBgColor
        // v6.16.1.8: disable color Behavior during drag — color-animation
        // repaints combined with fast x/y updates = ghost frames.
        Behavior on color {
            enabled: !weatherDragArea.drag.active
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        antialiasing: true

        // v6.16.1.8: REMOVED scale + Behavior on scale during drag
        // (see clockWidget comment for full rationale).

        MouseArea {
            id: weatherDragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: weatherWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - weatherWidget.width
            drag.maximumY: dw.height - weatherWidget.height
            drag.threshold: 5
            onReleased: {
                dw.weatherPosX = weatherWidget.x
                dw.weatherPosY = weatherWidget.y
                dw._savePositions()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // Top section — emoji+temp left, stats forced right
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 90

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 12

                    Text {
                        text: WeatherService.emojiIcon
                        font.pixelSize: 48 * dw._scale
                    }

                    Column {
                        spacing: 1

                        Text {
                            text: WeatherService.temperature + "°C"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 42 * dw._scale
                            font.weight: Font.ExtraBold
                            color: "#ffffff"
                        }
                        Text {
                            text: WeatherService.locationName
                            font.family: "Adwaita Sans"
                            font.pixelSize: 13 * dw._scale
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                    }
                }

                // Stats forced to right edge
                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 4

                    Text {
                        anchors.right: parent.right
                        text: WeatherService.feelsLike + "°"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12 * dw._scale
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    Text {
                        anchors.right: parent.right
                        text: WeatherService.humidity + "%"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12 * dw._scale
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    Text {
                        anchors.right: parent.right
                        text: WeatherService.windSpeed + "km/h"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12 * dw._scale
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }
            }

            // Condition + updated
            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                Text {
                    text: WeatherService.condition
                    font.family: "Adwaita Sans"
                    font.pixelSize: 14 * dw._scale
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
                Text {
                    visible: WeatherService.lastUpdated !== ""
                    text: "Updated " + WeatherService.lastUpdated
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10 * dw._scale
                    color: Qt.rgba(1, 1, 1, 0.4)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // Forecast: Today + 6 days with emoji cloud/sun icons
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: {
                        const fc = WeatherService.forecast
                        if (!fc || fc.length === 0) return []
                        return fc.slice(0, 7)
                    }
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 72
                        radius: 8
                        color: index === 0 ? Qt.rgba(0.22, 0.22, 0.24, 0.6) : Qt.rgba(0.18, 0.18, 0.19, 0.4)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, index === 0 ? 0.12 : 0.05)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: modelData.day || "?"
                                font.family: "Adwaita Sans"
                                font.pixelSize: 10 * dw._scale
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, index === 0 ? 0.9 : 0.6)
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData.emoji || "☁️"
                                font.pixelSize: 18 * dw._scale
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: (modelData.maxTemp !== undefined ? modelData.maxTemp : "--") + "°/" + (modelData.minTemp !== undefined ? modelData.minTemp : "--") + "°"
                                font.family: "Adwaita Sans"
                                font.pixelSize: 10 * dw._scale
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, 0.8)
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                Text {
                    visible: !WeatherService.forecast || WeatherService.forecast.length === 0
                    text: "Loading forecast..."
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11 * dw._scale
                    color: Qt.rgba(1, 1, 1, 0.4)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════
    // SYSTEM MONITOR — NO x/y binding, sparklines
    //
    // v6.16.1 additions:
    //   - Smooth drag (scale-only — no layer toggle, no external shadow,
    //     v6.16.1.3 ghost fix)
    //   - btop quick-launch button (upper-right corner)
    //   - Tab bar for multi-GPU: Overview | CPU | GPU0 | GPU1... | NET
    //     Overview is the original 2×2 grid (unchanged).
    //     Per-GPU tabs show full-screen sparkline + stats for that GPU.
    // ═══════════════════════════════════════════════════════════

    // Tab state — Overview by default. Valid values:
    //   "overview" | "cpu" | "gpu0" | "gpu1" | ... | "net"
    property string sysmonActiveTab: "overview"

    Rectangle {
        id: sysmonWidget
        visible: dw.sysmonEnabled
        // NO x: or y: binding — set imperatively
        // v6.16.3.7: scaled with dw._scale (see Settings → Widgets)
        width: 420 * dw._scale
        height: 420 * dw._scale
        radius: 16
        // v6.16.1.5: reactive background from WidgetsPage settings
        color: dw.sysmonBgColor
        // v6.16.1.8: disable color Behavior during drag
        Behavior on color {
            enabled: !sysmonDragArea.drag.active
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        antialiasing: true

        // v6.16.1.8: REMOVED scale + Behavior on scale during drag

        MouseArea {
            id: sysmonDragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: sysmonWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - sysmonWidget.width
            drag.maximumY: dw.height - sysmonWidget.height
            drag.threshold: 5
            onReleased: {
                dw.sysmonPosX = sysmonWidget.x
                dw.sysmonPosY = sysmonWidget.y
                dw._savePositions()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // ── Header row: title + btop button ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle { width: 3; height: 16; radius: 2; color: "#ff453a" }
                Text {
                    text: "SYSTEM MONITOR"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12 * dw._scale
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: SystemMonitorService.cpuName
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10 * dw._scale
                    color: Qt.rgba(1, 1, 1, 0.5)
                    visible: dw.sysmonActiveTab === "overview"
                }

                // v6.16.1: btop button — upper-right corner.
                // Launches `alacritty --title btopWindow -e btop`
                // (or kitty/foot fallback). Toggle-kill pattern same as SysRow.
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 22
                    radius: 6
                    color: btopBtn.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12)
                        : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf2db"  // microchip / process icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13 * dw._scale
                        color: Qt.rgba(1, 1, 1, 0.9)
                    }

                    MouseArea {
                        id: btopBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Toggle-kill: close btop if already open, else launch.
                            // Prefer alacritty → kitty → foot.
                            btopProc.command = ["bash", "-c",
                                "if pgrep -f 'btop|btm' >/dev/null 2>&1 && "
                                + "pgrep -f 'alacritty.*btop\\|alacritty.*btm\\|kitty.*btop\\|foot.*btop' >/dev/null 2>&1; "
                                + "then pkill -f 'alacritty.*btop\\|alacritty.*btm\\|kitty.*btop\\|foot.*btop'; "
                                + "else "
                                + "  if command -v alacritty >/dev/null; then "
                                + "    alacritty --title btopWindow -e btop 2>/dev/null & "
                                + "  elif command -v kitty >/dev/null; then "
                                + "    kitty --title btopWindow btop 2>/dev/null & "
                                + "  elif command -v foot >/dev/null; then "
                                + "    foot --title btopWindow btop 2>/dev/null & "
                                + "  elif command -v alacritty >/dev/null; then "
                                + "    alacritty --title btopWindow -e btm 2>/dev/null & "
                                + "  fi; "
                                + "fi"]
                            btopProc.running = true
                        }
                    }
                }
            }

            // ── v6.16.1: Tab bar ──
            // Shows Overview + CPU + per-GPU + NET tabs. Auto-adapts to
            // the number of detected GPUs (SystemMonitorService.gpuCount).
            // On single-GPU systems collapses to 4 tabs.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Static tabs: Overview, CPU
                Repeater {
                    model: [
                        { id: "overview", label: "Overview" },
                        { id: "cpu",      label: "CPU" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: dw.sysmonActiveTab === modelData.id
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: tabLbl.implicitWidth + 16
                        radius: 6
                        color: isActive
                            ? Qt.rgba(0.3, 0.55, 0.9, 0.35)
                            : (tabMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : Qt.rgba(1, 1, 1, 0.03))
                        border.width: isActive ? 1 : 0
                        border.color: Qt.rgba(0.48, 0.78, 1.0, 0.6)

                        Text {
                            id: tabLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "Adwaita Sans"
                            font.pixelSize: 9 * dw._scale
                            font.weight: Font.DemiBold
                            color: parent.isActive ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.55)
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dw.sysmonActiveTab = modelData.id
                        }
                    }
                }

                // Per-GPU tabs — one per detected GPU
                Repeater {
                    model: SystemMonitorService.gpuCount
                    delegate: Rectangle {
                        required property int index
                        readonly property string tabId: "gpu" + index
                        readonly property bool isActive: dw.sysmonActiveTab === tabId
                        readonly property var gpu: SystemMonitorService.gpus[index] || {}
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: gpuTabLbl.implicitWidth + 16
                        radius: 6
                        color: isActive
                            ? Qt.rgba(0.3, 0.55, 0.9, 0.35)
                            : (gpuTabMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : Qt.rgba(1, 1, 1, 0.03))
                        border.width: isActive ? 1 : 0
                        border.color: Qt.rgba(0.48, 0.78, 1.0, 0.6)

                        Text {
                            id: gpuTabLbl
                            anchors.centerIn: parent
                            text: SystemMonitorService.gpuCount > 1
                                ? ("GPU" + index)
                                : "GPU"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 9 * dw._scale
                            font.weight: Font.DemiBold
                            color: parent.isActive ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.55)
                        }

                        MouseArea {
                            id: gpuTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dw.sysmonActiveTab = tabId
                        }
                    }
                }

                // NET tab
                Rectangle {
                    readonly property bool isActive: dw.sysmonActiveTab === "net"
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: netLbl.implicitWidth + 16
                    radius: 6
                    color: isActive
                        ? Qt.rgba(0.3, 0.55, 0.9, 0.35)
                        : (netTabMouse.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.rgba(1, 1, 1, 0.03))
                    border.width: isActive ? 1 : 0
                    border.color: Qt.rgba(0.48, 0.78, 1.0, 0.6)

                    Text {
                        id: netLbl
                        anchors.centerIn: parent
                        text: "NET"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 9 * dw._scale
                        font.weight: Font.DemiBold
                        color: parent.isActive ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.55)
                    }

                    MouseArea {
                        id: netTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dw.sysmonActiveTab = "net"
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Content area: GridLayout (overview) or tab detail ──
            // Overview: the original 2×2 grid (unchanged — wala tayong babawasan)
            GridLayout {
                visible: dw.sysmonActiveTab === "overview"
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                // CPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "CPU"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
                        }
                        Canvas {
                            id: cpuCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.cpuHistory
                            property color lc: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(cpuCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "TEMP"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°C" : "--"; font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.Bold; color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp) }
                            Item { Layout.fillWidth: true }
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.cpuPercent + "%"; font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.Bold; color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent) }
                        }
                    }
                }

                // GPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "GPU"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text { text: "VRAM"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
                        }
                        Canvas {
                            id: gpuCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.gpuHistory
                            property color lc: SystemMonitorService.usageColor(SystemMonitorService.gpuUsage)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(gpuCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "TEMP"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.gpuTemp > 0 ? SystemMonitorService.gpuTemp + "°C" : "--"; font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.Bold; color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp) }
                            Item { Layout.fillWidth: true }
                            Text { text: "VRAM"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.gpuVramUsed.toFixed(1) + "GB"; font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.8) }
                        }
                    }
                }

                // RAM
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "RAM"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text { text: "TOTAL"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
                        }
                        Canvas {
                            id: ramCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.ramHistory
                            property color lc: SystemMonitorService.usageColor(SystemMonitorService.ramPercent)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(ramCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.ramPercent + "%"; font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.Bold; color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent) }
                            Item { Layout.fillWidth: true }
                            Text { text: "TOTAL"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.ramTotalGb.toFixed(0) + "GB"; font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.8) }
                        }
                    }
                }

                // Network
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        Text {
                            text: "NETWORK"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10 * dw._scale
                            font.weight: Font.DemiBold
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }
                        Canvas {
                            id: netCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 40
                            property var hd: SystemMonitorService.netHistory
                            property color lc: Qt.rgba(0.19, 0.82, 0.35, 0.9)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(netCanvas, hd, lc)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "DOWN"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.netDown; font.family: "Adwaita Sans"; font.pixelSize: 12 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(0.19,0.82,0.35,0.9) }
                            Item { Layout.fillWidth: true }
                            Text { text: "UP"; font.family: "Adwaita Sans"; font.pixelSize: 8 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.netUp; font.family: "Adwaita Sans"; font.pixelSize: 12 * dw._scale; font.weight: Font.Bold; color: Qt.rgba(0.48,0.81,1.0,0.9) }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────
            // v6.16.1: Per-tab detail views (CPU / GPUn / NET)
            // Each is a single large sparkline + big stat readout.
            // Only one is visible at a time (matches the active tab).
            // ─────────────────────────────────────────────────────

            // CPU detail
            Rectangle {
                visible: dw.sysmonActiveTab === "cpu"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    Text {
                        text: SystemMonitorService.cpuName
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12 * dw._scale
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1,1,1,0.9)
                    }

                    Canvas {
                        id: cpuBigCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        property var hd: SystemMonitorService.cpuHistory
                        property color lc: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                        onHdChanged: requestPaint()
                        onPaint: dw.drawSparkline(cpuBigCanvas, hd, lc)
                        visible: parent.visible
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text { text: "TEMP"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            text: SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°C" : "--"
                            font.family: "Adwaita Sans"; font.pixelSize: 20 * dw._scale; font.weight: Font.Bold
                            color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp)
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            text: SystemMonitorService.cpuPercent + "%"
                            font.family: "Adwaita Sans"; font.pixelSize: 20 * dw._scale; font.weight: Font.Bold
                            color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)
                        }
                    }
                }
            }

            // Per-GPU detail (Repeater — one Rectangle per GPU)
            Repeater {
                model: SystemMonitorService.gpuCount
                delegate: Rectangle {
                    required property int index
                    readonly property string tabId: "gpu" + index
                    readonly property var g: SystemMonitorService.gpus[index] || {}
                    visible: dw.sysmonActiveTab === tabId
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: parent.parent.g.name || "GPU " + parent.parent.index
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12 * dw._scale
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1,1,1,0.9)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: (parent.parent.g.type || "").toUpperCase()
                                font.family: "Adwaita Sans"
                                font.pixelSize: 9 * dw._scale
                                font.weight: Font.Bold
                                color: {
                                    const t = parent.parent.g.type
                                    if (t === "nvidia") return "#76b900"
                                    if (t === "amd") return "#ed1c24"
                                    if (t === "intel") return "#0071c5"
                                    return Qt.rgba(1,1,1,0.5)
                                }
                            }
                        }

                        Canvas {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property var hd: parent.parent.g.history || []
                            property color lc: SystemMonitorService.usageColor(parent.parent.g.usage || 0)
                            onHdChanged: requestPaint()
                            onPaint: dw.drawSparkline(this, hd, lc)
                        }

                        // "No metrics" placeholder for secondary GPUs
                        Text {
                            visible: !parent.parent.g.hasMetrics
                            text: "(no live metrics for secondary GPU)"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 10 * dw._scale
                            color: Qt.rgba(1,1,1,0.4)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            visible: parent.parent.g.hasMetrics

                            Text { text: "TEMP"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                            Text {
                                text: (parent.parent.parent.g.temp || 0) > 0 ? (parent.parent.parent.g.temp + "°C") : "--"
                                font.family: "Adwaita Sans"; font.pixelSize: 20 * dw._scale; font.weight: Font.Bold
                                color: SystemMonitorService.tempColor(parent.parent.parent.g.temp || 0)
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                            Text {
                                text: (parent.parent.parent.g.usage || 0) + "%"
                                font.family: "Adwaita Sans"; font.pixelSize: 20 * dw._scale; font.weight: Font.Bold
                                color: SystemMonitorService.usageColor(parent.parent.parent.g.usage || 0)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            visible: parent.parent.g.hasMetrics && (parent.parent.g.vramTotal || 0) > 0

                            Text { text: "VRAM"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                            Text {
                                text: (parent.parent.parent.g.vramUsed || 0).toFixed(1) + " / "
                                      + (parent.parent.parent.g.vramTotal || 0).toFixed(0) + " GB"
                                font.family: "Adwaita Sans"; font.pixelSize: 14 * dw._scale; font.weight: Font.DemiBold
                                color: Qt.rgba(1,1,1,0.85)
                            }
                        }
                    }
                }
            }

            // NET detail
            Rectangle {
                visible: dw.sysmonActiveTab === "net"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Qt.rgba(0.14, 0.14, 0.16, 0.6)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    Text { text: "NETWORK"; font.family: "Adwaita Sans"; font.pixelSize: 12 * dw._scale; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.9) }

                    Canvas {
                        id: netBigCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        property var hd: SystemMonitorService.netHistory
                        property color lc: Qt.rgba(0.19, 0.82, 0.35, 0.9)
                        onHdChanged: requestPaint()
                        onPaint: dw.drawSparkline(netBigCanvas, hd, lc)
                        visible: parent.visible
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text { text: "DOWN"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            text: SystemMonitorService.netDown
                            font.family: "Adwaita Sans"; font.pixelSize: 20 * dw._scale; font.weight: Font.Bold
                            color: Qt.rgba(0.19,0.82,0.35,0.9)
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: "UP"; font.family: "Adwaita Sans"; font.pixelSize: 10 * dw._scale; color: Qt.rgba(1,1,1,0.5) }
                        Text {
                            text: SystemMonitorService.netUp
                            font.family: "Adwaita Sans"; font.pixelSize: 20 * dw._scale; font.weight: Font.Bold
                            color: Qt.rgba(0.48,0.81,1.0,0.9)
                        }
                    }
                }
            }
        }

        Process { id: btopProc; running: false }
    }

    // ═══════════════════════════════════════════════════════════
    // SPARKLINE
    // ═══════════════════════════════════════════════════════════
    function drawSparkline(canvas, data, lineColor) {
        const ctx = canvas.getContext("2d")
        const w = canvas.width
        const h = canvas.height
        if (!ctx || w <= 0 || h <= 0) return
        ctx.clearRect(0, 0, w, h)
        if (!data || data.length < 2) return

        const len = data.length
        const stepX = w / (len - 1)

        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
        ctx.lineWidth = 0.5
        for (let g = 1; g < 4; g++) {
            ctx.beginPath()
            ctx.moveTo(0, h * g / 4)
            ctx.lineTo(w, h * g / 4)
            ctx.stroke()
        }

        const grad = ctx.createLinearGradient(0, 0, 0, h)
        grad.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.25))
        grad.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.02))
        ctx.beginPath()
        ctx.moveTo(0, h)
        for (let i = 0; i < len; i++) {
            ctx.lineTo(i * stepX, h - (Math.min(data[i], 100) / 100) * h)
        }
        ctx.lineTo(w, h)
        ctx.closePath()
        ctx.fillStyle = grad
        ctx.fill()

        ctx.beginPath()
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        for (let i = 0; i < len; i++) {
            const x = i * stepX
            const y = h - (Math.min(data[i], 100) / 100) * h
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
        ctx.stroke()
    }
}
