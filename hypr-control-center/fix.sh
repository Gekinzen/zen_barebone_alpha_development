#!/bin/bash
# ONE-COMMAND FIX for Panel "Coming Soon" issue
# Run this from ~/.config/hypr-control-center/

echo "=========================================="
echo "FIXING PANEL IMPORTS - ONE COMMAND FIX"
echo "=========================================="
echo

# Check directory
if [ ! -f "src/window.py" ]; then
    echo "❌ Error: src/window.py not found"
    echo "Please run from ~/.config/hypr-control-center/"
    exit 1
fi

echo "Step 1: Backup window.py..."
cp src/window.py src/window.py.backup
echo "✅ Backup created: src/window.py.backup"
echo

echo "Step 2: Fix imports in window.py..."
# Replace the import line
sed -i 's|from .pages.placeholders import (|from .pages.panel import build_panel_page\nfrom .pages.placeholders import (|' src/window.py

# Remove build_panel_page from placeholders import
sed -i 's|build_panel_page, build_workspaces_page|build_workspaces_page|' src/window.py

echo "✅ Imports fixed!"
echo

echo "Step 3: Clear Python cache..."
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find . -name "*.pyc" -delete 2>/dev/null
echo "✅ Cache cleared!"
echo

echo "Step 4: Verify imports..."
if grep -q "from .pages.panel import build_panel_page" src/window.py; then
    echo "✅ window.py now imports panel correctly!"
else
    echo "⚠️  Auto-fix may not have worked"
    echo "Please check src/window.py manually"
fi
echo

echo "=========================================="
echo "FIX COMPLETE!"
echo "=========================================="
echo
echo "Now restart the app:"
echo "  pkill -f 'python.*main.py'"
echo "  python3 main.py"
echo
echo "Then click 'Panel' - should work now! 🎉"
echo