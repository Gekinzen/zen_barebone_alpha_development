import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/*
 * QuickNotesPanel v7.0.0-beta.1-hf82e — Karui (軽い)
 *
 * Popover with sidebar list + markdown editor pane. Mounted in shell.qml
 * as a per-screen PanelWindow gated by PanelState.quickNotesVisible.
 *
 * Layout (left to right):
 *   ┌────────────┬──────────────────────────────────────┐
 *   │ + New      │  # Editor                            │
 *   │ Search…    │                                      │
 *   ├────────────┤  (textarea with autosave)            │
 *   │ ★ Pinned   │                                      │
 *   │ • Note 1   │                                      │
 *   │ • Note 2   │                                      │
 *   │ Recent     │                                      │
 *   │ • Note 3   │                                      │
 *   │ • ...      │                                      │
 *   └────────────┴──────────────────────────────────────┘
 */
Item {
    id: panel
    width: 720
    height: 480
    clip: true   // v7.0.0-beta.1-hf43: hard clip so children can't escape

    // v7.0.0-beta.1-hf50 — close-on-request signal
    //
    // Emitted when the user clicks the ✕ button in the drag handle
    // OR presses Esc. shell.qml hooks this to PanelState.quickNotesVisible = false.
    signal closeRequested()

    // Esc key closes the panel — same UX as ControlPanel / Settings.
    Keys.onEscapePressed: panel.closeRequested()
    focus: visible   // request keyboard focus when shown so Esc works

    // v7.0.0-beta.1-hf49 — draggable panel (ControlPanel pattern).
    //
    // The PanelWindow in shell.qml is full-screen. By default
    // anchors.centerIn: parent (set in shell.qml mount) centers
    // this panel. When the user drags the header bar, the parent
    // shell.qml breaks the anchor (anchors.centerIn = undefined)
    // and the panel's x/y become free, so it follows the drag.
    //
    // hasBeenDragged is exposed so shell.qml can switch the
    // anchor binding. Reset to false on every visibility cycle
    // so each open() starts centered again.
    property bool hasBeenDragged: false

    // ── Drag handle strip ──
    //
    // Spans the full width of the panel along the top edge, 22px
    // tall. Visible as a subtle gradient/handle hint so users know
    // where to drag. ControlPanel uses the same pattern (8-line
    // grip area in its top-left).
    //
    // v7.0.0-beta.1-hf50: 22px tall (was 18) to fit the close button
    // comfortably. Close ✕ button sits flush right.
    Rectangle {
        id: dragHandle
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22
        z: 100   // ABOVE the main content RowLayout (which fills parent)
        color: dragMa.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.05)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        // Drag MouseArea — fills handle EXCEPT the close button area
        // on the right. Close button has its own MouseArea later (as
        // a later sibling = on top via natural QML render order).
        MouseArea {
            id: dragMa
            anchors.fill: parent
            anchors.rightMargin: 32   // leave space for close button
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true

            drag.target: panel
            drag.axis: Drag.XAndYAxis
            onPressed: panel.hasBeenDragged = true
        }

        // Visual drag-handle hint (three dots) centered horizontally
        // in the dragMa area (excluding close button zone)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -16   // shift left a bit
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: ThemeService.alpha(ThemeService.fg, 0.35)
                }
            }
        }

        // v7.0.0-beta.1-hf50 — close button
        Rectangle {
            id: closeBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            width: 20
            height: 20
            radius: 10
            color: closeMa.containsMouse
                   ? ThemeService.alpha(ThemeService.red || "#e06c75", 0.85)
                   : ThemeService.alpha(ThemeService.fg, 0.10)
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.centerIn: parent
                text: "\uf00d"   // ✕
                font.family: Theme.iconFontFamily
                font.pixelSize: 10
                color: closeMa.containsMouse
                       ? "#ffffff"
                       : ThemeService.alpha(ThemeService.fg, 0.7)
            }

            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.closeRequested()
            }

            ToolTip.visible: closeMa.containsMouse
            ToolTip.text: "Close (Esc)"
            ToolTip.delay: 600
        }

        ToolTip.visible: dragMa.containsMouse && !dragMa.drag.active
        ToolTip.text: "Drag to move"
        ToolTip.delay: 800
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: LookService.surfaceColor(ThemeService.bg1, 0.96)
        border.color: ThemeService.alpha(ThemeService.fg, 0.15)
        border.width: 1
    }

    RowLayout {
        anchors.fill: parent
        // Top margin increased to make room for the drag handle + close button
        anchors.topMargin: 26   // hf50: was 22 (18 handle + 4 gap), now 22 handle + 4 gap
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        spacing: 12

        // ── Sidebar ──
        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 6
                    color: ThemeService.alpha(ThemeService.green || "#98c379", 0.18)
                    border.color: ThemeService.alpha(ThemeService.green || "#98c379", 0.4)
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "\uf067"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 10
                            color: ThemeService.green || "#98c379"
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "New note"
                            color: ThemeService.green || "#98c379"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: QuickNotesService.createNote()
                    }
                }
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "Search…"
                text: QuickNotesService.searchQuery
                onTextChanged: QuickNotesService.searchQuery = text
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.fg
                background: Rectangle {
                    radius: 4
                    color: LookService.surfaceColor(ThemeService.bg2 || ThemeService.bg1, 0.6)
                    border.color: ThemeService.alpha(ThemeService.fg, 0.15)
                    border.width: 1
                }
            }

            // Notes list
            ListView {
                id: notesList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: QuickNotesService.filteredNotes()

                delegate: Rectangle {
                    width: notesList.width
                    height: 40
                    radius: 5
                    clip: true   // v7.0.0-beta.1-hf43: safety
                    color: modelData.id === QuickNotesService.currentNoteId
                           ? ThemeService.alpha(ThemeService.blue, 0.20)
                           : (delegateMa.containsMouse
                              ? ThemeService.alpha(ThemeService.fg, 0.08)
                              : "transparent")
                    border.color: modelData.id === QuickNotesService.currentNoteId
                                  ? ThemeService.alpha(ThemeService.blue, 0.4)
                                  : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: modelData.pinned
                            text: "\uf005"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 8
                            color: ThemeService.blue
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true
                                // hf82e: same first-non-📅-line extraction
                                // applied to the sidebar title display.
                                // Previously this used `modelData.title`
                                // directly — which for calendar notes
                                // showed up as "📅 2026-05-23" instead
                                // of the user's typed text. The scan
                                // path in QuickNotesService now stores
                                // the right title, but applying the
                                // same extraction here as a fallback
                                // covers (a) live in-memory edits where
                                // .title may not yet reflect the new
                                // body, and (b) any legacy state file
                                // entries cached before the scan fix.
                                text: {
                                    const n = modelData
                                    if (n && n.body && typeof n.body === "string") {
                                        const lines = n.body.split("\n")
                                        for (let i = 0; i < lines.length; i++) {
                                            const t = lines[i].trim()
                                            if (t && !t.startsWith("📅")) return t.substring(0, 80)
                                        }
                                    }
                                    // Fall back to stored title — but if THAT
                                    // also starts with 📅 (legacy entries),
                                    // strip the prefix so the user at least
                                    // sees something resembling content.
                                    const fallback = (n && n.title) || ""
                                    if (fallback.startsWith("📅")) {
                                        // legacy: try to recover from .body
                                        // structure; otherwise show as-is
                                        // (better the date than blank)
                                        return fallback
                                    }
                                    return fallback || "(untitled)"
                                }
                                color: ThemeService.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true
                                text: new Date(modelData.mtime * 1000).toLocaleString()
                                color: ThemeService.alpha(ThemeService.fg, 0.5)
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: delegateMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                contextMenu.x = mouse.x
                                contextMenu.y = mouse.y
                                contextMenu.targetId = modelData.id
                                contextMenu.open()
                            } else {
                                QuickNotesService.selectNote(modelData.id)
                            }
                        }
                    }

                    Menu {
                        id: contextMenu
                        property string targetId: ""
                        MenuItem {
                            text: modelData.pinned ? "Unpin" : "Pin"
                            onTriggered: QuickNotesService.togglePin(contextMenu.targetId)
                        }
                        MenuItem {
                            text: "Delete"
                            onTriggered: QuickNotesService.deleteNote(contextMenu.targetId)
                        }
                    }
                }
            }
        }

        // ── Editor pane ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 100   // prevent collapse on weird sizes
            radius: 6
            color: LookService.surfaceColor(ThemeService.bg2 || ThemeService.bg1, 0.6)
            border.color: ThemeService.alpha(ThemeService.fg, 0.10)
            border.width: 1
            clip: true   // v7.0.0-beta.1-hf43: belt-and-suspenders clip

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Header with sticky + pin buttons
                RowLayout {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 28   // hf43: clamp header height
                    spacing: 6

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        Layout.fillWidth: true
                        Layout.maximumWidth: parent.width - 60   // hf43: reserve space for 2 buttons (24+24+12 spacing)
                        text: {
                            const n = QuickNotesService.getCurrentNote()
                            if (!n) return "(select or create a note)"
                            return n.title || "(untitled)"
                        }
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1   // hf43: force single line
                        clip: true            // hf43: extra safety
                    }

                    // ⭐ Sticky toggle — pins note as floating window
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        visible: QuickNotesService.getCurrentNote() !== null
                        color: stickyMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.15)
                               : "transparent"

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\uf249"   // sticky-note glyph
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                            color: {
                                const n = QuickNotesService.getCurrentNote()
                                return (n && n.sticky)
                                       ? (ThemeService.yellow || "#e0af68")
                                       : ThemeService.alpha(ThemeService.fg, 0.5)
                            }
                        }

                        MouseArea {
                            id: stickyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = QuickNotesService.getCurrentNote()
                                if (n) QuickNotesService.toggleSticky(n.id)
                            }
                        }

                        ToolTip.visible: stickyMa.containsMouse
                        ToolTip.text: {
                            const n = QuickNotesService.getCurrentNote()
                            return (n && n.sticky)
                                   ? "Un-stick from desktop"
                                   : "Stick as floating note on desktop"
                        }
                        ToolTip.delay: 500
                    }

                    // v7.0.0-beta.1-hf47 — Pop out as widget.
                    //
                    // One-click: stickies the note AND enables widget
                    // mode. Result: the note immediately appears as a
                    // desktop widget alongside the clock/weather/CPU
                    // temp widgets. User can drag it anywhere; position
                    // persists.
                    //
                    // If the note is ALREADY a widget, this button
                    // disables widget mode (back to overlay sticky).
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        visible: QuickNotesService.getCurrentNote() !== null
                        color: popoutMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.15)
                               : "transparent"

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\uf0b2"   // arrows-alt (drag icon)
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                            color: {
                                const n = QuickNotesService.getCurrentNote()
                                return (n && QuickNotesService.isStickyDraggable(n.id))
                                       ? (ThemeService.green || "#98c379")
                                       : ThemeService.alpha(ThemeService.fg, 0.5)
                            }
                        }

                        MouseArea {
                            id: popoutMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = QuickNotesService.getCurrentNote()
                                if (!n) return
                                const wasWidget = QuickNotesService.isStickyDraggable(n.id)
                                if (wasWidget) {
                                    // Already a widget — toggle off
                                    QuickNotesService.setStickyDraggable(n.id, false)
                                } else {
                                    // Make sticky + enable widget mode
                                    if (!n.sticky) {
                                        QuickNotesService.toggleSticky(n.id)
                                    }
                                    QuickNotesService.setStickyDraggable(n.id, true)
                                }
                            }
                        }

                        ToolTip.visible: popoutMa.containsMouse
                        ToolTip.text: {
                            const n = QuickNotesService.getCurrentNote()
                            return (n && QuickNotesService.isStickyDraggable(n.id))
                                   ? "Disable widget mode (back to overlay)"
                                   : "Pop out as desktop widget (draggable, like clock/weather)"
                        }
                        ToolTip.delay: 500
                    }

                    // ★ Pin to top (sidebar priority)
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        visible: QuickNotesService.getCurrentNote() !== null
                        color: pinMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.15)
                               : "transparent"

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\uf005"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                            color: {
                                const n = QuickNotesService.getCurrentNote()
                                return (n && n.pinned) ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.5)
                            }
                        }

                        MouseArea {
                            id: pinMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = QuickNotesService.getCurrentNote()
                                if (n) QuickNotesService.togglePin(n.id)
                            }
                        }

                        ToolTip.visible: pinMa.containsMouse
                        ToolTip.text: {
                            const n = QuickNotesService.getCurrentNote()
                            return (n && n.pinned)
                                   ? "Unpin from sidebar top"
                                   : "Pin to sidebar top"
                        }
                        ToolTip.delay: 500
                    }
                }

                // Text editor
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: editor
                        // v7.0.0-beta.1-hf50: imperative text sync to
                        // avoid the QML binding-break-on-type loop.
                        // Initial text set on completion / when note
                        // selection changes. External updates (from
                        // sticky widgets editing the same note) come
                        // via the Connections handler below.
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.fg
                        wrapMode: TextArea.Wrap
                        placeholderText: "Start writing… auto-saves every keystroke.\n\n"
                                       + "Use #tags for filtering. Markdown supported."
                        placeholderTextColor: ThemeService.alpha(ThemeService.fg, 0.4)
                        background: null
                        selectByMouse: true
                        enabled: QuickNotesService.getCurrentNote() !== null

                        property bool _syncingFromService: false

                        // v7.0.0-beta.1-hf51 — focus-loss safety.
                        // Same fix as DesktopStickyNotes — clear text
                        // selection + release focus when user clicks
                        // away to another app. Prevents accidental
                        // typing leak when sticky / panel isn't
                        // the active surface.
                        onActiveFocusChanged: {
                            if (_syncingFromService) return
                            if (!activeFocus) {
                                deselect()
                                focus = false
                            }
                        }

                        // When the user selects a different note,
                        // reload the editor's text from that note.
                        Connections {
                            target: QuickNotesService
                            function onCurrentNoteIdChanged() {
                                const n = QuickNotesService.getCurrentNote()
                                editor._syncingFromService = true
                                editor.text = n ? (n.body || "") : ""
                                editor._syncingFromService = false
                            }
                            // Live sync: when notes update (from any
                            // source — sticky widget, external file
                            // load, etc.) reflect into this editor.
                            // Skip if this editor is the active
                            // focus (user typing) — don't clobber.
                            function onNotesChanged() {
                                const n = QuickNotesService.getCurrentNote()
                                if (!n) return
                                const newBody = n.body || ""
                                if (newBody === editor.text) return
                                if (editor.activeFocus) return
                                editor._syncingFromService = true
                                editor.text = newBody
                                editor._syncingFromService = false
                            }
                        }

                        Component.onCompleted: {
                            const n = QuickNotesService.getCurrentNote()
                            editor._syncingFromService = true
                            editor.text = n ? (n.body || "") : ""
                            editor._syncingFromService = false
                        }

                        onTextChanged: {
                            if (_syncingFromService) return
                            const n = QuickNotesService.getCurrentNote()
                            if (n && text !== n.body) {
                                QuickNotesService.saveBody(n.id, text)
                            }
                        }
                    }
                }

                // Footer status
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    Layout.fillWidth: true
                    visible: QuickNotesService.getCurrentNote() !== null
                    text: {
                        const n = QuickNotesService.getCurrentNote()
                        if (!n) return ""
                        const chars = (n.body || "").length
                        const words = (n.body || "").trim().split(/\s+/).filter(w => w).length
                        return chars + " chars · " + words + " words"
                             + (n.tags && n.tags.length > 0
                                ? " · #" + n.tags.join(" #") : "")
                    }
                    color: ThemeService.alpha(ThemeService.fg, 0.5)
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }
            }
        }
    }
}
