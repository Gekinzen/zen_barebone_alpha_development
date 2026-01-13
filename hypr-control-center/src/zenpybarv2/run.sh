#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# ZenPyBar v2.0 - Launcher Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script sets up the environment and launches ZenPyBar.
# GTK4 Layer Shell requires LD_PRELOAD to work properly.
#
# Usage:
#   ./run.sh              # Run normally
#   ./run.sh --replace    # Kill existing and run
#   ./run.sh --stop       # Stop running instance
#
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAR_SCRIPT="$SCRIPT_DIR/bar.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              ZenPyBar v2.0 - Waybar Replacement               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_dependencies() {
    local missing=()
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    # Check GTK4 Layer Shell
    if [ ! -f "/usr/lib/libgtk4-layer-shell.so" ]; then
        if [ ! -f "/usr/lib64/libgtk4-layer-shell.so" ]; then
            missing+=("gtk4-layer-shell")
        fi
    fi
    
    # Check Hyprland
    if ! command -v hyprctl &> /dev/null; then
        missing+=("hyprland")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}"
        echo ""
        echo "Install with:"
        echo "  sudo pacman -S python gtk4-layer-shell hyprland"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies found${NC}"
}

find_layer_shell_lib() {
    # Check common paths
    if [ -f "/usr/lib/libgtk4-layer-shell.so" ]; then
        echo "/usr/lib/libgtk4-layer-shell.so"
    elif [ -f "/usr/lib64/libgtk4-layer-shell.so" ]; then
        echo "/usr/lib64/libgtk4-layer-shell.so"
    elif [ -f "/usr/local/lib/libgtk4-layer-shell.so" ]; then
        echo "/usr/local/lib/libgtk4-layer-shell.so"
    else
        # Try to find it
        find /usr -name "libgtk4-layer-shell.so" 2>/dev/null | head -1
    fi
}

stop_existing() {
    if pgrep -f "python.*bar.py" > /dev/null; then
        echo -e "${YELLOW}⏹️  Stopping existing ZenPyBar...${NC}"
        pkill -f "python.*bar.py"
        sleep 0.5
    fi
    
    if pgrep -f "zenpybarv2" > /dev/null; then
        pkill -f "zenpybarv2"
        sleep 0.5
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

print_header

# Parse arguments
case "$1" in
    --stop)
        stop_existing
        echo -e "${GREEN}✅ ZenPyBar stopped${NC}"
        exit 0
        ;;
    --replace)
        stop_existing
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --replace    Kill existing instance and start new"
        echo "  --stop       Stop running instance"
        echo "  --help       Show this help"
        echo ""
        exit 0
        ;;
esac

# Check dependencies
check_dependencies

# Check bar.py exists
if [ ! -f "$BAR_SCRIPT" ]; then
    echo -e "${RED}❌ bar.py not found at: $BAR_SCRIPT${NC}"
    exit 1
fi

# Find GTK4 Layer Shell library
LAYER_SHELL_LIB=$(find_layer_shell_lib)

if [ -z "$LAYER_SHELL_LIB" ]; then
    echo -e "${RED}❌ Could not find libgtk4-layer-shell.so${NC}"
    echo "Install with: sudo pacman -S gtk4-layer-shell"
    exit 1
fi

echo -e "${GREEN}📦 GTK4 Layer Shell: $LAYER_SHELL_LIB${NC}"

# Set environment
export LD_PRELOAD="$LAYER_SHELL_LIB"
export GDK_BACKEND=wayland

# Optional: Set Python path
export PYTHONDONTWRITEBYTECODE=1

echo -e "${BLUE}🚀 Launching ZenPyBar...${NC}"
echo ""

# Run bar.py
cd "$SCRIPT_DIR"
exec python3 "$BAR_SCRIPT" "$@"