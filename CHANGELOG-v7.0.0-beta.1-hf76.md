# v7.0.0-beta.1-hf76 — Right-click-day → calendar note

**Channel:** beta (hotfix)
**Released:** 2026-05-18
**Branch:** `dev`

---

## What this hotfix adds

`CalendarButton.qml` (the combined Notifications + Calendar + Power
bar module) now lets you attach a sticky note to any current-month
day cell:

1. Open the calendar popup (click the date pill in the bar).
2. **Right-click** a day number.
3. A small inline entry card appears over the calendar with the
   date pre-filled.
4. Type the note title and press **Enter**. **Esc** or backdrop
   click cancels.
5. The note is committed via `QuickNotesService.createCalendarNote(
   dateStr, title, "")` — same code path as any other calendar note
   — so it surfaces immediately in `DesktopStickyNotes` and the
   `QuickNotesPanel` sidebar.

After the note is saved, a small yellow dot indicator appears at
the bottom of the day cell. The dot is driven by a reactive binding
to `QuickNotesService.notesByDate`, so the indicator updates the
instant a note is added or removed via any surface.

The existing left-click semantics on day cells are untouched —
calendar remains primarily a viewer, the right-click is purely
additive. Wala tayong babawasan.

---

## Why this lives in CalendarButton, not ZenCalendar

Two calendar surfaces exist:

- `ZenCalendar.qml` — the small Clock-attached calendar (wheel
  scroll, `↩ Today` shortcut, Escape close).
- `CalendarButton.qml` — the combined bar module with notifications
  row, calendar grid, and system quick-actions.

Only `CalendarButton.qml` gets this feature in hf76. `ZenCalendar`
stays as the pure date viewer it was designed to be — that's the
hover-glance surface. `CalendarButton` is the dedicated panel where
you'd actually be doing calendar work, so it's the right home for
note entry.

If parity becomes desirable later, the entry overlay is structured
as a self-contained sibling Rectangle and could be lifted into a
shared `CalendarNoteEntry.qml` component.

---

## Implementation notes

### Date format

The cell date is computed locally as `YYYY-MM-DD` to match the
format `QuickNotesService._dateToStr()` produces. This keeps
`notesByDate` lookups direct without any conversion. The local
formatter (`popup._formatDate`) is intentionally not delegated to
the service's private helper — keeps the call site free of
underscore-prefixed cross-module access.

### notifyTime intentionally empty

`createCalendarNote(dateStr, title, "")` is invoked with an empty
notify time. That means the calendar notification scheduler in
`QuickNotesService._checkCalendarNotifications` will skip this note
when scanning for upcoming alerts (the scheduler only fires when
`m.notifyTime` is a non-empty `HH:MM` string).

This is intentional for hf76 — the request was for date-anchored
sticky notes, not timed reminders. A future hf can add a `HH:MM`
field to the entry card and pass it through as the third argument
if reminders become desirable.

### TextInput, not TextField

The entry uses bare `TextInput` (QtQuick core) instead of
`TextField` (QtQuick.Controls). This matches the pattern in
`Bar.qml`'s notes about Quickshell + Controls compatibility — the
bar layer keeps its dependency surface minimal. The placeholder
text is overlaid as a sibling `Text` element with visibility tied
to `text.length === 0 && !activeFocus`.

### Reactive dot indicator

```qml
readonly property bool hasNote:
    modelData.current
    && (QuickNotesService.notesByDate[cellDateStr] || 0) > 0
```

QML property bindings track all reads inside the expression, so
when `QuickNotesService.notesByDate` recomputes (which it does
whenever `notesMeta` changes), every day cell re-evaluates and
the dot appears/disappears without any imperative refresh.

### Right-click only

The new MouseArea on day cells uses `acceptedButtons: Qt.RightButton`
exclusively. Left-click events pass through to the parent — which
currently does nothing, but reserves the space for a future
left-click-to-expand-notes-inline feature without disrupting
hf76's behavior.

### Entry state lifecycle

`onVisibleChanged` was extended so that when the calendar popup
itself closes, the entry overlay state (`_entryVisible`,
`_entryDateStr`) is cleared. Otherwise, reopening the popup with
a stale `_entryDateStr` could surface an overlay anchored to the
wrong date.

---

## Files touched

- `zen-shell-v5/CalendarButton.qml` — 245 lines added, 0 removed.
  Validated with `qmllint` (Qt5 syntactic check); brace/paren/
  bracket balance verified.

---

## Test plan

1. Bar pill click → popup opens.
2. Right-click today's number → entry card appears, input focused.
3. Type "Pay rent" → Enter → entry dismisses; small yellow dot
   appears under "today" in the grid.
4. Open `QuickNotesPanel` (Super+N or whatever your bind is) →
   new sticky present with body starting `📅 YYYY-MM-DD\nPay rent\n`.
5. Reopen calendar popup → right-click the same day → entry card
   header shows "1 existing".
6. Esc → cancels cleanly with no note created.
7. Right-click a previous-month or next-month spill cell → no-op
   (intentional — only current-month cells accept entry).
8. Navigate to next month via ▶ → right-click a day → entry card
   shows the navigated month's date, not today's.

---

## Known limitations / deferred

- No HH:MM time field in the entry card (deferred — pass third
  arg to `createCalendarNote` when added).
- No inline preview of existing notes on a date (deferred —
  the "N existing" badge in the header is currently the only hint).
- Entry overlay is not yet a shared component — lives inline in
  `CalendarButton.qml`. Lift to `CalendarNoteEntry.qml` if
  `ZenCalendar` ever needs the same affordance.
