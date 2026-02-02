"""
═══════════════════════════════════════════════════════════════════════════════
THEMING MODULE - Hyprland Control Center
Complete Theme Management for Waybar, Rofi, Kitty, and Control Center
Author: Paul Zenpy(Gekinzen) | Version: 1.4 //20260116
═══════════════════════════════════════════════════════════════════════════════

Changes in 1.4:
- Fixed Rofi: Now writes colors directly to zenpy-rofi/shared/colors.rasi
- Removed @import method, uses direct color definitions with #RRGGBBFF format
- Auto-applies rofi theme on dropdown selection change
- Path: ~/.config/rofi/zenpy-rofi/shared/colors.rasi

Changes in 1.3:
- Added missing themes: black, lovelace, paper, yousai, navy
- Kitty: Uses sed-like regex to update kitty.conf directly
- Control Center: Integrated theme switching
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gdk, GLib, Pango
import subprocess, os, json, shutil, math, cairo, re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any, Callable

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS & CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR = Path.home() / ".config/hypr-control-center"
THEMES_DIR = CONFIG_DIR / "themes"
BUILTIN_DIR = THEMES_DIR / "builtin"
CUSTOM_DIR = THEMES_DIR / "custom"
PROFILES_FILE = THEMES_DIR / "profiles.json"

# Application config paths
WAYBAR_DIR = Path.home() / ".config/waybar"
WAYBAR_COLORSCHEME_DIR = Path.home() / ".config/hypr/colorscheme"
ROFI_DIR = Path.home() / ".config/rofi"
ROFI_COLORS_DIR = ROFI_DIR / "colors"
# Zenpy-rofi paths (actual rofi config location)
ROFI_ZENPY_DIR = ROFI_DIR / "zenpy-rofi"
ROFI_SHARED_DIR = ROFI_ZENPY_DIR / "shared"
ROFI_COLORS_RASI = ROFI_SHARED_DIR / "colors.rasi"
KITTY_DIR = Path.home() / ".config/kitty"
KITTY_CONF = KITTY_DIR / "kitty.conf"

COLOR_OPTIONS = ["bg0", "bg1", "bg2", "bg3", "bg4", "fg", "grey0", "grey1", "grey2",
                 "red", "orange", "yellow", "green", "aqua", "blue", "purple"]

DEFAULT_WAYBAR_CONFIG = {
    "global": {"window_radius": 47, "window_opacity": 0.50, "module_radius": 45, "module_opacity": 0.90},
    "workspaces": {"container_opacity": 0.21, "container_radius": 26, "button_normal_bg": "bg1",
                   "button_active_bg": "blue", "button_active_text": "bg0", "button_hover_bg": "purple",
                   "button_hover_text": "bg0", "button_urgent_bg": "red", "button_urgent_text": "bg0"},
    "modules": {"cpu": {"color": "blue"}, "memory": {"color": "green"}, "temperature": {"color": "orange"},
                "pulseaudio": {"color": "yellow", "muted": "red"}, "battery": {"color": "green", "warning": "orange", "critical": "red"},
                "bluetooth": {"color": "blue", "connected": "green", "disconnected": "red"}, "clock": {"color": "blue"},
                "network": {"wifi": "purple", "ethernet": "green", "disconnected": "red"}, "notification": {"color": "fg"}},
    "taskbar": {"button_normal_bg": "bg1", "button_running_bg": "bg2", "button_running_indicator": "blue",
                "button_active_bg": "blue", "button_active_text": "bg0", "button_hover_bg": "bg3", "button_urgent_bg": "red"},
    "music": {"default": "purple", "playing": "green", "paused": "yellow", "idle": "grey0"},
}

# ═══════════════════════════════════════════════════════════════════════════════
# BUILTIN THEMES
# ═══════════════════════════════════════════════════════════════════════════════

BUILTIN_THEMES = {
    "one-dark": {
        "name": "One Dark", "description": "Atom's iconic dark theme",
        "colors": {"bg0": "#282c34", "bg1": "#21252b", "bg2": "#2c313a", "bg3": "#3e4451", "bg4": "#4b5263",
                   "fg": "#abb2bf", "grey0": "#5c6370", "grey1": "#828997", "grey2": "#abb2bf",
                   "red": "#e06c75", "orange": "#d19a66", "yellow": "#e5c07b", "green": "#98c379",
                   "aqua": "#56b6c2", "blue": "#61afef", "purple": "#c678dd"},
        "rofi": {"background": "#1E2127", "background-alt": "#282B31", "foreground": "#FFFFFF",
                 "selected": "#61AFEF", "active": "#98C379", "urgent": "#E06C75"},
        "kitty": {"background": "#282c34", "foreground": "#abb2bf", "cursor": "#528bff",
                  "selection_foreground": "#282c34", "selection_background": "#3e4451",
                  "color0": "#282c34", "color1": "#e06c75", "color2": "#98c379", "color3": "#e5c07b",
                  "color4": "#61afef", "color5": "#c678dd", "color6": "#56b6c2", "color7": "#abb2bf",
                  "color8": "#5c6370", "color9": "#e06c75", "color10": "#98c379", "color11": "#e5c07b",
                  "color12": "#61afef", "color13": "#c678dd", "color14": "#56b6c2", "color15": "#5c6370"}
    },
    "gruvbox-dark": {
        "name": "Gruvbox Dark", "description": "Retro groove with warm tones",
        "colors": {"bg0": "#282828", "bg1": "#3c3836", "bg2": "#504945", "bg3": "#665c54", "bg4": "#7c6f64",
                   "fg": "#ebdbb2", "grey0": "#928374", "grey1": "#a89984", "grey2": "#bdae93",
                   "red": "#fb4934", "orange": "#fe8019", "yellow": "#fabd2f", "green": "#b8bb26",
                   "aqua": "#8ec07c", "blue": "#83a598", "purple": "#d3869b"},
        "rofi": {"background": "#282828", "background-alt": "#353535", "foreground": "#EBDBB2",
                 "selected": "#83A598", "active": "#B8BB26", "urgent": "#FB4934"},
        "kitty": {"background": "#282828", "foreground": "#ebdbb2", "cursor": "#928374",
                  "selection_foreground": "#928374", "selection_background": "#3c3836",
                  "color0": "#282828", "color1": "#cc241d", "color2": "#98971a", "color3": "#d79921",
                  "color4": "#458588", "color5": "#b16286", "color6": "#689d6a", "color7": "#a89984",
                  "color8": "#928374", "color9": "#fb4934", "color10": "#b8bb26", "color11": "#fabd2f",
                  "color12": "#83a598", "color13": "#d3869b", "color14": "#8ec07c", "color15": "#928374"}
    },
    "nord": {
        "name": "Nord", "description": "Arctic north-bluish palette",
        "colors": {"bg0": "#2e3440", "bg1": "#3b4252", "bg2": "#434c5e", "bg3": "#4c566a", "bg4": "#5e81ac",
                   "fg": "#eceff4", "grey0": "#616e88", "grey1": "#7b88a1", "grey2": "#d8dee9",
                   "red": "#bf616a", "orange": "#d08770", "yellow": "#ebcb8b", "green": "#a3be8c",
                   "aqua": "#88c0d0", "blue": "#81a1c1", "purple": "#b48ead"},
        "rofi": {"background": "#2E3440", "background-alt": "#383E4A", "foreground": "#E5E9F0",
                 "selected": "#81A1C1", "active": "#A3BE8C", "urgent": "#BF616A"},
        "kitty": {"background": "#2e3440", "foreground": "#d8dee9", "cursor": "#d8dee9",
                  "selection_foreground": "#2e3440", "selection_background": "#4c566a",
                  "color0": "#3b4252", "color1": "#bf616a", "color2": "#a3be8c", "color3": "#ebcb8b",
                  "color4": "#81a1c1", "color5": "#b48ead", "color6": "#88c0d0", "color7": "#e5e9f0",
                  "color8": "#4c566a", "color9": "#bf616a", "color10": "#a3be8c", "color11": "#ebcb8b",
                  "color12": "#81a1c1", "color13": "#b48ead", "color14": "#8fbcbb", "color15": "#eceff4"}
    },
    "tokyo-night": {
        "name": "Tokyo Night", "description": "Tokyo city lights inspired",
        "colors": {"bg0": "#1a1b26", "bg1": "#16161e", "bg2": "#24283b", "bg3": "#414868", "bg4": "#565f89",
                   "fg": "#c0caf5", "grey0": "#565f89", "grey1": "#787c99", "grey2": "#a9b1d6",
                   "red": "#f7768e", "orange": "#ff9e64", "yellow": "#e0af68", "green": "#9ece6a",
                   "aqua": "#7dcfff", "blue": "#7aa2f7", "purple": "#bb9af7"},
        "rofi": {"background": "#15161E", "background-alt": "#1A1B26", "foreground": "#C0CAF5",
                 "selected": "#33467C", "active": "#414868", "urgent": "#F7768E"},
        "kitty": {"background": "#1a1b26", "foreground": "#c0caf5", "cursor": "#c0caf5",
                  "selection_foreground": "#1a1b26", "selection_background": "#414868",
                  "color0": "#15161e", "color1": "#f7768e", "color2": "#9ece6a", "color3": "#e0af68",
                  "color4": "#7aa2f7", "color5": "#bb9af7", "color6": "#7dcfff", "color7": "#a9b1d6",
                  "color8": "#414868", "color9": "#f7768e", "color10": "#9ece6a", "color11": "#e0af68",
                  "color12": "#7aa2f7", "color13": "#bb9af7", "color14": "#7dcfff", "color15": "#c0caf5"}
    },
    "catppuccin-mocha": {
        "name": "Catppuccin Mocha", "description": "Soothing pastel theme",
        "colors": {"bg0": "#1e1e2e", "bg1": "#181825", "bg2": "#313244", "bg3": "#45475a", "bg4": "#585b70",
                   "fg": "#cdd6f4", "grey0": "#6c7086", "grey1": "#7f849c", "grey2": "#9399b2",
                   "red": "#f38ba8", "orange": "#fab387", "yellow": "#f9e2af", "green": "#a6e3a1",
                   "aqua": "#94e2d5", "blue": "#89b4fa", "purple": "#cba6f7"},
        "rofi": {"background": "#1E1D2F", "background-alt": "#282839", "foreground": "#D9E0EE",
                 "selected": "#7AA2F7", "active": "#ABE9B3", "urgent": "#F28FAD"},
        "kitty": {"background": "#1e1e2e", "foreground": "#cdd6f4", "cursor": "#f5e0dc",
                  "selection_foreground": "#1e1e2e", "selection_background": "#45475a",
                  "color0": "#45475a", "color1": "#f38ba8", "color2": "#a6e3a1", "color3": "#f9e2af",
                  "color4": "#89b4fa", "color5": "#cba6f7", "color6": "#94e2d5", "color7": "#bac2de",
                  "color8": "#585b70", "color9": "#f38ba8", "color10": "#a6e3a1", "color11": "#f9e2af",
                  "color12": "#89b4fa", "color13": "#cba6f7", "color14": "#94e2d5", "color15": "#a6adc8"}
    },
    "everforest-dark": {
        "name": "Everforest Dark", "description": "Nature inspired green theme",
        "colors": {"bg0": "#2d353b", "bg1": "#343f44", "bg2": "#3d484d", "bg3": "#475258", "bg4": "#4f585e",
                   "fg": "#d3c6aa", "grey0": "#7a8478", "grey1": "#859289", "grey2": "#9da9a0",
                   "red": "#e67e80", "orange": "#e69875", "yellow": "#dbbc7f", "green": "#a7c080",
                   "aqua": "#83c092", "blue": "#7fbbb3", "purple": "#d699b6"},
        "rofi": {"background": "#323D43", "background-alt": "#3C474D", "foreground": "#DAD1BE",
                 "selected": "#7FBBB3", "active": "#A7C080", "urgent": "#E67E80"},
        "kitty": {"background": "#2d353b", "foreground": "#d3c6aa", "cursor": "#d3c6aa",
                  "selection_foreground": "#2d353b", "selection_background": "#475258",
                  "color0": "#475258", "color1": "#e67e80", "color2": "#a7c080", "color3": "#dbbc7f",
                  "color4": "#7fbbb3", "color5": "#d699b6", "color6": "#83c092", "color7": "#d3c6aa",
                  "color8": "#4f585e", "color9": "#e67e80", "color10": "#a7c080", "color11": "#dbbc7f",
                  "color12": "#7fbbb3", "color13": "#d699b6", "color14": "#83c092", "color15": "#9da9a0"}
    },
    "dracula": {
        "name": "Dracula", "description": "Vibrant dark theme",
        "colors": {"bg0": "#282a36", "bg1": "#1e1f29", "bg2": "#343746", "bg3": "#44475a", "bg4": "#565968",
                   "fg": "#f8f8f2", "grey0": "#6272a4", "grey1": "#7284b8", "grey2": "#bfbfbf",
                   "red": "#ff5555", "orange": "#ffb86c", "yellow": "#f1fa8c", "green": "#50fa7b",
                   "aqua": "#8be9fd", "blue": "#6272a4", "purple": "#bd93f9"},
        "rofi": {"background": "#1E1F29", "background-alt": "#282A36", "foreground": "#FFFFFF",
                 "selected": "#BD93F9", "active": "#50FA7B", "urgent": "#FF5555"},
        "kitty": {"background": "#282a36", "foreground": "#f8f8f2", "cursor": "#f8f8f2",
                  "selection_foreground": "#282a36", "selection_background": "#44475a",
                  "color0": "#21222c", "color1": "#ff5555", "color2": "#50fa7b", "color3": "#f1fa8c",
                  "color4": "#bd93f9", "color5": "#ff79c6", "color6": "#8be9fd", "color7": "#f8f8f2",
                  "color8": "#6272a4", "color9": "#ff6e6e", "color10": "#69ff94", "color11": "#ffffa5",
                  "color12": "#d6acff", "color13": "#ff92df", "color14": "#a4ffff", "color15": "#ffffff"}
    },
    "solarized-dark": {
        "name": "Solarized Dark", "description": "Precision colors",
        "colors": {"bg0": "#002b36", "bg1": "#073642", "bg2": "#094352", "bg3": "#0b5362", "bg4": "#586e75",
                   "fg": "#839496", "grey0": "#657b83", "grey1": "#839496", "grey2": "#93a1a1",
                   "red": "#dc322f", "orange": "#cb4b16", "yellow": "#b58900", "green": "#859900",
                   "aqua": "#2aa198", "blue": "#268bd2", "purple": "#6c71c4"},
        "rofi": {"background": "#002B36", "background-alt": "#073642", "foreground": "#EEE8D5",
                 "selected": "#268BD2", "active": "#859900", "urgent": "#DC322F"},
        "kitty": {"background": "#002b36", "foreground": "#839496", "cursor": "#839496",
                  "selection_foreground": "#002b36", "selection_background": "#586e75",
                  "color0": "#073642", "color1": "#dc322f", "color2": "#859900", "color3": "#b58900",
                  "color4": "#268bd2", "color5": "#d33682", "color6": "#2aa198", "color7": "#eee8d5",
                  "color8": "#002b36", "color9": "#cb4b16", "color10": "#586e75", "color11": "#657b83",
                  "color12": "#839496", "color13": "#6c71c4", "color14": "#93a1a1", "color15": "#fdf6e3"}
    },
    "cyberpunk": {
        "name": "Cyberpunk", "description": "Neon futuristic theme",
        "colors": {"bg0": "#000b1e", "bg1": "#0a1528", "bg2": "#141f32", "bg3": "#1e293c", "bg4": "#283346",
                   "fg": "#0abdc6", "grey0": "#065a5f", "grey1": "#088a91", "grey2": "#0abdc6",
                   "red": "#ff0000", "orange": "#ff6600", "yellow": "#ffff00", "green": "#00ff00",
                   "aqua": "#0abdc6", "blue": "#0066ff", "purple": "#ff00ff"},
        "rofi": {"background": "#000B1E", "background-alt": "#0A1528", "foreground": "#0ABDC6",
                 "selected": "#0ABDC6", "active": "#00FF00", "urgent": "#FF0000"},
        "kitty": {"background": "#000b1e", "foreground": "#0abdc6", "cursor": "#0abdc6",
                  "selection_foreground": "#000b1e", "selection_background": "#1e293c",
                  "color0": "#0a1528", "color1": "#ff0000", "color2": "#00ff00", "color3": "#ffff00",
                  "color4": "#0066ff", "color5": "#ff00ff", "color6": "#0abdc6", "color7": "#0abdc6",
                  "color8": "#283346", "color9": "#ff3333", "color10": "#33ff33", "color11": "#ffff33",
                  "color12": "#3399ff", "color13": "#ff33ff", "color14": "#3dcfd7", "color15": "#ffffff"}
    },
    "arc": {
        "name": "Arc", "description": "Flat transparent theme",
        "colors": {"bg0": "#2f343f", "bg1": "#383c4a", "bg2": "#404552", "bg3": "#4b5162", "bg4": "#5c6073",
                   "fg": "#d3dae3", "grey0": "#7c818c", "grey1": "#9499a4", "grey2": "#bac5d0",
                   "red": "#e06b74", "orange": "#d19a66", "yellow": "#f0c674", "green": "#98c379",
                   "aqua": "#56b6c2", "blue": "#5294e2", "purple": "#c678dd"},
        "rofi": {"background": "#2F343F", "background-alt": "#383C4A", "foreground": "#BAC5D0",
                 "selected": "#5294E2", "active": "#98C379", "urgent": "#E06B74"},
        "kitty": {"background": "#2f343f", "foreground": "#d3dae3", "cursor": "#5294e2",
                  "selection_foreground": "#2f343f", "selection_background": "#4b5162",
                  "color0": "#383c4a", "color1": "#e06b74", "color2": "#98c379", "color3": "#f0c674",
                  "color4": "#5294e2", "color5": "#c678dd", "color6": "#56b6c2", "color7": "#d3dae3",
                  "color8": "#5c6073", "color9": "#e06b74", "color10": "#98c379", "color11": "#f0c674",
                  "color12": "#5294e2", "color13": "#c678dd", "color14": "#56b6c2", "color15": "#ffffff"}
    },
    "adapta": {
        "name": "Adapta", "description": "Material design dark",
        "colors": {"bg0": "#222d32", "bg1": "#29353b", "bg2": "#313d43", "bg3": "#3a464c", "bg4": "#445055",
                   "fg": "#cfd8dc", "grey0": "#8c9a9e", "grey1": "#a0aeb3", "grey2": "#b8c2c6",
                   "red": "#ff4b60", "orange": "#ff8a65", "yellow": "#ffd54f", "green": "#21ff90",
                   "aqua": "#00bcd4", "blue": "#00bcd4", "purple": "#b388ff"},
        "rofi": {"background": "#222D32", "background-alt": "#29353B", "foreground": "#B8C2C6",
                 "selected": "#00BCD4", "active": "#21FF90", "urgent": "#FF4B60"},
        "kitty": {"background": "#222d32", "foreground": "#cfd8dc", "cursor": "#00bcd4",
                  "selection_foreground": "#222d32", "selection_background": "#3a464c",
                  "color0": "#29353b", "color1": "#ff4b60", "color2": "#21ff90", "color3": "#ffd54f",
                  "color4": "#00bcd4", "color5": "#b388ff", "color6": "#00bcd4", "color7": "#cfd8dc",
                  "color8": "#445055", "color9": "#ff6b7a", "color10": "#4dffaa", "color11": "#ffe07f",
                  "color12": "#4dd0e1", "color13": "#c9a8ff", "color14": "#4dd0e1", "color15": "#ffffff"}
    },
    # ═══════════════════════════════════════════════════════════════════════════
    # NEW THEMES - Matching Rofi color schemes
    # ═══════════════════════════════════════════════════════════════════════════
    "black": {
        "name": "Black", "description": "Pure black OLED theme",
        "colors": {"bg0": "#000000", "bg1": "#101010", "bg2": "#1a1a1a", "bg3": "#252525", "bg4": "#303030",
                   "fg": "#ffffff", "grey0": "#505050", "grey1": "#707070", "grey2": "#909090",
                   "red": "#e06b74", "orange": "#d19a66", "yellow": "#e5c07b", "green": "#98c379",
                   "aqua": "#56b6c2", "blue": "#62aeef", "purple": "#c678dd"},
        "rofi": {"background": "#000000", "background-alt": "#101010", "foreground": "#FFFFFF",
                 "selected": "#62AEEF", "active": "#98C379", "urgent": "#E06B74"},
        "kitty": {"background": "#000000", "foreground": "#ffffff", "cursor": "#62aeef",
                  "selection_foreground": "#000000", "selection_background": "#303030",
                  "color0": "#000000", "color1": "#e06b74", "color2": "#98c379", "color3": "#e5c07b",
                  "color4": "#62aeef", "color5": "#c678dd", "color6": "#56b6c2", "color7": "#ffffff",
                  "color8": "#505050", "color9": "#e06b74", "color10": "#98c379", "color11": "#e5c07b",
                  "color12": "#62aeef", "color13": "#c678dd", "color14": "#56b6c2", "color15": "#ffffff"}
    },
    "lovelace": {
        "name": "Lovelace", "description": "Elegant purple-cyan theme",
        "colors": {"bg0": "#1d1f28", "bg1": "#282a36", "bg2": "#323442", "bg3": "#3c3e4e", "bg4": "#46485a",
                   "fg": "#fdfdfd", "grey0": "#565869", "grey1": "#6e7086", "grey2": "#8688a3",
                   "red": "#f37f97", "orange": "#f2a272", "yellow": "#f2d67c", "green": "#5adecd",
                   "aqua": "#79e6f3", "blue": "#7eb8da", "purple": "#c574dd"},
        "rofi": {"background": "#1D1F28", "background-alt": "#282A36", "foreground": "#FDFDFD",
                 "selected": "#79E6F3", "active": "#5ADECD", "urgent": "#F37F97"},
        "kitty": {"background": "#1d1f28", "foreground": "#fdfdfd", "cursor": "#79e6f3",
                  "selection_foreground": "#1d1f28", "selection_background": "#3c3e4e",
                  "color0": "#1d1f28", "color1": "#f37f97", "color2": "#5adecd", "color3": "#f2d67c",
                  "color4": "#7eb8da", "color5": "#c574dd", "color6": "#79e6f3", "color7": "#fdfdfd",
                  "color8": "#565869", "color9": "#f37f97", "color10": "#5adecd", "color11": "#f2d67c",
                  "color12": "#7eb8da", "color13": "#c574dd", "color14": "#79e6f3", "color15": "#fdfdfd"}
    },
    "navy": {
        "name": "Navy", "description": "Deep navy blue theme",
        "colors": {"bg0": "#0a1628", "bg1": "#0f1d32", "bg2": "#14243c", "bg3": "#1a2b46", "bg4": "#213250",
                   "fg": "#d0e0f0", "grey0": "#4a5a6a", "grey1": "#6a7a8a", "grey2": "#8a9aaa",
                   "red": "#ff6b6b", "orange": "#ffa06b", "yellow": "#ffd56b", "green": "#6bffa0",
                   "aqua": "#6bffd5", "blue": "#6bb5ff", "purple": "#b56bff"},
        "rofi": {"background": "#0A1628", "background-alt": "#0F1D32", "foreground": "#D0E0F0",
                 "selected": "#6BB5FF", "active": "#6BFFA0", "urgent": "#FF6B6B"},
        "kitty": {"background": "#0a1628", "foreground": "#d0e0f0", "cursor": "#6bb5ff",
                  "selection_foreground": "#0a1628", "selection_background": "#1a2b46",
                  "color0": "#0a1628", "color1": "#ff6b6b", "color2": "#6bffa0", "color3": "#ffd56b",
                  "color4": "#6bb5ff", "color5": "#b56bff", "color6": "#6bffd5", "color7": "#d0e0f0",
                  "color8": "#4a5a6a", "color9": "#ff6b6b", "color10": "#6bffa0", "color11": "#ffd56b",
                  "color12": "#6bb5ff", "color13": "#b56bff", "color14": "#6bffd5", "color15": "#ffffff"}
    },
    "paper": {
        "name": "Paper", "description": "Light paper theme",
        "colors": {"bg0": "#f1f1f1", "bg1": "#e0e0e0", "bg2": "#d0d0d0", "bg3": "#c0c0c0", "bg4": "#b0b0b0",
                   "fg": "#252525", "grey0": "#808080", "grey1": "#606060", "grey2": "#404040",
                   "red": "#c30771", "orange": "#c77500", "yellow": "#a67c00", "green": "#10a778",
                   "aqua": "#007a90", "blue": "#008ec4", "purple": "#8b39a8"},
        "rofi": {"background": "#F1F1F1", "background-alt": "#E0E0E0", "foreground": "#252525",
                 "selected": "#008EC4", "active": "#10A778", "urgent": "#C30771"},
        "kitty": {"background": "#f1f1f1", "foreground": "#252525", "cursor": "#008ec4",
                  "selection_foreground": "#f1f1f1", "selection_background": "#c0c0c0",
                  "color0": "#252525", "color1": "#c30771", "color2": "#10a778", "color3": "#a67c00",
                  "color4": "#008ec4", "color5": "#8b39a8", "color6": "#007a90", "color7": "#f1f1f1",
                  "color8": "#808080", "color9": "#c30771", "color10": "#10a778", "color11": "#a67c00",
                  "color12": "#008ec4", "color13": "#8b39a8", "color14": "#007a90", "color15": "#ffffff"}
    },
    "yousai": {
        "name": "Yousai", "description": "Warm cream Japanese theme",
        "colors": {"bg0": "#f5e7de", "bg1": "#ebdcd2", "bg2": "#e0d0c5", "bg3": "#d5c4b8", "bg4": "#cab8ab",
                   "fg": "#34302d", "grey0": "#8a8078", "grey1": "#6a625a", "grey2": "#4a443e",
                   "red": "#b23636", "orange": "#d97742", "yellow": "#c49a3d", "green": "#6a8c3a",
                   "aqua": "#3a8c7a", "blue": "#4a7a9c", "purple": "#8a4a8c"},
        "rofi": {"background": "#F5E7DE", "background-alt": "#EBDCD2", "foreground": "#34302D",
                 "selected": "#D97742", "active": "#BF8F60", "urgent": "#B23636"},
        "kitty": {"background": "#f5e7de", "foreground": "#34302d", "cursor": "#d97742",
                  "selection_foreground": "#f5e7de", "selection_background": "#d5c4b8",
                  "color0": "#34302d", "color1": "#b23636", "color2": "#6a8c3a", "color3": "#c49a3d",
                  "color4": "#4a7a9c", "color5": "#8a4a8c", "color6": "#3a8c7a", "color7": "#f5e7de",
                  "color8": "#8a8078", "color9": "#b23636", "color10": "#6a8c3a", "color11": "#c49a3d",
                  "color12": "#4a7a9c", "color13": "#8a4a8c", "color14": "#3a8c7a", "color15": "#ffffff"}
    },
}

# ═══════════════════════════════════════════════════════════════════════════════
# PROFILE MANAGER CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class ThemeProfileManager:
    def __init__(self):
        self._ensure_directories()
        self._init_builtin_themes()
        self.profiles = self._load_profiles()
    
    def _ensure_directories(self):
        THEMES_DIR.mkdir(parents=True, exist_ok=True)
        BUILTIN_DIR.mkdir(parents=True, exist_ok=True)
        CUSTOM_DIR.mkdir(parents=True, exist_ok=True)
    
    def _init_builtin_themes(self):
        for theme_id, theme_data in BUILTIN_THEMES.items():
            theme_file = BUILTIN_DIR / f"{theme_id}.json"
            if not theme_file.exists():
                self._save_theme_file(theme_file, theme_id, theme_data, is_builtin=True)
    
    def _save_theme_file(self, path, theme_id, theme_data, is_builtin=False):
        data = {"id": theme_id, "name": theme_data.get("name", theme_id), "description": theme_data.get("description", ""),
                "is_builtin": is_builtin, "version": "1.0", "created_at": datetime.now().isoformat(),
                "modified_at": datetime.now().isoformat(), "colors": theme_data.get("colors", {}),
                "rofi": theme_data.get("rofi", {}), "kitty": theme_data.get("kitty", {}),
                "waybar": theme_data.get("waybar", DEFAULT_WAYBAR_CONFIG.copy())}
        with open(path, 'w') as f: json.dump(data, f, indent=2)
    
    def _load_profiles(self):
        if PROFILES_FILE.exists():
            try:
                with open(PROFILES_FILE) as f: return json.load(f)
            except: pass
        return {"version": "2.0", "active_profile": "one-dark", "active_profile_type": "builtin", "use_custom_scheme": True}
    
    def save_profiles(self):
        with open(PROFILES_FILE, 'w') as f: json.dump(self.profiles, f, indent=2)
    
    def get_active_theme(self):
        pid = self.profiles.get("active_profile", "one-dark")
        ptype = self.profiles.get("active_profile_type", "builtin")
        theme_file = (BUILTIN_DIR if ptype == "builtin" else CUSTOM_DIR) / f"{pid}.json"
        if theme_file.exists():
            with open(theme_file) as f: return json.load(f)
        if pid in BUILTIN_THEMES: return {"id": pid, "is_builtin": True, **BUILTIN_THEMES[pid]}
        return {"id": "one-dark", "is_builtin": True, **BUILTIN_THEMES["one-dark"]}
    
    def set_active_theme(self, theme_id, is_builtin=True):
        self.profiles["active_profile"] = theme_id
        self.profiles["active_profile_type"] = "builtin" if is_builtin else "custom"
        self.save_profiles()
    
    def get_all_themes(self):
        themes = [{"id": tid, "name": td["name"], "description": td.get("description", ""), "is_builtin": True} 
                  for tid, td in BUILTIN_THEMES.items()]
        for tf in CUSTOM_DIR.glob("*.json"):
            try:
                with open(tf) as f: d = json.load(f)
                themes.append({"id": d.get("id", tf.stem), "name": d.get("name", tf.stem), "description": d.get("description", ""), "is_builtin": False})
            except: pass
        return themes
    
    def create_custom_theme(self, name, base_theme_id=None):
        theme_id = ''.join(c for c in name.lower().replace(" ", "-").replace("_", "-") if c.isalnum() or c == '-')
        counter = 1
        orig = theme_id
        while (CUSTOM_DIR / f"{theme_id}.json").exists(): theme_id = f"{orig}-{counter}"; counter += 1
        base = BUILTIN_THEMES.get(base_theme_id, BUILTIN_THEMES["one-dark"]).copy()
        base["name"] = name
        base["description"] = f"Custom theme based on {base_theme_id or 'One Dark'}"
        self._save_theme_file(CUSTOM_DIR / f"{theme_id}.json", theme_id, base, is_builtin=False)
        return theme_id
    
    def update_custom_theme(self, theme_id, updates):
        tf = CUSTOM_DIR / f"{theme_id}.json"
        if not tf.exists(): return False
        with open(tf) as f: data = json.load(f)
        for k, v in updates.items():
            if isinstance(v, dict) and k in data and isinstance(data[k], dict): data[k].update(v)
            else: data[k] = v
        data["modified_at"] = datetime.now().isoformat()
        with open(tf, 'w') as f: json.dump(data, f, indent=2)
        return True
    
    def delete_custom_theme(self, theme_id):
        tf = CUSTOM_DIR / f"{theme_id}.json"
        if tf.exists():
            tf.unlink()
            if self.profiles.get("active_profile") == theme_id: self.set_active_theme("one-dark", True)
            return True
        return False
    
    def export_theme(self, theme_id, export_path):
        tf = BUILTIN_DIR / f"{theme_id}.json"
        if not tf.exists(): tf = CUSTOM_DIR / f"{theme_id}.json"
        if not tf.exists():
            if theme_id in BUILTIN_THEMES:
                data = {"id": theme_id, "name": BUILTIN_THEMES[theme_id]["name"], "colors": BUILTIN_THEMES[theme_id]["colors"],
                        "rofi": BUILTIN_THEMES[theme_id]["rofi"], "kitty": BUILTIN_THEMES[theme_id]["kitty"],
                        "waybar": DEFAULT_WAYBAR_CONFIG.copy(), "exported_at": datetime.now().isoformat()}
                with open(export_path, 'w') as f: json.dump(data, f, indent=2)
                return True
            return False
        shutil.copy(tf, export_path)
        return True
    
    def import_theme(self, import_path):
        try:
            with open(import_path) as f: data = json.load(f)
            if "colors" not in data: return None
            theme_id = self.create_custom_theme(data.get("name", import_path.stem))
            tf = CUSTOM_DIR / f"{theme_id}.json"
            with open(tf) as f: existing = json.load(f)
            existing.update({"colors": data.get("colors", {}), "rofi": data.get("rofi", {}),
                            "kitty": data.get("kitty", {}), "waybar": data.get("waybar", DEFAULT_WAYBAR_CONFIG.copy())})
            with open(tf, 'w') as f: json.dump(existing, f, indent=2)
            return theme_id
        except: return None

# ═══════════════════════════════════════════════════════════════════════════════
# THEME APPLIER CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class ThemeApplier:
    """Handles applying themes to all applications"""
    
    @staticmethod
    def apply_waybar_colorscheme(theme_data):
        """Generate and apply Waybar colorscheme CSS"""
        colors = theme_data.get("colors", {})
        theme_id = theme_data.get("id", "custom")
        css = f"""/* Auto-generated by Hyprland Control Center - {theme_data.get('name', 'Custom')} */
@define-color bg0 {colors.get('bg0', '#282c34')};
@define-color bg1 {colors.get('bg1', '#21252b')};
@define-color bg2 {colors.get('bg2', '#2c313a')};
@define-color bg3 {colors.get('bg3', '#3e4451')};
@define-color bg4 {colors.get('bg4', '#4b5263')};
@define-color fg {colors.get('fg', '#abb2bf')};
@define-color grey0 {colors.get('grey0', '#5c6370')};
@define-color grey1 {colors.get('grey1', '#828997')};
@define-color grey2 {colors.get('grey2', '#abb2bf')};
@define-color red {colors.get('red', '#e06c75')};
@define-color orange {colors.get('orange', '#d19a66')};
@define-color yellow {colors.get('yellow', '#e5c07b')};
@define-color green {colors.get('green', '#98c379')};
@define-color aqua {colors.get('aqua', '#56b6c2')};
@define-color blue {colors.get('blue', '#61afef')};
@define-color purple {colors.get('purple', '#c678dd')};
"""
        WAYBAR_COLORSCHEME_DIR.mkdir(parents=True, exist_ok=True)
        with open(WAYBAR_COLORSCHEME_DIR / f"{theme_id}.css", 'w') as f: f.write(css)
        
        # Update import in waybar style.css
        style_file = WAYBAR_DIR / "style.css"
        if style_file.exists():
            with open(style_file) as f: content = f.read()
            if "@import" in content:
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if "@import" in line and "colorscheme" in line:
                        lines[i] = f"@import '../hypr/colorscheme/{theme_id}.css';"
                        break
                with open(style_file, 'w') as f: f.write('\n'.join(lines))
        return True
    
    @staticmethod
    def apply_rofi_colors(theme_data):
        """
        Update Rofi colors.rasi with direct color definitions.
        Writes color values directly to ~/.config/rofi/zenpy-rofi/shared/colors.rasi
        """
        theme_id = theme_data.get("id", "one-dark")
        theme_name = theme_data.get("name", "Custom")
        rofi = theme_data.get("rofi", {})
        colors = theme_data.get("colors", {})
        
        # Get rofi colors from theme, with fallbacks to base colors
        def get_color_with_alpha(color):
            """Convert #RRGGBB to #RRGGBBFF format"""
            c = color.lstrip('#')
            if len(c) == 6:
                return f"#{c.upper()}FF"
            elif len(c) == 8:
                return f"#{c.upper()}"
            return f"#{c.upper()}FF"
        
        background = get_color_with_alpha(rofi.get("background", colors.get("bg0", "#282c34")))
        background_alt = get_color_with_alpha(rofi.get("background-alt", colors.get("bg1", "#21252b")))
        foreground = get_color_with_alpha(rofi.get("foreground", colors.get("fg", "#abb2bf")))
        selected = get_color_with_alpha(rofi.get("selected", colors.get("blue", "#61afef")))
        active = get_color_with_alpha(rofi.get("active", colors.get("green", "#98c379")))
        urgent = get_color_with_alpha(rofi.get("urgent", colors.get("red", "#e06c75")))
        
        # Ensure shared directory exists
        ROFI_SHARED_DIR.mkdir(parents=True, exist_ok=True)
        
        # Generate colors.rasi with direct color definitions (no @import)
        new_content = f'''/**
 *
 * Author : Aditya Shakya (adi1090x)
 * Github : @adi1090x
 * 
 * Colors - Auto-updated by Hyprland Control Center
 * Current Theme: {theme_name}
 *
 * Available Colors Schemes
 *
 * adapta    catppuccin    everforest    navy       paper
 * arc       cyberpunk     gruvbox       nord       solarized
 * black     dracula       lovelace      onedark    yousai
 *
 **/
* {{
    background:     {background};
    background-alt: {background_alt};
    foreground:     {foreground};
    selected:       {selected};
    active:         {active};
    urgent:         {urgent};
}}
'''
        
        try:
            with open(ROFI_COLORS_RASI, 'w') as f:
                f.write(new_content)
            return True
        except Exception as e:
            print(f"Error updating rofi colors.rasi: {e}")
            return False
    
    @staticmethod
    def apply_kitty_colors(theme_data):
        """Update Kitty colors using sed-like regex to modify kitty.conf directly"""
        kitty = theme_data.get("kitty", {})
        colors = theme_data.get("colors", {})
        
        if not KITTY_CONF.exists():
            print(f"Kitty config not found: {KITTY_CONF}")
            return False
        
        # Color mappings - kitty config key to theme value
        color_mappings = {
            "background": kitty.get("background", colors.get("bg0", "#282c34")),
            "foreground": kitty.get("foreground", colors.get("fg", "#abb2bf")),
            "cursor": kitty.get("cursor", colors.get("blue", "#61afef")),
            "selection_foreground": kitty.get("selection_foreground", colors.get("grey0", "#928374")),
            "selection_background": kitty.get("selection_background", colors.get("bg2", "#3c3836")),
            "color0": kitty.get("color0", colors.get("bg0", "#282c34")),
            "color1": kitty.get("color1", colors.get("red", "#e06c75")),
            "color2": kitty.get("color2", colors.get("green", "#98c379")),
            "color3": kitty.get("color3", colors.get("yellow", "#e5c07b")),
            "color4": kitty.get("color4", colors.get("blue", "#61afef")),
            "color5": kitty.get("color5", colors.get("purple", "#c678dd")),
            "color6": kitty.get("color6", colors.get("aqua", "#56b6c2")),
            "color7": kitty.get("color7", colors.get("fg", "#abb2bf")),
            "color8": kitty.get("color8", colors.get("grey0", "#5c6370")),
            "color9": kitty.get("color9", colors.get("red", "#e06c75")),
            "color10": kitty.get("color10", colors.get("green", "#98c379")),
            "color11": kitty.get("color11", colors.get("yellow", "#e5c07b")),
            "color12": kitty.get("color12", colors.get("blue", "#61afef")),
            "color13": kitty.get("color13", colors.get("purple", "#c678dd")),
            "color14": kitty.get("color14", colors.get("aqua", "#56b6c2")),
            "color15": kitty.get("color15", colors.get("grey0", "#5c6370")),
        }
        
        try:
            # Read current config
            with open(KITTY_CONF, 'r') as f:
                content = f.read()
            
            # Apply each color using sed-like replacement
            for key, value in color_mappings.items():
                # Pattern: key followed by spaces and any value until end of line
                # This handles "background  #282828" format
                pattern = rf'^({key}\s+)#?[a-fA-F0-9]+.*$'
                replacement = rf'\g<1>{value}'
                
                # Check if key exists in config
                if re.search(rf'^{key}\s+', content, re.MULTILINE):
                    content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            
            # Write updated config
            with open(KITTY_CONF, 'w') as f:
                f.write(content)
            
            return True
        except Exception as e:
            print(f"Error updating kitty.conf: {e}")
            return False
    
    @staticmethod
    def apply_control_center_theme(theme_data, window=None):
        """Apply theme to Control Center UI"""
        colors = theme_data.get("colors", {})
        
        # Generate CSS for Control Center
        css = f"""
/* Auto-generated Control Center Theme - {theme_data.get('name', 'Custom')} */
@define-color bg_color {colors.get('bg0', '#282c34')};
@define-color fg_color {colors.get('fg', '#abb2bf')};
@define-color accent_color {colors.get('blue', '#61afef')};
@define-color accent_bg_color {colors.get('blue', '#61afef')};
@define-color destructive_color {colors.get('red', '#e06c75')};
@define-color success_color {colors.get('green', '#98c379')};
@define-color warning_color {colors.get('yellow', '#e5c07b')};
@define-color error_color {colors.get('red', '#e06c75')};

@define-color window_bg_color {colors.get('bg0', '#282c34')};
@define-color window_fg_color {colors.get('fg', '#abb2bf')};
@define-color view_bg_color {colors.get('bg1', '#21252b')};
@define-color view_fg_color {colors.get('fg', '#abb2bf')};
@define-color headerbar_bg_color {colors.get('bg1', '#21252b')};
@define-color headerbar_fg_color {colors.get('fg', '#abb2bf')};
@define-color card_bg_color {colors.get('bg1', '#21252b')};
@define-color card_fg_color {colors.get('fg', '#abb2bf')};
@define-color sidebar_bg_color {colors.get('bg1', '#21252b')};
@define-color sidebar_fg_color {colors.get('fg', '#abb2bf')};

window, .background {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

.sidebar {{
    background-color: @sidebar_bg_color;
}}

.card {{
    background-color: @card_bg_color;
    border-radius: 12px;
}}

.suggested-action {{
    background-color: @accent_color;
    color: {colors.get('bg0', '#282c34')};
}}

.destructive-action {{
    background-color: @destructive_color;
    color: {colors.get('bg0', '#282c34')};
}}

headerbar {{
    background-color: @headerbar_bg_color;
}}
"""
        
        # Save to config directory
        css_file = CONFIG_DIR / "control-center-theme.css"
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(css_file, 'w') as f:
            f.write(css)
        
        # Apply CSS to window if provided
        if window:
            try:
                css_provider = Gtk.CssProvider()
                css_provider.load_from_data(css.encode())
                Gtk.StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                )
            except Exception as e:
                print(f"Error applying CSS to window: {e}")
        
        return True
    
    @staticmethod
    def reload_waybar():
        """Send SIGUSR2 to reload Waybar styles"""
        try:
            subprocess.run(["pkill", "-SIGUSR2", "waybar"], check=False)
            return True
        except:
            return False
    
    @staticmethod
    def reload_kitty():
        """Send USR1 to reload Kitty config"""
        try:
            subprocess.run(["pkill", "-USR1", "kitty"], check=False)
            return True
        except:
            return False
    
    @staticmethod
    def notify(title, message, icon="preferences-desktop-theme"):
        """Send desktop notification"""
        try:
            subprocess.run(["notify-send", "-a", "Hyprland Control Center", "-i", icon, title, message], check=False)
        except:
            pass

# ═══════════════════════════════════════════════════════════════════════════════
# PREVIEW WIDGETS
# ═══════════════════════════════════════════════════════════════════════════════

def _hex_to_rgba(hex_color, alpha=1.0):
    h = hex_color.lstrip('#')[:6]
    if len(h) >= 6:
        r, g, b = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
        return (r, g, b, alpha)
    return (0.5, 0.5, 0.5, alpha)

def _draw_rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi/2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi/2)
    cr.arc(x + r, y + h - r, r, math.pi/2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3*math.pi/2)
    cr.close_path()

class WaybarPreviewWidget(Gtk.DrawingArea):
    def __init__(self, colors, waybar_config):
        super().__init__()
        self.colors = colors.copy()
        self.waybar_config = waybar_config.copy()
        self.hover = "normal"
        self.set_content_width(540)
        self.set_content_height(48)
        self.set_draw_func(self._draw)
        motion = Gtk.EventControllerMotion()
        motion.connect("motion", lambda c, x, y: (setattr(self, 'hover', 'hover' if 10 <= x <= 140 else 'normal'), self.queue_draw()))
        motion.connect("leave", lambda c: (setattr(self, 'hover', 'normal'), self.queue_draw()))
        self.add_controller(motion)
    
    def _draw(self, area, cr, w, h):
        opacity = self.waybar_config.get("global", {}).get("window_opacity", 0.5)
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg0", "#282c34"), opacity))
        _draw_rounded_rect(cr, 2, 2, w - 4, h - 4, 20)
        cr.fill()
        ws = self.waybar_config.get("workspaces", {})
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg0", "#282c34"), ws.get("container_opacity", 0.21)))
        _draw_rounded_rect(cr, 10, 6, 120, h - 12, 10)
        cr.fill()
        states = ["normal", "hover", "active", "urgent"] if self.hover == "hover" else ["normal", "normal", "active", "normal"]
        bx = 14
        for i, st in enumerate(states):
            bw = 30 if st != "normal" else 22
            bg_map = {"active": ws.get("button_active_bg", "blue"), "hover": ws.get("button_hover_bg", "purple"),
                      "urgent": ws.get("button_urgent_bg", "red"), "normal": ws.get("button_normal_bg", "bg1")}
            cr.set_source_rgba(*_hex_to_rgba(self.colors.get(bg_map.get(st, "bg1"), "#21252b")))
            _draw_rounded_rect(cr, bx, 9, bw, h - 18, 6)
            cr.fill()
            if st != "normal":
                cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg0", "#282c34")))
                cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
                cr.set_font_size(8)
                cr.move_to(bx + bw/2 - 3, h/2 + 3)
                cr.show_text(str(i + 1))
            bx += bw + 4
        mods = self.waybar_config.get("modules", {})
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg0", "#282c34"), 0.9))
        _draw_rounded_rect(cr, w/2 - 25, 6, 50, h - 12, 10)
        cr.fill()
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get(mods.get("clock", {}).get("color", "blue"), "#61afef")))
        cr.set_font_size(9)
        cr.move_to(w/2 - 15, h/2 + 3)
        cr.show_text("12:45")
        mx = w - 180
        for icon, col in [("C", mods.get("cpu", {}).get("color", "blue")), ("M", mods.get("memory", {}).get("color", "green")),
                          ("V", mods.get("pulseaudio", {}).get("color", "yellow")), ("N", mods.get("network", {}).get("wifi", "purple")),
                          ("B", mods.get("battery", {}).get("color", "green"))]:
            cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg0", "#282c34"), 0.9))
            _draw_rounded_rect(cr, mx, 6, 28, h - 12, 8)
            cr.fill()
            cr.set_source_rgba(*_hex_to_rgba(self.colors.get(col, "#61afef")))
            cr.set_font_size(8)
            cr.move_to(mx + 10, h/2 + 3)
            cr.show_text(icon)
            mx += 32
    
    def update_colors(self, colors): self.colors = colors.copy(); self.queue_draw()
    def update_waybar_config(self, cfg): self.waybar_config = cfg.copy(); self.queue_draw()

class RofiPreviewWidget(Gtk.DrawingArea):
    def __init__(self, colors, rofi_config):
        super().__init__()
        self.colors = colors.copy()
        self.rofi = rofi_config.copy()
        self.set_content_width(240)
        self.set_content_height(140)
        self.set_draw_func(self._draw)
    
    def _get_color(self, name):
        if name in self.rofi:
            c = self.rofi[name]
            return c[:7] if len(c) == 9 else c
        return self.colors.get(name, "#888888")
    
    def _draw(self, area, cr, w, h):
        bg, bg_alt, fg, sel = self._get_color("background"), self._get_color("background-alt"), self._get_color("foreground"), self._get_color("selected")
        cr.set_source_rgba(*_hex_to_rgba(bg))
        _draw_rounded_rect(cr, 0, 0, w, h, 8)
        cr.fill()
        cr.set_source_rgba(*_hex_to_rgba(sel))
        _draw_rounded_rect(cr, 0, 0, w, h, 8)
        cr.set_line_width(2)
        cr.stroke()
        cr.set_source_rgba(*_hex_to_rgba(bg_alt))
        _draw_rounded_rect(cr, 10, 10, w - 20, 24, 5)
        cr.fill()
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(9)
        cr.move_to(16, 27)
        cr.show_text("Search...")
        iy = 44
        for i, name in enumerate(["Firefox", "VS Code", "Kitty"]):
            if i == 1:
                cr.set_source_rgba(*_hex_to_rgba(sel))
                _draw_rounded_rect(cr, 10, iy, w - 20, 24, 5)
                cr.fill()
                cr.set_source_rgba(*_hex_to_rgba(bg))
            else:
                cr.set_source_rgba(*_hex_to_rgba(fg))
            cr.set_font_size(9)
            cr.move_to(16, iy + 16)
            cr.show_text(name)
            iy += 30
    
    def update_rofi(self, rofi): self.rofi = rofi.copy(); self.queue_draw()
    def update_colors(self, colors): self.colors = colors.copy(); self.queue_draw()

class KittyPreviewWidget(Gtk.DrawingArea):
    def __init__(self, colors, kitty_config):
        super().__init__()
        self.colors = colors.copy()
        self.kitty = kitty_config.copy()
        self.set_content_width(240)
        self.set_content_height(110)
        self.set_draw_func(self._draw)
    
    def _get_color(self, name): return self.kitty.get(name, self.colors.get(name, "#888888"))
    
    def _draw(self, area, cr, w, h):
        bg, fg, cursor = self._get_color("background"), self._get_color("foreground"), self._get_color("cursor")
        green, blue = self._get_color("color2"), self._get_color("color4")
        cr.set_source_rgba(*_hex_to_rgba(bg, 0.95))
        _draw_rounded_rect(cr, 0, 0, w, h, 6)
        cr.fill()
        cr.set_source_rgba(*_hex_to_rgba(self.colors.get("bg3", "#444")))
        _draw_rounded_rect(cr, 0, 0, w, h, 6)
        cr.set_line_width(1)
        cr.stroke()
        cr.select_font_face("Monospace", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(8)
        y = 14
        cr.set_source_rgba(*_hex_to_rgba(green))
        cr.move_to(6, y)
        cr.show_text("user@arch")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text(" ~ $ neofetch")
        y += 12
        cr.set_source_rgba(*_hex_to_rgba(blue))
        cr.move_to(6, y)
        cr.show_text("    ████")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text("  OS: Arch Linux")
        y += 12
        cr.set_source_rgba(*_hex_to_rgba(blue))
        cr.move_to(6, y)
        cr.show_text("    ████")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text("  WM: Hyprland")
        y += 16
        cr.set_source_rgba(*_hex_to_rgba(green))
        cr.move_to(6, y)
        cr.show_text("user@arch")
        cr.set_source_rgba(*_hex_to_rgba(fg))
        cr.show_text(" ~ $ ")
        ext = cr.text_extents("user@arch ~ $ ")
        cr.set_source_rgba(*_hex_to_rgba(cursor))
        cr.rectangle(6 + ext.width, y - 8, 6, 10)
        cr.fill()
    
    def update_kitty(self, kitty): self.kitty = kitty.copy(); self.queue_draw()
    def update_colors(self, colors): self.colors = colors.copy(); self.queue_draw()

# ═══════════════════════════════════════════════════════════════════════════════
# UI COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════

class ColorPickerRow(Gtk.Box):
    def __init__(self, label, color_key, hex_value, on_change):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.color_key = color_key
        self.on_change = on_change
        self.hex_value = hex_value
        self.set_margin_start(8); self.set_margin_end(8); self.set_margin_top(4); self.set_margin_bottom(4)
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(24); self.swatch.set_content_height(24)
        self.swatch.set_draw_func(self._draw_swatch)
        click = Gtk.GestureClick()
        click.connect("pressed", self._on_click)
        self.swatch.add_controller(click)
        self.append(self.swatch)
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0); lbl.set_size_request(90, -1)
        self.append(lbl)
        self.entry = Gtk.Entry()
        self.entry.set_text(hex_value)
        self.entry.set_max_length(7); self.entry.set_width_chars(9)
        self.entry.connect("changed", self._on_entry)
        self.append(self.entry)
    
    def _draw_swatch(self, area, cr, w, h):
        hc = self.hex_value.lstrip('#')
        r, g, b = tuple(int(hc[i:i+2], 16) / 255.0 for i in (0, 2, 4)) if len(hc) >= 6 else (0.5, 0.5, 0.5)
        cr.set_source_rgb(r, g, b)
        _draw_rounded_rect(cr, 0, 0, w, h, 5)
        cr.fill()
    
    def _on_click(self, gesture, n, x, y):
        dialog = Gtk.ColorChooserDialog(title=f"Choose {self.color_key}", transient_for=self.get_root(), use_alpha=False)
        rgba = Gdk.RGBA(); rgba.parse(self.hex_value)
        dialog.set_rgba(rgba)
        dialog.connect("response", self._on_color)
        dialog.present()
    
    def _on_color(self, dialog, response):
        if response == Gtk.ResponseType.OK:
            rgba = dialog.get_rgba()
            self.hex_value = "#{:02x}{:02x}{:02x}".format(int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255))
            self.entry.set_text(self.hex_value)
            self.swatch.queue_draw()
            self.on_change(self.color_key, self.hex_value)
        dialog.destroy()
    
    def _on_entry(self, entry):
        t = entry.get_text()
        if len(t) == 7 and t.startswith('#'):
            try:
                int(t[1:], 16)
                self.hex_value = t
                self.swatch.queue_draw()
                self.on_change(self.color_key, t)
            except: pass

class ColorVariableDropdown(Gtk.Box):
    def __init__(self, label, current, colors, on_change):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.colors = colors
        self.on_change = on_change
        self.config_key = label.lower().replace(" ", "_")
        self.current = current
        self.set_margin_start(8); self.set_margin_end(8); self.set_margin_top(4); self.set_margin_bottom(4)
        lbl = Gtk.Label(label=label)
        lbl.set_xalign(0); lbl.set_size_request(110, -1)
        self.append(lbl)
        self.swatch = Gtk.DrawingArea()
        self.swatch.set_content_width(18); self.swatch.set_content_height(18)
        self.swatch.set_draw_func(self._draw)
        self.append(self.swatch)
        self.dropdown = Gtk.DropDown()
        model = Gtk.StringList()
        for opt in COLOR_OPTIONS: model.append(opt)
        self.dropdown.set_model(model)
        try: self.dropdown.set_selected(COLOR_OPTIONS.index(current))
        except: self.dropdown.set_selected(0)
        self.dropdown.connect("notify::selected", self._on_changed)
        self.append(self.dropdown)
    
    def _draw(self, area, cr, w, h):
        c = self.colors.get(self.current, "#888888")
        hc = c.lstrip('#')
        r, g, b = tuple(int(hc[i:i+2], 16) / 255.0 for i in (0, 2, 4)) if len(hc) >= 6 else (0.5, 0.5, 0.5)
        cr.set_source_rgb(r, g, b)
        cr.arc(w/2, h/2, min(w, h)/2 - 1, 0, 2 * math.pi)
        cr.fill()
    
    def _on_changed(self, dd, pspec):
        idx = dd.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION:
            self.current = COLOR_OPTIONS[idx]
            self.swatch.queue_draw()
            self.on_change(self.config_key, self.current)
    
    def update_colors(self, colors): self.colors = colors; self.swatch.queue_draw()

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def _create_group(title):
    group = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    group.add_css_class("card"); group.set_margin_bottom(8)
    lbl = Gtk.Label(label=title)
    lbl.add_css_class("caption"); lbl.set_xalign(0)
    lbl.set_margin_start(16); lbl.set_margin_top(12); lbl.set_margin_bottom(4)
    group.append(lbl)
    return group

def _create_swatch(key, label, hex_color):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.set_halign(Gtk.Align.CENTER)
    swatch = Gtk.DrawingArea()
    swatch.set_content_width(40); swatch.set_content_height(40)
    swatch.hex_color = hex_color
    def draw(area, cr, w, h):
        hc = area.hex_color.lstrip('#')
        r, g, b = tuple(int(hc[i:i+2], 16) / 255.0 for i in (0, 2, 4)) if len(hc) >= 6 else (0.5, 0.5, 0.5)
        cr.set_source_rgb(r, g, b)
        _draw_rounded_rect(cr, 0, 0, w, h, 6)
        cr.fill()
    swatch.set_draw_func(draw)
    box.append(swatch)
    lbl = Gtk.Label(label=label)
    lbl.add_css_class("caption"); lbl.add_css_class("dim-label")
    box.append(lbl)
    box.swatch = swatch
    return box

def _refresh_ui(window, pm):
    theme = pm.get_active_theme()
    colors = theme.get("colors", BUILTIN_THEMES["one-dark"]["colors"])
    waybar = theme.get("waybar", DEFAULT_WAYBAR_CONFIG)
    rofi = theme.get("rofi", {})
    kitty = theme.get("kitty", {})
    window.current_theme_colors = colors.copy()
    window.current_waybar_config = waybar.copy()
    window.current_rofi_config = rofi.copy()
    window.current_kitty_config = kitty.copy()
    if hasattr(window, 'color_swatches'):
        for k, box in window.color_swatches.items():
            if k in colors: box.swatch.hex_color = colors[k]; box.swatch.queue_draw()
    if hasattr(window, 'waybar_preview'):
        window.waybar_preview.update_colors(colors)
        window.waybar_preview.update_waybar_config(waybar)
    if hasattr(window, 'rofi_preview'):
        window.rofi_preview.update_colors(colors)
        window.rofi_preview.update_rofi(rofi)
    if hasattr(window, 'kitty_preview'):
        window.kitty_preview.update_colors(colors)
        window.kitty_preview.update_kitty(kitty)

def _refresh_dropdown(window, pm):
    all_themes = pm.get_all_themes()
    window.all_themes = all_themes
    model = Gtk.StringList()
    active_idx = 0
    active_id = pm.profiles.get("active_profile", "one-dark")
    for i, t in enumerate(all_themes):
        model.append(f"{'● ' if t['is_builtin'] else '◆ '}{t['name']}")
        if t["id"] == active_id: active_idx = i
    window.theme_dropdown.set_model(model)
    window.theme_dropdown.set_selected(active_idx)
    if hasattr(window, 'delete_btn') and active_idx < len(all_themes):
        window.delete_btn.set_sensitive(not all_themes[active_idx]["is_builtin"])

def _apply_theme(window, pm):
    """Apply theme to all applications"""
    theme = pm.get_active_theme()
    data = {"id": theme.get("id", "custom"), "name": theme.get("name", "Custom"),
            "colors": window.current_theme_colors, "waybar": window.current_waybar_config,
            "rofi": window.current_rofi_config, "kitty": window.current_kitty_config}
    if not theme.get("is_builtin", True): 
        pm.update_custom_theme(theme.get("id"), data)
    results = []
    if ThemeApplier.apply_waybar_colorscheme(data): 
        results.append("Waybar")
        ThemeApplier.reload_waybar()
    if ThemeApplier.apply_rofi_colors(data): 
        results.append("Rofi")
    if ThemeApplier.apply_kitty_colors(data): 
        results.append("Kitty")
        ThemeApplier.reload_kitty()
    if ThemeApplier.apply_control_center_theme(data, window):
        results.append("Control Center")
    if results: 
        ThemeApplier.notify("Theme Applied", f"Updated: {', '.join(results)}")

def _reset_theme(window, pm):
    pm.set_active_theme("one-dark", True)
    _refresh_dropdown(window, pm)
    _refresh_ui(window, pm)
    ThemeApplier.notify("Theme Reset", "Reset to One Dark")

# ═══════════════════════════════════════════════════════════════════════════════
# DIALOGS
# ═══════════════════════════════════════════════════════════════════════════════

def _show_new_dialog(window, pm):
    dialog = Adw.MessageDialog(transient_for=window, heading="Create New Profile", body="Enter name:")
    entry = Gtk.Entry(); entry.set_placeholder_text("My Custom Theme")
    entry.set_margin_start(24); entry.set_margin_end(24)
    dialog.set_extra_child(entry)
    dialog.add_response("cancel", "Cancel"); dialog.add_response("create", "Create")
    dialog.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED)
    def on_response(d, r):
        if r == "create" and entry.get_text().strip():
            tid = pm.create_custom_theme(entry.get_text().strip(), pm.get_active_theme().get("id", "one-dark"))
            pm.set_active_theme(tid, False)
            _refresh_dropdown(window, pm)
            ThemeApplier.notify("Profile Created", f"Created: {entry.get_text().strip()}")
        d.destroy()
    dialog.connect("response", on_response)
    dialog.present()

def _show_save_dialog(window, pm):
    dialog = Adw.MessageDialog(transient_for=window, heading="Save As Custom", body="Enter name:")
    entry = Gtk.Entry(); entry.set_placeholder_text("My Custom Theme")
    entry.set_margin_start(24); entry.set_margin_end(24)
    dialog.set_extra_child(entry)
    dialog.add_response("cancel", "Cancel"); dialog.add_response("save", "Save")
    dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED)
    def on_response(d, r):
        if r == "save" and entry.get_text().strip():
            tid = pm.create_custom_theme(entry.get_text().strip(), pm.get_active_theme().get("id"))
            pm.update_custom_theme(tid, {"colors": window.current_theme_colors, "waybar": window.current_waybar_config,
                                         "rofi": window.current_rofi_config, "kitty": window.current_kitty_config})
            pm.set_active_theme(tid, False)
            _refresh_dropdown(window, pm)
            ThemeApplier.notify("Profile Saved", f"Saved: {entry.get_text().strip()}")
        d.destroy()
    dialog.connect("response", on_response)
    dialog.present()

def _show_export_dialog(window, pm):
    dialog = Gtk.FileChooserDialog(title="Export Theme", transient_for=window, action=Gtk.FileChooserAction.SAVE)
    dialog.add_button("Cancel", Gtk.ResponseType.CANCEL); dialog.add_button("Export", Gtk.ResponseType.ACCEPT)
    dialog.set_current_name(f"{pm.get_active_theme().get('id', 'theme')}.json")
    filt = Gtk.FileFilter(); filt.set_name("JSON"); filt.add_pattern("*.json"); dialog.add_filter(filt)
    def on_response(d, r):
        if r == Gtk.ResponseType.ACCEPT and d.get_file():
            if pm.export_theme(pm.get_active_theme().get("id"), Path(d.get_file().get_path())):
                ThemeApplier.notify("Export Complete", "Theme exported")
        d.destroy()
    dialog.connect("response", on_response)
    dialog.present()

def _show_import_dialog(window, pm):
    dialog = Gtk.FileChooserDialog(title="Import Theme", transient_for=window, action=Gtk.FileChooserAction.OPEN)
    dialog.add_button("Cancel", Gtk.ResponseType.CANCEL); dialog.add_button("Import", Gtk.ResponseType.ACCEPT)
    filt = Gtk.FileFilter(); filt.set_name("JSON"); filt.add_pattern("*.json"); dialog.add_filter(filt)
    def on_response(d, r):
        if r == Gtk.ResponseType.ACCEPT and d.get_file():
            tid = pm.import_theme(Path(d.get_file().get_path()))
            if tid:
                pm.set_active_theme(tid, False)
                _refresh_dropdown(window, pm)
                _refresh_ui(window, pm)
                ThemeApplier.notify("Import Complete", "Theme imported")
        d.destroy()
    dialog.connect("response", on_response)
    dialog.present()

def _show_delete_dialog(window, pm):
    theme = pm.get_active_theme()
    if theme.get("is_builtin", True):
        ThemeApplier.notify("Cannot Delete", "Built-in profiles cannot be deleted"); return
    dialog = Adw.MessageDialog(transient_for=window, heading="Delete Profile?",
                               body=f"Delete '{theme.get('name')}'? This cannot be undone.")
    dialog.add_response("cancel", "Cancel"); dialog.add_response("delete", "Delete")
    dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE)
    def on_response(d, r):
        if r == "delete":
            pm.delete_custom_theme(theme.get("id"))
            _refresh_dropdown(window, pm)
            _refresh_ui(window, pm)
            ThemeApplier.notify("Profile Deleted", "Custom profile removed")
        d.destroy()
    dialog.connect("response", on_response)
    dialog.present()

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_theming_page(window) -> Gtk.ScrolledWindow:
    """Build the Theming configuration page - MAIN ENTRY POINT"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    header.set_margin_start(32); header.set_margin_end(32); header.set_margin_top(24); header.set_margin_bottom(16)
    title = Gtk.Label(label="Theming"); title.add_css_class('title-1'); title.set_xalign(0)
    header.append(title)
    subtitle = Gtk.Label(label="Customize themes for Waybar, Rofi, Kitty, and Control Center")
    subtitle.add_css_class('dim-label'); subtitle.set_xalign(0)
    header.append(subtitle)
    content.append(header)
    pm = ThemeProfileManager()
    window.theme_profile_manager = pm
    main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    main.set_margin_start(32); main.set_margin_end(32); main.set_margin_bottom(32)
    theme = pm.get_active_theme()
    colors = theme.get("colors", BUILTIN_THEMES["one-dark"]["colors"])
    waybar_cfg = theme.get("waybar", DEFAULT_WAYBAR_CONFIG)
    rofi_cfg = theme.get("rofi", BUILTIN_THEMES["one-dark"]["rofi"])
    kitty_cfg = theme.get("kitty", BUILTIN_THEMES["one-dark"]["kitty"])
    window.current_theme_colors = colors.copy()
    window.current_waybar_config = waybar_cfg.copy()
    window.current_rofi_config = rofi_cfg.copy()
    window.current_kitty_config = kitty_cfg.copy()
    
    # Profile Management
    prof_group = _create_group("PROFILE MANAGEMENT")
    prof_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    prof_row.set_margin_start(16); prof_row.set_margin_end(16); prof_row.set_margin_top(12); prof_row.set_margin_bottom(8)
    prof_row.append(Gtk.Label(label="Active Profile"))
    prof_row.append(Gtk.Box(hexpand=True))
    all_themes = pm.get_all_themes()
    dropdown = Gtk.DropDown()
    model = Gtk.StringList()
    active_idx = 0
    active_id = pm.profiles.get("active_profile", "one-dark")
    for i, t in enumerate(all_themes):
        model.append(f"{'● ' if t['is_builtin'] else '◆ '}{t['name']}")
        if t["id"] == active_id: active_idx = i
    dropdown.set_model(model); dropdown.set_selected(active_idx)
    window.theme_dropdown = dropdown; window.all_themes = all_themes
    prof_row.append(dropdown)
    new_btn = Gtk.Button(); new_btn.set_icon_name("list-add-symbolic"); new_btn.set_tooltip_text("New Profile")
    new_btn.connect("clicked", lambda b: _show_new_dialog(window, pm))
    prof_row.append(new_btn)
    prof_group.append(prof_row)
    acts = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    acts.set_margin_start(16); acts.set_margin_end(16); acts.set_margin_bottom(12)
    save_btn = Gtk.Button(label="Save As"); save_btn.connect("clicked", lambda b: _show_save_dialog(window, pm)); acts.append(save_btn)
    exp_btn = Gtk.Button(label="Export"); exp_btn.connect("clicked", lambda b: _show_export_dialog(window, pm)); acts.append(exp_btn)
    imp_btn = Gtk.Button(label="Import"); imp_btn.connect("clicked", lambda b: _show_import_dialog(window, pm)); acts.append(imp_btn)
    acts.append(Gtk.Box(hexpand=True))
    del_btn = Gtk.Button(label="Delete"); del_btn.add_css_class("destructive-action")
    del_btn.set_sensitive(not all_themes[active_idx]["is_builtin"] if all_themes else False)
    del_btn.connect("clicked", lambda b: _show_delete_dialog(window, pm))
    window.delete_btn = del_btn; acts.append(del_btn)
    prof_group.append(acts)
    main.append(prof_group)
    
    # Theme Preview
    prev_group = _create_group("THEME PREVIEW")
    swatches = Gtk.FlowBox()
    swatches.set_selection_mode(Gtk.SelectionMode.NONE)
    swatches.set_max_children_per_line(9); swatches.set_min_children_per_line(5)
    swatches.set_margin_start(16); swatches.set_margin_end(16); swatches.set_margin_top(12); swatches.set_margin_bottom(16)
    swatches.set_row_spacing(8); swatches.set_column_spacing(8)
    window.color_swatches = {}
    for key, label in [("bg0", "Background"), ("fg", "Text"), ("blue", "Accent"), ("red", "Alert"),
                       ("green", "Success"), ("orange", "Orange"), ("yellow", "Yellow"), ("aqua", "Aqua"), ("purple", "Purple")]:
        box = _create_swatch(key, label, colors.get(key, "#888888"))
        window.color_swatches[key] = box
        swatches.append(box)
    prev_group.append(swatches)
    main.append(prev_group)
    
    # App Customization
    apps_group = _create_group("APPLICATION CUSTOMIZATION")
    
    # Waybar
    wb_exp = Gtk.Expander(label="󰍹 Waybar")
    wb_exp.set_margin_start(16); wb_exp.set_margin_end(16); wb_exp.set_margin_top(8)
    wb_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    wb_content.set_margin_start(16); wb_content.set_margin_top(8); wb_content.set_margin_bottom(8)
    wb_preview = WaybarPreviewWidget(colors, waybar_cfg)
    window.waybar_preview = wb_preview
    wb_frame = Gtk.Frame(); wb_frame.set_child(wb_preview); wb_content.append(wb_frame)
    hint = Gtk.Label(label="Hover workspaces to see hover state"); hint.add_css_class("dim-label"); wb_content.append(hint)
    wb_content.append(Gtk.Label(label="WORKSPACE COLORS", xalign=0))
    ws_cfg = waybar_cfg.get("workspaces", {})
    def on_ws(key, val):
        if "workspaces" not in window.current_waybar_config: window.current_waybar_config["workspaces"] = {}
        window.current_waybar_config["workspaces"]["button_" + key] = val
        window.waybar_preview.update_waybar_config(window.current_waybar_config)
    for lbl, cur in [("Hover Background", ws_cfg.get("button_hover_bg", "purple")),
                     ("Active Background", ws_cfg.get("button_active_bg", "blue")),
                     ("Urgent Background", ws_cfg.get("button_urgent_bg", "red"))]:
        wb_content.append(ColorVariableDropdown(lbl, cur, colors, on_ws))
    wb_content.append(Gtk.Label(label="MODULE COLORS", xalign=0))
    mods_cfg = waybar_cfg.get("modules", {})
    def on_mod(key, val):
        if "modules" not in window.current_waybar_config: window.current_waybar_config["modules"] = {}
        mod = key.split("_")[0]
        if mod not in window.current_waybar_config["modules"]: window.current_waybar_config["modules"][mod] = {}
        window.current_waybar_config["modules"][mod]["color"] = val
        window.waybar_preview.update_waybar_config(window.current_waybar_config)
    for lbl, cur in [("CPU Color", mods_cfg.get("cpu", {}).get("color", "blue")),
                     ("Memory Color", mods_cfg.get("memory", {}).get("color", "green")),
                     ("Clock Color", mods_cfg.get("clock", {}).get("color", "blue")),
                     ("Network Color", mods_cfg.get("network", {}).get("wifi", "purple"))]:
        wb_content.append(ColorVariableDropdown(lbl, cur, colors, on_mod))
    wb_exp.set_child(wb_content)
    apps_group.append(wb_exp)
    
    # Rofi
    rf_exp = Gtk.Expander(label="󱃧 Rofi")
    rf_exp.set_margin_start(16); rf_exp.set_margin_end(16); rf_exp.set_margin_top(8)
    rf_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    rf_content.set_margin_start(16); rf_content.set_margin_top(8); rf_content.set_margin_bottom(8)
    rf_preview = RofiPreviewWidget(colors, rofi_cfg)
    window.rofi_preview = rf_preview
    rf_frame = Gtk.Frame(); rf_frame.set_child(rf_preview); rf_content.append(rf_frame)
    rf_info = Gtk.Label(label="Writes colors directly to ~/.config/rofi/zenpy-rofi/shared/colors.rasi")
    rf_info.add_css_class("dim-label"); rf_info.set_xalign(0)
    rf_content.append(rf_info)
    rf_content.append(Gtk.Label(label="PREVIEW COLORS", xalign=0))
    def on_rofi(key, val):
        window.current_rofi_config[key] = val
        window.rofi_preview.update_rofi(window.current_rofi_config)
    for lbl, key, cur in [("Background", "background", rofi_cfg.get("background", colors.get("bg0"))),
                          ("Selected", "selected", rofi_cfg.get("selected", colors.get("blue"))),
                          ("Foreground", "foreground", rofi_cfg.get("foreground", colors.get("fg")))]:
        cur = cur[:7] if len(cur) == 9 else cur
        rf_content.append(ColorPickerRow(lbl, key, cur, on_rofi))
    rf_exp.set_child(rf_content)
    apps_group.append(rf_exp)
    
    # Kitty
    kt_exp = Gtk.Expander(label="󰆍 Kitty Terminal")
    kt_exp.set_margin_start(16); kt_exp.set_margin_end(16); kt_exp.set_margin_top(8); kt_exp.set_margin_bottom(8)
    kt_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    kt_content.set_margin_start(16); kt_content.set_margin_top(8); kt_content.set_margin_bottom(8)
    kt_preview = KittyPreviewWidget(colors, kitty_cfg)
    window.kitty_preview = kt_preview
    kt_frame = Gtk.Frame(); kt_frame.set_child(kt_preview); kt_content.append(kt_frame)
    kt_info = Gtk.Label(label="Updates color values directly in ~/.config/kitty/kitty.conf")
    kt_info.add_css_class("dim-label"); kt_info.set_xalign(0)
    kt_content.append(kt_info)
    kt_content.append(Gtk.Label(label="TERMINAL COLORS", xalign=0))
    def on_kitty(key, val):
        window.current_kitty_config[key] = val
        window.kitty_preview.update_kitty(window.current_kitty_config)
    for lbl, key, cur in [("Background", "background", kitty_cfg.get("background", "#282c34")),
                          ("Foreground", "foreground", kitty_cfg.get("foreground", "#abb2bf")),
                          ("Cursor", "cursor", kitty_cfg.get("cursor", "#61afef"))]:
        kt_content.append(ColorPickerRow(lbl, key, cur, on_kitty))
    kt_exp.set_child(kt_content)
    apps_group.append(kt_exp)
    main.append(apps_group)
    
    # Apply Buttons
    apply_group = _create_group("APPLY CHANGES")
    apply_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    apply_row.set_margin_start(16); apply_row.set_margin_end(16); apply_row.set_margin_top(12); apply_row.set_margin_bottom(16)
    apply_btn = Gtk.Button(label="󰄬 Apply Theme"); apply_btn.add_css_class("suggested-action")
    apply_btn.connect("clicked", lambda b: _apply_theme(window, pm))
    apply_row.append(apply_btn)
    apply_row.append(Gtk.Box(hexpand=True))
    reset_btn = Gtk.Button(label="Reset to Default")
    reset_btn.connect("clicked", lambda b: _reset_theme(window, pm))
    apply_row.append(reset_btn)
    apply_group.append(apply_row)
    main.append(apply_group)
    
    # Info
    info_group = _create_group("APPLIES TO")
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    info_box.set_margin_start(16); info_box.set_margin_end(16); info_box.set_margin_top(8); info_box.set_margin_bottom(12)
    for item in ["✓ Waybar Panel (colorscheme CSS)", "✓ Rofi Launcher (direct color write to zenpy-rofi/shared/colors.rasi)", 
                 "✓ Kitty Terminal (config sed update)", "✓ Control Center UI"]:
        lbl = Gtk.Label(label=item, xalign=0)
        lbl.add_css_class("dim-label")
        info_box.append(lbl)
    info_group.append(info_box)
    main.append(info_group)
    content.append(main)
    
    def on_profile_changed(dd, pspec):
        idx = dd.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION and idx < len(window.all_themes):
            t = window.all_themes[idx]
            pm.set_active_theme(t["id"], t["is_builtin"])
            _refresh_ui(window, pm)
            window.delete_btn.set_sensitive(not t["is_builtin"])
            
            # Auto-apply rofi theme when dropdown selection changes
            theme_data = pm.get_active_theme()
            ThemeApplier.apply_rofi_colors(theme_data)
            
    dropdown.connect("notify::selected", on_profile_changed)
    scrolled.set_child(content)
    return scrolled