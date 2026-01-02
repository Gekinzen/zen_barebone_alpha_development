"""
Panel (Waybar) Configuration Page - Helper Functions
COMPLETE VERSION with Nerd Fonts + Drag & Drop
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, GLib, Gdk, GObject
from typing import List, Callable

def create_module_chip(module_name: str, position: str, on_remove: Callable = None) -> Gtk.Box:
    """Create a draggable module chip with Nerd Font icons"""
    chip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    chip.add_css_class('module-chip')
    # Store as custom attribute (GTK4 compatible)
    chip.module_name = module_name
    chip.position = position  # Store position for drag data
    
    # Icon based on module type - NERD FONT ICONS!
    icon_map = {
        # Core
        'clock': '󰥔',                     # nf-md-clock
        'hyprland/workspaces': '󰕰',      # nf-md-view_grid
        'hyprland/window': '󰖯',          # nf-md-window

        # Panels / Bars
        'tray': '󰍉',                      # nf-md-apps

        # System
        'pulseaudio': '󰕾',               # nf-md-volume_high
        'network': '󰖩',                   # nf-md-wifi
        'battery': '󰁹',                   # nf-md-battery
        'bluetooth': '󰂯',                # nf-md-bluetooth
        'backlight': '󰃟',                # nf-md-brightness

        # Performance
        'cpu': '󰻠',                       # nf-md-cpu
        'memory': '󰍛',                    # nf-md-memory
        'disk': '󰋊',                      # nf-md-harddisk
        'temperature': '󰔏',              # nf-md-thermometer

        # Media / UX
        'mpris': '󰝚',                     # nf-md-music
        'idle_inhibitor': '󰒳',           # nf-md-coffee
        'custom/notification': '󰂚',     # nf-md-bell
        'custom/launcher': '󰀻',          # nf-md-apps

        # Future / Dock-ready
        'custom/taskbar': '󰏔',           # alias for taskbar
        'custom/pinned': '󰐃',            # nf-md-pin (pinned apps)
    }

    
    # Use label instead of image for Nerd Font icons
    icon_text = icon_map.get(module_name, '󰘳')  # Default: nf-md-application
    icon_label = Gtk.Label(label=icon_text)
    icon_label.add_css_class('module-chip-icon')
    chip.append(icon_label)
    
    # Display name
    display_name = module_name.replace('/', ' - ').replace('_', ' ').title()
    label = Gtk.Label(label=display_name)
    label.add_css_class('module-chip-label')
    chip.append(label)
    
    # Remove button
    if on_remove:
        remove_btn = Gtk.Button()
        remove_btn.set_icon_name('window-close-symbolic')
        remove_btn.add_css_class('module-chip-remove')
        remove_btn.connect('clicked', lambda b: on_remove(module_name))
        chip.append(remove_btn)
    
    # ENABLE DRAG SOURCE - WORKING!
    drag_source = Gtk.DragSource()
    drag_source.set_actions(Gdk.DragAction.MOVE)
    
    def prepare_drag(source, x, y):
        # Send format: "position:module"
        drag_data = f"{position}:{module_name}"
        value = GObject.Value(GObject.TYPE_STRING, drag_data)
        return Gdk.ContentProvider.new_for_value(value)
    
    def drag_begin(source, drag):
        # Create paintable for drag icon
        paintable = Gtk.WidgetPaintable.new(chip)
        
        # Wayland compatible - skip icon if not supported
        try:
            drag.set_icon(paintable, 0, 0)
        except AttributeError:
            pass
        
        chip.add_css_class('dragging')
        
        # PREVENT SCROLL DURING DRAG
        widget = chip
        while widget:
            widget = widget.get_parent()
            if isinstance(widget, Gtk.ScrolledWindow):
                widget.set_kinetic_scrolling(False)
                break
    
    def drag_end(source, drag, delete_data):
        chip.remove_css_class('dragging')
        
        # RE-ENABLE SCROLL AFTER DRAG
        widget = chip
        while widget:
            widget = widget.get_parent()
            if isinstance(widget, Gtk.ScrolledWindow):
                widget.set_kinetic_scrolling(True)
                break
    
    drag_source.connect('prepare', prepare_drag)
    drag_source.connect('drag-begin', drag_begin)
    drag_source.connect('drag-end', drag_end)
    chip.add_controller(drag_source)
    
    return chip


def create_module_drop_zone(position: str, modules: List[str], 
                            on_add: Callable, on_remove: Callable,
                            on_reorder: Callable) -> Gtk.Box:
    """Create a drop zone for modules with drag & drop support"""
    zone = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    zone.add_css_class('module-drop-zone')
    zone.position = position
    
    # Header with title and add button
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    header.set_margin_bottom(8)
    
    title = Gtk.Label(label=position.upper())
    title.add_css_class('drop-zone-title')
    title.set_halign(Gtk.Align.START)
    title.set_hexpand(True)
    header.append(title)
    
    # Add button
    add_btn = Gtk.Button()
    add_btn.set_icon_name('list-add-symbolic')
    add_btn.add_css_class('add-module-btn')
    add_btn.connect('clicked', lambda b: on_add(position))
    header.append(add_btn)
    
    zone.append(header)
    
    # Modules container
    modules_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    modules_box.add_css_class('modules-container')
    modules_box.position = position
    
    # Add module chips
    for module in modules:
        chip = create_module_chip(module, position, lambda m: on_remove(position, m))
        modules_box.append(chip)
    
    # ENABLE DROP TARGET - WORKING!
    drop_target = Gtk.DropTarget.new(GObject.TYPE_STRING, Gdk.DragAction.MOVE)
    
    def on_drop_handler(target, value, x, y):
        # Value format: "from_position:module_name"
        on_reorder(position, value)
        return True
    
    def on_enter(target, x, y):
        modules_box.add_css_class('drop-target-hover')
        return Gdk.DragAction.MOVE
    
    def on_leave(target):
        modules_box.remove_css_class('drop-target-hover')
    
    drop_target.connect('drop', on_drop_handler)
    drop_target.connect('enter', on_enter)
    drop_target.connect('leave', on_leave)
    modules_box.add_controller(drop_target)
    
    zone.append(modules_box)
    
    return zone


def create_size_selector(current_size: str, on_change: Callable) -> Gtk.Box:
    """Create panel size selector (Small, Medium, Large, X-Large)"""
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    box.add_css_class('size-selector')
    box.set_homogeneous(True)
    
    sizes = [
        ('Small', 28),
        ('Medium', 34),
        ('Large', 42),
        ('X-Large', 52)
    ]
    
    size_map = {h: name for name, h in sizes}
    current_name = size_map.get(current_size, 'Medium')
    
    for name, height in sizes:
        btn = Gtk.ToggleButton(label=name)
        btn.add_css_class('size-btn')
        if name == current_name:
            btn.set_active(True)
        btn.connect('toggled', lambda b, h=height, n=name: on_size_changed(b, h, n, on_change))
        box.append(btn)
    
    return box


def on_size_changed(button, height, name, callback):
    """Handle size button toggle"""
    if button.get_active():
        # Deactivate other buttons
        parent = button.get_parent()
        for child in parent:
            if isinstance(child, Gtk.ToggleButton) and child != button:
                child.set_active(False)
        callback(height)


def _get_available_profiles(self) -> list:
    """Get list of available power profiles"""
    try:
        result = subprocess.run(
            ['powerprofilesctl', 'list'],
            capture_output=True,
            text=True,
            timeout=2
        )
        
        # Parse output for available profiles
        profiles = []
        for line in result.stdout.split('\n'):
            line = line.strip()
            if line.startswith('* ') or line.startswith('  '):
                # Extract profile name (e.g., "* power-saver:" -> "power-saver")
                profile_name = line.lstrip('* ').split(':')[0].strip()
                if profile_name:
                    profiles.append(profile_name)
        
        return profiles if profiles else ['power-saver', 'balanced']
        
    except:
        # Default fallback
        return ['power-saver', 'balanced']




def get_monitor_list() -> List[str]:
    """Get list of monitors from hyprctl"""
    import subprocess
    import json
    
    try:
        result = subprocess.run(
            ['hyprctl', 'monitors', '-j'],
            capture_output=True,
            text=True,
            check=True,
            timeout=2
        )
        monitors = json.loads(result.stdout)
        monitor_names = [m.get('name', 'Unknown') for m in monitors]
        
        # Add special options
        return ['All Monitors', 'Primary'] + monitor_names
    except Exception as e:
        print(f"Error getting monitors: {e}")
        return ['All Monitors', 'Primary']