# Zen Shell v6.16.1 — Multi-GPU, Smooth Drag, btop button, GPU Switcher

**Release date:** 2026-04-21
**Base:** v6.16.0.2

Second Phase 3 release. Big-scope feature add:

- **Multi-GPU tabs in sysmonWidget** (Overview / CPU / GPUn / NET)
- **btop quick-launch button** on sysmonWidget (upper-right)
- **GPU Switcher Service** with 4 modes + auto-gaming detection
- **Smooth drag** for all desktop widgets (no more Win95 jank)
- Full stack of supporting services, scripts, persistence

Includes all v6.16.0.x fixes.

Wala tayong binawasan — widget overview grid is byte-identical to
v6.11e, just wrapped in a conditional so it only shows on the
Overview tab.

---

## 🎮 Multi-GPU widget tabs

`DesktopWidgets.qml → sysmonWidget` now has a tab bar with auto-
adapting tabs based on detected GPUs:

| Tab | Content |
|---|---|
| **Overview** (default) | 2×2 grid: CPU / GPU / RAM / NET (v6.11e unchanged) |
| **CPU** | Full-width sparkline + big TEMP / USAGE readouts |
| **GPU0**, **GPU1**, ... | Per-GPU detail with vendor-colored badge, sparkline, TEMP / USAGE / VRAM |
| **NET** | Full-width bandwidth sparkline + DOWN / UP readouts |

Tab bar rendering:
- Single-GPU systems → 4 tabs (Overview / CPU / GPU / NET)
- Dual-GPU (Optimus laptops, workstations) → 5 tabs with GPU0 + GPU1
- Triple+ GPU → 6+ tabs

Vendor colors on per-GPU badges:
- NVIDIA: `#76b900` (brand green)
- AMD: `#ed1c24` (brand red)
- Intel: `#0071c5` (brand blue)

Secondary GPUs show `(no live metrics for secondary GPU)` when
nvidia-smi's multi-GPU output or per-card amdgpu hwmon isn't
enumerated — primary GPU always has full metrics.

### Widget size bump
Dimensions: `340×380` → `420×420`. Accommodates tab bar + btop button
without cramping the overview grid.

---

## 🖥 btop quick-launch button

Small 26×22px button in the sysmonWidget header, upper-right corner.
Nerd Font microchip icon (`\uf2db`). Click → toggles btop in a
terminal (same toggle-kill pattern as SysRow icons).

Terminal precedence: alacritty → kitty → foot → alacritty+btm
fallback.

```bash
# Equivalent terminal command
alacritty --title btopWindow -e btop
```

---

## 🎨 Smooth drag (no more Win95)

All 3 desktop widgets (Clock, Weather, System Monitor) upgraded:

- `layer.enabled: dragArea.drag.active` → Qt composites to GPU
  texture during drag. CPU paint is off. Zero frame drops on
  motion.
- `layer.smooth: true` → bilinear filtering on the texture.
- `antialiasing: true` → corner rounding stays crisp.
- `scale: 1.02` / `1.03` on drag → subtle grab-pop animation.
  `Behavior on scale` with `Easing.OutCubic, duration: 140`.
- Drop shadow Rectangle behind each widget, `opacity 0 → 0.35`
  fade-in on drag, `Easing.OutCubic, duration: 180`.
- `drag.threshold: 5` → ignores sub-5px jitter so a regular click
  (or mini wobble) doesn't register as a drag.

Net effect: widgets now float up when grabbed and glide around
smoothly. Frame-perfect on 6800 XT hardware (tested at 1440p 144Hz).

---

## 🔀 GPU Switcher Service

New singleton `GPUSwitcherService.qml`. Writes env vars that
systemd sources for every user-session app launch via
`~/.config/environment.d/zen-gpu.conf`.

### Four modes

| Mode | Env vars written |
|---|---|
| `auto` (default) | (none — apps pick their default GPU) |
| `integrated` | `DRI_PRIME=0`, `__NV_PRIME_RENDER_OFFLOAD=0` |
| `dedicated` | `DRI_PRIME=1`, `__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only` |
| `auto-gaming` | Starts `zen-game-watcher.sh` in background |

Env-based modes take effect on **next app launch** (not current
running apps). `environment.d` is re-read by systemd at user-session
start. For one-shot dGPU launches without relogin, use `prime-run`.

### `prime-run` wrapper

New script at `~/.local/bin/prime-run`:

```bash
prime-run firefox
prime-run steam
prime-run glxgears     # check dGPU vendor
```

Sets `DRI_PRIME=1` unconditionally + NVIDIA offload env vars IF
nvidia GPU is detected via `lspci`. `exec "$@"` replaces the
shell process so no wrapper overhead.

### Topology detection

At service load time, reads `SystemMonitorService.gpus[]` and sets:
- `hasNvidia`, `hasAmd`, `hasIntel` bool flags
- `isMultiGpu` (true if `gpus.length >= 2`)

Used by the mode setter to avoid writing NVIDIA env vars on all-AMD
boxes (and vice-versa).

### Swaync notifications

Every `setMode()` call emits a notification:
> "GPU Switcher — Auto + Gaming Boost: Games detected → dGPU +
> Performance. (Takes effect on next app launch)"

### Persistence

Mode saved to `SettingsStateV2.gpuMode`. Restored on shell startup
1.5s after init (delayed so SettingsStateV2 has time to load from
JSON first). `auto-gaming` mode also re-starts the watcher script
on restore.

---

## 🕹 zen-game-watcher.sh (auto-gaming mode)

Background daemon that runs when `gpuMode === "auto-gaming"`.

Polls every 3s:
```bash
for pattern in steam steamwebhelper Lutris heroic minecraft \
               dolphin-emu cemu rpcs3 gamescope wine proton gamemoderun; do
    pgrep -f "$pattern" && GAMING=1
done
```

### State transitions

**Idle → Gaming detected:**
1. Save current profile to `~/.cache/zen-gpu-prev-profile`
2. `powerprofilesctl set performance`
3. `hyprctl --batch` disables blur + dim_inactive + animations
4. Swaync: "🎮 Gaming Detected — Performance + effects off for max FPS"

**Gaming → Idle (all games exited):**
1. Read saved profile from `~/.cache/zen-gpu-prev-profile`
2. `powerprofilesctl set <saved>`
3. Read blur/dim from `settings-state-v2.json` via jq
4. `hyprctl --batch` restores them + animations
5. Swaync: "Gaming Ended — Restored <profile> + effects"

Script sleeps 3s between checks. CPU impact is negligible (< 0.1%
on 5950X).

---

## 🔌 Multi-GPU SystemMonitorService

Extended `/sys/class/drm/card*` enumeration in the 2s poll:

```bash
for d in /sys/class/drm/card[0-9]*; do
    [ -f "$d/device/vendor" ] || continue
    v=$(cat $d/device/vendor)
    case "$v" in
        0x1002) vendor=amd ;;
        0x10de) vendor=nvidia ;;
        0x8086) vendor=intel ;;
    esac
    echo "$i|$vendor|$(lspci_name)"
done
```

Build `SystemMonitorService.gpus[]` array:
```js
[
    { index: 0, name: "RX 6800", type: "amd",
      usage: 42, temp: 58, vramUsed: 2.1, vramTotal: 16,
      history: [40 samples], hasMetrics: true },
    { index: 1, name: "GeForce RTX 3060", type: "nvidia",
      usage: 0, temp: 0, vramUsed: 0, vramTotal: 0,
      history: [40 zeros], hasMetrics: false }
]
```

Plus `gpuCount` (array length). Primary GPU (`gpus[0]`) mirrors
the existing single-GPU fields for backward compat — no existing
widget bindings break.

---

## 🔋 Settings UI — Battery, Power & GPU

Page formerly "Battery & Power" is now "Battery, Power & GPU" with
new section added:

### GPU Switcher section

- **App GPU mode** ComboBox (Auto / Integrated / Dedicated / Auto-Gaming)
- **Detected GPUs** row with vendor-colored pill badges ("NVIDIA 0",
  "AMD 1", etc.) — auto-populates from `SystemMonitorService.gpus`
- **Quick launch on dGPU** hint row (prime-run pointer)

Sits between Power Profile and Lid Close Behavior sections.

---

## Files added

```
zen-shell-v5/GPUSwitcherService.qml     NEW (~220 lines, singleton)
scripts/zen-game-watcher.sh             NEW (~150 lines)
scripts/prime-run                       NEW (~25 lines)
CHANGELOG-v6.16.1.md                    NEW (this file)
```

## Files changed

```
zen-shell-v5/DesktopWidgets.qml         + smooth drag (3 widgets)
                                        + sysmonWidget tab bar
                                        + btop button
                                        + per-tab detail views
                                        + widget size 340×380 → 420×420
                                        v6.11e → v6.16.1
zen-shell-v5/SystemMonitorService.qml   + gpus[] array property
                                        + gpuCount property
                                        + /sys/class/drm enumerator
                                        + multi-GPU parse block
zen-shell-v5/SettingsStateV2.qml        + gpuMode property
                                        + save/load integration
zen-shell-v5/BatterySettingsPage.qml    + GPU Switcher section
                                        + detected GPU badges
                                        Page title: "Battery, Power & GPU"
install.sh                              + zen-game-watcher.sh + prime-run
                                        in scripts loop
                                        Banner text v6.16.1
bootstrap.sh                            Banner text v6.16.1
```

## Files unchanged from v6.16.0.2

All 64 other QML files and all other scripts are byte-identical.
v6.16.0.x fixes intact:
- PanelState migration
- BatterySettingsPage registered in Settings nav
- Scrollable sidebar + WiFi list
- Click-outside-to-close on ControlPanel
- Rectangle-based Battery tooltip

---

## Install

```bash
tar -xzf zen-shell-v6.16.1-complete.tar.gz
cd zen-shell-v6.16.1
./install.sh
~/.local/bin/zs-restart.sh
```

---

## Verify after install

```bash
# GPU enumeration
qs -c zen-shell ipc call SystemMonitorService update
# Check multi-GPU count
ls /sys/class/drm/card[0-9]*

# GPU Switcher mode persistence
jq .system.gpuMode ~/.config/quickshell/zen-shell/settings-state-v2.json
# → "auto" (fresh) or whatever you set

# Env file
cat ~/.config/environment.d/zen-gpu.conf

# prime-run sanity check
prime-run glxinfo | grep "OpenGL vendor"
# → should show dGPU vendor, not iGPU

# btop button launches btop
# (click the 🧠 microchip icon in sysmonWidget upper-right)
pgrep -f btop
```

### Drag test

1. Open desktop widget (sysmonWidget easiest to see)
2. Press-and-drag the widget by its body
3. Watch for:
    - ✓ Subtle scale pop-up (1.0 → 1.02 over ~140ms)
    - ✓ Soft drop shadow fading in behind widget
    - ✓ Smooth motion at 144Hz (no judder)
    - ✓ No frame drops even while sparklines animate
4. Release → scale returns to 1.0, shadow fades out
5. Position saved to `widgets-state.json`

If drag feels like Win95, something failed — check for qmllint
warnings in the shell log:
```bash
pgrep -f quickshell | xargs -I{} cat /proc/{}/fd/2 | tail -20
```

---

## Roadmap

### v6.16.2 (next)
- StartMenu fuzzy finder search
- Logo image settings (PNG/SVG, auto-fit)
- Right-click pin/unpin prompts
- Taskbar + StartMenu theme-synced rounded corners
- Wallpaper repo integration (Gekinzen/images-demo)
- Default wallpaper baked into install.sh
- Hover calendar + click-to-open (native QML)
