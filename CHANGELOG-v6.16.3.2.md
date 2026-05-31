# Zen Shell v6.16.3.2 — Smart Lid + Full Wake Recovery overlay

**Release date:** 2026-04-22
**Branch:** `beta-v12.6.16.3.2`
**Base:** v6.16.3.1
**Status:** Beta — second feature drop of the v6.16.3.X series

---

## TL;DR

Lid close on the X270 is no longer a roulette wheel. The compositor
state, monitor enumeration, swww daemon, hyprlock surface, and DRM/DPMS
state are all explicitly recovered on every wake — through three
independent paths (lid switch, systemd-sleep hook, manual hotkey)
covering every wake scenario.

Smart-mode default replaces "mirror" as the lid-close behavior:

| External? | AC plugged? | What happens                       |
|-----------|-------------|------------------------------------|
| Yes       | —           | Clamshell (eDP off, externals run) |
| No        | Yes         | Lock + DPMS off (no suspend)       |
| No        | No          | Lock + Suspend                     |

Overlay-only release — does NOT touch the 65K main `install.sh`.
Apply with `./install-v6.16.3.2-overlay.sh` on top of any v6.16.x
installation. Includes v6.16.3.1's `PowerConfirmDialog.qml`.

**Wala tayong binawasan.** Old `mirror` / `keep` / `off` lid modes
still work exactly as in v6.16.0; the only thing that changed is the
default when no behavior is saved.

---

## The three failure modes this addresses

Paul reported on 2026-04-22:
1. **Black screen on wake**, requires hard reboot
2. **Wakes but stays locked behind hyprlock indefinitely**
3. **External monitor stays off after redocking**

Diagnostic context: v6.16.0's lid handler did `hyprctl reload` on lid
open and called it done. That's enough for "lid down → lid up, nothing
else changed" but not for any of the above. Specifically:

- **Symptom 1** = compositor's DRM state half-resumed after systemd
  suspend. `hyprctl reload` re-reads config but doesn't kick the GPU's
  display engine. Fix: explicit DPMS off→on cycle.
- **Symptom 2** = hyprlock's surface lost its `wl_output` binding
  during suspend. The process is alive but never repaints. Fix: send
  `SIGUSR1` (hyprlock 0.5+ redraw signal).
- **Symptom 3** = monitor hotplug events emitted while suspended are
  dropped. On wake, Hyprland's monitor list is stale. Fix: full
  `hyprctl reload` + per-monitor `keyword monitor X,preferred,auto,1`.

Each of these is now applied at three layers:
1. **Lid open** path — `zen-lid-handler.sh open` (the existing hook)
2. **Systemd post-suspend** — `zen-sleep-hook.sh` → `zen-resume-handler.sh`
3. **Manual** — `SUPER+SHIFT+W` keybind, also calls `zen-resume-handler.sh`

All three are idempotent. Doubling up is harmless.

---

## Smart mode logic

```
Lid CLOSE
├─ External monitor connected?
│  └─ YES → Clamshell:
│           hyprctl keyword monitor eDP-1,disable
│           hyprctl reload
│
└─ NO → AC plugged in?
        ├─ YES → Lock + DPMS off:
        │        hyprlock &
        │        hyprctl dispatch dpms off
        │        (system stays awake; quick wake on lid open)
        │
        └─ NO  → Lock + Suspend:
                 hyprlock &
                 systemctl suspend
                 (battery preservation)

Lid OPEN  (always — same pipeline regardless of close mode)
1. hyprctl keyword monitor eDP-1,preferred,auto,1
2. hyprctl reload                   ← catches dock changes
3. sleep 0.25                       ← settle
4. hyprctl dispatch dpms off; sleep 0.15; hyprctl dispatch dpms on
                                    ← THE black-screen-on-wake fix
5. swww query || (pkill swww-daemon; setsid swww-daemon)
                                    ← wallpaper resurrection
6. pkill -SIGUSR1 hyprlock          ← unjam the lock surface
7. workspace bounce                 ← belt-and-suspenders render kick
```

---

## Why "smart" isn't suspend-on-AC

Long-running workflows on docked laptops (compiles, downloads, IPC
sessions, tunnels, IDE indexers) get killed by suspend. That's a worse
outcome than a few extra watts. AC plugged in → user has signaled
"power isn't a constraint right now" → respect that.

If you want suspend-on-AC anyway: future v6.16.3.X.x will expose the
behavior in `SettingsPage`. For now, set
`.system.lidCloseBehavior = "mirror"` in `settings-state-v2.json`
manually — that's the legacy "always suspend when no external"
behavior.

---

## Files in this drop

### NEW

```
hypr-config/hypridle.conf            ← idle/lock/suspend cascade
hypr-config/hyprlock.conf            ← Tokyo-Night styled lock screen
hypr-config/zen-sleep-hook.sh        ← systemd-sleep hook (root)
scripts/zen-resume-handler.sh        ← post-wake recovery pipeline
install-v6.16.3.2-overlay.sh         ← standalone overlay installer
CHANGELOG-v6.16.3.2.md               ← this file
```

### UPDATED

```
hypr-config/lid-behavior.conf        ← + SUPER+SHIFT+W manual recovery
hypr-config/autostart.conf           ← + exec-once = hypridle
scripts/zen-lid-handler.sh           ← smart mode + full recovery on open
```

### CARRIED OVER FROM v6.16.3.1

```
zen-shell-v5/PowerConfirmDialog.qml  ← MDI icons + suspend support
CHANGELOG-v6.16.3.1.md
```

### UNCHANGED

Everything else from v6.16.2.3.6 (the entire `zen-shell-v5/` QML tree
minus `PowerConfirmDialog.qml`, all themes, all other scripts, the
main `install.sh`, `bootstrap.sh`, etc.) ships byte-identical.

---

## Three-layer recovery architecture

```
                   ┌─────────────────────────────────────┐
WAKE EVENT  ───────┤  Where did the wake come from?      │
                   └─────────────────────────────────────┘
                              │
            ┌─────────────────┼──────────────────┐
            │                 │                  │
            ▼                 ▼                  ▼
   ┌──────────────┐  ┌──────────────────┐  ┌─────────────────┐
   │ LID OPEN     │  │ SYSTEMD POST-    │  │ MANUAL HOTKEY   │
   │ switch event │  │ SUSPEND          │  │ SUPER+SHIFT+W   │
   └──────┬───────┘  └────────┬─────────┘  └────────┬────────┘
          │                   │                     │
          │                   ▼                     │
          │       ┌─────────────────────────┐       │
          │       │  /usr/lib/systemd/      │       │
          │       │  system-sleep/          │       │
          │       │  zen-sleep-hook.sh      │       │
          │       │  (runs as ROOT)         │       │
          │       └────────────┬────────────┘       │
          │                    │                    │
          │      sudo -u user, with WAYLAND env     │
          │                    │                    │
          ▼                    ▼                    ▼
   ┌──────────────┐  ┌──────────────────┐  ┌─────────────────┐
   │ zen-lid-     │  │ zen-resume-      │  │ zen-resume-     │
   │ handler.sh   │  │ handler.sh       │  │ handler.sh      │
   │ open         │  │ (post-suspend)   │  │ (manual)        │
   └──────┬───────┘  └────────┬─────────┘  └────────┬────────┘
          │                   │                     │
          └───────────────────┼─────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │ RECOVERY PIPELINE    │
                  │  1. monitor re-enum  │
                  │  2. DPMS off→on      │
                  │  3. swww restart     │
                  │  4. hyprlock SIGUSR1 │
                  │  5. workspace bounce │
                  └──────────────────────┘
```

Each entry path runs the same recovery pipeline. Idempotent — running
it twice in 100ms is a no-op the second time (everything's already
healthy).

---

## hypridle.conf — the cascade

```
   0   user goes idle
   ↓
 5min  → loginctl lock-session   (locks via hyprlock)
   ↓
 6min  → hyprctl dispatch dpms off
   ↓
15min  → on battery: systemctl suspend
         on AC: stays at DPMS-off
   ↓
       USER WAKES
   ↓
       hyprctl dispatch dpms on  (after_sleep_cmd in [general])
       PLUS the systemd-sleep hook fires the recovery pipeline
       PLUS lid-open also fires it if the wake was a lid event
```

The 15-minute on-battery suspend is implemented via inline bash in the
`on-timeout` line because hypridle has no native AC condition. Cheap,
robust, no extra script needed.

---

## hyprlock.conf — minimal but themed

Tokyo-Night palette baked into the rgba values (matches v6.16.3.2's
default scheme). Uses `screenshot` background source with 3-pass blur
so it doesn't depend on swww being healthy at lock time. Avatar pulls
from `~/.config/quickshell/zen-shell/avatar.png` (the same file the
Zen Shell user profile widget uses), so changing it in Settings
auto-updates the lock screen too.

A future v6.16.3.X may auto-regenerate this file from the active theme
JSON, mirroring `regen-swaync-theme.sh`. For now it's a static drop —
override locally if you're on a non-Tokyo-Night scheme.

---

## Logging — debug your X270 wake issues

Two new bounded log files (last 200 lines each):

```
~/.cache/zen-shell/lid.log      ← every lid open/close event
~/.cache/zen-shell/resume.log   ← every wake recovery pipeline
```

Tail them while testing:

```
tail -f ~/.cache/zen-shell/lid.log ~/.cache/zen-shell/resume.log
```

Sample lid.log line:
```
[2026-04-22 14:32:15] close: behavior=smart ext=0 internal=eDP-1
[2026-04-22 14:32:15]   → smart + no external + on AC: lock + dpms off
```

Sample resume.log line:
```
[2026-04-22 14:35:02] resume: pipeline start (HIS=abc123def456)
[2026-04-22 14:35:02]   hyprctl reachable after 200ms
[2026-04-22 14:35:02]   force-applied preferred mode on eDP-1
[2026-04-22 14:35:02]   DPMS off→on cycle complete
[2026-04-22 14:35:02]   swww-daemon stale, restarting
[2026-04-22 14:35:02]   re-applied wallpaper /home/paul/.local/share/wallpapers/...
[2026-04-22 14:35:02]   workspace bounce complete (returned to ws 3)
[2026-04-22 14:35:02] resume: pipeline complete
```

If a wake breaks anyway, paste those two log files and we'll diff the
recovery sequence to see what didn't fire.

---

## Optional dependencies

| Tool       | Purpose                            | Behavior if missing                    |
|------------|------------------------------------|----------------------------------------|
| `hypridle` | Idle/lock/suspend cascade          | No timed lock; manual lock still works |
| `hyprlock` | Lock screen surface                | Falls back to `swaylock`, then DPMS off|
| `swww`     | Wallpaper daemon                   | Wallpaper won't repaint after wake     |
| `jq`       | Parse settings JSON                | Defaults to "smart" mode always        |
| `sudo`     | Install systemd-sleep hook         | Only lid-open + manual hotkey work     |

Arch package install (matches Paul's CachyOS):

```bash
sudo pacman -S hypridle hyprlock jq
```

---

## Install / update

### Fresh box (already running v6.16.x)

```bash
tar -xzf zen-shell-v6.16.3.2.tar.gz
cd zen-shell-v6.16.3.2
./install-v6.16.3.2-overlay.sh
```

The overlay installer is idempotent — re-run it whenever to refresh.

### Brand-new install

Use the main `install.sh` first (does the full bootstrap), then run
the overlay:

```bash
tar -xzf zen-shell-v6.16.3.2.tar.gz
cd zen-shell-v6.16.3.2
./install.sh                          # base install
./install-v6.16.3.2-overlay.sh        # smart lid layer
```

### Manual without sudo (skip the systemd hook)

When the overlay asks "Install systemd-sleep hook? [Y/n]" answer `n`.
You get full recovery on lid events and via SUPER+SHIFT+W; you don't
get recovery on non-lid wakes (keyboard wake, manual `systemctl
suspend`, hypridle auto-suspend). For most users this is fine.

---

## Test matrix Paul should run on the X270

After applying the overlay:

| # | Setup                              | Expected on lid close          | Expected on lid open           |
|---|------------------------------------|--------------------------------|--------------------------------|
| 1 | AC plugged, no external monitor    | Locks, screen off, awake       | Wake, prompt password, full UI |
| 2 | On battery, no external monitor    | Locks, suspends                | Wake, prompt password, full UI |
| 3 | External via dock, any power       | eDP off, externals stay live   | eDP back on, externals intact  |
| 4 | Suspend manually (`systemctl suspend`) | n/a                        | Wake, full UI restored         |
| 5 | Idle 5min                          | Locks                          | Prompt password                |
| 6 | Idle 15min on battery              | Locks → DPMS off → suspend     | Wake, prompt password, full UI |
| 7 | Idle 15min on AC                   | Locks → DPMS off (no suspend)  | Wake, prompt password, full UI |
| 8 | Wake to broken display             | n/a                            | SUPER+SHIFT+W restores UI      |

Run scenarios 1–4 first; those are the ones that were broken before.
5–7 confirm the new hypridle cascade works. 8 is the manual escape
hatch — should always work as a last resort.

---

## What's deliberately NOT in v6.16.3.2

- **SettingsPage UI for "smart" mode** — to ship next as a small
  v6.16.3.2.1 hotfix or batched into v6.16.3.4 (bar profile badge).
  For now, the new mode is the silent default; users wanting old
  behavior edit `settings-state-v2.json` manually.
- **Auto-regenerated hyprlock theme** — static Tokyo-Night drop only.
  Theme-syncing comes when we generalize `regen-swaync-theme.sh`.
- **Monitor watcher daemon** (socket2 listener) — not needed because
  the `hyprctl reload` in the lid-open path catches dock changes.
  Will only revisit if Paul sees hot-plug-during-active issues.
- **xss-lock / loginctl integration** — v6.16.3.2 uses Hyprland-
  native `loginctl lock-session` which works fine on systemd-logind
  systems (everyone). Non-systemd setups unsupported (out of scope).

---

## Next up in the v6.16.3.X series

- **v6.16.3.3** — `DisplaysPage` resolution dropdown enumeration fix
- **v6.16.3.4** — Bar profile/GPU badge widget
- **v6.16.3.5** — Start Menu logo image picker
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
