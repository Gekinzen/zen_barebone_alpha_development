#!/usr/bin/env bash
set -e

# ==================================================
# Zen Barebone Installer - Complete Fixed Edition
# WITH ALL FIXES + SMART WALLPAPER DETECTION
# ==================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Zen Barebone Installer - Complete Edition${NC}"
echo "======================================"
echo ""

# ==================================================
# Detect OS (Arch-based only)
# ==================================================
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo -e "${RED}Cannot detect OS${NC}"
  exit 1
fi

case "$ID" in
  arch|endeavouros|cachyos|manjaro) ;;
  *)
    echo -e "${RED}Unsupported distro: $ID${NC}"
    echo "This installer is for Arch-based distributions only."
    exit 1
    ;;
esac

echo -e "${GREEN}Detected distro: $NAME${NC}"
echo ""

# ==================================================
# SMART BACKUP
# ==================================================
BACKUP_ROOT="$HOME/.config/zen-backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

CONFIG_TARGETS=(hypr waybar kitty swaync rofi zen)

echo -e "${CYAN}Checking existing configs...${NC}"

FOUND=false
for cfg in "${CONFIG_TARGETS[@]}"; do
  [[ -d "$HOME/.config/$cfg" ]] && FOUND=true
done

if [[ "$FOUND" == true ]]; then
  echo -e "${YELLOW}Existing configs found - backing up${NC}"
  mkdir -p "$BACKUP_DIR"

  for cfg in "${CONFIG_TARGETS[@]}"; do
    [[ -d "$HOME/.config/$cfg" ]] && cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/"
  done

  [[ -d "$HOME/.cache/waybar" ]] && {
    mkdir -p "$BACKUP_DIR/.cache"
    cp -a "$HOME/.cache/waybar" "$BACKUP_DIR/.cache/"
  }

  echo -e "${GREEN}Backup saved to: $BACKUP_DIR${NC}"
  echo ""
else
  echo -e "${GREEN}No existing configs detected${NC}"
fi

# ==================================================
# Base Dependencies
# ==================================================
echo -e "${BLUE}Installing base dependencies...${NC}"
sudo pacman -S --needed --noconfirm \
  git \
  base-devel \
  curl \
  rsync \
  wget \
  jq \
  cmake \
  meson \
  cpio

# ==================================================
# yay (AUR Helper)
# ==================================================
if ! command -v yay &>/dev/null; then
  echo -e "${BLUE}Installing yay...${NC}"
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
  echo -e "${GREEN}yay installed${NC}"
else
  echo -e "${GREEN}yay already installed${NC}"
fi

echo ""

# ==================================================
# CRITICAL: Python + GTK4 + GObject Introspection
# ==================================================
echo -e "${PURPLE}Installing Python + GTK4 stack${NC}"

sudo pacman -S --needed --noconfirm \
  python \
  python-pip \
  python-setuptools \
  python-wheel \
  python-gobject \
  python-cairo \
  gobject-introspection \
  gtk4 \
  libadwaita \
  cairo

echo -e "${BLUE}Installing Python dependencies...${NC}"
pip install --break-system-packages --upgrade \
  pillow \
  psutil \
  pytz

echo -e "${CYAN}Verifying Cairo bindings...${NC}"
if python -c "import cairo" 2>/dev/null; then
  echo -e "${GREEN}Cairo bindings working${NC}"
else
  echo -e "${YELLOW}Cairo bindings issue, installing from pip...${NC}"
  pip install --break-system-packages pycairo
fi

echo -e "${GREEN}Python stack complete${NC}"
echo ""

# ==================================================
# GTK4 Layer Shell
# ==================================================
echo -e "${PURPLE}Installing GTK4 Layer Shell...${NC}"
yay -S --needed --noconfirm gtk4-layer-shell

echo -e "${GREEN}GTK4 Layer Shell installed${NC}"
echo ""

# ==================================================
# ZSH SETUP
# ==================================================
echo -e "${PURPLE}Installing zsh${NC}"

sudo pacman -S --needed --noconfirm zsh zsh-completions

[[ ! -x /bin/zsh ]] && {
  echo -e "${RED}/bin/zsh missing${NC}"
  exit 1
}

grep -q "^/bin/zsh$" /etc/shells || echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null

echo -e "${GREEN}Zsh installed${NC}"

if [[ ! -f "$HOME/.zshrc" ]]; then
  cat > "$HOME/.zshrc" << 'EOF'
# Basic zsh config
autoload -Uz compinit && compinit
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
EOF
  echo -e "${GREEN}Created basic .zshrc${NC}"
fi

echo ""

# ==================================================
# KITTY SAFE MODE
# ==================================================
echo -e "${PURPLE}Configuring Kitty${NC}"

KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$HOME/.config/kitty"

[[ -f "$KITTY_CONF" ]] && cp "$KITTY_CONF" "$KITTY_CONF.pre-install.bak"

if grep -q "^shell " "$KITTY_CONF" 2>/dev/null; then
  sed -i 's|^shell .*|shell /bin/bash|' "$KITTY_CONF"
else
  echo "shell /bin/bash" >> "$KITTY_CONF"
fi

echo -e "${GREEN}Kitty configured${NC}"
echo ""

# ==================================================
# Hyprland + Wayland Ecosystem
# ==================================================
echo -e "${PURPLE}Installing Hyprland ecosystem${NC}"

yay -S --needed --noconfirm \
  hyprland \
  hyprland-protocols \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  qt5-wayland \
  qt6-wayland \
  polkit-kde-agent

echo -e "${GREEN}Hyprland core installed${NC}"
echo ""

# ==================================================
# HYPRBARS PLUGIN
# ==================================================
echo -e "${PURPLE}Installing hyprbars plugin${NC}"

sudo pacman -S --needed --noconfirm \
  git \
  cmake \
  meson \
  ninja \
  gcc \
  pkgconf

echo -e "${CYAN}Installing hyprland-headers from AUR...${NC}"
yay -S --needed --noconfirm hyprland-headers || {
  echo -e "${YELLOW}Warning: hyprland-headers install had issues${NC}"
}

echo -e "${CYAN}Setting up hyprbars via hyprpm...${NC}"
hyprpm update 2>/dev/null || true
hyprpm add https://github.com/hyprwm/hyprland-plugins 2>/dev/null || true
hyprpm enable hyprbars 2>/dev/null || true

echo -e "${GREEN}Hyprbars plugin setup complete${NC}"
echo ""

# ==================================================
# Desktop Utilities & Tools
# ==================================================
echo -e "${PURPLE}Installing desktop tools${NC}"

yay -S --needed --noconfirm \
  swww \
  waybar \
  swaync \
  rofi-wayland \
  wofi \
  kitty \
  thunar \
  thunar-archive-plugin \
  thunar-volman \
  ffmpegthumbnailer \
  tumbler \
  gvfs \
  gvfs-mtp \
  file-roller \
  grim \
  slurp \
  flameshot \
  wl-clipboard \
  cliphist \
  hyprpicker \
  brightnessctl \
  playerctl \
  pamixer \
  pipewire \
  pipewire-pulse \
  pipewire-alsa \
  wireplumber \
  bluez \
  bluez-utils \
  blueman \
  networkmanager \
  network-manager-applet

echo -e "${GREEN}Desktop utilities installed${NC}"
echo ""

# ==================================================
# Power Management (cpupower + tlp)
# ==================================================
echo -e "${PURPLE}Installing power management tools${NC}"

sudo pacman -S --needed --noconfirm \
  cpupower \
  tlp \
  tlp-rdw

echo -e "${GREEN}Power management tools installed${NC}"
echo ""

# ==================================================
# Theming & Appearance
# ==================================================
echo -e "${PURPLE}Installing theme tools${NC}"

yay -S --needed --noconfirm \
  nwg-look \
  nwg-displays \
  adw-gtk-theme \
  papirus-icon-theme \
  xcursor-breeze

echo -e "${GREEN}Theme tools installed${NC}"
echo ""

# ==================================================
# Gaming Tools
# ==================================================
echo -e "${PURPLE}Installing gaming tools${NC}"

yay -S --needed --noconfirm \
  protonup-qt

echo -e "${GREEN}Gaming tools installed${NC}"
echo ""

# ==================================================
# Fonts
# ==================================================
echo -e "${PURPLE}Installing fonts${NC}"

yay -S --needed --noconfirm \
  ttf-jetbrains-mono-nerd \
  ttf-geist-mono-nerd \
  ttf-fira-code \
  ttf-font-awesome \
  noto-fonts \
  noto-fonts-emoji \
  noto-fonts-cjk

echo -e "${CYAN}Rebuilding font cache...${NC}"
fc-cache -fv >/dev/null 2>&1

echo -e "${GREEN}Fonts installed${NC}"
echo ""

# ==================================================
# System Monitoring Tools
# ==================================================
echo -e "${PURPLE}Installing system monitoring tools${NC}"

sudo pacman -S --needed --noconfirm \
  btop \
  htop \
  lm_sensors \
  acpi \
  upower

echo -e "${GREEN}System tools installed${NC}"
echo ""

# ==================================================
# Create Essential Directories
# ==================================================
echo -e "${BLUE}Creating directories...${NC}"

mkdir -p \
  "$HOME/wallpapers" \
  "$HOME/.local/bin" \
  "$HOME/.local/share/applications" \
  "$HOME/.config/hypr/scripts" \
  "$HOME/.config/systemd/user" \
  "$HOME/.cache/waybar"

echo -e "${GREEN}Directories created${NC}"
echo ""

# ==================================================
# SMART WALLPAPER DETECTION & COPY
# ==================================================
echo -e "${PURPLE}Setting up wallpapers...${NC}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Try multiple possible wallpaper locations
WALLPAPER_SOURCES=(
  "$REPO_ROOT/wallpapers"
  "$REPO_ROOT/images"
  "$REPO_ROOT/.config/wallpapers"
  "$REPO_ROOT/assets/wallpapers"
)

WALLPAPER_FOUND=false

for SOURCE in "${WALLPAPER_SOURCES[@]}"; do
  if [[ -d "$SOURCE" ]]; then
    echo -e "${CYAN}Found wallpapers in: $SOURCE${NC}"
    
    # Copy all wallpapers
    cp -rv "$SOURCE"/* "$HOME/wallpapers/" 2>/dev/null && {
      WALLPAPER_FOUND=true
      echo -e "${GREEN}Wallpapers copied to: $HOME/wallpapers${NC}"
      break
    }
  fi
done

if [[ "$WALLPAPER_FOUND" == false ]]; then
  echo -e "${YELLOW}No wallpapers directory found in repo${NC}"
  echo -e "${YELLOW}Checked: ${WALLPAPER_SOURCES[*]}${NC}"
fi

echo ""

# ==================================================
# DEPLOY CONFIGS
# ==================================================
echo -e "${CYAN}Applying configs from repo${NC}"

CONFIG_SOURCE="$REPO_ROOT/.config"

[[ ! -d "$CONFIG_SOURCE" ]] && {
  echo -e "${RED}Repo .config not found at: $CONFIG_SOURCE${NC}"
  exit 1
}

mkdir -p "$HOME/.config"

for dir in "$CONFIG_SOURCE"/*; do
  [[ ! -d "$dir" ]] && continue
  name="$(basename "$dir")"
  echo -e "${BLUE}Installing: $name${NC}"
  rsync -av --delete "$dir/" "$HOME/.config/$name/" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Could not fully sync $name${NC}"
  }
done

echo -e "${GREEN}Configs applied${NC}"
echo ""

# ==================================================
# FIX HYPRLAND CONFIG - REMOVE DEPRECATED RULES
# ==================================================
echo -e "${PURPLE}Fixing Hyprland config...${NC}"

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

if [[ -f "$HYPR_CONF" ]]; then
  # Backup
  cp "$HYPR_CONF" "$HYPR_CONF.backup-$(date +%s)"
  
  # Remove all deprecated windowrulev2 lines
  sed -i '/windowrulev2 = plugin:hyprbars:nobar/d' "$HYPR_CONF"
  
  # Fix plugin syntax if needed
  sed -i 's/^plugin {$/plugin:hyprbars {/' "$HYPR_CONF"
  
  # Ensure correct hyprbars config exists
  if ! grep -q "plugin:hyprbars {" "$HYPR_CONF"; then
    cat >> "$HYPR_CONF" << 'EOF'

# ─────────────────────────────────────────────────────────────
# PLUGINS (CORRECTED SYNTAX)
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
EOF
  fi
  
  # Add correct window rules if not present
  if ! grep -q "# HYPRBARS RULES (FIXED)" "$HYPR_CONF"; then
    cat >> "$HYPR_CONF" << 'EOF'

# ─────────────────────────────────────────────────────────────
# HYPRBARS RULES (FIXED)
# ─────────────────────────────────────────────────────────────
windowrulev2 = noborder, fullscreen:1
windowrulev2 = noborder, floating:1
windowrulev2 = noborder, title:^(Start Menu)$
windowrulev2 = noborder, title:^(hypr-widget-)
EOF
  fi
  
  echo -e "${GREEN}Hyprland config fixed${NC}"
else
  echo -e "${YELLOW}Hyprland config not found${NC}"
fi

echo ""

# ==================================================
# SMART DEFAULT WALLPAPER DETECTION
# ==================================================
echo -e "${PURPLE}Setting default wallpaper...${NC}"

# Try to find the anime wallpaper
POSSIBLE_WALLPAPERS=(
  "$HOME/wallpapers/anime-crescent-moon-over-forest-desktop-wallpaper.jpg"
  "$HOME/wallpapers/anime-crescent-moon-over-forest.jpg"
  "$HOME/wallpapers/"*moon*.jpg
  "$HOME/wallpapers/"*anime*.jpg
)

DEFAULT_WALLPAPER=""

for WALLPAPER in "${POSSIBLE_WALLPAPERS[@]}"; do
  if [[ -f "$WALLPAPER" ]]; then
    DEFAULT_WALLPAPER="$WALLPAPER"
    echo -e "${GREEN}Found wallpaper: $(basename "$WALLPAPER")${NC}"
    break
  fi
done

# If no specific wallpaper found, use first jpg in wallpapers dir
if [[ -z "$DEFAULT_WALLPAPER" ]]; then
  DEFAULT_WALLPAPER=$(find "$HOME/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \) | head -n1)
fi

if [[ -n "$DEFAULT_WALLPAPER" && -f "$DEFAULT_WALLPAPER" ]]; then
  # Create swww init script
  SWWW_SCRIPT="$HOME/.config/hypr/scripts/swww-init.sh"
  mkdir -p "$(dirname "$SWWW_SCRIPT")"
  
  cat > "$SWWW_SCRIPT" << EOF
#!/usr/bin/env bash

# Kill existing swww daemon
pkill swww-daemon

# Initialize swww daemon
swww-daemon &

# Wait for daemon to be ready
sleep 2

# Set wallpaper
swww img "$DEFAULT_WALLPAPER" --transition-type fade --transition-duration 2
EOF
  
  chmod +x "$SWWW_SCRIPT"
  
  echo -e "${GREEN}Default wallpaper set: $(basename "$DEFAULT_WALLPAPER")${NC}"
  
  # Update autostart
  AUTOSTART_CONF="$HOME/.config/hypr/modules/autostart.conf"
  if [[ -f "$AUTOSTART_CONF" ]]; then
    # Remove old wallpaper scripts
    sed -i '/wallpaper-slideshow/d' "$AUTOSTART_CONF"
    sed -i '/swww-init/d' "$AUTOSTART_CONF"
    
    # Add new swww init
    echo "exec-once = ~/.config/hypr/scripts/swww-init.sh" >> "$AUTOSTART_CONF"
    echo -e "${GREEN}Added swww-init to autostart${NC}"
  fi
else
  echo -e "${YELLOW}No wallpaper found in ~/wallpapers${NC}"
fi

echo ""

# ==================================================
# FIX WAYBAR DESKTOP PORTAL
# ==================================================
echo -e "${PURPLE}Fixing Waybar desktop portal...${NC}"

mkdir -p "$HOME/.config/xdg-desktop-portal"

cat > "$HOME/.config/xdg-desktop-portal/portals.conf" << 'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Settings=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.Screencast=hyprland
EOF

cat > "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" << 'EOF'
[preferred]
default=hyprland;gtk
EOF

killall xdg-desktop-portal-hyprland 2>/dev/null || true
killall xdg-desktop-portal 2>/dev/null || true
sleep 2

echo -e "${GREEN}Portal config created${NC}"
echo ""

# ==================================================
# KITTY FINAL SHELL (ZSH)
# ==================================================
echo -e "${PURPLE}Switching Kitty to zsh${NC}"

if [[ -f "$KITTY_CONF" ]]; then
  sed -i 's|^shell .*|shell /bin/zsh|' "$KITTY_CONF"
  echo -e "${GREEN}Kitty will use zsh${NC}"
fi

echo ""

# ==================================================
# Ownership Fix
# ==================================================
echo -e "${BLUE}Fixing permissions...${NC}"

[[ "$(stat -c '%U' "$HOME/.config" 2>/dev/null)" != "$USER" ]] && \
  sudo chown -R "$USER:$USER" "$HOME/.config"
[[ -d "$HOME/.local" ]] && sudo chown -R "$USER:$USER" "$HOME/.local"
[[ -d "$HOME/wallpapers" ]] && sudo chown -R "$USER:$USER" "$HOME/wallpapers"

echo -e "${GREEN}Permissions fixed${NC}"
echo ""

# ==================================================
# Enable Services
# ==================================================
echo -e "${PURPLE}Enabling services${NC}"

# PipeWire
systemctl --user enable --now pipewire.service 2>/dev/null || true
systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
systemctl --user enable --now wireplumber.service 2>/dev/null || true

# Bluetooth
sudo systemctl enable --now bluetooth.service 2>/dev/null || true

# NetworkManager
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true

# TLP (power management)
sudo systemctl enable --now tlp.service 2>/dev/null || true

echo -e "${GREEN}Services configured${NC}"
echo ""

# ==================================================
# CREATE WAYBAR LAUNCH SCRIPT
# ==================================================
echo -e "${PURPLE}Creating Waybar launch script...${NC}"

mkdir -p "$HOME/.config/waybar"
cat > "$HOME/.config/waybar/launch.sh" << 'EOF'
#!/usr/bin/env bash

# Kill existing waybar instances
killall waybar 2>/dev/null

# Wait for processes to die
sleep 1

# Restart waybar
waybar &
EOF

chmod +x "$HOME/.config/waybar/launch.sh"

echo -e "${GREEN}Waybar launch script created${NC}"
echo ""

# ==================================================
# Reload Hyprland & Start Services
# ==================================================
echo -e "${PURPLE}Starting desktop services...${NC}"

if pgrep -x "Hyprland" > /dev/null; then
  echo -e "${CYAN}Reloading Hyprland config...${NC}"
  hyprctl reload 2>/dev/null || echo -e "${YELLOW}Could not reload Hyprland${NC}"
  
  echo -e "${CYAN}Reloading hyprbars plugin...${NC}"
  hyprpm reload -n 2>/dev/null || true
  
  echo -e "${CYAN}Starting portals...${NC}"
  /usr/lib/xdg-desktop-portal-hyprland &
  sleep 2
  /usr/lib/xdg-desktop-portal &
  disown
  
  echo -e "${CYAN}Initializing wallpaper...${NC}"
  if [[ -f "$HOME/.config/hypr/scripts/swww-init.sh" ]]; then
    "$HOME/.config/hypr/scripts/swww-init.sh" &
    disown
  fi
  
  echo -e "${CYAN}Starting Waybar...${NC}"
  "$HOME/.config/waybar/launch.sh" &
  disown
  
  echo -e "${GREEN}Services started${NC}"
else
  echo -e "${YELLOW}Hyprland not running, services will start on next login${NC}"
fi

echo ""

# ==================================================
# Validation Check
# ==================================================
echo -e "${CYAN}Validating installation...${NC}"
echo ""

VALIDATION_ERRORS=0

# Python checks
echo -n "  GTK4 bindings... "
python -c "import gi; gi.require_version('Gtk', '4.0'); from gi.repository import Gtk" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; ((VALIDATION_ERRORS++)); }

echo -n "  Libadwaita... "
python -c "import gi; gi.require_version('Adw', '1'); from gi.repository import Adw" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; ((VALIDATION_ERRORS++)); }

echo -n "  Cairo... "
python -c "import cairo" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; ((VALIDATION_ERRORS++)); }

echo -n "  Pillow... "
python -c "from PIL import Image" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; ((VALIDATION_ERRORS++)); }

echo -n "  psutil... "
python -c "import psutil" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; ((VALIDATION_ERRORS++)); }

echo -n "  pytz... "
python -c "import pytz" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; ((VALIDATION_ERRORS++)); }

echo ""

# Command checks
echo -e "${CYAN}Essential commands:${NC}"
for cmd in hyprctl hyprpm waybar rofi swaync swww kitty flameshot nwg-displays protonup-qt cpupower tlp; do
  echo -n "  $cmd... "
  command -v "$cmd" &>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}MISSING${NC}"; ((VALIDATION_ERRORS++)); }
done

echo ""

# Plugin check
echo -n "  hyprbars plugin... "
hyprpm list 2>/dev/null | grep -q "hyprbars" && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}WARNING${NC}"

# Waybar check
echo -n "  Waybar running... "
pgrep -x waybar >/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}NOT RUNNING${NC}"

# Wallpaper check
echo -n "  Default wallpaper... "
[[ -n "$DEFAULT_WALLPAPER" && -f "$DEFAULT_WALLPAPER" ]] && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}NOT SET${NC}"

echo ""

# ==================================================
# DONE
# ==================================================
echo ""
echo -e "${PURPLE}========================================${NC}"
if [[ $VALIDATION_ERRORS -eq 0 ]]; then
  echo -e "${GREEN}         INSTALL COMPLETE${NC}"
else
  echo -e "${YELLOW}  INSTALL COMPLETE (with $VALIDATION_ERRORS warnings)${NC}"
fi
echo -e "${PURPLE}========================================${NC}"
echo ""

[[ "$FOUND" == true ]] && {
  echo -e "${CYAN}Backup location:${NC}"
  echo "   $BACKUP_DIR"
  echo ""
}

echo -e "${GREEN}Zen Barebone installed successfully${NC}"
echo ""
echo -e "${CYAN}INSTALLED FEATURES:${NC}"
echo "  - Hyprland with hyprbars plugin"
echo "  - Waybar with fixed desktop portal"
echo "  - Thunar with thumbnails"
echo "  - Flameshot for screenshots"
echo "  - nwg-displays for display management"
echo "  - ProtonUp-Qt for gaming"
echo "  - PipeWire audio system"
echo "  - Power management (cpupower + tlp)"
[[ -n "$DEFAULT_WALLPAPER" ]] && echo "  - Default wallpaper: $(basename "$DEFAULT_WALLPAPER")"
echo "  - Wallpapers in: $HOME/wallpapers"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo "  1. Log out and log back in"
echo "  2. Select Hyprland from your login manager"
echo "  3. Everything should auto-start"
echo ""
echo -e "${CYAN}POWER MANAGEMENT SETUP (OPTIONAL):${NC}"
echo "  Run the Hypr Control Center Power & Battery module to:"
echo "  - Configure CPU governor"
echo "  - Setup passwordless power management"
echo "  - Or manually run: sudo pacman -S cpupower && sudo pacman -S tlp"
echo ""
echo -e "${CYAN}MANUAL CHECKS (if needed):${NC}"
echo "  - Check hyprbars: hyprpm list"
echo "  - Enable hyprbars: hyprpm enable hyprbars"
echo "  - Restart waybar: ~/.config/waybar/launch.sh"
echo "  - Change wallpaper: swww img ~/wallpapers/your-image.jpg"
echo ""

if [[ $VALIDATION_ERRORS -gt 0 ]]; then
  echo -e "${YELLOW}Some checks failed. Try:${NC}"
  echo "   - pip install --break-system-packages --force-reinstall pygobject"
  echo "   - sudo pacman -S --needed python-gobject gtk4 libadwaita"
  echo "   - hyprpm update && hyprpm enable hyprbars"
  echo ""
fi

echo -e "${PURPLE}========================================${NC}"
echo ""
```
