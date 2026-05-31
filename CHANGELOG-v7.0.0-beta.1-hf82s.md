# v7.0.0-beta.1-hf82s — Fix desktop scan + float toggle

**Channel:** beta (hotfix on hf82r)
**Released:** 2026-05-26

## Bugs fixed

### Bug 1: Desktop icons say "empty" when files actually exist
- **Root cause**: hf82r DesktopIconsService had a complex bash pipeline
  (`find | while read | case | done | sort -t$'\t'`) inside the QML
  `Process.command` string. This worked standalone in bash but failed
  silently in Quickshell's Process context. The complex pipeline +
  multi-level shell escaping was the most likely culprit.
- **Fix**: hf82s splits the scan into two stages:
  1. Bash does ONLY the directory listing (`find -printf '%y|%f\n'`).
     Pipe-separated, much simpler escaping, no inline `case`/`while`.
  2. JS-side parser handles type detection + initial icon name from
     filename extension (no per-file `file --mime-type` subprocess for
     non-.desktop entries).
  3. For .desktop files, ONE small `grep -m1 '^Icon='` Process per file
     spawned asynchronously to extract the real icon name.
- **Side benefit**: per-entry `console.log` so we can see the scan in
  journalctl if it ever breaks again.

### Bug 2: App Float Rules switches don't toggle
- **Root cause**: HMSwitch's internal click handler does
  `root.checked = !root.checked` BEFORE firing `onToggled`. My hf82r code
  bound `HMSwitch.checked` directly to `WindowRulesService.isFloating(wmClass)`
  — the manual assignment in HMSwitch **broke that QML binding** on first
  click, leaving the switch "stuck" with no source of truth.
- **Fix**: introduce row-level `rowFloating` property + `Connections` block
  on `WindowRulesService.floatAppsChanged`. Toggle now:
  1. Optimistically updates `rowFloating` (instant visual feedback)
  2. Calls `setFloating()` which writes file + reloads Hyprland
  3. When service re-reads file and `floatApps` changes, Connections
     auto-syncs `rowFloating` to truth — handles both success AND failure
     cases (if write fails, `rowFloating` reverts because service stays
     at old value).

## Files modified

| File | Change |
|---|---|
| `DesktopIconsService.qml` | Rewrote scan with split bash + JS approach + console.log |
| `AppFloatRulesPage.qml` | Added `rowFloating` property + Connections binding |
| `ZenVersion.qml` | hf82r → hf82s |
| `install.sh` | banner bump |

3 modified, 0 new, 0 removed.

## Install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82s.tgz
cd zen-shell-v7.0.0-beta.1-hf82s
./install.sh
pkill -f quickshell && sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

## Verify

1. Desktop should now show your files (steam, Lutris, etc.)
2. `journalctl --user -n 50 | grep DesktopIconsService` should show:
   `[DesktopIconsService] refresh() starting, scanPath=/home/paul/Desktop`
   `[DesktopIconsService] scan returned XXX bytes`
   `[DesktopIconsService] parsed N entries`
3. App Float Rules → click any switch → it should flip and STAY flipped
4. `cat ~/.config/hypr/modules/zen-window-rules.conf` should show the toggled rule
