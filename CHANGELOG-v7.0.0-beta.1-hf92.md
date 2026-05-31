# Zen Shell v7.0.0-beta.1-hf92 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical fixes + Workspaces & Clock vertical modes.** Fixes the
one-icon taskbar bug and adds two more vertical modules. Top/bottom
confirmed normal. Additive, explicit `vertical` flags default false.
Wala tayong babawasan.

---

## 1. Fix: vertical taskbar showed only one icon

The taskbar's "clipped viewport" (the container that hides horizontal
overflow behind ‹ › chevrons) was a fixed-height 44px strip with
`clip: true`. In vertical mode it clipped the icon COLUMN to ~one icon
tall — the empty-pill-with-one-icon you saw.

- **`Taskbar.qml`** — the viewport is now axis-aware: vertical sizes it
  to `btnSize × taskbarColH` (full column, no clip); horizontal keeps the
  original 44px clipped strip exactly. The icon column also aligns to the
  viewport top in vertical. Result: **icons stack downward** and all show.

## 2. Workspaces vertical (dots stack downward)

- **`Workspaces.qml`** — explicit `vertical` flag. Vertical → dots stack
  in a column (GridLayout, 1 column) and the module sizes to the bar
  thickness; horizontal → unchanged single row.
- **`BarVertical.qml`** — mounts `Workspaces { vertical: true }`.

## 3. Clock vertical (date/time fits the thin bar)

The horizontal clock renders a wide one-line "YYYY-MM-DD HH:MM:SS" that
overflowed the vertical bar (you saw "2026-05-" cut off).

- **`Clock.qml`** — explicit `vertical` flag. Vertical → a compact
  STACKED readout: HH over MM, a divider, then MM / dd, all centered and
  sized to the bar thickness so nothing is clipped. Horizontal → the
  original single-line clock, untouched.
- **`BarVertical.qml`** — mounts the clock + calendar slots with
  `vertical: true`.

---

## Still to do (your order)
- **SysRow vertical** — stacked icon cluster + the expand arrow pointing
  up/down (next).
- **Window title vertical** — rotated/clamped.
- Then vertical music strings + auto-hide/slide + rounded corner
  decorators.

The taskbar's vertical OVERFLOW (chevron scroll when very many apps) is
still Phase 2b — the column grows for now.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf92
Taskbar.qml      axis-aware clipped viewport (fixes one-icon bug)
Workspaces.qml   explicit `vertical` — dot column
Clock.qml        explicit `vertical` — stacked compact readout
BarVertical.qml  workspaces + clock + calendar mounted vertical: true
```

Carries forward hf83–hf91; horizontal Bar remains the known-good
pre-hf90 version, and all vertical behavior is opt-in via explicit flags.
