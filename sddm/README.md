# Zen Tokyo — SDDM greeter (lock-screen replica)

A login greeter that mirrors your Zen Shell hyprlock screen
(`hyprlock.conf` v6.16.3.2.1): live wallpaper (blurred + darkened),
big centred clock in your bar's font, mood/care line, pill password
input, Tokyo-Night colours — plus the things a greeter needs that a
lock screen doesn't: a mouse cursor, a user selector, a session
selector, and power controls.

## Why a separate installer

SDDM runs system-wide as the `sddm` user *before* login, so it can't
read your `$HOME`. Installing it therefore needs root and lives apart
from the per-user `install.sh`. It's opt-in — run it only if you want
the matching login screen.

## Install

```bash
cd sddm
sudo ./zen-sddm-install.sh
```

This:
1. copies `zen-tokyo/` → `/usr/share/sddm/themes/zen-tokyo`
2. writes `/etc/sddm.conf.d/10-zen-tokyo.conf` (`Current=zen-tokyo`,
   a `CursorTheme` so the cursor shows)
3. installs `zen-sddm-sync.sh` → `/usr/local/bin` plus a login hook and
   a polkit rule, so the greeter wallpaper follows your live desktop
4. runs a first wallpaper/font sync

Preview without rebooting:

```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/zen-tokyo
# Qt6 builds: sddm-greeter-qt6 --test-mode --theme …
```

Uninstall (restores your previous greeter):

```bash
sudo ./zen-sddm-install.sh --uninstall
```

## How it tracks your desktop (same idea as the lock screen)

- **Wallpaper** — `zen-sddm-sync.sh` reads `.currentWallpaper` from
  `wallpaper-v5.json` (exactly like `zen-lock.sh`) and *copies* it into
  the theme's `backgrounds/` (a copy, not a symlink, because sddm can't
  follow a link into your home). The QML blurs + darkens it at display
  time, matching hyprlock's live blur.
- **Fonts** — the same `fontFamilyId → font` mapping `zen-lock.sh`
  uses, written into `theme.conf` (`clockFont` / `textFont`). So the
  greeter clock uses the same font as your lock + bar.
- **Colours** — Tokyo-Night defaults in `theme.conf`, identical to
  `hyprlock.conf`. A future release can regenerate them from the active
  scheme (same note as in `hyprlock.conf`).

The sync runs at login (profile hook); you can also trigger it on
wallpaper change. Everything it writes is confined to the theme dir —
it never touches your `$HOME`.

## Files

```
sddm/
  zen-sddm-install.sh        installer (root)
  zen-tokyo/
    metadata.desktop         theme metadata (QtVersion=6)
    theme.conf               colours / fonts / wallpaper / toggles
    Main.qml                 the greeter
    backgrounds/             live wallpaper copied here by the sync
  scripts/
    zen-sddm-sync.sh         wallpaper + font + mood sync (root)
```

## Notes / tuning

- **Qt version**: `Main.qml` targets Qt6 (`QtQuick.Effects` /
  `MultiEffect`, Qt 6.5+, which current Arch/CachyOS ships). If your
  sddm is Qt5, the blur import differs (`QtGraphicalEffects` +
  `FastBlur`) — ping me and I'll add a Qt5 variant.
- **Colours from scheme**: right now `theme.conf` holds fixed
  Tokyo-Night values. When you want them auto-generated from the active
  Zen scheme (like matugen does for the rest), that's a follow-up.
- **Mood/care line**: optional; populated from `zen-lock-message.sh`
  into `mood-care.txt`. Empty file → the line is simply hidden.

Wala tayong binawasan — this is all additive, separate from the shell.
