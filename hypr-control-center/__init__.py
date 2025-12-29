"""
Page modules for different settings sections
"""

from .appearance import build_appearance_page
from .placeholders import (
    build_panel_page,
    build_workspaces_page,
    build_animations_page,
    build_input_page,
    build_monitors_page,
    build_keybinds_page
)

__all__ = [
    'build_appearance_page',
    'build_panel_page',
    'build_workspaces_page',
    'build_animations_page',
    'build_input_page',
    'build_monitors_page',
    'build_keybinds_page'
]
