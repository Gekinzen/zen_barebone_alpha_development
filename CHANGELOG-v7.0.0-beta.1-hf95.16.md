# Zen Shell v7.0.0-beta.1-hf95.16 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Fix: the "Failed to load configuration … shell.qml[-1:-1]: File not
found" that flashed during ./install.sh. The QML install step now updates
atomically, so a running Quickshell never sees a moment where shell.qml
is missing.** Wala tayong babawasan.

---

## Root cause

Step [4/9] deleted ALL top-level `*.qml` from the config dir and THEN
copied the new ones in. If Quickshell was running with the live config
and reloaded during that gap (it watches the dir), `shell.qml` didn't
exist yet → "File not found" with the tell-tale `[-1:-1]` (no line
number = the file itself is missing, not a line in it). It was transient
— the copy a moment later fixed it — but it threw the error toast you saw
mid-install.

## Fix — copy-first, prune-after

1. Copy the fresh QML in FIRST (overwrites in place, so `shell.qml` is
   never absent at any instant).
2. THEN prune only the stale top-level `*.qml` that no longer exist in
   this build (still handles renamed/removed modules — the reason the
   clean step existed in the first place).

The compiled-cache clear (`*.qmlc`/`*.jsc`) is unchanged and still runs
before the copy.

Verified by simulation: `shell.qml` present throughout, `SddmLoginPage.qml`
deployed, a seeded stale module pruned, source/dest counts match (179).

## Version

- `ZenVersion.qml` bumped `hf95.15` → `hf95.16`.

## Files touched

- `install.sh` — atomic QML update (copy-first, prune-after)
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
