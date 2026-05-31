# Zen Shell v7.0.0-beta.1-hf95.19 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Fix: when hyprbars is on, the "Zen-Shell-Hypr-Control-Center" title bar
overlapped the native Settings header at the top. The whole settings UI
now sits BELOW the title bar, so your original "Settings" header + window
buttons are fully visible underneath it.** Wala tayong babawasan.

---

## Fix

In hf95.17 the restored HyprbarsMimic title bar was anchored to the top
of the window (z:50), but only the inner sidebar+content row was offset
to clear it — the OUTER ColumnLayout (which holds the native full-width
"Settings" header) still started at y=0, so the two stacked on top of
each other.

Now the outer ColumnLayout carries the clearance
(`anchors.topMargin = hyprbarsMimic.visible ? hyprbarsMimic.height : 0`),
pushing the ENTIRE settings UI — native header included — below the
mimic bar. The inner row's offset is dropped to 0 so it doesn't double
up. When hyprbars is off, both offsets are 0 and the layout is identical
to before.

## Version

- `ZenVersion.qml` bumped `hf95.18` → `hf95.19`.

## Files touched

- `zen-shell-v5/ZenSettings.qml` — outer-layout top clearance for the mimic bar
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
