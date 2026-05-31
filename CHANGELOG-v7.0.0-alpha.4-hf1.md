# v7.0.0-alpha.4-hf1 — StartMenu V2 fixes

**Channel:** alpha (hotfix)
**Released:** 2026-05-08
**Branch:** `dev`

---

## What this hotfix fixes

Six issues in the alpha.4 StartMenu V2, all reported in user testing:

### 1. Pinned grid alignment

**Issue:** When fewer items pinned than grid slots, items appeared
distributed across rows with visible gaps (e.g. 8 pinned items showed
4 in row 1 + 4 in row 4, with rows 2-3 empty).

**Cause:** `GridLayout` expands to fill its parent height, distributing
N rows across the configured slot count.

**Fix:** Replaced with `QtQuick.Grid` (packs top-left → bottom-right
naturally, no distribution behavior). Anchored to `parent.top` so
partial fills sit at the top.

### 2. Avatar image broken

**Issue:** Was showing only a first-letter circle placeholder; user's
actual avatar image (set via Settings → User Profile) didn't render.

**Fix:** Now binds `Image.source` to
`UserProfileService.effectiveAvatarSource` (matches v6 behavior:
custom avatar → /var/lib/AccountsService → fallback to letter only
when no image loads).

The Rectangle's `radius: 16` + `clip: true` naturally circle-clips the
image; the letter fallback now only shows when `Image.status !==
Image.Ready`.

### 3. Folder button → Thunar specifically

**Issue:** Was firing `xdg-open ~`, which on some setups opened a
non-Thunar file manager.

**Fix:** Now invokes `thunar "$HOME"` directly via shell-side detection:

```
sh -c 'command -v thunar >/dev/null && thunar "$HOME" || xdg-open "$HOME"'
```

Falls back to xdg-open silently if thunar isn't installed. Tooltip
added: "Files (Thunar)".

### 4. Settings button restored

**Issue:** The settings gear button between Files and Power was
missing from the alpha.4 user pill.

**Fix:** Added back. Clicking opens the in-shell Zen Settings panel
via the same IPC call v6 used:

```
qs -c zen-shell ipc call zen toggleSettings
```

Closes the StartMenu after triggering. Tooltip: "Settings".

### 5. Power button → expandable popup

**Issue:** Single-click logout fired `powerActionRequested("logout", "")`
immediately. No way to access Lock / Suspend / Restart / Shutdown
without going through other UI.

**Fix:** Power button now toggles a popup menu showing all 5 actions
with the same icons + commands as v6:

| Icon | Label | Action | Command |
|---|---|---|---|
| `\uf023` | Lock | `lock` | `hyprlock` |
| `\uf186` | Suspend | `suspend` | `systemctl suspend` |
| `\uf2f5` | Logout | `logout` | `hyprctl dispatch exit` |
| `\uf021` | Restart | `reboot` | `systemctl reboot` |
| `\uf011` | Shutdown | `shutdown` | `systemctl poweroff` |

Each menu item fires `powerActionRequested(action, command)` which
flows through shell.qml's existing `triggerPowerAction()` →
`PowerConfirmDialog` chain. Shutdown row gets red destructive
styling. Click-outside closes the menu.

When Densho on, labels become bilingual:
"Lock · 施錠", "Suspend · 休眠", "Logout · 退出", "Restart · 再起動",
"Shutdown · 終了".

### 6. Right-click context menu

**Issue:** Right-clicking immediately toggled pin state with no
visible feedback or way to cancel.

**Fix:** Right-click on either an all-apps row OR a pinned tile now
opens a small floating popup at cursor position with two rows:

- **Pin to Start** (or **Unpin from Start** if already pinned) —
  commits the action
- **Cancel** — closes without changes

Click-outside also closes. The popup is clamped to the panel bounds
so it never escapes the visible area.

When Densho on:

- "Pin · 固定"
- "Unpin · 解除"
- "Cancel · 取消"

---

## Files modified

```
zen-shell-v5/StartMenuPanel.qml   (full rewrite — same file, ~870 lines, was ~740)
zen-shell-v5/ZenVersion.qml       (bumped to v7.0.0-alpha.4-hf1)
install.sh                        (version strings)
```

No other files touched. AppLauncherService, RecentFilesService,
PanelState, BarModulesPage all unchanged from alpha.4.

---

## Wala tayong babawasan

- All alpha.4 features preserved: dynamic grid (PanelState configurable),
  auto-detect across pacman/AUR/Flatpak/Snap, recently-used.xbel parsing,
  Densho-aware bilingual headers, ListView reuseItems, debounced search.
- Public panel interface unchanged — shell.qml mount remains untouched.
- All v7 alpha.1-3 features (Updates Panel, Densho Foundation, Densho
  Surfaces) carry forward.

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.4-hf1-startmenu-fixes.tgz
cd zen-shell-v7.0.0-alpha.4
./install.sh
qs -r
```

Auto-snapshot before overwrite (Updates Panel safety net). Roll back
via Settings → Updates → Restore if anything misbehaves.
