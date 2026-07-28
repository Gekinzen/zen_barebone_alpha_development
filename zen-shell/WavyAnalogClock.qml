import QtQuick

/*
 * WavyAnalogClock v7.0.0-beta.1-hf99r — Karui (軽い)
 *
 * Google-Pixel "Material You" style analog clock: a scalloped / cog-edged
 * round face with chunky rounded hour + minute hands and a day label.
 * Pure QML — Canvas for the wavy face, rotated rounded Rectangles for hands.
 *
 * Drive it with `hours` / `minutes` (0–23 / 0–59) and `dayLabel`.
 */
Item {
    id: root

    property int hours: 0
    property int minutes: 0
    property string dayLabel: ""

    // Pixel-ish palette (cream face, dark hour hand, rust minute hand).
    property color faceColor:   "#e9e6dc"
    property color hourColor:   "#3d2b1f"
    property color minuteColor: "#c0632a"
    property color textColor:   "#3d2b1f"

    implicitWidth: 200
    implicitHeight: 200

    readonly property real _cx: width / 2
    readonly property real _cy: height / 2

    // ── Scalloped face ────────────────────────────────────────────
    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2, cy = height / 2
            const scallops = 12
            const baseR = Math.min(width, height) / 2 - 4
            const amp = baseR * 0.055
            const steps = 288
            ctx.beginPath()
            for (let i = 0; i <= steps; i++) {
                const a = (i / steps) * Math.PI * 2
                const r = baseR + amp * Math.cos(scallops * a)
                const x = cx + r * Math.cos(a)
                const y = cy + r * Math.sin(a)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.closePath()
            ctx.fillStyle = root.faceColor
            ctx.fill()
        }
        Component.onCompleted: requestPaint()
    }
    // repaint if the widget is resized or recoloured
    onWidthChanged: face.requestPaint()
    onHeightChanged: face.requestPaint()
    onFaceColorChanged: face.requestPaint()

    // ── Day label (top) ───────────────────────────────────────────
    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.17
        text: root.dayLabel
        color: root.textColor
        font.family: "Adwaita Sans"
        font.weight: Font.Medium
        font.pixelSize: Math.max(10, root.height * 0.1)
    }

    // ── Hour hand ─────────────────────────────────────────────────
    Rectangle {
        width: Math.max(6, root.width * 0.058)
        height: root.height * 0.28
        radius: width / 2
        antialiasing: true
        color: root.hourColor
        x: root._cx - width / 2
        y: root._cy - height
        transformOrigin: Item.Bottom
        rotation: (((root.hours % 12) + root.minutes / 60) / 12) * 360
        Behavior on rotation { RotationAnimation { duration: 400; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic } }
    }

    // ── Minute hand ───────────────────────────────────────────────
    Rectangle {
        width: Math.max(5, root.width * 0.05)
        height: root.height * 0.4
        radius: width / 2
        antialiasing: true
        color: root.minuteColor
        x: root._cx - width / 2
        y: root._cy - height
        transformOrigin: Item.Bottom
        rotation: (root.minutes / 60) * 360
        Behavior on rotation { RotationAnimation { duration: 400; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic } }
    }

    // ── Center cap ────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: root.width * 0.055
        height: width
        radius: width / 2
        antialiasing: true
        color: root.minuteColor
    }
}
