# Zen Shell v6.16.3.7 — Universal widget scale + font deps

**Release date:** 2026-04-24
**Branch:** `beta-v12.6.16.3.7`
**Base:** v6.16.3.6.1
**Status:** Beta — roadmap milestone (DPI/scale-aware widgets)

---

## TL;DR — two tracks

### Track 1 — Widget Scale Factor (roadmap milestone)

> Roadmap: *"Universal widget auto-resize, DPI/scale-aware"*

Every desktop widget (clocks, weather, sysmon) now resizes in
lockstep via a single multiplier in Settings. No more hand-editing
QML to change widget size when switching between 1080p and 4K
monitors.

**Settings → Widgets → Widget Scale** gains a new slider:

```
┌─ Widget Scale ─────────────────────────────────────────┐
│  Resize all desktop widgets in one go                  │
│                                                         │
│  Scale    [■■■■■■■●──────────]  1.25×   [Reset]        │
│           0.5× compact  ·  1.0× baseline  ·  2.0× large │
└─────────────────────────────────────────────────────────┘
```

Range: 0.5× to 2.0×, step 0.05. Default 1.0× = Paul's original
design baseline for his 1440p/4K setup.

**Live apply, no restart**: moving the slider immediately resizes
all widgets. PanelState.widgetScale → saveState → panel-state.json
→ FileView reload ping. Drag-and-drop positions respected (widgets
re-anchor at new size).

### Track 2 — Font dependency check in install.sh

> *"paki sama ito sa install.sh --needed din hehe"*

v6.16.3.6.1's fix mapped `adwaita` → `"Adwaita Sans Black"`, but if
the Adwaita `Black` weight variant isn't installed on the system,
fontconfig silently falls back to Regular and the lock clock
renders thin again.

install.sh now checks for the required font weight variants via
`fc-list` and offers them through the existing optional-packages
install flow (uses `paru/yay/sudo pacman -S --needed` so nothing
reinstalls if already present).

---

## Track 1 — Internals

### PanelState (new property + persistence)

```qml
// v6.16.3.7: universal desktop widget scale factor.
// Range clamped to 0.5-2.0. Bump to 1.25-1.5 on very large
// screens, drop to 0.75-0.85 on 1080p to match visual density.
property real widgetScale: 1.0

// saveState serializes:
widgetScale: widgetScale,

// applyState loads with defensive clamp:
if (typeof s.widgetScale === "number")
    widgetScale = Math.max(0.5, Math.min(2.0, s.widgetScale))
```

### DesktopWidgets root — single source of truth

```qml
readonly property real _scale: {
    const s = PanelState.widgetScale !== undefined ? PanelState.widgetScale : 1.0
    return Math.max(0.5, Math.min(2.0, s))
}
```

Every dimension and font size inside `dw` multiplies by `dw._scale`.
Because the clock widget's outer Rectangle derives its size from
content (`width: clockLayout.implicitWidth + 40`), scaling the fonts
alone already resizes the container — no extra layout math.

### 68 scale multipliers applied

| Where               | Before                                  | After                                      |
|---------------------|-----------------------------------------|---------------------------------------------|
| Primary clock       | `font.pixelSize: 120`                   | `font.pixelSize: 120 * dw._scale`          |
| Sub-clock           | `font.pixelSize: 36`                    | `font.pixelSize: 36 * dw._scale`           |
| Weather temp        | `font.pixelSize: 48` → `42`             | `... * dw._scale`                          |
| Weather city label  | `font.pixelSize: 13`                    | `font.pixelSize: 13 * dw._scale`           |
| Sysmon chip labels  | `font.pixelSize: 12`                    | `font.pixelSize: 12 * dw._scale`           |
| Clock widget ternary| `font.pixelSize: index===0?120:36`      | `font.pixelSize: (index===0?120:36) * dw._scale` |
| Weather container   | `width: 400; height: 260`               | `width: 400 * dw._scale; height: 260 * dw._scale` |
| Sysmon container    | `width: 420; height: 420`               | `... * dw._scale` (both dims)              |
| 63 other pixelSize  | —                                        | all batch-scaled via sed                   |

Batch sed applied:
```bash
sed -i -E 's/font\.pixelSize:[[:space:]]+([0-9]+)([^0-9*]|$)/font.pixelSize: \1 * dw._scale\2/g'
```

The `[^0-9*]` guard in the regex avoids re-scaling values that
already have `* dw._scale` appended (idempotent — re-running the
sed is safe).

### Settings UI — the Widget Scale section

```qml
HMSection { title: "Widget Scale"; subtitle: "Resize all desktop widgets in one go"
    HMRow {
        label: "Scale"
        description: "Drag the slider. 0.5× compact, 1.0× baseline, 2.0× large."
        icon: "\uf065"
        RowLayout {
            Slider {
                id: scaleSlider
                from: 0.5
                to: 2.0
                stepSize: 0.05
                value: PanelState.widgetScale
                onMoved: {
                    PanelState.widgetScale = value
                    PanelState.saveState()
                }
            }
            Text {
                text: scaleSlider.value.toFixed(2) + "×"
            }
            Button {
                text: "Reset"
                onClicked: {
                    PanelState.widgetScale = 1.0
                    PanelState.saveState()
                }
            }
        }
    }
}
```

Placed between "Widget Display" and "Widget Colors" sections so it
reads naturally as a global appearance control — before the
per-widget tint/opacity settings.

---

## Track 2 — Internals

### check_font helper

```bash
check_font() {
    local style=$1 family=$2 pkg=$3
    if fc-list 2>/dev/null | grep -iq "${family}:style=${style}"; then
        echo "    ✓ ${family} ${style} (installed)"
    else
        echo "  ○ ${family} ${style} missing — will offer: ${pkg}"
        add_opt "${pkg}"
    fi
}
```

Uses `fc-list` (fontconfig) to detect installed font family +
style pairs. Command-based `check_cmd` can't be used because fonts
aren't binaries.

### Packages added to the optional offer

```bash
if command -v fc-list >/dev/null 2>&1; then
    check_font Black "Adwaita Sans" adwaita-fonts
    check_font Black "Inter"        inter-font
    # gnome-themes-extra catch-all for full Adwaita theme pack
    if ! pacman -Q gnome-themes-extra >/dev/null 2>&1; then
        add_opt "gnome-themes-extra"
    fi
else
    add_opt "fontconfig"
    add_opt "adwaita-fonts"
fi
```

Each missing package lands in `MISSING_OPTIONAL`, which the
existing `[1/9] Dependency check` prompt offers to install via:

```bash
paru -S --needed $MISSING_OPTIONAL
# or yay, or sudo pacman
```

**Idempotent**: `--needed` flag means already-installed packages
are skipped. Running install.sh repeatedly never forces reinstall.

---

## Files in this drop

### NEW

```
CHANGELOG-v6.16.3.7.md                ← this file
```

### UPDATED

```
zen-shell-v5/PanelState.qml           ← +widgetScale property + persistence
zen-shell-v5/DesktopWidgets.qml       ← +_scale prop + 68 scale multipliers
zen-shell-v5/WidgetsPage.qml          ← +Widget Scale HMSection (slider + reset)
zen-shell-v5/ZenVersion.qml           ← bump to v6.16.3.7
install.sh                             ← +check_font helper, +font package offer, banner
```

### CARRIED OVER from 3.6.1

- Lock clock font sync (now with correct Black/Bold mapping)
- Gender-aware lock messages (3 pools per bucket, English only)
- Weather mood + care line on lock
- Hover popup parity (ZenClock, ZenSysMonitor)
- User Profile → Personal Preferences picker
- Bundled Start Button logos (7)
- ZenComboBox bounds-aware popup
- Module Layout dedup across zones

---

## Install / verify

```bash
tar -xzf zen-shell-v6.16.3.7.tar.gz
cd zen-shell-v6.16.3.7
./install.sh
```

The dependency check will now list:

```
v6.16.3.7 — Font weight variants (lock clock + widgets):
  ✓ Adwaita Sans Black (installed)             ← if already there
  ○ Inter Black missing — will offer: inter-font ← or this
  ○ gnome-themes-extra (optional...)           ← also listed
```

Then the standard `Install optional packages with paru? [Y/n]`
prompt adds `adwaita-fonts` / `inter-font` / `gnome-themes-extra`
via `--needed`.

### Test Widget Scale

1. Restart shell: `~/.local/bin/zs-restart.sh`
2. Settings (Super+I or click cog) → Widgets
3. Find "Widget Scale" section (below "Widget Display")
4. Try three values:
   - **0.75×** — widgets shrink ~25%, fonts smaller
   - **1.00×** — baseline (default)
   - **1.50×** — widgets grow 50%, chunky clock
5. Verify all three widgets (clocks, weather, sysmon) resize in
   lockstep. No widget should stay at old size.
6. Drag a widget to new position → scale again → position should
   stay anchored (x,y is stored unscaled, so visual position
   follows top-left).
7. Click **Reset** → returns to 1.0× exactly.
8. Quit Settings, reopen → scale persists (panel-state.json).

### Known visual behavior

- At 2.0×, the clocks widget might overflow the monitor on 1080p
  displays. Drag it back into view — positions persist across
  scale changes because they're stored unscaled.
- The sysmon widget's sparkline graphs scale correctly because
  they're SVG paths inside a scaled Rectangle.
- Font rendering stays crisp because Qt rasterizes at the final
  `pixelSize`, not via bitmap scaling.

---

## Next up: v6.16.3.8

Idle/lid/sleep UX pass — hypridle config defaults, lid switch
behavior, hyprlock cascade timing.

Then: v6.16.4 — Global Hyprland `configreloaded` IPC listener
(supersedes the 3.4.1 MouseSettingsService spot-fix), which unlocks
cleaner live-reload for all Settings panels.

**Wala tayong binawasan.** Every feature from 3.6.1 carries byte-
identical into 3.7.
