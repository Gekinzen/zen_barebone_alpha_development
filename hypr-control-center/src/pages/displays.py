"""
Displays Page - Monitor configuration with nwg-displays integration
Optimized for performance and memory efficiency
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib
import subprocess
import json
from pathlib import Path
from typing import List, Dict, Optional

from ..widgets import SettingsGroup, DropdownRow, ToggleRow
from ..preferences import DisplayPreferences

class DisplaysPage:
    """Displays page with lazy loading and efficient rendering"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = DisplayPreferences()
        self.monitors = []
        self._monitor_widgets = {}  # Cache widgets
        
    def build(self) -> Gtk.Box:
        """Build displays page with lazy loading"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.set_margin_top(24)
        page.set_margin_bottom(24)
        page.set_margin_start(32)
        page.set_margin_end(32)
        
        # Header
        header = self._build_header()
        page.append(header)
        
        # Load monitors asynchronously
        spinner = Gtk.Spinner()
        spinner.start()
        page.append(spinner)
        
        # Detect monitors in background
        GLib.idle_add(lambda: self._load_monitors_async(page, spinner))
        
        return page
    
    def _build_header(self) -> Gtk.Box:
        """Build page header"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        header.set_margin_bottom(24)
        
        title = Gtk.Label(label="Displays")
        title.add_css_class('page-title')
        title.set_xalign(0)
        header.append(title)
        
        subtitle = Gtk.Label(
            label="Configure monitors, resolution, and scaling"
        )
        subtitle.add_css_class('page-subtitle')
        subtitle.set_xalign(0)
        header.append(subtitle)
        
        return header
    
    def _load_monitors_async(self, page: Gtk.Box, spinner: Gtk.Spinner):
        """Load monitors asynchronously to avoid blocking UI"""
        try:
            # Detect monitors
            self.monitors = self._detect_monitors()
            
            # Remove spinner
            page.remove(spinner)
            
            # Build monitor sections
            if self.monitors:
                for monitor in self.monitors:
                    section = self._build_monitor_section(monitor)
                    page.append(section)
                
                # Quick actions
                actions = self._build_quick_actions()
                page.append(actions)
            else:
                # No monitors found
                error_label = Gtk.Label(label="No monitors detected")
                error_label.add_css_class('dim-label')
                page.append(error_label)
                
        except Exception as e:
            page.remove(spinner)
            error = Gtk.Label(label=f"Error: {str(e)}")
            error.add_css_class('error-label')
            page.append(error)
        
        return False  # Don't repeat
    
    def _detect_monitors(self) -> List[Dict]:
        """
        Detect monitors using hyprctl with available modes
        Returns list of monitor info dicts
        """
        try:
            result = subprocess.run(
                ['hyprctl', 'monitors', '-j'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            if result.returncode == 0:
                monitors_data = json.loads(result.stdout)
                monitors = []
                
                for m in monitors_data:
                    # Get available modes
                    modes = self._get_available_modes(m.get('name'))
                    
                    monitor_info = {
                        'name': m.get('name', 'Unknown'),
                        'description': m.get('description', 'Monitor'),
                        'width': m.get('width', 1920),
                        'height': m.get('height', 1080),
                        'refreshRate': m.get('refreshRate', 60.0),
                        'scale': m.get('scale', 1.0),
                        'x': m.get('x', 0),
                        'y': m.get('y', 0),
                        'transform': m.get('transform', 0),
                        'focused': m.get('focused', False),
                        'activeWorkspace': m.get('activeWorkspace', {}),
                        'availableModes': modes,  # Available resolutions and refresh rates
                    }
                    monitors.append(monitor_info)
                
                return monitors
        except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
            pass
        
        return []
    
    def _get_available_modes(self, monitor_name: str) -> List[Dict]:
        """Get available display modes for a monitor"""
        try:
            # Use wlr-randr to get available modes
            result = subprocess.run(
                ['wlr-randr'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            if result.returncode == 0:
                modes = []
                in_monitor = False
                
                for line in result.stdout.split('\n'):
                    # Check if this is our monitor
                    if monitor_name in line:
                        in_monitor = True
                        continue
                    
                    # Stop at next monitor
                    if in_monitor and line and not line.startswith(' '):
                        break
                    
                    # Parse mode line (e.g., "  1920x1080 px, 60.000000 Hz")
                    if in_monitor and 'px' in line and 'Hz' in line:
                        try:
                            # Extract resolution and refresh rate
                            parts = line.strip().split(',')
                            res_part = parts[0].strip().replace(' px', '')
                            rate_part = parts[1].strip().replace(' Hz', '')
                            
                            width, height = map(int, res_part.split('x'))
                            rate = float(rate_part)
                            
                            modes.append({
                                'width': width,
                                'height': height,
                                'refreshRate': rate
                            })
                        except (ValueError, IndexError):
                            continue
                
                return modes if modes else self._get_default_modes()
        except:
            pass
        
        return self._get_default_modes()
    
    def _get_default_modes(self) -> List[Dict]:
        """Fallback default modes"""
        return [
            {'width': 3840, 'height': 2160, 'refreshRate': 60.0},  # 4K
            {'width': 2560, 'height': 1440, 'refreshRate': 144.0}, # 1440p 144Hz
            {'width': 2560, 'height': 1440, 'refreshRate': 60.0},  # 1440p
            {'width': 1920, 'height': 1080, 'refreshRate': 144.0}, # 1080p 144Hz
            {'width': 1920, 'height': 1080, 'refreshRate': 60.0},  # 1080p
        ]
    
    def _build_monitor_section(self, monitor: Dict) -> Adw.PreferencesGroup:
        """Build configuration section for a monitor"""
        # Use Adw.PreferencesGroup for efficiency
        group = Adw.PreferencesGroup()
        group.set_title(monitor['description'])
        group.set_description(f"{monitor['name']} • {monitor['width']}x{monitor['height']}@{monitor['refreshRate']:.0f}Hz")
        
        # Cache widget for reuse
        if monitor['name'] not in self._monitor_widgets:
            self._monitor_widgets[monitor['name']] = self._create_monitor_controls(monitor)
        
        for widget in self._monitor_widgets[monitor['name']]:
            group.add(widget)
        
        return group
    
    def _create_monitor_controls(self, monitor: Dict) -> List[Adw.ActionRow]:
        """Create control widgets for a monitor (cached)"""
        controls = []
        
        # Enable/Disable
        enable_row = Adw.ActionRow()
        enable_row.set_title("Enable Display")
        enable_switch = Gtk.Switch()
        enable_switch.set_active(True)  # Assume enabled if detected
        enable_switch.set_valign(Gtk.Align.CENTER)
        enable_switch.connect('notify::active', 
                            lambda s, _: self._on_monitor_toggle(monitor['name'], s.get_active()))
        enable_row.add_suffix(enable_switch)
        controls.append(enable_row)
        
        # Resolution (if we have available modes)
        res_row = Adw.ActionRow()
        res_row.set_title("Resolution")
        res_row.set_subtitle(f"{monitor['width']}x{monitor['height']}")
        controls.append(res_row)
        
        # Refresh Rate
        refresh_row = Adw.ActionRow()
        refresh_row.set_title("Refresh Rate")
        refresh_row.set_subtitle(f"{monitor['refreshRate']:.0f} Hz")
        controls.append(refresh_row)
        
        # Scale
        scale_row = Adw.ActionRow()
        scale_row.set_title("Scale")
        
        # Create scale dropdown
        scale_options = ["100%", "125%", "133%", "150%", "167%", "175%", "200%"]
        scale_values = [1.0, 1.25, 1.333333, 1.5, 1.666667, 1.75, 2.0]
        
        current_scale = monitor['scale']
        # Find closest scale
        closest_idx = min(range(len(scale_values)), 
                         key=lambda i: abs(scale_values[i] - current_scale))
        
        scale_dropdown = Gtk.DropDown()
        scale_dropdown.set_model(Gtk.StringList.new(scale_options))
        scale_dropdown.set_selected(closest_idx)
        scale_dropdown.set_valign(Gtk.Align.CENTER)
        scale_dropdown.connect('notify::selected', 
                              lambda d, _: self._on_scale_change(monitor['name'], 
                                                                 scale_values[d.get_selected()]))
        scale_row.add_suffix(scale_dropdown)
        controls.append(scale_row)
        
        # Orientation
        orient_row = Adw.ActionRow()
        orient_row.set_title("Orientation")
        
        orient_options = ["Standard", "90°", "180°", "270°"]
        orient_values = [0, 1, 2, 3]
        
        orient_dropdown = Gtk.DropDown()
        orient_dropdown.set_model(Gtk.StringList.new(orient_options))
        orient_dropdown.set_selected(monitor.get('transform', 0))
        orient_dropdown.set_valign(Gtk.Align.CENTER)
        orient_dropdown.connect('notify::selected',
                               lambda d, _: self._on_orientation_change(monitor['name'],
                                                                       orient_values[d.get_selected()]))
        orient_row.add_suffix(orient_dropdown)
        controls.append(orient_row)
        
        return controls
    
    def _build_quick_actions(self) -> Adw.PreferencesGroup:
        """Build quick action buttons"""
        group = Adw.PreferencesGroup()
        group.set_title("Quick Actions")
        
        # Open nwg-displays button
        nwg_row = Adw.ActionRow()
        nwg_row.set_title("Advanced Display Settings")
        nwg_row.set_subtitle("Open nwg-displays for visual configuration")
        
        nwg_button = Gtk.Button(label="Open")
        nwg_button.set_valign(Gtk.Align.CENTER)
        nwg_button.connect('clicked', lambda b: self._launch_nwg_displays())
        nwg_row.add_suffix(nwg_button)
        
        group.add(nwg_row)
        
        # Apply button
        apply_row = Adw.ActionRow()
        apply_row.set_title("Apply Configuration")
        apply_row.set_subtitle("Save and apply monitor settings")
        
        apply_button = Gtk.Button(label="Apply")
        apply_button.add_css_class('suggested-action')
        apply_button.set_valign(Gtk.Align.CENTER)
        apply_button.connect('clicked', lambda b: self._apply_changes())
        apply_row.add_suffix(apply_button)
        
        group.add(apply_row)
        
        return group
    
    def _on_monitor_toggle(self, monitor_name: str, enabled: bool):
        """Handle monitor enable/disable"""
        config = self.prefs.get_monitor_config(monitor_name) or {}
        config['enabled'] = enabled
        self.prefs.set_monitor_config(monitor_name, config)
    
    def _on_resolution_change(self, monitor_name: str, resolution: str):
        """Handle resolution change"""
        width, height = map(int, resolution.split('x'))
        config = self.prefs.get_monitor_config(monitor_name) or {}
        config['width'] = width
        config['height'] = height
        self.prefs.set_monitor_config(monitor_name, config)
    
    def _on_refresh_change(self, monitor_name: str, refresh_rate: float):
        """Handle refresh rate change"""
        config = self.prefs.get_monitor_config(monitor_name) or {}
        config['refreshRate'] = refresh_rate
        self.prefs.set_monitor_config(monitor_name, config)
    
    def _on_scale_change(self, monitor_name: str, scale: float):
        """Handle scale change"""
        config = self.prefs.get_monitor_config(monitor_name) or {}
        config['scale'] = scale
        self.prefs.set_monitor_config(monitor_name, config)
    
    def _on_orientation_change(self, monitor_name: str, transform: int):
        """Handle orientation change"""
        config = self.prefs.get_monitor_config(monitor_name) or {}
        config['transform'] = transform
        self.prefs.set_monitor_config(monitor_name, config)
    
    def _launch_nwg_displays(self):
        """Launch nwg-displays for advanced configuration"""
        try:
            subprocess.Popen(['nwg-displays'])
        except FileNotFoundError:
            self.window._show_toast("nwg-displays not installed")
    
    def _apply_changes(self):
        """Apply monitor configuration"""
        try:
            # Write to monitors.conf
            self._write_monitors_conf()
            
            # Run scale fixer
            scale_script = Path.home() / ".config/hypr/scripts/fix-monitor-scale.sh"
            if scale_script.exists():
                subprocess.run(['bash', str(scale_script)], timeout=5)
            
            # Reload Hyprland
            subprocess.run(['hyprctl', 'reload'], timeout=2)
            
            self.window._show_toast("Monitor configuration applied!")
        except Exception as e:
            self.window._show_toast(f"Error: {str(e)}")
    
    def _write_monitors_conf(self):
        """Write monitors.conf file"""
        conf_file = Path.home() / ".config/hypr/monitors.conf"
        conf_file.parent.mkdir(parents=True, exist_ok=True)
        
        lines = []
        for monitor in self.monitors:
            config = self.prefs.get_monitor_config(monitor['name']) or {}
            
            # Get settings
            enabled = config.get('enabled', True)
            scale = config.get('scale', monitor['scale'])
            transform = config.get('transform', monitor['transform'])
            
            if enabled:
                # Format: monitor=NAME,RES@RATE,POS,SCALE
                line = (
                    f"monitor={monitor['name']},"
                    f"{monitor['width']}x{monitor['height']}@{monitor['refreshRate']:.0f},"
                    f"{monitor['x']}x{monitor['y']},"
                    f"{scale}"
                )
                
                if transform > 0:
                    line += f",transform,{transform}"
                
                lines.append(line)
            else:
                lines.append(f"monitor={monitor['name']},disable")
        
        conf_file.write_text('\n'.join(lines) + '\n')


def build_displays_page(window) -> Gtk.Box:
    """Build displays page (factory function)"""
    page_builder = DisplaysPage(window)
    return page_builder.build()