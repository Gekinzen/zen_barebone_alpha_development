"""
ZenPyBar Core Framework v2.0
============================

A complete Python-based Waybar replacement with:
- Automatic Waybar config sync
- Theme icon integration
- Pin/Unpin functionality (Windows-style)
- Multi-monitor support
- Real-time IPC updates

Author: Paul (ZenPyBar Project)
"""

__version__ = "2.0.0"
__author__ = "Paul"

from .config_manager import ConfigManager
from .theme_manager import ThemeManager
from .waybar_sync import WaybarSync
from .icon_resolver import IconResolver
from .pinned_manager import PinnedManager
from .window_tracker import WindowTracker

__all__ = [
    'ConfigManager',
    'ThemeManager', 
    'WaybarSync',
    'IconResolver',
    'PinnedManager',
    'WindowTracker',
]