#!/bin/bash

# Monitor Scale Fixer for Hyprland
# Handles bitdepth, transform, and other parameters

MONITORS_CONF="$HOME/.config/hypr/monitors.conf"
BACKUP_CONF="$HOME/.config/hypr/monitors.conf.backup"

# Function to round scale to nearest valid value
round_scale() {
    local input_scale=$1
    local rounded
    
    # Round to nearest valid Hyprland scale
    rounded=$(echo "$input_scale" | awk '{
        val = $1
        # Round to nearest valid fraction
        if (val <= 1.0) print "1.0"
        else if (val > 1.0 && val < 1.29) print "1.25"
        else if (val >= 1.29 && val < 1.42) print "1.333333"
        else if (val >= 1.42 && val < 1.58) print "1.5"
        else if (val >= 1.58 && val < 1.71) print "1.666667"
        else if (val >= 1.71 && val < 1.87) print "1.75"
        else if (val >= 1.87 && val < 2.12) print "2.0"
        else if (val >= 2.12 && val < 2.37) print "2.25"
        else if (val >= 2.37 && val < 2.62) print "2.5"
        else if (val >= 2.62 && val < 2.87) print "2.75"
        else print "3.0"
    }')
    
    echo "$rounded"
}

# Check if monitors.conf exists
if [ ! -f "$MONITORS_CONF" ]; then
    echo "monitors.conf not found!"
    exit 0
fi

# Backup original config
cp "$MONITORS_CONF" "$BACKUP_CONF"

# Process the file
FIXED=false
TEMP_FILE=$(mktemp)

while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ $line =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Skip transform lines (they don't have scales)
    if [[ $line =~ ^monitor=.*,transform, ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Match monitor lines: monitor=NAME,RES@REFRESH,POS,SCALE[,other params...]
    if [[ $line =~ ^monitor=([^,]+),([^,]+),([^,]+),([0-9]+\.?[0-9]*)(.*)?$ ]]; then
        MONITOR_NAME="${BASH_REMATCH[1]}"
        RESOLUTION="${BASH_REMATCH[2]}"
        POSITION="${BASH_REMATCH[3]}"
        CURRENT_SCALE="${BASH_REMATCH[4]}"
        EXTRA_PARAMS="${BASH_REMATCH[5]}"  # Everything after scale (bitdepth, etc)
        
        # Check if scale is valid
        if [[ "$CURRENT_SCALE" =~ ^(1\.0|1\.25|1\.333333|1\.5|1\.666667|1\.75|2\.0|2\.25|2\.5|2\.75|3\.0)$ ]]; then
            # Scale is valid, keep line as-is
            echo "$line" >> "$TEMP_FILE"
        else
            # Fix the scale
            FIXED_SCALE=$(round_scale "$CURRENT_SCALE")
            
            # Reconstruct the line
            FIXED_LINE="monitor=$MONITOR_NAME,$RESOLUTION,$POSITION,$FIXED_SCALE$EXTRA_PARAMS"
            echo "$FIXED_LINE" >> "$TEMP_FILE"
            
            echo "✓ Fixed $MONITOR_NAME: Scale $CURRENT_SCALE → $FIXED_SCALE"
            FIXED=true
        fi
    else
        # Not a monitor line, keep as-is
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$MONITORS_CONF"

# Apply fixes if any were made
if [ "$FIXED" = true ]; then
    mv "$TEMP_FILE" "$MONITORS_CONF"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ monitors.conf updated!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$MONITORS_CONF"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Send notification
    notify-send "Monitor Scales Fixed" \
        "Invalid scales automatically corrected" \
        -i video-display
    
    # Reload Hyprland
    sleep 0.5
    hyprctl reload
else
    rm "$TEMP_FILE"
    echo "✓ All scales are valid, no changes needed"
fi