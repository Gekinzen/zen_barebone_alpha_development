# Zen Shell v6.16.3.4 — Bar profile + GPU badge widget

**Release date:** 2026-04-22
**Branch:** `beta-v12.6.16.3.4`
**Base:** v6.16.3.3
**Status:** Beta — fourth feature drop of the v6.16.3.X series

---

## TL;DR

New bar module: `PowerBadge`. Tiny pill in the bar showing your current
power profile and GPU mode at a glance, with hover popup for details
and middle/right-click power user shortcuts.

```
   ┌──────────────┐
   │  ⚡  🎮       │   ← profile glyph (left), gpu glyph (right)
   └──────────────┘
       ↓ hover ↓
   ┌─────────────────────────────────────────────┐
   │  ⚡  Profile: Performance                    │
   │  🎮  GPU: Auto + Gaming Boost                │
   │  L-click: open · R-click: cycle · M: boost  │
   └─────────────────────────────────────────────┘
```

Self-hides on systems where it'd be useless (single-GPU desktop with
no powerprofilesctl). Wala tayong binawasan — every existing bar
module untouched, additive registration in `Bar.qml`, additive helper
script for users on customized layouts.

---

## What it does

A single bar module that surfaces two pieces of system state that
were previously only visible by drilling into Control Panel:

1. **Current power profile** — saver / balanced / performance, color-
   coded (green / blue / orange respectively). Sourced from the
   existing `PowerProfileService` singleton.
2. **Current GPU mode** — auto / integrated / dedicated / auto-gaming.
   Sourced from `GPUSwitcherService`. Only visible on multi-GPU
   systems (`isMultiGpu === true`).

If Gaming Boost is active OR GPU mode is `auto-gaming`, the badge
turns red regardless of profile color. Visual high-alert.

### Click semantics

| Click           | Action                                               |
|-----------------|------------------------------------------------------|
| **Left**        | Open Control Panel (full toggle UI)                  |
| **Right**       | Cycle power profile (saver → balanced → performance) |
| **Middle**      | Toggle Gaming Boost                                  |

The right-click cycle is genuinely useful on laptops — quick "go fast"
or "go quiet" without opening any panel. Middle-click boost is the
"presentation mode" / "render this video NOW" shortcut.

### Hover popup

After 300ms of hover, a Wayland layer-shell popup appears beneath the
badge showing full state and the click-shortcut reference. Hides on
mouse-exit with a 200ms grace window so micro-jitters don't flicker
it. Mouse can move FROM the badge INTO the popup without dismissing
(both surfaces share the hover state — same pattern used by the
SysRow hover memory popups in v6.15).

### Self-hiding

The badge collapses to width-0 (and `visible: false`) when:

- `PowerProfileService.available === false` AND
- `GPUSwitcherService.isMultiGpu === false`

So a single-GPU desktop without `power-profiles-daemon` installed
won't see anything in the bar. No wasted space.

If only ONE of those conditions is met, only that half renders:

- `power-profiles-daemon` installed but single GPU → just the profile glyph
- Multi-GPU but no PPD → just the GPU glyph

Width auto-resizes via QML `Behavior on width` so the transition is
smooth.

### Theme integration

Border color follows the active accent (recap):

| State                               | Border color | Theme token   |
|-------------------------------------|--------------|---------------|
| Power Saver                         | Green        | `Theme.green` |
| Balanced                            | Blue         | `Theme.blue`  |
| Performance                         | Orange       | `Theme.orange`|
| Gaming Boost active (any profile)   | Red          | `Theme.red`   |
| GPU mode = auto-gaming              | Red          | `Theme.red`   |

Background = `Theme.alpha(Theme.bg0, 0.9)` (matches the existing
NotificationIcon pill background pattern). Radius follows
`Theme.styleMode === "round" ? height/2 : moduleRadius` — picks up
your round/pill toggle automatically.

---

## Why it's defensive

Two services this badge depends on are conditional:

1. `PowerProfileService` requires `powerprofilesctl` (on CachyOS,
   that's `power-profiles-daemon`). Not always installed.
2. `GPUSwitcherService.isMultiGpu` is true only on systems with 2+
   detected GPUs. On a desktop with one RX 6800 XT, `isMultiGpu` is
   false.

So the badge has to gracefully handle:

- Both available → render full badge (both glyphs)
- Only profile available → render half (profile glyph only)
- Only GPU available → render half (GPU glyph only)
- Neither available → render nothing (width 0, visible false)

All four cases tested via the singleton's `available` / `isMultiGpu`
properties — no exception paths, no `try/catch`, just bound visibility
chains. If a service initializes late, `Behavior on width` smooths
the popup-in.

---

## Module registration

Three layers, designed so existing users aren't disrupted:

### Layer 1: `Bar.qml` factory + switch case

Added a new Component:

```qml
// v6.16.3.4: Power profile + GPU mode badge.
Component { id: cPowerBadge;  PowerBadge {} }
```

And a new switch case:

```qml
case "powerbadge":    return cPowerBadge
```

Existing modules (start, taskbar, workspaces, window, music, sysrow,
tray, notifications, clock, weather, sysmonitor, battery) are
**byte-identical** to v6.16.3.3. Only ADDED the new entry.

### Layer 2: `Theme.qml` default layout

Default `barLayout.right` array now includes `"powerbadge"`:

```diff
- "right": ["music", "sysrow", "tray", "battery", "notifications", "clock"]
+ "right": ["music", "sysrow", "tray", "battery", "powerbadge", "notifications", "clock"]
```

Position: between battery and notifications. This means **fresh
installs see the badge immediately** without any user action.

**Existing users with a saved `bar-layout.json`:** that file overrides
the Theme.qml default (additive policy preserves your customizations
across upgrades). So upgrading from v6.16.3.3 won't auto-add the
badge to your bar — you have to opt in. See Layer 3.

### Layer 3: Opt-in helper for existing users

`~/.local/bin/zen-bar-add-powerbadge.sh` is a tiny idempotent script
that:

1. Locates your `bar-layout.json` (checks all 4 known paths)
2. Validates JSON
3. Inserts `"powerbadge"` into the right row, just before
   `"notifications"`. Falls back to appending if `"notifications"`
   isn't there.
4. Backs up the original to `.bak.<timestamp>` first

```bash
~/.local/bin/zen-bar-add-powerbadge.sh             # add
~/.local/bin/zen-bar-add-powerbadge.sh --dry-run   # preview
~/.local/bin/zen-bar-add-powerbadge.sh --remove    # take it back out
~/.local/bin/zen-bar-add-powerbadge.sh --help
```

After running, `~/.local/bin/zs-restart.sh` to reload the shell.

---

## Files in this drop

### NEW

```
zen-shell-v5/PowerBadge.qml                   ← the new bar module
scripts/zen-bar-add-powerbadge.sh             ← opt-in layout helper
CHANGELOG-v6.16.3.4.md                        ← this file
```

### UPDATED

```
zen-shell-v5/Bar.qml                          ← +Component + switch case
zen-shell-v5/Theme.qml                        ← +powerbadge in default layout
install.sh                                    ← +zen-bar-add-powerbadge.sh, version bump
```

### CARRIED OVER FROM v6.16.3.1 / v6.16.3.2 / v6.16.3.2.1 / v6.16.3.3

(everything from prior changelogs — unchanged)

---

## Install / update

### Standard

```bash
tar -xzf zen-shell-v6.16.3.4.tar.gz
cd zen-shell-v6.16.3.4
./install.sh
```

The `install.sh` from v6.16.3.3 already handles the v6.16.3 stack
phases. v6.16.3.4 just adds:
- One new QML file (PowerBadge.qml) — copied by [4/9]
- One new script (zen-bar-add-powerbadge.sh) — copied by [5/9]
- Updates to Bar.qml and Theme.qml — copied by [4/9]

After install, restart the shell:

```bash
~/.local/bin/zs-restart.sh
```

### Opt-in for existing customized bars

If you have a saved `bar-layout.json` (most users on v6.16.x do —
it's auto-saved when you change the bar style), the upgrade won't
auto-add the badge. Run:

```bash
~/.local/bin/zen-bar-add-powerbadge.sh
~/.local/bin/zs-restart.sh
```

Or `--dry-run` first to preview.

---

## Verification

| # | Test                                      | Expected                              |
|---|-------------------------------------------|---------------------------------------|
| 1 | Fresh install with PPD installed          | Badge visible in bar (between batt & notif) |
| 2 | Single-GPU desktop, no PPD                | Badge invisible (width 0)             |
| 3 | Hover badge for 300ms                     | Popup appears below                   |
| 4 | Mouse from badge into popup               | Popup stays open                      |
| 5 | Mouse out of both                         | Popup hides after 200ms               |
| 6 | Right-click badge                         | Profile cycles to next                |
| 7 | Profile change reflected in border color  | Color animates (220ms)                |
| 8 | Middle-click badge                        | Gaming Boost toggles                  |
| 9 | Gaming Boost on → border red              | Yes                                   |
| 10 | Multi-GPU laptop, GPU mode = auto-gaming | Border red even without boost         |
| 11 | Existing bar-layout.json + opt-in script | Badge inserted before notifications   |
| 12 | Theme switch (tokyo-night → catppuccin)  | Badge accent retints (uses Theme.*)   |

---

## What's NOT in v6.16.3.4

- **A settings UI for the click bindings.** Hardcoded for now. If
  you want different click semantics, edit `PowerBadge.qml`'s
  `MouseArea.onClicked`. A future v6.16.3.X may surface this in
  Settings → Bar Modules if there's demand.
- **Animated profile transitions in the badge body.** Border color
  animates (`Behavior on color`); the glyph itself snap-changes.
  Crossfading the glyph would mean two stacked Text items + opacity
  animation per transition — looked janky in early prototype.
- **Battery percentage integration.** That's the existing Battery
  module's job. Keeping concerns separate so users can mix and match.
- **Tap-to-cycle on touch.** Right-click on touch is a long-press
  on most Wayland setups; that should "just work" via the existing
  Qt touch event translation, but isn't tested. File if broken.

---

## Next up in the v6.16.3.X series

- **v6.16.3.5** — Start Menu logo image picker
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
