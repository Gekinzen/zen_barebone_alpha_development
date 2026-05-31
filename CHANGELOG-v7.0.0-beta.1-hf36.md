# v7.0.0-beta.1-hf36 — Refresh rate downgrade toggle (manual 60Hz mode)

**Channel:** beta (hotfix)
**Released:** 2026-05-16
**Branch:** `dev`

---

## What this hotfix adds

User request:

> "make it sure kung anu yun settings ko dito 144hz pero kapag naka
> laptop and lalo na ito for battery life span 60hz pero dapat
> prompt natin sa notification na current settings naka 60hz pero
> if balance niya and high performance or gaming kung nau yun
> settings sa monitor gets?"

After discussion, the chosen design:
1. **Manual toggle** in Battery & Power (no auto-switch on profile
   or battery state — user controls when to flip it)
2. **All monitors** affected (including external like DP-2 Xiaomi
   3440×1440 @ 144Hz)
3. **Toast notification** on every transition via the native zen-shell
   toast pipeline

Pure addition. No reverts, no breaking changes.

---

## #1 — New `RefreshRateService.qml` singleton

A new service that manages the 60Hz downgrade lifecycle.

### Architecture

```
User toggles ON
   ↓
RefreshRateService.setDowngrade(true)
   ↓
_snapshotAndApply()
   ↓
hyprctl monitors -j  → JSON list
   ↓
For each enabled monitor with rate > 60Hz:
   - record originalHz → savedRates[name]
   - build "name,WxH@60.00,pos,scale" command
   ↓
hyprctl --batch "keyword monitor cmd1;keyword monitor cmd2;..."
   ↓
NotificationService.postInternal(
  "Display · 60Hz mode ON",
  "DP-2 144Hz → 60Hz\neDP-1 165Hz → 60Hz\nSaves battery life on laptops.",
  ...)
   ↓
Persist {downgrade60Hz: true, savedRates: {...}} to JSON
```

```
User toggles OFF
   ↓
RefreshRateService.setDowngrade(false)
   ↓
_queryAndRestore()
   ↓
hyprctl monitors -j  → JSON list
   ↓
For each monitor with a saved rate:
   - build "name,WxH@<savedHz>.00,pos,scale" command
   ↓
hyprctl --batch "..."
   ↓
NotificationService.postInternal(
  "Display · Native refresh rate restored",
  "DP-2 → 144Hz\neDP-1 → 165Hz",
  ...)
   ↓
Clear savedRates, persist {downgrade60Hz: false, savedRates: {}}
```

### Key design choices

1. **Snapshots per-monitor, not per-rate.** Each monitor's original
   refresh rate is stored individually so the restore path
   precisely returns each monitor to where it was. Works correctly
   even when monitors have different native rates (eDP-1 at 165Hz
   + DP-2 at 144Hz — both restore to their respective values).

2. **Doesn't touch `hyprland-monitors.conf`.** DisplaysPage owns
   that file as the source of truth for "user's preferred config."
   We only apply changes live via `hyprctl`. This way:
   - User's DisplaysPage choices remain authoritative across logouts
   - Toggle-off cleanly restores those preferences
   - If user changes a monitor in DisplaysPage while toggle is on,
     the new rate becomes the new preferred (next toggle-off
     restores to the rate snapshotted at toggle-on, NOT the new
     DisplaysPage choice — this is intentional, see below)

3. **Persistence across restarts.** State stored at
   `~/.config/quickshell/zen-shell/refresh-rate.json`:
   ```json
   {
     "downgrade60Hz": true,
     "savedRates": { "eDP-1": 165, "DP-2": 144 },
     "targetRateHz": 60
   }
   ```
   On shell startup with `downgrade60Hz: true`, the service waits
   1.5s for Hyprland to settle, then re-snapshots current rates
   (which come from hyprland-monitors.conf = user's preferred) and
   re-applies 60Hz. The toggle is sticky.

4. **No auto-switching.** Per user preference — they don't want
   surprises. The service does NOT hook into PowerProfileService
   or LaptopModeService events. Only the manual toggle (or the
   re-apply button) triggers state changes.

5. **Atomic batch apply.** Uses `hyprctl --batch
   "keyword monitor cmd1;keyword monitor cmd2;..."` so all
   monitors switch in a single Hyprland transaction. Avoids the
   visual glitch of monitors flipping one-by-one.

6. **Skips already-60Hz monitors.** If a monitor is already at
   60Hz (or within 0.5Hz tolerance for EDIDs like 59.934), no
   hyprctl command is sent for it. The snapshot still records its
   rate so we can verify state on toggle-off.

7. **No race with DisplaysPage.** The `_applying` flag guards
   against re-entry during the apply/restore cycle. Released
   500ms after the batch dispatches, giving downstream listeners
   time to re-read monitor state.

---

## #2 — UI integration in `BatterySettingsPage.qml`

New section inserted between "GPU Switcher" and "Smart Gaming
Detection". Three rows:

### Row 1 — The toggle

```
┌─────────────────────────────────────────────────────────────┐
│ 🖥️  Reduce refresh rate to 60Hz                      [○──]  │
│     Off — monitors at their preferred refresh rate.         │
│     Toggle ON to drop everything to 60Hz.                   │
└─────────────────────────────────────────────────────────────┘
```

When ON:
```
┌─────────────────────────────────────────────────────────────┐
│ 🖥️  Reduce refresh rate to 60Hz                      [──●]  │
│     Active — DP-2 (was 144Hz), eDP-1 (was 165Hz)            │
└─────────────────────────────────────────────────────────────┘
```

The description dynamically shows what's currently downgraded,
including the original rates. Helps user see at a glance what
they'll restore when they toggle off.

### Row 2 — Re-apply button (only visible when toggle is ON)

```
┌─────────────────────────────────────────────────────────────┐
│ 🔄  Re-apply to current monitors                  [Re-apply]│
│     Includes monitors plugged in after the toggle was       │
│     enabled. Re-snapshots current rates as the new restore  │
│     point.                                                  │
└─────────────────────────────────────────────────────────────┘
```

This handles the edge case: user has toggle on, then plugs in an
external monitor. The new monitor wasn't in the snapshot, so it
stays at its native rate. Click "Re-apply" → re-snapshots ALL
current monitors (including the new one) and applies 60Hz across
the board.

### Row 3 — Status indicator

```
┌─────────────────────────────────────────────────────────────┐
│ ℹ️  Status                                               ●  │
│     60Hz mode active. Toggle off to restore native rates.   │
└─────────────────────────────────────────────────────────────┘
```

Mirrors the pattern used by Smart Gaming Detection's status row —
green dot when active, grey dot when inactive. Pure cosmetic
confirmation.

---

## #3 — Toast notification samples

### Toggle ON

> **Display · 60Hz mode ON**
> DP-2 144Hz → 60Hz
> eDP-1 165Hz → 60Hz
> Saves battery life on laptops.

### Toggle OFF

> **Display · Native refresh rate restored**
> DP-2 → 144Hz
> eDP-1 → 165Hz

### Toggle ON when all monitors already 60Hz (e.g. desktop)

> **Display**
> All monitors already at 60Hz

### Toggle OFF when nothing was changed

> **Display**
> Already at native refresh rate

All routed through `NotificationService.postInternal()` (the
in-shell pipeline added in hf32). Consistent with the
PowerProfileService toast style.

---

## Behavior matrix

| Scenario | What happens |
|---|---|
| Fresh install, toggle never touched | Monitors at native rates. No effect. |
| Toggle ON for first time | Snapshot rates, apply 60Hz, toast lists changes. |
| Toggle OFF | Restore from snapshot, clear snapshot, toast. |
| Reboot with toggle ON | 1.5s after shell start, snapshot current (native) rates, apply 60Hz, toast. |
| Reboot with toggle OFF | Nothing happens. |
| Change monitor in DisplaysPage while toggle ON | New rate persists; doesn't fight DisplaysPage. Next toggle-off restores to the snapshotted rate (not the new DisplaysPage choice). |
| Plug in new monitor while toggle ON | New monitor stays at native rate. Click "Re-apply" to include it. |
| Power profile changes (Balanced→Performance→Gaming Boost) | No effect on refresh rate. Toggle is independent. |
| Battery state changes (AC plug/unplug) | No effect. Toggle is manual-only. |

---

## Why "manual only" instead of auto

User explicitly chose manual:

> "Manual toggle lang — may setting sa Battery & Power, walang
> auto-switch"

Reasons this is the right call:

1. **Predictability.** Users hate surprises where settings change on
   their own. If user pinned 144Hz in DisplaysPage, they want 144Hz.
2. **Composability with PowerProfile.** Some users run Performance
   on battery for short tasks but still want 60Hz to extend runtime.
   Some run Balanced on AC but still want 144Hz. Decoupling these
   axes gives more flexibility.
3. **External monitors.** Auto-downgrade based on battery state
   would also drop external monitors (which are AC-powered and don't
   benefit from being on a laptop's battery). Manual lets user
   choose.
4. **Easier to debug.** If something goes wrong, "you toggled it"
   is a clear cause.

Future hotfix could add an optional "auto-switch when on battery"
sub-toggle as a power-user option — but the default stays manual.

---

## Files changed (5)

```
zen-shell-v5/RefreshRateService.qml  — NEW singleton, ~315 lines
zen-shell-v5/BatterySettingsPage.qml — NEW section (3 HMRows) between
                                       GPU Switcher and Smart Gaming
                                       Detection, ~80 added lines
zen-shell-v5/shell.qml               — Touch RefreshRateService in
                                       Component.onCompleted so its
                                       FileView loads + reapplies if
                                       persisted state is on
zen-shell-v5/ZenVersion.qml          — Bumped to hf36
install.sh                            — Banner + changelog entry
```

No existing functionality modified. Wala tayong babawasan.

---

## State file

`~/.config/quickshell/zen-shell/refresh-rate.json`

Schema:
```json
{
  "downgrade60Hz": true,
  "savedRates": {
    "eDP-1": 165,
    "DP-2": 144.012
  },
  "targetRateHz": 60
}
```

- `downgrade60Hz` — current toggle state, sticky across restarts
- `savedRates` — original refresh rates captured at the moment we
  applied the downgrade, used for restoration. Empty when toggle is
  off. Float precision preserved (Hyprland reports 59.934 etc. for
  some EDIDs).
- `targetRateHz` — target rate when downgrading. Default 60. Kept as
  a property in case a future hotfix wants a "30Hz endurance" sub-mode.

To reset manually:
```bash
rm ~/.config/quickshell/zen-shell/refresh-rate.json
# Restart shell or just toggle off then on in Settings
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf36-refresh-rate-toggle.tgz
cd zen-shell-v7.0.0-beta.1-hf36
./install.sh
```

State files all forward-compatible. No migration.

---

## How to verify

1. Open Settings → Battery & Power → scroll to "Refresh Rate"
   section (between "GPU Switcher" and "Smart Gaming Detection")
2. Toggle "Reduce refresh rate to 60Hz" → ON
3. Watch:
   - DP-2 (Xiaomi 3440×1440) drops from 144Hz to 60Hz
   - Any other monitors above 60Hz drop to 60Hz too
   - Toast appears upper-right: "Display · 60Hz mode ON" with
     the list of affected monitors
   - Status dot turns green
   - Description updates to "Active — DP-2 (was 144Hz)..."
4. Toggle OFF → monitors return to original rates, toast confirms
5. Verify via `hyprctl monitors | grep refresh`
6. Toggle ON again, then reboot the shell:
   ```bash
   qs ipc call zen reload
   # or: kill quickshell, it'll respawn
   ```
   After 1.5s the downgrade re-applies automatically. Toast confirms.

---

## Wala tayong babawasan

All hf32, hf33-safe-subset, hf34, and hf35 fixes preserved. hf36 is
purely additive — new service + new UI section + version bump.
Nothing removed or restructured. 🍃
