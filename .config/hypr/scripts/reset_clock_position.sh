#!/bin/bash
# Reset clock widget position

CONFIG_FILE="$HOME/.config/hypr-control-center/preferences/widgets.json"

echo "🔧 Resetting clock widget position..."

# Kill existing clock
pkill -9 -f clock_widget.py

# Create/update config with safe position
mkdir -p "$(dirname "$CONFIG_FILE")"

cat > "$CONFIG_FILE" << 'EOF'
{
  "widgets": {
    "clock": {
      "x": 100,
      "y": 100,
      "enabled": true
    },
    "weather": {
      "x": 100,
      "y": 350,
      "enabled": true
    },
    "system_monitor": {
      "x": 750,
      "y": 350,
      "enabled": true
    }
  }
}
EOF

echo "✅ Position reset to (100, 100)"
echo ""
echo "🚀 Starting clock..."

cd "$HOME/.config/hypr-control-center/widgets"
LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 clock_widget.py &

sleep 2

echo ""
echo "📍 Current position:"
hyprctl layers | grep -A 2 "hypr-widget-clock"