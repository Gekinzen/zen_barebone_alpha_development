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

    // v6.11: Color mode
    property string colorMode: "default"
    property string customColor: "#ffffff"

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
            customColor: customColor
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
                ComboBox { width: root.dropdownWidth; model: ["Primary Monitor", "All Monitors"]
                    currentIndex: root.widgetDisplay === "primary" ? 0 : 1
                    onActivated: { root.widgetDisplay = currentIndex === 0 ? "primary" : "all"; root.saveState() }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WIDGET COLOR MODE
        // ═══════════════════════════════════════════════════════
        HMSection { title: "Widget Colors"; subtitle: "Text color mode for desktop widgets"
            HMRow { label: "Color Mode"; description: "Default (white), Theme (auto-sync), or Custom"; icon: "\uf53f"; separator: true
                ComboBox { width: root.dropdownWidth; model: { const m=[]; for(const c of root.colorModes) m.push(c.label); return m }
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
                    Rectangle { width: 50; height: 26; radius: 13; color: modelData.enabled ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.15); Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle { width: 22; height: 22; radius: 11; x: modelData.enabled ? parent.width - 24 : 2; y: 2; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 150 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.updateClock(index, "enabled", !modelData.enabled) }
                    }
                }
                HMRow { label: "Timezone"; description: modelData.label || "Select timezone"; icon: "\uf0ac"; separator: true
                    ComboBox { width: root.dropdownWidth; model: { const m=[]; for(const tz of root.timezones) m.push(tz.label); return m }
                        currentIndex: root.tzIndex(modelData.timezone)
                        onActivated: root.updateClock(index, "timezone", root.timezones[currentIndex].id)
                    }
                }
                HMRow { label: "24-hour format"; description: "14:30 vs 2:30 PM"; icon: "\uf073"
                    Rectangle { width: 50; height: 26; radius: 13; color: modelData.format24h ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.15); Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle { width: 22; height: 22; radius: 11; x: modelData.format24h ? parent.width - 24 : 2; y: 2; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 150 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.updateClock(index, "format24h", !modelData.format24h) }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WEATHER
        // ═══════════════════════════════════════════════════════
        HMSection { title: "Weather Widget"; subtitle: "Desktop weather overlay + bar module data"
            HMRow { label: "Enable"; description: "Show weather on desktop"; icon: "\uf0c2"; separator: true
                Rectangle { width: 50; height: 26; radius: 13; color: root.weatherEnabled ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.15); Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle { width: 22; height: 22; radius: 11; x: root.weatherEnabled ? parent.width - 24 : 2; y: 2; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 150 } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.weatherEnabled = !root.weatherEnabled; root.saveState() } }
                }
            }
            HMRow { label: "Location mode"; description: "Auto-detect or manual"; icon: "\uf3c5"; separator: true
                ComboBox { width: root.dropdownWidth; model: ["Auto-detect (IP)", "Manual"]
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
                Rectangle { width: 50; height: 26; radius: 13; color: root.sysmonEnabled ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.15); Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle { width: 22; height: 22; radius: 11; x: root.sysmonEnabled ? parent.width - 24 : 2; y: 2; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 150 } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.sysmonEnabled = !root.sysmonEnabled; root.saveState() } }
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
