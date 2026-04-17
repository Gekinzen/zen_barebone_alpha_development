import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * DesktopWidgets v6.11e — Desktop overlay
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
    function _applyPositions() {
        // Guard: don't apply if window hasn't sized yet
        if (dw.width <= 0 || dw.height <= 0) return

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

            // Apply positions imperatively after loading
            _applyPositions()
        } catch (e) {}
    }

    Timer {
        id: posSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            const state = {
                clocks: dw.clocks,
                weather: { enabled: dw.weatherEnabled },
                sysmon: { enabled: dw.sysmonEnabled },
                widgetDisplay: dw.widgetDisplay,
                clockGlow: dw.clockGlow,
                positions: { clockX: dw.clockPosX, clockY: dw.clockPosY, weatherX: dw.weatherPosX, weatherY: dw.weatherPosY, sysmonX: dw.sysmonPosX, sysmonY: dw.sysmonPosY },
                colorMode: dw.colorMode,
                customColor: dw.customColor
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
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: clockWidget
        visible: dw.clocks.length > 0 && dw.clocks[0].enabled
        // NO x: or y: binding here — set imperatively via _applyPositions()
        width: clockLayout.implicitWidth + 40
        height: clockLayout.implicitHeight + 20
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: clockWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - clockWidget.width
            drag.maximumY: dw.height - clockWidget.height
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
                            font.pixelSize: index === 0 ? 120 : 36
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
                        font.pixelSize: 24
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
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: Qt.rgba(dw.widgetTextColor.r, dw.widgetTextColor.g, dw.widgetTextColor.b, 0.7)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }

                    Text {
                        visible: index > 0
                        text: modelData.label || modelData.timezone.split("/").pop().replace(/_/g, " ")
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14
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
        width: 400
        height: 260
        radius: 16
        color: Qt.rgba(0.11, 0.11, 0.118, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        MouseArea {
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: weatherWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - weatherWidget.width
            drag.maximumY: dw.height - weatherWidget.height
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
                        font.pixelSize: 48
                    }

                    Column {
                        spacing: 1

                        Text {
                            text: WeatherService.temperature + "°C"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 42
                            font.weight: Font.ExtraBold
                            color: "#ffffff"
                        }
                        Text {
                            text: WeatherService.locationName
                            font.family: "Adwaita Sans"
                            font.pixelSize: 13
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
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    Text {
                        anchors.right: parent.right
                        text: WeatherService.humidity + "%"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    Text {
                        anchors.right: parent.right
                        text: WeatherService.windSpeed + "km/h"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
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
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
                Text {
                    visible: WeatherService.lastUpdated !== ""
                    text: "Updated " + WeatherService.lastUpdated
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
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
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, index === 0 ? 0.9 : 0.6)
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData.emoji || "☁️"
                                font.pixelSize: 18
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: (modelData.maxTemp !== undefined ? modelData.maxTemp : "--") + "°/" + (modelData.minTemp !== undefined ? modelData.minTemp : "--") + "°"
                                font.family: "Adwaita Sans"
                                font.pixelSize: 10
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
                    font.pixelSize: 11
                    color: Qt.rgba(1, 1, 1, 0.4)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════
    // SYSTEM MONITOR — NO x/y binding, sparklines
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: sysmonWidget
        visible: dw.sysmonEnabled
        // NO x: or y: binding — set imperatively
        width: 340
        height: 380
        radius: 16
        color: Qt.rgba(0.11, 0.11, 0.118, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)

        MouseArea {
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: sysmonWidget
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: dw.width - sysmonWidget.width
            drag.maximumY: dw.height - sysmonWidget.height
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle { width: 3; height: 16; radius: 2; color: "#ff453a" }
                Text {
                    text: "SYSTEM MONITOR"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: SystemMonitorService.cpuName
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.5)
                }
                Text {
                    text: SystemMonitorService.gpuName
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.5)
                }
            }

            GridLayout {
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
                            Text { text: "CPU"; font.family: "Adwaita Sans"; font.pixelSize: 10; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
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
                            Text { text: "TEMP"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.cpuTemp > 0 ? SystemMonitorService.cpuTemp + "°C" : "--"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.Bold; color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp) }
                            Item { Layout.fillWidth: true }
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.cpuPercent + "%"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.Bold; color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent) }
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
                            Text { text: "GPU"; font.family: "Adwaita Sans"; font.pixelSize: 10; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text { text: "VRAM"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
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
                            Text { text: "TEMP"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.gpuTemp > 0 ? SystemMonitorService.gpuTemp + "°C" : "--"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.Bold; color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp) }
                            Item { Layout.fillWidth: true }
                            Text { text: "VRAM"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.gpuVramUsed.toFixed(1) + "GB"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.8) }
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
                            Text { text: "RAM"; font.family: "Adwaita Sans"; font.pixelSize: 10; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.5) }
                            Item { Layout.fillWidth: true }
                            Text { text: "TOTAL"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.DemiBold; color: Qt.rgba(1,1,1,0.3) }
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
                            Text { text: "USAGE"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.ramPercent + "%"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.Bold; color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent) }
                            Item { Layout.fillWidth: true }
                            Text { text: "TOTAL"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.ramTotalGb.toFixed(0) + "GB"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.8) }
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
                            font.pixelSize: 10
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
                            Text { text: "DOWN"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.netDown; font.family: "Adwaita Sans"; font.pixelSize: 12; font.weight: Font.Bold; color: Qt.rgba(0.19,0.82,0.35,0.9) }
                            Item { Layout.fillWidth: true }
                            Text { text: "UP"; font.family: "Adwaita Sans"; font.pixelSize: 8; font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.4) }
                            Text { text: SystemMonitorService.netUp; font.family: "Adwaita Sans"; font.pixelSize: 12; font.weight: Font.Bold; color: Qt.rgba(0.48,0.81,1.0,0.9) }
                        }
                    }
                }
            }
        }
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
