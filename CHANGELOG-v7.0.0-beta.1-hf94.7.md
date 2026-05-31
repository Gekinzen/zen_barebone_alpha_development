# Zen Shell v7.0.0-beta.1-hf94.7 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Self-verifying, symlink-aware clean-sync script.** The QML is correct
(verified, md5 `9a26c4fca17393aa7d7e08a44a1eaafb` for Workspaces.qml);
this drop is purely about getting the right files into the load path.
Wala tayong babawasan.

---

## Why hf94.6 still errored

Same `BarVertical.qml[98]: non-existent property "vertical"`. The build's
`Workspaces.qml` **has** the property (triple-checked, line 21). So the
config dir still has a stale copy — meaning the hf94.6 sync script either
wasn't run, or something overwrites the dir afterward (e.g. a launch
script copying from a different/old folder, or the dir being a symlink to
a stale source).

## What's new in the sync script

- **Symlink-aware** — if `~/.config/quickshell/zen-shell` is a *symlink*,
  the script removes the link and writes a real directory, so a
  symlinked stale source can't shadow the fresh files.
- **Self-verifying** — after copying, it greps the installed
  `Workspaces.qml` for `vertical` and prints ✓ or a loud WARNING. If you
  see the WARNING, something is copying an old file over the config dir
  *after* the sync (your launch script is the place to look).
- Still preserves `panel-state.json`. Tested end-to-end (stale file in →
  fresh file + preserved settings out).

## Please run this and paste the output

```fish
cd zen-shell-v7.0.0-beta.1-hf94.7
bash sync-config.sh
```

The last ~6 lines tell us everything:
- `Installed version: v7.0.0-beta.1-hf94.7` → the copy reached the dir.
- `Workspaces.qml has the 'vertical' property ✓` → the stale-file bug is
  gone; launching now will NOT hit that error.
- If instead you see the WARNING line → your **launcher** is overwriting
  the config dir with an old copy; that's the thing to fix (point it at
  this folder, or stop it copying).

Also, the diagnostic commands from chat (md5 of the running
`Workspaces.qml`, whether the dir is a symlink, its version + mtime) will
pinpoint exactly what's shadowing the fresh files.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.7
sync-config.sh   symlink-aware + self-verifying (preserves panel-state.json)
```

No QML logic changed since hf94.5. Carries forward hf83–hf94.6.

> Lesson logged (again, louder): when "non-existent property X" persists
> but the build provably HAS X, stop editing QML — the load path has a
> stale copy. Make the sync clean-wipe, symlink-aware, and self-verifying.
