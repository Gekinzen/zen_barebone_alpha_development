#!/bin/bash
# ULTIMATE FIX SCRIPT - No more bullshit!

echo "🔥 ULTIMATE FIX - HYPRLAND CONTROL CENTER 🔥"
echo ""

CONFIG_DIR="$HOME/.config/hypr-control-center"
HYPR_DIR="$HOME/.config/hypr"

# ============================================================
# FIX 1: FORCE WHITE ICONS IN WINDOW.PY
# ============================================================
echo "🔧 FIX 1: Forcing white icons..."

WINDOW_FILE="$CONFIG_DIR/src/window.py"
TEMP_FILE=$(mktemp)

# Find all icon.set_pixel_size lines and add CSS classes if missing
python3 << 'PYEOF' > "$TEMP_FILE"
import sys
with open(sys.argv[1], 'r') as f:
    lines = f.readlines()

output = []
i = 0
while i < len(lines):
    line = lines[i]
    output.append(line)
    
    # If we see set_pixel_size
    if 'icon.set_pixel_size(18)' in line and 'icon =' in lines[i-1]:
        # Get indentation
        indent = ' ' * (len(line) - len(line.lstrip()))
        
        # Check if next lines already have the classes
        next_two = ''.join(lines[i+1:i+3])
        
        if "add_css_class('sidebar-icon')" not in next_two:
            output.append(f"{indent}icon.add_css_class('sidebar-icon')\n")
            print(f"Added sidebar-icon at line {i+1}")
        
        if "add_css_class('force-white')" not in next_two:
            output.append(f"{indent}icon.add_css_class('force-white')\n")
            print(f"Added force-white at line {i+1}")
    
    i += 1

with open(sys.argv[1], 'w') as f:
    f.writelines(output)
PYEOF

python3 - "$WINDOW_FILE" < /dev/stdin

echo "✅ window.py fixed!"

# ============================================================
# FIX 2: CHECK IF STYLES.PY HAS WHITE ICON CSS
# ============================================================
echo ""
echo "🔧 FIX 2: Checking styles.py..."

if grep -q ".force-white" "$CONFIG_DIR/src/styles.py"; then
    echo "✅ styles.py has white icon CSS"
else
    echo "❌ styles.py MISSING white icon CSS!"
    echo "📥 You MUST copy styles_FINAL.py!"
    exit 1
fi

# ============================================================
# FIX 3: INSTALL SLIDESHOW DAEMON
# ============================================================
echo ""
echo "🔧 FIX 3: Installing slideshow daemon..."

SCRIPT_DIR="$HYPR_DIR/scripts"
DAEMON_SCRIPT="$SCRIPT_DIR/wallpaper-slideshow.sh"

mkdir -p "$SCRIPT_DIR"

# Create the daemon script
cat > "$DAEMON_SCRIPT" << 'DAEMON_EOF'
#!/bin/bash
# Wallpaper Slideshow Daemon

CONFIG_FILE="$HOME/.config/hypr-control-center/preferences/wallpaper.json"

# Function to read JSON (requires jq)
read_json() {
    if ! command -v jq &> /dev/null; then
        echo "jq not installed, installing..."
        sudo pacman -S --noconfirm jq
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found: $CONFIG_FILE"
        exit 0
    fi
    
    ENABLED=$(jq -r '.slideshow_enabled // false' "$CONFIG_FILE")
    
    if [ "$ENABLED" != "true" ]; then
        echo "Slideshow disabled"
        exit 0
    fi
    
    echo "Slideshow enabled!"
}

# Function to apply random wallpaper
apply_wallpaper() {
    FOLDER=$(jq -r '.folder // "~/wallpapers"' "$CONFIG_FILE")
    FOLDER="${FOLDER/#\~/$HOME}"
    
    TRANSITION=$(jq -r '.transition // "fade"' "$CONFIG_FILE")
    RANDOM_TRANS=$(jq -r '.random_transition // false' "$CONFIG_FILE")
    
    # Get random wallpaper
    WALLPAPER=$(find "$FOLDER" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)
    
    if [ -z "$WALLPAPER" ]; then
        echo "No wallpapers found in $FOLDER"
        return
    fi
    
    # Pick transition
    if [ "$RANDOM_TRANS" = "true" ] || [ "$TRANSITION" = "random" ]; then
        TRANSITIONS=("fade" "wipe" "grow" "outer" "wave")
        TRANSITION="${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}"
    fi
    
    echo "Applying: $WALLPAPER ($TRANSITION)"
    swww img "$WALLPAPER" --transition-type "$TRANSITION"
}

# Main loop
main() {
    # Start swww if not running
    if ! pgrep -x "swww-daemon" > /dev/null; then
        swww-daemon &
        sleep 2
    fi
    
    read_json
    
    while true; do
        # Check if still enabled
        ENABLED=$(jq -r '.slideshow_enabled // false' "$CONFIG_FILE" 2>/dev/null)
        if [ "$ENABLED" != "true" ]; then
            echo "Slideshow disabled, exiting"
            exit 0
        fi
        
        # Apply wallpaper
        apply_wallpaper
        
        # Get interval
        INTERVAL=$(jq -r '.slideshow_interval // 60' "$CONFIG_FILE" 2>/dev/null)
        sleep "$INTERVAL"
    done
}

main
DAEMON_EOF

chmod +x "$DAEMON_SCRIPT"
echo "✅ Daemon script created: $DAEMON_SCRIPT"

# Add to hyprland.conf if not already there
if ! grep -q "wallpaper-slideshow.sh" "$HYPR_DIR/hyprland.conf" 2>/dev/null; then
    echo "exec-once = $DAEMON_SCRIPT" >> "$HYPR_DIR/hyprland.conf"
    echo "✅ Added to hyprland.conf"
else
    echo "✅ Already in hyprland.conf"
fi

# ============================================================
# FIX 4: START DAEMON NOW IF ENABLED
# ============================================================
echo ""
echo "🔧 FIX 4: Starting daemon if enabled..."

if [ -f "$CONFIG_DIR/preferences/wallpaper.json" ]; then
    ENABLED=$(jq -r '.slideshow_enabled // false' "$CONFIG_DIR/preferences/wallpaper.json")
    
    if [ "$ENABLED" = "true" ]; then
        echo "Slideshow is enabled, starting daemon..."
        pkill -f "wallpaper-slideshow.sh"
        "$DAEMON_SCRIPT" &
        echo "✅ Daemon started!"
    else
        echo "Slideshow disabled in config"
    fi
fi

# ============================================================
# FIX 5: CLEAR ALL CACHE
# ============================================================
echo ""
echo "🔧 FIX 5: Clearing all Python cache..."

find "$CONFIG_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find "$CONFIG_DIR" -type f -name "*.pyc" -delete 2>/dev/null
echo "✅ Cache cleared!"

# ============================================================
# DONE
# ============================================================
echo ""
echo "============================================================"
echo "✅ ALL FIXES APPLIED!"
echo "============================================================"
echo ""
echo "NOW RUN:"
echo "  cd ~/.config/hypr-control-center"
echo "  python3 main.py"
echo ""
echo "If icons still colored, you MUST install styles_FINAL.py:"
echo "  cp ~/Downloads/styles_FINAL.py ~/.config/hypr-control-center/src/styles.py"
echo ""