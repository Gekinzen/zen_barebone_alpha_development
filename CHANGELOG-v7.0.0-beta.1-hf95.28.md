# Zen Shell v7.0.0-beta.1-hf95.28 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The doctor now recognises the "headers ver is not equal to running
hyprland ver" load error and tells you the only real fix: restart the
Hyprland session.** Wala tayong babawasan.

---

## Your current error explained

`[hyprbars] Failure in initialization: Version mismatch (headers ver is
not equal to running hyprland ver)` means the plugin BUILT fine, but
against headers from a DIFFERENT Hyprland version than the one currently
running. This happens after a `pacman -Syu` updates the hyprland
package/headers on disk while your live session is still the old
compositor. A rebuild keeps mismatching until the running Hyprland is
restarted to match the headers — no plugin-side fix can bridge a live
ABI mismatch.

## What changed

When `hyprctl plugin load` fails with a version-mismatch message, the
doctor now:

- Stops and explains clearly that the running compositor ≠ the headers
  the plugin was built for.
- Tells you to **log out and back in (or reboot)**, then re-run the
  doctor — after which they match and hyprbars loads.
- Prints the two commands to confirm the match
  (`hyprctl version | grep Tag` vs `pacman -Q hyprland`).

(The shell's own auto-load is already bounded against retry spam, so the
error toast won't loop endlessly.)

## TL;DR for you

1. `zen-hyprbars-doctor.sh` (will report the mismatch + tell you to
   relogin)
2. **Log out and log back in** (or reboot)
3. `zen-hyprbars-doctor.sh` again → it loads cleanly

## Version

- `ZenVersion.qml` bumped `hf95.27` → `hf95.28`.

## Files touched

- `scripts/zen-hyprbars-doctor.sh` — detect headers≠running mismatch, guide relogin
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
