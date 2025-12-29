#!/bin/bash
# Nuclear Cache Clear - Forces CSS reload

echo "🔥 NUCLEAR CACHE CLEAR"
echo "======================"
echo

cd ~/.config/hypr-control-center || exit 1

echo "1. Killing app..."
pkill -9 -f "python.*main.py"
sleep 1

echo "2. Clearing Python cache..."
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find . -name "*.pyc" -delete 2>/dev/null
find . -name "*.pyo" -delete 2>/dev/null

echo "3. Clearing GTK cache..."
rm -rf ~/.cache/gtk-4.0/* 2>/dev/null
rm -rf ~/.cache/gnome-shell/* 2>/dev/null

echo "4. Touching CSS file (force reload)..."
touch assets/style.css

echo "5. Verifying CSS colors..."
if grep -q "#abb2bf !important" assets/style.css; then
    echo "   ✅ CSS has white colors with !important"
else
    echo "   ❌ CSS may be old version!"
fi

echo
echo "6. Starting app..."
python3 main.py &

echo
echo "✅ Done! Check Panel page now."
echo "   All text should be WHITE (#abb2bf)"