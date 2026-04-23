# Zen Shell v6.16.4.1 — Panic script hotfix

**Release date:** 2026-04-24
**Base:** v6.16.4
**Severity:** HIGH — v6.16.4 panic keybind had destructive side effects

---

## Bugs fixed

### Bug 1: panic wiped runtime monitor config

> *"nag display off sabay nag on hindi na running quickshell ko
>   tapos yun configure ko nawala like monitors naging default"*

**Root cause**: `zen-panic.sh` step 4 called `hyprctl reload` which
re-reads `hyprland.conf` and **wipes all runtime monitor= keywords**
set via Settings → Displays. User's custom resolution / scale /
refresh rate → reverted to hyprland.conf defaults every panic press.

This is documented in internal notes:
> *`hyprctl reload` wipes runtime keyword state (re-call
> `applyToHyprland()` in onExited)*

I forgot that rule when writing the script. Same bug also lived in
`zen-resume-handler.sh` — flew under the radar because Paul rarely
triggers actual suspend/resume, but panic hit it every press.

**Fix**: Replaced `hyprctl reload` with `hyprctl dispatch
forcerendererreload` in BOTH scripts. `forcerendererreload` does a
KMS-level monitor re-enumeration **without re-reading hyprland.conf
or touching runtime keywords**. Same recovery benefit, zero config
clobbering. Available since Hyprland 0.50+.

Also removed the per-monitor `${mon},preferred,auto,1` loop — it
was overriding user custom resolution / scale even without the full
`reload`. E.g., `eDP-1,2880x1800@90,auto,1.5` reverted to
`preferred,auto,1` (1.0× scale, native mode).

### Bug 2: panic killed Quickshell every single press

> *"hindi na running quickshell ko"*

**Root cause**: step 6 sent `SIGUSR2` to Quickshell thinking it was
a graceful no-op signal. It's not — under default Linux signal
disposition, **unhandled SIGUSR2 terminates the process**. Quickshell
doesn't specifically handle SIGUSR2, so the signal killed it every
panic press.

**Fix**: Removed the SIGUSR2 send entirely. New policy: **single
press NEVER touches Quickshell**. Your bar, widgets, music marquee,
drag positions — all preserved across panic. Only the double-press
escalation path (within 10 seconds) restarts Quickshell via
`zs-restart.sh`, and that's explicitly a last-resort for cases where
single-press recovery didn't help.

### Bug 3: music widget loop + widget animation replay

> *"bakit ganun pati music layer ko nag loloko na pabalik pablik
>   papunta dun sa start to music"*

**Root cause**: two compounding factors —
1. SIGUSR2 killing Quickshell → MusicService re-subscribed to MPRIS
   on respawn → metadata fired multiple times → marquee animation
   restarted from position 0 every panic press
2. Step 8 workspace bounce (`dispatch workspace 2` then back) →
   windows re-ran their enter animations → music widget's
   `Behavior on` properties re-triggered → visible loop

**Fix**:
- Bug 2 fix eliminates factor 1 (no more Quickshell kill → no
  MPRIS re-subscribe)
- Removed workspace bounce entirely (both scripts) → factor 2
  eliminated

Step 3 (DPMS cycle) + step 4 (forcerendererreload) already force
a paint pass at the compositor level. The workspace bounce was
redundant belt-and-suspenders with real animation side effects.

---

## Verified in 4.1 — what panic does now

### Single press

```
Step 1 — SIGKILL hyprlock ONLY if zombie detected (layer count = 0)
Step 2 — Wait for hyprctl IPC (up to 3s)
Step 3 — Double DPMS off→on cycle
Step 4 — forcerendererreload (preserves runtime monitor config)
Step 5 — swww-daemon revive if zombied + wallpaper re-apply
Step 6 — SKIP (no Quickshell touch)
Step 7 — Clean re-lock if session was locked pre-panic
Step 8 — SKIP (no workspace bounce)
Step 9 — (via resume handler on actual resume) input subsystem kick
```

End result: monitors stay configured · Quickshell stays running ·
music widget stays put · widgets keep their drag positions. Only
the actually-wedged pieces get fixed.

### Double press (within 10s)

Same as single press, PLUS step 6 escalates to full Quickshell
restart via `zs-restart.sh`. This is now explicitly a last-resort
when single-press wasn't enough.

---

## Files changed from 4.0

```
UPDATED
  scripts/zen-panic.sh                    ← 3 bug fixes
  scripts/zen-resume-handler.sh            ← same reload + bounce fixes
  zen-shell-v5/BatterySettingsPage.qml    ← description text updated
  zen-shell-v5/ZenVersion.qml              ← v6.16.4.1
  install.sh                                ← banner
NEW
  CHANGELOG-v6.16.4.1.md                   ← this file
```

Everything else from 4.0 carries byte-identical.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.4.1.tar.gz
cd zen-shell-v6.16.4.1
./install.sh
hyprctl dispatch forcerendererreload
# or logout/login to refresh binds
```

### Smoke test

1. **Set up distinctive monitor config first** — go to Settings →
   Displays → set eDP-1 or whatever monitor to a non-default
   resolution/scale. Confirm with:
   ```bash
   hyprctl monitors | grep -A 3 eDP
   ```

2. **Fire panic**: `SUPER+SHIFT+CTRL+Escape`

3. **Verify nothing got wiped**:
   ```bash
   hyprctl monitors | grep -A 3 eDP    # should match step 1
   pgrep -f 'quickshell.*zen-shell'     # should return PID
   ```
   If either fails, something still wipes state — capture
   `~/.cache/zen-shell/panic.log` and report.

4. **Music widget test** — start playing music, check the marquee
   is mid-animation. Press panic. Marquee should KEEP playing from
   where it was, not jump back to start.

5. **Double-press test** — press panic twice within 10s. Second press
   should log `DOUBLE-PRESS detected — full Quickshell restart`.
   Bar respawns, widgets re-render. This is the ONLY time Quickshell
   should restart now.

### Read the panic log to verify

```bash
cat ~/.cache/zen-shell/panic.log | tail -30
```

Expected lines on single press (new behavior):
```
step 4: force renderer reload (preserves runtime config)
step 6: quickshell running — leaving untouched (press again within 10s to force restart)
step 8: workspace bounce SKIPPED in 4.1 (was causing animation replay bug)
```

If you see `hyprctl reload` or `SIGUSR2` in the log, something went
wrong — the 4.1 script wasn't properly deployed.

---

## What panic still fixes (unchanged from 4.0)

- Frozen/zombie hyprlock → SIGKILL + clean relaunch
- Black screen after wake → DPMS double cycle + forcerendererreload
- swww-daemon zombie → kill + restart + wallpaper re-apply
- Keystrokes not reaching password field → input subsystem kick
  (on actual resume via zen-resume-handler.sh)
- Display KMS wedge → DRM sysfs fallback (via resume handler)

Core value proposition holds: `SUPER+SHIFT+CTRL+Escape` still your
escape hatch. Just now it doesn't destroy more than it fixes.

---

## Apologies, pre

4.0 was too aggressive. Should've tested the side effects more
carefully before shipping. The SIGUSR2 thing especially — I wrote
"Quickshell ignores unknown signals gracefully" in the comment
without verifying. Default Linux signal dispositions don't work
that way for USR2.

Thanks for catching all three bugs in one test run — the music
widget behavior was the tell-tale that pointed me at the signal +
bounce issues.

---

## Next up

Still **v6.16.5** for the `configreloaded` IPC listener (deferred
from original 6.16.4 plan). 4.1 is pure hotfix — no new features.
