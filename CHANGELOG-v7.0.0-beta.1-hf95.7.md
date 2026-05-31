# Zen Shell v7.0.0-beta.1-hf95.7 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Global scale-to-fit for the vertical bar: when the stacked modules need
more height than the bar has, the WHOLE column (and the music string)
scales down together so everything stays visible — same idea as SysRow's
expanded cluster, applied to the entire vertical bar.** Wala tayong
babawasan.

---

## How it works

- **`VerticalModuleHost`** now pins each module to its preferred height
  (`Layout.minimumHeight = Layout.preferredHeight`). An over-full column
  therefore OVERFLOWS rather than squishing modules into each other.
- **`barRootV.vFitScale`** = `barHeight / contentHeight` when the column
  overflows, else `1.0`. `rootColV` applies it as
  `scale` with `transformOrigin: Item.Top`, compressing the overflow to
  fit cleanly. At `1.0` (a bar that already fits) nothing changes.
- The **music string** scales in sync: `BarVertical` publishes the factor
  to `ZenStringsState.verticalFitScale`, and the vertical strings overlay
  multiplies the string by it and re-centers on the scaled slot position.

## Important — only kicks in when the bar OVERFLOWS

`vFitScale` is `1.0` whenever the column already fits the bar, so on a
bar that isn't full this is a no-op. If your column is overflowing
(too many modules for the screen height), everything now shrinks to fit.

If your bar FITS but the music string still feels too long / overlaps
its neighbours, that's a separate knob (shortening the string itself) —
tell me and I'll add that on top.

## Version

- `ZenVersion.qml` bumped `hf95.6` → `hf95.7`.

## Files touched

- `zen-shell-v5/BarVertical.qml` — `vFitScale`, host min-height, rootColV scale
- `zen-shell-v5/ZenStringsState.qml` — `verticalFitScale`
- `zen-shell-v5/shell.qml` — string scales + re-centres on scaled slot
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. Horizontal bar untouched.
