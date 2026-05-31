# v7.0.0-beta.1-hf82y — File-system icon search (the real fix)

**Channel:** beta (hotfix on hf82x)
**Released:** 2026-05-26

## The bug

For 4 hotfixes (hf82t → hf82w → hf82x) I tried to fix desktop icons by
calling `Quickshell.iconPath(name, true)`. The diagnostic finally
revealed why it kept failing:

User has Steam game launchers on `~/Desktop`:
- `Crimson Desert.desktop` with `Icon=steam_icon_3321460`
- `Reverse 1999.desktop` with `Icon=steam_icon_3092660`
- etc.

These icons live in `~/.local/share/icons/hicolor/256x256/apps/`
(installed by Steam). `Quickshell.iconPath()` doesn't always find them
because the user's icon dir isn't reliably in its theme search path.

Every attempt at theme lookups, app-launcher matching, and fuzzy name
matching missed this — the icons exist, just not where the theme spec
expects them.

## The fix

`DesktopIconsService._resolveDesktopIcon` now also does a file-system
search at scan time. For each `Icon=<name>` it reads from a .desktop,
it searches:

```
$XDG_DATA_HOME/icons      (~/.local/share/icons)
~/.icons
/usr/local/share/icons
/usr/share/icons
/usr/share/pixmaps
```

For `<name>.{png,svg,xpm}`. If found, the absolute path is stored as
`entry.iconAbsPath`. `DesktopIcon._iconSource` uses this as Stage 0
(highest priority) — `file://<absolute-path>` — bypassing theme lookup
entirely.

This is the same pattern Thunar/Nautilus/Dolphin use.

## Files

| File | Change |
|---|---|
| `DesktopIconsService.qml` | `_resolveDesktopIcon` extended with bash file-system search; `_patchEntryIcon` accepts absPath; entry shape gains `iconAbsPath` |
| `DesktopIcon.qml` | New Stage 0 in `_iconSource`: use `iconAbsPath` if set + debug logging |
| `ZenVersion.qml` | hf82x → hf82y |

3 modified files. 0 new, 0 removed.

## Install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82y.tgz
cd zen-shell-v7.0.0-beta.1-hf82y
./install.sh
pkill -f quickshell && sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

## Verify

```bash
journalctl --user -n 200 --no-pager | grep DesktopIcon | head -20
```

Should see:
```
[DesktopIcon] resolving file='Crimson Desert.desktop'
              iconName='steam_icon_3321460'
              iconAbsPath='/home/paul/.local/share/icons/hicolor/256x256/apps/steam_icon_3321460.png'
→ Stage 0 (iconAbsPath): file:///home/paul/.local/share/icons/...
```

And the desktop icons should show real Steam cover art.

## Notes

- `Pasted Image.png` will still show generic glyph (it's a regular file,
  not a launcher). Could add image thumbnail rendering in a future hf82z.
- `net.lutris.nte-1.desktop` will resolve via its own Icon= field — the
  scan reads each file's content directly, not just the filename.
- Debug logging is still enabled. Once you confirm icons work, I can
  ship hf82z with the `console.log` calls removed.

## Open threads

- Drag-easier toggle
- Profile setup popup positioning
- Pasted-image thumbnail (future)
