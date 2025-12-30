from gi.repository import Gdk


def hex_to_rgba(hex_color: str) -> Gdk.RGBA:
    """
    Convert #RRGGBBAA → Gdk.RGBA
    """
    rgba = Gdk.RGBA()
    rgba.parse(hex_color)
    return rgba


def rgba_to_hex(rgba: Gdk.RGBA) -> str:
    """
    Convert Gdk.RGBA → #RRGGBBAA
    """
    r = int(rgba.red * 255)
    g = int(rgba.green * 255)
    b = int(rgba.blue * 255)
    a = int(rgba.alpha * 255)
    return f"#{r:02x}{g:02x}{b:02x}{a:02x}"
