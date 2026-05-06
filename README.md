# Zen Shell · 戻り (Modori)

> **A QML-native desktop environment for Hyprland on Arch / CachyOS.**
> Panel · Control Center · Wallpaper Engine · Themes · Settings — all unified in a single Quickshell process. No GTK4. No Python helpers. No Waybar.

<p align="center">
  <img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg" alt="Zen Shell Modori desktop preview" width="100%" />
</p>

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v6.16.4.12.9.10"><img alt="stable" src="https://img.shields.io/badge/stable-v6.16.4.12.9.10-e87554?style=flat-square&labelColor=14140f" /></a>
  <img alt="alpha" src="https://img.shields.io/badge/alpha-coming%20soon-8a8a85?style=flat-square&labelColor=14140f" />
  <img alt="hyprland" src="https://img.shields.io/badge/hyprland-≥%200.54-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="quickshell" src="https://img.shields.io/badge/quickshell-≥%200.2.1-7A9068?style=flat-square&labelColor=14140f" />
  <img alt="license" src="https://img.shields.io/badge/license-MIT-b8924e?style=flat-square&labelColor=14140f" />
</p>

---

## 戻り — Modori (v6.16.4.12.9.10)

**Modori (戻り)** means *"to return"*.

After the **Tategaki (縦書き)** vertical-bar attempt hit three startup-blocking parser errors and a broken empty-bar render, the bar code was rolled back to the proven **Tachiagari .7.1** base. Modori is what was added back on top of that proven foundation — promoted to **stable** after the **.11** and **.12** reliability patches landed.

**The current stable on `main` is `v6.16.4.12.9.10`.** It bundles patch levels `.10`, `.11`, and `.12` together.

### What Modori adds

- **Smart-contrast theme engine (WCAG-aware)** — every loaded theme runs through a luminance check; unreadable foreground tones are auto-nudged toward a WCAG 4.5:1 ratio. Custom user themes get the same protection on import.
- **In-shell WiFi password prompt** — at `WlrLayer.Overlay`, replacing the old zenity prompt that was hiding behind the Control Panel.
- **Redesigned WiFi + Bluetooth panels** — saved/available split, larger 44px tap targets, scan toggle, BT pair flow.
- **GTK Dark Mode toggle** — one-tap atomic sync of `gsettings` + GTK3/4 `settings.ini` + libadwaita.
- **Two new built-in themes** — *Modori Dark* (midnight indigo · bone white · persimmon) and *Modori Light* (washi cream · sumi ink · persimmon).
- **Paired procedural wallpapers** — an imperfect enso (zen calligraphic circle) with a small persimmon dot inside marking "home", and a faint **戻** kanji watermark in the lower-right.
- **Persimmon accent** — `#e87554` carried through every surface (bar, control panel, settings, calendar).
- **Bulletproof sidebar user labels** — env-fallback resolution, no more empty `$USER`.
- **Settings persistence fixes** — debounced 200ms save so rapid slider drags no longer corrupt `panel-state.json`. Module Shape / Bar Opacity / Bar Corner Radius now persist correctly across restarts.

### Bundled patches

| Patch    | What it fixes                                                                                                                     |
|----------|-----------------------------------------------------------------------------------------------------------------------------------|
| `.10`    | Modori baseline release                                                                                                           |
| `.11`    | WiFi route-metric preference (wifi wins over LAN on user-tap), `preventStealing` on row taps, open-network parser fix, action exit refresh + stderr logging |
| `.12`    | Critical one-line restore of a recursive helper that was silently breaking every WiFi/BT/audio toggle                             |

---

## Quick Install

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development

# Pin to the exact tag for reproducibility
git checkout v6.16.4.12.9.10

# Or stay on main for the latest patch level (.11, .12, ...)
# git checkout main

./install.sh --bootstrap
```

**Tag:** [`v6.16.4.12.9.10`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/v6.16.4.12.9.10) · **Branch:** [`main`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/main)

> **Tip:** checkout the tag for an exact pin, or stay on `main` for the freshest patches as they land.

### Requirements

- **Arch Linux** or **CachyOS** (other distros may work but aren't officially tested)
- **Hyprland ≥ 0.54** (uses `0.54+` syntax exclusively — `layerrule = blur on, match:namespace x` and `windowrule = float true, match:title ^(x)` formats; no deprecated `windowrulev2` or block-style `layerrule {}`)
- **Quickshell ≥ 0.2.1**
- AMD Ryzen + Radeon (recommended — extensively tested on `Ryzen 9 5950X` + `RX 6800 XT`)

---

## Alpha · *Coming soon*

There's no active alpha cycle right now. Modori (戻り) is the new stable, just promoted.

The work that was queued behind Tategaki will pick up under a **new codename** once the first commit lands. Likely candidates from the roadmap:

- Wrong-password feedback on WiFi connect failures
- "Connect automatically" checkbox per network
- WPA-Enterprise (802.1X) support
- Confirm dialogs for destructive actions (forget network, unpair device)
- Auto-rescan WiFi while picker is open
- Bluetooth audio sink routing (route audio to a paired BT device with one tap)
- **Tategaki redux** — vertical bar, properly staged this time
- Plugin system v2

> **Watch the repo** for the next `alpha-v6.16.4.12.10.x` (or similar) branch when the cycle starts.

---

## Lineage

Modori is the latest in a long line of zen-named releases. **Wala tayong babawasan** — every era preserved.

```
Wakaba (若葉)         Alpha v0.91         · Genesis · bare Waybar + Python
Koke   (苔)           Alpha v2.x          · Legacy · GTK4 / Libadwaita era
Yugen  (幽玄)         v6.10 → v6.14       · Rewrite · GTK → Quickshell QML
Ensō   (円相)         v6.15.x → v6.16     · Unified · the circle closes
Ma     (間)           v6.16.1.x           · Refinement · cascade Control Panel
Shibui (渋い)         v6.16.2.3.x         · Refinement · click-through fixes
Sabi   (寂)           v6.16.3.x           · Refinement · Lock screen, PowerBadge
Kintsugi (金継ぎ)     v6.16.4.x → .11.2   · Stable predecessor · gold in seams
Hikari  (光)          v6.16.4.12.5 → .6.53 · Interlude · illumination + plugins
Tsubasa (翼)          v6.16.4.12.6.40     · Interlude · Hyprland plugin manager
Hiraki  (開き)        v6.16.4.12.6.52-.53 · Interlude · click-to-open triggers
Tachiagari (立ち上がり) v6.16.4.12.7 → .7.1 · Interlude · the proven base
Tategaki (縦書き)     v6.16.4.12.8.x      · ROLLED BACK · vertical-bar attempt
─────────────────────────────────────────────────────────────────────────────
Modori (戻り)         v6.16.4.12.9.10     · ★ CURRENT STABLE ★
```

**Future:** *Michi (道)* — the way · the path — in-app Updates Manager, planned for v6.16.5.

---

## Architecture

Zen Shell is built on the following stack:

- **[Quickshell](https://quickshell.outfoxxed.me/)** — QML-native shell framework for Wayland
- **QML / Qt 6** — declarative UI, fragment shaders for circular masking, custom delegates
- **Hyprland 0.54+** — compositor (no other compositor supported)
- **Custom singletons** for state — `PanelState`, `ThemeState`, `WallpaperState`, `BluetoothState`, `WiFiState`
- **No external IPC** — components communicate via QML signals + singletons (PanelState bypasses IPC for the calendar toggle, for example)

### Key design rules

- Hyprland 0.54+ syntax **only**. No deprecated `windowrulev2` or old block-style `layerrule {}`.
- Singletons for state — never `Component.onCompleted: somethingGlobal = x` to share state.
- Fragment shaders for circular masking — avoid `OpacityMask` where shaders are cleaner.
- `PanelState` singleton drives the calendar toggle directly (bypassing Hyprland IPC for snappy response).
- `parent.parent.width` is unreliable inside `Flickable` / `ScrollView` — use a ref to the outer item instead.
- Overlay `Rectangle`s must be **siblings**, not children, of layouts — `RowLayout` / `ColumnLayout` will fight a child overlay's anchors.
- `hyprctl reload` wipes runtime keyword state — anything set via runtime `hyprctl keyword` must be re-applied after a reload.

---

## Themes

Modori ships with **21 built-in themes** including the new pair:

- **Modori Dark** — midnight indigo (`#0e0f1a` / `#1a1c28`) · bone white (`#f0e8d8`) · persimmon (`#e87554` / `#f08868`) · sage (`#98b283`)
- **Modori Light** — washi cream (`#f5ede0` / `#ebe1d0`) · sumi ink (`#1a1a1a`) · persimmon (`#e87554` / `#c95a3c`) · sage (`#7A9068`)

The full Kintsugi-era theme set is preserved. Custom user themes drop into `~/.config/zen-shell/themes/` and are auto-validated against the smart-contrast engine on import.

---

## Demo Gallery

See the live captures from Modori running on Hyprland 0.54+:

→ **[Browse the full Modori folder on GitHub](https://github.com/Gekinzen/images-demo/tree/main/zen_6_16_4_12_9_3)**

A dedicated Modori walkthrough video is on the way. In the meantime, the existing showcases still apply (most of the UI surfaces are unchanged — Modori just adds the smart-contrast engine, in-shell password prompt, and WiFi+BT redesign on top):

- 🟢 **[Hikari Release Showcase](https://www.youtube.com/watch?v=nS2L9dIQbF4)** — most recent video (v6.16.4.12.5)
- [Full Tour · v6.15.x (Ensō)](https://www.youtube.com/watch?v=dNwGRBhA97g)
- [Zen Shell v6.14 (Yugen)](https://www.youtube.com/watch?v=YQxrh5_naMQ)
- [Zen Shell v6.10 (Yugen foundations)](https://www.youtube.com/watch?v=ao89J3DEqiA)

---

## Project Site

A full visual site lives at **[gekinzen.github.io/zen-shell-site](https://gekinzen.github.io/zen-shell-site/)** — hero, demo gallery, codename history, install, and the complete project archive.

---

## Branch Naming Convention

- **Stable:** `main` (always tracks the latest stable patch level)
- **Stable tags:** `v6.x.x.x` — e.g. `v6.16.4.12.9.10`
- **Beta branches:** `beta-v12.x.x.x.xx` — e.g. `beta-v12.6.16.1.11`
- **Alpha branches:** `alpha-v6.x.x.x.x` — e.g. *(next cycle TBA)*

Beta branches strip down to `v6.x.x.x` on official release.

---

## Roadmap

### Modori patch line (current)
- ✅ `v6.16.4.12.9.10` — stable release with bundled `.11` + `.12` patches
- 🔜 Bug fixes and small QoL improvements as needed

### Next alpha cycle (codename TBA)
- WiFi: wrong-password feedback, "Connect automatically" checkbox, WPA-Enterprise (802.1X) support
- UX: confirm dialogs for destructive actions (forget network, unpair device)
- Discovery: auto-rescan WiFi while picker is open, BT scan-while-pairing
- Bluetooth: audio sink routing
- Bar: **Tategaki redux** — vertical bar, properly staged
- Plugin system v2

### Future (Michi · 道 · v6.16.5)
- In-app Updates Manager
- One-click upgrade flow with rollback

---

## Contributing

Issues and PRs welcome. Before opening one, please check:

1. **Hyprland version** — must be `≥ 0.54`. Older Hyprland will not work.
2. **Quickshell version** — must be `≥ 0.2.1`.
3. **Syntax** — never use `windowrulev2` or old block-style `layerrule {}`. See the **Architecture** section above.
4. **Branch** — file PRs against `main` for fixes; against the active alpha branch for new features.

---

## Credits

- **[Quickshell](https://quickshell.outfoxxed.me/)** by outfoxxed — the QML shell framework that makes Zen Shell possible
- **[Hyprland](https://hyprland.org/)** by vaxerski — the only supported compositor
- **[Literata](https://fonts.google.com/specimen/Literata)**, **[JetBrains Mono](https://www.jetbrains.com/lp/mono/)**, **[Noto Serif JP](https://fonts.google.com/noto/specimen/Noto+Serif+JP)** — typography
- All the alpha testers who survived the Tategaki rollback 🙏

---

## License

MIT · Crafted in Antipolo, Philippines · 戻り

---

<p align="center">
  <a href="https://github.com/Gekinzen/zen_barebone_alpha_development">GitHub</a> ·
  <a href="https://gekinzen.github.io/zen-shell-site/">Project Site</a> ·
  <a href="https://buymeacoffee.com/zenpy">☕ Buy a coffee</a>
</p>
