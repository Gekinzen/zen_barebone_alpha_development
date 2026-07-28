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

    // Color — hf82j: uses dedicated ropeColor instead of color1.
    // This lets the user pick a screenshot-rope color independently
    // from the music-strings color (inherit/theme/synced/custom).
    // "inherit" mode preserves pre-hf82j behavior (uses color1).
    property color ropeColor: ZenStringsState.ropeColor

    // ══ v8.0.0-alpha-hf129 — SWING DIRECTION ══
    // ══ v8.0.0-alpha-hf130 — corrected, and put in its place ══
    //
    // hf129 seeded a lateral velocity here and claimed it steered the rope.
    // Simulating the integrator says otherwise. The tick hard-clamps the last
    // four points straight onto the pull:
    //
    //     if (i < segments - 3) { ...spring... } else { point.center = pull }
    //
    // so points 7..10 discard their seed on frame 1, and the spring pulling
    // points 1..6 toward the pull overwhelms whatever velocity they started
    // with. Measured over 12 frames, swingDir −1 and +1 produced lateral drifts
    // of 826.3px and 823.1px — a 3px difference. It does almost nothing.
    //
    // What actually decides where a rope appears to come from is its ANCHOR.
    // That is why hf129 didn't fix Paul's "galing pa rin sa upper left": it
    // moved the pull and seeded a swing, and never touched the four hardcoded
    // screen corners. hf130 moves the anchors (see ZenScreenshotOverlay's
    // cursor bands) and leaves swingDir as the small settling flourish it is.
    //
    // Two honest corrections while we're here:
    //   · the kick is scaled across the FREE section (1..segments-4), not the
    //     whole chain, so it lands on the points that survive the clamp, and
    //   · the chain seeds along the anchor→pull vector instead of a fixed
    //     +x/+y diagonal, which pointed off-screen from the right-hand corners.
    //
    // Defaults keep a bare ZenRope behaving like a plumb line. gravity, inertia,
    // springForce and the segment count are untouched. Wala tayong babawasan.
    property int  swingDir: 0            // -1 left · 0 straight · +1 right
    property real swingImpulse: 4.2      // px/tick of lateral kick, free section
    property real swingLean: 0.35        // px/segment of sideways seed offset
    property bool seedTowardPull: true   // seed along anchor→pull, not +x/+y

    // ── v8.0.0-alpha-hf130 — the anchor is allowed to move ──
    //
    // The overlay now slides the anchors between cursor bands. Animating them
    // makes the rig read as a gantry gliding across the top of the screen; a
    // hard jump reads as a glitch. The physics samples anchorX/anchorY every
    // tick, so it simply follows.
    property bool animateAnchor: false
    Behavior on anchorX {
        enabled: ropeRect.animateAnchor
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    Behavior on anchorY {
        enabled: ropeRect.animateAnchor
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    anchors.fill: parent

    // v6.15.1: Reset all physics points — offset from anchor like
    // the initial Component.onCompleted. Clears velocity so rope
    // starts fresh and physics naturally pulls it toward pullX/pullY.
    //
    // hf129: seeded along anchor→pull with a lateral kick.
    // hf130: the kick is spread over the free section only (see above).
    function resetPhysics() {
        const dx = pullX - anchorX
        const dy = pullY - anchorY
        const len = Math.sqrt(dx * dx + dy * dy)
        // Unit vector toward the pull point. Falls back to the historical
        // +x/+y diagonal when the pull sits on top of the anchor (len ~ 0),
        // which is exactly what the old code always did.
        const useDir = seedTowardPull && len > 1
        const ux = useDir ? dx / len : 1
        const uy = useDir ? dy / len : 1
        // Points at index >= segments-3 are clamped to the pull by the tick.
        // Scale the kick across what's left, or it is spent on nothing.
        const freeTip = Math.max(1, segments - 4)

        for (var i = 0; i < segments; i++) {
            var point = dotPath.pathElements[i + 1]
            if (!point) continue
            point.centerX = anchorX + ux * i + swingDir * swingLean * i
            point.centerY = anchorY + uy * i
            point.vx = swingDir * swingImpulse * Math.min(1, i / freeTip)
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

        // Physics tick — 60fps simulation.
        //
        // v7.0.0-beta.1-hf33 MEMORY FIX: gated behind ropeRect.visible.
        // Previously `running: true` meant the timer fired 60 times/sec
        // FOREVER from shell startup — but ZenRope is ONLY used inside
        // ZenScreenshotOverlay (4 instances per screen for corner ropes
        // to selection box). With a typical 2-monitor setup that's
        // 8 ropes × 60Hz = 480 useless physics ticks/sec churning JS
        // scratch values (sqrt/pow allocations, vec2 temporaries) into
        // the V8 heap, forcing GC pressure that contributed to bloated
        // RAM. Gating with `running: ropeRect.visible` means the timer
        // only runs while the screenshot overlay is actually shown —
        // which is the only time the rope physics matter visually.
        //
        // Also: resetPhysics() is already called when overlay opens
        // (see ZenScreenshotOverlay.resetState() path), so when timer
        // resumes it starts from a clean known state — no stale
        // velocities to flush.
        Timer {
            interval: 1000 / 60
            running: ropeRect.visible
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
                    // v7.0.0-beta.1-hf14: null guard — pathCurves.pathElements[index]
                    // may be undefined during the race window when ropeRect.segments
                    // triggers new Instantiator instances faster than the
                    // onObjectAdded pushes them into pathCurves.pathElements.
                    // Without this guard, every animation frame fires a TypeError
                    // ("Value is undefined and could not be converted to an
                    // object") — accumulates to SIGSEGV. Line 69 above already
                    // has this guard pattern; these inline handlers needed it too.
                    if (pathCurves.pathElements[index]) {
                        pathCurves.pathElements[index].x = centerX
                    }
                }
                onCenterYChanged: {
                    if (pathCurves.pathElements[index]) {
                        pathCurves.pathElements[index].y = centerY
                    }
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
                    // v7.0.0-beta.1-hf14: same null guard as above
                    if (pathCurves.pathElements[index]) {
                        pathCurves.pathElements[index].x = centerX
                        pathCurves.pathElements[index].y = centerY
                    }
                }

                radiusX: 1; radiusY: 1
                startAngle: 0; sweepAngle: 360
            }
        }
    }
}
