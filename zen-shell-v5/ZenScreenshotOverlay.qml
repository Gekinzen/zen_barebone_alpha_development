import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/*
 * ZenScreenshotOverlay v6.15 — Flameshot-style annotation overlay
 *
 * Flow:
 *   1. User drags to select a region (rope strings stretch from screen
 *      corners to selection corners using theme colors)
 *   2. Floating toolbar appears above the selection
 *   3. User draws annotations with 7 tools: pen, highlighter, rect,
 *      circle, arrow, line, text
 *   4. Copy (JPG to clipboard) / Save (to ~/Pictures/Screenshots) / Exit
 *
 * Capture pipeline:
 *   1. Hide overlay visually (keep window to preserve coord frame)
 *   2. grim captures the region (raw screen pixels)
 *   3. If there are annotations: render them onto the image via
 *      ImageMagick's `convert` using SVG overlay
 *   4. wl-copy --type image/jpeg  for clipboard
 *      or save to ~/Pictures/Screenshots/ for save
 *
 * Exit modes: Escape key, click outside selection, Exit button
 *
 * WALA TAYONG BABAWASAN — existing zen-screenshot.sh untouched.
 */
Item {
    id: overlayRoot
    anchors.fill: parent
    focus: true

    // ── Phase machine ──
    // "selecting" → user is dragging to select region
    // "annotating" → selection done, toolbar visible, user can draw
    property string phase: "selecting"

    // ── Monitor offset (for multi-monitor grim geometry) ──
    // Mouse coords in QML are monitor-local (0,0 = top-left of this
    // screen). grim needs GLOBAL coords (0,0 = top-left of leftmost
    // monitor in the Hyprland layout). shell.qml populates these from
    // hyprctl monitors before showing the overlay.
    property real monitorOffsetX: 0
    property real monitorOffsetY: 0

    // ── Selection box coordinates (monitor-local) ──
    property int anchorX: 0
    property int anchorY: 0
    property int anchor1X: 0
    property int anchor1Y: 0
    property int anchor2X: 0
    property int anchor2Y: 0
    property int anchorDx: anchor2X - anchor1X
    property int anchorDy: anchor2Y - anchor1Y

    property int borderWidth: 3

    // ── Active tool state (bound to toolbar) ──
    property string activeTool: "select"
    property color  activeColor: ThemeService.red
    property real   activeStroke: 3

    // ── Annotations storage ──
    // Each entry: {
    //   type: "pen" | "highlight" | "rect" | "circle" | "arrow" | "line" | "text",
    //   color: color, stroke: real,
    //   x1,y1,x2,y2: real  (for rect/circle/arrow/line)
    //   points: [{x,y},...] (for pen/highlight)
    //   text: string, x,y (for text)
    // }
    property var annotations: []
    property var currentStroke: null   // being drawn right now

    // ── Theme-derived rope colors (auto-follow current theme) ──
    readonly property color ropeColor1: ThemeService.blue
    readonly property color ropeColor2: ThemeService.purple

    // ── Output paths ──
    readonly property string screenshotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string tmpRaw: "/tmp/zen-shot-raw.png"
    readonly property string tmpOverlay: "/tmp/zen-shot-overlay.svg"
    // v6.15.1: Clipboard uses PNG — browsers/web apps (Claude, FB
    // Messenger, Discord, Slack) expect image/png for Ctrl+V paste.
    // image/jpeg is silently ignored by most web Clipboard API impls.
    readonly property string tmpFinalPng: "/tmp/zen-shot-final.png"
    readonly property string tmpFinalJpg: "/tmp/zen-shot-final.jpg"
    readonly property string timestamp: new Date().toISOString()
        .replace(/[-:T]/g, "").split(".")[0]
    readonly property string savedFilename: screenshotsDir + "/screenshot-" + timestamp + ".png"

    signal captureComplete()
    signal captureCancelled()

    // ═══════════════════════════════════════════════════════════════
    // v6.15.1: Reset state — called every time a NEW screenshot
    // session begins (overlay becomes visible AND not mid-capture).
    //
    // CRITICAL: During capture, the PanelWindow goes invisible briefly
    // (hideWindowRequested → captureInProgress = true) so grim doesn't
    // capture the rope/toolbar. That visibility toggle must NOT trigger
    // resetState or it wipes the selection coords before grim fires.
    // Guard: only reset when pendingCapture is empty (= fresh session).
    // ═══════════════════════════════════════════════════════════════
    function resetState() {
        phase = "selecting"
        anchorX = 0; anchorY = 0
        anchor1X = 0; anchor1Y = 0
        anchor2X = 0; anchor2Y = 0
        activeTool = "select"
        activeColor = ThemeService.red
        activeStroke = 3
        annotations = []
        currentStroke = null
        pendingCapture = ""
        selectionCanvas.visible = false
        if (typeof textPrompt !== "undefined") textPrompt.visible = false
        // v6.15.1: Reset rope physics so they start from clean lerp
        // positions, not tangled from a previous session
        ropeTL.resetPhysics()
        ropeTR.resetPhysics()
        ropeBL.resetPhysics()
        ropeBR.resetPhysics()
        overlayRoot.forceActiveFocus()
    }

    onVisibleChanged: {
        // Only reset on fresh session open — NOT when window hides
        // briefly during capture (pendingCapture would be "copy"/"save")
        if (visible && pendingCapture === "") {
            resetState()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Keyboard handling
    // ═══════════════════════════════════════════════════════════════
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            overlayRoot.captureCancelled()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (phase === "annotating") {
                overlayRoot.copyToClipboard()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            overlayRoot.undoLast()
            event.accepted = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Phase 1: Region selection (MouseArea full-screen)
    // ═══════════════════════════════════════════════════════════════
    MouseArea {
        id: selectArea
        anchors.fill: parent
        enabled: overlayRoot.phase === "selecting"
        visible: enabled
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 1

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                overlayRoot.captureCancelled()
                return
            }
            overlayRoot.anchorX = mouse.x
            overlayRoot.anchorY = mouse.y
            overlayRoot.anchor1X = mouse.x
            overlayRoot.anchor1Y = mouse.y
            overlayRoot.anchor2X = mouse.x
            overlayRoot.anchor2Y = mouse.y
            selectionCanvas.visible = true
        }

        onPositionChanged: (mouse) => {
            overlayRoot.anchor1X = Math.min(overlayRoot.anchorX, mouse.x)
            overlayRoot.anchor1Y = Math.min(overlayRoot.anchorY, mouse.y)
            overlayRoot.anchor2X = Math.max(overlayRoot.anchorX, mouse.x)
            overlayRoot.anchor2Y = Math.max(overlayRoot.anchorY, mouse.y)
        }

        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return
            if (overlayRoot.anchorDx < 10 || overlayRoot.anchorDy < 10) {
                overlayRoot.captureCancelled()
                return
            }
            // Enter annotation phase — toolbar appears
            overlayRoot.phase = "annotating"
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Phase 2: Annotation (MouseArea clipped to selection)
    // ═══════════════════════════════════════════════════════════════
    // v6.15.1: Resize handles — 8 drag zones at corners + edges.
    // Active only during "annotating" phase when tool is "select".
    // ═══════════════════════════════════════════════════════════════
    Repeater {
        model: [
            // [edge, cursorShape]
            // corners
            { ex: "tl", cs: Qt.SizeFDiagCursor },
            { ex: "tr", cs: Qt.SizeBDiagCursor },
            { ex: "bl", cs: Qt.SizeBDiagCursor },
            { ex: "br", cs: Qt.SizeFDiagCursor },
            // edges
            { ex: "t",  cs: Qt.SizeVerCursor },
            { ex: "b",  cs: Qt.SizeVerCursor },
            { ex: "l",  cs: Qt.SizeHorCursor },
            { ex: "r",  cs: Qt.SizeHorCursor }
        ]

        MouseArea {
            id: handle
            required property var modelData
            property string edge: modelData.ex
            property int handleSize: 12

            visible: overlayRoot.phase === "annotating" && overlayRoot.activeTool === "select"
            enabled: visible
            z: 10
            cursorShape: modelData.cs

            // Position each handle at the correct corner/edge
            x: {
                if (edge === "tl" || edge === "bl" || edge === "l")
                    return overlayRoot.anchor1X - handleSize / 2
                if (edge === "tr" || edge === "br" || edge === "r")
                    return overlayRoot.anchor2X - handleSize / 2
                // t, b — center horizontally
                return overlayRoot.anchor1X + overlayRoot.anchorDx / 2 - handleSize / 2
            }
            y: {
                if (edge === "tl" || edge === "tr" || edge === "t")
                    return overlayRoot.anchor1Y - handleSize / 2
                if (edge === "bl" || edge === "br" || edge === "b")
                    return overlayRoot.anchor2Y - handleSize / 2
                // l, r — center vertically
                return overlayRoot.anchor1Y + overlayRoot.anchorDy / 2 - handleSize / 2
            }
            width: handleSize
            height: handleSize

            property real dragStartX: 0
            property real dragStartY: 0
            property int origA1X: 0
            property int origA1Y: 0
            property int origA2X: 0
            property int origA2Y: 0

            onPressed: (mouse) => {
                dragStartX = mouse.x + x
                dragStartY = mouse.y + y
                origA1X = overlayRoot.anchor1X
                origA1Y = overlayRoot.anchor1Y
                origA2X = overlayRoot.anchor2X
                origA2Y = overlayRoot.anchor2Y
            }
            onPositionChanged: (mouse) => {
                var dx = (mouse.x + x) - dragStartX
                var dy = (mouse.y + y) - dragStartY
                // Move the appropriate edges — clamp to min 20px
                if (edge.includes("l")) {
                    var newL = Math.min(origA1X + dx, origA2X - 20)
                    overlayRoot.anchor1X = newL
                }
                if (edge.includes("r")) {
                    var newR = Math.max(origA2X + dx, origA1X + 20)
                    overlayRoot.anchor2X = newR
                }
                if (edge.includes("t")) {
                    var newT = Math.min(origA1Y + dy, origA2Y - 20)
                    overlayRoot.anchor1Y = newT
                }
                if (edge.includes("b")) {
                    var newB = Math.max(origA2Y + dy, origA1Y + 20)
                    overlayRoot.anchor2Y = newB
                }
            }

            // Visual handle dot
            Rectangle {
                anchors.fill: parent
                radius: parent.handleSize / 2
                color: overlayRoot.ropeColor1
                opacity: 0.9
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.4)
            }
        }
    }

    MouseArea {
        id: annotateArea
        x: overlayRoot.anchor1X
        y: overlayRoot.anchor1Y
        width: overlayRoot.anchorDx
        height: overlayRoot.anchorDy
        enabled: overlayRoot.phase === "annotating" && overlayRoot.activeTool !== "select"
        cursorShape: overlayRoot.activeTool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
        z: 2
        preventStealing: true

        property real startX: 0
        property real startY: 0

        onPressed: (mouse) => {
            startX = mouse.x
            startY = mouse.y
            const t = overlayRoot.activeTool
            if (t === "pen" || t === "highlight") {
                overlayRoot.currentStroke = {
                    type: t,
                    color: "" + overlayRoot.activeColor,
                    stroke: overlayRoot.activeStroke,
                    points: [{x: mouse.x, y: mouse.y}]
                }
            } else if (t === "rect" || t === "circle" || t === "arrow" || t === "line") {
                overlayRoot.currentStroke = {
                    type: t,
                    color: "" + overlayRoot.activeColor,
                    stroke: overlayRoot.activeStroke,
                    x1: mouse.x, y1: mouse.y,
                    x2: mouse.x, y2: mouse.y
                }
            } else if (t === "text") {
                // Text is single-click + prompt
                textPrompt.promptX = mouse.x
                textPrompt.promptY = mouse.y
                textPrompt.promptColor = overlayRoot.activeColor
                textPrompt.visible = true
                textPrompt.focusInput()
            }
            annotationCanvas.requestPaint()
        }

        onPositionChanged: (mouse) => {
            if (!overlayRoot.currentStroke) return
            const t = overlayRoot.currentStroke.type
            if (t === "pen" || t === "highlight") {
                overlayRoot.currentStroke.points.push({x: mouse.x, y: mouse.y})
            } else {
                overlayRoot.currentStroke.x2 = mouse.x
                overlayRoot.currentStroke.y2 = mouse.y
            }
            annotationCanvas.requestPaint()
        }

        onReleased: (mouse) => {
            if (!overlayRoot.currentStroke) return
            // Commit current stroke
            const copy = overlayRoot.annotations.slice()
            copy.push(overlayRoot.currentStroke)
            overlayRoot.annotations = copy
            overlayRoot.currentStroke = null
            annotationCanvas.requestPaint()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Selection box visual (dim background + clear hole)
    // ═══════════════════════════════════════════════════════════════
    Canvas {
        id: selectionCanvas
        anchors.fill: parent
        visible: false
        z: 0
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            // Dim background everywhere
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.5)
            ctx.fillRect(0, 0, parent.width, parent.height)

            // Clear inside selection (transparent hole)
            ctx.clearRect(
                overlayRoot.anchor1X, overlayRoot.anchor1Y,
                overlayRoot.anchorDx, overlayRoot.anchorDy)

            // Selection border
            ctx.strokeStyle = Qt.rgba(
                overlayRoot.ropeColor1.r,
                overlayRoot.ropeColor1.g,
                overlayRoot.ropeColor1.b, 0.95)
            ctx.lineWidth = overlayRoot.borderWidth
            ctx.strokeRect(
                overlayRoot.anchor1X, overlayRoot.anchor1Y,
                overlayRoot.anchorDx, overlayRoot.anchorDy)

            // Corner nubs (only while selecting)
            if (overlayRoot.phase === "selecting") {
                var corners = [
                    [overlayRoot.anchor1X, overlayRoot.anchor1Y],
                    [overlayRoot.anchor2X, overlayRoot.anchor1Y],
                    [overlayRoot.anchor1X, overlayRoot.anchor2Y],
                    [overlayRoot.anchor2X, overlayRoot.anchor2Y]
                ]
                ctx.fillStyle = Qt.rgba(
                    overlayRoot.ropeColor2.r,
                    overlayRoot.ropeColor2.g,
                    overlayRoot.ropeColor2.b, 0.95)
                for (var i = 0; i < corners.length; i++) {
                    ctx.beginPath()
                    ctx.arc(corners[i][0], corners[i][1], 6, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }
        }
    }

    // Repaint selection on anchor change
    onAnchor1XChanged: selectionCanvas.requestPaint()
    onAnchor1YChanged: selectionCanvas.requestPaint()
    onAnchor2XChanged: selectionCanvas.requestPaint()
    onAnchor2YChanged: selectionCanvas.requestPaint()
    onPhaseChanged: selectionCanvas.requestPaint()

    // ═══════════════════════════════════════════════════════════════
    // Annotation canvas (renders all shapes on top of selection)
    // v6.15.1: renderTarget = Canvas.Image forces software rendering
    // which properly supports transparency. Canvas.FramebufferObject
    // (default on some Qt builds) can produce opaque white backgrounds.
    // ═══════════════════════════════════════════════════════════════
    Canvas {
        id: annotationCanvas
        x: overlayRoot.anchor1X
        y: overlayRoot.anchor1Y
        width: overlayRoot.anchorDx
        height: overlayRoot.anchorDy
        visible: overlayRoot.phase === "annotating"
        z: 1
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // v6.15.1: Explicitly clear to transparent — ctx.reset()
            // leaves an opaque white fill on some Qt rendering backends,
            // which covers the clear selection hole from selectionCanvas
            // and makes annotations appear on a white background.
            ctx.clearRect(0, 0, width, height)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            function drawShape(s) {
                ctx.strokeStyle = s.color
                ctx.fillStyle = s.color
                ctx.lineWidth = s.stroke
                ctx.globalAlpha = (s.type === "highlight") ? 0.35 : 1.0

                if (s.type === "pen" || s.type === "highlight") {
                    if (!s.points || s.points.length < 1) return
                    if (s.type === "highlight") ctx.lineWidth = s.stroke * 5
                    ctx.beginPath()
                    ctx.moveTo(s.points[0].x, s.points[0].y)
                    for (var i = 1; i < s.points.length; i++) {
                        ctx.lineTo(s.points[i].x, s.points[i].y)
                    }
                    ctx.stroke()
                } else if (s.type === "rect") {
                    var rx = Math.min(s.x1, s.x2)
                    var ry = Math.min(s.y1, s.y2)
                    var rw = Math.abs(s.x2 - s.x1)
                    var rh = Math.abs(s.y2 - s.y1)
                    ctx.strokeRect(rx, ry, rw, rh)
                } else if (s.type === "circle") {
                    var cx = (s.x1 + s.x2) / 2
                    var cy = (s.y1 + s.y2) / 2
                    var radiusX = Math.abs(s.x2 - s.x1) / 2
                    var radiusY = Math.abs(s.y2 - s.y1) / 2
                    ctx.beginPath()
                    ctx.ellipse(cx - radiusX, cy - radiusY, radiusX * 2, radiusY * 2)
                    ctx.stroke()
                } else if (s.type === "line") {
                    ctx.beginPath()
                    ctx.moveTo(s.x1, s.y1)
                    ctx.lineTo(s.x2, s.y2)
                    ctx.stroke()
                } else if (s.type === "arrow") {
                    ctx.beginPath()
                    ctx.moveTo(s.x1, s.y1)
                    ctx.lineTo(s.x2, s.y2)
                    ctx.stroke()
                    // Arrowhead
                    var angle = Math.atan2(s.y2 - s.y1, s.x2 - s.x1)
                    var headLen = 12 + s.stroke * 2
                    ctx.beginPath()
                    ctx.moveTo(s.x2, s.y2)
                    ctx.lineTo(s.x2 - headLen * Math.cos(angle - Math.PI / 6),
                               s.y2 - headLen * Math.sin(angle - Math.PI / 6))
                    ctx.lineTo(s.x2 - headLen * Math.cos(angle + Math.PI / 6),
                               s.y2 - headLen * Math.sin(angle + Math.PI / 6))
                    ctx.closePath()
                    ctx.fill()
                } else if (s.type === "text") {
                    ctx.font = "bold " + (16 + s.stroke * 2) + "px sans-serif"
                    ctx.fillText(s.text || "", s.x, s.y)
                }
                ctx.globalAlpha = 1.0
            }

            for (var i = 0; i < overlayRoot.annotations.length; i++) {
                drawShape(overlayRoot.annotations[i])
            }
            if (overlayRoot.currentStroke) {
                drawShape(overlayRoot.currentStroke)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Rope strings from screen corners to selection corners
    // v6.15.1: IDs added so resetState() can call resetPhysics()
    // ═══════════════════════════════════════════════════════════════
    ZenRope {
        id: ropeTL
        anchors.fill: parent
        z: 3
        color: "transparent"
        anchorX: 0; anchorY: 0
        pullX: overlayRoot.anchor1X; pullY: overlayRoot.anchor1Y
        ropeColor: overlayRoot.ropeColor1
    }
    ZenRope {
        id: ropeTR
        anchors.fill: parent
        z: 3
        color: "transparent"
        anchorX: parent.width; anchorY: 0
        pullX: overlayRoot.anchor2X; pullY: overlayRoot.anchor1Y
        ropeColor: overlayRoot.ropeColor2
    }
    ZenRope {
        id: ropeBL
        anchors.fill: parent
        z: 3
        color: "transparent"
        anchorX: 0; anchorY: parent.height
        pullX: overlayRoot.anchor1X; pullY: overlayRoot.anchor2Y
        ropeColor: overlayRoot.ropeColor1
    }
    ZenRope {
        id: ropeBR
        anchors.fill: parent
        z: 3
        color: "transparent"
        anchorX: parent.width; anchorY: parent.height
        pullX: overlayRoot.anchor2X; pullY: overlayRoot.anchor2Y
        ropeColor: overlayRoot.ropeColor2
    }

    // ═══════════════════════════════════════════════════════════════
    // Size indicator — only while selecting
    // ═══════════════════════════════════════════════════════════════
    Text {
        visible: overlayRoot.phase === "selecting"
                 && overlayRoot.anchorDx > 30 && overlayRoot.anchorDy > 20
        x: overlayRoot.anchor1X + (overlayRoot.anchorDx / 2) - (implicitWidth / 2)
        y: overlayRoot.anchor2Y + 12
        z: 4
        text: overlayRoot.anchorDx + " × " + overlayRoot.anchorDy
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: overlayRoot.ropeColor1
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.8)
    }

    // ═══════════════════════════════════════════════════════════════
    // Floating toolbar (Flameshot-style, above selection)
    // ═══════════════════════════════════════════════════════════════
    ZenAnnotationToolbar {
        id: toolbar
        visible: overlayRoot.phase === "annotating"
        z: 5

        activeTool: overlayRoot.activeTool
        activeColor: overlayRoot.activeColor
        strokeWidth: overlayRoot.activeStroke

        // Position: center horizontally over selection, above if room, else below
        x: {
            var centerX = overlayRoot.anchor1X + overlayRoot.anchorDx / 2
            var tx = centerX - implicitWidth / 2
            // Clamp to screen
            if (tx < 8) tx = 8
            if (tx + implicitWidth > overlayRoot.width - 8)
                tx = overlayRoot.width - implicitWidth - 8
            return tx
        }
        y: {
            var topY = overlayRoot.anchor1Y - implicitHeight - 12
            if (topY < 8) {
                // Place below selection
                var bottomY = overlayRoot.anchor2Y + 12
                if (bottomY + implicitHeight < overlayRoot.height - 8) return bottomY
                // Still no room: overlap top of selection
                return 8
            }
            return topY
        }

        onToolPicked:   (t) => overlayRoot.activeTool   = t
        onColorPicked:  (c) => overlayRoot.activeColor  = c
        onStrokePicked: (w) => overlayRoot.activeStroke = w
        onUndoRequested:  overlayRoot.undoLast()
        onClearRequested: overlayRoot.clearAnnotations()
        onCopyRequested:  overlayRoot.copyToClipboard()
        onSaveRequested:  overlayRoot.saveToFile()
        onExitRequested:  overlayRoot.captureCancelled()
    }

    // ═══════════════════════════════════════════════════════════════
    // Text input prompt (for text annotation tool)
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: textPrompt
        visible: false
        property real promptX: 0
        property real promptY: 0
        property color promptColor: ThemeService.red

        x: overlayRoot.anchor1X + promptX
        y: overlayRoot.anchor1Y + promptY
        z: 6
        width: input.implicitWidth + 24
        height: 36
        radius: 6
        color: Qt.rgba(0, 0, 0, 0.85)
        border.width: 2
        border.color: promptColor

        function focusInput() { input.forceActiveFocus() }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: "sans-serif"
            font.pixelSize: 16
            font.bold: true
            color: textPrompt.promptColor
            selectByMouse: true
            clip: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (input.text.length > 0) {
                        const copy = overlayRoot.annotations.slice()
                        copy.push({
                            type: "text",
                            color: "" + textPrompt.promptColor,
                            stroke: overlayRoot.activeStroke,
                            x: textPrompt.promptX,
                            y: textPrompt.promptY,
                            text: input.text
                        })
                        overlayRoot.annotations = copy
                        annotationCanvas.requestPaint()
                    }
                    input.text = ""
                    textPrompt.visible = false
                    overlayRoot.forceActiveFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    input.text = ""
                    textPrompt.visible = false
                    overlayRoot.forceActiveFocus()
                    event.accepted = true
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Click-outside-selection-to-exit
    // (only during annotating, avoids clobbering the select phase)
    // ═══════════════════════════════════════════════════════════════
    MouseArea {
        anchors.fill: parent
        enabled: overlayRoot.phase === "annotating"
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        onPressed: (mouse) => {
            // If click is inside selection area OR toolbar, let it through
            const inSel = mouse.x >= overlayRoot.anchor1X
                       && mouse.x <= overlayRoot.anchor2X
                       && mouse.y >= overlayRoot.anchor1Y
                       && mouse.y <= overlayRoot.anchor2Y
            const tbX1 = toolbar.x
            const tbY1 = toolbar.y
            const tbX2 = toolbar.x + toolbar.width
            const tbY2 = toolbar.y + toolbar.height
            const inTb = mouse.x >= tbX1 && mouse.x <= tbX2
                      && mouse.y >= tbY1 && mouse.y <= tbY2
            if (!inSel && !inTb) {
                overlayRoot.captureCancelled()
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Functions — annotation management
    // ═══════════════════════════════════════════════════════════════
    function undoLast() {
        if (annotations.length === 0) return
        const copy = annotations.slice(0, annotations.length - 1)
        annotations = copy
        annotationCanvas.requestPaint()
    }

    function clearAnnotations() {
        annotations = []
        currentStroke = null
        annotationCanvas.requestPaint()
    }


    // ═══════════════════════════════════════════════════════════════
    // Capture pipeline — grim → apply annotations → clipboard/save
    //
    // v6.15 fix: SVG is written via FileView (walang shell-escape
    // issues from SVG attributes containing quotes). Window is hidden
    // before grim fires so rope/toolbar/annotations don't appear sa
    // capture. On success, auto-exit yung overlay.
    // ═══════════════════════════════════════════════════════════════

    // Track what kind of capture is pending so onExited knows what to do.
    // "" = idle, "copy" = clipboard, "save" = file
    property string pendingCapture: ""

    // Temp file holding the SVG overlay (written via FileView before grim)
    // blockWrites: true makes setText() synchronous — the SVG is
    // guaranteed to be on disk before captureDelayTimer fires. Without
    // this, magick might read an empty/incomplete SVG.
    FileView {
        id: svgFileView
        path: overlayRoot.tmpOverlay
        atomicWrites: true
        blockWrites: true
    }

    function buildAnnotationSvg() {
        const w = anchorDx, h = anchorDy
        var svg = '<svg xmlns="http://www.w3.org/2000/svg" '
                + 'width="' + w + '" height="' + h + '" '
                + 'viewBox="0 0 ' + w + ' ' + h + '">'

        function esc(s) {
            return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
        }
        function colStr(c) { return "" + c }

        for (var i = 0; i < annotations.length; i++) {
            const a = annotations[i]
            const col = colStr(a.color)
            const sw = a.stroke
            if (a.type === "pen" || a.type === "highlight") {
                if (!a.points || a.points.length < 1) continue
                var d = "M " + a.points[0].x + " " + a.points[0].y
                for (var j = 1; j < a.points.length; j++) {
                    d += " L " + a.points[j].x + " " + a.points[j].y
                }
                const hlWidth = (a.type === "highlight") ? sw * 5 : sw
                const hlOp = (a.type === "highlight") ? 0.35 : 1.0
                svg += '<path d="' + d + '" stroke="' + col + '" '
                     + 'stroke-width="' + hlWidth + '" '
                     + 'stroke-linecap="round" stroke-linejoin="round" '
                     + 'fill="none" opacity="' + hlOp + '"/>'
            } else if (a.type === "rect") {
                var rx = Math.min(a.x1, a.x2)
                var ry = Math.min(a.y1, a.y2)
                var rw = Math.abs(a.x2 - a.x1)
                var rh = Math.abs(a.y2 - a.y1)
                svg += '<rect x="' + rx + '" y="' + ry + '" width="' + rw
                     + '" height="' + rh + '" stroke="' + col
                     + '" stroke-width="' + sw + '" fill="none"/>'
            } else if (a.type === "circle") {
                var cx = (a.x1 + a.x2) / 2
                var cy = (a.y1 + a.y2) / 2
                var rdx = Math.abs(a.x2 - a.x1) / 2
                var rdy = Math.abs(a.y2 - a.y1) / 2
                svg += '<ellipse cx="' + cx + '" cy="' + cy
                     + '" rx="' + rdx + '" ry="' + rdy
                     + '" stroke="' + col + '" stroke-width="' + sw
                     + '" fill="none"/>'
            } else if (a.type === "line") {
                svg += '<line x1="' + a.x1 + '" y1="' + a.y1
                     + '" x2="' + a.x2 + '" y2="' + a.y2
                     + '" stroke="' + col + '" stroke-width="' + sw
                     + '" stroke-linecap="round"/>'
            } else if (a.type === "arrow") {
                svg += '<line x1="' + a.x1 + '" y1="' + a.y1
                     + '" x2="' + a.x2 + '" y2="' + a.y2
                     + '" stroke="' + col + '" stroke-width="' + sw
                     + '" stroke-linecap="round"/>'
                const ang = Math.atan2(a.y2 - a.y1, a.x2 - a.x1)
                const hl = 12 + sw * 2
                const hx1 = a.x2 - hl * Math.cos(ang - Math.PI / 6)
                const hy1 = a.y2 - hl * Math.sin(ang - Math.PI / 6)
                const hx2 = a.x2 - hl * Math.cos(ang + Math.PI / 6)
                const hy2 = a.y2 - hl * Math.sin(ang + Math.PI / 6)
                svg += '<polygon points="' + a.x2 + ',' + a.y2 + ' '
                     + hx1 + ',' + hy1 + ' ' + hx2 + ',' + hy2
                     + '" fill="' + col + '"/>'
            } else if (a.type === "text") {
                const fs = 16 + sw * 2
                svg += '<text x="' + a.x + '" y="' + a.y
                     + '" font-family="sans-serif" font-weight="bold" '
                     + 'font-size="' + fs + '" fill="' + col + '">'
                     + esc(a.text) + '</text>'
            }
        }
        svg += '</svg>'
        return svg
    }

    // Emitted by this overlay when it wants to hide the containing
    // PanelWindow (shell.qml listens). After hideWindowRequested, the
    // PanelWindow goes invisible → we wait ~120ms for the compositor
    // to swap frames → then grim fires → then window comes back visible
    // only long enough for captureComplete() to close it cleanly.
    signal hideWindowRequested()
    signal showWindowRequested()

    function captureToFile(outputPath, mode) {
        // mode: "copy" or "save"
        overlayRoot.pendingCapture = mode

        // 1. Write SVG to disk via FileView (no shell escaping needed)
        //    FileView.setText is synchronous when blockWrites is true.
        if (annotations.length > 0) {
            svgFileView.setText(buildAnnotationSvg())
        } else {
            svgFileView.setText("")
        }

        // 2. Ask shell.qml to hide the PanelWindow before we grim
        overlayRoot.hideWindowRequested()

        // 3. After a brief delay (let compositor unmap layer), run script
        captureDelayTimer.outputPath = outputPath
        captureDelayTimer.mode = mode
        captureDelayTimer.restart()
    }

    Timer {
        id: captureDelayTimer
        interval: 300         // give compositor time to unmap layer
        repeat: false
        property string outputPath: ""
        property string mode: ""
        onTriggered: overlayRoot._runCaptureScript(outputPath, mode)
    }

    function _runCaptureScript(outputPath, mode) {
        const globalX = anchor1X + overlayRoot.monitorOffsetX
        const globalY = anchor1Y + overlayRoot.monitorOffsetY
        const geom = globalX + "," + globalY + " " + anchorDx + "x" + anchorDy
        const hasAnnots = annotations.length > 0
        const isCopy = (mode === "copy")
        const logPath = "/tmp/zen-screenshot.log"
        // v6.15.1: Use PNG for clipboard (browsers expect image/png)
        const finalFile = tmpFinalPng

        var script = ""
            + "LOG='" + logPath + "'; "
            + "echo '=== zen-screenshot " + new Date().toISOString() + " ===' > \"$LOG\" 2>&1; "
            + "echo 'geom: " + geom + "  mode: " + mode + "' >> \"$LOG\"; "

        // Step 1: grim the region → PNG
        script += "grim -g '" + geom + "' '" + tmpRaw + "' 2>>\"$LOG\" || { "
               +  "  echo 'FAIL: grim' >> \"$LOG\"; exit 1; }; "
               +  "echo \"grim ok $(stat -c%s '" + tmpRaw + "')b\" >> \"$LOG\"; "

        // Step 2: compose annotations (if any) → PNG output
        if (hasAnnots) {
            script += "if [ -s '" + tmpOverlay + "' ] && command -v magick >/dev/null 2>&1; then "
                   +  "  magick '" + tmpRaw + "' \\( '" + tmpOverlay + "' -background none \\) "
                   +  "    -compose over -composite '" + finalFile + "' 2>>\"$LOG\" "
                   +  "    && echo 'composite ok' >> \"$LOG\" "
                   +  "    || { echo 'composite fail, using raw' >> \"$LOG\"; cp '" + tmpRaw + "' '" + finalFile + "'; }; "
                   +  "elif [ -s '" + tmpOverlay + "' ] && command -v convert >/dev/null 2>&1; then "
                   +  "  convert '" + tmpRaw + "' \\( '" + tmpOverlay + "' -background none \\) "
                   +  "    -compose over -composite '" + finalFile + "' 2>>\"$LOG\" "
                   +  "    && echo 'composite ok' >> \"$LOG\" "
                   +  "    || { echo 'composite fail, using raw' >> \"$LOG\"; cp '" + tmpRaw + "' '" + finalFile + "'; }; "
                   +  "else "
                   +  "  cp '" + tmpRaw + "' '" + finalFile + "'; "
                   +  "fi; "
        } else {
            // No annotations — raw PNG is the final output
            script += "cp '" + tmpRaw + "' '" + finalFile + "'; "
        }

        script += "echo \"final $(stat -c%s '" + finalFile + "')b\" >> \"$LOG\"; "

        // Step 3: copy or save
        if (isCopy) {
            // v6.15.1: Use grimblast-style pipe approach — proven on Hyprland.
            // `cat file | wl-copy --type image/png` keeps the pipe alive
            // while wl-copy reads and forks its clipboard daemon.
            // Fallback chain: wl-copy → xclip (for XWayland apps).
            script += "if command -v wl-copy >/dev/null 2>&1; then "
                   +  "  cat '" + finalFile + "' | wl-copy --type image/png 2>>\"$LOG\"; "
                   +  "  echo \"wl-copy=$?\" >> \"$LOG\"; "
                   +  "  wl-paste --list-types >> \"$LOG\" 2>&1; "
                   +  "elif command -v xclip >/dev/null 2>&1; then "
                   +  "  xclip -selection clipboard -t image/png -i '" + finalFile + "' 2>>\"$LOG\"; "
                   +  "  echo \"xclip=$?\" >> \"$LOG\"; "
                   +  "else "
                   +  "  echo 'no wl-copy or xclip' >> \"$LOG\"; "
                   +  "  notify-send -u critical 'Screenshot' 'wl-clipboard not installed' 2>/dev/null; "
                   +  "  exit 1; "
                   +  "fi; "
                   +  "notify-send -i '" + finalFile + "' "
                   +  "  'Screenshot copied' 'PNG in clipboard — Ctrl+V to paste' "
                   +  "  2>/dev/null || true; "
        } else {
            script += "mkdir -p '" + screenshotsDir + "'; "
                   +  "cp '" + finalFile + "' '" + outputPath + "' "
                   +  "  && echo 'saved' >> \"$LOG\" "
                   +  "  || echo 'FAIL: save' >> \"$LOG\"; "
                   +  "notify-send -i '" + outputPath + "' "
                   +  "  'Screenshot saved' '" + outputPath.split("/").pop() + "' "
                   +  "  2>/dev/null || true; "
        }

        script += "echo 'done' >> \"$LOG\""

        captureProc.command = ["bash", "-c", script]
        captureProc.running = true
    }

    function copyToClipboard() {
        captureToFile(tmpFinalPng, "copy")
    }

    function saveToFile() {
        captureToFile(savedFilename, "save")
    }

    Process {
        id: captureProc
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("[ZenScreenshotOverlay] capture script exited",
                             exitCode, "— cancelling overlay")
            }
            // Regardless of exit code, dismiss the overlay.
            // Success path: capture done, clipboard/file has image.
            // Error path: user sees no notif, but overlay closes so
            // they can retry via Super+Shift+S.
            overlayRoot.pendingCapture = ""
            overlayRoot.captureComplete()
        }
    }

    Component.onCompleted: overlayRoot.forceActiveFocus()
}
