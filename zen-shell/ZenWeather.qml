import QtQuick
import QtQuick.Layouts

/*
 * ZenWeather — compact bar weather module
 *
 * v6.8: Binds to WeatherService for live weather data.
 * Shows: weather icon + temperature + condition (compact one-line).
 * Mounted by BOTH Bar.qml ("weather" module) and ZenDock.qml (hf126).
 *
 * v8.0.0-alpha-hf131 — the icon follows the desktop widgets.
 *
 * "yung mga widgets sa weather dito sa qml bar and dock dapat same sa logic
 *  icons nung sa desktop widgets ko if cloudy, sunny, windy, rainy"
 *
 * Two things were wrong. First, this drew `WeatherService.icon` — a Weather
 * Icons codepoint — in "JetBrainsMono Nerd Font", where U+F0xx is Font Awesome.
 * Overcast (U+F013) rendered as fa-cog: a gear, next to "30° Overcast". Rain
 * was fa-download. Clear was an ✕. See WeatherService.wmoIcon() for the whole
 * list; every entry was wrong and only the fallback looked plausible.
 *
 * Second, the desktop widgets don't agree with each other either. The Glance
 * blob draws Material Symbols; the classic widget, the dashboard card and the
 * Quick Settings card draw emoji. So `iconStyle` picks, and the default is
 * `material` — monochrome, themeable, and the same glyph set the Glance blob
 * and the rest of v8's chrome already use.
 *
 *   material  clear_day · partly_cloudy_day · cloud · rainy · air   (default)
 *   emoji     ☀️ ⛅ ☁️ 🌧️ 🌬️            (matches the dashboard + QS cards)
 *   nerd      wi-day-sunny · wi-cloudy · wi-rain · wi-windy  (fixed codepoints)
 *
 * Settings → Bar Modules → Weather icon style. Wala tayong babawasan — the nerd
 * path still exists, it just points at the right glyphs now.
 */
Item {
    id: weatherRoot
    implicitWidth: weatherRow.implicitWidth + 16
    implicitHeight: parent ? parent.height : 40

    readonly property string iconStyle:
        (typeof PanelState.weatherIconStyle !== "undefined") ? PanelState.weatherIconStyle : "material"
    readonly property bool tintByCondition:
        (typeof PanelState.weatherIconTint === "undefined") || PanelState.weatherIconTint !== "accent"

    RowLayout {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 6

        // Weather icon — one source of truth: WeatherService, keyed off the raw
        // WMO code. Windy is derived from wind speed (WMO has no windy code).
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: weatherRoot.iconStyle === "emoji" ? WeatherService.emojiIconLive
                : weatherRoot.iconStyle === "nerd"  ? WeatherService.nerdIcon
                :                                     WeatherService.materialIcon
            font.family: weatherRoot.iconStyle === "emoji" ? Theme.fontFamily
                       : weatherRoot.iconStyle === "nerd"  ? "JetBrainsMono Nerd Font"
                       :                                     "Material Symbols Rounded"
            font.pixelSize: weatherRoot.iconStyle === "material" ? 16 : 15
            // hf132: emoji carry their own palette; tinting them does nothing.
            // Material and Nerd glyphs are single outlines, so the condition's
            // colour is the only thing that tells a sun from a thunderstorm.
            color: weatherRoot.iconStyle === "emoji" ? ThemeService.fg
                 : weatherRoot.tintByCondition      ? WeatherService.iconTint
                 :                                    ThemeService.aqua
            Behavior on color { ColorAnimation { duration: 220 } }
            Layout.alignment: Qt.AlignVCenter
        }

        // Temperature
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: WeatherService.temperature + "°"
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeService.fg
        }

        // Condition (short) — hide on narrow bars
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: WeatherService.condition
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 11
            color: ThemeService.grey0
            visible: weatherRoot.implicitWidth < 200  // always visible in normal bar
            elide: Text.ElideRight
            Layout.maximumWidth: 80
        }
    }

    // Hover detail popup (no ToolTip in Quickshell)
    Rectangle {
        id: weatherTip
        visible: tipArea.containsMouse
        x: -20
        y: weatherRoot.height + 4
        width: tipCol.implicitWidth + 24
        height: tipCol.implicitHeight + 16
        radius: 8
        color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.95)
        border.width: 1
        border.color: ThemeService.alpha(ThemeService.fg, 0.12)
        z: 999

        Column {
            id: tipCol
            anchors.centerIn: parent
            spacing: 2
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: WeatherService.locationName; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.fg }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: WeatherService.temperature + "°C — " + WeatherService.condition; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey0 }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: "Feels " + WeatherService.feelsLike + "° • Humidity " + WeatherService.humidity + "% • Wind " + WeatherService.windSpeed + " km/h"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1 }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 visible: WeatherService.lastUpdated.length > 0; text: "Updated " + WeatherService.lastUpdated; font.family: Theme.fontFamily; font.pixelSize: 9; color: ThemeService.grey2 }
        }
    }

    MouseArea {
        id: tipArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
