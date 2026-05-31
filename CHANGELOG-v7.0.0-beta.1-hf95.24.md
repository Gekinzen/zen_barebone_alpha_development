# Zen Shell v7.0.0-beta.1-hf95.24 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Smart hyprpm/hyprbars install: install.sh now detects your Hyprland
build and routes around hyprpm's version-mismatch failures automatically —
building hyprbars from AUR against your system headers instead of dumping
a wall of errors.** Wala tayong babawasan.

---

## The problem

hyprpm pins plugins to a specific Hyprland release tag and builds them
against headers it fetches for that tag. On a fast-moving / git / CachyOS
Hyprland (e.g. 0.55.2), those headers don't match, the hyprbars build
fails with header/ABI errors, and the old flow just printed manual
recovery steps.

## Smart detection + auto-fallback

New helpers in install.sh:

- `_hypr_detect_version` — reads the exact tag + commit from
  `hyprctl version`.
- `_hypr_is_dev_build` — flags git/dev/dirty builds (and the
  `hyprland-git` package), where hyprpm's pinned headers usually won't
  match.
- `_hypr_have_system_headers` — checks for `/usr/include/hyprland` /
  `pkg-config hyprland`, which AUR plugins can build against directly.
- `_hyprbars_aur_fallback` — builds `hyprland-plugin-hyprbars-git` (then
  stable) via paru/yay against the system headers and symlinks the `.so`
  into hyprpm's dir so the shell detects it.

New flow:

- **Phase 0b** detects the build and prints the version. On a dev build
  WITH system headers, it tries the AUR hyprbars FIRST and skips the
  doomed hyprpm header build entirely.
- **Phase 1** still runs `hyprpm update` for normal (tagged-release)
  setups. If it fails even after `purge-cache`, it now AUTOMATICALLY runs
  the AUR fallback before falling back to manual instructions.

So on your CachyOS 0.55.2 build, hyprbars should now install via AUR
without you touching anything. Requires an AUR helper (paru/yay) and the
`hyprland` package (for headers); if either is missing it explains what to
install.

## Version

- `ZenVersion.qml` bumped `hf95.23` → `hf95.24`.

## Files touched

- `install.sh` — version detection helpers, Phase 0b pre-flight, automatic AUR fallback
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. The manual recovery commands and
`scripts/install-hyprbars.sh` remain as a last resort.
