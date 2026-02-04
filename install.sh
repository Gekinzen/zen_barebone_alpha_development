#!/usr/bin/env bash
set -e

# ==================================================
# Zen Barebone Installer
# SAFE BOOTSTRAP + REPLACE MODE
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
  arch|endeavouros|cachyos) ;;
  *)
    echo -e "${RED}❌ Unsupported distro: $ID${NC}"
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
sudo pacman -S --needed --noconfirm git base-devel curl rsync

# ==================================================
# yay
# ==================================================
if ! command -v yay &>/dev/null; then
  echo -e "${BLUE}📦 Installing yay...${NC}"
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
fi

# ==================================================
# KITTY SAFE MODE (FORCE BASH)
# ==================================================
echo -e "${PURPLE}🐱 Kitty bootstrap mode (bash)${NC}"

KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$HOME/.config/kitty"

[[ -f "$KITTY_CONF" ]] && cp "$KITTY_CONF" "$KITTY_CONF.pre-zsh.bak"

if grep -q "^shell " "$KITTY_CONF" 2>/dev/null; then
  sed -i 's|^shell .*|shell /bin/bash|' "$KITTY_CONF"
else
  echo "shell /bin/bash" >> "$KITTY_CONF"
fi

echo -e "${GREEN}✓ Kitty forced to bash${NC}"
echo ""

# ==================================================
# ZSH SETUP
# ==================================================
echo -e "${PURPLE}🐚 Installing & configuring zsh${NC}"

sudo pacman -S --needed --noconfirm zsh

[[ ! -x /bin/zsh ]] && {
  echo -e "${RED}❌ /bin/zsh missing${NC}"
  exit 1
}

grep -q "^/bin/zsh$" /etc/shells || echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null
chsh -s /bin/zsh "$USER" || true

echo -e "${GREEN}✓ Zsh ready${NC}"
echo ""

# ==================================================
# Desktop Packages (includes Thunar)
# ==================================================
echo -e "${PURPLE}📦 Installing desktop packages${NC}"
yay -S --needed --noconfirm \
  hyprland xdg-desktop-portal-hyprland \
  swww waybar swaync rofi wofi kitty thunar \
  grim slurp wl-clipboard cliphist \
  nwg-look adw-gtk-theme \
  ttf-jetbrains-mono-nerd \
  ttf-geist-mono-nerd \
  noto-fonts-emoji

# ==================================================
# Python / GTK deps
# ==================================================
echo -e "${PURPLE}📦 Installing Python + GTK deps${NC}"
sudo pacman -S --needed --noconfirm \
  python python-pip python-gobject gtk4 libadwaita python-pytz

pip install --break-system-packages pillow psutil

# ==================================================
# DEPLOY CONFIGS (REPLACE MODE)
# ==================================================
echo -e "${CYAN}📂 Applying configs from repo${NC}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SOURCE="$REPO_ROOT/.config"

[[ ! -d "$CONFIG_SOURCE" ]] && {
  echo -e "${RED}❌ Repo .config not found${NC}"
  exit 1
}

mkdir -p "$HOME/.config"

for dir in "$CONFIG_SOURCE"/*; do
  name="$(basename "$dir")"
  echo -e "${BLUE}→ Installing:${NC} $name"
  rsync -av --delete "$dir/" "$HOME/.config/$name/"
done

echo -e "${GREEN}✅ Configs applied${NC}"
echo ""

# ==================================================
# KITTY FINAL SHELL (ZSH)
# ==================================================
echo -e "${PURPLE}🐱 Switching Kitty to zsh${NC}"
sed -i 's|^shell .*|shell /bin/zsh|' "$KITTY_CONF"
echo -e "${GREEN}✓ Kitty now uses zsh${NC}"
echo ""

# ==================================================
# Directories
# ==================================================
mkdir -p \
  "$HOME/wallpapers" \
  "$HOME/.local/bin" \
  "$HOME/.config/hypr/scripts" \
  "$HOME/.config/systemd/user"

# ==================================================
# Ownership Fix
# ==================================================
[[ "$(stat -c '%U' "$HOME/.config")" != "$USER" ]] && \
  sudo chown -R "$USER:$USER" "$HOME/.config"

# ==================================================
# DONE
# ==================================================
echo ""
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo -e "${PURPLE} INSTALL COMPLETE${NC}"
echo -e "${PURPLE}════════════════════════════════════${NC}"
echo ""

[[ "$FOUND" == true ]] && echo -e "${CYAN}📦 Backup:${NC} $BACKUP_DIR"

echo -e "${GREEN}🎉 Zen Barebone installed safely.${NC}"
echo ""
echo "IMPORTANT:"
echo "  • Reboot (shell switch needs it)"
echo "  • Kitty will now launch correctly"
echo ""
