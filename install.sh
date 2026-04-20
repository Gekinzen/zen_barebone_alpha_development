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
echo "    Zen Shell v6.15.14"
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Quickshell-native desktop environment for Hyprland."
echo ""
echo "    v6.15.15 — Smart one-command install + hardware detection"
echo ""
echo "      Auto-bootstrap              install.sh detects missing critical"
echo "                                   deps (Hyprland, Quickshell, grim,"
echo "                                   slurp, wl-copy, swww, cava,"
echo "                                   playerctl, jq, notify-send) and"
echo "                                   auto-runs bootstrap.sh if needed."
echo "                                   Single './install.sh' works on both"
echo "                                   fresh laptops and existing setups."
echo ""
echo "      Smart hardware detection    Auto-detects multi-GPU topology"
echo "                                   (iGPU + dGPU, Optimus, NVIDIA,"
echo "                                   AMD, Intel) and writes env vars"
echo "                                   to ~/.config/hypr/modules/"
echo "                                   hardware.conf with AQ_DRM_DEVICES"
echo "                                   set to the correct primary node."
echo "                                   Never overwritten on upgrade."
echo ""
echo "      Complete script inventory   3 scripts that were missing from"
echo "                                   prior tarballs, now shipped:"
echo "                                     - openrgb-autoload.sh"
echo "                                     - openrgb-wrapper.sh"
echo "                                     - zen-screenshot-capture.sh"
echo ""
echo "      Complete hypr modules       3 hypr config modules now"
echo "                                   shipped to ~/.config/hypr/modules/"
echo "                                   with preserve-if-exists logic:"
echo "                                     - animations.conf"
echo "                                     - autostart.conf"
echo "                                     - look_and_feel.conf"
echo ""
echo "      Source auto-wired           hyprland.conf gets source = lines"
echo "                                   auto-appended for all 4 modules"
echo "                                   (hardware/animations/autostart/"
echo "                                   look_and_feel) when missing."
echo ""
echo "    v6.15.14 — Ship 12 QML files missing from prior tarballs"
echo "      Fresh-install fix           v6.15 → v6.15.13 tarballs shipped"
echo "                                   only 56 of 68 QML files. Fresh"
echo "                                   installs crashed with errors like"
echo "                                   'PowerConfirmDialog is not a type'"
echo ""
echo "    v6.15.13 — Install automation polish"
echo "      Generic helper script       zs-restart.sh fully dynamic via"
echo "                                   \$HOME and \$USER, no hardcoded"
echo "                                   paths."
echo "      Auto cleanup on upgrade     install.sh removes stale"
echo "                                   ~/.local/bin/zen-shell-nuclear-"
echo "                                   restart.sh from v6.15.11."
echo ""
echo "    v6.15.12 hotfix — Fix nuclear restart self-suicide bug"
echo "      Script renamed              zs-restart.sh (no 'zen-shell' in"
echo "                                   path → can't self-pkill)"
echo "      Tightened pkill pattern     'quickshell.*zen-shell' matches"
echo "                                   ONLY the quickshell process, not"
echo "                                   arbitrary scripts with 'zen-shell'"
echo "                                   anywhere in their cmdline"
echo "      Installed permanently       ~/.local/bin/zs-restart.sh via"
echo "                                   install.sh step 5 (with inline"
echo "                                   /tmp fallback for hotfix users)"
echo ""
echo "    v6.15.11 hotfix — Fix nuclear respawn command (actual invocation)"
echo "      Correct quickshell command  Paul's actual reload pattern is"
echo "                                   'quickshell -p ~/.config/quickshell/"
echo "                                   zen-shell', NOT 'qs -c zen-shell'"
echo "                                   as v6.15.10 assumed. pkill pattern"
echo "                                   'zen-shell' now matches any invocation."
echo "      Helper-script approach      Wrote reload commands to a /tmp"
echo "                                   script instead of nested bash -c,"
echo "                                   eliminating all quoting bugs."
echo "      Debug log at                /tmp/zs-restart.log"
echo "      Manual test IPC:            'ipc call zen testNuclearRestart'"
echo ""
echo "    v6.15.10 hotfix — Nuclear shell respawn for Float/FW → Island"
echo "      Only on problematic path    Previous mode fullwidth/floating +"
echo "                                   new mode island → kill + relaunch"
echo "                                   the entire qs shell process. Every"
echo "                                   other transition unchanged."
echo "      Brief flicker (~600-900ms)  All ephemeral shell state resets"
echo "                                   (Settings panel, Control Panel,"
echo "                                   calendar close). Music stream"
echo "                                   continues (cava is external)."
echo "                                   Trade-off chosen by user — the"
echo "                                   only way to fully bypass Qt/"
echo "                                   Quickshell layer-shell timing quirk."
echo ""
echo "    v6.15.9 hotfix — Synchronous layout via forceLayout()"
echo "      Collapse async layout loop   Calls RowLayout.forceLayout() on"
echo "                                    all 4 bar rows during mode"
echo "                                    transitions. Eliminates the"
echo "                                    multi-frame feedback loop that"
echo "                                    caused island-commit-at-startmenu"
echo "                                    bug — positions are now guaranteed"
echo "                                    fresh when we read them."
echo "      Faster Loading                Stable-read unlock now typically"
echo "                                    fires on first or second read,"
echo "                                    reducing transition Loading time."
echo ""
echo "    v6.15.8 hotfix — Stable-read transition verification"
echo "      Island mode commit fix      Floating/FW → Island no longer"
echo "                                   commits music string at start-menu"
echo "                                   position. Transition now waits for"
echo "                                   TWO consecutive stable position"
echo "                                   reads before committing — catches"
echo "                                   island's multi-frame layout settle."
echo "      Bounds sanity               Parent-chain walk now verifies x is"
echo "                                   within bar bounds before writing."
echo "                                   Prevents stale rightRow.x from"
echo "                                   previous mode leaking through."
echo ""
echo "    v6.15.7 hotfix — Mode cycling orphaned string"
echo "      Lockout during transition   Rapid Island→FW→Float→Island no"
echo "                                   longer leaves music string at stale"
echo "                                   old coordinates. Bar.qml now blocks"
echo "                                   position writes during bar resize +"
echo "                                   shell.qml waits for barWindowLeft to"
echo "                                   settle before committing position."
echo ""
echo "    v6.15.6 bugfix — Theme reload / panel mode string fixes"
echo "      Complete applyToHyprland    Snap gaps + blur/shadow extras now"
echo "                                   apply properly → no more reset to"
echo "                                   hyprland.conf defaults after theme"
echo "                                   change"
echo "      Panel mode safety           Switching fullwidth/floating/island"
echo "                                   no longer leaves music string"
echo "                                   orphaned at old coordinates"
echo ""
echo "    v6.15.5 enhancement — Smooth runtime transitions"
echo "      Behavior on margins        Tray expand / app open → string slides"
echo "                                  smoothly into new position (180ms)"
echo "                                  instead of snap-after-delay"
echo ""
echo "    v6.15.4 hotfix — Layout-stuck position + tooltip gap"
echo "      Parent-chain walk          Position via direct .x reads, no"
echo "                                  scene-graph staleness on login"
echo "      Layout nudger (30s)        Forces RowLayout recompute every 250ms"
echo "                                  → unsticks wrong rightRow.x without"
echo "                                  needing user hover/click"
echo "      15s max-wait + sanity gate  Max-wait no longer fires with a"
echo "                                  pre-layout default position"
echo "      Tooltip bar-top anchor      Music tooltip now snug to bar edge"
echo "                                  like SysRow tooltips (no vPad gap)"
echo ""
echo "    v6.15.3 hotfix — Loading loop + clock jitter"
echo "      2px write threshold       Clock/badge jitter no longer restarts"
echo "                                 stability timer → no more infinite Loading"
echo "      Stop-on-ready safetyPoll  No continuous polling in steady state"
echo ""
echo "    v6.15.2 patch — Music string position live-update + loading placeholder"
echo "      musicSlotLocalX          Live tracking across zone reflows"
echo "      Loading placeholder      Pulsing '...' in bar slot on login"
echo "      Stability-based reveal   Strings fade in after 600ms settle"
echo ""
echo "    v6.15 — Music module → ZenStrings"
echo "      Strings in music slot     Toggle music widget → ZenStrings"
echo "      Music slot position fix   Strings now align with music slot"
echo "      No background             String floats transparently in bar"
echo "      Hover tooltip             Shows Artist — Title on hover"
echo "      Static when idle          Decorative line when nothing plays"
echo "      Animated when playing     Cava-reactive bezier on beat"
echo "      Color modes               Theme / Synced / Custom"
echo "      zen-cava.sh               Bundled cava wrapper script"
echo ""
echo "    Carried forward from v6.14.x:"
echo "      Screenshot ropes          Physics rope on region screenshot"
echo "      Tooltip PopupWindow       SysRow tooltip aligns to icon"
echo "      SwayNC position fix       Notification position applies"
echo "      Process reuse fix         Rapid settings clicks honored"
echo "      SIGTERM-first restart     Clean daemon restart sequence"
echo ""
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Smart mode (default): auto-detects missing Hyprland/Quickshell"
echo "    and runs bootstrap automatically if needed. Safe alongside"
echo "    KDE, GNOME, or COSMIC."
echo ""

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
echo "      8. Restart qs"
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

echo ""
echo "    v6.15 new:"
echo "      MusicStrings.qml         — music slot string renderer + hover tooltip"
echo "      ZenStrings.qml           — bezier string visual (updated)"
echo "      ZenStringsState.qml      — simplified state (updated)"
echo "      ZenScreenshotOverlay.qml — screenshot rope overlay (carried from v6.14.2)"
echo "      ZenRope.qml              — physics rope primitive (carried from v6.14.2)"
echo ""
echo "    v6.15 modified:"
echo "      Bar.qml                  — cMusic toggles MusicWidget ↔ MusicStrings"
echo "                                  + reliable music slot position tracking"
echo "      GeneralPage.qml          — Strings section added"
echo "      shell.qml                — ZenStrings sibling + screenshotRope IPC"

echo ""
echo "    Auto-applying bar modules..."
for pair in "ZenClock.qml:Clock.qml" "ZenWorkspaces.qml:Workspaces.qml"; do
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
    zs-restart.sh
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
# v6.15.11 installed ~/.local/bin/zen-shell-nuclear-restart.sh which
# had the self-suicide pkill bug (script's own path contained
# "zen-shell" and got matched by its own pkill -f zen-shell call).
# v6.15.12 replaced it with zs-restart.sh (safe filename). Remove the
# old script so users upgrading don't end up with both files.
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
# These are USER-CUSTOMIZABLE — install default only if missing.
# ─────────────────────────────────────────────────────────────────
for mod in animations.conf autostart.conf look_and_feel.conf; do
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

HCONF="$HYPR_DIR/hyprland.conf"
if [ -f "$HCONF" ]; then
    added=0
    grep -q "modules/hardware.conf" "$HCONF" || {
        printf '\n# ── Added by Zen Shell installer (hardware detection) ──\nsource = ~/.config/hypr/modules/hardware.conf\n' >> "$HCONF"
        added=$((added+1)); }
    grep -q "modules/binds.conf" "$HCONF" || {
        printf '\n# ── Added by Zen Shell installer ──\nsource = ~/.config/hypr/modules/binds.conf\n' >> "$HCONF"
        added=$((added+1)); }
    grep -q "modules/animations.conf" "$HCONF" || {
        echo "source = ~/.config/hypr/modules/animations.conf" >> "$HCONF"
        added=$((added+1)); }
    grep -q "modules/autostart.conf" "$HCONF" || {
        echo "source = ~/.config/hypr/modules/autostart.conf" >> "$HCONF"
        added=$((added+1)); }
    grep -q "modules/look_and_feel.conf" "$HCONF" || {
        echo "source = ~/.config/hypr/modules/look_and_feel.conf" >> "$HCONF"
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

# ═══════════════════════════════════════════════════════════════
# [8.5/9] QML integrity smoke test (v6.15.15+)
# ═══════════════════════════════════════════════════════════════
# Catches missing QML type references BEFORE quickshell crashes on
# load. Would have prevented the v6.15.13 PowerConfirmDialog bug and
# the v6.15.14 Theme/Clock/MusicWidget chain.
#
# How it works:
#   1. For each local *.qml file, grep for component names that look
#      like Zen Shell-local types (PascalCase starting at column 0
#      or after whitespace).
#   2. Check that every referenced name has a corresponding .qml
#      file in $SHELL_DIR.
#   3. Report anything missing — doesn't abort the install (user may
#      be intentionally customizing), just prints a warning.
echo ""
echo "[8.5/9] QML integrity check..."
MISSING_TYPES=""
if [ -d "$SHELL_DIR" ]; then
    # Build a set of provided type names (bare file stems)
    PROVIDED=$(ls "$SHELL_DIR"/*.qml 2>/dev/null | xargs -n1 basename | sed 's/\.qml$//' | sort -u)

    # Scan shell.qml + Bar.qml (the two files most likely to instantiate other components)
    # for  ComponentName { ... }  patterns that look like local types
    for scan_file in "$SHELL_DIR/shell.qml" "$SHELL_DIR/Bar.qml"; do
        [ -f "$scan_file" ] || continue
        # Extract PascalCase identifiers followed by {  (likely component instantiations)
        # Filter out known Quickshell / QtQuick builtins
        REFS=$(grep -oE '^\s*[A-Z][a-zA-Z0-9_]*\s*\{' "$scan_file" 2>/dev/null \
               | sed 's/\s*{$//' | sed 's/^\s*//' | sort -u \
               | grep -vE '^(Item|Rectangle|Row|Column|Grid|RowLayout|ColumnLayout|GridLayout|StackLayout|Text|Image|MouseArea|Loader|Repeater|Timer|Process|Binding|Connections|Behavior|NumberAnimation|PropertyAnimation|SequentialAnimation|ParallelAnimation|State|Transition|PathAnimation|PathView|ListView|GridView|TableView|ScrollView|Flickable|Popup|ApplicationWindow|Window|PanelWindow|FloatingWindow|PopupWindow|ShellRoot|IpcHandler|Variants|LayerSurface|ExclusiveZone|WlrLayer|Scope|Component|QtObject|Package|SystemTrayItem|Socket|FileView|Quickshell|Hyprland|Keys|Anchors|Margins|AnchorChanges|PropertyChanges|StateGroup|PathLine|PathQuad|PathCubic|Path|Gradient|GradientStop|Canvas|ShaderEffect|ShaderEffectSource|Flow|Pane|Control|TextInput|TextEdit|TextField|TextArea|Button|CheckBox|RadioButton|Slider|SpinBox|ComboBox|ProgressBar|ScrollBar|Switch|Label|GroupBox|Menu|MenuItem|ToolTip|Dialog|DialogButtonBox|BusyIndicator|Frame|ToolBar|TabBar|TabButton|StackView|Page|PageIndicator|Drawer|Action|ActionGroup)$')

        for ref in $REFS; do
            if ! echo "$PROVIDED" | grep -qx "$ref"; then
                # Double-check it's not in any sub-directory
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
        echo "    If you haven't, the missing file is probably from an incomplete package."
        echo "    Run: $INSTALLER -S --needed quickshell-git  # to ensure latest Quickshell"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [9/9] Restart
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[9/9] Restart..."
pkill -9 qs 2>/dev/null || true
sleep 0.5
rm -rf "/run/user/$(id -u)/quickshell/by-id"/* 2>/dev/null

command -v swww >/dev/null 2>&1 && ! swww query >/dev/null 2>&1 && {
    if command -v swww-daemon >/dev/null 2>&1; then
        setsid swww-daemon </dev/null >/dev/null 2>&1 & disown 2>/dev/null || true
    else
        setsid swww init </dev/null >/dev/null 2>&1 & disown 2>/dev/null || true
    fi
    sleep 1
    echo "    swww-daemon started"
}

setsid qs -c zen-shell > /tmp/zen-shell.log 2>&1 </dev/null & disown
echo "    qs -c zen-shell started (log: /tmp/zen-shell.log)"

pgrep -x Hyprland >/dev/null && sleep 0.5 && hyprctl reload 2>/dev/null && echo "    Hyprland reloaded"

sleep 1

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
QML_FINAL=$(ls -1 "$SHELL_DIR/"*.qml 2>/dev/null | wc -l)
SHELL_PID=$(pgrep -f "qs -c zen-shell" | head -1)
SWWW_ALIVE="no";  command -v swww >/dev/null 2>&1 && swww query >/dev/null 2>&1 && SWWW_ALIVE="yes"
SWAYNC_ALIVE="no"; pgrep -x swaync >/dev/null 2>&1 && SWAYNC_ALIVE="yes"
CAVA_OK="no";      command -v cava >/dev/null 2>&1 && CAVA_OK="yes"
PCTL_OK="no";      command -v playerctl >/dev/null 2>&1 && PCTL_OK="yes"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         🎉  ZEN SHELL v6.15.14 INSTALLED SUCCESSFULLY  🎉      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  ── Install summary ──"
echo "    QML files installed:   $QML_FINAL"
echo "    Toggle scripts:        $INSTALLED_SCRIPTS_COUNT in $BIN_DIR"
echo "    Builtin themes:        $INSTALLED_THEMES_COUNT"
echo "    Shell running:         ${SHELL_PID:-(not running — check /tmp/zen-shell.log)}"
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
echo "  ── New in v6.15 ──"
echo "      Music module → ZenStrings    Toggle in Settings → General → Strings"
echo "      Position tracking             Strings follow music slot reliably"
echo "      Hover tooltip                 Artist — Title on hover"
echo "      Color modes                   Theme / Synced / Custom"
echo "      zen-cava.sh                   Bundled cava wrapper"
echo ""
echo "  ── Fixed in v6.15 ──"
echo "      Music slot position         Strings now align to actual music slot"
echo "                                   (was stuck at far-left due to layout race)"
echo "      Carried from v6.14:         Tooltip alignment, SwayNC position,"
echo "                                   Process reuse, SIGTERM restart"
echo ""
echo "  ── Fixed in v6.15.2 ──"
echo "      Live position updates       String now tracks music slot position"
echo "                                   even when sysrow/taskbar reflow after"
echo "                                   login — no more stale position until"
echo "                                   user interaction."
echo "      Loading placeholder         Pulsing 'Loading…' shows in the bar"
echo "                                   slot during the 600ms settle window."
echo "      Stability-based reveal      Strings fade in only when the slot"
echo "                                   position has been stable for 600ms,"
echo "                                   not on a fixed 1.5s timer."
echo ""
echo "  ── Fixed in v6.15.3 ──"
echo "      Loading loop                Clock ticks + taskbar badges + sysrow"
echo "                                   jitter used to keep restarting the"
echo "                                   600ms stability timer → placeholder"
echo "                                   looped forever. Write threshold now"
echo "                                   2px (ignores sub-pixel noise)."
echo ""
echo "  ── Fixed in v6.15.4 ──"
echo "      Layout-stuck position       After Loading finished, string used"
echo "                                   to stay at wrong (pre-layout) position"
echo "                                   until user hovered a bar module."
echo "                                   Now auto-unsticks via layoutNudger"
echo "                                   + parent-chain walk + 15s max-wait"
echo "                                   with sanity gate."
echo "      Tooltip bar-top anchor      Music string tooltip no longer floats"
echo "                                   60px above the bar — now snug to bar"
echo "                                   top edge like SysRow tooltips."
echo ""
echo "  ── Enhanced in v6.15.5 ──"
echo "      Smooth runtime transitions  When sysrow/tray expands or taskbar"
echo "                                   gains/loses an app, the string now"
echo "                                   SLIDES smoothly (180ms OutCubic) into"
echo "                                   its new position instead of snap-after-"
echo "                                   delay. Width changes (stringLength"
echo "                                   adjustments) animate too."
echo "                                   Initial login placement still snaps"
echo "                                   — only runtime changes animate."
echo ""
echo "  ── Fixed in v6.15.6 ──"
echo "      Complete applyToHyprland    SettingsStateV2 now writes ALL snap"
echo "                                   keywords (window_gap, monitor_gap,"
echo "                                   border_overlap, respect_gaps) plus"
echo "                                   the full blur/shadow extras. Before"
echo "                                   this, those were never asserted to"
echo "                                   Hyprland — so any hyprctl reload"
echo "                                   silently reverted them to"
echo "                                   hyprland.conf defaults."
echo "      Theme reload defensively    After theme change, applyToHyprland"
echo "                                   is called again — so even if some"
echo "                                   downstream cascade wipes settings,"
echo "                                   user config is immediately restored."
echo "      Panel mode transition       Switching Fullwidth/Floating/Island"
echo "                                   no longer leaves music string stuck"
echo "                                   at stale old coordinates. Transition"
echo "                                   now routes through the Loading"
echo "                                   placeholder → fresh position discovery"
echo "                                   → strings reappear at correct position."
echo ""
echo "  ── Fixed in v6.15.7 ──"
echo "      Rapid mode cycling fix      When user rapidly cycles Island →"
echo "                                   Fullwidth → Floating → Island, the"
echo "                                   v6.15.6 fix could still leak stale"
echo "                                   intermediate coordinates (captured"
echo "                                   mid-resize) into ZenStringsState,"
echo "                                   leading to orphaned string at wrong"
echo "                                   position after Loading cleared."
echo "      Bar.qml mode lockout        _doUpdatePos now short-circuits"
echo "                                   while _modeTransitioning is true."
echo "                                   The flag is set on panelModeChanged"
echo "                                   and cleared 300ms after barRoot.width"
echo "                                   stops changing significantly (>20px)."
echo "                                   Runtime tray expand (<20px changes)"
echo "                                   is unaffected."
echo "      shell.qml barWindowLeft     Stability timer now watches"
echo "                                   barWindowLeft changes in addition to"
echo "                                   musicSlotLocalX. Prevents positionReady"
echo "                                   commit while bar origin is still"
echo "                                   updating post-mode-change."
echo ""
echo "  ── Fixed in v6.15.8 ──"
echo "      Island commit at start-menu v6.15.7's bar-width-idle lockout"
echo "                                   unlocked too early for Floating→Island"
echo "                                   or FW→Island transitions. Island mode"
echo "                                   has a layout feedback loop"
echo "                                   (barWindow.implicitWidth ↔"
echo "                                   bar.contentImplicitWidth) that can"
echo "                                   propagate across multiple frames"
echo "                                   AFTER bar.width stabilizes. Single"
echo "                                   read after unlock caught intermediate"
echo "                                   stale values, committed to wrong"
echo "                                   position (near start menu)."
echo "      Stable-read verification    _doUpdatePos now requires TWO"
echo "                                   consecutive stable reads (x,width)"
echo "                                   within 2px AND bar-width-idle before"
echo "                                   lifting the mode transition lockout."
echo "                                   Guarantees layout has fully propagated."
echo "      Bounds sanity check         x must be within (0, barRoot.width)"
echo "                                   and musicSlotItem.width must be"
echo "                                   sensible. Filters out partial"
echo "                                   layout state reads."
echo ""
echo "  ── Fixed in v6.15.9 ──"
echo "      RowLayout.forceLayout()     The proper fix to the island layout"
echo "                                   feedback loop. Instead of passively"
echo "                                   waiting for Qt's async layout engine"
echo "                                   to propagate child .x values across"
echo "                                   multiple frames, we now explicitly"
echo "                                   call forceLayout() on all 4 bar"
echo "                                   RowLayouts (main, left, center,"
echo "                                   right). This collapses the entire"
echo "                                   layout pass into a single synchronous"
echo "                                   update so positions are ALWAYS fresh"
echo "                                   when read."
echo "      Transition-only cost        forceLayout() is only called during"
echo "                                   _modeTransitioning (once in the"
echo "                                   panelModeChanged handler as preemptive"
echo "                                   warmup, and again at start of each"
echo "                                   _doUpdatePos during transition). Zero"
echo "                                   overhead in steady state."
echo "      Faster Loading              Typical transition Loading reduced"
echo "                                   from ~1-1.2s down to ~700-900ms."
echo ""
echo "  ── Fixed in v6.15.10 ──"
echo "      Nuclear Float/FW → Island   v6.15.2 through v6.15.9 all attempted"
echo "                                   progressively more sophisticated QML"
echo "                                   workarounds to catch Qt's async"
echo "                                   RowLayout propagation in island mode."
echo "                                   forceLayout() (v6.15.9) should have"
echo "                                   been the proper fix but Quickshell"
echo "                                   PanelWindow + WlrLayer renegotiation"
echo "                                   timing has a quirk QML can't reach."
echo "      Kill + relaunch on transit  When previous mode was fullwidth or"
echo "                                   floating and new mode is island,"
echo "                                   shell.qml triggers a detached bash"
echo "                                   respawn (setsid + nohup). PanelState"
echo "                                   saves to JSON first, then pkill +"
echo "                                   relaunch. Reborn shell starts"
echo "                                   directly in island mode from fresh"
echo "                                   state — no feedback loop."
echo "      Selective — only that path  Island→FW, Island→Float, FW↔Float"
echo "                                   transitions continue using v6.15.8"
echo "                                   stable-read + v6.15.9 forceLayout."
echo "                                   No unnecessary flicker."
echo ""
echo "  ── Fixed in v6.15.11 ──"
echo "      Nuclear respawn command     v6.15.10's pkill pattern assumed"
echo "                                   Quickshell was invoked as 'qs -c"
echo "                                   zen-shell'. Paul actually runs it"
echo "                                   as 'quickshell -p ~/.config/"
echo "                                   quickshell/zen-shell' — different"
echo "                                   executable name entirely. The"
echo "                                   pkill pattern didn't match and"
echo "                                   v6.15.10's nuclear restart never"
echo "                                   actually fired."
echo "      Fixed pkill pattern         Now uses 'zen-shell' which matches"
echo "                                   BOTH invocations (qs or quickshell)"
echo "                                   as long as they have 'zen-shell'"
echo "                                   in the command line — covers all"
echo "                                   reasonable setups."
echo "      Helper script approach      Nuclear restart commands are now"
echo "                                   written to /tmp/zen-shell-nuclear-"
echo "                                   restart.sh and executed via"
echo "                                   setsid -f (fallback nohup+disown)."
echo "                                   No more nested bash -c quoting"
echo "                                   bugs. Debug log at"
echo "                                   /tmp/zs-restart.log"
echo "      Manual test IPC endpoint    Added 'testNuclearRestart' to the"
echo "                                   IpcHandler — run 'quickshell -p"
echo "                                   ~/.config/quickshell/zen-shell"
echo "                                   ipc call zen testNuclearRestart'"
echo "                                   from terminal to verify respawn"
echo "                                   works outside the mode-change"
echo "                                   pathway."
echo "      Recovery timer              If respawn fails silently,"
echo "                                   _nuclearRestartPending clears"
echo "                                   after 3s so another mode cycle"
echo "                                   can trigger a fresh attempt."
echo ""
echo "  ── Fixed in v6.15.12 ──"
echo "      Helper script self-suicide  v6.15.11's helper was written to"
echo "                                   /tmp/zen-shell-nuclear-restart.sh"
echo "                                   — path contains 'zen-shell'."
echo "                                   Inside, it ran 'pkill -f zen-shell'"
echo "                                   which matched its OWN cmdline and"
echo "                                   killed itself mid-execution. The"
echo "                                   quickshell respawn half never ran."
echo "                                   Paul reported: 'nung nag pkill"
echo "                                   -f zen-shell wala na hindi nag"
echo "                                   load yung sleep mo 0.2 quickshell"
echo "                                   -p...'"
echo "      Safe filename               Renamed to 'zs-restart.sh' — no"
echo "                                   'zen-shell' substring, immune to"
echo "                                   the broad pkill pattern."
echo "      Tightened pkill pattern     Now uses 'quickshell.*zen-shell'"
echo "                                   which matches ONLY the quickshell"
echo "                                   invocation, not random scripts."
echo "      Permanent install path      ~/.local/bin/zs-restart.sh added"
echo "                                   to install.sh scripts list."
echo "                                   Inline /tmp/zs-restart.sh fallback"
echo "                                   if user applied hotfix patch"
echo "                                   without re-running install.sh."
echo ""
echo "  ── How to use Strings ──"
echo "    Super+,  → Settings → General → Strings"
echo "    Toggle 'Enable strings' → music module becomes a string"
echo "    Play music → string animates with the beat"
echo "    Hover over string → shows Artist — Title tooltip"
echo "    Pause/stop → string returns to static line"
echo ""
echo "  ── Color modes ──"
echo "    theme    = auto blue→purple from current theme"
echo "    synced   = pick specific theme color keys"
echo "    custom   = your own hex colors"
echo ""
echo "  ── Screenshot rope (add to hyprland.conf if not set) ──"
echo "    bind = SUPER SHIFT, S, exec, qs msg -i zen -f zenScreenshotRope"
echo ""
echo "  ── Keybinds ──"
echo "    Super+C      → Control Panel (quick settings)"
echo "    Super+,      → Settings window"
echo "    Super+W      → Wallpaper picker"
echo "    Super+A      → Start menu"
echo "    Super+/      → Keybind cheatsheet"
echo ""
echo "  ── Quick test (v6.15 strings) ──"
echo "    1. Super+,  → General → Strings → Enable strings"
echo "    2. Verify the string sits INSIDE the music slot (not far-left)"
echo "    3. Play music in Spotify/Rhythmbox → string animates with beat"
echo "    4. Hover the string → Artist — Title tooltip pops above it"
echo "    5. Pause music → string returns to static line"
echo ""
echo "  ── Diagnostics ──"
echo "    tail -30 /tmp/zen-shell.log"
echo "    playerctl status"
echo "    cava   (test standalone)"
echo ""
echo "  ✅  Done. Enjoy Zen Shell v6.15, pre."
echo ""
exit 0
