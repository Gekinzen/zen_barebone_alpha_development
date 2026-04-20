import QtQuick
import QtQuick.Shapes

/*
 * ZenRope v6.15.1 — Physics-based rope/string simulation
 *
 * Adapted from Zephyr dotfiles (flicko) — Rope.qml
 * Used in screenshot overlay: 4 ropes from screen corners to selection box.
 *
 * Physics: Each segment has position + velocity. Gravity pulls down,
 * spring forces connect segments, damping prevents oscillation explosion.
 * Renders as a curved ShapePath using PathCurve for smooth catenary look.
 *
 * v6.15.1 changes (from v6.14.2):
 *   - Reverted to flicko-original segment count (10) and length (5) —
 *     short, tightly-coupled segments drape like real rope instead of
 *     stiff springs. Previous 30×50 was way too rigid.
 *   - Uses flicko-original gravity (9.8) and damping (0.5/0.45) —
 *     proven smooth catenary feel
 *   - Changed init from lerp-to-pull to offset-from-anchor (flicko
 *     original) — works correctly when pullX/pullY are 0 at creation
 *   - Added resetPhysics() — called when overlay re-opens so rope
 *     starts fresh, not tangled from previous session
 *
 * WALA TAYONG BABAWASAN.
 */
Rectangle {
    id: ropeRect
    color: "transparent"

    // Anchor = fixed point (screen corner)
    property int anchorX: 0
    property int anchorY: 0

    // Pull = dynamic point (follows cursor / selection box corner)
    property int pullX: 100
    property int pullY: 100

    // v6.15.1: Use flicko-original values for smooth drape.
    // Short segments + small rest length = smooth catenary curve.
    // The spring physics stretches segments beyond rest length naturally —
    // gravity (9.8/tick) adds catenary sag, damping (0.5/0.45) lets
    // the rope swing with gentle overshoot before settling.
    property int segments: 10
    property int segment_length: 5

    // v6.15.1: Exposed as properties for future tuning.
    // These are flicko's exact original values — proven smooth.
    property real gravity: 9.8        // Earth-like, creates visible sag
    property real inertia: 0.5        // momentum carry — 50%
    property real springForce: 0.45   // spring pull — 45%

    // Color — inherits from theme
    property color ropeColor: ZenStringsState.color1

    anchors.fill: parent

    // v6.15.1: Reset all physics points — offset from anchor like
    // the initial Component.onCompleted. Clears velocity so rope
    // starts fresh and physics naturally pulls it toward pullX/pullY.
    function resetPhysics() {
        for (var i = 0; i < segments; i++) {
            var point = dotPath.pathElements[i + 1]
            if (!point) continue
            point.centerX = anchorX + i
            point.centerY = anchorY + i
            point.vx = 0
            point.vy = 0
            if (pathCurves.pathElements[i]) {
                pathCurves.pathElements[i].x = point.centerX
                pathCurves.pathElements[i].y = point.centerY
            }
        }
    }

    Shape {
        id: rope
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer

        // Curve path elements (visual output)
        Instantiator {
            model: ropeRect.segments
            onObjectAdded: (index, pathCurve) => {
                pathCurves.pathElements.push(pathCurve)
            }
            delegate: PathCurve {
                property int index: model.index
                x: 500; y: 500
            }
        }

        ShapePath {
            id: pathCurves
            strokeColor: ropeRect.ropeColor
            fillColor: "transparent"
            strokeWidth: ZenStringsState.strokeWidth
            startX: ropeRect.anchorX
            startY: ropeRect.anchorY
        }

        // Dot path (physics simulation points)
        ShapePath {
            id: dotPath

            PathAngleArc {
                id: startPoint
                property int index: -1
                property double dx: 0
                property double dy: 0
                property double vx: 0
                property double vy: 0

                onCenterXChanged: { pathCurves.startX = centerX }
                onCenterYChanged: { pathCurves.startY = centerY }

                centerX: ropeRect.anchorX
                centerY: ropeRect.anchorY
                radiusX: 3; radiusY: 3
                startAngle: 0; sweepAngle: 360
            }
        }

        // Physics tick — 60fps simulation
        Timer {
            interval: 1000 / 60
            running: true
            repeat: true

            onTriggered: {
                for (var i = ropeRect.segments; i > 0; i--) {
                    var point = dotPath.pathElements[i]
                    var line = pathCurves.pathElements[i - 1]
                    var prev = dotPath.pathElements[i - 1]

                    var prevDx = prev.centerX - point.centerX
                    var prevDy = prev.centerY - point.centerY

                    var prevDist = Math.sqrt(Math.pow(prevDx, 2) + Math.pow(prevDy, 2))
                    var prevExtend = prevDist - ropeRect.segment_length

                    var vx = (prevDx / prevDist) * prevExtend
                    var vy = (prevDy / prevDist) * prevExtend + ropeRect.gravity

                    if (isNaN(vx)) vx = 0
                    if (isNaN(vy)) vy = 0

                    if (i < ropeRect.segments - 3) {
                        var next = dotPath.pathElements[i + 1]
                        var nextDx = next.centerX - point.centerX
                        var nextDy = next.centerY - point.centerY
                        var nextDist = Math.sqrt(Math.pow(nextDx, 2) + Math.pow(nextDy, 2))
                        var nextExtend = nextDist - ropeRect.segment_length

                        vx += (nextDx / nextDist) * nextExtend
                        vy += (nextDy / nextDist) * nextExtend
                    } else {
                        var toX = ropeRect.pullX
                        var toY = ropeRect.pullY
                        point.centerX = toX
                        point.centerY = toY
                    }

                    // flicko-original damping: 0.5 inertia / 0.45 spring.
                    // Balanced — enough momentum for fluid swing, enough
                    // spring pull to converge. Proven smooth in Zephyr.
                    point.vx = point.vx * ropeRect.inertia + vx * ropeRect.springForce
                    point.vy = point.vy * ropeRect.inertia + vy * ropeRect.springForce

                    point.centerX += point.vx
                    point.centerY += point.vy
                }
            }
        }

        // Physics point instantiator
        Instantiator {
            model: ropeRect.segments
            onObjectAdded: (index, pathArc) => {
                dotPath.pathElements.push(pathArc)
            }
            delegate: PathAngleArc {
                property int index: model.index
                property double dx: 0
                property double dy: 0
                property double vx: 0
                property double vy: 0

                onCenterXChanged: {
                    pathCurves.pathElements[index].x = centerX
                }
                onCenterYChanged: {
                    pathCurves.pathElements[index].y = centerY
                }
                Component.onCompleted: {
                    // v6.15.1: Use flicko-original init — small offset
                    // per index from anchor point. This gives each segment
                    // initial separation so physics has something to work
                    // with from frame 1. Lerp to pullX/pullY doesn't work
                    // because at creation time pull coords may be 0,0
                    // (overlay just appeared, no drag yet).
                    centerX = ropeRect.anchorX + index
                    centerY = ropeRect.anchorY + index
                    pathCurves.pathElements[index].x = centerX
                    pathCurves.pathElements[index].y = centerY
                }

                radiusX: 1; radiusY: 1
                startAngle: 0; sweepAngle: 360
            }
        }
    }
}
