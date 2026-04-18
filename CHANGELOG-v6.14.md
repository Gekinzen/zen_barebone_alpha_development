# Zen Shell v6.14 — Changelog

**Target:** Hyprland 0.54+ / CachyOS / Arch Linux
**Quickshell:** QML-based shell (Zen Shell beta)
**Total QML files:** 50
**Type:** Bugfix release

---

## v6.14 — Tooltip PopupWindow Rewrite + SwayNC Position Fix

Two bugs from v6.13 fixed: SysRow tooltip popping up at wrong screen
position, and SwayNC notification position not applying from Settings.

---

## Bug 1: SysRow Tooltip Misaligned — PopupWindow Rewrite

**Symptom:** Hovering any SysRow icon (CPU, RAM, Sound, etc.) showed
the tooltip at the far LEFT of the screen instead of directly above
the hovered icon. Worse in floating/island bar modes.

**Root cause:** v6.13 used a separate PanelWindow in shell.qml with
manual `margins.left` calculated from parent-chain x-offset walking.
This broke because:
- The parent walk gives position-within-window, not screen position
- Floating mode margin offset was approximate
- Island mode (centered bar) had no offset calculation at all
- Layer-shell PanelWindows don't expose their screen position

**Fix — same approach as Taskbar.qml:**

Replaced the PanelWindow tooltip with a `PopupWindow` inside each
`SysRowIcon.qml`, using Quickshell's built-in anchor system:

```qml
PopupWindow {
    anchor.item: root          // anchor to THIS icon
    anchor.edges: Edges.Top    // appear above
    anchor.gravity: Edges.Top  // grow upward
    visible: iconMouse.containsMouse
    ...
}
```

This is the exact same pattern that Taskbar.qml uses for its window
list and context menu popups — and those work correctly in all bar
modes. Quickshell handles all the Wayland positioning automatically.

**Changes:**
- `SysRowIcon.qml` — tooltip is now a local PopupWindow, no more
  SysRowState.showTooltip/hideTooltip calls needed
- `shell.qml` — removed the old Variants + PanelWindow tooltip block
  (75 lines removed)
- `hyprland-layer-rules.conf` — removed `zen-shell-tooltip` layer rule
  (PopupWindow is not a layer-shell surface)

**SysRowState.qml tooltip properties kept** (tooltipVisible, tooltipTitle,
tooltipDetail, tooltipX, showTooltip, hideTooltip) — not referenced
anymore but left in place for any external consumers. Can be cleaned
up in a future release.

---

## Bug 2: SwayNC Notification Position Not Applying

**Symptom:** Clicking a new position in Settings → Notifications
(e.g. bottom-right) would visually select it, but the test notification
still appeared at the old position (top-right).

**Fixes applied:**

### Process reuse — rapid clicks silently ignored

Quickshell's `Process` object ignores `running = true` if already
running. The patch script takes ~4s. Rapid clicks → command set but
never started.

**Fix:** `if (swayncPatcher.running) swayncPatcher.running = false`
before setting new command. Same for `stateSaver`.

### patchTimer too short

200ms delay between state save and config patch was marginal.

**Fix:** Increased to 500ms.

### Script: SIGKILL without SIGTERM

`pkill -9 swaync` doesn't let swaync clean up Wayland surfaces.

**Fix:** SIGTERM first, wait 1s, SIGKILL only if still alive.

### Script: python3 heredoc variable injection

Unquoted heredoc with bash variable expansion into Python code.

**Fix:** Quoted heredoc + `sys.argv` for clean separation.

### Script: no verification after write

**Fix:** Reads back `positionX`/`positionY` from config after write,
logs WARNING on mismatch.

### Script: execution order

**Fix:** Moved `regen-swaync-theme.sh` before config patch (defensive).

**Files changed:** `NotificationPage.qml`, `patch-swaync-position.sh`

---

## Files

**Modified (2 QML):**
- `SysRowIcon.qml` — complete rewrite: PopupWindow tooltip
- `NotificationPage.qml` — Process reuse fix, timer bump, debug logging

**Modified (1 QML, removal only):**
- `shell.qml` — removed PanelWindow tooltip block (75 lines)

**Modified (1 script):**
- `patch-swaync-position.sh` — SIGTERM restart, verification, heredoc fix

**Modified (1 config):**
- `hyprland-layer-rules.conf` — removed zen-shell-tooltip layer rule

**Unchanged:** All other 47 QML files, all other scripts, themes

---

## Install

```bash
tar -xzf zen-shell-v6_14-complete.tar.gz
cd zen-shell-v6_14-complete
./install.sh
```

## Test Checklist

- [ ] SysRow `❮` expand → hover Sound icon → tooltip pops up directly above it
- [ ] Hover CPU → tooltip above CPU, hover RAM → above RAM
- [ ] Tooltip follows icon position exactly (like Taskbar popups)
- [ ] All three bar modes: fullwidth, floating, island — tooltip correct
- [ ] Settings → Notifications → click bottom-left → notif appears bottom-left
- [ ] Settings → Notifications → click top-center → notif appears top-center
- [ ] Rapid click: bottom-left then immediately bottom-right → final = bottom-right
- [ ] Position persists after `qs` restart
- [ ] `cat /tmp/zen-swaync-position.log` shows correct values
- [ ] Restart SwayNC button still works
- [ ] Clear All Notifications button still works
