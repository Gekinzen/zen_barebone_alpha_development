# Zen Shell v7.0.0-beta.1-hf94.1 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Crash hotfix for hf94.** Wala tayong babawasan.

---

## Fix: crash within 10s of launch

hf94 booted ("Shell ready") then crashed within 10 seconds. Two new
layout constructs from hf94 were the likely cause — both are
feedback-loop hazards that can recurse at the C++ layout level (a hard
crash, not just a warning):

1. **WindowTitle rotated text** — a 90°-rotated `Text` inside an `Item`
   whose size was derived from that Text's implicit size, with
   `anchors.centerIn` coupling position to the parent size. Size →
   position → size loops here can crash.
2. **VerticalModuleHost** — the loader used `anchors.verticalCenter`
   while the host's `Layout.preferredHeight` read the loaded item's
   implicit height — another size↔position feedback path.

Fixes:
- **`WindowTitle.qml`** — vertical title is now dead-simple and
  loop-free: the app icon + a very short, clipped horizontal label
  underneath (max ~6 chars). No rotation, no size-from-child coupling.
  (Rotated vertical text can come back later in a carefully-tested drop.)
- **`BarVertical.qml`** — `VerticalModuleHost` loader reverted to
  `anchors.top` (no `verticalCenter`), removing the feedback path while
  still forwarding the module's implicit height with a `Math.max(1, …)`
  floor.

The pre-existing `ZenDropdown` / `NetworkPulseModule` /
`TitleTranslatorModule` "[undefined] to bool/QString" warnings are NOT
from this work (those files are untouched) and are harmless transient
binding warnings, not the crash cause.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.1
WindowTitle.qml  vertical title simplified (icon + short label, no rotation)
BarVertical.qml  host loader back to top-anchor (no verticalCenter loop)
```

Carries forward hf83–hf94. Horizontal bar remains the known-good
pre-hf90 version; vertical modules (Taskbar / Workspaces / Clock /
SysRow / tray / music / window) are all opt-in via explicit flags.

> Lesson logged: in a vertical layout, avoid `rotation` + `anchors.centerIn`
> on an item whose parent sizes from the item, and avoid `verticalCenter`
> on a loader whose host height reads the loaded item — both are
> size↔position feedback loops that can hard-crash the scene graph.
