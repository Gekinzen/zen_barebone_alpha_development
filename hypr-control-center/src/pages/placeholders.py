"""
Placeholder pages for upcoming features
"""

from ..widgets import PlaceholderPage

def build_panel_page(window):
    """Build Panel (Waybar) placeholder page"""
    return PlaceholderPage(
        "Panel",
        "view-paged-symbolic",
        "Configure Waybar position, size, margins, and dock mode for a customized status bar experience."
    )

def build_workspaces_page(window):
    """Build Workspaces placeholder page"""
    return PlaceholderPage(
        "Workspaces",
        "view-grid-symbolic",
        "Configure workspace rules, monitor assignments, and persistent workspace behavior."
    )

def build_animations_page(window):
    """Build Animations placeholder page"""
    return PlaceholderPage(
        "Animations",
        "preferences-desktop-effects-symbolic",
        "Configure window animations, bezier curves, and transition effects for a smooth desktop experience."
    )

def build_input_page(window):
    """Build Input Devices placeholder page"""
    return PlaceholderPage(
        "Input Devices",
        "input-keyboard-symbolic",
        "Configure keyboard layouts, mouse sensitivity, touchpad gestures, and other input device settings."
    )

def build_monitors_page(window):
    """Build Monitors placeholder page"""
    return PlaceholderPage(
        "Monitors",
        "video-display-symbolic",
        "Configure monitor resolution, position, scale, and rotation for multi-display setups."
    )

def build_keybinds_page(window):
    """Build Keybinds placeholder page"""
    return PlaceholderPage(
        "Keybinds",
        "preferences-desktop-keyboard-shortcuts-symbolic",
        "Customize keyboard shortcuts for window management, workspace navigation, and launching applications."
    )
