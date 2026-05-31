# v7.0.0-beta.1-hf82t — windowrule deprecation + real desktop icons (taskbar-style)

**Channel:** beta (hotfix on hf82s)
**Released:** 2026-05-26
**Scope:** 4 files (WindowRulesService, DesktopIcon, install.sh, ZenVersion)

## Bugs fixed

### Bug 1: Hyprland config error when toggling app float
- **Root cause**: hf82n-s wrote `windowrulev2 = float, class:^(NAME)$` to
  zen-window-rules.conf. The `windowrulev2` keyword was deprecated in
  Hyprland 0.42 (about a year ago) and on Hyprland 0.55+ it now triggers
  a visible config-error overlay at the top of the screen. Per upstream
  discussion #13115: "windowrulev2 was deprecated almost a year ago. All
  it did up until now was to send it to windowrule and call it a day."
- **Fix**:
  1. `WindowRulesService._writeFile()` now writes `windowrule = ...`
     (drop the `v2` suffix — syntax otherwise identical)
  2. Parser regex updated to accept BOTH keywords so existing toggles
     from hf82n-s aren't lost (auto-migrated on next toggle)
  3. install.sh adds a one-time sed-based migration that rewrites any
     existing `windowrulev2` lines in zen-window-rules.conf to plain
     `windowrule`. Backup created at .pre-hf82t-<timestamp>. Idempotent.
- **Compat**: `windowrule` works on Hyprland 0.42 through 0.55+ unchanged.
  The new syntax is the canonical form going forward and the only one
  that doesn't trigger deprecation warnings on 0.55+.

### Bug 2: Desktop icons show generic file glyph instead of real app icons
- **Root cause**: hf82s only tried `Quickshell.iconPath(iconName, true)`
  where iconName was MIME-based (e.g. "text-x-generic"). Files like
  `steam`, `Surviving Mars`, `Crimson Desert` got generic glyphs even
  though their matching .desktop launchers exist in
  /usr/share/applications/ or ~/.local/share/applications/.
- **Fix**: copy the EXACT pattern the taskbar uses for running apps:
  `Quickshell.iconPath(appId, true)` does best-match lookup against the
  freedesktop icon theme by app id (basename of .desktop file). For
  desktop icons, hf82t now tries the same lookup against the filename
  basename — so `steam` → Steam logo, `Surviving Mars` → game icon if
  Lutris/Steam-installed, etc. Falls back to MIME-based generic icon
  only when no match found.
- **Algorithm**:
  1. Absolute Icon= path → use directly (`file://` prefix)
  2. Theme lookup by iconName (existing behavior)
  3. ★ NEW ★ Lowercased basename match (`steam` → steam icon)
  4. ★ NEW ★ First-word match (`Surviving Mars` → surviving)
  5. Glyph fallback

## Files

| File | Change |
|---|---|
| `WindowRulesService.qml` | Writer: `windowrulev2` → `windowrule`. Parser: accept both. |
| `DesktopIcon.qml` | Icon resolution: add taskbar-style filename lookup |
| `install.sh` | sed migration for existing zen-window-rules.conf |
| `ZenVersion.qml` | hf82s → hf82t |

4 modified files. 0 new, 0 removed.

## Install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82t.tgz
cd zen-shell-v7.0.0-beta.1-hf82t
./install.sh
pkill -f quickshell && sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

The install.sh's migration step will fire automatically if you toggled
any apps under hf82n-s, migrating the existing windowrulev2 lines.

## Verify

1. **Hyprland error gone**: Toggle Brave float ON sa App Float Rules,
   should NOT see "deprecation" error overlay at top.
2. **Real icons**: `~/Desktop` items like `steam`, `Lutris`, `Brave-browser`
   should show their real app icons (not generic file glyph).
3. **Migration log**: Watch for "Migrated deprecated 'windowrulev2' → 'windowrule'"
   in install.sh output (only if you had any existing toggles).
4. **Backup created**: `ls ~/.config/hypr/modules/zen-window-rules.conf.pre-hf82t-*`
   should show a timestamped backup if migration ran.

## Open threads (still active)

- Drag-easier-on-mouse-down (your 3rd question, awaiting your pick)
- Samsung folder-style icon groups (hf82s-equivalent feature deferred)
- Profile setup popup positioning
- Dock Phase 2 / Phase 3
