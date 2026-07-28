import QtQuick
import QtQuick.Shapes
import Quickshell
import Qt5Compat.GraphicalEffects

/*
 * ZenStrings v6.15 — Audio-reactive string renderer
 *
 * Used by MusicStrings.qml as the visual layer.
 * isAudioActive: true = animated bezier (cava), false = static line.
 * Color mode: "theme" | "synced" | "custom"
 *
 * Adapted from Zephyr dotfiles (flicko) — FastMusicLine.qml
 */
Item {
    id: root
    // clip: false intentionally — curves must overflow the bar bounds freely
    // The strings rope effect needs to bow above/below the bar slot

    property bool isAudioActive: false
    property var cavaData: []

    readonly property int dotPadding: 24
    readonly property int dotRadius: 6
    readonly property int curveStart: dotPadding
    readonly property int curveEnd: width - dotPadding
    readonly property int curveLen: Math.max(1, curveEnd - curveStart)

    function _resolveKey(key) {
        switch(key) {
            case "red":    return ThemeService.red
            case "orange": return ThemeService.orange
            case "yellow": return ThemeService.yellow
            case "green":  return ThemeService.green
            case "aqua":   return ThemeService.aqua
            case "blue":   return ThemeService.blue
            case "purple": return ThemeService.purple
            case "fg":     return ThemeService.fg
            case "grey0":  return ThemeService.grey0
            default:       return ThemeService.blue
        }
    }

    // v8.0.0-alpha-hf120 — was coercing ZenStringsState.customColor1 (a *string*)
    // straight to `color`. An 8-hex string parses as #AARRGGBB, so the rendered
    // string got a different colour than the swatch showed. ZenStringsState.color1
    // already resolves mode + normalises the hex; just use it. Same semantics,
    // one source of truth.
    property color color1: ZenStringsState.color1
    property color color2: ZenStringsState.color2

    property int segments: ZenStringsState.segments
    property int curveHeight: ZenStringsState.curveHeight

    // slotCenterY: the Y position of the actual bar slot center within
    // this Item. Since this Item is taller than the bar (inflated by
    // curveHeight each side), center is NOT height/2.
    // MusicStrings passes this as: parent.height/2 (its own slot height / 2)
    // mapped into this Item's coordinate space.
    // Default: height/2 (safe fallback for equal inflation both sides).
    property real slotCenterY: height / 2

    // v7.0.0-alpha.5 (Karui Laptop Mode): audio-mode falls back to
    // static mode when LaptopModeService.audioRopeAllowed is false.
    // This kicks in only when user is on battery + Endurance + capacity
    // below 30% (see LaptopModeService.qml header for the table).
    // When LaptopModeService is undefined (very early init) or its mode
    // is "off", the rope behaves identically to v6.
    readonly property bool _audioAllowed:
        (typeof LaptopModeService === "undefined") || LaptopModeService.audioRopeAllowed
    readonly property string effectiveMode:
        (isAudioActive && _audioAllowed) ? "audio" : "static"

    // ── AUDIO MODE ──
    Glow {
        visible: effectiveMode === "audio" && ZenStringsState.glowEnabled
        anchors.fill: parent
        radius: ZenStringsState.glowRadius
        samples: 17
        color: Qt.rgba(0, 0, 0, 0.2)
        source: audioShape
    }

    Shape {
        id: audioShape
        visible: effectiveMode === "audio"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Instantiator {
            model: root.segments
            onObjectAdded: (index, sp) => { audioShape.data.push(sp) }
            delegate: ShapePath {
                readonly property int idx: model.index

                function colorMix(c1, c2, w) {
                    var ww = w * 2 - 1; var w1 = (ww / 2) + 0.5; var w2 = 1 - w1
                    return Qt.rgba(c1.r*w1+c2.r*w2, c1.g*w1+c2.g*w2, c1.b*w1+c2.b*w2, c1.a*w1+c2.a*w2)
                }

                strokeWidth: {
                    var cv = (idx < root.cavaData.length) ? root.cavaData[idx] : 0
                    return Math.max(1, ZenStringsState.strokeWidth - 2 * cv)
                }
                strokeColor: {
                    var mix = colorMix(root.color1, root.color2, idx / root.segments)
                    // v7.0.0-beta.1-hf38: Only apply the alternating
                    // Qt.darker treatment when colorMode is "theme" or
                    // "synced" — those modes deliberately add visual
                    // rhythm through alternating tone variation.
                    //
                    // When the user picks specific custom hex colors,
                    // they expect those EXACT colors to appear (e.g.
                    // #ff6464ff red + #81f16eff green should produce
                    // a clean red→green gradient without half the
                    // strings being darkened to ~67% of the picked
                    // value). This was the "iba yung lumalabas na
                    // color" bug from Paul's hf37 test.
                    if (ZenStringsState.colorMode === "custom") {
                        return mix
                    }
                    return (idx % 2 === 0) ? Qt.darker(mix, 1.5) : mix
                }
                fillColor: "transparent"

                startX: root.curveStart
                startY: root.slotCenterY
                pathHints: ShapePath.PathQuadratic

                PathCubic {
                    x: root.curveEnd; y: root.slotCenterY
                    property real cv: (idx < root.cavaData.length) ? root.cavaData[idx] : 0
                    control1X: {
                        var raw = (idx > root.segments/2
                            ? idx-1+cv*1.5 : idx-1-cv*1.5) * root.curveLen / root.segments
                        return root.curveStart + raw
                    }
                    control1Y: {
                        var centerY = root.slotCenterY
                        return (idx < root.segments/4 || idx > root.segments*3/4)
                            ? centerY - root.curveHeight * cv
                            : centerY + root.curveHeight * cv
                    }
                    control2X: root.curveEnd; control2Y: root.slotCenterY
                }
            }
        }

        ShapePath {
            strokeColor: "transparent"; fillColor: root.color1
            startX: root.curveStart; startY: root.slotCenterY
            PathAngleArc {
                centerX: root.curveStart; centerY: root.slotCenterY
                radiusX: root.dotRadius; radiusY: root.dotRadius
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: "transparent"; fillColor: root.color2
            startX: root.curveEnd; startY: root.slotCenterY
            PathAngleArc {
                centerX: root.curveEnd; centerY: root.slotCenterY
                radiusX: root.dotRadius; radiusY: root.dotRadius
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // ── STATIC MODE ──
    Glow {
        visible: effectiveMode === "static" && ZenStringsState.glowEnabled
        anchors.fill: parent
        radius: ZenStringsState.glowRadius
        samples: 17
        color: Qt.rgba(0, 0, 0, 0.2)
        source: staticShape
    }

    Shape {
        id: staticShape
        visible: effectiveMode === "static"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color1; fillColor: "transparent"
            strokeWidth: ZenStringsState.strokeWidth
            startX: root.curveStart; startY: root.slotCenterY
            PathLine { x: root.curveEnd; y: root.slotCenterY }
        }
        ShapePath {
            strokeColor: "transparent"; fillColor: root.color1
            PathAngleArc {
                centerX: root.curveStart; centerY: root.slotCenterY
                radiusX: root.dotRadius; radiusY: root.dotRadius
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: "transparent"; fillColor: root.color2
            PathAngleArc {
                centerX: root.curveEnd; centerY: root.slotCenterY
                radiusX: root.dotRadius; radiusY: root.dotRadius
                startAngle: 0; sweepAngle: 360
            }
        }
    }
}
