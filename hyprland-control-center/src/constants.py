"""
Configuration paths and constants for Hyprland Control Center
"""

from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════════════════════

HOME = Path.home()
CONFIG_DIR = HOME / ".config" / "hypr"
MODULES_DIR = CONFIG_DIR / "modules"
DEFAULT_DIR = MODULES_DIR / "default"
WAYBAR_DIR = HOME / ".config" / "waybar"

# Config files
LOOK_AND_FEEL_CONF = MODULES_DIR / "look_and_feel.conf"
ANIMATIONS_CONF = CONFIG_DIR / "hyprland.conf"  # animations are in main conf
MONITORS_CONF = MODULES_DIR / "monitors.conf"
BINDS_CONF = MODULES_DIR / "binds.conf"
AUTOSTART_CONF = MODULES_DIR / "autostart.conf"

# ═══════════════════════════════════════════════════════════════════════════════
# ONE DARK COLOR PALETTE
# ═══════════════════════════════════════════════════════════════════════════════

ONE_DARK = {
    'bg0': '#282c34',
    'bg1': '#21252b',
    'bg2': '#2c313a',
    'bg3': '#3e4451',
    'bg4': '#4b5263',
    'red': '#e06c75',
    'orange': '#d19a66',
    'yellow': '#e5c07b',
    'green': '#98c379',
    'aqua': '#56b6c2',
    'blue': '#61afef',
    'purple': '#c678dd',
    'fg': '#abb2bf',
    'grey0': '#5c6370',
    'grey1': '#828997',
    'grey2': '#abb2bf',
}
