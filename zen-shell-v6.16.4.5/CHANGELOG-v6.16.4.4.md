# Zen Shell v6.16.4.4 — DisplaysPage runtime-state preservation

**Release date:** 2026-04-24
**Base:** v6.16.4.3
**Severity:** LOW — cosmetic regression when applying monitor changes

---

## Paul's report

> *"nung nag palit pala ako ng mga scale etc yung mga gaps ko
>   nawala yun current setup ko. tas nag reselect ako ng theme
>   bumalik ulit yun mga gaps etc paki check yan pre."*

Classic symptom of the runtime-keyword-wipe pattern:
gaps/rounding/blur/borders disappear after Apply in DisplaysPage,
come back only after theme reselect triggers
`SettingsStateV2.applyToHyprland()` as a side effect.

---

## Root cause

`DisplaysPage.applyMonitor()` runs:

```qml
applyProc.command = ["hyprctl", "keyword", "monitor", cmd]
applyProc.running = true
```

`hyprctl keyword monitor <cmd>` internally bumps Hyprland's
monitor state machine. Workspaces get re-linked to the new output
configuration. As a side effect, **runtime keywords that were
applied via `hyprctl keyword` rather than written to hyprland.conf
fall back to whatever the config file has on disk** — which is
usually defaults.

This is the same bug class as v6.16.3.4.3's AnimationsPage fix.
There, `hyprctl reload` wiped runtime state; here, `hyprctl
keyword monitor` wipes a subset of it. Both need the same
`SettingsStateV2.applyToHyprland()` re-assertion.

Paul discovered the workaround accidentally: reselecting a theme
makes ZenSettings trigger `applyToHyprland()` as part of the theme
apply chain → runtime keywords re-asserted → gaps/borders come
back.

---

## Fix

`applyProc.stdout.onStreamFinished` now calls
`SettingsStateV2.applyToHyprland()` after the monitor apply
completes:

```qml
Process {
    id: applyProc
    stdout: StdioCollector {
        onStreamFinished: {
            root.applyStatus = ...
            refreshDelay.running = true
            Qt.callLater(function() {
                if (typeof SettingsStateV2 !== "undefined"
                    && typeof SettingsStateV2.applyToHyprland === "function") {
                    SettingsStateV2.applyToHyprland()
                }
            })
        }
    }
}
```

`Qt.callLater` queues the re-apply after the current event loop
tick — gives Hyprland a moment to finish the monitor
reconfiguration before we re-assert runtime keywords on top.

Pattern matches the one AnimationsPage has used since v6.16.1.6
(documented with an identical comment block).

---

## Why v6.16.5 finally kills this bug class

v6.16.5's planned global `configreloaded` IPC listener is exactly
the fix for "Settings pages have to individually remember to call
applyToHyprland after every operation that might wipe runtime
state." Once the listener exists, any config reload / state bump
automatically re-asserts everything — no per-page wiring needed.

For now, 4.4 is the spot fix for the specific Displays case Paul
hit.

---

## Files changed from 4.3

```
UPDATED
  zen-shell-v5/DisplaysPage.qml  ← +SettingsStateV2.applyToHyprland on apply
  zen-shell-v5/ZenVersion.qml     ← bump to v6.16.4.4
  install.sh                       ← banner
NEW
  CHANGELOG-v6.16.4.4.md           ← this file
```

All v6.16.4.3 features carry byte-identical.

---

## Install + test

```bash
tar -xzf zen-shell-v6.16.4.4.tar.gz
cd zen-shell-v6.16.4.4
./install.sh
~/.local/bin/zs-restart.sh
```

### Reproduce + verify

1. Set your preferred gaps: Settings → Decoration → verify gaps_out/
   gaps_in are your customized values (e.g., 8/4)
2. Also set a distinctive rounding: Settings → Decoration →
   rounding = 12
3. Open a window or two to verify gaps are visible
4. Settings → Displays → change Scale from 1.0 to 1.25 (or any
   change) → Apply
5. **Before 4.4**: window gaps collapse to 0, rounding resets
   to hyprland.conf default. Had to reselect theme to get them back.
6. **After 4.4**: gaps + rounding stay exactly as you configured
   them. No workaround needed.

---

## Next up

Still v6.16.5 — global `configreloaded` IPC listener. This fix
plus the others in 4.x make the case for it even stronger.
