"""
ZenPyBar - Python Waybar Replacement
=====================================

A full GTK4 bar that reads Waybar config.jsonc and style.css

Features:
- Drop-in Waybar replacement
- Same config format
- Real PNG icons for taskbar
- Full Hyprland integration
"""

__version__ = "0.1.0"
__author__ = "Paul"

from .bar import ZenPyBar
from .config_parser import ConfigParser

__all__ = ['ZenPyBar', 'ConfigParser']
