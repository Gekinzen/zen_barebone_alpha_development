# Zen Shell v7.0.0-beta.1-hf95.30 — Karui (軽い)

Release date: 2026-06-01
Channel: beta · Codename: Karui (軽い)

**Taskbar icons now FLOAT inside the bar with padding all around (like the
dock), so the window-count / workspace / minimize badges are visible and
you get the obvious floating look. Plus a hyprbars troubleshooting guide
now that the doctor works.** Wala tayong babawasan.

---

## Taskbar icons float (like the dock)

Taskbar icons filled the full bar height edge-to-edge (`btnSize =
Theme.moduleHeight`), leaving no room around them. Now there's an
`iconPadding` (~7px, scales with the bar's content scale) and `btnSize =
moduleHeight − 2·padding`, so each icon sits in a floating box with
breathing room — same idea as the dock's `contentPadding`. The existing
vertical-centering keeps them centered, so the badges below each icon are
visible.

- Typical 40px bar → 26px icon, 7px float each side.
- Clamped to a sane minimum (18px) on very short bars.
- Vertical-bar mode benefits too (same `btnSize`).

If you want them larger/smaller, it's the single `iconPadding` value.

## Hyprbars troubleshooting guide

Added `TROUBLESHOOTING-hyprbars.md` documenting `zen-hyprbars-doctor.sh`:
what it checks (build detection, version skew, hyprpm purge-cache + retry,
AUR fallback against system headers, direct load), why the "Outdated
headers" / "headers ver != running" errors happen, prerequisites, and how
to make hyprbars persistent. (The doctor itself is unchanged this
release — it's working.)

## Version

- `ZenVersion.qml` bumped `hf95.29` → `hf95.30`.

## Files touched

- `zen-shell-v5/Taskbar.qml` — floating icons via iconPadding
- NEW `TROUBLESHOOTING-hyprbars.md`
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
