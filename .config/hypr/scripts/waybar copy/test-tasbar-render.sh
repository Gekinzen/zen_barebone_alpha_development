#!/usr/bin/env bash
# Quick test to see taskbar output

echo "Testing taskbar-render.sh output:"
echo ""

OUTPUT=$(~/.config/hypr/scripts/waybar/taskbar-render.sh 2>/dev/null)

echo "=== RAW JSON OUTPUT ==="
echo "$OUTPUT" | jq .
echo ""

echo "=== TEXT FIELD (what Waybar displays) ==="
TEXT=$(echo "$OUTPUT" | jq -r '.text')
echo "$TEXT"
echo ""

echo "=== ANALYSIS ==="
if echo "$TEXT" | grep -q "<img"; then
    IMG_COUNT=$(echo "$TEXT" | grep -o "<img" | wc -l)
    echo "HTML Mode: $IMG_COUNT image tag(s) found"
    
    # Extract image sources
    echo ""
    echo "Image sources:"
    echo "$TEXT" | grep -oP "file://[^'\"]*" | nl
else
    echo "Minimal Mode: Nerd Fonts only"
    echo "Icons: $TEXT"
fi
echo ""

echo "=== TOOLTIP ==="
echo "$OUTPUT" | jq -r '.tooltip'
