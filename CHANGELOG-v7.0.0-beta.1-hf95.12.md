# Zen Shell v7.0.0-beta.1-hf95.12 — Karui (軽い)

Release date: 2026-05-31
Channel: beta · Codename: Karui (軽い)

**Six fixes in one: music left-click works again, new users get a full
zen-shell on creation, the SDDM greeter clock matches the widget font and
shows the start-menu avatar, SDDM stays optional, and there's a Settings
page to toggle the login theme + pick its background.** Wala tayong
babawasan.

---

## 1. Music left-click now pauses/plays (real root cause)

Whenever Music Strings are enabled, the bar shows `MusicStrings.qml` —
not `MusicWidget.qml`. `MusicStrings`' MouseArea was `Qt.NoButton`
(hover-only), so left-click did nothing on both bars. It now accepts
clicks and drives playback via `playerctl`:

- Left → play/pause · Right → next · Middle → previous

State refreshes immediately after a click instead of waiting for the 2s
poll. (`MusicWidget`'s own click path from hf95.3 is unchanged for the
strings-disabled case.)

## 2. Creating a user now installs a COMPLETE zen-shell

`createUser`'s dotfile clone was missing key directories, so the new
account booted half-themed. `CLONE_DIRS` now covers the full desktop:
adds `.config/hypr-control-center` (the THEME / current-theme.json —
without it the new user had no scheme), `.config/alacritty`,
`.config/fuzzel`, `.config/gtk-3.0`, `.config/gtk-4.0`, and
`.local/share/zen-shell`. The shell autostarts via the cloned
`autostart.conf` (`exec-once = quickshell -p ~/.config/quickshell/zen-shell`),
so the new user logs straight into a working, identically-themed
zen-shell. (hf95.9's robust source resolution + full path-rewrite still
apply.)

## 3. SDDM greeter clock matches the widget font

The widget clock renders `family "Adwaita Sans" + weight Font.Black`. The
greeter was setting `family "Adwaita Sans Black"`, which Qt often can't
resolve as a family → silent fallback to a default font. Main.qml now
strips the trailing weight word and applies the weight via
`font.weight`, so the greeter clock looks exactly like the widget.

## 4. SDDM greeter shows the start-menu profile image

The greeter now displays the user's avatar (the same image the start menu
uses), with a circular mask and a letter-initial fallback. It reads
SDDM's per-user `icon`, and the sync hook publishes the zen-shell custom
avatar to `/var/lib/AccountsService/icons/<user>` and
`/usr/share/sddm/faces/<user>.face.icon` so SDDM picks it up.

## 5. SDDM stays optional in install.sh

`install.sh` already never installed SDDM; it now says so explicitly and
points to the opt-in `sudo ./sddm/zen-sddm-install.sh`. Skipping it
changes nothing about the desktop install.

## 6. Settings → Login Screen (SDDM)

New settings page (`SddmLoginPage`) with:

- **Enable SDDM login theme** — master switch. Theme changes only push to
  the greeter when this is on (`ThemeService.syncSddmIfEnabled()` gates
  all three apply sites; the sync hook also checks it). Off by default.
- **Background** — choose *Use my wallpaper (blurred)* (same look as the
  lock screen) or *Use matugen colour* (solid scheme colour, no image).
- **Sync now** button.

Persisted in `settings-state.json` under `sddm.{loginEnabled,
backgroundMode}`; the sync hook reads both, and `Main.qml` renders a flat
scheme colour in matugen mode (no wallpaper/blur).

## Version

- `ZenVersion.qml` bumped `hf95.11` → `hf95.12`.

## Files touched

- `zen-shell-v5/MusicStrings.qml` — clickable playback control
- `zen-shell-v5/UserManagementService.qml` — full desktop clone
- `zen-shell-v5/ThemeService.qml` — gated SDDM themer
- `zen-shell-v5/SettingsState.qml` — sddm settings + persistence
- `zen-shell-v5/SddmLoginPage.qml` — NEW settings page
- `zen-shell-v5/ZenSettings.qml` — nav entry + page registration
- `sddm/zen-tokyo/Main.qml` — clock font, avatar, background mode
- `sddm/zen-tokyo/theme.conf` — backgroundMode key
- `sddm/scripts/zen-sddm-sync.sh` — toggles, bg mode, avatar publish
- `sddm/zen-sddm-install.sh` — force first sync
- `install.sh` — explicit optional-SDDM note
- `zen-shell-v5/ZenVersion.qml` — version string

No feature, setting, or file removed.
