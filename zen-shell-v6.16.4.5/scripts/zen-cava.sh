#!/usr/bin/env bash
# zen-cava.sh — cava wrapper for ZenStrings
# Usage: zen-cava.sh [segments]
# Outputs: semicolon-delimited bar values, one line per frame
# e.g.: 123;456;789;...;

SEGMENTS="${1:-10}"

# Generate a minimal cava config on the fly
CAVA_CONF=$(mktemp /tmp/zen-cava-XXXXXX.conf)

cat > "$CAVA_CONF" << EOF
[general]
bars = $SEGMENTS
framerate = 60

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
EOF

trap 'rm -f "$CAVA_CONF"' EXIT

exec cava -p "$CAVA_CONF"
