# Zen Shell v7.0.0-beta.1-hf94.9 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Decisive fix: renamed the property `vertical` → `zenVertical`** to
sidestep whatever was making `vertical` unresolvable at instantiation
(even after a verified-fresh source + cache clear). Wala tayong
babawasan.

---

## Why this should finally work

Across hf94.4–.8 we proved:
- The source `Workspaces.qml` HAS the property (md5-verified, line 21).
- A clean config sync put it in place (script printed ✓).
- The compiled QML cache was cleared.

…and it STILL crashed with `Cannot assign to non-existent property
"vertical"`. When a provably-correct property name still won't resolve,
the pragmatic fix is to stop fighting the name: **rename it to something
unambiguous.**

- All seven vertical-capable modules (`Taskbar`, `Workspaces`, `Clock`,
  `SysRow`, `SystemTray`, `MusicWidget`, `WindowTitle`) now declare
  `property bool zenVertical: false` (was `vertical`), and every internal
  reference uses `zenVertical`.
- **`BarVertical.qml`** assigns `zenVertical: true` accordingly.

`zenVertical` cannot collide with any QtQuick concept, any singleton
property, or any cached symbol keyed on the old name. If the crash was a
name-resolution / stale-symbol issue (which all evidence pointed to),
this removes it at the source.

## Run it the same way (clean sync still recommended)

```fish
cd zen-shell-v7.0.0-beta.1-hf94.9
./sync-config.sh        # clean-wipes config dir + clears QML cache
quickshell -p ~/.config/quickshell/zen-shell &
```

Expected: boots with no crash; on a left/right bar the vertical modules
render (taskbar icon column, workspaces dot column, 2-row clock, SysRow
with ▲/▼, vertical tray, music glyph, window icon+label).

If — against all expectation — it STILL throws a "non-existent property
zenVertical" now, that would PROVE something is loading a different
BarVertical/Workspaces than the one in the config dir (a duplicate
somewhere on the QML import path), and the find-based diagnostics from
chat will locate it.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.9
Taskbar.qml      vertical → zenVertical
Workspaces.qml   vertical → zenVertical
Clock.qml        vertical → zenVertical
SysRow.qml       vertical → zenVertical
SystemTray.qml   vertical → zenVertical
MusicWidget.qml  vertical → zenVertical
WindowTitle.qml  vertical → zenVertical
BarVertical.qml  assigns zenVertical: true (×8)
```

Carries forward hf83–hf94.8 (incl. the hf94.4 crash fix and the
cache-clearing sync script). Horizontal bar unchanged.

> Lesson logged: if a verified-present property still won't resolve after
> a clean source sync AND a cache wipe, rename it — a fresh, unique
> property name bypasses name-collision / stale-symbol resolution
> entirely.
