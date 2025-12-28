"""
Color conversion utilities between Hyprland RGBA and GTK Gdk.RGBA
"""

import re
import gi
gi.require_version('Gdk', '4.0')
from gi.repository import Gdk

def rgba_to_gdk(rgba_str: str) -> Gdk.RGBA:
    """Convert hyprland rgba to Gdk.RGBA"""
    match = re.match(r'rgba\(([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\)', rgba_str)
    if match:
        r, g, b, a = match.groups()
        color = Gdk.RGBA()
        color.red = int(r, 16) / 255.0
        color.green = int(g, 16) / 255.0
        color.blue = int(b, 16) / 255.0
        color.alpha = int(a, 16) / 255.0
        return color
    color = Gdk.RGBA()
    color.parse("#83a598")
    return color

def gdk_to_rgba(color: Gdk.RGBA) -> str:
    """Convert Gdk.RGBA to hyprland rgba"""
    r = int(color.red * 255)
    g = int(color.green * 255)
    b = int(color.blue * 255)
    a = int(color.alpha * 255)
    return f"rgba({r:02x}{g:02x}{b:02x}{a:02x})"
