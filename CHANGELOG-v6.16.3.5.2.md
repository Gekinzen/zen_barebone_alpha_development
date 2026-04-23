# Zen Shell v6.16.3.5.2 — Module Layout dropdown fixes + zone dedup

**Release date:** 2026-04-24
**Base:** v6.16.3.5.1
**Status:** Micro-patch — ZenComboBox smart flip + Module Layout dedup

---

## TL;DR

> *"panel dop down ko center and right zone dropdown hindi ako
>   makapag select sa baba dapat kht anu mangayri kht anu dami yan
>   dapat ma clcik ko padin lahat nung nas adrop down. and paki
>   lagay yun logic na kapag nakalagay na sa qml bar hindi na
>   mareselect yun mga naka assign na need muna alisin pra ma gamit
>   ulit and ma assign ulit gets?"*

Two fixes:

1. **ZenComboBox flip logic is now desired-height-aware.** Previous
   fixed `flipMargin: 140` threshold failed for the Module Layout
   zone dropdowns — Center and Right zones sit at the bottom of the
   Panel page, popup opens with ~200px below which is >140 so no
   flip, popup caps to 200, last 3-4 items tucked away behind a
   skinny 6px scrollbar. Now the decision is "does the full popup
   fit below? if not AND above has meaningfully more room, flip".

2. **Module Layout dropdowns now dedup across ALL three zones.**
   Before: a module assigned to `center` still appeared in `left`
   and `right` dropdowns. Clicking Add would double-assign it.
   Now: a module appears in at most ONE zone's picker (the zones
   it's NOT in). Remove it first (× chip) to make it available
   again anywhere.

Also snuck in: **`battery` + `powerbadge` now appear** in the zone
dropdowns. They were registered in `Bar.qml` all along but missing
from `PanelPage.allModules` — so you couldn't pick them without
hand-editing `bar-layout.json`.

**Wala tayong binawasan.**

---

## Fix 1 — smarter ZenComboBox flip

### Before (v6.16.3.4.6 through 3.5.1)

```qml
readonly property bool _flipUp: {
    return _availableBelow < root.flipMargin       // flipMargin = 140
        && _availableAbove > _availableBelow
}
```

Problem: a popup of 11 items (all modules minus 2 already assigned)
× ~30px = 330px. In a typical Panel page scroll position where the
Center Zone combobox has 200px below it:

- `_availableBelow = 200`
- `root.flipMargin = 140`
- `200 < 140` → false
- Popup opens DOWN at 200px tall, showing ~6 items
- User has to find the thin scrollbar and drag to see items 7-11

### After (v6.16.3.5.2)

```qml
readonly property real _desiredHeight: {
    return Math.min(contentItem.implicitHeight, root.maxPopupHeight)
}

readonly property bool _flipUp: {
    if (!_window) return false
    return _availableBelow < _desiredHeight                 // 200 < 280 → true
        && _availableAbove > _availableBelow + 20           // above > 220 → likely true
}
```

Same 11-item scenario, same 200px below:

- `_desiredHeight = min(330, 280) = 280`
- `_availableBelow = 200` which is `< 280` → cramped below
- If `_availableAbove > 220`, flip up → popup opens ABOVE the combobox
  with more room, fits more items naturally
- Otherwise stays down (symmetric scroll behavior)

### ScrollBar bulked up too

Width 8→12, content fill opacity 35%→45% idle / 55% hover / 70% pressed.
Still `policy: AsNeeded` so it only appears when content overflows.
Lives at the right edge of the popup so it doesn't hide the first
character of text on short labels.

---

## Fix 2 — zone dedup across all 3 zones

### Before

```qml
property var availableForZone: {
    return root.allModules.filter(
        m => root.modulesFor(modelData.id).indexOf(m) === -1
    )
}
```

Only filters out modules in **this** zone. A module assigned to
`center` still showed in `left` and `right` dropdowns.

### After

```qml
property var availableForZone: {
    const assigned = [].concat(
        root.modulesFor("left"),
        root.modulesFor("center"),
        root.modulesFor("right")
    )
    return root.allModules.filter(m => assigned.indexOf(m) === -1)
}
```

Reads all three zones. A module shown in any zone is filtered out
of every zone's dropdown. To move a module, click × on its chip
first, then pick it from the target zone's dropdown.

Reactivity: `Theme.barLayout` reassignment (done by `addToZone` /
`removeFromZone`) fires the binding, so dropdowns refresh
immediately on every mutation.

### allModules additions

```qml
readonly property var allModules: [
    "start", "taskbar", "workspaces", "window",
    "music", "sysrow", "tray", "battery", "powerbadge",  // ← +2
    "notifications", "clock",
    "weather", "sysmonitor"
]
```

`battery` has been a real bar module since v6.16.0 (auto-hides on
desktops via `SystemMonitorService.batteryPresent === false`).
`powerbadge` shipped in v6.16.3.4 (hides on systems without
`powerprofilesctl` or multi-GPU). Both are now pickable from the
Module Layout UI — no more hand-editing `bar-layout.json` to
rearrange them.

---

## Files in this drop

### UPDATED

```
zen-shell-v5/ZenComboBox.qml      ← smart flip (desired-height-aware), chunky ScrollBar
zen-shell-v5/PanelPage.qml        ← all-zone dedup + battery/powerbadge in allModules
zen-shell-v5/ZenVersion.qml       ← bump to v6.16.3.5.2
install.sh                         ← banner bump
CHANGELOG-v6.16.3.5.2.md           ← this file (NEW)
```

### CARRIED OVER

Everything from 3.5.1 byte-identical — 7 bundled logos, 3-mode
Start Button picker, PowerBadge A+B, grid overlap fix.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.5.2.tar.gz
cd zen-shell-v6.16.3.5.2
./install.sh
~/.local/bin/zs-restart.sh
```

### Verify Fix 1 — flip behavior

1. Settings → Panel → scroll to "Module Layout"
2. Open the Center Zone's "+ Add" dropdown
3. **Before 3.5.2:** popup opens downward, last items behind small scrollbar
4. **After 3.5.2:** with a long list + limited space below, popup opens
   UPWARD instead — all items visible without scrolling needed
5. Open the Right Zone's dropdown — same smart flip behavior
6. Resize the Settings window smaller → popups still pick the bigger side

### Verify Fix 2 — dedup

1. With a fresh layout: Center has `workspaces` + `window`
2. Open **Left Zone** dropdown — `workspaces` and `window` should NOT appear
3. Open **Right Zone** dropdown — same, they're filtered out
4. Click × on the `workspaces` chip in Center (remove it)
5. Open Left Zone dropdown — `workspaces` is back in the list
6. Pick `workspaces` in Left → click + Add → now it's in Left
7. Check Center/Right dropdowns — `workspaces` no longer offered

### Verify allModules expansion

- Open any zone dropdown — you should now see `battery` and
  `powerbadge` as pickable options (they were missing before)

---

## Next up

Post-3.5.2 roadmap:

- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale-aware)
- **v6.16.3.8** — Idle / lid / sleep UX
- **v6.16.4** — Global Hyprland configreloaded IPC listener
