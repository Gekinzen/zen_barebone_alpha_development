#!/bin/bash
# Monitor Scale Fixer for Hyprland
# Handles bitdepth, transform, and other parameters
# zenv1 alpha prototype (from Paul's original)

MONITORS_CONF="$HOME/.config/hypr/modules/monitors.conf"
BACKUP_CONF="$HOME/.config/hypr/modules/monitors.conf.backup"

# Function to round scale to nearest valid value
round_scale() {
    local input_scale=$1
    local rounded

    rounded=$(echo "$input_scale" | awk '{
        val = $1
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

if [ ! -f "$MONITORS_CONF" ]; then
    echo "monitors.conf not found at $MONITORS_CONF"
    exit 0
fi

cp "$MONITORS_CONF" "$BACKUP_CONF"

FIXED=false
TEMP_FILE=$(mktemp)

while IFS= read -r line; do
    if [[ $line =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi

    if [[ $line =~ ^monitor=.*,transform, ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi

    if [[ $line =~ ^monitor=([^,]+),([^,]+),([^,]+),([0-9]+\.?[0-9]*)(.*)?$ ]]; then
        MONITOR_NAME="${BASH_REMATCH[1]}"
        RESOLUTION="${BASH_REMATCH[2]}"
        POSITION="${BASH_REMATCH[3]}"
        CURRENT_SCALE="${BASH_REMATCH[4]}"
        EXTRA_PARAMS="${BASH_REMATCH[5]}"

        if [[ "$CURRENT_SCALE" =~ ^(1\.0|1\.25|1\.333333|1\.5|1\.666667|1\.75|2\.0|2\.25|2\.5|2\.75|3\.0)$ ]]; then
            echo "$line" >> "$TEMP_FILE"
        else
            FIXED_SCALE=$(round_scale "$CURRENT_SCALE")
            FIXED_LINE="monitor=$MONITOR_NAME,$RESOLUTION,$POSITION,$FIXED_SCALE$EXTRA_PARAMS"
            echo "$FIXED_LINE" >> "$TEMP_FILE"
            echo "✓ Fixed $MONITOR_NAME: Scale $CURRENT_SCALE → $FIXED_SCALE"
            FIXED=true
        fi
    else
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$MONITORS_CONF"

if [ "$FIXED" = true ]; then
    mv "$TEMP_FILE" "$MONITORS_CONF"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ monitors.conf updated!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$MONITORS_CONF"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    command -v notify-send >/dev/null 2>&1 && \
        notify-send "Monitor Scales Fixed" \
            "Invalid scales automatically corrected" \
            -i video-display

    sleep 0.5
    hyprctl reload
else
    rm "$TEMP_FILE"
    echo "✓ All scales are valid, no changes needed"
fi
