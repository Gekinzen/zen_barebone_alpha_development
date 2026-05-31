import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/*
 * DesktopStickyNotes v7.0.0-beta.1-hf82d — Karui (軽い)
 *
 * Sibling of DesktopWidgets.qml — hosts sticky notes that are in
 * "widget mode" (QuickNotesService.isStickyDraggable(id) === true).
 *
 * Mounted by shell.qml inside the SAME per-screen PanelWindow at
 * WlrLayer.Bottom that hosts the clock/weather/CPU temp widgets. So
 * widget-mode stickies behave exactly like those:
 *   - Below regular windows (your browser/IDE sits on top)
 *   - Above the wallpaper
 *   - Draggable anywhere on the screen
 *   - Position persisted across shell restarts
 *
 * Stickies in NORMAL mode (toggle off) stay on the Overlay layer via
 * the original QuickNotesSticky.qml mount in shell.qml — that's how
 * they get to float on top of everything when you need them in your
 * face. The two are mutually exclusive: a given note ID renders in
 * EITHER DesktopStickyNotes OR QuickNotesSticky, never both.
 *
 * Drag pattern: same as DesktopWidgets.qml clock/weather/sysmon —
 *   - Imperative x/y on the card Rectangle (not bound)
 *   - drag.target: card on the MouseArea
 *   - preventStealing: true
 *   - persist position on release
 *   - guard against re-apply during active drag
 *
 * User request:
 *   "dapt draggable tas san yun toggle pre buo dapat sticky ma tag
 *    na din sa widget sa desktop ko mismo prang heto mga clock gets?
 *    draggable nadin tas yan super shift n daapt draggable din yan
 *    tas kapag toggle on niya widget modee automatically magiging
 *    katulad nung mga clock widget ko"
 *
 * Translation: stickies should integrate into the desktop widgets
 * surface so they behave exactly like the clock/weather/CPU widgets
 * when widget-mode is enabled. That's what this file delivers.
 */
Item {
    id: dsn
    anchors.fill: parent

    // ────────────────────────────────────────────────────────────
    // ACTIVE WIDGET-MODE STICKY IDS
    // ────────────────────────────────────────────────────────────
    //
    // Computed from QuickNotesService.stickyIds intersect with
    // stickyDraggable[id] === true. Recomputes when either changes.
    readonly property var widgetStickyIds: {
        const out = []
        for (const id of QuickNotesService.stickyIds) {
            if (QuickNotesService.isStickyDraggable(id)) {
                out.push(id)
            }
        }
        return out
    }

    // ────────────────────────────────────────────────────────────
    // DRAG-ACTIVE GUARD — shared across all sticky widget instances.
    //
    // Mirrors DesktopWidgets' _anyDragActive readonly. When ANY
    // sticky is currently being dragged, individual widgets must
    // skip the "re-apply saved position" handler — otherwise the
    // stickyPositionsChanged signal (which fires on drag release
    // for the dragger) would snap OTHER stickies back to their
    // saved positions if they happened to share a noteId match.
    //
    // We don't need to track individual MouseArea.drag.active here
    // because each card has its own dragArea below; they peek at
    // this property via the parent chain.
    property bool _anyDragActive: false

    // ────────────────────────────────────────────────────────────
    // HIGHLIGHT BUS
    //
    // Listens for QuickNotesService.highlightWidgetStickies() and
    // re-fires the shake + glow + bounce sequence on every mounted
    // sticky card. Each card has its own animation set; this is
    // just the trigger.
    //
    // We use a counter property — incrementing it bumps the
    // animations via property binding. Simpler than maintaining
    // a list of card references.
    property int _highlightTick: 0

    Connections {
        target: QuickNotesService
        function onHighlightWidgetStickies() {
            dsn._highlightTick = dsn._highlightTick + 1
        }
    }

    // ────────────────────────────────────────────────────────────
    // STICKY CARDS
    // ────────────────────────────────────────────────────────────
    //
    // v7.0.0-beta.1-hf50: switched from Loader wrapper to direct
    // Rectangle delegate. The previous Loader had 0x0 bounds (no
    // anchors/size), so mouse hit-testing on the card inside FAILED
    // — drag and clicks both ignored even though the card visually
    // rendered. Direct Rectangle delegate gives the card proper
    // bounds = the card's own width/height = 280x220, which matches
    // its hit region.
    Repeater {
        id: stickyRepeater
        model: dsn.widgetStickyIds

        delegate: stickyCardComponent
    }

    // ────────────────────────────────────────────────────────────
    // STICKY CARD COMPONENT
    // ────────────────────────────────────────────────────────────
    Component {
        id: stickyCardComponent

        Rectangle {
            id: card

            // modelData is the noteId string from Repeater's model
            // (dsn.widgetStickyIds). Use directly — no Loader proxy.
            readonly property string noteId: modelData || ""

            readonly property var note: QuickNotesService.getNote(noteId)

            // Card sizing matches QuickNotesSticky for visual parity
            width: 280
            height: 220
            radius: 6
            color: "#fdf6a8"
            // v7.0.0-beta.1-hf51: border color reflects focus state.
            // When editing → blue tint so user clearly sees "this is
            // the active sticky." When not editing → muted tan border
            // = "passive widget, won't capture keys." The
            // _editorHasFocus property is set by the TextArea's
            // onActiveFocusChanged handler further down.
            property bool _editorHasFocus: false
            border.color: _editorHasFocus ? "#5288c9" : "#c9b96c"
            border.width: _editorHasFocus ? 2 : 1
            Behavior on border.color { ColorAnimation { duration: 150 } }
            clip: true

            // ── Drop shadow ──
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.topMargin: 2
                z: -1
                radius: 6
                color: "transparent"
                border.color: Qt.rgba(0, 0, 0, 0.18)
                border.width: 2
            }

            // ── Highlight glow border (animated on _highlightTick) ──
            Rectangle {
                id: glowBorder
                anchors.fill: parent
                anchors.margins: -3
                radius: 9
                color: "transparent"
                border.width: 3
                border.color: "#4caf50"   // green pulse
                opacity: 0
                z: -2

                SequentialAnimation on opacity {
                    id: glowAnim
                    running: false
                    loops: 2
                    NumberAnimation { to: 0.9; duration: 200; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0.0; duration: 500; easing.type: Easing.InQuad }
                }
            }

            // ── Shake + bounce animation triggered by _highlightTick ──
            //
            // Both run in parallel: the card translates left/right
            // (shake) while also bouncing slightly down then up.
            // Triggered by watching parent's _highlightTick value
            // — every increment fires the animations once.
            property int _localTick: 0
            Connections {
                target: dsn
                function on_HighlightTickChanged() {
                    if (dsn._highlightTick !== card._localTick) {
                        card._localTick = dsn._highlightTick
                        shakeAnim.restart()
                        bounceAnim.restart()
                        glowAnim.start()
                    }
                }
            }

            transform: [
                Translate { id: shakeT; x: 0 },
                Translate { id: bounceT; y: 0 }
            ]

            SequentialAnimation {
                id: shakeAnim
                running: false
                loops: 3
                NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to:  6; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 60 }
            }

            SequentialAnimation {
                id: bounceAnim
                running: false
                loops: 1
                NumberAnimation { target: bounceT; property: "y"; to:  6; duration: 120 }
                NumberAnimation { target: bounceT; property: "y"; to: -3; duration: 120 }
                NumberAnimation { target: bounceT; property: "y"; to:  0; duration: 120 }
            }

            // ── Initial position from saved state or hash fallback ──
            //
            // Imperative writes (DesktopWidgets v6.11e pattern). No
            // declarative binding on x/y to avoid drag.target fight.
            Component.onCompleted: {
                const saved = QuickNotesService.getStickyPosition(card.noteId)
                if (saved) {
                    card.x = saved.x
                    card.y = saved.y
                } else {
                    // Hash-derived fallback
                    let h = 0
                    for (let i = 0; i < card.noteId.length; i++) {
                        h = ((h << 5) - h) + card.noteId.charCodeAt(i)
                        h |= 0
                    }
                    card.x = 80 + (Math.abs(h) % 400)
                    let h2 = 0
                    for (let i = 0; i < card.noteId.length; i++) {
                        h2 = ((h2 << 7) - h2) + card.noteId.charCodeAt(i)
                        h2 |= 0
                    }
                    card.y = 100 + (Math.abs(h2) % 250)
                }
            }

            // ── Re-apply saved position when stickyPositions changes
            //    externally — but only if WE aren't the active dragger.
            Connections {
                target: QuickNotesService
                function onStickyPositionsChanged() {
                    if (dragArea.drag.active) return
                    const saved = QuickNotesService.getStickyPosition(card.noteId)
                    if (saved && (card.x !== saved.x || card.y !== saved.y)) {
                        card.x = saved.x
                        card.y = saved.y
                    }
                }
            }

            // ── Re-fetch note when notes[] changes ──
            Connections {
                target: QuickNotesService
                function onNotesChanged() {
                    // Force re-evaluation of card.note binding
                    card.noteRefresh = card.noteRefresh + 1
                }
            }
            property int noteRefresh: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // ── Title bar ──
                //
                // v7.0.0-beta.1-hf49 drag fix: the dragArea is now a
                // visible Rectangle (full title-bar background) that
                // OWNS the click events. Button MouseAreas overlap on
                // top as children of a Row that sits at higher z by
                // virtue of natural QML rendering order (later
                // siblings = above).
                //
                // Previous hf46/47 pattern had dragArea with `z: -1`
                // which placed it BELOW the parent Rectangle's draw
                // layer — events landed on the parent's empty space
                // and never reached the MouseArea. Result: drag
                // didn't work even though everything looked right.
                //
                // ControlPanel.qml uses this exact same pattern and
                // its drag works flawlessly, so we copy verbatim.
                Rectangle {
                    id: titleBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    color: Qt.rgba(0, 0, 0, dragArea.containsMouse ? 0.06 : 0.03)
                    radius: 4
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // FIRST CHILD — drag MouseArea, fills the whole
                    // title bar. Catches drags on any blank pixels.
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active
                                     ? Qt.ClosedHandCursor
                                     : Qt.OpenHandCursor
                        preventStealing: true

                        drag.target: card
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 0
                        drag.minimumY: 0
                        drag.maximumX: dsn.width - card.width
                        drag.maximumY: dsn.height - card.height

                        onPressed: dsn._anyDragActive = true
                        onReleased: {
                            dsn._anyDragActive = false
                            QuickNotesService.setStickyPosition(
                                card.noteId, card.x, card.y)
                        }
                    }

                    // SECOND CHILD — RowLayout with buttons. Sits on
                    // top of dragArea by render order. Each button
                    // has its own MouseArea that catches clicks for
                    // its specific region. Empty space between buttons
                    // falls through to dragArea below.
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 6

                        // ⭐ — un-stick (closes the widget, removes from sticky list)
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: starMa.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\uf005"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 9
                                color: "#c9a200"
                            }
                            MouseArea {
                                id: starMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: QuickNotesService.toggleSticky(card.noteId)
                            }
                            ToolTip.visible: starMa.containsMouse
                            ToolTip.text: "Un-stick (note stays in your library)"
                            ToolTip.delay: 600
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.note
                                  ? (card.note.title || "(new note)")
                                  : "(deleted)"
                            color: "#2a2a2a"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            clip: true
                        }

                        // ── Widget-mode toggle pill (ALWAYS ON here
                        //    since we only render widget-mode stickies
                        //    in this component) ──
                        //
                        // Click flips to OFF → note disappears from
                        // DesktopStickyNotes and respawns as overlay
                        // sticky via QuickNotesSticky.
                        Rectangle {
                            id: dragPill
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 16
                            radius: 8
                            color: Qt.rgba(0.45, 0.78, 0.40, 0.85)
                            Rectangle {
                                width: 12; height: 12; radius: 6
                                color: "#fafafa"
                                y: 2
                                x: parent.width - width - 2
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.12)
                            }
                            MouseArea {
                                id: pillMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    QuickNotesService.setStickyDraggable(
                                        card.noteId, false)
                                }
                            }
                            ToolTip.visible: pillMa.containsMouse
                            ToolTip.text: "Lock position — switch to anchored overlay"
                            ToolTip.delay: 600
                        }

                        // ✕ close
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: closeMa.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 9
                                color: "#666"
                            }
                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: QuickNotesService.toggleSticky(card.noteId)
                            }
                            ToolTip.visible: closeMa.containsMouse
                            ToolTip.text: "Close sticky (un-stick)"
                            ToolTip.delay: 600
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(0, 0, 0, 0.1)
                }

                // ── Editor — inline editing of the note body ──
                //
                // v7.0.0-beta.1-hf50: live sync between panel editor
                // and this widget's editor. When user types in EITHER
                // surface, the other automatically reflects the change.
                //
                // Avoid the classic QML circular-binding trap:
                //   declarative `text: card.note.body` binds the text
                //   to the model, but typing in the TextArea breaks
                //   that binding (Qt's intentional behavior). And the
                //   onTextChanged → saveBody → notes update → would
                //   trigger another binding fire (if it still existed)
                //   resetting cursor position.
                //
                // Solution: imperative update via Connections.
                // Listen for QuickNotesService.notesChanged, look up
                // this card's note, and write to TextArea.text ONLY
                // if (a) the value actually differs, AND (b) the
                // TextArea is not the currently active focus item.
                // The focus guard means: if YOU are typing here, your
                // own keystrokes don't get clobbered by the sync.
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: stickyEditor
                        // Initial text set once on completion. Updates
                        // come via the Connections handler below.
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: "#1a1a1a"
                        wrapMode: TextArea.Wrap
                        placeholderText: "Write here…"
                        placeholderTextColor: Qt.rgba(0, 0, 0, 0.4)
                        background: null
                        selectByMouse: true
                        // Internal flag — set true while we're
                        // imperatively updating .text from external
                        // change, so onTextChanged knows to skip its
                        // saveBody trigger (would be a loop).
                        property bool _syncingFromService: false

                        // v7.0.0-beta.1-hf51 — focus-loss safety.
                        //
                        // User report:
                        //   "kapag hindi nako naka select dun dapat
                        //    alisin mo na yun select dun kasi baka
                        //    mag kamali unexpected typing sa notes"
                        //
                        // Without this handler, the TextArea could
                        // keep its selection highlight + cursor blink
                        // even when the user clicked away to another
                        // app. Combined with the Bottom-layer +
                        // OnDemand keyboardFocus from hf50, keystrokes
                        // could conceivably leak into the sticky if
                        // the compositor still considered our surface
                        // the keyboard target.
                        //
                        // Fix: watch activeFocus. When it flips to
                        // false (user clicked away, Tab'd out,
                        // anything), explicitly:
                        //   1. deselect() — clear text selection
                        //      visual highlight
                        //   2. cursorPosition stays where it is
                        //      (preserves "where I left off" memory)
                        //   3. focus = false defensively, so the
                        //      QML focus chain releases too
                        //
                        // Skip this during sync writes — those don't
                        // count as a real focus change.
                        onActiveFocusChanged: {
                            if (_syncingFromService) return
                            // Update card-level flag for border highlight
                            card._editorHasFocus = activeFocus
                            if (!activeFocus) {
                                deselect()
                                focus = false
                            }
                        }

                        Component.onCompleted: {
                            if (card.note) {
                                _syncingFromService = true
                                text = card.note.body || ""
                                _syncingFromService = false
                            }
                        }

                        // hf82d FIX — Same race as QuickNotesSticky. If this
                        // desktop sticky widget mounts before QuickNotesService
                        // finishes loading notes from disk, `card.note` is null
                        // at Component.onCompleted and the editor inits blank.
                        // Listen for the `note` ref itself changing (null →
                        // populated, or note swapped) and re-init then.
                        Connections {
                            target: card
                            function onNoteChanged() {
                                if (!card.note) return
                                const newBody = (card.note.body && typeof card.note.body === "string")
                                              ? card.note.body
                                              : ""
                                if (newBody === stickyEditor.text) return
                                if (stickyEditor.activeFocus) return
                                stickyEditor._syncingFromService = true
                                stickyEditor.text = newBody
                                stickyEditor._syncingFromService = false
                            }
                        }

                        Connections {
                            target: QuickNotesService
                            function onNotesChanged() {
                                if (!card.note) return
                                const newBody = card.note.body || ""
                                if (newBody === stickyEditor.text) return
                                // Skip if user is currently focused
                                // in THIS editor — don't clobber
                                // their typing.
                                if (stickyEditor.activeFocus) return
                                stickyEditor._syncingFromService = true
                                stickyEditor.text = newBody
                                stickyEditor._syncingFromService = false
                            }
                        }

                        onTextChanged: {
                            // Skip if this change came from the
                            // Connections handler above — not a user
                            // keystroke.
                            if (_syncingFromService) return
                            if (card.note && text !== card.note.body) {
                                QuickNotesService.saveBody(card.noteId, text)
                            }
                        }
                    }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: stickyEditor.text.length + " chars"
                        color: Qt.rgba(0, 0, 0, 0.4)
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                    }
                    Text {
                        text: "\uf0b2  widget"
                        color: Qt.rgba(0.10, 0.45, 0.05, 0.7)
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.italic: true
                    }
                }
            }
        }
    }
}
