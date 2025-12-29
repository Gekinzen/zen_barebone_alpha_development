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
    
    # Theme source section
    source_group = SettingsGroup("Theme Source")
    
    # Get current mode
    current_mode = theme_mgr.get_theme_source_mode()
    
    # Mode selector (radio-style toggle)
    from ..widgets import ToggleRow
    
    use_custom = current_mode == "custom"
    toggle_row = ToggleRow(
        "Use Custom Color Scheme",
        use_custom,
        lambda v: _on_theme_source_toggle(window, v),
        "When OFF, follows system GTK theme instead"
    )
    source_group.append(toggle_row)
    
    page.append(source_group)
    
    # Current theme section (only show if custom mode)
    if current_mode == "custom":
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
    else:
        # GTK mode - show info
        gtk_info_group = SettingsGroup("System GTK Theme")
        
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        info_box.set_margin_top(8)
        info_box.set_margin_bottom(12)
        
        info_label = Gtk.Label(
            label="Currently following your system GTK theme.\nColors will match your desktop environment.",
            xalign=0,
            wrap=True
        )
        info_label.add_css_class('dim-label')
        info_box.append(info_label)
        
        gtk_info_group.append(info_box)
        page.append(gtk_info_group)
    
    # Restart app section
    restart_group = SettingsGroup("Apply Theme Fully")
    
    restart_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    restart_box.set_margin_top(8)
    restart_box.set_margin_bottom(12)
    
    info_label = Gtk.Label(
        label="For full theme effect, restart the application:",
        xalign=0
    )
    info_label.add_css_class('dim-label')
    restart_box.append(info_label)
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    btn_box.set_halign(Gtk.Align.START)
    
    restart_btn = Gtk.Button(label="Restart App")
    restart_btn.add_css_class('suggested-action')
    restart_btn.connect('clicked', lambda b: _restart_app())
    btn_box.append(restart_btn)
    
    restart_box.append(btn_box)
    restart_group.append(restart_box)
    page.append(restart_group)
    
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


def _on_theme_source_toggle(window, use_custom: bool):
    """Handle theme source toggle"""
    theme_mgr = window.theme_manager
    
    # Set mode
    mode = "custom" if use_custom else "gtk"
    theme_mgr.set_theme_source_mode(mode)
    
    # Show toast
    if use_custom:
        window._show_toast("Using custom color schemes")
    else:
        window._show_toast("Following system GTK theme")
    
    # Refresh page to show/hide theme selector
    _refresh_themes_page(window)


def _on_theme_change(window, theme_id: str):
    """Handle theme selection change"""
    theme_mgr = window.theme_manager
    
    # Apply theme
    success = theme_mgr.apply_theme(theme_id)
    
    if success:
        # Show toast
        window._show_toast(f"Theme applied: {theme_mgr.THEMES[theme_id]['name']}")
        
        # Refresh themes page to show new color preview
        _refresh_themes_page(window)
        
        # Notify about restart for full effect
        import subprocess
        subprocess.Popen([
            'notify-send',
            'Theme Applied',
            'App theme updated! Waybar reloaded.',
            '-t', '3000'
        ])
    else:
        window._show_toast("Failed to apply theme")


def _refresh_themes_page(window):
    """Refresh themes page to show updated color preview"""
    # Rebuild the themes page
    new_page = build_themes_page(window)
    
    # Replace in stack
    old_page = window.stack.get_child_by_name("themes")
    if old_page:
        window.stack.remove(old_page)
    
    window.stack.add_named(new_page, "themes")
    window.stack.set_visible_child_name("themes")


def _restart_app():
    """Restart the application to apply theme fully"""
    import os
    import sys
    
    # Kill current process and restart
    os.execv(sys.executable, ['python3'] + sys.argv)


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