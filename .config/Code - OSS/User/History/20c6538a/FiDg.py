from gi.repository import Gdk


# ==================================================
# GTK RGBA -> HYPRLAND RGBA STRING
# ==================================================
def rgba_to_hypr(rgba: Gdk.RGBA) -> str:
    """
    Convert GTK RGBA to Hyprland rgba(hex) string
    Example: rgba(83a598aa)
    """
    r = int(rgba.red * 255)
    g = int(rgba.green * 255)
    b = int(rgba.blue * 255)
    a = int(rgba.alpha * 255)
    return f"rgba({r:02x}{g:02x}{b:02x}{a:02x})"


# ==================================================
# HYPRLAND RGBA STRING -> GTK RGBA
# ==================================================
def hypr_to_rgba(value: str) -> Gdk.RGBA:
    """
    Convert Hyprland rgba(hex) string to GTK RGBA
    Example: rgba(83a598aa)
    """
    try:
        hexv = value.replace("rgba(", "").replace(")", "")
        r = int(hexv[0:2], 16) / 255
        g = int(hexv[2:4], 16) / 255
        b = int(hexv[4:6], 16) / 255
        a = int(hexv[6:8], 16) / 255
        return Gdk.RGBA(r, g, b, a)
    except Exception:
        # fallback: white
        return Gdk.RGBA(1, 1, 1, 1)
