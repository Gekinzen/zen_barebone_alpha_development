# Zen Shell v6.16.3.4.2 — Material You power profile status pill (Battery & Power page)

**Release date:** 2026-04-23
**Branch:** `beta-v12.6.16.3.4.2`
**Base:** v6.16.3.4.1
**Status:** Beta — third pillar of the unified power-profile UX

---

## TL;DR

Compact Material You status pill at the top of **Settings → Battery
& Power**. Always visible, always shows current profile + GPU mode,
click to cycle, auto-syncs with the bar PowerBadge and the Control
Panel toggles. Notify fires automatically (already existing behavior
in `PowerProfileService`).

```
┌──────────────────────────────────────────────────────────────┐
│  🚀  Active profile · click to cycle    ⚡ Auto + Boost  ⌄  │
│      Performance                                              │
└──────────────────────────────────────────────────────────────┘
```

One file touched: `BatterySettingsPage.qml`. No new singletons, no new
files, no schema changes, no install.sh phases. Pure additive UI on
top of infrastructure that's existed since v6.16.0.

**Wala tayong binawasan.**

---

## What you asked for, mapped to what shipped

> "kapag may pinili ako dun matic dpat mag notify din"

✓ Click pill → `PowerProfileService.setProfile()` → notify-send fires
automatically (existing v6.16.0 behavior).

> "syncronized dapat ah kung anu yun settings"

✓ Free via QML singleton property bindings. `PowerProfileService` is
a Singleton; bar `PowerBadge`, ControlPanel pills, BatterySettingsPage
pill, and the existing dropdown ALL bind to `.currentProfile`. Change
anywhere → bound surfaces update instantly. No manual sync code.

> "kht mag restart akl applied padin ah"

✓ Already covered system-side. `setProfile()` writes to
`SettingsStateV2.powerProfile` → JSON-persisted. On reboot,
`~/.local/bin/zen-power-profile-restore.sh` (autostart.conf) reads
JSON and re-applies via `powerprofilesctl`. Three-layer safety:
QML state, JSON file, autostart restore.

> "kapag click nag sswitch din or hover pwd mamili switch"

✓ Left-click cycles profile (saver → balanced → performance → saver).
If Gaming Boost is currently active, clicking disables boost first.
Hover gives soft elevation + cursor pointer. Right-click was
considered for cycle-backwards but kept simple — left-click only.

> "google material ah elegant icons natin"

✓ MDI nf-md filled-style glyphs (same surrogate-pair vocabulary as
v6.16.3.1's PowerConfirmDialog):

| Profile      | MDI codepoint | Glyph |
|--------------|---------------|-------|
| Power Saver  | U+F032A `nf-md-leaf`             | 🌿 |
| Balanced     | U+F05D1 `nf-md-scale_balance`    | ⚖️ |
| Performance  | U+F14DE `nf-md-rocket_launch`    | 🚀 |
| Gaming Boost | U+F0EB5 `nf-md-gamepad_variant`  | 🎮 |
| Affordance   | U+F035D `nf-md-menu_down`        | ⌄  |

Round-tripped through Python codepoint math before commit.

---

## Material You design notes

The pill follows MD3 / Material You principles:

| Property            | Value                                          |
|---------------------|------------------------------------------------|
| Shape               | Capsule (radius 20, height 56)                 |
| Surface tint (rest) | Profile color @ 10% alpha                      |
| Surface tint hover  | Profile color @ 18% alpha                      |
| Outline             | Profile color @ 35% alpha, 1.5px               |
| Icon size           | 26px (large for visual weight)                 |
| Label hierarchy     | Caption (11px) + DemiBold title (17px)         |
| Transition easing   | OutQuad, 220ms                                 |
| Cursor              | PointingHandCursor on hover                    |
| Padding             | 20px horizontal                                |

The "active profile · click to cycle" caption text degrades to
"Boost active · click to disable" when boost is engaged — keeps
the affordance honest about what the click will do in current state.

The inline GPU-mode mini-badge (right side of pill, above the
chevron) only renders when `GPUSwitcherService.isMultiGpu === true`.
Single-GPU systems see a cleaner pill without it.

---

## Color matrix (matches PowerBadge bar widget for cross-surface unity)

| State                               | Border + accent | Theme token        |
|-------------------------------------|-----------------|--------------------|
| Power Saver                         | Green           | `ThemeService.green`  |
| Balanced                            | Blue            | `ThemeService.blue`   |
| Performance                         | Orange          | `ThemeService.orange` |
| Gaming Boost active (any profile)   | Red             | `ThemeService.red`    |
| powerprofilesctl missing            | Grey (disabled) | `ThemeService.grey1`  |

Theme switch (e.g. tokyo-night → catppuccin) auto-retints because all
five colors are bound to `ThemeService` which is rewritten on theme
load.

---

## "Disabled" state

When `powerprofilesctl` isn't installed, the active pill hides and a
greyed-out "Power profile management unavailable" pill takes its
place with an install hint. The page never shows a blank header —
there's always a status surface.

```
┌──────────────────────────────────────────────────────────────┐
│  ⚠  Power profile management unavailable                     │
│     Install power-profiles-daemon to enable                   │
└──────────────────────────────────────────────────────────────┘
```

---

## What this pill does NOT do (deliberately)

1. **Does not include a manual GPU mode switcher.** The pill SHOWS
   GPU mode but doesn't expose toggle there — that's still the job
   of the existing GPU section further down the page (and the
   ControlPanel GPU tab). Dropping a third toggle in the pill would
   bloat the surface.

2. **Does not expose Gaming Boost settings (animations etc).** Click
   either enables boost (default settings) or disables it. The full
   "boost configures animations + blur + dim" controls live in
   ControlPanel as before.

3. **Does not have a long-press menu.** Considered radial menu / hover
   dropdown like the bar PowerBadge popup, but for a settings page
   that already has the full Profile + Boost UI 100px below, it'd be
   redundant. Left click cycles, that's it.

---

## Files in this drop

### UPDATED

```
zen-shell-v5/BatterySettingsPage.qml   ← +Material You pill (additive header insertion)
install.sh                              ← version banner bump
CHANGELOG-v6.16.3.4.2.md                ← this file (NEW)
```

### CARRIED OVER

Everything from v6.16.3.4.1 (including the inotify-reload re-push fix
in MouseSettingsService that addressed your gap regression). Every
v6.16.3.X feature carried byte-identical.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.4.2.tar.gz
cd zen-shell-v6.16.3.4.2
./install.sh
~/.local/bin/zs-restart.sh
```

Then:

1. Open Settings → Battery & Power
2. **Look at top of page** — should see colored Material You pill
   showing your current profile (e.g. "Balanced" with blue accent,
   ⚖️ icon)
3. Left-click the pill — profile cycles to Performance (orange, 🚀)
4. Notification toast should appear from swaync
5. Look at bar PowerBadge (if you've opted in) — should match
6. Open ControlPanel — Power Profile section pill should also match
7. Toggle Gaming Boost from anywhere — pill goes red, label changes
   to "Gaming Boost", caption changes to "click to disable"
8. Reboot — profile persists (via `zen-power-profile-restore.sh`)

---

## Sync verification matrix

After clicking ANY of these surfaces, ALL others should update
within 220ms (the binding-propagation + animation duration):

| Click here                                      | Updates these                                         |
|-------------------------------------------------|-------------------------------------------------------|
| BatterySettingsPage pill (this 3.4.2)           | Bar PowerBadge, ControlPanel pills, the dropdown      |
| ControlPanel profile pill                       | Bar PowerBadge, BatterySettingsPage pill, dropdown    |
| Bar PowerBadge right-click cycle                | ControlPanel pills, BatterySettingsPage pill, dropdown|
| BatterySettingsPage dropdown (existing)         | Bar PowerBadge, ControlPanel pills, this pill         |
| `powerprofilesctl set <profile>` from terminal  | All of the above (via PowerProfileService.refresh)    |

---

## What's NOT in v6.16.3.4.2

- **PowerBadge bar opt-in diagnosis** — your v6.16.3.4 PowerBadge
  isn't visible in the bar despite Theme.qml + PowerBadge.qml being
  deployed. Separate scope, separate fix. Will track as a follow-up
  once we confirm 3.4.2 lands clean.
- **Global Hyprland reload listener** (the foundational fix
  superseding 3.4.1's MouseSettingsService spot-fix) — still
  deferred to v6.16.4.
- **v6.16.3.5 (Start Menu logo picker)** — still paused until you
  confirm 3.4.1 + 3.4.2 hold.

---

## Next up

- Diagnose why bar PowerBadge isn't rendering despite files being deployed
- v6.16.3.5 — Start Menu logo image picker
- v6.16.3.6 — Clock hover popup parity with CPU/Memory hover
- v6.16.3.7 — Universal widget auto-resize (DPI / scale aware)
- v6.16.4 — Global Hyprland configreloaded IPC listener
