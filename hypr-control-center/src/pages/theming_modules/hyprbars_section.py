"""
═══════════════════════════════════════════════════════════════════════════════
HYPRBARS SECTION - Hyprland Window Decorations Plugin Theming v2.5
═══════════════════════════════════════════════════════════════════════════════

Features:
- Auto-detect if hyprbars plugin is active
- Dynamic col.text and bar_color synced with theme (bg0 -> bar_color, fg -> col.text)
- Font family synced with waybar font selection
- Customizable bar_text_size, bar_text_align, bar_buttons_alignment
- Live preview of title bar
- AUTO hyprctl reload on changes
- Themed dropdowns (bg3 background, fg text)
- PROPER PLUGIN BLOCK PARSING (v2.5) - handles plugin { hyprbars { } } format
- AUTO-UPDATE hyprland.conf on Apply Theme (v2.5)
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Gdk, Adw, GLib
import subprocess
import re
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS & CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

HYPRLAND_CONF = Path.home() / ".config/hypr/hyprland.conf"
HYPRBARS_CONF = Path.home() / ".config/hypr/hyprbars.conf"

# Font families matching waybar_section.py
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

DEFAULT_HYPRBARS_CONFIG = {
    "bar_height": 28,
    "bar_text_size": 10,
    "bar_text_align": "center",
    "bar_text_font": "Adwaita Sans",
    "bar_padding": 8,
    "bar_button_padding": 10,
    "bar_buttons_alignment": "left",
    "col_text": "#eceff4",
    "bar_color": "#2e3440",
    "col_close": "#f38ba8",
    "col_minimize": "#f9e2af",
    "col_maximize": "#a6e3a1",
}


# ═══════════════════════════════════════════════════════════════════════════════
# DETECTION & PARSING (v2.5 - Proper plugin {} block handling)
# ═══════════════════════════════════════════════════════════════════════════════

def is_hyprbars_active() -> bool:
    """Check if hyprbars plugin is loaded in Hyprland"""
    try:
        result = subprocess.run(
            ["hyprctl", "plugins", "list"],
            capture_output=True, text=True, timeout=3
        )
        if "hyprbars" in result.stdout.lower():
            return True
        
        if HYPRLAND_CONF.exists():
            content = HYPRLAND_CONF.read_text()
            # Check for plugin { hyprbars { } } format
            if re.search(r'plugin\s*\{[^}]*hyprbars\s*\{', content, re.DOTALL | re.IGNORECASE):
                return True
            # Check for standalone hyprbars { }
            if re.search(r'hyprbars\s*\{', content, re.IGNORECASE):
                return True
        
        if HYPRBARS_CONF.exists():
            return True
            
    except Exception as e:
        print(f"[hyprbars] Detection error: {e}")
    
    return False


def _extract_hyprbars_block(content: str) -> str:
    """Extract the hyprbars {} block content from hyprland.conf"""
    
    # Find hyprbars { in content
    match = re.search(r'hyprbars\s*\{', content)
    if not match:
        return ""
    
    block_start = match.end()
    depth = 1
    pos = block_start
    
    while pos < len(content) and depth > 0:
        if content[pos] == '{':
            depth += 1
        elif content[pos] == '}':
            depth -= 1
        pos += 1
    
    if depth == 0:
        return content[block_start:pos-1]
    
    return ""


def get_hyprbars_config() -> dict:
    """Parse current hyprbars configuration from hyprland.conf"""
    config = DEFAULT_HYPRBARS_CONFIG.copy()
    
    try:
        if not HYPRLAND_CONF.exists():
            return config
            
        content = HYPRLAND_CONF.read_text()
        block = _extract_hyprbars_block(content)
        
        if not block:
            print("[hyprbars] No hyprbars block found, using defaults")
            return config
        
        # Parse values from block
        patterns = {
            "bar_height": r'bar_height\s*=\s*(\d+)',
            "bar_text_size": r'bar_text_size\s*=\s*(\d+)',
            "bar_text_align": r'bar_text_align\s*=\s*(\w+)',
            "bar_text_font": r'bar_text_font\s*=\s*(.+?)(?:\n|$)',
            "bar_padding": r'bar_padding\s*=\s*(\d+)',
            "bar_button_padding": r'bar_button_padding\s*=\s*(\d+)',
            "bar_buttons_alignment": r'bar_buttons_alignment\s*=\s*(\w+)',
        }
        
        # Color patterns - rgb() format
        color_patterns = {
            "col_text": r'col\.text\s*=\s*rgb[a]?\(([^)]+)\)',
            "bar_color": r'bar_color\s*=\s*rgb[a]?\(([^)]+)\)',
            "col_close": r'col\.button_close\s*=\s*rgb[a]?\(([^)]+)\)',
            "col_minimize": r'col\.button_minimize\s*=\s*rgb[a]?\(([^)]+)\)',
            "col_maximize": r'col\.button_maximize\s*=\s*rgb[a]?\(([^)]+)\)',
        }
        
        for key, pattern in patterns.items():
            m = re.search(pattern, block, re.IGNORECASE)
            if m:
                value = m.group(1).strip()
                if key in ["bar_height", "bar_text_size", "bar_padding", "bar_button_padding"]:
                    config[key] = int(value)
                else:
                    config[key] = value
        
        for key, pattern in color_patterns.items():
            m = re.search(pattern, block, re.IGNORECASE)
            if m:
                hex_val = m.group(1).strip()
                config[key] = f"#{hex_val}"
        
        print(f"[hyprbars] Parsed: bar_color={config['bar_color']}, col_text={config['col_text']}, font={config['bar_text_font']}")
                        
    except Exception as e:
        print(f"[hyprbars] Config parse error: {e}")
        import traceback
        traceback.print_exc()
    
    return config


def apply_hyprbars_config(config: dict, auto_reload: bool = True) -> bool:
    """Apply hyprbars configuration to hyprland.conf with automatic reload"""
    try:
        if not HYPRLAND_CONF.exists():
            print("[hyprbars] hyprland.conf not found")
            return False
            
        content = HYPRLAND_CONF.read_text()
        
        # Strip # from colors for rgb() format
        col_text = config.get("col_text", "#eceff4").lstrip("#")
        bar_color = config.get("bar_color", "#2e3440").lstrip("#")
        col_close = config.get("col_close", "#f38ba8").lstrip("#")
        col_minimize = config.get("col_minimize", "#f9e2af").lstrip("#")
        col_maximize = config.get("col_maximize", "#a6e3a1").lstrip("#")
        
        # Generate new hyprbars block content (indented for inside plugin {})
        new_block_content = f'''# Bar properties
bar_height = {config.get("bar_height", 28)}
bar_color = rgb({bar_color})
col.text = rgb({col_text})
# Button colors (macOS style)
col.button_close = rgb({col_close})
col.button_minimize = rgb({col_minimize})
col.button_maximize = rgb({col_maximize})
# Text styling
bar_text_size = {config.get("bar_text_size", 10)}
bar_text_font = {config.get("bar_text_font", "Adwaita Sans")}
bar_text_align = {config.get("bar_text_align", "center")}
# Padding
bar_padding = {config.get("bar_padding", 8)}
bar_button_padding = {config.get("bar_button_padding", 10)}
bar_buttons_alignment = {config.get("bar_buttons_alignment", "left")}
# Button actions
hyprbars-button = rgb({col_close}), 17, , hyprctl dispatch killactive
hyprbars-button = rgb({col_minimize}), 17, , ~/.config/hypr/scripts/waybar/hyprbars-minimize.sh
hyprbars-button = rgb({col_maximize}), 17, , hyprctl dispatch fullscreen 1
on_double_click = hyprctl dispatch fullscreen 1'''
        
        # Find and replace hyprbars block
        hyprbars_match = re.search(r'hyprbars\s*\{', content)
        
        if hyprbars_match:
            # Find the matching closing brace
            start = hyprbars_match.start()
            block_content_start = hyprbars_match.end()
            depth = 1
            pos = block_content_start
            
            while pos < len(content) and depth > 0:
                if content[pos] == '{':
                    depth += 1
                elif content[pos] == '}':
                    depth -= 1
                pos += 1
            
            end = pos
            
            # Check indentation level
            line_start = content.rfind('\n', 0, start) + 1
            indent = content[line_start:start]
            
            # Build new block with proper indentation
            new_block = f"hyprbars {{\n{new_block_content}\n{indent}}}"
            
            # Replace
            content = content[:start] + new_block + content[end:]
        else:
            # No existing block - add inside plugin {} if exists
            plugin_match = re.search(r'plugin\s*\{', content)
            if plugin_match:
                insert_pos = plugin_match.end()
                content = content[:insert_pos] + f"\n    hyprbars {{\n{new_block_content}\n    }}" + content[insert_pos:]
            else:
                # Add new plugin block
                content += f'''

# Hyprbars plugin configuration
plugin {{
    hyprbars {{
{new_block_content}
    }}
}}
'''
        
        HYPRLAND_CONF.write_text(content)
        print(f"[hyprbars] ✓ Updated hyprland.conf")
        print(f"[hyprbars]   bar_color: rgb({bar_color})")
        print(f"[hyprbars]   col.text: rgb({col_text})")
        print(f"[hyprbars]   font: {config.get('bar_text_font')}")
        
        # Auto reload hyprland config
        if auto_reload:
            result = subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=3)
            if result.returncode == 0:
                print("[hyprbars] ✓ Reloaded Hyprland config")
            else:
                print(f"[hyprbars] Reload warning: {result.stderr.decode() if result.stderr else 'unknown'}")
        
        return True
        
    except Exception as e:
        print(f"[hyprbars] Apply error: {e}")
        import traceback
        traceback.print_exc()
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
        print(f"[hyprbars] Font detection error: {e}")
    
    return "Adwaita Sans"


# ═══════════════════════════════════════════════════════════════════════════════
# PREVIEW WIDGET
# ═══════════════════════════════════════════════════════════════════════════════

class HyprbarsPreviewWidget(Gtk.DrawingArea):
    """Live preview of hyprbars title bar"""
    
    def __init__(self, config: dict):
        super().__init__()
        self.config = config.copy()
        self.set_size_request(-1, 80)
        self.set_draw_func(self._draw)
    
    def update_config(self, config: dict):
        self.config = config.copy()
        self.queue_draw()
    
    def _parse_color(self, hex_color: str) -> tuple:
        hex_color = hex_color.lstrip("#")
        if len(hex_color) == 6:
            r = int(hex_color[0:2], 16) / 255.0
            g = int(hex_color[2:4], 16) / 255.0
            b = int(hex_color[4:6], 16) / 255.0
            return (r, g, b, 1.0)
        return (0.12, 0.12, 0.17, 1.0)
    
    def _draw(self, area, cr, width, height):
        import math
        
        # Window background
        cr.set_source_rgba(0.15, 0.15, 0.20, 1.0)
        cr.rectangle(0, 0, width, height)
        cr.fill()
        
        # Title bar
        bar_height = self.config.get("bar_height", 28)
        bar_color = self._parse_color(self.config.get("bar_color", "#2e3440"))
        cr.set_source_rgba(*bar_color)
        cr.rectangle(0, 0, width, bar_height)
        cr.fill()
        
        # Buttons
        buttons_left = self.config.get("bar_buttons_alignment", "left") == "left"
        button_padding = self.config.get("bar_button_padding", 10)
        button_radius = 7
        button_spacing = 24
        
        colors = [
            self._parse_color(self.config.get("col_close", "#f38ba8")),
            self._parse_color(self.config.get("col_minimize", "#f9e2af")),
            self._parse_color(self.config.get("col_maximize", "#a6e3a1")),
        ]
        
        for i, color in enumerate(colors):
            if buttons_left:
                x = button_padding + 10 + (i * button_spacing)
            else:
                x = width - button_padding - 10 - ((2 - i) * button_spacing)
            
            y = bar_height / 2
            cr.set_source_rgba(*color)
            cr.arc(x, y, button_radius, 0, 2 * math.pi)
            cr.fill()
        
        # Title text
        text_color = self._parse_color(self.config.get("col_text", "#eceff4"))
        cr.set_source_rgba(*text_color)
        
        text = "Window Title"
        font_size = self.config.get("bar_text_size", 10)
        cr.select_font_face(self.config.get("bar_text_font", "Sans"), 0, 0)
        cr.set_font_size(font_size)
        
        extents = cr.text_extents(text)
        text_align = self.config.get("bar_text_align", "center")
        
        if text_align == "left":
            text_x = button_padding + 80 if buttons_left else button_padding + 10
        elif text_align == "right":
            text_x = width - extents.width - (button_padding + 80 if not buttons_left else button_padding + 10)
        else:
            text_x = (width - extents.width) / 2
        
        text_y = (bar_height + extents.height) / 2
        cr.move_to(text_x, text_y)
        cr.show_text(text)


# ═══════════════════════════════════════════════════════════════════════════════
# THEMED UI COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════

def create_themed_dropdown(options: list, current: str, on_change, colors: dict) -> Gtk.DropDown:
    """Create a themed dropdown"""
    model = Gtk.StringList()
    current_idx = 0
    
    for i, opt in enumerate(options):
        model.append(opt)
        if opt.lower() == current.lower():
            current_idx = i
    
    dd = Gtk.DropDown()
    dd.set_model(model)
    dd.set_selected(current_idx)
    dd.add_css_class("themed-dropdown")
    
    dd.connect("notify::selected", lambda d, _: on_change(options[d.get_selected()]))
    
    return dd


def create_color_button(label: str, color: str, on_change, colors: dict = None) -> Gtk.Box:
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
    btn.connect("color-set", lambda b: on_change(f"#{int(b.get_rgba().red*255):02x}{int(b.get_rgba().green*255):02x}{int(b.get_rgba().blue*255):02x}"))
    row.append(btn)
    
    return row


def create_spin_row(label: str, value: int, min_val: int, max_val: int, on_change, colors: dict = None) -> Gtk.Box:
    """Create a spin button row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_top(4)
    row.set_margin_bottom(4)
    
    lbl = Gtk.Label(label=label)
    lbl.set_xalign(0)
    lbl.set_hexpand(True)
    row.append(lbl)
    
    spin = Gtk.SpinButton.new_with_range(min_val, max_val, 1)
    spin.set_value(value)
    spin.add_css_class("themed-spin")
    spin.connect("value-changed", lambda s: on_change(int(s.get_value())))
    row.append(spin)
    
    return row


def create_dropdown_row(label: str, options: list, current: str, on_change, colors: dict) -> Gtk.Box:
    """Create a dropdown row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_top(4)
    row.set_margin_bottom(4)
    
    lbl = Gtk.Label(label=label)
    lbl.set_xalign(0)
    lbl.set_hexpand(True)
    row.append(lbl)
    
    dd = create_themed_dropdown(options, current, on_change, colors)
    row.append(dd)
    
    return row


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SECTION BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_hyprbars_section(window, theme_colors: dict) -> Gtk.Widget:
    """Build the hyprbars configuration section"""
    
    if not is_hyprbars_active():
        empty = Gtk.Box()
        empty.set_visible(False)
        return empty
    
    # Get current config from hyprland.conf
    config = get_hyprbars_config()
    window.current_hyprbars_config = config.copy()
    
    # Sync with theme colors (bg0 -> bar_color, fg -> col_text)
    if theme_colors:
        window.current_hyprbars_config["bar_color"] = theme_colors.get("bg0", config["bar_color"])
        window.current_hyprbars_config["col_text"] = theme_colors.get("fg", config["col_text"])
    
    # Sync with waybar font
    if hasattr(window, 'current_waybar_config') and window.current_waybar_config:
        waybar_font = window.current_waybar_config.get("font_family", "")
        if waybar_font:
            window.current_hyprbars_config["bar_text_font"] = waybar_font
    
    # Main container
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    box.set_margin_start(16)
    box.set_margin_end(16)
    box.set_margin_top(8)
    box.set_margin_bottom(16)
    
    # Preview
    preview = HyprbarsPreviewWidget(window.current_hyprbars_config)
    window.hyprbars_preview = preview
    
    frame = Gtk.Frame()
    frame.set_child(preview)
    frame.set_margin_bottom(12)
    box.append(frame)
    
    def update_preview():
        if hasattr(window, 'hyprbars_preview'):
            window.hyprbars_preview.update_config(window.current_hyprbars_config)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # COLORS SECTION
    # ═══════════════════════════════════════════════════════════════════════════
    colors_label = Gtk.Label(label="COLORS")
    colors_label.add_css_class("caption")
    colors_label.add_css_class("dim-label")
    colors_label.set_xalign(0)
    colors_label.set_margin_top(8)
    box.append(colors_label)
    
    def on_bar_color(val):
        window.current_hyprbars_config["bar_color"] = val
        update_preview()
    
    bar_color_row = create_color_button(
        "Bar Background (synced with bg0)",
        window.current_hyprbars_config.get("bar_color", "#2e3440"),
        on_bar_color, theme_colors
    )
    window.hyprbars_bar_color_btn = bar_color_row.get_last_child()
    box.append(bar_color_row)
    
    def on_text_color(val):
        window.current_hyprbars_config["col_text"] = val
        update_preview()
    
    text_color_row = create_color_button(
        "Text Color (synced with fg)",
        window.current_hyprbars_config.get("col_text", "#eceff4"),
        on_text_color, theme_colors
    )
    window.hyprbars_text_color_btn = text_color_row.get_last_child()
    box.append(text_color_row)
    
    # Button colors
    def on_close_color(val):
        window.current_hyprbars_config["col_close"] = val
        update_preview()
    
    box.append(create_color_button(
        "Close Button",
        window.current_hyprbars_config.get("col_close", "#f38ba8"),
        on_close_color, theme_colors
    ))
    
    def on_minimize_color(val):
        window.current_hyprbars_config["col_minimize"] = val
        update_preview()
    
    box.append(create_color_button(
        "Minimize Button",
        window.current_hyprbars_config.get("col_minimize", "#f9e2af"),
        on_minimize_color, theme_colors
    ))
    
    def on_maximize_color(val):
        window.current_hyprbars_config["col_maximize"] = val
        update_preview()
    
    box.append(create_color_button(
        "Maximize Button",
        window.current_hyprbars_config.get("col_maximize", "#a6e3a1"),
        on_maximize_color, theme_colors
    ))
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TEXT SETTINGS
    # ═══════════════════════════════════════════════════════════════════════════
    text_label = Gtk.Label(label="TEXT SETTINGS")
    text_label.add_css_class("caption")
    text_label.add_css_class("dim-label")
    text_label.set_xalign(0)
    text_label.set_margin_top(16)
    box.append(text_label)
    
    # Font Family
    font_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    font_row.set_margin_top(4)
    font_row.set_margin_bottom(4)
    
    font_lbl = Gtk.Label(label="Font Family (synced with Waybar)")
    font_lbl.set_xalign(0)
    font_lbl.set_hexpand(True)
    font_row.append(font_lbl)
    
    font_options = [display for display, _ in FONT_FAMILIES]
    current_font = window.current_hyprbars_config.get("bar_text_font", "Adwaita Sans")
    current_display = "Adwaita Sans"
    
    for display, actual in FONT_FAMILIES:
        if actual.lower() in current_font.lower() or current_font.lower() in actual.lower():
            current_display = display
            break
    
    def on_font_change(selected_display):
        for display, actual in FONT_FAMILIES:
            if display == selected_display:
                window.current_hyprbars_config["bar_text_font"] = actual
                update_preview()
                break
    
    font_dd = create_themed_dropdown(font_options, current_display, on_font_change, theme_colors)
    window.hyprbars_font_dropdown = font_dd
    font_row.append(font_dd)
    box.append(font_row)
    
    # Text Size
    def on_text_size(val):
        window.current_hyprbars_config["bar_text_size"] = val
        update_preview()
    
    box.append(create_spin_row(
        "Text Size",
        window.current_hyprbars_config.get("bar_text_size", 10),
        8, 24, on_text_size, theme_colors
    ))
    
    # Text Alignment
    def on_text_align(val):
        window.current_hyprbars_config["bar_text_align"] = val.lower()
        update_preview()
    
    box.append(create_dropdown_row(
        "Text Alignment",
        ["left", "center", "right"],
        window.current_hyprbars_config.get("bar_text_align", "center"),
        on_text_align, theme_colors
    ))
    
    # ═══════════════════════════════════════════════════════════════════════════
    # LAYOUT SETTINGS
    # ═══════════════════════════════════════════════════════════════════════════
    layout_label = Gtk.Label(label="LAYOUT")
    layout_label.add_css_class("caption")
    layout_label.add_css_class("dim-label")
    layout_label.set_xalign(0)
    layout_label.set_margin_top(16)
    box.append(layout_label)
    
    def on_bar_height(val):
        window.current_hyprbars_config["bar_height"] = val
        update_preview()
    
    box.append(create_spin_row(
        "Bar Height",
        window.current_hyprbars_config.get("bar_height", 28),
        20, 50, on_bar_height, theme_colors
    ))
    
    def on_bar_padding(val):
        window.current_hyprbars_config["bar_padding"] = val
        update_preview()
    
    box.append(create_spin_row(
        "Bar Padding",
        window.current_hyprbars_config.get("bar_padding", 8),
        0, 20, on_bar_padding, theme_colors
    ))
    
    def on_button_padding(val):
        window.current_hyprbars_config["bar_button_padding"] = val
        update_preview()
    
    box.append(create_spin_row(
        "Button Padding",
        window.current_hyprbars_config.get("bar_button_padding", 10),
        0, 20, on_button_padding, theme_colors
    ))
    
    # Buttons Alignment
    def on_buttons_align(val):
        window.current_hyprbars_config["bar_buttons_alignment"] = val.lower()
        update_preview()
    
    box.append(create_dropdown_row(
        "Buttons Position",
        ["left", "right"],
        window.current_hyprbars_config.get("bar_buttons_alignment", "left"),
        on_buttons_align, theme_colors
    ))
    
    return box


def sync_hyprbars_with_theme(window, theme_colors: dict):
    """Sync hyprbars colors when theme changes - bg0 -> bar_color, fg -> col_text"""
    if not hasattr(window, 'current_hyprbars_config'):
        return
    
    # Sync bar_color with bg0
    if "bg0" in theme_colors:
        window.current_hyprbars_config["bar_color"] = theme_colors["bg0"]
        if hasattr(window, 'hyprbars_bar_color_btn'):
            rgba = Gdk.RGBA()
            rgba.parse(theme_colors["bg0"])
            window.hyprbars_bar_color_btn.set_rgba(rgba)
    
    # Sync col_text with fg
    if "fg" in theme_colors:
        window.current_hyprbars_config["col_text"] = theme_colors["fg"]
        if hasattr(window, 'hyprbars_text_color_btn'):
            rgba = Gdk.RGBA()
            rgba.parse(theme_colors["fg"])
            window.hyprbars_text_color_btn.set_rgba(rgba)
    
    # Update preview
    if hasattr(window, 'hyprbars_preview'):
        window.hyprbars_preview.update_config(window.current_hyprbars_config)


def sync_hyprbars_with_waybar_font(window, font_name: str):
    """Sync hyprbars font when waybar font changes"""
    if not hasattr(window, 'current_hyprbars_config'):
        return
    
    window.current_hyprbars_config["bar_text_font"] = font_name
    
    # Update font dropdown selection
    if hasattr(window, 'hyprbars_font_dropdown'):
        for i, (display, actual) in enumerate(FONT_FAMILIES):
            if actual.lower() in font_name.lower() or font_name.lower() in actual.lower():
                window.hyprbars_font_dropdown.set_selected(i)
                break
    
    # Update preview
    if hasattr(window, 'hyprbars_preview'):
        window.hyprbars_preview.update_config(window.current_hyprbars_config)


def apply_hyprbars_settings(window) -> bool:
    """Apply current hyprbars settings with automatic hyprctl reload"""
    if not hasattr(window, 'current_hyprbars_config'):
        print("[hyprbars] No config found on window")
        return False
    
    # Make sure we have latest theme colors synced
    if hasattr(window, 'current_theme_colors'):
        window.current_hyprbars_config["bar_color"] = window.current_theme_colors.get("bg0", window.current_hyprbars_config["bar_color"])
        window.current_hyprbars_config["col_text"] = window.current_theme_colors.get("fg", window.current_hyprbars_config["col_text"])
    
    # Make sure waybar font is synced
    if hasattr(window, 'current_waybar_config') and window.current_waybar_config:
        waybar_font = window.current_waybar_config.get("font_family", "")
        if waybar_font:
            window.current_hyprbars_config["bar_text_font"] = waybar_font
    
    return apply_hyprbars_config(window.current_hyprbars_config, auto_reload=True)


# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

__all__ = [
    'is_hyprbars_active',
    'get_hyprbars_config',
    'apply_hyprbars_config',
    'build_hyprbars_section',
    'sync_hyprbars_with_theme',
    'sync_hyprbars_with_waybar_font',
    'apply_hyprbars_settings',
    'HyprbarsPreviewWidget',
    'FONT_FAMILIES',
    'DEFAULT_HYPRBARS_CONFIG',
]