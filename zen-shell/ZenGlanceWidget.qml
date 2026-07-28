import QtQuick
import QtQuick.Shapes
import Quickshell

/*
 * ZenGlanceWidget v8.0.0-alpha-hf113 — the merged desktop "Glance" blob
 *
 * Pixel's At-a-Glance blob: an asymmetric squircle with four DIFFERENT
 * elliptical corners, a slanted weather glyph, and the temperature set
 * flush to the top-right. Tap it and it morphs into a compact card;
 * tap expand and it opens the full forecast / system readout.
 *
 * Only mounted when `glance.merged` is true. When merged is false,
 * DesktopWidgets keeps rendering the original weatherWidget +
 * sysmonWidget exactly as before — walang binabago dun.
 *
 * Why Shape and not Rectangle:
 *   Rectangle's per-corner radii (Qt 6.7+) are CIRCULAR. The reference
 *   blob needs radiusX != radiusY per corner (e.g. 78x70 top-left,
 *   66x84 top-right) — that lopsidedness is the whole look. So the
 *   background is one ShapePath: 4 PathLine edges + 4 elliptical
 *   PathArc corners. Every radius lerps toward 28 as `_blend` goes
 *   0 -> 1, which is what makes the blob melt into a card.
 *
 * Ink colour is auto-derived from the surface (see `_autoInk`): we take
 * the surface's own hue, then drop it dark + saturated on light
 * surfaces, or lift it pale on dark ones. Porcelain #FBEDE8 lands on
 * roughly #6A2B16 — the burnt sienna from the reference — and a Zen
 * bg1 #24283b lands on a pale periwinkle. So "auto" always reads.
 *
 * View states: "blob" -> "compact" -> "detail".
 * Face states: "weather" | "system", switched by the two icon buttons.
 */
Item {
    id: g

    // ── public API (DesktopWidgets binds these) ─────────────────────
    property real   scaleFactor: 1.0
    property string fontFamily: "Adwaita Sans"
    property color  surfaceColor: "#FBEDE8"
    property real   surfaceOpacity: 0.96
    property string inkMode: "auto"              // auto | theme | custom
    property color  inkCustom: "#6E2A14"
    property color  accentColor: "#5DC4E8"
    property bool   weatherEnabled: true
    property bool   sysmonEnabled: true

    signal moved(real px, real py)

    // ── view / face state ──────────────────────────────────────────
    property string view: "blob"                 // blob | compact | detail
    property string face: weatherEnabled ? "weather" : "system"

    readonly property real s: scaleFactor
    readonly property bool open: view !== "blob"

    // ── geometry ───────────────────────────────────────────────────
    readonly property real _w: view === "blob" ? 178 : (view === "compact" ? 404 : 576)
    readonly property real _h: view === "blob" ? 156
                             : (view === "compact" ? 200
                             : (face === "weather" ? 436 : 368))

    // v8.0.0-alpha-hf125 — the resting size, available before the 620ms width
    // Behavior has finished. DesktopWidgets needs it to solve the expanded
    // placement on the same frame the view changes.
    readonly property real targetWidth:  _w * s
    readonly property real targetHeight: _h * s

    width:  _w * s
    height: _h * s
    Behavior on width  { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }

    // 0 = blob (lopsided corners), 1 = card (uniform 28px)
    property real _blend: open ? 1 : 0
    Behavior on _blend { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }

    // CSS equivalent: border-radius: 78px 66px 72px 86px / 70px 84px 64px 74px
    function _r(blobR) { return (blobR * (1 - _blend) + 28 * _blend) * s }
    readonly property real _tlx: _r(78);  readonly property real _tly: _r(70)
    readonly property real _trx: _r(66);  readonly property real _try: _r(84)
    readonly property real _brx: _r(72);  readonly property real _bry: _r(64)
    readonly property real _blx: _r(86);  readonly property real _bly: _r(74)

    // ── colour system ──────────────────────────────────────────────
    function _mix(a, b, t) {
        return Qt.rgba(a.r * t + b.r * (1 - t),
                       a.g * t + b.g * (1 - t),
                       a.b * t + b.b * (1 - t), 1)
    }
    readonly property color _autoInk: {
        const c = g.surfaceColor
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        // Near-greys have a meaningless hue — don't tint them red.
        const flat = c.hslSaturation < 0.08
        const h = flat ? 0 : c.hslHue
        const sat = flat ? 0 : (lum > 0.55 ? 0.62 : 0.32)
        return lum > 0.55 ? Qt.hsla(h, sat, 0.26, 1) : Qt.hsla(h, sat, 0.90, 1)
    }
    readonly property color ink: inkMode === "theme"  ? ThemeService.fg
                               : inkMode === "custom" ? inkCustom
                               : _autoInk
    readonly property color ink2:  _mix(ink, surfaceColor, 0.74)
    readonly property color mute:  _mix(ink, surfaceColor, 0.40)
    readonly property color track: _mix(ink, surfaceColor, 0.11)
    readonly property color stroke: _mix(ink, surfaceColor, 0.16)

    // ── weather glyph mapping (Nerd codepoint -> Material ligature) ──
    //
    // v8.0.0-alpha-hf131 — SUPERSEDED, kept as a fallback.
    //
    // This table existed because "WeatherService stores wmoIcon() glyphs" and
    // threw the raw WMO code away, so the blob had to map Nerd codepoints back
    // into Material ligature names. That was backlog item [G3]. The service
    // keeps `weatherCode` now and exposes `materialIcon` directly, so `wxIcon()`
    // prefers it — and picks up `air` when it's windy, which this table could
    // never express.
    //
    // The old lookup stays for any caller still holding a legacy glyph, and
    // because its keys are the pre-hf131 Font Awesome codepoints it also acts as
    // a translator for a stale weather cache. Wala tayong babawasan.
    readonly property var _wxMap: ({
        "\uf00d": "clear_day",   "\uf00c": "clear_day",
        "\uf002": "partly_cloudy_day",
        "\uf013": "cloud",       "\uf014": "foggy",
        "\uf01a": "rainy",       "\uf019": "rainy",  "\uf018": "rainy",
        "\uf01b": "weather_snowy","\uf076": "weather_snowy",
        "\uf01e": "thunderstorm"
    })
    function wxIcon(glyph) {
        // hf131: the service knows better than we can infer from a glyph.
        if (typeof WeatherService.materialIcon === "string"
                && WeatherService.materialIcon.length > 0
                && WeatherService.weatherCode >= 0)
            return WeatherService.materialIcon
        return _wxMap[glyph] || "cloud"
    }

    readonly property string msFont: "Material Symbols Rounded"

    function toggleFace() {
        if (!weatherEnabled || !sysmonEnabled) return
        face = face === "weather" ? "system" : "weather"
    }
    function cycleOpen() {
        view = view === "detail" ? "compact" : "detail"
    }

    // ════════════════════════════════════════════════════════════════
    // background — the blob itself
    // ════════════════════════════════════════════════════════════════
    Shape {
        anchors.fill: parent
        // CurveRenderer gives clean AA on the curved corners without a
        // layer/FBO. Falls back automatically if unsupported.
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.rgba(g.surfaceColor.r, g.surfaceColor.g,
                               g.surfaceColor.b, g.surfaceOpacity)
            strokeColor: g.stroke
            strokeWidth: 1

            startX: g._tlx; startY: 0
            PathLine { x: g.width - g._trx;  y: 0 }
            PathArc  { x: g.width;           y: g._try
                       radiusX: g._trx;      radiusY: g._try;  direction: PathArc.Clockwise }
            PathLine { x: g.width;           y: g.height - g._bry }
            PathArc  { x: g.width - g._brx;  y: g.height
                       radiusX: g._brx;      radiusY: g._bry;  direction: PathArc.Clockwise }
            PathLine { x: g._blx;            y: g.height }
            PathArc  { x: 0;                 y: g.height - g._bly
                       radiusX: g._blx;      radiusY: g._bly;  direction: PathArc.Clockwise }
            PathLine { x: 0;                 y: g._tly }
            PathArc  { x: g._tlx;            y: 0
                       radiusX: g._tlx;      radiusY: g._tly;  direction: PathArc.Clockwise }
        }
    }

    // ── drag + tap-to-open (sits under the content, above nothing) ──
    // v8.0.0-alpha-hf116 — hover comes from a HoverHandler, not this MouseArea.
    //
    // An ancestor MouseArea's `containsMouse` goes FALSE the moment a descendant
    // MouseArea with hoverEnabled takes the hover. The icon buttons each have one.
    // So: hover the blob → controls fade in → cursor lands on a button → the
    // button steals the hover → dragArea.containsMouse false → controls fade out
    // → cursor is over nothing → containsMouse true → fade in. A flicker loop, at
    // the animation's frame rate.
    //
    // HoverHandler is passive: it stays `hovered` while the pointer is anywhere
    // inside the item, children included. No steal, no loop.
    HoverHandler { id: rootHover }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        // hoverEnabled deliberately off — cursorShape works without it, and we
        // don't want a second hover consumer competing with rootHover.
        cursorShape: pressed ? Qt.ClosedHandCursor
                             : (g.open ? Qt.ArrowCursor : Qt.PointingHandCursor)
        drag.target: g
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (g.parent ? g.parent.width  : 0) - g.width
        drag.maximumY: (g.parent ? g.parent.height : 0) - g.height
        drag.threshold: 5
        onClicked: if (!g.open) g.view = "compact"
        onReleased: g.moved(g.x, g.y)
    }

    // ════════════════════════════════════════════════════════════════
    // reusable bits
    // ════════════════════════════════════════════════════════════════
    component Glyph: Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        font.family: g.msFont
        renderType: Text.NativeRendering
        color: g.mute
    }

    component IconButton: Item {
        id: ib
        property string icon: ""
        property bool active: false
        property real d: 34 * g.s
        signal tapped()
        width: d; height: d
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: ib.active ? g.ink : (hov.containsMouse ? g.track : "transparent")
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.centerIn: parent
            text: ib.icon
            font.family: g.msFont
            font.pixelSize: ib.d * 0.62
            renderType: Text.NativeRendering
            color: ib.active ? g.surfaceColor : g.ink2
        }
        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.tapped()
        }
    }

    component StatCard: Rectangle {
        property string caption: ""
        property string value: ""
        radius: 14 * g.s
        color: g.track
        Column {
            anchors.left: parent.left;  anchors.leftMargin: 14 * g.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * g.s
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: parent.parent.caption; font.family: g.fontFamily
                   font.pixelSize: 11 * g.s; font.letterSpacing: 0.6; color: g.ink2 }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                 text: parent.parent.value; font.family: g.fontFamily
                   font.pixelSize: 17 * g.s; font.weight: Font.Medium
                   font.letterSpacing: -0.4; color: g.ink }
        }
    }

    // Everything below is clipped to the widget box. The blob's curved
    // corners never reach the content, so a rect clip is enough.
    Item {
        id: content
        anchors.fill: parent
        clip: true

        // ════════════════════════════════════════════════════════════
        // WEATHER FACE
        // ════════════════════════════════════════════════════════════
        Item {
            id: wxFace
            anchors.fill: parent
            opacity: g.face === "weather" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 240 } }

            // slanted glyph — straightens as the blob opens
            Glyph {
                id: wxIco
                text: g.wxIcon(WeatherService.icon)
                color: g.accentColor
                font.pixelSize: (g.open ? 46 : 64) * g.s
                x: (g.open ? 24 : 12) * g.s
                y: (g.open ? 48 : 74) * g.s
                rotation: g.open ? 0 : -13
                transformOrigin: Item.Center
                Behavior on font.pixelSize { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on x        { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on y        { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on rotation { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }

            Row {
                id: wxTemp
                spacing: 1
                y: (g.open ? 44 : 24) * g.s
                x: g.open ? 84 * g.s : (g.width - width - 20 * g.s)
                Behavior on x { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: WeatherService.temperature
                    font.family: g.fontFamily
                    font.pixelSize: 52 * g.s
                    font.weight: g.open ? Font.Medium : Font.DemiBold
                    font.letterSpacing: -2.2 * g.s
                    color: g.ink
                }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "°C"
                    anchors.top: parent.top
                    anchors.topMargin: 6 * g.s
                    font.family: g.fontFamily
                    font.pixelSize: 22 * g.s
                    font.weight: Font.Medium
                    color: g.ink
                }
            }

            // blob-only humidity chip (top-right, under the temp)
            Row {
                spacing: 4 * g.s
                x: g.width - width - 24 * g.s
                y: 92 * g.s
                opacity: g.open ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Glyph { text: "water_drop"; font.pixelSize: 15 * g.s; color: g.ink2 }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: WeatherService.humidity + "%"; font.family: g.fontFamily
                       font.pixelSize: 12 * g.s; color: g.ink2 }
            }

            // ── compact tier ──
            Item {
                anchors.fill: parent
                opacity: g.open ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    x: 84 * g.s; y: 100 * g.s
                    text: WeatherService.locationName
                    font.family: g.fontFamily; font.pixelSize: 14 * g.s; color: g.ink2
                }
                Column {
                    x: g.width - width - 24 * g.s
                    y: 26 * g.s
                    spacing: 9 * g.s
                    Repeater {
                        model: [
                            { ic: "device_thermostat", tx: WeatherService.feelsLike + "°" },
                            { ic: "water_drop",        tx: WeatherService.humidity + "%" },
                            { ic: "air",               tx: WeatherService.windSpeed + " km/h" }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 8 * g.s
                            layoutDirection: Qt.RightToLeft
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: modelData.tx; font.family: g.fontFamily
                                   font.pixelSize: 13 * g.s; color: g.ink2 }
                            Glyph { text: modelData.ic; font.pixelSize: 18 * g.s }
                        }
                    }
                }
                Row {
                    x: 24 * g.s; y: 122 * g.s
                    spacing: 10 * g.s
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.condition; font.family: g.fontFamily
                           font.pixelSize: 15 * g.s; color: g.ink }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Updated " + WeatherService.lastUpdated
                           anchors.baseline: parent.children[0].baseline
                           font.family: g.fontFamily; font.pixelSize: 11 * g.s; color: g.mute }
                }
            }

            // ── detail tier ──
            Item {
                anchors.fill: parent
                opacity: g.view === "detail" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Rectangle { x: 24 * g.s; y: 158 * g.s; width: g.width - 48 * g.s
                            height: 1; color: g.track }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     x: 24 * g.s; y: 168 * g.s; text: "HOURLY FORECAST"
                       font.family: g.fontFamily; font.pixelSize: 11 * g.s
                       font.letterSpacing: 1 * g.s; color: g.ink2 }

                Row {
                    x: 24 * g.s; y: 192 * g.s; spacing: 6 * g.s
                    Repeater {
                        model: Math.min(8, WeatherService.hourly.length)
                        delegate: Column {
                            required property int index
                            readonly property var h: WeatherService.hourly[index]
                            width: 56 * g.s
                            spacing: 2 * g.s
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: h.temp + "°"; width: parent.width
                                   horizontalAlignment: Text.AlignHCenter
                                   font.family: g.fontFamily; font.pixelSize: 15 * g.s
                                   font.weight: Font.Medium; color: g.ink }
                            Glyph { text: g.wxIcon(h.icon); width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 24 * g.s }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: h.precip + "%"; width: parent.width
                                   horizontalAlignment: Text.AlignHCenter
                                   font.family: g.fontFamily; font.pixelSize: 11 * g.s
                                   color: g.accentColor }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: h.hour; width: parent.width
                                   horizontalAlignment: Text.AlignHCenter
                                   font.family: g.fontFamily; font.pixelSize: 11 * g.s
                                   color: g.ink2 }
                        }
                    }
                }

                Row {
                    x: 24 * g.s; y: 286 * g.s; spacing: 6 * g.s
                    Repeater {
                        model: Math.min(7, WeatherService.forecast.length)
                        delegate: Rectangle {
                            required property int index
                            readonly property var f: WeatherService.forecast[index]
                            width: 66 * g.s; height: 72 * g.s
                            radius: 14 * g.s
                            color: g.track
                            Column {
                                anchors.centerIn: parent
                                spacing: 1 * g.s
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: f.day; anchors.horizontalCenter: parent.horizontalCenter
                                       font.family: g.fontFamily; font.pixelSize: 12 * g.s
                                       font.weight: Font.Medium; color: g.ink }
                                Glyph { text: g.wxIcon(f.icon); font.pixelSize: 20 * g.s
                                        anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: f.maxTemp + "°/" + f.minTemp + "°"
                                       anchors.horizontalCenter: parent.horizontalCenter
                                       font.family: g.fontFamily; font.pixelSize: 11 * g.s
                                       color: g.ink2 }
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════
        // SYSTEM FACE
        // ════════════════════════════════════════════════════════════
        Item {
            id: sysFace
            anchors.fill: parent
            opacity: g.face === "system" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Glyph {
                text: "memory"
                color: g.accentColor
                font.pixelSize: (g.open ? 46 : 64) * g.s
                x: (g.open ? 24 : 12) * g.s
                y: (g.open ? 48 : 74) * g.s
                rotation: g.open ? 0 : -13
                transformOrigin: Item.Center
                Behavior on font.pixelSize { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on x        { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on y        { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on rotation { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }

            Row {
                spacing: 1
                y: (g.open ? 44 : 24) * g.s
                x: g.open ? 84 * g.s : (g.width - width - 20 * g.s)
                Behavior on x { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: SystemMonitorService.cpuPercent
                       font.family: g.fontFamily; font.pixelSize: 52 * g.s
                       font.weight: g.open ? Font.Medium : Font.DemiBold
                       font.letterSpacing: -2.2 * g.s; color: g.ink }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: "%"; anchors.top: parent.top; anchors.topMargin: 6 * g.s
                       font.family: g.fontFamily; font.pixelSize: 22 * g.s
                       font.weight: Font.Medium; color: g.ink }
            }

            Row {
                spacing: 4 * g.s
                x: g.width - width - 24 * g.s
                y: 92 * g.s
                opacity: g.open ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Glyph { text: "device_thermostat"; font.pixelSize: 15 * g.s; color: g.ink2 }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     text: SystemMonitorService.cpuTemp + "°C"; font.family: g.fontFamily
                       font.pixelSize: 12 * g.s; color: g.ink2 }
            }

            // ── compact tier ──
            Item {
                anchors.fill: parent
                opacity: g.open ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    x: 84 * g.s; y: 100 * g.s
                    text: Quickshell.env("USER") + " · CachyOS"
                    font.family: g.fontFamily; font.pixelSize: 14 * g.s; color: g.ink2
                }
                Column {
                    x: g.width - width - 24 * g.s
                    y: 26 * g.s
                    spacing: 9 * g.s
                    Repeater {
                        model: [
                            { ic: "device_thermostat", tx: SystemMonitorService.cpuTemp + "°C" },
                            { ic: "speed",             tx: (SystemMonitorService.cpuMhz / 1000).toFixed(1) + " GHz" },
                            { ic: "storage",           tx: SystemMonitorService.ramUsedGb.toFixed(1) + " / "
                                                          + Math.round(SystemMonitorService.ramTotalGb) + " G" }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 8 * g.s
                            layoutDirection: Qt.RightToLeft
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: modelData.tx; font.family: g.fontFamily
                                   font.pixelSize: 13 * g.s; color: g.ink2 }
                            Glyph { text: modelData.ic; font.pixelSize: 18 * g.s }
                        }
                    }
                }
                Row {
                    x: 24 * g.s; y: 122 * g.s; spacing: 10 * g.s
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: SystemMonitorService.cpuPercent < 60 ? "All systems nominal" : "Under load"
                           font.family: g.fontFamily; font.pixelSize: 15 * g.s; color: g.ink }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: SystemMonitorService.cpuName
                           anchors.baseline: parent.children[0].baseline
                           font.family: g.fontFamily; font.pixelSize: 11 * g.s; color: g.mute }
                }
            }

            // ── detail tier ──
            Item {
                anchors.fill: parent
                opacity: g.view === "detail" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Rectangle { x: 24 * g.s; y: 158 * g.s; width: g.width - 48 * g.s
                            height: 1; color: g.track }
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                     x: 24 * g.s; y: 168 * g.s; text: "MEMORY PRESSURE"
                       font.family: g.fontFamily; font.pixelSize: 11 * g.s
                       font.letterSpacing: 1 * g.s; color: g.ink2 }

                // RAM + VRAM meters
                Column {
                    x: 24 * g.s; y: 192 * g.s; spacing: 10 * g.s
                    width: g.width - 48 * g.s
                    Repeater {
                        model: [
                            { label: "RAM",  pct: SystemMonitorService.ramPercent,
                              tx: SystemMonitorService.ramUsedGb.toFixed(1) + " / "
                                  + Math.round(SystemMonitorService.ramTotalGb) + " GB" },
                            { label: "VRAM", pct: SystemMonitorService.gpuVramTotal > 0
                                  ? Math.round(SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100) : 0,
                              tx: SystemMonitorService.gpuVramUsed.toFixed(1) + " / "
                                  + Math.round(SystemMonitorService.gpuVramTotal) + " GB" }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 22 * g.s
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: modelData.label; font.family: g.fontFamily
                                   font.pixelSize: 11 * g.s; font.letterSpacing: 0.6
                                   color: g.ink2; anchors.left: parent.left }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: modelData.tx; font.family: g.fontFamily
                                   font.pixelSize: 11 * g.s; color: g.mute
                                   anchors.right: parent.right }
                            Rectangle {
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 6 * g.s; radius: height / 2; color: g.track
                                Rectangle {
                                    width: parent.width * Math.min(1, modelData.pct / 100)
                                    height: parent.height; radius: height / 2
                                    color: g.accentColor
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                        }
                    }
                }

                Row {
                    x: 24 * g.s; y: 262 * g.s; spacing: 10 * g.s
                    readonly property real cw: (g.width - 48 * g.s - 20 * g.s) / 3
                    StatCard {
                        width: parent.cw; height: 56 * g.s
                        caption: "CPU · " + SystemMonitorService.cpuName
                        value: SystemMonitorService.cpuPercent + "% · " + SystemMonitorService.cpuTemp + "°C"
                    }
                    StatCard {
                        width: parent.cw; height: 56 * g.s
                        caption: "GPU · " + SystemMonitorService.gpuName
                        value: SystemMonitorService.gpuUsage + "% · " + SystemMonitorService.gpuTemp + "°C"
                    }
                    StatCard {
                        width: parent.cw; height: 56 * g.s
                        caption: "NETWORK"
                        value: SystemMonitorService.netUp + " ↑"
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // controls — face switcher (left) + expand/collapse (right)
    // Always above the drag area, so they're always clickable.
    // On the blob they fade in on hover; on a card they're persistent.
    // ════════════════════════════════════════════════════════════════
    readonly property bool _showControls: open || rootHover.hovered

    Row {
        id: switcher
        visible: g.weatherEnabled && g.sysmonEnabled
        // `enabled` propagates to child MouseAreas. Without it the buttons stay
        // clickable while fully transparent — invisible hit targets on the blob.
        enabled: g._showControls
        opacity: g._showControls ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        spacing: 2 * g.s
        x: g.open ? 22 * g.s : (g.width - width - 44 * g.s)
        y: g.height - height - (g.open ? 12 : 8) * g.s
        Behavior on x { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }

        IconButton {
            d: (g.open ? 34 : 28) * g.s
            icon: "cloud"
            active: g.face === "weather"
            onTapped: g.face = "weather"
        }
        IconButton {
            d: (g.open ? 34 : 28) * g.s
            icon: "device_thermostat"
            active: g.face === "system"
            onTapped: g.face = "system"
        }
    }

    Row {
        id: actions
        enabled: g._showControls
        opacity: g._showControls ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        spacing: 2 * g.s
        x: g.width - width - (g.open ? 16 : 8) * g.s
        y: g.height - height - (g.open ? 12 : 8) * g.s

        IconButton {
            d: (g.open ? 40 : 30) * g.s
            icon: g.view === "detail" ? "expand_circle_up" : "expand_circle_down"
            onTapped: g.view === "blob" ? g.view = "compact" : g.cycleOpen()
        }
        IconButton {
            d: 40 * g.s
            visible: g.open
            icon: "collapse_content"
            onTapped: g.view = "blob"
        }
    }

    // If one of the two sources gets disabled in Settings, snap to the
    // surviving face so we never show an empty widget.
    onWeatherEnabledChanged: if (!weatherEnabled) face = "system"
    onSysmonEnabledChanged:  if (!sysmonEnabled)  face = "weather"

    Keys.onEscapePressed: view = "blob"
}
