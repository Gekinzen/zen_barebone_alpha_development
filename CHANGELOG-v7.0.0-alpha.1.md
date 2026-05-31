# v7.0.0-alpha.1 — Karui (軽い) hf1

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Released:** 2026-05-08
**Branch:** `dev` (new v7 branch convention)

---

## v7 launch

This is the first drop on the v7 line. v7 is the "lightweight" major,
themed around performance, battery efficiency, RAM cleanliness, and
low-spec friendliness.

### Versioning scheme reform

Dropped the 5-segment v6 tail (v6.16.4.12.9.12 was painful to grep
and tag). v7+ uses clean semver:

- **Stable:** `v7.0.0`, `v7.0.1`, `v7.1.0`
- **Beta:** `v7.0.0-beta.1`, `v7.0.0-beta.2`
- **Alpha:** `v7.0.0-alpha.1`, `v7.0.0-alpha.2`

Hotfixes bump patch (v7.0.0 → v7.0.1), not new tail segments.

### Branch naming

Replacing the scattered `alpha-vX.Y.Z` and `beta-v12.X.Y.Z` branches:

- `main` — latest stable
- `next` — beta candidates
- `dev` — alpha (active development, this branch)

---

## What's new in this drop

### Updates Panel (NEW)

A new `Settings → System → Updates` page that surfaces:

- **Current version** card with channel badge (alpha/beta/stable colored
  dot), codename + kanji, release date, and a **Check for updates** button.
- **Update-available banner** that appears when a newer release exists on
  the configured GitHub repo. Shows version, release date, release notes
  preview, and an **Install update** button gated by a confirmation dialog.
- **Update preferences:** auto-check toggle, check interval (1–168 hours),
  channel selector (Stable / Beta / Alpha — three pill buttons), snapshot-
  before-update toggle, max snapshots retained.
- **Snapshots & rollback** section with per-snapshot rows:
  - Yellow pin badge if pinned
  - Version + codename + channel
  - Relative timestamp + size
  - **Restore** button → confirmation → safety snapshot of current →
    atomic restore → reload prompt
  - **Pin / Unpin** button
  - **Delete** button (disabled if pinned)
- **Status footer** that surfaces the last action's result with color-
  coded background (green/red/blue/grey).

### `ZenUpdateService` singleton (NEW)

Backing service for the Updates Panel. Lives at
`qml/ZenUpdateService.qml`.

API surface:

- `checkForUpdates()` — manual check trigger
- `installLatest()` — downloads + installs the latest release tag
- `createSnapshot(label)` — manual snapshot of current install
- `deleteSnapshot(path)` — remove snapshot (refuses if pinned)
- `pinSnapshot(path, bool)` — pin/unpin protection
- `rollbackTo(path)` — restore a snapshot, with safety-snapshot first
- `refreshSnapshots()` — re-read manifest from disk

Auto-check runs once 30s after shell start, then every
`autoCheckIntervalHours`. Throttled to interval/2 minimum to prevent
churn from rapid shell restarts.

State persisted to `~/.config/quickshell/zen-shell/update-state.json`
with `_schema: 7` field. Atomic writes via mktemp + mv.

### Helper scripts (NEW)

Four bash scripts in `scripts/`, intended for `~/.local/bin/`:

- **`zen-update-check.sh <repo> <channel>`** — fetches GitHub releases,
  filters by channel (jq required for proper filtering; grep fallback if
  not), caches results 5 min in `~/.cache/zen-shell/`, emits one-line
  JSON for the QML service to parse.
- **`zen-snapshot-create.sh`** — multi-mode: `--version X --label Y`
  (create), `--delete PATH`, `--pin PATH`, `--unpin PATH`, `--prune`.
  Snapshots are full copies of the QML dir + state JSONs, stored at
  `~/.local/share/zen-shell/snapshots/<version>-<timestamp>/`. Manifest
  at `~/.local/share/zen-shell/snapshots/manifest.json`. Auto-prune
  drops oldest unpinned beyond `maxSnapshotsRetained`.
- **`zen-rollback.sh <snapshot-path>`** — atomic-ish restore with
  pre-rollback safety snapshot. Three-step swap: stage in temp, rename
  current → `.zen-shell.old-{ts}`, rename stage → live. Auto-revert on
  any failure mid-swap. Old install retained 7 days as tertiary safety.
- **`zen-update-install.sh --repo X --tag Y [--snapshot]`** — downloads
  release tarball from GitHub, extracts to temp, runs the contained
  `install.sh --no-bootstrap`. Verifies download size > 1KB before
  extract.

### `ZenVersion.qml` rewrite

- Bumped to `v7.0.0-alpha.1`, codename `Karui`, kanji `軽い`.
- New `compareVersion(a, b)` and `isNewer(other)` functions —
  semver-aware including prerelease ordering (alpha < beta < rc <
  release).
- New `semver`, `prerelease`, `major`, `minor`, `patch` parsed
  properties.
- New `schemaVersion: 7` constant — single source of truth for
  state file `_schema` field.
- `series` now returns `"v7.0"` style (was `"6.16.3.4 series"`).

---

## Migration notes

- All v6 state files continue to load. v7 services write `_schema: 7`
  to new files; old `_schema: 6` (or absent) files are read as-is.
- No state file format breaking changes in this drop. Existing
  `panel-state.json`, `bar-layout.json`, `wallpaper-state.json`,
  `weather.json`, etc. all load unchanged.
- v6 → v7 schema migration script (`migrate-v6-to-v7.sh`) deferred
  to a later drop because no breaking schema changes have landed yet.

---

## Known limits / caveats

- Auto-check **does not yet honor battery state**. The QML stub
  comment notes this will defer to `LaptopModeService` once that
  lands. For now, auto-check fires regardless of power source.
- Two snapshots created within the same second collide on the
  timestamp directory name. Will be fixed with ms-precision
  timestamps in a future drop.
- Update install assumes the release tarball has a top-level
  `install.sh` (matches the standard Zen Shell release layout).
  Custom layouts need a `zen-update-install.sh` patch.
- `.zen-shell.old-*` cleanup timer not yet shipped — these
  directories accumulate until manually deleted. Recommend
  `find ~/.config/quickshell -maxdepth 1 -name '.zen-shell.old-*' -mtime +7 -exec rm -rf {} +`
  in a cron until the systemd timer ships.
- Rollback **does** restore state JSONs along with QML — this is
  intentional (mismatched state vs old QML can crash shell) but
  may surprise users who expected only QML to revert.

---

## Wala tayong babawasan

This drop is purely additive:

- New singleton, new page, new scripts, new sidebar entry.
- `ZenVersion.qml` is a rewrite, but every existing public property
  (`version`, `versionRaw`, `releaseDate`, `channel`, `codename`,
  `fullLabel`, `series`) still exists and behaves identically.
- No existing service, page, or behavior was removed or changed.
- No schema-breaking state file changes.

Rollback to any v6.16.4.12.9.x release is fully supported (delete
the three new QML files + remove the two ZenSettings.qml edits).

---

## Files added

```
qml/ZenUpdateService.qml      (NEW, ~340 lines)
qml/UpdatesPage.qml           (NEW, ~580 lines)
scripts/zen-update-check.sh   (NEW)
scripts/zen-snapshot-create.sh (NEW)
scripts/zen-rollback.sh       (NEW)
scripts/zen-update-install.sh (NEW)
docs/INTEGRATION-v7.0.0-alpha.1.md (NEW)
docs/MIGRATION-v6-to-v7.md    (NEW)
```

## Files modified

```
qml/ZenVersion.qml            (bumped to v7, semver helpers added,
                               all v6 properties preserved)
qml/ZenSettings.qml           (sidebar entry + StackLayout case —
                               see INTEGRATION doc for diff)
install.sh                    (optional: helper-script copy block —
                               see INTEGRATION doc)
```
