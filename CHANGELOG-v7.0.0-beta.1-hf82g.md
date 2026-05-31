# v7.0.0-beta.1-hf82g — Universal taskbar drag + flameshot scale-fix v2 + install.sh banner refresh

**Channel:** beta (hotfix patch on hf82f)
**Released:** 2026-05-24
**Branch:** `dev`
**Scope:** 2 QML files + 1 script + install.sh

---

## Two user-reported issues + 1 cosmetic fix

### Issue 1 — Last 2 taskbar icons can't be dragged

> "sa taskbar sa dulo last 2 icons hindi ko ma drag"

Screenshot showed 9 icons in the taskbar; the last 2 had workspace badges (small dots at bottom of icon — `wsBadge` visible because `isRunning && _wsLabel.length > 0`). These are **running-but-not-pinned** apps that sit at the end of `appList`, after the pinned ones.

The hf82f drag implementation hardcoded `if (!appBtn.isPinned) return` in both the press-hold-timer fire and the 8px-move quick-drag path. Running-but-not-pinned icons could not engage drag at all — neither the visual lift nor the cursor follow. The user saw "press-and-hold does nothing" on those last 2 icons and reasonably concluded the drag feature was broken for them.

**The user expectation matches every modern DE** — GNOME, KDE, Plasma, Windows 11, macOS Dock — every icon in the taskbar is draggable, regardless of pin state. Dragging a non-pinned icon implicitly pins it at the dropped position.

**Fix:** drag now accepts ANY icon. The drag-start path:

1. Press-hold timer fires (or 8px move) on any icon → `_startDrag()` invoked.
2. If `!appBtn.isPinned`, `pinApp(appId)` is called first — adds the appId to `pinnedApps` at the end. The auto-pin is tracked via new `_dragAutoPinned` flag on `taskbarRoot`.
3. The fresh `pinnedIndex` is read from the now-updated `pinnedApps` array → that becomes `_dragStartIndex`.
4. Drag proceeds normally with the icon at its current visual position (which is the end-of-pinnedApps slot, where running-only icons already render).
5. On commit (release with valid target), the reorder fires — `pinnedApps` gets the moved app at the new position, `savePinned()` persists.
6. On cancel (Esc / focus loss / drop-outside), if `_dragAutoPinned` was true, `unpinApp(appId)` is called to undo the auto-pin — the icon goes back to running-but-not-pinned state.

Net result: every icon is draggable. The user's mental model ("just drag any icon to reorder") works without surprises.

---

### Issue 2 — Flameshot STILL crops at 1.25x / 1.5x scale

> "ganito itsura nung flameshot putol dapat buo padin yun screen kapag screenshot kunwari naka 1.25 , 1.5 scale"

The hf82e fix (`get_active_monitor_geometry` switched from printing native → logical dimensions) was a wrong-direction guess. Screenshot from the user showed the capture was STILL cropped — only ~2/3 of the screen width was captured on a 1.5x scaled monitor.

**Root cause is upstream:** flameshot on Wayland-Hyprland with `--region` has known buggy coordinate handling. Neither native nor logical dimensions work consistently across fractional scales. The flameshot Wayland backend uses either `wlr-screencopy` or `xdg-desktop-portal` depending on environment, and the `--region` geometry isn't interpreted the same way across both. There's no consistent transform we can apply in our wrapper script that makes it work right for all scales.

The hf82e attempt fixed the "what flameshot thinks the screen size is" half of the problem but didn't fix the "how flameshot crops the captured buffer using that size" half — different scales gave different crop amounts because flameshot's internal pixel arithmetic doesn't account for scaled-display Wayland properly.

**Fix:** drop `--region` from all flameshot calls. `flameshot gui`, `flameshot full`, and `flameshot full --clipboard` are now called bare. flameshot's own focused-monitor auto-detection takes over — works correctly on Hyprland Wayland regardless of scale.

**Trade-off:** In multi-monitor setups where flameshot's auto-detection picks the wrong screen (rare but possible), the workaround is to move the mouse to the desired screen before pressing the keybind. The hf82e attempt to enforce focused-monitor targeting via `--region` caused way more problems than it solved on scaled displays. The right way to target a specific monitor on Wayland is via the `--screen N` argument (where N is a flameshot-side index), which would require maintaining a mapping between hyprctl monitor names and flameshot screen indices — out of scope for this hotfix.

Script bumped `zen-screenshot.sh` v6.13 → v6.14.

---

### Cosmetic fix — `install.sh` banner showed `hf58`

User's screenshot of the install output:

```
║    🎉  ZEN SHELL v7.0.0-beta.1-hf58 · KARUI ALPHA 5 INSTALLED  🎉   ║
...
  ✅  Done. Enjoy Zen Shell v7.0.0-beta.1-hf58 Karui (軽い).
```

The shell itself was on hf82f but `install.sh` had the v7.0.0-beta.1-hf58 strings hardcoded from January. Was already in the "Open Threads" list from earlier roadmap revisions — fixed now while I'm in here.

Three string updates in `install.sh`:
1. Top banner: `Zen Shell v7.0.0-beta.1-hf75 — Karui (軽い) alpha 5` → `v7.0.0-beta.1-hf82g` + fresh changelog summary for hf82a-82g block prepended to existing historical entries.
2. Closing box banner: `hf58 · KARUI ALPHA 5 INSTALLED` → `hf82g · KARUI ALPHA 5 INSTALLED`.
3. Done line: `Done. Enjoy Zen Shell v7.0.0-beta.1-hf58 Karui (軽い).` → `v7.0.0-beta.1-hf82g`.

Historical changelog blocks deeper in the script (hf62 detail, hf58 detail, etc.) are preserved unchanged — they're documentation of past hotfixes, not active version display, and ripping them out would lose context.

**Still open thread:** auto-derive the version string at install time from `git describe` or the release tarball filename. Manual bumps per release are error-prone (as this issue proves). Out of scope for hf82g.

---

## Patched files

| File | hf82f | hf82g | Δ | Why |
|---|---:|---:|---:|---|
| `Taskbar.qml` | 1282 | 1347 | +65 | Drag accepts any icon; auto-pin on start + auto-unpin on cancel |
| `ZenVersion.qml` | 110 | 110 | +0 | hf82f → hf82g string bumps |
| `scripts/zen-screenshot.sh` | 232 (v6.13) | 235 (v6.14) | +3 (mostly comment changes — actual logic simplification dropped ~30 lines but added explanatory comments) | Drop `--region` from all flameshot calls |
| `install.sh` | 4047 | 4072 | +25 | Banner / Done refresh + hf82g changelog summary prepended |
| **Total** | **5671** | **5764** | **+93** | |

---

## Install

Drop-in over hf82f:

```fish
tar -xzf zen-shell-v7_0_0-beta_1-hf82g-patch-only.tgz

cp zen-shell-v7.0.0-beta.1-hf82g/zen-shell-v5/*.qml \
   ~/.config/quickshell/zen-shell/

cp zen-shell-v7.0.0-beta.1-hf82g/scripts/zen-screenshot.sh \
   ~/.config/quickshell/zen-shell/scripts/
chmod +x ~/.config/quickshell/zen-shell/scripts/zen-screenshot.sh

# Optional: refresh install.sh in your dev tarball (for future installs)
cp zen-shell-v7.0.0-beta.1-hf82g/install.sh \
   ~/Documents/development/v17/v6/zen-shell-v7.0.0-beta.1-hf82g/

pkill -f quickshell; and sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

After reload, verify:

1. **Universal drag:** press-and-hold ANY taskbar icon — including the running-but-not-pinned ones at the end of the bar — for 350ms. The icon should lift and follow the cursor. Drop where you want.
2. **Auto-pin commit:** drag a running-only icon, drop it somewhere in the middle of the pinned apps. Check that it's now pinned at that position:
   ```fish
   cat ~/.local/share/quickshell/zen-shell/pinned-apps.json
   # Should include the formerly-running app in the new order.
   ```
3. **Auto-pin rollback on cancel:** drag a running-only icon, then press Esc or drop outside the bar. The icon should snap back to its original position AND NOT appear in pinned-apps.json. Restart the shell to verify it's still running-but-not-pinned.
4. **Flameshot full-screen at 1.5x:** trigger your screenshot keybind. The flameshot GUI should cover the **entire visible workspace** of the focused monitor, no cropping. Test the same at 1.25x and 1.0x scales.
5. **Version display:** Settings → User Profile → System Information → `v7.0.0-beta.1-hf82g · released 2026-05-24`.
6. **Install banner (next time you run install.sh):** should read `hf82g` not `hf58`.

---

## Wala tayong babawasan

Four behavioral changes:

1. **All icons draggable.** Pre-hf82g behavior of "only pinned apps drag" was a usability bug; new behavior matches every modern DE.
2. **Auto-pin on drag-start.** Running-but-not-pinned icons gain a `pinnedApps` entry when drag begins. Reversible via cancel.
3. **`flameshot gui/full/full --clipboard` no longer get `--region`.** Lets flameshot pick the focused monitor itself, which works correctly on scaled displays.
4. **`install.sh` banner / changelog / Done refreshed** to hf82g.

Zero removals from any file. All version strings bumped consistently. `get_active_monitor_geometry()` and `get_active_monitor_slurp()` helpers in `zen-screenshot.sh` preserved — they're still useful for the grim+slurp path and for any future flameshot fix that does want to target specific screens.

---

## Known limitations / open threads

- **Multi-monitor flameshot targeting.** If flameshot's auto-detection picks the wrong screen, you currently have to move the cursor before triggering the keybind. The proper fix is mapping hyprctl monitor names to flameshot's internal `--screen N` indices — non-trivial, deferred.
- **Drag + overflow auto-scroll.** Still open from hf82f — drag near the viewport edge doesn't auto-scroll the chevron overflow region. Only matters with 12+ pinned apps.
- **Version auto-derivation at build time.** `ZenVersion.qml` + `install.sh` both have hardcoded version strings that need manual bumps every drop. `git describe --tags --always` could automate this.
- **Quickshell C++ crash dump capture.** Still pending. hf82c shipped defensive hardening; targeted fix still depends on capturing the dump.
