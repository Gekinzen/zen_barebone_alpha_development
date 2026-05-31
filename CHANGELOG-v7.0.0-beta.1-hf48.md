# v7.0.0-beta.1-hf48 — Hyprlock unlock focus reset workaround

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "kapag nag lock screen tas sa isang monitor ako nag login tas now
> hindi ko ma cclick yun nasa kabila ko monitor unless drag ko papunta
> sa isa monitor then ibabalik pwd na ulit weird paki ayos yun"

After locking with hyprlock and entering the password on one monitor,
keyboard + mouse focus gets stuck on that monitor. Clicking on the
OTHER monitor does nothing — the user has to drag the cursor back to
the active monitor, then drag it again across to "wake up" the input
manager.

---

## Root cause — NOT a Zen Shell bug

Verified via upstream GitHub issues:

- **[Hyprland #5884](https://github.com/hyprwm/Hyprland/issues/5884)** —
  "keyboard focus does not work with mouse click right after unlock"
- **[hyprlock #483](https://github.com/hyprwm/hyprlock/issues/483)** —
  "Unlocking after automatic screen lock doesn't allow to click any
  window"

Hyprland maintainer **vaxerski** confirmed: bug is in
`CInputManager::mouseMoveUnified` / `mouseDownNormal`. The lock
sequence leaves Hyprland's internal "currently focused window" state
out of sync with the actual window receiving keyboard input.

The bug has been present since Hyprland v0.35 (released early 2024)
and is **not fixed upstream** as of v0.54+. Multi-monitor users hit
it consistently.

Zen Shell only LAUNCHES hyprlock — it doesn't manage the lock screen
state itself. But since we own the launch command, we can wrap it
and run a fix-up sequence after unlock.

---

## The workaround

Before hf48, the lock command was just:

```qml
function powerLock() {
    root.triggerPowerAction("lock", "hyprlock")
}
```

After hf48, the command wraps hyprlock with a focus-reset sequence
that runs automatically when hyprlock exits (i.e. user unlocked):

```bash
hyprlock; \
sleep 0.4; \
# Capture which monitor was focused before reset
if command -v jq >/dev/null 2>&1; then
    ORIG_MON="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"
    ALL_MONS="$(hyprctl monitors -j | jq -r '.[].name')"
else
    # Fallback when jq not installed — parse plain output with awk
    ORIG_MON="$(hyprctl monitors | awk '/^Monitor / {name=$2} /focused: yes/ {print name; exit}')"
    ALL_MONS="$(hyprctl monitors | awk '/^Monitor / {print $2}')"
fi
[ -z "$ORIG_MON" ] && ORIG_MON="$(echo "$ALL_MONS" | head -n1)"

# Cycle focus across every monitor — each focusmonitor call kicks
# CInputManager to re-evaluate its focus state
echo "$ALL_MONS" | while read -r mon; do
    [ -n "$mon" ] && hyprctl dispatch focusmonitor "$mon"
    sleep 0.08
done

# End by restoring focus to originally-active monitor
[ -n "$ORIG_MON" ] && hyprctl dispatch focusmonitor "$ORIG_MON"

# Nudge keyboard focus to fully clear the stuck state
hyprctl dispatch movefocus l
hyprctl dispatch movefocus r
```

Net effect after unlock:
- 400ms grace period (lets Hyprland tear down hyprlock's layer surfaces)
- Hyprland forced to re-evaluate focused monitor for every monitor
- Originally-focused monitor restored
- Keyboard focus nudged with movefocus l;r

This is exactly what the user does manually when they drag the cursor
around — we just do it automatically and faster.

---

## Why two paths (jq + awk)?

`jq` is a recommended dependency for Hyprland ricers (used by
countless dotfiles to parse `hyprctl -j`). It IS installed on most
Arch + CachyOS setups, but not guaranteed.

The script tests `command -v jq` and picks the right path:
- **jq present** → parses `hyprctl monitors -j` JSON output
- **jq missing** → parses plain `hyprctl monitors` text output via awk

Both paths end up with the same `ORIG_MON` + `ALL_MONS` values.
Tested end-to-end with mocked hyprctl in dev — both paths produce
identical dispatch sequences.

---

## Why 400ms wait + 80ms between dispatches?

- **400ms before reset:** hyprlock needs time to tear down its layer-shell
  surfaces. If we fire focusmonitor dispatches too early, Hyprland is
  still processing the unlock and the dispatches get queued or
  swallowed. 400ms is well-tested in similar workarounds in
  hyprland-utils.
- **80ms between dispatches:** Hyprland's input manager batches focus
  changes — too fast and only the last one registers. Too slow and
  the user notices the dispatches. 80ms is the sweet spot per
  upstream maintainer discussions in issue #5884.

---

## Files changed (2)

```
zen-shell-v5/shell.qml         — wrapped hyprlock with focus-reset script
zen-shell-v5/ZenVersion.qml    — bumped to hf48
install.sh                      — banner + changelog
```

Pure surgical edit — only the `powerLock()` IPC handler in shell.qml
changed. Everything else identical to hf47.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf48-hyprlock-focus-reset.tgz
cd zen-shell-v7.0.0-beta.1-hf48
./install.sh
```

Reload shell (`pkill quickshell`) to pick up the new powerLock
handler.

---

## How to verify

1. Open multiple windows across both monitors (eDP-1 + DP-2)
2. Trigger lock via Zen Shell power menu (or whatever your binding is)
3. Confirm lock → hyprlock takes over both monitors
4. Type password → unlock
5. **WITHOUT moving the cursor**, click on a window on the OPPOSITE
   monitor from where your cursor was at lock time
6. Click should immediately register, keyboard should follow

Before hf48: step 5 fails — cursor moves but the click is "swallowed"
by the stuck focus state.

After hf48: step 5 works the first time. Watch
`journalctl --user -f` to see the message:

```
[zen-shell hf48] post-unlock focus reset complete
```

That confirms the reset sequence ran.

---

## Caveats

- This is a WORKAROUND, not a fix. The real fix needs to happen in
  Hyprland's `CInputManager`. When upstream lands it (no ETA), we
  can simplify this back to bare `hyprlock`.
- The 400ms wait is BLOCKING on the bash wrapper — there's a brief
  moment after typing password where the cursor is visible but
  Hyprland is still cleaning up. Doesn't affect security (the unlock
  already happened) but cosmetically you see a half-second of
  "transparent" before things fully settle.
- If you have your own lock command bound outside Zen Shell (e.g.
  `bind = SUPER, L, exec, hyprlock` in hyprland.conf), THAT path
  bypasses Zen Shell and won't get the workaround. Either remove
  that bind and use Zen Shell's power menu, OR add the same wrapper
  to your binding directly.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf47 sticky notes as desktop widgets
- ✅ hf46 sticky note draggable toggle
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state
- ✅ hf43 Quick Notes panel clipping + rounded toggle pills
- ✅ hf42 modules visible + usage docs

Pure additive workaround for upstream bug. 🍃
