#!/bin/bash
# Initialize default preferences

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📁 Setting up preferences...${NC}"

PREFS_DIR="$HOME/.config/hypr-control-center/preferences"

# Create preferences directory
mkdir -p "$PREFS_DIR"

# Check if files already exist
if [ -f "$PREFS_DIR/theme.json" ]; then
    echo -e "${GREEN}✓ Preferences already exist, skipping...${NC}"
    exit 0
fi

# Copy default preferences
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}  → Creating theme.json${NC}"
cat > "$PREFS_DIR/theme.json" << 'EOF'
{
  "current_theme": "one-dark",
  "theme_source": "custom"
}
EOF

echo -e "${BLUE}  → Creating wallpaper.json${NC}"
cat > "$PREFS_DIR/wallpaper.json" << EOF
{
  "folder": "$HOME/wallpapers",
  "current": null,
  "transition": "fade"
}
EOF

echo -e "${BLUE}  → Creating power.json${NC}"
cat > "$PREFS_DIR/power.json" << 'EOF'
{
  "profile": "neutral",
  "auto": false
}
EOF

echo -e "${BLUE}  → Creating notifications.json${NC}"
cat > "$PREFS_DIR/notifications.json" << 'EOF'
{
  "positionX": "right",
  "positionY": "top",
  "display": "all"
}
EOF

echo -e "${BLUE}  → Creating displays.json${NC}"
cat > "$PREFS_DIR/displays.json" << 'EOF'
{
  "primary": null,
  "monitors": {}
}
EOF

echo -e "${GREEN}✓ Default preferences created!${NC}"
echo
echo "Location: $PREFS_DIR"
echo
echo "Files created:"
echo "  - theme.json"
echo "  - wallpaper.json"
echo "  - power.json"
echo "  - notifications.json"
echo "  - displays.json"