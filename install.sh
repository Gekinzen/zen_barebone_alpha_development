#!/usr/bin/env bash
set -e

# ==================================================
# Zen Barebone Installer
# SAFE BOOTSTRAP + REPLACE MODE + DEPENDENCY VALIDATOR
# ==================================================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Zen Barebone Installer${NC}"
echo "======================================"
echo ""

# ==================================================
# Detect OS (Arch-based only)
# ==================================================
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo -e "${RED}❌ Cannot detect OS${NC}"
  exit 1
fi

case "$ID" in
  arch|endeavouros|cachyos|manjaro) ;;
  *)
    echo -e "${RED}❌ Unsupported distro: $ID${NC}"
    echo "This installer is for Arch-based distributions only."
    exit 1
    ;;
esac

echo -e "${GREEN}✅ Detected distro: $NAME${NC}"
echo ""

# ==================================================
# SMART BACKUP
# ==================================================
BACKUP_ROOT="$HOME/.config/zen-backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

CONFIG_TARGETS=(hypr waybar kitty swaync rofi zen)

echo -e "${CYAN}🧠 Checking existing configs...${NC}"

FOUND=false
for cfg in "${CONFIG_TARGETS[@]}"; do
  [[ -d "$HOME/.config/$cfg" ]] && FOUND=true
done

if [[ "$FOUND" == true ]]; then
  echo -e "${YELLOW}⚠️ Existing configs found — backing up${NC}"
  mkdir -p "$BACKUP_DIR"

  for cfg in "${CONFIG_TARGETS[@]}"; do
    [[ -d "$HOME/.config/$cfg" ]] && cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/"
  done

  [[ -d "$HOME/.cache/waybar" ]] && {
    mkdir -p "$BACKUP_DIR/.cache"
    cp -a "$HOME/.cache/waybar" "$BACKUP_DIR/.cache/"
  }

  echo -e "${GREEN}✅ Backup saved to:${NC} $BACKUP_DIR"
  echo ""
else
  echo -e "${GREEN}✓ No existing configs detected${NC}"
fi

# ==================================================
# Base Dependencies
# ==================================================
echo -e "${BLUE}📦 Installing base dependencies...${NC}"
sudo pacman -S --needed --noconfirm git base-devel curl rsync wget

# ==================================================
# yay (AUR Helper)
# ==================================================
if ! command -v yay &>/dev/null; then
  echo -e "${BLUE}📦 Installing yay...${NC}"
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
  echo -e "${GREEN}✅ yay installed${NC}"
else
  echo -e "${GREEN}✓ yay already installed${NC}"
fi

echo ""

# ==================================================
# CRITICAL: Python + GTK4 + GObject Introspection
# ==================================================
echo -e "${PURPLE}🐍 Installing Python + GTK4 stack${NC}"

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
echo -e "${BLUE}📦 Installing Python dependencies...${NC}"
pip install --break-system-packages --upgrade \
  pillow \
  psutil \
  pytz

# Verify Cairo bindings
echo -e "${CYAN}🔍 Verifying Cairo bindings...${NC}"
if python -c "import cairo" 2>/dev/null; then
  echo -e "${GREEN}✓ Cairo bindings working${NC}"
else
  echo -e "${YELLOW}⚠️ Cairo bindings issue, installing from pip...${NC}"
  pip install --break-system-packages pycairo
fi

echo -e "${GREEN}✅ Python stack complete${NC}"
echo ""

# ==================================================
# GTK4 Layer Shell (CRITICAL for desktop widgets)
# ==================================================
echo -e "${PURPLE}🪟 Installing GTK4 Layer Shell...${NC}"
yay -S --needed --noconfirm gtk4-layer-shell

echo -e "${GREEN}✅ GTK4 Layer Shell installed${NC}"
echo ""

# ==================================================
# ZSH SETUP (NO HANG - KITTY HANDLES SHELL)
# ==================================================
echo -e "${PURPLE}🐚 Installing zsh${NC}"

sudo pacman -S --needed --noconfirm zsh zsh-completions

[[ ! -x /bin/zsh ]] && {
  echo -e "${RED}❌ /bin/zsh missing${NC}"
  exit 1
}

# Add zsh to shells if not already there
grep -q "^/bin/zsh$" /etc/shells || echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null

echo -e "${GREEN}✓ Zsh installed${NC}"
echo -e "${CYAN}ℹ️ Kitty will use zsh via config (no system shell change)${NC}"

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
  echo -e "${GREEN}✓ Created basic .zshrc${NC}"
fi

echo ""

# ==================================================
# KITTY SAFE MODE (FORCE BASH DURING INSTALL)
# ==================================================
echo -e "${PURPLE}🐱 Configuring Kitty (bootstrap mode)${NC}"

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

echo -e "${GREEN}✓ Kitty using bash (temporary)${NC}"
echo ""

# ==================================================
# Hyprland + Wayland Ecosystem
# ==================================================
echo -e "${PURPLE}🪟 Installing Hyprland ecosystem${NC}"

yay -S --needed --noconfirm \
  hyprland \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  qt5-wayland \
  qt6-wayland \
  polkit-kde-agent

echo -e "${GREEN}✅ Hyprland core installed${NC}"
echo ""

# ==================================================
# Desktop Utilities & Tools
# ==================================================
echo -e "${PURPLE}🛠️ Installing desktop tools${NC}"

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
  gvfs \
  gvfs-mtp \
  file-roller \
  grim \
  slurp \
  wl-clipboard \
  cliphist \
  hyprpicker \
  brightnessctl \
  playerctl \
  pamixer \
  bluez \
  bluez-utils \
  blueman \
  networkmanager \
  network-manager-applet

echo -e "${GREEN}✅ Desktop utilities installed${NC}"
echo ""

# ==================================================
# Theming & Appearance
# ==================================================
echo -e "${PURPLE}🎨 Installing theme tools${NC}"

yay -S --needed --noconfirm \
  nwg-look \
  adw-gtk-theme \
  papirus-icon-theme \
  xcursor-breeze

echo -e "${GREEN}✅ Theme tools installed${NC}"
echo ""

# ==================================================
# Fonts (CRITICAL for icons/UI)
# ==================================================
echo -e "${PURPLE}🔤 Installing fonts${NC}"

yay -S --needed --noconfirm \
  ttf-jetbrains-mono-nerd \
  ttf-geist-mono-nerd \
  ttf-fira-code \
  ttf-font-awesome \
  noto-fonts \
  noto-fonts-emoji \
  noto-fonts-cjk

# Rebuild font cache
echo -e "${CYAN}🔄 Rebuilding font cache...${NC}"
fc-cache -fv >/dev/null 2>&1

echo -e "${GREEN}✅ Fonts installed${NC}"
echo ""

# ==================================================
# System Monitoring Tools (for widgets)
# ==================================================
echo -e "${PURPLE}📊 Installing system monitoring tools${NC}"

sudo pacman -S --needed --noconfirm \
  btop \
  htop \
  lm_sensors \
  acpi \
  upower

echo -e "${GREEN}✅ System tools installed${NC}"
echo ""

# ==================================================
# DEPLOY CONFIGS (REPLACE MODE)
# ==================================================
echo -e "${CYAN}📂 Applying configs from repo${NC}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SOURCE="$REPO_ROOT/.config"

[[ ! -d "$CONFIG_SOURCE" ]] && {
  echo -e "${RED}❌ Repo .config not found at: $CONFIG_SOURCE${NC}"
  exit 1
}

mkdir -p "$HOME/.config"

for dir in "$CONFIG_SOURCE"/*; do
  [[ ! -d "$dir" ]] && continue
  name="$(basename "$dir")"
  echo -e "${BLUE}→ Installing:${NC} $name"
  rsync -av --delete "$dir/" "$HOME/.config/$name/" 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Warning: Could not fully sync $name${NC}"
  }
done

echo -e "${GREEN}✅ Configs applied${NC}"
echo ""

# ==================================================
# Create Essential Directories
# ==================================================
echo -e "${BLUE}📁 Creating directories...${NC}"

mkdir -p \
  "$HOME/wallpapers" \
  "$HOME/.local/bin" \
  "$HOME/.local/share/applications" \
  "$HOME/.config/hypr/scripts" \
  "$HOME/.config/systemd/user" \
  "$HOME/.cache/waybar"

echo -e "${GREEN}✅ Directories created${NC}"
echo ""

# ==================================================
# KITTY FINAL SHELL (ZSH)
# ==================================================
echo -e "${PURPLE}🐱 Switching Kitty to zsh${NC}"

# Update Kitty config to use zsh
if [[ -f "$KITTY_CONF" ]]; then
  sed -i 's|^shell .*|shell /bin/zsh|' "$KITTY_CONF"
  echo -e "${GREEN}✓ Kitty will use zsh${NC}"
else
  echo -e "${YELLOW}⚠️ Kitty config not found, will be created by rsync${NC}"
fi

echo ""

# ==================================================
# Ownership Fix
# ==================================================
echo -e "${BLUE}🔒 Fixing permissions...${NC}"

[[ "$(stat -c '%U' "$HOME/.config" 2>/dev/null)" != "$USER" ]] && \
  sudo chown -R "$USER:$USER" "$HOME/.config"
[[ -d "$HOME/.local" ]] && sudo chown -R "$USER:$USER" "$HOME/.local"

echo -e "${GREEN}✅ Permissions fixed${NC}"
echo ""

# ==================================================
# Enable Services
# ==================================================
echo -e "${PURPLE}🔧 Enabling services${NC}"

# Bluetooth
sudo systemctl enable --now bluetooth.service 2>/dev/null || \
  echo -e "${YELLOW}⚠️ Could not enable bluetooth${NC}"

# NetworkManager
sudo systemctl enable --now NetworkManager.service 2>/dev/null || \
  echo -e "${YELLOW}⚠️ Could not enable NetworkManager${NC}"

echo -e "${GREEN}✅ Services configured${NC}"
echo ""

# ==================================================
# Validation Check
# ==================================================
echo -e "${CYAN}🔍 Validating installation...${NC}"
echo ""

VALIDATION_ERRORS=0

# Check Python GTK bindings
echo -n "  Checking GTK4 bindings... "
if python -c "import gi; gi.require_version('Gtk', '4.0'); from gi.repository import Gtk" 2>/dev/null; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check Libadwaita
echo -n "  Checking Libadwaita... "
if python -c "import gi; gi.require_version('Adw', '1'); from gi.repository import Adw" 2>/dev/null; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check Cairo
echo -n "  Checking Cairo... "
if python -c "import cairo" 2>/dev/null; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check PIL/Pillow
echo -n "  Checking Pillow... "
if python -c "from PIL import Image" 2>/dev/null; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check psutil
echo -n "  Checking psutil... "
if python -c "import psutil" 2>/dev/null; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check pytz
echo -n "  Checking pytz... "
if python -c "import pytz" 2>/dev/null; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

echo ""

# Check essential commands
echo -e "${CYAN}Checking essential commands:${NC}"
for cmd in hyprctl waybar rofi swaync swww kitty; do
  echo -n "  $cmd... "
  if command -v "$cmd" &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  fi
done

echo ""

# ==================================================
# DONE
# ==================================================
echo ""
echo -e "${PURPLE}════════════════════════════════════${NC}"
if [[ $VALIDATION_ERRORS -eq 0 ]]; then
  echo -e "${GREEN}      ✅ INSTALL COMPLETE${NC}"
else
  echo -e "${YELLOW}   ⚠️ INSTALL COMPLETE (with $VALIDATION_ERRORS warnings)${NC}"
fi
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""

[[ "$FOUND" == true ]] && {
  echo -e "${CYAN}📦 Backup location:${NC}"
  echo "   $BACKUP_DIR"
  echo ""
}

echo -e "${GREEN}🎉 Zen Barebone installed successfully!${NC}"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo "  1. ${YELLOW}Reboot your system${NC} (recommended but not required)"
echo "  2. Log out and select Hyprland from your login manager"
echo "  3. Launch Hyprland and enjoy!"
echo ""
echo -e "${CYAN}OPTIONAL:${NC}"
echo "  • To make zsh your default system shell: ${YELLOW}chsh -s /bin/zsh${NC}"
echo "  • View system logs: ${YELLOW}journalctl -xe${NC}"
echo ""

if [[ $VALIDATION_ERRORS -gt 0 ]]; then
  echo -e "${YELLOW}⚠️ Some validation checks failed. Please review above.${NC}"
  echo -e "${YELLOW}   If you encounter issues, try:${NC}"
  echo "   • ${CYAN}pip install --break-system-packages --force-reinstall pygobject${NC}"
  echo "   • ${CYAN}sudo pacman -S --needed python-gobject gtk4 libadwaita${NC}"
  echo ""
fi

echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""