# v7.0.0-beta.1-hf82 — Lark crash residue + Auto-Performance opt-in + Calendar↔Sticky live sync

**Channel:** beta (hotfix)
**Released:** 2026-05-21
**Branch:** `dev`

---

## Summary

Three user-reported issues, all surgical:

1. **Lark Suite notifications still occasionally SIGSEGV the shell**
   despite hf79 + hf80, causing a hard Hyprland restart. Root cause:
   `notification.summary` and `notification.appName` were stored raw
   and rendered through `Text {}` elements with no `textFormat` set,
   so Qt's `Text.AutoText` auto-promoted them to the `RichText`
   parser the moment any HTML-looking markup appeared. RichText is
   the exact path hf79 KO'd for `body` — chat apps put markup in
   summaries too.

2. **Game detection always forced power profile to Performance**,
   with no way to enjoy the workflow tagging / DND side of game
   detection without also having the power profile yanked under the
   user. No opt-in control existed.

3. **Calendar ↔ sticky note edits did not propagate live.**
   `QuickNotesPanel` (hf50) and `DesktopStickyNotes` (hf50) already
   use the `_syncingFromService` pattern; `QuickNotesSticky`
   (anchored overlay normal-mode) and the calendar entry editor's
   `calendarNoteTitle` `TextInput` did not — so editing in one
   surface did not show up in the other until you re-clicked the
   date cell or re-opened the sticky.

All three fixes are additive — **wala tayong babawasan**. No
existing feature, file, public property, signal, or behavior was
removed. The one structural change in `QuickNotesSticky.qml`
(replacing the broken declarative `text:` binding with imperative
init + Connections handler) is a fix shape Paul already approved
in hf50 for `DesktopStickyNotes` and `QuickNotesPanel`; same
pattern, applied to the third surface that was missed.

---

## Patched files

### `zen-shell-v5/NotificationService.qml`  (826 → 865 lines)

Added summary + appName sanitization at reception, right after the
existing hf80 body + image sanitization block.

- New `safeSummary` pipeline: hard-cap at 400 chars, strip the
  same dangerous-tag whitelist used for body (extended to also
  strip the few `StyledText`-allowed tags — `<a>`, `<b>`, `<i>`,
  `<u>`, `<s>`, `<br>`, `<font>`, `<center>`, `<strong>`, `<em>` —
  since the summary `Text` is now `PlainText` and shouldn't try to
  render markup at all), strip `data:` URIs, collapse runs of
  whitespace left by the strip.
- New `safeAppName` pipeline: hard-cap at 80 chars, strip ALL
  `<...>` tags conservatively, collapse whitespace.
- `entry.summary` and `entry.appName` now use the sanitized
  versions; everything downstream sees safe strings.

### `zen-shell-v5/ZenNotifyToast.qml`  (311 → 330 lines)

Added `textFormat: Text.PlainText` to both:

- the `Text { text: toast._appName }` element in the toast header,
- the `Text { text: toast._summary }` element below.

Belt-and-suspenders alongside the service-level sanitization
above — closes the `AutoText → RichText` auto-promote door.

### `zen-shell-v5/NotificationListPanel.qml`  (386 → 397 lines)

Same `textFormat: Text.PlainText` lock applied to the appName and
summary `Text` elements inside the list delegate. Body already had
`Text.StyledText` via hf79; appName + summary now match the
plain-text policy.

### `zen-shell-v5/QuickNotesSticky.qml`  (292 → 370 lines)

Replaced the broken declarative `text: stickyWindow.note ? ... : ""`
binding on `TextArea` with the same imperative-init +
`Connections { onNotesChanged }` + `_syncingFromService` guard +
`activeFocus` guard pattern already used by `DesktopStickyNotes`
(hf50) and `QuickNotesPanel`.

Now a sticky in normal-mode (toggle-off) live-updates from edits
made in:

- the calendar entry editor (ZenNotificationCenter),
- the QuickNotesPanel side panel,
- a `DesktopStickyNotes` widget-mode surface for the same note,
- any future surface that calls `QuickNotesService.saveBody(id, ...)`.

The `activeFocus` guard means: if YOU are typing in this sticky
right now, an incoming sync write is skipped so your keystrokes
aren't clobbered. Same semantics as the other two surfaces.

Also added the hf51 focus-loss `deselect() + focus = false` guard
for consistency with `DesktopStickyNotes` — clicking away
properly releases focus/highlight here too.

### `zen-shell-v5/ZenNotificationCenter.qml`  (814 → 872 lines)

Added a `Connections` block inside the `calendarNoteTitle`
`TextInput` that listens for `QuickNotesService.notesChanged` and:

- looks up the note by `root._editingNoteId`,
- extracts the "first non-📅 line" (the same title-extraction rule
  the existing edit-button handler around lines 528–537 uses),
- mirrors that into `calendarNoteTitle.text` via a
  `_syncingFromService` flag — **only if** `calendarNoteTitle` is
  not currently active-focused. If the user is typing into the
  calendar editor input itself, their keystrokes win.

Net effect: with a sticky note open AND the calendar entry editor
open for the same note, typing into either surface live-updates
the other (subject to the focus-guard rule on each side).

### `zen-shell-v5/GameProfileService.qml`  (729 → 790 lines)

New `property bool autoPowerSwitch: false` (default OFF — user
must opt in). Three call sites updated:

- `_enterGameMode()` now only calls
  `WorkflowProfileService.activate("gaming")` when
  `autoPowerSwitch` is true. When false, the rest of game-detection
  state still fires (`gameActive = true`, badge update,
  notification posted) — only the power-profile flip is skipped.
- `_exitGameMode()` matches: only calls
  `WorkflowProfileService.activate(previousProfile)` when
  `autoPowerSwitch` is true. Doing the rollback otherwise would
  yank the user out of any profile they manually selected between
  game-on and game-off, which is exactly what they're trying to
  avoid.
- The notification body now annotates whether power was switched
  (`⚡ Power-saver → performance`) or not
  (`(auto-power off — profile untouched)`), so the user always
  knows what the shell did or didn't do.

Persistence:

- `_parseGamesJson()` now reads `autoPowerSwitch` from
  `~/.config/quickshell/zen-shell/games.json` if present.
- `_writeGamesJson()` now writes `autoPowerSwitch` into that file.
- `onAutoPowerSwitchChanged: root._queueSave()` queues a save
  every time the user flips the GamingPage toggle.

Migration: missing key in an existing `games.json` falls back to
the new default (false). Users upgrading from hf81 get the
hands-off behavior automatically — anyone who relied on the old
"auto everything" must flip the toggle on once.

### `zen-shell-v5/GamingPage.qml`  (290 → 321 lines)

New `HMRow` row directly under the "Enable game detection" row in
the **Detection** section:

- Label: **Auto-switch to Performance**
- Icon: `\uf0e7` (fa-bolt)
- Bound to `GameProfileService.autoPowerSwitch`
- Description explains the new split semantics in one line:
  detection still runs; power profile is only touched when this
  is on.

---

## Behaviour matrix

| Setting | `enabled` | `autoPowerSwitch` | What happens when game detected |
|---|---|---|---|
| OFF | off | (n/a) | Nothing. No detection. |
| Detect, hands-off (NEW default) | on | off | `gameActive=true`, bar badge updates, "Gaming mode activated (auto-power off — profile untouched)" toast. Power profile NOT changed. |
| Detect + auto-perf (old behavior, opt-in now) | on | on | `WorkflowProfileService.activate("gaming")` → DND on, brightness 95, power profile → Performance. Restored to previous workflow on game exit. |

Gaming Boost (the manual pill in PowerProfileService — toggle
yourself into Performance + blur/dim off) is unchanged and
independent of this toggle.

---

## Lark crash — defense-in-depth recap

After hf82, the full set of mitigations for chat-app spam crashes is:

| Field | At reception | In renderer |
|---|---|---|
| `body` | sanitize tags + data: URIs + 2000 char cap (hf80) | `textFormat: Text.StyledText` + re-sanitize per render (hf79) |
| `summary` | **sanitize tags + data: URIs + 400 char cap (hf82)** | **`textFormat: Text.PlainText` (hf82)** |
| `appName` | **sanitize tags + 80 char cap (hf82)** | **`textFormat: Text.PlainText` (hf82)** |
| `image` | drop data: URIs / large pixmap refs (hf80) | not rendered in toast/list |
| burst rate | 5/3000ms per-app (hf80) | 5 toasts hard cap (hf24) |
| native refs | `_nativeMap` with 30-entry cap (hf80) | warmup gate 3s (hf25), defensive `_dismiss` (hf24) |
| infinite recursion | `_clearNative` fixed (hf80) | |

If Lark / Teams / Workvivo / FB / Discord can still SIGSEGV the
shell after hf82, the next-most-likely culprits would be:

- `notification.actions` array shapes from non-spec-compliant
  senders (currently stored raw on the entry, not yet rendered in
  toast/list but accessible via `invokeAction`),
- pixmap data accessed via the live native ref while DND mode
  silently drops the toast (race window between `tracked=true` and
  ListView delegate teardown).

Neither has been observed in logs yet; flagged here for future
hf83+ work if user reports a fourth crash mode.

---

## Calendar↔Sticky sync — surface coverage

| Surface | Live-sync from `QuickNotesService.notesChanged` |
|---|---|
| `QuickNotesPanel` editor | ✓ hf50 |
| `DesktopStickyNotes` (widget mode) | ✓ hf50 |
| `QuickNotesSticky` (normal mode, anchored overlay) | **✓ hf82** |
| `ZenNotificationCenter.calendarNoteTitle` (TextInput) | **✓ hf82** |
| `ZenNotificationCenter` "Existing notes" Repeater | ✓ already reactive (binds through `QuickNotesService.getNotesForDate(...)`) |

All five surfaces now share the same `_syncingFromService` +
`activeFocus`-guarded pattern. Typing in any of them propagates
to the others on `saveBody()`'s debounce-flush (~500ms), or
sooner via the in-memory `notes` update in `saveBody()` which
fires `notesChanged` synchronously.

---

## Maintainer / install notes

- Pure QML changes. No bootstrap, install.sh, or systemd touched.
- Drop-in via existing zen-update flow or manual:
  ```bash
  cp NotificationService.qml ZenNotifyToast.qml NotificationListPanel.qml \
     QuickNotesSticky.qml ZenNotificationCenter.qml \
     GameProfileService.qml GamingPage.qml \
     ~/.config/quickshell/zen-shell/zen-shell-v5/
  hyprctl dispatch killactive quickshell || pkill -USR1 quickshell || \
    systemctl --user restart quickshell.service
  ```
  Or just `Super+Shift+R` in Hyprland to reload the shell.
- No new dependencies. No `versions.lock` bump needed — same
  Hyprland 0.54 / Quickshell 0.2 / Qt 6.9 baseline as hf81.
- No new files. No deleted files. 7 patched files. 0 removed.

---

## Wala tayong babawasan — strict compliance

Line count delta per file (hf81 → hf82):

| File | hf81 | hf82 | Δ |
|---|---:|---:|---:|
| `GameProfileService.qml` | 729 | 790 | +61 |
| `GamingPage.qml` | 290 | 321 | +31 |
| `NotificationListPanel.qml` | 386 | 397 | +11 |
| `NotificationService.qml` | 826 | 865 | +39 |
| `QuickNotesSticky.qml` | 292 | 370 | +78 |
| `ZenNotificationCenter.qml` | 814 | 872 | +58 |
| `ZenNotifyToast.qml` | 311 | 330 | +19 |
| **Total** | **3648** | **3945** | **+297** |

Every file grew. Header version bumps swap one comment line for
another of equivalent intent (`v6.16.4.12.6.51 (Hikari)` →
`v7.0.0-beta.1-hf82 (Karui)`, etc.) consistent with the
established codename lineage at gekinzen.github.io/zen-shell-site/.
No functional code or comments documenting prior hotfixes were
removed.

The one shape-changed block — `QuickNotesSticky.qml`'s
`TextArea`, which dropped the declarative `text:` binding in
favor of `Component.onCompleted` + `Connections` — is a fix shape
already in production via hf50 (`DesktopStickyNotes`,
`QuickNotesPanel`). Same intent (display + edit the note body),
strictly better implementation (works with live sync; without the
swap, the declarative binding would have to stay broken).
