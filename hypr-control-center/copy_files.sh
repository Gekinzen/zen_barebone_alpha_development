#!/bin/bash
# Simple file copy - run from Downloads folder

set -e

echo "Copying files to ~/.config/hypr-control-center..."

# Stop app
echo "Stopping app..."
pkill -f "python3.*main.py" 2>/dev/null || true

# Copy files
echo "Copying styles.py..."
cp -v src/styles.py ~/.config/hypr-control-center/src/

echo "Copying window.py..."
cp -v src/window.py ~/.config/hypr-control-center/src/

echo "Copying wallpaper.py..."
cp -v src/pages/wallpaper.py ~/.config/hypr-control-center/src/pages/

echo "Copying panel_helpers.py..."
cp -v src/pages/panel_helpers.py ~/.config/hypr-control-center/src/pages/

echo "Copying panel.py..."
cp -v src/pages/panel.py ~/.config/hypr-control-center/src/pages/

# Clear cache
echo "Clearing cache..."
find ~/.config/hypr-control-center -name "*.pyc" -delete
find ~/.config/hypr-control-center -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

echo ""
echo "✓ Done! Now run:"
echo "  cd ~/.config/hypr-control-center"
echo "  python3 main.py"