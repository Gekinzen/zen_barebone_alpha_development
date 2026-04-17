pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * WeatherService — weather data provider for bar + desktop widgets
 *
 * v6.8: Pure QML replacement for Python weather_widget.py.
 * Uses Open-Meteo (free, no API key) + ipapi.co for auto-location.
 * Caches to JSON, refreshes every 30 minutes.
 *
 * Bar modules bind to: temperature, condition, icon, humidity, wind, forecasts
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: home + "/.config/quickshell/zen-shell"
    readonly property string cachePath: home + "/.cache/zen-shell/weather.json"
    readonly property string configPath: configDir + "/weather-state.json"

    // ── Current weather data (bar modules bind to these) ──
    property int temperature: 0           // °C
    property int feelsLike: 0
    property string condition: "Loading..."
    property string icon: "\uf0c2"        // cloud nerd icon
    property int humidity: 0
    property int windSpeed: 0             // km/h
    property string locationName: "Detecting..."

    // ── Forecast (7 days) ──
    property var forecast: []   // [{ day, icon, maxTemp, minTemp }]

    // ── Config ──
    property string locationMode: "auto"  // "auto" | "manual"
    property string manualLocation: ""
    property real lat: 0
    property real lon: 0
    property bool loading: false
    property string lastUpdated: ""

    // ── Emoji icon for desktop widget (separate from nerd font for bar) ──
    property string emojiIcon: "🌡️"

    // ── WMO weather code → emoji mapping (for desktop widgets) ──
    function wmoEmoji(code) {
        const map = {
            0: "☀️", 1: "🌤️", 2: "⛅", 3: "☁️",
            45: "🌫️", 48: "🌫️",
            51: "🌧️", 53: "🌧️", 55: "🌧️",
            56: "🌧️", 57: "🌧️",
            61: "🌧️", 63: "🌧️", 65: "🌧️",
            66: "🌧️", 67: "🌧️",
            71: "🌨️", 73: "🌨️", 75: "❄️", 77: "🌨️",
            80: "🌦️", 81: "🌦️", 82: "🌧️",
            85: "🌨️", 86: "❄️",
            95: "⛈️", 96: "⛈️", 99: "⛈️"
        }
        return map[code] || "☁️"
    }

    // ── WMO weather code → icon + condition mapping ──
    function wmoIcon(code) {
        const map = {
            0: "\uf00d",  // clear
            1: "\uf00c",  // mainly clear
            2: "\uf002",  // partly cloudy
            3: "\uf013",  // overcast
            45: "\uf014", // fog
            48: "\uf014",
            51: "\uf01a", // drizzle
            53: "\uf01a", 55: "\uf019",
            61: "\uf019", // rain
            63: "\uf019", 65: "\uf018",
            71: "\uf01b", // snow
            73: "\uf01b", 75: "\uf076",
            80: "\uf01a", // showers
            81: "\uf019", 82: "\uf018",
            95: "\uf01e", // thunderstorm
            96: "\uf01e", 99: "\uf01e"
        }
        return map[code] || "\uf03e"
    }

    function wmoCondition(code) {
        const map = {
            0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Overcast",
            45: "Fog", 48: "Fog",
            51: "Light Drizzle", 53: "Drizzle", 55: "Heavy Drizzle",
            61: "Light Rain", 63: "Rain", 65: "Heavy Rain",
            71: "Light Snow", 73: "Snow", 75: "Heavy Snow",
            80: "Showers", 81: "Showers", 82: "Heavy Showers",
            95: "Thunderstorm", 96: "Thunderstorm", 99: "Severe Storm"
        }
        return map[code] || "Unknown"
    }

    // ── Auto-refresh every 30 min ──
    Timer {
        interval: 1800000  // 30 min
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    // ── Location detection ──
    Process {
        id: locationDetector
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    if (data.latitude && data.longitude) {
                        root.lat = data.latitude
                        root.lon = data.longitude
                        root.locationName = data.city || "Unknown"
                        root.saveConfig()
                        root.fetchWeather()
                    }
                } catch (e) {
                    console.error("[Weather] Location detect error:", e)
                    // Fallback to Manila
                    root.lat = 14.5995
                    root.lon = 120.9842
                    root.locationName = "Manila"
                    root.fetchWeather()
                }
            }
        }
    }

    function detectLocation() {
        locationDetector.command = ["curl", "-s", "--connect-timeout", "5",
                                   "https://ipapi.co/json/"]
        locationDetector.running = true
    }

    // ── Weather fetch ──
    Process {
        id: weatherFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try {
                    const data = JSON.parse(this.text)
                    if (data.current) {
                        const c = data.current
                        root.temperature = Math.round(c.temperature_2m || 0)
                        root.feelsLike = Math.round(c.apparent_temperature || 0)
                        root.humidity = c.relative_humidity_2m || 0
                        root.windSpeed = Math.round(c.wind_speed_10m || 0)

                        const code = c.weather_code || 0
                        root.icon = root.wmoIcon(code)
                        root.emojiIcon = root.wmoEmoji(code)
                        root.condition = root.wmoCondition(code)
                    }

                    if (data.daily) {
                        const d = data.daily
                        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                        const fc = []
                        for (let i = 0; i < Math.min(7, (d.time || []).length); i++) {
                            const dateObj = new Date(d.time[i])
                            fc.push({
                                day: i === 0 ? "Today" : days[dateObj.getDay()],
                                icon: root.wmoIcon(d.weather_code[i]),
                                emoji: root.wmoEmoji(d.weather_code[i]),
                                maxTemp: Math.round(d.temperature_2m_max[i]),
                                minTemp: Math.round(d.temperature_2m_min[i])
                            })
                        }
                        root.forecast = fc
                    }

                    const now = new Date()
                    root.lastUpdated = now.getHours().toString().padStart(2, "0") + ":" +
                                       now.getMinutes().toString().padStart(2, "0")
                    root.saveCache()
                } catch (e) {
                    console.error("[Weather] Parse error:", e)
                }
            }
        }
    }

    function fetchWeather() {
        if (lat === 0 && lon === 0) return
        loading = true
        const url = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=" + lat + "&longitude=" + lon +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature," +
            "weather_code,wind_speed_10m" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
            "&timezone=auto&forecast_days=7"
        weatherFetcher.command = ["curl", "-s", "--connect-timeout", "8", url]
        weatherFetcher.running = true
    }

    function refresh() {
        if (locationMode === "auto" && lat === 0) {
            detectLocation()
        } else {
            fetchWeather()
        }
    }

    // ── Persistence ──
    Process { id: configSaver; running: false }
    Process { id: cacheSaver; running: false }

    function saveConfig() {
        const state = {
            locationMode: locationMode,
            manualLocation: manualLocation,
            lat: lat, lon: lon,
            locationName: locationName
        }
        const json = JSON.stringify(state, null, 2)
        configSaver.command = ["bash", "-c",
            "mkdir -p '" + configDir + "' && cat > '" + configPath + "' << 'ZENEOF'\n" + json + "\nZENEOF"]
        configSaver.running = true
    }

    function saveCache() {
        const cache = {
            temperature: temperature, feelsLike: feelsLike,
            condition: condition, icon: icon,
            humidity: humidity, windSpeed: windSpeed,
            locationName: locationName,
            forecast: forecast,
            lastUpdated: lastUpdated,
            timestamp: new Date().toISOString()
        }
        const json = JSON.stringify(cache, null, 2)
        cacheSaver.command = ["bash", "-c",
            "mkdir -p '" + home + "/.cache/zen-shell' && cat > '" + cachePath + "' << 'ZENEOF'\n" + json + "\nZENEOF"]
        cacheSaver.running = true
    }

    FileView {
        id: configLoader
        path: root.configPath
        blockLoading: false
        onLoaded: {
            try {
                const s = JSON.parse(this.text())
                if (s.locationMode) root.locationMode = s.locationMode
                if (s.manualLocation) root.manualLocation = s.manualLocation
                if (s.lat) root.lat = s.lat
                if (s.lon) root.lon = s.lon
                if (s.locationName) root.locationName = s.locationName
            } catch (e) {}
        }
    }

    FileView {
        id: cacheLoader
        path: root.cachePath
        blockLoading: false
        onLoaded: {
            try {
                const c = JSON.parse(this.text())
                // Check cache age (6 hours max)
                const age = (Date.now() - new Date(c.timestamp).getTime()) / 1000
                if (age < 21600) {
                    root.temperature = c.temperature || 0
                    root.feelsLike = c.feelsLike || 0
                    root.condition = c.condition || "Cached"
                    root.icon = c.icon || "\uf0c2"
                    root.humidity = c.humidity || 0
                    root.windSpeed = c.windSpeed || 0
                    root.locationName = c.locationName || ""
                    if (c.forecast) root.forecast = c.forecast
                    root.lastUpdated = c.lastUpdated || ""
                }
            } catch (e) {}
        }
    }

    // ── Init ──
    Component.onCompleted: {
        configLoader.reload()
        cacheLoader.reload()
        // Delay initial fetch to let config load
        Qt.callLater(function() {
            if (root.lat === 0 && root.lon === 0) {
                root.detectLocation()
            } else {
                root.fetchWeather()
            }
        })
    }
}
