import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * CalendarButton v6.16.4.12 — Hikari 光
 *
 * Self-contained bar module. Click → opens PopupWindow with
 * calendar + notifications + system icons. No external wiring.
 *
 * To use: add "calendar" to your barLayout via Settings → Panel.
 */
Rectangle {
    id: root

    width: dateText.implicitWidth + 24
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    color: ma.containsMouse ? Theme.alpha(Theme.blue, 0.25) : Theme.alpha(Theme.bg0, 0.9)
    border.width: 1
    border.color: ma.containsMouse ? Theme.blue : Theme.bg1

    Behavior on color { ColorAnimation { duration: 150 } }

    // ── Live date ──
    property var now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }

    readonly property var monthShort: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    readonly property var monthFull: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayHeaders: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: "\uf073"  // calendar icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: ma.containsMouse ? Theme.blue : Theme.fg
        }
        Text {
            id: dateText
            text: monthShort[root.now.getMonth()] + " " + root.now.getDate()
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.fg
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            console.log("[CalendarButton] click — popup.visible was:", popup.visible)
            popup.visible = !popup.visible
        }
    }

    // ═══════════════════════════════════════════════════════════
    // POPUP — calendar + notifications + system icons
    // PopupWindow is a Quickshell primitive that positions itself
    // relative to its anchor item (this rectangle).
    // ═══════════════════════════════════════════════════════════
    PopupWindow {
        id: popup

        // ───────────────────────────────────────────────────────
        // v6.16.4.12.7.1 — 4-direction-aware popup positioning.
        //
        // CalendarButton uses manual `anchor.rect.x/y` (not anchor.item)
        // because it needs absolute control over the popup's offset —
        // it's a 330×540 calendar box, not a generic tooltip. So the
        // helpers in PanelState don't apply directly; we have to do
        // the x/y math ourselves for each of the four bar positions.
        //
        // The popup's reference point is the bar module (root). The
        // popup should always grow AWAY from the bar so it never
        // overlaps it and never gets clipped by the bar's screen edge.
        //
        //   Bar bottom (default):
        //     x = button center − popupWidth/2  (centered on button)
        //     y = button.y − popupHeight        (above the button)
        //
        //   Bar top:
        //     x = button center − popupWidth/2  (centered on button)
        //     y = button.y + button.height + 8  (below the button)
        //
        //   Bar left (vertical, future):
        //     x = button.x + button.width + 8   (right of the button)
        //     y = button center − popupHeight/2 (centered on button)
        //
        //   Bar right (vertical, future):
        //     x = button.x − popupWidth − 8     (left of the button)
        //     y = button center − popupHeight/2 (centered on button)
        //
        // popupWidth = 330, popupHeight = 540 (must match implicitWidth/
        // implicitHeight below). 8px gap between bar and popup avoids
        // visual collision while keeping the click affordance tight.
        // ───────────────────────────────────────────────────────
        readonly property int _popupW: 330
        readonly property int _popupH: 540
        readonly property int _gap: 8

        anchor.window: QsWindow.window
        anchor.rect.x: {
            if (PanelState.isLeft)  return root.x + root.width + popup._gap
            if (PanelState.isRight) return root.x - popup._popupW - popup._gap
            // Horizontal bar (top/bottom) — centered on the button
            return root.x + (root.width / 2) - (popup._popupW / 2)
        }
        anchor.rect.y: {
            if (PanelState.isTop)    return root.y + root.height + popup._gap
            if (PanelState.isLeft || PanelState.isRight)
                return root.y + (root.height / 2) - (popup._popupH / 2)
            // Bottom bar (default) — above the button
            return root.y - popup._popupH
        }
        anchor.rect.width: 0
        anchor.rect.height: 0

        implicitWidth: popup._popupW
        implicitHeight: popup._popupH
        color: "transparent"
        visible: false

        // ── Calendar state ──
        property int viewYear: new Date().getFullYear()
        property int viewMonth: new Date().getMonth()
        readonly property var today: new Date()

        // ─────────────────────────────────────────────────────────
        // v7.0.0-beta.1-hf76 — Right-click-day → add note overlay
        //
        // Right-clicking a current-month day cell opens a small inline
        // entry over the calendar. Type → Enter saves the note to
        // QuickNotesService via createCalendarNote(dateStr, title, "")
        // — which appends to the same data model DesktopStickyNotes
        // renders from, so the new note appears as a sticky immediately
        // (no extra wiring needed).
        //
        // Empty notifyTime ("") means no notification schedule — the
        // note is anchored to the date but doesn't fire notify-send.
        // Date is YYYY-MM-DD to match QuickNotesService._dateToStr().
        // ─────────────────────────────────────────────────────────
        property string _entryDateStr: ""
        property bool _entryVisible: false

        function _padN(n) { return n < 10 ? "0" + n : "" + n }
        function _formatDate(y, m, d) {
            return y + "-" + popup._padN(m + 1) + "-" + popup._padN(d)
        }

        function _openNoteEntry(dayCell) {
            // hf77: any cell is right-clickable; spill cells use their
            // OWN cellYear/cellMonth (set in buildDays) so the date is
            // accurate even when right-clicking the trailing "1, 2, 3"
            // of next month while viewing the current one.
            const y = (dayCell.cellYear !== undefined) ? dayCell.cellYear : popup.viewYear
            const m = (dayCell.cellMonth !== undefined) ? dayCell.cellMonth : popup.viewMonth
            popup._entryDateStr = popup._formatDate(y, m, dayCell.day)
            popup._entryVisible = true
            Qt.callLater(function() {
                if (typeof noteEntryInput !== "undefined") {
                    noteEntryInput.text = ""
                    noteEntryInput.forceActiveFocus()
                }
            })
        }

        // hf77: explicit close helper — clears dateStr so the next
        // open can't ever resurface a stale value (defensive against
        // the "📅 undefined" class of bugs).
        function _closeNoteEntry() {
            popup._entryVisible = false
            popup._entryDateStr = ""
            if (typeof noteEntryInput !== "undefined") noteEntryInput.text = ""
        }

        function _commitNote() {
            const txt = (typeof noteEntryInput !== "undefined") ? noteEntryInput.text : ""
            if (txt && txt.trim().length > 0 && popup._entryDateStr) {
                QuickNotesService.createCalendarNote(popup._entryDateStr, txt.trim(), "")
                // hf77: keep the overlay open after save so the new
                // note appears in the left list immediately (binding
                // refresh via QuickNotesService.notesMeta change).
                // User closes via × button, Esc, or backdrop click.
                if (typeof noteEntryInput !== "undefined") noteEntryInput.text = ""
            }
        }

        onVisibleChanged: {
            if (visible) {
                viewYear = new Date().getFullYear()
                viewMonth = new Date().getMonth()
                if (typeof notifPoll !== "undefined") notifPoll.running = true
            } else {
                // hf76/hf77: tidy entry state when popup closes — go
                // through _closeNoteEntry so noteEntryInput.text also
                // resets (otherwise stale text could appear next open).
                popup._closeNoteEntry()
            }
        }

        // ── Notification state ──
        property int notifCount: 0
        property bool dndEnabled: false

        Process {
            id: notifPoll
            command: ["swaync-client", "-swb"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(this.text)
                        popup.notifCount = d.count || 0
                        popup.dndEnabled = d.dnd || false
                    } catch (e) {}
                }
            }
        }
        Timer { interval: 2000; running: popup.visible; repeat: true; onTriggered: notifPoll.running = true }

        // ── Build calendar grid ──
        // hf77: each cell carries its own true cellYear / cellMonth so
        // prev-/next-month spill cells produce correct YYYY-MM-DD when
        // right-clicked. Without this, spill cells would inherit
        // viewYear/viewMonth and silently misroute notes to the wrong
        // month (e.g. right-clicking the leading "30" from April while
        // viewing May would save under May-30 instead of April-30).
        function buildDays() {
            const firstDay = new Date(popup.viewYear, popup.viewMonth, 1).getDay()
            const daysInMonth = new Date(popup.viewYear, popup.viewMonth + 1, 0).getDate()
            const prevMonthDays = new Date(popup.viewYear, popup.viewMonth, 0).getDate()
            const prevM = popup.viewMonth === 0 ? 11 : popup.viewMonth - 1
            const prevY = popup.viewMonth === 0 ? popup.viewYear - 1 : popup.viewYear
            const nextM = popup.viewMonth === 11 ? 0 : popup.viewMonth + 1
            const nextY = popup.viewMonth === 11 ? popup.viewYear + 1 : popup.viewYear
            let cells = []
            for (let i = firstDay - 1; i >= 0; i--)
                cells.push({ day: prevMonthDays - i, current: false, cellYear: prevY, cellMonth: prevM })
            for (let d = 1; d <= daysInMonth; d++)
                cells.push({ day: d, current: true, cellYear: popup.viewYear, cellMonth: popup.viewMonth })
            let nextDay = 1
            while (cells.length < 42)
                cells.push({ day: nextDay++, current: false, cellYear: nextY, cellMonth: nextM })
            return cells
        }

        // ── Power action runner ──
        Process { id: powerRunner; running: false }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.97)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.12)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // ─── NOTIFICATIONS ROW ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 10
                    color: notifMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : Theme.alpha(Theme.bg1, 0.5)
                    border.width: 1; border.color: Theme.alpha(Theme.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: popup.dndEnabled ? "\uf1f6" : (popup.notifCount > 0 ? "\uf0f3" : "\uf0a2")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: popup.notifCount > 0 ? Theme.yellow : Theme.grey0
                        }
                        Text {
                            text: "Notifications"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.fg
                        }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: popup.notifCount > 0
                            width: countText.implicitWidth + 14; height: 22; radius: 11
                            color: Theme.alpha(Theme.yellow, 0.2)
                            border.width: 1; border.color: Theme.alpha(Theme.yellow, 0.3)
                            Text {
                                id: countText; anchors.centerIn: parent
                                text: popup.notifCount
                                font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold
                                color: Theme.yellow
                            }
                        }
                    }

                    MouseArea {
                        id: notifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached({command: ["swaync-client", "-t", "-sw"]})
                    }
                }

                // ─── CALENDAR HEADER ───
                RowLayout {
                    Layout.fillWidth: true; spacing: 0

                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                        color: prevMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf104"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.grey0 }
                        MouseArea {
                            id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popup.viewMonth === 0) { popup.viewMonth = 11; popup.viewYear-- }
                                else popup.viewMonth--
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.monthFull[popup.viewMonth] + " " + popup.viewYear
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.fg
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                        color: nextMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf105"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.grey0 }
                        MouseArea {
                            id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popup.viewMonth === 11) { popup.viewMonth = 0; popup.viewYear++ }
                                else popup.viewMonth++
                            }
                        }
                    }
                }

                // ─── DAY HEADERS ───
                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Repeater {
                        model: root.dayHeaders
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.grey1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // ─── DAY GRID ───
                Grid {
                    Layout.fillWidth: true
                    columns: 7; rows: 6; spacing: 2
                    Repeater {
                        model: popup.buildDays()
                        Rectangle {
                            id: dayCell
                            required property var modelData
                            readonly property bool isToday:
                                modelData.current
                                && modelData.day === popup.today.getDate()
                                && popup.viewMonth === popup.today.getMonth()
                                && popup.viewYear === popup.today.getFullYear()
                            // hf77: cellDateStr is built from the cell's OWN
                            // cellYear/cellMonth (set in buildDays), so spill
                            // cells get correct dates instead of "" — this is
                            // what enables right-click on any cell + dot
                            // indicators on adjacent-month days that have notes.
                            readonly property string cellDateStr:
                                popup._formatDate(modelData.cellYear, modelData.cellMonth, modelData.day)
                            readonly property bool hasNote:
                                (QuickNotesService.notesByDate[cellDateStr] || 0) > 0
                            width: (popup.implicitWidth - 28 - 12) / 7
                            height: 28
                            radius: 6
                            color: isToday ? Theme.alpha(Theme.blue, 0.3) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: isToday ? Font.Bold : Font.Normal
                                color: isToday
                                       ? Theme.fg
                                       : (modelData.current ? Theme.grey0 : Theme.grey2)
                            }
                            // hf77: dot indicator moved to UPPER-RIGHT (was
                            // bottom-center in hf76). 5×5 instead of 4×4 for
                            // visibility. Adjacent-month spill cells with
                            // notes also show the dot — gives at-a-glance
                            // context that notes exist just outside the
                            // current view window.
                            Rectangle {
                                visible: dayCell.hasNote
                                width: 5; height: 5; radius: 2.5
                                color: dayCell.isToday ? Theme.fg : Theme.yellow
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 3
                                anchors.rightMargin: 3
                            }
                            // hf77: right-click works on ANY cell (no longer
                            // gated by modelData.current). Spill cells route
                            // to the correct adjacent-month date via the
                            // cellYear/cellMonth carried in modelData.
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        popup._openNoteEntry(dayCell.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── SEPARATOR ───
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    color: Theme.alpha(Theme.fg, 0.08)
                }

                // ─── SYSTEM QUICK-ACTIONS ───
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6

                    // Row 1: BT / WiFi / Lock / Logout
                    Repeater {
                        model: [
                            { icon: "\uf293", label: "BT",     action: "bt" },
                            { icon: "\uf1eb", label: "WiFi",   action: "wifi" },
                            { icon: "\uf023", label: "Lock",   action: "lock" },
                            { icon: "\uf2f5", label: "Logout", action: "logout" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 8
                            color: btnMa.containsMouse
                                   ? Theme.alpha(Theme.blue, 0.18)
                                   : Theme.alpha(Theme.bg1, 0.4)
                            border.width: 1
                            border.color: Theme.alpha(Theme.fg, 0.06)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: Theme.fg
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: Theme.grey0
                                }
                            }

                            MouseArea {
                                id: btnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    switch (modelData.action) {
                                        case "bt":
                                            powerRunner.command = ["bash", "-c", "bluetoothctl power on || bluetoothctl power off"]
                                            powerRunner.running = true
                                            break
                                        case "wifi":
                                            powerRunner.command = ["bash", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"]
                                            powerRunner.running = true
                                            break
                                        case "lock":
                                            popup.visible = false
                                            powerRunner.command = ["hyprlock"]
                                            powerRunner.running = true
                                            break
                                        case "logout":
                                            popup.visible = false
                                            powerRunner.command = ["hyprctl", "dispatch", "exit"]
                                            powerRunner.running = true
                                            break
                                    }
                                }
                            }
                        }
                    }

                    // Row 2: Restart / Shutdown
                    Repeater {
                        model: [
                            { icon: "\uf021", label: "Restart",  cmd: "systemctl reboot",   color: Theme.blue },
                            { icon: "\uf011", label: "Shutdown", cmd: "systemctl poweroff", color: Theme.red }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            Layout.preferredHeight: 38
                            radius: 8
                            color: pwrMa.containsMouse
                                   ? Theme.alpha(modelData.color, 0.2)
                                   : Theme.alpha(Theme.bg1, 0.4)
                            border.width: 1
                            border.color: Theme.alpha(Theme.fg, 0.06)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent; spacing: 6
                                Text {
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: modelData.color
                                }
                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                }
                            }

                            MouseArea {
                                id: pwrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    popup.visible = false
                                    powerRunner.command = ["bash", "-c", modelData.cmd]
                                    powerRunner.running = true
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════
            // v7.0.0-beta.1-hf77 — Note entry / browse overlay
            //
            // Sibling of the ColumnLayout above, sits on top via z:100.
            // STARTS HIDDEN — visible only when popup._entryVisible is
            // true (set strictly by right-click on a day cell).
            //
            // Two modes driven by whether the date already has notes:
            //
            //   1) Date has NO notes yet → compact card with just the
            //      "Add a note…" input + Add button. Card height ~120.
            //
            //   2) Date has ≥1 existing notes → expanded card with a
            //      split body — LEFT: scrollable list of note titles
            //      for this date, RIGHT: full body of the selected
            //      note. Add row stays at the bottom for quick "Add
            //      another". After save, overlay stays open so the
            //      new note appears in the list reactively (via the
            //      QuickNotesService.notesMeta binding chain).
            //
            // Esc / × button / backdrop click all dismiss. The card
            // itself swallows clicks so typing doesn't dismiss.
            //
            // Defensive against the hf76 "📅 undefined" symptom:
            //   - _entryDateStr only ever set inside _openNoteEntry
            //   - _closeNoteEntry clears it to "" so a stale string
            //     can never resurface on next open
            //   - Header guards visibility on _entryDateStr !== ""
            // ═════════════════════════════════════════════════════
            Rectangle {
                id: noteEntryOverlay
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.92)
                visible: popup._entryVisible && popup._entryDateStr !== ""
                z: 100

                // Backdrop click → cancel
                MouseArea {
                    anchors.fill: parent
                    onClicked: popup._closeNoteEntry()
                }

                // Centered entry / browse card
                Rectangle {
                    id: noteEntryCard
                    anchors.centerIn: parent
                    width: parent.width - 20

                    // hf77: reactive data for the split view. Binding
                    // tracks both popup._entryDateStr AND the reads
                    // inside getNotesForDate (root.notes, root.notesMeta),
                    // so adding a note via _commitNote refreshes the
                    // list without any imperative call.
                    readonly property var dateNotes: {
                        if (!popup._entryDateStr) return []
                        return QuickNotesService.getNotesForDate(popup._entryDateStr) || []
                    }
                    readonly property int notesCount: dateNotes.length
                    readonly property bool hasNotes: notesCount > 0
                    property int selectedIdx: 0
                    readonly property var selectedNote:
                        (hasNotes && selectedIdx >= 0 && selectedIdx < notesCount)
                        ? dateNotes[selectedIdx]
                        : null

                    // When the date changes (different cell right-clicked),
                    // reset selection to the first note.
                    Connections {
                        target: popup
                        function on_EntryDateStrChanged() { noteEntryCard.selectedIdx = 0 }
                    }
                    // Also clamp if the list shrinks (e.g. note deleted elsewhere).
                    onNotesCountChanged: {
                        if (selectedIdx >= notesCount) selectedIdx = Math.max(0, notesCount - 1)
                    }

                    height: hasNotes ? 360 : 120
                    radius: 10
                    color: Theme.alpha(Theme.bg1, 0.98)
                    border.width: 1
                    border.color: Theme.alpha(Theme.blue, 0.4)

                    // Swallow card clicks so backdrop dismiss doesn't fire
                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // ── Header: 📅 date · count · ×  ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "\uf073"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.blue
                            }
                            Text {
                                Layout.fillWidth: true
                                text: popup._entryDateStr
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.fg
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: noteEntryCard.hasNotes
                                text: noteEntryCard.notesCount + (noteEntryCard.notesCount === 1 ? " note" : " notes")
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: Theme.grey1
                            }
                            // Close × button
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 4
                                color: closeBtnMa.containsMouse
                                       ? Theme.alpha(Theme.red, 0.2)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: closeBtnMa.containsMouse ? Theme.red : Theme.grey1
                                }
                                MouseArea {
                                    id: closeBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup._closeNoteEntry()
                                }
                            }
                        }

                        // ── Split body (when notes exist) ──
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: noteEntryCard.hasNotes

                            RowLayout {
                                anchors.fill: parent
                                spacing: 6

                                // LEFT: list of notes for this date
                                Rectangle {
                                    Layout.preferredWidth: 110
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: Theme.alpha(Theme.bg0, 0.6)
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.fg, 0.08)

                                    ListView {
                                        id: notesList
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        clip: true
                                        model: noteEntryCard.dateNotes
                                        spacing: 2
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: notesList.width - 8
                                            height: 26
                                            radius: 4
                                            color: index === noteEntryCard.selectedIdx
                                                   ? Theme.alpha(Theme.blue, 0.28)
                                                   : (itemMa.containsMouse
                                                      ? Theme.alpha(Theme.fg, 0.06)
                                                      : "transparent")
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                // Note title falls back to first
                                                // non-📅 line of body, then "Untitled".
                                                text: {
                                                    const n = parent.modelData
                                                    if (!n) return "Untitled"
                                                    if (n.title && n.title.trim().length > 0) return n.title
                                                    // Parse first useful line of the body
                                                    if (n.body) {
                                                        const lines = n.body.split("\n")
                                                        for (const ln of lines) {
                                                            const t = ln.trim()
                                                            if (t && !t.startsWith("📅")) return t
                                                        }
                                                    }
                                                    return "Untitled"
                                                }
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: index === noteEntryCard.selectedIdx
                                                             ? Font.DemiBold
                                                             : Font.Normal
                                                color: index === noteEntryCard.selectedIdx
                                                       ? Theme.fg
                                                       : Theme.grey0
                                                elide: Text.ElideRight
                                            }
                                            MouseArea {
                                                id: itemMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: noteEntryCard.selectedIdx = parent.index
                                            }
                                        }
                                    }
                                }

                                // RIGHT: selected note body
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: Theme.alpha(Theme.bg0, 0.6)
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.fg, 0.08)

                                    Flickable {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        clip: true
                                        contentWidth: width
                                        contentHeight: detailBodyTxt.implicitHeight
                                        boundsBehavior: Flickable.StopAtBounds

                                        Text {
                                            id: detailBodyTxt
                                            width: parent.width
                                            text: noteEntryCard.selectedNote
                                                  ? (noteEntryCard.selectedNote.body || "(empty)")
                                                  : ""
                                            wrapMode: Text.WordWrap
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.fg
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }
                            }
                        }

                        // ── Empty-state hint (when no notes for this date) ──
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                            visible: !noteEntryCard.hasNotes
                            Text {
                                anchors.centerIn: parent
                                text: "No notes yet — type below to add one"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: Theme.grey1
                            }
                        }

                        // ── Quick-add row (always visible) ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: 6
                                color: Theme.alpha(Theme.bg0, 0.7)
                                border.width: 1
                                border.color: noteEntryInput.activeFocus
                                              ? Theme.blue
                                              : Theme.alpha(Theme.fg, 0.12)
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                TextInput {
                                    id: noteEntryInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.fg
                                    selectionColor: Theme.alpha(Theme.blue, 0.4)
                                    selectedTextColor: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    clip: true
                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: noteEntryCard.hasNotes
                                              ? "Add another note…"
                                              : "Add a note for this day…"
                                        color: Theme.grey1
                                        font: noteEntryInput.font
                                        visible: noteEntryInput.text.length === 0
                                                 && !noteEntryInput.activeFocus
                                    }
                                    Keys.onReturnPressed: popup._commitNote()
                                    Keys.onEnterPressed: popup._commitNote()
                                    Keys.onEscapePressed: popup._closeNoteEntry()
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: addBtnTxt.implicitWidth + 18
                                Layout.preferredHeight: 28
                                radius: 6
                                color: addBtnMa.containsMouse
                                       ? Theme.alpha(Theme.blue, 0.35)
                                       : Theme.alpha(Theme.blue, 0.2)
                                border.width: 1
                                border.color: Theme.alpha(Theme.blue, 0.45)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    id: addBtnTxt
                                    anchors.centerIn: parent
                                    text: "\uf067  Add"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.blue
                                }
                                MouseArea {
                                    id: addBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup._commitNote()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
