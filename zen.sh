#!/usr/bin/env bash

# ===============================
# Zen Dotfiles & Control Panel
# Homepage Script
# ===============================

set -e

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

# ---------- Banner ----------
echo -e "${CYAN}"
cat << "EOF"
███████╗███████╗███╗   ██╗
╚══███╔╝██╔════╝████╗  ██║
  ███╔╝ █████╗  ██╔██╗ ██║
 ███╔╝  ██╔══╝  ██║╚██╗██║
███████╗███████╗██║ ╚████║
╚══════╝╚══════╝╚═╝  ╚═══╝

Zen Dotfiles & Hyprland Control Panel
EOF
echo -e "${NC}"

echo -e "${PURPLE}────────────────────────────────────────${NC}"
echo -e "${GREEN}👋 Welcome, ${USER}!${NC}"
echo -e "${CYAN}A clean Hyprland + Control Center setup${NC}"
echo -e "${PURPLE}────────────────────────────────────────${NC}"
echo ""

# ---------- Menu ----------
echo -e "${BLUE}What would you like to do?${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} Install Zen Dotfiles & Control Panel"
echo -e "  ${YELLOW}2)${NC} Install (Headless / No UI)"
echo -e "  ${RED}3)${NC} Uninstall Zen Control Panel"
echo -e "  ${CYAN}4)${NC} Exit"
echo ""

read -rp "➜ Select an option [1-4]: " CHOICE
echo ""

# ---------- Actions ----------
case "$CHOICE" in
    1)
        echo -e "${GREEN}🚀 Starting full installation...${NC}"
        bash ./install.sh
        ;;
    2)
        echo -e "${YELLOW}🚀 Starting headless installation...${NC}"
        bash ./install.sh --headless
        ;;
    3)
        echo -e "${RED}🧹 Uninstalling Zen Control Panel...${NC}"
        bash ./uninstall.sh
        ;;
    4)
        echo -e "${CYAN}👋 Goodbye, Zen out.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid option.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✨ Done.${NC}"
