# Zen Shell hf39-hf42 Productivity Features — Usage Guide

This document explains how to use the 5 productivity features added in
v7.0.0-beta.1-hf39, plus the hf40 sticky-note enhancement.

After installing **hf42** (or later), `quicknotes` and `titletranslator`
appear on your bar automatically. The other 3 are available via
**Settings → Panel → Module Layout → +Add** dropdown.

---

## 1. Quick Notes 📝

**Bar icon:** sticky-note glyph with count badge
**Keybinds:**
- `Super + Shift + N` — toggle popover (auto-creates note if empty)
- `Super + Alt + N` — always create new note + open

### What it does

Markdown scratchpad. Each note = one `.md` file under
`~/.local/share/zen-notes/YYYY-MM-DD-HHMM.md`. Auto-saves every keystroke
(500ms debounce).

### How to use

**Create a note:**
1. Press `Super + Shift + N` OR click the bar icon
2. Type your note content — saves automatically
3. First non-empty line becomes the title in the sidebar

**Sticky notes (Post-It style):**
1. Open Quick Notes panel
2. With a note selected, click the ⭐ button in editor header
3. A yellow floating sticky note appears on your desktop
4. Edit it directly from the sticky window — syncs with the .md file
5. Click ⭐ again on the sticky (or in the panel) to un-stick
6. Note stays in library — only the floating window is removed
7. Sticky state persists across shell restarts

**Pin to top:**
- Click the ★ button — note jumps to top of sidebar list
- Useful for current/active notes

**Tags:**
- Add `#hashtag` anywhere in your note text
- Search box on top of sidebar filters by title, body, OR tag

**Delete:**
- Right-click a note in sidebar → Delete

### Where files live

```
~/.local/share/zen-notes/2026-05-16-1432-12345.md  ← your notes
~/.config/quickshell/zen-shell/quick-notes.json    ← pinned/sticky IDs
```

You can edit notes in vim/neovim/any editor — Quick Notes will re-scan
on next open and pick up changes.

---

## 2. Title Translator 🌐

**Bar icon:** globe with language-code badge (JA / ZH / KO / RU / AR)
**No keybind — passive.**

### What it does

Watches the active window title for non-Latin scripts. When detected,
shows the language code on the bar icon. Hover the icon to see the
detected title + translation tooltip.

### How to use

**Passive mode (default):**
1. Open any app with foreign text in its title (e.g. Japanese YouTube)
2. Bar icon turns blue with `JA` badge
3. Hover the icon → tooltip shows the title + "Click to translate"
4. Click the icon → translation appears in the tooltip

**Auto-translate mode:**
1. Settings → PRODUCTIVITY → Title Translator
2. Toggle "Auto-translate" ON
3. Now translations fetch automatically when foreign title detected

**Self-hosted LibreTranslate:**
1. Settings → PRODUCTIVITY → Title Translator
2. Change LibreTranslate URL to your own instance
3. Default is the public `translate.argosopentech.com` (rate-limited)

**Right-click bar icon** → jumps to Settings page.

### Where data lives

```
~/.config/quickshell/zen-shell/title-translator.json    ← config
~/.cache/zen-shell/title-translations.json              ← cache
```

The cache persists across reboots so repeat titles don't hit the
network every time.

---

## 3. Focus Spaces 🗺️ (opt-in)

**Not in default barLayout.** Add via Settings → Panel → +Add → "Focus Spaces"

### What it does

Save and restore per-app workspace layouts. Example: "Coding" workspace =
VS Code on ws1 + 2 terminals on ws2 + Brave docs on ws3. One click
restores. If apps aren't running, they get launched.

### How to use

**Save a layout:**
1. Open apps and arrange them how you want (workspaces, monitors)
2. Settings → PRODUCTIVITY → Focus Spaces
3. Type a name like "Coding" in the field at top
4. Click Save → all current windows captured

**Restore a layout:**
1. Settings → PRODUCTIVITY → Focus Spaces
2. Click Restore on any saved space
3. Existing windows move to their saved workspace + position
4. Missing apps get launched with `hyprctl dispatch exec [workspace N silent]`

**Update existing:**
- Open new windows / rearrange
- Click Update on the space → captures current state, replaces stored

**Delete:**
- Click the red × button on a space row

### Caveats

- App detection by window class. If you have weird launch flags (e.g.
  Discord via flatpak), the auto-detected launch command may be wrong.
- Some apps (Brave with restored session) ignore positioning and use
  their own last state.
- Floating window positions restore exactly. Tiled positions restore
  to the right workspace but Hyprland decides tile order.

---

## 4. Network Pulse 🌐 (opt-in)

**Not in default barLayout.** Add via Settings → Panel → +Add → "Network Pulse"

### What it does

Live per-app bandwidth monitoring. Shows ↓ ↑ rates on the bar. Click
opens Settings page with per-app connection breakdown.

### How to use

**View total bandwidth:**
- Bar icon shows ↓ rate / ↑ rate live (updates every 2s when hovered/clicked,
  every 10s when idle)

**See which apps are using the network:**
1. Right-click bar icon → Settings → Network Pulse
2. List shows: each PID, comm name, connection count, ports

**Block awareness:**
- (Manual sandboxing — Zen Shell doesn't actually firewall apps)
- Mark an app as "blocked" for awareness
- Pair with `firejail` or `nftables` outside the shell for actual blocking

### Tools detected

- **ss** — always available (built into iproute2)
- **nethogs** — optional, gives true per-app bandwidth if installed
  with `SUID` or `CAP_NET_ADMIN`. If missing, only connection counts
  are shown (no per-app B/s).

```bash
sudo pacman -S nethogs   # Arch
sudo setcap cap_net_admin,cap_net_raw+ep $(which nethogs)
```

### Where data lives

```
~/.config/quickshell/zen-shell/network-pulse.json
```

---

## 5. Smart Dim 💡 (opt-in)

**Not in default barLayout.** Add via Settings → Panel → +Add → "Smart Dim"

**Off by default.** Must be explicitly enabled.

### What it does

Context-aware brightness automation. Watches active window class +
fullscreen + battery state. Applies brightness adjustments per a
rule table.

### Rule table (defaults)

| Rule | Trigger | Adjustment | Priority |
|---|---|---|---|
| `battery_critical` | Battery < 15% on battery | Set to 30% | 100 (highest) |
| `video` | mpv/vlc/celluloid + fullscreen | Offset -10% | 70 |
| `video_browser` | Brave/Firefox + YouTube/Netflix + fullscreen | Offset -8% | 60 |
| `gaming` | GameProfileService.gameActive | Offset -5% | 30 |
| `ide` | VS Code / vim / emacs | Offset +5% | 40 |
| `reading` | Browsers / PDFs / Obsidian | No change | 20 |
| `default` | Anything else | Restore baseline | 0 |

### How to use

**Enable:**
1. Settings → PRODUCTIVITY → Smart Dim
2. Toggle "Enable Smart Dim" ON
3. Smart Dim snapshots your current brightness as the **baseline**
4. From now on, brightness adjusts as your active window changes

**Re-snapshot baseline:**
- Adjust your brightness manually to a new comfortable level
- Settings → Smart Dim → Re-snapshot
- The new value is now the "no-rule-active" target

**Disable:**
- Toggle OFF → brightness restored to baseline

### What you'll see

The bar icon (if you add it) color-codes by active rule:
- Default sun (white) — no rule active
- Moon (blue) — video / video_browser
- Lightbulb (green) — ide
- Book (white) — reading
- Battery (red) — battery_critical
- Gamepad (purple) — gaming

### Where data lives

```
~/.config/quickshell/zen-shell/smart-dim.json
```

You can edit the rules JSON directly for custom triggers — `classes`
array, `titleRegex`, `kind: "absolute"|"offset"`, `value`, `priority`.

---

## Module visibility cheat sheet

| Module | In default bar? | How to add |
|---|---|---|
| `quicknotes` | ✅ yes (hf42 default) | already there |
| `titletranslator` | ✅ yes (hf42 default) | already there |
| `focusspaces` | ❌ opt-in | Settings → Panel → +Add → "Focus Spaces" |
| `networkpulse` | ❌ opt-in | Settings → Panel → +Add → "Network Pulse" |
| `smartdim` | ❌ opt-in | Settings → Panel → +Add → "Smart Dim" |

---

## Right-click anywhere → Settings shortcut

All 5 bar modules support **right-click → jump to their Settings page**:

- Right-click quicknotes icon → Quick Notes settings
- Right-click focusspaces icon → Focus Spaces settings
- Right-click networkpulse icon → Network Pulse settings
- Right-click smartdim icon → Smart Dim settings
- Right-click titletranslator icon → Title Translator settings

Faster than navigating through `Super+comma` → sidebar → click.

---

## Privacy note

- **Title Translator** sends window titles to the configured
  LibreTranslate endpoint when translation is requested. By default
  this is `translate.argosopentech.com` (public). Set your own
  self-hosted URL if you want everything local.
- **Quick Notes** are stored as plain `.md` files in your home
  directory — no cloud, no sync. Use your own backup tool if needed.
- **Network Pulse** reads `/proc/net/dev` + `ss -p` locally. No
  network traffic from this feature itself.
- **Smart Dim** reads `hyprctl activewindow` locally. Window class
  + title are NOT transmitted anywhere.
- **Focus Spaces** stores window class names + launch commands
  locally in JSON. No transmission.

🍃 Enjoy!
