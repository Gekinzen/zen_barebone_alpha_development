# v7.0.0-beta.1-hf82k.1 — Dock default modules adjusted to lean preset

**Channel:** beta (mini-patch on hf82k)
**Released:** 2026-05-24
**Scope:** 3 files (DockState.qml + DockPage.qml + ZenVersion.qml)

## Why

User answered the original scoping questions explicitly after hf82k had already been built:

- Q: Default modules? — A: "Just app icons (pure dock — drag-and-drop launcher only)" AND "App icons + workspaces (compact, no sysrow clutter)"

Both selections share: lean, no sysrow clutter, no start menu duplicate (the bar already has one), no divider needed when there are only 2 adjacent modules. Picking the more inclusive of the two as the actual default → **taskbar + workspaces**.

## What changed

- `DockState.qml` — `property var modules` default goes from `["start", "taskbar", "workspaces", "divider", "sysrow", "controlcenter"]` to **`["taskbar", "workspaces"]`**.
- `DockState.qml` — `resetDefaults()` updated to match.
- `DockPage.qml` — "Reset modules to default" button description + action updated to match.
- `ZenVersion.qml` — bumped to `hf82k.1`.

## What did NOT change

Everything else from hf82k stays. The 4 removed-from-default modules (`start`, `divider`, `sysrow`, `controlcenter`) are still **recognized module ids** in ZenDock.getComponent() — the user can add any of them via DockPage → Modules → Add module dropdown. Only the FRESH-INSTALL default array is leaner now.

If you already installed hf82k AND already toggled "Enable dock" (which would have written dock-state.json with the old 6-module default), your existing dock-state.json wins — you'll keep the 6 modules until you reset via the DockPage button. To get the lean default immediately: click "Reset" in Settings → Dock → Modules section, OR delete `~/.local/share/quickshell/zen-shell/dock-state.json`.

## Install

Drop-in over hf82k:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82k_1-patch-only.tgz
cp zen-shell-v7.0.0-beta.1-hf82k.1/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/
pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

## Wala tayong babawasan

Default array shrunk; nothing removed from the codebase. All previously-supported module ids still resolve via ZenDock.getComponent().
