#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗ 
#  ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗
#  ███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║
#  ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║
#  ██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝
#  ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ 
#                                                                      
#  Hyprland 0.53+ Complete Config Migration & Installation Script
#  Author: Paul's Hyprland Setup
#  Version: 2.0.0
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ─────────────────────────────────────────────────────────────
# COLORS & STYLING
# ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────
HYPR_DIR="$HOME/.config/hypr"
BACKUP_DIR="$HOME/.config/hypr-backup-$(date +%Y%m%d_%H%M%S)"
SCRIPT_VERSION="2.0.0"

# ─────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────
print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║   ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗    ║"
    echo "║   ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║    ║"
    echo "║   ███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║    ║"
    echo "║   ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║    ║"
    echo "║   ██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║    ║"
    echo "║   ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝    ║"
    echo "║                                                                   ║"
    echo "║          ${WHITE}0.53+ Config Migration & Installation${CYAN}                  ║"
    echo "║                    ${GRAY}Script v${SCRIPT_VERSION}${CYAN}                               ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}ℹ${NC} ${WHITE}$1${NC}"; }
log_ok() { echo -e "${GREEN}✓${NC} ${WHITE}$1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠${NC} ${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}✗${NC} ${RED}$1${NC}"; }
log_step() {
    echo -e "\n${MAGENTA}⚙${NC} ${BOLD}$1${NC}"
    echo -e "${GRAY}────────────────────────────────────────────${NC}"
}

confirm() {
    echo -e -n "${YELLOW}$1 (y/N): ${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ─────────────────────────────────────────────────────────────
# VERSION CHECK
# ─────────────────────────────────────────────────────────────
check_hyprland_version() {
    log_step "Checking Hyprland Version"
    
    if ! command -v hyprctl &> /dev/null; then
        log_warn "hyprctl not found - Hyprland may not be installed"
        if confirm "Continue anyway?"; then
            return 0
        else
            exit 1
        fi
    fi
    
    local version=$(hyprctl version 2>/dev/null | grep -oP 'Hyprland \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [[ -z "$version" ]]; then
        log_warn "Could not detect Hyprland version"
        return 0
    fi
    
    log_ok "Detected Hyprland version: ${CYAN}$version${NC}"
    
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    
    if [[ "$major" -eq 0 ]] && [[ "$minor" -lt 53 ]]; then
        log_warn "This config requires Hyprland 0.53+"
        log_warn "Your version: $version"
        echo ""
        if confirm "Upgrade Hyprland first?"; then
            upgrade_hyprland
        else
            log_warn "Proceeding with current version - expect errors!"
        fi
    else
        log_ok "Version compatible ✓"
    fi
}

# ─────────────────────────────────────────────────────────────
# HYPRLAND UPGRADE
# ─────────────────────────────────────────────────────────────
upgrade_hyprland() {
    log_step "Upgrading Hyprland"
    
    if command -v paru &> /dev/null; then
        PKG_MGR="paru"
    elif command -v yay &> /dev/null; then
        PKG_MGR="yay"
    elif command -v pacman &> /dev/null; then
        PKG_MGR="sudo pacman"
    else
        log_error "No supported package manager found"
        return 1
    fi
    
    log_info "Using: ${CYAN}$PKG_MGR${NC}"
    
    echo ""
    echo -e "${WHITE}Select package:${NC}"
    echo -e "  ${CYAN}1)${NC} hyprland        ${GRAY}(stable)${NC}"
    echo -e "  ${CYAN}2)${NC} hyprland-git    ${GRAY}(latest)${NC}"
    echo -e "  ${CYAN}3)${NC} Skip"
    echo -e -n "${YELLOW}Choice [1-3]: ${NC}"
    read -r choice
    
    case $choice in
        1) $PKG_MGR -S --needed hyprland ;;
        2) $PKG_MGR -S --needed hyprland-git ;;
        *) log_info "Skipping upgrade"; return 0 ;;
    esac
    
    log_info "Upgrading related packages..."
    $PKG_MGR -S --needed --noconfirm hyprutils hyprlang xdg-desktop-portal-hyprland 2>/dev/null || true
    
    log_ok "Upgrade complete"
}

# ─────────────────────────────────────────────────────────────
# BACKUP
# ─────────────────────────────────────────────────────────────
backup_existing_config() {
    log_step "Backing Up Configuration"
    
    if [[ -d "$HYPR_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$HYPR_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
        local count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
        log_ok "Backup: ${CYAN}$BACKUP_DIR${NC} (${count} files)"
    else
        log_info "No existing config - fresh install"
        mkdir -p "$HYPR_DIR"
    fi
}

# ─────────────────────────────────────────────────────────────
# DIRECTORY STRUCTURE
# ─────────────────────────────────────────────────────────────
create_directories() {
    log_step "Creating Directories"
    
    mkdir -p "$HYPR_DIR"/{modules,scripts/waybar,colorscheme}
    log_ok "Directory structure created"
}

# ─────────────────────────────────────────────────────────────
# MAIN CONFIG (0.53+ SYNTAX)
# ─────────────────────────────────────────────────────────────
install_main_config() {
    log_step "Installing Main Config (0.53+ Syntax)"
    
    cat > "$HYPR_DIR/hyprland.conf" << 'EOF'
# ═══════════════════════════════════════════════════════════════
# HYPRLAND 0.53+ CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
# IMPORTS
# ─────────────────────────────────────────────────────────────
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/modules/autostart.conf
source = ~/.config/hypr/modules/look_and_feel.conf
source = ~/.config/hypr/modules/animations.conf
source = ~/.config/hypr/modules/binds.conf

# ─────────────────────────────────────────────────────────────
# PROGRAMS
# ─────────────────────────────────────────────────────────────
$terminal = kitty
$fileManager = thunar
$menu = rofi -show drun

# ─────────────────────────────────────────────────────────────
# ENVIRONMENT
# ─────────────────────────────────────────────────────────────
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

# ─────────────────────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────────────────────
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    touchpad {
        natural_scroll = false
    }
}

# ─────────────────────────────────────────────────────────────
# GESTURES (0.51+ SYNTAX)
# OLD: gestures { workspace_swipe = true }  <- REMOVED!
# NEW: gesture = <fingers>, <direction>, <action>
# ─────────────────────────────────────────────────────────────
gesture = 3, horizontal, workspace

# ─────────────────────────────────────────────────────────────
# LAYOUTS
# ─────────────────────────────────────────────────────────────
dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_status = master
}

misc {
    force_default_wallpaper = -1
    disable_hyprland_logo = false
}

# ─────────────────────────────────────────────────────────────
# WINDOW RULES (0.53 SYNTAX)
# 
# FORMAT: windowrule = <effect> <value>, match:<matcher> <pattern>
#
# OLD -> NEW:
#   suppressevent -> suppress_event
#   nofocus       -> no_focus
#   noborder      -> border_size 0
#   noshadow      -> no_shadow
#   noanim        -> no_anim
#   noblur        -> no_blur
# ─────────────────────────────────────────────────────────────

# Suppress maximize
windowrule = suppress_event maximize, match:class .*

# Terminals
windowrule {
    name = terminal-float
    match:class = ^(kitty)$
    float = true
    center = true
}

# File manager
windowrule {
    name = filemanager-float
    match:class = ^(thunar)$
    float = true
    center = true
}

# Flameshot
windowrule {
    name = flameshot-rules
    match:class = ^(flameshot)$
    float = true
    center = true
}

# Picture in Picture
windowrule {
    name = pip-rules
    match:title = ^(Picture-in-Picture)$
    float = true
    pin = true
}

# Steam notifications
windowrule {
    name = steam-notif
    match:class = ^(steam)$
    match:title = ^(notificationtoasts)$
    float = true
    pin = true
    move = 100%-450 40
}

# ─────────────────────────────────────────────────────────────
# LAYER RULES (0.53 SYNTAX)
#
# OLD -> NEW:
#   blur          -> blur on
#   ignorezero    -> ignore_alpha 1
#   ignorealpha X -> ignore_alpha X
# ─────────────────────────────────────────────────────────────

layerrule = blur on, ignore_alpha 0.5, match:namespace waybar
layerrule = blur on, ignore_alpha 1, match:namespace notifications
layerrule = blur on, ignore_alpha 0.5, match:namespace start-menu
layerrule = blur on, ignore_alpha 0.5, match:namespace hypr-control-center

# ─────────────────────────────────────────────────────────────
# AUTOSTART
# ─────────────────────────────────────────────────────────────
exec-once = ~/.config/hypr/scripts/swww-init.sh
exec-once = hyprpm reload -n
exec-once = ~/.config/hypr-control-center/src/zenpybar/run.sh

# ─────────────────────────────────────────────────────────────
# PLUGINS
# ─────────────────────────────────────────────────────────────
plugin:hyprbars {
    bar_height = 28
    bar_color = rgb(1a1b26)
    col.text = rgb(c0caf5)
    col.button_close = rgb(f38ba8)
    col.button_minimize = rgb(f9e2af)
    col.button_maximize = rgb(a6e3a1)
    bar_text_size = 10
    bar_text_font = Adwaita Sans
    bar_text_align = center
    bar_padding = 8
    bar_button_padding = 10
    bar_buttons_alignment = left
    hyprbars-button = rgb(f38ba8), 17, , hyprctl dispatch killactive
    hyprbars-button = rgb(f9e2af), 17, , ~/.config/hypr/scripts/waybar/hyprbars-minimize.sh
    hyprbars-button = rgb(a6e3a1), 17, , hyprctl dispatch fullscreen 1
}

plugin:hyprspace {
    overview_gapsout = 20
    overview_gapsin = 10
    overview_columns = 3
    overview_autohide = true
    overview_show_names = true
}

# ─────────────────────────────────────────────────────────────
# BORDER RULES (0.53: noborder is INVALID, use border_size 0)
# ─────────────────────────────────────────────────────────────
windowrule = border_size 0, match:fullscreen 1
windowrule = border_size 0, match:floating true
windowrule = border_size 0, match:title ^(Start Menu)$
windowrule = border_size 0, match:title ^(hypr-widget-)

# ─────────────────────────────────────────────────────────────
# WIDGETS
# ─────────────────────────────────────────────────────────────
windowrule {
    name = widget-rules
    match:title = ^(hypr-widget-)
    float = true
    pin = true
    border_size = 0
    no_shadow = true
    no_anim = true
}

# ─────────────────────────────────────────────────────────────
# OPACITY
# ─────────────────────────────────────────────────────────────
windowrule = opacity 1.0 override, match:class ^(zenpy|hypr-control-center)$
EOF

    log_ok "Main config installed"
}

# ─────────────────────────────────────────────────────────────
# MODULE: MONITORS
# ─────────────────────────────────────────────────────────────
install_monitors() {
    [[ -f "$HYPR_DIR/monitors.conf" ]] && { log_info "monitors.conf exists - preserving"; return 0; }
    
    cat > "$HYPR_DIR/monitors.conf" << 'EOF'
# ─────────────────────────────────────────────────────────────
# MONITORS - https://wiki.hypr.land/Configuring/Monitors/
# ─────────────────────────────────────────────────────────────
monitor = ,preferred,auto,1

# Examples:
# monitor = DP-1,2560x1440@170,0x0,1
# monitor = HDMI-A-1,1920x1080@144,2560x0,1
EOF
    log_ok "Created monitors.conf"
}

# ─────────────────────────────────────────────────────────────
# MODULE: AUTOSTART
# ─────────────────────────────────────────────────────────────
install_autostart() {
    [[ -f "$HYPR_DIR/modules/autostart.conf" ]] && { log_info "autostart.conf exists - preserving"; return 0; }
    
    cat > "$HYPR_DIR/modules/autostart.conf" << 'EOF'
# ─────────────────────────────────────────────────────────────
# AUTOSTART
# ─────────────────────────────────────────────────────────────
exec-once = swaync
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
EOF
    log_ok "Created autostart.conf"
}

# ─────────────────────────────────────────────────────────────
# MODULE: LOOK AND FEEL
# ─────────────────────────────────────────────────────────────
install_look_and_feel() {
    [[ -f "$HYPR_DIR/modules/look_and_feel.conf" ]] && { log_info "look_and_feel.conf exists - preserving"; return 0; }
    
    cat > "$HYPR_DIR/modules/look_and_feel.conf" << 'EOF'
# ─────────────────────────────────────────────────────────────
# LOOK AND FEEL
# ─────────────────────────────────────────────────────────────
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    allow_tearing = false
}

decoration {
    rounding = 10
    rounding_power = 2.0
    active_opacity = 1.0
    inactive_opacity = 0.9
    fullscreen_opacity = 1.0
    dim_inactive = false

    blur {
        enabled = true
        size = 8
        passes = 2
        new_optimizations = true
        xray = false
        noise = 0.0117
        contrast = 0.8916
        brightness = 0.8172
        vibrancy = 0.1696
        popups = true
    }

    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }
}

group {
    col.border_active = rgba(33ccffee)
    col.border_inactive = rgba(595959aa)
    groupbar {
        enabled = true
        font_size = 10
        height = 20
        col.active = rgba(33ccffee)
        col.inactive = rgba(595959aa)
    }
}
EOF
    log_ok "Created look_and_feel.conf"
}

# ─────────────────────────────────────────────────────────────
# MODULE: ANIMATIONS
# ─────────────────────────────────────────────────────────────
install_animations() {
    [[ -f "$HYPR_DIR/modules/animations.conf" ]] && { log_info "animations.conf exists - preserving"; return 0; }
    
    cat > "$HYPR_DIR/modules/animations.conf" << 'EOF'
# ─────────────────────────────────────────────────────────────
# ANIMATIONS
# ─────────────────────────────────────────────────────────────
animations {
    enabled = true

    bezier = easeOutExpo, 0.16, 1, 0.3, 1
    bezier = easeInOutCubic, 0.65, 0, 0.35, 1
    bezier = linear, 0, 0, 1, 1
    bezier = almostLinear, 0.5, 0.5, 0.75, 1.0
    bezier = quick, 0.15, 0, 0.1, 1

    animation = global, 1, 10, default
    animation = border, 1, 5.39, easeOutExpo
    animation = windows, 1, 4.79, easeOutExpo
    animation = windowsIn, 1, 4.1, easeOutExpo, popin 87%
    animation = windowsOut, 1, 1.49, linear, popin 87%
    animation = fadeIn, 1, 1.73, almostLinear
    animation = fadeOut, 1, 1.46, almostLinear
    animation = fade, 1, 3.03, quick
    animation = layers, 1, 3.81, easeOutExpo
    animation = layersIn, 1, 4, easeOutExpo, fade
    animation = layersOut, 1, 1.5, linear, fade
    animation = workspaces, 1, 1.94, almostLinear, fade
}
EOF
    log_ok "Created animations.conf"
}

# ─────────────────────────────────────────────────────────────
# MODULE: KEYBINDINGS
# ─────────────────────────────────────────────────────────────
install_binds() {
    [[ -f "$HYPR_DIR/modules/binds.conf" ]] && { log_info "binds.conf exists - preserving"; return 0; }
    
    cat > "$HYPR_DIR/modules/binds.conf" << 'EOF'
# ─────────────────────────────────────────────────────────────
# KEYBINDINGS
# ─────────────────────────────────────────────────────────────
$mainMod = SUPER

# Apps
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, R, exec, $menu
bind = $mainMod, B, exec, firefox

# Window
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, V, togglefloating
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit
bind = $mainMod, F, fullscreen

# Focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Move
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

# Resize
binde = $mainMod CTRL, left, resizeactive, -20 0
binde = $mainMod CTRL, right, resizeactive, 20 0
binde = $mainMod CTRL, up, resizeactive, 0 -20
binde = $mainMod CTRL, down, resizeactive, 0 20

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scratchpad
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Mouse
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Media
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Screenshot
bind = , Print, exec, grimblast copy area
bind = SHIFT, Print, exec, grimblast copy screen
EOF
    log_ok "Created binds.conf"
}

# ─────────────────────────────────────────────────────────────
# SCRIPTS
# ─────────────────────────────────────────────────────────────
install_scripts() {
    log_step "Installing Scripts"
    
    # SWWW Init
    cat > "$HYPR_DIR/scripts/swww-init.sh" << 'EOF'
#!/bin/bash
killall -q swww-daemon 2>/dev/null
sleep 0.5
swww-daemon &
sleep 1
WALLPAPER="$HOME/wallpapers/default.jpg"
[[ -f "$WALLPAPER" ]] && swww img "$WALLPAPER" --transition-type grow --transition-duration 2
EOF
    chmod +x "$HYPR_DIR/scripts/swww-init.sh"
    log_ok "Created swww-init.sh"
    
    # Hyprbars minimize
    cat > "$HYPR_DIR/scripts/waybar/hyprbars-minimize.sh" << 'EOF'
#!/bin/bash
ADDR=$(hyprctl activewindow -j | jq -r '.address')
hyprctl dispatch movetoworkspacesilent special:minimized,address:$ADDR
EOF
    chmod +x "$HYPR_DIR/scripts/waybar/hyprbars-minimize.sh"
    log_ok "Created hyprbars-minimize.sh"
}

# ─────────────────────────────────────────────────────────────
# VALIDATE
# ─────────────────────────────────────────────────────────────
validate_config() {
    log_step "Validating Configuration"
    
    if ! command -v hyprctl &> /dev/null || ! pgrep -x Hyprland > /dev/null; then
        log_info "Validation will occur on next Hyprland start"
        return 0
    fi
    
    log_info "Reloading config..."
    if hyprctl reload 2>&1 | grep -qi "error"; then
        log_error "Config has errors - check above"
        log_info "Backup at: ${CYAN}$BACKUP_DIR${NC}"
        return 1
    fi
    log_ok "Config reloaded successfully!"
}

# ─────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${GREEN}${BOLD}Installation Complete!${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Installed:${NC}"
    echo -e "  → ${CYAN}$HYPR_DIR/hyprland.conf${NC}"
    echo -e "  → ${CYAN}$HYPR_DIR/monitors.conf${NC}"
    echo -e "  → ${CYAN}$HYPR_DIR/modules/*.conf${NC}"
    echo -e "  → ${CYAN}$HYPR_DIR/scripts/*${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Backup:${NC} ${YELLOW}$BACKUP_DIR${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}0.53 Syntax Changes:${NC}"
    echo -e "  ${GRAY}OLD${NC} gestures { workspace_swipe = true }  ${RED}→${NC} ${GREEN}gesture = 3, horizontal, workspace${NC}"
    echo -e "  ${GRAY}OLD${NC} windowrulev2 = float, class:^(x)\$   ${RED}→${NC} ${GREEN}windowrule = float true, match:class ^(x)\$${NC}"
    echo -e "  ${GRAY}OLD${NC} layerrule = blur, waybar             ${RED}→${NC} ${GREEN}layerrule = blur on, match:namespace waybar${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Commands:${NC}"
    echo -e "  Reload: ${CYAN}hyprctl reload${NC}"
    echo -e "  Edit:   ${CYAN}$EDITOR $HYPR_DIR/hyprland.conf${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Resources:${NC}"
    echo -e "  Wiki:      ${BLUE}https://wiki.hypr.land${NC}"
    echo -e "  Converter: ${BLUE}https://forum.hypr.land/t/0-53-window-layerrule-converter/1243${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────
main() {
    print_header
    
    echo -e "${WHITE}This script will:${NC}"
    echo -e "  → Check/upgrade Hyprland to 0.53+"
    echo -e "  → Backup existing configuration"
    echo -e "  → Install 0.53+ compatible config"
    echo -e "  → Create all module files"
    echo ""
    
    if ! confirm "Continue?"; then
        echo -e "${YELLOW}Cancelled${NC}"
        exit 0
    fi
    
    check_hyprland_version
    backup_existing_config
    create_directories
    install_main_config
    install_monitors
    install_autostart
    install_look_and_feel
    install_animations
    install_binds
    install_scripts
    validate_config
    print_summary
}

main "$@"