#!/usr/bin/env bash
set -o pipefail 2>/dev/null || true

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SHELL_DIR="$HOME/.config/quickshell/zen-shell"
HYPR_DIR="$HOME/.config/hypr"
GTK_DIR="$HOME/.config/hypr-control-center"
THEMES_BUILTIN="$GTK_DIR/themes/builtin"
THEMES_CUSTOM="$GTK_DIR/themes/custom"
BIN_DIR="$HOME/.local/bin"
TS=$(date +%Y%m%d-%H%M%S)

# ═══════════════════════════════════════════════════════════════
# Flag parsing — --bootstrap / --no-bootstrap / --help
# ═══════════════════════════════════════════════════════════════
# By default (v6.15.15+), install.sh AUTO-DETECTS whether bootstrap
# is needed based on whether the critical dependencies are present.
# The --bootstrap flag FORCES bootstrap to run. The --no-bootstrap
# flag skips the check even if deps are missing (advanced users).
DO_BOOTSTRAP=auto        # auto | force | skip
for arg in "$@"; do
    case "$arg" in
        --bootstrap|-b)    DO_BOOTSTRAP=force ;;
        --no-bootstrap)    DO_BOOTSTRAP=skip ;;
        --help|-h)
            cat <<EOF
Usage: install.sh [OPTIONS]

One command, smart by default:
  ./install.sh          — auto-detects what's needed and does the right thing.
                          Runs bootstrap automatically if Hyprland / Quickshell
                          / critical deps are missing. If everything's there,
                          installs Zen Shell directly.

OPTIONS:
  --bootstrap, -b       Force bootstrap.sh to run first (reinstalls
                        all system deps even if already present).
  --no-bootstrap        Skip auto-detection — go straight to Zen Shell
                        install even if deps are missing. Advanced users
                        who manage their own Hyprland/Quickshell installs.
  --help, -h            Show this help.

EXAMPLES:
  ./install.sh                      # The smart default — works everywhere
  ./install.sh --bootstrap          # Force a full reinstall of system deps
  ./install.sh --no-bootstrap       # Skip auto-bootstrap (custom setups)
EOF
            exit 0
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════
# Critical dependency auto-detection (v6.15.15+)
# ═══════════════════════════════════════════════════════════════
# Zen Shell needs these to actually run. Anything missing triggers
# auto-bootstrap (with user confirmation). The list is intentionally
# minimal — just the things without which the shell literally cannot
# function. Optional deps (cava, flameshot, alacritty, etc.) are
# handled later in the full dependency check where the user can
# pick-and-choose.
CRITICAL_DEPS=(
    hyprland       # the compositor itself
    hyprctl        # Hyprland's CLI — scripts use it
    quickshell     # the QML runtime that runs Zen Shell
    jq             # JSON tooling used by multiple scripts
    grim           # screenshot backend
    slurp          # region selector for screenshots
    wl-copy        # clipboard (from wl-clipboard package)
    swww           # wallpaper daemon (OR swww-daemon)
    cava           # audio visualizer for music strings
    playerctl      # MPRIS control for music module
    notify-send    # for install-time + runtime notifications (libnotify)
)

detect_critical_deps() {
    MISSING_CRITICAL=()
    for dep in "${CRITICAL_DEPS[@]}"; do
        # Special case: swww can be satisfied by swww-daemon OR awww
        if [ "$dep" = "swww" ]; then
            command -v swww >/dev/null 2>&1 && continue
            command -v swww-daemon >/dev/null 2>&1 && continue
            command -v awww >/dev/null 2>&1 && continue
            MISSING_CRITICAL+=("$dep")
            continue
        fi
        if ! command -v "$dep" >/dev/null 2>&1; then
            MISSING_CRITICAL+=("$dep")
        fi
    done
}

run_bootstrap() {
    if [ ! -f "$SCRIPT_DIR/bootstrap.sh" ]; then
        echo "    ✗ bootstrap.sh not found next to install.sh"
        echo "      The full release tarball includes bootstrap.sh — you may"
        echo "      have extracted an incomplete archive. Re-download the full"
        echo "      zen-shell-v6.15.15-complete.tar.gz."
        exit 1
    fi
    echo ""
    echo "    ── Running bootstrap.sh first ──"
    echo ""
    bash "$SCRIPT_DIR/bootstrap.sh" || {
        echo ""
        echo "    ✗ Bootstrap failed or was cancelled. Aborting install.sh."
        exit 1
    }
    echo ""
    echo "    ── Bootstrap complete ──"
    echo ""
}

# ── Decide whether to bootstrap ──────────────────────────────────
if [ "$DO_BOOTSTRAP" = "force" ]; then
    echo ""
    echo "    --bootstrap specified — running bootstrap.sh unconditionally"
    run_bootstrap
elif [ "$DO_BOOTSTRAP" = "skip" ]; then
    echo ""
    echo "    --no-bootstrap specified — skipping auto-detection"
else
    # Auto mode — detect missing critical deps
    detect_critical_deps
    if [ ${#MISSING_CRITICAL[@]} -gt 0 ]; then
        echo ""
        echo "    ── Dependency check ──"
        echo ""
        echo "    Zen Shell needs these but they're not on your system:"
        for dep in "${MISSING_CRITICAL[@]}"; do
            echo "      ✗ $dep"
        done
        echo ""
        echo "    This looks like a fresh install. Running bootstrap.sh will"
        echo "    install these + other system dependencies via paru/yay/pacman,"
        echo "    set up Hyprland, register a Wayland session, and configure"
        echo "    the audio/bluetooth/network stack. Safe to run alongside"
        echo "    KDE/GNOME/COSMIC — does not touch your display manager or"
        echo "    change your default session."
        echo ""
        printf "    Run bootstrap.sh now? [Y/n] "
        if read -r -t 60 BS_REPLY </dev/tty 2>/dev/null; then :; else
            BS_REPLY="y"; echo "(no input — defaulting to yes)"
        fi
        case "${BS_REPLY:-y}" in
            [nN]*)
                echo ""
                echo "    Skipping bootstrap. The install will likely fail at"
                echo "    the dependency check below. To install the missing"
                echo "    packages manually:"
                echo ""
                echo "      paru -S ${MISSING_CRITICAL[*]}"
                echo ""
                echo "    Then re-run ./install.sh"
                echo ""
                ;;
            *)
                run_bootstrap
                # Re-check after bootstrap ran — confirm success
                detect_critical_deps
                if [ ${#MISSING_CRITICAL[@]} -gt 0 ]; then
                    echo "    ⚠ Still missing after bootstrap: ${MISSING_CRITICAL[*]}"
                    echo "      The install will continue but may fail at dep check."
                    echo ""
                else
                    echo "    ✓ All critical dependencies now present. Continuing..."
                    echo ""
                fi
                ;;
        esac
    else
        # All critical deps already present — nothing to say, proceed silently
        :
    fi
fi

echo ""
echo "    Zen Shell v6.16.4.12.6.53"
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Quickshell-native desktop environment for Hyprland."
echo ""
cat << 'ZSCHANGELOG'
    v6.16.4.12.6.20 — Plugins auto-install + Hyprland 0.54+ syntax fix

      [8.7/9] hyprpm auto-install   Auto-installs hyprbars, hyprexpo,
                                    hyprexpo, hyprwinwrap, borders++ via hyprpm if
                                    Hyprland is running. User can opt out
                                    via ZEN_NO_PLUGIN_INSTALL=1. Skipped
                                    if hyprpm not in PATH. Idempotent —
                                    safe to re-run.

      Hyprland 0.54+ syntax fix     `noborder on` (removed PR #12269)
                                    AND `bordersize 0` (no underscore,
                                    invalid) → `border_size 0` per official
                                    0.54 wiki. The earlier two attempts
                                    were both wrong — third time's the
                                    charm. Verified against
                                    wiki.hypr.land/0.54.0/Configuring/
                                    Window-Rules/.

    v6.16.2.3.7 — Single-instance launch (fix double bar on re-install)
    (older changelog truncated for brevity — see CHANGELOG.md)

ZSCHANGELOG
echo ""
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Smart mode (default): auto-detects missing Hyprland/Quickshell"
echo "    and runs bootstrap automatically if needed. Safe alongside"
echo "    KDE, GNOME, or COSMIC."
echo ""

# ═══════════════════════════════════════════════════════════════
# Shared helper — kill ALL zen-shell instances (v6.16.2.3.7)
# ═══════════════════════════════════════════════════════════════
# Kills both invocation styles:
#   (a) qs -c zen-shell             (legacy)
#   (b) quickshell -p .../zen-shell (current)
# SIGTERM up to 3 rounds, escalates to SIGKILL on rounds 4-5,
# then zombie-clears Quickshell IPC sockets so respawn is clean.
# Returns 0 if everything died, non-zero count = surviving PIDs.
_zen_kill_all_shells() {
    local label="${1:-kill}"
    local patterns=( 'qs[[:space:]].*zen-shell' 'quickshell.*zen-shell' )
    local initial=0 attempt pids p

    # Count initial victims for the report line
    for p in "${patterns[@]}"; do
        local n
        n=$(pgrep -f "$p" 2>/dev/null | wc -l)
        initial=$(( initial + n ))
    done

    # Status messages MUST go to stderr — stdout is captured by $() callers
    # for the final survivor count. Mixing them produces shell errors like
    # `[: 0: integer expected` because the caller tries to compare the
    # echo'd "[label] nothing to kill." text as a number.
    if [ "$initial" -gt 0 ]; then
        echo "    [$label] $initial existing zen-shell process(es) found, terminating..." >&2
    else
        echo "    [$label] nothing to kill." >&2
    fi

    # 5 rounds: 3x SIGTERM, then 2x SIGKILL
    for attempt in 1 2 3 4 5; do
        local all_pids=""
        for p in "${patterns[@]}"; do
            pids=$(pgrep -f "$p" 2>/dev/null || true)
            [ -n "$pids" ] && all_pids="$all_pids $pids"
        done
        all_pids=$(echo "$all_pids" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')
        [ -z "$all_pids" ] && break
        if [ "$attempt" -le 3 ]; then
            # shellcheck disable=SC2086
            kill $all_pids 2>/dev/null || true
        else
            # shellcheck disable=SC2086
            kill -9 $all_pids 2>/dev/null || true
        fi
        sleep 0.3
    done

    # Belt-and-suspenders: also pkill -9 for the bare 'qs' executable
    # (covers the rare case where a shell was launched with no path arg).
    pkill -9 -x qs 2>/dev/null || true

    # Clear stale IPC sockets so the next quickshell can claim the id
    rm -rf "/run/user/$(id -u)/quickshell/by-id"/* 2>/dev/null || true

    # Final survivor count — stdout-only, single integer for $() callers
    local survivors=0
    for p in "${patterns[@]}"; do
        local n
        n=$(pgrep -f "$p" 2>/dev/null | wc -l)
        survivors=$(( survivors + n ))
    done
    echo "$survivors"
}

# ═══════════════════════════════════════════════════════════════
# [0/9] Pre-flight: Smart detect + warning
# ═══════════════════════════════════════════════════════════════

echo "    Pre-flight check"
echo ""

EXISTING_INSTALL=0
if [ -d "$SHELL_DIR" ]; then
    QML_COUNT=$(ls "$SHELL_DIR"/*.qml 2>/dev/null | wc -l)
    echo "    Existing install detected: $SHELL_DIR"
    echo "    QML files found: $QML_COUNT"
    EXISTING_INSTALL=1
else
    echo "    Fresh install (no existing config found)"
fi

if [ -d "$HYPR_DIR" ]; then
    echo "    Hyprland config: $HYPR_DIR"
else
    echo "    Warning: $HYPR_DIR not found"
fi

echo ""
echo "    The installer will:"
echo "      1. Back up your entire quickshell/zen-shell directory"
echo "      2. Back up hyprland keybind configs"
echo "      3. Install all QML files ($(ls "$SCRIPT_DIR/zen-shell-v5/"*.qml | wc -l) components)"
echo "      4. Auto-apply ZenClock, ZenWorkspaces, Taskbar"
echo "      5. Install CLI scripts (inc. zen-cava.sh) and themes"
echo "      6. Install Hyprland binds, keybind updates, layer rules"
echo "      7. Migrate strings-state.json to v6.15 schema (if needed)"
echo "      8. Restart qs (single instance — v6.16.2.3.7)"
echo ""

if [ "$EXISTING_INSTALL" -eq 1 ]; then
    echo "    Your current config will be preserved at:"
    echo "      $SHELL_DIR.bak-$TS"
    echo ""

    # Migration notice for users coming from old wing-based strings
    if grep -q "zen-shell-strings-left\|zen-shell-strings-right" "$SHELL_DIR/shell.qml" 2>/dev/null; then
        echo "    ── Migration notice (v6.14.2 → v6.15) ──"
        echo "    Old string wings detected in your shell.qml."
        echo "    v6.15 removes the separate PanelWindow wings."
        echo "    String is now the music module itself — same slot,"
        echo "    no background, hover tooltip, aligned via mapToItem."
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [0.5/9] Smart hardware detection (v6.15.15+)
# ═══════════════════════════════════════════════════════════════
# Detects GPU topology, display server, and CPU vendor. Sets env
# variables that get baked into the user's Hyprland config so that:
#   - Multi-GPU systems (e.g. RTX 3060 + Ryzen iGPU, Intel + NVIDIA
#     Optimus laptops) render Hyprland on the right GPU
#   - Pure AMD / Intel / NVIDIA single-GPU systems get the lean path
#   - VRR + hardware cursor settings suit the detected panels
#
# What we DETECT, not what we DECIDE:
#   - We never force a GPU on the user. We set AQ_DRM_DEVICES / env
#     vars with the detected primary render node as a hint.
#   - User can override everything via ~/.config/hypr/modules/
#     hardware.conf (we only WRITE this file if it doesn't exist).

echo ""
echo "    Hardware detection"
echo ""

# ── GPU enumeration via lspci ──────────────────────────────────
GPU_COUNT=0
GPU_VENDORS=""
GPU_NAMES=""
if command -v lspci >/dev/null 2>&1; then
    # VGA compatible controller OR 3D controller (discrete) OR Display controller
    GPU_LIST=$(lspci -nn 2>/dev/null | grep -E 'VGA compatible controller|3D controller|Display controller' || true)
    if [ -n "$GPU_LIST" ]; then
        GPU_COUNT=$(echo "$GPU_LIST" | wc -l)
        while IFS= read -r line; do
            if echo "$line" | grep -iq nvidia;            then GPU_VENDORS="$GPU_VENDORS NVIDIA"
            elif echo "$line" | grep -iq 'amd\|advanced micro devices\|ati'; then GPU_VENDORS="$GPU_VENDORS AMD"
            elif echo "$line" | grep -iq intel;           then GPU_VENDORS="$GPU_VENDORS Intel"
            else                                               GPU_VENDORS="$GPU_VENDORS Unknown"
            fi
            # Extract the chipset name (after the colon, before brackets)
            chip=$(echo "$line" | sed -E 's/.*: (.*) \[.*/\1/' | cut -c1-50)
            GPU_NAMES="${GPU_NAMES}|${chip}"
        done <<< "$GPU_LIST"
    fi
fi

# Normalize vendors list
GPU_VENDORS=$(echo "$GPU_VENDORS" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | sed 's/ $//')

# ── DRM render nodes (preferred modern detection) ───────────────
DRM_NODES=""
PRIMARY_NODE=""
if [ -d /dev/dri ]; then
    for node in /dev/dri/card[0-9]*; do
        [ -e "$node" ] || continue
        if [ -z "$DRM_NODES" ]; then
            DRM_NODES="$node"
        else
            DRM_NODES="$DRM_NODES:$node"
        fi
    done
    # Pick primary: if NVIDIA + (AMD|Intel), prefer the discrete NVIDIA
    # Most users with a discrete GPU want Hyprland rendering on it.
    if echo "$GPU_VENDORS" | grep -q NVIDIA; then
        # Try to find the NVIDIA card specifically
        for node in /dev/dri/card[0-9]*; do
            [ -e "$node" ] || continue
            udev_vendor=$(udevadm info --query=property --name="$node" 2>/dev/null | grep ID_VENDOR_FROM_DATABASE | cut -d= -f2)
            if echo "$udev_vendor" | grep -iq nvidia; then
                PRIMARY_NODE="$node"
                break
            fi
        done
    fi
    # Otherwise just pick card0
    [ -z "$PRIMARY_NODE" ] && PRIMARY_NODE="/dev/dri/card0"
fi

# ── CPU vendor (for possible kernel param hints) ────────────────
CPU_VENDOR=""
if [ -r /proc/cpuinfo ]; then
    CPU_VENDOR=$(grep -m1 '^vendor_id' /proc/cpuinfo | awk '{print $3}')
fi

# ── Session type ───────────────────────────────────────────────
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"

# ── Display Manager detection (for Wayland compat warning) ─────
DM_NAME=""
for dm in gdm sddm lightdm lxdm greetd tuigreet ly entrance; do
    if systemctl is-active --quiet "$dm" 2>/dev/null || \
       systemctl is-active --quiet "${dm}.service" 2>/dev/null; then
        DM_NAME="$dm"; break
    fi
done
[ -z "$DM_NAME" ] && pgrep -l gdm sddm lightdm greetd ly 2>/dev/null | head -1 | awk '{print $2}' | grep -q . && \
    DM_NAME="$(pgrep -l gdm sddm lightdm greetd ly 2>/dev/null | head -1 | awk '{print $2}')"

# ── Connected monitors (via DRM sysfs — works without X/Wayland) ─
MONITOR_COUNT=0
MONITOR_NAMES=""
if [ -d /sys/class/drm ]; then
    for card_dir in /sys/class/drm/card*-*; do
        [ -d "$card_dir" ] || continue
        status_file="$card_dir/status"
        [ -r "$status_file" ] || continue
        if [ "$(cat "$status_file" 2>/dev/null)" = "connected" ]; then
            MONITOR_COUNT=$((MONITOR_COUNT+1))
            mon=$(basename "$card_dir" | sed 's/^card[0-9]*-//')
            MONITOR_NAMES="$MONITOR_NAMES $mon"
        fi
    done
fi
MONITOR_NAMES=$(echo "$MONITOR_NAMES" | sed 's/^ //')

# ── Touchpad / keyboard detection (via libinput or /proc/bus/input) ─
HAS_TOUCHPAD=0
if command -v libinput >/dev/null 2>&1; then
    libinput list-devices 2>/dev/null | grep -iq "touchpad\|trackpad" && HAS_TOUCHPAD=1
elif [ -r /proc/bus/input/devices ]; then
    grep -iq "touchpad\|trackpad" /proc/bus/input/devices 2>/dev/null && HAS_TOUCHPAD=1
fi

# ── Chassis type (laptop vs desktop, useful for power profile) ──
CHASSIS_TYPE="unknown"
if [ -r /sys/class/dmi/id/chassis_type ]; then
    ct=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
    case "$ct" in
        8|9|10|11|14) CHASSIS_TYPE="laptop" ;;
        3|4|5|6|7)    CHASSIS_TYPE="desktop" ;;
        *)            CHASSIS_TYPE="other" ;;
    esac
fi

# ── NVIDIA driver version (for explicit-sync flag) ──────────────
NVIDIA_DRIVER_VER=""
if [ -r /proc/driver/nvidia/version ]; then
    NVIDIA_DRIVER_VER=$(grep -oE 'Kernel Module\s+[0-9]+\.[0-9]+' /proc/driver/nvidia/version 2>/dev/null | awk '{print $NF}')
fi

# ── Report detection results ────────────────────────────────────
if [ "$GPU_COUNT" -eq 0 ]; then
    echo "    GPU: none detected (install lspci via 'pciutils')"
elif [ "$GPU_COUNT" -eq 1 ]; then
    echo "    GPU: single — $GPU_VENDORS"
    [ -n "$GPU_NAMES" ] && echo "      chipset: $(echo "$GPU_NAMES" | sed 's/^|//')"
    [ -n "$PRIMARY_NODE" ] && echo "      render node: $PRIMARY_NODE"
else
    echo "    GPU: multi (${GPU_COUNT}) — $GPU_VENDORS"
    [ -n "$GPU_NAMES" ] && {
        echo "      chipsets:"
        echo "$GPU_NAMES" | tr '|' '\n' | grep -v '^$' | sed 's/^/        - /'
    }
    [ -n "$PRIMARY_NODE" ] && echo "      primary render node: $PRIMARY_NODE"
    [ -n "$DRM_NODES" ] && echo "      all nodes (priority order): $DRM_NODES"
    echo "      → Hyprland will render on primary; dmabuf from others"
fi
echo "    CPU: ${CPU_VENDOR:-unknown}"
echo "    Chassis: $CHASSIS_TYPE"
echo "    Session: $SESSION_TYPE"
echo "    Display manager: ${DM_NAME:-none running}"
if [ "$MONITOR_COUNT" -gt 0 ]; then
    echo "    Monitors connected: $MONITOR_COUNT ($MONITOR_NAMES)"
else
    echo "    Monitors connected: unknown (will detect at Hyprland start)"
fi
[ "$HAS_TOUCHPAD" = "1" ] && echo "    Touchpad: present (natural scroll + tap-to-click will be enabled)"
[ -n "$NVIDIA_DRIVER_VER" ] && echo "    NVIDIA driver: $NVIDIA_DRIVER_VER"
echo ""

# ── NVIDIA-specific warnings ───────────────────────────────────
if echo "$GPU_VENDORS" | grep -q NVIDIA; then
    if [ ! -r /sys/module/nvidia_drm/parameters/modeset ]; then
        echo "    ⚠ NVIDIA detected but nvidia_drm not loaded. Hyprland needs:"
        echo "      nvidia_drm.modeset=1 in your kernel cmdline"
        echo "      (edit /etc/default/grub or your bootloader config)"
        echo ""
    elif [ "$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)" != "Y" ]; then
        echo "    ⚠ nvidia_drm.modeset is NOT enabled. Hyprland will flicker/crash."
        echo "      Set nvidia_drm.modeset=1 in kernel cmdline and reboot."
        echo ""
    fi
fi

# ── Display manager compat warning ──────────────────────────────
if [ "$DM_NAME" = "lightdm" ] || [ "$DM_NAME" = "lxdm" ]; then
    echo "    ⚠ $DM_NAME may not offer a Hyprland Wayland session entry."
    echo "      SDDM or GDM are recommended for Hyprland. To install SDDM:"
    echo "        sudo pacman -S sddm"
    echo "        sudo systemctl disable $DM_NAME; sudo systemctl enable sddm"
    echo ""
fi

# ── Write hardware.conf (preserve-if-exists) ───────────────────
HW_CONF="$HYPR_DIR/modules/hardware.conf"
if [ -f "$HW_CONF" ]; then
    echo "    ${HW_CONF/$HOME/~} already exists — preserved"
else
    mkdir -p "$HYPR_DIR/modules"
    {
        echo "# ─────────────────────────────────────────────────────────────"
        echo "# Zen Shell — hardware.conf"
        echo "# Auto-generated by install.sh on $(date -Iseconds)"
        echo "# Edit freely. Reinstall will NOT overwrite this file."
        echo "# ─────────────────────────────────────────────────────────────"
        echo ""
        echo "# Detected:"
        echo "#   GPU count:   $GPU_COUNT"
        echo "#   GPU vendors: $GPU_VENDORS"
        echo "#   Primary:     ${PRIMARY_NODE:-unknown}"
        echo "#   CPU vendor:  ${CPU_VENDOR:-unknown}"
        echo ""

        # ── Multi-GPU rendering (Aquamarine) ───────────────────
        if [ "$GPU_COUNT" -gt 1 ] && [ -n "$DRM_NODES" ]; then
            echo "# Multi-GPU rendering path — Hyprland on primary, DMA-BUF import"
            echo "# from secondary nodes. Fixes laptops with iGPU + dGPU where the"
            echo "# display is wired to one GPU but the other handles rendering."
            # Build priority list with PRIMARY_NODE first
            ordered="$PRIMARY_NODE"
            for n in $(echo "$DRM_NODES" | tr ':' ' '); do
                [ "$n" = "$PRIMARY_NODE" ] && continue
                ordered="$ordered:$n"
            done
            echo "env = AQ_DRM_DEVICES,$ordered"
            echo ""
        fi

        # ── NVIDIA-specific env (only when NVIDIA present) ─────
        if echo "$GPU_VENDORS" | grep -q NVIDIA; then
            echo "# NVIDIA — required for Wayland rendering on proprietary driver"
            echo "env = LIBVA_DRIVER_NAME,nvidia"
            echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
            echo "env = GBM_BACKEND,nvidia-drm"
            echo "env = __NV_PRIME_RENDER_OFFLOAD,1"
            echo "env = __VK_LAYER_NV_optimus,NVIDIA_only"

            # Explicit-sync for NVIDIA driver 555+
            if [ -n "$NVIDIA_DRIVER_VER" ]; then
                nv_major=$(echo "$NVIDIA_DRIVER_VER" | cut -d. -f1)
                if [ "${nv_major:-0}" -ge 555 ] 2>/dev/null; then
                    echo ""
                    echo "# NVIDIA driver $NVIDIA_DRIVER_VER — explicit-sync (555+)"
                    echo "render {"
                    echo "    explicit_sync = 2"
                    echo "    explicit_sync_kms = 2"
                    echo "}"
                fi
            fi

            echo ""
            echo "# Hardware cursor can tear on some NVIDIA generations"
            echo "cursor {"
            echo "    no_hardware_cursors = true"
            echo "}"
            echo ""
        fi

        # ── Intel-specific hints ──────────────────────────────
        if echo "$GPU_VENDORS" | grep -q Intel; then
            echo "# Intel — iHD driver for modern Intel, i965 for older"
            echo "env = LIBVA_DRIVER_NAME,iHD"
            echo ""
        fi

        # ── AMD-specific hints ────────────────────────────────
        if echo "$GPU_VENDORS" | grep -q AMD && ! echo "$GPU_VENDORS" | grep -q NVIDIA; then
            echo "# AMD — RADV is the upstream Vulkan driver"
            echo "env = AMD_VULKAN_ICD,RADV"
            echo "env = RADV_PERFTEST,aco"
            echo ""
        fi

        # ── Universal env ─────────────────────────────────────
        echo "# Universal — Wayland session variables"
        echo "env = XDG_CURRENT_DESKTOP,Hyprland"
        echo "env = XDG_SESSION_TYPE,wayland"
        echo "env = XDG_SESSION_DESKTOP,Hyprland"
        echo "env = QT_QPA_PLATFORM,wayland;xcb"
        echo "env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        echo "env = GDK_BACKEND,wayland,x11"
        echo "env = MOZ_ENABLE_WAYLAND,1"
        echo "env = CLUTTER_BACKEND,wayland"
        echo ""

        # ── VRR (applies if supported) ────────────────────────
        echo "# Variable Refresh Rate — 2 = fullscreen apps only (safe default)"
        echo "# Set to 1 for always-on, 0 to disable."
        echo "misc {"
        echo "    vrr = 2"
        echo "}"
    } > "$HW_CONF"
    echo "    Wrote: ${HW_CONF/$HOME/~}"
    echo "      (edit to customize GPU / env / VRR — reinstall won't overwrite)"
fi
echo ""

read -rp "    Proceed with installation? [Y/n] " proceed_ans
if [ "${proceed_ans,,}" = "n" ]; then
    echo ""
    echo "    Installation cancelled."
    exit 0
fi
echo ""

# ═══════════════════════════════════════════════════════════════
# [1/9] Dependency check
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[1/9] Dependency check..."

MISSING_REQUIRED=0
MISSING_OPTIONAL=""

add_opt() { case " $MISSING_OPTIONAL " in *" $1 "*) ;; *) MISSING_OPTIONAL="$MISSING_OPTIONAL $1" ;; esac }

check_cmd() {
    local cmd=$1 pkg=${2:-$1} sev=${3:-optional} found=""
    command -v "$cmd" >/dev/null 2>&1 && found=$(command -v "$cmd")
    if [ -z "$found" ]; then
        for p in /usr/bin /usr/local/bin "$HOME/.local/bin"; do
            [ -x "$p/$cmd" ] && found="$p/$cmd" && break
        done
    fi
    if [ -n "$found" ]; then
        echo "    ✓ $cmd ($found)"
    elif [ "$sev" = "required" ]; then
        echo "  ✗ $cmd MISSING — install: paru -S $pkg"
        MISSING_REQUIRED=1
    else
        echo "  ○ $cmd optional — will offer: $pkg"
        add_opt "$pkg"
    fi
}

echo "  Required:"
check_cmd qs quickshell required
check_cmd hyprctl hyprland required
check_cmd jq jq required

echo "  Wallpaper:"
SWWW_OK=0
if command -v swww >/dev/null 2>&1 || command -v awww >/dev/null 2>&1; then
    SWWW_OK=1
    if command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
        mkdir -p "$BIN_DIR"
        ln -sf "$(command -v awww)" "$BIN_DIR/swww" 2>/dev/null
        ln -sf "$(command -v awww-daemon 2>/dev/null || echo '')" "$BIN_DIR/swww-daemon" 2>/dev/null
        echo "    ✓ awww → symlinked as swww in $BIN_DIR"
    else
        echo "    ✓ swww ($(command -v swww))"
    fi
else
    echo "  ○ swww / awww missing"
    add_opt "awww"
fi

echo "  Recommended:"
check_cmd nwg-displays nwg-displays
check_cmd nwg-look nwg-look
check_cmd alacritty alacritty
check_cmd fuzzel fuzzel
check_cmd btm bottom
check_cmd notify-send libnotify
check_cmd blueman-manager blueman
check_cmd nmtui networkmanager
check_cmd zenity zenity
check_cmd thunar thunar
check_cmd swaync swaync
check_cmd grim grim
check_cmd slurp slurp
check_cmd wl-copy wl-clipboard
check_cmd magick imagemagick   # v6.15: annotation compose + JPG copy
check_cmd nmcli networkmanager
check_cmd bluetoothctl bluez-utils
check_cmd wpctl wireplumber
check_cmd pavucontrol pavucontrol

echo "  v6.15 — Strings music module:"
check_cmd cava cava
check_cmd playerctl playerctl

# v6.16.3.2.1 — Lock screen + idle daemon (recommended for laptops)
# These power the smart lid behavior, the auto-lock cascade, and
# the wallpaper-synced lock screen. install-v6.16.3.2-overlay.sh
# also auto-installs them if you didn't pick them here.
echo "  v6.16.3.2 — Lock screen + idle (laptop-recommended):"
check_cmd hyprlock hyprlock
check_cmd hypridle hypridle

# v6.16.3.4.3 — Brightness control (laptops only; ignored on desktops)
# brightnessctl handles logind permissions cleanly on Arch/CachyOS.
# Without it we fall back to direct sysfs writes which need a udev rule.
echo "  v6.16.3.4.3 — Laptop brightness control:"
check_cmd brightnessctl brightnessctl

# v6.16.4.12.6.23 — Hyprland plugin build dependencies
# hyprpm needs cmake/meson/g++/make to compile plugins from source.
# Most Arch/CachyOS systems have these via base-devel, pero some minimal
# installs missing them. Auto-install via pacman if user agrees (skip if
# ZEN_NO_PLUGIN_INSTALL=1 — assume they don't want plugins).
echo "  v6.16.4.12.6.23 — Hyprland plugin build deps:"
HYPRPM_DEPS_MISSING=""
for cmd in cmake meson make gcc g++ pkg-config; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "    ✓ $cmd"
    else
        echo "  ○ $cmd missing (needed by hyprpm to compile plugins)"
        HYPRPM_DEPS_MISSING="$HYPRPM_DEPS_MISSING $cmd"
    fi
done

if [ -n "$HYPRPM_DEPS_MISSING" ] && [ "${ZEN_NO_PLUGIN_INSTALL:-}" != "1" ]; then
    echo ""
    echo "    Hyprland plugins (hyprbars, hyprexpo, hyprwinwrap, borders++, xtra-dispatchers)"
    echo "    require these tools. Without them, plugin auto-install will"
    echo "    skip later in [8.7/9]."
    echo ""
    if command -v pacman >/dev/null 2>&1; then
        # Try to auto-install (will prompt for sudo password)
        echo "    Attempting auto-install via pacman..."
        if [ "${ZEN_AUTO_INSTALL_DEPS:-1}" = "1" ]; then
            if sudo -n true 2>/dev/null || [ -t 0 ]; then
                # Either passwordless sudo OR interactive terminal
                sudo pacman -S --needed --noconfirm base-devel cmake meson 2>&1 \
                    | sed 's/^/      /' || \
                    echo "      (auto-install failed — install manually below)"
                # Re-check
                STILL_MISSING=""
                for cmd in cmake meson make gcc g++ pkg-config; do
                    command -v "$cmd" >/dev/null 2>&1 || STILL_MISSING="$STILL_MISSING $cmd"
                done
                if [ -z "$STILL_MISSING" ]; then
                    echo "    ✓ Build deps now installed"
                else
                    echo "  ⚠ Still missing:$STILL_MISSING"
                    echo "    Manual install: sudo pacman -S --needed base-devel cmake meson"
                fi
            else
                echo "  ⚠ No interactive terminal for sudo prompt"
                echo "    Manual install: sudo pacman -S --needed base-devel cmake meson"
            fi
        fi
    else
        echo "  ⚠ pacman not found — install manually:"
        echo "    apt: sudo apt install build-essential cmake meson pkg-config"
        echo "    dnf: sudo dnf groupinstall 'Development Tools' && sudo dnf install cmake meson"
    fi
fi

# v6.16.4.12.6 — Matugen (Material You wallpaper-driven theming)
# ────────────────────────────────────────────────────────────────
# Optional. When installed + the toggle is ON in Settings → Themes,
# every wallpaper switch regenerates the theme from the wallpaper's
# dominant colors. Shell works fine without it (toggle hides itself
# when the binary is missing). AUR package: matugen-bin (recommended,
# pre-compiled) or matugen (source build, slower).
echo "  v6.16.4.12.6 — Matugen wallpaper-driven theming (optional):"
check_cmd matugen matugen-bin

# v6.16.4.12.6.10 — Monitor auto-enable watcher (laptop-recommended)
# ────────────────────────────────────────────────────────────────
# socat is required by zen-monitor-watcher.sh to subscribe to
# Hyprland's socket2 IPC. Without it, the watcher won't start and
# the auto-re-enable behavior is unavailable. Shell still works
# fine — this only affects the monitor automation.
echo "  v6.16.4.12.6.10 — Monitor auto-enable watcher (laptop-recommended):"
check_cmd socat socat

# v6.16.3.7 — Font packages for lock screen + bar parity
# ────────────────────────────────────────────────────────────────
# zen-lock.sh maps fontFamilyId → "Adwaita Sans Black" / "Inter Black"
# etc. to match the desktop widget clock weight. If the Black/Heavy
# variant family isn't installed, fc-config falls back to Regular
# and the lock clock renders thin (the bug fixed in 3.6.1).
#
# We check the specific weighted family names via fc-list (not
# command -v, since these are fonts not binaries) and add the
# packaging to the optional install offer.
echo "  v6.16.3.7 — Font weight variants (lock clock + widgets):"
check_font() {
    local style=$1 family=$2 pkg=$3
    if fc-list 2>/dev/null | grep -q ":style=.*${style}" | head -1 >/dev/null 2>&1 \
       || fc-list 2>/dev/null | grep -iq "${family}:style=${style}"; then
        echo "    ✓ ${family} ${style} (installed)"
    else
        echo "  ○ ${family} ${style} missing — will offer: ${pkg}"
        add_opt "${pkg}"
    fi
}
if command -v fc-list >/dev/null 2>&1; then
    check_font Black   "Adwaita Sans"   adwaita-fonts
    check_font Black   "Inter"          inter-font
    # gnome-themes-extra is a safe catch-all that pulls in Adwaita
    # variants + font alternates. Offer alongside adwaita-fonts for
    # users who want the whole GNOME theme pack.
    if ! pacman -Q gnome-themes-extra >/dev/null 2>&1; then
        echo "  ○ gnome-themes-extra (optional: Adwaita theme pack) — will offer"
        add_opt "gnome-themes-extra"
    fi
else
    echo "  ○ fc-list not available — can't verify font variants"
    add_opt "fontconfig"
    add_opt "adwaita-fonts"
fi

if [ "$MISSING_REQUIRED" = "1" ]; then
    echo ""
    echo "  ⚠ Missing required deps."
    echo ""
    if [ -f "$SCRIPT_DIR/bootstrap.sh" ] && command -v pacman >/dev/null 2>&1; then
        echo "    ── Fresh system? Use bootstrap mode ──"
        echo ""
        echo "    This tarball includes bootstrap.sh which installs"
        echo "    Hyprland + Quickshell + all 35+ dependencies via"
        echo "    paru/yay on Arch-based systems (KDE/GNOME/COSMIC safe)."
        echo ""
        echo "    Run:"
        echo "       ./install.sh --bootstrap"
        echo ""
        echo "    ── Or install required packages manually ──"
        echo "       paru -S quickshell-git hyprland jq"
        echo ""
    else
        echo "    Install required packages first:"
        echo "       paru -S quickshell-git hyprland jq"
        echo ""
    fi
    exit 1
fi

# ── Offer optional installs ──
MISSING_OPTIONAL=$(echo "$MISSING_OPTIONAL" | xargs)
INSTALLED_OPTIONAL_PACKAGES=""
SKIPPED_OPTIONAL_PACKAGES=""
if [ -n "$MISSING_OPTIONAL" ]; then
    echo ""
    echo "  Missing optional packages: $MISSING_OPTIONAL"
    INSTALLER=""
    command -v paru >/dev/null 2>&1 && INSTALLER="paru"
    command -v yay  >/dev/null 2>&1 && [ -z "$INSTALLER" ] && INSTALLER="yay"
    command -v pacman >/dev/null 2>&1 && [ -z "$INSTALLER" ] && INSTALLER="sudo pacman"

    if [ -n "$INSTALLER" ]; then
        echo ""
        printf "  Install optional packages with %s? [Y/n] " "$INSTALLER"
        if read -r -t 30 REPLY </dev/tty 2>/dev/null; then :; else REPLY="n"; echo "(timeout — skipping)"; fi
        case "${REPLY:-y}" in
            [nN]*)
                echo "    Skipped. Later: $INSTALLER -S $MISSING_OPTIONAL"
                SKIPPED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL"
                ;;
            *)
                # shellcheck disable=SC2086
                if $INSTALLER -S --needed $MISSING_OPTIONAL; then
                    echo "    Installed."
                    INSTALLED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL"
                else
                    echo "  ⚠ Some failed. Continuing..."
                    SKIPPED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL"
                fi
                ;;
        esac
    else
        echo "  No AUR helper found. Install manually: $MISSING_OPTIONAL"
        SKIPPED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [2/9] Backup
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[2/9] Backup..."
if [ -d "$SHELL_DIR" ]; then
    cp -r "$SHELL_DIR" "$SHELL_DIR.bak-$TS"
    echo "    $SHELL_DIR → .bak-$TS"
fi
[ -f "$HYPR_DIR/modules/binds.conf" ] && \
    cp "$HYPR_DIR/modules/binds.conf" "$HYPR_DIR/modules/binds.conf.bak-$TS" && \
    echo "    $HYPR_DIR/modules/binds.conf → .bak-$TS"

# Migrate strings-state.json from old wing-based format
STRINGS_STATE="$SHELL_DIR/strings-state.json"
if [ -f "$STRINGS_STATE" ] && command -v jq >/dev/null 2>&1; then
    cp "$STRINGS_STATE" "$STRINGS_STATE.bak-$TS"
    jq 'del(.mode, .leftEnabled, .rightEnabled, .leftAudioVisual,
             .rightAudioVisual, .position, .barPosition)
        | if .colorMode == "synced" then . else .colorMode = "theme" end
        | .stringLength //= 0
        | .ropeSegments      = 10
        | .ropeSegmentLength = 5' \
        "$STRINGS_STATE.bak-$TS" > "$STRINGS_STATE" 2>/dev/null \
        && echo "    strings-state.json migrated to v6.15.1 schema (rope physics reset)" \
        || echo "    (migration skipped — defaults will apply)"
fi

# ═══════════════════════════════════════════════════════════════
# [3/9] Create directories
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[3/9] Setup directories..."
rm -rf "$SHELL_DIR/pages" "$SHELL_DIR/services" 2>/dev/null
mkdir -p "$SHELL_DIR/config" "$HYPR_DIR/modules" "$BIN_DIR"
mkdir -p "$HOME/.config/alacritty" "$HOME/.config/fuzzel"
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/.cache/zen-shell"
echo "    Done"

# ═══════════════════════════════════════════════════════════════
# [4/9] Install QML files
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[4/9] Install QML files..."
cp "$SCRIPT_DIR/zen-shell-v5/"*.qml "$SHELL_DIR/"
INSTALLED_QML_COUNT=$(ls "$SHELL_DIR/"*.qml 2>/dev/null | wc -l)
echo "    $INSTALLED_QML_COUNT QML files installed"

# v6.16.3.5: Deploy bundled Start Button logos
# These ship with the shell under zen-shell-v5/assets/logos/ and get
# installed to ~/.local/share/quickshell/zen-shell/logos/ so the Start
# Menu picker can find them via an absolute path. Idempotent — we
# always overwrite so logo bug fixes land without prompting.
LOGOS_SRC="$SCRIPT_DIR/zen-shell-v5/assets/logos"
LOGOS_DST="$HOME/.local/share/quickshell/zen-shell/logos"
if [ -d "$LOGOS_SRC" ]; then
    mkdir -p "$LOGOS_DST"
    cp -f "$LOGOS_SRC/"*.svg "$LOGOS_DST/" 2>/dev/null || true
    LOGO_COUNT=$(ls "$LOGOS_DST/"*.svg 2>/dev/null | wc -l)
    echo "    $LOGO_COUNT built-in Start Button logos installed → $LOGOS_DST"
fi

echo ""
echo "    Auto-applying bar modules..."
# v6.16.4.12.6.13: Auto-applier is now SIZE-AWARE. The earlier logic
# blindly overwrote Clock.qml with ZenClock.qml every install — but
# Clock.qml is the LIVE module that gets edits during development,
# while ZenClock.qml has often been a stale earlier copy. When the
# two diverge significantly (>20% size diff), we take the larger
# file as canonical to both sides. This protects against:
#   - clobbering live Clock.qml edits with stale ZenClock.qml content
#   - clobbering live ZenClock.qml edits with stale Clock.qml content
# Wala tayo babawasan: backups still made for whichever side gets
# overwritten so revert is one `mv` away.
#
# v6.16.4.12.6.53 (Hiraki hotfix 1): the `ZenClock.qml:Clock.qml`
# pair has been REMOVED from this loop. Since Hikari (.51), Clock.qml
# is the canonical clock module — a forked, focused module that's
# significantly smaller than the legacy 43KB ZenClock.qml. The
# size-aware heuristic above backfires: it sees the bigger
# (legacy) ZenClock.qml as canonical and clobbers the new Clock.qml
# from the tarball, breaking the click-to-open behaviour at install
# time. Bar.qml uses `Clock {}` directly; ZenClock.qml is unused at
# runtime and only kept on disk for back-compat. The pair entry is
# kept in this comment block as documentation; the loop now only
# handles Workspaces and SysMonitor pairs.
for pair in "ZenWorkspaces.qml:Workspaces.qml" "ZenSysMonitor.qml:SysMonitor.qml"; do
    src="${pair%%:*}"; dst="${pair##*:}"
    [ -f "$SHELL_DIR/$src" ] || continue

    if [ -f "$SHELL_DIR/$dst" ]; then
        if diff -q "$SHELL_DIR/$src" "$SHELL_DIR/$dst" >/dev/null 2>&1; then
            echo "      $dst up to date"
            continue
        fi

        # Compare sizes and timestamps to decide direction.
        src_size=$(wc -c <"$SHELL_DIR/$src")
        dst_size=$(wc -c <"$SHELL_DIR/$dst")
        # Files differ — pick canonical = whichever is larger if the
        # gap is substantial (≥20%). Otherwise default to src→dst (old
        # behavior) since src was just freshly copied from the tarball.
        if [ "$dst_size" -gt 0 ]; then
            ratio=$(( src_size * 100 / dst_size ))
        else
            ratio=200
        fi

        if [ "$ratio" -lt 80 ]; then
            # src is significantly SMALLER than dst — dst is likely the
            # live edited copy with new features. Promote dst → src so
            # ZenClock.qml stays in sync with edits to Clock.qml.
            cp "$SHELL_DIR/$src" "$SHELL_DIR/$src.bak-$TS"
            cp "$SHELL_DIR/$dst" "$SHELL_DIR/$src"
            echo "      $dst → $src (live $dst is newer/bigger; old $src backed up)"
        else
            # src is same-or-larger than dst — go with src→dst (the
            # canonical path, preserves the new tarball's content).
            cp "$SHELL_DIR/$dst" "$SHELL_DIR/$dst.bak-$TS"
            cp "$SHELL_DIR/$src" "$SHELL_DIR/$dst"
            echo "      $src → $dst (backed up old $dst)"
        fi
    else
        cp "$SHELL_DIR/$src" "$SHELL_DIR/$dst"
        echo "      $src → $dst (new)"
    fi
done

# v6.16.4.12.6.53 (Hiraki hotfix 1): Clock.qml is now ALWAYS taken
# straight from the tarball — no size heuristic, no ZenClock.qml
# pairing. The freshly-unpacked tarball Clock.qml is already in
# place at $SHELL_DIR/Clock.qml at this point (copied by the QML
# bulk-copy step earlier in this script), so this is a no-op except
# for the user-visible echo. Old Clock.qml backups from earlier
# installs (Clock.qml.bak-*) are left on disk untouched.
if [ -f "$SHELL_DIR/Clock.qml" ]; then
    echo "      Clock.qml installed direct from tarball (no auto-applier — Hikari/Hiraki canonical)"
fi

# ═══════════════════════════════════════════════════════════════
# [5/9] Install scripts
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[5/9] Install scripts..."
INSTALLED_SCRIPTS_COUNT=0
for script in \
    fix-monitor-scale.sh blueman-toggle.sh btm-toggle.sh \
    wifi-toggle.sh termrun.sh regen-terminal-themes.sh \
    regen-swaync-theme.sh zen-screenshot.sh \
    patch-swaync-position.sh zen-cava.sh \
    zs-restart.sh \
    zen-volume-notify.sh zen-power-profile-restore.sh zen-lid-handler.sh \
    zen-resume-handler.sh zen-lock.sh zen-lock-message.sh zen-hypridle-sync.sh zen-panic.sh zen-bar-add-powerbadge.sh \
    zen-game-watcher.sh prime-run \
    zen-matugen-bootstrap.sh \
    zen-monitor-watcher.sh \
    zen-quickprompt.sh \
    zen-hyprpm-fix.sh \
    install-hyprbars.sh
do
    src="$SCRIPT_DIR/scripts/$script"
    if [ -f "$src" ]; then
        cp "$src" "$BIN_DIR/$script"
        chmod +x "$BIN_DIR/$script"
        echo "    $BIN_DIR/$script"
        INSTALLED_SCRIPTS_COUNT=$((INSTALLED_SCRIPTS_COUNT+1))
    else
        echo "  ⚠ missing: $script"
    fi
done

# ─────────────────────────────────────────────────────────────────
# v6.16.4.12.6.10 → .6.11 — Monitor auto-enable watcher (smart memory)
# ─────────────────────────────────────────────────────────────────
# Solves the "disabled internal display + external unplug = no display"
# scenario, AND adds per-topology state memory so docked configs auto-
# restore on re-dock. Safety: never permits 0 enabled monitors — force-
# enables the configured MAIN if a user/state would leave nothing on.
#
# Watcher subscribes to Hyprland's socket2 IPC. State snapshots get saved
# to ~/.config/hypr/zen-monitor-states/topology-<key>.json — one per
# unique combination of physically-connected monitors.
#
# Idempotent re-install: enable --now is safe to repeat. Disable with:
#   systemctl --user disable --now zen-monitor-watcher
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_SRC="$SCRIPT_DIR/scripts/zen-monitor-watcher.service"
if [ -f "$SERVICE_SRC" ]; then
    mkdir -p "$SYSTEMD_USER_DIR"
    cp "$SERVICE_SRC" "$SYSTEMD_USER_DIR/zen-monitor-watcher.service"
    echo "    $SYSTEMD_USER_DIR/zen-monitor-watcher.service"

    # Drop the example env file alongside hyprland configs so the user
    # can copy + edit. We DON'T install it directly to its active location
    # because we don't want to overwrite a user-customized env file.
    HYPR_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
    ENV_EXAMPLE_SRC="$SCRIPT_DIR/scripts/zen-monitor-watcher.env.example"
    if [ -f "$ENV_EXAMPLE_SRC" ]; then
        mkdir -p "$HYPR_CONFIG_DIR"
        cp "$ENV_EXAMPLE_SRC" "$HYPR_CONFIG_DIR/zen-monitor-watcher.env.example"
        echo "    $HYPR_CONFIG_DIR/zen-monitor-watcher.env.example"
        echo "      (desktop users: copy to zen-monitor-watcher.env and set ZEN_MONITOR_MAIN)"
    fi

    # Reload systemd user manager so the new unit is visible
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        # Enable but don't start mid-install — the unit is gated by
        # graphical-session.target and HYPRLAND_INSTANCE_SIGNATURE,
        # so it'll start on the next Hyprland session login.
        systemctl --user enable zen-monitor-watcher.service 2>&1 \
            | sed 's/^/    /' || true
    fi
fi

[ -f "$SCRIPT_DIR/bin/swww-test" ] && \
    cp "$SCRIPT_DIR/bin/swww-test" "$BIN_DIR/swww-test" && \
    chmod +x "$BIN_DIR/swww-test" && \
    echo "    $BIN_DIR/swww-test"

# ═══════════════════════════════════════════════════════════════
# v6.15.14: Clean up stale helper from pre-v6.15.12 installs
# ═══════════════════════════════════════════════════════════════
if [ -f "$BIN_DIR/zen-shell-nuclear-restart.sh" ]; then
    rm -f "$BIN_DIR/zen-shell-nuclear-restart.sh"
    echo "    removed stale: zen-shell-nuclear-restart.sh (replaced by zs-restart.sh)"
fi

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo ""
    echo "  $BIN_DIR not in PATH — auto-configuring..."

    # Detect user's login shell from /etc/passwd
    USER_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
    USER_SHELL_NAME=$(basename "${USER_SHELL:-/bin/bash}")

    # Pick the right rc file
    PATH_ADDED=0
    case "$USER_SHELL_NAME" in
        fish)
            FISH_CONF="$HOME/.config/fish/config.fish"
            mkdir -p "$(dirname "$FISH_CONF")"
            touch "$FISH_CONF"
            if ! grep -q "\.local/bin" "$FISH_CONF" 2>/dev/null; then
                echo "" >> "$FISH_CONF"
                echo "# Added by Zen Shell installer" >> "$FISH_CONF"
                echo "fish_add_path ~/.local/bin" >> "$FISH_CONF"
                echo "      → added 'fish_add_path ~/.local/bin' to ~/.config/fish/config.fish"
                PATH_ADDED=1
            fi
            ;;
        zsh)
            ZSH_CONF="$HOME/.zshrc"
            touch "$ZSH_CONF"
            if ! grep -q "\.local/bin" "$ZSH_CONF" 2>/dev/null; then
                echo "" >> "$ZSH_CONF"
                echo "# Added by Zen Shell installer" >> "$ZSH_CONF"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSH_CONF"
                echo "      → added PATH export to ~/.zshrc"
                PATH_ADDED=1
            fi
            ;;
        bash|sh)
            BASH_CONF="$HOME/.bashrc"
            touch "$BASH_CONF"
            if ! grep -q "\.local/bin" "$BASH_CONF" 2>/dev/null; then
                echo "" >> "$BASH_CONF"
                echo "# Added by Zen Shell installer" >> "$BASH_CONF"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASH_CONF"
                echo "      → added PATH export to ~/.bashrc"
                PATH_ADDED=1
            fi
            ;;
        *)
            echo "  ⚠ Unknown shell: $USER_SHELL_NAME. Add this manually:"
            echo "     export PATH=\"\$HOME/.local/bin:\$PATH\""
            ;;
    esac

    # Always add to ~/.profile too (for non-interactive + login shells)
    PROFILE="$HOME/.profile"
    touch "$PROFILE"
    if ! grep -q "\.local/bin" "$PROFILE" 2>/dev/null; then
        echo "" >> "$PROFILE"
        echo "# Added by Zen Shell installer" >> "$PROFILE"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
        [ "$PATH_ADDED" = "0" ] && echo "      → added PATH export to ~/.profile"
    fi

    echo "      Re-login or source the file to apply. Current session:"
    echo "        export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ═══════════════════════════════════════════════════════════════
# [5.9/9] Detect existing user settings profile (v6.16.4.12.6.51)
# ═══════════════════════════════════════════════════════════════
# Inspect the user's existing Hyprland + Zen Shell configs so the
# installer reports what will be PRESERVED vs INSTALLED-AS-DEFAULT.
# Nothing is overwritten here — this is read-only detection. The
# actual preservation logic lives in [6/9] (per-file: copy default
# only if missing; touch nothing if present).
#
# Detected:
#   • general:gaps_in / gaps_out / border_size  (from look_and_feel.conf)
#   • general:layout                             (from look_and_feel.conf)
#   • decoration:rounding                        (from look_and_feel.conf)
#   • Hyprland version                           (from hyprctl)
#   • Zen Shell panel position / panel mode      (from panel-state.json)
#   • Zen Shell selected theme                   (from theme state)
echo ""
echo "[5.9/9] Detecting existing user settings..."

# Helper: extract first matching value from an .conf file (key = value).
# Tolerates whitespace and inline comments. Empty string if no match.
# Portable: uses POSIX awk only (works on mawk, gawk, busybox awk).
_zen_detect_conf_val() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || { echo ""; return; }
    awk -v k="$key" '
        /^[[:space:]]*#/ { next }
        {
            sub(/#.*$/, "")
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (substr(line, 1, length(k)) != k) next
            rest = substr(line, length(k) + 1)
            sub(/^[[:space:]]*=[[:space:]]*/, "", rest)
            sub(/[[:space:]]+$/, "", rest)
            if (rest != "") { print rest; exit }
        }
    ' "$file" 2>/dev/null
}

# Helper: extract a JSON string field via a conservative regex (no jq dep).
_zen_detect_json_str() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || { echo ""; return; }
    grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
        | head -1 \
        | sed -E "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
}

LAF="$HOME/.config/hypr/modules/look_and_feel.conf"
PANEL_STATE="$HOME/.config/quickshell/zen-shell/panel-state.json"
SETTINGS_STATE="$HOME/.config/quickshell/zen-shell/settings-state.json"

DETECT_GAPS_IN=$(_zen_detect_conf_val "$LAF" "gaps_in")
DETECT_GAPS_OUT=$(_zen_detect_conf_val "$LAF" "gaps_out")
DETECT_BORDER=$(_zen_detect_conf_val "$LAF" "border_size")
DETECT_LAYOUT=$(_zen_detect_conf_val "$LAF" "layout")
DETECT_ROUNDING=$(_zen_detect_conf_val "$LAF" "rounding")
DETECT_PANEL_POS=$(_zen_detect_json_str "$PANEL_STATE" "panelPosition")
DETECT_PANEL_MODE=$(_zen_detect_json_str "$PANEL_STATE" "panelMode")
DETECT_THEME=$(_zen_detect_json_str "$SETTINGS_STATE" "themeId")

if command -v hyprctl >/dev/null 2>&1; then
    DETECT_HYPR_VER=$(hyprctl version 2>/dev/null | grep -oE 'Tag: v?[0-9.]+' | head -1)
fi

if [ -f "$LAF" ] || [ -f "$PANEL_STATE" ] || [ -f "$SETTINGS_STATE" ]; then
    echo "    Existing config found — the following will be PRESERVED on re-install:"
    [ -n "$DETECT_GAPS_IN" ]    && echo "      gaps_in        = $DETECT_GAPS_IN  (look_and_feel.conf)"
    [ -n "$DETECT_GAPS_OUT" ]   && echo "      gaps_out       = $DETECT_GAPS_OUT  (look_and_feel.conf)"
    [ -n "$DETECT_BORDER" ]     && echo "      border_size    = $DETECT_BORDER  (look_and_feel.conf)"
    [ -n "$DETECT_LAYOUT" ]     && echo "      layout         = $DETECT_LAYOUT  (look_and_feel.conf)"
    [ -n "$DETECT_ROUNDING" ]   && echo "      rounding       = $DETECT_ROUNDING  (look_and_feel.conf)"
    [ -n "$DETECT_PANEL_POS" ]  && echo "      panel position = $DETECT_PANEL_POS  (panel-state.json)"
    [ -n "$DETECT_PANEL_MODE" ] && echo "      panel mode     = $DETECT_PANEL_MODE  (panel-state.json)"
    [ -n "$DETECT_THEME" ]      && echo "      theme          = $DETECT_THEME  (settings-state.json)"
    [ -n "${DETECT_HYPR_VER:-}" ] && echo "      Hyprland       = $DETECT_HYPR_VER"
    echo ""
    echo "    The installer will skip these files (idempotent merge in [6/9])."
    echo "    To force a reset to defaults: delete the file before running again."
else
    echo "    No prior configuration detected — defaults will be installed."
    [ -n "${DETECT_HYPR_VER:-}" ] && echo "      Hyprland = $DETECT_HYPR_VER"
fi

# ═══════════════════════════════════════════════════════════════
# [6/9] Hyprland configs
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[6/9] Hyprland configs..."
[ -f "$SCRIPT_DIR/hypr-config/binds.conf" ] && \
    cp "$SCRIPT_DIR/hypr-config/binds.conf" "$HYPR_DIR/modules/binds.conf" && \
    echo "    binds.conf"
[ -f "$SCRIPT_DIR/hypr-config/keybinds-update.conf" ] && \
    cp "$SCRIPT_DIR/hypr-config/keybinds-update.conf" "$SHELL_DIR/config/keybinds-update.conf" && \
    echo "    keybinds-update.conf (v6.15: carried from v6.14)"
[ -f "$SCRIPT_DIR/hypr-config/hyprland-layer-rules.conf" ] && \
    cp "$SCRIPT_DIR/hypr-config/hyprland-layer-rules.conf" "$SHELL_DIR/config/hyprland-layer-rules.conf" && \
    echo "    hyprland-layer-rules.conf (v6.15: carried from v6.14)"

# ─────────────────────────────────────────────────────────────────
# v6.15.15: animations.conf / autostart.conf / look_and_feel.conf
# v6.16.0 : + lid-behavior.conf
# These are USER-CUSTOMIZABLE — install default only if missing.
# ─────────────────────────────────────────────────────────────────
for mod in animations.conf autostart.conf look_and_feel.conf lid-behavior.conf plugins.conf; do
    src="$SCRIPT_DIR/hypr-config/$mod"
    dst="$HYPR_DIR/modules/$mod"
    if [ -f "$src" ]; then
        if [ -f "$dst" ]; then
            echo "    $mod (already exists — preserved)"
        else
            cp "$src" "$dst"
            echo "    $mod (installed default)"
        fi
    fi
done

# ─────────────────────────────────────────────────────────────────
# v6.16.4.12.6.51 (Hikari): Sync saved profile values back into
# look_and_feel.conf so the FILE matches the user's saved profile.
#
# Why: the Settings UI applies gaps/border changes via
# `hyprctl keyword general:gaps_in N` (runtime only) and saves them
# to settings-state.json (the profile). It does NOT rewrite
# look_and_feel.conf. Result: after Hyprland reload, the file values
# reload first and override the runtime values — until SettingsStateV2
# re-applies the profile from settings-state.json on QML startup.
# That brief window lost the user's saved gaps to whatever the file
# had (often defaults from a prior install), and the user reported
# "nawala yun gap settings ko".
#
# Fix: after preserving look_and_feel.conf, read settings-state.json
# and rewrite the gaps_in / gaps_out / border_size lines in the file
# to match the saved profile. Only touches those three lines; the
# rest of look_and_feel.conf (decoration, animations, etc.) is left
# alone. Idempotent — re-running the installer just no-ops if values
# already match.
# ─────────────────────────────────────────────────────────────────
LAF_NOW="$HYPR_DIR/modules/look_and_feel.conf"
SETTINGS_STATE_NOW="$SHELL_DIR/settings-state.json"
if [ -f "$LAF_NOW" ] && [ -f "$SETTINGS_STATE_NOW" ]; then
    # Helper: extract integer field from JSON (no jq dependency)
    _zen_json_int() {
        grep -oE "\"$1\"[[:space:]]*:[[:space:]]*-?[0-9]+" "$SETTINGS_STATE_NOW" 2>/dev/null \
            | head -1 \
            | sed -E "s/.*:[[:space:]]*//"
    }
    PROF_GAPS_IN=$(_zen_json_int "gapsIn")
    PROF_GAPS_OUT=$(_zen_json_int "gapsOut")
    PROF_BORDER=$(_zen_json_int "borderSize")

    sync_count=0
    if [ -n "$PROF_GAPS_IN" ]; then
        sed -i -E "s/^([[:space:]]*)gaps_in[[:space:]]*=.*/\\1gaps_in = $PROF_GAPS_IN/" "$LAF_NOW"
        sync_count=$((sync_count+1))
    fi
    if [ -n "$PROF_GAPS_OUT" ]; then
        sed -i -E "s/^([[:space:]]*)gaps_out[[:space:]]*=.*/\\1gaps_out = $PROF_GAPS_OUT/" "$LAF_NOW"
        sync_count=$((sync_count+1))
    fi
    if [ -n "$PROF_BORDER" ]; then
        sed -i -E "s/^([[:space:]]*)border_size[[:space:]]*=.*/\\1border_size = $PROF_BORDER/" "$LAF_NOW"
        sync_count=$((sync_count+1))
    fi
    if [ "$sync_count" -gt 0 ]; then
        echo "    look_and_feel.conf — synced $sync_count value(s) from saved profile:"
        [ -n "$PROF_GAPS_IN" ]  && echo "      gaps_in    = $PROF_GAPS_IN"
        [ -n "$PROF_GAPS_OUT" ] && echo "      gaps_out   = $PROF_GAPS_OUT"
        [ -n "$PROF_BORDER" ]   && echo "      border_size = $PROF_BORDER"
    fi
fi

# ─────────────────────────────────────────────────────────────────
# v6.15.15: hyprland.conf — canonical template install
# ─────────────────────────────────────────────────────────────────
HCONF="$HYPR_DIR/hyprland.conf"
TEMPLATE="$SCRIPT_DIR/hypr-config/hyprland.conf.template"

# Helper: dedupe quickshell/qs exec-once lines from a hyprland.conf
# (autostart.conf is the single source of truth for quickshell startup)
dedupe_quickshell_execonce() {
    local f="$1"
    if grep -qE "^[[:space:]]*exec-once[[:space:]]*=.*\b(quickshell|qs)\b.*\bzen-shell\b" "$f" 2>/dev/null; then
        # Found stray exec-once for quickshell — back up + remove
        cp "$f" "$f.dedupe-bak-$TS"
        sed -i -E "/^[[:space:]]*exec-once[[:space:]]*=.*\b(quickshell|qs)\b.*\bzen-shell\b/d" "$f"
        echo "    Removed stray 'exec-once = quickshell ... zen-shell' from hyprland.conf"
        echo "      (autostart.conf is the canonical source — backup at $f.dedupe-bak-$TS)"
        return 0
    fi
    return 1
}

if [ -f "$TEMPLATE" ]; then
    if [ ! -f "$HCONF" ]; then
        # Fresh install — drop the canonical template directly
        mkdir -p "$HYPR_DIR"
        cp "$TEMPLATE" "$HCONF"
        echo "    hyprland.conf — installed canonical template (fresh install)"
    else
        # Existing hyprland.conf — preserve, just append missing source
        # lines + dedupe quickshell exec-once
        added=0

        # First, dedupe any double quickshell launches
        dedupe_quickshell_execonce "$HCONF" && added=$((added+1))

        # Append missing source lines (idempotent via grep -q guards)
        grep -q "modules/hardware.conf" "$HCONF" || {
            printf '\n# ── Added by Zen Shell installer (hardware detection) ──\nsource = ~/.config/hypr/modules/hardware.conf\n' >> "$HCONF"
            added=$((added+1)); }
        grep -q "modules/binds.conf" "$HCONF" || {
            printf '\n# ── Added by Zen Shell installer ──\nsource = ~/.config/hypr/modules/binds.conf\n' >> "$HCONF"
            added=$((added+1)); }
        grep -q "modules/autostart.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/autostart.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "modules/look_and_feel.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/look_and_feel.conf" >> "$HCONF"
            added=$((added+1)); }
        # v6.16.0: lid-behavior module (bindl rules for switch:on:Lid)
        grep -q "modules/lid-behavior.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/lid-behavior.conf" >> "$HCONF"
            added=$((added+1)); }
        # v6.16.3.4.4: animations.conf — THIS WAS MISSING in all prior
        # versions. AnimationsPage.qml writes preset content to this
        # file and calls `hyprctl reload`, but without a source line
        # Hyprland never read it, so switching presets did nothing.
        # Placed LAST so it overrides look_and_feel.conf's animations{}.
        grep -q "modules/animations.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/animations.conf" >> "$HCONF"
            added=$((added+1)); }
        # v6.16.4.12.6.19: Hyprland plugins config (managed by Settings)
        grep -q "modules/plugins.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/plugins.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "keybinds-update.conf" "$HCONF" || {
            echo "source = ~/.config/quickshell/zen-shell/config/keybinds-update.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "hyprland-layer-rules.conf" "$HCONF" || {
            echo "source = ~/.config/quickshell/zen-shell/config/hyprland-layer-rules.conf" >> "$HCONF"
            added=$((added+1)); }

        if [ $added -gt 0 ]; then
            echo "    Added $added line(s) to hyprland.conf"
        else
            echo "    hyprland.conf already up to date"
        fi

        echo ""
        echo "    Tip: To replace your hyprland.conf with the canonical Zen Shell"
        echo "         template (your version backed up to .bak-$TS), run:"
        echo "           cp ${HCONF/$HOME/~}{,.bak-$TS}"
        echo "           cp $SCRIPT_DIR/hypr-config/hyprland.conf.template $HCONF"
    fi
else
    echo "  ⚠ hyprland.conf.template not found — falling back to source = appender"
    if [ -f "$HCONF" ]; then
        added=0
        dedupe_quickshell_execonce "$HCONF" && added=$((added+1))
        grep -q "modules/hardware.conf" "$HCONF" || {
            printf '\n# ── Added by Zen Shell installer ──\nsource = ~/.config/hypr/modules/hardware.conf\n' >> "$HCONF"
            added=$((added+1)); }
        grep -q "modules/binds.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/binds.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "modules/autostart.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/autostart.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "modules/look_and_feel.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/look_and_feel.conf" >> "$HCONF"
            added=$((added+1)); }
        # v6.16.0: lid-behavior module
        grep -q "modules/lid-behavior.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/lid-behavior.conf" >> "$HCONF"
            added=$((added+1)); }
        # v6.16.3.4.4: animations.conf (previously missing — see main block)
        grep -q "modules/animations.conf" "$HCONF" || {
            echo "source = ~/.config/hypr/modules/animations.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "keybinds-update.conf" "$HCONF" || {
            echo "source = ~/.config/quickshell/zen-shell/config/keybinds-update.conf" >> "$HCONF"
            added=$((added+1)); }
        grep -q "hyprland-layer-rules.conf" "$HCONF" || {
            echo "source = ~/.config/quickshell/zen-shell/config/hyprland-layer-rules.conf" >> "$HCONF"
            added=$((added+1)); }
        [ $added -gt 0 ] \
            && echo "    Added $added line(s) to hyprland.conf" \
            || echo "    hyprland.conf already up to date"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [7/9] Themes
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[7/9] Themes..."
mkdir -p "$THEMES_BUILTIN" "$THEMES_CUSTOM"
cp "$SCRIPT_DIR/themes-builtin/"*.json "$THEMES_BUILTIN/"
INSTALLED_THEMES_COUNT=$(ls "$THEMES_BUILTIN/"*.json 2>/dev/null | wc -l)
echo "    $INSTALLED_THEMES_COUNT builtin themes"

if [ ! -f "$GTK_DIR/current-theme.json" ] && [ -f "$THEMES_BUILTIN/tokyo-night.json" ]; then
    cp "$THEMES_BUILTIN/tokyo-night.json" "$GTK_DIR/current-theme.json"
    echo "    Default theme: tokyo-night"
fi

# ═══════════════════════════════════════════════════════════════
# [8/9] First-run tasks
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[8/9] First-run tasks..."
[ -x "$BIN_DIR/fix-monitor-scale.sh" ] && [ -f "$HYPR_DIR/modules/monitors.conf" ] && {
    echo "    fix-monitor-scale.sh..."
    timeout 10s "$BIN_DIR/fix-monitor-scale.sh" 2>&1 | sed 's/^/    /' || true
}
[ -x "$BIN_DIR/regen-terminal-themes.sh" ] && [ -f "$GTK_DIR/current-theme.json" ] && {
    echo "    regen-terminal-themes.sh..."
    timeout 10s "$BIN_DIR/regen-terminal-themes.sh" 2>&1 | sed 's/^/    /' || true
}
[ -x "$BIN_DIR/regen-swaync-theme.sh" ] && [ -f "$GTK_DIR/current-theme.json" ] && {
    echo "    regen-swaync-theme.sh..."
    timeout 10s "$BIN_DIR/regen-swaync-theme.sh" 2>&1 | sed 's/^/    /' || true
}

# ─────────────────────────────────────────────────────────────────
# v6.16.4.12.6 — Matugen config bootstrap (smart-detect, idempotent)
# ─────────────────────────────────────────────────────────────────
# Run zen-matugen-bootstrap.sh whenever matugen is on PATH and the
# bootstrap script is installed. The bootstrap is fully idempotent:
#   - First run: writes ~/.config/matugen/config.toml from template
#   - Re-run: leaves existing config alone IF it has [templates]
#   - v6.16.4.12.6.3: HEALS configs from earlier v6.16.4.12.6 installs
#     that lack [templates] (matugen 2.x requires it). Original is
#     backed up to config.toml.bak-zenheal-<timestamp>.
#
# Safe to run on every install — that's the whole point of the heal
# branch. The earlier `[ ! -f config.toml ]` guard is gone for that
# reason.
if command -v matugen >/dev/null 2>&1 \
   && [ -x "$BIN_DIR/zen-matugen-bootstrap.sh" ]; then
    echo "    zen-matugen-bootstrap.sh (idempotent setup + heal)..."
    timeout 5s "$BIN_DIR/zen-matugen-bootstrap.sh" 2>&1 | sed 's/^/    /' || true
fi

# ─────────────────────────────────────────────────────────────────
# v6.16.3.4.5 — One-shot bar-layout migrations
# ─────────────────────────────────────────────────────────────────
# When we ship a new bar module (powerbadge in v6.16.3.4), existing
# users whose bar-layout.json was saved BEFORE the module existed
# silently miss it — their saved layout overrides Theme.qml's default.
#
# Instead of forcing users to discover + run zen-bar-add-powerbadge.sh
# manually, we run those migrations here — ONCE. A marker file under
# ~/.config/quickshell/zen-shell/.migrations/ records that the
# migration has been applied, so re-installs don't re-add a module
# the user may have deliberately removed after first migration.
#
# Each migration is idempotent AND guarded by its own marker. Adding
# a new bar module later = drop another bash block + marker file.
MIG_DIR="$HOME/.config/quickshell/zen-shell/.migrations"
mkdir -p "$MIG_DIR"

# Migration: powerbadge bar module (introduced v6.16.3.4)
if [ ! -f "$MIG_DIR/powerbadge-v6.16.3.4" ]; then
    if [ -x "$BIN_DIR/zen-bar-add-powerbadge.sh" ]; then
        echo "    One-shot migration: adding 'powerbadge' to bar-layout.json..."
        "$BIN_DIR/zen-bar-add-powerbadge.sh" 2>&1 | sed 's/^/      /' || true
        touch "$MIG_DIR/powerbadge-v6.16.3.4"
        echo "      marker written — migration will not re-run on future installs"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [8.5/9] QML integrity smoke test (v6.15.15+)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[8.5/9] QML integrity check..."
MISSING_TYPES=""
if [ -d "$SHELL_DIR" ]; then
    PROVIDED=$(ls "$SHELL_DIR"/*.qml 2>/dev/null | xargs -n1 basename | sed 's/\.qml$//' | sort -u)
    for scan_file in "$SHELL_DIR/shell.qml" "$SHELL_DIR/Bar.qml"; do
        [ -f "$scan_file" ] || continue
        REFS=$(grep -oE '^\s*[A-Z][a-zA-Z0-9_]*\s*\{' "$scan_file" 2>/dev/null \
               | sed 's/\s*{$//' | sed 's/^\s*//' | sort -u \
               | grep -vE '^(Item|Rectangle|Row|Column|Grid|RowLayout|ColumnLayout|GridLayout|StackLayout|Text|Image|MouseArea|Loader|Repeater|Timer|Process|Binding|Connections|Behavior|NumberAnimation|PropertyAnimation|SequentialAnimation|ParallelAnimation|State|Transition|PathAnimation|PathView|ListView|GridView|TableView|ScrollView|Flickable|Popup|ApplicationWindow|Window|PanelWindow|FloatingWindow|PopupWindow|ShellRoot|IpcHandler|Variants|LayerSurface|ExclusiveZone|WlrLayer|Scope|Component|QtObject|Package|SystemTrayItem|Socket|FileView|Quickshell|Hyprland|Keys|Anchors|Margins|AnchorChanges|PropertyChanges|StateGroup|PathLine|PathQuad|PathCubic|Path|Gradient|GradientStop|Canvas|ShaderEffect|ShaderEffectSource|Flow|Pane|Control|TextInput|TextEdit|TextField|TextArea|Button|CheckBox|RadioButton|Slider|SpinBox|ComboBox|ProgressBar|ScrollBar|Switch|Label|GroupBox|Menu|MenuItem|ToolTip|Dialog|DialogButtonBox|BusyIndicator|Frame|ToolBar|TabBar|TabButton|StackView|Page|PageIndicator|Drawer|Action|ActionGroup)$')

        for ref in $REFS; do
            if ! echo "$PROVIDED" | grep -qx "$ref"; then
                if ! find "$SHELL_DIR" -maxdepth 2 -name "${ref}.qml" 2>/dev/null | grep -q .; then
                    MISSING_TYPES="$MISSING_TYPES $ref"
                fi
            fi
        done
    done

    MISSING_TYPES=$(echo "$MISSING_TYPES" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')

    if [ -z "$MISSING_TYPES" ]; then
        echo "    ✓ All QML types referenced by shell.qml / Bar.qml resolve to local .qml files"
    else
        echo "  ⚠ References to types without matching .qml file(s):"
        for t in $MISSING_TYPES; do
            echo "      - $t  (expected: $SHELL_DIR/${t}.qml)"
        done
        echo ""
        echo "    This is usually fine if you've customized shell.qml with external types."
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [8.7/9] Hyprland plugins auto-install (v6.16.4.12.6.22+ smart)
# ═══════════════════════════════════════════════════════════════
# Smart auto-install with retry-on-header-failure logic. Common
# failure modes handled:
#
#   1. Outdated headers:        run `hyprpm purge-cache` then retry
#   2. Missing base-devel:      detect + offer to install via pacman
#   3. Missing meson/cmake:     specific package suggestion
#   4. Wrong Hyprland source:   suggest reinstalling hyprland-headers
#   5. Permission/polkit issue: clearly explain need for auth daemon
#
# Skip conditions (still respected):
#   - ZEN_NO_PLUGIN_INSTALL=1  → user opt-out
#   - hyprpm not in PATH       → silent skip with hint
#   - Not inside Hyprland      → skip (hyprpm needs active instance)
#
# Plugins (4 from 2 repos):
#   - hyprland-plugins repo: hyprbars, hyprexpo, hyprwinwrap, borders++, xtra-dispatchers
#
# v6.16.4.12.6.51 (Hikari): TEMPORARILY DISABLED. The hyprpm sub-system
# needs more stability work before being re-enabled by the installer.
# The QML-side Plugins page is also hidden (see ZenSettings.qml). To
# re-enable the auto-install: change `if false` to `if true` below.
# Manual install is still possible:
#     hyprpm add https://github.com/hyprwm/hyprland-plugins
#     hyprpm update
#     hyprpm enable hyprbars     # (or any plugin)
#     hyprpm reload

echo ""
echo "[8.7/9] Hyprland plugins auto-install... SKIPPED (temporarily disabled in v6.16.4.12.6.51)"

if false; then   # ── BEGIN temporarily-disabled block ──

# ── Helpers (scoped to this step) ──────────────────────────────────
_hyprpm_check_deps() {
    local missing=""
    for cmd in cmake meson make gcc g++ pkg-config; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done
    if [ -n "$missing" ]; then
        echo "    ⚠ Missing build tools:$missing"
        echo "      hyprpm needs them to compile plugins."
        echo "      Install with: sudo pacman -S --needed base-devel cmake meson"
        return 1
    fi
    return 0
}

# Run hyprpm with -v (verbose) so user sees real-time progress.
# Captures full output for parsing while ALSO streaming it live to
# stdout. Done via process substitution + tee.
_hyprpm_run_update() {
    local LOG=$(mktemp)
    echo "    [verbose mode — full hyprpm output below]"
    echo "    ────────────────────────────────────────────"
    if hyprpm -v update 2>&1 | tee "$LOG" | sed 's/^/      │ /'; then
        :
    fi
    echo "    ────────────────────────────────────────────"
    local OUT
    OUT=$(cat "$LOG")
    rm -f "$LOG"
    if echo "$OUT" | grep -qE "error code|Failed|Headers (version mismatch|outdated|missing|corrupted)|Couldn't update headers"; then
        return 1
    fi
    return 0
}

# Detect plugins that are already enabled in hyprpm — for `--needed`
# semantics. Returns space-separated list.
_hyprpm_already_enabled() {
    hyprpm list 2>/dev/null \
        | awk '/Plugin / {p=$NF; next} /enabled: true/ {print p}' \
        | tr '\n' ' '
}

# Interactive Y/n/skip prompt — only asks if stdin is a TTY (not piped).
# Defaults to YES if no stdin (e.g. piped install).
# Honors ZEN_NO_PLUGIN_INSTALL=1 (auto-skip) and ZEN_AUTO_PLUGIN_INSTALL=1
# (auto-yes, no prompt).
_ask_install_plugins() {
    if [ "${ZEN_NO_PLUGIN_INSTALL:-}" = "1" ]; then
        echo "    [auto-skip via ZEN_NO_PLUGIN_INSTALL=1]"
        return 1
    fi
    if [ "${ZEN_AUTO_PLUGIN_INSTALL:-}" = "1" ]; then
        echo "    [auto-yes via ZEN_AUTO_PLUGIN_INSTALL=1]"
        return 0
    fi
    if [ ! -t 0 ]; then
        # Non-interactive — default to yes
        echo "    [non-interactive — defaulting to YES]"
        return 0
    fi
    # Interactive prompt
    echo ""
    echo "    Install Hyprland plugins (hyprbars, hyprexpo, hyprwinwrap, borders++, xtra-dispatchers)?"
    echo "      Y/y/[Enter] = Install (default)"
    echo "      N/n         = Skip plugins entirely"
    echo "      S/s         = Skip plugins this run, ask again next install"
    echo ""
    local ans
    read -r -p "    Your choice [Y/n/s]: " ans
    case "$ans" in
        ""|"y"|"Y"|"yes"|"YES")
            echo "    → Will install plugins."
            return 0
            ;;
        "n"|"N"|"no"|"NO")
            echo "    → Skipping plugins. Set ZEN_NO_PLUGIN_INSTALL=1 to skip silently next time."
            return 1
            ;;
        "s"|"S"|"skip"|"SKIP")
            echo "    → Skipping for this run only."
            return 1
            ;;
        *)
            echo "    → Unrecognized answer '$ans' — defaulting to YES."
            return 0
            ;;
    esac
}

# ── Main flow ─────────────────────────────────────────────────────
if [ "${ZEN_NO_PLUGIN_INSTALL:-}" = "1" ]; then
    echo "    Skipped (ZEN_NO_PLUGIN_INSTALL=1 in env)"
elif ! command -v hyprpm >/dev/null 2>&1; then
    echo "    Skipped — hyprpm not found in PATH"
    echo "    Most CachyOS / Arch Hyprland packages include hyprpm."
    echo "    If you need it, install Hyprland from official repos:"
    echo "      sudo pacman -S hyprland"
elif [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "    Skipped — not running inside Hyprland session"
    echo "    Re-run install.sh from inside Hyprland to auto-install plugins."
elif ! _hyprpm_check_deps; then
    echo ""
    echo "    Skipping plugin install due to missing build tools."
    echo "    After installing them, re-run this installer."
elif ! _ask_install_plugins; then
    echo "    Plugin install skipped by user choice."
    echo "    You can install later via Settings → Hyprland Plugins"
    echo "    or by running: ZEN_AUTO_PLUGIN_INSTALL=1 ./install.sh"
else
    # ── Detect what's already enabled — skip those (--needed semantics) ──
    ALREADY_ENABLED=$(_hyprpm_already_enabled)
    if [ -n "$ALREADY_ENABLED" ]; then
        echo ""
        echo "    Already-enabled plugins (will use --needed semantics, won't reinstall):"
        echo "$ALREADY_ENABLED" | tr ' ' '\n' | sed 's/^/      ✓ /' | head -10
    fi

    PLUGIN_REPOS=(
        "https://github.com/hyprwm/hyprland-plugins"
    )
    PLUGINS_TO_ENABLE=(
        "hyprbars"
        "hyprexpo"
        "hyprwinwrap"
        "borders-plus-plus"
        "xtra-dispatchers"
    )

    # ── PHASE 0: Purge non-official sources (v6.16.4.12.6.29) ──
    # If user previously installed any of our managed plugins from AUR
    # or manually-symlinked sources, remove them so hyprwm/hyprland-plugins
    # is the SOLE source of truth. This prevents version drift between
    # the official repo and shadow installations that confuse hyprpm.
    echo ""
    echo "    Phase 0/4: Detect + purge non-official plugin sources..."

    PURGED_ANY=0
    HYPRPM_PLUGINS_DIR="$HOME/.local/share/hyprpm/hyprland-plugins"

    # Check for AUR-installed per-plugin packages
    if command -v pacman >/dev/null 2>&1; then
        for plugin in "${PLUGINS_TO_ENABLE[@]}"; do
            for pkg in "hyprland-plugin-${plugin}-git" "hyprland-plugin-${plugin}"; do
                if pacman -Qi "$pkg" >/dev/null 2>&1; then
                    echo "      → Found AUR package: $pkg"
                    echo "        (will keep package, but ensure hyprpm uses official repo)"
                    PURGED_ANY=1
                fi
            done
        done
    fi

    # Check for symlinks in hyprpm dir pointing OUTSIDE hyprpm
    # (e.g. → /usr/lib/hyprland-plugins/*.so from AUR)
    if [ -d "$HYPRPM_PLUGINS_DIR" ]; then
        for plugin in "${PLUGINS_TO_ENABLE[@]}"; do
            so="$HYPRPM_PLUGINS_DIR/$plugin/$plugin.so"
            if [ -L "$so" ]; then
                # It's a symlink — is target inside hyprpm dir?
                target=$(readlink -f "$so" 2>/dev/null || echo "")
                if [ -n "$target" ] && [[ ! "$target" =~ ^"$HYPRPM_PLUGINS_DIR" ]]; then
                    echo "      ✗ Removing rogue symlink: $plugin.so → $target"
                    rm -f "$so"
                    PURGED_ANY=1
                fi
            fi
        done
    fi

    if [ "$PURGED_ANY" = "1" ]; then
        echo "      ✓ Cleanup done. Will rebuild from hyprwm/hyprland-plugins"
    else
        echo "      ✓ No conflicting sources detected"
    fi

    # ── PHASE 1: hyprpm update with smart retry ──
    echo ""
    echo "    Phase 1/4: Updating hyprpm headers (may prompt for sudo)..."
    if _hyprpm_run_update; then
        echo "    ✓ Headers updated successfully"
    else
        echo ""
        echo "    ⚠ hyprpm update failed (likely outdated/mismatched headers)"
        echo "    Auto-recovery: running hyprpm purge-cache then retrying..."
        echo ""
        hyprpm purge-cache 2>&1 | sed 's/^/      /' || \
            echo "      (purge-cache may not exist on older hyprpm)"

        # Also clean up stale cache directories (older hyprpm versions)
        rm -rf "$HOME/.local/share/hyprpm/headersRoot" 2>/dev/null || true
        rm -rf "/tmp/hyprpm" 2>/dev/null || true

        echo "    Phase 1 retry: hyprpm update..."
        if _hyprpm_run_update; then
            echo "    ✓ Headers updated successfully (after purge)"
        else
            echo ""
            echo "    ✗ hyprpm update STILL failed after purge-cache."
            echo ""
            echo "    Common causes + fixes:"
            echo "      • Hyprland version mismatch with hyprland-headers"
            echo "        → Reinstall: sudo pacman -S --needed hyprland"
            echo "      • Missing polkit/auth daemon (sudo prompt didn't show)"
            echo "        → Check polkit running: systemctl status polkit"
            echo "      • Custom Hyprland build (git/AUR) without matching headers"
            echo "        → Use official repo Hyprland or build headers manually"
            echo ""
            echo "    For verbose error: hyprpm -v update"
            echo "    Then check: tail -50 ~/.local/share/hyprpm/state.toml"
            echo ""
            echo "    Skipping plugin install — you can retry later via Settings"
            echo "    → Hyprland Plugins → Copy install command per plugin."
            HYPRPM_OK=0
        fi
    fi

    # ── PHASE 2: Add plugin repos (verbose, --needed semantics) ──
    if [ "${HYPRPM_OK:-1}" = "1" ]; then
        echo ""
        echo "    Phase 2/4: Adding plugin repositories (verbose mode)..."
        # Detect existing repos so we can apply --needed semantics
        EXISTING_REPOS=$(hyprpm list 2>/dev/null \
            | awk '/^→ Repository/ {print $3}' \
            | tr '\n' ' ' || echo "")
        for repo in "${PLUGIN_REPOS[@]}"; do
            repo_name=$(basename "$repo")
            # --needed check: skip if repo already added
            if echo " $EXISTING_REPOS " | grep -q " $repo_name "; then
                echo "      ✓ $repo_name (already added, --needed skip)"
                continue
            fi
            echo ""
            echo "      Adding: $repo_name"
            echo "      ────────────────────────────────────────────"
            # Use -v for verbose, tee to capture for parsing while streaming
            ADD_LOG=$(mktemp)
            hyprpm -v add "$repo" 2>&1 | tee "$ADD_LOG" | sed 's/^/        │ /'
            echo "      ────────────────────────────────────────────"
            ADD_OUT=$(cat "$ADD_LOG")
            rm -f "$ADD_LOG"
            if echo "$ADD_OUT" | grep -qE "already (exists|added)"; then
                echo "      ✓ $repo_name (already present)"
            elif echo "$ADD_OUT" | grep -qE "fail|error" && \
                 ! echo "$ADD_OUT" | grep -qE "all plugins built|installed repository"; then
                echo "      ⚠ $repo_name had errors (some plugins may have failed to build)"
            else
                echo "      ✓ $repo_name added"
            fi
        done

        # ── PHASE 3: Enable each plugin (with build-status detection) ──
        echo ""
        echo "    Phase 3/4: Enabling plugins (smart build detection)..."

        # First: capture which plugins ACTUALLY built successfully via hyprpm list.
        # Output format includes lines like:
        #   │ Plugin hyprbars
        #   └─ enabled: false
        # OR for failed builds:
        #   └─ enabled: Plugin failed to build
        BUILT_PLUGINS=$(hyprpm list 2>/dev/null \
            | awk '/Plugin / {p=$NF; next} /enabled:/ {if (!/failed/) print p}' \
            | tr '\n' ' ')
        FAILED_PLUGINS=$(hyprpm list 2>/dev/null \
            | awk '/Plugin / {p=$NF; next} /enabled:.*failed/ {print p}' \
            | tr '\n' ' ')

        echo "      Built successfully:${BUILT_PLUGINS:- (none)}"
        if [ -n "$FAILED_PLUGINS" ]; then
            echo "      Build failed (will retry via AUR fallback if available):"
            echo "$FAILED_PLUGINS" | tr ' ' '\n' | sed 's/^/        ✗ /' | head -10
        fi

        # ── No AUR fallback (v6.16.4.12.6.28: simplified) ──
        # We rely solely on hyprwm/hyprland-plugins official repo. If a
        # plugin fails to build, we just report it. User can manually
        # install AUR per-plugin packages if needed (rare).
        if [ -n "$FAILED_PLUGINS" ]; then
            echo ""
            echo "    Note: ${FAILED_PLUGINS}failed to build (Hyprland version mismatch with official repo)."
            echo "    These will retry on next install. Manual fix if urgent:"
            echo "      paru -S hyprland-plugin-<name>-git    # per-plugin AUR fallback"
        fi

        # ── PHASE 3b: Enable the plugins that DID build ──
        echo ""
        echo "    Phase 3b/4: Enabling successfully-built plugins (verbose, --needed)..."
        # Re-snapshot already-enabled (may have changed after AUR fallback)
        ALREADY_ENABLED=$(_hyprpm_already_enabled)
        enabled_count=0
        skipped_count=0
        already_count=0
        for plugin in "${PLUGINS_TO_ENABLE[@]}"; do
            # --needed: skip if already enabled
            if echo " $ALREADY_ENABLED " | grep -q " $plugin "; then
                echo "      ✓ $plugin (already enabled, --needed skip)"
                already_count=$((already_count+1))
                continue
            fi
            # Check if built
            if echo " $BUILT_PLUGINS " | grep -q " $plugin "; then
                echo "      → enabling $plugin..."
                EN_OUT=$(hyprpm enable "$plugin" 2>&1)
                echo "$EN_OUT" | sed 's/^/        │ /'
                if echo "$EN_OUT" | grep -qiE "enabled|loaded|already enabled|plugin load state ensured"; then
                    echo "      ✓ $plugin enabled"
                    enabled_count=$((enabled_count+1))
                else
                    echo "      ⚠ $plugin enable returned unexpected output (see above)"
                fi
            else
                echo "      ⊘ $plugin (build failed — skipping enable)"
                skipped_count=$((skipped_count+1))
            fi
        done

        # ── Write a state file the QML PluginsPage will read ──
        # This lets the UI show which plugins are actually available vs
        # which ones failed to build, with a clear explanation per plugin.
        STATE_DIR="$HOME/.config/quickshell/zen-shell"
        mkdir -p "$STATE_DIR"
        STATE_FILE="$STATE_DIR/hyprpm-state.json"
        {
            echo "{"
            echo "  \"updated_at\": \"$(date -Iseconds)\","
            echo "  \"hyprland_version\": \"$(hyprctl version 2>/dev/null | head -1 | sed 's/.*Hyprland \\([0-9.]*\\).*/\\1/' || echo unknown)\","
            echo "  \"built\": ["
            FIRST=1
            for p in $BUILT_PLUGINS; do
                [ "$FIRST" = 1 ] || echo ","
                printf '    "%s"' "$p"
                FIRST=0
            done
            echo ""
            echo "  ],"
            echo "  \"failed\": ["
            FIRST=1
            for p in $FAILED_PLUGINS; do
                # Skip if it's now in built list (AUR fallback rescued it)
                if echo " $BUILT_PLUGINS " | grep -q " $p "; then continue; fi
                [ "$FIRST" = 1 ] || echo ","
                printf '    "%s"' "$p"
                FIRST=0
            done
            echo ""
            echo "  ]"
            echo "}"
        } > "$STATE_FILE"
        echo "      ↳ wrote state to $STATE_FILE"

        # ── PHASE 4: Reload ──
        echo ""
        echo "    Phase 4/4: Reloading hyprpm..."
        hyprpm reload 2>&1 | sed 's/^/      /' || \
            echo "      (reload skipped — Hyprland will pick up plugins on next config reload)"

        echo ""
        echo "    Plugin install summary:"
        echo "      ✓ Newly enabled:    $enabled_count"
        if [ "${already_count:-0}" -gt 0 ]; then
            echo "      ✓ Already enabled:  $already_count (--needed, no reinstall)"
        fi
        if [ "${skipped_count:-0}" -gt 0 ]; then
            echo "      ⊘ Build skipped:    $skipped_count (see Settings → Plugins for help)"
        fi
        echo "      ↳ Total available:  ${#PLUGINS_TO_ENABLE[@]} plugin(s) defined in Zen Shell"
        echo "      ↳ Toggle ON/OFF live in Settings → Hyprland Plugins"

        # ── Final verification: show hyprpm list output ──
        # User specifically asked: "kapag ng hyprpm list ako makita ko lahat"
        # So we run hyprpm list at the end and highlight expected plugins.
        echo ""
        echo "    ┌─────────────────────────────────────────────────────────┐"
        echo "    │ Verification: hyprpm list output                        │"
        echo "    └─────────────────────────────────────────────────────────┘"
        HYPRPM_LIST=$(hyprpm list 2>&1)
        echo "$HYPRPM_LIST" | sed 's/^/      /'

        # Check each managed plugin appears in the list
        echo ""
        echo "    ┌─────────────────────────────────────────────────────────┐"
        echo "    │ Per-plugin status check                                 │"
        echo "    └─────────────────────────────────────────────────────────┘"
        for plugin in "${PLUGINS_TO_ENABLE[@]}"; do
            if echo "$HYPRPM_LIST" | grep -q "Plugin $plugin"; then
                # Found in list — check enabled state
                state=$(echo "$HYPRPM_LIST" | grep -A1 "Plugin $plugin" | grep "enabled:" | head -1 | sed 's/.*enabled:\s*//')
                case "$state" in
                    *"true"*)   echo "      ✓ $plugin    listed + enabled" ;;
                    *"false"*)  echo "      ○ $plugin    listed (not enabled — toggle ON in Settings)" ;;
                    *"failed"*) echo "      ✗ $plugin    build failed (Hyprland version mismatch)" ;;
                    *)          echo "      ? $plugin    listed, state: $state" ;;
                esac
            else
                echo "      ✗ $plugin    NOT in hyprpm list (something went wrong)"
            fi
        done
        echo ""

        if [ -n "$FAILED_PLUGINS" ] && ! (command -v paru >/dev/null 2>&1 || command -v yay >/dev/null 2>&1); then
            echo ""
            echo "      Tip: Install an AUR helper (paru or yay) so the next install"
            echo "           can auto-fallback to per-plugin AUR packages for missing"
            echo "           plugins:"
            echo "           sudo pacman -S --needed base-devel git"
            echo "           git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si"
        fi
    fi
fi

fi   # ── END temporarily-disabled block (v6.16.4.12.6.51) ──


# v6.16.2.3.6 and earlier ALSO spawned a 'qs -c zen-shell' here, then
# the end-of-install block at the bottom of the file spawned ANOTHER
# 'quickshell -p ...' instance. The end-of-install kill loop only
# matched 'quickshell.*zen-shell', missing the 'qs' invocation from
# this step → TWO bars on every install.
#
# v6.16.2.3.7 makes step [9/9] kill-only. The single canonical spawn
# is owned by the v6.16.2.3.7 launch block at the end of the file.

# ═══════════════════════════════════════════════════════════════
# [8.9/9] Restore user profile settings to Hyprland (v6.16.4.12.6.51)
# ═══════════════════════════════════════════════════════════════
# After all the .conf files are in place but BEFORE the shell relaunch,
# push the user's saved settings-state.json values back to Hyprland via
# `hyprctl --batch keyword …`. This mirrors what SettingsState.qml does
# on shell startup, but does it eagerly here so the gaps/border/
# rounding/opacity/blur values from the saved profile are visible
# immediately instead of waiting for the user to change a theme to
# trigger a re-apply.
#
# This step is read-only on the JSON files — it never writes them back.
# If the JSON is missing or empty, it skips silently (genuine fresh
# install case where SettingsState seeds from Hyprland on first run).
echo ""
echo "[8.9/9] Restoring user profile settings to Hyprland..."

SETTINGS_JSON="$HOME/.config/quickshell/zen-shell/settings-state.json"
SETTINGS_V2_JSON="$HOME/.config/quickshell/zen-shell/settings-state-v2.json"

# Helper: extract a numeric value from the JSON. Greps the line
# containing  "key": <number>  and pulls out the number. Tolerates
# integer or float, with or without trailing comma.
_zen_json_num() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || { echo ""; return; }
    grep -oE "\"$key\"[[:space:]]*:[[:space:]]*-?[0-9]+(\.[0-9]+)?" "$file" 2>/dev/null \
        | head -1 \
        | sed -E "s/.*:[[:space:]]*//"
}

# Helper: extract a boolean value (true/false) from the JSON.
_zen_json_bool() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || { echo ""; return; }
    grep -oE "\"$key\"[[:space:]]*:[[:space:]]*(true|false)" "$file" 2>/dev/null \
        | head -1 \
        | sed -E "s/.*:[[:space:]]*//"
}

if [ ! -f "$SETTINGS_JSON" ] && [ ! -f "$SETTINGS_V2_JSON" ]; then
    echo "    No saved settings profile found — skipping (fresh install)"
elif ! command -v hyprctl >/dev/null 2>&1; then
    echo "    Skipped — hyprctl not in PATH"
elif [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "    Skipped — not running inside a live Hyprland session"
    echo "    (your settings will still apply automatically next time the shell starts)"
else
    # Pull the values from whichever JSON file exists (V2 takes priority)
    SRC="$SETTINGS_JSON"
    [ -f "$SETTINGS_V2_JSON" ] && SRC="$SETTINGS_V2_JSON"

    SAVED_GAPS_IN=$(_zen_json_num "$SRC" "gapsIn")
    SAVED_GAPS_OUT=$(_zen_json_num "$SRC" "gapsOut")
    SAVED_BORDER=$(_zen_json_num "$SRC" "borderSize")
    SAVED_ROUNDING=$(_zen_json_num "$SRC" "rounding")
    SAVED_ACTIVE_OPACITY=$(_zen_json_num "$SRC" "activeOpacity")
    SAVED_INACTIVE_OPACITY=$(_zen_json_num "$SRC" "inactiveOpacity")
    SAVED_BLUR_ENABLED=$(_zen_json_bool "$SRC" "blurEnabled")
    SAVED_BLUR_SIZE=$(_zen_json_num "$SRC" "blurSize")
    SAVED_BLUR_PASSES=$(_zen_json_num "$SRC" "blurPasses")

    BATCH=""
    APPLIED_LIST=""
    if [ -n "$SAVED_GAPS_IN" ]; then
        BATCH="${BATCH}keyword general:gaps_in $SAVED_GAPS_IN;"
        APPLIED_LIST="${APPLIED_LIST}      gaps_in        = $SAVED_GAPS_IN
"
    fi
    if [ -n "$SAVED_GAPS_OUT" ]; then
        BATCH="${BATCH}keyword general:gaps_out $SAVED_GAPS_OUT;"
        APPLIED_LIST="${APPLIED_LIST}      gaps_out       = $SAVED_GAPS_OUT
"
    fi
    if [ -n "$SAVED_BORDER" ]; then
        BATCH="${BATCH}keyword general:border_size $SAVED_BORDER;"
        APPLIED_LIST="${APPLIED_LIST}      border_size    = $SAVED_BORDER
"
    fi
    if [ -n "$SAVED_ROUNDING" ]; then
        BATCH="${BATCH}keyword decoration:rounding $SAVED_ROUNDING;"
        APPLIED_LIST="${APPLIED_LIST}      rounding       = $SAVED_ROUNDING
"
    fi
    if [ -n "$SAVED_ACTIVE_OPACITY" ]; then
        BATCH="${BATCH}keyword decoration:active_opacity $SAVED_ACTIVE_OPACITY;"
        APPLIED_LIST="${APPLIED_LIST}      active_opacity = $SAVED_ACTIVE_OPACITY
"
    fi
    if [ -n "$SAVED_INACTIVE_OPACITY" ]; then
        BATCH="${BATCH}keyword decoration:inactive_opacity $SAVED_INACTIVE_OPACITY;"
        APPLIED_LIST="${APPLIED_LIST}      inactive_opacity = $SAVED_INACTIVE_OPACITY
"
    fi
    if [ -n "$SAVED_BLUR_ENABLED" ]; then
        BATCH="${BATCH}keyword decoration:blur:enabled $SAVED_BLUR_ENABLED;"
        APPLIED_LIST="${APPLIED_LIST}      blur:enabled   = $SAVED_BLUR_ENABLED
"
    fi
    if [ -n "$SAVED_BLUR_SIZE" ]; then
        BATCH="${BATCH}keyword decoration:blur:size $SAVED_BLUR_SIZE;"
        APPLIED_LIST="${APPLIED_LIST}      blur:size      = $SAVED_BLUR_SIZE
"
    fi
    if [ -n "$SAVED_BLUR_PASSES" ]; then
        BATCH="${BATCH}keyword decoration:blur:passes $SAVED_BLUR_PASSES;"
        APPLIED_LIST="${APPLIED_LIST}      blur:passes    = $SAVED_BLUR_PASSES
"
    fi

    if [ -n "$BATCH" ]; then
        # Strip the trailing semicolon then push to Hyprland in one batch
        BATCH="${BATCH%;}"
        if hyprctl --batch "$BATCH" >/dev/null 2>&1; then
            echo "    Applied saved profile values to running Hyprland session:"
            printf "%s" "$APPLIED_LIST"
            echo "    (Source: $(basename "$SRC"))"
        else
            echo "    ⚠ hyprctl --batch failed — values will reapply on next shell start."
        fi
    else
        echo "    No numeric values found in saved profile — skipping (defaults stay in place)"
    fi
fi

echo ""
echo "[9/9] Pre-launch cleanup — kill any running zen-shell instances..."
# v6.16.4.12.6.31: Use the proven kill recipe — pkill -9 + sleep 2.
# Previous SIGTERM-then-SIGKILL loop was unreliable, leading to double
# bars after install.
pkill -9 -f 'quickshell' 2>/dev/null || true
pkill -9 -x qs 2>/dev/null || true
pkill -9 -f 'qs.*zen-shell' 2>/dev/null || true
rm -rf "/run/user/$(id -u)/quickshell/by-id"/* 2>/dev/null || true
sleep 2

SURV1=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null | wc -l)
SURV1=$(echo "$SURV1" | tr -cd '0-9' | head -c 6)
SURV1=${SURV1:-0}
if [ "$SURV1" -gt 0 ] 2>/dev/null; then
    echo "    ⚠ $SURV1 process(es) survived SIGKILL — end-of-install spawn will refuse to start a duplicate."
else
    echo "    ✓ All previous zen-shell instances stopped cleanly (SIGKILL + 2s wait)."
fi

# Best-effort: start swww-daemon if it's not already running. The shell
# expects it but does NOT spawn a new shell here — that's reserved for
# the single canonical launch block at the end of the file.
command -v swww >/dev/null 2>&1 && ! swww query >/dev/null 2>&1 && {
    if command -v swww-daemon >/dev/null 2>&1; then
        setsid swww-daemon </dev/null >/dev/null 2>&1 & disown 2>/dev/null || true
    else
        setsid swww init </dev/null >/dev/null 2>&1 & disown 2>/dev/null || true
    fi
    sleep 1
    echo "    swww-daemon started"
}

# Reload Hyprland config so any new source = lines / module changes apply
# before the shell reattaches its layer surface.
pgrep -x Hyprland >/dev/null && sleep 0.3 && hyprctl reload 2>/dev/null && echo "    Hyprland reloaded"

sleep 0.5

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
QML_FINAL=$(ls -1 "$SHELL_DIR/"*.qml 2>/dev/null | wc -l)
SWWW_ALIVE="no";  command -v swww >/dev/null 2>&1 && swww query >/dev/null 2>&1 && SWWW_ALIVE="yes"
SWAYNC_ALIVE="no"; pgrep -x swaync >/dev/null 2>&1 && SWAYNC_ALIVE="yes"
CAVA_OK="no";      command -v cava >/dev/null 2>&1 && CAVA_OK="yes"
PCTL_OK="no";      command -v playerctl >/dev/null 2>&1 && PCTL_OK="yes"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     🎉  ZEN SHELL v6.16.4.12.6.53 · HIRAKI INSTALLED  🎉      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  ── Install summary ──"
echo "    QML files installed:   $QML_FINAL"
echo "    Toggle scripts:        $INSTALLED_SCRIPTS_COUNT in $BIN_DIR"
echo "    Builtin themes:        $INSTALLED_THEMES_COUNT"
echo "    swww daemon alive:     $SWWW_ALIVE"
echo "    swaync daemon alive:   $SWAYNC_ALIVE"
echo "    cava available:        $CAVA_OK"
echo "    playerctl available:   $PCTL_OK"
if [ -n "$INSTALLED_OPTIONAL_PACKAGES" ]; then
    echo "    Optional pkgs added:   $INSTALLED_OPTIONAL_PACKAGES"
fi
if [ -n "$SKIPPED_OPTIONAL_PACKAGES" ]; then
    echo "    Optional pkgs skipped: $SKIPPED_OPTIONAL_PACKAGES"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# v6.16.2.3.2: SEED zen-mouse.conf + INJECT source line into hyprland.conf
# ═══════════════════════════════════════════════════════════════════════
ZEN_MOUSE_CONF="${HOME}/.config/hypr/zen-mouse.conf"
ZEN_HYPRLAND_CONF="${HOME}/.config/hypr/hyprland.conf"

mkdir -p "${HOME}/.config/hypr"
if [ ! -f "${ZEN_MOUSE_CONF}" ]; then
    cat > "${ZEN_MOUSE_CONF}" << 'ZSMOUSE'
# Zen Shell v6.16.2.3.7 — managed mouse settings
# Edit via Control Panel → Input, not by hand.
input {
    sensitivity     = 0.0
    scroll_factor   = 1.0
    natural_scroll  = false
    touchpad {
        natural_scroll = false
    }
}
ZSMOUSE
    echo "  ── Seeded ${ZEN_MOUSE_CONF}"
fi

if [ -f "${ZEN_HYPRLAND_CONF}" ]; then
    if ! grep -q "zen-mouse.conf" "${ZEN_HYPRLAND_CONF}"; then
        cat >> "${ZEN_HYPRLAND_CONF}" << 'ZSAPP'

# Zen Shell v6.16.2.3.7: mouse settings (managed by Control Panel → Input)
source = ~/.config/hypr/zen-mouse.conf
ZSAPP
        echo "  ── Injected source line into ${ZEN_HYPRLAND_CONF}"
    fi
fi

echo "  ── Diagnostics ──"
echo "    tail -30 /tmp/zen-shell.log"
echo "    playerctl status"
echo "    cava   (test standalone)"
echo "    pgrep -fa 'quickshell.*zen-shell|qs.*zen-shell'   # should show ONE line"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# v6.16.2.3.2: DEFAULT WALLPAPER FETCH
# ═══════════════════════════════════════════════════════════════════════
ZEN_WP_DIR="${HOME}/.config/zen-shell/wallpapers"
ZEN_WP_STATE="${HOME}/.config/quickshell/zen-shell/wallpaper-state.json"
ZEN_DEFAULT_WP_NAME="123824383_p0 (Edited) compressed.png"
ZEN_DEFAULT_WP_URL="https://raw.githubusercontent.com/Gekinzen/images-demo/main/wallpapers/123824383_p0%20(Edited)%20compressed.png"
ZEN_DEFAULT_WP_LOCAL="${ZEN_WP_DIR}/${ZEN_DEFAULT_WP_NAME}"

mkdir -p "${ZEN_WP_DIR}"

_is_fresh_wallpaper() {
    [ ! -f "${ZEN_WP_STATE}" ] && return 0
    local current
    current=$(grep -oE '"currentPath"[[:space:]]*:[[:space:]]*"[^"]*"' "${ZEN_WP_STATE}" 2>/dev/null | sed -E 's/.*"([^"]*)"$/\1/')
    [ -z "${current}" ] && return 0
    [ ! -f "${current}" ] && return 0
    return 1
}

echo "  ── Default wallpaper ──"
if command -v curl >/dev/null 2>&1; then
    if [ ! -f "${ZEN_DEFAULT_WP_LOCAL}" ]; then
        echo "    Downloading default wallpaper from Gekinzen/images-demo ..."
        if curl -fsSL --connect-timeout 10 --max-time 60 \
                -o "${ZEN_DEFAULT_WP_LOCAL}" "${ZEN_DEFAULT_WP_URL}"; then
            echo "    ✅  Saved to ${ZEN_DEFAULT_WP_LOCAL}"
        else
            echo "    ⚠️   Download failed (offline? repo private?) — skipping."
            rm -f "${ZEN_DEFAULT_WP_LOCAL}" 2>/dev/null
        fi
    else
        echo "    ✅  Already cached at ${ZEN_DEFAULT_WP_LOCAL}"
    fi

    if [ -f "${ZEN_DEFAULT_WP_LOCAL}" ] && _is_fresh_wallpaper; then
        echo "    Fresh install detected → applying default wallpaper."
        if command -v swww >/dev/null 2>&1; then
            swww query >/dev/null 2>&1 || swww-daemon >/dev/null 2>&1 &
            sleep 0.3
            swww img "${ZEN_DEFAULT_WP_LOCAL}" \
                --transition-type fade --transition-duration 0.6 \
                >/dev/null 2>&1 || true
            mkdir -p "$(dirname "${ZEN_WP_STATE}")"
            cat > "${ZEN_WP_STATE}" << JSONEOF
{
  "currentPath": "${ZEN_DEFAULT_WP_LOCAL}",
  "appliedBy": "install.sh-v6.16.2.3.7"
}
JSONEOF
            echo "    ✅  Default wallpaper applied via swww."
        else
            echo "    ⚠️   swww not found — wallpaper downloaded but not applied."
            echo "         Run: swww img \"${ZEN_DEFAULT_WP_LOCAL}\""
        fi
    else
        echo "    ℹ️   User already has a wallpaper — not overriding."
    fi
else
    echo "    ⚠️   curl not found — cannot fetch default wallpaper."
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# v6.16.3 STACK — idempotent apply of smart-lid + wake + lock changes
# ───────────────────────────────────────────────────────────────────────
# Replaces the standalone install-v6.16.3.2.1-overlay.sh. Runs on every
# `./install.sh` invocation so the v6.16.3 files are always in sync with
# the tarball. Individual phases are idempotent — re-running is cheap.
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "  ── v6.16.3 stack (smart lid + wake recovery + lock redesign) ──"

# Phase A — lock screen + idle daemon deps
# Added in v6.16.3.2.1: auto-detect + offer paru/yay/pacman install for
# hyprlock + hypridle. Earlier optional-deps loop above already covered
# this during the fresh-install flow; we still check here in case user
# answered "n" to that prompt but changed their mind, OR is running a
# re-install after initial setup.
V6163_NEED=()
command -v hyprlock >/dev/null 2>&1 || V6163_NEED+=(hyprlock)
command -v hypridle >/dev/null 2>&1 || V6163_NEED+=(hypridle)
if [ ${#V6163_NEED[@]} -gt 0 ]; then
    echo "    hyprlock/hypridle missing: ${V6163_NEED[*]}"
    V6163_INSTALLER=""
    if command -v paru >/dev/null 2>&1; then V6163_INSTALLER="paru"
    elif command -v yay >/dev/null 2>&1; then V6163_INSTALLER="yay"
    elif command -v pacman >/dev/null 2>&1; then V6163_INSTALLER="sudo pacman"
    fi
    if [ -n "$V6163_INSTALLER" ]; then
        printf '    Install with `%s -S --needed %s`? [Y/n] ' "$V6163_INSTALLER" "${V6163_NEED[*]}"
        read -r V6163_ANS
        case "$V6163_ANS" in
            n|N|no|NO) echo "    skipped — lock screen + auto-lock disabled until installed" ;;
            *) $V6163_INSTALLER -S --needed "${V6163_NEED[@]}" || echo "    install failed — try manually" ;;
        esac
    else
        echo "    no pacman/paru/yay — install manually: sudo pacman -S --needed ${V6163_NEED[*]}"
    fi
else
    echo "    ✓ hyprlock + hypridle present"
fi

# Phase B — hypridle.conf + hyprlock.conf (user-scope, ~/.config/hypr/)
# These files live directly under $HYPR_DIR (NOT modules/) because
# hypridle and hyprlock look there by default. Existing files get
# backed up to .bak.<TS> so users who hand-tweaked are safe.
for v6163f in hypridle.conf hyprlock.conf; do
    src="$SCRIPT_DIR/hypr-config/$v6163f"
    dst="$HYPR_DIR/$v6163f"
    [ -f "$src" ] || continue
    if [ -f "$dst" ] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        cp "$dst" "$dst.bak.$TS" 2>/dev/null
        cp "$src" "$dst"
        echo "    $v6163f → $dst (backed up old)"
    elif [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        echo "    $v6163f → $dst (new)"
    else
        echo "    $v6163f up to date"
    fi
done

# v6.16.3.8: Sync hypridle timeouts with PanelState on fresh install.
# Picks up idleLockSeconds / idleSleepSeconds if the user has an
# existing panel-state.json; otherwise defaults baked in
# hypridle.conf (5min lock, never sleep) stay put.
if [ -x "$BIN_DIR/zen-hypridle-sync.sh" ]; then
    "$BIN_DIR/zen-hypridle-sync.sh" >/dev/null 2>&1 || true
    echo "    hypridle timeouts synced from panel-state.json"
fi

# Phase C — lid-behavior.conf + autostart.conf (modules scope)
# These were already copied by [6/9]'s generic hypr-config loop if the
# install.sh had one; explicit copy here guarantees v6.16.3.X versions
# land even when that loop is absent in older install.sh variants.
for v6163f in lid-behavior.conf autostart.conf; do
    src="$SCRIPT_DIR/hypr-config/$v6163f"
    dst="$HYPR_DIR/modules/$v6163f"
    [ -f "$src" ] || continue
    cp "$src" "$dst"
done
echo "    lid-behavior.conf + autostart.conf synced"

# Phase D — lock-wallpaper symlink seed (so first lock has a bg)
V6163_LOCK_BG="$HOME/.cache/zen-shell/lock-wallpaper.png"
V6163_WP_STATE="$HOME/.config/quickshell/zen-shell/wallpaper-v5.json"
if [ -f "$V6163_WP_STATE" ] && command -v jq >/dev/null 2>&1; then
    V6163_CUR_WP=$(jq -r '.currentWallpaper // empty' "$V6163_WP_STATE" 2>/dev/null)
    if [ -n "$V6163_CUR_WP" ] && [ -f "$V6163_CUR_WP" ]; then
        ln -sfn "$V6163_CUR_WP" "$V6163_LOCK_BG"
        echo "    lock wallpaper seed → $V6163_CUR_WP"
    fi
fi
if [ ! -e "$V6163_LOCK_BG" ] && command -v grim >/dev/null 2>&1; then
    grim "$V6163_LOCK_BG" 2>/dev/null && echo "    lock wallpaper seed → grim fallback"
fi

# Phase E — systemd-sleep hook (optional, needs sudo)
# Skip prompt silently if already installed; only ask on fresh boxes
# and only if sudo is reachable without password-less hostile env.
V6163_HOOK_SRC="$SCRIPT_DIR/hypr-config/zen-sleep-hook.sh"
V6163_HOOK_DST="/usr/lib/systemd/system-sleep/zen-sleep-hook"
if [ -f "$V6163_HOOK_SRC" ]; then
    if [ -f "$V6163_HOOK_DST" ]; then
        echo "    ✓ systemd-sleep hook already installed"
    else
        printf '    Install systemd-sleep hook for full wake recovery? [Y/n] '
        read -r V6163_ANS
        case "$V6163_ANS" in
            n|N|no|NO) echo "    skipped (lid + manual recovery still work)" ;;
            *)
                if command -v sudo >/dev/null 2>&1; then
                    sudo install -m 0755 -o root -g root "$V6163_HOOK_SRC" "$V6163_HOOK_DST" \
                        && echo "    ✓ installed at $V6163_HOOK_DST" \
                        || echo "    ⚠ sudo install failed"
                else
                    echo "    no sudo available — copy manually as root"
                fi
                ;;
        esac
    fi
fi

# Phase F — restart hypridle if it's running (so new hypridle.conf takes effect)
if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle 2>/dev/null
    sleep 0.3
fi
if command -v hypridle >/dev/null 2>&1; then
    setsid -f hypridle </dev/null >/dev/null 2>&1 &
    echo "    ✓ hypridle restarted"
fi

echo "  ── v6.16.3 stack applied ──"
echo ""


ZEN_QS_PATH="${HOME}/.config/quickshell/zen-shell"

if command -v quickshell >/dev/null 2>&1; then
    # v6.16.4.12.6.31: NUCLEAR kill approach (proven recipe)
    # The previous SIGTERM-then-SIGKILL loop wasn't reliably terminating
    # the prior shell before the new spawn — result was DOUBLE BARS.
    # User's tested-and-working recipe:
    #
    #   pkill -9 quickshell; sleep 2
    #   quickshell -p ~/.config/quickshell/zen-shell > /tmp/qs.log 2>&1 &
    #   sleep 5
    #
    # We do exactly this — straightforward, no clever process-substitution
    # tricks that may eat the kill signal under fish/bash differences.
    echo "    [launch] Force-killing all quickshell instances (SIGKILL)..."
    pkill -9 -f 'quickshell' 2>/dev/null || true
    pkill -9 -x qs 2>/dev/null || true
    pkill -9 -f 'qs.*zen-shell' 2>/dev/null || true
    # Clear stale IPC sockets so fresh shell can claim its by-id slot
    rm -rf "/run/user/$(id -u)/quickshell/by-id"/* 2>/dev/null || true
    sleep 2

    # Verify nothing survived the SIGKILL
    REMAINING=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null | wc -l)
    REMAINING=$(echo "$REMAINING" | tr -cd '0-9' | head -c 6)
    REMAINING=${REMAINING:-0}

    if [ "$REMAINING" -gt 0 ] 2>/dev/null; then
        echo "    ⚠️   $REMAINING zen-shell process(es) survived SIGKILL — REFUSING"
        echo "         to spawn another (would result in stacked bars)."
        echo "         Diagnose with:"
        echo "           pgrep -fa 'quickshell.*zen-shell|qs.*zen-shell'"
        echo "         Then manually:"
        echo "           pkill -9 -f quickshell; sleep 2"
        echo "           quickshell -p ${ZEN_QS_PATH} > /tmp/qs.log 2>&1 &"
    else
        echo "    [launch] All previous instances killed cleanly."
        # All clear — spawn exactly ONE detached zen-shell.
        echo "    [launch] Spawning fresh quickshell..."
        if command -v setsid >/dev/null 2>&1; then
            setsid -f quickshell -p "${ZEN_QS_PATH}" </dev/null >/tmp/zen-shell.log 2>&1
        else
            nohup quickshell -p "${ZEN_QS_PATH}" </dev/null >/tmp/zen-shell.log 2>&1 &
            disown
        fi
        # CRITICAL: 5 seconds for shell to fully boot — was 0.6s before
        # which was racing the QML load and reporting wrong instance count.
        echo "    [launch] Waiting 5s for shell to boot..."
        sleep 5
        FINAL=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null | wc -l)
        FINAL=$(echo "$FINAL" | tr -cd '0-9' | head -c 6)
        FINAL=${FINAL:-0}
        if [ "$FINAL" -eq 1 ] 2>/dev/null; then
            echo "    ✅  spawned: quickshell -p ${ZEN_QS_PATH}  (1 instance, verified)"
        elif [ "$FINAL" -eq 0 ] 2>/dev/null; then
            echo "    ⚠️   spawn did not stick — check /tmp/zen-shell.log"
            echo "         tail -30 /tmp/zen-shell.log"
        else
            echo "    ⚠️   $FINAL instances detected after spawn (expected 1) — check"
            echo "         pgrep -fa 'quickshell.*zen-shell|qs.*zen-shell'"
        fi
    fi
else
    echo "    ⚠️   quickshell not in PATH — bootstrap may have failed."
fi
echo ""

# v6.16.4.12.6.49: Remove standalone "calendar" bar widget if present.
# The Clock module now has built-in calendar popup (click clock → calendar
# opens) — the separate CalendarButton widget became redundant and confused
# users who saw two clock-like things in the bar.
PANEL_STATE_FILE="$SHELL_DIR/panel-state.json"
if [ -f "$PANEL_STATE_FILE" ] && grep -q '"calendar"' "$PANEL_STATE_FILE"; then
    cp "$PANEL_STATE_FILE" "$PANEL_STATE_FILE.bak-$TS"
    # Remove "calendar" entries from any of the layout arrays
    # (use sed to handle JSON cleanly — supports both with and without trailing comma)
    sed -i 's/"calendar",\?\s*//g; s/,\s*"calendar"//g' "$PANEL_STATE_FILE"
    echo "    🧹  Removed standalone calendar widget from panel layout"
    echo "        Calendar popup now built into Clock module (click clock to open)"
fi

echo "  ✅  Done. Enjoy Zen Shell v6.16.4.12.6.51 Hikari (光)."
echo ""
exit 0