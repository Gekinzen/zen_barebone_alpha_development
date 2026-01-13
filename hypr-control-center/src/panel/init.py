"""
Hyprland Panel Module
Python GTK4 panel components for Hyprland

Location: ~/.config/hypr-control-center/src/panel/
"""

from .hypr_ipc import (
    HyprlandIPC,
    HyprEvent,
    HyprEventType,
    HyprWindow,
    hyprctl,
    hyprctl_json
)

__all__ = [
    'HyprlandIPC',
    'HyprEvent', 
    'HyprEventType',
    'HyprWindow',
    'hyprctl',
    'hyprctl_json'
]