# Zen Shell v7.0.0-beta.1-hf90 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical bar — Tategaki (縦書き) Phase 1.** The left/right panel
position renders a real vertical bar now. Fully additive + opt-in:
nothing changes unless you pick Left or Right. Wala tayong babawasan.

---

## What works now

Pick **Settings → Panel → Panel Position → Left** (or Right) and the bar
moves to that edge, full height, and reserves screen space (windows tile
beside it).

- **`PanelPage.qml`** — Left + Right re-added to the Panel Position
  picker (removed back in Modori when there was no vertical rendering).
- **`PanelState.qml`** — left/right are now accepted + persisted (no more
  silent migrate-to-bottom on load). `isVertical` / `isHorizontal` /
  `isLeft` / `isRight` flags drive everything.
- **`shell.qml`** — bar window is position-aware: vertical anchors
  top+bottom + the chosen side edge, full height, fixed thickness
  (= your Bar Height value, reused as width), and the layer-shell
  reserves that thickness. Horizontal (top/bottom) anchoring is
  byte-for-byte unchanged.
- **`Bar.qml`** — added a parallel vertical `ColumnLayout` content path
  (top / center / bottom zones, mapped from your left / center / right
  bar layout). It only activates when `isVertical`; the horizontal
  `RowLayout` path is gated to `isHorizontal` and its modules unload when
  vertical, so there's no double-loading and the horizontal bar is
  untouched.
- **`Workspaces.qml`** — now orientation-aware: dots stack in a column on
  a vertical bar (GridLayout flips to 1 column), back to a row on
  top/bottom.

Already in place (verified, no change needed):
- The **music-strings overlay** already suppresses itself on a vertical
  bar (`visible: … && PanelState.isHorizontal`), so it won't mis-draw.
- The **Settings sidebar** has zero dependency on panel position, so the
  old Modori "user row disappears on left/right" risk isn't reintroduced
  from there.

## Phase 1 honesty — what's NOT done yet

- **Taskbar + SysRow render in their horizontal (wide) form** inside the
  vertical bar, so they'll clip to the thin width. Small pill modules
  (Clock, Battery, single-icon, Workspaces) stack cleanly. Proper
  vertical rendering of Taskbar/SysRow is **Phase 2** — for now, a
  Left/Right bar works best with the narrow modules.
- **Vertical music strings** (your "horizontal → vertical strings"
  request) is **Phase 2** — the current strings overlay is a horizontal
  renderer and is intentionally suppressed on vertical for now.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf90
PanelState.qml   accept + persist left/right (no migrate-away)
PanelPage.qml    Left/Right re-added to Panel Position picker
shell.qml        bar window vertical anchoring + thickness + reserve
Bar.qml          additive vertical ColumnLayout content path
Workspaces.qml   dots stack vertically on a vertical bar
```

Carries forward hf83–hf89 in full.

---

## Next (Tategaki Phase 2)
- Vertical Taskbar (icon column) + vertical SysRow (stacked cluster).
- Vertical music strings renderer for left/right bars.
- Vertical bar visual polish (thickness control, per-edge rounding).
