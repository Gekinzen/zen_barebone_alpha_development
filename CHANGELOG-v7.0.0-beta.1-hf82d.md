# v7.0.0-beta.1-hf82d — Calendar title load fix + Sticky note initial-render race fix + Version display bump

**Channel:** beta (hotfix patch on hf82c)
**Released:** 2026-05-23
**Branch:** `dev`
**Scope:** 4 files patched

---

## Three user-reported issues

### Issue 1 — Calendar shows date instead of saved note title

> "kunwari nag restart ako dun sa calendar kunwari may put nako notes kapag nag restart hindi na nakikita yun notes na nilagay ko ang lumalabas na yun date"

Clicking a day cell that already has a saved note loaded `📅 2026-05-21` (the auto-generated date line) into the editor instead of the user's typed text. The actual note content was preserved on disk, just hidden from the editor on click-open.

**Root cause:** `ZenNotificationCenter.qml` day-cell click handler used `existing[0].title` as the editor's initial text. For calendar notes, `.title` is the **first line of the body**, which the `createCalendarNote()` API pre-fills with `📅 YYYY-MM-DD`. The user's typed text is on the SECOND line. The edit-button handler (around line 530 of the same file) was already doing the right thing — extracting the first non-📅 line — but the day-cell click path was using the cheap shortcut.

**Fix:** Mirror the edit-button extraction logic into the day-cell click handler. First non-📅 line of the body = user's typed text. Fall back to `.title` only for legacy entries with no non-📅 body lines.

### Issue 2 — Sticky note opens blank on first open

> "tas sa notepad sticky note dapat tuwing open natin yun notes autoamtically mag open siya ng new blank na notes nangyayari kasi nakatutok siya sa una pero may laman na yun pero lumalabas wala so kapag click ko yun pangalawa then balik sa una may laman tlga"

The sticky window showed empty/placeholder text the first time it opened even though the note had content. Clicking a different note in the panel then clicking back to the first one made the body appear correctly. So the note WAS loaded — just not rendered on first paint.

**Root cause:** Both `QuickNotesSticky.qml` (normal mode) and `DesktopStickyNotes.qml` (widget mode) use `Component.onCompleted` to initialize `stickyEditor.text` from `note.body`. But `note` is a declarative binding to `QuickNotesService.getNote(noteId)`. If the sticky window mounts **before** `QuickNotesService` finishes loading notes from disk (FileView read race at shell start), `note` is null/undefined at `Component.onCompleted` time, and the editor inits blank.

The `Connections { target: QuickNotesService onNotesChanged }` handler hf82 added only fires on **saves**, not on the initial post-load population. So the editor stayed blank until something else triggered `notesChanged` — which is exactly what clicking another note then back did (the click refreshes the cache, fires `notesChanged`, then THAT path populated the editor).

**Fix:** Two new `Connections` blocks in `QuickNotesSticky.qml`, mirror change in `DesktopStickyNotes.qml`:

- **`target: stickyWindow` / `onNoteChanged`** — fires whenever the `note` ref itself changes (null → populated, or note swapped to a different one). Re-pulls `note.body` into `stickyEditor.text`. Same `activeFocus` + `_syncingFromService` guards as the existing onNotesChanged handler.
- **`target: stickyWindow` / `onVisibleChanged`** — fires when the sticky becomes visible after being hidden. Covers the case where the sticky was off-screen during a note edit and the onNotesChanged handler may have skipped this editor because it wasn't yet rendered. On re-show, re-pull the latest body.

Both wrapped in try/catch with the defensive `_syncingFromService = false` reset on catch (same hf82c pattern).

### Issue 3 — System Information panel still shows hf75

> "yan nalang mga need ayusin pre yun version dito paki update nadin pre"

Settings → User Profile → System Information showed:

```
Version:  v7.0.0-beta.1-hf75 · released 2026-05-18
```

User has been running hf82c. The version label is read from `ZenVersion.qml`, which had three hardcoded strings (`version`, `prerelease`, `releaseDate`) that haven't been bumped since hf75.

**Fix:** `ZenVersion.qml` strings bumped:
- `version` → `v7.0.0-beta.1-hf82d`
- `prerelease` → `beta.1-hf82d`
- `releaseDate` → `2026-05-23`

`versionRaw`, `semver`, `codename`, `codenameKanji`, `channel`, `fullLabel` unchanged (those are stable across hotfixes).

**Recommendation for going forward:** add a single string bump to every hotfix's drop list. Or better, derive the version at build time from `git describe` or the release tarball filename. Out of scope for hf82d but worth noting in the open threads.

---

## Patched files

| File | hf82c | hf82d | Δ | Why |
|---|---:|---:|---:|---|
| `ZenNotificationCenter.qml` | 893 | 925 | +32 | First-non-📅-line extraction in day-cell click |
| `QuickNotesSticky.qml` | 384 | 453 | +69 | `onNoteChanged` + `onVisibleChanged` race fix |
| `DesktopStickyNotes.qml` | 589 (hf47) | 610 | +21 | Same `onNoteChanged` race fix for widget mode |
| `ZenVersion.qml` | 110 (hf75) | 110 | +0 | 3 string bumps, identical line count |
| **Total** | **1976** | **2098** | **+122** | |

`NotificationService.qml` (hf82c, 951 lines), `ZenNotifyToast.qml` (hf82c, 330), `NotificationListPanel.qml` (hf82c, 397), `GameProfileService.qml` (hf82b, 821), `GamingPage.qml` (hf82, 321) all stay at their current versions — not touched by hf82d. If you've already installed hf82c, the 4 files in this drop are all you need.

---

## Install

Drop-in over existing hf82c install:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82d-patch-only.tgz
cp zen-shell-v7.0.0-beta.1-hf82d/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

# Reload shell
pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload, verify:

```fish
# Calendar fix — open notification center, click a date that has a saved
# note. Editor should show the note text, not "📅 YYYY-MM-DD".

# Sticky fix — restart the shell and immediately open a sticky note.
# Body should populate on first paint, not after clicking another note.

# Version fix — Settings → User Profile → scroll to System Information.
# Should read: v7.0.0-beta.1-hf82d · released 2026-05-23
grep "version:" ~/.config/quickshell/zen-shell/ZenVersion.qml
```

---

## Wala tayong babawasan

Three behavioral changes:

1. **Calendar day-cell click** now resolves `.title` differently — extraction logic copied from the existing edit-button handler. Pre-hf82d behavior of showing `📅 YYYY-MM-DD` was a bug; the new behavior shows the user's typed text. Legacy entries with no non-📅 body lines still fall back to `.title`.
2. **Sticky note editor** now re-initializes when `note` changes from null to populated. Pre-hf82d behavior of staying blank was a bug; the new behavior shows the body on first paint. The `activeFocus` and `_syncingFromService` guards prevent the new handlers from clobbering user typing — if you're typing in this editor, the sync is skipped.
3. **`ZenVersion.qml` strings** swapped 3 lines. No new properties, no removed properties.

Header version bumps:
- `ZenNotificationCenter.qml`: hf82c → hf82d
- `QuickNotesSticky.qml`: hf82c → hf82d
- `DesktopStickyNotes.qml`: hf47 → hf82d (was carrying an old header; current hotfix line catches up)
- `ZenVersion.qml`: alpha.1 → hf82d (was carrying the original header)

Zero removals across all 4 files.
