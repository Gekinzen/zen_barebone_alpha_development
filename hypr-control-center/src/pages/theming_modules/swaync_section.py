"""
═══════════════════════════════════════════════════════════════════════════════
SWAYNC SECTION - SwayNC Notification Center Theming v1.4
═══════════════════════════════════════════════════════════════════════════════

Features:
- Auto-detect SwayNC installation
- Generate COMPLETE CSS (colors + notifications + control center)
- Sync with current theme colors
- SYNC FONT with Waybar font selection
- Manual color selection with live preview
- Auto reload on apply
- DIRECT OVERWRITE to ~/.config/swaync/style.css (v1.4)
- Auto backup before overwrite (v1.4)

Output: ~/.config/swaync/style.css (DIRECT - no more themes subfolder)
Backup: ~/.config/swaync/style.css.backup
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Gdk, Adw
import subprocess
import re
import shutil
from pathlib import Path
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS & CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

SWAYNC_DIR = Path.home() / ".config/swaync"
SWAYNC_STYLE = SWAYNC_DIR / "style.css"  # DIRECT target
SWAYNC_BACKUP = SWAYNC_DIR / "style.css.backup"

# Font families - same as waybar_section.py and hyprbars_section.py
FONT_FAMILIES = [
    ("Adwaita Sans", "Adwaita Sans"),
    ("JetBrains Mono", "JetBrainsMono Nerd Font"),
    ("GeistMono", "GeistMono Nerd Font Mono"),
    ("FiraCode", "FiraCode Nerd Font"),
    ("CaskaydiaCove", "CaskaydiaCove Nerd Font"),
    ("Iosevka", "Iosevka Nerd Font"),
    ("Hack", "Hack Nerd Font"),
    ("Ubuntu Mono", "UbuntuMono Nerd Font"),
    ("SF Pro", "SF Pro Display"),
    ("Inter", "Inter"),
]

DEFAULT_SWAYNC_CONFIG = {
    "bg": "#1e2127",
    "bg_alt": "#282b31",
    "fg": "#abb2bf",
    "selected": "#61afef",
    "hover": "#4b5263",
    "urgent": "#e06c75",
    "font_family": "JetBrainsMono Nerd Font",
    "font_size": 14,
    "border_radius": 24,
    "notification_radius": 24,
}


def is_swaync_installed() -> bool:
    """Check if SwayNC is installed"""
    try:
        result = subprocess.run(["which", "swaync"], capture_output=True, text=True, timeout=3)
        if result.returncode == 0:
            return True
        return SWAYNC_DIR.exists()
    except Exception as e:
        print(f"[swaync] Detection error: {e}")
    return False


def is_swaync_running() -> bool:
    """Check if SwayNC daemon is running"""
    try:
        result = subprocess.run(["pgrep", "-x", "swaync"], capture_output=True, text=True, timeout=3)
        return result.returncode == 0
    except Exception:
        return False


def get_current_waybar_font() -> str:
    """Get current font family from waybar style.css"""
    try:
        waybar_style = Path.home() / ".config/waybar/style.css"
        if waybar_style.exists():
            content = waybar_style.read_text()
            match = re.search(r'\*\s*{[^}]*font-family:\s*"?([^",;\n]+)', content, re.DOTALL)
            if match:
                font = match.group(1).strip().strip('"\'')
                return font
    except Exception as e:
        print(f"[swaync] Font detection error: {e}")
    return "JetBrainsMono Nerd Font"


def backup_style_css() -> bool:
    """Backup existing style.css before overwriting"""
    try:
        if SWAYNC_STYLE.exists():
            # Create timestamped backup on first run
            if not SWAYNC_BACKUP.exists():
                shutil.copy2(SWAYNC_STYLE, SWAYNC_BACKUP)
                print(f"[swaync] ✓ Created backup: {SWAYNC_BACKUP}")
            return True
    except Exception as e:
        print(f"[swaync] Backup error: {e}")
    return False


def restore_backup() -> bool:
    """Restore style.css from backup"""
    try:
        if SWAYNC_BACKUP.exists():
            shutil.copy2(SWAYNC_BACKUP, SWAYNC_STYLE)
            print(f"[swaync] ✓ Restored from backup")
            reload_swaync()
            return True
    except Exception as e:
        print(f"[swaync] Restore error: {e}")
    return False


# ═══════════════════════════════════════════════════════════════════════════════
# COMPLETE CSS GENERATION - DIRECT OVERWRITE VERSION
# ═══════════════════════════════════════════════════════════════════════════════

def generate_swaync_css(config: dict) -> str:
    """Generate COMPLETE SwayNC CSS - colors + notifications + control center + widgets"""
    
    bg = config.get("bg", "#1e2127")
    bg_alt = config.get("bg_alt", "#282b31")
    fg = config.get("fg", "#abb2bf")
    selected = config.get("selected", "#61afef")
    hover = config.get("hover", "#4b5263")
    urgent = config.get("urgent", "#e06c75")
    font = config.get("font_family", "JetBrainsMono Nerd Font")
    font_size = config.get("font_size", 14)
    border_r = config.get("border_radius", 24)
    notif_r = config.get("notification_radius", 24)
    
    return f'''/* ═══════════════════════════════════════════════════════════════════════════════
   SwayNC Complete Theme - Auto-generated by Hyprland Control Center v1.4
   Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
   
   Colors synced from Control Center theme
   Backup location: ~/.config/swaync/style.css.backup
   ═══════════════════════════════════════════════════════════════════════════════ */

/* COLOR DEFINITIONS */
@define-color background      {bg};
@define-color background-alt  {bg_alt};
@define-color text            {fg};
@define-color selected        {selected};
@define-color hover           {hover};
@define-color urgent          {urgent};

/* GLOBAL STYLES */
* {{
    color: @text;
    all: unset;
    font-size: {font_size}px;
    font-family: "{font}", "Adwaita Sans", sans-serif;
    transition: 200ms;
}}

.blank-window {{
    background: transparent;
}}

/* ═══════════════════════════════════════════════════════════════════════════════
   FLOATING NOTIFICATIONS (popup notifications)
   ═══════════════════════════════════════════════════════════════════════════════ */

.notification-row {{
    outline: none;
    margin: 0;
    padding: 0px;
}}

.floating-notifications.background .notification-row .notification-background {{
    background: alpha(@background, .55);
    box-shadow: 0 0 8px 0 rgba(0,0,0,.6);
    border: 1px solid @selected;
    border-radius: {notif_r}px;
    margin: 16px;
    padding: 0;
}}

.floating-notifications.background .notification-row .notification-background .notification {{
    padding: 6px;
    border-radius: 12px;
}}

.floating-notifications.background .notification-row .notification-background .notification.critical {{
    border: 2px solid @urgent;
}}

.floating-notifications.background .notification-row .notification-background .notification .notification-content {{
    margin: 14px;
}}

.floating-notifications.background .notification-row .notification-background .notification > *:last-child > * {{
    min-height: 3.4em;
}}

.floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action {{
    border-radius: 8px;
    background-color: @background-alt;
    margin: 6px;
    border: 1px solid transparent;
}}

.floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action:hover {{
    background-color: @hover;
    border: 1px solid @selected;
}}

.floating-notifications.background .notification-row .notification-background .notification > *:last-child > * .notification-action:active {{
    background-color: @selected;
    color: @background;
}}

/* Notification content */
.image {{
    margin: 10px 20px 10px 0px;
}}

.summary {{
    font-weight: 800;
    font-size: 1rem;
}}

.body {{
    font-size: 0.8rem;
}}

/* Close button */
.floating-notifications.background .notification-row .notification-background .close-button {{
    margin: 6px;
    padding: 2px;
    border-radius: 6px;
    background-color: transparent;
    border: 1px solid transparent;
}}

.floating-notifications.background .notification-row .notification-background .close-button:hover {{
    background-color: @selected;
}}

.floating-notifications.background .notification-row .notification-background .close-button:active {{
    background-color: @selected;
    color: @background;
}}

/* Progress bars */
.notification.critical progress {{
    background-color: @urgent;
}}

.notification.low progress,
.notification.normal progress {{
    background-color: @selected;
}}

/* ═══════════════════════════════════════════════════════════════════════════════
   CONTROL CENTER (notification panel)
   ═══════════════════════════════════════════════════════════════════════════════ */

.control-center {{
    background: @background;
    border-radius: {border_r}px;
    border: 1px solid @selected;
    box-shadow: 0 0 10px 0 rgba(0,0,0,.6);
    margin: 18px;
    padding: 12px;
}}

.control-center .notification-row .notification-background,
.control-center .notification-row .notification-background .notification.critical {{
    background-color: @background-alt;
    border-radius: 16px;
    margin: 4px 0px;
    padding: 4px;
}}

.control-center .notification-row .notification-background .notification.critical {{
    color: @urgent;
}}

.control-center .notification-row .notification-background .notification .notification-content {{
    margin: 6px;
    padding: 8px 6px 2px 2px;
}}

.control-center .notification-row .notification-background .notification > *:last-child > * {{
    min-height: 3.4em;
}}

.control-center .notification-row .notification-background .notification > *:last-child > * .notification-action {{
    background: alpha(@selected, .6);
    color: @text;
    border-radius: 12px;
    margin: 6px;
}}

.control-center .notification-row .notification-background .notification > *:last-child > * .notification-action:hover {{
    background: @selected;
}}

.control-center .notification-row .notification-background .close-button {{
    background: transparent;
    border-radius: 6px;
    color: @text;
    margin: 0px;
    padding: 4px;
}}

.control-center .notification-row .notification-background .close-button:hover {{
    background-color: @selected;
}}

/* Progress bars in control center */
progressbar,
progress,
trough {{
    border-radius: 12px;
}}

progressbar {{
    background-color: rgba(255,255,255,.1);
}}

/* ═══════════════════════════════════════════════════════════════════════════════
   NOTIFICATION GROUPS
   ═══════════════════════════════════════════════════════════════════════════════ */

.notification-group {{
    margin: 2px 8px 2px 8px;
}}

.notification-group-headers {{
    font-weight: bold;
    font-size: 1.25rem;
    color: @text;
    letter-spacing: 2px;
}}

.notification-group-icon {{
    color: @text;
}}

.notification-group-collapse-button,
.notification-group-close-all-button {{
    background: transparent;
    color: @text;
    margin: 4px;
    border-radius: 6px;
    padding: 4px;
}}

.notification-group-collapse-button:hover,
.notification-group-close-all-button:hover {{
    background: @hover;
}}

/* ═══════════════════════════════════════════════════════════════════════════════
   WIDGETS
   ═══════════════════════════════════════════════════════════════════════════════ */

/* Title widget */
.widget-title {{
    font-size: 1.2em;
    margin: 6px;
}}

.widget-title button {{
    background: @background-alt;
    border-radius: 6px;
    padding: 4px 16px;
}}

.widget-title button:hover {{
    background-color: @hover;
}}

.widget-title button:active {{
    background-color: @selected;
}}

/* Do Not Disturb widget */
.widget-dnd {{
    margin: 6px;
    font-size: 1.2rem;
}}

.widget-dnd > switch {{
    background: @background-alt;
    font-size: initial;
    border-radius: 8px;
    box-shadow: none;
    padding: 2px;
}}

.widget-dnd > switch:hover {{
    background: @hover;
}}

.widget-dnd > switch:checked {{
    background: @selected;
}}

.widget-dnd > switch:checked:hover {{
    background: @hover;
}}

.widget-dnd > switch slider {{
    background: @text;
    border-radius: 6px;
}}

/* Buttons grid widget */
.widget-buttons-grid {{
    font-size: x-large;
    padding: 6px 2px;
    margin: 6px;
    border-radius: 12px;
    background: @background-alt;
}}

.widget-buttons-grid>flowbox>flowboxchild>button {{
    margin: 4px 10px;
    padding: 6px 12px;
    background: transparent;
    border-radius: 8px;
}}

.widget-buttons-grid>flowbox>flowboxchild>button:hover {{
    background: @hover;
}}

.widget-buttons-grid>flowbox>flowboxchild>button:active {{
    background: @selected;
}}

/* MPRIS media widget */
.widget-mpris {{
    background: @background-alt;
    border-radius: 16px;
    color: @text;
    margin: 20px 6px;
}}

.widget-mpris-player {{
    background-color: @background;
    border-radius: 22px;
    padding: 6px 14px;
    margin: 6px;
}}

.widget-mpris > box > button {{
    color: @text;
    border-radius: 20px;
}}

.widget-mpris button {{
    color: alpha(@text, .6);
}}

.widget-mpris button:hover {{
    color: @text;
}}

.widget-mpris-album-art {{
    border-radius: 16px;
}}

.widget-mpris-title {{
    font-weight: 700;
    font-size: 1rem;
}}

.widget-mpris-subtitle {{
    font-weight: 500;
    font-size: 0.8rem;
}}

/* Volume widget */
.widget-volume {{
    background: @background;
    color: @text;
    padding: 4px;
    margin: 6px;
    border-radius: 6px;
}}

/* Label widget */
.widget-label {{
    margin: 6px;
}}

.widget-label > label {{
    font-size: 1rem;
}}

/* Menubar widget */
.widget-menubar > box > .menu-button-bar > button {{
    border: none;
    background: transparent;
}}

.widget-menubar > box > .menu-button-bar > button:hover {{
    background: @hover;
}}

/* Backlight widget */
.widget-backlight {{
    background: @background-alt;
    border-radius: 12px;
    padding: 6px;
    margin: 6px;
}}

/* Inhibitors widget */
.widget-inhibitors {{
    margin: 6px;
    font-size: 1rem;
}}

.widget-inhibitors > button {{
    background: @background-alt;
    border-radius: 6px;
    padding: 4px 8px;
}}

.widget-inhibitors > button:hover {{
    background: @hover;
}}

.widget-inhibitors > button > box > image {{
    color: @text;
}}

.widget-inhibitors > button > box > label {{
    color: @text;
}}
'''


def reload_swaync():
    """Reload SwayNC CSS"""
    try:
        subprocess.run(["swaync-client", "--reload-css"], capture_output=True, timeout=3)
        print("[swaync] ✓ Reloaded CSS")
        return True
    except Exception as e:
        print(f"[swaync] Reload error: {e}")
        return False


def apply_swaync_colorscheme(config: dict, auto_reload: bool = True) -> bool:
    """Apply SwayNC colorscheme - DIRECT OVERWRITE to style.css"""
    try:
        # Ensure directory exists
        SWAYNC_DIR.mkdir(parents=True, exist_ok=True)
        
        # Backup existing style.css (only once)
        backup_style_css()
        
        # Generate and write CSS directly to style.css
        css_content = generate_swaync_css(config)
        SWAYNC_STYLE.write_text(css_content)
        
        print(f"[swaync] ✓ Wrote CSS to {SWAYNC_STYLE}")
        print(f"[swaync]   Font: {config.get('font_family')}")
        print(f"[swaync]   BG: {config.get('bg')}, FG: {config.get('fg')}, Accent: {config.get('selected')}")
        
        if auto_reload:
            reload_swaync()
        
        return True
    except Exception as e:
        print(f"[swaync] Apply error: {e}")
        import traceback
        traceback.print_exc()
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# PREVIEW WIDGET
# ═══════════════════════════════════════════════════════════════════════════════

class SwayNCPreviewWidget(Gtk.DrawingArea):
    """Live preview of SwayNC notification styling"""
    
    def __init__(self, config: dict):
        super().__init__()
        self.config = config.copy()
        self.set_size_request(-1, 120)
        self.set_draw_func(self._draw)
    
    def update_config(self, config: dict):
        self.config = config.copy()
        self.queue_draw()
    
    def _parse_color(self, hex_color: str) -> tuple:
        hex_color = hex_color.lstrip("#")
        if len(hex_color) == 6:
            return (int(hex_color[0:2], 16)/255, int(hex_color[2:4], 16)/255, int(hex_color[4:6], 16)/255, 1.0)
        return (0.12, 0.12, 0.17, 1.0)
    
    def _rounded_rect(self, cr, x, y, w, h, r):
        import math
        cr.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
        cr.arc(x + w - r, y + r, r, 1.5 * math.pi, 0)
        cr.arc(x + w - r, y + h - r, r, 0, 0.5 * math.pi)
        cr.arc(x + r, y + h - r, r, 0.5 * math.pi, math.pi)
        cr.close_path()
    
    def _draw(self, area, cr, width, height):
        bg = self._parse_color(self.config.get("bg", "#1e2127"))
        bg_alt = self._parse_color(self.config.get("bg_alt", "#282b31"))
        hover = self._parse_color(self.config.get("hover", "#4b5263"))
        fg = self._parse_color(self.config.get("fg", "#abb2bf"))
        selected = self._parse_color(self.config.get("selected", "#61afef"))
        border_r = self.config.get("border_radius", 24)
        
        # Main background
        cr.set_source_rgba(bg[0], bg[1], bg[2], 0.92)
        self._rounded_rect(cr, 0, 0, width, height, border_r / 2)
        cr.fill()
        
        # Border
        cr.set_source_rgba(selected[0], selected[1], selected[2], 1.0)
        self._rounded_rect(cr, 0, 0, width, height, border_r / 2)
        cr.set_line_width(1)
        cr.stroke()
        
        # Notification card
        m = 12
        cx, cy, cw, ch = m, m, width - m*2, height - m*2
        
        cr.set_source_rgba(bg_alt[0], bg_alt[1], bg_alt[2], 0.98)
        self._rounded_rect(cr, cx, cy, cw, ch, 16)
        cr.fill()
        
        # App icon circle
        cr.set_source_rgba(selected[0], selected[1], selected[2], 1.0)
        import math
        cr.arc(cx + 36, cy + 36, 16, 0, 2 * math.pi)
        cr.fill()
        
        # Title
        cr.set_source_rgba(fg[0], fg[1], fg[2], 1.0)
        cr.select_font_face("Sans", 0, 1)
        cr.set_font_size(13)
        cr.move_to(cx + 64, cy + 34)
        cr.show_text("Application")
        
        # Body
        cr.select_font_face("Sans", 0, 0)
        cr.set_font_size(11)
        cr.set_source_rgba(fg[0], fg[1], fg[2], 0.8)
        cr.move_to(cx + 64, cy + 52)
        cr.show_text("This is a notification message...")
        
        # Action buttons
        btn_y = cy + ch - 32
        
        # Dismiss button
        cr.set_source_rgba(hover[0], hover[1], hover[2], 1.0)
        self._rounded_rect(cr, cx + cw - 160, btn_y, 70, 24, 8)
        cr.fill()
        cr.set_source_rgba(fg[0], fg[1], fg[2], 0.8)
        cr.set_font_size(10)
        cr.move_to(cx + cw - 145, btn_y + 16)
        cr.show_text("Dismiss")
        
        # Open button
        cr.set_source_rgba(selected[0], selected[1], selected[2], 0.6)
        self._rounded_rect(cr, cx + cw - 82, btn_y, 70, 24, 8)
        cr.fill()
        cr.set_source_rgba(fg[0], fg[1], fg[2], 1.0)
        cr.move_to(cx + cw - 62, btn_y + 16)
        cr.show_text("Open")


# ═══════════════════════════════════════════════════════════════════════════════
# UI COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════

def create_color_button(label: str, color: str, on_change) -> Gtk.Box:
    """Create a color picker row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_top(4)
    row.set_margin_bottom(4)
    
    lbl = Gtk.Label(label=label)
    lbl.set_xalign(0)
    lbl.set_hexpand(True)
    row.append(lbl)
    
    btn = Gtk.ColorButton()
    rgba = Gdk.RGBA()
    rgba.parse(color)
    btn.set_rgba(rgba)
    
    def on_color_set(button):
        rgba = button.get_rgba()
        hex_color = f"#{int(rgba.red*255):02x}{int(rgba.green*255):02x}{int(rgba.blue*255):02x}"
        on_change(hex_color)
    
    btn.connect("color-set", on_color_set)
    row.append(btn)
    
    return row


def create_spin_row(label: str, value: int, min_v: int, max_v: int, on_change) -> Gtk.Box:
    """Create a spin button row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_top(4)
    row.set_margin_bottom(4)
    
    lbl = Gtk.Label(label=label)
    lbl.set_xalign(0)
    lbl.set_hexpand(True)
    row.append(lbl)
    
    spin = Gtk.SpinButton.new_with_range(min_v, max_v, 1)
    spin.set_value(value)
    spin.add_css_class("themed-spin")
    spin.connect("value-changed", lambda s: on_change(int(s.get_value())))
    row.append(spin)
    
    return row


def create_font_dropdown(current_font: str, on_change) -> tuple:
    """Create font family dropdown - synced with waybar"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_top(4)
    row.set_margin_bottom(4)
    
    lbl = Gtk.Label(label="Font Family (synced with Waybar)")
    lbl.set_xalign(0)
    lbl.set_hexpand(True)
    row.append(lbl)
    
    model = Gtk.StringList()
    current_idx = 0
    
    for i, (display_name, font_name) in enumerate(FONT_FAMILIES):
        model.append(display_name)
        if font_name.lower() in current_font.lower() or current_font.lower() in font_name.lower():
            current_idx = i
    
    dd = Gtk.DropDown()
    dd.add_css_class("themed-dropdown")
    dd.set_model(model)
    dd.set_selected(current_idx)
    
    def on_font_selected(dropdown, _):
        idx = dropdown.get_selected()
        if idx < len(FONT_FAMILIES):
            font_name = FONT_FAMILIES[idx][1]
            on_change(font_name)
    
    dd.connect("notify::selected", on_font_selected)
    row.append(dd)
    
    return row, dd


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SECTION BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_swaync_section(window, theme_colors: dict) -> Gtk.Widget:
    """Build the SwayNC configuration section"""
    
    if not is_swaync_installed():
        empty = Gtk.Box()
        empty.set_visible(False)
        return empty
    
    config = DEFAULT_SWAYNC_CONFIG.copy()
    
    # Sync colors from current theme
    if theme_colors:
        config["bg"] = theme_colors.get("bg0", config["bg"])
        config["bg_alt"] = theme_colors.get("bg1", config["bg_alt"])
        config["fg"] = theme_colors.get("fg", config["fg"])
        config["selected"] = theme_colors.get("blue", config["selected"])
        config["hover"] = theme_colors.get("bg4", config["hover"])
        config["urgent"] = theme_colors.get("red", config["urgent"])
    
    # Sync font from waybar config
    if hasattr(window, 'current_waybar_config') and window.current_waybar_config:
        waybar_font = window.current_waybar_config.get("font_family", "")
        if waybar_font:
            config["font_family"] = waybar_font
    else:
        config["font_family"] = get_current_waybar_font()
    
    window.current_swaync_config = config.copy()
    
    # Main container
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    box.set_margin_start(16)
    box.set_margin_end(16)
    box.set_margin_top(8)
    box.set_margin_bottom(16)
    
    # Preview
    preview = SwayNCPreviewWidget(config)
    window.swaync_preview = preview
    frame = Gtk.Frame()
    frame.set_child(preview)
    frame.set_margin_bottom(12)
    box.append(frame)
    
    def update_preview():
        if hasattr(window, 'swaync_preview'):
            window.swaync_preview.update_config(window.current_swaync_config)
    
    def make_handler(key):
        def handler(val):
            window.current_swaync_config[key] = val
            update_preview()
        return handler
    
    # ═══════════════════════════════════════════════════════════════════════════
    # COLORS SECTION
    # ═══════════════════════════════════════════════════════════════════════════
    clr_lbl = Gtk.Label(label="COLORS")
    clr_lbl.add_css_class("caption")
    clr_lbl.add_css_class("dim-label")
    clr_lbl.set_xalign(0)
    clr_lbl.set_margin_top(8)
    box.append(clr_lbl)
    
    bg_row = create_color_button("Background", config["bg"], make_handler("bg"))
    window.swaync_bg_btn = bg_row.get_last_child()
    box.append(bg_row)
    
    bg_alt_row = create_color_button("Background Alt", config["bg_alt"], make_handler("bg_alt"))
    window.swaync_bg_alt_btn = bg_alt_row.get_last_child()
    box.append(bg_alt_row)
    
    fg_row = create_color_button("Text", config["fg"], make_handler("fg"))
    window.swaync_fg_btn = fg_row.get_last_child()
    box.append(fg_row)
    
    sel_row = create_color_button("Selected / Accent", config["selected"], make_handler("selected"))
    window.swaync_selected_btn = sel_row.get_last_child()
    box.append(sel_row)
    
    hover_row = create_color_button("Hover", config["hover"], make_handler("hover"))
    window.swaync_hover_btn = hover_row.get_last_child()
    box.append(hover_row)
    
    urg_row = create_color_button("Urgent / Critical", config["urgent"], make_handler("urgent"))
    window.swaync_urgent_btn = urg_row.get_last_child()
    box.append(urg_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TEXT SETTINGS SECTION
    # ═══════════════════════════════════════════════════════════════════════════
    txt_lbl = Gtk.Label(label="TEXT SETTINGS")
    txt_lbl.add_css_class("caption")
    txt_lbl.add_css_class("dim-label")
    txt_lbl.set_xalign(0)
    txt_lbl.set_margin_top(16)
    box.append(txt_lbl)
    
    font_row, font_dd = create_font_dropdown(config["font_family"], make_handler("font_family"))
    window.swaync_font_dropdown = font_dd
    box.append(font_row)
    
    box.append(create_spin_row("Font Size", config["font_size"], 10, 20, make_handler("font_size")))
    
    # ═══════════════════════════════════════════════════════════════════════════
    # LAYOUT SECTION
    # ═══════════════════════════════════════════════════════════════════════════
    lay_lbl = Gtk.Label(label="LAYOUT")
    lay_lbl.add_css_class("caption")
    lay_lbl.add_css_class("dim-label")
    lay_lbl.set_xalign(0)
    lay_lbl.set_margin_top(16)
    box.append(lay_lbl)
    
    box.append(create_spin_row("Control Center Radius", config["border_radius"], 0, 48, make_handler("border_radius")))
    box.append(create_spin_row("Notification Radius", config["notification_radius"], 0, 48, make_handler("notification_radius")))
    
    # ═══════════════════════════════════════════════════════════════════════════
    # STATUS SECTION
    # ═══════════════════════════════════════════════════════════════════════════
    st_lbl = Gtk.Label(label="STATUS")
    st_lbl.add_css_class("caption")
    st_lbl.add_css_class("dim-label")
    st_lbl.set_xalign(0)
    st_lbl.set_margin_top(16)
    box.append(st_lbl)
    
    # Running status
    st_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    st_row.set_margin_top(4)
    running = is_swaync_running()
    st_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic" if running else "emblem-synchronizing-symbolic")
    st_row.append(st_icon)
    st_txt = Gtk.Label(label="SwayNC is running" if running else "SwayNC not running")
    st_txt.set_xalign(0)
    st_txt.set_hexpand(True)
    st_row.append(st_txt)
    box.append(st_row)
    
    # Output file info
    file_lbl = Gtk.Label()
    file_lbl.set_markup(f"<small><tt>Output: {SWAYNC_STYLE}</tt></small>")
    file_lbl.set_xalign(0)
    file_lbl.add_css_class("dim-label")
    file_lbl.set_margin_top(4)
    box.append(file_lbl)
    
    # Backup info
    backup_exists = SWAYNC_BACKUP.exists()
    backup_lbl = Gtk.Label()
    if backup_exists:
        backup_lbl.set_markup(f"<small><tt>Backup: {SWAYNC_BACKUP}</tt></small>")
    else:
        backup_lbl.set_markup("<small><tt>Backup will be created on first apply</tt></small>")
    backup_lbl.set_xalign(0)
    backup_lbl.add_css_class("dim-label")
    backup_lbl.set_margin_top(2)
    box.append(backup_lbl)
    
    # Restore button (only if backup exists)
    if backup_exists:
        restore_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        restore_row.set_margin_top(8)
        
        restore_btn = Gtk.Button(label="Restore from Backup")
        restore_btn.add_css_class("destructive-action")
        
        def on_restore(btn):
            if restore_backup():
                # Show notification
                try:
                    subprocess.run(["notify-send", "SwayNC", "Restored from backup"], timeout=3)
                except:
                    pass
        
        restore_btn.connect("clicked", on_restore)
        restore_row.append(restore_btn)
        box.append(restore_row)
    
    return box


def sync_swaync_with_theme(window, theme_colors: dict):
    """Sync SwayNC colors when theme changes"""
    if not hasattr(window, 'current_swaync_config'):
        return
    
    # Update config colors from theme
    mappings = [
        ("bg", "bg0"),
        ("bg_alt", "bg1"),
        ("fg", "fg"),
        ("selected", "blue"),
        ("hover", "bg4"),
        ("urgent", "red")
    ]
    
    for cfg_key, theme_key in mappings:
        if theme_key in theme_colors:
            window.current_swaync_config[cfg_key] = theme_colors[theme_key]
    
    # Update color button widgets
    btn_map = [
        ("swaync_bg_btn", "bg"),
        ("swaync_bg_alt_btn", "bg_alt"),
        ("swaync_fg_btn", "fg"),
        ("swaync_selected_btn", "selected"),
        ("swaync_hover_btn", "hover"),
        ("swaync_urgent_btn", "urgent")
    ]
    
    for btn_name, cfg_key in btn_map:
        if hasattr(window, btn_name):
            rgba = Gdk.RGBA()
            rgba.parse(window.current_swaync_config[cfg_key])
            getattr(window, btn_name).set_rgba(rgba)
    
    # Update preview
    if hasattr(window, 'swaync_preview'):
        window.swaync_preview.update_config(window.current_swaync_config)


def sync_swaync_with_waybar_font(window, font_name: str):
    """Sync SwayNC font when waybar font changes"""
    if not hasattr(window, 'current_swaync_config'):
        return
    
    window.current_swaync_config["font_family"] = font_name
    
    # Update font dropdown selection
    if hasattr(window, 'swaync_font_dropdown'):
        for i, (display, actual) in enumerate(FONT_FAMILIES):
            if actual.lower() in font_name.lower() or font_name.lower() in actual.lower():
                window.swaync_font_dropdown.set_selected(i)
                break
    
    # Update preview
    if hasattr(window, 'swaync_preview'):
        window.swaync_preview.update_config(window.current_swaync_config)


def apply_swaync_settings(window) -> bool:
    """Apply current SwayNC settings from window config"""
    if not hasattr(window, 'current_swaync_config'):
        print("[swaync] No config found on window")
        return False
    
    # Sync waybar font before applying
    if hasattr(window, 'current_waybar_config') and window.current_waybar_config:
        waybar_font = window.current_waybar_config.get("font_family", "")
        if waybar_font:
            window.current_swaync_config["font_family"] = waybar_font
    
    return apply_swaync_colorscheme(window.current_swaync_config, auto_reload=True)


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

__all__ = [
    'is_swaync_installed',
    'is_swaync_running',
    'generate_swaync_css',
    'apply_swaync_colorscheme',
    'reload_swaync',
    'backup_style_css',
    'restore_backup',
    'build_swaync_section',
    'sync_swaync_with_theme',
    'sync_swaync_with_waybar_font',
    'apply_swaync_settings',
    'SwayNCPreviewWidget',
    'SWAYNC_STYLE',
    'SWAYNC_BACKUP',
    'DEFAULT_SWAYNC_CONFIG',
    'FONT_FAMILIES',
    'get_current_waybar_font',
]