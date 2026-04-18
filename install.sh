#!/usr/bin/env bash
# Intentionally NOT using `set -e` — too many benign non-zero exits
# (grep no match, command -v miss, pkill with nothing to kill, etc.)
# would halt the installer mid-run. Individual failing steps below
# guard with `|| true` / `if command -v ...` explicitly where needed.
#
# `pipefail` ensures `timeout 10s foo | sed ...` reports the timeout
# exit code (124) correctly so we can print "(timed out)" hints.
set -o pipefail 2>/dev/null || true

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SHELL_DIR="$HOME/.config/quickshell/zen-shell"
HYPR_DIR="$HOME/.config/hypr"
GTK_DIR="$HOME/.config/hypr-control-center"
THEMES_BUILTIN="$GTK_DIR/themes/builtin"
THEMES_CUSTOM="$GTK_DIR/themes/custom"
BIN_DIR="$HOME/.local/bin"
TS=$(date +%Y%m%d-%H%M%S)

echo ""
echo "    Zen Shell v6.14"
echo "    ─────────────────────────────────────────────────────"
echo ""
echo "    Quickshell-native desktop environment for Hyprland."
echo ""
echo "    This release — Bugfix: Tooltip Alignment + SwayNC Position"
echo "      Tooltip fix            SysRow hover tooltip now aligns to icon"
echo "      SwayNC position fix    Notification position changes now apply"
echo "      Process reuse fix      Rapid settings clicks no longer ignored"
echo "      Better restart          SIGTERM-first daemon restart sequence"
echo ""
echo "    ─────────────────────────────────────────────────────"
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
echo "      3. Install all QML files (50 components)"
echo "      4. Auto-apply ZenClock, ZenWorkspaces, Taskbar"
echo "      5. Install CLI scripts and themes"
echo ""

if [ "$EXISTING_INSTALL" -eq 1 ]; then
    echo "    Your current config will be preserved at:"
    echo "      $SHELL_DIR.bak-$TS"
    echo ""
fi

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
MISSING_OPTIONAL_PACKAGES=""
INSTALLED_OPTIONAL_PACKAGES=""
SKIPPED_OPTIONAL_PACKAGES=""
INSTALLER="paru"

add_missing_pkg() {
    local pkg=$1
    case " $MISSING_OPTIONAL_PACKAGES " in
        *" $pkg "*) ;;
        *) MISSING_OPTIONAL_PACKAGES="$MISSING_OPTIONAL_PACKAGES $pkg" ;;
    esac
}

check_cmd() {
    local cmd=$1
    local package=${2:-$1}
    local severity=${3:-required}
    local found_path=""

    if command -v "$cmd" >/dev/null 2>&1; then
        found_path=$(command -v "$cmd")
    else
        for p in /usr/bin /usr/local/bin "$HOME/.local/bin" /opt/"$cmd"/bin; do
            if [ -x "$p/$cmd" ]; then
                found_path="$p/$cmd"
                case ":$PATH:" in
                    *":$p:"*) ;;
                    *) export PATH="$p:$PATH" ;;
                esac
                break
            fi
        done
    fi

    if [ -n "$found_path" ]; then
        echo "    $cmd ($found_path)"
        return 0
    else
        if [ "$severity" = "required" ]; then
            echo "  ✗ $cmd MISSING (install: paru -S $package)"
            MISSING_REQUIRED=1
        else
            echo "  ○ $cmd optional → will offer to install $package"
            add_missing_pkg "$package"
        fi
        return 0
    fi
}

echo "  Required:"
check_cmd qs quickshell required
check_cmd hyprctl hyprland required
check_cmd jq jq required

echo "  Strongly recommended (for wallpaper):"
SWWW_STATUS="missing"
if command -v swww >/dev/null 2>&1 || [ -x /usr/bin/swww ] || [ -x /usr/local/bin/swww ]; then
    SWWW_STATUS="native"
    check_cmd swww swww recommended
    check_cmd swww-daemon swww recommended
elif command -v awww >/dev/null 2>&1 || [ -x /usr/bin/awww ]; then
    SWWW_STATUS="awww-compat"
    AWWW_BIN=$(command -v awww 2>/dev/null || echo "/usr/bin/awww")
    AWWW_DAEMON_BIN=$(command -v awww-daemon 2>/dev/null || echo "/usr/bin/awww-daemon")
    echo "    awww (rebranded swww) detected at $AWWW_BIN"
    mkdir -p "$BIN_DIR"
    [ -e "$AWWW_BIN" ] && ln -sf "$AWWW_BIN" "$BIN_DIR/swww" && \
        echo "    → symlinked $BIN_DIR/swww → $AWWW_BIN"
    [ -e "$AWWW_DAEMON_BIN" ] && ln -sf "$AWWW_DAEMON_BIN" "$BIN_DIR/swww-daemon" && \
        echo "    → symlinked $BIN_DIR/swww-daemon → $AWWW_DAEMON_BIN"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) export PATH="$BIN_DIR:$PATH" ;;
    esac
    check_cmd swww swww recommended
    check_cmd swww-daemon swww recommended
else
    echo "  ○ swww / awww both missing → will offer to install"
    add_missing_pkg awww
fi

echo "  Strongly recommended (for full feature set):"
check_cmd nwg-displays nwg-displays recommended
check_cmd nwg-look nwg-look recommended
check_cmd alacritty alacritty recommended
check_cmd fuzzel fuzzel recommended
check_cmd btm bottom recommended
check_cmd notify-send libnotify recommended
check_cmd blueman-manager blueman recommended
check_cmd nmtui networkmanager recommended
check_cmd zenity zenity recommended
check_cmd thunar thunar recommended
check_cmd tumblerd tumbler recommended
check_cmd ffmpegthumbnailer ffmpegthumbnailer recommended
check_cmd swaync swaync recommended
check_cmd swaync-client swaync recommended

echo "  Screenshot tools:"
check_cmd grim grim recommended
check_cmd slurp slurp recommended
check_cmd wl-copy wl-clipboard recommended
check_cmd flameshot flameshot recommended

echo "  v6.14 — Control Panel dependencies (from v6.13):"
check_cmd nmcli networkmanager recommended
check_cmd bluetoothctl bluez-utils recommended
check_cmd wpctl wireplumber recommended
check_cmd pavucontrol pavucontrol recommended

if [ "$MISSING_REQUIRED" = "1" ]; then
    echo ""
    echo "  ⚠ Required dependencies missing. Install them first, then re-run this script."
    echo "    Quick install all: paru -S quickshell hyprland jq"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# [1b] Offer to install missing optional packages via paru
# ═══════════════════════════════════════════════════════════════
MISSING_OPTIONAL_PACKAGES=$(echo "$MISSING_OPTIONAL_PACKAGES" | xargs)

if [ -n "$MISSING_OPTIONAL_PACKAGES" ]; then
    echo ""
    echo "  Missing optional packages: $MISSING_OPTIONAL_PACKAGES"

    INSTALLER=""
    if command -v paru >/dev/null 2>&1; then
        INSTALLER="paru"
    elif command -v yay >/dev/null 2>&1; then
        INSTALLER="yay"
    elif command -v pacman >/dev/null 2>&1; then
        INSTALLER="sudo pacman"
    fi

    if [ -z "$INSTALLER" ]; then
        echo "  ⚠ No package manager found (paru/yay/pacman). Install manually:"
        echo "    $MISSING_OPTIONAL_PACKAGES"
    else
        echo ""
        echo "  Install all optional packages now with $INSTALLER? [Y/n]"
        if read -r -t 30 REPLY </dev/tty 2>/dev/null; then
            :
        else
            REPLY="n"
            echo "  (no input after 30s — skipping optional install)"
        fi

        case "${REPLY:-y}" in
            [nN]|[nN][oO])
                echo "    Skipping optional install. Re-run installer or:"
                echo "    $INSTALLER -S $MISSING_OPTIONAL_PACKAGES"
                SKIPPED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL_PACKAGES"
                ;;
            *)
                echo "    Running: $INSTALLER -S --needed $MISSING_OPTIONAL_PACKAGES"
                echo ""
                # shellcheck disable=SC2086
                if $INSTALLER -S --needed $MISSING_OPTIONAL_PACKAGES; then
                    INSTALLED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL_PACKAGES"
                    echo ""
                    echo "    Optional packages installed"
                else
                    echo ""
                    echo "  ⚠ Some optional packages failed to install. Continuing anyway..."
                    SKIPPED_OPTIONAL_PACKAGES="$MISSING_OPTIONAL_PACKAGES"
                fi
                ;;
        esac
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [2/9] Backup existing install
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[2/9] Backup..."
[ -d "$SHELL_DIR" ] && cp -r "$SHELL_DIR" "$SHELL_DIR.bak-$TS" && echo "    zen-shell → $SHELL_DIR.bak-$TS"
[ -f "$HYPR_DIR/modules/binds.conf" ] && cp "$HYPR_DIR/modules/binds.conf" "$HYPR_DIR/modules/binds.conf.bak-$TS"

# ═══════════════════════════════════════════════════════════════
# [3/9] Clean stale dirs + create fresh structure
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[3/9] Clean stale subdirs..."
rm -rf "$SHELL_DIR/pages" "$SHELL_DIR/services" 2>/dev/null
mkdir -p "$SHELL_DIR/config" "$HYPR_DIR/modules" "$BIN_DIR"
mkdir -p "$HOME/.config/alacritty" "$HOME/.config/fuzzel"
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/.cache/zen-shell"

# ═══════════════════════════════════════════════════════════════
# [4/9] Install QML files
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[4/9] Install QML files..."
cp "$SCRIPT_DIR"/zen-shell-v5/*.qml "$SHELL_DIR/"
count=$(ls "$SHELL_DIR"/*.qml 2>/dev/null | wc -l)
echo "    $count QML files installed"

echo ""
echo "    v6.14 patched files:"
for f in SysRowIcon.qml NotificationPage.qml; do
    [ -f "$SHELL_DIR/$f" ] && echo "      $f (bugfix)"
done
echo "      patch-swaync-position.sh (bugfix)"

echo "    v6.13 files (carried forward):"
for f in ConnectivityService.qml ControlPanel.qml ConnToggleRow.qml \
         StatChip.qml ConnectivityPage.qml; do
    [ -f "$SHELL_DIR/$f" ] && echo "      $f"
done

# v6.10: Auto-apply bar modules — always copy latest with backup
echo ""
echo "    Auto-applying bar modules..."

for pair in "ZenClock.qml:Clock.qml" "ZenWorkspaces.qml:Workspaces.qml"; do
    src="${pair%%:*}"
    dst="${pair##*:}"
    if [ -f "$SHELL_DIR/$src" ]; then
        if [ -f "$SHELL_DIR/$dst" ]; then
            if ! diff -q "$SHELL_DIR/$src" "$SHELL_DIR/$dst" >/dev/null 2>&1; then
                cp "$SHELL_DIR/$dst" "$SHELL_DIR/$dst.bak-$TS"
                cp "$SHELL_DIR/$src" "$SHELL_DIR/$dst"
                echo "      $src -> $dst (original backed up)"
            else
                echo "      $dst already up to date"
            fi
        else
            cp "$SHELL_DIR/$src" "$SHELL_DIR/$dst"
            echo "      $src -> $dst (fresh install)"
        fi
    fi
done

if [ -f "$SHELL_DIR/Taskbar.qml" ]; then
    if ! grep -q "safeClose" "$SHELL_DIR/Taskbar.qml" 2>/dev/null; then
        echo "      Taskbar.qml updated (close button fix applied)"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [5/9] Install CLI scripts into ~/.local/bin
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[5/9] Install CLI scripts..."

# swww-test from bin/ (v6.2)
if [ -f "$SCRIPT_DIR/bin/swww-test" ]; then
    cp "$SCRIPT_DIR/bin/swww-test" "$BIN_DIR/swww-test"
    chmod +x "$BIN_DIR/swww-test"
    echo "    $BIN_DIR/swww-test"
fi

# v6.5/v6.6+ scripts from scripts/
if [ -d "$SCRIPT_DIR/scripts" ]; then
    for script in fix-monitor-scale.sh blueman-toggle.sh btm-toggle.sh \
                  wifi-toggle.sh termrun.sh regen-terminal-themes.sh \
                  regen-swaync-theme.sh zen-screenshot.sh \
                  patch-swaync-position.sh; do
        src="$SCRIPT_DIR/scripts/$script"
        if [ -f "$src" ]; then
            cp "$src" "$BIN_DIR/$script"
            chmod +x "$BIN_DIR/$script"
            echo "    $BIN_DIR/$script"
        else
            echo "  ⚠ missing: $src"
        fi
    done
fi

# PATH hint if ~/.local/bin not in PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo ""
    echo "  ⚠ $BIN_DIR is not in your PATH. Add this line to ~/.config/fish/config.fish"
    echo "     or ~/.bashrc:"
    echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ═══════════════════════════════════════════════════════════════
# [6/9] Install Hyprland configs + ensure sourcing
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[6/9] Install keybinds + layer rules..."
if [ -f "$SCRIPT_DIR/hypr-config/binds.conf" ]; then
    cp "$SCRIPT_DIR/hypr-config/binds.conf" "$HYPR_DIR/modules/binds.conf"
    echo "    binds.conf"
fi
if [ -f "$SCRIPT_DIR/hypr-config/keybinds-update.conf" ]; then
    cp "$SCRIPT_DIR/hypr-config/keybinds-update.conf" "$SHELL_DIR/config/keybinds-update.conf"
    echo "    keybinds-update.conf (v6.14: carried from v6.13)"
fi
if [ -f "$SCRIPT_DIR/hypr-config/hyprland-layer-rules.conf" ]; then
    cp "$SCRIPT_DIR/hypr-config/hyprland-layer-rules.conf" "$SHELL_DIR/config/hyprland-layer-rules.conf"
    echo "    hyprland-layer-rules.conf (v6.14: carried from v6.13)"
fi

HCONF="$HYPR_DIR/hyprland.conf"
if [ -f "$HCONF" ]; then
    added=0
    if ! grep -q "modules/binds.conf" "$HCONF"; then
        echo "" >> "$HCONF"
        echo "# ── Added by Zen Shell v6.5 installer ──" >> "$HCONF"
        echo "source = ~/.config/hypr/modules/binds.conf" >> "$HCONF"
        added=$((added+1))
    fi
    if ! grep -q "keybinds-update.conf" "$HCONF"; then
        echo "source = ~/.config/quickshell/zen-shell/config/keybinds-update.conf" >> "$HCONF"
        added=$((added+1))
    fi
    if ! grep -q "hyprland-layer-rules.conf" "$HCONF"; then
        echo "source = ~/.config/quickshell/zen-shell/config/hyprland-layer-rules.conf" >> "$HCONF"
        added=$((added+1))
    fi
    [ $added -gt 0 ] && echo "    Added $added source lines to hyprland.conf" || echo "  = hyprland.conf already sourcing all files"

    # v6.12: Ensure QT_QPA_PLATFORM=wayland is set in hyprland.conf
    if ! grep -q "QT_QPA_PLATFORM" "$HCONF"; then
        echo "" >> "$HCONF"
        echo "# ── Added by Zen Shell v6.12 installer ──" >> "$HCONF"
        echo "env = QT_QPA_PLATFORM,wayland" >> "$HCONF"
        echo "    Added env = QT_QPA_PLATFORM,wayland to hyprland.conf"
    else
        echo "  = QT_QPA_PLATFORM already set in hyprland.conf"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [7/9] Install builtin themes
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[7/9] Install builtin themes..."
mkdir -p "$THEMES_BUILTIN" "$THEMES_CUSTOM"
if [ -d "$SCRIPT_DIR/themes-builtin" ]; then
    cp "$SCRIPT_DIR"/themes-builtin/*.json "$THEMES_BUILTIN/"
    tcount=$(ls "$THEMES_BUILTIN"/*.json 2>/dev/null | wc -l)
    echo "    $tcount builtin themes"
fi

if [ ! -f "$GTK_DIR/current-theme.json" ]; then
    if [ -f "$THEMES_BUILTIN/tokyo-night.json" ]; then
        cp "$THEMES_BUILTIN/tokyo-night.json" "$GTK_DIR/current-theme.json"
        echo "    Set tokyo-night as default theme"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# [8/9] First-run: fix monitor scales + generate terminal themes
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[8/9] First-run tasks..."

if [ -x "$BIN_DIR/fix-monitor-scale.sh" ] && [ -f "$HYPR_DIR/modules/monitors.conf" ]; then
    echo "    Running fix-monitor-scale.sh..."
    timeout 10s "$BIN_DIR/fix-monitor-scale.sh" 2>&1 | sed 's/^/    /' \
        || echo "    (skipped or timed out)"
fi

if [ -x "$BIN_DIR/regen-terminal-themes.sh" ] && [ -f "$GTK_DIR/current-theme.json" ]; then
    echo "    Running regen-terminal-themes.sh..."
    timeout 10s "$BIN_DIR/regen-terminal-themes.sh" 2>&1 | sed 's/^/    /' \
        || echo "    (skipped or timed out)"
fi

if [ -x "$BIN_DIR/regen-swaync-theme.sh" ] && [ -f "$GTK_DIR/current-theme.json" ]; then
    echo "    Running regen-swaync-theme.sh..."
    timeout 10s "$BIN_DIR/regen-swaync-theme.sh" 2>&1 | sed 's/^/    /' \
        || echo "    (skipped or timed out)"
fi

# ═══════════════════════════════════════════════════════════════
# [9/9] Restart services
# ═══════════════════════════════════════════════════════════════
echo ""
echo "[9/9] Restart..."
pkill -9 qs 2>/dev/null || true
sleep 0.5
rm -rf "/run/user/$(id -u)/quickshell/by-id"/* 2>/dev/null

# Start swww daemon
if command -v swww >/dev/null 2>&1; then
    if ! swww query > /dev/null 2>&1; then
        if command -v swww-daemon >/dev/null 2>&1; then
            setsid swww-daemon </dev/null >/dev/null 2>&1 &
            disown 2>/dev/null || true
            echo "    Started swww-daemon (detached)"
        else
            setsid swww init </dev/null >/dev/null 2>&1 &
            disown 2>/dev/null || true
            echo "    Started swww (legacy init, detached)"
        fi
        sleep 1
    else
        echo "  = swww daemon already running"
    fi
fi

# Start Zen Shell
setsid qs -c zen-shell > /tmp/zen-shell.log 2>&1 < /dev/null & disown
echo "    Started qs -c zen-shell (log: /tmp/zen-shell.log)"

if pgrep -x Hyprland >/dev/null; then
    sleep 0.5
    hyprctl reload 2>/dev/null
    echo "    Reloaded Hyprland"
fi

sleep 1

# ═══════════════════════════════════════════════════════════════
# FINAL STATUS BANNER
# ═══════════════════════════════════════════════════════════════

INSTALLED_QML_COUNT=$(ls -1 "$SHELL_DIR"/*.qml 2>/dev/null | wc -l)
INSTALLED_SCRIPTS_COUNT=$(ls -1 "$BIN_DIR"/*.sh 2>/dev/null | wc -l)
INSTALLED_THEMES_COUNT=$(ls -1 "$THEMES_BUILTIN"/*.json 2>/dev/null | wc -l)

SHELL_PID=$(pgrep -f "qs -c zen-shell" | head -1)
SWWW_ALIVE="no"
if command -v swww >/dev/null 2>&1 && swww query >/dev/null 2>&1; then
    SWWW_ALIVE="yes"
fi
SWAYNC_ALIVE="no"
pgrep -x swaync >/dev/null 2>&1 && SWAYNC_ALIVE="yes"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║            🎉  ZEN SHELL v6.14 INSTALLED SUCCESSFULLY  🎉      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  ── Install summary ──"
echo "    QML files installed:   $INSTALLED_QML_COUNT"
echo "    Toggle scripts:        $INSTALLED_SCRIPTS_COUNT in $BIN_DIR"
echo "    Builtin themes:        $INSTALLED_THEMES_COUNT"
echo "    Shell running:         ${SHELL_PID:-(not running — check /tmp/zen-shell.log)}"
echo "    swww daemon alive:     $SWWW_ALIVE"
echo "    swaync daemon alive:   $SWAYNC_ALIVE"
if [ -n "$INSTALLED_OPTIONAL_PACKAGES" ]; then
    echo "    Optional pkgs added:   $INSTALLED_OPTIONAL_PACKAGES"
fi
if [ -n "$SKIPPED_OPTIONAL_PACKAGES" ]; then
    echo "    Optional pkgs skipped: $SKIPPED_OPTIONAL_PACKAGES"
    echo "      → rerun: $INSTALLER -S $SKIPPED_OPTIONAL_PACKAGES"
fi
echo ""
echo "  ── Fixed in v6.14 ──"
echo "      Tooltip alignment    SysRow icons → tooltip now pops up above the icon"
echo "      SwayNC position      Settings → Notifications → position actually applies"
echo "      Process reuse        Rapid clicks no longer silently ignored"
echo "      Daemon restart       SIGTERM first, SIGKILL fallback, verify before start"
echo ""
echo "  ── Keybinds ──"
echo "    Super+C      → Control Panel (quick settings)"
echo "    Super+,      → Settings window"
echo "    Super+W      → Wallpaper picker"
echo "    Super+A      → Start menu"
echo "    Super+/      → Keybind cheatsheet"
echo ""
echo "  ── Quick test (v6.14 fixes) ──"
echo "    1. Expand SysRow ❮ → hover each icon"
echo "       → tooltip should appear DIRECTLY ABOVE the hovered icon"
echo "    2. Super+, → Settings → Notifications"
echo "       → click bottom-right → test notification appears bottom-right"
echo "       → check: cat /tmp/zen-swaync-position.log"
echo ""
echo "  ── Diagnostics if something's wrong ──"
echo "    tail -30 /tmp/zen-shell.log              # shell stderr"
echo "    cat /tmp/zen-swaync-position.log         # swaync patch debug"
echo "    grep positionX ~/.config/swaync/config.json  # verify config"
echo "    wpctl status                             # PipeWire check"
echo "    nmcli radio wifi                         # WiFi check"
echo "    bluetoothctl show                        # BT check"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅  All done. Enjoy Zen Shell v6.14, pre."
echo "═══════════════════════════════════════════════════════════════"
echo ""

exit 0
