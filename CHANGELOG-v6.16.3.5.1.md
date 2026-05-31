# Zen Shell v6.16.3.5.1 — Built-in logo grid overlap fix

**Release date:** 2026-04-24
**Base:** v6.16.3.5
**Status:** Micro-patch — single-row UI layout fix

---

## TL;DR

> *"BUILT IN LOGO DROP DOWN OVERLAP YUN ITSURA PRE HAHAHA and make it
>   sure mag save padin yan ah kapag nag restart ako ng pc"*

Two things in this drop:

1. **Overlap fixed.** The "Pick a built-in" grid (7 tiles across 2
   rows, ~180px tall) was wrapped in a `SettingRow` whose hardcoded
   `implicitHeight: 48` caused the parent `ColumnLayout` to position
   the next row ("Workspace Dot (Active)") at y=48 — right inside
   the grid. Result: tiles visibly cut across the Workspace rows.
   Replaced the SettingRow wrapper with a plain `ColumnLayout` that
   reports its real children height, so everything downstream shifts
   correctly.

2. **Persistence verified.** Nothing changed on that front — the
   v6.16.3.5 wiring already persists all four logo properties
   (`startButtonLogoMode`, `startButtonLogoBuiltinId`,
   `startButtonLogoPath`, `startButtonLogoTint`) through
   `saveState()` → `panel-state.json` → `applyState()` on restart.
   Every UI mutation (mode combo, tile click, path edit, tint
   toggle) calls `PanelState.saveState()` immediately. Confirmed
   working.

**Wala tayong binawasan.**

---

## The bug

```
┌─ Start Button & Workspaces ─────────────────────────────────┐
│  Start Button Icon ─────────────────── [=====] 42px         │
│  Start Button Logo  [Built-in logo ▼] [preview]             │
│  ┌──┐┌──┐┌──┐┌──┐            ←── grid overlaps here         │
│  │🔺││🛡 ││🔻││ƒ │   Workspace Dot (Active) ─ [====] 48px   │ ← mashed together
│  └──┘└──┘└──┘└──┘   Size of the active workspace indicator  │
│  ┌──┐┌──┐┌──┐     Workspace Dot (Inactive) ─ [===] 30px     │
│  │🟠││❄ ││🐧│     Size of inactive workspace dots           │
│  └──┘└──┘└──┘                                                │
└──────────────────────────────────────────────────────────────┘
```

SettingRow has `implicitHeight: 48` baked into its QML. ColumnLayout
in SettingsSection.contentLayout positions children based on reported
implicitHeight. My grid was ~180px tall but its wrapper only reported
48px → next rows placed on top of the grid.

## The fix

```qml
// BEFORE — SettingRow caps height at 48
SettingRow {
    label: "Pick a built-in"
    description: "..."
    visible: PanelState.startButtonLogoMode === "builtin"
    Column {
        Grid { ... tiles ... }
    }
}

// AFTER — plain ColumnLayout, auto-sizes to children
ColumnLayout {
    Layout.fillWidth: true
    visible: PanelState.startButtonLogoMode === "builtin"
    spacing: 10

    ColumnLayout {   // header: label + description
        Layout.leftMargin: 16
        Text { ... "Pick a built-in" ... }
        Text { ... description ... }
    }
    Grid {           // tile grid, unchanged
        Layout.leftMargin: 16
        columns: 4
        rowSpacing: 10
        ...
    }
}
```

`Layout.leftMargin: 16` matches `SettingRow`'s internal left padding
so the header + grid visually align with the other rows above and
below. The tile content (Rectangle, Image, Text, MouseArea bindings)
is byte-identical to v6.16.3.5 — only the outer wrapper changed.

## Persistence quick-reference

State lives at:

```
~/.local/share/quickshell/zen-shell/panel-state.json
```

Relevant keys written on every mutation:

```json
{
  "startButtonLogoMode":      "builtin",
  "startButtonLogoBuiltinId": "cachyos",
  "startButtonLogoPath":      "",
  "startButtonLogoTint":      false
}
```

On shell startup, `PanelState.applyState()` reads this file and
restores the properties. Verify your selection survived a restart:

```bash
jq '.startButtonLogoMode, .startButtonLogoBuiltinId' \
   ~/.local/share/quickshell/zen-shell/panel-state.json
```

---

## Files in this drop

### UPDATED

```
zen-shell-v5/PanelPage.qml         ← grid wrapper: SettingRow → ColumnLayout
zen-shell-v5/ZenVersion.qml        ← bump to v6.16.3.5.1
install.sh                          ← banner bump
CHANGELOG-v6.16.3.5.1.md            ← this file (NEW)
```

### CARRIED OVER

Everything from 3.5 byte-identical — 7 bundled SVG logos, resolver
function, auto-detect, install.sh deployment, full 3-mode picker
logic. Only the grid's outer container changed.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.5.1.tar.gz
cd zen-shell-v6.16.3.5.1
./install.sh
~/.local/bin/zs-restart.sh
```

Then open Settings → Panel → scroll to Start Button Logo → switch
mode to "Built-in logo":

- Grid appears with 7 tiles in 2 rows
- **Workspace Dot rows stay BELOW the grid** (not inside it)
- Clicking any tile updates the Start Button immediately
- `jq` the state file — your selection is there
- `zs-restart.sh` → open Settings again → selection is still there
