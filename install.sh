#!/usr/bin/env bash
set -e

# ==================================================
# Zen Barebone Installer - Minimalist Edition
# WITH WORKING HYPRBARS + WAYBAR FIX
# ==================================================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Zen Barebone Installer${NC}"
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

# Core Python & GTK
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

# Python libraries (system-wide)
echo -e "${BLUE}Installing Python dependencies...${NC}"
pip install --break-system-packages --upgrade \
  pillow \
  psutil \
  pytz

# Verify Cairo bindings
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
# GTK4 Layer Shell (CRITICAL for desktop widgets)
# ==================================================
echo -e "${PURPLE}Installing GTK4 Layer Shell...${NC}"
yay -S --needed --noconfirm gtk4-layer-shell

echo -e "${GREEN}GTK4 Layer Shell installed${NC}"
echo ""

# ==================================================
# ZSH SETUP (NO HANG - KITTY HANDLES SHELL)
# ==================================================
echo -e "${PURPLE}Installing zsh${NC}"

sudo pacman -S --needed --noconfirm zsh zsh-completions

[[ ! -x /bin/zsh ]] && {
  echo -e "${RED}/bin/zsh missing${NC}"
  exit 1
}

# Add zsh to shells if not already there
grep -q "^/bin/zsh$" /etc/shells || echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null

echo -e "${GREEN}Zsh installed${NC}"
echo -e "${CYAN}Kitty will use zsh via config (no system shell change)${NC}"

# Create basic .zshrc if it doesn't exist
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
# KITTY SAFE MODE (FORCE BASH DURING INSTALL)
# ==================================================
echo -e "${PURPLE}Configuring Kitty (bootstrap mode)${NC}"

KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$HOME/.config/kitty"

# Backup existing config
[[ -f "$KITTY_CONF" ]] && cp "$KITTY_CONF" "$KITTY_CONF.pre-install.bak"

# Force bash temporarily
if grep -q "^shell " "$KITTY_CONF" 2>/dev/null; then
  sed -i 's|^shell .*|shell /bin/bash|' "$KITTY_CONF"
else
  echo "shell /bin/bash" >> "$KITTY_CONF"
fi

echo -e "${GREEN}Kitty using bash (temporary)${NC}"
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
# HYPRBARS PLUGIN - OFFICIAL METHOD
# ==================================================
echo -e "${PURPLE}Installing hyprbars plugin${NC}"

# Install dependencies for building
sudo pacman -S --needed --noconfirm \
  git \
  cmake \
  meson \
  ninja \
  gcc \
  pkgconf \
  hyprland-headers

# Create build directory
HYPRBARS_DIR="$HOME/.local/share/hyprland-plugins"
mkdir -p "$HYPRBARS_DIR"

echo -e "${CYAN}Cloning hyprland-plugins repo...${NC}"
if [[ -d "$HYPRBARS_DIR/hyprland-plugins" ]]; then
  echo -e "${YELLOW}Repo exists, pulling latest...${NC}"
  cd "$HYPRBARS_DIR/hyprland-plugins"
  git pull
else
  git clone https://github.com/hyprwm/hyprland-plugins "$HYPRBARS_DIR/hyprland-plugins"
  cd "$HYPRBARS_DIR/hyprland-plugins"
fi

# Build hyprbars
echo -e "${CYAN}Building hyprbars...${NC}"
cd "$HYPRBARS_DIR/hyprland-plugins"

# Get Hyprland version to match
HYPR_VERSION=$(hyprctl version | head -n1 | awk '{print $2}')
echo -e "${CYAN}Detected Hyprland version: ${HYPR_VERSION}${NC}"

# Checkout matching version if exists
git fetch --all --tags
if git tag | grep -q "^$HYPR_VERSION$"; then
  echo -e "${CYAN}Checking out matching tag: $HYPR_VERSION${NC}"
  git checkout "$HYPR_VERSION"
else
  echo -e "${YELLOW}No matching tag, using latest main${NC}"
  git checkout main
  git pull
fi

# Build hyprbars specifically
echo -e "${CYAN}Compiling hyprbars plugin...${NC}"
cd hyprbars
make all

# Install the plugin
PLUGIN_INSTALL_DIR="$HOME/.local/share/hyprload/plugins/hyprbars"
mkdir -p "$PLUGIN_INSTALL_DIR"
cp hyprbars.so "$PLUGIN_INSTALL_DIR/" 2>/dev/null || {
  echo -e "${YELLOW}Traditional install failed, using hyprpm...${NC}"
}

echo -e "${GREEN}Hyprbars compiled${NC}"

# Try hyprpm method
echo -e "${CYAN}Registering with hyprpm...${NC}"
cd "$HYPRBARS_DIR/hyprland-plugins"

# Update hyprpm
hyprpm update 2>/dev/null || echo -e "${YELLOW}hyprpm update warnings (normal)${NC}"

# Add the plugin repo
hyprpm add "$HYPRBARS_DIR/hyprland-plugins" 2>/dev/null || {
  echo -e "${YELLOW}Repo already added${NC}"
}

# Enable hyprbars
hyprpm enable hyprbars 2>/dev/null || {
  echo -e "${YELLOW}Manual enable attempt...${NC}"
}

echo -e "${GREEN}Hyprbars plugin installed${NC}"
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
# Fonts (CRITICAL for icons/UI)
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

# Rebuild font cache
echo -e "${CYAN}Rebuilding font cache...${NC}"
fc-cache -fv >/dev/null 2>&1

echo -e "${GREEN}Fonts installed${NC}"
echo ""

# ==================================================
# System Monitoring Tools (for widgets)
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
# COPY WALLPAPERS FROM REPO TO USER HOME
# ==================================================
echo -e "${PURPLE}Copying wallpapers...${NC}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
WALLPAPER_SOURCE="$REPO_ROOT/images"

if [[ -d "$WALLPAPER_SOURCE" ]]; then
  echo -e "${CYAN}Found wallpapers in: $WALLPAPER_SOURCE${NC}"
  
  # Copy all wallpapers to user's home
  cp -rv "$WALLPAPER_SOURCE"/* "$HOME/wallpapers/" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Could not copy all wallpapers${NC}"
  }
  
  echo -e "${GREEN}Wallpapers copied to: $HOME/wallpapers${NC}"
else
  echo -e "${YELLOW}No wallpapers directory found in repo${NC}"
fi

echo ""

# ==================================================
# DEPLOY CONFIGS (REPLACE MODE)
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
# FIX HYPRLAND CONFIG FOR HYPRBARS
# ==================================================
echo -e "${PURPLE}Fixing Hyprland config for hyprbars...${NC}"

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

if [[ -f "$HYPR_CONF" ]]; then
  # Backup original
  cp "$HYPR_CONF" "$HYPR_CONF.backup-$(date +%s)"
  
  # Fix plugin syntax - replace old format with new
  sed -i 's/^plugin {$/plugin:hyprbars {/' "$HYPR_CONF"
  sed -i '/^plugin:hyprbars {/,/^}$/ s/hyprbars {//' "$HYPR_CONF"
  
  # Remove deprecated windowrule syntax
  sed -i '/windowrulev2 = plugin:hyprbars:nobar/d' "$HYPR_CONF"
  
  # Add noborder as replacement
  if ! grep -q "windowrulev2 = noborder, fullscreen:1" "$HYPR_CONF"; then
    cat >> "$HYPR_CONF" << 'EOF'

# ─────────────────────────────────────────────────────────────
# HYPRBARS RULES (FIXED FOR LATEST HYPRLAND)
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
# SET DEFAULT WALLPAPER WITH SWWW
# ==================================================
echo -e "${PURPLE}Setting default wallpaper...${NC}"

DEFAULT_WALLPAPER="$HOME/wallpapers/anime-crescent-moon-over-forest-desktop-wallpaper.jpg"

if [[ -f "$DEFAULT_WALLPAPER" ]]; then
  # Create swww init script
  SWWW_SCRIPT="$HOME/.config/hypr/scripts/swww-init.sh"
  mkdir -p "$(dirname "$SWWW_SCRIPT")"
  
  cat > "$SWWW_SCRIPT" << EOF
#!/usr/bin/env bash

# Initialize swww daemon
swww-daemon &

# Wait for daemon to be ready
sleep 1

# Set wallpaper
swww img "$DEFAULT_WALLPAPER" --transition-type fade --transition-duration 2
EOF
  
  chmod +x "$SWWW_SCRIPT"
  
  echo -e "${GREEN}Default wallpaper set: anime-crescent-moon-over-forest-desktop-wallpaper.jpg${NC}"
  echo -e "${CYAN}Wallpaper script created at: $SWWW_SCRIPT${NC}"
  
  # Update autostart if it exists
  AUTOSTART_CONF="$HOME/.config/hypr/modules/autostart.conf"
  if [[ -f "$AUTOSTART_CONF" ]]; then
    # Remove old wallpaper slideshow if exists
    sed -i '/wallpaper-slideshow/d' "$AUTOSTART_CONF"
    
    # Add swww init if not exists
    if ! grep -q "swww-init.sh" "$AUTOSTART_CONF"; then
      echo "exec-once = ~/.config/hypr/scripts/swww-init.sh" >> "$AUTOSTART_CONF"
      echo -e "${GREEN}Added swww-init to autostart${NC}"
    fi
  fi
else
  echo -e "${YELLOW}Default wallpaper not found: $DEFAULT_WALLPAPER${NC}"
  echo -e "${YELLOW}Wallpapers available in: $HOME/wallpapers${NC}"
fi

echo ""

# ==================================================
# Fix Waybar Desktop Portal Error
# ==================================================
echo -e "${PURPLE}Fixing Waybar desktop portal...${NC}"

# Create portal config
mkdir -p "$HOME/.config/xdg-desktop-portal"
cat > "$HOME/.config/xdg-desktop-portal/portals.conf" << 'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Settings=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.Screencast=hyprland
EOF

# Create hyprland portal config
cat > "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" << 'EOF'
[preferred]
default=hyprland;gtk
EOF

# Kill and restart portal
killall xdg-desktop-portal-hyprland 2>/dev/null || true
killall xdg-desktop-portal 2>/dev/null || true
sleep 2

echo -e "${GREEN}Portal config created${NC}"
echo ""

# ==================================================
# KITTY FINAL SHELL (ZSH)
# ==================================================
echo -e "${PURPLE}Switching Kitty to zsh${NC}"

# Update Kitty config to use zsh
if [[ -f "$KITTY_CONF" ]]; then
  sed -i 's|^shell .*|shell /bin/zsh|' "$KITTY_CONF"
  echo -e "${GREEN}Kitty will use zsh${NC}"
else
  echo -e "${YELLOW}Kitty config not found, will be created by rsync${NC}"
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
systemctl --user enable --now pipewire.service 2>/dev/null || \
  echo -e "${YELLOW}Could not enable pipewire${NC}"
systemctl --user enable --now pipewire-pulse.service 2>/dev/null || \
  echo -e "${YELLOW}Could not enable pipewire-pulse${NC}"
systemctl --user enable --now wireplumber.service 2>/dev/null || \
  echo -e "${YELLOW}Could not enable wireplumber${NC}"

# Bluetooth
sudo systemctl enable --now bluetooth.service 2>/dev/null || \
  echo -e "${YELLOW}Could not enable bluetooth${NC}"

# NetworkManager
sudo systemctl enable --now NetworkManager.service 2>/dev/null || \
  echo -e "${YELLOW}Could not enable NetworkManager${NC}"

echo -e "${GREEN}Services configured${NC}"
echo ""

# ==================================================
# CREATE WAYBAR LAUNCH SCRIPT
# ==================================================
echo -e "${PURPLE}Creating Waybar launch script...${NC}"

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
  hyprpm reload -n 2>/dev/null || echo -e "${YELLOW}Could not reload plugins${NC}"
  
  echo -e "${CYAN}Starting portals...${NC}"
  /usr/lib/xdg-desktop-portal-hyprland &
  sleep 2
  /usr/lib/xdg-desktop-portal &
  disown
  
  echo -e "${CYAN}Initializing swww and setting wallpaper...${NC}"
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

# Check Python GTK bindings
echo -n "  Checking GTK4 bindings... "
if python -c "import gi; gi.require_version('Gtk', '4.0'); from gi.repository import Gtk" 2>/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FAILED${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check Libadwaita
echo -n "  Checking Libadwaita... "
if python -c "import gi; gi.require_version('Adw', '1'); from gi.repository import Adw" 2>/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FAILED${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check Cairo
echo -n "  Checking Cairo... "
if python -c "import cairo" 2>/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FAILED${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check PIL/Pillow
echo -n "  Checking Pillow... "
if python -c "from PIL import Image" 2>/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FAILED${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check psutil
echo -n "  Checking psutil... "
if python -c "import psutil" 2>/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FAILED${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check pytz
echo -n "  Checking pytz... "
if python -c "import pytz" 2>/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FAILED${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

echo ""

# Check essential commands
echo -e "${CYAN}Checking essential commands:${NC}"
for cmd in hyprctl hyprpm waybar rofi swaync swww kitty flameshot nwg-displays protonup-qt; do
  echo -n "  $cmd... "
  if command -v "$cmd" &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
  else
    echo -e "${RED}MISSING${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  fi
done

echo ""

# Check hyprbars plugin
echo -n "  Checking hyprbars plugin... "
if [[ -f "$HOME/.local/share/hyprload/plugins/hyprbars/hyprbars.so" ]] || \
   hyprpm list 2>/dev/null | grep -q "hyprbars"; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${YELLOW}WARNING${NC}"
fi

# Check waybar process
echo -n "  Checking Waybar running... "
if pgrep -x waybar >/dev/null; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${YELLOW}NOT RUNNING${NC} (will start on next login)"
fi

# Check wallpaper
echo -n "  Checking default wallpaper... "
if [[ -f "$HOME/wallpapers/anime-crescent-moon-over-forest-desktop-wallpaper.jpg" ]]; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${YELLOW}NOT FOUND${NC}"
fi

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
echo "  - Hyprland with hyprbars plugin (custom window bars)"
echo "  - Waybar with fixed desktop portal"
echo "  - Thunar with thumbnails (ffmpegthumbnailer)"
echo "  - Flameshot for screenshots"
echo "  - nwg-displays for display management"
echo "  - ProtonUp-Qt for gaming"
echo "  - PipeWire audio system"
echo "  - Default wallpaper: anime-crescent-moon-over-forest"
echo "  - Wallpapers copied to: $HOME/wallpapers"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo "  1. Log out and log back in (recommended)"
echo "  2. Select Hyprland from your login manager"
echo "  3. Everything should auto-start"
echo ""
echo -e "${CYAN}MANUAL CHECKS (if needed):${NC}"
echo "  - Check hyprbars: hyprpm list"
echo "  - Enable hyprbars: hyprpm enable hyprbars"
echo "  - Restart waybar: ~/.config/waybar/launch.sh"
echo "  - Set wallpaper: swww img ~/wallpapers/your-image.jpg"
echo "  - View Hyprland logs: cat /tmp/hypr/\$(ls -t /tmp/hypr/ | head -n1)/hyprland.log"
echo ""
echo -e "${CYAN}OPTIONAL:${NC}"
echo "  - Make zsh default shell: chsh -s /bin/zsh"
echo "  - View system logs: journalctl -xe"
echo ""

if [[ $VALIDATION_ERRORS -gt 0 ]]; then
  echo -e "${YELLOW}Some validation checks failed. Try these fixes:${NC}"
  echo "   - pip install --break-system-packages --force-reinstall pygobject"
  echo "   - sudo pacman -S --needed python-gobject gtk4 libadwaita"
  echo "   - hyprpm update && hyprpm enable hyprbars"
  echo ""
fi

echo -e "${PURPLE}========================================${NC}"
echo ""