import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * WidgetsPage v6.11b — Desktop widget configuration
 *
 * v6.11b:
 *   - Clock array: configure N clocks, each with own timezone + 12/24h
 *   - Widget display toggle: Always Primary / All Monitors
 *   - Widget color modes: Default / Theme / Custom
 *   - Position reset
 *   - wala tayo babawasan
 */
ScrollView {
    id: root
    clip: true

    readonly property string configDir: Quickshell.env("HOME") + "/.config/quickshell/zen-shell"
    readonly property string statePath: configDir + "/widgets-state.json"

    // v6.11b: Clock array
    property var clocks: [
        { enabled: true, timezone: "Asia/Manila", format24h: true, label: "Manila" },
        { enabled: false, timezone: "America/Winnipeg", format24h: true, label: "Winnipeg" }
    ]

    property bool weatherEnabled: true
    property string weatherMode: "auto"
    property string weatherLocation: ""
    property bool sysmonEnabled: true

    // v6.11: Widget display
    property string widgetDisplay: "primary"   // "primary" | "all"

    // v6.11: Color mode (TEXT color)
    property string colorMode: "default"
    property string customColor: "#ffffff"

    // v6.16.1.5: Widget background color mode (per widget: weather, sysmon)
    //   "default" → hardcoded near-black Qt.rgba(0.11, 0.11, 0.118, 0.92)
    //   "theme"   → ThemeService.alpha(ThemeService.bg0, 0.88)
    //   "custom"  → user-picked color at bgCustomColor with custom opacity
    // Clock widget is transparent and unaffected by these settings.
    property string weatherBgMode: "default"
    property string weatherBgCustomColor: "#1c1c1e"
    property real   weatherBgOpacity: 0.92
    property string sysmonBgMode: "default"
    property string sysmonBgCustomColor: "#1c1c1e"
    property real   sysmonBgOpacity: 0.92

    // Positions (read from state, edited via drag)
    property real posClockX: 40
    property real posClockY: 60
    property real posWeatherX: -1
    property real posWeatherY: 40
    property real posSysmonX: -1
    property real posSysmonY: 300

    readonly property var timezones: [
        { id: "Asia/Manila", label: "Manila (PHT)" },
        { id: "Asia/Tokyo", label: "Tokyo (JST)" },
        { id: "Asia/Singapore", label: "Singapore (SGT)" },
        { id: "Asia/Hong_Kong", label: "Hong Kong (HKT)" },
        { id: "Asia/Seoul", label: "Seoul (KST)" },
        { id: "Asia/Shanghai", label: "Shanghai (CST)" },
        { id: "Asia/Kolkata", label: "India (IST)" },
        { id: "Asia/Dubai", label: "Dubai (GST)" },
        { id: "Europe/London", label: "London (GMT/BST)" },
        { id: "Europe/Paris", label: "Paris (CET)" },
        { id: "America/New_York", label: "New York (EST)" },
        { id: "America/Chicago", label: "Chicago (CST)" },
        { id: "America/Los_Angeles", label: "Los Angeles (PST)" },
        { id: "America/Winnipeg", label: "Winnipeg (CST)" },
        { id: "America/Toronto", label: "Toronto (EST)" },
        { id: "America/Vancouver", label: "Vancouver (PST)" },
        { id: "Australia/Sydney", label: "Sydney (AEST)" },
        { id: "Pacific/Auckland", label: "Auckland (NZST)" },
        { id: "UTC", label: "UTC" }
    ]

    readonly property var colorModes: [
        { id: "default", label: "Default (White)" },
        { id: "theme", label: "Theme (Auto-sync)" },
        { id: "custom", label: "Custom Color" }
    ]

    readonly property var presetColors: [
        "#ffffff", "#e0e0e0", "#ff453a", "#ff9f0a", "#ffd60a",
        "#30d158", "#64d2ff", "#5e5ce6", "#bf5af2", "#ff375f"
    ]

    function tzIndex(tzId) { for (let i = 0; i < timezones.length; i++) if (timezones[i].id === tzId) return i; return 0 }
    function colorModeIndex(modeId) { for (let i = 0; i < colorModes.length; i++) if (colorModes[i].id === modeId) return i; return 0 }

    // Helper to update a clock in the array
    function updateClock(idx, key, value) {
        let arr = JSON.parse(JSON.stringify(root.clocks))
        if (idx < arr.length) {
            arr[idx][key] = value
            // Auto-set label from timezone
            if (key === "timezone") arr[idx].label = value.split("/").pop().replace(/_/g, " ")
            root.clocks = arr
            root.saveState()
        }
    }

    function saveState() {
        const state = {
            clocks: root.clocks,
            weather: { enabled: weatherEnabled, mode: weatherMode, location: weatherLocation },
            sysmon: { enabled: sysmonEnabled },
            widgetDisplay: widgetDisplay,
            positions: {
                clockX: posClockX, clockY: posClockY,
                weatherX: posWeatherX, weatherY: posWeatherY,
                sysmonX: posSysmonX, sysmonY: posSysmonY
            },
            colorMode: colorMode,
            customColor: customColor,
            // v6.16.1.5: per-widget background colors
            weatherBg: { mode: weatherBgMode, color: weatherBgCustomColor, opacity: weatherBgOpacity },
            sysmonBg:  { mode: sysmonBgMode,  color: sysmonBgCustomColor,  opacity: sysmonBgOpacity }
        }
        stateSaver.command = ["bash", "-c", "mkdir -p '" + configDir + "' && cat > '" + statePath + "' << 'ZENEOF'\n" + JSON.stringify(state, null, 2) + "\nZENEOF"]
        stateSaver.running = true
    }
    Process { id: stateSaver; running: false }

    FileView {
        id: stateLoader; path: root.statePath; blockLoading: false
        onLoaded: {
            try {
                const s = JSON.parse(this.text())

                // v6.11b: Clock array
                if (s.clocks && Array.isArray(s.clocks)) {
                    root.clocks = s.clocks
                } else {
                    // Legacy compat
                    const c1 = s.clock || {}
                    const c2 = s.clock2 || {}
                    root.clocks = [
                        { enabled: c1.enabled !== false, timezone: c1.timezone || "Asia/Manila", format24h: c1.format24h !== false, label: (c1.timezone || "Asia/Manila").split("/").pop().replace(/_/g," ") },
                        { enabled: c2.enabled === true, timezone: c2.timezone || "America/Winnipeg", format24h: c2.format24h !== false, label: (c2.timezone || "America/Winnipeg").split("/").pop().replace(/_/g," ") }
                    ]
                }

                if (s.weather) { if (typeof s.weather.enabled === "boolean") root.weatherEnabled = s.weather.enabled; if (s.weather.mode) root.weatherMode = s.weather.mode; if (s.weather.location) root.weatherLocation = s.weather.location }
                if (s.sysmon) { if (typeof s.sysmon.enabled === "boolean") root.sysmonEnabled = s.sysmon.enabled }
                if (s.widgetDisplay) root.widgetDisplay = s.widgetDisplay
                if (s.positions) {
                    if (typeof s.positions.clockX === "number") root.posClockX = s.positions.clockX
                    if (typeof s.positions.clockY === "number") root.posClockY = s.positions.clockY
                    if (typeof s.positions.weatherX === "number") root.posWeatherX = s.positions.weatherX
                    if (typeof s.positions.weatherY === "number") root.posWeatherY = s.positions.weatherY
                    if (typeof s.positions.sysmonX === "number") root.posSysmonX = s.positions.sysmonX
                    if (typeof s.positions.sysmonY === "number") root.posSysmonY = s.positions.sysmonY
                }
                if (s.colorMode) root.colorMode = s.colorMode
                if (s.customColor) root.customColor = s.customColor

                // v6.16.1.5: per-widget backgrounds
                if (s.weatherBg) {
                    if (s.weatherBg.mode) root.weatherBgMode = s.weatherBg.mode
                    if (s.weatherBg.color) root.weatherBgCustomColor = s.weatherBg.color
                    if (typeof s.weatherBg.opacity === "number") root.weatherBgOpacity = s.weatherBg.opacity
                }
                if (s.sysmonBg) {
                    if (s.sysmonBg.mode) root.sysmonBgMode = s.sysmonBg.mode
                    if (s.sysmonBg.color) root.sysmonBgCustomColor = s.sysmonBg.color
                    if (typeof s.sysmonBg.opacity === "number") root.sysmonBgOpacity = s.sysmonBg.opacity
                }
            } catch (e) {}
        }
    }
    Component.onCompleted: stateLoader.reload()

    readonly property int dropdownWidth: 280

    ColumnLayout {
        width: root.availableWidth - 48; x: 24; y: 24; spacing: 18

        ColumnLayout { Layout.fillWidth: true; spacing: 4
            Text { text: "Desktop Widgets"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: ThemeService.fg }
            Text { text: "Configure clock, weather, and system monitor overlays"; font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
        }

        // ═══════════════════════════════════════════════════════
        // WIDGET DISPLAY
        // ═══════════════════════════════════════════════════════
        HMSection { title: "Widget Display"; subtitle: "Which monitor shows desktop widgets"
            HMRow { label: "Show Widgets On"; description: "Primary monitor only or all monitors"; icon: "\uf108"; separator: false
                ZenComboBox { width: root.dropdownWidth; model: ["Primary Monitor", "All Monitors"]
                    currentIndex: root.widgetDisplay === "primary" ? 0 : 1
                    onActivated: { root.widgetDisplay = currentIndex === 0 ? "primary" : "all"; root.saveState() }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // v6.16.3.7 — WIDGET SCALE
        // ═══════════════════════════════════════════════════════
        // Universal scale multiplier applied to all three desktop
        // widgets (clocks, weather, sysmon) in lockstep. Changes
        // apply live — no shell restart needed — because the
        // _scale property on DesktopWidgets binds to
        // PanelState.widgetScale and every font.pixelSize /
        // container dimension in that file multiplies by it.
        HMSection { title: "Widget Scale"; subtitle: "Resize all desktop widgets in one go"
            HMRow {
                label: "Scale"
                description: "Drag the slider. 0.5× compact, 1.0× baseline, 2.0× large. Reset returns to 1.0×."
                icon: "\uf065"
                separator: false
                RowLayout {
                    spacing: 10
                    Slider {
                        id: scaleSlider
                        Layout.preferredWidth: root.dropdownWidth - 110
                        from: 0.5
                        to: 2.0
                        stepSize: 0.05
                        value: PanelState.widgetScale
                        onMoved: {
                            PanelState.widgetScale = value
                            PanelState.saveState()
                        }
                    }
                    Text {
                        text: scaleSlider.value.toFixed(2) + "×"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                    Button {
                        text: "Reset"
                        onClicked: {
                            PanelState.widgetScale = 1.0
                            PanelState.saveState()
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WIDGET COLOR MODE
        // ═══════════════════════════════════════════════════════
        HMSection { title: "Widget Colors"; subtitle: "Text color mode for desktop widgets"
            HMRow { label: "Color Mode"; description: "Default (white), Theme (auto-sync), or Custom"; icon: "\uf53f"; separator: true
                ZenComboBox { width: root.dropdownWidth; model: { const m=[]; for(const c of root.colorModes) m.push(c.label); return m }
                    currentIndex: root.colorModeIndex(root.colorMode)
                    onActivated: { root.colorMode = root.colorModes[currentIndex].id; root.saveState() }
                }
            }
            HMRow { label: "Custom Color"; description: "Pick a color for widget text"; icon: "\uf1fc"; visible: root.colorMode === "custom"
                RowLayout { spacing: 4
                    Repeater {
                        model: root.presetColors
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.customColor === modelData ? 3 : 1
                            border.color: root.customColor === modelData ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.customColor = modelData; root.saveState() } }
                        }
                    }
                }
            }
            HMRow { label: "Active Theme"; description: "Colors sync from ThemeService automatically"; icon: "\uf1fc"; visible: root.colorMode === "theme"
                RowLayout { spacing: 8
                    Rectangle { width: 20; height: 20; radius: 4; color: ThemeService.fg; border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.3) }
                    Text { text: "Text"; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Rectangle { width: 20; height: 20; radius: 4; color: ThemeService.blue; border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.3) }
                    Text { text: "Accent"; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // v6.16.1.5: WIDGET BACKGROUNDS
        // Per-widget background color + opacity (weather, sysmon).
        // Three modes:
        //   Default — the original hardcoded dark Qt.rgba(0.11, 0.11, 0.118, 0.92)
        //   Theme   — ThemeService.bg0 with configurable opacity
        //   Custom  — user-picked color with custom opacity
        // Clock widget has a transparent bg and isn't affected.
        // ═══════════════════════════════════════════════════════
        HMSection {
            title: "Weather Widget Background"
            subtitle: "Background color + opacity for the weather overlay"

            HMRow { label: "Mode"; description: "Default / Theme-synced / Custom color"; icon: "\uf53f"; separator: true
                ZenComboBox {
                    width: root.dropdownWidth
                    model: ["Default (Dark)", "Theme (Auto-sync)", "Custom Color"]
                    readonly property var ids: ["default", "theme", "custom"]
                    currentIndex: {
                        const idx = ids.indexOf(root.weatherBgMode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: { root.weatherBgMode = ids[currentIndex]; root.saveState() }
                }
            }

            HMRow {
                label: "Custom Color"
                description: "Tap a color to apply"
                icon: "\uf1fc"
                separator: true
                visible: root.weatherBgMode === "custom"
                RowLayout { spacing: 4
                    Repeater {
                        model: ["#1c1c1e", "#2c2c2e", "#3a3a3c", "#1a3a4a",
                                "#2d4a2d", "#4a2d2d", "#4a3a2d", "#3a2d4a",
                                "#5A4F42", "#1e2030"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.weatherBgCustomColor === modelData ? 3 : 1
                            border.color: root.weatherBgCustomColor === modelData
                                ? ThemeService.fg
                                : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.weatherBgCustomColor = modelData; root.saveState() }
                            }
                        }
                    }
                }
            }

            HMRow {
                label: "Theme Preview"
                description: "Current theme background + opacity"
                icon: "\uf1fc"
                separator: true
                visible: root.weatherBgMode === "theme"
                RowLayout { spacing: 8
                    Rectangle {
                        width: 40; height: 24; radius: 4
                        color: ThemeService.alpha(ThemeService.bg0, root.weatherBgOpacity)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.3)
                    }
                    Text {
                        text: (root.weatherBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 11
                        color: ThemeService.grey0
                    }
                }
            }

            HMRow {
                label: "Opacity"
                description: "Transparency of the background (50%–100%)"
                icon: "\uf042"
                visible: root.weatherBgMode !== "default"
                RowLayout { spacing: 8
                    Slider {
                        width: 160
                        from: 0.5; to: 1.0; stepSize: 0.05
                        value: root.weatherBgOpacity
                        onMoved: { root.weatherBgOpacity = value; root.saveState() }
                    }
                    Text {
                        text: (root.weatherBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 12
                        color: ThemeService.fg
                        Layout.preferredWidth: 44
                    }
                }
            }
        }

        HMSection {
            title: "System Monitor Widget Background"
            subtitle: "Background color + opacity for the sysmon overlay"

            HMRow { label: "Mode"; description: "Default / Theme-synced / Custom color"; icon: "\uf53f"; separator: true
                ZenComboBox {
                    width: root.dropdownWidth
                    model: ["Default (Dark)", "Theme (Auto-sync)", "Custom Color"]
                    readonly property var ids: ["default", "theme", "custom"]
                    currentIndex: {
                        const idx = ids.indexOf(root.sysmonBgMode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: { root.sysmonBgMode = ids[currentIndex]; root.saveState() }
                }
            }

            HMRow {
                label: "Custom Color"
                description: "Tap a color to apply"
                icon: "\uf1fc"
                separator: true
                visible: root.sysmonBgMode === "custom"
                RowLayout { spacing: 4
                    Repeater {
                        model: ["#1c1c1e", "#2c2c2e", "#3a3a3c", "#1a3a4a",
                                "#2d4a2d", "#4a2d2d", "#4a3a2d", "#3a2d4a",
                                "#5A4F42", "#1e2030"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.sysmonBgCustomColor === modelData ? 3 : 1
                            border.color: root.sysmonBgCustomColor === modelData
                                ? ThemeService.fg
                                : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.sysmonBgCustomColor = modelData; root.saveState() }
                            }
                        }
                    }
                }
            }

            HMRow {
                label: "Theme Preview"
                description: "Current theme background + opacity"
                icon: "\uf1fc"
                separator: true
                visible: root.sysmonBgMode === "theme"
                RowLayout { spacing: 8
                    Rectangle {
                        width: 40; height: 24; radius: 4
                        color: ThemeService.alpha(ThemeService.bg0, root.sysmonBgOpacity)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.3)
                    }
                    Text {
                        text: (root.sysmonBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 11
                        color: ThemeService.grey0
                    }
                }
            }

            HMRow {
                label: "Opacity"
                description: "Transparency of the background (50%–100%)"
                icon: "\uf042"
                visible: root.sysmonBgMode !== "default"
                RowLayout { spacing: 8
                    Slider {
                        width: 160
                        from: 0.5; to: 1.0; stepSize: 0.05
                        value: root.sysmonBgOpacity
                        onMoved: { root.sysmonBgOpacity = value; root.saveState() }
                    }
                    Text {
                        text: (root.sysmonBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 12
                        color: ThemeService.fg
                        Layout.preferredWidth: 44
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // CLOCKS — Array-based, each clock independently configured
        // ═══════════════════════════════════════════════════════
        Repeater {
            model: root.clocks
            delegate: HMSection {
                required property var modelData
                required property int index
                title: index === 0 ? "Primary Clock" : ("Clock " + (index + 1))
                subtitle: index === 0 ? "Main desktop clock overlay" : "Additional timezone clock"

                HMRow { label: "Enable"; description: "Show this clock on desktop"; icon: "\uf017"; separator: true
                    HMSwitch {
                        checked: modelData.enabled
                        onToggled: root.updateClock(index, "enabled", !modelData.enabled)
                    }
                }
                HMRow { label: "Timezone"; description: modelData.label || "Select timezone"; icon: "\uf0ac"; separator: true
                    ZenComboBox { width: root.dropdownWidth; model: { const m=[]; for(const tz of root.timezones) m.push(tz.label); return m }
                        currentIndex: root.tzIndex(modelData.timezone)
                        onActivated: root.updateClock(index, "timezone", root.timezones[currentIndex].id)
                    }
                }
                HMRow { label: "24-hour format"; description: "14:30 vs 2:30 PM"; icon: "\uf073"
                    HMSwitch {
                        checked: modelData.format24h
                        onToggled: root.updateClock(index, "format24h", !modelData.format24h)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WEATHER
        // ═══════════════════════════════════════════════════════
        HMSection { title: "Weather Widget"; subtitle: "Desktop weather overlay + bar module data"
            HMRow { label: "Enable"; description: "Show weather on desktop"; icon: "\uf0c2"; separator: true
                HMSwitch {
                    checked: root.weatherEnabled
                    onToggled: { root.weatherEnabled = !root.weatherEnabled; root.saveState() }
                }
            }
            HMRow { label: "Location mode"; description: "Auto-detect or manual"; icon: "\uf3c5"; separator: true
                ZenComboBox { width: root.dropdownWidth; model: ["Auto-detect (IP)", "Manual"]
                    currentIndex: root.weatherMode === "auto" ? 0 : 1
                    onActivated: { root.weatherMode = currentIndex === 0 ? "auto" : "manual"; root.saveState() }
                }
            }
            HMRow { label: "Manual location"; description: "City name when mode is Manual"; icon: "\uf279"; separator: true
                Rectangle { width: root.dropdownWidth; height: 32; radius: 8; color: ThemeService.alpha(ThemeService.bg2, 0.6)
                    border.width: 1; border.color: locIn.activeFocus ? ThemeService.alpha(ThemeService.blue, 0.5) : ThemeService.alpha(ThemeService.fg, 0.1)
                    TextInput { id: locIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: Text.AlignVCenter
                        text: root.weatherLocation; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; selectByMouse: true
                        onEditingFinished: { root.weatherLocation = text; root.saveState() }
                        Text { visible: !locIn.text; anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "e.g. Antipolo, Manila, Winnipeg"
                            font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
                    }
                }
            }
            HMRow { label: "Current weather"; description: "Live from WeatherService"; icon: "\uf2c9"
                RowLayout { spacing: 8
                    Text { text: WeatherService.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: ThemeService.aqua }
                    Text { text: WeatherService.temperature + "°C"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: ThemeService.fg }
                    Text { text: WeatherService.condition; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Text { text: "(" + WeatherService.locationName + ")"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1 }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // SYSTEM MONITOR
        // ═══════════════════════════════════════════════════════
        HMSection { title: "System Monitor Widget"; subtitle: "CPU, GPU, RAM, Network overlay with sparkline graphs"
            HMRow { label: "Enable"; description: "Show system stats on desktop"; icon: "\uf080"
                HMSwitch {
                    checked: root.sysmonEnabled
                    onToggled: { root.sysmonEnabled = !root.sysmonEnabled; root.saveState() }
                }
            }
            HMRow { label: "Live stats"; description: "Current system status"; icon: "\uf2db"
                RowLayout { spacing: 10
                    Text { text: "CPU " + SystemMonitorService.cpuPercent + "%"; font.family: Theme.fontFamily; font.pixelSize: 12; color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent) }
                    Text { text: "RAM " + SystemMonitorService.ramUsedGb.toFixed(1) + "G"; font.family: Theme.fontFamily; font.pixelSize: 12; color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent) }
                    Text { visible: SystemMonitorService.gpuTemp > 0; text: "GPU " + SystemMonitorService.gpuTemp + "°"; font.family: Theme.fontFamily; font.pixelSize: 12; color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp) }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WIDGET POSITIONS
        // ═══════════════════════════════════════════════════════
        HMSection { title: "Widget Positions"; subtitle: "Drag widgets on desktop to reposition. Reset to defaults here."
            HMRow { label: "Current positions"; description: "Clock, Weather, System Monitor"; icon: "\uf0b2"
                ColumnLayout { spacing: 4
                    Text { text: "Clock: " + Math.round(root.posClockX) + ", " + Math.round(root.posClockY); font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Text { text: "Weather: " + (root.posWeatherX < 0 ? "auto-right" : Math.round(root.posWeatherX)) + ", " + Math.round(root.posWeatherY); font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Text { text: "SysMon: " + (root.posSysmonX < 0 ? "auto-right" : Math.round(root.posSysmonX)) + ", " + Math.round(root.posSysmonY); font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                }
            }
            HMRow { label: "Reset Positions"; description: "Restore default widget placement"; icon: "\uf0e2"
                Rectangle {
                    width: 120; height: 32; radius: 8
                    color: resetPosHover.containsMouse ? ThemeService.alpha(ThemeService.red, 0.2) : ThemeService.alpha(ThemeService.bg2, 0.6)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.red, 0.3)
                    Text { anchors.centerIn: parent; text: "Reset"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: ThemeService.red }
                    MouseArea { id: resetPosHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.posClockX=40; root.posClockY=60; root.posWeatherX=-1; root.posWeatherY=40; root.posSysmonX=-1; root.posSysmonY=300; root.saveState() }
                    }
                }
            }
        }

        PageFooter { description: "Widget settings auto-save. Desktop overlays read config live. Drag widgets to reposition."
            onResetRequested: {
                root.clocks = [
                    { enabled: true, timezone: "Asia/Manila", format24h: true, label: "Manila" },
                    { enabled: false, timezone: "America/Winnipeg", format24h: true, label: "Winnipeg" }
                ]
                weatherEnabled=true; weatherMode="auto"; weatherLocation=""
                sysmonEnabled=true; widgetDisplay="primary"
                colorMode="default"; customColor="#ffffff"
                posClockX=40; posClockY=60; posWeatherX=-1; posWeatherY=40; posSysmonX=-1; posSysmonY=300
                saveState()
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
