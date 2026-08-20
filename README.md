# Zen Shell · ZenithArch-shell-qml

> **A QML-native desktop environment for Hyprland on Arch / CachyOS.**
> Panel · Control Center · Wallpaper Engine · Themes · Settings · Lock screen · Dock · Taskbar · Native notifications — unified in a single Quickshell process.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg" alt="Zen Shell desktop preview" width="100%" />
</p>

<p align="center">
  <img alt="v8" src="https://img.shields.io/badge/v8-Kaizen%20Akatsuki-e87554?style=flat-square&labelColor=14140f" />
  <img alt="status" src="https://img.shields.io/badge/status-alpha%20·%20hf202-c68a4a?style=flat-square&labelColor=14140f" />
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v7.0.0-beta.1"><img alt="stable" src="https://img.shields.io/badge/stable-v7.0.0--beta.1%20Karui-7A9068?style=flat-square&labelColor=14140f" /></a>
  <img alt="hyprland" src="https://img.shields.io/badge/hyprland-≥%200.54-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="quickshell" src="https://img.shields.io/badge/quickshell-≥%200.2.1-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="license" src="https://img.shields.io/badge/license-MIT-b8924e?style=flat-square&labelColor=14140f" />
</p>

<p align="center">
  <a href="https://zenithshell.dev/"><b>zenithshell.dev</b></a>
</p>

---

## 改善暁 · Kaizen Akatsuki — version 8

**ZenithArch-shell-qml** is the name version 8 ships under: the peak (*zenith*) of the
Arch-native QML shell that started as a Waybar-and-Python proof of concept five codenames ago.

Its codename is a pair, because the release is a pair.

**Kaizen (改善)** — *"change for the better"*, the practice of small relentless improvements
rather than one grand rewrite. That is honestly what version 8 is: **103 hotfixes** from `hf100`
to `hf202`, each one a real bug found and closed or a real feature finished, shipped in sequence
with the reasoning written down. Nothing here was planned as a release. It became one.

**Akatsuki (暁)** — *"dawn / daybreak"*. What relentless improvement arrives at.

> **Current build: `v8.1.0-alpha-hf202`.** The stable line remains **v7.0.0-beta.1 (Karui)**.
> Nothing from v6 or v7 is removed — version 8 only adds on top.

### The Look system — Glass, Glass+, and readable text

The largest single thread in the line. Frosted surfaces everywhere, and then the much harder
problem of keeping text legible **on top of** frost sitting over an arbitrary wallpaper.

- **Five glassiness levels** with one surface rule shared by every panel, popup, menu and sheet — `LookService.surfaceColor()` is the single place glass is decided.
- **Glass+ adaptive text** — samples the wallpaper's luminance behind each surface and flips text between light and dark, with a matching outline, so a bright wallpaper never eats the label.
- **Frost that survives** a settings apply, a `hyprctl reload`, and a login — three separate ways it used to silently wash out.
- **Frosted everywhere**: notification panel, menus, clock, title bars, fuzzel, start menu, dropdowns, the Control Center itself.
- **Sakura theme** joins the built-in set.

### Lock screen

- Wears your **current wallpaper**, blurred, instead of a separate image that drifts out of sync.
- **Time-of-day awareness** — the greeting and its emoji follow both the clock and the live weather.
- **Weather survives offline** — the last good reading is kept rather than blanking.
- **Random lock message** per lock, drawn properly with `shuf -e`.
- Clickable **Shutdown / Restart** pills, theme-synced accents.

### Appearance and theming

- **Cursor theme picker** promoted to its own page under Appearance, scanning `.icons`, `.themes`, `.cursor` and `/usr/share`, detecting **hyprcursor** themes as well as XCursor — and the chosen cursor survives a relogin **from the very first frame**.
- **GTK icon theme picker** built in, so there is no detour through GTK settings.
- **Wallpaper page** with fuzzy search and auto-load on open.
- **Dropdowns** that follow their sheet instead of drifting, with text that picks its own colour on an opaque surface.
- **Densho (伝承) mode** — a full traditional-Japanese identity: kanji workspace labels, a vertical kanji date column, a seasonal kanji tracking the 24 solar terms, brush-stroke bar separators, and **34 module kanji plus 6 category kanji in the Control Center sidebar** with romaji tails, plus the written 禅 mark on the brand badge.

### Dock, Taskbar and the bar

- A matured **Dock** with context menus, `SUPER+D`, floating icons, and a proper **dock plate** background.
- A **Taskbar** page and module.
- **The centre bar zone now actually stays centred.** It was a `RowLayout` with two `fillWidth` spacers, which averages rather than centres: the centre sat `(left − right) / 2` away from the middle, so adding one icon on the left slid it by half that icon. On a 1920 bar that was up to **450px off**. Both bars are now anchor-positioned — each zone against the bar, never against its neighbours — with a symmetric budget and a clipping slot, so the centre **narrows evenly instead of sliding away** when the sides grow. The vertical bar had the identical bug rotated 90 degrees, and got the same fix.
- **System tray** spacing fixed in two places for two different reasons: an en-space in the bar's own formatter, and a real icon slot on `SettingRow` for the settings page — because padding a string with spaces cannot fix a gap made of mixed fallback-font advance widths.
- **Volume OSD clears the dock**, not just the bar — one rule that holds whichever edge either is on.

### Networking

An extended debugging arc that ended somewhere quite different from where it started. The wrong
turns are documented because they are the useful part.

- **Connected-state detection rebuilt.** The original test was `parts[0] === "yes"` against `nmcli`'s IN-USE column — which on NetworkManager 1.40+ prints `*`, never `yes`. One line, three symptoms: the panel offered "Connect" on the network you were already joined to, the bar glyph fell through to the ethernet/disconnected icon, and Saved Networks never highlighted.
- **Three independent sources, ORed rather than chained** — `iw dev link` (the card), `nmcli device show` (the device), `nmcli connection show --active` (the profile). An early version gated the last two on the first being absent, which turned three sources into one and made a healthy connection report "Not connected".
- **One row per network** — a router broadcasting on 2.4 and 5GHz returns several BSSIDs; they fold into one row with an `N AP` hint, keeping the radio you are actually associated to.
- **`_nmSplit`** — `nmcli -t` escapes literal colons as `\:`, so a plain `split(":")` silently shifted every field for any SSID containing one.
- **The Wi-Fi Keeper** — remembers the network you were genuinely connected to and rejoins it with 5s to 60s backoff, capped at six attempts; clears NetworkManager's invisible autoconnect block before each retry; **stops immediately and asks when a password is the problem**, because retrying cannot supply one; and stands down entirely when you disconnect on purpose.
- **Wrong password is now distinguishable from missing password.** `nmcli` reports both as "Secrets were required", which is why this took a night: a stored-but-rejected key looks identical to no key at all. The supplicant knows the difference and says `WRONG_KEY`, so that is what gets checked.
- **The password you type is the password that gets stored.** A failed attempt leaves the wrong key saved in the profile; `nmcli device wifi connect` then reuses that profile and discards what you typed. The key is written straight in with `connection modify … psk … psk-flags 0`.
- **`zen-wifi-doctor.sh`** — read-only. Reports which of the three detection sources disagrees with reality, and with `--why`: adapter and bus, driver provenance (in-tree versus DKMS), USB autosuspend, power saving, the full profile, `psk-flags` reachability, NetworkManager's journal, the kernel log, regulatory domain, and access-point band-steering analysis.
- **`zen-wifi-watch.sh`** — read-only. Watches live and records the drop **at the moment it happens**, because the reason a reconnect fails is not the reason the link dropped, and reconstructing after the fact had already produced one wrong diagnosis.
- **GTK Wi-Fi selector** reachable from the bar icon, the Network Pulse module, and the dashboard rail.

### Input and system

- **Keyboard-independent media keys.** A bind written as `code:60` names a physical matrix position, so it lands somewhere else on a different keyboard. Keysym binds name the *meaning* and survive the swap. Ships as a self-installing drop-in — the installer copies it and adds the `source` line idempotently.
- Every new bind was **diffed against every bind Zen Shell already ships** before being made active, which caught one that would have silently stolen the dashboard shortcut.
- **EasyEffects autostart**, Bluetooth and audio manager launchers with proper toggle semantics.
- **Panic recovery**, game-mode warnings, "Reset all to defaults" covering focus settings, and a Lark/Zoom call-popup fix.

### Installer — everything lands, and your settings survive

The least glamorous thread in version 8, and the one that was quietly costing the most.

The installer was copying the **wrong source tree**. This drop ships both `zen-shell/`
(201 modules, v8.1.0) and the legacy `zen-shell-v5/` (179 modules, v7.0.0), and the install
body hardcoded the legacy path. Every install laid down the v7 tree and printed a v8 banner,
so twenty-one v8-only modules never landed — `LookService` (the whole Look and Glass system),
`ZenDashboard` and `UnifiedDashboard` (the Control Center), `ZenGlanceWidget`, the cursor
picker, the Panasonic pages, the Taskbar page. The self-check at the end of the install had
been reporting two of them missing for releases.

Separately, every copy step worked off a hardcoded list of filenames. That is correct
right up until a file is added to the tarball and nobody remembers to also edit the
installer — after which the file ships and silently never installs. Eleven of them had
piled up, including `zen-boost-guard.sh` and `zen-callwatch.sh`, so the 300% Boost Guard
and the `SUPER+SHIFT+C` call reaper did not exist on disk after a clean install, while the
QML called them by absolute path. `sakura` was a headline v8 theme that no installed shell
had ever had.

- **Payload sweep** walks directories instead of lists, so new files land on their own.
- **Coverage audit** runs at the end and names anything shipped that did not land, which
  turns the next gap of this kind into a line of output instead of a silent absence.
- **Settings deep-merge** — your `*.json` are snapshotted before migrations and merged back
  key by key afterwards. Your values win, new keys from the build get added. A straight
  restore would have protected your settings by discarding new features; a straight
  migration does the reverse. This does neither.
- **Byte-compare before write** — two installs back to back now write nothing.
- **Line endings normalised on the way in**, so an archive round trip can no longer ship a
  script the kernel refuses to run.
- **Brand, site and version are read from one place** — the version comes out of
  `ZenVersion.qml`, so the banner cannot drift from the shell again.

### Still to land before version 8 is tagged

- **A real NetworkManager secret agent.** Zen Shell registers none, which is why an agent-owned PSK can never authenticate under Hyprland. A proper agent covers WPA-Enterprise, VPN secrets and requests from other applications — not just the one case patched around so far.
- **WPA-Enterprise (802.1X)** — multi-field form: identity, EAP method, CA certificate.
- **"Connect automatically" per network** in the in-shell prompt.
- **Confirm dialogs** for destructive actions — forget network, unpair device.
- **Bluetooth audio sink routing** — one tap to move audio to a paired device via `wpctl`.
- **ZenCleanupService** — RAM reclaim and zombie reaping.
- **QML lazy-load pass** — the last leg of the Karui performance trio.
- **Plugin system v2** — signed manifests, per-plugin QML sandboxing, a community registry.
- **Panasonic wheel pad validated on real hardware.** The geometry engine is unit-tested off-hardware; the evdev half has never met an actual wheel pad.

### Download

| Build | Channel | State |
|---|---|---|
| **ZenithArch-shell-qml** | tag `v8.0.0` | **Coming soon** — not tagged yet |
| **Version 8 alpha** | `main` · hf202 | Rolling, untagged |
| **Karui** | tag `v7.0.0-beta.1` | Available — recommended |

> **ZenithArch-shell-qml has not been tagged yet.** Watch the repository for the first `v8` tag.

```bash
# Coming soon
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development
git checkout v8.0.0          # not published yet
./install.sh
```

Until then:

```bash
git checkout v7.0.0-beta.1   # stable — Karui
git checkout main            # version 8 alpha — Kaizen Akatsuki
```

---

## The shipped line — v6 Modori and v7 Karui

The two official lines version 8 builds on. Both remain runnable; v7 is the recommended stable.

### Karui (軽い) — v7.0.0-beta.1 · *lightweight*

**Performance trio — `LaptopModeService`.** Three modes (Off / Balanced / Endurance) drive
adaptive polling across the existing services. System monitor stretches 2s to 5–30s by mode and
battery level; weather refresh is suppressed under the low-battery threshold; the audio rope falls
back to static when critical; the CPU governor switches to power-saver on battery in Endurance; an
optional sub-toggle pushes minimal Hyprland animations and restores them when plugged in. Optional
80% charge limit where the kernel exposes `charge_control_end_threshold`. Auto-hides on desktops,
with a manual override.

**Lock screen.** Music-string alignment self-heals after lock and login via a
screen-width-independent island width; hyprlock power pills; time-aware greeting with a
weather-matched emoji; theme-synced accents on every lock.

**Notifications.** The native `NotificationServer` reliably owns
`org.freedesktop.Notifications` in Zen mode, stopping and disabling **swaync, mako and dunst**
rather than only swaync. SwayNC fallback mode unchanged.

**Base.** Matured Dock, `SUPER+SHIFT+T` drop-down terminal, Zen Tokyo SDDM greeter,
`zen-hyprbars-doctor.sh` for the recurring hyprpm "Outdated headers" failure, and the Tategaki
redux vertical bar.

### Modori (戻り) — v6.16.4.12.9.10 · *to return*

After the Tategaki vertical-bar attempt hit three startup-blocking parser errors, the bar was
rolled back to the proven Tachiagari `.7.1` base. Modori is what was rebuilt on top, bundling
patch levels `.10`, `.11` and `.12`.

- **Smart-contrast theme engine** — every theme runs a luminance check and nudges unreadable foregrounds toward WCAG 4.5:1. Custom themes get the same protection on import.
- **In-shell Wi-Fi password prompt** at `WlrLayer.Overlay`, replacing the zenity prompt that hid behind the Control Panel.
- **Redesigned Wi-Fi and Bluetooth panels** — saved and available split, 44px tap targets, scan toggle, pair flow.
- **GTK Dark Mode toggle** — atomic sync of `gsettings` plus GTK3/4 `settings.ini` plus libadwaita.
- **Modori Dark / Light** themes and paired procedural wallpapers — an imperfect ensō with a persimmon dot, and a faint 戻 watermark.
- **Persimmon accent** `#e87554` throughout.
- Debounced 200ms settings save, so rapid slider drags stop corrupting `panel-state.json`.

| Patch | What it fixes |
|---|---|
| `.10` | Modori baseline |
| `.11` | Wi-Fi route-metric preference, `preventStealing` on row taps, open-network parser fix, action exit refresh |
| `.12` | One-line restore of a recursive helper that was silently breaking every Wi-Fi, Bluetooth and audio toggle |

---

---

## Hardware support — ongoing

Zen Shell targets Arch and CachyOS generally, but two laptop families get dedicated work because
their signature hardware does not work out of the box under Wayland. **Both are in active
development, not finished.** What each one honestly is right now:

### Panasonic Let's Note — shipping, wheel pad awaiting hardware validation

The round **wheel pad** is the reason this exists. libinput implements exactly three scroll
methods — two-finger, edge, on-button — and circular is not one of them. The ArchWiki pages for
the **CF-SV9** and **CF-SV1** both state plainly that circular scrolling is unavailable under
Wayland; it works under Xorg only, via `xf86-input-synaptics`. Hyprland is Wayland-only, so it
has to be synthesised rather than configured.

**In the tree today:**

| Piece | State |
|---|---|
| `PanasonicService.qml` · `PanasonicPage.qml` | Shipping. Hardware-gated by DMI — on anything else the page does not exist and nothing polls. |
| `zen-wheelpad.py` | Shipping, **not yet validated on real hardware.** |
| `zen-panasonic-setup.sh` | Shipping. Hyprland tuning, udev rule, systemd unit, `panasonic-laptop` checks. |
| ECO battery limit · sticky keys | Shipping, via `/sys/devices/platform/panasonic`. |

**How the wheel pad works.** The daemon grabs the touchpad with `EVIOCGRAB`, republishes it as a
uinput clone with identical capabilities so libinput keeps handling pointer acceleration, tap and
gestures exactly as before, and converts angular travel around the outer ring into scroll events.
The clone is the whole point: a daemon that only *watched* the pad could emit scroll but could not
suppress the pointer motion happening at the same time, so circling would scroll *and* drag the
cursor. If the daemon dies, is killed or crashes, the kernel drops the grab automatically — worst
case you lose circular scroll, never the pointer.

Tunable ring width, sensitivity, engage threshold and direction, with a live ring preview in the
settings page. The geometry engine is unit-tested off-hardware across eleven scenarios — full
circle both directions, finger in the middle never engaging, two fingers left to libinput, short
edge flicks not engaging, spiralling inward disengaging, the ±180° seam not producing a click
burst.

**What is not done.** The evdev half has never met an actual wheel pad. Start with
`python3 zen-wheelpad.py --dry-run`, which grabs nothing and just prints its decisions.

Detection covers **CF-SV / SZ / LX / NX / RZ / QV / FV / SR** and the **Toughbook FZ** line, by DMI
and by touchpad capability rather than a model table — so an untested model still works.

*Reports from any Let's Note are wanted, especially the older round-pad models.*

### ThinkPad — in development

Nothing has shipped yet. This is the planned scope, listed so it is clear what is and is not
promised:

- **TrackPoint** — sensitivity and speed as first-class settings, and middle-button scroll wired properly (libinput's `on-button` scroll method with the middle button, which Hyprland supports but which nothing in Zen Shell currently configures).
- **Battery charge thresholds** — start and stop, via `charge_control_start_threshold` and `charge_control_end_threshold`. The 80% limit already exists for Panasonic; ThinkPad exposes both ends.
- **Keyboard backlight** — `/sys/class/leds/tpacpi::kbd_backlight`, with its two levels surfaced as a real control rather than a keybind you have to remember.
- **Fan control and thermals** — read-only reporting first, from `/proc/acpi/ibm/fan`. Anything that writes to it is opt-in and clearly labelled, because a wrong value there is a hardware risk, not a cosmetic one.
- **Dock and hotkey events** — undock, ThinkVantage and the Fn-layer keys through `thinkpad_acpi`.
- **A ThinkPad settings page**, hardware-gated the same way the Panasonic one is: absent entirely on other machines.

The Panasonic work established the pattern — DMI detection, a gated page, sysfs bridged through a
service, helper processes only where QML genuinely cannot reach — so ThinkPad support is mostly a
matter of filling that shape in rather than inventing it.

*If you run a ThinkPad and want a say in what lands first, open an issue.*

## Install

Two ways in. Both end at the same `install.sh`.

**From a release tarball**

```bash
tar -xzf ZenithArch-shell-qml-v8.1.0-alpha-hf202.tar.gz
cd ZenithArch-shell-qml-v8.1.0-alpha-hf202
./install.sh --version          # confirm what you are about to install
./install.sh
```

**From the repository**

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git checkout main               # version 8 alpha (Kaizen Akatsuki)
# git checkout v7.0.0-beta.1    # stable (Karui)

./install.sh
```

`./install.sh` on its own is the right command in almost every case. It looks at what
is already on the machine and decides for itself whether a bootstrap is needed, so
there is no separate "first time" command to remember.

### What it actually does

| Step | What happens |
|---|---|
| `[0/9]` | Version pin check against `versions.lock` — patch bumps pass silently, a major/minor mismatch warns or blocks |
| `[0.5/9]` | Hardware detection — GPU topology, DRM render nodes, session type, display manager, monitors, chassis |
| `[1/9]` | Dependency check, and offers to install anything optional that is missing |
| `[2/9]` | Backup of your existing install |
| `[3/9]` | Directory setup |
| `[4/9]` | QML install, compiled-QML cache clear, stale-module prune, vertical-bar self-heal |
| `[5/9]` | Helper scripts and the monitor watcher unit |
| `[5.5/9]` | **Payload sweep** — walks the tarball directories and installs everything in them |
| `[5.9/9]` | Reads your existing settings and reports what will be preserved |
| `[6/9]` | Hyprland configs and drop-ins, sourced into `hyprland.conf` idempotently |
| `[7/9]` | Themes |
| `[8/9]` | First-run tasks, QML smoke test, Hyprland plugin install |
| `[9/9]` | Kills every running zen-shell instance and spawns exactly one |
| `[9.9/9]` | **Coverage audit** — names anything shipped that has no counterpart on disk |

### Flags

| Flag | Effect |
|---|---|
| *(none)* | The smart default. Auto-detects whether bootstrap is needed. |
| `--bootstrap` / `-b` | Force `bootstrap.sh` to run first, reinstalling system dependencies even if present. |
| `--no-bootstrap` | Skip the check entirely. For people who manage their own Hyprland / Quickshell. |
| `--version` / `-V` | Print the version this drop installs, then exit. Writes nothing. |
| `--help` / `-h` | Usage. |

### Environment overrides

| Variable | Effect |
|---|---|
| `ZEN_NO_MERGE=1` | Skip the settings deep-merge. Your `*.json` are then left exactly as the migrations produced them. |
| `ZEN_ALLOW_PROFILE_MIGRATE=1` | Drop the verbatim guard on `panel-state.json` and `bar-layout.json` and take the new default layout. |
| `ZEN_FORCE_THEMES=1` | Overwrite built-in themes you have edited (a `.bak` is still kept). |
| `ZEN_FORCE_VERSIONS=1` | Ignore the `versions.lock` pins. |
| `ZEN_BOOST_INTENSITY` / `ZEN_BOOST_LIMIT_DB` | Tune the Boost Guard compressor and limiter. |

### Reinstalling and upgrading

Re-running `./install.sh` is safe and is the supported upgrade path. Since `hf202`:

- **Your `*.json` settings are never overwritten.** Every state file is snapshotted before
  the migrations run and merged back after, key by key. Your values win; only genuinely
  new keys from the new build are added. So an upgrade gains features without resetting
  anything you configured.
- **`panel-state.json` and `bar-layout.json`** get a stricter guard on top: they come back
  byte for byte, and any copy a migration produced is kept beside them as `.migrated-<ts>`.
- **Only files whose bytes actually changed are written.** Two runs back to back write
  nothing at all — no churn, no `.bak` spam.
- **Themes and Look presets you have edited are yours.** The shipped copy is parked next to
  yours as `<name>.json.new` instead of replacing it.

Nothing is ever deleted to make room. Every replaced file leaves a `.bak-<timestamp>`
next to it, and a per-run manifest of everything touched is written to
`~/.cache/zen-shell/installed-manifest-<timestamp>.txt`.

### Where things land

| Path | Contents |
|---|---|
| `~/.config/quickshell/zen-shell/` | QML, your `*.json` state, `scripts/`, `looks/`, `config/`, `assets/` |
| `~/.local/bin/` | Helper scripts and toggles |
| `~/.config/hypr/` | Hyprland configs and Zen drop-ins |
| `~/.config/hypr-control-center/themes/` | `builtin/` and `custom/` themes |
| `~/.config/zen-shell/wallpapers/` | Built-in wallpapers |
| `~/.local/share/zen-shell/snapshots/` | Rollback snapshots |
| `~/.cache/zen-shell/` | Install manifests and logs |

### After installing

```bash
./install.sh --version                 # what is installed
systemctl --user status zen-monitor-watcher
zen-hyprlock-doctor                    # inventory your lock screen setup
```

If the coverage audit at the end names any file, that file ships in the tarball but did
not land anywhere. Report it — it is a packaging bug, not something you need to work
around. The audit is a report only and never aborts the install.

### Optional, opt-in extras

```bash
sudo ./sddm/zen-sddm-install.sh        # SDDM theme (needs root)
```

`hypr-config/zen-multimonitor.conf` is seeded to `~/.config/hypr/` but deliberately not
sourced, because monitor rules are hardware specific. Read it, then add:

```
source = ~/.config/hypr/zen-multimonitor.conf
```

### Rolling back

Every install snapshots the previous one.

```bash
ls ~/.local/share/zen-shell/snapshots/
~/.config/quickshell/zen-shell/scripts/zen-rollback.sh <snapshot-path>
```

`zen-rollback.sh` takes a safety snapshot of the current install first, stages the restore
in a temp directory, and swaps atomically — a failure at any step reverts. Scripts are
snapshotted alongside the QML so script versions stay matched to QML versions across a
rollback boundary.

### Requirements

- **Arch Linux** or **CachyOS** — other distributions may work but are not tested
- **Hyprland ≥ 0.54** (0.55 supported) — `0.54+` syntax only
- **Quickshell ≥ 0.2.1**
- AMD Ryzen and Radeon recommended — developed on `Ryzen 9 5950X` and `RX 6800`

`install.sh` auto-detects and offers to install the rest: grim, slurp, wl-copy, swww, cava,
playerctl, jq, notify-send, and `swh-plugins` for the Boost Guard.

### Optional

Two features ship as separate helper processes rather than QML, because they need kernel
interfaces QML has no access to:

| Feature | Needs |
|---|---|
| GTK Wi-Fi selector | `python-gobject` `gtk4` `libadwaita` |
| Panasonic wheel pad | `python-evdev`, membership of `input`, write access to `/dev/uinput` |
| Wi-Fi diagnostics | `iw` (optional — two other detection sources work without it) |

Both are **opt-in and inert when absent** — nothing in the shell depends on them, and the Wi-Fi
selector falls back to `nm-connection-editor` and then `nmtui`.

### If a script will not run

If you unpacked from an archive that rewrote line endings and a helper fails with

```
bad interpreter: /usr/bin/env bash^M: no such file or directory
```

the installer already normalises line endings on the way in, so a reinstall fixes the
installed copies. To fix the source tree as well:

```bash
find scripts hypr-config themes-builtin -type f -exec sed -i 's/\r$//' {} +
```

---

## Architecture

- **[Quickshell](https://quickshell.outfoxxed.me/)** — QML-native shell framework for Wayland
- **QML / Qt 6** — declarative interface, fragment shaders for circular masking, custom delegates
- **Hyprland 0.54+** — the only supported compositor
- **Custom singletons** for state — `PanelState`, `ThemeService`, `LookService`, `WallpaperState`, `ConnectivityService`, `NotificationService`, `DockState`, `DenshoService`, `PanasonicService`, `ZenStringsState`

### Key design rules

Hard-won, most of them from a bug that took hours to find.

- Hyprland 0.54+ syntax **only**. No `windowrulev2`, no block-style `layerrule {}`.
- Singletons for state — never `Component.onCompleted: somethingGlobal = x`.
- **Centre with anchors, never with spacers.** Two `fillWidth` spacers average; they do not centre.
- **`anchors.fill` sets width AND height.** An explicit `height` alongside it loses, silently — that is how a MouseArea covered a whole row and made a button unclickable.
- **Positional parallel tables must be appended to, never inserted into.** `navItems` and `navCatFor` are index-matched, and a page Loader keys off the number.
- **A QML signal's `.length` is its argument count, not its connection count.** Gate optional behaviour on an explicit boolean.
- **Converting a Layout to an Item loses `implicitWidth` and `implicitHeight`.** Anything bound to them silently reads zero.
- `parent.parent.width` is unreliable inside `Flickable` or `ScrollView` — keep a reference to the outer item.
- Overlay `Rectangle`s must be **siblings**, not children, of layouts.
- `hyprctl reload` wipes runtime keyword state — re-apply anything set via `hyprctl keyword`.
- Layer-shell windows always report `win.x = 0`; reconstruct screen-X from `panelMode`.
- **`pkill -x`, never `pkill -f`** in a toggle — `-f` matches the whole command line and will kill the shell command issuing it.

---

## Lineage

Every era is preserved.

```
Wakaba (若葉)            Alpha v0.91          · Genesis · bare Waybar + Python
Koke   (苔)              Alpha v2.x           · Legacy · GTK4 / Libadwaita era
Yugen  (幽玄)            v6.10 → v6.14        · Rewrite · GTK → Quickshell QML
Ensō   (円相)            v6.15.x → v6.16      · Unified · the circle closes
Ma     (間)              v6.16.1.x            · Refinement · cascade Control Panel
Shibui (渋い)            v6.16.2.3.x          · Refinement · click-through fixes
Sabi   (寂)              v6.16.3.x            · Refinement · Lock screen, PowerBadge
Kintsugi (金継ぎ)        v6.16.4.x → .11.2    · Stable predecessor · gold in seams
Hikari  (光)             v6.16.4.12.5 → .6.53 · Interlude · illumination + plugins
Tsubasa (翼)             v6.16.4.12.6.40      · Interlude · Hyprland plugin manager
Hiraki  (開き)           v6.16.4.12.6.52-.53  · Interlude · click-to-open triggers
Tachiagari (立ち上がり)   v6.16.4.12.7 → .7.1  · Interlude · the proven base
Tategaki (縦書き)        v6.16.4.12.8.x       · ROLLED BACK · vertical-bar attempt
Modori (戻り)            v6.16.4.12.9.10      · OFFICIAL v6
Karui  (軽い)            v7.0.0-beta.1        · OFFICIAL v7
Kaizen Akatsuki (改善暁)  ZenithArch-shell-qml · VERSION 8 · alpha hf100 → hf202
```

**Hoshi (星)** — *"star"* — stays reserved as a future milestone name.

## Codename history

| Codename | Kanji | Meaning | Versions |
|---|---|---|---|
| Wakaba | 若葉 | Young leaf | Alpha v0.91 — Waybar, Python, rofi |
| Koke | 苔 | Moss | Alpha v2.x — GTK4 / Libadwaita era |
| Yugen | 幽玄 | Subtle profound grace | v6.10 – v6.14 — QML rewrite |
| Ensō | 円相 | The zen circle | v6.15.x · v6.16 base |
| Ma | 間 | The space between | v6.16.1.x |
| Shibui | 渋い | Understated refinement | v6.16.2.3.x |
| Sabi | 寂 | Beauty of age and patina | v6.16.3.x |
| Kintsugi | 金継ぎ | Golden repair | v6.16.4.x · v6.16.4.11.2 |
| Hikari | 光 | Light — illumination | v6.16.4.12.5 – .6.53 |
| Tsubasa | 翼 | Wings and plumage | v6.16.4.12.6.40 |
| Hiraki | 開き | Opening | v6.16.4.12.6.52 – .53 |
| Tachiagari | 立ち上がり | Rising up | v6.16.4.12.7 – .7.1 |
| Tategaki | 縦書き | Vertical writing — rolled back | v6.16.4.12.8.x |
| **Modori** | **戻り** | **To return — v6 stable** | **v6.16.4.12.9.10** |
| **Karui** | **軽い** | **Lightweight — v7 stable** | **v7.0.0-beta.1** |
| **Kaizen Akatsuki** | **改善暁** | **Continuous improvement, and the dawn it arrives at** | **Version 8 · ZenithArch-shell-qml** |
| Hoshi | 星 | Star — reserved | — |

---

## Branch naming

- **v6 official:** tag `v6.16.4.12.9.10` (Modori)
- **v7 official:** tag `v7.0.0-beta.1` (Karui)
- **Version 8 alpha:** `main` — `v8.1.0-alpha-hfNNN` (Kaizen Akatsuki)
- **Version 8 release:** tag `v8.0.0` — ZenithArch-shell-qml · not yet published

---

## Project archive

> From sprout to lacquered bowl to relentless refinement. Zen Shell began as *Zen Barebone Alpha* —
> a bare Waybar and Python concept on Hyprland 0.52.

### Wakaba (若葉) — *the first sprout* · Alpha v0.91

Bare Waybar, Python helpers, `rofi` for launching, on **Hyprland 0.52**. No QML, no Quickshell.
Proof that a cohesive desktop could be built on Hyprland with shell scripts and config.

### Koke (苔) — *moss grows steady* · Alpha v2.x

The full **Python / GTK4 / Libadwaita** era. Custom GTK control center, dock, unified theme
engine, desktop widgets, smart start menu, 13+ themes.

| | | |
|---|---|---|
| ![Main demo](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif) | ![Theme switching](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif) | ![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif) |
| **Main demo** | **Theme switching** | **Wallpaper picker** |
| ![Panel modes](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif) | ![Desktop looks](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png) | ![Dock](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png) |
| **Panel modes** | **Desktop looks** | **Dock and taskbar** |

> [Browse the full Koke archive](https://github.com/Gekinzen/images-demo/tree/main/zen_demo_old_archive_2025)

### Yugen (幽玄) — *subtle, profound grace* · v6.10 → v6.14

The QML rewrite cycle. GTK4 gradually replaced with Quickshell-native QML.

[v6.14 demo](https://www.youtube.com/watch?v=YQxrh5_naMQ) · [v6.10 foundations](https://www.youtube.com/watch?v=ao89J3DEqiA)

### Ensō (円相) — *the circle closes* · v6.15.x

Full Quickshell-native stack. Bar, Start Menu, Control Panel, Settings, theme engine, wallpaper
manager, music strings, screenshot ropes, avatar system, island mode, system tray — all QML.

[Full v6.15.x tour](https://www.youtube.com/watch?v=dNwGRBhA97g)

| | | |
|---|---|---|
| ![Desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png) | ![Workspace](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png) | ![Settings](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png) |
| **Desktop** | **Workspace and island mode** | **Settings page** |

### Ma · Shibui · Sabi — v6.16.1 → v6.16.3

Cascade Control Panel and two-column layouts; click-through mask fixes and `OpacityMask` avatar;
Material power icons, lock screen overhaul, PowerBadge, weather mood, widget scale.

### Kintsugi (金継ぎ) — *gold in the seams* · v6.16.4.x

The stable predecessor to Modori. Panic Recovery keybind, 11 alpha iterations in two days, widget
scale awareness, Dark Mode toggle, Wi-Fi Connect rewrite, the colour picker that took four
attempts, Material dropdown with WCAG luminance contrast, PaletteBox. **The Kintsugi themes still
ship.**

| | |
|---|---|
| ![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_01_wallpaper_picker.gif) | ![Animation presets](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_02_animations_dropdown.gif) |
| **Wallpaper engine** (Super+W) | **Animation presets** |
| ![Themes page](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_03_themes_palette.gif) | ![Panel drag-drop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_04_panel_drag_drop.gif) |
| **Themes page** (21 themes) | **Panel and bar modes** |

### The Hikari → Tachiagari arc · v6.16.4.12.5 → .7.1

- **Hikari (光)** — illumination across every surface, frosted glass, plugin manager, click-to-open bar triggers
- **Tsubasa (翼)** — Hyprland plugin manager built into Settings
- **Hiraki (開き)** — click-to-open bar triggers, popup-above-clock
- **Tachiagari (立ち上がり)** — Pill fix, sidebar user row, smart gaming, four-direction popup edge logic. **The base Modori rolled back to.**

[Hikari Release Showcase](https://www.youtube.com/watch?v=nS2L9dIQbF4)

### Tategaki (縦書き) — *rolled back* · v6.16.4.12.8.x

Vertical-bar rendering attempt. Three startup-blocking parser errors and a broken empty-bar
render. Reverted in Modori, **revived properly in v7**. Preserved so the lineage stays honest —
not every experiment lands.

---

## Themes

**21 built-in themes**, plus **Sakura** from the version 8 line and the Modori pair:

- **Modori Dark** — midnight indigo `#0e0f1a` / `#1a1c28` · bone white `#f0e8d8` · persimmon `#e87554` · sage `#98b283`
- **Modori Light** — washi cream `#f5ede0` / `#ebe1d0` · sumi ink `#1a1a1a` · persimmon `#e87554` · sage `#7A9068`

Custom themes drop into `~/.config/zen-shell/themes/` and are auto-validated against the
smart-contrast engine on import.

---

## Contributing

Issues and pull requests welcome. Before opening one:

1. **Hyprland ≥ 0.54** and **Quickshell ≥ 0.2.1** — older will not work.
2. Never use `windowrulev2` or block-style `layerrule {}`.
3. Read **Key design rules** above — most were paid for in hours.
4. File pull requests against `main` for the version 8 alpha; against the v7 tag for stable fixes.

---

## Credits

- **[Quickshell](https://quickshell.outfoxxed.me/)** by outfoxxed — the framework that makes Zen Shell possible
- **[Hyprland](https://hyprland.org/)** by vaxerski — the only supported compositor
- **[Literata](https://fonts.google.com/specimen/Literata)**, **[JetBrains Mono](https://www.jetbrains.com/lp/mono/)**, **[Noto Serif JP](https://fonts.google.com/noto/specimen/Noto+Serif+JP)** — typography
- All the alpha testers who survived the Tategaki rollback

---

## License

MIT · Crafted in Antipolo, Philippines

---

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development">GitHub</a> ·
  <a href="https://gekinzen.github.io/zen-shell-site/">Project Site</a> ·
  <a href="https://buymeacoffee.com/zenpy">Buy a coffee</a>
</p>
