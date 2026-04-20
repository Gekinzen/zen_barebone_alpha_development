# Zen Shell v6.15.14 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.13 (package missing 12 QML files)

**Scope:** Critical packaging fix — the v6.15.13 release tarball was
missing twelve QML files referenced by `shell.qml` and other
components. Fresh installs on machines without a pre-existing
Zen Shell tree would fail with QML errors like:

```
ERROR: Failed to load configuration
ERROR:   caused by @shell.qml[1033:13]: PowerConfirmDialog is not a type
```

**No functional changes.** This release is strictly a packaging fix —
the 12 missing files are copied verbatim from the reference working
install. Existing users who applied v6.15.12 or earlier via
`install.sh` already have these files; they only need v6.15.14 if
they are installing fresh or recovering from a cleaned
`~/.config/quickshell/zen-shell/` directory.

---

## The bug

When packaging v6.15 → v6.15.13, twelve QML files present in the
development environment were never added to the release's
`zen-shell-v5/` directory. Each prior release inherited this gap
from the base tarball.

The files rely on each other through implicit QML module resolution —
Quickshell finds `PowerConfirmDialog`, `Theme`, etc. by looking in
the same directory as `shell.qml`. On a dev machine where those
files already existed from earlier iterations, the shell loaded
fine. On a fresh install, the flat-layout copy step in `install.sh`:

```bash
cp "$SCRIPT_DIR/zen-shell-v5/"*.qml "$SHELL_DIR/"
```

…copied only the 56 files that were in the tarball, leaving
`~/.config/quickshell/zen-shell/` incomplete. The first unresolved
reference (`PowerConfirmDialog`) triggered a fatal QML error and
quickshell exited immediately.

Paul hit this on a fresh ROG laptop install:

> "ERROR: Failed to load configuration — caused by @shell.qml[1033:13]:
> PowerConfirmDialog is not a type"

---

## The twelve missing files

Added to the tarball verbatim from the working reference install:

| File | Role |
|---|---|
| `PowerConfirmDialog.qml` | Power action confirmation (shutdown / reboot / logout / lock) with countdown timer — referenced at `shell.qml:1033` |
| `Theme.qml` | Theme color singleton — `Theme.bg0`, `Theme.fg`, `Theme.alpha()`, etc. Used by ~25 other QML files |
| `Clock.qml` | Legacy bar clock (retained for compatibility; `ZenClock.qml` is the current module) |
| `MusicWidget.qml` | Non-strings music module — the default loaded when `ZenStringsState.enabled` is false |
| `NotificationIcon.qml` | Bar notification icon with unread count badge |
| `SysIndicator.qml` | System status indicator component (used by SysRow) |
| `SystemTray.qml` | StatusNotifierItem-compliant tray (distinct from `SysRow`) |
| `WallpaperService.qml` | Legacy wallpaper service (kept for migration paths; `WallpaperServiceV5.qml` is current) |
| `WindowTitle.qml` | Active window title bar module |
| `Workspaces.qml` | Legacy workspace module (kept alongside `ZenWorkspaces.qml`) |
| `_ConnToggleRow.qml` | Internal helper for the Connectivity page |
| `_StatChip.qml` | Internal helper for the Stats chip display |

Total file count brought from **56 → 68 QML files** — matching the
reference install exactly.

---

## Verification

```bash
# After installing v6.15.14, this should print 68:
ls ~/.config/quickshell/zen-shell/*.qml | wc -l

# All twelve files should be present:
for f in PowerConfirmDialog Theme Clock MusicWidget NotificationIcon \
         SysIndicator SystemTray WallpaperService WindowTitle \
         Workspaces _ConnToggleRow _StatChip; do
    test -f ~/.config/quickshell/zen-shell/${f}.qml && echo "  ✓ $f" || echo "  ✗ $f MISSING"
done

# Shell should launch without QML errors:
quickshell -p ~/.config/quickshell/zen-shell 2>&1 | grep -i error
# Expected output: (nothing)
```

---

## Files changed

```
zen-shell-v5/PowerConfirmDialog.qml    NEW (was missing from tarball)
zen-shell-v5/Theme.qml                 NEW (was missing from tarball)
zen-shell-v5/Clock.qml                 NEW (was missing from tarball)
zen-shell-v5/MusicWidget.qml           NEW (was missing from tarball)
zen-shell-v5/NotificationIcon.qml      NEW (was missing from tarball)
zen-shell-v5/SysIndicator.qml          NEW (was missing from tarball)
zen-shell-v5/SystemTray.qml            NEW (was missing from tarball)
zen-shell-v5/WallpaperService.qml      NEW (was missing from tarball)
zen-shell-v5/WindowTitle.qml           NEW (was missing from tarball)
zen-shell-v5/Workspaces.qml            NEW (was missing from tarball)
zen-shell-v5/_ConnToggleRow.qml        NEW (was missing from tarball)
zen-shell-v5/_StatChip.qml             NEW (was missing from tarball)
install.sh                             Version banner bump → v6.15.14
bootstrap.sh                           Version banner bump → v6.15.14
```

No changes to `shell.qml`, `Bar.qml`, `SettingsStateV2.qml`,
`scripts/`, `hypr-config/`, themes, or state schemas.

---

## Migration

### Fresh install (first-timer):
```bash
cd zen-shell-v6.15.14
./install.sh --bootstrap    # on a fresh laptop
#   or
./install.sh                # Hyprland already installed
```

### Upgrade from v6.15.13 (broken install — shell won't load):
Two equally valid options:

**Option A — run the v6.15.14 installer (recommended):**
```bash
cd zen-shell-v6.15.14
./install.sh
```
`cp` is idempotent; this fills in the twelve missing files without
touching anything else.

**Option B — copy just the twelve missing files:**
```bash
cd zen-shell-v6.15.14/zen-shell-v5
cp PowerConfirmDialog.qml Theme.qml Clock.qml MusicWidget.qml \
   NotificationIcon.qml SysIndicator.qml SystemTray.qml \
   WallpaperService.qml WindowTitle.qml Workspaces.qml \
   _ConnToggleRow.qml _StatChip.qml \
   ~/.config/quickshell/zen-shell/

# Restart
pkill -f 'quickshell.*zen-shell'
quickshell -p ~/.config/quickshell/zen-shell &
```

### Already on v6.15.13 with working install (dev machine):
You already have the files locally — v6.15.14 is a no-op for you.
Skip unless you want the version banner bump.

---

## How this was caught

Paul attempted a fresh install on an ROG Strix laptop, completed
`./install.sh --bootstrap`, then launched quickshell and got the
`PowerConfirmDialog is not a type` error. His dev machine's
`~/.config/quickshell/zen-shell/` was sourced as a reference tarball
and compared against the v6.15.13 release — diff revealed twelve
files the release was missing.

---

## Lesson — how to prevent this next time

The v6.15 → v6.15.13 releases were built by copying QML files from
an incomplete "clean source" tree. The proper source of truth is the
working install, not a curated subset. Future releases should:

1. Include a pre-packaging step that diffs
   `zen-shell-v5/*.qml` against a reference working install and
   halts if any references resolve outside the package
2. Add a post-install smoke test in `install.sh` that runs
   `quickshell check -p "$SHELL_DIR"` (or equivalent) and reports
   unresolved type references before the installer returns success
3. Maintain a canonical file manifest (e.g. `zen-shell-v5/MANIFEST`)
   that the release script validates against

For now, v6.15.14 ships the complete 68-file set verified against a
known-good working install.
