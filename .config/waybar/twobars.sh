#!/usr/bin/env bash

# Kill all existing Waybar instances
pkill waybar

# Small delay to prevent race conditions
sleep 0.3

# First bar (primary monitor)
waybar &



