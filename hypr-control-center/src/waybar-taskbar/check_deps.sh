#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# C++ Waybar Taskbar Module - Dependency Checker & Installer
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     C++ WAYBAR TASKBAR MODULE - Dependency Checker               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

MISSING=()

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✅ $1${NC}"
        return 0
    else
        echo -e "  ${RED}❌ $1${NC}"
        return 1
    fi
}

check_pkg() {
    if pkg-config --exists "$1" 2>/dev/null; then
        version=$(pkg-config --modversion "$1" 2>/dev/null)
        echo -e "  ${GREEN}✅ $1 ($version)${NC}"
        return 0
    else
        echo -e "  ${RED}❌ $1${NC}"
        return 1
    fi
}

check_header() {
    if [ -f "$1" ]; then
        echo -e "  ${GREEN}✅ $2${NC}"
        return 0
    else
        echo -e "  ${RED}❌ $2${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/5] Build Tools${NC}"
check_command g++ || MISSING+=("base-devel")
check_command pkg-config || MISSING+=("pkgconf")
check_command make || MISSING+=("make")

echo ""
echo -e "${YELLOW}[2/5] GTK4 Development${NC}"
check_pkg gtk4 || MISSING+=("gtk4")
check_pkg gdk-pixbuf-2.0 || MISSING+=("gdk-pixbuf2")

echo ""
echo -e "${YELLOW}[3/5] GLib/GIO${NC}"
check_pkg glib-2.0 || MISSING+=("glib2")
check_pkg gio-2.0 || MISSING+=("glib2")
check_pkg gio-unix-2.0 || MISSING+=("glib2")

echo ""
echo -e "${YELLOW}[4/5] JSON Library${NC}"
# Check for nlohmann/json header
if [ -f "/usr/include/nlohmann/json.hpp" ]; then
    echo -e "  ${GREEN}✅ nlohmann-json${NC}"
else
    echo -e "  ${RED}❌ nlohmann-json${NC}"
    MISSING+=("nlohmann-json")
fi

echo ""
echo -e "${YELLOW}[5/5] Waybar${NC}"
check_command waybar || MISSING+=("waybar")
check_command hyprctl || MISSING+=("hyprland")

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════════════"

if [ ${#MISSING[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ ALL DEPENDENCIES INSTALLED!${NC}"
    echo ""
    echo "You're ready to build the C++ taskbar module."
    echo ""
    echo "To compile:"
    echo "  cd ~/.config/waybar/modules/taskbar"
    echo "  make"
    echo ""
else
    echo -e "${RED}❌ MISSING PACKAGES:${NC}"
    echo ""
    
    # Remove duplicates
    UNIQUE_MISSING=($(echo "${MISSING[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    echo "Install on Arch Linux:"
    echo -e "  ${BLUE}sudo pacman -S ${UNIQUE_MISSING[*]}${NC}"
    echo ""
    echo "Or with yay:"
    echo -e "  ${BLUE}yay -S ${UNIQUE_MISSING[*]}${NC}"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════"
echo -e "${YELLOW}QUICK INSTALL (Arch Linux):${NC}"
echo ""
echo "  # All dependencies in one command:"
echo -e "  ${BLUE}sudo pacman -S base-devel gtk4 glib2 gdk-pixbuf2 nlohmann-json${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════"