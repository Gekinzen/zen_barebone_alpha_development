#!/usr/bin/env bash
set -e

echo "🧹 Uninstalling Hyprland Control Center..."

# Stop & disable service
systemctl --user stop hypr-wallpaper-slideshow.service 2>/dev/null || true
systemctl --user disable hypr-wallpaper-slideshow.service 2>/dev/null || true

# Remove service file
rm -f ~/.config/systemd/user/hypr-wallpaper-slideshow.service
systemctl --user daemon-reload

# Remove configs (ONLY app-specific)
rm -rf ~/.config/hypr-control-center
rm -f ~/.config/hypr/scripts/wallpaper-slideshow.sh

echo "✅ Removed services and configs"
echo "ℹ️ Packages were not auto-removed (safe by design)"
echo "Done."
