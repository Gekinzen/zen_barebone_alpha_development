# v7.0.0-beta.1-hf82k — Dock surface foundation (Phase 1)

**Channel:** beta (hotfix patch on hf82j)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 5 new QML files + 2 modified + ZenVersion bump

---

## User request

> "okay game paki dagdagan ng docker panel pre and yung docker pwd din malagyan ng ibang widgets, pero default kung anu yun nasa taskbar ko make it sure draggable din and same feature pati yun workspace numbers count and yun pop up as in same tas yun divider natin katulad nung palagay nln din sa panel hypr control center. and pwd assign sa top or bottom din and synced din sa qml bar settings natin if anu yun border color etc and based din sa theme pre. and enable natin yun desktop icons toggle din pero draggble din kht san ilagay sa desktop ah or auto. or resize prang sa android"

Translation:
1. Add a Dock panel (Mac-dock-style second surface)
2. Fillable with widgets, defaults to what's in the taskbar
3. Draggable items
4. Same workspace counter + popup feature
5. Divider widget plus a Hypr Control Center
6. Assignable top or bottom
7. Synced with bar settings (border color, theme)
8. Desktop icons toggle, draggable anywhere on desktop, auto-arrange, Android-style resize

---

## What ships in hf82k (Phase 1)

Honest scoping: this is **a 3-phase feature**, hf82k builds the foundation.

✅ **In hf82k:**
- Dock surface (PanelWindow per screen, fullwidth/floating/island modes)
- Top OR bottom positioning (independent of bar)
- DockState singleton (persisted state)
- Module manifest system (which widgets appear)
- Default modules: `start`, `taskbar`, `workspaces`, `divider`, `sysrow`, `controlcenter`
- Reuse of existing widgets — **drag (hf82g) + workspace popup come for free**
- Theme sync from bar (toggle) — border, background, blur, radius
- Per-dock override fields when sync is off
- DockPage settings (general / appearance / modules with up/down/remove + add)
- Sidebar entry registered
- ControlCenterButton stub (placeholder; popup ships next)

⏳ **Deferred to hf82l (Phase 2):**
- Control Center popup (volume sliders, wifi/bt toggles, power profile, brightness)
- Drag-to-reorder list UI in DockPage (currently uses up/down buttons — feature-equivalent)
- Per-dock-instance module slots (e.g. two docks with different layouts)

⏳ **Deferred to hf82m (Phase 3):**
- Desktop icons feature (separate WlrLayer.Bottom surface)
- Auto-scan ~/Desktop/ contents
- Draggable icons with saved positions
- Auto-arrange mode
- Android-style resize handles

Each phase ships testable. You can stop at any phase if the next isn't worth it.

---

## How it works

### The dock surface (`shell.qml`)
A new `Variants { model: Quickshell.screens }` block mounts a PanelWindow per screen, mirroring how the bar does multi-monitor. Its `visible` binding gates on `DockState.enabled` AND `DockState.showOnMonitor` matching the screen (or `"all"` / `"primary"`).

Anchors flip based on `DockState.position`:
- `"top"` → `anchors.top: true`
- `"bottom"` → `anchors.bottom: true`

Edge margin (`DockState.marginEdge`) applies to whichever edge is anchored. The `anchors.left/right` are only set in `fullwidth` mode; in `floating` and `island` modes, the PanelWindow's `implicitWidth` is hug-content (capped at screen width minus side margins).

`WlrLayer.Top` + `ExclusionMode.Ignore` = sits over windows like the bar but doesn't reserve space (Mac-dock behavior — windows can extend beneath it).

### Module reuse (`ZenDock.qml`)
Mirrors `Bar.qml`'s module dispatcher pattern. Each module is a `Component { id: cFoo; Foo {} }`, resolved via `getComponent(name)`. The dock's RowLayout iterates `DockState.modules` and instantiates each via a `Loader` with `sourceComponent: dockRoot.getComponent(modelData)`.

Recognized module ids: `start`, `taskbar`, `workspaces`, `divider`, `sysrow`, `controlcenter`, `tray`, `clock`, `battery`, `notifications`.

**Critical design choice:** the dock reuses the BAR'S existing widgets unchanged. This means:
- The Taskbar widget inside the dock inherits the hf82g universal drag-to-reorder
- The Workspaces widget inherits the workspace popup + count
- StartMenu, SysRow etc. all work identically to how they do in the bar

Zero new widget code needed for parity with the bar.

### Theme sync (`ZenDock.qml`)
When `DockState.syncFromBar === true`:
- `radius` = `Theme.styleMode === "round" ? 22 : Theme.barRadius`
- `color` = mirrors `Bar.qml`'s color resolution (PanelState.bgOverrideEnabled OR ThemeService.bg0 at PanelState.barOpacity)
- `border.color` = `ThemeService.fg` at 12% alpha
- `border.width` = `PanelState.borderEnabled ? PanelState.borderWidth : 0`

Toggle `syncFromBar` off and the dock uses its own override fields (`DockState.overrideBgColor`, `overrideBorderColor`, etc.) — set in DockPage. Override values persist regardless of sync state, so toggling sync off doesn't reset previous picks.

### Persistence (`DockState.qml`)
Standard `pragma Singleton` + `FileView` + debounced `Process` saver pattern. State lives at `~/.local/share/quickshell/zen-shell/dock-state.json`. Survives shell restart and the hf82e atomic-write race patterns are applied (mkdir + mktemp + mv).

### Settings page (`DockPage.qml`)
Three sections matching the visual language of GeneralPage / PanelPage:
1. **General**: enable, position, mode, monitor target, height, margins
2. **Appearance**: sync-from-bar toggle + per-dock override fields when off
3. **Modules**: enable/disable + reorder (up/down) + add-from-picker + reset

Uses `HMSection`, `HMRow`, `HMSwitch`, `NumericStepper`, `ZenDropdown`, `ColorSwatch`, `DenshoPageHeader` — all standard project components. No new UI primitives needed.

### Control Center stub (`ControlCenterButton.qml`)
36×36 round button with a gear icon. Visual quality is final (theme-aware hover, smooth color animation, proper icon font fallback). The click handler is intentionally a placeholder:

```qml
Process { id: notifier; ... }
function _fire() {
    notifier.command = ["notify-send", "-a", "Zen Shell",
        "Control Center",
        "Coming in hf82l — quick-settings popup with volume, wifi, BT, power profile, brightness."]
    notifier.running = true
}
```

In hf82l this becomes a one-line change to open `ZenControlCenter` popup. The visual stays.

### Divider (`ZenDivider.qml`)
1px vertical separator, theme-aware (`ThemeService.fg` at 25% alpha). 60% height ratio by default so it doesn't bisect the full dock — it reads as a "module boundary" instead of a wall. Sizes via implicit, slots into any RowLayout.

---

## Files

| File | Status | Lines | Purpose |
|---|---|---:|---|
| `DockState.qml` | NEW | 244 | Singleton + persistence + mutators |
| `ZenDock.qml` | NEW | 165 | Dock body — RowLayout of module Loaders |
| `ZenDivider.qml` | NEW | 42 | Vertical separator widget |
| `ControlCenterButton.qml` | NEW | 96 | Stub button (popup deferred to hf82l) |
| `DockPage.qml` | NEW | 368 | Settings UI |
| `shell.qml` | MODIFIED | +94 | New Variants { model: screens } > PanelWindow mount |
| `ZenSettings.qml` | MODIFIED | +5 | Sidebar entry + StackLayout registration |
| `ZenVersion.qml` | MODIFIED | +0 | hf82j → hf82k bump |
| **Total** | | **~1014 new lines** | |

---

## Install

Drop-in over hf82j:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82k-patch-only.tgz

cp zen-shell-v7.0.0-beta.1-hf82k/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

### First-launch experience
The dock is **opt-in**. After hf82k install, nothing visually changes until you flip the toggle:

1. Open Settings → sidebar now has "Dock" entry (under SYSTEM section, after Game Detection)
2. Toggle "Enable dock" → dock appears at the bottom, island mode, with start/taskbar/workspaces/divider/sysrow/controlcenter
3. Default `position: bottom`, `mode: island`, `syncFromBar: true`

### Verify

1. **Dock renders** — toggle on. Should see Mac-dock-style centered pill at bottom of screen.
2. **Default modules visible** — start menu on left, your taskbar pinned/running apps next, workspaces strip, vertical divider, sysrow cluster, gear-icon control center button on the right.
3. **Drag works on dock taskbar** — press-hold any icon in the dock's taskbar widget → drag → drop. (hf82g pattern auto-inherited.)
4. **Workspace popup works on dock** — hover a workspace number in the dock → popup shows window thumbnails. (Workspaces widget feature.)
5. **Top/bottom toggle** — Settings → Dock → Position. Dock should flip instantly.
6. **Theme sync** — change theme color in Themes page → dock's border + background update automatically.
7. **Theme sync OFF** — toggle off, then pick custom override colors → dock uses those instead.
8. **Module reorder** — Settings → Dock → Modules section → use ↑/↓ buttons. Module order updates in real time.
9. **Add/remove module** — picker dropdown adds unused modules; X button removes.
10. **Control center button** — click it → notify-send appears saying "Coming in hf82l".
11. **Settings → System Info** → `v7.0.0-beta.1-hf82k · released 2026-05-24`.

### Multi-monitor

`DockState.showOnMonitor` defaults to `"primary"` (first screen only). Change to `"all"` for every monitor, or pick a specific monitor name (e.g. `"DP-2"`).

---

## Architectural notes

### Why a new singleton (DockState) instead of extending PanelState?

PanelState carries bar-specific state — position, mode, layout, height, margins. The dock has independent position/mode/etc., so embedding them in PanelState would either:
- Duplicate all those properties with `dock` prefixes (PanelState.dockPosition, etc.) — messy
- Couple dock state to bar state — bar position changes would risk affecting dock

A separate singleton keeps the surfaces decoupled and matches the precedent of `ZenStringsState` (which is independent of `PanelState` for the same reason). The `syncFromBar` flag explicitly opts INTO coupling for visual fields only.

### Why reuse Bar widgets instead of dock-specific copies?

User asked: "default kung anu yun nasa taskbar ko" + "same feature pati yun workspace numbers count and yun pop up as in same." Reusing widgets is the only honest way to deliver same-feature parity. If we copied widgets, we'd have to maintain hf82g drag in TWO places, workspace popup in TWO places, etc.

Reuse means:
- The dock's Taskbar IS your Taskbar
- The dock's Workspaces IS your Workspaces  
- One bug fix fixes both surfaces
- One feature add benefits both surfaces

The widgets don't know they're inside the dock vs. the bar — they just render. Theme, drag, popups all work identically.

### Why hf82k doesn't do drag-to-reorder LIST UI for modules?

A proper drag-to-reorder list (long-press, slot animation, drop commit) inside DockPage would be ~300-400 lines on its own and exhibit the same QML race patterns the hf82d/e/h family bugs uncovered. The up/down/remove buttons + add picker is feature-equivalent and ships in hf82k. Drag list UI is a candidate for hf82l once Phase 1 has settled.

### Race surface

The dock is mounted via `Variants { model: Quickshell.screens } > PanelWindow > ZenDock` — exactly the pattern that hit hf82h's first-open-empty race. The dock body Rectangle (`ZenDock`) doesn't depend on async data load (no `Component.onCompleted { _refresh() }`), so it's not vulnerable to the same race.

However, if modules get added later that DO depend on async data (e.g. a recent-files module that reads from disk), they'd need the hf82h Connections-on-singleton-property pattern applied.

---

## Wala tayong babawasan

Five new files, two modified files, zero removals. The dock is gated behind `DockState.enabled = false` by default, so pre-hf82k visual behavior is preserved unconditionally.

The two modifications to existing files:
1. `shell.qml` — new `Variants { ... } > PanelWindow > ZenDock` block inserted between barWindow Variants and stringsWindow Variants. No existing code touched.
2. `ZenSettings.qml` — one sidebar `navItems` entry added, one `currentIndex` switch case added, one Page instantiation added. All purely additive.

The bar continues to work identically. Existing widgets (Taskbar, Workspaces, StartMenu, SysRow) are read-only from the dock's perspective — the dock instantiates fresh instances of each Component, sharing the same singleton state but rendering independently.

---

## Open threads still active

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting (`--screen N`)
- Drag + overflow auto-scroll (12+ pinned apps edge case)
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit across the codebase
- Panel-position-aware calculation audit (`isTop` branches missing elsewhere)
- `Switch` → `HMSwitch` audit across settings pages
- **NEW from hf82k (Phase 1):**
  - hf82l: ZenControlCenter popup (volume / wifi / BT / power profile / brightness)
  - hf82l: drag-to-reorder list UI in DockPage (replace up/down buttons)
  - hf82m: Desktop icons feature (WlrLayer.Bottom + auto-scan + drag + resize + auto-arrange)
  - hf82m: dock auto-hide / reveal-on-cursor-edge (Mac-dock behavior)
  - hf82m: per-app dock badges (notification count overlay)
