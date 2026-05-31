# v6.16.4.12.9.1 — Modori (戻り) · hotfix 1

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9 — Modori

## Summary

Single-purpose hotfix on Modori. User reported that the avatar +
username appears TWICE in the Settings window: once at the bottom
of the left sidebar (added in v6.16.4.12.7 Tachiagari) and again
in the title bar's right side (added in Modori .9). Both render
the same identity, side by side in the same window — pure
visual duplication.

User asked for the title-bar version to go; the sidebar bottom
row stays.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.1. |
| `zen-shell-v5/ZenSettings.qml` | Title-bar user pill block removed (~115 lines deleted: outer Rectangle, inner RowLayout with avatar + username, ids `titleUserPill` / `titleUserRow` / `titleUserMa` / `titleAvatarImg` / `titleAvatarMask`, full OpacityMask shader plumbing). The Settings title bar reverts to its pre-Modori layout: gear icon + "Settings" text + drag handle on the left, Maximize + Close buttons on the right, no user pill in between. The sidebar bottom user row (Tachiagari .7) is unaffected and still surfaces the avatar + username + @hostname. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped to .9.1. |
| `CHANGELOG-v6.16.4.12.9.1.md` | NEW (this file). |

## Detail

The title-bar pill was added in Modori based on a reading of the
user's earlier request as "show the avatar + username on the right
side of the main content area, not just the sidebar." With the
sidebar bottom row already covering "the user's identity is visible
in Settings," the title-bar version turned out to be redundant —
both surfaces render the same name + same avatar in the same
visible window at the same time.

Removing the title-bar pill leaves the sidebar bottom row as the
single canonical place to surface user identity in Settings. The
sidebar version is also more informative (shows `@hostname` too,
which the title-bar version dropped to save horizontal space).

## Carry-forward from Modori .9

All Modori fixes preserved:

- Theme.layoutLoader stop reading stale `style` from
  bar-layout.json (settings persistence fix)
- `saveState()` debounced through 200ms Timer (slider-drag
  corruption fix)
- All Tachiagari .7.1 features: 4-direction popup helpers, 4-card
  Panel Position picker, pill module shape fix, sidebar user row,
  Smart Gaming Detection, Start Button border tint, monitor-fix v2

## Wala tayong babawasan

Pure deletion of a redundant element. The information itself
(avatar, username) is fully preserved in the sidebar. No behavior
change, no data loss, no migration needed.
