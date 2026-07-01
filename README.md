# Zen Shell · 軽い (Karui) — Official v7

> **A QML-native desktop environment for Hyprland on Arch / CachyOS.**
> Panel · Control Center · Wallpaper Engine · Themes · Settings · Lock screen · Native notifications — all unified in a single Quickshell process. No GTK4. No Python helpers. No Waybar.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg" alt="Zen Shell desktop preview" width="100%" />
</p>

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v7.0.0-beta.1"><img alt="v7 official" src="https://img.shields.io/badge/v7%20official-v7.0.0--beta.1%20Karui-e87554?style=flat-square&labelColor=14140f" /></a>
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v6.16.4.12.9.10"><img alt="v6 official" src="https://img.shields.io/badge/v6%20official-v6.16.4.12.9.10%20Modori-e87554?style=flat-square&labelColor=14140f" /></a>
  <img alt="upcoming" src="https://img.shields.io/badge/next%20alpha-Akatsuki%20暁%20·%20coming%20soon-c68a4a?style=flat-square&labelColor=14140f" />
  <img alt="hyprland" src="https://img.shields.io/badge/hyprland-≥%200.54-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="quickshell" src="https://img.shields.io/badge/quickshell-≥%200.2.1-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="license" src="https://img.shields.io/badge/license-MIT-b8924e?style=flat-square&labelColor=14140f" />
</p>

---

## 軽い — Karui (v7.0.0-beta.1) · official v7 release

**Karui (軽い)** means *"light / lightweight"* — the theme of the v7 line.

Karui is the **official v7 release**, actively hardened through the `hf98`
hotfix series. It is the first of the v7 **performance trio**: adaptive polling
that drops battery drain without sacrificing responsiveness when plugged in,
plus a full pass over the lock screen and a native, conflict-free notification
daemon.

**Both v6 and v7 are official lines you can run today.** Karui doesn't "become"
something else — it ships under its own name. **Hoshi (星)** — *"star"* — stays
reserved as a future v7 milestone name, honoring the GitHub repository that
hosts Zen Shell.

> **The current official build is `v7.0.0-beta.1` (Karui), hotfix `hf98`.** The
> whole v6 line — Modori (戻り) `v6.16.4.12.9.10` — remains the official **v6**
> **line**. **Wala tayong babawasan** — nothing from v6 is removed; v7 only adds
> on top.

### What Karui brings

**Performance trio — `LaptopModeService`**

- **Three modes** (Off / Balanced / Endurance) drive adaptive polling on the
  existing services so battery drain drops without hurting responsiveness on AC.
- **SystemMonitorService**: 2s default → 5–30s adaptive based on mode + battery %.
- **WeatherService**: refresh suppressed below the low-battery threshold.
- **ZenStrings (audio rope)**: falls back to static when the battery is critical in Endurance.
- **CPU governor**: auto-switch to power-saver via the existing `PowerProfileService` when in Endurance + on battery.
- **Hyprland animations**: an optional Endurance sub-toggle pushes a minimal-animation snippet to `~/.config/hypr/zen-laptop-anims.conf` and `hyprctl reload`s — restored to defaults when unplugged.
- **Battery health**: optional 80% charge limit if the kernel exposes `charge_control_end_threshold` for your BAT*.
- **Auto-detect**: hides itself on desktops (chassis_type + BAT* sniff). Manual override available for users who want it on a desktop.
- **Coming next in the trio**: `ZenCleanupService` (RAM cleaner + zombie reaper), then a QML lazy-load pass.

**Lock screen (hf98 series)**

- **Music-string alignment self-heals after lock → login.** The audio-rope
  overlay used to land far-left (island mode only) after unlocking. The bar's
  centre is now published as a screen-width-independent island width and the
  overlay centres itself from its own always-valid screen width — a live
  binding, no polling, no staleness, no "Loading…" blink.
- **hyprlock power buttons** — clickable **Shutdown** and **Restart** pills at
  the bottom of the lock screen (hyprlock `onclick`), matching the desktop power
  menu (`systemctl poweroff` / `reboot`). Icons render inline so they never clip.
- **Time-aware greeting with your name** under the clock — *"Good afternoon,
  Paul ⛈️"* — and the trailing emoji **matches the live weather** (🌧️ rain,
  ⛈️ storm, ☁️ cloudy, 🌌 starry night, ☀️/🌤️/🌇/🌙 for clear-by-time-of-day),
  so it lines up with the weather mood line below it.
- **Theme-synced lock colours** — the power-button accents follow the active
  theme (`current-theme.json`) on every lock, so Tokyo-Night, Gruvbox,
  Catppuccin, matugen, etc. all carry through.

**Notifications — native daemon, no conflicts**

- The zen-shell native **NotificationServer** now reliably owns the
  `org.freedesktop.Notifications` bus in **Zen mode**: it stops + disables +
  kills any competing daemon — **swaync, mako, AND dunst** — instead of only
  swaync. Whichever a user's own dotfiles autostarted no longer steals the bus
  and drops notifications in the wrong corner. **SwayNC fallback mode is
  unchanged.**

**v7 line base (Karui beta → Hoshi stable)**

- A matured **Dock**, a **Super+Shift+T** quick drop-down terminal, the **Zen
  Tokyo SDDM greeter**, the `zen-hyprbars-doctor.sh` repair tool for the
  recurring hyprpm "Outdated headers" failure, and the **Tategaki redux**
  vertical bar that finally landed after the v6 rollback.

---

## 暁 — Akatsuki · *upcoming alpha · coming soon*

**Akatsuki (暁)** means *"dawn / daybreak"* — after the star (Hoshi 星) comes the
dawn. It is the codename reserved for the **next alpha cycle** once the v7.0.0
line settles. Nothing is on the alpha branch yet; this is the name the next
first commit will carry.

Likely first landings (order approximate, may shuffle on feedback):

- **Wrong-password feedback** on WiFi connect failures (watch the `nmcli` exit code, re-open the prompt with an error).
- **"Connect automatically" checkbox** per network in the in-shell password prompt.
- **WPA-Enterprise (802.1X)** support — multi-field expanded form (identity, EAP, CA cert).
- **Confirm dialogs** for destructive actions (forget network, unpair device).
- **Auto-rescan WiFi** every 30s while the picker is open.
- **Bluetooth audio sink routing** — one-tap route audio to a paired BT device via `wpctl`.
- **ZenCleanupService** + the QML lazy-load pass (rest of the Karui performance trio).
- **Plugin system v2** — signed manifests, per-plugin QML sandboxing, a community registry.

> **Watch the repo** for the first `alpha` branch under the Akatsuki codename
> when the cycle opens.

---

## Quick Install

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Official v7 (Karui)
git checkout v7.0.0-beta.1

# Or the official v6 (Modori) — bundles patch levels .10 / .11 / .12
# git checkout v6.16.4.12.9.10

./install.sh --bootstrap
```

`install.sh` auto-detects whether bootstrap is needed (missing Hyprland /
Quickshell / grim / slurp / wl-copy / swww / cava / playerctl / jq /
notify-send), runs bootstrap if any are missing, then installs. At the end it
kills any existing zen-shell process and spawns exactly ONE new instance.

### Requirements

- **Arch Linux** or **CachyOS** (other distros may work but aren't officially tested)
- **Hyprland ≥ 0.54** (0.55 supported) — uses `0.54+` syntax exclusively (`layerrule = blur on, match:namespace x` / `windowrule = float true, match:title ^(x)`; no deprecated `windowrulev2` or block-style `layerrule {}`)
- **Quickshell ≥ 0.2.1**
- AMD Ryzen + Radeon recommended — extensively tested on `Ryzen 9 5950X` + `RX 6800 XT`

---

## Lineage

Zen Shell is the latest in a long line of zen-named releases. **Wala tayong
babawasan** — every era preserved.

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
Akatsuki (暁)          next cycle           · ☀ UPCOMING ALPHA · coming soon
```

**Hoshi (星)** — *"star"* — stays reserved as a future v7 milestone name.
**Akatsuki (暁)** — *"dawn"* — is the next alpha cycle after Karui.

---

## 戻り — Modori (v6.16.4.12.9.10) · v6 stable

**Modori (戻り)** means *"to return"*. After the **Tategaki (縦書き)** vertical-bar
attempt hit three startup-blocking parser errors and a broken empty-bar render,
the bar code was rolled back to the proven **Tachiagari .7.1** base. Modori is
what was added back on top of that proven foundation — promoted to **v6 stable**
after the **.11** and **.12** reliability patches landed. It bundles patch levels
`.10`, `.11`, and `.12` together.

### What Modori adds

- **Smart-contrast theme engine (WCAG-aware)** — every loaded theme runs through a luminance check; unreadable foreground tones are auto-nudged toward a WCAG 4.5:1 ratio. Custom user themes get the same protection on import.
- **In-shell WiFi password prompt** — at `WlrLayer.Overlay`, replacing the old zenity prompt that was hiding behind the Control Panel.
- **Redesigned WiFi + Bluetooth panels** — saved/available split, larger 44px tap targets, scan toggle, BT pair flow.
- **GTK Dark Mode toggle** — one-tap atomic sync of `gsettings` + GTK3/4 `settings.ini` + libadwaita.
- **Two new built-in themes** — *Modori Dark* (midnight indigo · bone white · persimmon) and *Modori Light* (washi cream · sumi ink · persimmon).
- **Paired procedural wallpapers** — an imperfect enso (zen calligraphic circle) with a small persimmon dot inside marking "home", and a faint **戻** kanji watermark in the lower-right.
- **Persimmon accent** — `#e87554` carried through every surface (bar, control panel, settings, calendar).
- **Bulletproof sidebar user labels** — env-fallback resolution, no more empty `$USER`.
- **Settings persistence fixes** — debounced 200ms save so rapid slider drags no longer corrupt `panel-state.json`.

| Patch | What it fixes |
|---|---|
| `.10` | Modori baseline release |
| `.11` | WiFi route-metric preference (wifi wins over LAN on user-tap), `preventStealing` on row taps, open-network parser fix, action exit refresh + stderr logging |
| `.12` | Critical one-line restore of a recursive helper that was silently breaking every WiFi/BT/audio toggle |

---

## Architecture

- **[Quickshell](https://quickshell.outfoxxed.me/)** — QML-native shell framework for Wayland
- **QML / Qt 6** — declarative UI, fragment shaders for circular masking, custom delegates
- **Hyprland 0.54+** — compositor (no other compositor supported)
- **Custom singletons** for state — `PanelState`, `ThemeService`, `WallpaperState`, `ConnectivityService`, `NotificationService`, `ZenStringsState`
- **No external IPC** — components communicate via QML signals + singletons (PanelState bypasses IPC for the calendar toggle, for example)

### Key design rules

- Hyprland 0.54+ syntax **only**. No deprecated `windowrulev2` or old block-style `layerrule {}`.
- Singletons for state — never `Component.onCompleted: somethingGlobal = x` to share state.
- Fragment shaders for circular masking — avoid `OpacityMask` where shaders are cleaner.
- `PanelState` singleton drives the calendar toggle directly (bypassing Hyprland IPC for snappy response).
- `parent.parent.width` is unreliable inside `Flickable` / `ScrollView` — use a ref to the outer item instead.
- Overlay `Rectangle`s must be **siblings**, not children, of layouts — `RowLayout` / `ColumnLayout` will fight a child overlay's anchors.
- `hyprctl reload` wipes runtime keyword state — anything set via runtime `hyprctl keyword` must be re-applied after a reload.
- Layer-shell windows always report `win.x = 0`; reconstruct real screen-X from `panelMode` when positioning cross-window overlays (music strings, calendar).

---

## Themes

Ships with **21 built-in themes** including the Modori pair:

- **Modori Dark** — midnight indigo (`#0e0f1a` / `#1a1c28`) · bone white (`#f0e8d8`) · persimmon (`#e87554` / `#f08868`) · sage (`#98b283`)
- **Modori Light** — washi cream (`#f5ede0` / `#ebe1d0`) · sumi ink (`#1a1a1a`) · persimmon (`#e87554` / `#c95a3c`) · sage (`#7A9068`)

The full Kintsugi-era theme set is preserved. Custom user themes drop into
`~/.config/zen-shell/themes/` and are auto-validated against the smart-contrast
engine on import.

---

## Project Archive

> **From sprout to lacquered bowl to return to lightness.**
> Zen Shell began as *Zen Barebone Alpha* — a bare Waybar + Python concept on
> Hyprland 0.52. Every era preserved here. **Wala tayong babawasan.**

### 若葉 · Wakaba — *the first sprout* (Alpha v0.91)

The earliest concept build. Bare Waybar, Python helpers, `rofi` for launching —
running on **Hyprland 0.52**, no QML, no Quickshell yet. Pure proof-of-concept
that a cohesive desktop could be built on Hyprland with shell scripts and config.

**Stack:** Hyprland 0.52 · Waybar · Python + rofi

### 苔 · Koke — *moss grows steady* (Alpha v2.x · v2.1.3)

The full **Python / GTK4 / Libadwaita** era. Custom GTK control center, dock
module, unified theme engine, desktop widgets, smart start menu — 13+ themes.

**Stack:** Hyprland 0.52 · GTK4 / Libadwaita · 13+ themes · Custom dock · rofi/wofi

| | | |
|---|---|---|
| ![Main demo](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif) | ![Theme switching](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif) | ![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif) |
| **Main demo** | **Theme switching** | **Wallpaper picker** |
| ![Panel modes](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif) | ![Desktop looks](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png) | ![Dock](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png) |
| **Panel modes** | **Desktop looks** | **Dock · taskbar** |

> **Browse the full Koke archive folder:** [`zen_demo_old_archive_2025/`](https://github.com/Gekinzen/images-demo/tree/main/zen_demo_old_archive_2025)

### 幽玄 · Yugen — *subtle, profound grace* (v6.10 → v6.14)

The QML rewrite cycle. GTK4 gradually replaced with **Quickshell-native QML**.
v6.10 shipped foundations, v6.14 added theme switching and panel modes.

📺 [v6.14 demo](https://www.youtube.com/watch?v=YQxrh5_naMQ) · [v6.10 foundations](https://www.youtube.com/watch?v=ao89J3DEqiA)

### 円相 · Ensō — *the circle closes* (v6.15.x series)

Full Quickshell-native stack. Bar, Start Menu, Control Panel, Settings, Theme
engine, Wallpaper manager, music strings, screenshot ropes, avatar system,
island mode, system tray — all QML, no more GTK helpers.

📺 [Full v6.15.x tour](https://www.youtube.com/watch?v=dNwGRBhA97g)

| | | |
|---|---|---|
| ![Desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png) | ![Workspace](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png) | ![Settings](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png) |
| **Desktop** | **Workspace · island mode** | **Settings page** |

### 間 · Ma — *the space between* (v6.16.1.x)

Cascade Control Panel, two-column layouts. The architecture got room to breathe.

### 渋い · Shibui — *understated refinement* (v6.16.2.3.x)

Click-through mask fixes, `OpacityMask` avatar, polish-everywhere mode.

### 寂 · Sabi — *beauty of age & patina* (v6.16.3.x)

Material power icons, Lock screen overhaul, PowerBadge, weather mood, Widget Scale.

### 金継ぎ · Kintsugi — *gold in the seams* (v6.16.4.x · v6.16.4.11.2)

The stable predecessor to Modori. Panic Recovery keybind, 11 alpha iterations in
two days, widget scale awareness, Dark Mode toggle, WiFi Connect rewrite, the
color picker that took 4 attempts, palette relocation, Material dropdown with
WCAG luminance contrast, PaletteBox. **The Kintsugi themes still ship today.**

| | |
|---|---|
| ![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_01_wallpaper_picker.gif) | ![Animation presets](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_02_animations_dropdown.gif) |
| **Wallpaper engine** (Super+W) | **Animation presets** (Material ZenComboBox) |
| ![Themes page](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_03_themes_palette.gif) | ![Panel drag-drop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_04_panel_drag_drop.gif) |
| **Themes page** (PaletteBox · 21 themes) | **Panel · Bar modes** (drag-drop zones) |
| ![Control Panel](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_05_control_panel.gif) | |
| **Control Panel + Dark Mode** | |

### The Hikari → Tachiagari arc (v6.16.4.12.5 → v6.16.4.12.7.1)

The interlude between Kintsugi stable and Modori:

- **光 · Hikari** — *light · illumination* — illumination across every surface, frosted glass, plugin manager, click-to-open bar triggers (`v6.16.4.12.5 → .6.53`)
- **翼 · Tsubasa** — *wings · plumage* — Hyprland plugin manager built into Settings (`v6.16.4.12.6.40` interlude)
- **開き · Hiraki** — *opening* — click-to-open bar triggers, popup-above-clock, installer hotfix (`v6.16.4.12.6.52 → .53`)
- **立ち上がり · Tachiagari** — *rising up* — Pill fix, sidebar user row, smart gaming, 4-direction popup edge logic. **The proven base Modori rolled back to.** (`v6.16.4.12.7 → .7.1`)

📺 [Hikari Release Showcase](https://www.youtube.com/watch?v=nS2L9dIQbF4)

### 縦書き · Tategaki — *ROLLED BACK* (v6.16.4.12.8.x)

Vertical-bar rendering attempt. Three startup-blocking parser errors and a broken
empty-bar render. Reverted in Modori; the vertical bar was deferred, then
**revived properly in the v7 line (Tategaki redux)**. Preserved here so the
lineage stays honest — not every experiment lands.

### 戻り · Modori — *to return* · v6 stable (v6.16.4.12.9.10)

See the **[Modori section](#戻り--modori-v6164129 10--v6-stable)** above for the full
feature list and demo gallery. **Demo folder:**
[`zen_6_16_4_12_9_3/`](https://github.com/Gekinzen/images-demo/tree/main/zen_6_16_4_12_9_3).

### 軽い · Karui — *lightweight* · ★ official v7 release ★ (v7.0.0-beta.1)

The official v7 release. See the **[Karui section](#軽い--karui-v700-beta1--official-v7-release)**
at the top for the full feature list. Hoshi (星) stays reserved as a future v7
milestone name; the next alpha cycle carries **Akatsuki (暁)**.

---

## Codename history

| Codename | Kanji | Meaning | Versions |
|---|---|---|---|
| Wakaba | 若葉 | Young leaf | Alpha v0.91 — Waybar + Python + rofi |
| Koke | 苔 | Moss | Alpha v2.x (v2.1.3) — GTK4 / Libadwaita era |
| Yugen | 幽玄 | Subtle profound grace | v6.10 – v6.14 — QML rewrite |
| Ensō | 円相 | The zen circle | v6.15.x · v6.16 base |
| Ma | 間 | The space between | v6.16.1.x |
| Shibui | 渋い | Understated refinement | v6.16.2.3.x |
| Sabi | 寂 | Beauty of age & patina | v6.16.3.x |
| Kintsugi | 金継ぎ | Golden-repair | v6.16.4.x · v6.16.4.11.2 |
| Hikari | 光 | Light — illumination | v6.16.4.12.5 – .6.53 |
| Tsubasa | 翼 | Wings · plumage | v6.16.4.12.6.40 (interlude) |
| Hiraki | 開き | Opening | v6.16.4.12.6.52 – .53 |
| Tachiagari | 立ち上がり | Rising up | v6.16.4.12.7 – .7.1 |
| Tategaki | 縦書き | Vertical writing ❌ rolled back | v6.16.4.12.8.x |
| **Modori** | **戻り** | **To return — v6 stable** | **v6.16.4.12.9.10** |
| **Karui** | **軽い** | **Lightweight — official v7 release** | **v7.0.0-beta.1** |
| Hoshi | 星 | Star — reserved, future v7 milestone | — |
| **Akatsuki** | **暁** | **Dawn — upcoming alpha · coming soon** | *next cycle* |

---

## Branch Naming Convention

- **v6 official:** `main` / tag `v6.16.4.12.9.10` (Modori)
- **v7 official:** tag `v7.0.0-beta.1` (Karui)
- **Official tags:** `v6.x.x.x` / `v7.x.x`
- **Alpha branches:** `alpha-v7.x.x.x` — *(Akatsuki cycle · TBA)*

---

## Contributing

Issues and PRs welcome. Before opening one, please check:

1. **Hyprland version** — must be `≥ 0.54`. Older Hyprland will not work.
2. **Quickshell version** — must be `≥ 0.2.1`.
3. **Syntax** — never use `windowrulev2` or old block-style `layerrule {}`. See **Architecture** above.
4. **Branch** — file PRs against `main` for v6 fixes; against the active v7 / alpha branch for new features.

---

## Credits

- **[Quickshell](https://quickshell.outfoxxed.me/)** by outfoxxed — the QML shell framework that makes Zen Shell possible
- **[Hyprland](https://hyprland.org/)** by vaxerski — the only supported compositor
- **[Literata](https://fonts.google.com/specimen/Literata)**, **[JetBrains Mono](https://www.jetbrains.com/lp/mono/)**, **[Noto Serif JP](https://fonts.google.com/noto/specimen/Noto+Serif+JP)** — typography
- All the alpha testers who survived the Tategaki rollback 🙏

---

## License

MIT · Crafted in Antipolo, Philippines · 軽い

---

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development">GitHub</a> ·
  <a href="https://gekinzen.github.io/zen-shell-site/">Project Site</a> ·
  <a href="https://buymeacoffee.com/zenpy">☕ Buy a coffee</a>
</p>
