"""
Notifications Page - SwayNC position and display configuration
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw
import json
import subprocess
from pathlib import Path
from typing import Dict

from ..preferences import NotificationPreferences

class NotificationsPage:
    """Notifications page for SwayNC configuration"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = NotificationPreferences()
        self.swaync_config_path = Path.home() / ".config/swaync/config.json"
        
    def build(self) -> Gtk.Box:
        """Build notifications page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.set_margin_top(24)
        page.set_margin_bottom(24)
        page.set_margin_start(32)
        page.set_margin_end(32)
        
        # Header
        header = self._build_header()
        page.append(header)
        
        # Position group
        position_group = self._build_position_group()
        page.append(position_group)
        
        # Display group
        display_group = self._build_display_group()
        page.append(display_group)
        
        # Actions
        actions_group = self._build_actions_group()
        page.append(actions_group)
        
        return page
    
    def _build_header(self) -> Gtk.Box:
        """Build page header"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        header.set_margin_bottom(24)
        
        title = Gtk.Label(label="Notifications")
        title.add_css_class('page-title')
        title.set_xalign(0)
        header.append(title)
        
        subtitle = Gtk.Label(
            label="Configure notification position and behavior"
        )
        subtitle.add_css_class('page-subtitle')
        subtitle.set_xalign(0)
        header.append(subtitle)
        
        return header
    
    def _build_position_group(self) -> Adw.PreferencesGroup:
        """Build position selector group"""
        group = Adw.PreferencesGroup()
        group.set_title("Position")
        group.set_description("Choose where notifications appear on screen")
        
        # Get current position
        pos_x = self.prefs.get_position_x()
        pos_y = self.prefs.get_position_y()
        
        # Position grid (3x3)
        grid_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        grid_box.set_margin_top(12)
        grid_box.set_margin_bottom(12)
        
        positions = [
            [('left', 'top'), ('center', 'top'), ('right', 'top')],
            [('left', 'center'), ('center', 'center'), ('right', 'center')],
            [('left', 'bottom'), ('center', 'bottom'), ('right', 'bottom')]
        ]
        
        position_labels = {
            ('left', 'top'): "Top Left",
            ('center', 'top'): "Top Center",
            ('right', 'top'): "Top Right",
            ('left', 'center'): "Middle Left",
            ('center', 'center'): "Center",
            ('right', 'center'): "Middle Right",
            ('left', 'bottom'): "Bottom Left",
            ('center', 'bottom'): "Bottom Center",
            ('right', 'bottom'): "Bottom Right",
        }
        
        for row in positions:
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row_box.set_homogeneous(True)
            
            for x, y in row:
                btn = Gtk.Button(label=position_labels[(x, y)])
                btn.add_css_class('position-btn')
                
                if x == pos_x and y == pos_y:
                    btn.add_css_class('active')
                
                btn.connect('clicked', lambda b, px=x, py=y: self._on_position_change(px, py))
                row_box.append(btn)
            
            grid_box.append(row_box)
        
        group.add(grid_box)
        
        return group
    
    def _build_display_group(self) -> Adw.PreferencesGroup:
        """Build display selection group"""
        group = Adw.PreferencesGroup()
        group.set_title("Display")
        group.set_description("Select which monitor shows notifications")
        
        display_row = Adw.ActionRow()
        display_row.set_title("Target Display")
        
        displays = ["All Displays", "Display 1", "Display 2"]
        current = self.prefs.get_display()
        
        # Map internal values to display names
        display_map = {
            'all': "All Displays",
            'display1': "Display 1",
            'display2': "Display 2"
        }
        current_label = display_map.get(current, "All Displays")
        current_idx = displays.index(current_label) if current_label in displays else 0
        
        display_dropdown = Gtk.DropDown()
        display_dropdown.set_model(Gtk.StringList.new(displays))
        display_dropdown.set_selected(current_idx)
        display_dropdown.set_valign(Gtk.Align.CENTER)
        display_dropdown.connect('notify::selected',
                                lambda d, _: self._on_display_change(displays[d.get_selected()]))
        display_row.add_suffix(display_dropdown)
        
        group.add(display_row)
        
        return group
    
    def _build_actions_group(self) -> Adw.PreferencesGroup:
        """Build actions group"""
        group = Adw.PreferencesGroup()
        group.set_title("Actions")
        
        # Apply button
        apply_row = Adw.ActionRow()
        apply_row.set_title("Apply Configuration")
        apply_row.set_subtitle("Save settings and reload SwayNC")
        
        apply_button = Gtk.Button(label="Apply")
        apply_button.add_css_class('suggested-action')
        apply_button.set_valign(Gtk.Align.CENTER)
        apply_button.connect('clicked', lambda b: self._apply_config())
        apply_row.add_suffix(apply_button)
        
        group.add(apply_row)
        
        # Open SwayNC settings
        open_row = Adw.ActionRow()
        open_row.set_title("Advanced Settings")
        open_row.set_subtitle("Edit SwayNC config file directly")
        
        open_button = Gtk.Button(label="Open File")
        open_button.set_valign(Gtk.Align.CENTER)
        open_button.connect('clicked', lambda b: self._open_config_file())
        open_row.add_suffix(open_button)
        
        group.add(open_row)
        
        return group
    
    def _on_position_change(self, x: str, y: str):
        """Handle position change"""
        self.prefs.set_position_x(x)
        self.prefs.set_position_y(y)
        self.window._show_toast(f"Position: {y.capitalize()} {x.capitalize()}")
    
    def _on_display_change(self, display: str):
        """Handle display change"""
        # Map display name to internal value
        display_map = {
            "All Displays": 'all',
            "Display 1": 'display1',
            "Display 2": 'display2'
        }
        internal_value = display_map.get(display, 'all')
        self.prefs.set_display(internal_value)
        self.window._show_toast(f"Display: {display}")
    
    def _apply_config(self):
        """Apply configuration to SwayNC"""
        try:
            # Load current config
            if self.swaync_config_path.exists():
                with open(self.swaync_config_path, 'r') as f:
                    config = json.load(f)
            else:
                config = {}
            
            # Update position
            config['positionX'] = self.prefs.get_position_x()
            config['positionY'] = self.prefs.get_position_y()
            
            # Save config
            self.swaync_config_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.swaync_config_path, 'w') as f:
                json.dump(config, f, indent=2)
            
            # Reload SwayNC
            subprocess.run(['swaync-client', '--reload-config'], timeout=2, check=False)
            
            self.window._show_toast("SwayNC configuration applied!")
            
        except Exception as e:
            self.window._show_toast(f"Error: {str(e)}")
    
    def _open_config_file(self):
        """Open SwayNC config file in editor"""
        try:
            subprocess.Popen(['xdg-open', str(self.swaync_config_path)])
        except:
            self.window._show_toast("Could not open file")


def build_notifications_page(window) -> Gtk.Box:
    """Build notifications page (factory function)"""
    page_builder = NotificationsPage(window)
    return page_builder.build()