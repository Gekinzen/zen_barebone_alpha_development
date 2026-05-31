# v7.0.0-beta.1-hf62 — Heavy recovery (atomic rebuild + load)

**Channel:** beta (hotfix)
**Released:** 2026-05-18
**Branch:** `dev`

---

## What this hotfix fixes

User report (after installing hf61):

> Screenshot showing diagnostic card:
> "No hyprbars*.so found in any hyprpm location
> (checked $XDG_RUNTIME_DIR/hyprpm, ~/.local/share/hyprpm,
> ~/.cache/hyprpm) — plugin build failed. Run in terminal: hyprpm update -v"

But the earlier terminal output (from running `hyprpm update -v`)
clearly showed:

```
✓ built hyprbars into hyprbars/hyprbars.so
make: Leaving directory '/run/user/1000/hyprpm/paul/hyprbars'
```

So the .so WAS built. But by the time Zen Shell tried to find it,
the directory was empty.

---

## The actual mechanism

Modern hyprpm (Hyprland 0.50+) does its work entirely in
`$XDG_RUNTIME_DIR/hyprpm/$USER/`, which is **tmpfs**:

1. `hyprpm update` clones repos + compiles .so files there
2. `hyprpm reload` reads the build state, runs
   `hyprctl plugin load` on **enabled** plugins
3. After reload exits, the runtime build dir typically gets cleaned

This is by design — keeps state fresh per session, no stale builds
across reboots. But it means the .so only exists on disk during
a narrow window: **between the build finishing and hyprpm reload
exiting**.

Critical observation from Paul's terminal output:

```
✓ Ensuring plugin load state
✓ Loaded borders-plus-plus     ← only borders, NOT hyprbars
✓ Plugin load state ensured
```

borders-plus-plus loaded, but hyprbars didn't. That tells us
**hyprbars isn't in hyprpm's enabled list**. So when `hyprpm
reload` runs, it loads borders but skips hyprbars. The hyprbars
.so was built (visible in output), briefly existed on disk, then
got cleaned up — never injected into Hyprland.

Our Zen Shell auto-load then runs `hyprctl plugin load <so>` but
the .so is already gone. Light auto-load loops 3 times finding
nothing. Exhausts.

---

## Fix — heavy recovery atomic chain

When lightweight auto-load exhausts AND we haven't tried heavy
recovery yet this session, fire a single atomic bash command that
exploits the ~5-10s window where the .so is on disk:

```bash
hyprpm enable hyprbars            # (idempotent — ensures enabled)
hyprpm reload                     # (rebuilds + loads enabled plugins)
# Verify if hyprpm already loaded it
if hyprctl plugin list | grep -qi hyprbars; then
  STATUS=ok-via-hyprpm; exit 0
fi
# Otherwise find the freshly-built .so and manual-load while it's still on disk
[multi-location find]
hyprctl plugin load "$SO"
# Verify final state
```

All in **one** bash process so the runtime tmpfs doesn't get
cleaned between commands. This is the difference between hf59-61's
sequential approach (multiple separate bash invocations, gap
between them) and hf62's atomic approach.

### Bounded by once-per-session

Heavy recovery rebuilds the .so (~5-10s blocking), so we don't
want it running every 30s on the watchdog. New flag:

```qml
property bool _heavyRecoveryAttempted: false
```

Set to true after first heavy attempt. Light auto-load won't
escalate to heavy again until the user explicitly takes action
(install / enable / manual load / heavy rebuild buttons all reset
the flag).

### Settings UI

New orange **"Rebuild + load"** button beside Force load. Bypasses
the once-per-session cap — manual click always allowed:

```
[Install / reinstall] [Update plugin] [Check status] [Force load] [Rebuild + load]
                                                                   ^^^^^^^^^^^^^^^
                                                                   NEW (orange)
```

While heavy recovery is running, button text changes to
"Rebuilding…" and the badge shows
"Heavy recovery in progress — rebuilding via hyprpm…"

---

## Badge states surfaced

```
●  Plugin loaded in Hyprland — bars active                  (green)
●  Heavy recovery in progress — rebuilding via hyprpm…      (yellow)
●  Auto-loading plugin… (attempt 2 of 3)                    (yellow)
●  Auto-load exhausted — heavy recovery will start…         (red)
●  Heavy recovery exhausted — click 'Rebuild + load' or…    (red)
●  Plugin NOT verified loaded — click 'Check status'…       (red)
```

Diagnostic card surfaces specific reasons when heavy recovery
itself can't leave a .so on disk:

> hyprctl plugin load error: hyprpm reload didn't leave .so on disk
> and plugin not loaded — likely hyprpm did not enable hyprbars
> (try: hyprpm list | grep hyprbars in terminal)

So if the root issue is actually "hyprpm forgot hyprbars is
enabled," the user gets pointed straight at the verification
command.

---

## Files modified (4)

```
zen-shell-v5/HyprbarsService.qml       — _heavyRecoveryAttempted +
                                          _heavyRecoveryInProgress
                                          properties, heavyRecoveryProc
                                          Process, _heavyRecoveryCmd()
                                          atomic command builder,
                                          verifyProc escalation logic,
                                          triggerHeavyRecovery() public
                                          function, user-action resets
zen-shell-v5/HyprbarsSettingsPage.qml  — orange Rebuild + load button,
                                          badge text + dot color updated
                                          to include heavy recovery
                                          states
zen-shell-v5/ZenVersion.qml            — bumped to hf62
install.sh                              — banner + changelog entry
```

**No core framework changes. All hyprbars-scoped.**

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf62-heavy-recovery.tgz
cd zen-shell-v7.0.0-beta.1-hf62
./install.sh
pkill quickshell
```

---

## What to expect

### On boot

1. ~800ms: state loads, verify fires
2. Plugin not loaded → light auto-load attempts 1/3
   - Light load fires `hyprctl plugin load <so>` — fails (no .so)
3. ~600ms later: re-verify → still not loaded → attempt 2/3
4. Same: fails
5. Attempt 3/3 — fails
6. Auto-load exhausted → **heavy recovery escalates automatically**
7. Badge: 🟡 yellow "Heavy recovery in progress — rebuilding via hyprpm…"
8. ~5-10s: hyprpm builds .so, reloads, finds it, manual-loads it
9. **Badge turns 🟢 green: "Plugin loaded in Hyprland — bars active"**
10. Bars appear on Brave / terminal / floating windows

Total boot-to-bars time: ~12-15 seconds. Slower than I'd like
but it's the cost of the upstream tmpfs cleanup behavior.

### If heavy recovery also fails

Most likely cause: hyprpm doesn't have hyprbars in its enabled
list at all. Diagnostic card will say:

> hyprctl plugin load error: hyprpm reload didn't leave .so on disk
> and plugin not loaded — likely hyprpm did not enable hyprbars
> (try: hyprpm list | grep hyprbars in terminal)

Manual fix:

```bash
hyprpm list | grep -A2 hyprbars
# If "enabled: false" or hyprbars missing entirely:
hyprpm enable hyprbars
hyprpm reload
hyprctl plugin list   # should now show hyprbars
```

Then click **"Rebuild + load"** in Zen Shell Settings → Hyprbars
to re-fire the recovery.

### If you don't want auto-recovery

Settings → Hyprbars → toggle "Auto-load on boot / reload" OFF.
Heavy recovery won't auto-trigger. Use the orange "Rebuild + load"
button manually when needed.

---

## Hyprbars hotfix journey (11 attempts)

| Hotfix | Theory | Result |
|---|---|---|
| hf52 | Just install + enable | Worked once, wrong floating-only syntax |
| hf53-56 | Tweak windowrule syntax | All variants errored |
| hf57 | Gate windowrules on plugin state | Errors gone, no bars |
| hf58 | Diagnostic + manual button | Need to click every reload |
| hf59 | Auto force-load + watchdog | Auto-load couldn't find .so |
| hf60 | Surface load error to UI | Showed "exhausted" with no detail |
| hf61 | Fix .so search path (XDG_RUNTIME) | Search location correct but .so cleaned up |
| **hf62** | **Atomic rebuild + load (heavy recovery)** | **Rebuilds .so + loads in one shell command before tmpfs cleanup** |

The Layered approach worked — each hotfix surfaced one more layer.
hf62 wouldn't have been findable without hf60's stderr capture or
hf61's multi-location search. We needed to see the .so was being
built but then disappearing, which required all three of those
diagnostic surfaces to make visible.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf61 multi-location .so search (XDG_RUNTIME_DIR + legacy)
- ✅ hf60 lastLoadError / soPath / soExists surfaces
- ✅ hf60 mimic gating + showMimicFallback opt-in
- ✅ hf59 auto force-load + Hyprland reload watchdog
- ✅ hf58 7-step diagnostic + manual Force load button
- ✅ hf57 plugin verify gate + portable tilde paths
- ✅ hf56 block windowrule syntax (gated)
- ✅ hf55 auto-rewrite timer
- ✅ hf54 mimic layout
- ✅ hf53 popup mimic foundation
- ✅ hf52 hyprbars integration
- ✅ hf51-32 all preserved

🍃 Pre, install + reload. Mag-aabang ka ng around 12-15 seconds —
yung heavy recovery na nagtatakbo. If 🟢 green badge na, ayos
tayo. If hindi pa rin, screenshot mo yung diagnostic card text —
yun ang magsasabi exactly anong susunod na step (likely magrun ka
lang ng `hyprpm enable hyprbars && hyprpm reload` sa terminal once,
then click "Rebuild + load" sa Settings).
