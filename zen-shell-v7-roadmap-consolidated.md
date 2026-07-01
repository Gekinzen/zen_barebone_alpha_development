# Zen Shell v7 — Master Roadmap (Consolidated)

**Updated:** 2026-05-30
**Status:** beta.1 — hf90 shipped (Vertical bar Tategaki Phase 1: left/right render a real side bar; uniform module height; Quick Settings position; ZenButton migration) (manual Module-size slider, ZenButton modern buttons, Settings sidebar hover style; vertical-bar approach scoped from dots-hyprland)
**Internal working name:** Karui (軽い) *(not public — gekinzen.github.io/zen-shell-site lists v7 codename as "Coming soon · TBA")*
**Current public stable:** v6.16.4.12.9.10 "Modori" (戻り)
**Maintainer:** Paul @ obsidevs.com
**Repo branch:** `dev`

> **Reconciliation note.** Source of truth for the v7 hotfix line + remaining beta blockers. Original 18-feature brainstorm folded into the priority lists with `#N` refs (section 5). Previous version's bookkeeping notes preserved in section 9.

---

## 1. Shipped — Alpha Line (alpha.1 → alpha.18)

| Drop | Theme | Key Deliverables |
|------|-------|-----------------|
| alpha.1 | Updates Panel | Snapshot rollback, update checker |
| alpha.2 | Densho Foundation | Toggle components, theme primitives |
| alpha.3 | Densho Surfaces | Bar/Clock/Settings integration |
| alpha.4 | StartMenu V2 | Dual-pane, auto-detect, app grid |
| alpha.5 | LaptopModeService | Adaptive polling, lid-close actions |
| alpha.6 | Search + Clipboard | FloatingSettingsSearch, ClipboardPanel, cliphist |
| alpha.7 | ZenCleanupService | RAM cleaner, zombie reaper, auto-trigger 5% |
| alpha.8 | Spotlight Palette | Command palette, app launcher |
| alpha.9 | Densho Restyle | Brush separators, page headers, widget icons |
| alpha.10 | Notification Center | ZenNotificationCenter (replaced SwayNC inline) |
| alpha.11 | Workflow Profiles | Work/Gaming/Focus/Movie/Sleep + Workspace Overview |
| alpha.12 | OSDs + Hot Corners | Volume/brightness OSD, hot corner triggers |
| alpha.13 | Per-Game + Battery | GameProfileService v1, BatteryHealthService |
| alpha.14 | Quick Wins Bundle | QuickNotes, FocusSpaces, NetworkPulse, SmartDim |
| alpha.15 | System Services | TitleTranslator, GPUSwitcher, RefreshRate, MouseSettings |
| alpha.16 | Connectivity | ConnectivityService (WiFi/BT), PowerProfileService |
| alpha.17 | Theming Engine V2 | ThemeService rewrite, Matugen, smart-contrast |
| alpha.18 | Architecture | SettingsStateV2, UserProfile, ZenVersion, ZenStrings |

---

## 2. Shipped — Beta.1 Hotfix Line (hf1 → hf82l)

### hf1–hf39 · Foundation Stabilization
Toast notification crash fixes (Lark/Teams burst protection), PanelState persistence audit (bar-layout.json clobber), DesktopStickyNotes, QuickNotesService + Panel (sidebar + markdown editor), FocusSpacesService + Page, SmartDimService + Page, TitleTranslatorService, NetworkPulsePage.

### hf39–hf55 · Productivity + Polish
QuickNotes markdown editor with autosave, calendar note creation API, HyprbarsService (plugin manager + auto-load + theme sync), HyprbarsSettingsPage + Mimic fallback, bar module visibility toggles.

### hf55–hf69 · Stability Sprint + Hyprbars Saga
Hyprbars auto-fix on boot, plugin watchdog (30s verify + auto-reload), heavy recovery (hyprpm rebuild fallback), taskbar minimize-restore (proper workspace restore sequence), WorkspaceOverview window thumbnails. **Hyprbars hf52→hf70 journey** ended with: invisible-glyph trick for button clickability (hf66) + auto-load unconditional, no toggle (hf70). Upstream hyprpm is still the real bottleneck; heavy recovery + auto-load is the workaround.

### hf70–hf74 · Features + Crash Safety
Calendar + Sticky Notes sync foundations, hot corner refinements, workflow profile auto-switching, crash recovery, screen-pinned popups (hf71–73 — string-name comparison fix + capture-on-visible), crash-safe sticky notes with JSON body backup + SIGTERM-first shutdown + JSON export (hf74).

### hf75–hf79 · Calendar Integration + GameProfile Rewrite

- **hf75** — Calendar + StickyNotes integration: right-click date → add note, green dots on dates with notes, auto-notify, auto-complete past events
- **hf76–78** — Calendar right-click note entry refinements (scope fix + "📅 undefined" arrow-function-in-binding fix)
- **hf79 (MEGA DROP — 9 files):**

| File | What Changed |
|------|-------------|
| **ZenNotificationCenter** | Calendar edit/delete/expand + scope fix |
| **GameProfileService** | Full rewrite: 3-tier detect, auto-learn, games.json |
| **GamingPage** *(NEW)* | Settings page — learned games list + clear cache |
| **ZenSettings** | Register GamingPage at index 24 |
| **HyprbarsService** | Boot time 2s → 400ms (event-driven verify) |
| **ZenNotifyToast** | Lark crash fix (RichText → StyledText + sanitize) |
| **NotificationListPanel** | Same Lark crash fix |
| **Taskbar** | Workspace switch (not window move) + cursor warp + WS label |
| **WorkspaceOverview** | Empty-on-first-open race-condition fix |

### hf80 · Notification Hardening — Second Pass
After hf79 cut, Lark/Teams crashes still occurred. hf80 added:

- **`NotificationService.qml`** — Per-app rate limiter (5/3000ms, critical bypass), burst suppressor, body sanitization at reception (2000-char cap + tag strip + `data:` URI strip), image-field hardening (drop `data:` and >500-char strings), `_nativeMap` cap (100 entries), `_clearNative` infinite-recursion fix
- Warmup gate (3s after start) before accepting native pixmap refs

### hf81 · Version Pin (`versions.lock`)
Released 2026-05-19. Pure additive infrastructure drop — `install.sh` + `bootstrap.sh` now soft-verify the user's `hyprland`, `quickshell`, `qt6-declarative`, `qt6-wayland`, `qt6-5compat`, `qt6-svg` versions against a `versions.lock` baked into the release tarball at build time. Policy: patch floats silent ✓, minor newer warns ⚠, minor older blocks with confirm, `ZEN_FORCE_VERSIONS=1` overrides. New `[0/9]` pre-stage in `install.sh`, new `scripts/zen-version-check.sh` library.

### hf82 · Lark Defense Round 3 + Opt-in Power + Live Sync (7 files)
Released 2026-05-21. Three concurrent user reports addressed in one drop:

| File | What Changed |
|------|-------------|
| **NotificationService** | Sanitize `summary` + `appName` at reception (mirroring hf80 body pipeline) — hf79/hf80 only covered `body`, but Lark/Teams put HTML in summary lines too |
| **ZenNotifyToast** | `textFormat: Text.PlainText` lock on summary + appName Text elements — closes the AutoText → RichText auto-promote door |
| **NotificationListPanel** | Same PlainText lock |
| **GameProfileService** | New `autoPowerSwitch: false` property (default OFF, persisted to games.json) gates `WorkflowProfileService.activate("gaming")` — user can now have game detection without forced Performance profile switch *(#13-adjacent)* |
| **GamingPage** | New "Auto-switch to Performance" `HMRow` toggle bound to `autoPowerSwitch` |
| **QuickNotesSticky** | Applied `_syncingFromService` + `activeFocus`-guarded `Connections` pattern (mirror of hf50 `DesktopStickyNotes` fix) — sticky note in normal mode now live-syncs with calendar/panel edits |
| **ZenNotificationCenter** | New `Connections { onNotesChanged }` handler on `calendarNoteTitle` TextInput — calendar editor now live-mirrors edits made in sticky/panel surfaces, with focus-guard |

### hf82b · Critical: FileView text() Unwrap (1 file)
Released 2026-05-22. Single-file critical patch caught by user crash log paste:

```
[GameProfileService] games.json parse error:
  TypeError: Property 'trim' of object function text() { [native code] }
  is not a function
```

Quickshell's `FileView` exposes loaded content via callable `text()`, **not** a plain string property. `gamesJsonReader.onTextChanged: root._parseGamesJson(text)` was passing the function reference. This bug had existed silently since `learnedGames` persistence was introduced — caught by try/catch, logged warning, all persisted state silently failed to load every shell start. hf82 made it visible by adding `autoPowerSwitch` persistence on top.

Fix: defensive call-site unwrap `(typeof text === "function") ? text() : text` + type coercion guard in `_parseGamesJson`. Two layers of defense against future repeat. After install, `games.json` finally persists correctly for the first time since the bug was introduced — covers classPatterns, titlePatterns, ignoreClasses, gpuBusyThreshold, learnedGames, AND autoPowerSwitch.

### hf82c · Defensive Hardening (5 files)
Released 2026-05-22. Shipped without a captured crash dump (user's verbose log was Qt rendering spam, no actual error frames). Belt-and-suspenders on the most likely remaining crash paths after hf82b:

| File | What Changed |
|------|-------------|
| **NotificationService** | Actions array sanitization (type-check, strip HTML from labels, cap at 8 entries), appIcon length cap (drop >500-char + `data:` URIs), try/catch wrap around `notification.tracked = true` (C++-bridged property — destroyed native peer → SIGSEGV in C++), try/catch wrap on `_setNative()` call |
| **ZenNotificationCenter** | Full try/catch + null guards on the hf82 `calendarNoteTitle` Connections handler. Defensive `_syncingFromService = false` reset on catch |
| **QuickNotesSticky** | Same defensive wrap on hf82 `onNotesChanged` handler. Narrowed `Connections.target` to typeof check |
| **ZenNotifyToast** | Header bump only |
| **NotificationListPanel** | Header bump only |

`GameProfileService.qml` stays at hf82b (untouched — confirmed working). `GamingPage.qml` stays at hf82.

**Active debug**: Quickshell C++ crash dialog still firing under Lark notification storm. hf82c is defensive; targeted hf82d-or-later depends on capturing `~/.cache/quickshell/crashes/<latest>/` dump contents.

### hf82d · Calendar title load + Sticky initial-render race + Version display (4 files)
Released 2026-05-23. Three more user-reported issues, all on UI surfaces hf82 introduced or touched:

| File | What Changed |
|---|---|
| **ZenNotificationCenter** | Day-cell click handler now uses "first non-📅 line" extraction (mirror of edit-button logic at line ~530). Pre-hf82d showed the `📅 YYYY-MM-DD` date line in the editor instead of the user's typed title. |
| **QuickNotesSticky** | New `onNoteChanged` + `onVisibleChanged` `Connections` handlers fix race where sticky window mounts before `QuickNotesService` finishes loading from disk → `Component.onCompleted` inits editor blank → user sees empty sticky until clicking another note and back. |
| **DesktopStickyNotes** | Same `onNoteChanged` race fix for widget-mode stickies. |
| **ZenVersion** | 3 hardcoded strings bumped — `version`, `prerelease`, `releaseDate`. Settings → User Profile → System Information was showing `v7.0.0-beta.1-hf75 · released 2026-05-18` despite the running shell being on hf82c. **Open thread:** auto-derive at build time from `git describe` or tarball filename. |

### hf82e · Calendar/sticky title rendering + Flameshot 1.5x scale fix (4 QML + 1 script)
Released 2026-05-24. Three more user-reported UI bugs surfaced from screenshots showing every calendar note rendering as `📅 2026-05-23` in both calendar and sticky panel sidebar, and flameshot region overshooting on a 1.5x scaled monitor:

| File | What Changed |
|---|---|
| **QuickNotesService** | Scan-time title extraction switched from `grep -m1 .` (first non-empty line) to `awk 'NF && !/^📅/ {print; exit}'` (first non-empty line that doesn't start with 📅). Falls back to old behavior if no such line found. Fixes the wrong `.title` getting stored on shell start for every calendar note. |
| **ZenNotificationCenter** | Calendar repeater now triggers `loadBody(id)` per row when `modelData.body` is empty (race fix — QuickNotesService loads bodies on demand, was racing with list render). Title fallback strengthened: if both `.body` and the legacy `.title` start with 📅, show `(loading…)` instead of the date duplicate. |
| **QuickNotesPanel** | Sticky panel sidebar now applies the same first-non-📅-line extraction as the calendar list, with same fallback for legacy 📅-prefixed titles. |
| **ZenVersion** | hf82d → hf82e, releaseDate 2026-05-24. |
| **scripts/zen-screenshot.sh** | `get_active_monitor_geometry()` was computing logical dimensions correctly but printing native (`m["width"]xm["height"]`) — fixed to print the computed logical (`w`x`h`) values. Flameshot's region picker on Hyprland Wayland operates in logical coordinate space; passing native dimensions overshot bounds on a 3440x1440 at 1.5x scale monitor. Script bumped v6.12 → v6.13. |

### hf82f · Taskbar drag-to-reorder pinned apps (2 files)
Released 2026-05-24. Pulled forward from the **P0 Immediate "Next Up"** slot (was queued for hf83-87). User asked for it directly:

> "can you make my taskbar here in the QML bar draggable — the icons? And please make the drag smooth and responsive."

| File | What Changed |
|---|---|
| **Taskbar** | Added drag-to-reorder for pinned apps. 350ms press-hold OR 8px move engages drag. Picked-up icon lifts (z + scale + opacity). Neighbors animate aside in real time. Drop commits + savePinned() persists. Esc/focus-loss cancels with snap-back. Architectural change: `taskbarRow` switched from `RowLayout` to plain `Item` with manual x positioning per icon — RowLayout's Layout.preferred* properties are non-negotiable and made smooth drag impossible. Now each icon computes its x from `effectiveIndex` (shifts during drag of neighbors) and animates via `Behavior on x`. The dragged icon overrides its own x to follow cursor 1:1. Only pinned apps reorder; running-but-not-pinned stay at end of `appList`. All existing click/popup/context-menu behavior preserved. |
| **ZenVersion** | hf82e → hf82f. |

### hf82g · Universal taskbar drag + Flameshot scale-fix v2 + install.sh banner refresh (4 files)
Released 2026-05-24. Two same-day user reports plus a long-standing cosmetic fix:

| File | What Changed |
|---|---|
| **Taskbar** | hf82f drag only worked for pinned apps. User: *"sa taskbar sa dulo last 2 icons hindi ko ma drag"* — running-but-not-pinned icons (at end of appList with workspace badges) couldn't engage drag. Fix: drag accepts ANY icon now. `_startDrag()` auto-pins non-pinned apps before drag-start (so they join pinnedApps and can participate in reorder); `_endDrag(false)` reverses the auto-pin on cancel. New `_dragAutoPinned` flag tracks this state. Matches GNOME/KDE/Windows 11 behavior. |
| **scripts/zen-screenshot.sh** | hf82e logical-dimensions attempt didn't fully fix the scaled-monitor cropping — neither native nor logical dims work consistently across all scales because flameshot's Wayland `--region` handling is upstream-buggy. Fix v2: drop `--region` entirely from `flameshot gui`, `flameshot full`, and `flameshot full --clipboard`. Flameshot's own focused-monitor auto-detection takes over, which works correctly on Hyprland Wayland regardless of scale. Script v6.13 → v6.14. |
| **install.sh** | User screenshot showed install output still saying `Done. Enjoy Zen Shell v7.0.0-beta.1-hf58 Karui (軽い).` while running shell was on hf82f. Top banner, closing box banner, and Done line all bumped from hf75/hf58 → hf82g, with a fresh hf82a-82g changelog summary prepended to the existing historical entries. Open thread still: auto-derive at build time. |
| **ZenVersion** | hf82f → hf82g. |

### hf82h · WorkspaceOverview first-open race fix (2 files)
Released 2026-05-24. User report:

> "the Super+Tab show-workspace — the first time I run it it's empty; only on the second run does it show up."

| File | What Changed |
|---|---|
| **WorkspaceOverview** | Third bug in the hf82 series caused by the QML "parent.visible flips but child.visible property doesn't reassign" race (hf82d sticky, hf82e calendar list, hf82h workspace overview). On first Super+Tab after shell start, the Rectangle inside PanelWindow had `visible: true` default that never changed (parent-to-child visibility cascade doesn't always trigger `visibleChanged` on the child) — so `onVisibleChanged` handler that should call `_refresh()` never fired. Close → reopen pattern worked because the close DOES propagate visible=false through the parent chain, so the second-open false→true transition fires properly. Fix: subscribe to `PanelState.workspaceOverviewVisible` directly via Connections (authoritative singleton property that always emits change signals). Plus 4 more defensive layers: `Component.onCompleted` for shell-reload-while-open, `Hyprland.toplevels.valuesChanged` for live updates, `Hyprland.workspaces.valuesChanged` for workspace creation, unconditional 250ms `_refreshTickTimer` for slow-data scenarios. Tile delegates also subscribe to PanelState directly (same race lurks inside each Repeater delegate). Legacy `onVisibleChanged` + `_retryTimer` preserved as belt-and-braces backups. |
| **ZenVersion** | hf82g → hf82h. |

### hf82i · ZenStrings vertical alignment fix for top-anchored bar (2 files)
Released 2026-05-24. User report:

> "my strings, when the panel is at the top, aren't aligned with the QML bar itself."

| File | What Changed |
|---|---|
| **shell.qml** | `slotCenterY` binding inside the `ZenStrings` block (around line 1348) only handled the bottom-anchored case — math worked backwards from `panelMarginBottom`. When bar is at top, `panelMarginBottom` is 0/unused, the bar is anchored via `panelMarginTop`. Result: strings rendered ~2*vPad below the actual bar center. Fix: added `if (PanelState.isTop) { ... }` branch that mirrors the math for the top-anchor case (`barTopInWindow = panelMarginTop - actualTopMargin`, `barCenter = barTopInWindow + barHeight/2`). The `margins.top` / `margins.bottom` bindings on the strings window itself were already correct (had the `isTop` ternary) — only the slot-center calc was missing the branch. Plus a new `onPanelPositionChanged` Connections handler so top↔bottom flips trigger a clean position-ready reset (mirror of the existing `onPanelModeChanged` for fullwidth/floating/island). |
| **ZenVersion** | hf82h → hf82i. |

### hf82j · Rope colors + UpdatesPage HMSwitch + Update mechanism setup guide (4 QML)
Released 2026-05-24. Three asks from user:

> "the string colors and screenshot ropes should be recolorable too, and the colors should be accurate; and updates should use the same toggle design as the current ones, like in General. And how do I connect this Check for Updates given the repository exists, and what paths are needed for it to work? Write a guide."

| File | What Changed |
|---|---|
| **ZenStringsState** | Added 3 new properties for independent screenshot rope colors: `ropeColorMode` (`inherit`/`theme`/`synced`/`custom`), `ropeSyncedColorKey`, `ropeCustomColor`. New `ropeColor` resolver binding. Defaults to "inherit" so pre-hf82j behavior preserved. Custom mode is direct hex passthrough — no ThemeService remapping, "accurate" coloring guaranteed. Persisted in `string-state.json` alongside existing config. |
| **ZenRope** | Reads `ZenStringsState.ropeColor` instead of `color1` directly. Single-line change. |
| **GeneralPage** | New "Rope color" dropdown + "Rope palette key" + "Rope hex color" rows in Strings section, visible only when strings + screenshot ropes both enabled. |
| **UpdatesPage** | Swapped 2 instances of Qt's platform-native `Switch` → `HMSwitch` pill toggle (matches General / Battery / Widgets / ZenStrings styling). |
| **ZenVersion** | hf82i → hf82j. |

### hf82k · Dock surface foundation — Phase 1 (5 new + 2 modified)
Released 2026-05-24. Major feature, user request:

> "okay, please add a dock panel, and the dock should also be able to hold other widgets, but default to whatever's in my taskbar — make sure it's draggable too, and the same feature for the workspace numbers/count and the popup, as in identical..."

Honest phasing: shipped foundation in hf82k, deferred control center popup to hf82l, deferred desktop icons to hf82m.

| File | Status | Lines | What |
|---|---|---:|---|
| **DockState** | NEW | 244 | Singleton + persistence + module list mutators |
| **ZenDock** | NEW | 165 | Body — RowLayout of module Loaders mirroring Bar.qml dispatcher |
| **ZenDivider** | NEW | 42 | Vertical separator (theme-aware, parent-relative height) |
| **ControlCenterButton** | NEW | 96 | Stub button (visual final, click fires notify-send placeholder for hf82l) |
| **DockPage** | NEW | 368 | Settings UI (general / appearance / modules) |
| **shell.qml** | MODIFIED | +94 | New `Variants { model: screens } > PanelWindow > ZenDock` block |
| **ZenSettings** | MODIFIED | +5 | Sidebar entry + StackLayout registration |
| **ZenVersion** | MODIFIED | +0 | hf82j → hf82k |

**Phase 1 ships:** dock surface, top/bottom positioning, fullwidth/floating/island modes, default modules mirroring taskbar, theme sync from bar with per-dock override fields, drag and workspace popup inherited "for free" by reusing Bar widgets, settings page with module reorder.

**Phase 2 (hf82l):** ZenControlCenter popup (volume / wifi / BT / power / brightness), drag-to-reorder list UI in DockPage replacing up/down buttons.

**Phase 3 (hf82m):** Desktop icons (WlrLayer.Bottom surface, ~/Desktop scan, drag, resize, auto-arrange), dock auto-hide on cursor-edge reveal, per-app dock badges.

### hf82k.1 · Dock default modules adjusted to lean preset (3 files)
Released 2026-05-24. Mini-patch on hf82k after user's explicit elicitation answers came in: default `DockState.modules` reduced from 6-item full set (`start, taskbar, workspaces, divider, sysrow, controlcenter`) to lean 2-item set (`taskbar, workspaces`). Reset button + resetDefaults() updated to match. All previously-default module ids still slot-able via DockPage's Add picker. Version bumped to `hf82k.1`.

### hf82l · Hyprland 0.55 compatibility + version-aware config sanitizer (4 files)
Released 2026-05-25. User reported error after OS + Hyprland upgrade to 0.55:

> "I got an error after I updated my OS and it's Hyprland 0.55 now — there's an error; our OS should support 0.54 and 0.55, future-proof it."

Three Hyprland errors: `dwindle:pseudotile does not exist` (0.55 removed it), `Invalid dispatcher, requested "togglesplit"` (0.54 removed it), plus a cascade line 44 from the same dwindle block.

| File | What Changed |
|---|---|
| **hypr-config/binds.conf** | Line 12 `togglesplit` → `layoutmsg, togglesplit` (correct form since 0.54). Version-explanatory comment added inline. |
| **hypr-config/hyprland.conf.template** | Removed `pseudotile = true` from dwindle block. 10-line comment block explaining why + that the `pseudo` dispatcher still works fine for the same UX. |
| **install.sh** | NEW `_sanitize_hl_conf` function + supporting helpers (`_detect_hl_minor`, `_hl_version_at_least`, `_strip_hl54_breakages`, `_strip_hl55_breakages`). Detects user's Hyprland version via `hyprctl version`; for each version threshold, applies the appropriate strip/rewrite. Idempotent (re-runs safe), backs up to `.pre-hl5N-${TS}` before editing. Invoked at 3 points: fresh hyprland.conf write, existing hyprland.conf BEFORE source-line appending, and after each modules/*.conf copy (both new + preserved cases). Works across 0.53 / 0.54 / 0.55 / 0.56+ — pattern documented inline for adding next breakage in 0.56. |
| **ZenVersion** | hf82k.1 → hf82l. Release date 2026-05-25. |

Functionally tested: sanitizer regex correctly rewrites `togglesplit`/`swapsplit` to `layoutmsg` form across 4 input variants (bind, bindd with desc, already-correct lines passthrough), idempotent on re-run. Version comparator tested across 7 version pairs.

Future-proofing: when 0.56 ships with new breakages, only edit needed is adding `_strip_hl56_breakages()` function + one line in `_sanitize_hl_conf`. Pattern + compat matrix table documented inline.

---

### hf83–hf85 · Bar sizing + Dock space + Desktop-icon widget + User clone (2026-05-30)

Three same-day user-driven drops, all additive (toggles default to
preserve prior behavior unless noted):

- **hf83** — (a) **Auto bar height** — bar window hugs its tallest
  module + padding (`PanelState.barAutoHeight`). (b) **Full-width
  Settings header** — `⚙ Settings` title + window buttons span the top
  of the Settings window above sidebar+content (`fullWidthHeader`); old
  in-sidebar header hidden, not removed. (c) **Dock reserve-space** —
  dock window switches from `ExclusionMode.Ignore` to `Normal` +
  explicit `exclusiveZone` (`DockState.reserveSpace`, default on) so it
  no longer overlaps Hyprland tiles. (d) **Single-widget desktop icons**
  — new `DesktopIconsWidget.qml`: one movable + resizable panel holding
  all icons in a reflowing grid, taskbar-parity icon resolution
  (`DesktopIconsState.widgetMode`).
- **hf84** — **Fit-contents-to-bar** — `Theme.barContentScale` derived
  from bar height; `iconSize`/`fontSize`/`moduleHeight` become scaled
  derived values (base held in `*Base`), and the hardcoded-size modules
  (Taskbar `btnSize`-driven reflow, SysRowIcon glyph, SysRow main-row,
  Workspaces dots) wired to a local `_fit`. Off → byte-identical to hf83.
- **hf85** — (a) **Settings search auto-hide removed** (pinned in
  header). (b) **Bar vertical content padding** (`barContentPaddingV`) —
  modules stay centered with even top/bottom gap. (c) **New-user dotfile
  clone** — `createUser(copyDotfiles)` copies curated rice
  (quickshell/hypr/kitty/fish/matugen/swww/local) + rewrites home paths
  + chowns to the new user, in one pkexec call. (d) **Custom PNG icons**
  for desktop-icon tiles — `customIcons` map + right-click file picker
  (Shift+right-click clears).

- **hf86** — (A) manual **Module size** slider (`barModuleScale`) folded into `Theme.barContentScale` alongside the hf84 fit-contents dynamic scale. (B) **ZenButton** modern button component (replaces flat platform `Button{}`); applied to ControlCenterBanner "Open" (shared across pages), DesktopPage + UserManagementPage actions. (C) Settings sidebar **rounded/square hover** (`settingsHoverStyle`). (D) Vertical bar/dock approach captured from the user's dots-hyprland reference at this point (see Tategaki row in §4) — **subsequently shipped**: the left/right vertical QML bar now works (bar, workspaces, taskbar, sysrow, music strings all vertical).

> Honest phasing note: the desktop-icons **app-list pinning** (pin
> arbitrary installed apps, not just `~/Desktop`) and the **standalone
> installer** were asked in the hf85 turn and are tracked in §4 — not
> shipped yet. The hf85 dotfile-clone is the installer's core mechanism.

---

### hf86–hf95.32 · Dock maturity + Hyprbars doctor + Quick terminal + SDDM + User-clone polish (2026-05-30 → 06-01)

A long user-driven run, mostly from screenshots of the running shell.
Everything additive; toggles/defaults preserve prior behavior unless
noted. Grouped by theme:

**Quick drop-down terminal (Super+Shift+T)**
- **hf95.13** — new `zen-quickterm.sh`: a dedicated Alacritty instance
  (`--class zen-quickterm`) with its OWN config
  (`~/.config/alacritty-quick/`), toggled via a `special:quickterm`
  Hyprland workspace. Normal Alacritty untouched. Keybind + window rules
  + install deploy + preserve-if-exists config.
- **hf95.14 → hf95.17** — position iterations: centered → top-center →
  discovered special-workspace windows IGNORE the `move` windowrule, so
  the script repositions explicitly via `movewindowpixel` (focused-
  monitor + scale aware, top-center, ~40px from top).

**SDDM greeter + DM switch**
- **hf95.10 → hf95.13** — new "Zen Tokyo" SDDM greeter under `sddm/`
  (Qt6, blur, big clock, user/session/power selectors), dynamic theming
  from the active Zen theme (`zen-sddm-sync.sh`), avatar = start-menu
  profile image, and a `zen-dm-switch.sh` that ACTUALLY switches the
  active display manager (enable sddm / restore previous) with safe
  ordering (replacement enabled before old disabled; effective next
  reboot). Settings → Login Screen (SDDM) page + polkit rule.

**Hyprbars "Outdated headers" saga → `zen-hyprbars-doctor.sh`**
- **hf95.18** — fixed an `invalid field type plugin:hyprbars:bar_height`
  config error: ANY `hyprbars:*` windowrule errors on 0.54/0.55 when the
  plugin isn't loaded, and the static layer-rules file is always parsed.
  Removed it; quick-term no-bar moved INTO HyprbarsService (gated on
  `pluginLoaded`).
- **hf95.24** — smart Hyprland-version detection in install.sh
  (`_hypr_detect_version` / `_hypr_is_dev_build` /
  `_hypr_have_system_headers` / `_hyprbars_aur_fallback`); Phase 0b
  pre-flight routes dev builds straight to AUR; a Phase 1 hyprpm failure
  auto-falls-back to AUR.
- **hf95.25 → hf95.30** — new **`zen-hyprbars-doctor.sh`**: one-shot
  diagnose + auto-repair. Detects build, **version skew** (running
  `hyprctl` vs installed `pacman -Q hyprland` — the pacman-upgrade-
  without-relogin case), auto-runs **`hyprpm purge-cache` + retry**
  (official fix for error-code-4 on clean builds), then AUR fallback
  against system headers (build-aware package order: repo→stable first,
  git→`-git` first), then direct `hyprctl plugin load`. Purges stale
  `*hyprbars*.so` and force-rebuilds when versions match but a
  headers≠running mismatch persists. **Confirmed working by the user at
  hf95.30.** `TROUBLESHOOTING-hyprbars.md` documents it.

**Settings window title bar (HyprbarsMimic) — explored then parked**
- **hf95.17 → hf95.22** — restored the `HyprbarsMimic` fake title bar on
  the Settings window (it's layer-shell, so the real plugin can't
  decorate it), titled `Zen-Shell-Hypr-Control-Center`, gated on
  hyprbars-enabled, themed + aligned from HyprbarsService, centered title
  (`centerTitle`), draggable (`dragTarget`), search-bar offset, minimize
  removed (no taskbar to restore to). Ultimately **disabled per user
  request** (`wantBar: false`) — native header returns; component kept in
  the tree, offsets auto-zero.

**User-management clone reliability**
- **hf95.9 → hf95.23** — clone now resolves the source user root-side via
  `PKEXEC_UID`; path-rewrite covers ALL copied dirs; clone expanded to the
  full working desktop (theme/alacritty/fuzzel/gtk/local). **Live
  progress** streamed to the banner via `SplitParser` (`>> step` markers)
  + 90s **watchdog** + clearer exit-126/127 message, so a missing polkit
  agent no longer looks like a frozen "Creating user…".

**Taskbar + Dock sizing / overflow / monitor**
- **hf95.30** — Taskbar icons **float** inside the bar (`iconPadding`,
  `btnSize = moduleHeight − 2·padding`) like the dock, so window-count
  badges are visible.
- **hf95.31** — Dock **hybrid resize→arrows**: in fullwidth/floating it
  shrinks icons to fit (`dockFitScale`, capped 1.0) down to
  `DockState.minIconScale`, then shows chevron scroll arrows
  (`hasOverflow`). New **Minimum icon scale** slider; **Taskbar width
  cap** moved to a `PanelState.taskbarMaxWidth` slider (was hardcoded
  440). Confirmed both bar + dock already have **monitor targeting**
  (Settings → Panel → Display Target; Settings → Dock → Show on monitor,
  auto-detected from `Quickshell.screens`).
- **hf95.32** — Dock **Icon size** slider (`DockState.iconSizeScale`,
  60–200%, independent of bar; surface height grows with it). Dock
  dropdowns ("Add module", "Show on monitor") gained `preferAbove` so
  they open UPWARD and stay inside the Settings window instead of
  spilling onto the desktop where they couldn't be clicked.

> The intervening hf86–hf95.8 covered Zen Shell internals across this
> window (vertical music strings, sticky/quick-notes, focus reset after
> hyprlock, desktop-icon resolution, and the v7 QML architecture work)
> consistent with the beta hotfix cadence; the entries above are the
> user-facing drops from the most recent sessions.

---

## 3. Current — hf82m 🚧 (ZenControlCenter popup + drag-list UI; Dock Phase 2)

> **Blocking on:** Capture of Quickshell crash dump contents from `~/.cache/quickshell/crashes/<latest>/` — needs `meta.json` + `qml-stack.txt` + any `info.txt`/`stacktrace.txt`. hf82c was defensive shot-in-the-dark; targeted patch will be pinpoint once dump lands.
>
> **If dump confirms notification-path culprit:** hf82c probably already covers it, next patch may just be header-bump documentation.
>
> **If dump points elsewhere (Bar.qml / PanelState / ThemeService / hyprbars plugin / etc.):** next patch targets that file with the same defensive `_syncingFromService` + try/catch + typeof-guard pattern used in hf82c.

---

## 4. Next Up (hf83 → beta.2)

> Single priority list. Original 18-brainstorm items folded in with `#N` references (see section 5 for full mapping).

### 🔥 Immediate — hf86–89 (Taskbar & Calendar QoL)

> Note: hf83–hf85 were consumed by the user-driven bar-sizing / dock / desktop-icon-widget / user-clone drops (see §2). The QoL items below shift to hf86+.

| P | Module | Effort | Notes |
|---|--------|--------|-------|
| **P0** | Taskbar hover preview | M | 400ms hover delay → window thumbnail popup (Hyprland screenshot) |
| ~~**P0**~~ ✅ | ~~Taskbar drag-to-reorder~~ | ~~M~~ | **SHIPPED hf82f** — press-hold 350ms + drag, neighbors slide smoothly, savePinned() on drop |
| **P0** | Calendar split-view | M | Left list + right editor (mirror QuickNotesPanel layout) inside ZenNotificationCenter |
| **P0** | Notification per-app rules *(#14)* | L | Mute specific apps, priority levels, DND schedule — partial groundwork in hf80 rate limiter |
| **P1** | Hyprbars enable/disable → hyprpm sync | S | OFF fires `hyprpm disable hyprbars` + unload; ON fires enable + reload |
| **P1** | Title Translator in-shell popup | M | LibreTranslate API in QML, floating draggable popup, optional desktop widget pin |
| **P1** | Notes export as ODT | S | pandoc conversion from existing hf74 `exportToJson` |
| **P2** | Quick Notes search highlights | S | Sidebar highlights matched title/body portions |
| **P2** | Multi-monitor sticky widget placement | S | Per-sticky monitor selector + saved monitor name |
| **P2** | Maximize calendar view | M | Full-screen monthly overview + sidebar |
| **P1** | Desktop-icons **app-list pinning** | M | Pin arbitrary installed apps into DesktopIconsWidget (not just ~/Desktop). Reuse AppLauncherService.apps; pinned list in DesktopIconsState; drag-add from a picker. Custom PNG per pin already shipped hf85. |
| **P0** | **Standalone installer** | L | First-run + new-user provisioning wrapping the hf85 dotfile-clone (curated copy + /home path rewrite + chown). install.sh already has version-pin (hf81) + Hyprland sanitizer (hf82l); fold the clone in + a guided first-run profile import. Gate for v7.0.0 stable. |

### 🎯 Short-term — hf88–95 (Architectural)

| P | Module | Effort | Notes |
|---|--------|--------|-------|
| **✅ SHIPPED** | **Tategaki Redux** (vertical bar) | XL | **DONE — left/right vertical QML bar is working.** Left/right picker enabled; bar window vertical-anchored full-height + reserves thickness; Bar.qml vertical ColumnLayout; Workspaces, Taskbar, SysRow and music strings all render vertically. Built on the dots-hyprland `ii/verticalBar` approach: PanelWindow anchored left XOR right + top+bottom (full height), fixed `implicitWidth=barThickness`, `exclusiveZone=barThickness` (reuses the dock reserve-space pattern on the vertical edge); Bar.qml RowLayout→ColumnLayout (top / center fillHeight / bottom, modules AlignHCenter). Remaining polish (not blocking): mixed-DPI vertical sizing, optional vertical-specific module tweaks. |
| **P0** | **Plugin System V2** | XL | Signed manifests, sandboxing, dependency declaration, registry. Hidden since Hikari .51. |
| **P1** | Matugen Polish | L | Live preview pane in Settings → Themes, per-target overrides |
| **P1** | Theme Importer | M | Side-by-side smart-contrast preview, bulk import |
| **P1** | Wallpaper Picker (online) | M | In-app browser for online wallpaper repo, one-click apply |
| **✅ SHIPPED** | MusicStrings Vertical | S | Done — ZenStrings render vertically alongside the vertical bar. |
| **P2** | Clipboard smart categorize *(#7)* | M | URL / code / email / plaintext / image tabs |
| **P2** | Workspace breadcrumbs *(#15)* | M | Back-history dots in bar, click to jump |

### 🌱 Mid-term — hf96+ → beta.2 / beta.3

| P | Module | Effort | Notes |
|---|--------|--------|-------|
| **P0** | Full QA pass | L | Every Settings page, every bar module, every popup |
| **P0** | Documentation site | L | MkDocs Material at gekinzen.github.io/zen-shell |
| **P1** | Multi-monitor polish | L | Mixed-DPI blur, hot-plug migration, rotated-monitor coords |
| **P1** | Settings persistence audit | M | STATE-OWNERSHIP.md + State Inspector debug overlay. **Partial:** hf82b proved games.json was silently failing for months — audit should round-trip-test every FileView writer. |
| **P1** | Lock Screen polish | M | Wallpaper-aware hyprlock, clock + weather + media on lock |
| **P1** | stow/chezmoi/Nix packaging | M | Dotfiles manager integration |
| **P1** | zsctl CLI tool | M | `zsctl theme apply`, `profile switch`, `diag` |
| **P1** | Window Peek *(#6)* | L | Super+Tab hold preview across workspaces (HyprlandIpc + thumbnails) |
| **P1** | Power Schedule *(#8)* | M | Time + calendar-driven PowerProfile switching |
| **P1** | Hot Corners + modifiers *(#11)* | M | Extend hf37 with Shift/Ctrl/Alt → 12 combos |
| **P1** | Audio Profiles *(#13)* | M | EQ + per-app routing presets (pactl/wpctl) |
| **P2** | Pomodoro Timer | S | Bar module + focus session tracking |
| **P2** | Calculator Widget | S | Desktop widget, basic + scientific |
| **P2** | Audio Output Picker | S | Quick-switch headphones/speakers/HDMI |
| **P2** | Screenshot Annotation Lib *(#9)* | L | Presets + OCR + upload targets |
| **P2** | Wallpaper Mood Engine *(#10)* | L | Time/weather/music-color transitions |
| **P2** | Toolbox *(#12)* | M | Bash scripts as floating panel buttons (YAML frontmatter) |
| **P2** | Game Library Quick Launch *(#16)* | L | Steam/Lutris/Heroic scanner → Spotlight + Auto Gaming Boost |
| **P2** | FPS Counter overlay *(#17)* | S | mangohud auto-inject via GameProfileService trigger |
| **P2** | Recording Hotkey *(#18)* | S | wf-recorder Super+Alt+R |
| **P2** | Community theme gallery | M | Theme sharing + one-click install |
| **P2** | Plugin registry | L | Curated index at Gekinzen/zen-plugins-registry |
| **P2** | Theme schema v3 | M | Bundle ZenStrings + HotCorners + ScreenshotRope into profile JSON |
| **P2** | C++ Quickshell native singletons | L | Hot-path services (HyprlandFocusGrab queries, hyprctl polling) |

### 🔧 Just-shipped from previous "Next Up" list

Tracking what cleared between roadmap revisions:

| Item | Previous P | Cleared in |
|------|-----------|------------|
| Lark notification deep fix | P1 (was hf81–85) | **hf82** (summary + appName + actions + appIcon) + **hf82c** (tracked= and _setNative wraps). Quickshell C++ crash still being hunted — not the same path. |
| Calendar ↔ sticky live sync foundations | P0-ish (hf70 baseline) | **hf82** completed for all 5 surfaces (panel, widget sticky, normal sticky, calendar editor, calendar repeater) |
| Game-detection opt-in power profile control | implicit in #13 | **hf82** `autoPowerSwitch` toggle. Default OFF preserves user's manual power profile choice. |
| Version pinning infrastructure | not previously roadmapped | **hf81** baked it in. Future minor-version test matrix now possible. |
| Calendar saved-note title load bug | not previously surfaced | **hf82d** — day-cell click handler was loading `📅 YYYY-MM-DD` instead of user's typed text. First-non-📅-line extraction logic copied from edit-button. |
| Sticky note initial-render race | not previously surfaced | **hf82d** — `Component.onCompleted` fired before `QuickNotesService` loaded notes from disk. Added `onNoteChanged` + `onVisibleChanged` Connections handlers in both QuickNotesSticky + DesktopStickyNotes. |
| Stale version label in System Info | not previously surfaced | **hf82d** — `ZenVersion.qml` hardcoded strings bumped from hf75 → hf82d. Auto-derive at build time still TODO. |
| Calendar/sticky list shows duplicate `📅 YYYY-MM-DD` instead of titles | not previously surfaced | **hf82e** — scan-time bash extraction was grabbing the 📅 line as the title. Switched to awk skipping 📅-prefixed lines. Also added per-row `loadBody()` trigger in calendar list + sidebar fallback strengthened. |
| Flameshot region overshoots on scaled monitors | not previously surfaced | **hf82e** — `zen-screenshot.sh` was printing native dimensions to flameshot `--region` instead of logical (already-divided-by-scale) values. Bug had been in v6.11 since flameshot region support was added. |
| Taskbar drag-to-reorder | P0 Immediate (was hf83-87) | **hf82f** — pulled forward by user request. RowLayout → Item architectural change for smooth drag. 350ms press-hold engagement, neighbor slide animation, savePinned on drop, snap-back on cancel. |
| Universal taskbar drag (any icon, not just pinned) | not previously surfaced | **hf82g** — hf82f restriction surprised users with running-but-not-pinned icons at end of bar that couldn't drag. Auto-pin on drag-start, auto-unpin on cancel, matches GNOME/KDE/Win11. |
| Flameshot scaled-monitor capture (v2 fix) | hf82e partial | **hf82g** — hf82e logical-dim attempt was still cropping at 1.25x/1.5x. v2 fix drops `--region` entirely from all flameshot calls; auto-detect handles focused monitor. |
| install.sh banner stale | open thread | **hf82g** — top/closing banners + Done line refreshed from hf75/hf58 → hf82g. |
| WorkspaceOverview empty on first Super+Tab | not previously surfaced | **hf82h** — third hit of the QML parent.visible→child.visible cascade race. Switched from `onVisibleChanged` on Rectangle to `Connections` on `PanelState.workspaceOverviewVisible` (authoritative singleton). Plus 4 defensive layers. |
| ZenStrings misaligned when bar is at top | not previously surfaced | **hf82i** — `slotCenterY` binding only had bottom-anchored math; missing `if (PanelState.isTop)` branch. Added the symmetric top-case calculation. New open thread for "panel-position-aware calculation audit" — likely affects other floating overlays anchored relative to the bar. |
| Screenshot ropes lacked color config | not previously surfaced | **hf82j** — added `ropeColorMode` / `ropeSyncedColorKey` / `ropeCustomColor` to ZenStringsState. "Inherit" mode preserves pre-hf82j behavior. Custom mode is direct hex passthrough for accurate coloring. |
| UpdatesPage Switch → HMSwitch | not previously surfaced | **hf82j** — 2 Qt platform-native `Switch` instances swapped to project-standard `HMSwitch`. New open thread: audit other settings pages for stragglers. |
| Update mechanism setup docs | open thread | **hf82j** — comprehensive setup guide for connecting Check for Updates to a GitHub repo: file inventory, state paths, 3-step setup, test commands, channel cheat sheet, pitfalls, dev-loop workflow. Embedded in hf82j CHANGELOG. |
| Dock (second module surface) | not previously surfaced | **hf82k** — Phase 1 of 3-phase dock feature. Foundation: DockState + ZenDock + DockPage + ZenDivider + ControlCenterButton stub + shell.qml mount + sidebar entry. Reuses Bar widgets (Taskbar, Workspaces, StartMenu, SysRow) so drag (hf82g) + workspace popup inherited free. Top/bottom positioning, fullwidth/floating/island modes, theme sync from bar with overrides. |
| Hyprland 0.55 breaking changes (dwindle:pseudotile, togglesplit dispatcher) | not previously surfaced | **hf82l** — Fixed shipped configs (binds.conf: togglesplit → layoutmsg, togglesplit; template: removed pseudotile). NEW version-aware sanitizer in install.sh: detects user's Hyprland version, applies appropriate strip/rewrite to existing configs. Idempotent + back-ups. Extensible for 0.56+. |

---

## 5. Original 18 Brainstorm — Tracking

> So nothing gets forgotten. `#N` numbers cross-reference section 4.

| # | Feature | Status | Where it lives now |
|---|---------|--------|---------------------|
| 1 | Focus Spaces | ✅ Shipped | hf39 |
| 2 | Smart Dim | ✅ Shipped | hf39 |
| 3 | Network Pulse | ✅ Shipped | hf39 |
| 4 | Quick Notes / Scratchpad | ✅ Shipped + polished | hf39 → hf76 → hf82 (live sync round-trip across all 5 surfaces) |
| 5 | Window Title Translator | ✅ Shipped | hf39 |
| 6 | Window Peek | ⏸ Mid-term | Needs HyprlandIpc window query + thumbnails |
| 7 | Clipboard smart categorize | ⏸ Short-term | Basic clipboard exists; categorize TBD |
| 8 | Power Schedule | ⏸ Mid-term | PowerProfileService hooks ready; needs Schedule UI |
| 9 | Screenshot Annotation Lib | ⏸ Mid-term | ZenScreenshotOverlay foundation ready |
| 10 | Wallpaper Mood Engine | ⏸ Mid-term | WallpaperService + Matugen exist |
| 11 | Hot Corners + modifier keys | ⏸ Mid-term | hf37 event-driven foundation ready |
| 12 | Toolbox | ⏸ Mid-term | New surface — pattern like QuickNotesPanel |
| 13 | Audio Profiles | ⏸ Mid-term | pactl/wpctl plumbing already in shell. Adjacent: hf82 `autoPowerSwitch` proved the opt-in-toggle pattern that audio-profiles UI can copy. |
| 14 | Notification Center Filters | ⏸ Immediate (hf83–87) | ZenNotificationCenter foundation exists; rate limiter from hf80 + sanitization stack from hf82/hf82c is the substrate |
| 15 | Workspace Indicators | ⏸ Short-term | Workspaces.qml + ZenWorkspaces.qml foundation |
| 16 | Game Library Quick Launch | ⏸ Mid-term | StartMenu/Spotlight integration target. GameProfileService.learnedGames (hf79) + working persistence (hf82b) is the data layer. |
| 17 | FPS Counter Overlay | ⏸ Mid-term | GameProfileService.gameActive trigger ready |
| 18 | Recording Hotkey | ⏸ Mid-term | wf-recorder + Super+Alt+R |

**Shipped: 5 / 18 · Remaining: 13 / 18**

---

## 6. Beta Blockers Status

### P0 — Must Land before v7.0.0

| Blocker | Status | Notes |
|---------|--------|-------|
| Tategaki Redux (vertical bar) | 🟢 Shipped | Left/right vertical QML bar working — bar, workspaces, taskbar, sysrow, music strings all render vertically. Polish (mixed-DPI) remains but not blocking. |
| Plugin System V2 | 🔴 Not started | Manifest + sandbox required |
| Settings persistence audit | 🟡 Partial | bar-layout.json clobber fixed. hf82b proved silent-failure FileView pattern is a class of bug — full audit should round-trip every persistence path. |
| Multi-monitor edge cases | 🟡 Partial | Common setups OK. Mixed-DPI + hot-plug pending. |
| Quickshell C++ crash under Lark storm | 🟡 Active debug | hf82/hf82c hardened every JS-visible path. Remaining crash dialog points to native side — needs crash dump capture for hf82d. |

### P1 — Should Land

| Blocker | Status | Notes |
|---------|--------|-------|
| Matugen polish | 🟡 Partial | Smart-contrast landed. Live preview + per-target TBD. |
| Theme importer | 🔴 Not started | |
| Wallpaper picker online | 🔴 Not started | |
| MusicStrings vertical | 🟢 Shipped | Renders vertically with the vertical bar. |

### P2 — Nice to Have

| Blocker | Status | Notes |
|---------|--------|-------|
| Native notification system | 🟢 Mostly done | ZenNotifyToast + NotificationListPanel + sanitization stack (hf79 → hf80 → hf82 → hf82c). swaync still used for history. |
| Lock screen polish | 🔴 Not started | |
| Documentation site | 🔴 Not started | |

---

## 7. State File Inventory

| File | Owner | Contents |
|------|-------|----------|
| `~/.config/quickshell/zen-shell/panel-state.json` | PanelState | comprehensive panel + bar state |
| `~/.local/share/quickshell/zen-shell/bar-layout.json` | external scripts | bar module list only |
| `~/.config/quickshell/zen-shell/current-theme.json` | ThemeService | colors + theme + densho |
| `~/.config/quickshell/zen-shell/quick-notes.json` | QuickNotesService | notes meta + sticky + positions + bodies backup (hf74) + notesMeta calendar (hf75) |
| `~/.config/quickshell/zen-shell/widgets-state.json` | DesktopWidgets | widget positions + visibility |
| `~/.config/quickshell/zen-shell/title-translator.json` | TitleTranslatorService | config |
| `~/.cache/zen-shell/title-translations.json` | TitleTranslatorService | translation cache |
| `~/.config/quickshell/zen-shell/network-pulse.json` | NetworkPulseService | config |
| `~/.config/quickshell/zen-shell/smart-dim.json` | SmartDimService | rules + baseline |
| `~/.config/quickshell/zen-shell/hyprbars.json` | HyprbarsService | enabled + colors + buttons + autoLoadEnabled (hf59) + showMimicFallback (hf60) |
| `~/.config/quickshell/zen-shell/games.json` | GameProfileService | learned games + classPatterns + titlePatterns + processPatterns + ignoreClasses + gpuBusyThreshold (hf79) + autoPowerSwitch (hf82) — **actually persisting since hf82b** |
| `~/.local/share/zen-notes/*.md` | QuickNotesService | individual note markdown files |
| `~/.cache/quickshell/crashes/<minidump-id>/` | Quickshell native | C++ crash reports (meta.json + qml-stack.txt + minidump) |

**Install layout note (hf81+):** Paul's flat install path is `~/.config/quickshell/zen-shell/` directly, not nested under `zen-shell-v5/`. The release tarball ships `zen-shell-v5/*.qml` which `install.sh` flattens into the config root.

---

## 8. Path to v7.0.0 Stable

```
hf82d-87   → Quickshell crash hunt close-out + Taskbar QoL + Calendar split-view + per-app rules
hf88-95    → Tategaki Redux (staged vertical bar)
beta.2     → ← cut here for stability pass
hf96-105   → Plugin System V2
hf106-115  → Matugen polish + Theme importer + Wallpaper picker + Notes ODT export
beta.3     → ← final QA + docs site
v7.0.0     → 🎉 Stable + codename reveal at gekinzen.github.io/zen-shell-site
```

~13–18 sessions to stable at current pace (was 15–20 last revision; hf80–82c whittled the immediate notification + persistence blockers down). Order remains flexible — "it's my gaming month, push Tategaki later" is always valid.

---

## 8b. Upcoming — v7.1 (post-stable line)

> Targets for the FIRST minor after v7.0.0 ships. These build directly on
> the hf95.x dock / quick-terminal / SDDM / hyprbars-doctor work above.
> Nothing here removes anything — **we don't take features away.**

### Quick terminal v2
- Per-edge spawn (top/bottom/left/right) + size presets, animation
  bezier tuning, optional theme-synced colors written into
  `alacritty-quick` on theme change, optional blur, and a Settings page
  (currently keybind + window-rule only).

### Dock v2
- Per-app **scroll-to-reveal hover** while overflowed, optional
  **magnify-on-hover** (macOS genie), drag-reorder inside the dock
  (taskbar drag already inherited), and **auto-hide / reveal-on-edge**
  mode with reserve-space awareness.

### SDDM / login v2
- Theme-preview thumbnail in Settings → Login Screen, per-monitor greeter
  wallpaper, and a "test greeter" launcher; finish the avatar→
  AccountsService publish path so every user's face shows automatically.

### Hyprbars / plugin reliability
- Fold `zen-hyprbars-doctor.sh` logic into a **generic plugin doctor**
  (any hyprpm plugin, not just hyprbars), and a Settings → Hyprland
  Plugins "Repair" button that runs it in-shell with live output.
- Auto-run the version-skew check on shell start and surface a
  non-spammy "relogin to finish Hyprland update" banner.

### User management v2
- Progress as a proper stepped UI (not just banner text), an explicit
  "no polkit agent" pre-check before launching, and a dry-run preview of
  what the dotfile clone will copy.

### Multi-monitor polish (carry-over, prioritized for 7.1)
- Per-monitor dock/bar size overrides, hot-plug re-placement, and
  mixed-DPI scale-correct dock icon sizing.

### Settings UX
- Re-evaluate the optional title bar on layer-shell popups (the
  HyprbarsMimic work is parked, not deleted) — possibly a lightweight
  native-style header toggle instead of mimicking hyprbars.

---

## 8c. New user-facing features added in the hf95.x run (changelog digest)

For the v7 release notes / site "What's new" — the concrete additions a
user can see and toggle:

1. **Quick drop-down terminal** — Super+Shift+T, top-center, separate
   config, doesn't touch your main Alacritty.
2. **Zen Tokyo SDDM greeter** — themed login screen that tracks your Zen
   theme + wallpaper, with a one-toggle DM switch (and safe restore).
3. **`zen-hyprbars-doctor.sh`** — fixes the hyprpm "Outdated headers" /
   version-mismatch failures automatically (purge-cache retry → AUR build
   → direct load), with a troubleshooting guide.
4. **Floating taskbar icons** — icons float inside the bar with padding so
   window-count badges are visible.
5. **Dock dynamic sizing** — icons auto-shrink to fit in
   fullwidth/floating, then scroll arrows; plus an **Icon size** slider
   and a **Minimum icon scale** slider.
6. **Taskbar width cap slider** — control where the taskbar's scroll
   arrows kick in (was a hardcoded 440px).
7. **Monitor targeting** (surfaced) — bar and dock each choose
   primary / all / a specific monitor, auto-detected.
8. **Reliable user creation** — live progress + watchdog + clear errors
   when no polkit agent is running.
9. **Upward-opening dropdowns** — Settings dropdowns near the window
   bottom now open upward so they stay clickable.

---

## 9. Reconciliation Notes

What changed in this revision vs the 2026-05-19 cut:

1. **hf80 placeholder filled in.** Notification hardening second pass — rate limiter, body sanitization at reception, image-field hardening, `_nativeMap` cap, `_clearNative` recursion fix, warmup gate.
2. **hf81 documented.** Pure-infrastructure version pin drop.
3. **hf82 → hf82b → hf82c added as full hotfix entries.** Three concurrent user reports (Lark crash defense round 3, opt-in auto-power, live calendar↔sticky sync) → critical FileView bug discovered via user crash log → defensive hardening pre-emptive shot.
4. **Original 18-list status column updated.** Items 4, 13, 14, 16 got "Where it lives now" amendments reflecting hf80/hf82/hf82b/hf82c work.
5. **Beta blockers — new row** for the Quickshell C++ crash under Lark storm, marked 🟡 active debug.
6. **Section 4 — new "Just-shipped from previous Next Up list" subtable** tracking items that cleared between revisions, so the next revision can keep the burn-down honest.
7. **State file inventory — games.json line expanded** to call out the hf82b "actually persisting since" caveat. New row added for Quickshell crash dump folder under `~/.cache/quickshell/crashes/`.
8. **Path to v7.0.0 — milestone numbers shifted** to reflect hf82c as the current head and ~13–18 sessions remaining estimate (down from 15–20).
9. **Install layout note added** to section 7 — Paul's flat path discovered the hard way mid-debug session, worth documenting so it doesn't get re-litigated next refactor.
10. **hf82d added** (2026-05-23 follow-up): three user-reported UI bugs on surfaces hf82 touched — calendar editor showing date instead of saved note title, sticky window blank on first open due to mount-vs-load race, stale ZenVersion strings showing hf75 in System Info. New "Component.onCompleted race" thread added to open threads section as a class of bugs worth auditing.
11. **hf82e added** (2026-05-24 follow-up): screenshot from user showed every saved calendar note rendering as `📅 2026-05-23` instead of the user's typed text — both in calendar list AND in the sticky panel sidebar. Root cause was deeper than hf82d's editor-input fix: the stored `.title` field itself was wrong because the scan-time bash extraction grabbed the 📅 prefix line. Plus a separate report: flameshot region picker overshoots the visible workspace on a 1.5x scaled monitor — `zen-screenshot.sh` was printing native dimensions to flameshot `--region` instead of the already-computed logical values. Both fixed in this drop.
12. **hf82f added** (2026-05-24 follow-up): user requested Taskbar drag-to-reorder for pinned apps. Was P0 Immediate next up; pulled forward. Architectural change: `taskbarRow` switched from RowLayout to Item with manual x positioning per icon — RowLayout's Layout.preferred* properties made smooth drag impossible. Per-icon `effectiveIndex` computed from current drag state shifts neighbors aside smoothly via `Behavior on x`. Adds open thread for overflow + drag interaction (auto-scroll during edge-hover) at users with 12+ pinned apps.
13. **hf82g added** (2026-05-24 same-day follow-up): two issues from a single user screenshot. (a) hf82f drag only worked for pinned apps; user couldn't drag the running-but-not-pinned icons at the end of the bar. Fix: auto-pin on drag-start, auto-unpin on cancel. (b) hf82e flameshot logical-dimensions attempt still cropped on 1.25x/1.5x scales — flameshot's Wayland `--region` is upstream-buggy across fractional scales. Fix v2: drop `--region` entirely; let flameshot auto-detect the focused screen. Plus bumped install.sh banner from hf75/hf58 → hf82g (was an open thread; partially closed now).
14. **hf82h added** (2026-05-24 same-day follow-up): WorkspaceOverview empty on first Super+Tab after shell start. THIRD hit of the QML parent.visible→child.visible cascade race in the hf82 series. The pattern: a Rectangle inside a PanelWindow has `visible: true` default that never reassigns; when PanelWindow.visible flips false→true on first open, the child Rectangle's `visibleChanged` doesn't fire. Fix pattern (now confirmed across 3 components): subscribe directly to the authoritative source-of-truth property via Connections, treat existing onVisibleChanged as backup. Added codebase-wide audit as an open thread for the next session.
15. **hf82i added** (2026-05-24 same-day follow-up): ZenStrings rope misaligned vertically when bar at top. `slotCenterY` binding in shell.qml had bottom-anchored math only — `if (PanelState.isTop)` branch was missing. Fix adds the symmetric top-case calculation that mirrors how the strings window's own margins.top/margins.bottom already handle both cases. Pattern is "panel-position-aware calculation" — a new audit dimension added to open threads.
16. **hf82j added** (2026-05-24 same-day follow-up): three user asks in one turn. (a) Screenshot ropes lacked independent color config — added `ropeColorMode` with inherit/theme/synced/custom modes to ZenStringsState; custom mode is direct hex passthrough for "accurate" coloring. (b) UpdatesPage was still using Qt platform `Switch` → swapped to HMSwitch. (c) Comprehensive Check-for-Updates setup guide embedded in CHANGELOG, since the user asked "how do I connect this" + "write a guide". Update infrastructure has been complete since alpha.1; just needed the docs.
17. **hf82k added** (2026-05-24): major feature — Dock surface foundation. User asked for full Mac-dock-style second module surface with widgets, drag, workspace popup, divider, control center, top/bottom positioning, theme sync, plus desktop icons. Honest phasing: shipped Phase 1 (dock + modules + theme sync + drag/popup via widget reuse + control-center stub + settings page) in hf82k, deferred control center popup to hf82l, desktop icons to hf82m. ~1014 new lines across 5 new files + 2 modified. Default `enabled: false` so opt-in.
18. **hf82k.1 added** (2026-05-24): mini-patch correcting Dock default modules array after user's explicit elicitation answers came in post-shipment. Reduced from 6-item full set to lean 2-item set (`taskbar, workspaces`). All previously-default modules still addable via DockPage. Took 3 files (DockState + DockPage + ZenVersion). Renumbered Dock Phase 2 / 3 to hf82m / hf82n since hf82l now belongs to compat work.
19. **hf82l added** (2026-05-25): user upgraded Hyprland to 0.55 and hit three config errors (dwindle:pseudotile removed in 0.55, togglesplit dispatcher removed in 0.54 — user skipped 0.54 so first surfaced now, plus cascade). Fixed shipped configs directly (binds.conf + hyprland.conf.template) AND added a version-aware sanitizer to install.sh that detects Hyprland version + applies appropriate strip/rewrite to existing user configs. Idempotent, backs up before edit, extensible for future versions (just add `_strip_hl5N_breakages()`). 4 files, +170 lines.

20. **hf83–hf85 added** (2026-05-30): user-driven cluster from screenshots of the running shell. hf83 — four asks in one turn (auto bar height, full-width Settings title, dock no-overlap-with-tiles, desktop icons as one resizable widget). hf84 — follow-up after user showed the bar icons weren't fitting: the *contents* needed to scale to the bar, not the bar to the contents — root cause was the big modules (Taskbar/SysRow/Workspaces) using hardcoded sizes instead of Theme.iconSize, so added Theme.barContentScale + per-module `_fit` hooks. hf85 — four more (search auto-hide removal now that search is pinned in the header, guaranteed bar vertical centering+padding, new-user dotfile clone, custom PNG icons via right-click picker). New open threads: (a) Taskbar drag-positioning under scaled btnSize, (b) cross-singleton readonly-binding pattern (Theme reading PanelState.barFitContents) — confirmed safe via typeof guard, worth standardizing, (c) dotfile-clone is the seed for the standalone installer P0.


Previous revision's bookkeeping notes (two docs collapsed, original 18-list folded, hotfix detail consolidated, Hyprbars saga compressed, hf80 placeholder, codename framing) carried forward unchanged where still accurate.

---

## 10. Open Threads (carry-forward for next session)

- **Quickshell crash dump capture.** Top of the list. Targeted notification-area patch depends on it. Fish-friendly one-liner from chat:
  ```fish
  ls -la ~/.cache/quickshell/crashes/; and \
  set LATEST (ls -td ~/.cache/quickshell/crashes/*/ | head -1); and \
  echo "=== Latest: $LATEST ==="; and ls -la $LATEST; and \
  for f in (find $LATEST -type f \( -name "*.txt" -o -name "*.log" -o -name "*.json" -o -name "info*" -o -name "meta*" -o -name "stack*" \))
      echo "--- $f ---"; cat $f
  end
  ```
- **Auto-derive version string at build time.** hf82d uncovered that `ZenVersion.qml` was carrying hf75 strings while the running shell was on hf82c. Manual bump every drop is error-prone. Build-time stamp from `git describe --tags --always` or release tarball filename → write into `ZenVersion.qml` before tar would solve permanently. Out of scope for hf82d itself; flagged for next infrastructure session alongside the install.sh embedded changelog refresh.
- **`install.sh` embedded changelog** ✅ partially resolved hf82g — top banner + closing banner + Done line bumped from hf75/hf58 → hf82g, with fresh hf82a-82g summary block prepended. Historical changelog blocks deeper in install.sh (hf58, hf62 detail) preserved as documentation. Auto-derivation at build time still TODO.
- **GameProfileService persistence regression test.** hf82b uncovered that `games.json` had been silently failing for months. Add a round-trip test (write known JSON → restart → confirm loaded values) before signing off the Settings persistence audit P0 blocker.
- **Quickshell FileView API check.** The `text()` callable vs `text` property shape may have been a Quickshell version change. Worth a one-line search through other services that use FileView (`QuickNotesService`, `HyprbarsService`, `SmartDimService`, etc.) to confirm none have the same latent bug. Apply the same `(typeof text === "function") ? text() : text` defensive shape preemptively if found.
- **Component.onCompleted vs declarative binding race.** hf82d/hf82e/hf82h uncovered three instances of the same class of bug — any QML component that depends on a singleton service's data via `Component.onCompleted` + `onVisibleChanged` has a race if the service finishes loading after the component mounts OR if visibility propagation through PanelWindow doesn't fire the child's visibleChanged signal. Pattern fix established and now applied in:
  - QuickNotesSticky + DesktopStickyNotes (hf82d) — `onNoteChanged` + `onVisibleChanged` Connections
  - ZenNotificationCenter calendar repeater (hf82e) — per-row `loadBody()` trigger
  - WorkspaceOverview (hf82h) — `Connections { target: PanelState; onWorkspaceOverviewVisibleChanged }` + 4 backup layers

  **Codebase-wide audit pending.** Likely affected: StartMenu, ClipboardPanel, NotificationCenter, SearchOverlay, ContextMenus, anything else mounted via `Variants { model: Quickshell.screens }` + `PanelWindow` + `visible: <PanelState property>` pattern. Standard pattern to apply: subscribe to the PanelState toggle directly, don't rely on Rectangle.visibleChanged inside the PanelWindow.
- **`versions.lock` test matrix.** hf81 baked in the version-check infrastructure but the policy table (patch float / minor newer warn / minor older block) hasn't been exercised against a real Hyprland minor bump yet. Next Hyprland 0.55 release is the natural test event.
- **Panel-position-aware calculation audit.** hf82i uncovered the pattern of "math that assumes bottom-anchored bar without an `isTop` branch". Likely affects other floating overlays anchored relative to the bar: Hyprbars title-bar previews, hot-corner indicators, OSDs (volume/brightness/lock), notification toast Y position, popup anchor edges, anything that hard-codes `panelMarginBottom` without a corresponding `panelMarginTop` case. Pre-screen these so they don't surface one by one as user-facing reports.
- **`Switch` → `HMSwitch` audit.** hf82j surfaced that UpdatesPage was the last (?) place still using Qt's platform `Switch`. Quick grep:
  ```fish
  grep -rn "^\\s*Switch {$" ~/.config/quickshell/zen-shell/*.qml
  ```
  Any hits = candidates for the swap. The HMSwitch centralization was in v6.16.1.4; pages added or last touched before that may still have stragglers.
- **Dock Phase 2 (hf82l).** ZenControlCenter popup (volume sliders / wifi toggle / BT toggle / power profile picker / brightness slider), plus drag-to-reorder list UI in DockPage to replace up/down buttons. Estimated ~700 lines.
- **Dock Phase 3 (hf82m).** Desktop icons feature — separate WlrLayer.Bottom surface scanning `~/Desktop/`, draggable icons with saved positions in `~/.local/share/quickshell/zen-shell/desktop-icons.json`, Android-style resize handles, auto-arrange mode. Also dock auto-hide-on-cursor-reveal (Mac-dock behavior), per-app dock badges (notification count overlay). Estimated ~900 lines.
- **Hyprland minor-version compat tracking** (NEW from hf82l). Sanitizer covers 0.54 + 0.55. Next breaks (0.56, 0.57, etc.) need monitoring upstream release notes + a new `_strip_hl56_breakages()` function each time. Could automate via a small CI check that diffs Hyprland's wiki between releases. Also: `misc:vfr` → `debug:vfr` migration not auto-applied (needs hyprlang-block-context awareness — out of scope for sed); sanitizer prints a NOTE if it detects `vfr =`, user fixes manually.
- **Taskbar drag + overflow auto-scroll.** hf82f shipped drag-to-reorder but doesn't auto-scroll the taskbar when you drag an icon near the edges of the visible viewport while the chevron-scroll overflow is active. Affects users with 12+ pinned apps (taskbarRow.implicitWidth > maxVisibleWidth = 440). The fix is to add a `Timer` that increments/decrements `scrollOffset` when `_dragCursorX` is within the last ~30px of the viewport edge. Not urgent — most users don't hit the overflow threshold. Queue for hf82g or a future Taskbar QoL pass.
