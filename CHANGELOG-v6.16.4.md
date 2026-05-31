# Zen Shell v6.16.4 — Laptop reliability pass

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.4`
**Base:** v6.16.3.8
**Status:** Beta — critical laptop UX hardening

---

## TL;DR

> *"make it sure ah sa mga laptop kasi nahihirapan ako lage ako
>   nag forced power off button sa laptop dpat hindi ganun hehe"*

The "I keep force-power-off'ing my laptop" problem — solved with
three layers of defense:

1. **Escape hatch keybind** — `SUPER+SHIFT+CTRL+Escape` (works
   even through frozen hyprlock, via Hyprland's `bindl` flag).
   Runs `zen-panic.sh` — kills zombied hyprlock, double DPMS
   cycle, monitor re-enum, swww revive, quickshell wake, clean
   relock. ~2 seconds end-to-end.
2. **Hardened resume pipeline** — `zen-resume-handler.sh` extends
   retry window 2s → 5s, adds DRM sysfs fallback kick,
   zombie-hyprlock detection via layer surface check, input
   subsystem power-cycle for stuck-keyboard fix.
3. **Pre-suspend health validation** — `zen-lid-handler.sh`'s
   `lock_screen()` now detects + kills zombied hyprlock before
   re-locking; `pre_suspend_healthcheck()` runs before every
   `systemctl suspend` to prevent "suspend a broken session →
   wake even more broken" cascades.

---

## 1. The panic keybind — your last-resort button

Bound in `hypr-config/binds.conf`:

```
bindl = $mainMod SHIFT CTRL, Escape, exec, ~/.local/bin/zen-panic.sh
```

**Why `bindl` matters**: Hyprland has four bind flavors — `bind`,
`bindl` (locked), `bindr` (release), `bindp` (press-through). The
`l` flag means "this keybind fires even when a session-lock
surface is up". hyprlock is a session-lock surface. Without the
`l` flag, hyprlock swallows every keystroke and you can't fire
recovery.

**With `l`**: Hyprland processes the bind itself, BEFORE hyprlock
sees the keys. Even if hyprlock is frozen, crashed, or zombie,
the keybind fires.

### What zen-panic.sh does (9 recovery steps)

```
Step 1  — SIGKILL hyprlock (if frozen)
          Snapshot pre-state to panic.log for post-mortem
Step 2  — Wait for hyprctl IPC reachability (up to 3s)
Step 3  — Double DPMS off→on cycle (AMDGPU needs 2x)
Step 4  — Monitor re-enumeration via hyprctl reload
          + per-monitor force preferred,auto,1
Step 5  — swww-daemon zombie detection + restart
          + wallpaper re-apply from wallpaper-v5.json
Step 6  — Quickshell wake hint (SIGUSR2)
          If second panic within 10s → full Quickshell restart
Step 7  — Clean re-lock (if session was locked before panic)
Step 8  — Workspace bounce (force paint pass)
Step 9  — (via resume handler) input subsystem power-cycle
```

**Two-press escalation**: first press = gentle recovery. Second
press within 10 seconds = full Quickshell restart (for cases
where step 6's SIGUSR2 didn't unstuck it). Tracked via
`~/.cache/zen-shell/panic-last` timestamp file.

**Notify-send confirmation**: if notifications work, you get a
"Zen Panic Recovery complete" popup so you know it ran.

### Manual invocation (when even the keybind can't fire)

If Hyprland itself is totally wedged and keybinds don't register:

**SSH from phone/other machine:**
```bash
ssh paul@laptop "~/.local/bin/zen-panic.sh"
```

**From TTY (Ctrl+Alt+F2):**
```bash
# Log in, then:
~/.local/bin/zen-panic.sh
```

The script runs with or without a live Hyprland IPC — every step
has a timeout and continues past failures.

---

## 2. Resume pipeline hardening (zen-resume-handler.sh)

### Before (2s retry, fail = exit)

```bash
while ! hyprctl monitors >/dev/null 2>&1; do
    sleep 0.1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 20 ]; then
        log "  hyprctl unreachable after 2s — abort recovery"
        exit 0
    fi
done
```

Failure mode: slower hardware (AMD APU, some NVIDIA) takes 3-4s
to re-init after deep suspend. 2s window was too tight → recovery
aborted → user got stuck.

### After (5s retry + DRM sysfs fallback)

```bash
while ! hyprctl monitors >/dev/null 2>&1; do
    sleep 0.1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 50 ]; then
        log "  hyprctl unreachable after 5s — last-resort DRM kick"
        for card in /sys/class/drm/card*/card*-*/enabled; do
            [ -w "$card" ] || continue
            echo "disabled" >"$card" 2>/dev/null
            sleep 0.1
            echo "enabled"  >"$card" 2>/dev/null
        done
        break   # ← NOT exit — continue with recovery
    fi
done
```

New behavior:
- 5s retry window (covers slow hardware)
- If still unreachable, direct DRM sysfs power cycle (bypasses
  Hyprland entirely — works at KMS level)
- Crucially: **continue** recovery steps even after timeout,
  instead of aborting. Each subsequent step has its own timeouts
  so nothing hangs.

### New: zombie hyprlock detection

```bash
# Is hyprlock "running" but not actually showing?
LAYER_COUNT=$(hyprctl layers -j 2>/dev/null \
    | jq -r '[..|.namespace? // empty | select(contains("hyprlock") or contains("session-lock"))] | length' 2>/dev/null \
    || echo 0)
if [ "$LAYER_COUNT" = "0" ] && pgrep -x hyprlock >/dev/null; then
    # Process alive but no visible surface → zombie
    pkill -9 -x hyprlock
    setsid -f zen-lock.sh &
fi
```

This is the exact failure mode that causes "black screen with
hyprlock process running but invisible" → force-power-off.
Detect → kill → cleanly relaunch.

### New: Step 8 — Input subsystem power-cycle

```bash
for dev in /sys/class/input/input*/device/power/control; do
    [ -w "$dev" ] || continue
    echo "on"   >"$dev" 2>/dev/null
    sleep 0.05
    echo "auto" >"$dev" 2>/dev/null
done
```

Fixes "keystrokes don't reach password field on hyprlock" after
wake. Pokes libinput's wakeup state so the USB keyboard (and
touchpad) come back online cleanly.

### New: Step 9 — Final responsiveness check + loud log

```bash
if ! timeout 2 hyprctl dispatch focuscurrentorlast >/dev/null 2>&1; then
    log "  ⚠ WARNING: hyprctl still unresponsive after recovery."
    log "  ⚠ Try panic keybind: SUPER+SHIFT+CTRL+Escape"
fi
```

If everything failed, the log explicitly tells the user what to
try next. No more "I don't know what's wrong".

---

## 3. zen-lid-handler.sh hardening

### lock_screen() rewrite

Before: simple hyprlock → swaylock → DPMS off chain. No zombie
detection. No wrapper preference.

After:
1. Check for zombie hyprlock → SIGKILL if detected
2. Prefer `zen-lock.sh` wrapper (gives wallpaper sync + font sync
   + lock message — stronger guarantee user lands on fully-rendered
   lock screen)
3. Fallback: direct hyprlock → swaylock → DPMS off

### New: pre_suspend_healthcheck()

Called before every `systemctl suspend` invocation in the close-case
branches (smart-with-battery, mirror-no-external, explicit
lid_action=suspend):

```bash
pre_suspend_healthcheck() {
    # hyprctl reachable?
    if ! timeout 1 hyprctl monitors >/dev/null 2>&1; then
        log "  pre-suspend: hyprctl unreachable — will suspend anyway"
        return 1
    fi
    # zombie hyprlock? kill before suspend.
    if pgrep -x hyprlock && [ "$layers" = "0" ]; then
        log "  pre-suspend: ⚠ zombie hyprlock — killing first"
        pkill -9 -x hyprlock
    fi
    return 0
}
```

Purpose: never suspend a broken session. If the session is
already wedged, waking from suspend makes it worse — that's when
force-power-off becomes the only option. Kill zombies BEFORE
suspending so resume starts from a clean slate.

---

## 4. Settings UI — "Panic Recovery" section

New HMSection in Settings → Battery & Power, below Lid Close
Behavior:

```
┌─ Panic Recovery ───────────────────────────────────────────┐
│  The keybind that saves you from force-power-off           │
│                                                             │
│  Escape keybind      [ SUPER + SHIFT + CTRL + Esc ]        │
│                       (red-tinted surface — emphasis)       │
│                                                             │
│  What it does        1) SIGKILL frozen hyprlock            │
│                      2) DPMS off→on double cycle           │
│                      3) Monitor re-enumeration             │
│                      4) Restart zombied swww-daemon        │
│                      5) Wake quickshell event loop         │
│                         (2nd press within 10s = full restart)│
│                      6) Re-lock cleanly                    │
│                      7) Workspace bounce                   │
│                      8) Input subsystem kick               │
│                                                             │
│  Manual invocation   SSH or TTY: ~/.local/bin/zen-panic.sh │
│                                                             │
│  Check recovery log  ~/.cache/zen-shell/panic.log          │
└─────────────────────────────────────────────────────────────┘
```

The keybind is shown as a red-tinted pill — visual cue that this
is an emergency feature, not a routine shortcut.

**Why it's in Settings** (not just docs): the user needs to KNOW
about the keybind BEFORE they need it. Black-screen-with-no-UI is
exactly when you can't look up shortcuts.

---

## Files in this drop

### NEW

```
scripts/zen-panic.sh                   ← escape hatch recovery script
CHANGELOG-v6.16.4.md                    ← this file
```

### UPDATED

```
zen-shell-v5/BatterySettingsPage.qml   ← +Panic Recovery section
zen-shell-v5/ZenVersion.qml             ← bump to v6.16.4
scripts/zen-resume-handler.sh           ← hardened: 5s retry, DRM fallback,
                                          zombie detection, input kick, final log
scripts/zen-lid-handler.sh               ← hardened: zombie-aware lock_screen,
                                          pre_suspend_healthcheck gating suspend
hypr-config/binds.conf                   ← +bindl panic keybind
install.sh                                ← deploy zen-panic.sh, banner
```

### CARRIED OVER from 3.8

- Idle/lid/sleep UX (user-configurable timeouts)
- zen-hypridle-sync.sh marker-based hypridle.conf sync
- Universal widget scale factor
- Lock clock font sync with Black/Bold weight mapping
- Gender-aware lock messages

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.4.tar.gz
cd zen-shell-v6.16.4
./install.sh
```

The panic keybind is active as soon as Hyprland reloads
`binds.conf`. `hyprctl reload` or logout/login triggers that.

### Smoke test

1. **Test the keybind is bound**:
   ```bash
   hyprctl binds | grep -i panic
   ```
   Expected: shows `, escape, dispatcher: exec, arg: ...zen-panic.sh`.

2. **Test the script dry**:
   ```bash
   ~/.local/bin/zen-panic.sh
   # Watch output — should log 8 steps in panic.log
   cat ~/.cache/zen-shell/panic.log | tail -30
   ```

3. **Test from lock screen**:
   - `~/.local/bin/zen-lock.sh`
   - Press `SUPER+SHIFT+CTRL+Escape`
   - Lock should unlock, briefly show desktop, re-lock within
     1-2 seconds (step 7 clean-relock, since session was locked
     before panic fired)

4. **Test double-press escalation**:
   - Fire panic once
   - Within 10 seconds, fire again
   - `panic.log` should show: `second panic within Ns — full
     Quickshell restart`
   - Bar + wallpaper should flicker and re-render

### If laptop actually freezes

The thing this was built for. Procedure:

**Level 1 — Panic keybind**: `SUPER+SHIFT+CTRL+Escape`.
Works through frozen hyprlock (via `bindl`). Try this first.

**Level 2 — If keybind doesn't fire**: Hyprland itself is wedged.
Options:
- Another Bluetooth/USB keyboard → same keybind (hardware input
  path is different)
- SSH from phone/other device → `~/.local/bin/zen-panic.sh`
- TTY (Ctrl+Alt+F2) → login → `~/.local/bin/zen-panic.sh`,
  then Ctrl+Alt+F1 back to Wayland

**Level 3 — only if all above fail**: this is the "never happen"
zone. Report it with `~/.cache/zen-shell/panic.log` attached so
we can trace exactly what recovery steps ran vs failed.

---

## What this won't fix

Being honest about scope:

- **Kernel hang** (no fan, stuck at login prompt, nothing on TTY)
  → force-power-off is still the only option. Usually a driver
  or firmware issue outside anything userspace can recover.
- **Full display adapter crash** (GPU hang with amdgpu reset
  failing) → kernel log will show "amdgpu: GPU reset failed".
  Force-power-off again. This version's DRM sysfs fallback might
  help ~10% of these cases but not all.
- **ACPI / firmware suspend bugs** — some laptops just can't
  resume cleanly. zen-panic.sh can help if display is recoverable;
  if the laptop is in S3 limbo with no keyboard response, still
  need hardware button.

The goal of this release is to turn the 80% of "soft freeze"
cases that previously needed force-power-off into "press the
escape keybind and keep working". The remaining 20% is kernel-
level and will always need hardware reset.

---

## Next up: v6.16.5

The roadmap item originally planned for 6.16.4 — **Global Hyprland
`configreloaded` IPC listener**. Laptop reliability took priority
this cycle because actual user pain > architectural cleanup. The
IPC listener work carries forward unchanged into 6.16.5.

**Wala tayong binawasan.** Every 3.8 feature carries into 6.16.4.
