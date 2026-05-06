# Beta Blockers

This document tracks what needs to land before the current alpha line
(v6.16.x) graduates to a beta-stable cut (target: v6.17.x).

Updated as items resolve. Items here are NOT promises about timeline —
they're a commitment about scope of "beta-quality."

## P0 — Must land before beta

### Tategaki redux complete

The vertical-bar rendering attempt rolled back in Modori .9 needs to
return, this time with proper staged validation:

- [ ] **Workspaces** vertical-aware (one drop, ship, validate)
- [ ] **SysRow** vertical-aware (one drop)
- [ ] **Taskbar** vertical-aware including chevron-pagination on the
      Y axis (one drop — this is the trickiest)
- [ ] **SystemTray** vertical-aware
- [ ] **Battery / PowerBadge / NotificationIcon** vertical-aware
      (mostly square chips, low risk — can land together)
- [ ] **Bar.qml** outer layout: Loader-driven RowLayout/ColumnLayout
      swap (NOT GridLayout flow tricks — those failed in .8.3)
- [ ] **shell.qml** barWindow 4-direction anchor matrix +
      dimension swap
- [ ] **Audit every `PanelState.isVertical` consumer outside the bar**
      — Modori .9.3 had to hide L/R cards because ZenSettings.qml's
      sidebar reacted to `isVertical` but the bar stayed horizontal
      after the .9 rollback. Inconsistency like that needs to be
      impossible by design.
- [ ] **Re-add Left/Right panel position cards** to PanelPage with
      the partial-support yellow notice removed.

### Plugin system v2

Plugin manager has been hidden since Hikari .51 because the loading
interface is being reworked. Beta-quality plugins need:

- [ ] Signed-manifest plugins (avoid arbitrary code execution
      surprises — current plugin loading is `qs ipc -> import URL`
      which has no manifest validation).
- [ ] Per-plugin sandboxing for QML scope (isolate plugin state
      from shell singletons).
- [ ] Dependency declaration in plugin manifest (`requires:
      ["Quickshell.Hyprland", "Quickshell.Services.Mpris"]`).
- [ ] Plugin manager UI returns to Settings (currently hidden).
- [ ] Community plugin registry — at minimum a curated index in
      `Gekinzen/zen-plugins-registry/` with manifest validation.

### Settings persistence audit

Modori .9.1 surfaced the `bar-layout.json` clobbering `panel-state.json`
issue. Need to audit every other state file in the shell for similar
patterns:

- [ ] Inventory every FileView in `zen-shell-v5/` and document
      what file each one writes vs reads.
- [ ] Identify any state field written by MORE THAN ONE source
      (current bug pattern: `Theme.styleMode` was written by both
      `panel-state.json` load and `bar-layout.json` load).
- [ ] Establish single-source-of-truth ownership for every state
      field. Document in `STATE-OWNERSHIP.md`.
- [ ] Add a debug overlay (Settings → Diagnostics → State Inspector)
      showing live state-field values + their source files.

### Wayland layer-shell positioning math (multi-monitor edge cases)

Multi-monitor setups currently work in the common cases (mirror,
extended) but have known issues with:

- [ ] Mixed-DPI monitors (1× + 2× scaling) — bar position is correct
      but blur/shadow effects clip wrong.
- [ ] Hot-plug during shell runtime — Quickshell handles the new
      monitor itself but PanelState's `barTargetDisplay` selection
      doesn't always migrate cleanly.
- [ ] Vertical-monitor-rotated-90° setups — bar dimensions are
      correct but mouse coordinates for popup positioning need work.

## P1 — Should land before beta

### Matugen polish

Material You wallpaper-driven theming was added opt-in in
v6.16.4.12.6. Beta-quality:

- [ ] First-class Settings → Themes integration (live preview
      pane, per-mode targets).
- [ ] Smart-contrast pass already protects Matugen output (Modori
      .9.4) — verify with a corpus of 20+ test wallpapers.
- [ ] Palette extraction visualization (show the user which colors
      came from where in the wallpaper).
- [ ] Per-target overrides (e.g. "Matugen for everything except
      keep my custom `orange`").

### Theme importer with smart-contrast preview

- [ ] Side-by-side preview pane: theme-as-designed vs theme-after-
      smart-contrast-correction.
- [ ] Opt-out flag `"smart_contrast": false` in theme JSON for
      designers who specifically want stylistic near-invisible
      tones.
- [ ] Bulk theme import (drop a folder of `.json` files in).

### Wallpaper picker online repo browser

- [ ] In-app browser for `Gekinzen/images-demo/wallpapers/` —
      preview thumbnails, one-click apply, no leaving the panel.
- [ ] Featured wallpapers section (Modori Dark/Light + community
      submissions).
- [ ] Per-wallpaper smart-contrast theme suggestion (apply
      Matugen automatically when wallpaper is applied).

### MusicStrings on vertical bars

After Tategaki redux, the audio-reactive MusicStrings overlay
needs to work on vertical bars:

- [ ] Rotate the ZenStrings rendered output 90° via Qt transform
      (the .8.3 attempt at this approach is preserved as a
      reference; the parse error was unrelated to the rotation).
- [ ] Ensure `stringsWindow` 4-direction anchoring matches barWindow.
- [ ] Verify slot position tracking works when bar flow is
      vertical (the parent-walk `.x` → `.y` swap in Bar.qml's
      `_doUpdatePos` from .8.3 is the correct approach but needs
      runtime test).

## P2 — Nice to have

### Notification system overhaul

Current swaync integration is functional but feels bolted on. Beta:

- [ ] Native QML notification surface inside the shell (no
      external swaync process required).
- [ ] Per-app notification rules (priority, mute, do-not-disturb
      schedules).
- [ ] Notification center popup matching the bar's theme.

### Lock screen polish

Hyprlock integration works but:

- [ ] Wallpaper-aware lock screen (current Modori dark/light
      wallpaper as the lock background by default).
- [ ] Optional clock + weather + media controls on the lock.
- [ ] Per-monitor lock backgrounds (different wallpaper per
      monitor).

### Documentation site

- [ ] Static site (probably MkDocs Material) hosted at
      gekinzen.github.io/zen-shell or similar.
- [ ] All CHANGELOG entries searchable.
- [ ] Tutorials: "your first theme", "your first plugin", "writing
      a custom bar module".
- [ ] Community gallery of themes/wallpapers/configs.

## Already done (no longer blockers)

These items used to be blockers and are now resolved:

- ✅ Settings persistence (Module Shape / Bar Opacity / Bar Corner
     Radius silently reverting on restart) — fixed in Modori .9.1
- ✅ Slider-drag JSON corruption — fixed in Modori .9.1 via 200ms
     debounce timer
- ✅ Smart-contrast theme engine — landed in Modori .9.4
- ✅ Default wallpaper paired with default theme (Modori Dark) —
     landed in Modori .9.4
- ✅ User identity surface in Settings (sidebar bottom row) —
     landed in Tachiagari .7
- ✅ 4-direction popup edge logic (popups grow correctly on
     top/bottom bars) — landed in Tachiagari .7
- ✅ Top-bar popup adaptation — landed in Tachiagari .7
- ✅ Smart Gaming Detection — landed in Tachiagari .7
- ✅ Pill module shape (was clamping to round) — fixed in
     Tachiagari .7
- ✅ Click-to-open Clock + StartMenu (no hover open) — landed in
     Hiraki .52
- ✅ Calendar popup positioning — fixed in Hiraki .53
- ✅ install.sh ZenClock-clobber — fixed in Hiraki .53
