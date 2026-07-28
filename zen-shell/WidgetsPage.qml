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
    // v8.0.0-alpha-hf156 — weather display style (Standard card / Pixel blob)
    property string weatherStyle: "standard"        // standard | pixel
    // Open-state passthrough: DesktopWidgets owns these at runtime; this page only
    // reads them from the state file and writes them back unchanged, so saving a
    // setting here never clobbers whether a widget was left open.
    property bool   openWeatherExpanded: false
    property string openWeatherPixelView: "blob"
    property string openGlanceView: "blob"
    // Settings tabs (v8.0.0-alpha-hf156): home | weather | clock | sysmon
    property string uiTab: "home"
    property bool sysmonEnabled: true
    property string sysmonStyle: "classic"  // hf99ze/zg: classic|pills
    // v7.0.0-beta.1-hf99zh: per-widget font family (resolved family names)
    property string clockFont: "Adwaita Sans"
    property string weatherFont: "Adwaita Sans"
    property string sysmonFont: "Adwaita Sans"
    // v7.0.0-beta.1-hf99zg: Pills card theming
    property string sysmonCardColor: "#f2f2f5"
    property real   sysmonCardOpacity: 1.0
    property string sysmonAccentMode: "multi"     // multi | theme | custom
    property string sysmonAccentColor: "#0a84ff"
    // v7.0.0-beta.1-hf99zi: weather accent
    property string weatherAccentMode: "default"   // default | theme | custom
    property string weatherAccentColor: "#7ab8ff"
    // v8.0.0-alpha-hf113: merged Glance blob
    property bool   glanceMerged: false
    property string glanceSurfaceMode: "default"
    property string glanceSurfaceColor: "#fbede8"
    property real   glanceSurfaceOpacity: 0.96
    property string glanceInkMode: "auto"
    property string glanceInkColor: "#6e2a14"
    property string glanceAccentMode: "default"
    property string glanceAccentColor: "#5dc4e8"
    property string glanceFont: "Adwaita Sans"
    property real   posGlanceX: -1
    property real   posGlanceY: 40

    // v6.11: Widget display — DEPRECATED, kept for legacy state compat
    property string widgetDisplay: "primary"   // "primary" | "all" — legacy only

    // v6.9.3: Per-monitor widget display — array of monitor names
    // e.g. ["HDMI-A-1", "eDP-1"] — widgets show ONLY on these monitors
    property var widgetMonitors: []
    // Auto-detected connected monitors
    property var detectedMonitors: []

    // v6.11: Color mode (TEXT color)
    property string colorMode: "default"
    property string customColor: "#ffffff"

    // v6.16.1.5: Widget background color mode (per widget: weather, sysmon)
    //   "default" → hardcoded near-black Qt.rgba(0.11, 0.11, 0.118, 0.92)
    //   "theme"   → LookService.surfaceColor(ThemeService.bg0, 0.88)
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
    // v7.0.0-beta.1-hf99o: desktop clock design variant (outline/solid/raised/mono)
    property string clockStyle: "outline"
    // v7.0.0-beta.1-hf99y: each clock its own draggable widget vs one group
    property bool independentClocks: false
    // v7.0.0-beta.1-hf99z: per-widget scale multipliers (× global scale)
    property real clockScale: 1.0
    property real weatherScale: 1.0
    property real sysmonScale: 1.0
    // v7.0.0-beta.1-hf99zc: linked = global scale drives all (per-widget
    // sliders disabled); unlinked = per-widget sliders (global disabled).
    property bool linkedScale: true
    property real posWeatherX: -1
    property real posWeatherY: 40
    property real posSysmonX: -1
    property real posSysmonY: 300

    // v8.0.0-alpha-hf111: the FULL IANA list, read from the system (~430 zones,
    // Asia/Qatar included) instead of a hand-picked 20. See TimezoneService.qml.
    readonly property var timezones: TimezoneService.zones

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

    // v7.0.0-beta.1-hf99p: up to 10 desktop clocks.
    readonly property int maxClocks: 10
    function addClock() {
        if (root.clocks.length >= root.maxClocks) return
        let arr = JSON.parse(JSON.stringify(root.clocks))
        arr.push({ enabled: true, timezone: "UTC", format24h: true, label: "UTC" })
        root.clocks = arr
        root.saveState()
    }
    function removeClock(idx) {
        // Primary (index 0) is permanent — it's the main desktop clock.
        if (idx <= 0 || idx >= root.clocks.length) return
        let arr = JSON.parse(JSON.stringify(root.clocks))
        arr.splice(idx, 1)
        root.clocks = arr
        root.saveState()
    }

    function saveState() {
        const state = {
            clocks: root.clocks,
            clockStyle: clockStyle,
            independentClocks: independentClocks,
            clockScale: clockScale,
            weatherScale: weatherScale,
            sysmonScale: sysmonScale,
            sysmonStyle: sysmonStyle,
            clockFont: clockFont,
            weatherFont: weatherFont,
            sysmonFont: sysmonFont,
            sysmonCardColor: sysmonCardColor,
            sysmonCardOpacity: sysmonCardOpacity,
            sysmonAccentMode: sysmonAccentMode,
            sysmonAccentColor: sysmonAccentColor,
            weatherAccentMode: weatherAccentMode,
            weatherAccentColor: weatherAccentColor,
            linkedScale: linkedScale,
            weather: { enabled: weatherEnabled, mode: weatherMode, location: weatherLocation, style: weatherStyle },
            sysmon: { enabled: sysmonEnabled },
            widgetDisplay: widgetDisplay,
            widgetMonitors: widgetMonitors,
            positions: {
                clockX: posClockX, clockY: posClockY,
                weatherX: posWeatherX, weatherY: posWeatherY,
                sysmonX: posSysmonX, sysmonY: posSysmonY,
                glanceX: posGlanceX, glanceY: posGlanceY
            },
            colorMode: colorMode,
            customColor: customColor,
            // v6.16.1.5: per-widget background colors
            weatherBg: { mode: weatherBgMode, color: weatherBgCustomColor, opacity: weatherBgOpacity },
            sysmonBg:  { mode: sysmonBgMode,  color: sysmonBgCustomColor,  opacity: sysmonBgOpacity },
            // v8.0.0-alpha-hf113 — keep in sync with DesktopWidgets posSaveTimer
            glance: {
                merged: glanceMerged,
                surfaceMode: glanceSurfaceMode, surfaceColor: glanceSurfaceColor,
                surfaceOpacity: glanceSurfaceOpacity,
                inkMode: glanceInkMode, inkColor: glanceInkColor,
                accentMode: glanceAccentMode, accentColor: glanceAccentColor,
                font: glanceFont
            },
            // v8.0.0-alpha-hf156 — open-state passthrough (owned by DesktopWidgets)
            open: { weatherExpanded: openWeatherExpanded, weatherPixelView: openWeatherPixelView, glanceView: openGlanceView }
        }
        stateSaver.command = ["bash", "-c", "mkdir -p '" + configDir + "' && cat > '" + statePath + "' << 'ZENEOF'\n" + JSON.stringify(state, null, 2) + "\nZENEOF"]
        stateSaver.running = true
    }
    Process { id: stateSaver; running: false }

    // v6.9.3: Detect connected monitors for per-monitor widget toggles
    Process {
        id: monitorDetector
        command: ["hyprctl", "monitors", "all", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(this.text)
                    let detected = []
                    for (const m of mons) {
                        detected.push({
                            name: m.name,
                            description: m.description || "",
                            width: m.width || 0,
                            height: m.height || 0,
                            disabled: m.disabled || false,
                            focused: m.focused || false
                        })
                    }
                    root.detectedMonitors = detected

                    // If widgetMonitors is empty (first run or legacy),
                    // initialize from widgetDisplay for backward compat
                    if (root.widgetMonitors.length === 0 && detected.length > 0) {
                        if (root.widgetDisplay === "all") {
                            root.widgetMonitors = detected.filter(m => !m.disabled).map(m => m.name)
                        } else {
                            // "primary" — just first monitor
                            root.widgetMonitors = [detected[0].name]
                        }
                    }
                } catch (e) { root.detectedMonitors = [] }
            }
        }
    }

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
                if (typeof s.clockStyle === "string") root.clockStyle = s.clockStyle
                if (typeof s.independentClocks === "boolean") root.independentClocks = s.independentClocks
                if (typeof s.clockScale === "number") root.clockScale = s.clockScale
                if (typeof s.weatherScale === "number") root.weatherScale = s.weatherScale
                if (typeof s.sysmonScale === "number") root.sysmonScale = s.sysmonScale
                if (typeof s.linkedScale === "boolean") root.linkedScale = s.linkedScale

                if (s.weather) { if (typeof s.weather.enabled === "boolean") root.weatherEnabled = s.weather.enabled; if (s.weather.mode) root.weatherMode = s.weather.mode; if (s.weather.location) root.weatherLocation = s.weather.location; if (typeof s.weather.style === "string") root.weatherStyle = s.weather.style }
                // v8.0.0-alpha-hf156 — open-state passthrough (read as-is, written back unchanged)
                if (s.open) { if (typeof s.open.weatherExpanded === "boolean") root.openWeatherExpanded = s.open.weatherExpanded; if (typeof s.open.weatherPixelView === "string") root.openWeatherPixelView = s.open.weatherPixelView; if (typeof s.open.glanceView === "string") root.openGlanceView = s.open.glanceView }
                if (s.sysmon) { if (typeof s.sysmon.enabled === "boolean") root.sysmonEnabled = s.sysmon.enabled }
                if (typeof s.sysmonStyle === "string") root.sysmonStyle = (s.sysmonStyle === "bars" ? "pills" : s.sysmonStyle)
                if (typeof s.clockFont === "string") root.clockFont = s.clockFont
                if (typeof s.weatherFont === "string") root.weatherFont = s.weatherFont
                if (typeof s.sysmonFont === "string") root.sysmonFont = s.sysmonFont
                if (typeof s.sysmonCardColor === "string") root.sysmonCardColor = s.sysmonCardColor
                if (typeof s.sysmonCardOpacity === "number") root.sysmonCardOpacity = s.sysmonCardOpacity
                if (typeof s.sysmonAccentMode === "string") root.sysmonAccentMode = s.sysmonAccentMode
                if (typeof s.sysmonAccentColor === "string") root.sysmonAccentColor = s.sysmonAccentColor
                if (typeof s.weatherAccentMode === "string") root.weatherAccentMode = s.weatherAccentMode
                if (typeof s.weatherAccentColor === "string") root.weatherAccentColor = s.weatherAccentColor
                if (s.widgetDisplay) root.widgetDisplay = s.widgetDisplay
                // v6.9.3: per-monitor array
                if (s.widgetMonitors && Array.isArray(s.widgetMonitors)) root.widgetMonitors = s.widgetMonitors
                if (s.positions) {
                    if (typeof s.positions.clockX === "number") root.posClockX = s.positions.clockX
                    if (typeof s.positions.clockY === "number") root.posClockY = s.positions.clockY
                    if (typeof s.positions.weatherX === "number") root.posWeatherX = s.positions.weatherX
                    if (typeof s.positions.weatherY === "number") root.posWeatherY = s.positions.weatherY
                    if (typeof s.positions.sysmonX === "number") root.posSysmonX = s.positions.sysmonX
                    if (typeof s.positions.sysmonY === "number") root.posSysmonY = s.positions.sysmonY
                    if (typeof s.positions.glanceX === "number") root.posGlanceX = s.positions.glanceX
                    if (typeof s.positions.glanceY === "number") root.posGlanceY = s.positions.glanceY
                }
                // v8.0.0-alpha-hf113
                if (s.glance) {
                    if (typeof s.glance.merged === "boolean")        root.glanceMerged = s.glance.merged
                    if (typeof s.glance.surfaceMode === "string")    root.glanceSurfaceMode = s.glance.surfaceMode
                    if (typeof s.glance.surfaceColor === "string")   root.glanceSurfaceColor = s.glance.surfaceColor
                    if (typeof s.glance.surfaceOpacity === "number") root.glanceSurfaceOpacity = s.glance.surfaceOpacity
                    if (typeof s.glance.inkMode === "string")        root.glanceInkMode = s.glance.inkMode
                    if (typeof s.glance.inkColor === "string")       root.glanceInkColor = s.glance.inkColor
                    if (typeof s.glance.accentMode === "string")     root.glanceAccentMode = s.glance.accentMode
                    if (typeof s.glance.accentColor === "string")    root.glanceAccentColor = s.glance.accentColor
                    if (typeof s.glance.font === "string")           root.glanceFont = s.glance.font
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
    Component.onCompleted: {
        stateLoader.reload()
        // v6.9.3: Detect monitors after state loads (slight delay so
        // widgetDisplay/widgetMonitors are read first for legacy compat)
        Qt.callLater(function() { monitorDetector.running = true })
    }

    readonly property int dropdownWidth: 280

    ColumnLayout {
        width: root.availableWidth - 48; x: 24; y: 24; spacing: 18

        ColumnLayout { Layout.fillWidth: true; spacing: 4
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: "Desktop Widgets"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: ThemeService.fg }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: "Configure clock, weather, and system monitor overlays"; font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
        }

        // ═══════════════════════════════════════════════════════
        // v8.0.0-alpha-hf156 — SECTION TABS (Home / Weather / Clock / Sys Monitor)
        // Keeps the page from getting long: each tab shows only its own sections,
        // gated by `visible: root.uiTab === …` on every HMSection below. Home is
        // the shared band — widget display → widget colors — plus the merge blob
        // and positions. Nothing is removed; sections just group under a tab.
        // ═══════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8
            Repeater {
                model: [
                    { id: "home",    label: "Home" },
                    { id: "weather", label: "Weather" },
                    { id: "clock",   label: "Clock" },
                    { id: "sysmon",  label: "Sys Monitor" }
                ]
                delegate: Rectangle {
                    id: tabPill
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 9
                    property bool active: root.uiTab === modelData.id
                    color: active ? ThemeService.alpha(ThemeService.blue, 0.16) : LookService.surfaceColor(ThemeService.bg2, 0.6)
                    border.width: 1
                    border.color: active ? ThemeService.alpha(ThemeService.blue, 0.5) : ThemeService.alpha(ThemeService.fg, 0.12)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: tabPill.active ? Font.DemiBold : Font.Medium
                        color: tabPill.active ? ThemeService.blue : ThemeService.fg
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.uiTab = modelData.id }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // v6.9.3: WIDGET DISPLAY — Per-monitor toggles
        //
        // Auto-detects all connected monitors via hyprctl.
        // Each monitor gets its own toggle — user picks exactly
        // which monitors show desktop widgets. Replaces the old
        // binary "Primary / All" dropdown.
        // ═══════════════════════════════════════════════════════
        HMSection { visible: root.uiTab === "home"; title: "Widget Display"; subtitle: "Toggle which monitors show desktop widgets"

            // Quick-action buttons
            HMRow { label: "Quick Select"; description: "Select all or primary only"; icon: "\uf108"; separator: true
                RowLayout { spacing: 8
                    Rectangle {
                        width: allLabel.implicitWidth + 20; height: 28; radius: 6
                        color: allMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.2) : LookService.surfaceColor(ThemeService.bg2, 0.5)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.blue, 0.2)
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             id: allLabel; anchors.centerIn: parent; text: "All Monitors"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.blue }
                        MouseArea { id: allMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.widgetMonitors = root.detectedMonitors.filter(function(m) { return !m.disabled }).map(function(m) { return m.name })
                                root.widgetDisplay = "all"
                                root.saveState()
                            }
                        }
                    }
                    Rectangle {
                        width: priLabel.implicitWidth + 20; height: 28; radius: 6
                        color: priMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.1) : LookService.surfaceColor(ThemeService.bg2, 0.5)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             id: priLabel; anchors.centerIn: parent; text: "Primary Only"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.fg }
                        MouseArea { id: priMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.detectedMonitors.length > 0) root.widgetMonitors = [root.detectedMonitors[0].name]
                                root.widgetDisplay = "primary"
                                root.saveState()
                            }
                        }
                    }
                    Rectangle {
                        width: refLabel.implicitWidth + 20; height: 28; radius: 6
                        color: refMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.1) : LookService.surfaceColor(ThemeService.bg2, 0.4)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.08)
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             id: refLabel; anchors.centerIn: parent; text: "\uf021 Refresh"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: ThemeService.grey0 }
                        MouseArea { id: refMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: monitorDetector.running = true
                        }
                    }
                }
            }

            // Per-monitor toggles
            Repeater {
                model: root.detectedMonitors
                delegate: HMRow {
                    required property var modelData
                    required property int index
                    label: modelData.name
                    description: (modelData.description || "Unknown") + "  •  " + modelData.width + "×" + modelData.height + (modelData.disabled ? "  •  Disabled" : "") + (modelData.focused ? "  •  Primary" : "")
                    icon: modelData.focused ? "\uf005" : "\uf26c"
                    separator: index < root.detectedMonitors.length - 1

                    HMSwitch {
                        checked: root.widgetMonitors.indexOf(modelData.name) >= 0
                        activeColor: ThemeService.green
                        enabled: !modelData.disabled
                        opacity: modelData.disabled ? 0.4 : 1.0
                        onToggled: {
                            let arr = root.widgetMonitors.slice()
                            const pos = arr.indexOf(modelData.name)
                            if (pos >= 0) {
                                // Don't allow removing the last monitor
                                if (arr.length <= 1) {
                                    checked = true
                                    return
                                }
                                arr.splice(pos, 1)
                            } else {
                                arr.push(modelData.name)
                            }
                            root.widgetMonitors = arr
                            root.widgetDisplay = "custom"
                            root.saveState()
                        }
                    }
                }
            }

            // Fallback: no monitors detected yet
            HMRow {
                visible: root.detectedMonitors.length === 0
                label: "No monitors detected"
                description: "Click Refresh to detect connected monitors"
                icon: "\uf071"
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
        HMSection { visible: root.uiTab === "home"; title: "Widget Scale"; subtitle: "Resize all desktop widgets in one go"
            HMRow {
                label: "Scale"
                description: "Drag the slider. 0.5× compact (auto-floored to 0.65× for readability), 1.0× baseline, 2.0× large. Reset returns to 1.0×."
                icon: "\uf065"
                separator: false
                opacity: root.linkedScale ? 1.0 : 0.4
                enabled: root.linkedScale
                RowLayout {
                    spacing: 10
                    ZenSlider {
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
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: scaleSlider.value.toFixed(2) + "×"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                                        ZenButton {
                        text: "Reset"
                        onClicked: {
                            PanelState.widgetScale = 1.0
                            PanelState.saveState()
                        }
                    }
                }
            }
        }

        // v7.0.0-beta.1-hf99z: per-widget scale (on top of the global scale)
        // v7.0.0-beta.1-hf99zh: per-widget font family
        HMSection { visible: root.uiTab === "home"; title: "Widget Fonts"; subtitle: "Pick a font for each desktop widget individually"
            HMRow { label: "Clock"; description: "Font for the desktop clock(s)"; iconFont: "Material Symbols Rounded"; icon: "schedule"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: { const m=[]; for (const f of ZenConstants.fontFamilies) m.push(f.label); return m }
                    currentIndex: { for (let i=0;i<ZenConstants.fontFamilies.length;i++) if (ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id) === root.clockFont) return i; return 0 }
                    onActivated: (i) => { root.clockFont = ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id); root.saveState() }
                }
            }
            HMRow { label: "Weather"; description: "Font for the weather widget"; iconFont: "Material Symbols Rounded"; icon: "cloud"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: { const m=[]; for (const f of ZenConstants.fontFamilies) m.push(f.label); return m }
                    currentIndex: { for (let i=0;i<ZenConstants.fontFamilies.length;i++) if (ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id) === root.weatherFont) return i; return 0 }
                    onActivated: (i) => { root.weatherFont = ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id); root.saveState() }
                }
            }
            HMRow { label: "System Monitor"; description: "Font for the system monitor"; iconFont: "Material Symbols Rounded"; icon: "memory"; separator: false
                ZenDropdown {
                    width: root.dropdownWidth
                    model: { const m=[]; for (const f of ZenConstants.fontFamilies) m.push(f.label); return m }
                    currentIndex: { for (let i=0;i<ZenConstants.fontFamilies.length;i++) if (ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id) === root.sysmonFont) return i; return 0 }
                    onActivated: (i) => { root.sysmonFont = ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id); root.saveState() }
                }
            }
        }

        HMSection { visible: root.uiTab === "home"; title: "Per-Widget Scale"; subtitle: "Fine-tune each widget individually (× the global scale)"
            // v7.0.0-beta.1-hf99zc: link mode — ON = global scale controls all
            // (these disabled); OFF = these active, global disabled.
            HMRow { label: "Link all widgets"; description: "On: one global scale for all (sliders below off). Off: size each widget below (global scale off)."; iconFont: "Material Symbols Rounded"; icon: "link"; separator: true
                HMSwitch {
                    checked: root.linkedScale
                    onToggled: { root.linkedScale = checked; root.saveState() }
                }
            }
            HMRow { label: "Clock"; description: "0.5×–2.0×"; icon: "\uf017"; separator: true
                opacity: root.linkedScale ? 0.4 : 1.0
                enabled: !root.linkedScale
                RowLayout {
                    spacing: 10
                    ZenSlider { id: clockScaleSlider; Layout.preferredWidth: root.dropdownWidth - 110; from: 0.5; to: 2.0; stepSize: 0.05; value: root.clockScale; onMoved: { root.clockScale = value; root.saveState() } }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: clockScaleSlider.value.toFixed(2) + "×"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                    ZenButton { text: "Reset"; onClicked: { root.clockScale = 1.0; root.saveState() } }
                }
            }
            HMRow { label: "Weather"; description: "0.5×–2.0×"; icon: "\uf0c2"; separator: true
                opacity: root.linkedScale ? 0.4 : 1.0
                enabled: !root.linkedScale
                RowLayout {
                    spacing: 10
                    ZenSlider { id: weatherScaleSlider; Layout.preferredWidth: root.dropdownWidth - 110; from: 0.5; to: 2.0; stepSize: 0.05; value: root.weatherScale; onMoved: { root.weatherScale = value; root.saveState() } }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: weatherScaleSlider.value.toFixed(2) + "×"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                    ZenButton { text: "Reset"; onClicked: { root.weatherScale = 1.0; root.saveState() } }
                }
            }
            HMRow { label: "System Monitor"; description: "0.5×–2.0×"; iconFont: "Material Symbols Rounded"; icon: "memory"; separator: false
                opacity: root.linkedScale ? 0.4 : 1.0
                enabled: !root.linkedScale
                RowLayout {
                    spacing: 10
                    ZenSlider { id: sysmonScaleSlider; Layout.preferredWidth: root.dropdownWidth - 110; from: 0.5; to: 2.0; stepSize: 0.05; value: root.sysmonScale; onMoved: { root.sysmonScale = value; root.saveState() } }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: sysmonScaleSlider.value.toFixed(2) + "×"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                    ZenButton { text: "Reset"; onClicked: { root.sysmonScale = 1.0; root.saveState() } }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WIDGET COLOR MODE
        // ═══════════════════════════════════════════════════════
        HMSection { visible: root.uiTab === "home"; title: "Widget Colors"; subtitle: "Text color mode for desktop widgets"
            HMRow { label: "Color Mode"; description: "Default (white), Theme (auto-sync), or Custom"; icon: "\uf53f"; separator: true
                ZenDropdown { width: root.dropdownWidth; model: { const m=[]; for(const c of root.colorModes) m.push(c.label); return m }
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
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Text"; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Rectangle { width: 20; height: 20; radius: 4; color: ThemeService.blue; border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.3) }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Accent"; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                }
            }
        }

        // v7.0.0-beta.1-hf99o: desktop clock design variant picker
        HMSection { visible: root.uiTab === "clock"; title: "Clock Design"; subtitle: "Pick a look for the desktop clock"
            HMRow { label: "Style"; description: "Outline, Solid, Raised, Mono, or Analog (Google Pixel style)"; icon: "\uf017"; separator: false
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _styleIds: ["outline","solid","raised","mono","stacked","analog"]
                    model: ["Outline (bold)","Solid","Raised (shadow)","Mono","Stacked (03/28)","Analog (Pixel)"]
                    currentIndex: Math.max(0, _styleIds.indexOf(root.clockStyle))
                    onActivated: (i) => { root.clockStyle = _styleIds[i]; root.saveState() }
                }
            }
            // v7.0.0-beta.1-hf99y: independent draggable clocks
            HMRow { label: "Independent clocks"; description: "Each clock is its own draggable widget (drag them anywhere) instead of one stacked group"; iconFont: "Material Symbols Rounded"; icon: "drag_pan"; separator: false
                HMSwitch {
                    checked: root.independentClocks
                    onToggled: { root.independentClocks = checked; root.saveState() }
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

        // ═══════════════════════════════════════════════════════
        // CLOCKS — Array-based, each clock independently configured
        // ═══════════════════════════════════════════════════════
        Repeater {
            model: root.clocks
            delegate: HMSection {
                visible: root.uiTab === "clock"
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
                    ZenDropdown { width: root.dropdownWidth; model: { const m=[]; for(const tz of root.timezones) m.push(tz.label); return m }
                        currentIndex: root.tzIndex(modelData.timezone)
                        // v7.0.0-beta.1-hf99q: use the emitted index, not the
                        // dropdown's currentIndex (which raced the binding and
                        // sometimes left the tz unchanged).
                        onActivated: (tzi) => root.updateClock(index, "timezone", root.timezones[tzi].id)
                    }
                }
                // v7.0.0-beta.1-hf99zb: per-clock style (Inherit = follow global)
                HMRow { label: "Style"; description: "This clock's design (Inherit = follow the global Clock Design)"; icon: "\uf017"; separator: true
                    ZenDropdown {
                        width: root.dropdownWidth
                        property var _cids: ["inherit","outline","solid","raised","mono","stacked","analog"]
                        model: ["Inherit (global)","Outline","Solid","Raised","Mono","Stacked (03/28)","Analog (Pixel)"]
                        currentIndex: Math.max(0, _cids.indexOf(modelData.style || "inherit"))
                        onActivated: (i) => root.updateClock(index, "style", _cids[i])
                    }
                }
                // v7.0.0-beta.1-hf99u: per-clock custom display name (secondaries)
                HMRow { visible: index > 0; label: "Custom name"; description: "Shown under the time (blank = auto from timezone)"; icon: "\uf02b"; separator: true
                    TextField {
                        Layout.preferredWidth: 150
                        placeholderText: modelData.timezone.split("/").pop().replace(/_/g, " ")
                        text: modelData.name || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle {
                            radius: 6
                            color: LookService.surfaceColor(ThemeService.bg2, 0.6)
                            border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                            border.width: 1
                        }
                        onEditingFinished: root.updateClock(index, "name", text)
                    }
                }
                HMRow { label: "24-hour format"; description: "14:30 vs 2:30 PM"; icon: "\uf073"; separator: index > 0
                    HMSwitch {
                        checked: modelData.format24h
                        onToggled: root.updateClock(index, "format24h", !modelData.format24h)
                    }
                }
                // v7.0.0-beta.1-hf99p: remove (primary clock is permanent)
                HMRow { visible: index > 0; label: "Remove this clock"; description: "Delete " + (modelData.label || "clock"); icon: "\uf2ed"
                    Rectangle {
                        width: 90; height: 28; radius: 7
                        color: rmMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.25) : ThemeService.alpha(ThemeService.red, 0.12)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.red, 0.4)
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             anchors.centerIn: parent; text: "Remove"; color: ThemeService.red; font.pixelSize: 11; font.family: Theme.fontFamily }
                        MouseArea { id: rmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeClock(index) }
                    }
                }
            }
        }

        // v7.0.0-beta.1-hf99p: Add clock (up to root.maxClocks = 10)
        HMSection { visible: root.uiTab === "clock" && root.clocks.length < root.maxClocks; title: "Add Clock"; subtitle: "Up to " + root.maxClocks + " desktop clocks / timezones"
            HMRow { label: "New timezone clock"; description: root.clocks.length + " of " + root.maxClocks + " used"; icon: "\uf017"; separator: false
                Rectangle {
                    width: 90; height: 28; radius: 7
                    color: addMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.25) : ThemeService.alpha(ThemeService.blue, 0.12)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "+ Add"; color: ThemeService.blue; font.pixelSize: 11; font.family: Theme.fontFamily }
                    MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.addClock() }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WEATHER
        // ═══════════════════════════════════════════════════════
        // ═══════════════════════════════════════════════════════
        // GLANCE — merged weather + system blob (v8.0.0-alpha-hf113)
        // ═══════════════════════════════════════════════════════
        HMSection { visible: root.uiTab === "home"; title: "Glance Widget"; subtitle: "Merge weather and system monitor into one Pixel-style blob"

            HMRow { label: "Merge widgets"
                    description: "One blob with a cloud / thermostat switcher. Off: separate weather + system overlays."
                    iconFont: "Material Symbols Rounded"; icon: "join_inner"; separator: true
                HMSwitch {
                    checked: root.glanceMerged
                    onToggled: { root.glanceMerged = !root.glanceMerged; root.saveState() }
                }
            }

            HMRow { visible: root.glanceMerged; label: "Font"; description: "Type family for the blob"
                    iconFont: "Material Symbols Rounded"; icon: "text_fields"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: { const m=[]; for (const f of ZenConstants.fontFamilies) m.push(f.label); return m }
                    currentIndex: { for (let i=0;i<ZenConstants.fontFamilies.length;i++) if (ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id) === root.glanceFont) return i; return 0 }
                    onActivated: (i) => { root.glanceFont = ZenConstants.fontPrimary(ZenConstants.fontFamilies[i].id); root.saveState() }
                }
            }

            HMRow { visible: root.glanceMerged; label: "Surface"
                    description: "Blob background — Default is Pixel porcelain, Theme follows the active look"
                    iconFont: "Material Symbols Rounded"; icon: "format_color_fill"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _gids: ["default","theme","custom"]
                    model: ["Default (porcelain)","Theme (auto-sync)","Custom color"]
                    currentIndex: Math.max(0, _gids.indexOf(root.glanceSurfaceMode))
                    onActivated: (i) => { root.glanceSurfaceMode = _gids[i]; root.saveState() }
                }
            }

            HMRow { visible: root.glanceMerged && root.glanceSurfaceMode === "custom"
                    label: "Surface color"; description: "Text auto-contrasts against whatever you pick"; separator: true
                RowLayout { spacing: 4
                    Repeater {
                        model: ["#fbede8", "#f6f1e8", "#ffffff", "#e8e6e1", "#1c1c1e",
                                "#24283b", "#16211b", "#221913", "#16161f", "#2d2438"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.glanceSurfaceColor === modelData ? 3 : 1
                            border.color: root.glanceSurfaceColor === modelData ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.glanceSurfaceColor = modelData; root.saveState() } }
                        }
                    }
                    TextField {
                        Layout.preferredWidth: 84
                        placeholderText: "#fbede8"
                        text: root.glanceSurfaceColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                        onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.glanceSurfaceColor = text; root.saveState() } else { text = root.glanceSurfaceColor } }
                    }
                }
            }

            HMRow { visible: root.glanceMerged; label: "Text color"
                    description: "Auto derives ink from the surface's own hue — sienna on porcelain, pale on dark"
                    iconFont: "Material Symbols Rounded"; icon: "palette"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _gids: ["auto","theme","custom"]
                    model: ["Auto (contrast)","Theme (auto-sync)","Custom color"]
                    currentIndex: Math.max(0, _gids.indexOf(root.glanceInkMode))
                    onActivated: (i) => { root.glanceInkMode = _gids[i]; root.saveState() }
                }
            }

            HMRow { visible: root.glanceMerged && root.glanceInkMode === "custom"
                    label: "Text hex"; description: "Used verbatim — check contrast yourself"; separator: true
                TextField {
                    Layout.preferredWidth: 96
                    placeholderText: "#6e2a14"
                    text: root.glanceInkColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.fg
                    background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                    onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.glanceInkColor = text; root.saveState() } else { text = root.glanceInkColor } }
                }
            }

            HMRow { visible: root.glanceMerged; label: "Accent color"
                    description: "Weather glyph, rain probability, meter fills"
                    iconFont: "Material Symbols Rounded"; icon: "colorize"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _gids: ["default","theme","custom"]
                    model: ["Default (rain blue)","Theme (auto-sync)","Custom color"]
                    currentIndex: Math.max(0, _gids.indexOf(root.glanceAccentMode))
                    onActivated: (i) => { root.glanceAccentMode = _gids[i]; root.saveState() }
                }
            }

            HMRow { visible: root.glanceMerged && root.glanceAccentMode === "custom"
                    label: "Accent hex"; description: "Swatch or hex"
                RowLayout { spacing: 4
                    Repeater {
                        model: root.presetColors
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                            color: modelData
                            border.width: root.glanceAccentColor === modelData ? 3 : 1
                            border.color: root.glanceAccentColor === modelData ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.glanceAccentColor = modelData; root.saveState() } }
                        }
                    }
                }
            }
        }

        HMSection { visible: root.uiTab === "weather"; title: "Weather Widget"; subtitle: "Desktop weather overlay + bar module data"
            HMRow { label: "Enable"; description: "Show weather on desktop"; icon: "\uf0c2"; separator: true
                HMSwitch {
                    checked: root.weatherEnabled
                    onToggled: { root.weatherEnabled = !root.weatherEnabled; root.saveState() }
                }
            }
            // v8.0.0-alpha-hf156 — Standard card vs weather-only Pixel blob
            HMRow { label: "Style"; description: "Standard card, or a Pixel-style blob. The blob is weather-only — the system monitor stays separate and only joins it in the merged Glance."; iconFont: "Material Symbols Rounded"; icon: "widgets"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _wids: ["standard","pixel"]
                    model: ["Standard card","Pixel blob"]
                    currentIndex: Math.max(0, _wids.indexOf(root.weatherStyle))
                    onActivated: (i) => { root.weatherStyle = _wids[i]; root.saveState() }
                }
            }
            // v7.0.0-beta.1-hf99zi: weather accent colour
            HMRow { label: "Accent color"; description: "Default, Theme-synced, or a custom colour (temperature, rain %, today card)"; iconFont: "Material Symbols Rounded"; icon: "palette"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _wids: ["default","theme","custom"]
                    model: ["Default (blue)","Theme (auto-sync)","Custom"]
                    currentIndex: Math.max(0, _wids.indexOf(root.weatherAccentMode))
                    onActivated: (i) => { root.weatherAccentMode = _wids[i]; root.saveState() }
                }
            }
            HMRow { visible: root.weatherAccentMode === "custom"; label: "Custom accent"; description: "Tap a swatch or type a hex code"; iconFont: "Material Symbols Rounded"; icon: "colorize"; separator: true
                RowLayout { spacing: 4
                    Repeater {
                        model: ["#7ab8ff", "#30d158", "#ff453a", "#bf5af0", "#ff9f0a",
                                "#64d2ff", "#ff375f", "#5e5ce6", "#ea580c", "#f2f2f5"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.weatherAccentColor === modelData ? 3 : 1
                            border.color: root.weatherAccentColor === modelData ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.weatherAccentColor = modelData; root.saveState() } }
                        }
                    }
                    TextField {
                        Layout.preferredWidth: 84
                        placeholderText: "#7ab8ff"
                        text: root.weatherAccentColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                        onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.weatherAccentColor = text; root.saveState() } else { text = root.weatherAccentColor } }
                    }
                }
            }
            HMRow { label: "Location mode"; description: "Auto-detect or manual"; icon: "\uf3c5"; separator: true
                ZenDropdown { width: root.dropdownWidth; model: ["Auto-detect (IP)", "Manual"]
                    currentIndex: root.weatherMode === "auto" ? 0 : 1
                    onActivated: {
                        root.weatherMode = currentIndex === 0 ? "auto" : "manual"
                        root.saveState()
                        // v7.0.0-beta.1-hf2: bridge to WeatherService so the
                        // change actually takes effect. Was previously only
                        // saving to WidgetsPage state — WeatherService never
                        // got the memo, so "Antipolo" in the input did nothing.
                        WeatherService.locationMode = root.weatherMode
                        if (root.weatherMode === "manual" && root.weatherLocation.length > 0) {
                            WeatherService.manualLocation = root.weatherLocation
                        }
                        WeatherService.saveConfig()
                        WeatherService.refresh()
                    }
                }
            }
            HMRow { label: "Manual location"; description: "City name when mode is Manual"; icon: "\uf279"; separator: true
                Rectangle { width: root.dropdownWidth; height: 32; radius: 8; color: LookService.surfaceColor(ThemeService.bg2, 0.6)
                    border.width: 1; border.color: locIn.activeFocus ? ThemeService.alpha(ThemeService.blue, 0.5) : ThemeService.alpha(ThemeService.fg, 0.1)
                    TextInput { id: locIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: Text.AlignVCenter
                        text: root.weatherLocation; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; selectByMouse: true
                        onEditingFinished: {
                            root.weatherLocation = text
                            root.saveState()
                            // v7.0.0-beta.1-hf2: push to WeatherService + force refresh.
                            // Auto-flip mode to "manual" since the user clearly wants
                            // to use the typed city.
                            if (text.length > 0) {
                                WeatherService.manualLocation = text
                                WeatherService.locationMode = "manual"
                                root.weatherMode = "manual"
                                WeatherService.saveConfig()
                                WeatherService.refresh()
                            }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             visible: !locIn.text; anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "e.g. Antipolo, Manila, Winnipeg"
                            font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
                    }
                }
            }
            HMRow { label: "Current weather"; description: "Live from WeatherService"; icon: "\uf2c9"
                RowLayout { spacing: 8
                    // hf131: preview what the bar/dock will actually draw, in
                    // the style that is actually selected.
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: PanelState.weatherIconStyle === "emoji" ? WeatherService.emojiIconLive
                            : PanelState.weatherIconStyle === "nerd"  ? WeatherService.nerdIcon
                            :                                           WeatherService.materialIcon
                        font.family: PanelState.weatherIconStyle === "emoji" ? Theme.fontFamily
                                   : PanelState.weatherIconStyle === "nerd"  ? "JetBrainsMono Nerd Font"
                                   :                                           "Material Symbols Rounded"
                        font.pixelSize: 16
                        color: PanelState.weatherIconStyle === "emoji" ? ThemeService.fg
                             : PanelState.weatherIconTint !== "accent"  ? WeatherService.iconTint
                             :                                            ThemeService.aqua
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.temperature + "°C"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: ThemeService.fg }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.condition; font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "(" + WeatherService.locationName + ")"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1 }
                }
            }
        }

        // v8.0.0-alpha-hf125 — moved here from between Clock Design and
        // Glance Widget, ~400 lines above its own widget's section. It was
        // a real HMSection all along; nobody could find it.
        HMSection {
            visible: root.uiTab === "weather"
            title: "Weather Widget Background"
            subtitle: "Background color + opacity for the weather overlay"

            HMRow { label: "Mode"; description: "Default / Theme-synced / Custom color / None (no background)"; iconFont: "Material Symbols Rounded"; icon: "palette"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["Default (Dark)", "Theme (Auto-sync)", "Custom Color", "None (transparent)"]
                    readonly property var ids: ["default", "theme", "custom", "none"]
                    currentIndex: {
                        const idx = ids.indexOf(root.weatherBgMode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: { root.weatherBgMode = ids[currentIndex]; root.saveState() }
                }
            }

            HMRow {
                label: "Custom Color"
                description: "Tap a swatch or type a hex code"
                iconFont: "Material Symbols Rounded"; icon: "format_color_fill"
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
                    TextField {
                        Layout.preferredWidth: 84
                        placeholderText: "#1c1c1e"
                        text: root.weatherBgCustomColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                        onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.weatherBgCustomColor = text; root.saveState() } else { text = root.weatherBgCustomColor } }
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
                        color: LookService.surfaceColor(ThemeService.bg0, root.weatherBgOpacity)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.3)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: (root.weatherBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 11
                        color: ThemeService.grey0
                    }
                }
            }

            HMRow {
                label: "Opacity"
                description: "Transparency of the background (0% = none)"
                iconFont: "Material Symbols Rounded"; icon: "opacity"
                visible: root.weatherBgMode !== "default"
                RowLayout { spacing: 8
                    ZenSlider {
                        width: 160
                        from: 0.0; to: 1.0; stepSize: 0.05
                        value: root.weatherBgOpacity
                        onMoved: { root.weatherBgOpacity = value; root.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: (root.weatherBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 12
                        color: ThemeService.fg
                        Layout.preferredWidth: 44
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // SYSTEM MONITOR
        // ═══════════════════════════════════════════════════════
        HMSection { visible: root.uiTab === "sysmon"; title: "System Monitor Widget"; subtitle: "CPU, GPU, RAM, Network overlay with sparkline graphs"
            HMRow { label: "Enable"; description: "Show system stats on desktop"; icon: "\uf080"
                HMSwitch {
                    checked: root.sysmonEnabled
                    onToggled: { root.sysmonEnabled = !root.sysmonEnabled; root.saveState() }
                }
            }
            // v7.0.0-beta.1-hf99ze: system monitor design picker
            HMRow { label: "Design"; description: "Classic (tabs + graphs) or Pills (Pixel capsule cards)"; iconFont: "Material Symbols Rounded"; icon: "dashboard"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _sids: ["classic","pills"]
                    model: ["Classic (graphs)","Pills (Pixel)"]
                    currentIndex: Math.max(0, _sids.indexOf(root.sysmonStyle))
                    onActivated: (i) => { root.sysmonStyle = _sids[i]; root.saveState() }
                }
            }

            // v7.0.0-beta.1-hf99zg: Pills card theming
            HMRow { visible: root.sysmonStyle === "pills"; label: "Card color"; description: "Capsule card background — swatch or hex (text auto-contrasts)"; iconFont: "Material Symbols Rounded"; icon: "format_color_fill"; separator: true
                RowLayout { spacing: 4
                    Repeater {
                        model: ["#f2f2f5", "#ffffff", "#e8e6e1", "#1c1c1e", "#2c2c2e",
                                "#1e2030", "#243447", "#2d4a2d", "#4a2d2d", "#3a2d4a"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.sysmonCardColor === modelData ? 3 : 1
                            border.color: root.sysmonCardColor === modelData ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.sysmonCardColor = modelData; root.saveState() } }
                        }
                    }
                    TextField {
                        Layout.preferredWidth: 84
                        placeholderText: "#f2f2f5"
                        text: root.sysmonCardColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                        onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.sysmonCardColor = text; root.saveState() } else { text = root.sysmonCardColor } }
                    }
                }
            }
            HMRow { visible: root.sysmonStyle === "pills"; label: "Card opacity"; description: "0% = fully transparent cards (text switches to widget colour)"; iconFont: "Material Symbols Rounded"; icon: "opacity"; separator: true
                RowLayout { spacing: 10
                    ZenSlider { id: cardOpSlider; Layout.preferredWidth: root.dropdownWidth - 90; from: 0.0; to: 1.0; stepSize: 0.05; value: root.sysmonCardOpacity; onMoved: { root.sysmonCardOpacity = value; root.saveState() } }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: Math.round(cardOpSlider.value * 100) + "%"; color: ThemeService.fg; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                }
            }
            HMRow { label: "Accent colors"; description: "Multi (per-metric), Theme-synced, or one custom color — applies to Pills and the Classic header"; iconFont: "Material Symbols Rounded"; icon: "palette"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    property var _aids: ["multi","theme","custom"]
                    model: ["Multi (per-metric)","Theme (auto-sync)","Custom (single)"]
                    currentIndex: Math.max(0, _aids.indexOf(root.sysmonAccentMode))
                    onActivated: (i) => { root.sysmonAccentMode = _aids[i]; root.saveState() }
                }
            }
            HMRow { visible: root.sysmonAccentMode === "custom"; label: "Accent color"; description: "Tap a swatch or type a hex code"; iconFont: "Material Symbols Rounded"; icon: "colorize"; separator: true
                RowLayout { spacing: 4
                    Repeater {
                        model: ["#0a84ff", "#30d158", "#ff453a", "#bf5af0", "#ff9f0a",
                                "#64d2ff", "#ff375f", "#5e5ce6", "#ea580c", "#1e8e3e"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                            color: modelData
                            border.width: root.sysmonAccentColor === modelData ? 3 : 1
                            border.color: root.sysmonAccentColor === modelData ? ThemeService.fg : ThemeService.alpha(ThemeService.fg, 0.3)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.sysmonAccentColor = modelData; root.saveState() } }
                        }
                    }
                    TextField {
                        Layout.preferredWidth: 84
                        placeholderText: "#0a84ff"
                        text: root.sysmonAccentColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                        onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.sysmonAccentColor = text; root.saveState() } else { text = root.sysmonAccentColor } }
                    }
                }
            }
            HMRow { label: "Live stats"; description: "Current system status"; icon: "\uf2db"
                RowLayout { spacing: 10
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "CPU " + SystemMonitorService.cpuPercent + "%"; font.family: Theme.fontFamily; font.pixelSize: 12; color: SystemMonitorService.usageColor(SystemMonitorService.cpuPercent) }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "RAM " + SystemMonitorService.ramUsedGb.toFixed(1) + "G"; font.family: Theme.fontFamily; font.pixelSize: 12; color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent) }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         visible: SystemMonitorService.gpuTemp > 0; text: "GPU " + SystemMonitorService.gpuTemp + "°"; font.family: Theme.fontFamily; font.pixelSize: 12; color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp) }
                }
            }
        }

        // v8.0.0-alpha-hf125 — moved to sit under its own widget.
        HMSection {
            visible: root.uiTab === "sysmon"
            title: "System Monitor Widget Background"
            subtitle: "Background color + opacity for the sysmon overlay"

            HMRow { label: "Mode"; description: "Default / Theme-synced / Custom color / None (no background)"; iconFont: "Material Symbols Rounded"; icon: "palette"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["Default (Dark)", "Theme (Auto-sync)", "Custom Color", "None (transparent)"]
                    readonly property var ids: ["default", "theme", "custom", "none"]
                    currentIndex: {
                        const idx = ids.indexOf(root.sysmonBgMode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: { root.sysmonBgMode = ids[currentIndex]; root.saveState() }
                }
            }

            HMRow {
                label: "Custom Color"
                description: "Tap a swatch or type a hex code"
                iconFont: "Material Symbols Rounded"; icon: "format_color_fill"
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
                    TextField {
                        Layout.preferredWidth: 84
                        placeholderText: "#1c1c1e"
                        text: root.sysmonBgCustomColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        background: Rectangle { radius: 6; color: LookService.surfaceColor(ThemeService.bg2, 0.6); border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.2) }
                        onEditingFinished: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { root.sysmonBgCustomColor = text; root.saveState() } else { text = root.sysmonBgCustomColor } }
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
                        color: LookService.surfaceColor(ThemeService.bg0, root.sysmonBgOpacity)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.3)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: (root.sysmonBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 11
                        color: ThemeService.grey0
                    }
                }
            }

            HMRow {
                label: "Opacity"
                description: "Transparency of the background (0% = none)"
                iconFont: "Material Symbols Rounded"; icon: "opacity"
                visible: root.sysmonBgMode !== "default"
                RowLayout { spacing: 8
                    ZenSlider {
                        width: 160
                        from: 0.0; to: 1.0; stepSize: 0.05
                        value: root.sysmonBgOpacity
                        onMoved: { root.sysmonBgOpacity = value; root.saveState() }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: (root.sysmonBgOpacity * 100).toFixed(0) + "%"
                        font.family: Theme.fontFamily; font.pixelSize: 12
                        color: ThemeService.fg
                        Layout.preferredWidth: 44
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // WIDGET POSITIONS
        // ═══════════════════════════════════════════════════════
        HMSection { visible: root.uiTab === "home"; title: "Widget Positions"; subtitle: "Drag widgets on desktop to reposition. Reset to defaults here."
            HMRow { label: "Current positions"; description: "Clock, Weather, System Monitor"; icon: "\uf0b2"
                ColumnLayout { spacing: 4
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Clock: " + Math.round(root.posClockX) + ", " + Math.round(root.posClockY); font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Weather: " + (root.posWeatherX < 0 ? "auto-right" : Math.round(root.posWeatherX)) + ", " + Math.round(root.posWeatherY); font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "SysMon: " + (root.posSysmonX < 0 ? "auto-right" : Math.round(root.posSysmonX)) + ", " + Math.round(root.posSysmonY); font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.grey0 }
                }
            }
            HMRow { label: "Reset Positions"; description: "Restore default widget placement"; icon: "\uf0e2"
                Rectangle {
                    width: 120; height: 32; radius: 8
                    color: resetPosHover.containsMouse ? ThemeService.alpha(ThemeService.red, 0.2) : LookService.surfaceColor(ThemeService.bg2, 0.6)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.red, 0.3)
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         anchors.centerIn: parent; text: "Reset"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: ThemeService.red }
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
                widgetMonitors = detectedMonitors.length > 0 ? [detectedMonitors[0].name] : []
                colorMode="default"; customColor="#ffffff"
                posClockX=40; posClockY=60; posWeatherX=-1; posWeatherY=40; posSysmonX=-1; posSysmonY=300
                glanceMerged=false; glanceSurfaceMode="default"; glanceSurfaceColor="#fbede8"
                glanceInkMode="auto"; glanceAccentMode="default"; glanceFont="Adwaita Sans"
                posGlanceX=-1; posGlanceY=40
                saveState()
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
