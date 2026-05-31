# Zen Shell v7.0.0-beta.1-hf95.13 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Two things: the SDDM toggle now actually SWITCHES your login screen
(enable SDDM / restore the previous one), and a new Yakuake-style
drop-down Alacritty slides in from the top on Super+Shift+T — with its
own config, leaving your normal Alacritty untouched.** Wala tayong
babawasan.

---

## 1. SDDM toggle switches the display manager (bug fix)

Before, enabling "SDDM login theme" only THEMED sddm — it never changed
the active display manager, so after logout you were still on
cosmic-greeter. Now:

- `zen-sddm-install.sh` records your current DM into
  `/var/lib/zen-shell/previous-dm` and installs `zen-dm-switch.sh`
  (+ extends the polkit rule).
- The Settings toggle calls `zen-dm-switch.sh enable` (ON) →
  `systemctl enable sddm` then disables the previous DM, or
  `zen-dm-switch.sh restore` (OFF) → re-enables the previous DM then
  disables sddm.

Safety: the replacement is ALWAYS enabled before the old one is
disabled, so you can never end up with no login screen; the running
session is never stopped; the change takes effect on the next
reboot/logout. If no previous DM was recorded, `restore` leaves things
as-is rather than disabling sddm blindly.

## 2. Quick drop-down terminal (Yakuake/Guake style)

`Super+Shift+T` toggles a drop-down Alacritty that slides in from the TOP
and covers the upper ~42% of the screen.

- **Separate config**: launched with `--class zen-quickterm` and
  `~/.config/alacritty-quick/alacritty.toml`. Your normal Alacritty
  config is never read or modified.
- **Mechanism**: lives on the `special:quickterm` Hyprland workspace;
  toggling that workspace is the instant show/hide. Window rules in
  `hyprland-layer-rules.conf` pin it to the top, size it (`100% 42%`),
  round it, and animate `slide top`.
- First press spawns it; later presses toggle.
- Config is preserve-if-exists on install, so your edits survive
  upgrades.

## Version

- `ZenVersion.qml` bumped `hf95.12.1` → `hf95.13`.

## Files touched / added

- NEW `sddm/scripts/zen-dm-switch.sh` — enable/restore the active DM
- `sddm/zen-sddm-install.sh` — record previous DM, install switch helper + polkit
- `zen-shell-v5/SddmLoginPage.qml` — toggle now switches the DM
- NEW `scripts/zen-quickterm.sh` — drop-down terminal toggle
- NEW `hypr-config/alacritty-quick/alacritty.toml` — separate quick-term config
- `hypr-config/hyprland-layer-rules.conf` — zen-quickterm window rules
- `hypr-config/binds.conf` — Super+Shift+T bind
- `install.sh` — deploy zen-quickterm.sh + alacritty-quick config
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed. Your normal Alacritty and your
current login screen are both preserved (the latter restorable via the
toggle).
