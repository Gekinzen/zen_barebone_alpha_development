# v7.0.0-alpha.4 — Karui (軽い) · StartMenu V2

**Channel:** alpha
**Codename:** Karui (軽い)
**Sub-theme:** StartMenu V2 (dual-pane, auto-detect, perf/memory-friendly)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this drop adds

Brand-new dual-pane StartMenu (Win11-inspired layout, Densho-aware
visuals) that completely replaces the v6 single-list panel.
Backed by two new singleton services that handle app detection +
recent-file parsing.

### `StartMenuPanel.qml` v2 — full rewrite

Layout:

```
┌─────────────────────────────────────┬──────────────────────┐
│  Pinned (dynamic grid)              │  All Apps            │
│   ┌──┐ ┌──┐ ┌──┐ ┌──┐               │   Most Used          │
│   └──┘ └──┘ └──┘ └──┘               │     ▸ App  App ...   │
│   ┌──┐ ┌──┐ ┌──┐ ┌──┐               │                      │
│   └──┘ └──┘ └──┘ └──┘               │   Alphabetical list  │
│   …grid grows with PanelState rows… │     A — App A        │
│                                     │     A — App B        │
│  Recent (recently-used.xbel)        │     B — App C        │
│   ▸ document.pdf  · 2h ago          │     ...              │
│   ▸ photo.jpg     · 1d ago          │                      │
│                                     │                      │
│  ╭─────────────────────────╮        │   ┌────────────────┐ │
│  │ avatar  Paul   files  ⏻ │        │   │ Type to search │ │
│  ╰─────────────────────────╯        │   └────────────────┘ │
└─────────────────────────────────────┴──────────────────────┘
```

**Public surface preserved** — same signals + properties as v6 panel
(`closeRequested`, `appLaunched`, `powerActionRequested`,
`uploadInProgress`). `shell.qml` mount remains unchanged.

**Dynamic grid** — `PanelState.pinnedGridCols` (3–6) and
`PanelState.pinnedGridRows` (1–8) drive the pinned section. Clamped
defensively in the panel itself. Tile sizing computed from the left
pane width and column count so the grid scales fluidly across
different screen sizes.

**Manual pinning only** — empty state shows a pin icon and a prompt
("Right-click an app to pin"). Right-clicking any app row in the
all-apps list toggles its pin state. Right-clicking a pinned tile
unpins.

### `AppLauncherService.qml` (NEW singleton, ~280 lines)

Wraps Quickshell.DesktopEntries to auto-detect apps from every XDG
application source:

- `/usr/share/applications/` — system pacman
- `/usr/local/share/applications/` — local installs
- `~/.local/share/applications/` — user (yay/paru AUR helpers, AppImage)
- `/var/lib/flatpak/exports/share/applications/` — system flatpaks
- `~/.local/share/flatpak/exports/share/applications/` — user flatpaks
- `/var/lib/snapd/desktop/applications/` — snaps

**Two-layer auto-refresh:**

1. Primary: subscribes to `DesktopEntries.applications.onValuesChanged`.
   This is the standard path and handles most install/uninstall events.
2. Fallback: a long-running `inotifywait -m` Process watching the same
   six dirs with `--include '\.desktop$'`. Catches edge cases where
   Quickshell's built-in watcher misses (unusual flatpak install paths,
   AppImage integration tools, etc.).

Both paths feed a single 500ms debounced rebuild — when a package
install drops 20 .desktop files in burst (Adobe Suite via Wine, KDE
meta-package), all the events coalesce into one rebuild pass.

**NoDisplay/OnlyShowIn filtering** — Wine helper entries, gnome-only
or kde-only items are filtered out so they don't pollute the
all-apps list.

**Cached search index** — one flat lowercased
`name|comment|exec|categories` string per app, computed once on
entries-changed signal. `searchApps(query)` does a single linear scan
with three-tier ranking (exact-name-prefix → word-prefix → contains).

**Pin persistence** — `pinnedIds` array atomically written to
`~/.local/share/zen-shell/start-menu.json` (debounced 200ms). Atomic
writes via mktemp+mv pattern.

**Launch tracking** — `launches: { appId → count }` written to
`~/.local/share/zen-shell/app-launches.json` (debounced 1s, longer
since not user-visible). Drives the "Most Used" subsection
(`mostUsed(n)` returns top-N by count).

**API:**

```
property var apps              // canonical list, alphabetical
property var pinnedIds         // user's pinned IDs in order
property var launches          // { appId: count }
property bool loading          // true while rebuilding

function searchApps(query)     // → ranked array
function launch(app)           // execute + bump counter
function mostUsed(n)           // → top-N apps by launch count
function pin(id)
function unpin(id)
function isPinned(id)
function pinnedApps()          // → resolved app objects in pin order
function reorderPinned(newOrder)
```

### `RecentFilesService.qml` (NEW singleton, ~120 lines)

Parses `~/.local/share/recently-used.xbel` (the XDG recent-files
spec). Surfaces the most-recently-modified entries for the StartMenu
"Recent" section.

**Architecture:** instead of loading the (potentially 200KB+) XML
into Quickshell's QML context, we shell-out to a tiny `awk + sort +
head` pipeline that emits compact TSV. Parsing in QML is then trivial
and memory-efficient.

**Polling discipline** — only active while StartMenu panel is visible
(`active: true` toggle from the panel's `onVisibleChanged`). When
active, polls every 60s. When inactive, idle.

**Each entry surfaces:**

```
{ name, uri, path, mimeType, modified, application, iconName, exists }
```

`exists` is `false` for files that were deleted but still appear in
the xbel — the UI dims those rows to 45% opacity and disables the
click handler.

**Click handler** uses `xdg-open` so the entry opens in whatever app
the user has set as default for that MIME type.

### Patches

- **`PanelState.qml`** — Two new properties: `pinnedGridCols`
  (default 4) and `pinnedGridRows` (default 4). Both persisted via
  the existing saveState/loadState pipeline.
- **`BarModulesPage.qml`** — New `Start Menu` section with two
  `NumericStepper` rows (cols 3-6, rows 1-8) and an info row showing
  the live "X apps detected" count from AppLauncherService.

---

## Performance / memory measures (per the "memory friendly" spec)

| Concern | Mitigation |
|---|---|
| 200+ app icons rendering at once | `ListView` with `reuseItems: true` — only visible rows in scene graph |
| Off-screen rows lingering in RAM | `cacheBuffer: 200` (small enough that scrolling triggers cleanup quickly) |
| Icon images blocking UI on first show | `asynchronous: true` on every `Image` |
| Full-res icons from XDG icon theme | `sourceSize` capped: 64×64 for grid (rendered 32), 44×44 for list (rendered 22) |
| Search filter on every keystroke | 100ms debounce timer + cached lowercased index |
| Recent file polling when panel closed | `RecentFilesService.active = visible` — zero polling while menu hidden |
| inotifywait holding watches when shell closes | `Process` lifecycle managed; auto-restart 30s after unexpected exit |
| recently-used.xbel size (200KB+) | Shell-side awk parser emits TSV, only top-N rows transit to QML |
| Burst events from package install | 500ms debounced rebuild |

---

## Dynamic theme color rules (per "gaya sa quick settings + calendar")

Every text element in the new panel binds to ThemeService tokens:

- **`ThemeService.fg`** — primary headings + app names
- **`ThemeService.grey0`** — section sub-headers, muted labels
- **`ThemeService.grey1`** — secondary subtitles ("2h ago · zathura")
- **`ThemeService.blue`** — default accent (active/hover state)
- **`ThemeService.red`** — Densho accent (replaces blue when Densho on)
- **`ThemeService.alpha(token, 0.X)`** — translucent overlays

The Modori smart-contrast layer (v6.16.4.12.9.4 in ThemeService.qml)
automatically rewrites these RGBA values when a Matugen-generated
theme is applied, so readability is preserved against ANY background
— including the wallpaper-derived palettes that gave you trouble.

---

## Auto-refresh wiring

```
package install / uninstall
  ↓
.desktop file dropped/removed in any XDG dir
  ↓
TWO independent paths fire:
  ├─ Quickshell.DesktopEntries.applications signal (primary)
  └─ inotifywait emits a line on stdout (fallback)
  ↓
both call _scheduleRebuild() → 500ms debounced
  ↓
_rebuild() walks DesktopEntries, filters NoDisplay/OnlyShowIn,
sorts alphabetically, rebuilds the search index
  ↓
AppLauncherService.apps property changes
  ↓
ListView model binding triggers — visible delegates redraw
hidden delegates stay reused
  ↓
new app appears in StartMenu within ~500ms
```

---

## Files added

```
zen-shell-v5/AppLauncherService.qml      (NEW, ~280 lines)
zen-shell-v5/RecentFilesService.qml      (NEW, ~120 lines)
CHANGELOG-v7.0.0-alpha.4.md              (NEW, this file)
```

## Files modified

```
zen-shell-v5/StartMenuPanel.qml          (FULL REPLACEMENT, ~640 lines, was ~1467)
zen-shell-v5/PanelState.qml              (+2 properties: pinnedGridCols/Rows + persistence)
zen-shell-v5/BarModulesPage.qml          (+1 SettingsSection: Start Menu)
zen-shell-v5/ZenVersion.qml              (bumped to v7.0.0-alpha.4)
install.sh                               (version strings)
README.md                                (banner)
```

---

## Wala tayong babawasan

- **Public panel interface preserved**: same signals (`closeRequested`,
  `appLaunched`, `powerActionRequested`) and same property
  (`uploadInProgress`) so `shell.qml`'s existing mount continues to
  work without modification.
- **PanelState additions persist alongside existing fields** — old
  state files load fine (missing keys default to 4×4 grid).
- **Quickshell.DesktopEntries** dependency unchanged — we wrap it,
  don't replace it.
- **All previous v7 features carry forward**: Densho identity (alpha.2/3),
  UpdatesPage + snapshots (alpha.1), v6 baseline backup banner (alpha.1).
- Rollback via Updates Panel snapshots or `.bak-*` directory.

The old StartMenuPanel.qml v6 (1467 lines, single-list, hardcoded
pinned IDs) is gone from this drop. If you need it back, restore
from the auto-snapshot taken before install, or roll back to alpha.3
via Settings → Updates → Restore.

---

## Known caveats / next steps

- **Drag-to-reorder pinned tiles** — not implemented in this drop.
  Pin order is insertion order. To reorder, unpin then re-pin in
  desired order. Drag-reorder pending alpha.5.
- **Power menu** — clicking the ⏻ button currently fires
  `powerActionRequested("logout", "")` (forwards to shell.qml which
  shows a PowerConfirmDialog). The full inline expanded power menu
  (Suspend/Restart/Shutdown buttons) from v6 is simplified to a single
  logout click. If you want the full v6 power dropdown back, sabihan mo.
- **System info popover** — clicking the avatar in the v6 panel opened
  a fastfetch-style sysinfo card. Not in alpha.4 — kept the panel lean.
  Pwedeng i-add back in alpha.5 sa user pill.
- **Right-click context menu** — minimal in alpha.4: left-click =
  launch, right-click = toggle pin. The richer v6 context menu (Pin /
  Unpin / Properties / Remove from list) can be re-added if you want.
