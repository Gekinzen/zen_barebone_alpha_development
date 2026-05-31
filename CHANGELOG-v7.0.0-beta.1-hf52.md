# v7.0.0-beta.1-hf52 — Hyprbars plugin integration

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix adds

User request:

> "pwd ba ma install nadin ito tas may enable and disable tayo
> https://github.com/hyprwm/hyprland-plugins/tree/main/hyprbars
> tas yung color synced themes ah tas yun minimize maximize and exit
> may toggle left and right"

Translation: install + enable/disable toggle for the hyprbars Hyprland
plugin, with theme-synced colors and a left/right toggle for the
minimize/maximize/close buttons.

Hyprbars adds **window title bars** to Hyprland windows themselves
(rendered by Hyprland's own renderer, not by Quickshell). Lets you
recreate the traditional close/minimize/maximize buttons + a
draggable title strip on every window.

---

## What's included

### Plugin install management

`HyprbarsService.qml` wraps `hyprpm`:

```bash
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprbars
hyprpm reload
```

Buttons in Settings:
- **Install / reinstall** — fires the full add + enable + reload chain
- **Update plugin** — fires `hyprpm update; hyprpm reload`
- **Enable toggle** — flips the plugin on/off and writes config

State persisted to `~/.config/quickshell/zen-shell/hyprbars.json`.

### Color sync with Zen Shell theme

The service generates `~/.config/hypr/zen-hyprbars.conf`:

```hypr
plugin {
    hyprbars {
        bar_height = 24
        bar_color = rgb(282828)      # from ThemeService.bg1
        col.text = rgb(ebdbb2)       # from ThemeService.fg
        bar_text_size = 11
        bar_text_font = Adwaita Sans
        bar_text_align = left
        bar_buttons_alignment = right
        bar_blur = true
        bar_part_of_window = true
        bar_precedence_over_border = true
        bar_padding = 10
        bar_button_padding = 5
        on_double_click = hyprctl dispatch fullscreen 1

        hyprbars-button = rgb(b8bb26), 11, _, hyprctl dispatch movetoworkspacesilent special:minimized, rgb(1d2021)
        hyprbars-button = rgb(fabd2f), 11, , hyprctl dispatch fullscreen 1, rgb(1d2021)
        hyprbars-button = rgb(fb4934), 11, , hyprctl dispatch killactive, rgb(1d2021)
    }
}
```

When `syncWithTheme` is ON (default), every theme change fires a
re-write of this file + `hyprctl reload` so the title bars match
your current Zen Shell theme live. Switch from gruvbox to tokyo-night
and the title bars instantly recolor.

Auto-source: the service also appends
`source = ~/.config/hypr/zen-hyprbars.conf` to your main
`~/.config/hypr/hyprland.conf` on first enable, so Hyprland picks it
up. Idempotent — won't duplicate if already present.

### Button side toggle (left vs right)

Segmented control in the Settings page:

- **Left** (macOS style): `🔴 🟡 🟢` close → minimize → maximize from
  the leftmost edge
- **Right** (Windows style): `_ □ ✕` minimize → maximize → close from
  the rightmost edge

Under the hood, sets `bar_buttons_alignment = left` or `right` and
adjusts the order of `hyprbars-button =` lines so the close button
always ends up at the outermost edge for the chosen side.

Per upstream README + forum discussion confirming `bar_buttons_alignment`
is the right config key.

### Per-button visibility

Three rounded pill toggles in Settings:
- Show close button (✕) — runs `hyprctl dispatch killactive`
- Show maximize button (□) — runs `hyprctl dispatch fullscreen 1`
- Show minimize button (_) — runs `hyprctl dispatch movetoworkspacesilent special:minimized`

All ON by default. Toggle any individually.

### Appearance controls

- **Bar height** slider (16-40px, default 24)
- **Text size** slider (8-16pt, default 11)
- **Font family** (defaults to your Theme.fontFamily — "Adwaita Sans")
- **Sync colors with theme** toggle (default ON)
- **Blur background** toggle (default ON)
- **Bar is part of window** toggle (default ON — shadows surround the bar)

### Exclude specific apps

Settings page shows copy-paste examples for excluding apps via
Hyprland windowrules:

```hypr
windowrule = hyprbars:no_bar, class:^(Brave-browser)$
windowrule = hyprbars:no_bar, class:^(code-oss)$
windowrule = hyprbars:no_bar, fullscreen:1
windowrule = hyprbars:bar_color rgb(282828), class:^(kitty)$
```

These you add to your hyprland.conf manually (per-app exclusions
weren't worth a full GUI — the plugin maintainer doesn't expose a
runtime API for them).

---

## Files added (3 new)

```
zen-shell-v5/HyprbarsService.qml       NEW — plugin manager singleton
zen-shell-v5/HyprbarsSettingsPage.qml  NEW — Settings UI
zen-shell-v5/Hf52ToggleRow.qml         NEW — reusable label+pill row
```

## Files modified (2)

```
zen-shell-v5/ZenSettings.qml    — added Hyprbars nav entry + page
                                   StackLayout index 23
zen-shell-v5/ZenVersion.qml     — bumped to hf52
install.sh                       — banner + changelog
```

---

## Build dependencies (one-time)

Hyprbars compiles natively against the Hyprland headers. On
Arch/CachyOS you need:

```bash
sudo pacman -S --needed cpio cmake git meson gcc
```

Most ricer setups already have these. The Settings page surfaces
this hint as plain text under the Status section.

---

## How to install Zen Shell hf52

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf52-hyprbars-integration.tgz
cd zen-shell-v7.0.0-beta.1-hf52
./install.sh
```

`pkill quickshell` to reload.

---

## How to use

### Enable hyprbars

1. Open Settings (Super+,)
2. APPEARANCE → Hyprbars (title bars) — kanji 窓枠 / Madowaku
3. Click **"Install / reinstall"** button (first time only — does
   `hyprpm add` + `enable` + `reload`)
4. Toggle the pill at top → green
5. Title bars appear on all your Hyprland windows

### Switch button side

In the Settings page, hit the **Left** segment in the "Button side"
row. macOS-style traffic-light buttons appear on the left. Click
**Right** to flip back.

### Disable temporarily

Toggle the pill at top → grey. Fires `hyprpm disable hyprbars` +
`hyprpm reload`. Title bars disappear. Toggle back on later — your
button side / per-button visibility / color sync preferences are
preserved.

### Exclude apps

Copy a line from the "Exclude specific apps" section into your
`~/.config/hypr/hyprland.conf` and run `hyprctl reload`:

```hypr
windowrule = hyprbars:no_bar, class:^(Brave-browser)$
```

Now Brave shows without a title bar; other windows still have one.

---

## Original 18-feature list progress

This was item **#11 (Hot Corners + modifier keys)** in spirit — adds a
window-management feature you don't have to write a separate WM rule
for. Pero technically it's a NEW item:

| # | Feature | Status | Shipped |
|---|---|---|---|
| 1-5 | Focus Spaces, Smart Dim, Network Pulse, Quick Notes, Title Translator | ✅ | hf39 |
| NEW | **Hyprbars integration** | ✅ | **hf52** |
| 6-18 | Window Peek, Clipboard categorize, Power Schedule, etc. | ⏸ | TBD |

**6/18 shipped + hyprbars bonus.**

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf51 sticky editor focus-loss safety
- ✅ hf50 click-through + close + widget input/drag/live-sync
- ✅ hf49 sticky drag pattern + panel-level draggable
- ✅ hf48 hyprlock unlock focus reset
- ✅ hf47 sticky notes as desktop widgets
- ✅ hf46 sticky draggable toggle foundation
- ✅ hf45 bar layout save sync + Title Translator browser fallback
- ✅ hf44 theme profiles save full state
- ✅ hf43 panel clipping + rounded toggle pills
- ✅ hf42 modules visible + usage docs

🍃 Window title bars na ngayon, color-synced, with left/right toggle. Buong window-management story complete na.
