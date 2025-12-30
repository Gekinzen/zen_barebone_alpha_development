"""
Panel (Waybar) Configuration Page
Main Panel only - Dock (Waybar2) coming soon!
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw
from typing import Callable

from ..widgets import (
    SettingsGroup, IntegerRow, ToggleRow, DropdownRow, FloatRow
)
from ..waybar_manager import WaybarManager
from .panel_helpers import (
    create_module_drop_zone, get_monitor_list, create_size_selector
)


def build_panel_page(window) -> Gtk.ScrolledWindow:
    """Build Panel (Waybar) settings page - Main panel only for now"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Initialize waybar manager
    if not hasattr(window, 'waybar_manager'):
        window.waybar_manager = WaybarManager()
        window.waybar_manager.load_config(is_dock=False)
        # Dock (Waybar2) will be loaded when we implement it
        # window.waybar_manager.load_config(is_dock=True)
    
    # Header
    page_header = window._create_page_header(
        "Panel (Waybar)",
        "Configure your main Waybar panel - modules, position, and appearance"
    )
    content.append(page_header)
    
    # Info banner about Dock
    info_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    info_box.add_css_class('info-banner')
    info_box.set_margin_bottom(16)
    
    info_icon = Gtk.Image.new_from_icon_name('dialog-information-symbolic')
    info_icon.set_pixel_size(16)
    info_box.append(info_icon)
    
    info_label = Gtk.Label(label="📌 Dock (Waybar2) configuration coming soon! Focus on main panel for now.")
    info_label.add_css_class('setting-description')
    info_label.set_halign(Gtk.Align.START)
    info_box.append(info_label)
    
    content.append(info_box)
    
    # Main Panel content
    main_content = _build_main_panel_content(window)
    content.append(main_content)
    
    scrolled.set_child(content)
    return scrolled


def _build_main_panel_content(window) -> Gtk.Box:
    """Build main panel configuration content"""
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    content.set_margin_start(32)
    content.set_margin_end(32)
    content.set_margin_top(16)
    content.set_margin_bottom(16)
    
    wm = window.waybar_manager
    
    # ═══════════════════════════════════════════════════════════════
    # PANEL BEHAVIOR
    # ═══════════════════════════════════════════════════════════════
    
    behavior_group = SettingsGroup("Panel Behavior")
    
    # Position
    position = wm.get_position(is_dock=False)
    w = DropdownRow(
        "Position on Screen",
        ["top", "bottom", "left", "right"],
        position,
        lambda v: wm.set_position(v, is_dock=False),
        "Where the panel appears on screen"
    )
    window.widgets['main_position'] = w
    behavior_group.append(w)
    
    # Show on display
    monitors = get_monitor_list()
    current_output = wm.get_output(is_dock=False)
    if current_output:
        monitor_value = current_output
    else:
        monitor_value = "All Monitors"
    
    w = DropdownRow(
        "Show on Display",
        monitors,
        monitor_value,
        lambda v: _on_monitor_change(window, v, is_dock=False),
        "Which monitor to show the panel on"
    )
    window.widgets['main_monitor'] = w
    behavior_group.append(w)
    
    # Extend to screen edges
    w = ToggleRow(
        "Extend to Screen Edges",
        wm.get_margin('left', is_dock=False) == 0,
        lambda v: _on_extend_toggle(window, v, is_dock=False),
        "Panel spans full width/height of screen"
    )
    window.widgets['main_extend'] = w
    behavior_group.append(w)
    
    content.append(behavior_group)
    
    # ═══════════════════════════════════════════════════════════════
    # PANEL APPEARANCE
    # ═══════════════════════════════════════════════════════════════
    
    appearance_group = SettingsGroup("Panel Appearance")
    
    # Size selector
    size_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    size_box.set_margin_top(8)
    size_box.set_margin_bottom(8)
    
    size_label = Gtk.Label(label="Panel Size")
    size_label.add_css_class('setting-label')
    size_label.set_halign(Gtk.Align.START)
    size_label.set_hexpand(True)
    size_box.append(size_label)
    
    current_height = wm.get_height(is_dock=False)
    size_selector = create_size_selector(
        current_height,
        lambda h: wm.set_height(h, is_dock=False)
    )
    size_box.append(size_selector)
    
    appearance_group.append(size_box)
    
    # Background opacity (placeholder for CSS manipulation)
    w = FloatRow(
        "Background Opacity",
        1.0,
        0.0,
        1.0,
        lambda v: print(f"Opacity: {v}"),
        "Panel background transparency"
    )
    window.widgets['main_opacity'] = w
    appearance_group.append(w)
    
    # Margins
    margin_header = Gtk.Label(label="MARGINS")
    margin_header.add_css_class('section-header')
    margin_header.set_halign(Gtk.Align.START)
    margin_header.set_margin_top(16)
    margin_header.set_margin_bottom(8)
    appearance_group.append(margin_header)
    
    for side in ['top', 'bottom', 'left', 'right']:
        value = wm.get_margin(side, is_dock=False)
        w = IntegerRow(
            f"Margin {side.title()}",
            value,
            0,
            100,
            lambda v, s=side: wm.set_margin(s, v, is_dock=False),
            f"Space from screen {side}"
        )
        window.widgets[f'main_margin_{side}'] = w
        appearance_group.append(w)
    
    content.append(appearance_group)
    
    # ═══════════════════════════════════════════════════════════════
    # MODULE CONFIGURATION
    # ═══════════════════════════════════════════════════════════════
    
    modules_group = SettingsGroup("Module Layout")
    
    info = Gtk.Label(label="Drag and drop modules to rearrange. Click + to add new modules.")
    info.add_css_class('setting-description')
    info.set_wrap(True)
    info.set_halign(Gtk.Align.START)
    info.set_margin_bottom(12)
    modules_group.append(info)
    
    # Module zones
    zones_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    zones_box.set_homogeneous(True)
    
    for pos in ['left', 'center', 'right']:
        modules = wm.get_modules(pos, is_dock=False)
        zone = create_module_drop_zone(
            pos,
            modules,
            lambda p: _on_add_module(window, p, is_dock=False),
            lambda p, m: _on_remove_module(window, p, m, is_dock=False),
            lambda p, data: _on_reorder_modules(window, p, data, is_dock=False)
        )
        zones_box.append(zone)
    
    modules_group.append(zones_box)
    content.append(modules_group)
    
    # Action buttons
    content.append(window._create_action_buttons(
        on_reset=lambda b: _on_panel_reset(window, is_dock=False),
        on_apply=lambda b: _on_panel_apply(window, is_dock=False)
    ))
    
    return content


# ═══════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════

def _on_monitor_change(window, monitor_name: str, is_dock: bool):
    """Handle monitor selection change"""
    if monitor_name in ["All Monitors", "Primary"]:
        window.waybar_manager.set_output(None, is_dock=is_dock)
    else:
        window.waybar_manager.set_output(monitor_name, is_dock=is_dock)


def _on_extend_toggle(window, extend: bool, is_dock: bool):
    """Handle extend to edges toggle"""
    wm = window.waybar_manager
    if extend:
        wm.set_margin('left', 0, is_dock=is_dock)
        wm.set_margin('right', 0, is_dock=is_dock)
    else:
        wm.set_margin('left', 12, is_dock=is_dock)
        wm.set_margin('right', 12, is_dock=is_dock)


def _on_add_module(window, position: str, is_dock: bool):
    """Show dialog to add a module"""
    # TODO: Implement module selection dialog
    window._show_toast(f"Add module to {position} - Coming soon")


def _on_remove_module(window, position: str, module: str, is_dock: bool):
    """Remove a module from position"""
    window.waybar_manager.remove_module(position, module, is_dock=is_dock)
    window._show_toast(f"Removed {module}")
    # Refresh the page
    # TODO: Implement page refresh


def _on_reorder_modules(window, position: str, data: str, is_dock: bool):
    """Handle module reordering via drag and drop"""
    # Parse drag data: "position:module"
    parts = data.split(':')
    if len(parts) == 2:
        from_pos, module = parts
        if from_pos != position:
            window.waybar_manager.move_module(from_pos, position, module, is_dock=is_dock)
        # TODO: Implement reordering within same position


def _on_panel_reset(window, is_dock: bool):
    """Reset panel to default configuration"""
    panel_type = "Dock" if is_dock else "Main Panel"
    
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading=f"Reset {panel_type}?",
        body=f"This will restore the {panel_type.lower()} to default configuration."
    )
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("reset", "Reset")
    dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE)
    dialog.connect('response', lambda d, r: _on_panel_reset_response(window, d, r, is_dock))
    dialog.present()


def _on_panel_reset_response(window, dialog, response, is_dock: bool):
    """Handle reset confirmation"""
    if response == "reset":
        default_config = window.waybar_manager.create_default_config(is_dock=is_dock)
        if is_dock:
            window.waybar_manager.dock_config = default_config
        else:
            window.waybar_manager.main_config = default_config
        window._show_toast("Panel reset to default")
        # TODO: Refresh page


def _on_panel_apply(window, is_dock: bool):
    """Apply panel changes"""
    wm = window.waybar_manager
    if is_dock:
        wm.save_config(wm.dock_config, is_dock=True)
        window._show_toast("Dock configuration saved")
    else:
        wm.save_config(wm.main_config, is_dock=False)
        window._show_toast("Panel configuration saved")


# ═══════════════════════════════════════════════════════════════════
# FUTURE: DOCK (WAYBAR2) IMPLEMENTATION
# ═══════════════════════════════════════════════════════════════════
# 
# When ready to implement Dock:
# 1. Uncomment _build_dock_panel_content() below
# 2. In build_panel_page(), replace single content with TabView
# 3. Add tab for Main Panel and Dock
# 4. Enable: window.waybar_manager.load_config(is_dock=True)
#
# The structure is ready - just needs to be activated!
# ═══════════════════════════════════════════════════════════════════

"""
def _build_dock_panel_content(window) -> Gtk.Box:
    # Build dock panel configuration content
    # Same structure as main panel but with is_dock=True
    # Size presets: 48, 60, 72, 84
    # Default modules: workspaces + tray
    # Position: bottom
    # All same features as main panel
    pass
"""