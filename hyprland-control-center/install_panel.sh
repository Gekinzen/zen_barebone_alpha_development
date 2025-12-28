#!/bin/bash
# Automatic copy script for Panel module updates

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}=========================================="
echo "PANEL MODULE - AUTOMATIC UPDATE"
echo -e "==========================================${NC}"
echo

# Check if we're in the right place
if [ ! -f "main.py" ]; then
    echo -e "${RED}❌ Error: Not in hyprland-control-center directory${NC}"
    echo "This script should be run from the downloaded outputs folder"
    exit 1
fi

echo -e "${YELLOW}This will copy Panel module files to:${NC}"
echo "  ~/.config/hypr-control-center/"
echo
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Target directory
TARGET="$HOME/.config/hypr-control-center"

echo
echo -e "${CYAN}Step 1: Creating backup...${NC}"
if [ -d "$TARGET/src" ]; then
    BACKUP_DIR="$TARGET/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$TARGET/src" "$BACKUP_DIR/" 2>/dev/null
    echo -e "${GREEN}✓${NC} Backup created: $BACKUP_DIR"
else
    echo -e "${YELLOW}⚠${NC} No existing files to backup"
fi

echo
echo -e "${CYAN}Step 2: Copying Panel module files...${NC}"

# Create directories
mkdir -p "$TARGET/src/pages"

# Copy files
FILES=(
    "src/waybar_manager.py"
    "src/waybar_style_manager.py"
    "src/pages/panel.py"
    "src/pages/panel_helpers.py"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$TARGET/$file"
        echo -e "${GREEN}✓${NC} Copied: $file"
    else
        echo -e "${RED}✗${NC} Missing: $file"
    fi
done

echo
echo -e "${CYAN}Step 3: Clearing Python cache...${NC}"
cd "$TARGET"
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find . -name "*.pyc" -delete 2>/dev/null
echo -e "${GREEN}✓${NC} Cache cleared"

echo
echo -e "${CYAN}Step 4: Verifying installation...${NC}"
cd "$TARGET"

# Quick verification
if grep -q "available_modules = \[m for m in all_modules if m not in used_modules\]" src/pages/panel.py; then
    echo -e "${GREEN}✓${NC} Add module dialog: OK"
else
    echo -e "${RED}✗${NC} Add module dialog: MISSING"
fi

if grep -q "_refresh_panel_page" src/pages/panel.py; then
    echo -e "${GREEN}✓${NC} Page refresh: OK"
else
    echo -e "${RED}✗${NC} Page refresh: MISSING"
fi

if grep -q "config.jsonc" src/waybar_manager.py; then
    echo -e "${GREEN}✓${NC} Config.jsonc: OK"
else
    echo -e "${YELLOW}⚠${NC} Still using config.json"
fi

if [ -f "src/waybar_style_manager.py" ]; then
    echo -e "${GREEN}✓${NC} Style manager: OK"
else
    echo -e "${RED}✗${NC} Style manager: MISSING"
fi

echo
echo -e "${GREEN}=========================================="
echo "✓ INSTALLATION COMPLETE!"
echo -e "==========================================${NC}"
echo
echo "Next steps:"
echo "1. Close any running instances:"
echo -e "   ${YELLOW}pkill -f 'python.*main.py'${NC}"
echo
echo "2. Run the app:"
echo -e "   ${YELLOW}cd ~/.config/hypr-control-center${NC}"
echo -e "   ${YELLOW}python3 main.py${NC}"
echo
echo "3. Go to Panel page and test:"
echo "   - Position dropdown should only show: top, bottom"
echo "   - Click [+] button should show available modules"
echo "   - Remove module then add should work"
echo