# v7.0.0-beta.1-hf82i — ZenStrings vertical alignment fix for top-anchored bar

**Channel:** beta (hotfix patch on hf82h)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 2 files (shell.qml + ZenVersion.qml)

---

## User report

> "yung strings ko kapag top panel hindi naka pantay sa mismong qml bar ko"

When the bar is set to **top** position, the ZenStrings rope overlay renders misaligned vertically — visually offset below where the actual bar slot is, instead of centered on the bar's music-widget slot.

Verified from the screenshot: the bar is at the top, but the strings overlay sits slightly below the bar's vertical center, with a noticeable gap between the bar and the rope.

---

## Root cause

In `shell.qml`, the `slotCenterY` binding inside the `ZenStrings` block (around line 1348) only handled the **bottom-anchored** case:

```qml
slotCenterY: {
    const actualBottomMargin = stringsWindow.margins.bottom
    const barBottomInWindow = stringsWindow.implicitHeight
        - (PanelState.panelMarginBottom - actualBottomMargin)
    return barBottomInWindow - PanelState.barHeight / 2
}
```

This computes the bar's center Y position by working backwards from the **bottom edge** of the strings overlay window, using `PanelState.panelMarginBottom`. When the bar is at the top, `panelMarginBottom` is 0 (or irrelevant) — the bar is anchored from the TOP via `panelMarginTop` instead.

The math falls apart for the top case:

| Variable | Bottom-anchored | Top-anchored |
|---|---|---|
| `stringsWindow.implicitHeight` | `barHeight + 2*vPad` | `barHeight + 2*vPad` |
| `stringsWindow.margins.bottom` | `panelMarginBottom - vPad` (or 0) | **0** |
| `stringsWindow.margins.top` | 0 | `panelMarginTop - vPad` (or 0) |
| `PanelState.panelMarginBottom` | actual bottom margin | **0** |
| `PanelState.panelMarginTop` | 0 | actual top margin |
| Resulting `slotCenterY` | correct | **way below the bar** (~`barHeight/2 + 2*vPad` instead of `vPad + barHeight/2`) |

Meanwhile the `margins.top` / `margins.bottom` bindings on `stringsWindow` itself (lines 1314–1315) DO handle both cases correctly:

```qml
margins.bottom: PanelState.isTop ? 0 : Math.max(0, PanelState.panelMarginBottom - vPad)
margins.top: PanelState.isTop ? Math.max(0, PanelState.panelMarginTop - vPad) : 0
```

So the window itself is positioned correctly — only the slot-center calculation INSIDE the window was missing the `isTop` branch, which left the strings rendering at the wrong Y within an otherwise-correctly-positioned window.

---

## Fix

Mirror the bottom-anchored math for the top case:

```qml
slotCenterY: {
    if (PanelState.isTop) {
        // Window's top edge is at: screenTop + actualMarginTop
        // Bar's top edge is at:    screenTop + panelMarginTop
        // So bar top within this window is:
        //   panelMarginTop - actualMarginTop
        // Bar center Y = bar top + barHeight/2
        const actualTopMargin = stringsWindow.margins.top
        const barTopInWindow = PanelState.panelMarginTop - actualTopMargin
        return barTopInWindow + PanelState.barHeight / 2
    }
    // Existing bottom-anchored math unchanged
    const actualBottomMargin = stringsWindow.margins.bottom
    const barBottomInWindow = stringsWindow.implicitHeight
        - (PanelState.panelMarginBottom - actualBottomMargin)
    return barBottomInWindow - PanelState.barHeight / 2
}
```

Plus a `panelPositionChanged` Connections handler so top↔bottom toggles trigger a clean position-ready cycle (same pattern as the existing `panelModeChanged` handler for fullwidth/floating/island flips):

```qml
function onPanelPositionChanged() {
    stringsWindow.positionReady = false
    ZenStringsState.positionReady = false
    ZenStringsState.musicSlotLocalX = -1
    stringsStabilityTimer.restart()
    stringsMaxWaitTimer.restart()
}
```

Without this, the slotCenterY binding recomputes correctly but the Wayland-side anchor flip (margins.top vs margins.bottom) hasn't propagated yet — one-frame visible misalignment during the transition. The reset-and-resettle pattern (already used for the panel-mode flip) is the established way to handle this cleanly.

---

## Patched files

| File | hf82h | hf82i | Δ | Why |
|---|---:|---:|---:|---|
| `shell.qml` | 3091 | 3137 | +46 | `slotCenterY` isTop branch + `onPanelPositionChanged` Connections + comments |
| `ZenVersion.qml` | 110 | 110 | +0 | hf82h → hf82i string bumps |

---

## Install

Drop-in over hf82h:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82i-patch-only.tgz

cp zen-shell-v7.0.0-beta.1-hf82i/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload, verify:
1. **Bar at TOP** → ZenStrings rope should be vertically centered ON the bar's music-widget slot. No gap below.
2. **Bar at BOTTOM** → unchanged from hf82h (existing bottom-anchored case was already correct).
3. **Toggle top ↔ bottom** in Settings → Panel → Panel Position. Strings should briefly fade out, the bar settles in the new position, then strings fade back in correctly aligned. No visible misalignment frame.
4. Settings → User Profile → System Information → `v7.0.0-beta.1-hf82i · released 2026-05-24`.

---

## Wala tayong babawasan

Bottom-anchored math preserved unchanged inside the `if (PanelState.isTop) { ... } return ...` structure. The new top-anchored branch only fires when the bar is actually at top. Existing positionReady / stability timer / max-wait fuse / sanity gate all preserved.

The new `onPanelPositionChanged` handler is purely additive — it mirrors the existing `onPanelModeChanged` handler one level above it, so the established reset-and-resettle pattern is consistent across both kinds of bar reconfiguration.

Zero removals. One header bump (ZenVersion hf82h → hf82i). One inline file-level version comment was NOT bumped on `shell.qml` since shell.qml is the umbrella file without a single canonical header (it's the entry point).

---

## Open threads still active

- Quickshell C++ crash dump capture
- Multi-monitor flameshot screen targeting (`--screen N`)
- Drag + overflow auto-scroll (12+ pinned apps edge case)
- Build-time version auto-derivation (`git describe`)
- `Component.onCompleted` race audit across the codebase (3 confirmed hits in hf82d/hf82e/hf82h; likely more lurking)
- **NEW from hf82i:** audit for "panel-position-aware" calculations elsewhere in the shell. The slotCenterY bug pattern is "math that assumes bottom-anchored bar without an isTop branch". Likely also affects: other floating overlays anchored relative to the bar (Hyprbars title-bar previews, hot-corner indicators, OSDs, notification toast Y position), any module that hard-codes a `panelMarginBottom` dependency. Pre-screen these before user-facing reports surface them one by one.
