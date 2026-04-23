# Zen Shell v6.16.3.5 — Start Menu logo picker

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.5`
**Base:** v6.16.3.4.6
**Status:** Beta — feature milestone (promotes out of the 3.4.x hotfix series)

---

## TL;DR

> *"Start Menu logo image picker — make it sure yung default natin na
>   meron lage Arch and Cachyos logo ah"*

The Start Button next to the bar already supported a custom image in
v6.16.2, but the default path was always the Arch distributor icon
(hard-coded), and swapping required an Auto-vs-Custom combo plus a
manual zenity browse. This drop adds:

```
┌─────────────────────────────────────────────────────────────────┐
│  7 bundled SVG logos ship with the shell:                       │
│      arch · cachyos · endeavouros · fedora · ubuntu · nixos ·   │
│      linux (generic penguin fallback)                           │
│                                                                  │
│  3 modes in Settings → Panel:                                   │
│      · auto    — auto-detect via /etc/os-release                │
│      · builtin — pick from visual logo grid (this is the new   │
│                  UI for "I want Arch / CachyOS / …")            │
│      · custom  — user file (v6.16.2 behavior, preserved)        │
└─────────────────────────────────────────────────────────────────┘
```

**Wala tayong binawasan.** The v6.16.2 custom-image picker is intact;
we just added two new modes and a resolver function on PanelState.

---

## What ships

### Bundled SVGs

`zen-shell-v5/assets/logos/` — new directory with:

| File             | Brand color(s)            | Notes                        |
|------------------|---------------------------|------------------------------|
| `arch.svg`       | `#1793D1` (Arch blue)     | Classic triangle silhouette  |
| `cachyos.svg`    | Green gradient            | Rounded shield + stylized C  |
| `endeavouros.svg`| Magenta→purple→blue       | Gradient triangle            |
| `fedora.svg`     | `#294172` (Fedora blue)   | 'f' glyph                    |
| `ubuntu.svg`     | `#E95420` (Ubuntu orange) | Circle of Friends            |
| `nixos.svg`      | `#5277C3` / `#7EBAE4`     | Six-arm snowflake            |
| `linux.svg`      | Black + orange            | Stylized penguin fallback    |

All 128×128 viewBox, `PreserveAspectFit` scaling inside the 26px
Start Button (or whatever size `PanelState.startButtonIconSize` is
set to). SVGs are intentionally simple + stylized — small enough to
stay crisp at any scale without relying on system icon themes.

### install.sh deployment

```bash
LOGOS_SRC="$SCRIPT_DIR/zen-shell-v5/assets/logos"
LOGOS_DST="$HOME/.local/share/quickshell/zen-shell/logos"
mkdir -p "$LOGOS_DST"
cp -f "$LOGOS_SRC/"*.svg "$LOGOS_DST/"
```

Idempotent — runs on every install so bundled-logo updates (e.g. a
better CachyOS rendition in a future drop) land automatically. The
user's custom image path (if they chose `custom` mode) is untouched.

### PanelState additions

```qml
property string startButtonLogoMode: "auto"      // "auto" | "builtin" | "custom"
property string startButtonLogoBuiltinId: "arch" // id into builtinLogos
// startButtonLogoPath, startButtonLogoTint ← carried from v6.16.2

readonly property var builtinLogos: [
    { id: "arch",        label: "Arch Linux", osReleaseIds: ["arch", "archlinux", ...] },
    { id: "cachyos",     label: "CachyOS",    osReleaseIds: ["cachyos", ...] },
    …
]

function resolveStartButtonLogo() {
    // Returns file:// URL for the effective logo, or "" to fall
    // back to Quickshell.iconPath(). Handles all three modes +
    // os-release matching for auto mode.
}
```

Auto-detect logic: reads `UserProfileService.osLogo` (already parsed
from `/etc/os-release` `$LOGO` or `$ID`), matches against each
builtin entry's `osReleaseIds` array. First match wins. No match →
returns empty string so StartMenu falls back to
`Quickshell.iconPath("distributor-logo-<osLogo>")` and finally
`distributor-logo-archlinux`.

### StartMenu.qml — new fallback chain

```
PanelState.resolveStartButtonLogo()
    → if empty: Quickshell.iconPath("distributor-logo-<osLogo>")
    → if that 404s: Quickshell.iconPath("distributor-logo-archlinux")
```

Three-layer defense: user's explicit choice > system icon theme >
hard-coded Arch fallback. Any single failure degrades gracefully to
the next layer instead of showing a broken image icon.

### PanelPage picker UI

New layout under Settings → Panel → Start Button Logo:

```
┌─ Start Button Logo ─────────────────────────────────────────────┐
│  Auto-detect your distro, pick from the built-in set, or use a  │
│  custom image                                                    │
│  [Auto (detect distro)  ▼]   [🔺preview]   matched: CachyOS     │
├─────────────────────────────────────────────────────────────────┤
│  Pick a built-in              (visible when mode = builtin)     │
│                                                                  │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                         │
│  │  🔺  │  │  🛡   │  │  🔻  │  │  ƒ   │                         │
│  │ Arch │  │Cachy │  │Endea │  │Fedora│                         │
│  └──────┘  └──────┘  └──────┘  └──────┘                         │
│  ┌──────┐  ┌──────┐  ┌──────┐                                    │
│  │  🟠  │  │ ❄   │  │ 🐧  │                                    │
│  │Ubuntu│  │NixOS │  │Linux │                                    │
│  └──────┘  └──────┘  └──────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

Selected tile = blue border + tinted fill. Click any tile to swap
the Start Button immediately (no shell restart, no file picker).
Custom mode UI (text input + Browse button + tint toggle) carried
byte-identical from v6.16.2.

---

## Files in this drop

### NEW

```
zen-shell-v5/assets/logos/arch.svg
zen-shell-v5/assets/logos/cachyos.svg
zen-shell-v5/assets/logos/endeavouros.svg
zen-shell-v5/assets/logos/fedora.svg
zen-shell-v5/assets/logos/linux.svg
zen-shell-v5/assets/logos/nixos.svg
zen-shell-v5/assets/logos/ubuntu.svg
CHANGELOG-v6.16.3.5.md                    ← this file
```

### UPDATED

```
zen-shell-v5/PanelState.qml       ← +builtinLogos, +resolver, +2 props
zen-shell-v5/StartMenu.qml        ← 3-mode fallback chain
zen-shell-v5/PanelPage.qml        ← 3-mode picker UI + visual grid
zen-shell-v5/ZenVersion.qml       ← bump to v6.16.3.5
install.sh                         ← deploy logos + banner bump
```

### CARRIED OVER

Everything from v6.16.3.4.6 byte-identical, including:
- ZenComboBox (bounds-aware, flip-up, persistent ScrollBar)
- PowerBadge A+B (install migration + Bar Modules toggle)
- All previous 3.4.x fixes

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.5.tar.gz
cd zen-shell-v6.16.3.5
./install.sh
~/.local/bin/zs-restart.sh
```

### Verify bundled logos deployed

```bash
ls ~/.local/share/quickshell/zen-shell/logos/
# Expected: 7 SVGs (arch, cachyos, endeavouros, fedora, linux, nixos, ubuntu)
```

### Verify auto-detection works

On CachyOS (Paul's distro), Settings → Panel → Start Button Logo:
- Mode set to "Auto" → caption should say `matched: CachyOS`
- Start Button on the bar → should show the green shield (not Arch)

Switch to "Built-in logo":
- Logo grid appears with 7 tiles
- Current selection (CachyOS if you were on auto) is highlighted
- Click Arch → Start Button switches immediately
- Click CachyOS → back to green shield

Switch to "Custom image":
- Grid hides, file input + Browse button appear
- Behavior identical to v6.16.2

### Stress test the fallback chain

Deliberately break auto-mode by editing `/etc/os-release` to have
an `ID` value no builtin matches (e.g. `ID=exoticdistro`). Expected:
- auto mode returns empty from resolveStartButtonLogo()
- StartMenu tries `Quickshell.iconPath("distributor-logo-exoticdistro")`
- If that fails, falls back to `distributor-logo-archlinux`
- No broken image ever shown

### Persistence

Change mode + selection → close Settings → restart shell via
`zs-restart.sh` → confirm selection survived. State lives in
`PanelState` JSON at `~/.local/share/quickshell/zen-shell/panel-state.json`.

---

## Adding a new logo later

1. Drop the SVG in `zen-shell-v5/assets/logos/<id>.svg` (128×128 viewBox
   recommended)
2. Append one entry to `PanelState.builtinLogos`:
   ```qml
   { id: "manjaro",  label: "Manjaro",  osReleaseIds: ["manjaro"] }
   ```
3. Re-run `./install.sh` — the logo grid regenerates with the new tile,
   auto-detect picks it up on Manjaro installs.

No other code changes needed. The resolver, grid, and picker are all
data-driven from the array.

---

## Trademark note

The bundled SVGs are simplified, stylized renditions created for
distro identification in this shell. They are not official logos
and not trademark reproductions — consider them "inspired by" the
respective distro brand palettes and shapes. If you want the
pixel-exact official logos, put them at your chosen path with
`custom` mode (drop them in `~/.local/share/quickshell/zen-shell/logos/`
overwriting the bundled ones — install.sh will reinstate the stylized
versions on next install).

---

## Next up

Post-3.5 roadmap (bar PowerBadge stabilization first, then):

- **v6.16.3.6** — Clock hover popup parity with CPU/Memory hover
- **v6.16.3.7** — Universal widget auto-resize (DPI / scale aware)
- **v6.16.3.8** — Idle / lid / sleep UX
- **v6.16.4** — Global Hyprland configreloaded IPC listener

Phase 4 (Hyprland dark mode + hyprbars + auto-clean memory + window
tile/float policy) still queued after the 3.x series wraps.
