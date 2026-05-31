# Zen Shell v7.0.0-beta.1-hf95.6 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical strings alignment fixes: the string is now centered on the
bar (over the music icon) instead of floating off to the side, and the
"Loading…" placeholder no longer sticks on a vertical bar.** Wala tayong
babawasan.

---

## 1. Centered on the bar (not the window)

The v1 vertical string was centered in the overlay window, whose width
included the sideways bow padding — so the string sat ~`hPad/2` too far
in and bowed into the windows beside the bar. Now:

- The overlay reserves bow room on BOTH sides (`width = barThick + 2*hPad`).
- The string LINE is placed on the bar's CONTENT center
  (`barContentCenterX` = gutter + half the bar thickness, mirrored for a
  right bar), via explicit `x`/`y` instead of `anchors.centerIn`. Because
  the 90° rotation pivots about the item center, solving
  `x = barContentCenterX - width/2`, `y = (windowH - bowSpan)/2` lands the
  string line exactly over the music icon, bowing symmetrically (the
  outer bow clips at the screen edge, as expected on an edge bar).
- Bow span height is now `2*curveHeight + 16` so the full bow fits.

## 2. "Loading…" no longer sticks

On a vertical bar nothing flipped `ZenStringsState.positionReady`, so
MusicStrings kept showing its "Loading…" placeholder. BarVertical's slot
reporter now sets `positionReady = true` once it has a real slot Y, so
the placeholder clears and the string shows. (The horizontal stringsWindow
still owns this flag on horizontal bars; only one bar is ever active.)

## Still v1 on exact placement

If the string is still a touch off-center horizontally (bar gutter
nuance) or the vertical centering needs a nudge, tell me and I'll adjust
`barContentCenterX` / `margins.top`.

## Version

- `ZenVersion.qml` bumped `hf95.5` → `hf95.6`.

## Files touched

- `zen-shell-v5/shell.qml` — `stringsWindowV` centering geometry
- `zen-shell-v5/BarVertical.qml` — set `positionReady` on valid slot report
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
