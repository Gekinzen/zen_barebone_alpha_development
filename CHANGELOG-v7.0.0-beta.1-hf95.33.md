# Zen Shell v7.0.0-beta.1-hf95.33 — Karui (軽い)

Release date: 2026-06-01
Channel: beta · Codename: Karui (軽い)

**Docs-only drop: extended the consolidated roadmap with the full
hf86–hf95.32 history + a v7.1 upcoming section, added v7 release notes,
and an internal guide for wiring the in-shell updater to GitHub. No code
changed.** Wala tayong babawasan.

---

## What's added

1. **Roadmap extended** (`zen-shell-v7-roadmap-consolidated.md`, 545→711
   lines — nothing removed):
   - §2 new entry **"hf86–hf95.32"** documenting the quick terminal, SDDM
     greeter + DM switch, the hyprbars-doctor saga, the parked
     HyprbarsMimic title bar, user-clone reliability, and the taskbar/dock
     float + dynamic-sizing + monitor work.
   - New **§8b "Upcoming — v7.1"** (quick-terminal v2, dock v2, SDDM v2,
     generic plugin doctor, user-mgmt v2, multi-monitor polish, settings
     UX).
   - New **§8c** changelog digest of the user-facing features for the
     release notes / site "What's new".

2. **`RELEASE-NOTES-v7.0.0-beta.1.md`** — clean, publishable v7 beta notes
   covering the headline features, install, requirements, upgrader notes.
   (Includes the reminder that the v7 codename is internal/working, not
   the final public reveal.)

3. **`GUIDE-update-system-github.md`** — internal maintainer playbook for
   making **Settings → Updates → Check for updates** work against GitHub:
   the moving parts (`ZenUpdateService`, `zen-update-check.sh`, snapshots,
   `ZenVersion.qml`), how a check works, one-time setup, how to cut a
   GitHub Release (tag format + prerelease flag = channel), snapshot/
   rollback, the version-comparison gotcha, a full test loop, pitfalls,
   and a TL;DR release ritual.

## Version

- `ZenVersion.qml` bumped `hf95.32` → `hf95.33`.

## Files touched

- NEW `zen-shell-v7-roadmap-consolidated.md` (extended copy)
- NEW `RELEASE-NOTES-v7.0.0-beta.1.md`
- NEW `GUIDE-update-system-github.md`
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. No code paths changed.
