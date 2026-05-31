# Zen Shell v7.0.0-beta.1-hf95.31 — Karui (軽い)

Release date: 2026-06-01
Channel: beta · Codename: Karui (軽い)

**Dock now scales icons to fit (then shows scroll arrows) in
fullwidth/floating, with a Minimum-icon-scale slider; the taskbar's
overflow width cap is now an adjustable slider; and monitor targeting for
both bar and dock already exists in Settings.** Wala tayong babawasan.

---

## 1. Dock: hybrid dynamic resize → arrows (fullwidth/floating)

The dock was hug-content with no width limit. Now, when constrained
(fullwidth/floating) and the apps would overflow:

1. **Icons shrink to fit** via a centered scale (never grown past 100%,
   so a few apps stay normal size and centered).
2. Once shrinking hits the **Minimum icon scale** floor and it STILL
   overflows, **chevron < > scroll arrows** appear and scroll the row.

Island mode is unchanged (hug-content, no constraint). The dock reads its
usable width from the parent window per monitor, so it's correct on each
screen and updates live when you switch fullwidth/floating or change the
dock height (icons re-fit dynamically).

New **Settings → Dock → Minimum icon scale** (55–100%): how small icons
may get before arrows appear. 100% = arrows immediately.

## 2. Taskbar width cap is adjustable

The horizontal taskbar's overflow cap (where < > arrows appear) was
hardcoded at 440px. It's now **Settings → Panel → Taskbar width cap**
(240–900px). Applies to the taskbar in both the bar and the dock.

## 3. Monitor targeting (already present)

Both already support per-monitor display — no change needed, just use:
- **Settings → Panel → Display Target** — bar on primary / all / a
  specific monitor (auto-detected from connected screens).
- **Settings → Dock → Show on monitor** — same for the dock.

Selections are auto-populated from live `Quickshell.screens`, so primary,
all, or any named output (e.g. DP-2) work out of the box.

## Version

- `ZenVersion.qml` bumped `hf95.30` → `hf95.31`.

## Files touched

- `zen-shell-v5/ZenDock.qml` — dynamic fit-scale + overflow arrows + viewport
- `zen-shell-v5/DockState.qml` — `minIconScale` + persistence
- `zen-shell-v5/PanelState.qml` — `taskbarMaxWidth` + persistence
- `zen-shell-v5/Taskbar.qml` — read configurable width cap
- `zen-shell-v5/DockPage.qml` — Minimum icon scale slider
- `zen-shell-v5/PanelPage.qml` — Taskbar width cap slider
- `zen-shell-v5/shell.qml` — pass availableWidth to the dock
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
