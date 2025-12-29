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

# Check if we're in the outputs folder or the actual project folder
if [ -f "main.py" ] && [ -d "src" ]; then
    SOURCE_DIR="."
    echo -e "${GREEN}✓${NC} Found source files in current directory"
elif [ -d "hyprland-control-center" ] && [ -f "hyprland-control-center/main.py" ]; then
    SOURCE_DIR="hyprland-control-center"
    echo -e "${GREEN}✓${NC} Found source files in hyprland-control-center/"
else
    echo -e "${RED}❌ Error: Cannot find source files${NC}"
    echo "This script should be run from either:"
    echo "  - The hyprland-control-center folder (with main.py)"
    echo "  - The parent folder containing hyprland-control-center/"
    exit 1
fi

# Target directory
TARGET="$HOME/.config/hypr-control-center"

echo -e "${YELLOW}This will copy Panel module files from:${NC}"
echo "  $SOURCE_DIR"
echo -e "${YELLOW}To:${NC}"
echo "  $TARGET"
echo
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo -e "${CYAN}Step 1: Creating backup...${NC}"
if [ -d "$TARGET/src" ]; then
    BACKUP_DIR="$TARGET/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$TARGET/src" "$BACKUP_DIR/" 2>/dev/null
    cp -r "$TARGET/assets" "$BACKUP_DIR/" 2>/dev/null
    echo -e "${GREEN}✓${NC} Backup created: $BACKUP_DIR"
else
    echo -e "${YELLOW}⚠${NC} No existing files to backup"
fi

echo
echo -e "${CYAN}Step 2: Copying Panel module files...${NC}"

# Create directories
mkdir -p "$TARGET/src/pages"
mkdir -p "$TARGET/assets"

# Copy files with updated list
FILES=(
    "src/waybar_manager.py"
    "src/waybar_style_manager.py"
    "src/pages/panel.py"
    "src/pages/panel_helpers.py"
    "assets/style.css"
    "assets/waybar/default-style.css"
)

for file in "${FILES[@]}"; do
    SOURCE_FILE="$SOURCE_DIR/$file"
    if [ -f "$SOURCE_FILE" ]; then
        # Create parent directory if needed
        mkdir -p "$TARGET/$(dirname $file)"
        cp "$SOURCE_FILE" "$TARGET/$file"
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
CHECKS_PASSED=0
CHECKS_TOTAL=6

if grep -q "available_modules = \[m for m in all_modules if m not in used_modules\]" src/pages/panel.py 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Add module dialog: OK"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Add module dialog: MISSING"
fi

if grep -q "_refresh_panel_page" src/pages/panel.py 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Page refresh: OK"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Page refresh: MISSING"
fi

if grep -q "config.jsonc" src/waybar_manager.py 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Config.jsonc: OK"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Still using config.json"
fi

if [ -f "src/waybar_style_manager.py" ]; then
    echo -e "${GREEN}✓${NC} Style manager: OK"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Style manager: MISSING"
fi

if grep -q "module-chip-icon" assets/style.css 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Updated CSS styling: OK"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} CSS may be outdated"
fi

if grep -q "border-radius:46px" assets/waybar/default-style.css 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Waybar default style: OK"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Waybar style may be outdated"
fi

echo
if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
    echo -e "${GREEN}=========================================="
    echo "✓ INSTALLATION COMPLETE! ($CHECKS_PASSED/$CHECKS_TOTAL checks passed)"
    echo -e "==========================================${NC}"
else
    echo -e "${YELLOW}=========================================="
    echo "⚠ INSTALLATION DONE WITH WARNINGS ($CHECKS_PASSED/$CHECKS_TOTAL checks passed)"
    echo -e "==========================================${NC}"
fi

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
echo "   - Position dropdown: top, bottom only"
echo "   - Module zones: grey titles and icons"
echo "   - Click [+] to add modules"
echo "   - Click [×] to remove modules"
echo "   - Opacity, border-radius controls work"
echo