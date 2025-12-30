"""
Panel helper functions for waybar configuration
Includes working drag-and-drop between LEFT/CENTER/RIGHT zones
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib
from typing import Callable, List

# Module icons mapping
MODULE_ICONS = {
    'clock': '󰥔',
    'battery': '󰁹',
    'network': '󰖩',
    'pulseaudio': '󰕾',
    'cpu': '󰻠',
    'memory': '󰍛',
    'disk': '󰋊',
    'temperature': '󰔏',
    'backlight': '󰃟',
    'bluetooth': '󰂯',
    'tray': '󰍉',
    'idle_inhibitor': '󰒳',
    'mpris': '󰝚',
    'custom/launcher': '󰀻',
    'hyprland/workspaces': '󰕰',
    'hyprland/window': '󰖯',
}

def get_module_icon(module: str) -> str:
    """Get icon for module"""
    return MODULE_ICONS.get(module, '󰘳')


def create_module_chip(module: str, on_remove: Callable, position: str) -> Gtk.Box:
    """Create draggable module chip"""
    chip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    chip.add_css_class('module-chip')
    chip.set_margin_top(2)
    chip.set_margin_bottom(2)
    
    # Store module info
    chip.module_name = module
    chip.source_position = position
    
    # Icon
    icon_label = Gtk.Label(label=get_module_icon(module))
    icon_label.add_css_class('module-icon')
    chip.append(icon_label)
    
    # Name
    name_label = Gtk.Label(label=module)
    name_label.add_css_class('module-name')
    name_label.set_hexpand(True)
    name_label.set_halign(Gtk.Align.START)
    chip.append(name_label)
    
    # Remove button
    remove_btn = Gtk.Button()
    remove_btn.set_icon_name('window-close-symbolic')
    remove_btn.add_css_class('remove-module-btn')
    remove_btn.connect('clicked', lambda b: on_remove(module))
    chip.append(remove_btn)
    
    # Make draggable
    drag_source = Gtk.DragSource()
    drag_source.set_actions(Gdk.DragAction.MOVE)
    
    # Prepare drag data
    drag_source.connect('prepare', lambda s, x, y: _on_drag_prepare(chip))
    drag_source.connect('drag-begin', lambda s, d: _on_drag_begin(d, chip))
    
    chip.add_controller(drag_source)
    
    return chip


def _on_drag_prepare(chip: Gtk.Box):
    """Prepare drag data"""
    data = f"{chip.source_position}:{chip.module_name}"
    value = GLib.Value(GLib.TYPE_STRING, data)
    return Gdk.ContentProvider.new_for_value(value)


def _on_drag_begin(drag, chip: Gtk.Box):
    """Set drag icon"""
    paintable = Gtk.WidgetPaintable.new(chip)
    drag.set_icon(paintable, 0, 0)
    chip.add_css_class('dragging')


def create_module_drop_zone(position: str, modules: List[str], 
                            on_add: Callable, on_remove: Callable,
                            on_reorder: Callable) -> Gtk.Box:
    """Create a drop zone for modules with drag-and-drop support"""
    zone = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    zone.add_css_class('module-drop-zone')
    zone.position = position
    
    # Header
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
    modules_box.set_size_request(-1, 150)  # Min height for drop zone
    
    # Add modules
    for module in modules:
        chip = create_module_chip(module, lambda m: on_remove(position, m), position)
        modules_box.append(chip)
    
    # Drop target
    drop_target = Gtk.DropTarget.new(GLib.TYPE_STRING, Gdk.DragAction.MOVE)
    drop_target.connect('drop', lambda t, v, x, y: _on_drop(position, v, on_reorder, modules_box))
    drop_target.connect('enter', lambda t, x, y: _on_drag_enter(modules_box))
    drop_target.connect('leave', lambda t: _on_drag_leave(modules_box))
    modules_box.add_controller(drop_target)
    
    zone.append(modules_box)
    
    return zone


def _on_drag_enter(box: Gtk.Box) -> Gdk.DragAction:
    """Handle drag enter"""
    box.add_css_class('drop-target-hover')
    return Gdk.DragAction.MOVE


def _on_drag_leave(box: Gtk.Box):
    """Handle drag leave"""
    box.remove_css_class('drop-target-hover')


def _on_drop(target_position: str, drag_data: str, on_reorder: Callable, modules_box: Gtk.Box) -> bool:
    """Handle drop"""
    modules_box.remove_css_class('drop-target-hover')
    
    try:
        # Parse drag data: "source_position:module_name"
        source_position, module_name = drag_data.split(':', 1)
        
        # Get current modules in target zone
        current_modules = []
        child = modules_box.get_first_child()
        while child:
            if hasattr(child, 'module_name'):
                current_modules.append(child.module_name)
            child = child.get_next_sibling()
        
        # Build new order
        if source_position == target_position:
            # Same zone - reorder (not implemented yet, just keep order)
            on_reorder(target_position, {'from': source_position, 'module': module_name})
        else:
            # Different zone - move module
            on_reorder(target_position, {'from': source_position, 'module': module_name, 'to': target_position})
        
        return True
    except:
        return False


def create_size_selector(current_size: str, on_change: Callable) -> Gtk.Box:
    """Create panel size selector"""
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    box.add_css_class('size-selector')
    
    sizes = [
        ('Small', 28),
        ('Medium', 34),
        ('Large', 42),
        ('X-Large', 48),
    ]
    
    for label, value in sizes:
        btn = Gtk.Button(label=label)
        btn.add_css_class('size-btn')
        
        if current_size == label.lower():
            btn.add_css_class('active')
        
        btn.connect('clicked', lambda b, v=value, l=label: on_change(l.lower(), v))
        box.append(btn)
    
    return box