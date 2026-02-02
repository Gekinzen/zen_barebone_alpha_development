"""THEMING HELPERS - Utility Functions"""
import json, subprocess, re
from .constants import PREFERENCES_THEME_FILE, CURRENT_THEME_FILE, PROFILES_FILE, WAYBAR_CONFIG, HYPRLAND_CONF
from .themes_data import BUILTIN_THEMES

def is_light_theme(colors: dict) -> bool:
    """Check if theme is light based on bg luminance"""
    try:
        h = colors.get("bg0", "#282c34").lstrip('#')
        r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5
    except: return False

def get_saved_theme_data() -> dict:
    """Get saved theme data (read-only)"""
    for f in [PREFERENCES_THEME_FILE, CURRENT_THEME_FILE]:
        try:
            if f.exists():
                data = json.loads(f.read_text())
                if data.get('colors'): return data
        except: pass
    if PROFILES_FILE.exists():
        try:
            tid = json.loads(PROFILES_FILE.read_text()).get("active_profile")
            if tid in BUILTIN_THEMES:
                return {"id": tid, "name": BUILTIN_THEMES[tid]["name"], 
                        "colors": BUILTIN_THEMES[tid]["colors"], "is_builtin": True}
        except: pass
    return None

def get_current_theme_colors() -> dict:
    data = get_saved_theme_data()
    return data.get('colors', {}) if data else BUILTIN_THEMES["one-dark"]["colors"]

# Waybar helpers
def get_monitor_list():
    monitors = ["All Monitors"]
    try:
        r = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=5)
        if r.returncode == 0:
            for m in json.loads(r.stdout):
                if m.get("name"): monitors.append(m["name"])
    except: pass
    return monitors or ["All Monitors", "DP-1", "DP-2", "HDMI-A-1", "eDP-1"]

def get_waybar_field(field, default=""):
    try:
        if WAYBAR_CONFIG.exists():
            c = re.sub(r'//.*$', '', WAYBAR_CONFIG.read_text(), flags=re.MULTILINE)
            c = re.sub(r'/\*.*?\*/', '', c, flags=re.DOTALL)
            return json.loads(c).get(field, default)
    except: pass
    return default

def get_current_waybar_output(): return get_waybar_field("output", "")
def get_current_waybar_position(): return get_waybar_field("position", "top")

def get_current_waybar_margins():
    margins = {"top": 0, "bottom": 0, "left": 0, "right": 0}
    try:
        if WAYBAR_CONFIG.exists():
            c = re.sub(r'//.*$', '', WAYBAR_CONFIG.read_text(), flags=re.MULTILINE)
            c = re.sub(r'/\*.*?\*/', '', c, flags=re.DOTALL)
            cfg = json.loads(c)
            for s in margins: margins[s] = cfg.get(f"margin-{s}", 0)
    except: pass
    return margins

def update_waybar_config_field(field, value):
    try:
        if not WAYBAR_CONFIG.exists(): return False
        c = WAYBAR_CONFIG.read_text()
        if field == "output":
            if value in ["", "All Monitors"]:
                c = re.sub(r',?\s*"output"\s*:\s*"[^"]*"', '', c)
            elif re.search(r'"output"\s*:', c):
                c = re.sub(r'("output"\s*:\s*)"[^"]*"', f'\\1"{value}"', c)
        elif field == "position" and re.search(r'"position"\s*:', c):
            c = re.sub(r'("position"\s*:\s*)"[^"]*"', f'\\1"{value}"', c)
        elif field == "height" and re.search(r'"height"\s*:', c):
            c = re.sub(r'("height"\s*:\s*)\d+', f'\\g<1>{value}', c)
        elif field.startswith("margin-") and re.search(rf'"{field}"\s*:', c):
            c = re.sub(rf'("{field}"\s*:\s*)\d+', f'\\g<1>{value}', c)
        WAYBAR_CONFIG.write_text(c)
        return True
    except: return False

def apply_hyprland_rounding(radius: int = 12):
    try:
        if not HYPRLAND_CONF.exists(): return False
        c = HYPRLAND_CONF.read_text()
        p = r'(decoration\s*\{[^}]*rounding\s*=\s*)(\d+)'
        if re.search(p, c, re.DOTALL):
            HYPRLAND_CONF.write_text(re.sub(p, rf'\g<1>{radius}', c, flags=re.DOTALL))
            subprocess.run(['hyprctl', 'reload'], capture_output=True)
            return True
    except: pass
    return False
