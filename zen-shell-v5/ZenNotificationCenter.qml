import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * ZenNotificationCenter v7.0.0-beta.1-hf82e (Karui)
 *
 * Unified panel that opens on clock click:
 *   ┌──────────────────────────┐
 *   │ 🔔 Notifications  [N]   │  ← count + open swaync   (full mode)
 *   ├──────────────────────────┤
 *   │    ◀ April 2026 ▶       │  ← full calendar       (always)
 *   │   Su Mo Tu We Th Fr Sa  │
 *   │   ...                   │
 *   ├──────────────────────────┤
 *   │ BT  WiFi  Lock  Logout  │  ← system quick-actions (full mode)
 *   │ Restart   Shutdown       │
 *   └──────────────────────────┘
 *
 * v6.16.4.12.6.51: Added `compactMode` property. When TRUE, the
 * notifications strip + system quick-actions section + their
 * separator are hidden — only the calendar grid is visible. Used by
 * the Clock module's hover popup: peek = compact (calendar only),
 * click-pin = full (notif + calendar + buttons).
 */
Rectangle {
    id: root

    signal closeRequested()
    signal powerActionRequested(string action, string command)

    // v6.16.4.12.6.51 (Hikari): when true, hide notifications + system
    // quick-action buttons. Calendar grid stays visible. Used by Clock
    // module's hover-peek state — full state (click-pinned) sets this
    // back to false to reveal everything.
    property bool compactMode: false

    // ── Calendar state ──
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var today: new Date()
    readonly property int todayDay: today.getDate()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayYear: today.getFullYear()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayHeaders: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // ── Notification state ──
    property int notifCount: 0
    property bool dndEnabled: false

    // ── Calendar note editor state ──
    // hf78 CRITICAL FIX: these were previously declared inside
    // mainLayout (ColumnLayout), but referenced as root._editingDate
    // throughout. root (Rectangle) had no such property, so
    // root._editingDate evaluated to undefined in JS. The visibility
    // binding `root._editingDate !== ""` became `undefined !== ""`
    // which is ALWAYS TRUE — hence the permanently visible editor
    // with "📅 undefined" in the header. Moving to root scope fixes
    // both the visibility and the header text.
    property string _editingDate: ""
    property string _editingNoteId: ""

    function _formatDate(y, m, d) {
        const pad = (n) => (n < 10 ? "0" + n : "" + n)
        return y + "-" + pad(m + 1) + "-" + pad(d)
    }

    function _saveCalendarNote() {
        if (!root._editingDate || !calendarNoteTitle.text.trim()) return
        const title = calendarNoteTitle.text.trim()
        const time = calendarNoteTime.text.trim()

        if (root._editingNoteId) {
            // hf79: EDIT MODE — update the existing note's body.
            // Reconstruct body with the 📅 prefix + new user text.
            const newBody = "📅 " + root._editingDate + "\n" + title + "\n"
            QuickNotesService.saveBody(root._editingNoteId, newBody)
            // Update notification time if provided
            if (time) {
                const meta = Object.assign({}, QuickNotesService.notesMeta)
                if (meta[root._editingNoteId]) {
                    meta[root._editingNoteId] = Object.assign({}, meta[root._editingNoteId], { notifyTime: time })
                    QuickNotesService.notesMeta = meta
                }
            }
            root._editingNoteId = ""
        } else {
            // CREATE MODE — same as before
            QuickNotesService.createCalendarNote(root._editingDate, title, time)
        }
        calendarNoteTitle.text = ""
        calendarNoteTime.text = ""
        // Keep editor open to show the updated/new note
    }

    // ── Sizing ──
    width: 310
    height: mainLayout.implicitHeight + 28
    radius: Theme.panelRadius !== undefined ? Math.min(Theme.panelRadius, 16) : 12
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.96)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)

    Keys.onEscapePressed: closeRequested()

    // ── Notification poller ──
    Process {
        id: notifPoll
        command: ["swaync-client", "-swb"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.notifCount = d.count || 0
                    root.dndEnabled = d.dnd || false
                } catch (e) {}
            }
        }
    }
    Timer { interval: 2000; running: root.visible; repeat: true; onTriggered: notifPoll.running = true }
    onVisibleChanged: if (visible) notifPoll.running = true

    // ── Power action runner ──
    Process { id: actionRunner; running: false }

    // ── Calendar month scroll ──
    property int _lastConsumedMonthDelta: 0
    Connections {
        target: PanelState
        function onCalendarMonthDeltaChanged() {
            const diff = PanelState.calendarMonthDelta - root._lastConsumedMonthDelta
            if (diff === 0) return
            root._lastConsumedMonthDelta = PanelState.calendarMonthDelta
            let m = root.viewMonth + diff
            let y = root.viewYear
            while (m < 0)  { m += 12; y -= 1 }
            while (m > 11) { m -= 12; y += 1 }
            root.viewMonth = m; root.viewYear = y
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const dir = event.angleDelta.y > 0 ? -1 : +1
            let m = root.viewMonth + dir, y = root.viewYear
            if (m < 0)  { m += 12; y -= 1 }
            if (m > 11) { m -= 12; y += 1 }
            root.viewMonth = m; root.viewYear = y
            event.accepted = true
        }
    }

    function buildDays() {
        const firstDay = new Date(viewYear, viewMonth, 1).getDay()
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const prevMonthDays = new Date(viewYear, viewMonth, 0).getDate()
        // hf78: carry true cellYear/cellMonth per cell so spill cells
        // get correct dates when right-clicked.
        const prevM = viewMonth === 0 ? 11 : viewMonth - 1
        const prevY = viewMonth === 0 ? viewYear - 1 : viewYear
        const nextM = viewMonth === 11 ? 0 : viewMonth + 1
        const nextY = viewMonth === 11 ? viewYear + 1 : viewYear
        let cells = []
        for (let i = firstDay - 1; i >= 0; i--)
            cells.push({ day: prevMonthDays - i, current: false, cellYear: prevY, cellMonth: prevM })
        for (let d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, current: true, cellYear: viewYear, cellMonth: viewMonth })
        let nextDay = 1
        while (cells.length < 42)
            cells.push({ day: nextDay++, current: false, cellYear: nextY, cellMonth: nextM })
        return cells
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════
        // NOTIFICATIONS — top section
        // v7.0.0-beta.1-hf66 — HIDDEN per user request.
        // "useless na yun nakahiwalay naman yun notification ko"
        // Separate Notification Center panel exists. This inline
        // row was redundant. Kept in code (visible: false) to
        // preserve wala tayong babawasan policy.
        // ═══════════════════════════════════════════════
        Rectangle {
            visible: false   // hf66: hidden — use Notification Center panel instead
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 44 : 0
            radius: 10
            color: ThemeService.alpha(ThemeService.bg1, 0.5)
            border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.06)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: root.dndEnabled ? "\udb82\udd13" : (root.notifCount > 0 ? "\udb83\udd6b" : "\udb80\udc9c")
                    font.family: Theme.monoFont; font.pixelSize: 18
                    color: root.notifCount > 0 ? ThemeService.yellow : ThemeService.grey0
                }
                Text {
                    text: "Notifications"
                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: ThemeService.fg
                }
                Item { Layout.fillWidth: true }

                // Badge count
                Rectangle {
                    visible: root.notifCount > 0
                    width: countText.implicitWidth + 14; height: 22; radius: 11
                    color: ThemeService.alpha(ThemeService.yellow, 0.2)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.yellow, 0.3)
                    Text {
                        id: countText; anchors.centerIn: parent
                        text: root.notifCount
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold
                        color: ThemeService.yellow
                    }
                }

                // DND toggle
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: dndMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.1) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: root.dndEnabled ? "\uf1f6" : "\uf0f3"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                        color: root.dndEnabled ? ThemeService.red : ThemeService.grey0
                    }
                    MouseArea {
                        id: dndMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached({command: ["swaync-client", "-d", "-sw"]})
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
            }
        }

        // ═══════════════════════════════════════════════
        // CALENDAR — center section
        // ═══════════════════════════════════════════════

        // Header: ◀ Month Year ▶
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                color: prevMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "\uf104"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: ThemeService.grey0 }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- } else root.viewMonth-- }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: monthNames[root.viewMonth] + " " + root.viewYear
                font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: ThemeService.fg
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                color: nextMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "\uf105"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: ThemeService.grey0 }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ } else root.viewMonth++ }
                }
            }
        }

        // Day headers
        RowLayout {
            Layout.fillWidth: true; spacing: 0
            Repeater {
                model: root.dayHeaders
                Text { required property string modelData; Layout.fillWidth: true; text: modelData; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: ThemeService.grey1; horizontalAlignment: Text.AlignHCenter }
            }
        }

        // Day grid
        // v7.0.0-beta.1-hf75 — calendar + sticky notes integration.
        // Each day cell now:
        //   - Shows a dot indicator if there are notes on that date
        //   - Right-click → opens inline note editor for that date
        //   - Left-click on a date with notes → shows notes list

        // Currently selected date for the inline editor (empty = closed)
        // hf78: moved to root scope — see critical fix comment above.

        Grid {
            Layout.fillWidth: true; columns: 7; rows: 6; spacing: 2
            Repeater {
                model: root.buildDays()
                Rectangle {
                    id: dayCell
                    required property var modelData
                    // hf78: dateStr uses cell's own cellYear/cellMonth
                    // so spill cells get correct dates. No more empty
                    // string for non-current cells.
                    readonly property string dateStr:
                        root._formatDate(modelData.cellYear, modelData.cellMonth, modelData.day)
                    readonly property bool isToday: modelData.current && modelData.day === root.todayDay && root.viewMonth === root.todayMonth && root.viewYear === root.todayYear
                    readonly property bool hasNotes: QuickNotesService.hasNotesOnDate(dateStr)
                    readonly property bool isEditing: root._editingDate === dateStr

                    width: (root.width - 28 - 12) / 7; height: 32; radius: 6
                    color: isEditing
                           ? ThemeService.alpha(ThemeService.green, 0.25)
                           : isToday
                             ? ThemeService.alpha(ThemeService.blue, 0.3)
                             : dayMa.containsMouse
                               ? ThemeService.alpha(ThemeService.fg, 0.06)
                               : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                        color: dayCell.isToday ? ThemeService.fg
                               : (dayCell.modelData.current ? ThemeService.grey0 : ThemeService.grey2)
                    }
                    // hf78: dot indicator moved to upper-right (was
                    // bottom-center via ColumnLayout). 5×5 circle.
                    Rectangle {
                        visible: dayCell.hasNotes
                        width: 5; height: 5; radius: 2.5
                        color: dayCell.isToday ? ThemeService.fg : (ThemeService.green || "#98c379")
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 3
                        anchors.rightMargin: 3
                    }

                    MouseArea {
                        id: dayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            // hf78: any cell is clickable — no current gate.
                            const ds = dayCell.dateStr
                            if (mouse.button === Qt.RightButton) {
                                root._editingDate = ds
                                root._editingNoteId = ""
                                calendarNoteTitle.text = ""
                                calendarNoteTime.text = ""
                                calendarNoteTitle.forceActiveFocus()
                            } else {
                                if (root._editingDate === ds) {
                                    root._editingDate = ""
                                } else {
                                    root._editingDate = ds
                                    root._editingNoteId = ""
                                    const existing = QuickNotesService.getNotesForDate(ds)
                                    if (existing.length > 0) {
                                        // hf82d FIX — Issue: clicking a date cell with
                                        // an existing note was loading `.title` into the
                                        // editor, which for calendar notes is the auto-
                                        // generated "📅 2026-05-21" line (the first
                                        // line of the body), NOT the user-typed title.
                                        // Result: the editor showed "📅 2026-05-21" as
                                        // editable text instead of the actual note
                                        // content, and the user couldn't see what they
                                        // had written without re-clicking through the
                                        // edit button.
                                        //
                                        // Mirror the edit-button extraction (line ~530):
                                        // first non-📅 line of the body IS the user's
                                        // text. Fall back to `.title` only when the body
                                        // is empty or has no non-📅 lines (shouldn't
                                        // happen for properly-created calendar notes,
                                        // but keep the fallback for legacy entries).
                                        //
                                        // Wala tayong babawasan — the `_editingNoteId`
                                        // assignment is preserved, the date selection
                                        // is preserved, the focus call is preserved.
                                        // Only the .text assignment is corrected from
                                        // `.title` to the extracted body line.
                                        const n = existing[0]
                                        let userText = ""
                                        if (n.body && typeof n.body === "string") {
                                            const lines = n.body.split("\n")
                                            for (let i = 0; i < lines.length; i++) {
                                                const t = lines[i].trim()
                                                if (t && !t.startsWith("📅")) { userText = t; break }
                                            }
                                        }
                                        calendarNoteTitle.text = userText || n.title || ""
                                        root._editingNoteId = n.id
                                    } else {
                                        calendarNoteTitle.text = ""
                                    }
                                    calendarNoteTime.text = ""
                                    calendarNoteTitle.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // INLINE CALENDAR NOTE EDITOR
        // v7.0.0-beta.1-hf75 — shows below the calendar grid when
        // a date is selected (click or right-click). Quick entry for
        // events/reminders. Saves to QuickNotesService (synced with
        // sticky notes). Closes on Esc or second click on same date.
        // ═══════════════════════════════════════════════
        Rectangle {
            visible: root._editingDate !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? calNoteCol.implicitHeight + 16 : 0
            radius: 8
            color: ThemeService.alpha(ThemeService.bg2, 0.6)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.green, 0.3)

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }

            ColumnLayout {
                id: calNoteCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Date header + existing notes count
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "📅 " + root._editingDate
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: ThemeService.green || "#98c379"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: QuickNotesService.hasNotesOnDate(root._editingDate)
                        text: {
                            const c = QuickNotesService.notesByDate[root._editingDate] || 0
                            return c + " note" + (c !== 1 ? "s" : "")
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: ThemeService.grey1
                    }
                    // hf79: Open in QuickNotesPanel — full editor
                    Rectangle {
                        width: 18; height: 18; radius: 4
                        color: expandMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.2) : "transparent"
                        Text { anchors.centerIn: parent; text: "⤢"; font.pixelSize: 12; color: expandMa.containsMouse ? ThemeService.blue : ThemeService.grey1 }
                        MouseArea {
                            id: expandMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Open QuickNotesPanel — if we have a selected
                                // note, load it in the editor
                                if (root._editingNoteId) {
                                    QuickNotesService.currentNoteId = root._editingNoteId
                                    QuickNotesService.loadBody(root._editingNoteId)
                                }
                                PanelState.quickNotesVisible = true
                                root.closeRequested()
                            }
                        }
                    }
                    // Close button
                    Rectangle {
                        width: 18; height: 18; radius: 4
                        color: closeEditMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.2) : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: ThemeService.grey1 }
                        MouseArea {
                            id: closeEditMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._editingDate = ""
                        }
                    }
                }

                // Existing notes for this date
                Repeater {
                    model: root._editingDate !== "" ? QuickNotesService.getNotesForDate(root._editingDate) : []
                    Rectangle {
                        id: noteRow
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: modelData.id === root._editingNoteId
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 4
                        color: isSelected
                               ? ThemeService.alpha(ThemeService.blue, 0.15)
                               : existNoteMa.containsMouse
                                 ? ThemeService.alpha(ThemeService.fg, 0.08)
                                 : ThemeService.alpha(ThemeService.bg1, 0.4)

                        // hf82e: trigger loadBody for calendar notes
                        // when this row appears. QuickNotesService loads
                        // bodies on demand (line 157 sets body: "" at
                        // scan time), so without this, the title-from-
                        // body extraction below has nothing to read on
                        // first paint. Once loadBody completes, the
                        // notesChanged signal re-renders the Repeater
                        // with .body populated, and the extraction
                        // surfaces the correct first-non-📅 line.
                        Component.onCompleted: {
                            try {
                                const n = noteRow.modelData
                                if (n && n.id && (!n.body || n.body.length === 0)) {
                                    if (typeof QuickNotesService.loadBody === "function") {
                                        QuickNotesService.loadBody(n.id)
                                    }
                                }
                            } catch (e) {
                                console.warn("[ZenNotificationCenter] hf82e loadBody trigger error:", e)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4; spacing: 4
                            // Note title — skip 📅 prefix line
                            //
                            // hf82e: strengthened fallback. If .body
                            // hasn't loaded yet (FileView race at shell
                            // start) AND the stored .title starts with
                            // 📅 (legacy state from before hf82e scan
                            // fix), strip the 📅 prefix and show the
                            // bare date — better than leaving the
                            // user staring at duplicate "📅 2026-05-23"
                            // entries. Once body loads, the proper
                            // first-non-📅 extraction kicks in.
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const n = noteRow.modelData
                                    if (n && n.body && typeof n.body === "string") {
                                        const lines = n.body.split("\n")
                                        for (let i = 0; i < lines.length; i++) {
                                            const t = lines[i].trim()
                                            if (t && !t.startsWith("📅")) return t
                                        }
                                    }
                                    // Body not loaded or no non-📅 line —
                                    // try title, strip 📅 prefix if it's
                                    // the legacy format.
                                    let fallback = (n && n.title) || ""
                                    if (fallback.startsWith("📅")) {
                                        // Show "(loading…)" instead of the
                                        // date duplicate, since the body
                                        // load was triggered above and
                                        // should populate shortly.
                                        return "(loading…)"
                                    }
                                    return fallback || "(untitled)"
                                }
                                font.family: Theme.fontFamily; font.pixelSize: 10
                                font.weight: noteRow.isSelected ? Font.DemiBold : Font.Normal
                                color: ThemeService.fg; elide: Text.ElideRight
                            }
                            // hf79: Edit button — loads note into input for editing
                            Rectangle {
                                width: 22; height: 22; radius: 4
                                color: editBtnMa.containsMouse ? ThemeService.alpha(ThemeService.blue, 0.25) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent; text: "✎"
                                    font.pixelSize: 11
                                    color: editBtnMa.containsMouse ? ThemeService.blue : ThemeService.grey1
                                }
                                MouseArea {
                                    id: editBtnMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const n = noteRow.modelData
                                        root._editingNoteId = n.id
                                        // Load the user-typed content (skip 📅 line) into input
                                        let userText = ""
                                        if (n.body) {
                                            const lines = n.body.split("\n")
                                            for (let i = 0; i < lines.length; i++) {
                                                const t = lines[i].trim()
                                                if (t && !t.startsWith("📅")) { userText = t; break }
                                            }
                                        }
                                        calendarNoteTitle.text = userText || n.title || ""
                                        calendarNoteTitle.forceActiveFocus()
                                    }
                                }
                            }
                            // hf79: Delete button
                            Rectangle {
                                width: 22; height: 22; radius: 4
                                color: delBtnMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.25) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent; text: "🗑"
                                    font.pixelSize: 9
                                    color: delBtnMa.containsMouse ? ThemeService.red : ThemeService.grey1
                                }
                                MouseArea {
                                    id: delBtnMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root._editingNoteId === noteRow.modelData.id) {
                                            root._editingNoteId = ""
                                            calendarNoteTitle.text = ""
                                        }
                                        QuickNotesService.deleteNote(noteRow.modelData.id)
                                    }
                                }
                            }
                            // Completed badge / check
                            Rectangle {
                                visible: !(QuickNotesService.notesMeta[noteRow.modelData.id] || {}).completed
                                width: 22; height: 22; radius: 4
                                color: completeMa.containsMouse ? ThemeService.alpha(ThemeService.green, 0.25) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 9; color: ThemeService.green }
                                MouseArea {
                                    id: completeMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: QuickNotesService.markCompleted(noteRow.modelData.id)
                                }
                            }
                            Text {
                                visible: !!(QuickNotesService.notesMeta[noteRow.modelData.id] || {}).completed
                                text: "✅"; font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: existNoteMa; anchors.fill: parent; hoverEnabled: true; z: -1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Click row = select it
                                root._editingNoteId = noteRow.modelData.id
                            }
                        }
                    }
                }

                // hf79: Edit-mode indicator — shows which note is being edited
                RowLayout {
                    visible: root._editingNoteId !== ""
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "✎ Editing"
                        font.family: Theme.fontFamily; font.pixelSize: 9
                        font.weight: Font.DemiBold; color: ThemeService.blue
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: cancelEditTxt.implicitWidth + 12
                        Layout.preferredHeight: 18; radius: 4
                        color: cancelEditMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : "transparent"
                        Text {
                            id: cancelEditTxt; anchors.centerIn: parent
                            text: "Cancel"; font.family: Theme.fontFamily
                            font.pixelSize: 9; color: ThemeService.grey1
                        }
                        MouseArea {
                            id: cancelEditMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._editingNoteId = ""
                                calendarNoteTitle.text = ""
                            }
                        }
                    }
                }

                // Title input
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 6
                    color: ThemeService.alpha(ThemeService.bg0, 0.8)
                    border.width: 1; border.color: root._editingNoteId
                        ? ThemeService.alpha(ThemeService.blue, 0.4)
                        : ThemeService.alpha(ThemeService.fg, 0.12)
                    TextInput {
                        id: calendarNoteTitle
                        anchors.fill: parent; anchors.margins: 6
                        font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.fg
                        clip: true
                        property string placeholderText: root._editingNoteId
                            ? "Edit note…"
                            : "Event title (e.g. Birthday, Meeting...)"

                        // hf82: live sync from sticky / panel edits.
                        //
                        // User report:
                        //   "yung sa notes kapag nag edit ako sa calendar
                        //    ko hindi na update instantly sa sticky note ko
                        //    dapat live if anu yun update ko dito sa sticky
                        //    note ko naka tag sa calendar matic sa calendar
                        //    live din na update agad reflect gets ?"
                        //
                        // When a sticky note (QuickNotesSticky /
                        // DesktopStickyNotes) or the QuickNotesPanel
                        // edits the body of the note we're currently
                        // looking at in this calendar editor, mirror
                        // that change into this TextInput so the user
                        // sees the latest state without re-clicking
                        // the date cell.
                        //
                        // Guard: don't touch the field while the user
                        // is typing here (activeFocus) — their
                        // keystrokes win. The first non-📅 line of the
                        // note body is the "title" by the same
                        // extraction rule already used in the existing
                        // edit-button handler around line 528-537.
                        property bool _syncingFromService: false
                        Connections {
                            target: typeof QuickNotesService !== "undefined"
                                    ? QuickNotesService
                                    : null
                            function onNotesChanged() {
                                // hf82c: full try/catch + null guards.
                                // This handler runs on every saveBody
                                // flush, which fires synchronously
                                // from notifications via the
                                // calendar-note pipeline. If anything
                                // here throws (notes array transiently
                                // null during initial load, or note
                                // shape changes across versions), Qt
                                // logs but the QML engine may abort
                                // the signal handler chain — which
                                // observably breaks other Connections
                                // wired to the same signal.
                                try {
                                    if (!root._editingNoteId) return
                                    if (calendarNoteTitle.activeFocus) return
                                    if (typeof QuickNotesService === "undefined") return
                                    // Look up the note by id
                                    const noteList = QuickNotesService.notes || []
                                    if (!Array.isArray(noteList)) return
                                    let n = null
                                    for (let i = 0; i < noteList.length; i++) {
                                        if (noteList[i] && noteList[i].id === root._editingNoteId) {
                                            n = noteList[i]; break
                                        }
                                    }
                                    if (!n) return
                                    // Extract first non-📅 line (same
                                    // convention as the edit-button
                                    // handler earlier in this file).
                                    let userText = ""
                                    if (n.body && typeof n.body === "string") {
                                        const lines = n.body.split("\n")
                                        for (let i = 0; i < lines.length; i++) {
                                            const t = lines[i].trim()
                                            if (t && !t.startsWith("📅")) { userText = t; break }
                                        }
                                    }
                                    const fresh = userText || n.title || ""
                                    if (fresh === calendarNoteTitle.text) return
                                    calendarNoteTitle._syncingFromService = true
                                    calendarNoteTitle.text = fresh
                                    calendarNoteTitle._syncingFromService = false
                                } catch (eSync) {
                                    console.warn("[ZenNotificationCenter] hf82c calendar sync error:", eSync)
                                    calendarNoteTitle._syncingFromService = false
                                }
                            }
                        }

                        Text {
                            visible: !parent.text && !parent.activeFocus
                            text: parent.placeholderText
                            font: parent.font; color: ThemeService.grey2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Keys.onEscapePressed: root._editingDate = ""
                        Keys.onReturnPressed: root._saveCalendarNote()
                    }
                }

                // Time input + Save button row
                RowLayout {
                    Layout.fillWidth: true; spacing: 6

                    // Notify time (optional)
                    Rectangle {
                        Layout.preferredWidth: 80; Layout.preferredHeight: 28; radius: 6
                        color: ThemeService.alpha(ThemeService.bg0, 0.8)
                        border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.12)
                        TextInput {
                            id: calendarNoteTime
                            anchors.fill: parent; anchors.margins: 6
                            font.family: Theme.fontFamily; font.pixelSize: 11; color: ThemeService.fg
                            clip: true; inputMask: "99:99"
                            Text {
                                visible: !parent.text && !parent.activeFocus
                                text: "HH:MM"
                                font: parent.font; color: ThemeService.grey2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Keys.onReturnPressed: root._saveCalendarNote()
                        }
                    }
                    Text { text: "🔔"; font.pixelSize: 11; color: ThemeService.grey1; visible: calendarNoteTime.text.length > 0 }
                    Item { Layout.fillWidth: true }

                    // Save button
                    Rectangle {
                        Layout.preferredWidth: 60; Layout.preferredHeight: 28; radius: 6
                        color: saveMa.containsMouse
                               ? ThemeService.alpha(ThemeService.green, 0.4)
                               : ThemeService.alpha(ThemeService.green, 0.2)
                        Text { anchors.centerIn: parent; text: root._editingNoteId ? "Update" : "Save"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.fg }
                        MouseArea {
                            id: saveMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._saveCalendarNote()
                        }
                    }
                }
            }
        }

        // Save helper — hf78: moved to root scope.

        // Today shortcut
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 24; radius: 6
            color: todayMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.05) : "transparent"
            visible: root.viewMonth !== root.todayMonth || root.viewYear !== root.todayYear
            Text { anchors.centerIn: parent; text: "↩ Today"; font.family: Theme.fontFamily; font.pixelSize: 10; color: ThemeService.blue }
            MouseArea { id: todayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.viewYear = root.todayYear; root.viewMonth = root.todayMonth } }
        }

        // ═══════════════════════════════════════════════
        // SEPARATOR
        // ═══════════════════════════════════════════════
        Rectangle {
            // v6.16.4.12.6.51: hidden in compactMode
            visible: !root.compactMode
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 1 : 0
            color: ThemeService.alpha(ThemeService.fg, 0.08)
        }

        // ═══════════════════════════════════════════════
        // SYSTEM QUICK-ACTIONS — bottom section
        // ═══════════════════════════════════════════════
        GridLayout {
            // v6.16.4.12.6.51: hidden in compactMode (hover-peek state)
            visible: !root.compactMode
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6

            // Row 1: Connectivity toggles
            Repeater {
                model: [
                    { icon: "\uf294", label: "BT",       action: "bt",       active: ConnectivityService.btPowered,   color: "blue" },
                    { icon: "\uf1eb", label: "WiFi",     action: "wifi",     active: ConnectivityService.wifiEnabled, color: "blue" },
                    { icon: "\uf023", label: "Lock",     action: "lock",     active: false, color: "yellow" },
                    { icon: "\uf2f5", label: "Logout",   action: "logout",   active: false, color: "orange" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 8
                    color: {
                        if (modelData.active) return ThemeService.alpha(ThemeService[modelData.color] || ThemeService.blue, 0.2)
                        return sysActionMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.08) : ThemeService.alpha(ThemeService.bg1, 0.4)
                    }
                    border.width: 1
                    border.color: modelData.active ? ThemeService.alpha(ThemeService[modelData.color] || ThemeService.blue, 0.3) : ThemeService.alpha(ThemeService.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                            color: modelData.active ? (ThemeService[modelData.color] || ThemeService.blue) : ThemeService.grey0
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold
                            color: modelData.active ? ThemeService.fg : ThemeService.grey1
                        }
                    }

                    MouseArea {
                        id: sysActionMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switch (modelData.action) {
                                case "bt":    ConnectivityService.toggleBluetooth(); break
                                case "wifi":  ConnectivityService.toggleWifi(); break
                                case "lock":  root.powerActionRequested("lock", "hyprlock"); break
                                case "logout": root.powerActionRequested("logout", "hyprctl dispatch exit"); break
                            }
                        }
                    }
                }
            }

            // Row 2: Power actions
            Repeater {
                model: [
                    { icon: "\uf021", label: "Restart",  action: "reboot",   color: "blue" },
                    { icon: "\uf011", label: "Shutdown", action: "shutdown", color: "red" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.preferredHeight: 38
                    radius: 8
                    color: pwrMa.containsMouse
                           ? ThemeService.alpha(ThemeService[modelData.color] || ThemeService.red, 0.15)
                           : ThemeService.alpha(ThemeService.bg1, 0.4)
                    border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: ThemeService[modelData.color] || ThemeService.grey0 }
                        Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: ThemeService.fg }
                    }

                    MouseArea {
                        id: pwrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.action === "reboot") root.powerActionRequested("reboot", "systemctl reboot")
                            else root.powerActionRequested("shutdown", "systemctl poweroff")
                        }
                    }
                }
            }
        }
    }
}
