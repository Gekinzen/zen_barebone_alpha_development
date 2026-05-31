# Zen Shell v6.16.3.5.3 — ZenComboBox: guaranteed-in-bounds popup

**Release date:** 2026-04-24
**Base:** v6.16.3.5.2
**Status:** Micro-patch — ZenComboBox only

---

## TL;DR

> *"kunti nln hindi ko na ma select yun last niyan please paki ayos
>   dpat kht anu mangyari ma select padin pre"*

v6.16.3.5.2's smart flip worked for most cases but still missed the
Right Zone scenario where:
- 4-item popup × ~30px = 120px content
- Only ~80-100px space below combobox
- Popup opened downward anyway — last item (`sysmonitor`) clipped
  past Settings window bottom, visible but unclickable

Three fixes stacked for belt-and-suspenders reliability:

### 1. Smaller safer default
```
maxPopupHeight: 280  →  220
```
Fits in most Settings layouts without any flip logic at all. Call
sites with genuinely huge lists can still override upward.

### 2. Window resolution fallback chain
```qml
_window = root.Window.window
       || <first ancestor with height ≥ 200 and width ≥ 200>
       || null
```
When the Qt attached property fails to resolve (seen deep inside
nested ScrollView + SettingsSection + Repeater trees), we walk the
parent chain looking for something window-shaped. When that also
fails, `_availableBelow` defaults pessimistically to 120 → forces
flip-up thinking.

### 3. Aggressive flip policy
```qml
// BEFORE (3.5.2): flip only if below < desired AND above > below + 20
// AFTER  (3.5.3): flip unless below fits desired + 20px breathing room
readonly property bool _flipUp: {
    if (_availableBelow >= _desiredHeight + 20) return false
    return _availableAbove > _availableBelow
}
```
Opening downward requires below to COMFORTABLY fit the full desired
popup. Marginal fits flip up instead.

### Extra safety on _effectiveMax

```qml
const capped = Math.min(root.maxPopupHeight, side - 4)
return Math.max(80, capped)
```
- `- 4` extra pixel buffer against rounding
- `Math.max(80, ...)` floor ensures at least ~2.5 items + scrollbar
  show even in extremely cramped cases (user can scroll rest)

**Wala tayong babawasan.** All 30 ZenComboBox call sites keep their
existing API. Only the popup positioning internals changed.

---

## Files in this drop

```
UPDATED
  zen-shell-v5/ZenComboBox.qml     ← 3 stacked robustness fixes
  zen-shell-v5/ZenVersion.qml      ← bump to v6.16.3.5.3
  install.sh                        ← banner bump
NEW
  CHANGELOG-v6.16.3.5.3.md          ← this file
```

### CARRIED OVER

Everything from 3.5.2 byte-identical — Module Layout dedup logic,
battery+powerbadge in allModules, chunky 12px ScrollBar, 7 bundled
Start Button logos, PowerBadge A+B.

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.5.3.tar.gz
cd zen-shell-v6.16.3.5.3
./install.sh
~/.local/bin/zs-restart.sh
```

### Regression test: the Right Zone dropdown

1. Settings → Panel → scroll all the way down to "Module Layout"
2. Assign many modules to other zones so Right Zone's dropdown has
   4+ pickable options left
3. Open Right Zone's "+ Add" dropdown
4. **Before 3.5.3:** popup opens downward, `sysmonitor` / last item
   clipped past window edge, unclickable
5. **After 3.5.3:** popup opens UPWARD (window edge too close
   below), all items visible and clickable

### Cross-check: the Font family dropdown from 3.4.6

Settings → Bar Modules → Font family — opens the way it did in
3.4.6, no regression (that case had ample space below, still opens
downward with all 10 fonts visible).

### Edge cases

- Very top of Settings → dropdown opens downward (above has no room)
- Very bottom of Settings → dropdown opens upward (below has no room)
- Settings resized very small → both cramped → popup chooses bigger
  side and caps to ≥80px with ScrollBar visible

---

## Next up

Back to roadmap:

- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale-aware)
- **v6.16.3.8** — Idle / lid / sleep UX
- **v6.16.4** — Global Hyprland configreloaded IPC listener
