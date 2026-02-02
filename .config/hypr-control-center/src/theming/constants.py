"""
═══════════════════════════════════════════════════════════════════════════════
CONSTANTS - Paths, Color Options, Default Configurations
═══════════════════════════════════════════════════════════════════════════════
"""

from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR = Path.home() / ".config/hypr-control-center"
THEMES_DIR = CONFIG_DIR / "themes"
BUILTIN_DIR = THEMES_DIR / "builtin"
CUSTOM_DIR = THEMES_DIR / "custom"
PROFILES_FILE = THEMES_DIR / "profiles.json"
ASSETS_DIR = CONFIG_DIR / "assets"

WAYBAR_DIR = Path.home() / ".config/waybar"
WAYBAR_STYLE_FILE = WAYBAR_DIR / "style.css"
WAYBAR_COLORSCHEME_DIR = Path.home() / ".config/hypr/colorscheme"

ROFI_DIR = Path.home() / ".config/rofi"
KITTY_DIR = Path.home() / ".config/kitty"

# ═══════════════════════════════════════════════════════════════════════════════
# COLOR OPTIONS - Available color variables for mapping
# ═══════════════════════════════════════════════════════════════════════════════

COLOR_OPTIONS = [
    "bg0", "bg1", "bg2", "bg3", "bg4", 
    "fg", "grey0", "grey1", "grey2",
    "red", "orange", "yellow", "green", "aqua", "blue", "purple"
]

# ═══════════════════════════════════════════════════════════════════════════════
# FONT OPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

FONT_FAMILIES = [
    "JetBrainsMono Nerd Font Propo",
    "JetBrains Mono",
    "Fira Code",
    "Cascadia Code",
    "Source Code Pro",
    "SF Mono",
    "Adwaita Sans",
    "Inter",
    "Roboto",
    "Ubuntu",
    "Cantarell",
]

FONT_SIZES = [10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24]

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT WAYBAR CONFIG - Module colors and behavior
# ═══════════════════════════════════════════════════════════════════════════════

DEFAULT_WAYBAR_CONFIG = {
    "global": {
        "window_radius": 47,
        "window_opacity": 0.50,
        "module_radius": 45,
        "module_opacity": 0.90,
        "font_family": "JetBrainsMono Nerd Font Propo",
        "font_size": 14,
    },
    "workspaces": {
        "container_opacity": 0.21,
        "container_radius": 26,
        "container_padding": "5px 3px",
        "container_min_width": 176,
        "button_padding": "0px 6px",
        "button_margin": "0px 3px",
        "button_radius": 16,
        "button_normal_bg": "bg1",
        "button_normal_text": "transparent",
        "button_active_bg": "blue",
        "button_active_text": "bg0",
        "button_active_min_width": 50,
        "button_hover_bg": "purple",
        "button_hover_text": "bg0",
        "button_hover_min_width": 50,
        "button_urgent_bg": "red",
        "button_urgent_text": "bg0",
        "button_urgent_min_width": 50,
    },
    "modules": {
        "cpu": {"color": "blue"},
        "memory": {"color": "green"},
        "temperature": {"color": "orange"},
        "pulseaudio": {"color": "yellow", "muted": "red"},
        "battery": {"color": "green", "warning": "orange", "critical": "red"},
        "bluetooth": {"color": "blue", "connected": "green", "disconnected": "red"},
        "clock": {"color": "blue"},
        "network": {"wifi": "purple", "ethernet": "green", "disconnected": "red"},
        "notification": {"color": "fg"},
    },
    "taskbar": {
        "button_padding": "0.4em 0.8em",
        "button_margin": "0 4px",
        "button_radius": 14,
        "button_normal_bg": "bg1",
        "button_running_bg": "bg2",
        "button_running_indicator": "blue",
        "button_active_bg": "blue",
        "button_active_text": "bg0",
        "button_hover_bg": "bg3",
        "button_urgent_bg": "red",
        "button_pinned_bg": "bg0",
        "button_pinned_opacity": 0.6,
    },
    "music": {
        "default": "purple",
        "playing": "green",
        "paused": "yellow",
        "idle": "grey0",
    },
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT WAYBAR STYLE - Direct CSS values
# ═══════════════════════════════════════════════════════════════════════════════

DEFAULT_WAYBAR_STYLE = {
    "window": {
        "border_radius": 0,
        "background_opacity": 0.50,
    },
    "workspaces": {
        "background_opacity": 0.21,
        "padding": "5px 3px 5px 3px",
        "min_width": 176,
        "margin": "0 0 0 12px",
        "border_radius": 26,
    },
    "workspaces_button": {
        "padding": "0px 6px",
        "margin": "0px 3px",
        "border_radius": 16,
    },
    "workspaces_button_active": {
        "min_width": 50,
        "border_radius": 16,
        "font_size": 13,
    },
    "workspaces_button_hover": {
        "min_width": 50,
        "border_radius": 16,
    },
    "workspaces_button_urgent": {
        "min_width": 50,
        "border_radius": 16,
    },
    "modules": {
        "padding": "0 15px",
        "margin": "0 0 0 12px",
        "border_radius": 45,
    },
    "taskbar": {
        "padding": "5px 6px",
        "margin": "0 0 0 12px",
        "border_radius": 18,
    },
    "taskbar_button": {
        "padding": "0.4em 0.8em",
        "margin": "0 4px",
        "border_radius": 14,
    },
    "font": {
        "family": "JetBrainsMono Nerd Font Propo",
        "size": 14,
    },
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL CENTER STYLE MAPPING
# ═══════════════════════════════════════════════════════════════════════════════

CONTROL_CENTER_CSS_VARS = {
    "bg0": "--bg0",
    "bg1": "--bg1",
    "bg2": "--bg2",
    "bg3": "--bg3",
    "bg4": "--bg4",
    "fg": "--fg",
    "grey0": "--grey0",
    "grey1": "--grey1",
    "grey2": "--grey2",
    "red": "--red",
    "orange": "--orange",
    "yellow": "--yellow",
    "green": "--green",
    "aqua": "--aqua",
    "blue": "--blue",
    "purple": "--purple",
}
