# Zen Shell v6.15.15 — Patch Changelog

**Release date:** 2026-04-20
**Base:** v6.15.14 (QML complete, but scripts + hypr modules + hardware-specific env still missing)

**Scope:** Third-pass packaging fix that also makes the installer
**truly one-command smart**. Auto-detects missing dependencies and
auto-runs bootstrap when needed. Auto-detects GPU topology and
writes hardware.conf tailored to the machine. Everything shipped is
real content from a working production install — no stubs, no
placeholders.

No QML changes. All 68 QML files identical to v6.15.14.

---

## New — One-command smart install

`./install.sh` is now genuinely one-size-fits-all. No more `--bootstrap`
flag required. The installer:

1. **Auto-detects missing critical dependencies** — the 11 things without
   which Zen Shell cannot function:
   - `hyprland`, `hyprctl` (compositor + CLI)
   - `quickshell` (QML runtime)
   - `jq` (JSON tooling)
   - `grim`, `slurp`, `wl-copy` (screenshot + clipboard)
   - `swww` or `swww-daemon` or `awww` (wallpaper)
   - `cava` (audio visualizer for music strings)
   - `playerctl` (MPRIS for music module)
   - `notify-send` (runtime notifications)

2. **Auto-runs bootstrap.sh** if any of these are missing, with user
   confirmation (`[Y/n]` prompt, defaults to yes after 60s timeout).

3. **Proceeds straight to install** if everything's already there —
   no interruption, no prompts.

### Flag reference

| Flag | Behavior |
|---|---|
| (none) | **Smart default** — auto-detect, prompt to bootstrap if needed |
| `--bootstrap` / `-b` | Force bootstrap to run even if deps present (full reinstall) |
| `--no-bootstrap` | Skip auto-detection (for custom setups managing their own Hyprland) |
| `--help` / `-h` | Show usage |

### Migration from old behavior

| Old command | New equivalent |
|---|---|
| `./install.sh --bootstrap` on fresh laptop | `./install.sh` (auto-prompts to bootstrap) |
| `./install.sh` on existing setup | `./install.sh` (unchanged — proceeds directly) |
| Force reinstall of system deps | `./install.sh --bootstrap` (still works) |

---

## What v6.15.14 missed

v6.15.14 closed the QML gap, but a fresh ROG install still left the
shell half-configured:

- OpenRGB didn't auto-restore profiles on login
- Screenshot overlay called a helper that wasn't installed
- Hyprland ran with whatever defaults the user had hand-rolled —
  Zen Shell's animations, autostart, and general/decoration settings
  were never shipped
- Multi-GPU machines (like an ROG Strix with Ryzen iGPU + RTX 3060)
  had no guidance — users had to manually write AQ_DRM_DEVICES, NVIDIA
  env vars, and cursor settings

v6.15.15 fixes all four.

---

## New — Smart hardware detection

**The headline feature.** `install.sh` now runs a hardware-detection
pass before installing anything and generates a
`~/.config/hypr/modules/hardware.conf` file tailored to the detected
machine.

What it detects:

| Detection | How |
|---|---|
| GPU count & vendors | `lspci -nn` filtered by VGA / 3D / Display controller |
| DRM render nodes | `/dev/dri/card[0-9]*` enumeration |
| Primary GPU (multi-GPU case) | Discrete NVIDIA preferred via `udevadm` vendor query, falls back to card0 |
| CPU vendor | `/proc/cpuinfo vendor_id` |
| Session type | `$XDG_SESSION_TYPE` |
| NVIDIA DRM modeset status | `/sys/module/nvidia_drm/parameters/modeset` |

What it writes to `hardware.conf` (tailored per detection):

**Multi-GPU systems (iGPU + dGPU):**
```
env = AQ_DRM_DEVICES,<primary>:<secondary>
```
Hyprland renders on the primary (typically NVIDIA dGPU on laptops),
and imports via DMA-BUF from the secondary. This fixes the common
Optimus-style laptop bug where Hyprland would pick the wrong GPU.

**NVIDIA systems:**
```
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
cursor { no_hardware_cursors = true }
```

**AMD-only systems:**
```
env = AMD_VULKAN_ICD,RADV
env = RADV_PERFTEST,aco
```

**Intel systems:**
```
env = LIBVA_DRIVER_NAME,iHD
```

**Universal (always written):**
```
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland;xcb
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1
misc { vrr = 2 }
```

### Preserve-if-exists (critical)

`hardware.conf` is **only generated if it doesn't already exist**. On
upgrade, your customizations are never overwritten. If you want to
regenerate it, delete it first and re-run `install.sh`.

### Diagnostic warnings

If NVIDIA is detected but `nvidia_drm.modeset=1` is not enabled, the
installer prints a visible warning before proceeding. Hyprland on
NVIDIA without KMS modeset causes flicker and crashes — catching this
at install time prevents a confusing first boot.

---

## Files added (6 + hardware.conf runtime-generated)

### scripts/ — 3 new helpers

| File | Lines | Role |
|---|---|---|
| `openrgb-autoload.sh` | 7 | Sleeps 5s, reads `~/.config/openrgb/last-profile`, applies it via `openrgb --profile`. No-op if no profile saved. |
| `openrgb-wrapper.sh` | 14 | Wraps `/usr/bin/openrgb`. Auto-saves the profile name to `~/.config/openrgb/last-profile` whenever one is set. |
| `zen-screenshot-capture.sh` | 155 | Full grim → ImageMagick composite (for annotation SVGs) → wl-copy / save pipeline. Called from `ZenScreenshotOverlay.qml` Copy/Save actions. Logs to `/tmp/zen-screenshot.log`. |

### hypr-config/ — 3 new Hyprland modules

| File | Lines | Role |
|---|---|---|
| `animations.conf` | 19 | HyDe Diablo-2 preset — `wind` / `overshot` / `liner` beziers, popin windows, slidevert workspaces, loop borderangle. |
| `autostart.conf` | 25 | dbus-update → systemd import-environment → polkit-gnome → swww-daemon → swaync → cliphist (text + image) → quickshell. |
| `look_and_feel.conf` | 43 | Tokyo Night borders, 5/10 gaps, 12px rounding, 3-pass blur, shadows, dwindle layout, touchpad tuning. |

### install.sh — Smart generation

Generates `~/.config/hypr/modules/hardware.conf` on first install
(tailored to detected GPU topology).

---

## Install semantics

**Scripts** (`openrgb-*.sh`, `zen-screenshot-capture.sh`) are **always
overwritten** at `~/.local/bin/` — they are code, not config. Upgrades
pick up bug fixes automatically.

**Hypr modules** (`animations.conf`, `autostart.conf`,
`look_and_feel.conf`, `hardware.conf`) are **only installed if they
don't already exist** at `~/.config/hypr/modules/`. Custom edits
survive forever. Output on upgrade:

```
[6/9] Hyprland configs...
    binds.conf
    keybinds-update.conf (v6.15: carried from v6.14)
    hyprland-layer-rules.conf (v6.15: carried from v6.14)
    animations.conf (already exists — preserved)
    autostart.conf (already exists — preserved)
    look_and_feel.conf (already exists — preserved)
```

### hyprland.conf source = lines (auto-wired)

The installer appends any missing `source = ~/.config/hypr/modules/
<n>.conf` lines to `~/.config/hypr/hyprland.conf` using `grep -q`
guards — existing entries are never duplicated.

After a fresh install:

```conf
# ── Added by Zen Shell installer (hardware detection) ──
source = ~/.config/hypr/modules/hardware.conf

# ── Added by Zen Shell installer ──
source = ~/.config/hypr/modules/binds.conf
source = ~/.config/hypr/modules/animations.conf
source = ~/.config/hypr/modules/autostart.conf
source = ~/.config/hypr/modules/look_and_feel.conf
source = ~/.config/quickshell/zen-shell/config/keybinds-update.conf
source = ~/.config/quickshell/zen-shell/config/hyprland-layer-rules.conf
```

---

## Multi-GPU case study — ROG Strix (Ryzen 6800 iGPU + RTX 3060)

Without `AQ_DRM_DEVICES`, Hyprland picks `/dev/dri/card0` by default,
which on most ROG laptops is the AMD iGPU. The display is wired to
the iGPU (via MUX), so this works superficially — but discrete GPU
acceleration (CUDA, NVENC, heavy 3D) silently falls back to the iGPU
and users see weak performance without knowing why.

v6.15.15's detection notices **two GPUs + NVIDIA present** and writes:

```
env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
                      (NVIDIA)       (AMD iGPU)
```

Hyprland then renders on the RTX 3060, and the compositor uses
DMA-BUF to import the framebuffer to the iGPU-connected panel. CUDA
workloads, games, and anything that hits `nvidia-smi` now see the
expected GPU.

Users on a single-GPU laptop (e.g. desktop with pure RTX, or any
Thinkpad with just Intel) get the lean path — the multi-GPU block is
skipped entirely, keeping their config clean.

---

## Files changed

```
scripts/openrgb-autoload.sh          NEW (real, from working install)
scripts/openrgb-wrapper.sh           NEW (real, from working install)
scripts/zen-screenshot-capture.sh    NEW (real, from working install)
hypr-config/animations.conf          NEW (real, from working install)
hypr-config/autostart.conf           NEW (real, from working install)
hypr-config/look_and_feel.conf       NEW (real, from working install)
hypr-config/binds.conf               UPDATED (real, from working install)
install.sh                           Hardware detection block added
                                      (GPU enumeration, hardware.conf
                                      auto-generation, source-line wiring)
bootstrap.sh                         Version banner bump → v6.15.15
```

---

## Verification on the ROG

```bash
cd zen-shell-v6.15.15
./install.sh

# Check hardware detection output:
cat ~/.config/hypr/modules/hardware.conf
# Should show:
#   Detected: GPU count: 2, vendors: AMD NVIDIA
#   env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
#   env = LIBVA_DRIVER_NAME,nvidia
#   ... etc

# Reload Hyprland
hyprctl reload

# Confirm NVIDIA rendering
hyprctl systeminfo | grep GPU
nvidia-smi
```

---

## Migration paths

### Fresh install (brand new system)
```bash
cd zen-shell-v6.15.15
./install.sh --bootstrap
```
Hardware detection runs. All 6 new files land. hyprland.conf fully wired.

### Upgrade from any v6.15.x
```bash
cd zen-shell-v6.15.15
./install.sh
```
- Scripts overwrite (they're code)
- Hypr modules preserved if they exist
- `hardware.conf` generated if missing
- No surprises

### Regenerate hardware.conf
```bash
rm ~/.config/hypr/modules/hardware.conf
./install.sh
```

---

## Lesson (third and final time)

v6.15.13 / v6.15.14 / v6.15.15 all had the same root cause: **the
release tarball was built from a curated subset instead of the actual
working install.**

- v6.15.13: assumed the curated subset was complete
- v6.15.14: caught the 12 missing QML files
- v6.15.15: caught the 6 missing scripts + hypr modules AND added
  hardware detection so users don't have to hand-roll multi-GPU env vars

The canonical source of truth is the live working install. Future
releases will include a `release-check.sh` that diffs a reference
install against the packaged tarball and halts if any referenced
file is missing.
