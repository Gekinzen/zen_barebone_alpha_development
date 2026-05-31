# v7.0.0-beta.1-hf82n.1 — Scope fix for Default Apps + App Float Rules delegates

**Channel:** beta (mini-patch on hf82n)
**Released:** 2026-05-25
**Scope:** 3 files (DefaultAppsPage + AppFloatRulesPage + ZenVersion)

## Why

User report after installing hf82n + running install.sh: "wala sa hypr control center ko pre. Settings → sidebar should show Default Apps + App Float Rules"

Root-cause investigation found **two QML scope bugs** in the Repeater delegates that would cause silent property-binding failure → page fails to instantiate cleanly → possible cascade effect on the StackLayout / sidebar update.

## The bugs

**AppFloatRulesPage delegate**:
```qml
delegate: HMRow {
    required property var modelData
    readonly property string wmClass: rootView._classFor(modelData)
    HMSwitch {
        checked: WindowRulesService.isFloating(parent.wmClass)   // ❌ parent = controlSlot, NOT HMRow
        onToggled: WindowRulesService.setFloating(parent.wmClass, checked)
    }
}
```

**DefaultAppsPage delegate** has the same pattern with `modelData` instead of `wmClass`.

### Why broken

`HMRow.qml` declares `default property alias control: controlSlot.data` — so when you add HMSwitch as a child of HMRow, it gets **reparented into `controlSlot`**, not into HMRow itself. Then `parent.wmClass` resolves against the slot Item (which has no such property) — the binding fails silently and the page may fail to load.

## Fix

Add an `id:` to each delegate's HMRow and reference it explicitly:

```qml
delegate: HMRow {
    id: appRow   // ← NEW
    required property var modelData
    readonly property string wmClass: rootView._classFor(modelData)
    HMSwitch {
        checked: WindowRulesService.isFloating(appRow.wmClass)   // ✅ explicit ref
        onToggled: WindowRulesService.setFloating(appRow.wmClass, checked)
    }
}
```

Same pattern applied to DefaultAppsPage's ZenDropdown with `id: catRow` + `catRow.modelData`.

## Install (drop-in on top of hf82n)

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82n_1-patch-only.tgz
cp zen-shell-v7.0.0-beta.1-hf82n.1/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/
pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

## Verify

1. Settings → sidebar — should see **Default Apps** (既定 / Kitei) AND **App Float Rules** (窓規則 / Madokisoku) at the bottom of PRODUCTIVITY section
2. Open Default Apps → 10 category rows with dropdowns
3. Open App Float Rules → all installed apps with switches
4. System Info → `v7.0.0-beta.1-hf82n.1 · released 2026-05-25`

## Wala tayong babawasan

Only 2 line additions (the `id:` declarations) + 7 line edits (the references). Zero removals.

## What's coming in hf82o

Desktop icons + Android-style widgets (per your latest request). Scope being finalized via elicitation answers. Will be a bigger drop (~600-900 lines new).
