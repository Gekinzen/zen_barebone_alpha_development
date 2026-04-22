# Zen Shell v6.16.3.3 — install.sh merge + DisplaysPage resolution fix

**Release date:** 2026-04-22
**Branch:** `beta-v12.6.16.3.3`
**Base:** v6.16.3.2.1
**Status:** Beta — third feature drop of the v6.16.3.X series

---

## TL;DR

Two things in one drop because Paul asked for them together:

1. **Standalone overlay installer merged into `install.sh`.** One
   install command for everything, idempotent on re-run. The old
   `install-v6.16.3.2.1-overlay.sh` is gone; a tiny shim named
   `install-v6.16.3-overlay.sh` stays so muscle memory / old docs
   still work — it just forwards to `./install.sh`.
2. **DisplaysPage resolution dropdown enumeration fix** — the actual
   v6.16.3.3 scheduled feature. The regex that parsed Hyprland's
   `availableModes` array was too strict and silently dropped any
   mode without an `@<rate>` suffix. Also fixed the companion
   refresh-rate dropdown and added "always include current mode"
   guards so you never see an empty dropdown.

Cumulative — `./install.sh` applies v6.16.3.1 + v6.16.3.2 +
v6.16.3.2.1 + v6.16.3.3 all at once.

**Wala tayong binawasan.**

---

## #1 — `install.sh` merge

### What changed

Running `./install-v6.16.3.2.1-overlay.sh` has been deleted. Now:

```bash
./install.sh
```

does everything. The overlay phases from v6.16.3.2.1 are now a
new block inside `install.sh`, inserted just before the final
shell launch:

```
  ── v6.16.3 stack (smart lid + wake recovery + lock redesign) ──
    Phase A: hyprlock + hypridle dep check/install
    Phase B: hypridle.conf + hyprlock.conf → ~/.config/hypr/
    Phase C: lid-behavior.conf + autostart.conf → ~/.config/hypr/modules/
    Phase D: lock-wallpaper symlink seed
    Phase E: systemd-sleep hook (optional, sudo)
    Phase F: hypridle restart
  ── v6.16.3 stack applied ──
```

All phases are idempotent — they detect existing state and only
do work when needed. Re-running `./install.sh` is cheap.

The scripts loop was also extended to include:

```diff
  zen-volume-notify.sh zen-power-profile-restore.sh zen-lid-handler.sh \
+ zen-resume-handler.sh zen-lock.sh \
  zen-game-watcher.sh prime-run
```

### Why this was better as a merge

Three reasons this ended up being the right call:

1. **Single source of truth.** The overlay duplicated install.sh's
   hypridle.conf / hyprlock.conf / bin-copy logic. Duplication means
   drift.
2. **Fresh installs were broken.** Anyone running `./install.sh`
   without knowing about the overlay got the v6.16.3.1 Material
   icons but missed everything else (smart lid, wake recovery,
   redesigned lock). Now they can't miss it.
3. **Re-runs are reliable.** The overlay was idempotent by design,
   but nested inside `./install.sh` it also benefits from the
   parent script's kill/spawn logic so there's no race with a
   half-killed zen-shell surviving between overlay and main launch.

### The shim

`install-v6.16.3-overlay.sh` is now a 20-line shim that just runs
`exec ./install.sh "$@"`. Keeps old docs / muscle memory working.

### install.sh version banner

Bumped from v6.16.2.3.7 → v6.16.3.3 at the "Done." footer, so
`./install.sh` tail output makes it clear what you're running.

---

## #2 — DisplaysPage resolution dropdown enumeration fix

### What you reported

> "Display resolution dropdown enumeration fix — the resolution
>  dropdown in `DisplaysPage` is missing some valid modes the
>  monitor actually supports"

(Originally queued for v6.16.3.3 in the roadmap. Landing now.)

### Root cause

The resolution combobox was mining modes from Hyprland's
`.availableModes` array using this regex:

```javascript
m.match(/(\d+)x(\d+)@/)
```

The trailing `@` meant only modes with an explicit refresh-rate
suffix got picked up. But Hyprland emits `availableModes` in several
formats depending on kernel, driver, and monitor EDID quality:

| Format observed                | Old regex | New regex |
|--------------------------------|-----------|-----------|
| `"1920x1080@60.000Hz"`         | ✓ match   | ✓ match   |
| `"1920x1080@60.00000"`         | ✓ match   | ✓ match   |
| `"1920x1080@60Hz"`             | ✓ match   | ✓ match   |
| `"2560x1440@144.00Hz"`         | ✓ match   | ✓ match   |
| `"1920x1080"` (no refresh)     | ✗ DROPPED | ✓ match   |
| `"3840x2160@29.981Hz"`         | ✓ match   | ✓ match   |

That last bare-resolution case happens when:
- Custom `monitor =` override in hyprland.conf supplies the mode
- Driver reports a mode via DRM but without timing metadata
- Synthetic "generic" modes injected by the compositor

Any such mode was silently missing from the dropdown even though
the monitor supported it.

### The refresh-rate combobox had the same class of bug

Companion regex:

```javascript
new RegExp(rp[0]+"x"+rp[1]+"@([\\d.]+)")
```

Required `@<number>` to match. Worse: if no matches → returned
`[{hz:60,label:"60 Hz"}]` as fallback, which HID the monitor's
actual current refresh rate whenever it happened to be something
other than 60 (common on 144Hz / 165Hz gaming panels or 90Hz laptop
displays).

### The fix

**New resolution regex:** `/^(\d+)x(\d+)/`

- Anchored at start (so it doesn't get confused by prefixes)
- Only captures width × height, doesn't care what comes after
- Matches every format observed across every driver

**New refresh-rate regex:** `/@\s*([\d.]+)/`

- Optional whitespace after @ (defensive)
- If no @ present, default to 60 Hz as sensible fallback

**Two new "always include current" guards:**

1. Resolution dropdown always includes `modelData.width × modelData.height`
   even if it's not in `availableModes` (some custom / user-forced
   modes don't appear in the enum). Prevents empty current-index.

2. Refresh-rate dropdown always includes `modelData.refreshRate` when
   the currently-selected WxH matches the monitor's active mode.
   Prevents that "dropdown says 60 Hz but monitor is running 144 Hz"
   gaslight.

**Sort order improved:**

- Resolutions now sort descending by total pixel count (native → lowest)
- Refresh rates stay descending by Hz (highest → lowest)

### Deduplication improved

Refresh rates are deduped by ROUNDED Hz. Previously if a display
reported both "59.934" and "60.000" as available rates, both showed
up as "60 Hz" in the dropdown (duplicate entry confusion). Now they
collapse to one.

### Files touched

```
zen-shell-v5/DisplaysPage.qml   modified (2 comboboxes, ~60 lines changed)
```

No public API changes — still takes `modelData` from the same
`hyprctl monitors all -j` feed. The HMRow structure, ComboBox ids,
and apply button logic are all unchanged.

### Verify on your rig

Paul's setup hits multiple paths:

1. **Desktop 1440p panel** — should show every standard 1440p rate
   (60, 75, 120, 144, 165) IF the monitor reports them. Previously
   some were missing.
2. **X270 internal eDP-1** — 1920×1080 panel, 60Hz. If Hyprland
   reports a bare `"1920x1080"` entry (observed on some firmware),
   now visible.
3. **Docked externals** — hotplugged modes sometimes arrive with
   stripped metadata; those show up now too.

Open Settings → Displays → expand a monitor card → click
Resolution. The dropdown should match what `hyprctl monitors all`
reports in `.availableModes` (modulo dedup).

---

## Files in this drop

### NEW

```
install-v6.16.3-overlay.sh      ← shim that forwards to install.sh
CHANGELOG-v6.16.3.3.md          ← this file
```

### DELETED

```
install-v6.16.3.2.1-overlay.sh  ← merged into install.sh, deleted
```

### UPDATED

```
install.sh                       ← +v6.16.3 stack phase, +2 scripts, version bump
zen-shell-v5/DisplaysPage.qml    ← resolution + refresh rate enumeration fix
```

### CARRIED OVER FROM v6.16.3.1 / v6.16.3.2 / v6.16.3.2.1

```
zen-shell-v5/PowerConfirmDialog.qml   ← v6.16.3.1 MDI icons
zen-shell-v5/SettingsState.qml        ← v6.16.3.2.1 gap regression fix
hypr-config/lid-behavior.conf         ← v6.16.3.2 smart lid + manual recovery
hypr-config/autostart.conf            ← v6.16.3.2 +hypridle
hypr-config/hypridle.conf             ← v6.16.3.2.1 zen-lock.sh wrapper
hypr-config/hyprlock.conf             ← v6.16.3.2.1 vaxry redesign
hypr-config/zen-sleep-hook.sh         ← v6.16.3.2 systemd-sleep hook
scripts/zen-lid-handler.sh            ← v6.16.3.2 smart mode
scripts/zen-resume-handler.sh         ← v6.16.3.2 wake recovery
scripts/zen-lock.sh                   ← v6.16.3.2.1 live wallpaper sync
CHANGELOG-v6.16.3.1.md
CHANGELOG-v6.16.3.2.md
CHANGELOG-v6.16.3.2.1.md
```

---

## Install / update

### Standard

```bash
tar -xzf zen-shell-v6.16.3.3.tar.gz
cd zen-shell-v6.16.3.3
./install.sh
```

That's it. One command. Idempotent. Covers fresh installs AND
upgrades from any v6.16.x. The v6.16.3 stack phase near the end
will ask at most two prompts:

1. "Install hyprlock + hypridle?" — if missing
2. "Install systemd-sleep hook?" — if not already installed

### Old overlay command still works

If you have muscle memory / docs that say "run the overlay", the
shim keeps that working:

```bash
./install-v6.16.3-overlay.sh
```

It exec-forwards to `./install.sh` unchanged.

---

## Verification checklist

After `./install.sh`:

| # | Test                                         | Expected                           |
|---|----------------------------------------------|------------------------------------|
| 1 | Settings → Displays → expand monitor         | All available modes visible        |
| 2 | Resolution dropdown                          | Native res at top, no duplicates   |
| 3 | Refresh dropdown                             | Current rate matches live monitor  |
| 4 | Resolution only in `hyprctl monitors all`    | STILL shows up (no regression)     |
| 5 | Gap-wipe test (from v6.16.3.2.1)             | Gaps persist after mouse drag      |
| 6 | Lock screen (from v6.16.3.2.1)               | Live wallpaper + vaxry look        |
| 7 | Lid close on AC, no external                 | Lock + DPMS off (no suspend)       |
| 8 | Lid open                                     | Full UI restores                   |
| 9 | Power confirm dialog icons                   | Material Design glyphs             |
| 10 | `install-v6.16.3-overlay.sh` run directly   | Exec-forwards to install.sh        |

---

## What's NOT in v6.16.3.3

- **Per-monitor saved overrides for mode/refresh.** Applying a mode
  still goes through the existing `applyMonitor()` path which writes
  to `hyprland-monitors.conf`. No new persistence logic. The
  enumeration fix just makes the dropdowns show the right options.
- **Actual mode-switching logic changes.** If clicking Apply after
  picking a new mode doesn't stick, that's a separate bug (likely
  in `applyMonitor()`) — file it and we'll scope v6.16.3.3.1.

---

## Next up in the v6.16.3.X series

- **v6.16.3.4** — Bar profile/GPU badge widget
- **v6.16.3.5** — Start Menu logo image picker
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
