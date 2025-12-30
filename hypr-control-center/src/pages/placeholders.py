"""
Placeholder pages for upcoming features
"""

from ..widgets import PlaceholderPage

# Panel page is now implemented in panel.py

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
    """Build Monitors placeholder page (legacy name, use build_displays_page)"""
    return build_displays_page(window)

def build_displays_page(window):
    """Build Displays placeholder page"""
    return PlaceholderPage(
        "Displays",
        "video-display-symbolic",
        "Configure monitor resolution, position, scale, and rotation for multi-display setups."
    )

def build_power_page(window):
    """Build Power & Battery placeholder page"""
    return PlaceholderPage(
        "Power & Battery",
        "battery-symbolic",
        "Manage power profiles: Saver, Neutral, Performance, and Developer modes."
    )

def build_notifications_page(window):
    """Build Notifications placeholder page"""
    return PlaceholderPage(
        "Notifications",
        "preferences-system-notifications-symbolic",
        "Configure notification position, display selection, and SwayNC settings."
    )

def build_keybinds_page(window):
    """Build Keybinds placeholder page"""
    return PlaceholderPage(
        "Keybinds",
        "preferences-desktop-keyboard-shortcuts-symbolic",
        "Customize keyboard shortcuts for window management, workspace navigation, and launching applications."
    )