import QtQuick
import QtQuick.Layouts

/*
 * ZenAnnotationToolbar v6.15
 *
 * Flameshot-style floating toolbar that appears at the top of the
 * selected region. Exposes 7 annotation tools (pen, rect, circle,
 * arrow, line, text, highlighter), a color palette, stroke width
 * picker, copy-to-clipboard, save, and exit buttons.
 *
 * Pure visual component — emits signals for actions. All state
 * and rendering lives in ZenScreenshotOverlay.qml.
 */
Rectangle {
    id: toolbar

    // ── State ──
    property string activeTool: "select"   // select | pen | rect | circle | arrow | line | text | highlight
    property color activeColor: ThemeService.red
    property real strokeWidth: 3

    // ── Signals ──
    // Renamed to avoid QML signal-name collisions with Rectangle's
    // auto-generated property-change signals (colorChanged, widthChanged).
    signal toolPicked(string tool)
    signal colorPicked(color c)
    signal strokePicked(real w)
    signal undoRequested()
    signal clearRequested()
    signal copyRequested()
    signal saveRequested()
    signal exitRequested()

    // ── Appearance ──
    readonly property color bgCol: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g,
                                           ThemeService.bg0.b, 0.95)
    readonly property color fgCol: ThemeService.fg
    readonly property color dimCol: ThemeService.grey1

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 52
    radius: 12
    color: bgCol
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.15)

    // Shadow approximation
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        z: -1
        radius: parent.radius + 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.4)
    }

    // ── Helper: icon button ──
    component IconBtn : Rectangle {
        id: btn
        property string glyph: ""
        property string tooltip: ""
        property bool active: false
        property color glyphColor: toolbar.fgCol
        signal clicked()

        width: 36
        height: 36
        radius: 8
        color: active
            ? ThemeService.alpha(toolbar.activeColor, 0.25)
            : (ma.containsMouse ? ThemeService.alpha(toolbar.fgCol, 0.1) : "transparent")
        border.width: active ? 1 : 0
        border.color: ThemeService.alpha(toolbar.activeColor, 0.6)

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 18
            color: btn.glyphColor
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        // Tooltip
        Rectangle {
            visible: ma.containsMouse && btn.tooltip.length > 0
            anchors.top: parent.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: tt.implicitWidth + 14
            height: tt.implicitHeight + 8
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.85)
            z: 10
            Text {
                id: tt
                anchors.centerIn: parent
                text: btn.tooltip
                color: "white"
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    // ── Color swatch ──
    component ColorDot : Rectangle {
        property color c: "white"
        property bool active: false
        signal clicked()

        width: 22
        height: 22
        radius: 11
        color: c
        border.width: active ? 3 : (ma2.containsMouse ? 2 : 1)
        border.color: active
            ? toolbar.fgCol
            : (ma2.containsMouse ? ThemeService.alpha(toolbar.fgCol, 0.7)
                                 : ThemeService.alpha(toolbar.fgCol, 0.3))

        Behavior on border.width { NumberAnimation { duration: 100 } }

        MouseArea {
            id: ma2
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // ── Vertical divider ──
    component Divider : Rectangle {
        width: 1
        height: 28
        color: ThemeService.alpha(toolbar.fgCol, 0.2)
        Layout.alignment: Qt.AlignVCenter
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 4

        // ── Tool buttons ──
        IconBtn {
            glyph: "\uf245"  // cursor
            tooltip: "Select"
            active: toolbar.activeTool === "select"
            onClicked: { toolbar.activeTool = "select"; toolbar.toolPicked("select") }
        }
        IconBtn {
            glyph: "\uf303"  // pencil
            tooltip: "Pen (freehand)"
            active: toolbar.activeTool === "pen"
            onClicked: { toolbar.activeTool = "pen"; toolbar.toolPicked("pen") }
        }
        IconBtn {
            glyph: "\uf591"  // highlighter
            tooltip: "Highlighter"
            active: toolbar.activeTool === "highlight"
            onClicked: { toolbar.activeTool = "highlight"; toolbar.toolPicked("highlight") }
        }
        IconBtn {
            glyph: "\uf096"  // square
            tooltip: "Rectangle"
            active: toolbar.activeTool === "rect"
            onClicked: { toolbar.activeTool = "rect"; toolbar.toolPicked("rect") }
        }
        IconBtn {
            glyph: "\uf111"  // circle
            tooltip: "Circle"
            active: toolbar.activeTool === "circle"
            onClicked: { toolbar.activeTool = "circle"; toolbar.toolPicked("circle") }
        }
        IconBtn {
            glyph: "\uf061"  // arrow-right
            tooltip: "Arrow"
            active: toolbar.activeTool === "arrow"
            onClicked: { toolbar.activeTool = "arrow"; toolbar.toolPicked("arrow") }
        }
        IconBtn {
            glyph: "\uf068"  // minus (line)
            tooltip: "Line"
            active: toolbar.activeTool === "line"
            onClicked: { toolbar.activeTool = "line"; toolbar.toolPicked("line") }
        }
        IconBtn {
            glyph: "\uf031"  // font
            tooltip: "Text"
            active: toolbar.activeTool === "text"
            onClicked: { toolbar.activeTool = "text"; toolbar.toolPicked("text") }
        }

        Divider {}

        // ── Color palette ──
        ColorDot {
            c: ThemeService.red
            active: Qt.colorEqual(toolbar.activeColor, ThemeService.red)
            onClicked: { toolbar.activeColor = ThemeService.red; toolbar.colorPicked(ThemeService.red) }
        }
        ColorDot {
            c: ThemeService.orange
            active: Qt.colorEqual(toolbar.activeColor, ThemeService.orange)
            onClicked: { toolbar.activeColor = ThemeService.orange; toolbar.colorPicked(ThemeService.orange) }
        }
        ColorDot {
            c: ThemeService.yellow
            active: Qt.colorEqual(toolbar.activeColor, ThemeService.yellow)
            onClicked: { toolbar.activeColor = ThemeService.yellow; toolbar.colorPicked(ThemeService.yellow) }
        }
        ColorDot {
            c: ThemeService.green
            active: Qt.colorEqual(toolbar.activeColor, ThemeService.green)
            onClicked: { toolbar.activeColor = ThemeService.green; toolbar.colorPicked(ThemeService.green) }
        }
        ColorDot {
            c: ThemeService.blue
            active: Qt.colorEqual(toolbar.activeColor, ThemeService.blue)
            onClicked: { toolbar.activeColor = ThemeService.blue; toolbar.colorPicked(ThemeService.blue) }
        }
        ColorDot {
            c: ThemeService.purple
            active: Qt.colorEqual(toolbar.activeColor, ThemeService.purple)
            onClicked: { toolbar.activeColor = ThemeService.purple; toolbar.colorPicked(ThemeService.purple) }
        }
        ColorDot {
            c: "#ffffff"
            active: Qt.colorEqual(toolbar.activeColor, "#ffffff")
            onClicked: { toolbar.activeColor = "#ffffff"; toolbar.colorPicked("#ffffff") }
        }
        ColorDot {
            c: "#000000"
            active: Qt.colorEqual(toolbar.activeColor, "#000000")
            onClicked: { toolbar.activeColor = "#000000"; toolbar.colorPicked("#000000") }
        }

        Divider {}

        // ── Stroke width picker ──
        Rectangle {
            width: 60
            height: 28
            radius: 6
            color: ThemeService.alpha(toolbar.fgCol, 0.08)
            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [2, 3, 5, 8]
                    Rectangle {
                        width: 12; height: 12
                        radius: 6
                        color: toolbar.strokeWidth === modelData
                            ? toolbar.activeColor
                            : ThemeService.alpha(toolbar.fgCol, 0.4)
                        border.width: 1
                        border.color: ThemeService.alpha(toolbar.fgCol, 0.3)
                        scale: (modelData / 8) * 0.6 + 0.5
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                toolbar.strokeWidth = modelData
                                toolbar.strokePicked(modelData)
                            }
                        }
                    }
                }
            }
        }

        Divider {}

        // ── Action buttons ──
        IconBtn {
            glyph: "\uf0e2"  // undo
            tooltip: "Undo (Ctrl+Z)"
            onClicked: toolbar.undoRequested()
        }
        IconBtn {
            glyph: "\uf1f8"  // trash
            tooltip: "Clear all"
            glyphColor: ThemeService.orange
            onClicked: toolbar.clearRequested()
        }

        Divider {}

        IconBtn {
            glyph: "\uf0c5"  // copy
            tooltip: "Copy JPG (Enter)"
            glyphColor: ThemeService.green
            onClicked: toolbar.copyRequested()
        }
        IconBtn {
            glyph: "\uf0c7"  // save
            tooltip: "Save to file"
            glyphColor: ThemeService.blue
            onClicked: toolbar.saveRequested()
        }
        IconBtn {
            glyph: "\uf00d"  // x / close
            tooltip: "Exit (Esc)"
            glyphColor: ThemeService.red
            onClicked: toolbar.exitRequested()
        }
    }
}
