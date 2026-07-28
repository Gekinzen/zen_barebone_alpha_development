# Zen Shell · 改善 (Kaizen)

> **A QML-native desktop environment for Hyprland on Arch / CachyOS.**
> Panel · Control Center · Wallpaper Engine · Themes · Settings · Lock screen · Dock · Taskbar · Native notifications — unified in a single Quickshell process.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg" alt="Zen Shell desktop preview" width="100%" />
</p>

<p align="center">
  <img alt="current alpha" src="https://img.shields.io/badge/current-v8.0.0--alpha%20改善%20Kaizen-e87554?style=flat-square&labelColor=14140f" />
  <img alt="next" src="https://img.shields.io/badge/next-ZenithArch--shell--qml%20暁%20Akatsuki-c68a4a?style=flat-square&labelColor=14140f" />
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v7.0.0-beta.1"><img alt="stable" src="https://img.shields.io/badge/stable-v7.0.0--beta.1%20軽い%20Karui-7A9068?style=flat-square&labelColor=14140f" /></a>
  <img alt="hyprland" src="https://img.shields.io/badge/hyprland-≥%200.54-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="quickshell" src="https://img.shields.io/badge/quickshell-≥%200.2.1-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="license" src="https://img.shields.io/badge/license-MIT-b8924e?style=flat-square&labelColor=14140f" />
</p>

---

## 改善 · Kaizen — *continuous improvement* · current alpha line

**Kaizen (改善)** — *"change for the better"*, the practice of small relentless
improvements rather than one grand rewrite. It is the honest name for what the
`v8.0.0-alpha` line actually is: **96 hotfixes** from `hf100` to `hf195`, each one
a real bug found and closed or a real feature finished, shipped in sequence with
the reasoning written down.

Nothing here was planned as a release. It became one.

> **Current build: `v8.0.0-alpha-hf195`.** The stable line remains
> **v7.0.0-beta.1 (Karui 軽い)**. **Wala tayong babawasan** — nothing from v6 or
> v7 is removed; Kaizen only adds on top.

### The Look system — Glass, Glass+, and readable text

The largest single thread in the line. Frosted surfaces everywhere, and then the
much harder problem of keeping text legible **on top of** frost that sits over an
arbitrary wallpaper.

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

### Appearance & theming

- **Cursor theme picker** promoted to its own page under Appearance, scanning `.icons`, `.themes`, `.cursor` and `/usr/share`, detecting **hyprcursor** themes as well as XCursor — and the chosen cursor now survives a relogin **from the very first frame**.
- **GTK icon theme picker** built in, so there is no detour through GTK settings.
- **Wallpaper page** with fuzzy search and auto-load on open.
- **Dropdowns** that follow their sheet instead of drifting, with text that picks its own colour on an opaque surface.
- **Densho (伝承) mode** — a full traditional-Japanese identity: kanji workspace labels, a vertical kanji date column, a seasonal kanji that tracks the 24 solar terms, brush-stroke bar separators, and **34 module kanji + 6 category kanji in the Control Center sidebar** with romaji tails, plus the written 禅 mark on the brand badge.

### Dock, Taskbar and the bar

- A matured **Dock** with context menus, `SUPER+D`, floating icons, and a proper **dock plate** background.
- A **Taskbar** page and module.
- **The centre bar zone now actually stays centred.** It was a `RowLayout` with two `fillWidth` spacers, which averages rather than centres: the centre sat `(left − right) / 2` away from the middle, so adding one icon on the left slid it by half that icon. On a 1920 bar that was up to **450px off**. Both bars are now anchor-positioned — each zone against the bar, never against its neighbours — with a symmetric budget and a clipping slot so the centre **narrows evenly instead of sliding away** when the sides grow. The vertical bar had the identical bug rotated 90°, and got the same fix.
- **System tray** module spacing fixed in two different places for two different reasons: an en-space in the bar's own formatter, and a real icon slot on `SettingRow` for the settings page, because padding a string with spaces cannot fix a gap made of mixed fallback-font advance widths.
- **Volume OSD clears the dock**, not just the bar — one rule that holds whichever edge either is on.

### Networking — the long one

An extended debugging arc that ended somewhere quite different from where it started, and the wrong turns are documented because they are the useful part.

- **Connected-state detection rebuilt.** The original test was `parts[0] === "yes"` against `nmcli`'s IN-USE column — which on NetworkManager 1.40+ prints `*`, never `yes`. One line, three symptoms: the panel offered "Connect" on the network you were already joined to, the bar glyph fell through to the ethernet/disconnected icon, and Saved Networks never highlighted.
- **Three independent sources, ORed not chained** — `iw dev link` (the card), `nmcli device show` (the device), `nmcli connection show --active` (the profile). An early version gated the last two on the first being absent, which turned three sources into one and made a healthy connection report "Not connected".
- **One row per network** — a router broadcasting on 2.4 + 5GHz returns several BSSIDs; they fold into one row with an `N AP` hint, keeping the radio you are actually associated to.
- **`_nmSplit`** — `nmcli -t` escapes literal colons as `\:`, so a plain `split(":")` silently shifted every field for any SSID containing one.
- **The Wi-Fi Keeper** — remembers the network you were genuinely connected to and rejoins it with 5s→60s backoff, capped at six attempts; clears NM's invisible autoconnect block before each retry; **stops immediately and asks when a password is the problem**, because retrying cannot supply one; and stands down entirely when you disconnect on purpose.
- **Wrong password is now distinguishable from missing password.** `nmcli` reports both as "Secrets were required", which is why this took a night: a stored-but-rejected key looks identical to no key at all. The supplicant knows the difference and says `WRONG_KEY`, so that is what gets checked.
- **The password you type is now the password that gets stored.** A failed attempt leaves the wrong key saved in the profile; `nmcli device wifi connect` then reuses that profile and discards what you typed. The key is written straight in with `connection modify … psk … psk-flags 0`.
- **`zen-wifi-doctor.sh`** — read-only. Reports which of the three detection sources disagrees with reality, and with `--why`: adapter and bus, driver provenance (in-tree vs DKMS), USB autosuspend, power saving, the full profile, `psk-flags` reachability, NM's journal, the kernel log, regulatory domain, and AP/band-steering analysis.
- **`zen-wifi-watch.sh`** — read-only. Watches live and records the drop **at the moment it happens**, because the reason a reconnect fails is not the reason the link dropped, and reconstructing after the fact had already produced one wrong diagnosis.
- **GTK Wi-Fi selector** reachable from the bar icon, the Network Pulse module, and the dashboard rail.

### Panasonic Let's Note support

libinput implements exactly three scroll methods — two-finger, edge, on-button — and circular is not one of them. The ArchWiki pages for the CF-SV9 and CF-SV1 state plainly that the round wheel pad cannot do circular scrolling under Wayland. Hyprland is Wayland-only, so it had to be synthesised.

- **`zen-wheelpad`** grabs the touchpad, republishes it as a uinput clone with identical capabilities so libinput keeps handling accel, tap and gestures normally, and converts angular travel around the outer ring into scroll events. If it dies the kernel drops the grab automatically — worst case you lose circular scroll, never the pointer.
- Tunable ring width, sensitivity, engage threshold and direction, with a live ring preview.
- **`panasonic-laptop`** integration — ECO battery-charge limit and sticky keys via sysfs, with the firmware-reset caveat stated in the UI rather than buried.
- Detection covers CF-SV / SZ / LX / NX / RZ / QV / FV / SR and Toughbook FZ, by DMI and by touchpad capability rather than a model table.
- Hardware-gated: on anything that is not a Let's Note the page does not exist and nothing polls. A developer override exists so the page can be worked on from a desktop.

### Input & system

- **Keyboard-independent media keys.** A bind written as `code:60` names a physical matrix position, so it lands somewhere else on a different keyboard. Keysym binds name the *meaning* and survive the swap. Ships as a self-installing drop-in — the installer copies it and adds the `source` line idempotently.
- Every new bind was **diffed against every bind Zen Shell already ships** before being made active, which caught one that would have silently stolen the dashboard shortcut.
- **EasyEffects autostart**, Bluetooth and audio manager launchers with proper toggle semantics.
- **Panic recovery**, game-mode warnings, "Reset all to defaults" covering focus settings, and a Lark/Zoom call-popup fix.

---

## 暁 · Akatsuki — **ZenithArch-shell-qml** · v8 · *coming soon*

**Akatsuki (暁)** — *"dawn / daybreak"*. After relentless improvement comes the
release that carries it.

**ZenithArch-shell-qml** is the name the v8 line ships under: the peak
(*zenith*) of the Arch-native QML shell that began as a Waybar-and-Python
proof of concept five codenames ago.

### What lands in v8

- Everything in the Kaizen alpha line above, consolidated and stabilised.
- **A real NetworkManager secret agent.** Zen Shell currently registers none, which is why an agent-owned PSK can never authenticate under Hyprland. A proper agent covers WPA-Enterprise, VPN secrets and requests from other applications — not just the one case patched around today.
- **WPA-Enterprise (802.1X)** — multi-field form: identity, EAP method, CA certificate.
- **"Connect automatically" per network** in the in-shell prompt.
- **Confirm dialogs** for destructive actions — forget network, unpair device.
- **Bluetooth audio sink routing** — one tap to move audio to a paired device via `wpctl`.
- **ZenCleanupService** — RAM reclaim and zombie reaping.
- **QML lazy-load pass** — the last leg of the Karui performance trio.
- **Plugin system v2** — signed manifests, per-plugin QML sandboxing, a community registry.
- **Panasonic wheel pad validated on real hardware.** The geometry engine is unit-tested off-hardware; the evdev half has never met an actual wheel pad.

### Download

> **ZenithArch-shell-qml has not been released yet.**
> Watch the repository for the first `v8` tag under the Akatsuki codename.

```bash
# Coming soon
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development
git checkout v8.0.0          # ← not published yet
./install.sh --bootstrap
```

Until then, run the stable line or the Kaizen alpha:

```bash
git checkout v7.0.0-beta.1   # stable — Karui 軽い
git checkout main            # Kaizen alpha — v8.0.0-alpha
```

---

## The shipped line — v6 戻り Modori + v7 軽い Karui

The two official lines that carry everything Kaizen builds on. Both remain
runnable; v7 is the recommended stable.

### 軽い · Karui — v7.0.0-beta.1 · *lightweight*

**Performance trio — `LaptopModeService`**
Three modes (Off / Balanced / Endurance) drive adaptive polling across the
existing services. System monitor stretches 2s → 5–30s by mode and battery
level; weather refresh is suppressed under the low-battery threshold; the audio
rope falls back to static when critical; the CPU governor switches to
power-saver on battery in Endurance; an optional sub-toggle pushes minimal
Hyprland animations and restores them when plugged in. Optional 80% charge
limit where the kernel exposes `charge_control_end_threshold`. Auto-hides on
desktops, with a manual override.

**Lock screen** — music-string alignment self-heals after lock → login via a
screen-width-independent island width; hyprlock power pills; time-aware greeting
with a weather-matched emoji; theme-synced accents on every lock.

**Notifications** — the native `NotificationServer` reliably owns
`org.freedesktop.Notifications` in Zen mode, stopping and disabling **swaync,
mako and dunst** rather than only swaync. SwayNC fallback mode unchanged.

**Base** — matured Dock, `SUPER+SHIFT+T` drop-down terminal, Zen Tokyo SDDM
greeter, `zen-hyprbars-doctor.sh` for the recurring hyprpm "Outdated headers"
failure, and the Tategaki redux vertical bar.

### 戻り · Modori — v6.16.4.12.9.10 · *to return*

After the Tategaki vertical-bar attempt hit three startup-blocking parser errors,
the bar was rolled back to the proven Tachiagari `.7.1` base. Modori is what was
rebuilt on top, bundling patch levels `.10`, `.11` and `.12`.

- **Smart-contrast theme engine** — every theme runs a luminance check and nudges unreadable foregrounds toward WCAG 4.5:1. Custom themes get the same protection on import.
- **In-shell Wi-Fi password prompt** at `WlrLayer.Overlay`, replacing the zenity prompt that hid behind the Control Panel.
- **Redesigned Wi-Fi + Bluetooth panels** — saved/available split, 44px tap targets, scan toggle, pair flow.
- **GTK Dark Mode toggle** — atomic sync of `gsettings` + GTK3/4 `settings.ini` + libadwaita.
- **Modori Dark / Light** themes and paired procedural wallpapers — an imperfect ensō with a persimmon dot, and a faint 戻 watermark.
- **Persimmon accent** `#e87554` throughout.
- Debounced 200ms settings save, so rapid slider drags stop corrupting `panel-state.json`.

| Patch | What it fixes |
|---|---|
| `.10` | Modori baseline |
| `.11` | Wi-Fi route-metric preference, `preventStealing` on row taps, open-network parser fix, action exit refresh |
| `.12` | One-line restore of a recursive helper that was silently breaking every Wi-Fi / BT / audio toggle |

---

## Quick Install

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

git checkout v7.0.0-beta.1     # stable (Karui)
# git checkout main            # Kaizen alpha (v8.0.0-alpha)

./install.sh --bootstrap
```

`install.sh` auto-detects whether bootstrap is needed (Hyprland, Quickshell,
grim, slurp, wl-copy, swww, cava, playerctl, jq, notify-send), runs it if
anything is missing, then installs. It kills any existing zen-shell process and
spawns exactly one new instance.

### Requirements

- **Arch Linux** or **CachyOS** — other distros may work but are not tested
- **Hyprland ≥ 0.54** (0.55 supported) — `0.54+` syntax only
- **Quickshell ≥ 0.2.1**
- AMD Ryzen + Radeon recommended — developed on `Ryzen 9 5950X` + `RX 6800`

### Optional

Two features ship as separate helper processes rather than QML, because they
need kernel interfaces QML has no access to:

| Feature | Needs |
|---|---|
| GTK Wi-Fi selector | `python-gobject` `gtk4` `libadwaita` |
| Panasonic wheel pad | `python-evdev`, membership of `input`, write access to `/dev/uinput` |
| Wi-Fi diagnostics | `iw` (optional — two other detection sources work without it) |

Both are **opt-in and inert when absent** — nothing in the shell depends on
them, and the Wi-Fi selector falls back to `nm-connection-editor` and then
`nmtui`.

---

## Architecture

- **[Quickshell](https://quickshell.outfoxxed.me/)** — QML-native shell framework for Wayland
- **QML / Qt 6** — declarative UI, fragment shaders for circular masking, custom delegates
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
- **Converting a Layout to an Item loses `implicitWidth`/`implicitHeight`.** Anything bound to them silently reads zero.
- `parent.parent.width` is unreliable inside `Flickable` / `ScrollView` — keep a ref to the outer item.
- Overlay `Rectangle`s must be **siblings**, not children, of layouts.
- `hyprctl reload` wipes runtime keyword state — re-apply anything set via `hyprctl keyword`.
- Layer-shell windows always report `win.x = 0`; reconstruct screen-X from `panelMode`.
- **`pkill -x`, never `pkill -f`** in a toggle — `-f` matches the whole command line and will kill the shell command issuing it.

---

## Lineage

**Wala tayong babawasan** — every era preserved.

```
Wakaba (若葉)          Alpha v0.91          · Genesis · bare Waybar + Python
Koke   (苔)            Alpha v2.x           · Legacy · GTK4 / Libadwaita era
Yugen  (幽玄)          v6.10 → v6.14        · Rewrite · GTK → Quickshell QML
Ensō   (円相)          v6.15.x → v6.16      · Unified · the circle closes
Ma     (間)            v6.16.1.x            · Refinement · cascade Control Panel
Shibui (渋い)          v6.16.2.3.x          · Refinement · click-through fixes
Sabi   (寂)            v6.16.3.x            · Refinement · Lock screen, PowerBadge
Kintsugi (金継ぎ)      v6.16.4.x → .11.2    · Stable predecessor · gold in seams
Hikari  (光)           v6.16.4.12.5 → .6.53 · Interlude · illumination + plugins
Tsubasa (翼)           v6.16.4.12.6.40      · Interlude · Hyprland plugin manager
Hiraki  (開き)         v6.16.4.12.6.52-.53  · Interlude · click-to-open triggers
Tachiagari (立ち上がり) v6.16.4.12.7 → .7.1  · Interlude · the proven base
Tategaki (縦書き)      v6.16.4.12.8.x       · ROLLED BACK · vertical-bar attempt
Modori (戻り)          v6.16.4.12.9.10      · ★ OFFICIAL v6 ★
─────────────────────────────────────────────────────────────────────────────
Karui  (軽い)          v7.0.0-beta.1        · ★ OFFICIAL v7 ★
Kaizen (改善)          v8.0.0-alpha         · ◆ CURRENT · 96 hotfixes, hf100→hf195
Akatsuki (暁)          ZenithArch-shell-qml · ☀ COMING SOON · v8
```

**Hoshi (星)** — *"star"* — stays reserved as a future milestone name.

## Codename history

| Codename | Kanji | Meaning | Versions |
|---|---|---|---|
| Wakaba | 若葉 | Young leaf | Alpha v0.91 — Waybar + Python + rofi |
| Koke | 苔 | Moss | Alpha v2.x — GTK4 / Libadwaita era |
| Yugen | 幽玄 | Subtle profound grace | v6.10 – v6.14 — QML rewrite |
| Ensō | 円相 | The zen circle | v6.15.x · v6.16 base |
| Ma | 間 | The space between | v6.16.1.x |
| Shibui | 渋い | Understated refinement | v6.16.2.3.x |
| Sabi | 寂 | Beauty of age & patina | v6.16.3.x |
| Kintsugi | 金継ぎ | Golden repair | v6.16.4.x · v6.16.4.11.2 |
| Hikari | 光 | Light — illumination | v6.16.4.12.5 – .6.53 |
| Tsubasa | 翼 | Wings · plumage | v6.16.4.12.6.40 |
| Hiraki | 開き | Opening | v6.16.4.12.6.52 – .53 |
| Tachiagari | 立ち上がり | Rising up | v6.16.4.12.7 – .7.1 |
| Tategaki | 縦書き | Vertical writing ❌ rolled back | v6.16.4.12.8.x |
| **Modori** | **戻り** | **To return — v6 stable** | **v6.16.4.12.9.10** |
| **Karui** | **軽い** | **Lightweight — v7 stable** | **v7.0.0-beta.1** |
| **Kaizen** | **改善** | **Continuous improvement — current alpha** | **v8.0.0-alpha** |
| **Akatsuki** | **暁** | **Dawn — ZenithArch-shell-qml** | **v8 · coming soon** |
| Hoshi | 星 | Star — reserved | — |

---

## Branch Naming Convention

- **v6 official:** tag `v6.16.4.12.9.10` (Modori)
- **v7 official:** tag `v7.0.0-beta.1` (Karui)
- **v8 alpha:** `main` — `v8.0.0-alpha-hfNNN` (Kaizen)
- **v8 release:** tag `v8.0.0` — ZenithArch-shell-qml (Akatsuki) · *TBA*

---

## Project Archive

> **From sprout to lacquered bowl to relentless refinement.**
> Zen Shell began as *Zen Barebone Alpha* — a bare Waybar + Python concept on
> Hyprland 0.52.

### 若葉 · Wakaba — *the first sprout* (Alpha v0.91)

Bare Waybar, Python helpers, `rofi` for launching, on **Hyprland 0.52**. No QML,
no Quickshell. Proof that a cohesive desktop could be built on Hyprland with
shell scripts and config.

### 苔 · Koke — *moss grows steady* (Alpha v2.x)

The full **Python / GTK4 / Libadwaita** era. Custom GTK control center, dock,
unified theme engine, desktop widgets, smart start menu, 13+ themes.

| | | |
|---|---|---|
| ![Main demo](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif) | ![Theme switching](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif) | ![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif) |
| **Main demo** | **Theme switching** | **Wallpaper picker** |
| ![Panel modes](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif) | ![Desktop looks](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png) | ![Dock](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png) |
| **Panel modes** | **Desktop looks** | **Dock · taskbar** |

> [Browse the full Koke archive](https://github.com/Gekinzen/images-demo/tree/main/zen_demo_old_archive_2025)

### 幽玄 · Yugen — *subtle, profound grace* (v6.10 → v6.14)

The QML rewrite cycle. GTK4 gradually replaced with Quickshell-native QML.

📺 [v6.14 demo](https://www.youtube.com/watch?v=YQxrh5_naMQ) · [v6.10 foundations](https://www.youtube.com/watch?v=ao89J3DEqiA)

### 円相 · Ensō — *the circle closes* (v6.15.x)

Full Quickshell-native stack. Bar, Start Menu, Control Panel, Settings, theme
engine, wallpaper manager, music strings, screenshot ropes, avatar system,
island mode, system tray — all QML.

📺 [Full v6.15.x tour](https://www.youtube.com/watch?v=dNwGRBhA97g)

| | | |
|---|---|---|
| ![Desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png) | ![Workspace](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png) | ![Settings](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png) |
| **Desktop** | **Workspace · island mode** | **Settings page** |

### 間 · Ma · 渋い · Shibui · 寂 · Sabi (v6.16.1 → v6.16.3)

Cascade Control Panel and two-column layouts; click-through mask fixes and
`OpacityMask` avatar; Material power icons, lock screen overhaul, PowerBadge,
weather mood, widget scale.

### 金継ぎ · Kintsugi — *gold in the seams* (v6.16.4.x)

The stable predecessor to Modori. Panic Recovery keybind, 11 alpha iterations in
two days, widget scale awareness, Dark Mode toggle, Wi-Fi Connect rewrite, the
colour picker that took four attempts, Material dropdown with WCAG luminance
contrast, PaletteBox. **The Kintsugi themes still ship.**

| | |
|---|---|
| ![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_01_wallpaper_picker.gif) | ![Animation presets](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_02_animations_dropdown.gif) |
| **Wallpaper engine** (Super+W) | **Animation presets** |
| ![Themes page](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_03_themes_palette.gif) | ![Panel drag-drop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_04_panel_drag_drop.gif) |
| **Themes page** (21 themes) | **Panel · Bar modes** |

### The Hikari → Tachiagari arc (v6.16.4.12.5 → .7.1)

- **光 · Hikari** — illumination across every surface, frosted glass, plugin manager, click-to-open bar triggers
- **翼 · Tsubasa** — Hyprland plugin manager built into Settings
- **開き · Hiraki** — click-to-open bar triggers, popup-above-clock
- **立ち上がり · Tachiagari** — Pill fix, sidebar user row, smart gaming, 4-direction popup edge logic. **The base Modori rolled back to.**

📺 [Hikari Release Showcase](https://www.youtube.com/watch?v=nS2L9dIQbF4)

### 縦書き · Tategaki — *ROLLED BACK* (v6.16.4.12.8.x)

Vertical-bar rendering attempt. Three startup-blocking parser errors and a broken
empty-bar render. Reverted in Modori, **revived properly in v7**. Preserved so
the lineage stays honest — not every experiment lands.

---

## Themes

**21 built-in themes**, plus **Sakura** from the Kaizen line and the Modori pair:

- **Modori Dark** — midnight indigo `#0e0f1a` / `#1a1c28` · bone white `#f0e8d8` · persimmon `#e87554` · sage `#98b283`
- **Modori Light** — washi cream `#f5ede0` / `#ebe1d0` · sumi ink `#1a1a1a` · persimmon `#e87554` · sage `#7A9068`

Custom themes drop into `~/.config/zen-shell/themes/` and are auto-validated
against the smart-contrast engine on import.

---

## Contributing

Issues and PRs welcome. Before opening one:

1. **Hyprland ≥ 0.54** and **Quickshell ≥ 0.2.1** — older will not work.
2. Never use `windowrulev2` or block-style `layerrule {}`.
3. Read **Key design rules** above — most were paid for in hours.
4. File PRs against `main` for the Kaizen alpha; against the v7 tag for stable fixes.

---

## Credits

- **[Quickshell](https://quickshell.outfoxxed.me/)** by outfoxxed — the framework that makes Zen Shell possible
- **[Hyprland](https://hyprland.org/)** by vaxerski — the only supported compositor
- **[Literata](https://fonts.google.com/specimen/Literata)**, **[JetBrains Mono](https://www.jetbrains.com/lp/mono/)**, **[Noto Serif JP](https://fonts.google.com/noto/specimen/Noto+Serif+JP)** — typography
- All the alpha testers who survived the Tategaki rollback 🙏

---

## License

MIT · Crafted in Antipolo, Philippines · 改善

---

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development">GitHub</a> ·
  <a href="https://gekinzen.github.io/zen-shell-site/">Project Site</a> ·
  <a href="https://buymeacoffee.com/zenpy">☕ Buy a coffee</a>
</p>
