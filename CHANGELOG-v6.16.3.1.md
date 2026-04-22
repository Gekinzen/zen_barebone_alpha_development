# Zen Shell v6.16.3.1 — Power Confirm: Material Design icons + theme-synced palette

**Release date:** 2026-04-22
**Branch:** `beta-v12.6.16.3.1`
**Base:** v6.16.2.3.6
**Status:** Beta — first feature drop of the v6.16.3.X series

---

## TL;DR

`PowerConfirmDialog.qml` got a Material Design icon pass. Action icons,
countdown clock, cancel/confirm buttons all switched from FontAwesome to
Material Design Icons (Nerd Font `nf-md-*` range). Color tint per action
already palette-pulled, kept as-is. One small pre-existing bug fixed
along the way. Suspend support added as forward-compat.

**One file touched. Wala tayong binawasan.**

---

## Why MDI (Nerd Font) and not Google Material Symbols?

Google Material Symbols would mean:
- New font dependency in `bootstrap.sh` / `install.sh`
- New `Theme.materialSymbolsFont` property
- Touching font-rendering paths across the shell

Nerd Font Material Design Icons live inside the JetBrains Mono Nerd Font
we already ship. **Same Material Design language, visually
indistinguishable, zero install footprint.** For a single-file restyle
that's the right call. If we ever want true Google Material Symbols
later, we add the font once, swap the codepoint range, every existing
MDI usage just works.

---

## Icon swap table

| Action / control | v6.16.2.x (FA)   | v6.16.3.1 (MDI)            |
|------------------|------------------|----------------------------|
| Shutdown         | `\uf28d`         | U+F0425 `nf-md-power`        |
| Restart          | `\uf021`         | U+F0709 `nf-md-restart`      |
| Suspend          | (none)           | U+F0904 `nf-md-power_sleep`  |
| Logout           | `\uf0343` (bug — see below) | U+F0343 `nf-md-logout`     |
| Lock             | `\uf023`         | U+F033E `nf-md-lock`         |
| Warning fallback | `\uf071`         | U+F0028 `nf-md-alert_circle` |
| Countdown clock  | `\uf017`         | U+F0150 `nf-md-clock_outline`|
| Cancel button    | `\uf00d`         | U+F0156 `nf-md-close`        |
| Confirm button   | `\uf00c`         | U+F012C `nf-md-check`        |

Above-BMP codepoints written as UTF-16 surrogate pairs (`\udb81\udc25`,
etc.) to match the codebase's `\uXXXX` escape convention. Each pair was
verified end-to-end by codepoint round-trip before commit.

Icon `font.pixelSize` bumped 42 → 48 for the main action halo, 14 → 16
for the small in-row glyphs. MDI strokes read slightly narrower than FA
at identical px sizes — the bump restores visual weight inside the 96px
halo and the 44px buttons.

---

## Theme-synced colors — already healthy, kept as-is

The action accents (`Theme.red` for shutdown, `Theme.orange` for
restart, etc.) are already pulled from the active theme via
`Theme.applyScheme()`, which rewrites every `Theme.{red,green,blue,...}`
property when a scheme JSON loads. So switching from `tokyo-night` to
`catppuccin-mocha` already retints the dialog correctly.

The semantic mapping was preserved 1:1 — destructive (red) stays
destructive, etc. — with one new entry for suspend (purple, matches the
"sleep / dormant" cue used by GNOME and KDE):

| Action   | Theme token     | Tokyo-Night hex | Catppuccin hex |
|----------|-----------------|-----------------|----------------|
| Shutdown | `Theme.red`     | `#f7768e`       | `#f38ba8`      |
| Restart  | `Theme.orange`  | `#ff9e64`       | `#fab387`      |
| Suspend  | `Theme.purple`  | `#bb9af7`       | `#cba6f7`      |
| Logout   | `Theme.yellow`  | `#e0af68`       | `#f9e2af`      |
| Lock     | `Theme.blue`    | `#7aa2f7`       | `#89b4fa`      |

---

## Bug fix snuck in: logout glyph literal

The pre-3.1 logout entry was:

```qml
case "logout":   return { icon: "\uf0343", title: "Logout", ... }
```

JS / QML string escapes take **exactly four** hex digits after `\u`.
`"\uf0343"` was being parsed as `"\uf034" + "3"` — i.e. the FontAwesome
`text-height` glyph (`\uf034`) immediately followed by the literal
character `3`. So the logout button was actually rendering as
`<text-height-icon>3` next to the title. Probably never noticed because
the FA `text-height` glyph is small and thin and the `3` blended into
the icon at low display sizes.

The new MDI logout glyph U+F0343 is written as a proper surrogate pair
`"\udb80\udf43"`, decodes cleanly to U+F0343, no stray characters.

Coincidentally the same hex value as the buggy literal — so anyone
reading the diff might think nothing changed except the Nerd Font slot.
But: `\uf0343` (5 hex digits, malformed) vs. `\udb80\udf43` (proper
UTF-16 surrogate for U+F0343, valid) are two completely different
strings, and the second one renders the actual MDI logout icon.

---

## Suspend support — additive, no caller wired yet

The dialog now handles `action: "suspend"` as a first-class case. No
existing caller invokes it (the StartMenu power buttons in
`StartMenuPanel.qml:824-827` still go shutdown/reboot/logout/lock).
This is purely forward-compatible — whichever later v6.16.3.X item
adds a Suspend button to the Start Menu can flip it on with one line:

```qml
{ icon: "\udb82\udd04", label: "Suspend", action: "suspend",
  cmd: "systemctl suspend", destructive: false }
```

…and the dialog already knows what to do with it. Wala tayo
nagdagdag ng button ngayon — kept the StartMenu surface untouched
because that's a different scope.

---

## Files touched

```
zen-shell-v5/PowerConfirmDialog.qml   modified  (full replacement, drop-in)
```

That's it. No theme-builtin JSON edits, no `bootstrap.sh` edit, no font
install, no settings migration.

---

## How to deploy on your beta box

```bash
cp PowerConfirmDialog.qml ~/.config/quickshell/zen-shell/
~/.local/bin/zs-restart.sh   # or whatever your bulletproof restart alias is
```

Then trigger a power confirm from the Start Menu (any action) to verify
the new glyph renders. If you see a tofu □ instead of the icon, your
JetBrainsMono Nerd Font install is missing the `nf-md-*` range — run
`fc-list | grep -i jetbrains` to confirm the family name matches
`Theme.monoFont = "JetBrainsMono Nerd Font Propo"`.

---

## Verification steps Paul ran before shipping

1. Round-tripped every surrogate pair through Python codepoint math —
   all 9 pairs decoded back to the intended `nf-md-*` codepoint. ✓
2. Confirmed Theme.{red,orange,purple,yellow,blue} all pre-existing
   tokens (no new theme keys, every shipped scheme JSON in
   `themes-builtin/` already provides them). ✓
3. Public API unchanged — `action`, `command`, `countdown`, `confirmed`,
   `cancelled`, `executeAction()`, `cancel()` all identical to v6.16.2.x.
   No caller in `shell.qml` or anywhere else needs updating. ✓

---

## Next up in the v6.16.3.X series

- **v6.16.3.2** — Lid-close black-screen `hypr-config/` overlay patch
- **v6.16.3.3** — `DisplaysPage` resolution dropdown enumeration fix
- **v6.16.3.4** — Bar profile/GPU badge widget
- **v6.16.3.5** — Start Menu logo image picker
- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
