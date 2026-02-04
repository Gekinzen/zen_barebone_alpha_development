"""
═══════════════════════════════════════════════════════════════════════════════
THEMING MODULE - Hyprland Control Center v2.4 MODULAR
Complete Theme Management with ALL v2.1 Features + Hyprbars + SwayNC Support
═══════════════════════════════════════════════════════════════════════════════

Features:
- CLICKABLE COLOR SWATCHES: Click any color in Theme Preview to edit
- PANEL STYLE PRESETS: Dropdown with Classic, Modern Dark, Modern Light, Warm, Zen
- WORKSPACE BUTTON STYLING: Full customization (radius, width)
- HOVER EFFECTS: Customizable hover radius, background, text color
- MODULE ICON COLORS: Per-module color override
- FULL CSS GENERATION: Complete CSS for all apps
- 16 BUILTIN THEMES: All rofi themes converted
- HYPRBARS SUPPORT: Auto-detect plugin, sync colors/fonts with theme (v2.3)
- SWAYNC SUPPORT: Auto-sync notification center colors (v2.4)
- THEMED DROPDOWNS: bg4 background, fg text styling (v2.4)
"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Gdk, Adw
import sys
import os
from pathlib import Path

# Add theming_modules to path
_this_dir = Path(__file__).parent
_modules_dir = _this_dir / "theming_modules"
if _modules_dir.exists() and str(_this_dir) not in sys.path:
    sys.path.insert(0, str(_this_dir))

# Imports - try relative first
try:
    from theming_modules.constants import *
    from theming_modules.themes_data import BUILTIN_THEMES
    from theming_modules.helpers import is_light_theme, get_saved_theme_data, apply_hyprland_rounding
    from theming_modules.profile_manager import ThemeProfileManager
    from theming_modules.applier import ThemeApplier
    from theming_modules.css_generators import generate_control_center_css, generate_start_menu_css, generate_panel_widget_css
    from theming_modules.previews import WaybarPreviewWidget, RofiPreviewWidget, KittyPreviewWidget
    from theming_modules.ui_components import ClickableColorSwatch, ModuleColorRow, ColorPickerRow, create_group, create_section_header, create_setting_row
    from theming_modules.waybar_section import build_waybar_section
    from theming_modules.panel_styles import PANEL_STYLE_PRESETS
    from theming_modules.start_menu_section import build_start_menu_taskbar_section
    from theming_modules.dialogs import show_new_dialog, show_save_dialog, show_export_dialog, show_import_dialog, show_delete_dialog
    from theming_modules.hyprbars_section import (
        is_hyprbars_active, build_hyprbars_section, sync_hyprbars_with_theme,
        sync_hyprbars_with_waybar_font, apply_hyprbars_settings
    )
    from theming_modules.swaync_section import (
        is_swaync_installed, build_swaync_section, sync_swaync_with_theme,
        apply_swaync_colorscheme, apply_swaync_settings
    )
except ImportError:
    from .theming_modules.constants import *
    from .theming_modules.themes_data import BUILTIN_THEMES
    from .theming_modules.helpers import is_light_theme, get_saved_theme_data, apply_hyprland_rounding
    from .theming_modules.profile_manager import ThemeProfileManager
    from .theming_modules.applier import ThemeApplier
    from .theming_modules.css_generators import generate_control_center_css, generate_start_menu_css, generate_panel_widget_css
    from .theming_modules.previews import WaybarPreviewWidget, RofiPreviewWidget, KittyPreviewWidget
    from .theming_modules.ui_components import ClickableColorSwatch, ModuleColorRow, ColorPickerRow, create_group, create_section_header, create_setting_row
    from .theming_modules.waybar_section import build_waybar_section
    from .theming_modules.panel_styles import PANEL_STYLE_PRESETS
    from .theming_modules.start_menu_section import build_start_menu_taskbar_section
    from .theming_modules.dialogs import show_new_dialog, show_save_dialog, show_export_dialog, show_import_dialog, show_delete_dialog
    from .theming_modules.hyprbars_section import (
        is_hyprbars_active, build_hyprbars_section, sync_hyprbars_with_theme,
        sync_hyprbars_with_waybar_font, apply_hyprbars_settings
    )
    from .theming_modules.swaync_section import (
        is_swaync_installed, build_swaync_section, sync_swaync_with_theme,
        apply_swaync_colorscheme, apply_swaync_settings
    )

_CSS_PROVIDER = None

# ═══════════════════════════════════════════════════════════════════════════════
# THEMED DROPDOWN CSS (v2.4) - bg4 background, fg text
# ═══════════════════════════════════════════════════════════════════════════════

def _get_dropdown_css(colors: dict) -> str:
    """Generate CSS for themed dropdowns"""
    bg4 = colors.get("bg4", "#4b5263")
    fg = colors.get("fg", "#abb2bf")
    bg3 = colors.get("bg3", "#3e4451")
    blue = colors.get("blue", "#61afef")
    
    return f'''
/* Themed Dropdowns (v2.4) - bg4 background, fg text */
dropdown.themed-dropdown,
.themed-dropdown > button {{
    background: {bg4};
    color: {fg};
    border-radius: 6px;
    padding: 4px 8px;
    min-height: 32px;
}}

dropdown.themed-dropdown:hover,
.themed-dropdown > button:hover {{
    background: {bg3};
}}

dropdown.themed-dropdown:focus,
.themed-dropdown > button:focus {{
    outline: 2px solid {blue};
    outline-offset: -2px;
}}

dropdown.themed-dropdown popover,
.themed-dropdown popover {{
    background: {bg4};
}}

dropdown.themed-dropdown popover modelbutton,
.themed-dropdown popover modelbutton {{
    color: {fg};
    padding: 8px 12px;
}}

dropdown.themed-dropdown popover modelbutton:hover,
.themed-dropdown popover modelbutton:hover {{
    background: {bg3};
}}

dropdown.themed-dropdown popover modelbutton:selected,
.themed-dropdown popover modelbutton:selected {{
    background: {blue};
    color: #ffffff;
}}

spinbutton.themed-spin {{
    background: {bg4};
    color: {fg};
    border-radius: 6px;
}}

spinbutton.themed-spin:focus {{
    outline: 2px solid {blue};
    outline-offset: -2px;
}}
'''

# ═══════════════════════════════════════════════════════════════════════════════
# THEME INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

def initialize_saved_theme(window=None) -> dict:
    """Initialize theme from saved preferences on app startup"""
    global _CSS_PROVIDER
    
    data = get_saved_theme_data()
    if not data:
        data = {"id": "one-dark", "name": "One Dark", "colors": BUILTIN_THEMES["one-dark"]["colors"], "is_builtin": True}
    
    colors = data.get('colors', BUILTIN_THEMES["one-dark"]["colors"])
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Generate CSS with themed dropdown styles (v2.4)
    base_css = generate_control_center_css(colors)
    dropdown_css = _get_dropdown_css(colors)
    full_css = base_css + "\n" + dropdown_css
    
    CONTROL_CENTER_CSS.write_text(full_css)
    START_MENU_CSS.write_text(generate_start_menu_css(colors))
    PANEL_WIDGET_CSS.write_text(generate_panel_widget_css(colors))
    
    display = Gdk.Display.get_default()
    if display:
        if _CSS_PROVIDER:
            try: Gtk.StyleContext.remove_provider_for_display(display, _CSS_PROVIDER)
            except: pass
        _CSS_PROVIDER = Gtk.CssProvider()
        try:
            _CSS_PROVIDER.load_from_path(str(CONTROL_CENTER_CSS))
            Gtk.StyleContext.add_provider_for_display(display, _CSS_PROVIDER, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100)
        except: pass
    
    if window: window.queue_resize()
    return data

def ensure_theme_initialized(window=None) -> dict:
    return initialize_saved_theme(window)


# ═══════════════════════════════════════════════════════════════════════════════
# REFRESH & APPLY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def _refresh_ui(window, pm):
    """Refresh all UI elements with current theme"""
    theme = pm.get_active_theme()
    colors = theme.get("colors", BUILTIN_THEMES["one-dark"]["colors"])
    window.current_theme_colors = colors.copy()
    window.current_waybar_config = theme.get("waybar", DEFAULT_WAYBAR_CONFIG).copy()
    window.current_rofi_config = theme.get("rofi", {}).copy()
    window.current_kitty_config = theme.get("kitty", {}).copy()
    
    # Update clickable color swatches
    if hasattr(window, 'color_swatches'):
        for k, swatch in window.color_swatches.items():
            if k in colors:
                if hasattr(swatch, 'set_color'):
                    swatch.set_color(colors[k])
                elif hasattr(swatch, 'swatch'):
                    swatch.swatch.hex_color = colors[k]
                    swatch.swatch.queue_draw()
    
    # Update previews
    if hasattr(window, 'waybar_preview'):
        window.waybar_preview.update_colors(colors)
        if hasattr(window.waybar_preview, 'update_waybar_config'):
            window.waybar_preview.update_waybar_config(window.current_waybar_config)
    if hasattr(window, 'rofi_preview'):
        window.rofi_preview.update_colors(colors)
        window.rofi_preview.update_rofi(window.current_rofi_config)
    if hasattr(window, 'kitty_preview'):
        window.kitty_preview.update_colors(colors)
        window.kitty_preview.update_kitty(window.current_kitty_config)
    
    # Sync hyprbars with new theme colors (v2.3)
    sync_hyprbars_with_theme(window, colors)

def _refresh_dropdown(window, pm):
    """Refresh theme dropdown"""
    themes = pm.get_all_themes()
    window.all_themes = themes
    model = Gtk.StringList()
    active_idx, active_id = 0, pm.profiles.get("active_profile", "one-dark")
    for i, t in enumerate(themes):
        model.append(f"{'● ' if t['is_builtin'] else '◆ '}{t['name']}")
        if t["id"] == active_id: active_idx = i
    window.theme_dropdown.set_model(model)
    window.theme_dropdown.set_selected(active_idx)
    if hasattr(window, 'delete_btn'):
        window.delete_btn.set_sensitive(not themes[active_idx]["is_builtin"] if themes else False)

def _reload_start_menu() -> bool:
    """Send SIGUSR2 to start-menu.py to reload theme"""
    import signal
    import subprocess
    
    pid_file = Path("/tmp/hypr-startmenu.pid")
    try:
        if pid_file.exists():
            pid = int(pid_file.read_text().strip())
            # Check if process exists
            try:
                os.kill(pid, 0)  # Signal 0 just checks if process exists
                os.kill(pid, signal.SIGUSR2)
                print(f"[start-menu] ✓ Sent SIGUSR2 to PID {pid}")
                return True
            except ProcessLookupError:
                print("[start-menu] Process not running")
                return False
            except PermissionError:
                print("[start-menu] Permission denied")
                return False
    except Exception as e:
        print(f"[start-menu] Reload error: {e}")
    return False

def _apply_theme(window, pm):
    """Apply the current theme to all applications"""
    theme = pm.get_active_theme()
    data = {
        "id": theme.get("id"), "name": theme.get("name"),
        "colors": window.current_theme_colors,
        "waybar": window.current_waybar_config,
        "rofi": window.current_rofi_config,
        "kitty": window.current_kitty_config,
        "is_builtin": theme.get("is_builtin", True)
    }
    
    if not theme.get("is_builtin", True):
        pm.update_custom_theme(theme.get("id"), data)
    
    results = []
    if ThemeApplier.apply_waybar_colorscheme(data):
        results.append("Waybar"); ThemeApplier.reload_waybar()
    if ThemeApplier.apply_rofi_colors(data):
        results.append("Rofi")
    if ThemeApplier.apply_kitty_colors(data):
        results.append("Kitty"); ThemeApplier.reload_kitty()
    if ThemeApplier.apply_control_center_theme(data, window):
        results.append("Control Center")
    
    # Apply hyprbars settings (v2.3) - with auto hyprctl reload
    if is_hyprbars_active():
        sync_hyprbars_with_theme(window, window.current_theme_colors)
        if apply_hyprbars_settings(window):
            results.append("Hyprbars")
    
    # Apply SwayNC colorscheme (v2.4) - uses manual colors from window.current_swaync_config
    if is_swaync_installed():
        if apply_swaync_settings(window):
            results.append("SwayNC")
    
    # Reload Start Menu theme via SIGUSR2 (v2.4)
    if _reload_start_menu():
        results.append("Start Menu")
    
    if results:
        ThemeApplier.notify("Theme Applied", f"Updated: {', '.join(results)}")

def _reset_theme(window, pm):
    """Reset to default theme"""
    pm.set_active_theme("one-dark", True)
    _refresh_dropdown(window, pm)
    _refresh_ui(window, pm)
    ThemeApplier.apply_control_center_theme(pm.get_active_theme(), window)
    ThemeApplier.notify("Theme Reset", "Reset to One Dark")

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_theming_page(window) -> Gtk.ScrolledWindow:
    """Build the complete Theming page with ALL v2.1 features + Hyprbars (v2.3) + SwayNC (v2.4)"""
    
    ensure_theme_initialized(window)
    
    pm = ThemeProfileManager()
    theme = pm.get_active_theme()
    colors = theme.get("colors", BUILTIN_THEMES["one-dark"]["colors"])
    waybar = theme.get("waybar", DEFAULT_WAYBAR_CONFIG)
    rofi = theme.get("rofi", {})
    kitty = theme.get("kitty", {})
    
    window.current_theme_colors = colors.copy()
    window.current_waybar_config = waybar.copy()
    window.current_rofi_config = rofi.copy()
    window.current_kitty_config = kitty.copy()
    window.color_swatches = {}
    window.theme_profile_manager = pm
    
    # Main container
    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroll.set_vexpand(True)
    
    main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    main_box.set_margin_start(24); main_box.set_margin_end(24)
    main_box.set_margin_top(24); main_box.set_margin_bottom(24)
    scroll.set_child(main_box)
    
    # Page Title
    title = Gtk.Label(label="Theming")
    title.add_css_class("title-1"); title.set_xalign(0)
    main_box.append(title)
    
    subtitle = Gtk.Label(label="Customize colors for Waybar, Rofi, Kitty, Hyprbars, SwayNC, and the Control Center")
    subtitle.add_css_class("dim-label"); subtitle.set_xalign(0); subtitle.set_margin_bottom(24)
    main_box.append(subtitle)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PROFILE SELECTION
    # ═══════════════════════════════════════════════════════════════════════════
    profile_group = create_group("PROFILE")
    
    profile_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    profile_row.set_margin_start(16); profile_row.set_margin_end(16)
    profile_row.set_margin_top(8); profile_row.set_margin_bottom(12)
    
    themes = pm.get_all_themes()
    window.all_themes = themes
    
    dd = Gtk.DropDown()
    dd.add_css_class("themed-dropdown")  # v2.4 themed dropdown
    model = Gtk.StringList()
    active_idx, active_id = 0, pm.profiles.get("active_profile", "one-dark")
    for i, t in enumerate(themes):
        model.append(f"{'● ' if t['is_builtin'] else '◆ '}{t['name']}")
        if t["id"] == active_id: active_idx = i
    dd.set_model(model); dd.set_selected(active_idx); dd.set_hexpand(True)
    window.theme_dropdown = dd
    
    def on_theme_selected(dropdown, _):
        idx = dropdown.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION and idx < len(window.all_themes):
            t = window.all_themes[idx]
            pm.set_active_theme(t["id"], t["is_builtin"])
            _refresh_ui(window, pm)
            if hasattr(window, 'delete_btn'): window.delete_btn.set_sensitive(not t["is_builtin"])
    
    dd.connect("notify::selected", on_theme_selected)
    profile_row.append(dd)
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
    btn_box.add_css_class("linked")
    
    for icon, tip, fn in [
        ("document-new-symbolic", "New Profile", lambda b: show_new_dialog(window, pm, _refresh_dropdown, _refresh_ui)),
        ("document-save-symbolic", "Save As", lambda b: show_save_dialog(window, pm, _refresh_dropdown, _refresh_ui)),
        ("document-open-symbolic", "Import", lambda b: show_import_dialog(window, pm, _refresh_dropdown, _refresh_ui)),
        ("document-send-symbolic", "Export", lambda b: show_export_dialog(window, pm)),
    ]:
        btn = Gtk.Button(); btn.set_icon_name(icon); btn.set_tooltip_text(tip)
        btn.connect("clicked", fn); btn_box.append(btn)
    
    delete_btn = Gtk.Button(); delete_btn.set_icon_name("user-trash-symbolic"); delete_btn.set_tooltip_text("Delete")
    delete_btn.set_sensitive(not themes[active_idx]["is_builtin"] if themes else False)
    delete_btn.connect("clicked", lambda b: show_delete_dialog(window, pm, _refresh_dropdown, _refresh_ui))
    window.delete_btn = delete_btn; btn_box.append(delete_btn)
    
    profile_row.append(btn_box)
    profile_group.append(profile_row)
    main_box.append(profile_group)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CLICKABLE COLOR SWATCHES - v2.1 Feature
    # ═══════════════════════════════════════════════════════════════════════════
    color_group = create_group("THEME COLORS (Click to edit)")
    
    def on_color_change(key, value):
        window.current_theme_colors[key] = value
        if hasattr(window, 'waybar_preview'): window.waybar_preview.update_colors(window.current_theme_colors)
        if hasattr(window, 'rofi_preview'): window.rofi_preview.update_colors(window.current_theme_colors)
        if hasattr(window, 'kitty_preview'): window.kitty_preview.update_colors(window.current_theme_colors)
        # Sync hyprbars colors when theme colors change (v2.3)
        sync_hyprbars_with_theme(window, window.current_theme_colors)
    
    # Backgrounds
    bg_label = Gtk.Label(label="Backgrounds"); bg_label.add_css_class("caption"); bg_label.add_css_class("dim-label")
    bg_label.set_xalign(0); bg_label.set_margin_start(16); bg_label.set_margin_top(8)
    color_group.append(bg_label)
    
    bg_flow = Gtk.FlowBox(); bg_flow.set_selection_mode(Gtk.SelectionMode.NONE)
    bg_flow.set_max_children_per_line(8); bg_flow.set_min_children_per_line(4); bg_flow.set_homogeneous(True)
    bg_flow.set_margin_start(16); bg_flow.set_margin_end(16); bg_flow.set_margin_top(4); bg_flow.set_margin_bottom(8)
    
    for key in ["bg0", "bg1", "bg2", "bg3", "bg4"]:
        swatch = ClickableColorSwatch(key, key, colors.get(key, "#282c34"), on_color_change)
        window.color_swatches[key] = swatch; bg_flow.append(swatch)
    color_group.append(bg_flow)
    
    # Foreground & Greys
    fg_label = Gtk.Label(label="Foreground & Greys"); fg_label.add_css_class("caption"); fg_label.add_css_class("dim-label")
    fg_label.set_xalign(0); fg_label.set_margin_start(16)
    color_group.append(fg_label)
    
    fg_flow = Gtk.FlowBox(); fg_flow.set_selection_mode(Gtk.SelectionMode.NONE)
    fg_flow.set_max_children_per_line(8); fg_flow.set_min_children_per_line(4); fg_flow.set_homogeneous(True)
    fg_flow.set_margin_start(16); fg_flow.set_margin_end(16); fg_flow.set_margin_top(4); fg_flow.set_margin_bottom(8)
    
    for key in ["fg", "grey0", "grey1", "grey2"]:
        swatch = ClickableColorSwatch(key, key, colors.get(key, "#abb2bf"), on_color_change)
        window.color_swatches[key] = swatch; fg_flow.append(swatch)
    color_group.append(fg_flow)
    
    # Accent colors
    accent_label = Gtk.Label(label="Accent Colors"); accent_label.add_css_class("caption"); accent_label.add_css_class("dim-label")
    accent_label.set_xalign(0); accent_label.set_margin_start(16)
    color_group.append(accent_label)
    
    accent_flow = Gtk.FlowBox(); accent_flow.set_selection_mode(Gtk.SelectionMode.NONE)
    accent_flow.set_max_children_per_line(8); accent_flow.set_min_children_per_line(4); accent_flow.set_homogeneous(True)
    accent_flow.set_margin_start(16); accent_flow.set_margin_end(16); accent_flow.set_margin_top(4); accent_flow.set_margin_bottom(12)
    
    for key in ["red", "orange", "yellow", "green", "aqua", "blue", "purple"]:
        swatch = ClickableColorSwatch(key, key, colors.get(key, "#61afef"), on_color_change)
        window.color_swatches[key] = swatch; accent_flow.append(swatch)
    color_group.append(accent_flow)
    main_box.append(color_group)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # EXPANDER SECTIONS
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Waybar Section with Panel Style Presets
    waybar_expander = Gtk.Expander(label="󰀻  Waybar Panel (Style Presets)")
    waybar_expander.add_css_class("card"); waybar_expander.set_margin_bottom(8)
    waybar_content = build_waybar_section(window)
    waybar_expander.set_child(waybar_content)
    main_box.append(waybar_expander)
    
    # Start Menu & Taskbar
    start_expander = Gtk.Expander(label="  Start Menu & Taskbar")
    start_expander.add_css_class("card"); start_expander.set_margin_bottom(8)
    start_content = build_start_menu_taskbar_section(window, colors)
    start_expander.set_child(start_content)
    main_box.append(start_expander)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # HYPRBARS SECTION (v2.3) - Only shows if plugin is active
    # ═══════════════════════════════════════════════════════════════════════════
    if is_hyprbars_active():
        hyprbars_expander = Gtk.Expander(label="  Hyprbars Window Decorations")
        hyprbars_expander.add_css_class("card"); hyprbars_expander.set_margin_bottom(8)
        hyprbars_content = build_hyprbars_section(window, colors)
        hyprbars_expander.set_child(hyprbars_content)
        main_box.append(hyprbars_expander)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # SWAYNC SECTION (v2.4) - Only shows if installed
    # ═══════════════════════════════════════════════════════════════════════════
    if is_swaync_installed():
        swaync_expander = Gtk.Expander(label="󰂚  SwayNC Notifications")
        swaync_expander.add_css_class("card"); swaync_expander.set_margin_bottom(8)
        swaync_content = build_swaync_section(window, colors)
        swaync_expander.set_child(swaync_content)
        main_box.append(swaync_expander)
    
    # Rofi Section
    rofi_expander = Gtk.Expander(label="  Rofi Launcher")
    rofi_expander.add_css_class("card"); rofi_expander.set_margin_bottom(8)
    
    rofi_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    rofi_content.set_margin_start(16); rofi_content.set_margin_end(16)
    rofi_content.set_margin_top(8); rofi_content.set_margin_bottom(16)
    
    rofi_preview = RofiPreviewWidget(colors, rofi)
    window.rofi_preview = rofi_preview
    rofi_frame = Gtk.Frame(); rofi_frame.set_child(rofi_preview)
    rofi_content.append(rofi_frame)
    
    # Rofi Color Editors
    rofi_content.append(create_section_header("ROFI COLORS"))
    
    def on_rofi_color_change(key, value):
        window.current_rofi_config[key] = value
        if hasattr(window, 'rofi_preview'):
            window.rofi_preview.update_rofi(window.current_rofi_config)
    
    rofi_color_rows = [
        ("background", "Background", rofi.get("background", colors.get("bg0", "#282c34"))),
        ("background-alt", "Background Alt", rofi.get("background-alt", colors.get("bg1", "#353b45"))),
        ("foreground", "Foreground", rofi.get("foreground", colors.get("fg", "#abb2bf"))),
        ("selected", "Selected", rofi.get("selected", colors.get("blue", "#61afef"))),
        ("active", "Active", rofi.get("active", colors.get("green", "#98c379"))),
        ("urgent", "Urgent", rofi.get("urgent", colors.get("red", "#e06c75"))),
    ]
    
    for key, label, default in rofi_color_rows:
        row = ColorPickerRow(label, key, default, on_rofi_color_change)
        rofi_content.append(row)
    
    rofi_expander.set_child(rofi_content)
    main_box.append(rofi_expander)
    
    # Kitty Section
    kitty_expander = Gtk.Expander(label="  Kitty Terminal")
    kitty_expander.add_css_class("card"); kitty_expander.set_margin_bottom(8)
    
    kitty_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    kitty_content.set_margin_start(16); kitty_content.set_margin_end(16)
    kitty_content.set_margin_top(8); kitty_content.set_margin_bottom(16)
    
    kitty_preview = KittyPreviewWidget(colors, kitty)
    window.kitty_preview = kitty_preview
    kitty_frame = Gtk.Frame(); kitty_frame.set_child(kitty_preview)
    kitty_content.append(kitty_frame)
    
    # Kitty Color Editors
    kitty_content.append(create_section_header("KITTY COLORS"))
    
    def on_kitty_color_change(key, value):
        window.current_kitty_config[key] = value
        if hasattr(window, 'kitty_preview'):
            window.kitty_preview.update_kitty(window.current_kitty_config)
    
    kitty_color_rows = [
        ("background", "Background", kitty.get("background", colors.get("bg0", "#282c34"))),
        ("foreground", "Foreground", kitty.get("foreground", colors.get("fg", "#abb2bf"))),
        ("cursor", "Cursor", kitty.get("cursor", colors.get("blue", "#61afef"))),
        ("selection_background", "Selection BG", kitty.get("selection_background", colors.get("bg3", "#545862"))),
        ("selection_foreground", "Selection FG", kitty.get("selection_foreground", colors.get("fg", "#abb2bf"))),
    ]
    
    for key, label, default in kitty_color_rows:
        row = ColorPickerRow(label, key, default, on_kitty_color_change)
        kitty_content.append(row)
    
    kitty_expander.set_child(kitty_content)
    main_box.append(kitty_expander)
    
    # Hyprland Section
    hypr_expander = Gtk.Expander(label=" Hyprland")
    hypr_expander.add_css_class("card"); hypr_expander.set_margin_bottom(8)
    
    hypr_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    hypr_content.set_margin_start(16); hypr_content.set_margin_end(16)
    hypr_content.set_margin_top(8); hypr_content.set_margin_bottom(16)
    
    hypr_content.append(create_section_header("WINDOW ROUNDING"))
    rr = create_setting_row("Corner Radius", "0=square, higher=rounder")
    rs = Gtk.SpinButton.new_with_range(0, 30, 1); rs.set_value(12)
    rs.add_css_class("themed-spin")  # v2.4 themed spin
    rs.connect('value-changed', lambda s: apply_hyprland_rounding(int(s.get_value())))
    rr.append(rs); hypr_content.append(rr)
    
    hypr_expander.set_child(hypr_content)
    main_box.append(hypr_expander)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # GLOBAL ACTIONS
    # ═══════════════════════════════════════════════════════════════════════════
    action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    action_box.set_margin_top(24); action_box.set_halign(Gtk.Align.END)
    
    reset_btn = Gtk.Button(label="Reset to Default")
    reset_btn.connect("clicked", lambda b: _reset_theme(window, pm))
    action_box.append(reset_btn)
    
    apply_btn = Gtk.Button(label="󰄬 Apply Theme")
    apply_btn.add_css_class("suggested-action")
    apply_btn.connect("clicked", lambda b: _apply_theme(window, pm))
    action_box.append(apply_btn)
    
    main_box.append(action_box)
    
    return scroll


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

__all__ = [
    'build_theming_page', 'initialize_saved_theme', 'ensure_theme_initialized',
    'ThemeApplier', 'ThemeProfileManager', 'BUILTIN_THEMES', 'PANEL_STYLE_PRESETS',
    'generate_control_center_css', 'generate_start_menu_css', 'generate_panel_widget_css',
    'is_light_theme', 'get_saved_theme_data', 'apply_hyprland_rounding',
    'ClickableColorSwatch', 'ModuleColorRow',
    # Hyprbars exports (v2.3)
    'is_hyprbars_active', 'sync_hyprbars_with_theme', 'sync_hyprbars_with_waybar_font',
    'apply_hyprbars_settings',
    # SwayNC exports (v2.4)
    'is_swaync_installed', 'sync_swaync_with_theme', 'apply_swaync_colorscheme',
]