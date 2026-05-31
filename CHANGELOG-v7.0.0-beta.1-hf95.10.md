# Zen Shell v7.0.0-beta.1-hf95.10 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**New: a matching SDDM login greeter ("Zen Tokyo") that replicates the
hyprlock screen — live blurred wallpaper, big clock in your bar's font,
Tokyo-Night colours — extended with a mouse cursor, user selector,
session selector and power controls. Ships as an opt-in, root-level
installer separate from the per-user shell install.** Wala tayong
babawasan.

---

## SDDM greeter (new, opt-in)

Added under `sddm/`:

- `zen-tokyo/Main.qml` — Qt6 greeter (`QtQuick.Effects`/`MultiEffect`
  blur). Live wallpaper blurred + darkened (mirrors hyprlock), huge
  centred clock, greeting + optional mood/care line, pill password
  input, caps-lock indicator, user-selector chips, session selector,
  power controls, visible cursor.
- `zen-tokyo/theme.conf` — Tokyo-Night palette + fonts + wallpaper +
  toggles, all identical to `hyprlock.conf` v6.16.3.2.1 and rewritable
  by the sync hook.
- `zen-tokyo/metadata.desktop` — theme metadata (QtVersion=6).
- `scripts/zen-sddm-sync.sh` — copies the live wallpaper into the theme
  dir and maps the bar `fontFamilyId` → clock/text fonts using the SAME
  mapping as `zen-lock.sh`, so the greeter matches your lock + desktop.
  Optionally exports the mood/care line.
- `zen-sddm-install.sh` — installs the theme to
  `/usr/share/sddm/themes/zen-tokyo`, writes `/etc/sddm.conf.d`, installs
  the sync hook + a polkit rule + a login refresh hook, runs a first
  sync. `--uninstall` reverts.

Why separate: SDDM is system-level and runs as the `sddm` user before
login, so it can't read `$HOME`; the greeter therefore needs a
world-readable copy of the wallpaper and a root installer. It is fully
opt-in — the per-user `install.sh` is unchanged.

### Robustness notes

- Greeter never shows a blank screen: if the wallpaper copy is missing,
  it falls back to the flat Tokyo-Night background.
- Username handling uses a delegate-bound `selectedUser` string instead
  of fragile `Qt.UserRole+N` indexing, with a single-user seed — avoids
  blank labels across SDDM/Qt versions.
- QML brace-checked; both shell scripts pass `bash -n`.

### Carried over (hf95.x)

`install.sh` smart self-heal + Workspaces clobber fix; `sync-config.sh`
verify fix; vertical MusicWidget click + hover; SysRow sticky-expand +
auto-fit; vertical Music Strings (compact, dynamic, scale-to-fit);
user-management auto-install fix.

## Version

- `ZenVersion.qml` bumped `hf95.9` → `hf95.10`.

## Files touched / added

- NEW `sddm/` (theme + installer + sync hook + README)
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
