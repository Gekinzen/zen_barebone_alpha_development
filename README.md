# Zen Shell v7.0.0-beta.1 — 軽い (Karui)

> **A QML-native desktop environment for Hyprland on Arch / CachyOS.**
> Panel · Control Center · Dock · Wallpaper Engine · Themes · Settings — one Quickshell process. No GTK4. No Python helpers. No Waybar.

**Channel:** beta · **Codename:** Karui (軽い, "lightweight") · **Compositor:** Hyprland ≥ 0.54 (0.55 supported)

> **Heads-up:** the v7 codename is the internal working name. It is not the
> final public codename — that's revealed when v7.0.0 stable ships. Don't
> state it as final anywhere public; the project site says "Coming soon · TBA".

---

## What's new — the headline features

This release line matured the **Dock**, added a **quick drop-down
terminal**, a themed **SDDM greeter**, and — most importantly for anyone
on a rolling Hyprland — an automatic fix for the recurring hyprpm
"Outdated headers" plugin failure.

### 🖥️ Quick drop-down terminal (Super+Shift+T)
A Yakuake/Guake-style terminal that drops in from the **top-center** of
the screen. It uses a **dedicated Alacritty instance** with its own config
at `~/.config/alacritty-quick/`, so your normal Alacritty setup is never
touched. Toggled via a Hyprland special workspace; repositions itself
correctly on the focused monitor (scale-aware).

###  Zen Tokyo SDDM greeter
A login screen that matches your desktop: big clock, user / session /
power selectors, blur, and your profile avatar. It tracks your **active
Zen theme and wallpaper** automatically. Enabling it from
**Settings → Login Screen (SDDM)** also switches your active display
manager to SDDM — safely, with the previous DM restorable from the same
toggle (takes effect next reboot).

###  Hyprbars doctor — `zen-hyprbars-doctor.sh`
If hyprbars (window title bars) won't load — "Outdated headers" or
"headers ver is not equal to running hyprland ver" — run:

```bash
zen-hyprbars-doctor.sh
```

It diagnoses and repairs in one shot: detects your Hyprland build, catches
the **pacman-upgraded-but-not-relogged-in** version skew, auto-runs
`hyprpm purge-cache` and retries, then falls back to building the plugin
from AUR against your **system headers** and loading it directly. See
`TROUBLESHOOTING-hyprbars.md`. (Confirmed working on a clean CachyOS
0.55.2 build.)

###  Dock that adapts
- **Dynamic sizing** — in fullwidth/floating, dock icons shrink to fit
  when crowded, then show scroll arrows once they hit your minimum scale
  (hybrid resize → arrows).
- **Icon size** slider (60–200%), independent of the bar.
- **Minimum icon scale** slider (55–100%) — how small icons get before
  arrows appear.
- **Monitor targeting** — show the dock on primary / all / a specific
  output (auto-detected).

###  Floating taskbar icons
Taskbar icons now float inside the bar with padding all around (like the
dock), so the window-count / workspace / minimize badges under each icon
are visible.

###  Settings & reliability polish
- **Taskbar width cap** is now a slider (was hardcoded) — control where
  the taskbar's scroll arrows kick in.
- **Reliable user creation** — User Management streams live progress and
  has a watchdog + clear error if no polkit agent is running, so it never
  looks frozen.
- **Upward-opening dropdowns** — Settings dropdowns near the window bottom
  open upward, so the list stays inside the window and clickable.

---

## Install

```bash
# from the release tarball
tar xzf zen-shell-v7.0.0-beta.1-hf95.32.tgz
cd zen-shell-v7.0.0-beta.1-hf95.32
./install.sh

# optional: themed SDDM greeter
sudo ./sddm/zen-sddm-install.sh
```

After install, reload Hyprland (`hyprctl reload`) so the new keybinds and
window rules take effect. If hyprbars doesn't load, run
`zen-hyprbars-doctor.sh`.

### Requirements
- **Arch Linux** or **CachyOS**
- **Hyprland ≥ 0.54** (0.55 supported) — `0.54+` rule syntax only
- **Quickshell ≥ 0.2.1**
- For the hyprbars doctor's AUR path: an AUR helper (`paru`/`yay`) and the
  `hyprland` package (system headers)

---

## Notes for upgraders
- Nothing was removed. Every prior toggle, module, and theme is preserved.
- The Settings window's experimental hyprbars-style title bar
  (`HyprbarsMimic`) is **disabled** by default — the native header is
  used. The component remains in the tree for a future revisit.
- Quick terminal and SDDM greeter are **opt-in** (a keybind and an
  installer/toggle respectively).

---

## Full history
See `zen-shell-v7-roadmap-consolidated.md` (§2 "hf86–hf95.32" and §8c
"New user-facing features") for the complete drop-by-drop changelog, and
`CHANGELOG-v7.0.0-beta.1-hf95.*.md` for per-hotfix detail.

---

MIT · Crafted in Antipolo, Philippines · 軽い
