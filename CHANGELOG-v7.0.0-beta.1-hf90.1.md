# Zen Shell v7.0.0-beta.1-hf90.1 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Regression hotfix for hf90.** Wala tayong babawasan.

---

## Fix: top/bottom bar looked broken after hf90

hf90 introduced the vertical bar, but in doing so it rewrote the bar
window's `anchors` / `implicitWidth` / `implicitHeight` / `margins` into
new combined expressions. Those expressions changed behavior for the
**horizontal** (top/bottom) bar too — so even after switching back to Top
or Bottom, the bar looked wrong.

Root cause: the horizontal anchoring/sizing was no longer the original
logic — it was folded into `isVertical || …` / `isHorizontal && …`
combinations that didn't evaluate identically to the pre-hf90 code.

Fix — the horizontal path is now the **original expressions verbatim**,
wrapped as `PanelState.isVertical ? <vertical> : <ORIGINAL>`. When the
bar is on Top or Bottom (`isVertical === false`), every binding
evaluates **exactly** as it did before hf90:

- `anchors.top/bottom/left/right` — original values when horizontal.
- `implicitHeight` — original auto-height / barHeight expression.
- `implicitWidth` — original per-mode (fullwidth/floating/island) logic.
- `margins.top/bottom/left/right` — original ternaries.

So top/bottom is back to normal, and the vertical branch only applies
when you actually pick Left/Right.

Also: **SysRow** experimental vertical changes from the in-progress
work were reverted — it renders exactly as before (no risk to the
horizontal bar).

---

## Vertical bar status (unchanged from hf90, still Phase 1)

Left/Right still render a vertical bar. Clean-stacking modules
(Workspaces, Clock, Battery, single-icon) stack nicely. The wide cluster
modules (Taskbar, SysRow) still render horizontally inside it — that's
Phase 2 (see below). Music-strings overlay stays suppressed on vertical.

---

## Files touched

```
ZenVersion.qml  → v7.0.0-beta.1-hf90.1
shell.qml       horizontal anchoring/sizing/margins = original verbatim,
                vertical isolated behind `isVertical ? … : ORIGINAL`
SysRow.qml      reverted experimental vertical changes (unchanged vs hf89)
```

Carries forward hf83–hf90.

---

## Confirmed next: Tategaki Phase 2 (per your picks)

You asked for all three of end-4's vertical traits + vertical icon
stacks + vertical music strings first. Planned (separate, focused
drops — not riding on a hotfix again):

1. **Vertical music strings** (your #1 priority) — a vertical ZenStrings
   renderer that attaches to the left/right bar (curves drawn
   top-to-bottom), replacing the current suppress-on-vertical behavior.
2. **Dedicated vertical modules** — `vertical` flag on Taskbar (icon
   column with vertical drag-reorder) + SysRow (stacked cluster), the
   way end-4 gives each widget a `vertical: true` mode instead of
   squishing the horizontal one.
3. **Auto-hide + smooth slide-in** — bar slides off the edge and returns
   on hover / Super, with `Behavior on anchors.*Margin` animations
   (end-4's `elementMoveFast` feel).
4. **Rounded corner decorators** — screen-corner pieces that hug the bar
   where it meets the edge (end-4 `roundDecorators`).

> Lesson logged: don't fold an XL feature's new logic into shared
> expressions that the stable path also evaluates. Keep
> `isVertical ? new : ORIGINAL` so the established path is provably
> unchanged.
