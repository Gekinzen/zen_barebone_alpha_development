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
from ..waybar_style_manager import WaybarStyleManager
from .panel_helpers import (
    create_module_drop_zone, get_monitor_list, create_size_selector
)


def build_panel_page(window) -> Gtk.ScrolledWindow:
    """Build Panel (Waybar) settings page - Main panel only for now"""
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    
    # PREVENT AUTO-SCROLL DURING DRAG
    scrolled.set_kinetic_scrolling(False)
    scrolled.set_propagate_natural_height(True)
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    content.add_css_class('content-area')
    
    # Initialize waybar manager
    if not hasattr(window, 'waybar_manager'):
        window.waybar_manager = WaybarManager()
        window.waybar_manager.load_config(is_dock=False)
        # Dock (Waybar2) will be loaded when we implement it
        # window.waybar_manager.load_config(is_dock=True)
    
    # Initialize style manager
    if not hasattr(window, 'waybar_style_manager'):
        from ..constants import WAYBAR_DIR
        window.waybar_style_manager = WaybarStyleManager(WAYBAR_DIR)
        window.waybar_style_manager.load_style()
    
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
        ["top", "bottom"],  # TODO: left/right needs CSS fixes
        position if position in ["top", "bottom"] else "top",
        lambda v: _on_position_change(window, v, is_dock=False),
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
    
    # Get current font size from CSS
    sm = window.waybar_style_manager
    current_font_size = sm.get_current_font_size() or 16
    
    # Size presets: font-size in px
    sizes = [
        ('Small', 10),
        ('Medium', 16),
        ('Large', 20),
        ('X-Large', 26)
    ]
    
    # Create size buttons
    size_buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    size_buttons.add_css_class('size-selector')
    
    for name, font_size in sizes:
        btn = Gtk.ToggleButton(label=name)
        btn.add_css_class('size-btn')
        if font_size == current_font_size:
            btn.set_active(True)
        btn.connect('toggled', lambda b, fs=font_size: _on_size_changed(window, b, fs))
        size_buttons.append(btn)
    
    size_box.append(size_buttons)
    appearance_group.append(size_box)
    
    # Transparent background toggle
    sm = window.waybar_style_manager
    is_transparent = sm.is_transparent()
    
    w = ToggleRow(
        "Transparent Background",
        is_transparent,
        lambda v: _on_transparent_toggle(window, v, is_dock=False),
        "Use fully transparent background"
    )
    window.widgets['main_transparent'] = w
    appearance_group.append(w)
    
    # Background opacity (only when not transparent)
    current_opacity = sm.get_current_opacity() or 0.6
    w = FloatRow(
        "Background Opacity",
        current_opacity if not is_transparent else 0.6,
        0.0,
        1.0,
        lambda v: _on_opacity_change(window, v, is_dock=False),
        "Panel background transparency (0=clear, 1=opaque)"
    )
    w.set_sensitive(not is_transparent)  # Disable if transparent
    window.widgets['main_opacity'] = w
    appearance_group.append(w)
    
    # Border radius (only when not extended)
    extend_to_edges = wm.get_margin('left', is_dock=False) == 0
    current_radius = sm.get_border_radius() or 46
    w = IntegerRow(
        "Border Radius",
        current_radius,
        0,
        50,
        lambda v: _on_border_radius_change(window, v, is_dock=False),
        "Corner roundness in pixels"
    )
    w.set_sensitive(not extend_to_edges)  # Disable if extended
    window.widgets['main_border_radius'] = w
    appearance_group.append(w)
    
    # Note: User's default style uses background:transparent
    # Opacity controls removed - edit style.css manually if needed
    
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


def _on_position_change(window, position: str, is_dock: bool):
    """Handle position change - updates config and CSS for vertical bars"""
    wm = window.waybar_manager
    sm = window.waybar_style_manager
    
    # Set position in config
    wm.set_position(position, is_dock=is_dock)
    
    # If vertical bar (left/right), add module zone styling
    if position in ['left', 'right']:
        sm.add_vertical_bar_css()
    else:
        sm.remove_vertical_bar_css()


def _on_size_changed(window, button, font_size: int):
    """Handle size button toggle - changes font-size in CSS"""
    if button.get_active():
        # Deactivate other buttons
        parent = button.get_parent()
        for child in parent:
            if isinstance(child, Gtk.ToggleButton) and child != button:
                child.set_active(False)
        
        # Update CSS font-size
        sm = window.waybar_style_manager
        sm.set_font_size(font_size)
        sm.save_style()  # Save immediately
        
        # Reload waybar to apply
        window.waybar_manager.reload_waybar()
        window._show_toast(f"Font size changed to {font_size}px")


def _on_transparent_toggle(window, transparent: bool, is_dock: bool):
    """Handle transparent background toggle"""
    sm = window.waybar_style_manager
    
    if transparent:
        # Set to transparent
        sm.set_opacity(1.0, transparent=True)
        # Disable opacity slider
        if 'main_opacity' in window.widgets:
            window.widgets['main_opacity'].set_sensitive(False)
    else:
        # Set to current opacity value
        current_opacity = 0.6  # Default
        if 'main_opacity' in window.widgets:
            # Get value from slider if exists
            window.widgets['main_opacity'].set_sensitive(True)
        sm.set_opacity(current_opacity, transparent=False)


def _on_opacity_change(window, opacity: float, is_dock: bool):
    """Handle opacity slider change"""
    sm = window.waybar_style_manager
    # Only apply if not in transparent mode
    if not sm.is_transparent():
        sm.set_opacity(opacity, transparent=False)


def _on_transparent_toggle(window, transparent: bool, is_dock: bool):
    """Handle transparent background toggle"""
    sm = window.waybar_style_manager
    
    if transparent:
        # Set to transparent
        sm.set_opacity(1.0, transparent=True)
        # Disable opacity slider
        if 'main_opacity' in window.widgets:
            window.widgets['main_opacity'].set_sensitive(False)
    else:
        # Set to current opacity value
        current_opacity = 0.6  # Default
        if 'main_opacity' in window.widgets:
            window.widgets['main_opacity'].set_sensitive(True)
        sm.set_opacity(current_opacity, transparent=False)
    
    # Save CSS immediately
    sm.save_style()
    window.waybar_manager.reload_waybar()


def _on_opacity_change(window, opacity: float, is_dock: bool):
    """Handle opacity slider change"""
    sm = window.waybar_style_manager
    # Only apply if not in transparent mode
    if not sm.is_transparent():
        sm.set_opacity(opacity, transparent=False)
        # Save CSS immediately
        sm.save_style()
        window.waybar_manager.reload_waybar()


def _on_border_radius_change(window, radius: int, is_dock: bool):
    """Handle border radius change"""
    sm = window.waybar_style_manager
    sm.set_border_radius(radius, enabled=True)
    # Save CSS immediately
    sm.save_style()
    window.waybar_manager.reload_waybar()


def _on_extend_toggle(window, extend: bool, is_dock: bool):
    """Handle extend to edges toggle - sets all margins and disables border-radius"""
    wm = window.waybar_manager
    sm = window.waybar_style_manager
    
    if extend:
        # Extend to edges: all margins to 0, border-radius to 0
        wm.set_margin('left', 0, is_dock=is_dock)
        wm.set_margin('right', 0, is_dock=is_dock)
        wm.set_margin('top', 0, is_dock=is_dock)
        wm.set_margin('bottom', 0, is_dock=is_dock)
        sm.set_border_radius(0, enabled=False)
        sm.set_box_shadow(enabled=False)
        
        # Disable border-radius control
        if 'main_border_radius' in window.widgets:
            window.widgets['main_border_radius'].set_sensitive(False)
    else:
        # Floating panel: restore margins, enable border-radius
        wm.set_margin('left', 0, is_dock=is_dock)
        wm.set_margin('right', 0, is_dock=is_dock)
        
        # Restore border-radius to slider value
        if 'main_border_radius' in window.widgets:
            window.widgets['main_border_radius'].set_sensitive(True)
            # Get current value from widget
            # Will be set by user or default 46
        
        sm.set_border_radius(46, enabled=True)
        sm.set_box_shadow(enabled=True)
    
    # Save changes
    sm.save_style()
    wm.reload_waybar()


def _on_add_module(window, position: str, is_dock: bool):
    """Show dialog to add a module"""
    wm = window.waybar_manager
    
    # Get all modules defined in config
    all_modules = list(wm.get_available_modules())
    
    # Get currently used modules (in all zones)
    used_modules = []
    for pos in ['left', 'center', 'right']:
        used_modules.extend(wm.get_modules(pos, is_dock=is_dock))
    
    # Get available modules (not yet used)
    available_modules = [m for m in all_modules if m not in used_modules]
    
    if not available_modules:
        window._show_toast("All modules are already in use!")
        return
    
    # Create selection dialog
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading=f"Add Module to {position.upper()}",
        body="Select a module to add:"
    )
    
    # Create list box with available modules
    from gi.repository import Gtk
    list_box = Gtk.ListBox()
    list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
    list_box.add_css_class('boxed-list')
    
    for module in sorted(available_modules):
        row = Gtk.ListBoxRow()
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        
        # Icon
        icon_name = _get_module_icon(module)
        icon = Gtk.Image.new_from_icon_name(icon_name)
        icon.set_pixel_size(24)
        box.append(icon)
        
        # Label
        label = Gtk.Label(label=_get_module_display_name(module))
        label.set_halign(Gtk.Align.START)
        label.set_hexpand(True)
        box.append(label)
        
        row.set_child(box)
        row.module_name = module  # Store module name
        list_box.append(row)
    
    # Scrolled window for list
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scrolled.set_min_content_height(200)
    scrolled.set_max_content_height(400)
    scrolled.set_child(list_box)
    
    dialog.set_extra_child(scrolled)
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("add", "Add")
    dialog.set_response_appearance("add", Adw.ResponseAppearance.SUGGESTED)
    dialog.set_default_response("add")
    
    def on_response(dialog, response):
        if response == "add":
            selected_row = list_box.get_selected_row()
            if selected_row:
                module = selected_row.module_name
                # Add module
                wm.add_module(position, module, is_dock=is_dock)
                # Auto-save and reload
                _on_panel_apply(window, is_dock=is_dock)
                window._show_toast(f"Added {module} to {position}")
                # Refresh page
                _refresh_panel_page(window)
    
    dialog.connect('response', on_response)
    dialog.present()


def _refresh_panel_page(window):
    """Refresh the panel page to show updated modules"""
    # Rebuild the panel page
    from . import panel
    new_page = panel.build_panel_page(window)
    
    # Replace in stack
    window.stack.remove(window.stack.get_child_by_name("panel"))
    window.stack.add_named(new_page, "panel")
    window.stack.set_visible_child_name("panel")


def _get_module_icon(module: str) -> str:
    """Get icon name for module"""
    icons = {
        'clock': 'preferences-system-time-symbolic',
        'hyprland/workspaces': 'view-grid-symbolic',
        'hyprland/window': 'window-symbolic',

        'wlr/taskbar': 'view-list-symbolic',

        'tray': 'system-tray-symbolic',
        'pulseaudio': 'audio-volume-high-symbolic',
        'network': 'network-wireless-symbolic',
        'battery': 'battery-symbolic',

        'custom/notification': 'notification-symbolic',

        'cpu': 'utilities-system-monitor-symbolic',
        'memory': 'drive-harddisk-symbolic',
        'disk': 'drive-harddisk-symbolic',
        'temperature': 'temperature-symbolic',
        'backlight': 'display-brightness-symbolic',
    }

    return icons.get(module, 'application-x-executable-symbolic')


def _get_module_display_name(module: str) -> str:
    """Get display name for module"""
    names = {
        'clock': 'Clock',
        'hyprland/workspaces': 'Workspaces',
        'hyprland/window': 'Active Window Title',

        'wlr/taskbar': 'Taskbar (Running Apps)',

        'tray': 'System Tray',
        'pulseaudio': 'Audio',
        'network': 'Network',
        'battery': 'Battery',
        'custom/notification': 'Notifications',

        'cpu': 'CPU Usage',
        'memory': 'Memory Usage',
        'disk': 'Disk Usage',
        'temperature': 'Temperature',
        'backlight': 'Brightness',
    }

    return names.get(module, module.replace('/', ' ').title())


def _on_remove_module(window, position: str, module: str, is_dock: bool):
    """Remove a module from position - auto-saves and refreshes"""
    window.waybar_manager.remove_module(position, module, is_dock=is_dock)
    # Auto-save changes
    _on_panel_apply(window, is_dock=is_dock)
    window._show_toast(f"Removed {module} from {position}")
    # Refresh page to update UI
    _refresh_panel_page(window)


def _on_reorder_modules(window, position: str, data: str, is_dock: bool):
    """Handle module reordering via drag and drop"""
    # Parse drag data: "from_position:module"
    parts = data.split(':')
    if len(parts) == 2:
        from_pos, module = parts
        if from_pos != position:
            # Move module from one zone to another
            window.waybar_manager.move_module(from_pos, position, module, is_dock=is_dock)
            
            # Rebuild panel page to show changes
            window._show_toast(f"Moved {module} from {from_pos} to {position}")
            
            # AUTO-APPLY! Save changes immediately
            _on_panel_apply(window, is_dock)
            
            # Refresh the panel page
            _refresh_panel_page(window, is_dock)


def _refresh_panel_page(window, is_dock: bool):
    """Refresh panel page to show updated module layout"""
    # Get current page
    if is_dock:
        content = _build_dock_content(window)
    else:
        content = _build_main_panel_content(window)
    
    # Replace stack page
    page_name = "panel" if not is_dock else "dock"
    
    # Create new scrolled window
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scrolled.set_child(content)
    
    # Remove old page and add new one
    old_page = window.stack.get_child_by_name(page_name)
    if old_page:
        window.stack.remove(old_page)
    
    window.stack.add_named(scrolled, page_name)
    window.stack.set_visible_child_name(page_name)


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
    """Apply panel changes - saves config.jsonc only"""
    wm = window.waybar_manager
    
    # Save config.jsonc (layout)
    if is_dock:
        wm.save_config(wm.dock_config, is_dock=True)
    else:
        wm.save_config(wm.main_config, is_dock=False)
    
    # Note: style.css changes are saved separately by size selector
    # Reload waybar to apply changes
    wm.reload_waybar()
    
    window._show_toast("Panel configuration applied!")


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