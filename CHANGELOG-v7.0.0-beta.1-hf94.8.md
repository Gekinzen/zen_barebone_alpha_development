# Zen Shell v7.0.0-beta.1-hf94.8 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**The actual fix: clear the stale COMPILED QML cache.** Wala tayong
babawasan.

---

## The paradox that cracked it

hf94.7's sync ran and printed:

```
Verify: Workspaces.qml has the 'vertical' property ✓
```

…and it STILL crashed with `Cannot assign to non-existent property
"vertical"`. So the source file in the config dir is correct, yet the
loaded TYPE doesn't have the property. That paradox has one classic
cause: **Qt's compiled QML cache.**

Qt caches compiled QML as `.qmlc` files (under `~/.cache/quickshell/` /
`~/.cache/.../qmlcache`). If the cache holds an OLD compiled `Workspaces`
(from before the `vertical` property existed), Qt loads that **stale
compiled type** instead of recompiling the fresh `.qml` — so the source
has `vertical` but the loaded type doesn't. Exactly the symptom.

## Fix

- **`sync-config.sh`** — now also **wipes the compiled QML cache**
  (`*.qmlc` / `*.jsc`) after copying the fresh source, forcing Qt to
  recompile every module from the current `.qml`. Tested: a planted
  stale `.qmlc` is removed; settings still preserved.

### Run it (this should finally do it)

```fish
cd zen-shell-v7.0.0-beta.1-hf94.8
./sync-config.sh
quickshell -p ~/.config/quickshell/zen-shell &
```

You should see, in order:
```
Clearing Qt/Quickshell QML compiled cache…
  QML cache cleared.
Done. Installed version: v7.0.0-beta.1-hf94.8
Verify: Workspaces.qml has the 'vertical' property ✓
```
…and then it boots — no crash, vertical bar working.

If it somehow STILL crashes after this, the diagnostic commands from chat
(find all Workspaces.qml; list qmldir; list any remaining *.qmlc) will
show whatever cache/duplicate is left.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.8
sync-config.sh   now clears the compiled QML cache (*.qmlc/*.jsc) too
```

No QML logic changed since hf94.5. Carries forward hf83–hf94.7.

> Lesson logged: source-has-property-but-loaded-type-doesn't = stale
> compiled QML cache. Clear `~/.cache/.../qmlcache` (*.qmlc) to force a
> recompile; editing the source alone won't help while the cache wins.
