# v7.0.0-beta.1-hf82e — Calendar note titles, sticky sidebar titles, flameshot 1.5x scale fix

**Channel:** beta (hotfix patch on hf82d)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 4 QML files + 1 script

---

## Three user-reported issues

### Issue 1 — Calendar note list shows dates instead of titles

> "heto pre nagiging date siya ehh may mga notes ako jan dapat nakikita padin . lalabas lang yun actual messages kapag open ko yun sticky note natin tas dapat kung naka select ito dapat nakuha din agad yun data hindi yun need pa select isa and back and forth TINGNAN MO NAG REFRESH NA DITO"

The calendar entry panel showed every saved note as `📅 2026-05-23` (the date prefix) instead of the actual user-typed title. After clicking around (clicking another note then back), the list refreshed and showed the correct titles.

### Issue 2 — Sticky notes panel sidebar shows the same dates

Same root cause as Issue 1 — the sticky notes panel sidebar at left also showed `📅 2026-05-23` repeated for every calendar note, instead of the typed text.

### Root cause for Issues 1 + 2

Calendar notes are created with body `"📅 YYYY-MM-DD\n<title>\n..."`. The title field stored in `notes[].title` came from the scan-time bash command:

```bash
title=$(grep -m1 . "$f" | head -c 80 | tr '\n' ' ')
```

`grep -m1 .` grabs the **first non-empty line** — which for calendar notes is the 📅 prefix line, not the user's typed text. So `.title` was stored wrong.

Compounding the issue: `QuickNotesService` loads bodies **on demand** (line 157: `body: ""` at scan time). The list-rendering paths in `ZenNotificationCenter` + `QuickNotesPanel` both have "first non-📅 line" extraction logic on `.body`, but it fails when `.body` is empty (still pending FileView read), and falls back to the broken `.title`.

That's why clicking around made it work — clicking a note triggered `loadBody()`, which populated `.body`, which then made the extraction succeed.

### Fix

Three layers of defense, applied in `hf82e`:

1. **Scan-time title extraction fixed** (`QuickNotesService.qml`). The bash command now uses `awk` to find the first non-empty line that does NOT start with 📅:
   ```bash
   title=$(awk 'NF && !/^📅/ {print; exit}' "$f" | head -c 80 | tr '\n' ' ')
   ```
   Falls back to the old `grep -m1 .` if no non-📅 line is found (covers legacy / non-calendar notes that legitimately start with the emoji, and empty notes).

2. **Calendar list now triggers `loadBody()` per row** (`ZenNotificationCenter.qml`). When a `noteRow` Rectangle mounts and its `modelData.body` is empty, the row asks `QuickNotesService.loadBody(id)` to fetch from disk. Once it lands, `notesChanged` fires and the row re-renders with the proper body. While the load is pending, the row shows `(loading…)` instead of the bare `📅 YYYY-MM-DD` date duplicate.

3. **Sticky panel sidebar title extraction strengthened** (`QuickNotesPanel.qml`). Previously read `modelData.title` directly; now applies the same first-non-📅-line extraction from `.body` as the calendar repeater, falling back to `.title`. Covers live in-memory edits where `.title` hasn't caught up to the new body, and any cached state-file entries from before the scan fix.

After hf82e:
- Fresh shell start → calendar and sidebar both show correct titles immediately (scan-time fix).
- Live edits → propagate via existing `notesChanged` plumbing.
- Legacy state files → repaired on first scan write-back.
- Empty / pending bodies → show `(loading…)` instead of the wrong date.

---

### Issue 3 — Flameshot doesn't capture full screen at 1.5 scale

> "kapag nag screenshot ako ng flame shot kapag naka 1.5 scale dapat ma detect ko padin yun actual buong size ng screen"

On a 3440x1440 monitor at 1.5x scale, Hyprland reports the monitor as `width: 3440, height: 1440, scale: 1.5`. The logical workspace (what Wayland clients see) is `2293x960`.

`zen-screenshot.sh v6.12`'s `get_active_monitor_geometry()` function had a Python helper that computed `w = m['width']/scale` and `h = m['height']/scale` for use in slurp — but then printed `m["width"]xm["height"]` instead of the computed `w`/`h`. So flameshot got passed the **native** 3440x1440 region, while Wayland screencopy operates in **logical** 2293x960 space. Result: flameshot's region either:
- Overshot the actual screen and captured only the part that fit within bounds (cropped right/bottom edges).
- Failed to detect the entire visible area of the focused monitor.

**Fix:** `zen-screenshot.sh` bumped to v6.13. `get_active_monitor_geometry()` now prints the divided-by-scale values (logical dimensions), matching what `get_active_monitor_slurp()` already did correctly. The script's other paths (grim+slurp, full-monitor capture by name) were unaffected — only the flameshot `--region` argument path had the bug.

After hf82e:
- `flameshot gui` (region mode, mapped to your screenshot keybind) → opens covering the entire visible workspace of the focused monitor at 1.5x scale.
- `flameshot full --region` → captures the entire visible workspace.

---

## Patched files

| File | hf82d | hf82e | Δ | Why |
|---|---:|---:|---:|---|
| `QuickNotesService.qml` | 844 (hf39) | 878 | +34 | Awk-based first-non-📅 extraction in scan command + version header bump |
| `QuickNotesPanel.qml` | 616 (hf39) | 650 | +34 | Sidebar title now uses first-non-📅-line extraction + 📅-prefix-strip fallback + version header bump |
| `ZenNotificationCenter.qml` | 925 | 968 | +43 | Per-row `loadBody()` trigger + strengthened title fallback (📅-prefix → `(loading…)`) + version header bump |
| `ZenVersion.qml` | 110 | 110 | +0 | 3 string bumps |
| `scripts/zen-screenshot.sh` | 204 (v6.12) | 232 | +28 | Logical-dimension fix in `get_active_monitor_geometry()` |
| **Total** | **2699** | **2838** | **+139** | |

`NotificationService.qml` (hf82c, 951), `QuickNotesSticky.qml` (hf82d, 453), `DesktopStickyNotes.qml` (hf82d, 610), `ZenNotifyToast.qml` (hf82c, 330), `NotificationListPanel.qml` (hf82c, 397), `GameProfileService.qml` (hf82b, 821), `GamingPage.qml` (hf82, 321) all stay at their current versions — not touched by hf82e.

---

## Install

Drop-in over existing hf82d install:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82e-patch-only.tgz

# QML files into the flat config root
cp zen-shell-v7.0.0-beta.1-hf82e/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

# Updated screenshot script (path may differ — check yours)
cp zen-shell-v7.0.0-beta.1-hf82e/scripts/zen-screenshot.sh \
   ~/.config/quickshell/zen-shell/scripts/
chmod +x ~/.config/quickshell/zen-shell/scripts/zen-screenshot.sh

# Reload shell
pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload:
1. Open notification center → click May 23 → list should show actual note titles (`asdasdasd`, `asdasdasdasd`, etc.), not `📅 2026-05-23` repeated. No clicking-around needed.
2. Open QuickNotes panel (sticky note sidebar) → calendar notes should show their proper titles in the sidebar.
3. Run `flameshot gui` on 1.5x scaled monitor → region picker should cover the entire visible workspace, not just a cropped corner.
4. Settings → User Profile → System Information → should now read `v7.0.0-beta.1-hf82e · released 2026-05-24`.

---

## Optional one-time legacy state repair

If your `quick-notes.json` state file has cached titles from before hf82e (which it will, since that's exactly the data you've been looking at), the first scan after hf82e installs will rebuild the in-memory `notes[].title` correctly from the `.md` files. The state file gets re-written on the next save debounce.

If you want to force-rebuild immediately without waiting:

```fish
# Trigger a rescan by touching any note file
touch ~/.local/share/zen-notes/*.md
# Then reload shell
pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

---

## Wala tayong babawasan

Five behavioral changes:

1. **Scan-time title extraction** changed from "first non-empty line" to "first non-empty line that doesn't start with 📅, falling back to the old behavior if no such line exists." Old behavior preserved for legacy notes that don't have the calendar prefix. No removed code paths.
2. **Calendar list rendering** now triggers per-row `loadBody()` and shows `(loading…)` while pending. Pre-hf82e behavior of showing the date duplicate was a bug; new behavior shows useful loading state then the right title.
3. **Sticky panel sidebar** now applies the same extraction logic as the calendar list. Pre-hf82e behavior of trusting `.title` directly was a bug.
4. **`zen-screenshot.sh` `get_active_monitor_geometry()`** now prints logical (divided-by-scale) dimensions. Pre-hf82e behavior of printing native pixels was a bug on scaled displays.
5. **Version strings** bumped hf82d → hf82e.

Zero removals. Five header bumps (each file's `v7.0.0-beta.1-hfXX` comment line swapped for hf82e; one underlying script version `v6.12` → `v6.13`).
