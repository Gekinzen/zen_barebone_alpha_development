"""
Themes Page - Global theme management
Allows switching themes for Control Center, Waybar, and Rofi
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw

from ..theme_manager import ThemeManager
from ..widgets import SettingsGroup, DropdownRow, ActionRow

def build_themes_page(window) -> Gtk.Box:
    """Build the Themes configuration page"""
    
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    page.set_margin_start(32)
    page.set_margin_end(32)
    
    # Page header
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    header.set_margin_bottom(24)
    
    title = Gtk.Label(label="Theme Switcher")
    title.add_css_class('page-title')
    title.set_xalign(0)
    header.append(title)
    
    subtitle = Gtk.Label(
        label="Customize color themes for Control Center, Waybar, and Rofi"
    )
    subtitle.add_css_class('page-subtitle')
    subtitle.set_xalign(0)
    header.append(subtitle)
    
    page.append(header)
    
    # Initialize theme manager
    theme_mgr = ThemeManager()
    window.theme_manager = theme_mgr
    
    # Current theme section
    current_group = SettingsGroup("Current Theme")
    
    # Get available themes
    available_themes = theme_mgr.get_available_themes()
    theme_names = [t["name"] for t in available_themes]
    theme_ids = [t["id"] for t in available_themes]
    
    # Get current theme
    current_theme_id = theme_mgr.get_current_theme()
    current_theme_idx = theme_ids.index(current_theme_id) if current_theme_id in theme_ids else 0
    
    # Theme dropdown
    theme_row = DropdownRow(
        "Color Scheme",
        theme_names,
        theme_names[current_theme_idx],
        lambda name: _on_theme_change(window, theme_ids[theme_names.index(name)]),
        "Select theme to apply globally"
    )
    current_group.append(theme_row)
    
    page.append(current_group)
    
    # Theme preview section
    preview_group = SettingsGroup("Theme Preview")
    
    # Show current theme colors
    colors = theme_mgr.get_theme_colors(current_theme_id)
    if colors:
        preview_box = _create_color_preview(colors)
        preview_group.append(preview_box)
    
    page.append(preview_group)
    
    # Applied to section
    applies_group = SettingsGroup("Applies To")
    
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    info_box.set_margin_top(8)
    info_box.set_margin_bottom(12)
    
    applies_list = [
        "✓ Control Center UI",
        "✓ Waybar Panel",
        "⚬ Rofi Launcher (coming soon)"
    ]
    
    for item in applies_list:
        label = Gtk.Label(label=item, xalign=0)
        label.add_css_class('dim-label')
        info_box.append(label)
    
    applies_group.append(info_box)
    page.append(applies_group)
    
    # Available themes info
    themes_info_group = SettingsGroup("Available Themes")
    
    for theme_info in available_themes:
        row = ActionRow(
            theme_info["name"],
            theme_info["description"]
        )
        themes_info_group.append(row)
    
    page.append(themes_info_group)
    
    return page


def _on_theme_change(window, theme_id: str):
    """Handle theme selection change"""
    theme_mgr = window.theme_manager
    
    # Apply theme
    success = theme_mgr.apply_theme(theme_id)
    
    if success:
        # Show toast
        window._show_toast(f"Theme applied: {theme_mgr.THEMES[theme_id]['name']}")
        
        # Refresh UI to show new theme
        # Note: Full app restart recommended for best results
        import subprocess
        subprocess.Popen([
            'notify-send',
            'Theme Applied',
            'Restart app to see full theme changes',
            '-t', '3000'
        ])
    else:
        window._show_toast("Failed to apply theme")


def _create_color_preview(colors: dict) -> Gtk.Box:
    """Create color preview widget"""
    preview = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    preview.set_margin_top(12)
    preview.set_margin_bottom(12)
    
    # Main colors row
    main_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    main_row.set_halign(Gtk.Align.START)
    
    main_colors = [
        ("bg0", "Background"),
        ("fg", "Text"),
        ("blue", "Accent"),
        ("red", "Alert"),
        ("green", "Success")
    ]
    
    for color_key, color_name in main_colors:
        if color_key in colors:
            swatch = _create_color_swatch(colors[color_key], color_name)
            main_row.append(swatch)
    
    preview.append(main_row)
    
    # Extended colors row
    extended_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    extended_row.set_halign(Gtk.Align.START)
    
    extended_colors = [
        ("orange", "Orange"),
        ("yellow", "Yellow"),
        ("aqua", "Aqua"),
        ("purple", "Purple")
    ]
    
    for color_key, color_name in extended_colors:
        if color_key in colors:
            swatch = _create_color_swatch(colors[color_key], color_name)
            extended_row.append(swatch)
    
    preview.append(extended_row)
    
    return preview


def _create_color_swatch(color: str, name: str) -> Gtk.Box:
    """Create a single color swatch"""
    swatch_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    
    # Color box
    color_area = Gtk.DrawingArea()
    color_area.set_size_request(48, 48)
    color_area.set_content_width(48)
    color_area.set_content_height(48)
    
    # Set background color using CSS
    css_provider = Gtk.CssProvider()
    css = f"""
    * {{
        background-color: {color};
        border-radius: 8px;
        border: 1px solid rgba(255, 255, 255, 0.1);
    }}
    """
    css_provider.load_from_data(css.encode())
    color_area.get_style_context().add_provider(
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    
    swatch_box.append(color_area)
    
    # Label
    label = Gtk.Label(label=name)
    label.add_css_class('caption')
    label.add_css_class('dim-label')
    swatch_box.append(label)
    
    return swatch_box