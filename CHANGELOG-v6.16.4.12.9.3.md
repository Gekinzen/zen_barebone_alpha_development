# v6.16.4.12.9.3 — Modori (戻り) · hotfix 3

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.2 — Modori hotfix 2

## Summary

User reported that selecting **Left** or **Right** from
Settings → Panel → Panel Position (which was popup-only support
since Tachiagari .7.1; vertical bar rendering was rolled back in
Modori .9 due to crashes) caused the **user row at the bottom of
the Settings sidebar to disappear** — the `paul @cachyos-x8664`
identity surface lost its render. User asked to hide the Left
and Right options entirely until the proper vertical-bar drop
lands.

This hotfix:

1. **Hides Left and Right cards** from the Panel Position picker
   in Settings → Panel. Only Top and Bottom show now.
2. **Removes the yellow notice block** that lived below the
   picker explaining the partial-support state for vertical bars
   — with the cards hidden, the notice has nothing to clarify.
3. **Adds a migration safety net in PanelState.applyState()**:
   if a saved `panel-state.json` from a previous version still
   has `panelPosition: "left"` or `"right"`, it auto-migrates
   back to `"bottom"` on load and persists the migration. Without
   this, users who tested vertical-bar variants would be stuck in
   a broken state with no UI option to recover (the cards they'd
   need to select Bottom-instead are now gone).

The 4-direction popup helpers (`PanelState.popupAnchorEdges` /
`popupAnchorGravity`) are kept in PanelState — they're harmless
no-ops when only Top/Bottom are reachable, and they're already
wired into all the popup widgets (SysRowIcon, Taskbar, etc.).
When vertical bar rendering returns, Left/Right just need to be
re-added to the picker model and the popup logic will already
work.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.3. |
| `zen-shell-v5/PanelPage.qml` | Repeater model under Panel Position section trimmed from 4 entries (top/bottom/left/right) to 2 (top/bottom). Yellow "Vertical bar coming in a follow-up drop" notice block deleted (~28 lines). Comment block above the Repeater explains why. |
| `zen-shell-v5/PanelState.qml` | `applyState()` panelPosition load logic split into two branches: top/bottom passed through, left/right migrated to bottom + `Qt.callLater(saveState)` to persist the migration. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.3.md` | NEW (this file). |

## Detail — why Left/Right broke the Settings sidebar

`ZenSettings.qml` and several other Settings pages have layout
logic that reacts to `PanelState.isVertical` (which is true when
panelPosition is "left" or "right"). The intent was that vertical
bars would have different sidebar dimensions or alignment.

Some of that layout logic survived the Modori .9 vertical-bar
rollback because the rollback restored Bar.qml + the bar modules
to their Tachiagari state but didn't audit every consumer site
of `PanelState.isVertical` outside the bar. The Settings sidebar
user row was one such consumer — it had a layout branch that
expected vertical-bar geometry (different from horizontal-bar
geometry) and rendered nothing useful when the bar was actually
still horizontal (because of the rollback) but `panelPosition`
said "left."

Hiding Left/Right cards is the safer fix than auditing every
`PanelState.isVertical` consumer in this session. When vertical
bar rendering returns properly, that audit becomes part of that
drop's testing scope.

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.3
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

If you currently have `panelPosition: "left"` or `"right"` saved
from an earlier session, the migration safety net in PanelState
will auto-correct it to `"bottom"` on first launch. No manual
file edit needed; the corrected value is written back to disk
the same launch.

## Carry-forward from Modori .9.2

All Modori fixes preserved:

- Theme.layoutLoader stop reading stale `style` from
  bar-layout.json (settings persistence)
- `saveState()` debounced through 200ms Timer (slider-drag
  corruption fix)
- Built-in Modori Dark / Modori Light wallpapers + themes
- Sidebar bottom user row (paul @cachyos-x8664) — unchanged
- All Tachiagari .7.1 features

## Wala tayong babawasan

Settings UI loses the Left/Right picker cards (intentional —
they shipped broken). Code-level support for vertical
panelPosition values is preserved (popup helpers stay) so the
proper vertical-bar drop will need MINIMUM re-work to the
PanelPage UI when it returns.
