import QtQuick
import QtQuick.Layouts

/*
 * ZenWeather — compact bar weather module
 *
 * v6.8: Binds to WeatherService for live weather data.
 * Shows: weather icon + temperature + condition (compact one-line).
 * Install as Weather.qml in ~/.config/quickshell/zen-shell/
 * Then add "weather" to Theme.barLayout.right (or center/left).
 */
Item {
    id: weatherRoot
    implicitWidth: weatherRow.implicitWidth + 16
    implicitHeight: parent ? parent.height : 40

    RowLayout {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 6

        // Weather icon (Nerd Font)
        Text {
            text: WeatherService.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: ThemeService.aqua
        }

        // Temperature
        Text {
            text: WeatherService.temperature + "°"
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeService.fg
        }

        // Condition (short) — hide on narrow bars
        Text {
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
            Text { text: WeatherService.locationName; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.fg }
            Text { text: WeatherService.temperature + "°C — " + WeatherService.condition; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey0 }
            Text { text: "Feels " + WeatherService.feelsLike + "° • Humidity " + WeatherService.humidity + "% • Wind " + WeatherService.windSpeed + " km/h"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.grey1 }
            Text { visible: WeatherService.lastUpdated.length > 0; text: "Updated " + WeatherService.lastUpdated; font.family: Theme.fontFamily; font.pixelSize: 9; color: ThemeService.grey2 }
        }
    }

    MouseArea {
        id: tipArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
