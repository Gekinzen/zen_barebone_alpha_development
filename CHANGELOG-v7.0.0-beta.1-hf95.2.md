# Zen Shell v7.0.0-beta.1-hf95.2 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**THE real root cause of the recurring "Cannot assign to non-existent
property zenVertical" crash: `install.sh` was clobbering its own freshly
installed `Workspaces.qml` with the stale legacy `ZenWorkspaces.qml`
during the alias step — every single install. Fixed, plus a smart
self-heal pass so this class of bug can never silently return.** Wala
tayong babawasan.

---

## 0. Root cause — install.sh clobbered Workspaces.qml after copying it

Step `[4/9]` correctly bulk-copies the fresh `Workspaces.qml` (4288 B,
has `zenVertical`). But the alias loop right after it
(`ZenWorkspaces.qml:Workspaces.qml`) then ran a size heuristic:

```
src = ZenWorkspaces.qml  (3845 B, legacy, NO zenVertical)
dst = Workspaces.qml     (4288 B, live, HAS zenVertical)
ratio = 3845 * 100 / 4288 = 89
```

The heuristic only protects `dst` when `ratio < 80`. At **89** it fell
into the `src→dst` branch and copied the stale `ZenWorkspaces.qml` OVER
the good `Workspaces.qml`, dropping `zenVertical`. So the config dir
ended every install with a stale Workspaces — which is why the crash
returned no matter how many times the tarball was re-synced. The Clock
pair was removed from this loop back in .53 for the identical reason; the
Workspaces pair was left behind.

Verified by simulation: old loop → `zenVertical` count `0` (crash); new
flow → `1` (loads).

## 1. `install.sh` — Workspaces removed from the clobber loop

- The `ZenWorkspaces.qml:Workspaces.qml` pair is removed from the alias
  loop (mirrors the Clock fix). `Workspaces.qml` is the canonical runtime
  module — `Bar.qml` and `BarVertical.qml` both instantiate
  `Workspaces {}` directly. `ZenWorkspaces.qml` is unused at runtime and
  **stays on disk** for back-compat (it is still referenced by the
  BarModulesPage "Auto-apply" label as a manual user action).
- The `ZenSysMonitor.qml:SysMonitor.qml` pair is kept — there is no
  `SysMonitor.qml` in the source, so that branch only *creates* a
  back-compat alias and never clobbers a runtime module
  (`BarVertical.qml` uses `ZenSysMonitor {}` directly).

## 2. `install.sh` — SMART self-heal pass (new)

After all copy/alias steps, install.sh now re-asserts every module that
`BarVertical.qml` marks `zenVertical: true`
(`Clock`, `MusicWidget`, `SysRow`, `SystemTray`, `Taskbar`,
`WindowTitle`, `Workspaces`) straight from the tarball source, then
clears the compiled QML cache one final time and verifies each file
carries `zenVertical`. This is the last word in the install — nothing
after it touches these files — so even a future clobbering step cannot
ship a broken vertical bar. Idempotent and additive.

## 3. Version

- `ZenVersion.qml` bumped `hf95.1` → `hf95.2`. The "Installed version:"
  line confirms the smart installer is what landed in the config dir.

## Files touched

- `install.sh` — alias loop (Workspaces pair removed) + self-heal pass + comments
- `zen-shell-v5/ZenVersion.qml` — version string + header tag

Carried over from hf95.1: `sync-config.sh` verify fix + generalization.

No module `.qml` logic, no feature, no setting, no file removed.
`ZenWorkspaces.qml` and the SysMonitor alias are both preserved.
