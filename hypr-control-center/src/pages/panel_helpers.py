"""
Panel (Waybar) Configuration Page - Helper Functions
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, GLib, Gdk
from typing import List, Callable

def create_module_chip(module_name: str, position: str, on_remove: Callable = None) -> Gtk.Box:
    """Create a draggable module chip"""
    chip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    chip.add_css_class('module-chip')
    # Store as custom attribute (GTK4 compatible)
    chip.module_name = module_name
    chip.position = position  # Store position for drag data
    
    # Icon based on module type - NERD FONT ICONS!
    icon_map = {
        'clock': '󰥔',                    # nf-md-clock
        'hyprland/workspaces': '󰕰',    # nf-md-view_grid
        'tray': '󰍉',                     # nf-md-apps
        'pulseaudio': '󰕾',              # nf-md-volume_high
        'network': '󰖩',                  # nf-md-wifi
        'battery': '󰁹',                  # nf-md-battery
        'cpu': '󰻠',                      # nf-md-cpu
        'memory': '󰍛',                   # nf-md-memory
        'disk': '󰋊',                     # nf-md-harddisk
        'temperature': '󰔏',             # nf-md-thermometer
        'backlight': '󰃟',               # nf-md-brightness
        'bluetooth': '󰂯',               # nf-md-bluetooth
        'idle_inhibitor': '󰒳',         # nf-md-coffee
        'mpris': '󰝚',                    # nf-md-music
        'custom/launcher': '󰀻',        # nf-md-apps
        'hyprland/window': '󰖯',        # nf-md-window
        'custom/notification': '󰂚',   # nf-md-bell
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
    
    # ENABLE DRAG SOURCE!
    drag_source = Gtk.DragSource()
    drag_source.set_actions(Gdk.DragAction.MOVE)
    
    def prepare_drag(source, x, y):
        from gi.repository import GObject
        # Send format: "position:module"
        drag_data = f"{position}:{module_name}"
        value = GObject.Value(GObject.TYPE_STRING, drag_data)
        return Gdk.ContentProvider.new_for_value(value)
    
    def drag_begin(source, drag):
        # Create paintable for drag icon
        paintable = Gtk.WidgetPaintable.new(chip)
        
        # Use set_hotspot for Wayland compatibility (not set_icon)
        try:
            drag.set_icon(paintable, 0, 0)
        except AttributeError:
            # Wayland fallback - just skip icon
            pass
        
        chip.add_css_class('dragging')
    
    drag_source.connect('prepare', prepare_drag)
    drag_source.connect('drag-begin', drag_begin)
    chip.add_controller(drag_source)
    
    return chip


def create_module_drop_zone(position: str, modules: List[str], 
                            on_add: Callable, on_remove: Callable,
                            on_reorder: Callable) -> Gtk.Box:
    """Create a drop zone for modules"""
    zone = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    zone.add_css_class('module-drop-zone')
    # Store as custom attribute (GTK4 compatible)
    zone.position = position
    
    # Header
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    header.set_margin_bottom(8)
    
    title = Gtk.Label(label=position.upper())
    title.add_css_class('drop-zone-title')
    title.set_halign(Gtk.Align.START)
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
    # Store as custom attribute (GTK4 compatible)
    modules_box.position = position
    
    for module in modules:
        chip = create_module_chip(module, position, lambda m: on_remove(position, m))
        modules_box.append(chip)
    
    # ENABLE DROP TARGET!
    from gi.repository import GLib, GObject
    drop_target = Gtk.DropTarget.new(GObject.TYPE_STRING, Gdk.DragAction.MOVE)
    
    def on_drop_handler(target, value, x, y):
        # Value format: "from_position:module_name"
        on_reorder(position, value)  # Pass to parent handler
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


def on_drag_prepare(module: str, position: str):
    """Prepare drag data"""
    from gi.repository import Gdk
    data = f"{position}:{module}"
    return Gdk.ContentProvider.new_for_value(data)


def on_drag_begin(drag, widget):
    """Set drag icon"""
    from gi.repository import Gtk, Gdk
    icon = Gtk.WidgetPaintable.new(widget)
    drag.set_icon(icon, 0, 0)


def create_size_selector(current_size: str, on_change: Callable) -> Gtk.Box:
    """Create panel size selector (Small, Medium, Large, X-Large)"""
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    box.add_css_class('size-selector')
    
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


def get_monitor_list() -> List[str]:
    """Get list of monitors from hyprctl"""
    import subprocess
    import json
    
    try:
        result = subprocess.run(
            ['hyprctl', 'monitors', '-j'],
            capture_output=True,
            text=True,
            check=True
        )
        monitors = json.loads(result.stdout)
        monitor_names = [m.get('name', 'Unknown') for m in monitors]
        
        # Add special options
        return ['All Monitors', 'Primary'] + monitor_names
    except Exception as e:
        print(f"Error getting monitors: {e}")
        return ['All Monitors', 'Primary']