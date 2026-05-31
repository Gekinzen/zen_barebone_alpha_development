# v7.0.0-beta.1-hf40 — Quick Notes: keybinds wired + sticky-note windows

**Channel:** beta (hotfix)
**Released:** 2026-05-16
**Branch:** `dev`

---

## What this hotfix fixes/adds

User report after hf39:

> "yung notes super + n napunta sa network pre . and saan yun notes
> may pop up ba ito pra ma save mga notes ko etc nakikita prang
> sticky notes ?"

Two issues:

1. **Super+N collision** — Paul's `keybinds-update.conf` line 15 binds
   `$mainMod, N` to `~/.local/bin/wifi-toggle.sh`. The hf39 changelog
   suggested Super+N for notes but never actually wired it — and
   even if it had, it would have collided with wifi-toggle.

2. **Where do notes "pop up"?** The hf39 popover view (720x480
   center panel) was there, but the *sticky note* mode (Post-It
   style floating windows on the desktop) was stubbed but not
   actually implemented. So pinning a note as "sticky" did nothing
   visible.

This hotfix fixes both.

---

## #1 — Actual keybinds wired (avoiding Super+N conflict)

### Available keybind audit

I dumped every `bind = $mainMod...` from Paul's hypr-config, then
picked combos that don't conflict with existing bindings.

**Already taken by Paul's config:**
```
Super alone:           A, B, C, D, E, F, G, J, M, N, P, Q, R, T, V, W,
                       0-9, Space, Tab, Return, comma, grave, slash, F1, F2, F12, arrows
Super+Shift:           0-9, F, F12, I, L, Q, R, Return, S, T, U, W, X, Y, comma, grave
Super+Alt:             F12, S
Super+Ctrl:            F12
```

**Free Super+X choices:** `Z H K O Y I U ; -`
**Free Super+Shift+X choices:** `A B C D E G H J K M N O P V Z`
**Free Super+Alt+X choices:** all letters except F12, S

### Chosen binds

| Binding | Action | Why |
|---|---|---|
| **Super + Shift + N** | Toggle Quick Notes panel | Natural mnemonic for "Notes", consistent with your `Super+Shift+S` (screenshot) / `Super+Shift+T` (theme) pattern. Free slot. |
| **Super + Alt + N** | Always create new note | Power-user shortcut for batch capture. Free slot. |
| **Super + N** | (unchanged) wifi-toggle | Your existing binding preserved. |
| **Super + comma** | (unchanged) toggleSettings | Your hypr-control-panel binding preserved. |

### Where they're installed

`hf40` overwrites `~/.config/hypr/modules/keybinds-update.conf` with
2 new lines added in the "Zen Shell controls" section:

```ini
# ── Quick Notes (v7.0.0-beta.1-hf40) ──
bind = $mainMod SHIFT, N, exec, qs -c zen-shell ipc call zen quicknotes_toggle
bind = $mainMod ALT, N, exec, qs -c zen-shell ipc call zen quicknotes_new
```

### IPC handlers added to `shell.qml`

```qml
function quicknotes_toggle() {
    if (!PanelState.quickNotesVisible) {
        if (QuickNotesService.notes.length === 0
            || !QuickNotesService.getCurrentNote()) {
            QuickNotesService.createNote()
        }
    }
    PanelState.quickNotesVisible = !PanelState.quickNotesVisible
}
function quicknotes_new() {
    QuickNotesService.createNote()
    PanelState.quickNotesVisible = true
}
function quicknotes_close() {
    PanelState.quickNotesVisible = false
}
function quicknotes_sticky_current() {
    const n = QuickNotesService.getCurrentNote()
    if (n) QuickNotesService.toggleSticky(n.id)
}
```

### Behavior

- **`Super+Shift+N`** when nothing currently selected → creates a
  fresh note + opens the panel (cursor in editor, can type immediately)
- **`Super+Shift+N`** when a note is already open → closes the panel
  (preserves the note, just hides the UI)
- **`Super+Alt+N`** → always creates a fresh note regardless of
  current state

---

## #2 — Sticky note windows actually visible now

### Architecture

`hf39` had `QuickNotesService.stickyIds[]` + `toggleSticky()` but
**nothing was reading that array to spawn windows**. Now:

```
QuickNotesService.stickyIds:["note-A", "note-C"]
        ↓
shell.qml Repeater { model: stickyIds }
        ↓
  ┌────────────────────────┐    ┌────────────────────────┐
  │ QuickNotesSticky       │    │ QuickNotesSticky       │
  │   noteId: "note-A"     │    │   noteId: "note-C"     │
  │   WlrLayer.Overlay     │    │   WlrLayer.Overlay     │
  │   yellow Post-It UI    │    │   yellow Post-It UI    │
  │   in-place TextArea    │    │   in-place TextArea    │
  └────────────────────────┘    └────────────────────────┘
        ↑                                ↑
        position offset hashed from noteId so they don't
        perfectly overlap (each note picks a stable spot)
```

### `QuickNotesSticky.qml` — the new component (~240 lines)

- `PanelWindow` at `WlrLayer.Overlay` → floats above bar + windows
- Yellow tint (`#fdf6a8`) with subtle border + shadow effect
- Title bar shows note title + ⭐ unstick button + ✕ close button
- TextArea autosaves to the same `.md` file as the popover editor
- Hash-derived position so multiple stickies spread across the
  screen instead of stacking at the same coordinates

### How to use

1. Open Quick Notes panel (Super+Shift+N or click bar module)
2. Type your note content
3. Click the **⭐ sticky button** in the editor header (top-right
   of the editor pane, next to the ★ pin button)
4. A yellow floating sticky note appears on your desktop
5. Edit it directly from either:
   - The sticky window itself (TextArea inside)
   - The original popover (changes sync via the shared .md file)
6. Click ⭐ or ✕ on the sticky to un-stick (note stays in library)

### Persistence

Sticky state lives in `~/.config/quickshell/zen-shell/quick-notes.json`:

```json
{
  "pinnedIds": [],
  "stickyIds": ["2026-05-16-1432-12345", "2026-05-16-1530-67890"],
  "currentNoteId": "2026-05-16-1432-12345"
}
```

Stickies survive shell restart. On startup the Repeater sees
`stickyIds` and re-spawns the windows.

### Multi-monitor

For simplicity, sticky windows mount on `Quickshell.screens[0]`
(primary). You can manually drag them around if Hyprland is configured
to allow layer-shell window dragging, but they stay on the primary
monitor. Future hotfix can add per-monitor placement.

### Editing tooltips

Both buttons in the popover editor header now show tooltips on
hover:
- ⭐ "Stick as floating note on desktop" / "Un-stick from desktop"
- ★ "Pin to sidebar top" / "Unpin from sidebar top"

So you can tell them apart at a glance.

---

## Files changed (6)

```
zen-shell-v5/QuickNotesSticky.qml     NEW (~240 lines)
zen-shell-v5/shell.qml                +4 IPC handlers + Repeater mount
zen-shell-v5/QuickNotesPanel.qml      added sticky button + tooltips
zen-shell-v5/QuickNotesPage.qml       updated keybind hint text
zen-shell-v5/ZenVersion.qml           bumped to hf40
hypr-config/keybinds-update.conf      added 2 bind lines
install.sh                            banner + changelog entry
```

Total: 1 new file, 5 edits. No regressions to hf39's existing 5
features. All previous fixes (hf32-hf39) preserved.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf40-quicknotes-keybinds-sticky.tgz
cd zen-shell-v7.0.0-beta.1-hf40
./install.sh
```

The installer copies the updated `keybinds-update.conf` to
`~/.config/hypr/modules/keybinds-update.conf`. Reload Hyprland:

```bash
hyprctl reload
```

Or just log out + back in.

---

## How to verify

### Keybinds

```bash
# Press Super+Shift+N → panel should open with a fresh note ready
# Press Super+Shift+N again → panel closes
# Press Super+Alt+N → another new note is created + panel opens
# Press Super+N → wifi-toggle.sh runs (your existing behavior preserved)
```

### Sticky notes

1. Press `Super+Shift+N` → panel opens
2. Type "Test sticky note" in the editor
3. Click the ⭐ button (top-right of editor pane)
4. A yellow floating sticky note appears on your desktop
5. Click outside the panel → panel closes, sticky stays visible
6. Edit the sticky directly → see saves persist
7. Click ⭐ on the sticky → it disappears (note still in library)

### Multiple stickies

1. Open `Super+Shift+N` → make note 1 → ⭐ stick it
2. `Super+Alt+N` → make note 2 → ⭐ stick it
3. `Super+Alt+N` → make note 3 → ⭐ stick it
4. You should see 3 yellow stickies in different positions on
   the desktop

### Persistence

1. Stick a note
2. `pkill quickshell` then let it respawn (or reboot)
3. After login, the sticky should reappear automatically

---

## Wala tayong babawasan

All hf32-hf39 features preserved. The 5 productivity features from
hf39 (Quick Notes / Focus Spaces / Network Pulse / Smart Dim / Title
Translator) still work. Hot corners (hf37) still work. Refresh rate
toggle (hf36) still works. Native toasts (hf32) still work.

This hotfix is pure additive — wires the existing Quick Notes
service properly so it's actually usable from the keyboard + makes
the sticky-note dream real. 🍃
