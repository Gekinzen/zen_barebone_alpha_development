# v7.0.0-beta.1-hf82x — Icon detection fix + style rename

**Channel:** beta (hotfix on hf82w)
**Released:** 2026-05-26
**Scope:** 1 critical bug fix + 1 rename + auto-migration

## Two changes

### 1. Real icons on desktop (the critical fix)

**The bug**: hf82t-w tried to resolve desktop file icons via
`Quickshell.iconPath(basename, true)` — freedesktop icon theme lookup
by name. This only works when there's a themed icon literally named
"steam" or "surviving-mars". For Lutris game shortcuts or any file
named after a `.desktop` `Name=` field, the icon name on disk is
something like `lutris_surviving-mars` and the theme lookup misses
entirely. Result: generic file glyph for everything that wasn't a
direct theme name match.

**The fix**: walk `AppLauncherService.apps` (which wraps Quickshell's
own `DesktopEntries.applications` — same source the App Float Rules
page uses) and match the file's basename against each installed
`.desktop`'s `Name=` AND `id` fields. First match → use that app's
`Icon=` field → resolve via theme. Plus a looser "contains" match
fallback (so "Surviving Mars Demo" finds the "Surviving Mars" icon).

Result: `steam`, `Surviving Mars`, `Crimson Desert`, `Reverse 1999`,
`net.lutris.nte-1` etc. all show their real app icons.

The lookup order is now:
1. Absolute path Icon=/path/foo.png (use directly)
2. `entry.iconName` themed (works for files whose iconName already resolved)
3. ★ NEW ★ Exact match `app.name` or `app.id` vs file basename → `app.icon`
4. ★ NEW ★ Substring match (case-insensitive) for partial-name files
5. Lowercased basename via theme (legacy hf82t path)
6. Glyph fallback

### 2. Renamed compact / squircle styles (trademark safety)

`Pixel` and `Samsung` are registered trademarks. hf82w used those names
internally and in the UI, which is a trademark infringement risk —
especially for `Samsung` since Samsung holds patents on the
drop-to-create-folder gesture and the One UI squircle aesthetic.

Renamed:
- `"pixel"` style → `"compact"` (small dense icons, hover labels)
- `"samsung"` style → `"squircle"` (squircle icons, drop-to-folder gesture)

All UI strings, comments, and JSON state values updated. The
drop-to-folder mechanic and squircle visual are still implemented —
just under generic, non-trademark names.

**Auto-migration**: install.sh detects any user state with the legacy
values and silently rewrites them to the new ones. Backup at
`.pre-hf82x-<timestamp>` for safety.

## Files

| File | Change |
|---|---|
| `DesktopIcon.qml` | Rewrote `_iconSource` to walk AppLauncherService.apps + renamed style refs |
| `DesktopIconsState.qml` | Renamed style enum values + comments |
| `DesktopPage.qml` | Updated Style dropdown model + description |
| `DesktopSurface.qml` | Renamed style checks |
| `DesktopFoldersState.qml` | Renamed comments |
| `DesktopFolderPopup.qml` | Renamed comments |
| `install.sh` | Added auto-migration for desktop-icons.json |
| `ZenVersion.qml` | hf82w → hf82x |

## Install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82x.tgz
cd zen-shell-v7.0.0-beta.1-hf82x
./install.sh
pkill -f quickshell && sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

If you toggled Style → "samsung" or "pixel" under hf82w, the install
will auto-rename to "squircle"/"compact" — your selection is preserved
across the rename.

## Verify

1. **Real icons now show**: `~/Desktop` items like `steam`, `Surviving Mars`,
   `Crimson Desert` should display their actual app icons (not generic glyph)

2. **Migration ran** (if you had pixel/samsung selected):
   ```bash
   ls ~/.local/share/quickshell/zen-shell/desktop-icons.json.pre-hf82x-*
   ```

3. **New names in UI**: Settings → Desktop → Style dropdown shows
   `default / compact / squircle`

4. **All other hf82w features still work**: drop-to-folder gesture in
   squircle style, hover-only labels in compact style, hyprbars instant
   load via systemd service.

## Open threads

- Drag-easier toggle
- Profile setup popup positioning
- Dock Phase 2 / Phase 3
