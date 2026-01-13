"""
Data classes for Hyprland configuration
"""

from dataclasses import dataclass, field
from typing import List

@dataclass
class GeneralConfig:
    gaps_in: int = 8
    gaps_out: int = 18
    border_size: int = 1
    col_active_border: str = "rgba(83a598aa)"
    col_active_border_angle: int = 45
    col_inactive_border: str = "rgba(595959aa)"
    resize_on_border: bool = False
    allow_tearing: bool = False
    layout: str = "dwindle"

@dataclass
class DecorationConfig:
    rounding: int = 14
    rounding_power: int = 3
    active_opacity: float = 1.0
    inactive_opacity: float = 1.0
    shadow_enabled: bool = True
    shadow_range: int = 15
    shadow_render_power: int = 3
    shadow_color: str = "rgba(121212ee)"
    blur_enabled: bool = True
    blur_size: int = 7
    blur_passes: int = 3
    blur_vibrancy: float = 0.1696

@dataclass
class AnimationConfig:
    enabled: bool = True
    # Bezier curves
    bezier_easeOutQuint: str = "0.23, 1, 0.32, 1"
    bezier_easeInOutCubic: str = "0.65, 0.05, 0.36, 1"
    # Animation settings
    global_speed: int = 10
    border_speed: float = 5.39
    windows_speed: float = 4.79
    windowsIn_speed: float = 4.1
    windowsOut_speed: float = 1.49
    fade_speed: float = 1.73
    workspaces_speed: float = 2.39

@dataclass
class InputConfig:
    kb_layout: str = "us"
    follow_mouse: int = 1
    sensitivity: float = 0.0
    accel_profile: str = "flat"
    touchpad_natural_scroll: bool = True
    touchpad_disable_while_typing: bool = True
    touchpad_tap_to_click: bool = True

@dataclass
class MonitorConfig:
    name: str = ""
    resolution: str = "preferred"
    position: str = "auto"
    scale: float = 1.0
    transform: int = 0
    enabled: bool = True

@dataclass 
class WaybarConfig:
    position: str = "top"
    height: int = 34
    margin_top: int = 0
    margin_bottom: int = 0
    margin_left: int = 0
    margin_right: int = 0
    spacing: int = 4

@dataclass
class WorkspaceRule:
    workspace: int = 1
    monitor: str = ""
    default: bool = False
    persistent: bool = False
