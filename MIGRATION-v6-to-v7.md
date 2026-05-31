# Migration: v6 → v7 (Karui)

## Why v7?

v6 was the "feature breadth" major — bar modules, themes, control panel,
Wayland-overlay surfaces, smart-contrast theme engine, WiFi/BT redesign.
By v6.16.4.12.9.12 the line had landed almost everything from the
original `BETA-BLOCKERS.md`.

v7 is the **performance & efficiency** major. Theme: lightweight, low-spec
friendly, battery-conscious. The codename **Karui (軽い)** literally means
"lightweight."

## What changes at the v7 boundary

### Versioning scheme

| | v6 | v7 |
|---|---|---|
| Format | `v6.16.4.12.9.12` | `v7.0.0` |
| Beta | `beta-v12.6.16.1.11` | `v7.0.0-beta.1` |
| Alpha | `alpha-v6.16.4.12.9` | `v7.0.0-alpha.1` |
| Branches | `alpha-vX.Y.Z` per cut | `dev` / `next` / `main` |
| Hotfix | append `.N` | bump patch |

### What's preserved (no migration required)

- All state files load unchanged. v7 services write `_schema: 7` to new
  files; old files without `_schema` (or with lower values) load as-is.
- All themes, wallpapers, panel layouts, keybinds — identical behavior.
- All v6.16.4.12.9.x features remain. Wala tayong babawasan.
- `ZenVersion.qml` keeps every v6 property (`version`, `versionRaw`,
  `releaseDate`, `channel`, `codename`, `fullLabel`, `series`).

### What's removed at the v7 boundary

**Nothing yet** — v7.0.0-alpha.1 is purely additive. The deprecation
window for old files is reserved for v7.0.0-alpha.2 onward:

- **Planned for v7.0.0-alpha.2:** delete `_ConnToggleRow.qml`,
  `_StatChip.qml` (underscore-prefixed dead files).
- **Planned for v7.0.0-beta.1:** consolidate 30+ root `CHANGELOG-v6.X.Y.Z.md`
  files into a single `CHANGELOG.md` with anchored sections; old files
  archived under `docs/changelogs-archive/`.
- **Planned for v7.0.0:** drop `SettingsState.qml` (superseded by V2),
  drop `WallpaperService.qml` (superseded by V5).
- **Planned for v7.1.0:** rename `zen-shell-v5/` → `qml/` (the "v5"
  naming has been misleading since v6 shipped).

Each removal lands in its own drop with a clear changelog entry. Anyone
on the latest version up to that point will not be surprised.

### Update / rollback

v7.0.0-alpha.1 introduces the **Updates Panel** (Settings → System →
Updates). This makes future v7 → v7 upgrades safer:

- Auto-snapshot before every update (toggle).
- One-tap rollback to any retained snapshot.
- Pinned snapshots survive auto-prune.
- 7-day retention of displaced installs as tertiary safety net.

So the v7 upgrade path is itself the test case for the new system.

## Going from v6 to v7

If you're already on v6.16.4.12.9.x, the upgrade is:

1. Run the v7.0.0-alpha.1 `install.sh`.
2. Apply the two `ZenSettings.qml` edits documented in
   `INTEGRATION-v7.0.0-alpha.1.md` (sidebar entry + StackLayout case).
3. Reload Quickshell: `qs -r`.
4. Open Settings → System → Updates.
5. Tap "Snapshot now" to create your first v7 snapshot — this is the
   "good known state" you can roll back to if any future drop misbehaves.

That's it. No state file rewrites, no config migration, no autostart
script changes.

## Going BACK from v7 to v6

If you need to roll back to v6 (e.g. v7 has an unresolved bug for your
hardware):

**If you took a snapshot before the upgrade (recommended):**

1. Settings → System → Updates → find your pre-v7 snapshot → Restore.
2. Restart shell.

**If you didn't snapshot:**

1. Re-run the v6.16.4.12.9.12 `install.sh` from your v6 archive.
2. Manually revert the two `ZenSettings.qml` edits (remove the
   `updates` sidebar entry + StackLayout case).
3. Restart shell.

State files are forward-compatible from v6 to v7 but **not guaranteed
backward-compatible** beyond v7.0.0-alpha.1 once schema-breaking
changes land in later v7 drops. If you anticipate needing to roll
back, take a snapshot first.

## v7 roadmap

| Drop | Theme |
|---|---|
| **v7.0.0-alpha.1** (this) | Updates Panel + version system reform |
| v7.0.0-alpha.2 (planned) | `LaptopModeService` + adaptive polling |
| v7.0.0-alpha.3 (planned) | `ZenCleanupService` + RAM cleaner |
| v7.0.0-alpha.4 (planned) | QML lazy-load pass for memory |
| v7.0.0-alpha.5 (planned) | `/proc` direct reads + I/O coalescing |
| v7.0.0-beta.1 (planned) | State versioning audit + State Inspector |
| v7.0.0 (planned) | StartMenu Win11-style redesign + beta graduation |
| v7.1.0 (planned) | Spotlight palette + clipboard widget + Tategaki redux |

Wala tayong babawasan.
