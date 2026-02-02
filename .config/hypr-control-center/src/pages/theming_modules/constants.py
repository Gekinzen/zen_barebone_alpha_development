"""THEMING CONSTANTS - Paths & Theme Data"""
from pathlib import Path

# Paths
CONFIG_DIR = Path.home() / ".config/hypr-control-center"
THEMES_DIR = CONFIG_DIR / "themes"
BUILTIN_DIR = THEMES_DIR / "builtin"
CUSTOM_DIR = THEMES_DIR / "custom"
PROFILES_FILE = THEMES_DIR / "profiles.json"
PREFERENCES_DIR = CONFIG_DIR / "preferences"
PREFERENCES_THEME_FILE = PREFERENCES_DIR / "theme.json"
APPEARANCE_PREFS_FILE = PREFERENCES_DIR / "appearance.json"

WAYBAR_DIR = Path.home() / ".config/waybar"
WAYBAR_CONFIG = WAYBAR_DIR / "config.jsonc"
WAYBAR_STYLE = WAYBAR_DIR / "style.css"
WAYBAR_COLORSCHEME_DIR = Path.home() / ".config/hypr/colorscheme"

ROFI_SHARED_DIR = Path.home() / ".config/rofi/zenpy-rofi/shared"
ROFI_COLORS_RASI = ROFI_SHARED_DIR / "colors.rasi"
KITTY_CONF = Path.home() / ".config/kitty/kitty.conf"
HYPRLAND_CONF = Path.home() / ".config/hypr/hyprland.conf"

ASSETS_DIR = CONFIG_DIR / "assets"
CONTROL_CENTER_CSS = ASSETS_DIR / "style.css"
PANEL_WIDGET_CSS = ASSETS_DIR / "panel-widget.css"
START_MENU_CSS = ASSETS_DIR / "start-menu.css"
CURRENT_THEME_FILE = CONFIG_DIR / "current-theme.json"
START_ICONS_DIR = ASSETS_DIR / "start-icons"

COLOR_OPTIONS = ["bg0", "bg1", "bg2", "bg3", "bg4", "fg", "grey0", "grey1", "grey2",
                 "red", "orange", "yellow", "green", "aqua", "blue", "purple"]

DEFAULT_WAYBAR_CONFIG = {
    "global": {"window_radius": 47, "window_opacity": 0.50},
    "workspaces": {"button_normal_bg": "bg1", "button_active_bg": "blue", 
                   "button_hover_bg": "purple", "button_urgent_bg": "red"},
    "modules": {"cpu": {"color": "blue"}, "memory": {"color": "green"}, 
                "clock": {"color": "blue"}, "network": {"wifi": "purple"}},
}

# Load themes from separate file
from .themes_data import BUILTIN_THEMES
