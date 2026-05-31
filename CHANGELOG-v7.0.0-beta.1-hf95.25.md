# Zen Shell v7.0.0-beta.1-hf95.25 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**New: `zen-hyprbars-doctor.sh` — a one-shot diagnose + auto-repair for
the recurring hyprpm "Outdated headers" failure. It bypasses hyprpm's
header build entirely and installs hyprbars from AUR against your system
headers.** Wala tayong babawasan.

---

## Why `hyprpm add/enable/reload` keeps failing

`hyprpm update` clones the Hyprland source matching your release TAG and
builds headers from it, then builds the plugin against those headers. On a
git / dirty / CachyOS Hyprland (your 0.55.2 build) there's no exact-match
tagged source hyprpm can resolve, so the header build never succeeds — and
`add`, `enable`, and `reload` ALL depend on those headers, so re-running
them can't help. The headers are the wall.

## The doctor

`zen-hyprbars-doctor.sh` does, in order:

1. **Diagnose** — prints your Hyprland version/commit, whether it's a
   git/dev build, whether an AUR helper (paru/yay) and system headers
   (/usr/include/hyprland) are present, and the current hyprbars/hyprpm
   state. (`--diagnose` stops here, changes nothing.)
2. **Build via AUR** — builds `hyprland-plugin-hyprbars-git` (then stable)
   against your SYSTEM headers — never touching hyprpm's broken header
   build.
3. **Symlink** the built `.so` into hyprpm's plugin dir so Zen Shell's
   PluginsPage detects it.
4. **Load directly** with `hyprctl plugin load` (works even when hyprpm
   marks the plugin failed), then verifies it's listed.
5. **Persist** — tells you the one line to add to `plugins.conf` (or just
   toggle in Settings → Hyprbars).

Safe + idempotent; re-run anytime.

## How to use (your situation)

```
zen-hyprbars-doctor.sh
```

If it reports no AUR helper or no system headers, it tells you exactly
what to install first. The install.sh manual-recovery block now points
here as the easiest fix.

## Version

- `ZenVersion.qml` bumped `hf95.24` → `hf95.25`.

## Files touched

- NEW `scripts/zen-hyprbars-doctor.sh` — diagnose + auto-repair
- `install.sh` — deploy the doctor + reference it in recovery output
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
