# Zen Shell v7.0.0-beta.1-hf95.26 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The hyprbars doctor now (1) detects the real cause of your "hyprpm says a
different version than hyprctl" error — a pacman upgrade that needs a
relogin — and (2) tries `hyprpm update` automatically (with sudo) before
falling back to the AUR build.** Wala tayong babawasan.

---

## Your exact situation

A recent `pacman -Syu` (the one that pulled VLC) also upgraded the
`hyprland` package. Your RUNNING session is still the old binary, so:

- `hyprctl version` reports the OLD version
- `hyprpm` checks the NEWLY INSTALLED version
- they disagree → hyprpm refuses to build ("version mismatch")

No script can bridge this from inside the session — the compositor must
be restarted.

## What changed in the doctor

1. **Version-skew detection.** It now compares the RUNNING version
   (`hyprctl`) against the INSTALLED package (`pacman -Q hyprland`). If
   they differ, it stops with a clear message: **log out and back in (or
   reboot), then re-run the doctor.** After relogin they match and the
   build works. Nothing is changed while skewed.

2. **Automatic `hyprpm update` (with sudo).** When versions are in sync,
   the doctor now pre-seeds sudo and runs `hyprpm update` →
   `hyprpm add … hyprland-plugins` → `hyprpm enable hyprbars` →
   `hyprpm reload` automatically. If that succeeds, you're done. If it
   hits the header/version failure, it falls straight through to the AUR
   build against your system headers (no manual step).

So the full auto order is now: relogin-check → hyprpm update (sudo) →
AUR fallback → direct `hyprctl plugin load`.

## How to use

```
zen-hyprbars-doctor.sh
```

If it says versions are skewed: log out/in (or reboot), then run it again
— it'll proceed through hyprpm/AUR automatically.

## Version

- `ZenVersion.qml` bumped `hf95.25` → `hf95.26`.

## Files touched

- `scripts/zen-hyprbars-doctor.sh` — version-skew detection + automatic hyprpm update (sudo)
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
