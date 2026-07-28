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
    property string icon: "\ue312"        // hf131: wi-cloudy (was \uf0c2 = fa-cloud)
    property int humidity: 0
    property int windSpeed: 0             // km/h
    property string locationName: "Detecting..."

    // ── v8.0.0-alpha-hf131 — the raw WMO code is the source of truth ──
    //
    // Backlog [G3]: "Store `code` in forecast[]/hourly[] and the table goes away."
    // Before this, the service computed three representations at fetch time and
    // discarded the number that produced them. ZenGlanceWidget then had to map
    // Nerd codepoints BACK to Material ligature names to draw its blob. Two
    // lossy hops for a value we already had.
    //
    // -1 = nothing fetched yet.
    property int weatherCode: -1

    // ── Windy ──
    //
    // WMO has no "windy" code — wind is a separate measurement, and the API
    // already gives it to us in `wind_speed_10m`. So we derive it: if the sky is
    // otherwise quiet and the wind is up, say windy.
    //
    // Rain, snow and thunderstorms always win. You want to know it is raining
    // more than you want to know it is breezy — and a "heavy rain + wind" code
    // (65 / 82) already draws a wind-blown rain glyph on its own.
    //
    // 25 km/h ≈ Beaufort 4–5, the point where an umbrella stops working.
    property int windyThresholdKmh: 25
    readonly property var _calmSkyCodes: [0, 1, 2, 3, 45, 48]
    readonly property bool windy: windSpeed >= windyThresholdKmh
                                  && _calmSkyCodes.indexOf(weatherCode) >= 0

    /** Material Symbols Rounded ligature for right now. What the bar/dock draw. */
    readonly property string materialIcon: weatherCode < 0 ? "cloud"
                                         : (windy ? "air" : wmoMaterial(weatherCode))
    /** Nerd Font weather glyph for right now, windy-aware. */
    readonly property string nerdIcon: windy ? "\ue31e" : icon      // wi-windy
    /** Emoji for right now, windy-aware. */
    readonly property string emojiIconLive: windy ? "🌬️" : emojiIcon

    // ── Forecast (7 days) ──
    property var forecast: []   // [{ day, icon, maxTemp, minTemp, code }]   (code: hf131)
    // v7.0.0-beta.1-hf99zd: next ~12 hours — [{ hour, temp, precip, icon, emoji, code }]
    property var hourly: []

    // ── Config ──
    property string locationMode: "auto"  // "auto" | "manual"
    property string manualLocation: ""
    property real lat: 0
    property real lon: 0
    property bool loading: false
    property string lastUpdated: ""

    // ── Emoji icon for desktop widget (separate from nerd font for bar) ──
    // v6.16.1.5: Default was "🌡️" (thermometer) which renders as a huge
    // red thermometer when weather hasn't loaded yet — looked out of place
    // on the weather widget. Changed to "🌤️" (partly sunny) which is a
    // sensible neutral-pleasant default. Overwritten by wmoEmoji() as
    // soon as the first fetch completes.
    property string emojiIcon: "🌤️"

    // v7.0.0-beta.1-hf2: 7-DAY HISTORY
    //
    // Persists daily snapshots of (date, temp, condition, icon) so
    // the widget can display past data even when offline. Cleaned to
    // max 7 entries on every save.
    //
    // Snapshot triggers once per day on first refresh after midnight,
    // based on the lastHistoryDate property.
    property var history: []                  // [{ date: "YYYY-MM-DD", temp, condition, icon, emoji }]
    property string lastHistoryDate: ""       // YYYY-MM-DD of last snapshot

    function _appendHistorySnapshot() {
        const today = new Date()
        const ymd = today.getFullYear() + "-"
                    + String(today.getMonth() + 1).padStart(2, "0") + "-"
                    + String(today.getDate()).padStart(2, "0")
        if (root.lastHistoryDate === ymd) return  // already logged today

        const snapshot = {
            date: ymd,
            temp: root.temperature,
            condition: root.condition,
            icon: root.icon,
            emoji: root.emojiIcon,
            location: root.locationName
        }

        const hist = root.history.slice()
        hist.push(snapshot)
        // Keep only last 7 days
        while (hist.length > 7) hist.shift()

        root.history = hist
        root.lastHistoryDate = ymd
        root.saveCache()   // persist
        console.log("[Weather] History snapshot for " + ymd
                    + " (now " + hist.length + " entries)")
    }

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
    //
    // ══ v8.0.0-alpha-hf131 — THESE CODEPOINTS WERE FONT AWESOME ══
    //
    // Paul: "yung mga widgets sa weather dito sa qml bar and dock dapat same sa
    //        logic icons nung sa desktop widgets ko"
    //
    // His bar was drawing a GEAR next to "30° Overcast". Not a styling problem —
    // every codepoint in this table was wrong. They were written against the
    // standalone Weather Icons font (weathericons.io), where `wi-cloudy` really
    // is U+F013. But Nerd Fonts relocates that whole set into the Private Use
    // Area at U+E3xx, and leaves Font Awesome sitting at U+F0xx. So rendering
    // these glyphs with "JetBrainsMono Nerd Font" — which is exactly what
    // ZenWeather.qml does — resolved every one of them to a Font Awesome icon:
    //
    //     WMO   condition       old cp    what a Nerd Font actually draws
    //       0   Clear           U+F00D    fa-times            (an ✕)
    //       1   Mostly Clear    U+F00C    fa-check            (a ✓)
    //       2   Partly Cloudy   U+F002    fa-search           (a magnifier)
    //       3   Overcast        U+F013    fa-cog              ← the gear
    //      45   Fog             U+F014    fa-trash_o
    //      61   Rain            U+F019    fa-download
    //      71   Snow            U+F01B    fa-arrow_circle_o_up
    //      75   Heavy Snow      U+F076    fa-magnet
    //      95   Thunderstorm    U+F01E    fa-repeat
    //    dflt   (fallback)      U+F03E    fa-image
    //
    // Only the fallback ever looked right, and by accident: U+F0C2 really is
    // fa-cloud, which is why nobody caught this for 130 builds.
    //
    // The codepoints below come from ryanoasis/nerd-fonts `glyphnames.json`, not
    // from arithmetic. The naive offset (nf = 0xE300 + (wi - 0xF000)) holds for
    // day_sunny and then quietly breaks — wi-cloudy F013 lands on E312, not E313,
    // and E313 is fog. Every value here was looked up.
    //
    // Also filled in the codes the old table dropped on the floor: freezing
    // drizzle (56/57), freezing rain (66/67), snow grains (77) and snow showers
    // (85/86) all fell through to the fallback. Wala tayong babawasan.
    function wmoIcon(code) {
        const map = {
            0:  "\ue30d",  // wi-day-sunny
            1:  "\ue30c",  // wi-day-sunny-overcast
            2:  "\ue302",  // wi-day-cloudy
            3:  "\ue312",  // wi-cloudy
            45: "\ue313",  // wi-fog
            48: "\ue313",
            51: "\ue31b",  // wi-sprinkle  (drizzle)
            53: "\ue31b",
            55: "\ue319",  // wi-showers   (heavy drizzle)
            56: "\ue3ad",  // wi-sleet     (freezing drizzle)
            57: "\ue3ad",
            61: "\ue318",  // wi-rain
            63: "\ue318",
            65: "\ue317",  // wi-rain-wind (heavy rain)
            66: "\ue3ad",  // wi-sleet     (freezing rain)
            67: "\ue3ad",
            71: "\ue31a",  // wi-snow
            73: "\ue31a",
            75: "\ue36f",  // wi-snowflake-cold
            77: "\ue31a",  // wi-snow      (snow grains)
            80: "\ue319",  // wi-showers
            81: "\ue319",
            82: "\ue317",  // wi-rain-wind (violent showers)
            85: "\ue31a",  // wi-snow      (snow showers)
            86: "\ue36f",
            95: "\ue31d",  // wi-thunderstorm
            96: "\ue31c",  // wi-storm-showers
            99: "\ue31c"
        }
        return map[code] || "\ue374"        // wi-na
    }

    // ── v8.0.0-alpha-hf131 — WMO code → Material Symbols ligature ──
    //
    // This is backlog item [G3], done. ZenGlanceWidget used to translate
    // wmoIcon()'s Nerd codepoints back into Material ligature names with its own
    // private lookup, "because the service throws the raw WMO code away". The
    // service keeps the code now (see `weatherCode`), so the round-trip is gone
    // and the bar, the dock, the Glance blob and the settings preview all read
    // one table.
    //
    // Every ligature name below was checked against the actual
    // MaterialSymbolsRounded variable font — `cloudy` does NOT exist in it,
    // which is why overcast maps to `cloud`.
    function wmoMaterial(code) {
        const map = {
            0:  "clear_day",         1:  "clear_day",
            2:  "partly_cloudy_day",
            3:  "cloud",
            45: "foggy",             48: "foggy",
            51: "rainy_light",       53: "rainy_light",      55: "rainy",
            56: "weather_hail",      57: "weather_hail",
            61: "rainy",             63: "rainy",            65: "rainy_heavy",
            66: "weather_hail",      67: "weather_hail",
            71: "weather_snowy",     73: "weather_snowy",    75: "snowing_heavy",
            77: "weather_snowy",
            80: "rainy",             81: "rainy",            82: "rainy_heavy",
            85: "weather_snowy",     86: "snowing_heavy",
            95: "thunderstorm",      96: "thunderstorm",     99: "thunderstorm"
        }
        return map[code] || "cloud"
    }

    // ── v8.0.0-alpha-hf132 — WMO code → icon tint ──
    //
    // "kaya yun mag colors din pre? yung mga icons? prang sa widget desktop ko"
    //
    // The desktop widget's icons are coloured because they are emoji, and emoji
    // carry their own palette. Material Symbols and Nerd Font glyphs are single
    // outlines — whatever colour you paint them, they stay that colour. hf131
    // painted them all `ThemeService.aqua`, so a sun and a thunderstorm looked
    // identical apart from their shape.
    //
    // TWO palettes, because one cannot work. My first attempt was a single table
    // tuned on a dark bar, with a comment claiming it stayed legible on a light
    // one. Measured: 20 of 29 colours failed. Snow (#e3f2fd) on a light surface
    // scored a contrast ratio of 1.05 — invisible. Nor does a lightness
    // transform save it: forcing snow dark enough turns it into rain's blue.
    //
    // So the tint follows the surface. Both tables were audited:
    //
    //   dark  bar : worst contrast 4.99   (target >= 3.0)
    //   light bar : worst contrast 2.81   (target >= 2.5)
    //   22/22 required pairs separated by >= 45 in RGB distance
    //
    // Fog and overcast ARE close, deliberately. They are both grey sky; a
    // weather app that makes them wildly different is lying to you. Same for
    // snow vs freezing rain. The pairs that must never be confused — clear,
    // rain, snow, storm, windy — are all well clear of each other.
    //
    // A fixed palette, not theme-derived, for the reason a traffic light is not
    // theme-derived: rain should read as rain on every Shell Look. Set
    // Settings → Bar Modules → Weather → Icon colour to "Accent" for the old
    // single-colour behaviour. Wala tayong babawasan.
    function wmoTintDark(code) {
        const map = {
            0:  "#ffc53d",   // clear            — sun gold
            1:  "#ffd166",   // mostly clear
            2:  "#9ec5fe",   // partly cloudy    — pale sky
            3:  "#9aa5b1",   // overcast         — slate
            45: "#b8c0c8",   // fog              — pale slate
            48: "#b8c0c8",
            51: "#7cc4fa",   // drizzle          — light blue
            53: "#7cc4fa",
            55: "#4ea8de",   // heavy drizzle
            56: "#67e8f9",   // freezing drizzle — ice cyan
            57: "#67e8f9",
            61: "#4ea8de",   // rain             — blue
            63: "#4ea8de",
            65: "#2d7dd2",   // heavy rain       — deep blue
            66: "#67e8f9",   // freezing rain    — ice cyan
            67: "#67e8f9",
            71: "#e3f2fd",   // snow             — near-white
            73: "#e3f2fd",
            75: "#c7e9ff",   // heavy snow
            77: "#e3f2fd",   // snow grains
            80: "#58b4e8",   // showers
            81: "#58b4e8",
            82: "#2d7dd2",   // violent showers
            85: "#e3f2fd",   // snow showers
            86: "#c7e9ff",
            95: "#9d7bea",   // thunderstorm     — violet
            96: "#9d7bea",
            99: "#8b5cf6"    // severe storm
        }
        return map[code] || "#9aa5b1"
    }
    function wmoTintLight(code) {
        const map = {
            0:  "#c2740a",   // clear            — amber
            1:  "#cf8412",
            2:  "#4e7ca8",   // partly cloudy    — steel
            3:  "#55606b",   // overcast         — slate
            45: "#6d6a63",   // fog              — warm grey
            48: "#6d6a63",
            51: "#2b7fbd",   // drizzle
            53: "#2b7fbd",
            55: "#15599f",
            56: "#0f766e",   // freezing drizzle — teal
            57: "#0f766e",
            61: "#15599f",   // rain             — deep blue
            63: "#15599f",
            65: "#0f3f7a",   // heavy rain
            66: "#0f766e",   // freezing rain
            67: "#0f766e",
            71: "#0e9aa8",   // snow             — cyan
            73: "#0e9aa8",
            75: "#0b7288",   // heavy snow
            77: "#0e9aa8",
            80: "#2b7fbd",   // showers
            81: "#2b7fbd",
            82: "#0f3f7a",
            85: "#0e9aa8",
            86: "#0b7288",
            95: "#6d28d9",   // thunderstorm     — violet
            96: "#6d28d9",
            99: "#5b21b6"
        }
        return map[code] || "#55606b"
    }

    /**
     * Is the surface we paint onto dark? Relative luminance of the theme's base,
     * per WCAG's coefficients. Qt colour components are already 0..1.
     */
    readonly property bool _darkSurface: {
        const c = ThemeService.bg0
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) < 0.5
    }

    function wmoTint(code) {
        return _darkSurface ? wmoTintDark(code) : wmoTintLight(code)
    }

    /** Colour for the current condition. Windy gets its own green-teal. */
    readonly property color iconTint: weatherCode < 0
        ? (_darkSurface ? "#9aa5b1" : "#55606b")
        : (windy ? (_darkSurface ? "#34d399" : "#15803d") : wmoTint(weatherCode))

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
    //
    // v7.0.0-alpha.5 (Karui Laptop Mode): refresh is gated on
    // LaptopModeService.weatherRefreshAllowed. When user is on battery
    // and capacity is low (<20% balanced / <15% endurance), the timer
    // still fires but onTriggered short-circuits — saving the network
    // round-trip + parse work. Always-true when service is "off" or
    // when plugged in.
    Timer {
        interval: 1800000  // 30 min
        repeat: true
        running: true
        onTriggered: {
            if (typeof LaptopModeService !== "undefined"
                && !LaptopModeService.weatherRefreshAllowed) return
            root.refresh()
        }
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
                        root.weatherCode = code            // hf131 — keep the number
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
                                code: d.weather_code[i],                    // hf131 [G3]
                                icon: root.wmoIcon(d.weather_code[i]),
                                material: root.wmoMaterial(d.weather_code[i]), // hf131 [G3]
                                emoji: root.wmoEmoji(d.weather_code[i]),
                                maxTemp: Math.round(d.temperature_2m_max[i]),
                                minTemp: Math.round(d.temperature_2m_min[i])
                            })
                        }
                        root.forecast = fc
                    }

                    // v7.0.0-beta.1-hf99zd: hourly — next ~12 hours from now
                    if (data.hourly && data.hourly.time) {
                        const h = data.hourly
                        const nowMs = Date.now()
                        let startIdx = 0
                        for (let i = 0; i < h.time.length; i++) {
                            if (new Date(h.time[i]).getTime() >= nowMs - 3600000) { startIdx = i; break }
                        }
                        const hr = []
                        for (let i = startIdx; i < Math.min(startIdx + 12, h.time.length); i++) {
                            const dt = new Date(h.time[i])
                            hr.push({
                                hour: dt.getHours().toString().padStart(2, "0") + ":00",
                                temp: Math.round(h.temperature_2m[i]),
                                precip: (h.precipitation_probability && h.precipitation_probability[i] !== null) ? h.precipitation_probability[i] : 0,
                                code: h.weather_code[i],                    // hf131 [G3]
                                icon: root.wmoIcon(h.weather_code[i]),
                                material: root.wmoMaterial(h.weather_code[i]), // hf131 [G3]
                                emoji: root.wmoEmoji(h.weather_code[i])
                            })
                        }
                        root.hourly = hr
                    }

                    const now = new Date()
                    root.lastUpdated = now.getHours().toString().padStart(2, "0") + ":" +
                                       now.getMinutes().toString().padStart(2, "0")
                    // v7.0.0-beta.1-hf2: log daily snapshot (once per day)
                    root._appendHistorySnapshot()
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
            "&hourly=temperature_2m,precipitation_probability,weather_code" +
            "&timezone=auto&forecast_days=7"
        weatherFetcher.command = ["curl", "-s", "--connect-timeout", "8", url]
        weatherFetcher.running = true
    }

    // v7.0.0-beta.1-hf2: GEOCODING for manual location
    //
    // When user types a city name (e.g. "Antipolo") in WidgetsPage,
    // we hit Open-Meteo's free geocoding API to convert it to
    // lat/lon, then fetch weather as usual.
    //
    // Endpoint: https://geocoding-api.open-meteo.com/v1/search?name=X
    function geocodeManual() {
        if (!manualLocation || manualLocation.length === 0) return
        loading = true
        const q = encodeURIComponent(manualLocation)
        const url = "https://geocoding-api.open-meteo.com/v1/search?name="
                    + q + "&count=1&language=en&format=json"
        geocodeFetcher.command = ["curl", "-s", "--connect-timeout", "8", url]
        geocodeFetcher.running = true
    }

    Process {
        id: geocodeFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    if (data.results && data.results.length > 0) {
                        const r = data.results[0]
                        root.lat = r.latitude
                        root.lon = r.longitude
                        root.locationName = r.name
                            + (r.admin1 ? ", " + r.admin1 : "")
                            + (r.country ? ", " + r.country : "")
                        root.saveConfig()
                        // Now fetch actual weather for this location
                        root.fetchWeather()
                    } else {
                        console.warn("[Weather] Geocoding failed for: " + root.manualLocation)
                        root.loading = false
                    }
                } catch (e) {
                    console.error("[Weather] Geocoding parse error:", e)
                    root.loading = false
                }
            }
        }
    }

    function refresh() {
        // v7.0.0-beta.1-hf2: handle all 4 paths cleanly:
        //   - auto mode, lat unknown    → IP-based detect
        //   - auto mode, lat known      → fetch weather directly
        //   - manual mode, location set → geocode → fetch weather
        //   - manual mode, no location  → do nothing
        if (locationMode === "auto") {
            if (lat === 0) detectLocation()
            else fetchWeather()
        } else if (locationMode === "manual") {
            if (manualLocation && manualLocation.length > 0) {
                geocodeManual()
            }
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
            locationName: locationName,
            windyThresholdKmh: windyThresholdKmh          // hf131
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
            weatherCode: weatherCode,                       // hf131
            humidity: humidity, windSpeed: windSpeed,
            locationName: locationName,
            forecast: forecast,
            hourly: hourly,                                // v8.0.0-alpha-hf157 — 24h strip must survive offline too
            history: history,                              // v7.0.0-beta.1-hf2
            lastHistoryDate: lastHistoryDate,              // v7.0.0-beta.1-hf2
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
                if (typeof s.windyThresholdKmh === "number")     // hf131
                    root.windyThresholdKmh = Math.max(5, Math.min(80, s.windyThresholdKmh))
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
                // v8.0.0-alpha-hf157 — restore UNCONDITIONALLY so the widget is never
                // null offline. The old 6-hour age gate dropped everything past 21600s,
                // which is exactly when you most want the last-known reading (no net
                // after a long downtime — restart/login). The next successful fetch
                // overwrites; `lastUpdated` still shows how old it is. Matches how
                // history was already restored regardless of freshness.
                const age = (Date.now() - new Date(c.timestamp).getTime()) / 1000  // still handy for logs
                root.temperature = c.temperature || 0
                root.feelsLike = c.feelsLike || 0
                root.condition = c.condition || "Cached"
                // v8.0.0-alpha-hf131 — SELF-HEAL. Caches written before hf131 hold
                // Font Awesome codepoints (U+F0xx) in `icon`. If we have the code,
                // re-derive; otherwise drop the stale glyph until the next fetch.
                root.weatherCode = (typeof c.weatherCode === "number") ? c.weatherCode : -1
                if (root.weatherCode >= 0) {
                    root.icon = root.wmoIcon(root.weatherCode)
                    root.emojiIcon = root.wmoEmoji(root.weatherCode)
                } else {
                    const cached = c.icon || ""
                    const legacy = cached.length === 1 && cached.charCodeAt(0) >= 0xF000
                    root.icon = (cached.length > 0 && !legacy) ? cached : "\ue312"
                }
                root.humidity = c.humidity || 0
                root.windSpeed = c.windSpeed || 0
                root.locationName = c.locationName || ""
                if (c.forecast && Array.isArray(c.forecast)) root.forecast = c.forecast
                // v8.0.0-alpha-hf157 — hourly now persists too (was never in the cache,
                // so the 24h strip came up empty on every restart until a fetch landed).
                if (c.hourly && Array.isArray(c.hourly)) root.hourly = c.hourly
                root.lastUpdated = c.lastUpdated || ""
                // history survives offline periods regardless of freshness
                if (c.history && Array.isArray(c.history)) root.history = c.history
                if (c.lastHistoryDate) root.lastHistoryDate = c.lastHistoryDate
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
