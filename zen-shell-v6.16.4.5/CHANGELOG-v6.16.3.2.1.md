# Zen Shell v6.16.3.2.1 — Hotfix: gap regression + hyprlock dep + redesign

**Release date:** 2026-04-22
**Branch:** `beta-v12.6.16.3.2.1`
**Base:** v6.16.3.2
**Status:** Beta — hotfix between v6.16.3.2 and v6.16.3.3

---

## TL;DR

Three things landed in one drop because they all came up together
when Paul deployed v6.16.3.2 to the X270:

1. **Gap-wipe regression fixed** — changing mouse sensitivity (or
   any other action that re-instantiated SettingsState) was silently
   resetting your custom Gaps In/Out to defaults. Root cause: V1
   `SettingsState.qml` never received the v6.15.6 `readFromHyprland`
   guard that was applied to V2. Ported it now.
2. **hyprlock + hypridle now installable** — `install-v6.16.3.2.1-
   overlay.sh` Phase 2 auto-installs them via paru/yay/pacman with
   `--needed`. Also added to main `install.sh`'s recommended-deps
   section so future fresh installs get them.
3. **Hyprlock redesigned vaxry-style** — live desktop wallpaper as
   background (not screenshot), big centered Google-style clock,
   dynamic greeting line under it ("Good evening, paul 🌙" / "Good
   rainy morning, paul 🌧️"), pill-shaped password input.

Cumulative overlay — running `install-v6.16.3.2.1-overlay.sh` applies
v6.16.3.1 + v6.16.3.2 + v6.16.3.2.1 in one shot. Re-run any time.

---

## #1 — Gap-wipe regression (the actual root cause)

### What you saw

> "may napansin pala ako sa mouse sensitivity kapag nag change ako ng
>  values nawawla yun current settings ko sa gap naging default ganun"

Cosmetically: drag mouse sensitivity → gaps reset to default.

### What was actually happening

`AppearancePage.qml` (where you change gaps via the slider) is one
of the only consumers of the OLD V1 `SettingsState` singleton. The
rest of the codebase is on V2 (`SettingsStateV2`).

V1's init code was:

```qml
Component.onCompleted: {
    stateFile.reload()
    Qt.callLater(readFromHyprland)   // ← unconditional
}
```

That second line ALWAYS queried `hyprctl getoption general:gaps_in`
(and friends), pulled whatever Hyprland was currently reporting,
overwrote V1's properties with those values, then wrote them back
to `~/.config/quickshell/zen-shell/settings-state.json`.

Catch: if anything had triggered a `hyprctl reload` in between
(theme change, animation preset, lid handler open, hypridle
restart, even a no-op zen-shell reload), Hyprland's effective
gap values would have already reverted to whatever's in
`~/.config/hypr/hyprland.conf` (typically defaults). V1 then
read those defaults and saved them as your "preferences."

So the actual trigger wasn't mouse sensitivity at all — it was
ANY action that caused SettingsState to be re-instantiated after
a reload. Mouse sensitivity was the most visible culprit because
it's the most frequently changed.

V2 already had the fix for this (added in v6.15.6 — see
`SettingsStateV2.qml:587-619`). V1 was missed because at the
time AppearancePage was supposed to migrate to V2. That migration
never happened, so V1 stayed buggy in production until now.

### The fix

Ported V2's pattern into V1:

```qml
// v6.16.3.2.1
Component.onCompleted: {
    stateFile.reload()
    // (readFromHyprland call removed from here)
}

Connections {
    target: stateFile
    function onLoaded() {
        const text = stateFile.text()
        if (text && text.trim().length > 2) {
            root.loadFromJson(text)              // ← respect saved values
            Qt.callLater(root.applyToHyprland)   // ← push them BACK to hypr
        } else {
            // Genuine first run, no JSON saved yet — seed from hyprctl
            Qt.callLater(root.readFromHyprland)
        }
    }
}
```

Also added a V1-scoped `applyToHyprland()` function (mirror of V2's,
trimmed to V1's smaller property set) so the post-load defensive
push has somewhere to go.

### How to verify on your X270

1. Settings → Appearance → set Gaps In = 8, Gaps Out = 24 (anything
   other than the 5/20 defaults)
2. Open Control Panel → Input → drag mouse sensitivity around
3. Close Control Panel
4. Reopen Settings → Appearance — gaps should still be 8/24

Pre-fix: gaps would revert to 5/20. Post-fix: they stick.

### Files touched

```
zen-shell-v5/SettingsState.qml   modified (full replacement, drop-in)
```

One file. Still wala tayong binawasan — every property, every public
function, every existing call signature is byte-identical to v6.16.0.
Only the init order of operations changed.

---

## #2 — hyprlock / hypridle dependency

### What you asked

> "yung hyprlock wala kasi ako nun pre if ever kasama ba ito sa
>  install.sh natin? click ko kasi yun button nung hyprlock wala e
>  kapag click ok, naka --needed if ever"

You clicked Lock from the StartMenu, nothing happened — because
`hyprlock` wasn't installed and `PowerConfirmDialog` calls it
directly via `Quickshell.execDetached`.

### Pre-v6.16.3.2.1

`hyprlock` and `hypridle` weren't in `install.sh`'s dep list at all.
v6.16.3.2's overlay installer just WARNED if they were missing
("hyprlock missing — overlay will degrade gracefully") but didn't
offer to install them. That was too passive.

### Now (v6.16.3.2.1)

**Two layers of coverage:**

1. **Main `install.sh` (one-time fix)** — added a new section under
   the recommended deps:

   ```bash
   echo "  v6.16.3.2 — Lock screen + idle (laptop-recommended):"
   check_cmd hyprlock hyprlock
   check_cmd hypridle hypridle
   ```

   These now appear in the standard deps prompt during fresh installs
   and get installed alongside cava, playerctl, etc. when the user
   accepts the optional-deps prompt with `paru -S --needed ...`.

2. **`install-v6.16.3.2.1-overlay.sh` Phase 2 (immediate fix)** —
   detects missing hyprlock/hypridle, asks once, runs:

   ```bash
   $INSTALLER -S --needed hyprlock hypridle
   ```

   where `$INSTALLER` is whichever of `paru`, `yay`, or `sudo pacman`
   it finds. The `--needed` flag means already-installed packages
   are skipped silently — re-running the overlay later is harmless.

### CachyOS / Arch

Both `hyprlock` and `hypridle` are in the official `extra` repo on
modern Arch + CachyOS (since both are from the Hyprland project).
No AUR needed. paru/yay just call pacman under the hood.

If for some reason they're missing on your system, manual fallback:

```bash
sudo pacman -S --needed hyprlock hypridle
```

---

## #3 — Hyprlock vaxry-style redesign

### What you asked for

Reference: the screenshot of vaxry's lock screen (anime girl
wallpaper, centered "00:12", "Hi vaxry :)" greeting, pill input).

You wanted:
- Background = current desktop wallpaper, **synchronized**
- Centered Google-Material-You-style clock
- "Hi $USER" with **dynamic** greeting based on time of day
  (and weather — "rainy evening" was your example)
- Pill-shaped password input

### What v6.16.3.2.1 ships

```
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   │            (live desktop wallpaper, blurred)         │
   │                                                      │
   │                      ██████                          │
   │                      00:12                           │   ← clock
   │                                                      │     150px
   │              Good evening, paul 🌙                   │   ← dynamic
   │                                                      │     greeting
   │              ╭────────────────────╮                  │
   │              │  Input password    │                  │   ← pill input
   │              ╰────────────────────╯                  │
   │                                                      │
   └──────────────────────────────────────────────────────┘
```

### Live wallpaper sync — how

Hyprlock's `background.path` field accepts a static filepath only —
no expansion of "current wallpaper". To bridge that, v6.16.3.2.1
ships a wrapper:

```bash
~/.local/bin/zen-lock.sh
```

What it does:
1. Reads `.currentWallpaper` from `~/.config/quickshell/zen-shell/wallpaper-v5.json`
2. Symlinks that path to `~/.cache/zen-shell/lock-wallpaper.png`
3. Launches `hyprlock` (idempotent — exits if already running)

`hyprlock.conf` references the symlink:
```
background {
    path = $HOME/.cache/zen-shell/lock-wallpaper.png
    blur_passes = 3
    blur_size = 7
    brightness = 0.55
    ...
}
```

So every lock invocation through `zen-lock.sh` refreshes the symlink
to the current wallpaper, and hyprlock renders that. Change wallpaper
on the desktop → next lock, lock screen matches.

Fallbacks (in `zen-lock.sh`, in order):
- wallpaper-v5.json missing → keep existing symlink
- existing symlink also missing → `grim` screenshot
- `grim` missing → no background (hyprlock falls back to flat bg color)

`hypridle.conf` updated to call `~/.local/bin/zen-lock.sh` instead
of `hyprlock` directly:

```
general {
    lock_cmd = pidof hyprlock || ~/.local/bin/zen-lock.sh
}
```

### Dynamic greeting — how

Hyprlock supports `text = cmd[update:N] <shell>` for live-updating
labels. The greeting label runs every minute (60000ms) and computes:

```
                 emoji on weather match
                  ↓
"Good evening, paul 🌧️"
   ↑      ↑       ↑
   |      |       └─ default emoji for time-of-day
   |      └────────── time-of-day adjective + optional weather modifier
   └───────────────── "Good" / "Working" prefix
```

Time-of-day matrix:

| Hour          | Default        | Default emoji |
|---------------|----------------|---------------|
| 05–11         | morning        | ☀️             |
| 12–16         | afternoon      | ⛅             |
| 17–21         | evening        | 🌙             |
| 22–04         | (Working) late | ☕             |

Weather override (reads `~/.cache/zen-shell/weather.json` if jq is
present and the file exists — populated by Zen Shell's
`WeatherService.qml`):

| `condition` contains | Adjective prefix | Emoji override |
|----------------------|------------------|----------------|
| Rain / Drizzle       | "rainy"          | 🌧️             |
| Snow                 | "snowy"          | 🌨️             |
| Thunder / Storm      | "stormy"         | ⛈️             |
| Clear (night only)   | (no override)    | 🌌             |
| Cloud / Overcast (day only) | (no override) | ☁️         |

Examples:
- 7am clear weather → "Good morning, paul ☀️"
- 6pm rain → "Good rainy evening, paul 🌧️"
- 11pm clear sky → "Working late, paul 🌌"
- 2pm overcast → "Good afternoon, paul ☁️"

If `weather.json` doesn't exist (user has Weather widget disabled
or hasn't configured location yet), greeting silently degrades to
time-of-day only — no error.

### Pill input

```
input-field {
    size              = 360, 60
    rounding          = 30                       # = size.height / 2 → true pill
    outer_color       = rgba(122, 162, 247, 0.85) # Theme.blue
    inner_color       = rgba(36, 40, 59, 0.65)    # Theme.bg1 @ 65% alpha
    placeholder_text  = <i><span foreground="##94a3c2">  Input password</span></i>
}
```

### Bonus: caps-lock indicator

Small "⇪ CAPS LOCK" label appears below the password field if caps
lock is engaged. Disappears when off. Same color as the fail
state (Theme.red) so it stands out as a "watch out" cue.

---

## Files in this drop

### NEW

```
scripts/zen-lock.sh                  ← wrapper for live-wallpaper-synced hyprlock
install-v6.16.3.2.1-overlay.sh       ← cumulative overlay installer
CHANGELOG-v6.16.3.2.1.md             ← this file
```

### UPDATED

```
zen-shell-v5/SettingsState.qml       ← gap regression fix (port v6.15.6 from V2)
hypr-config/hyprlock.conf            ← vaxry-style redesign
hypr-config/hypridle.conf            ← lock_cmd routes through zen-lock.sh
install.sh                           ← +hyprlock +hypridle in recommended deps
```

### CARRIED OVER FROM v6.16.3.1 + v6.16.3.2 (unchanged)

```
zen-shell-v5/PowerConfirmDialog.qml  ← v6.16.3.1 — MDI icons + suspend
hypr-config/lid-behavior.conf        ← v6.16.3.2 — smart lid binds + manual recovery
hypr-config/autostart.conf           ← v6.16.3.2 — +hypridle launch
hypr-config/zen-sleep-hook.sh        ← v6.16.3.2 — systemd-sleep root hook
scripts/zen-lid-handler.sh           ← v6.16.3.2 — smart mode handler
scripts/zen-resume-handler.sh        ← v6.16.3.2 — wake recovery pipeline
CHANGELOG-v6.16.3.1.md               ← v6.16.3.1
CHANGELOG-v6.16.3.2.md               ← v6.16.3.2
```

### UNCHANGED FROM v6.16.2.3.6

Everything else (the rest of the QML tree, all themes, install.sh
beyond the small recommended-deps addition, bootstrap.sh, etc.).

---

## Install / update

### Standard cumulative overlay (recommended)

```bash
tar -xzf zen-shell-v6.16.3.2.1.tar.gz
cd zen-shell-v6.16.3.2.1
./install-v6.16.3.2.1-overlay.sh
```

The overlay installer is idempotent — re-run any time.

It will:
- Phase 2: Offer to install hyprlock + hypridle if missing
- Phase 3-5: Apply all v6.16.3.X file changes
- Phase 6: Seed the lock-wallpaper symlink (so first lock has a bg)
- Phase 7: Offer to install the systemd-sleep hook (sudo)
- Phase 8: Restart hypridle and quickshell so changes take effect

### Skip the systemd-sleep hook

When Phase 7 asks "Install systemd-sleep hook? [Y/n]" answer `n`.
You get full lid + manual recovery; you don't get auto recovery
on non-lid wakes. Most users are fine with this.

### Brand-new install

```bash
tar -xzf zen-shell-v6.16.3.2.1.tar.gz
cd zen-shell-v6.16.3.2.1
./install.sh                          # base install (now includes hyprlock+hypridle)
./install-v6.16.3.2.1-overlay.sh      # cumulative overlay
```

---

## Verification checklist for Paul on the X270

| # | Test                                        | Expected                       |
|---|---------------------------------------------|--------------------------------|
| 1 | Set Gaps In = 8, Gaps Out = 24 in Appearance | Saved                         |
| 2 | Drag mouse sensitivity slider               | Gaps remain 8/24               |
| 3 | Click Lock from StartMenu                   | Hyprlock appears               |
| 4 | Lock screen background                      | Matches current desktop wp     |
| 5 | Clock                                       | Big centered, sans-serif       |
| 6 | Greeting at 6pm                             | "Good evening, paul 🌙"        |
| 7 | Greeting if it's raining (weather configured) | "Good rainy evening, paul 🌧️" |
| 8 | Caps lock on                                | "⇪ CAPS LOCK" appears below   |
| 9 | Password input shape                        | Pill (rounded ends)            |

If #4 shows a flat bg instead of your wallpaper:
- Check `~/.cache/zen-shell/lock-wallpaper.png` exists and is a
  valid symlink: `ls -la ~/.cache/zen-shell/lock-wallpaper.png`
- Manually re-run: `~/.local/bin/zen-lock.sh` (which exits cleanly
  if hyprlock is already up, but updates the symlink first)

If #6 / #7 show a stale or wrong greeting:
- Tail: `tail -f ~/.cache/zen-shell/lock.log` while you lock
- The greeting cmd refreshes every 60s — wait a minute or unlock
  and re-lock to trigger immediate refresh

---

## What's NOT in v6.16.3.2.1

- **Theme-synced hyprlock palette** — still hardcoded Tokyo-Night
  rgba values. A future drop will auto-regen `hyprlock.conf`
  colors from the active scheme JSON, mirroring the existing
  `regen-swaync-theme.sh` pattern.
- **Avatar in the lock screen** — pulled out for now. The vaxry
  reference doesn't have an avatar and Paul's design ask was
  more minimalist. We can re-add as an opt-in if requested.
- **AppearancePage migration to V2** — out of scope for a hotfix.
  V1 will work correctly now; the migration is a separate, larger
  cleanup that can land in v6.17.
- **Mouse sensitivity in V2** — currently `MouseSettingsService` is
  its own singleton, separate from V1 and V2. That's fine — no
  need to migrate it. The bug was V1's init code, not the mouse
  service interaction.

---

## Next up in the v6.16.3.X series

- **v6.16.3.3** — `DisplaysPage` resolution dropdown enumeration fix
- **v6.16.3.4** — Bar profile/GPU badge widget
- **v6.16.3.5** — Start Menu logo image picker
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
