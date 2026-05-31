# Zen Shell v6.16.3.8 — Idle / Lid / Sleep unified UX

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.8`
**Base:** v6.16.3.7
**Status:** Beta — roadmap milestone (hypridle config, lid switch, hyprlock cascade)

---

## TL;DR

> *"need idle before lock lagay ng 30 secs 1 min 30 mins 1 3 5 hours
>   or never or sleep or never — lid ng notebook naman if laptop
>   if close lid automatically mag sleep mode tas matic diretso
>   na hyprlock ganun din sa logic ng desktop"*

Two new configurable cascades, unified under **Settings → Battery
& Power**:

### 1. Idle timeouts (user-picked)

| Setting            | Options                                          |
|--------------------|--------------------------------------------------|
| Lock after idle    | 30 seconds · 1 minute · 30 minutes · 1 hour · 3 hours · 5 hours · Never |
| Sleep after idle   | 30 seconds · 1 minute · 30 minutes · 1 hour · 3 hours · 5 hours · Never |

Picked values update hypridle.conf live via
`zen-hypridle-sync.sh` and restart hypridle so changes apply
without a shell restart.

### 2. Lid close action (laptop only)

| Option                          | Behavior                                                   |
|---------------------------------|------------------------------------------------------------|
| **Sleep (suspend + lock on wake)** | default — lock screen + `systemctl suspend`; wake to lock |
| Lock only (stay on)             | lock screen shows, system stays powered                    |
| Do nothing                      | no system action; monitor behavior still runs (see below)  |

This is **separate** from the existing Lid Close Behavior →
monitor mirroring option (mirror / keep / off). That one handles
the DISPLAY; this one handles the SYSTEM. Both fire on close.

### 3. Wake → Lock cascade (already correct, documented)

When the system suspends — from idle, from lid close, or manually
— `hypridle.conf:general.before_sleep_cmd = loginctl lock-session`
ensures the lock screen is up before sleep. On wake (any key,
mouse move, lid open), the user lands on hyprlock. No extra work
needed — this was already the designed flow in 3.2.

---

## Architecture

### New files

**`scripts/zen-hypridle-sync.sh`** (~120 lines, pure bash + jq)

```
panel-state.json                    hypridle.conf
┌──────────────────────┐            ┌─────────────────────────┐
│ idleLockSeconds: 60  │            │ listener {              │
│ idleSleepSeconds: 0  │ ──sed──▶   │   timeout = 60          │
└──────────────────────┘            │   # ZEN_IDLE_LOCK       │
                                     │ }                       │
                                     │ listener {              │
                                     │   timeout = 120         │
                                     │   # ZEN_IDLE_DPMS       │
                                     │ }                       │
                                     │ listener {              │
                                     │   timeout = 99999999    │
                                     │   # ZEN_IDLE_SLEEP      │
                                     │ }                       │
                                     └─────────────────────────┘
                                              │
                                              ▼
                                     pkill hypridle
                                     setsid -f hypridle &
```

- Reads `PanelState.idleLockSeconds` and `idleSleepSeconds` from
  `~/.local/share/quickshell/zen-shell/panel-state.json`
- Guards against non-integer values (defaults: 300 / 0)
- Normalizes `0` → `99999999` (sentinel = effectively never)
- Derives DPMS off as `LOCK + 60s` (or never, if lock is never)
- sed-rewrites timeout values on lines matching `# ZEN_IDLE_LOCK`,
  `# ZEN_IDLE_DPMS`, `# ZEN_IDLE_SLEEP` markers
- User customizations (unmarked lines) stay byte-identical
- pkill + restart hypridle (daemon doesn't support SIGHUP reload)

### Modified files

**`hypr-config/hypridle.conf`** — added marker comments on the
three timeout lines. Defaults baked in: 300s lock, 360s DPMS off,
99999999s sleep (never). Everything else (lock_cmd, before_sleep_cmd,
after_sleep_cmd) unchanged — documented flow still holds.

**`scripts/zen-lid-handler.sh`** — added `LID_ACTION` read from
PanelState, early-dispatch block at top of `close)` case:

```bash
if [ "$LID_ACTION" = "suspend" ]; then
    lock_screen
    sleep 0.3
    systemctl suspend
    exit 0
elif [ "$LID_ACTION" = "lock" ]; then
    lock_screen
    # fall through for monitor handling
fi
# "ignore" falls through (monitor handling only, old behavior)
```

When user sets "Sleep on lid close", this always fires — overrides
the smart/mirror AC-vs-battery logic. Clean, predictable.

**`zen-shell-v5/PanelState.qml`** — 3 new properties:

```qml
property int idleLockSeconds: 300         // 5 minutes default
property int idleSleepSeconds: 0          // never default
property string lidCloseAction: "suspend" // laptop default
```

All persist via `saveState()`, clamped on `applyState()` to valid
ranges (0-86400s for timeouts; enum validation for action).

**`zen-shell-v5/BatterySettingsPage.qml`** — new section "Idle &
Sleep" between the power profile pill and existing Lid Close
Behavior. Also extended Lid Close Behavior with the new "On lid
close" row at the top.

**`install.sh`** — deploys `zen-hypridle-sync.sh` via the existing
script-install loop, then calls it once after `hypridle.conf` is
copied in Phase B. Ensures defaults (or existing user values) are
applied without requiring a shell restart.

---

## Flow examples

### Idle lock (user picks 1 minute)

1. User opens Settings → Battery & Power → Idle & Sleep
2. Clicks "Lock after idle" combobox → picks "1 minute"
3. `PanelState.idleLockSeconds = 60` → `saveState()` writes
   `panel-state.json`
4. `Process { command: zen-hypridle-sync.sh }` fires (with 100ms
   delay for disk flush)
5. Script reads `panel-state.json` → sed-rewrites hypridle.conf:
   `timeout = 60 # ZEN_IDLE_LOCK`, `timeout = 120 # ZEN_IDLE_DPMS`
6. `pkill hypridle && setsid -f hypridle` — daemon restarts
7. User idle for 60s → lock screen appears

### Lid close on laptop (default "suspend")

1. User closes lid
2. Hyprland `bindl = , switch:on:Lid, exec, zen-lid-handler.sh close`
3. Handler reads `LID_ACTION = "suspend"` from panel-state.json
4. Early dispatch: `lock_screen && sleep 0.3 && systemctl suspend`
5. hypridle's `before_sleep_cmd = loginctl lock-session` fires too
   (defensive — `pidof hyprlock` guard prevents stacking)
6. System suspends
7. User opens lid → systemd resume
8. `after_sleep_cmd = hyprctl dispatch dpms on` → screen wakes
9. hyprlock is already running → user lands on lock screen

### Desktop idle (Paul's setup — lidless)

1. Paul picks "Lock after idle: 5 minutes" and "Sleep after idle: Never"
2. hypridle.conf: `ZEN_IDLE_LOCK=300`, `ZEN_IDLE_SLEEP=99999999`
3. After 5min idle → lock screen. No suspend (effectively never).
4. Any keypress → wake, hyprlock is already showing → password prompt

---

## Files in this drop

### NEW

```
scripts/zen-hypridle-sync.sh          ← new: PanelState → hypridle.conf sync
CHANGELOG-v6.16.3.8.md                 ← this file
```

### UPDATED

```
zen-shell-v5/PanelState.qml           ← +3 props (idleLock/Sleep/lidAction)
zen-shell-v5/BatterySettingsPage.qml  ← +Idle & Sleep section, lid action row
zen-shell-v5/ZenVersion.qml           ← bump to v6.16.3.8
scripts/zen-lid-handler.sh             ← +LID_ACTION override block
hypr-config/hypridle.conf              ← rewritten with ZEN_IDLE_* markers
install.sh                              ← deploy sync script + fire on install, banner
```

### CARRIED OVER from 3.7

- Universal widget scale factor (PanelState.widgetScale + slider)
- Font dependency check (adwaita-fonts, inter-font, gnome-themes-extra)
- Lock clock font sync with Black/Bold weight mapping
- Gender-aware lock messages (English, 3 pools × time × weather)
- Hover popup parity (ZenClock, ZenSysMonitor)

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.8.tar.gz
cd zen-shell-v6.16.3.8
./install.sh
```

No shell restart needed — hypridle config updates via the sync
script; lid behavior reads PanelState on every event.

### Test — idle lock

1. Settings → Battery & Power → **Idle & Sleep** section
2. "Lock after idle" → pick `30 seconds`
3. Don't touch keyboard/mouse for 30 seconds
4. Lock screen appears
5. Enter password → unlock
6. Go back to Settings → pick `Never`
7. Sync script fires, hypridle.conf now has `99999999` → no auto-lock

Verify sync worked:
```bash
grep ZEN_IDLE ~/.config/hypr/hypridle.conf
```

Expected output:
```
    timeout      = 99999999    # ZEN_IDLE_LOCK
    timeout      = 99999999    # ZEN_IDLE_DPMS
    timeout      = 99999999    # ZEN_IDLE_SLEEP
```

### Test — lid close (laptops only)

1. Settings → Battery & Power → **Lid Close Behavior** section
2. "On lid close" → `Sleep (suspend + lock on wake)`
3. Close lid
4. System suspends within ~0.3 seconds (lock fires first)
5. Open lid → screen wakes → hyprlock prompt

Log trace:
```bash
tail -f ~/.cache/zen-shell/lid.log
```

Expected lines on close:
```
close: behavior=smart lid_action=suspend ext=0 internal=eDP-1
  → lid_action=suspend: lock + systemctl suspend
```

### Test — "Do nothing" lid action

1. Settings → "On lid close" → `Do nothing`
2. Close lid
3. No lock, no suspend — just monitor handling (mirror/keep/off
   per the second dropdown)
4. Useful for "always-on" docked workflows where you close the
   lid but expect external monitor + system to stay fully awake

---

## Troubleshooting

### Idle timeout doesn't fire

```bash
pgrep -x hypridle && echo "running" || echo "NOT running"
```

If not running, re-launch: `setsid -f hypridle &`

Check the synced config:
```bash
grep ZEN_IDLE ~/.config/hypr/hypridle.conf
cat ~/.cache/zen-shell/hypridle-sync.log | tail
```

### Lid close doesn't suspend

```bash
cat ~/.cache/zen-shell/lid.log | tail -20
```

Look for `lid_action=suspend` in the last close event. If it says
`lid_action=` (empty), PanelState isn't being read — check:
```bash
jq .lidCloseAction ~/.local/share/quickshell/zen-shell/panel-state.json
```

### Lock clock appears before display sleeps

Expected — DPMS off is derived as lock + 60s. The 60s window lets
you enter your password without the display immediately blanking.
If you want them simultaneous, edit hypridle.conf manually and
remove the `# ZEN_IDLE_DPMS` marker (then zen-hypridle-sync.sh
won't touch that line anymore).

---

## Next up: v6.16.4

Global Hyprland `configreloaded` IPC listener — supersedes the
v6.16.3.4.1 MouseSettingsService spot-fix. Unlocks clean live-reload
for all Settings panels without per-page Process boilerplate.

Then: Phase 4 — Hyprland dark mode + GTK3/4 theming, hyprbars +
minimize mode, auto-clean memory, float/tile assignment.

**Wala tayong binawasan.** Every 3.7 feature carries byte-identical
into 3.8.
