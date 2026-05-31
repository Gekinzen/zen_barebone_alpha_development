# v7.0.0-beta.1-hf82o — Desktop icons (file/folder layer) + hf82n.1 scope fixes bundled

**Channel:** beta (hotfix on hf82n)
**Released:** 2026-05-25
**Scope:** 5 new files + 4 modified (shell.qml, ZenSettings.qml, hf82n.1 page fixes, ZenVersion)

---

## User request

> "may napnsin pala kapag setup change ko yun settings nung profile hindi naka align yun pop up sobrang taas yung pop up nasa taas na dapat nasa top ln nung icon prang mga memory cpu ko + pa provide na yun phase 1+ 2"

Two asks combined:
1. **Bug**: a "profile setup" popup is positioned too high (should be top-anchored to its icon like the CPU/memory hover popups)
2. **Feature**: Phase 1 + 2 of desktop icons + widgets (Android-style draggable + resizable)

### What this drop addresses

✅ **Phase 1 + 2 of desktop icons + widgets** (this changelog)
✅ **hf82n.1 scope bug fixes for Default Apps + App Float Rules** (bundled)
❌ **Profile setup popup position bug** — could not locate the specific popup in the codebase without more clues. Needs screenshot or more context. Tracked as open item.

---

## Important architectural correction

While building this, I discovered the codebase **already has** a desktop overlay system since v6.16.1.3:

| Existing file | What it provides |
|---|---|
| `DesktopWidgets.qml` (508+ lines) | Clock + Weather + SysMon widgets, drag, multi-monitor, persistence, scale, color themes |
| `DesktopStickyNotes.qml` | Widget-mode sticky notes (companion to QuickNotes) |
| `widgetWindow` in shell.qml | Per-screen `WlrLayer.Bottom` PanelWindow that hosts both |

**My initial plan** would have created a duplicate `DesktopWidget.qml` + standalone `desktopWindow` — DOUBLE-MOUNTING on `WlrLayer.Bottom` and conflicting with z-order.

**Corrected approach**: hf82o adds **only the file/folder icon layer** (the actual missing piece) and mounts it as a **SIBLING** of the existing widgets+stickies inside the **same** existing `widgetWindow`. Zero conflicts, zero duplication. Widgets stay where they are; this drop is purely additive.

Net new code: ~600 lines instead of 900 (saved by reusing existing widget system).

---

## What ships

### 5 new files (Desktop icons layer)

| File | Lines | Purpose |
|---|---:|---|
| `DesktopIconsState.qml` | 145 | Singleton: enable toggle + scan path + per-icon position persistence at `~/.local/share/quickshell/zen-shell/desktop-icons.json` |
| `DesktopIconsService.qml` | 100 | Scans the scan path every 30s, exposes `entries` array. Launch helper via `xdg-open` / `gtk-launch`. |
| `DesktopIcon.qml` | 165 | Single draggable icon: press-and-hold OR move-8px → drag engages. Free-form anywhere. Double-click to open. Scale animation + drop-shadow ring during drag. |
| `DesktopSurface.qml` | 80 | Container that runs the Repeater over `DesktopIconsService.entries`. Auto-flows icons without saved positions (column-major top-left → bottom-right). |
| `DesktopPage.qml` | 175 | Settings UI: enable, scan path, show folders, icon size, label color, maintenance buttons. Info banner pointing to existing Desktop Widgets page for widgets. |

### Files modified

| File | Δ | What |
|---|---:|---|
| `shell.qml` | +18 | Mount `DesktopSurface` as sibling of `DesktopWidgets`/`DesktopStickyNotes` inside the existing `widgetWindow` |
| `ZenSettings.qml` | +5 | Sidebar entry (`Desktop` / 卓上 Takujō under OTHER section) + StackLayout case 28 + page instantiation |
| `DefaultAppsPage.qml` | +1 / -7 | hf82n.1 fix: `parent.modelData` → `catRow.modelData` (added `id: catRow`) |
| `AppFloatRulesPage.qml` | +1 / -2 | hf82n.1 fix: `parent.wmClass` → `appRow.wmClass` (added `id: appRow`) |
| `ZenVersion.qml` | +0 | hf82n.1 → hf82o |

Total: 5 NEW + 4 MODIFIED + 1 VERSION = ~660 net new lines.

---

## How it works

### The drag pattern (Android-style)

Each `DesktopIcon` has two ways to engage drag:
1. **Press-and-hold** for 350ms
2. **Move 8px** while pressed (so quick double-click won't accidentally drag)

Visual feedback during drag: icon scales to 1.10× + gets a blue drop-shadow ring. Cursor changes to closed-hand. On release, position saves to `DesktopIconsState.iconPositions[name] = { x, y }`.

The Y position is clamped to parent bounds so users can't drag icons off-screen.

### Persistence

`~/.local/share/quickshell/zen-shell/desktop-icons.json`:
```json
{
  "enabled": true,
  "scanPath": "/home/paul/Desktop",
  "showFolderIcons": true,
  "iconSize": 64,
  "labelColor": "auto",
  "iconPositions": {
    "Documents":     { "x": 60,  "y": 80  },
    "Steam.desktop": { "x": 240, "y": 80  }
  }
}
```

Saved debounced (500ms after last change) via atomic mktemp + mv.

### Auto-flow for unpositioned icons

Icons without a saved `iconPositions[name]` entry get auto-placed via column-major flow: stacked vertically from the top-left padding, wrapping to a new column when they hit the bottom. Once user drags any icon, its position persists and overrides the flow. Other icons stay auto-flowed unless they too get dragged.

### Mount inside existing surface

`shell.qml` already has the `widgetWindow` Variants block for the desktop layer. hf82o adds DesktopSurface as a third sibling:

```qml
PanelWindow {
    id: widgetWindow
    WlrLayershell.layer: WlrLayer.Bottom
    // ... existing widget infrastructure ...

    DesktopWidgets { anchors.fill: parent }       // existing — clock/weather/sysmon
    DesktopStickyNotes { anchors.fill: parent }   // existing — sticky notes
    DesktopSurface { anchors.fill: parent }       // NEW (hf82o) — file/folder icons
}
```

Three sibling Items in one Wayland surface = correct z-order without any new compositor surface.

---

## Install

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82o.tgz
cd zen-shell-v7.0.0-beta.1-hf82o
./install.sh

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

---

## Verify

After install:

1. **Sidebar shows Default Apps + App Float Rules** (the hf82n.1 fix) — under PRODUCTIVITY section
2. **Sidebar shows Desktop** entry under OTHER section (between Wallpaper and PRODUCTIVITY break)
3. **Settings → Desktop** → toggle "Show desktop icons" ON
4. Put a few files/folders in `~/Desktop` (e.g. `touch ~/Desktop/hello.txt ; mkdir ~/Desktop/MyFolder`)
5. They should appear on the desktop with icons + labels, auto-flowed top-left
6. **Press-and-hold any icon** → drag to anywhere → drop → position saved
7. **Double-click an icon** → opens via xdg-open (folder → file manager, file → default handler)
8. **Restart shell** (`pkill -f quickshell; quickshell -p ~/.config/quickshell/zen-shell &`) → icon positions persist
9. **Settings → System Info** → `v7.0.0-beta.1-hf82o · released 2026-05-25`

### For widgets

Widgets (clock, weather, sysmon, sticky notes) were already supported in v6.x. They live in **Settings → Desktop Widgets** (sidebar id `widgets`), NOT in the new Desktop page. The new Desktop page has an info banner reminding you of this.

---

## Profile setup popup bug — open item

Tried to track down the popup you mentioned ("settings nung profile sobrang taas yung pop up") but couldn't find the specific component without more context. Searched:

- `UserProfilePage.qml`, `UserProfileService.qml`, `UserProfileExportService.qml`, `WorkflowProfilePicker.qml`, `WorkflowProfileBadge.qml`, `ProfileManagerSection.qml` — none have an obvious mis-positioned PopupWindow
- The canonical correct pattern is in `ZenSysMonitor.qml`:
  ```qml
  PopupWindow {
      anchor.item: sysRoot
      anchor.edges: Edges.Top
      anchor.gravity: Edges.Top
  }
  ```

**If you can share a screenshot or tell me exactly which click triggers the popup** (e.g. "clicking the avatar in the bar" or "Settings → User Profile → Edit Avatar"), I can fix the position in the next drop. Tracked as open item.

---

## Wala tayong babawasan

Zero removals. All existing desktop infrastructure (DesktopWidgets, DesktopStickyNotes, widgetWindow mount) preserved verbatim. Default `DesktopIconsState.enabled = false` so pre-hf82o desktop appearance is unchanged unconditionally.

The two hf82n bug fixes (parent.X scope issues in Default Apps + App Float Rules) are purely additive — added `id:` declarations on the HMRow delegates and rewrote the references; no behavior changes.

---

## Open threads (carry-forward + new)

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit
- Panel-position-aware (`isTop`) calculation audit
- `Switch` → `HMSwitch` audit
- Hyprland minor-version compat tracking (sanitizer for 0.56+)
- Dock Phase 2: ZenControlCenter popup + drag-to-reorder list UI
- User management (pkexec, useradd/userdel/wheel toggle, can't delete current user)
- **NEW from hf82o:** profile setup popup vertical position bug — needs screenshot/click-path identification before fix
- **NEW from hf82o:** dock auto-hide-on-cursor-reveal, per-app dock badges (was Phase 3, now standalone since desktop icons shipped)
