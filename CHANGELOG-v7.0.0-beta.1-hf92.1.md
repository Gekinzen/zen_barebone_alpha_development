# Zen Shell v7.0.0-beta.1-hf92.1 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**Boot-safety hotfix for hf92.** Wala tayong babawasan.

---

## Fix: "Cannot assign to non-existent property vertical"

hf92 failed to load with:

```
BarVertical.qml[98]: Cannot assign to non-existent property "vertical"
```

In the build here, `Workspaces.qml` (and `Taskbar.qml`, `Clock.qml`) all
correctly declare `property bool vertical: false` — verified. The error
means the engine instantiated a `Workspaces` type that lacked the
property, which happens when the **running config dir**
(`~/.config/quickshell/zen-shell/`) still has an older copy of that one
file (a partial/stale sync from the tarball — Quickshell loads from
`~/.config/...`, not the tarball folder).

A hard inline `vertical: true` assignment in a `Component {}` is checked
at instantiation, so one stale module file brings down the WHOLE shell
(Quickshell stops at the first error).

Fix — make the vertical opt-in crash-proof:
- **`BarVertical.qml`** — instead of inline `Module { vertical: true }`,
  each vertical module is now set via a guarded
  `Component.onCompleted: { if (this.vertical !== undefined) this.vertical = true }`.
  JS property access on a missing QML property returns `undefined`
  (doesn't throw), so:
  - With the correct files → `vertical` is set to true, full vertical
    layout (unchanged from the intended hf92 behavior).
  - With a stale module file → that module just stays horizontal instead
    of crashing the entire shell. The bar still boots.

So the shell will start no matter what state the config dir is in.

> **To get the full vertical layout**, make sure your launcher actually
> re-copies ALL .qml files from this tarball into
> `~/.config/quickshell/zen-shell/` (a stale `Workspaces.qml` there was
> the trigger). A clean re-sync of the whole folder is safest.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf92.1
BarVertical.qml  vertical opt-in via guarded onCompleted (boot-safe)
```

Carries forward hf83–hf92 (vertical Taskbar/Workspaces/Clock, the
one-icon viewport fix, separated BarVertical architecture). Horizontal
bar remains the known-good pre-hf90 version.

---

## Next (your order)
SysRow vertical (stacked icons + arrow up/down) → Window-title vertical
→ vertical music strings + auto-hide/slide + rounded corner decorators.
