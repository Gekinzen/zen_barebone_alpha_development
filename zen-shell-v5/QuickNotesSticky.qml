import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/*
 * QuickNotesSticky v7.0.0-beta.1-hf82d — Karui (軽い)
 *
 * Normal-mode (anchored) sticky note. Lives on WlrLayer.Overlay so
 * it floats above all other windows.
 *
 * v7.0.0-beta.1-hf47 — RESPONSIBILITY SPLIT.
 *
 *   This file now ONLY handles stickies in NORMAL mode (toggle off).
 *   Widget-mode stickies (toggle on) are rendered by DesktopStickyNotes
 *   inside the WlrLayer.Bottom desktop-widget surface — same parent as
 *   clock/weather/CPU temp. The two are mutually exclusive per note ID.
 *
 *   User request:
 *   "buo dapat sticky ma tag na din sa widget sa desktop ko mismo
 *    prang heto mga clock gets? draggable nadin tas yan super shift n
 *    daapt draggable din yan tas kapag toggle on niya widget modee
 *    automatically magiging katulad nung mga clock widget ko"
 *
 *   - Toggle OFF → this file renders it (anchored overlay)
 *   - Toggle ON  → DesktopStickyNotes renders it (desktop widget)
 *
 * The toggle pill in the title bar is still here — clicking it flips
 * isStickyDraggable to true, which makes shell.qml's Repeater drop
 * this instance and the DesktopStickyNotes Repeater pick it up.
 *
 * Position memory is SHARED between modes — flipping the toggle does
 * NOT reset the saved position. So if the user dragged the sticky to
 * (300, 200) while in widget mode, toggled off, then toggled on again,
 * it returns to (300, 200).
 *
 * NOTE: in normal mode, dragging is disabled. Position is locked to
 * either the saved value or the hash-derived fallback. To move a
 * normal-mode sticky, you must toggle widget mode on, drag it,
 * optionally toggle widget mode off again.
 */
PanelWindow {
    id: stickyWindow
    required property string noteId
    required property var modelData

    screen: modelData

    // Visible ONLY when this note is sticky AND in NORMAL mode.
    visible: QuickNotesService.stickyIds.indexOf(noteId) >= 0
          && !QuickNotesService.isStickyDraggable(noteId)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "zen-shell-sticky-overlay-" + noteId
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    readonly property int cardWidth: 280
    readonly property int cardHeight: 220

    color: "transparent"

    property var note: QuickNotesService.getNote(noteId)
    Connections {
        target: QuickNotesService
        function onNotesChanged() {
            stickyWindow.note = QuickNotesService.getNote(stickyWindow.noteId)
        }
    }

    function _fallbackX() {
        let h = 0
        for (let i = 0; i < noteId.length; i++) {
            h = ((h << 5) - h) + noteId.charCodeAt(i)
            h |= 0
        }
        return 80 + (Math.abs(h) % 400)
    }
    function _fallbackY() {
        let h = 0
        for (let i = 0; i < noteId.length; i++) {
            h = ((h << 7) - h) + noteId.charCodeAt(i)
            h |= 0
        }
        return 100 + (Math.abs(h) % 250)
    }

    Rectangle {
        id: card
        width: stickyWindow.cardWidth
        height: stickyWindow.cardHeight
        radius: 6
        color: "#fdf6a8"
        border.color: "#c9b96c"
        border.width: 1
        clip: true

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

        Component.onCompleted: {
            const saved = QuickNotesService.getStickyPosition(stickyWindow.noteId)
            if (saved) {
                card.x = saved.x
                card.y = saved.y
            } else {
                card.x = stickyWindow._fallbackX()
                card.y = stickyWindow._fallbackY()
            }
        }

        Connections {
            target: QuickNotesService
            function onStickyPositionsChanged() {
                const saved = QuickNotesService.getStickyPosition(stickyWindow.noteId)
                if (saved && (card.x !== saved.x || card.y !== saved.y)) {
                    card.x = saved.x
                    card.y = saved.y
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Rectangle {
                id: titleBar
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: "transparent"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 6

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
                            onClicked: QuickNotesService.toggleSticky(stickyWindow.noteId)
                        }
                        ToolTip.visible: starMa.containsMouse
                        ToolTip.text: "Un-stick (note stays in your library)"
                        ToolTip.delay: 600
                    }

                    Text {
                        Layout.fillWidth: true
                        text: stickyWindow.note
                              ? (stickyWindow.note.title || "(new note)")
                              : "(deleted)"
                        color: "#2a2a2a"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        clip: true
                    }

                    // ── Widget-mode toggle pill ──
                    //
                    // OFF here (we only render in normal mode). Click
                    // flips to ON → DesktopStickyNotes picks it up,
                    // this instance hides.
                    Rectangle {
                        id: dragPill
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 16
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.18)
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: "#fafafa"
                            y: 2
                            x: 2   // OFF: thumb on left
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
                                    stickyWindow.noteId, true)
                            }
                        }
                        ToolTip.visible: pillMa.containsMouse
                        ToolTip.text: "Enable widget mode (drag like clock/weather)"
                        ToolTip.delay: 600
                    }

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
                            onClicked: QuickNotesService.toggleSticky(stickyWindow.noteId)
                        }
                        ToolTip.visible: closeMa.containsMouse
                        ToolTip.text: "Close sticky (un-stick)"
                        ToolTip.delay: 600
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(0, 0, 0, 0.1)
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ── Editor — inline editing of the note body ──
                //
                // v7.0.0-beta.1-hf82: live sync fix.
                //
                // User report:
                //   "yung sa notes kapag nag edit ako sa calendar ko
                //    hindi na update instantly sa sticky note ko dapat
                //    live if anu yun update ko dito sa sticky note ko
                //    naka tag sa calendar matic sa calendar live din
                //    na update agad reflect gets ?"
                //
                // The previous declarative binding
                //   `text: stickyWindow.note ? (stickyWindow.note.body || "") : ""`
                // broke on the first keystroke (Qt's intentional
                // behavior: assigning to a property kills its binding).
                // After that, edits made in the calendar entry editor
                // OR the QuickNotesPanel OR another sticky surface for
                // the same note no longer propagated to this widget.
                //
                // Mirror DesktopStickyNotes' hf50 pattern: imperative
                // update via Connections + _syncingFromService guard +
                // activeFocus guard (don't clobber the user's typing
                // if they're focused HERE right now).
                //
                // Wala tayong babawasan — old `text:` binding replaced
                // by imperative initialization + Connections handler;
                // onTextChanged behavior preserved with a sync-skip
                // guard. The existing ScrollView/TextArea structure,
                // styling, and `chars` footer below are unchanged.
                TextArea {
                    id: stickyEditor
                    // Initial text set on completion. Subsequent
                    // updates come via the Connections handler below.
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: "#1a1a1a"
                    wrapMode: TextArea.Wrap
                    placeholderText: "Write here…"
                    placeholderTextColor: Qt.rgba(0, 0, 0, 0.4)
                    background: null
                    selectByMouse: true

                    // Internal flag — true while we're imperatively
                    // writing .text from an external change, so
                    // onTextChanged knows not to fire saveBody (which
                    // would create a write-loop and also reset cursor
                    // position).
                    property bool _syncingFromService: false

                    // Focus-loss safety: clear selection so the user
                    // doesn't accidentally keep typing into this
                    // sticky after clicking away. Same as the hf51
                    // safety in DesktopStickyNotes.
                    onActiveFocusChanged: {
                        if (_syncingFromService) return
                        if (!activeFocus) {
                            deselect()
                            focus = false
                        }
                    }

                    Component.onCompleted: {
                        if (stickyWindow.note) {
                            _syncingFromService = true
                            text = stickyWindow.note.body || ""
                            _syncingFromService = false
                        }
                    }

                    // hf82d FIX — Issue: sticky window opens blank on first
                    // open even though the note has content. Clicking another
                    // note then clicking back showed the body suddenly
                    // appearing.
                    //
                    // Root cause: `stickyWindow.note` is bound to
                    // `QuickNotesService.getNote(noteId)`. If the sticky
                    // window mounts BEFORE QuickNotesService finishes loading
                    // notes from disk (FileView read race at shell start),
                    // `note` is null/undefined at Component.onCompleted time,
                    // and the editor initializes to empty. The onNotesChanged
                    // Connections handler below only fires on saves, so the
                    // initial post-load population was missed for the very
                    // first paint of this sticky window — until something else
                    // triggered notesChanged (clicking around the panel
                    // refreshed the cache, which then made it look like the
                    // note "appeared after clicking another note").
                    //
                    // Fix: also re-init the editor whenever the `note` ref
                    // itself changes (from null → populated, or note swapped
                    // entirely). Same guards as the Connections handler —
                    // skip if user is typing here, skip if value matches.
                    Connections {
                        target: stickyWindow
                        function onNoteChanged() {
                            try {
                                if (!stickyWindow.note) return
                                const newBody = (stickyWindow.note.body && typeof stickyWindow.note.body === "string")
                                              ? stickyWindow.note.body
                                              : ""
                                if (newBody === stickyEditor.text) return
                                if (stickyEditor.activeFocus) return
                                stickyEditor._syncingFromService = true
                                stickyEditor.text = newBody
                                stickyEditor._syncingFromService = false
                            } catch (eNoteInit) {
                                console.warn("[QuickNotesSticky] hf82d note-init sync error:", eNoteInit)
                                stickyEditor._syncingFromService = false
                            }
                        }
                    }

                    // hf82d FIX (companion) — Also watch for visibility
                    // changes. If the sticky window was hidden while empty
                    // and then becomes visible after a note edit happened
                    // off-screen, the onNotesChanged handler may have
                    // skipped this editor because it wasn't yet rendered.
                    // On re-show, re-pull the latest body.
                    Connections {
                        target: stickyWindow
                        function onVisibleChanged() {
                            if (!stickyWindow.visible) return
                            try {
                                if (!stickyWindow.note) return
                                const newBody = (stickyWindow.note.body && typeof stickyWindow.note.body === "string")
                                              ? stickyWindow.note.body
                                              : ""
                                if (newBody === stickyEditor.text) return
                                if (stickyEditor.activeFocus) return
                                stickyEditor._syncingFromService = true
                                stickyEditor.text = newBody
                                stickyEditor._syncingFromService = false
                            } catch (eVis) {
                                console.warn("[QuickNotesSticky] hf82d visibility sync error:", eVis)
                                stickyEditor._syncingFromService = false
                            }
                        }
                    }

                    Connections {
                        target: typeof QuickNotesService !== "undefined"
                                ? QuickNotesService
                                : null
                        function onNotesChanged() {
                            // hf82c: full try/catch + null guards.
                            // Same reasoning as ZenNotificationCenter's
                            // calendar sync — a throw here can break
                            // other Connections wired to the same
                            // notesChanged signal across the shell.
                            try {
                                if (!stickyWindow.note) return
                                const newBody = (stickyWindow.note.body && typeof stickyWindow.note.body === "string")
                                              ? stickyWindow.note.body
                                              : ""
                                if (newBody === stickyEditor.text) return
                                // Don't clobber the user's in-progress
                                // typing in THIS editor. If they're
                                // focused elsewhere (calendar editor,
                                // panel, another sticky), sync away.
                                if (stickyEditor.activeFocus) return
                                stickyEditor._syncingFromService = true
                                stickyEditor.text = newBody
                                stickyEditor._syncingFromService = false
                            } catch (eSync) {
                                console.warn("[QuickNotesSticky] hf82c sync error:", eSync)
                                stickyEditor._syncingFromService = false
                            }
                        }
                    }

                    onTextChanged: {
                        // Skip if this change came from the Connections
                        // handler above — not a user keystroke.
                        if (_syncingFromService) return
                        if (stickyWindow.note && text !== stickyWindow.note.body) {
                            QuickNotesService.saveBody(stickyWindow.noteId, text)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: stickyEditor.text.length > 0
                text: stickyEditor.text.length + " chars"
                color: Qt.rgba(0, 0, 0, 0.4)
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }
        }
    }
}
