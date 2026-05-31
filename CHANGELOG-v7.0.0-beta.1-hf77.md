# v7.0.0-beta.1-hf77 — Calendar note entry redux

**Channel:** beta (hotfix)
**Released:** 2026-05-18
**Branch:** `dev`

---

## What this hotfix fixes

User report (screenshot from hf76):

> Entry card permanently visible below the calendar grid with
> header showing "📅 undefined", input empty, sitting between the
> grid and the BT/WiFi/Lock/Logout row. Should only appear on
> right-click of a specific date, and the date should be real.

hf76 shipped with the overlay correctly gated on `_entryVisible`,
but a `Text { text: popup._entryDateStr }` binding could still
render before `_entryDateStr` was set to a real value — opening
the door to a stale or empty header in edge cases. The fix
tightens visibility to `_entryVisible && _entryDateStr !== ""` so
the overlay can never paint without a real anchor date, and
routes all cleanup through a single `_closeNoteEntry()` helper
that also clears the input text (hf76 missed that path on
popup-close).

---

## What this hotfix adds

### Split-view note browser

Right-clicking a day cell that **already has notes** opens an
expanded card (~360px tall) with a two-pane layout:

- **LEFT (110px):** scrollable `ListView` of note titles for this
  date. Title falls back to the first non-📅 line of the note body
  when `note.title` is empty, then to "Untitled". Selected item
  is highlighted in `Theme.blue` @ 0.28.
- **RIGHT (fillWidth):** `Flickable` showing the selected note's
  full body. Plain text, word-wrapped.

When the date has **no notes yet**, the card collapses to ~120px
with a single hint line ("No notes yet — type below to add one")
and the quick-add row.

### Quick-add row (always visible)

A `TextInput` + Add button row stays at the bottom in both modes.
Enter or Add commits via `QuickNotesService.createCalendarNote()`.
After save, the input clears but **the overlay stays open** — the
new note appears in the left list immediately via the reactive
`getNotesForDate()` binding, so you can keep adding notes for the
same date without re-opening. Close via × button in the header,
Esc, or backdrop click.

### Indicator dot — upper-right

Moved from bottom-center (hf76) to **upper-right of the day
number**, 5×5 (was 4×4). The dot now appears on **any cell** with
notes, including prev/next-month spill cells — gives at-a-glance
context that notes exist just outside the current view window.
Color stays `Theme.yellow` (matches the notifications row chip),
swaps to `Theme.fg` on the today-highlighted cell so it stays
visible against the blue background.

### Right-click on any date

hf76 gated `_openNoteEntry` and `hasNote` on `modelData.current`,
silently ignoring right-clicks on prev/next-month spill cells.
hf77 drops the gate. `buildDays()` now carries each cell's
`cellYear` and `cellMonth`, so right-clicking the trailing "1, 2,
3" of June while viewing May correctly routes the note to June,
not May.

This was a latent footgun: had we shipped hf76 as-is, anyone
right-clicking a visible-but-adjacent day would have seen a
no-op with no feedback. Now any visible number is a valid target.

---

## Implementation notes

### buildDays() schema bump

Each cell object grew from `{day, current}` to:

```javascript
{ day, current, cellYear, cellMonth }
```

`cellYear` and `cellMonth` are pre-computed for prev/next month
spill cells (with year rollover at January/December boundaries),
so the day cell's `cellDateStr` binding can always produce a
correct `YYYY-MM-DD` without re-deriving the adjacent month at
the cell level.

This is a non-breaking additive change — any consumer reading
`{day, current}` continues to work; the new fields are additive.

### dateNotes binding chain

```qml
readonly property var dateNotes: {
    if (!popup._entryDateStr) return []
    return QuickNotesService.getNotesForDate(popup._entryDateStr) || []
}
```

QML's binding tracker registers reads inside the expression. The
function call into `QuickNotesService.getNotesForDate` itself
reads `root.notes` and `root.notesMeta`, which are tracked
transitively. Result: after `_commitNote()` calls
`createCalendarNote()`, `notesMeta` updates → `dateNotes`
re-evaluates → ListView model refreshes → the new note shows
up in the left pane. No manual refresh needed.

### Selection clamping

When a note is deleted elsewhere (e.g., via QuickNotesPanel)
while the overlay is open viewing the same date, `notesCount`
drops. `onNotesCountChanged` clamps `selectedIdx` to
`Math.max(0, notesCount - 1)` so the right pane never reads a
stale out-of-bounds index. If the count drops to 0, the
`hasNotes` flag flips and the split view hides, falling back to
the empty-state hint.

### Defensive close

`_closeNoteEntry()` is now the single dismiss path. It clears:

- `_entryVisible` → hides the overlay
- `_entryDateStr` → defends against stale-date binds on next open
- `noteEntryInput.text` → blank input on next open

Wired to: × button, Esc, backdrop click, popup close
(`onVisibleChanged: !visible`). hf76 had three of these four
paths only clearing `_entryVisible` — hence the residual stale
state that could surface as "undefined".

### Title resolution priority

```javascript
title || (first non-📅 body line) || "Untitled"
```

`createCalendarNote` sets the body to `"📅 " + dateStr + "\n"
+ title + "\n"` and leaves `title` on the note object empty
(QuickNotesService stores the user input only in the body for
calendar notes). So we parse the body for the first useful line
when rendering the left-pane list, skipping the 📅 anchor line.

---

## Files touched

- `zen-shell-v5/CalendarButton.qml` — replaces the hf76 entry
  overlay (+190 lines net), extends `buildDays()`, rewrites day
  cell indicator/MouseArea. Validated with `qmllint` (Qt5
  syntactic check); brace/paren/bracket balance verified.

---

## Test plan

1. Bar pill click → popup opens. Calendar visible. Entry card
   **NOT** visible. (hf76 regression check.)
2. Right-click today → entry card appears, ~120px tall, header
   shows `📅 2026-05-18` (real date, not "undefined"). Hint
   line: "No notes yet — type below to add one".
3. Type "Pay rent" → Enter. Input clears, card EXPANDS to ~360px,
   left list now shows "Pay rent" selected, right pane shows the
   note body starting with `📅 2026-05-18`. Yellow dot appears
   on today's number in the grid behind (visible via the dimmed
   backdrop).
4. Type "Yoga 6pm" → Enter. Left list now has 2 items. Header
   count: "2 notes". New note auto-selected? No — selection
   stays on first. Click "Yoga 6pm" in the list → right pane
   updates.
5. × button (header top-right) → overlay closes, calendar grid
   visible, today has a yellow dot in the upper-right corner.
6. Reopen popup. Today's number has yellow dot. Right-click
   today → expanded split view directly (skips empty state).
7. Navigate to next month via ▶. Right-click the trailing "1"
   that spills from next-next-month (or the leading "30" from
   previous month). Entry header should show the CORRECT
   adjacent-month date, not the current view month.
8. Right-click a date in a different month. Esc → overlay
   closes. Reopen — overlay stays closed (no stale state).
9. Backdrop click (the dimmed area outside the card) → cancel.
10. While overlay is open on a date with notes, open
    QuickNotesPanel separately and delete one of those notes.
    Return to calendar — list should shrink, selection clamps.

---

## Known limitations / deferred

- Right-pane body is read-only. Editing requires opening
  QuickNotesPanel. Pwedeng i-add ang inline edit later by
  swapping the `Text` for a `TextEdit`.
- No delete affordance per note in the list. Right-pane has no
  "open in QuickNotes" jump button. Both deferred until usage
  feedback.
- Dot color contrast on `Theme.bg0` backgrounds with very low
  alpha may be subtle — yellow on near-black is high-contrast,
  but on lighter themes the 5×5 may need a stronger color or
  border. Defer to first theme report.
