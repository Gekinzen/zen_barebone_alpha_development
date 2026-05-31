# Zen Shell v7.0.0-beta.1-hf94.6 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Root-causes the recurring "non-existent property" load errors: a STALE
config dir. Adds a clean-sync script.** Wala tayong babawasan.

---

## The real, recurring problem: a stale config dir

hf94.5 crashed again on load:

```
BarVertical.qml[98]: Cannot assign to non-existent property "vertical"
```

`Workspaces.qml` in the build **does** declare `property bool vertical`
(line 21 — verified). So this error has only ever meant one thing: the
**running config dir** (`~/.config/quickshell/zen-shell/`) still has an
OLD `Workspaces.qml` without the property. Quickshell loads from that
dir, NOT the tarball — so when the launcher copies only some files, one
stale file fails the whole load.

This is the same root cause behind several recent "stale" errors. The
guarded `Component.onCompleted` setter (hf92.1) only HID it — the shell
booted but workspaces stayed horizontal because the stale file had no
`vertical` to set. Switching back to a direct binding (hf94.5) exposed
it as a crash again.

## Fix: direct binding + a clean-sync script

- **`BarVertical.qml`** — kept the **direct** `Module { vertical: true }`
  bindings (correct + reliable with fresh files; this is what finally
  made Workspaces stack vertically).
- **NEW `sync-config.sh`** (in the build root) — does a CLEAN sync:
  wipes `~/.config/quickshell/zen-shell/` and copies the full current
  `zen-shell-v5/` tree in, so NO stale .qml can survive. Your settings
  (`panel-state.json`) are preserved across the wipe.

### Use it

```fish
cd zen-shell-v7.0.0-beta.1-hf94.6
bash sync-config.sh
quickshell -p ~/.config/quickshell/zen-shell/shell.qml
```

It prints the installed version at the end so you can confirm the sync
actually took (should say `v7.0.0-beta.1-hf94.6`). If your own launcher
script already copies files, point it at a clean wipe like this one, or
just run this script before launching.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.6
sync-config.sh   NEW — clean config-dir sync (preserves panel-state.json)
```

No QML logic changed since hf94.5 (the vertical bindings are already
correct). This drop is about making sure the CORRECT files actually
reach the running config dir.

Carries forward hf83–hf94.5 (vertical Taskbar / Workspaces / Clock /
SysRow with ▲/▼ arrow / tray / music / window; the hf94.4 crash fix).

> Lesson logged: "Cannot assign to non-existent property X" when the
> build clearly HAS X = a stale copy in the load path, not a code bug.
> Clean-wipe the config dir, don't merge-copy.
