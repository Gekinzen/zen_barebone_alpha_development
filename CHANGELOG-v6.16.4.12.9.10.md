# v6.16.4.12.9.10 — Modori (戻り) · hotfix 10

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.9 — Modori hotfix 9

## Summary

Replaces the `zenity --password` external dialog for first-time
WiFi connection with an **in-shell overlay popup** that floats
above all other surfaces — including the Control Panel that
triggered it. User reported the zenity prompt was hidden behind
the Control Panel and required moving windows to find it.

The new prompt:

- Floats at `WlrLayer.Overlay` (top compositor layer) — cannot
  be hidden by any other surface
- Centered on the focused monitor with a dimmed backdrop
- Auto-focuses the password field on open
- Submit on Enter, cancel on Esc
- Show/hide password toggle (eye icon)
- Click backdrop or any surface outside the prompt → cancel
- Themed to match the shell (no system GTK theme dependency)

## Architecture

### `PasswordPromptService.qml` singleton (NEW)

Reactive state holder + callback dispatcher. Public API:

```qml
PasswordPromptService.requestPassword(ssid, onSubmit, onCancel)
PasswordPromptService.setError("Wrong password")   // optional
```

`onSubmit(password)` fires when the user clicks Connect or hits
Enter. `onCancel()` fires when they click outside, hit Esc, or
click Cancel. Both are stored as JS function refs in the
service and invoked safely (try/catch around each).

If a previous prompt is still active when `requestPassword` is
called again, the old one is cancelled first (last-call-wins).

### `PasswordPromptPanel.qml` component (NEW)

Visual content — backdrop + centered card with header, password
TextField, error message slot, Cancel/Connect buttons. Uses
the existing ThemeService palette so it matches whatever theme
the user has active.

The TextField has `Keys.onReturnPressed` / `onEnterPressed` /
`onEscapePressed` handlers wired to the service's submit/cancel
methods. A `Connections { target: PasswordPromptService }` block
auto-focuses the field whenever `active` flips to true.

The show-password toggle is a small eye icon button that flips
the TextField's `echoMode` between `Password` and `Normal`.

### `shell.qml` integration

A new `Variants { model: Quickshell.screens }` block right after
`controlPanelWindow` mounts a `PanelWindow` per screen, but only
the focused-monitor instance is ever visible (matching the
existing controlPanelWindow pattern):

- `WlrLayershell.layer: WlrLayer.Overlay` — top compositor layer
- `WlrLayershell.namespace: "zen-shell-pwprompt"`
- `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` —
  captures Esc/Enter even if another window has focus
- `HyprlandFocusGrab` — clicks on Hyprland surfaces outside the
  overlay (e.g. the bar) cancel the prompt
- `exclusionMode: ExclusionMode.Ignore` — doesn't push the bar
  around when it appears

### `ConnectivityService.connectWifi()` rewrite

The previous monolithic bash one-liner that ran the
saved-creds check + zenity prompt + nmcli connect in one
synchronous shell pipeline is split into stages:

1. **`connectWifi(ssid, security)`** → spawns
   `savedCredsCheck` Process to query `nmcli connection show`
2. **`savedCredsCheck.stdout` finished** → branches on result:
   - `SAVED` → run `nmcli connection up <SSID>` directly
   - `NEW + open` → run `nmcli device wifi connect <SSID>`
   - `NEW + secured` → call
     `PasswordPromptService.requestPassword(...)` with a
     callback that runs the connect with the typed password
3. **User submits** → callback fires, runs nmcli with the
   password
4. **User cancels** → callback fires (no-op + log)

The legacy `connectWifi(ssid, password)` direct-string form
still works for programmatic callers.

If `PasswordPromptService` is somehow undefined (extremely
unlikely — it's a singleton), the code falls back to the old
zenity invocation. So the worst-case regression is "behaves
like before".

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.10. |
| `zen-shell-v5/PasswordPromptService.qml` | NEW — singleton with `active`/`ssid`/`errorMessage` reactive state, `requestPassword(ssid, onSubmit, onCancel)` API, internal `_submit(pwd)` / `_cancel()` callback dispatch with try/catch safety. |
| `zen-shell-v5/PasswordPromptPanel.qml` | NEW — visual content. Backdrop, centered card with lock icon header + SSID label + password TextField with eye-toggle + error message slot + Cancel/Connect buttons. Auto-focus, Enter/Esc handlers, themed colors. |
| `zen-shell-v5/shell.qml` | New `Variants` block right after `controlPanelWindow` mounts a `passwordPromptWindow` `PanelWindow` per screen. WlrLayer.Overlay, exclusive keyboard focus, HyprlandFocusGrab for outside-click cancel. Visible only when `PasswordPromptService.active && isFocusedMonitor`. |
| `zen-shell-v5/ConnectivityService.qml` | `connectWifi()` rewritten: monolithic zenity-bash pipeline replaced with async `savedCredsCheck` Process + branch logic. Saved → reconnect; New+open → connect; New+secured → `PasswordPromptService.requestPassword` with callback. Legacy `connectWifi(ssid, password)` still works. zenity fallback retained for safety if PasswordPromptService is unavailable. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.10.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.10
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

## Test scenarios

1. **Connect to a NEW secured WiFi network**: Open Control Panel
   (Super+C) → WiFi tab → tap a network in AVAILABLE NETWORKS
   that isn't in your saved list. The password prompt should
   appear centered on screen, with backdrop dimming, and the
   password field should already be focused — just start typing.

2. **Tap outside the prompt**: Click anywhere on the dimmed
   backdrop or on the bar. The prompt should dismiss without
   connecting.

3. **Press Esc**: Should also cancel.

4. **Press Enter after typing**: Should submit and start the
   connect attempt. The prompt closes immediately; `nmcli`
   runs in the background. The Control Panel updates within
   ~3s with the new connection state (active SSID highlighted
   in SAVED NETWORKS).

5. **Show/hide password**: Click the eye icon to toggle between
   masked and visible.

6. **Connect to a SAVED network**: Tap a row in SAVED NETWORKS.
   Should connect immediately — no password prompt because
   credentials are already stored. (This was already the
   behavior in .9.9; the .9.10 change preserves it.)

## Why the dimmed-backdrop modal pattern

Wayland's layer-shell protocol doesn't have a native "modal"
primitive — there's no `xdg_popup_constraints` for "block input
to lower layers". The standard approach is:

1. Render at `WlrLayer.Overlay` (the topmost layer)
2. Cover the entire screen with a partial-alpha backdrop
3. Set `keyboardFocus: WlrKeyboardFocus.Exclusive` to capture
   keyboard input
4. Use `HyprlandFocusGrab` to detect when the user clicks
   outside the overlay surface area

That gives the same effect as a modal: visually distinct,
focus is captured, outside clicks are detected. It's how
swaylock, ulauncher, and similar wlroots tools handle prompts.

## Carry-forward from Modori .9.9

All Modori .9.9 features preserved:

- WiFi+BT Control Panel redesign (saved/available split, refresh,
  forget, scan, pair, larger tap targets)
- GTK Dark Mode toggle
- Bulletproof sidebar user labels
- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- Left/Right panel position cards hidden + L/R-to-Bottom migration
- All Tachiagari .7.1 features

## Wala tayong babawasan

The previous `connectWifi()` API surface is unchanged — same
`(ssid, security)` signature, same legacy `(ssid, password)`
direct-string form. Existing UI rows (Available Networks tap,
SysRowIcon WiFi tap, etc.) work without modification — they
just now get the in-shell prompt instead of zenity.

Zenity is still installed by `install.sh` for other features
(custom theme save/rename/delete) — not removed from
dependencies.

## Future enhancements

- **Wrong-password feedback**: Currently if `nmcli` returns an
  error (wrong password), the prompt closes anyway and the
  Control Panel shows the network as still not active. Better:
  watch the actionRunner exit code, re-open the prompt with
  `setError("Authentication failed")` if it failed. Tracked in
  BETA-BLOCKERS.md.
- **Auto-connect on save**: Add a "Connect automatically" checkbox
  to the prompt that sets `connection.autoconnect=true` on the
  newly-created nmcli connection.
- **Remember per-network**: For enterprise (WPA-Enterprise / 802.1X)
  networks, the prompt needs more fields (username, identity, EAP
  method). Not in this drop — treats them as standard WPA which
  will fail silently. Tracked in BETA-BLOCKERS.md.
