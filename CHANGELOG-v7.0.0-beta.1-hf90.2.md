# Zen Shell v7.0.0-beta.1-hf90.2 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Architecture fix: horizontal bar fully de-risked; vertical bar moved
to its own component.** Wala tayong babawasan.

---

## The problem

Even after hf90.1, switching back to Top/Bottom still looked broken. The
root issue was architectural: hf90 had taught the SHARED horizontal
components (`Bar.qml`, `Workspaces.qml`) to also handle vertical, so the
horizontal bar kept catching collateral damage from vertical logic.

## The fix — separate vertical, like end-4

end-4's dots-hyprland keeps vertical in a dedicated `VerticalBar` /
`VerticalBarContent` tree, NOT inside its horizontal bar. Adopted that:

- **`Bar.qml`** — reverted to its pre-hf90 state. No `isVertical` /
  `isHorizontal` / dual-path anywhere. The horizontal bar is exactly what
  it was when top/bottom last worked.
- **`Workspaces.qml`** — reverted from the GridLayout experiment back to
  the original `RowLayout`. No orientation logic.
- **`BarVertical.qml`** — NEW dedicated vertical content component
  (top / center / bottom column, mapped from your left / center / right
  layout). Each module sits in a `VerticalModuleHost` that centers it and
  clips it to the bar thickness so a wide module can't force the bar
  wide.
- **`shell.qml`** — the bar window now mounts the horizontal `Bar` via a
  Loader active only when `isHorizontal`, and `BarVertical` via a Loader
  active only when `isVertical`. The two never coexist and never share a
  tree. `bar.contentImplicitWidth/Height` readers are null-guarded for
  the moment the horizontal Bar isn't loaded.

Net effect: **top/bottom is back to the known-good horizontal bar**, and
the vertical bar is a separate, opt-in renderer that cannot touch it.

## Vertical bar — honest status

Left/Right load `BarVertical`. Modules that stack cleanly (Workspaces,
Clock, Battery, single-icon, tray) look right. The wide cluster modules
(Taskbar, SysRow) are clipped to the bar thickness for now — they get
proper vertical modes in Phase 2. The empty-looking vertical bar from
before was those wide modules failing to render; now they're at least
constrained and the clean modules show. Real vertical Taskbar/SysRow +
vertical music strings are the next focused drops.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf90.2
Bar.qml          reverted to pre-hf90 (horizontal-only, no vertical logic)
Workspaces.qml   reverted to original RowLayout
BarVertical.qml  NEW — dedicated vertical bar content
shell.qml        bar window mounts Bar (horizontal) XOR BarVertical
                 (vertical) via separate Loaders; bar readers null-guarded
```

Carries forward hf83–hf89 in full; supersedes the hf90 / hf90.1 vertical
approach with the separated-component architecture.

---

## Next (Tategaki Phase 2 — your priority order)
1. **Vertical music strings** — vertical ZenStrings renderer in
   `BarVertical` (your #1).
2. **Vertical Taskbar / SysRow** — `vertical` modes (icon column + drag
   reorder; stacked cluster).
3. **Auto-hide + slide-in** + **rounded corner decorators** (end-4 feel).

> Lesson logged: keep an XL feature in its own component/tree. Don't
> teach the stable shared components to also do the new thing — separate,
> mount conditionally, leave the proven path byte-for-byte untouched.
