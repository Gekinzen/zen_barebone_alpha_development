"""
THEMING MODULE v2.0 - Complete Theme + Panel Appearance

Applies themes to: Control Center, Waybar, Rofi, Kitty
Panel Appearance: Opacity, Radius, Font, Height, Margins, Monitor

Installation:
    ~/.config/hypr-control-center/src/pages/theming/

Usage:
    from .pages.theming import build_theming_page
    self.stack.add_named(build_theming_page(self), "theming")
"""

from .page import build_theming_page, get_monitor_list
from .themes import THEMES, get_theme_list, get_theme_colors
from .theme_applier import ThemeApplier

__all__ = [
    'build_theming_page',
    'get_monitor_list',
    'THEMES',
    'get_theme_list', 
    'get_theme_colors',
    'ThemeApplier',
]
