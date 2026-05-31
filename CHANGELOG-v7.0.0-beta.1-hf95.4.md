# Zen Shell v7.0.0-beta.1-hf95.4 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical SysRow no longer cuts off its icons when expanded — the
expanded CPU / RAM / volume cluster now auto-fits (scales down to fit)
instead of being clipped.** Wala tayong babawasan.

---

## SysRow — vertical expanded cluster auto-fits (no more "putol")

hf95 capped the vertical expanded height at `vMaxExpandedH` (260px) and
**clipped** the cluster so it wouldn't push the clock off the bar. The
side effect: with many modules enabled (sound, CPU, RAM, temp, network,
BT, battery) the column exceeded 260px and the bottom icons were cut off.

Now, when the vertical expanded column would overflow the cap, the whole
cluster is **scaled down to fit** instead of clipped:

- New `_vContentH` (the cluster's natural height) and `_vFitScale`
  (`vMaxExpandedH / _vContentH`, capped at 1.0).
- `mainRow` gets `scale: _vFitScale` with `transformOrigin: Item.Top`, so
  it shrinks toward the top edge, staying centered horizontally.
- `clip` is now `false` — nothing is cut off because the scale keeps the
  whole cluster inside the band.

Result: every module stays fully visible (just slightly smaller when
there are many), and the bar is still never pushed around. When the
cluster already fits, scale is 1.0 → no visual change at all.

## Version

- `ZenVersion.qml` bumped `hf95.3` → `hf95.4`.

## Files touched

- `zen-shell-v5/SysRow.qml` — `_vContentH`/`_vFitScale` + `mainRow` scale + `clip: false`
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. Horizontal SysRow is unchanged
(scale is 1.0 unless vertical + expanded + overflowing).
