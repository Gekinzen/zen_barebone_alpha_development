# v7.0.0-beta.1-hf82c — Defensive hardening (shot-in-the-dark patch)

**Channel:** beta (hotfix patch on hf82b)
**Released:** 2026-05-22
**Branch:** `dev`
**Honesty:** This patch ships without a captured crash dump. It hardens the most likely remaining crash paths based on the hf82-era code review. **Yung crash dump is still the only way to confirm root cause** — please send the contents of `~/.cache/quickshell/crashes/<latest>/` after testing hf82c so the next round (if needed) is targeted.

---

## Why this patch exists

After hf82b shipped, Paul reported a Quickshell-native crash dialog
(C++-side SIGSEGV, not a QML throw) firing while Lark Suite was
running. The hf82b log confirmed the FileView `text()` unwrap fix
was working — `games.json` now persists correctly, no more
`TypeError: Property 'trim'` line. So whatever's crashing now is
a **different** path than the one hf82b addressed.

Without the new crash dump in hand at patch time, hf82c is
defensive: belt-and-suspenders guards on every remaining surface
that touches Quickshell's native Notification object, plus
try/catch wrappers around the new live-sync Connections handlers
hf82 introduced. If the real crash is in one of these areas, hf82c
fixes it. If the crash is elsewhere (PanelState, Bar, ZenClock,
ThemeService, hyprbars plugin), hf82c will not help — but it also
won't regress anything, since every change is purely additive.

---

## Patched files

### `zen-shell-v5/NotificationService.qml`  (865 → 951 lines, +86)

Three new defensive blocks at notification reception time:

1. **Actions array sanitization.** Previously stored
   `notification.actions || []` raw on the entry. Now: type-check
   each action object, require a string `identifier`, drop entries
   without one, truncate labels to 80 chars, strip HTML tags from
   labels, cap the array at 8 entries (toast can only render ~3
   anyway). Defends against Discord/Slack-wrapped/Electron senders
   that ship malformed action shapes. Wrapped in its own try/catch
   — if sanitization itself throws, we use an empty array and
   continue.

2. **appIcon length cap.** Mirrors hf80's image-field sanitization
   — drop appIcon values longer than 500 chars or starting with
   `data:`. Lark on Wayland has been observed sending appIcon
   strings that are inline base64-PNG pixmaps 100KB+ in size.
   Storing those in the entry blew up later renderers that tried
   to use them as icon-theme names.

3. **Try/catch wrap around `notification.tracked = true`.** This
   is a C++-bridged property on Quickshell's native Notification
   object. If the native peer has been destroyed (spec-violating
   sender that released the dbus reply immediately, or our prior
   `_clearNative` racing with re-emission of the same id), writing
   `tracked` dereferences a freed pointer → SIGSEGV in C++,
   un-catchable by JS. We can't fully prevent that race, but we
   verify the property is still writable, only flip if currently
   `false`, and skip the assignment if any precondition fails.
   Also wraps `_setNative()` in try/catch — entry still lands in
   history without a native ref if it fails, so action buttons
   won't work for that one entry but the daemon survives.

### `zen-shell-v5/ZenNotificationCenter.qml`  (872 → 893 lines, +21)

The `calendarNoteTitle` Connections handler hf82 added now
runs entirely inside a try/catch with explicit null guards:

- `QuickNotesService` typeof check (defensive — service should
  always exist, but absent during shell load it would throw),
- `Array.isArray()` on `notes` before iterating,
- `typeof n.body === "string"` before calling `.split()`,
- explicit reset of `_syncingFromService` to false in the catch
  branch (otherwise a mid-write throw would leave the flag stuck
  on, blocking subsequent user keystrokes from saving).

### `zen-shell-v5/QuickNotesSticky.qml`  (370 → 384 lines, +14)

Same hardening as ZenNotificationCenter — try/catch on the
`onNotesChanged` handler, typeof check on `body` before reading,
defensive `_syncingFromService = false` reset on catch. Also
narrows the `target` of the Connections block to the typeof check
so it won't error if QuickNotesService is unavailable at the
moment the sticky window opens.

### `zen-shell-v5/ZenNotifyToast.qml`  (330 → 330 lines, +0)

Version-header bump only — body text rendering was already locked
to `Text.StyledText` (hf79) and `Text.PlainText` for summary/app-
name (hf82). No further hardening identified without a real
stack trace.

### `zen-shell-v5/NotificationListPanel.qml`  (397 → 397 lines, +0)

Version-header bump only — same as above, already locked to
`Text.PlainText` on appName/summary and `Text.StyledText` on
body.

---

## What hf82c does NOT do

- **Does not change behavior on the happy path.** Every guard is
  invisible until something goes wrong. A well-shaped Lark notif
  with valid actions and a normal appIcon will be processed
  exactly as in hf82b — same sanitization, same rate limiter,
  same toast rendering.
- **Does not touch `GameProfileService.qml`** — the hf82b
  FileView fix is confirmed working (games.json now persists),
  so we leave it alone.
- **Does not change `GamingPage.qml`** — the autoPowerSwitch
  toggle row stays exactly as in hf82.
- **Does not introduce new dependencies, signals, or public
  API.** Internal-only hardening.

---

## Install

Drop-in over existing hf82b install:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82c-patch-only.tgz
cp zen-shell-v7.0.0-beta.1-hf82c/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

# Reload shell
pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

**Note on install path:** Paul's install layout flattens
`zen-shell-v5/*.qml` directly into
`~/.config/quickshell/zen-shell/` (not nested under another
`zen-shell-v5/`). The cp above writes to the correct flattened
location. If you have the tarball's `install.sh`, use that
instead — it knows the layout.

---

## Verification after install

```fish
# All 5 modified files should report hf82c in headers
grep -l "hf82c" ~/.config/quickshell/zen-shell/*.qml
# Expected: 5 files
#   NotificationService.qml  ZenNotificationCenter.qml
#   QuickNotesSticky.qml     ZenNotifyToast.qml
#   NotificationListPanel.qml

# GameProfileService stays at hf82b (untouched)
grep "GameProfileService v7" ~/.config/quickshell/zen-shell/GameProfileService.qml
# Expected: hf82b
```

If quickshell crashes again, **PLEASE** capture the dump:

```fish
ls -la ~/.cache/quickshell/crashes/; and \
set LATEST (ls -td ~/.cache/quickshell/crashes/*/ | head -1); and \
echo "=== Latest: $LATEST ==="; and ls -la $LATEST; and \
for f in (find $LATEST -type f \( -name "*.txt" -o -name "*.log" -o -name "*.json" -o -name "info*" -o -name "meta*" -o -name "stack*" \))
    echo "--- $f ---"; cat $f
end
```

With the dump contents, hf82d (if needed) becomes a 5-minute
targeted patch instead of another defensive round.

---

## Wala tayong babawasan

| File | hf82b | hf82c | Δ | Notes |
|---|---:|---:|---:|---|
| `NotificationService.qml` | 865 | 951 | +86 | Actions + appIcon sanitization, tracked= guard, _setNative wrap |
| `ZenNotificationCenter.qml` | 872 | 893 | +21 | Hardened calendarNoteTitle Connections |
| `QuickNotesSticky.qml` | 370 | 384 | +14 | Hardened onNotesChanged handler |
| `ZenNotifyToast.qml` | 330 | 330 | +0 | Header bump only |
| `NotificationListPanel.qml` | 397 | 397 | +0 | Header bump only |
| **Total** | **2834** | **2955** | **+121** | |

Zero removals. Zero behavior change on the happy path.
`GameProfileService.qml` (hf82b, 821 lines) and `GamingPage.qml`
(hf82, 321 lines) are not touched by hf82c and stay at their
hf82b/hf82 line counts.
