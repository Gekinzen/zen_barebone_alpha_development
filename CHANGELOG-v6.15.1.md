# Zen Shell v6.15.1 — Patch Changelog

**Release date:** 2026-04-19
**Base:** v6.15 (clean)
**Built & tested on:** **Hyprland 0.54+** (CachyOS / Arch Linux)
**Quickshell:** v0.2.1+ (QML-native shell)

---

## Fixes

### 1. Copy → Paste not working after screenshot capture

**Root cause:** `wl-copy` was launched via `nohup ... & disown` with
stdin redirection (`< file`). When Quickshell's Process reaped the
parent bash, the stdin fd was closed before `wl-copy` could fully
take clipboard ownership — leaving the clipboard empty or stale.

**Fix (ZenScreenshotOverlay.qml):**
- Use `setsid bash -c 'cat file | wl-copy --type image/jpeg'` to
  create a new process session. `setsid` fully detaches `wl-copy`
  from Quickshell's process tree — it survives even when the
  capture script's bash exits.
- Use `cat file | wl-copy` pipe instead of `wl-copy < file` redirect
  — piping keeps the data flowing independent of parent fd lifecycle.
- Increased settle time from 0.3s → 0.8s before verifying clipboard.
- Added clipboard verification: checks `wl-paste --list-types` for
  `image` MIME type. If missing, retries with `image/png` fallback.

### 2. State not resetting on exit — stale selection on re-trigger

**Root cause:** `ZenScreenshotOverlay` is instantiated once per screen
inside a `Variants` block. It's never destroyed/recreated between
screenshot sessions. So `phase`, `annotations`, `anchor` coordinates,
and `pendingCapture` carried over from the previous session.

**Fix (ZenScreenshotOverlay.qml):**
- Added `resetState()` function that clears all session state:
  phase → "selecting", all anchors → 0, annotations → [],
  currentStroke → null, pendingCapture → "", selection canvas hidden.
- `onVisibleChanged: if (visible) resetState()` — called every time
  the overlay appears, guaranteeing fresh state.
- `resetState()` also calls `resetPhysics()` on all 4 ZenRope
  instances so ropes start from clean lerp positions, not tangled
  from previous drag coordinates.

### 3. Rope physics too stiff — not smooth like flicko's Zephyr

**Root cause:** v6.15 used `ropeSegments: 30` and `ropeSegmentLength: 50`
(total reach 1500px). This created 30 long springs that behaved like
rigid poles — no catenary sag, no fluid motion. flicko's original uses
`segments: 10` and `segment_length: 5` (total reach ~50px), which
produces short, tightly-coupled points that drape like real string.

Additionally, gravity was 9.8 (Earth-like, too aggressive for a UI
decoration) and damping was 0.5/0.45 (too snappy, not enough inertia).

**Fix (ZenRope.qml — rewritten):**
- Reverted to flicko-original `segments: 10`, `segment_length: 5`
- Reduced gravity: 3.2 (was 9.8) — softer sag, less violent snapping
- Softer damping: `inertia: 0.65` / `springForce: 0.35`
  (was 0.5/0.45) — more momentum carry, gentler spring pull
- Result: rope swings fluidly and settles slowly, matching the
  "lambot" (soft/fluid) feel from the Zephyr reference video
- Kept lerp initialization from v6.14.2 (rope starts visually
  connected from frame 1)
- Added `resetPhysics()` function for clean re-initialization
- Physics properties (`gravity`, `inertia`, `springForce`) are
  now exposed as QML properties for future settings page tuning

**State migration (ZenStringsState.qml + install.sh):**
- `ropeSegments` default: 30 → 10
- `ropeSegmentLength` default: 50 → 5
- `install.sh` migration resets both values unconditionally
  (old 30/50 values would produce stiff rope with new physics)

---

## Modified Files

| File | Changes |
|---|---|
| `ZenRope.qml` | Rewritten — flicko-style physics (10×5), softer gravity/damping, resetPhysics() |
| `ZenScreenshotOverlay.qml` | resetState() + onVisibleChanged, rope IDs, wl-copy setsid fix |
| `ZenStringsState.qml` | Rope defaults 30/50 → 10/5 |
| `install.sh` | Migration resets ropeSegments/ropeSegmentLength to 10/5 |

---

## Test checklist

- [ ] Super+Shift+S → ropes appear from corners, smooth catenary drape
- [ ] Drag selection → ropes follow smoothly, fluid motion (not stiff)
- [ ] Release → toolbar appears, selection box clean
- [ ] Copy button → notification "Screenshot copied"
- [ ] Open any app → Ctrl+V → image pastes correctly
- [ ] Super+Shift+S again → overlay starts fresh (no old selection visible)
- [ ] Drag new selection → previous annotations gone, ropes start clean
- [ ] Escape → overlay closes cleanly
- [ ] Super+Shift+S → third session works identically to first
- [ ] Multi-monitor: rope appears on monitor where cursor is

---

*WALA TAYONG BABAWASAN — all v6.15 features carried forward.*
