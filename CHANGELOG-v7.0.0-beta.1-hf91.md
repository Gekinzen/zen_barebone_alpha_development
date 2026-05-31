# Zen Shell v7.0.0-beta.1-hf91 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical Taskbar — Tategaki Phase 2 (1 of 4).** Top/bottom confirmed
normal on hf90.2, so module-level vertical modes start here. Additive;
explicit `vertical` flag defaults false. Wala tayong babawasan.

---

## Vertical Taskbar (icon column + vertical drag-reorder)

The Taskbar now has a real vertical mode, the end-4 way: an explicit
`vertical` property (not global state-sniffing), so the horizontal bar is
provably untouched.

- **`Taskbar.qml`**
  - New `property bool vertical: false`. When false, every binding is the
    original horizontal logic verbatim — top/bottom is byte-identical.
  - When true: the module becomes a fixed-width COLUMN whose height grows
    with icon count; icons stack on the Y axis (`y = effectiveIndex *
    (btnSize + btnSpacing)`, centered on X).
  - Drag-to-reorder works vertically: new `_dragCursorY` /
    `_dragGrabOffsetY` track the Y axis; press/move/commit use Y when
    vertical (X path unchanged for horizontal). `_dragHitIndex` is
    axis-agnostic (same slot pitch), so reorder logic is shared.
  - `Behavior on y` added for smooth neighbor-slide in vertical (the
    existing `Behavior on x` still drives horizontal).
- **`BarVertical.qml`** — mounts the taskbar as `Taskbar { vertical: true }`.

Vertical overflow (chevron scroll when too many icons) is deferred to a
small follow-up (Phase 2b) — for now the column grows; with a normal
app count it fits fine.

## Still horizontal-form inside the vertical bar (next in order)
- **SysRow** (next) → stacked icon cluster.
- **Workspaces** → dot column.
- **Window title** → vertical/rotated.

These still render in their horizontal form (clipped to thickness by
`VerticalModuleHost`) until their turn.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf91
Taskbar.qml      explicit `vertical` mode — icon column + Y-axis drag
BarVertical.qml  taskbar mounted with vertical: true
```

Carries forward hf83–hf90.2; horizontal Bar/Workspaces remain the
reverted, known-good pre-hf90 versions.

---

## Next (your order)
SysRow vertical → Workspaces vertical → Window-title vertical → then
vertical music strings + auto-hide/slide + rounded corner decorators.
