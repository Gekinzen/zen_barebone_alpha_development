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
echo "    Zen Shell v6.16.2.3.7"
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Quickshell-native desktop environment for Hyprland."
echo ""
cat << 'ZSCHANGELOG'
    v6.16.2.3.7 — Single-instance launch (fix double bar on re-install)

      Step [9/9] kill-only         The legacy 'setsid qs -c zen-shell ...'
                                    spawn at the bottom of step [9/9] used
                                    the OLD invocation pattern (qs not
                                    quickshell). The end-of-install kill
                                    loop in v6.16.2.3.6 used a tightened
                                    'quickshell.*zen-shell' pattern, so it
                                    never matched the qs spawn from
                                    step [9/9] — net result was TWO bars
                                    on every fresh install / re-install
                                    (one from step 9, one from end-of-
                                    install). Step [9/9] now ONLY kills
                                    existing shells; the single canonical
                                    spawn happens at end-of-install.

      Catch-all kill pattern       New _zen_kill_all_shells() kills BOTH
                                    pattern variants — 'qs.*zen-shell'
                                    AND 'quickshell.*zen-shell' — across
                                    SIGTERM x3 then SIGKILL x2 attempts,
                                    plus zombie clear of /run/user/UID/
                                    quickshell/by-id/. Shared between
                                    step [9/9] and end-of-install so
                                    behavior is consistent.

      End-of-install verifies      Spawn refuses to fire if any shell
                                    process is still alive after kill loop
                                    (prevents stacked bars even if user
                                    runs ./install.sh while two shells
                                    are already up from prior bug). Prints
                                    actionable diagnostic lines.

    v6.16.2.3.6 — auto-restart at end of install (kill loop + verify)
    v6.16.2.3.2 — Window click-through + avatar cache + wallpaper repo + mouse tuning
    v6.16.2.3.1 — Click-through rope + clock hover + island persist
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

    if [ "$initial" -gt 0 ]; then
        echo "    [$label] $initial existing zen-shell process(es) found, terminating..."
    else
        echo "    [$label] nothing to kill."
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

    # Final survivor count
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
for pair in "ZenClock.qml:Clock.qml" "ZenWorkspaces.qml:Workspaces.qml" "ZenSysMonitor.qml:SysMonitor.qml"; do
    src="${pair%%:*}"; dst="${pair##*:}"
    [ -f "$SHELL_DIR/$src" ] || continue
    if [ -f "$SHELL_DIR/$dst" ]; then
        if ! diff -q "$SHELL_DIR/$src" "$SHELL_DIR/$dst" >/dev/null 2>&1; then
            cp "$SHELL_DIR/$dst" "$SHELL_DIR/$dst.bak-$TS"
            cp "$SHELL_DIR/$src" "$SHELL_DIR/$dst"
            echo "      $src → $dst (backed up old)"
        else
            echo "      $dst up to date"
        fi
    else
        cp "$SHELL_DIR/$src" "$SHELL_DIR/$dst"
        echo "      $src → $dst (new)"
    fi
done

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
    zen-game-watcher.sh prime-run
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
for mod in animations.conf autostart.conf look_and_feel.conf lid-behavior.conf; do
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
# [9/9] Pre-launch cleanup — KILL ONLY (v6.16.2.3.7)
# ═══════════════════════════════════════════════════════════════
# v6.16.2.3.6 and earlier ALSO spawned a 'qs -c zen-shell' here, then
# the end-of-install block at the bottom of the file spawned ANOTHER
# 'quickshell -p ...' instance. The end-of-install kill loop only
# matched 'quickshell.*zen-shell', missing the 'qs' invocation from
# this step → TWO bars on every install.
#
# v6.16.2.3.7 makes step [9/9] kill-only. The single canonical spawn
# is owned by the v6.16.2.3.7 launch block at the end of the file.
echo ""
echo "[9/9] Pre-launch cleanup — kill any running zen-shell instances..."
SURV1=$(_zen_kill_all_shells "step9")
if [ "$SURV1" -gt 0 ]; then
    echo "    ⚠ $SURV1 process(es) survived — end-of-install spawn will refuse to start a duplicate."
else
    echo "    ✓ All previous zen-shell instances stopped cleanly."
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
echo "║         🎉  ZEN SHELL v6.16.2.3.7 INSTALLED SUCCESSFULLY  🎉   ║"
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
    # Final kill pass — should be a no-op after step [9/9] but covers
    # the edge case where something respawned in the meantime.
    SURVIVED=$(_zen_kill_all_shells "launch")

    if [ "$SURVIVED" -gt 0 ]; then
        echo "    ⚠️   $SURVIVED zen-shell process(es) survived SIGKILL — REFUSING"
        echo "         to spawn another (would result in stacked bars)."
        echo "         Diagnose with:"
        echo "           pgrep -fa 'quickshell.*zen-shell|qs.*zen-shell'"
        echo "         Then manually:"
        echo "           pkill -9 -f 'zen-shell'"
        echo "           quickshell -p ${ZEN_QS_PATH} &"
    else
        # All clear — spawn exactly ONE detached zen-shell.
        if command -v setsid >/dev/null 2>&1; then
            setsid -f quickshell -p "${ZEN_QS_PATH}" </dev/null >/tmp/zen-shell.log 2>&1
        else
            nohup quickshell -p "${ZEN_QS_PATH}" </dev/null >/tmp/zen-shell.log 2>&1 &
            disown
        fi
        # Verify exactly one is running after spawn settles
        sleep 0.6
        FINAL=$(pgrep -f 'quickshell.*zen-shell' 2>/dev/null | wc -l)
        if [ "$FINAL" -eq 1 ]; then
            echo "    ✅  spawned: quickshell -p ${ZEN_QS_PATH}  (1 instance, verified)"
        elif [ "$FINAL" -eq 0 ]; then
            echo "    ⚠️   spawn did not stick — check /tmp/zen-shell.log"
        else
            echo "    ⚠️   $FINAL instances detected after spawn (expected 1) — check"
            echo "         pgrep -fa 'quickshell.*zen-shell|qs.*zen-shell'"
        fi
    fi
else
    echo "    ⚠️   quickshell not in PATH — bootstrap may have failed."
fi
echo ""

echo "  ✅  Done. Enjoy Zen Shell v6.16.4.1, pre."
echo ""
exit 0