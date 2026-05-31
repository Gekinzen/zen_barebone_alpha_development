# Zen Shell v7.0.0-beta.1-hf95.12.1 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Hotfix: SddmLoginPage.qml was missing its Quickshell imports, so the
new Settings page failed to load and took the whole shell down with it
("Process is not a type"). Imports added.** Wala tayong babawasan.

---

## Fix

`SddmLoginPage.qml` (new in hf95.12) uses `Process` and `Quickshell.env`
but only imported the QtQuick modules — `Process` lives in
`Quickshell.Io`. Because ZenSettings instantiates the page eagerly, the
missing type cascaded up: SddmLoginPage → ZenSettings → shell.qml failed
to load. Added:

```
import Quickshell
import Quickshell.Io
```

Audited every other hf95.12 file (MusicStrings, ThemeService,
SettingsState, UserManagementService) — all already import the modules
for the types they use; only the new page was affected.

## Version

- `ZenVersion.qml` bumped `hf95.12` → `hf95.12.1`.

## Files touched

- `zen-shell-v5/SddmLoginPage.qml` — add Quickshell + Quickshell.Io imports
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. All hf95.12 changes intact.
