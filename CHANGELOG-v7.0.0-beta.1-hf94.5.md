# Zen Shell v7.0.0-beta.1-hf94.5 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Vertical polish: workspaces actually stacks + SysRow arrow direction.**
The crash is fixed (hf94.4), so these are normal tweaks. Wala tayong
babawasan.

---

## 1. Workspaces now stacks vertically (for real)

Workspaces stayed horizontal in the vertical bar. It was wired via a
guarded `Component.onCompleted` setter (added during the crash hunt as a
boot-safety measure). Now that we know the crash was unrelated (it was
shell.qml's `property var bar`, fixed in hf94.4), that indirection is no
longer needed — and it wasn't reliably propagating `vertical` to the
`columns` binding.

- **`BarVertical.qml`** — all 8 vertical modules now use a **direct**
  `Module { vertical: true }` binding instead of the guarded
  `onCompleted` setter. A direct property binding re-evaluates dependent
  bindings (like Workspaces' `columns: vertical ? 1 : wsCount`)
  immediately, so the dots stack in a column as intended.

## 2. SysRow arrow direction fixed

You wanted: **▲ when collapsed**, **▼ when expanded** (down = "growing
downward / opening"). It was backwards (▼ collapsed / ▲ expanded).

- **`SysRow.qml`** — vertical arrow is now ▲ collapsed → ▼ expanded.
  Horizontal keeps the configured left/right arrows.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.5
BarVertical.qml  guarded onCompleted setters → direct vertical: true (×8)
SysRow.qml       vertical arrow ▲ collapsed / ▼ expanded
```

Carries forward hf83–hf94.4. Horizontal bar unchanged; vertical modules
(Taskbar / Workspaces / Clock / SysRow / tray / music / window) all opt
in via the direct `vertical` flag.

---

## Next
With the vertical bar stable and the modules adapting, the remaining
Tategaki items: **vertical music STRINGS** (audio-reactive curves along
the side edge, when enabled) → auto-hide / slide-in → rounded corner
decorators.
