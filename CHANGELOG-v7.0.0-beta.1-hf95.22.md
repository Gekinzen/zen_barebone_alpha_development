# Zen Shell v7.0.0-beta.1-hf95.22 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**The Settings / Control Center hyprbars mimic title bar is now disabled —
the window uses its native header again.** Wala tayong babawasan.

---

## Change

Per request, the mimic title bar on the Settings window
("Zen-Shell-Hypr-Control-Center") is force-hidden (`wantBar: false`). The
component stays in the tree with all its wiring intact (center title,
draggable, themed/aligned, no-minimize) — flip `wantBar` back to the
hyprbars-enabled check to bring it back.

Because the bar is hidden, the layout offsets that depended on it
auto-zero: the outer ColumnLayout top margin and the floating search bar's
Y both fall back to their original values, so the native "Settings" header
and search position are exactly as they were before the mimic was added.

## Version

- `ZenVersion.qml` bumped `hf95.21` → `hf95.22`.

## Files touched

- `zen-shell-v5/ZenSettings.qml` — disable the mimic bar (`wantBar: false`)
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. (Quick-terminal no-bar rule in
HyprbarsService and all earlier hf95.x work remain intact.)
