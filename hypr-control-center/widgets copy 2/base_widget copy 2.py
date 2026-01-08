#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/base_widget.py
"""
Base Widget Class - Desktop widget with auto-lower functionality
Now with GTK4 Layer Shell support for true transparency
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, Gio
import json
import os
import subprocess
from pathlib import Path

# Check for gtk4-layer-shell (required for true transparency on Wayland)
HAS_LAYER_SHELL = False
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except (ValueError, ImportError):
    print("⚠️  gtk4-layer-shell not found - install with: sudo pacman -S gtk4-layer-shell")
    print("   Widgets will work but may not have true transparent backgrounds")


class BaseWidget(Gtk.Window):
    def __init__(self, widget_id):
        super().__init__()
        
        self.widget_id = widget_id
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center/preferences"
        self.config_path = self.config_dir / "widgets.json"
        self.style_path = Path.home() / ".config/hypr-control-center/assets/style.css"
        self.widget_style_path = Path.home() / ".config/hypr-control-center/assets/widgets.css"
        self.theme_config = self.config_dir / "appearance.json"
        
        # Create config directory
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Track position manually
        self.current_x = 0
        self.current_y = 0
        self.is_dragging = False
        self.drag_start_x = 0
        self.drag_start_y = 0
        
        # Setup window properties
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_title(f"hypr-widget-{self.widget_id}")
        
        # ═══════════════════════════════════════════════════════════
        # LAYER SHELL SETUP - For true transparency on Wayland
        # ═══════════════════════════════════════════════════════════
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply base transparency CSS FIRST
        self._apply_transparency_css()
        
        # Setup drag functionality
        self._setup_drag()
        
        # Setup styling (loads widgets.css and style.css)
        self._setup_styling()
        
        # Apply current theme
        self.apply_theme_class()
        
        # Watch for theme changes
        self._watch_theme_changes()
        
        # Connect signals
        self.connect('realize', self._on_realize)
        self.connect('map', self._on_map)
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell for true Wayland transparency"""
        Gtk4LayerShell.init_for_window(self)
        
        # BOTTOM layer = below normal windows, above wallpaper
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
        
        # Namespace for identification
        Gtk4LayerShell.set_namespace(self, f"hypr-widget-{self.widget_id}")
        
        # Don't reserve space (allow windows to overlap)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        
        # Allow keyboard interaction when focused (for dragging)
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        
        print(f"[{self.widget_id}] ✅ Layer Shell initialized - true transparency enabled")
    
    def _apply_transparency_css(self):
        """Apply CSS for transparent window background"""
        css_provider = Gtk.CssProvider()
        
        # This CSS forces the window itself to be transparent
        css = """
        /* ═══════════════════════════════════════════════════════════
           FORCE WINDOW TRANSPARENCY - Applied with highest priority
           ═══════════════════════════════════════════════════════════ */
        
        window,
        window.background,
        .background {
            background-color: transparent;
            background: transparent;
            box-shadow: none;
            border: none;
        }
        
        /* Widget-specific window transparency */
        window[title^="hypr-widget-"] {
            background-color: transparent;
            background: transparent;
        }
        
        window[title^="hypr-widget-"].background {
            background-color: transparent;
            background: transparent;
        }
        """
        
        css_provider.load_from_string(css)
        
        # Apply with HIGHEST priority to override everything
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1000
        )
        
    def _on_realize(self, widget):
        """Setup after window is realized"""
        self._sync_position_from_hyprland()
        
        # Only use hyprctl lowering if NOT using layer-shell
        if not HAS_LAYER_SHELL:
            GLib.timeout_add(500, self._lower_window)
            GLib.timeout_add(2000, self._lower_window)
        
    def _lower_window(self):
        """Send widget to bottom using Hyprland (fallback without layer-shell)"""
        if HAS_LAYER_SHELL:
            return False  # Layer shell handles this
            
        try:
            subprocess.run(
                ['hyprctl', 'dispatch', 'alterzorder', 'bottom', f'title:hypr-widget-{self.widget_id}'],
                capture_output=True,
                text=True
            )
            print(f"[{self.widget_id}] 📍 Lowered to bottom")
        except Exception as e:
            print(f"[{self.widget_id}] ⚠️  Could not lower: {e}")
        
        return False
        
    def _on_map(self, widget):
        """Set initial position after window is mapped"""
        GLib.timeout_add(300, self.load_position)
        
        if not HAS_LAYER_SHELL:
            GLib.timeout_add(800, self._lower_window)
        
    def _sync_position_from_hyprland(self):
        """Get current window position from Hyprland"""
        try:
            result = subprocess.run(
                ['hyprctl', 'clients', '-j'],
                capture_output=True,
                text=True,
                timeout=1
            )
            
            if result.returncode == 0:
                import json as json_module
                clients = json_module.loads(result.stdout)
                
                for client in clients:
                    if client.get('title', '').startswith(f'hypr-widget-{self.widget_id}'):
                        self.current_x = client.get('at', [0, 0])[0]
                        self.current_y = client.get('at', [0, 0])[1]
                        break
        except:
            pass
            
    def _setup_drag(self):
        """Setup drag gesture"""
        drag = Gtk.GestureDrag.new()
        drag.set_button(1)
        drag.connect("drag-begin", self._on_drag_begin)
        drag.connect("drag-update", self._on_drag_update)
        drag.connect("drag-end", self._on_drag_end)
        self.add_controller(drag)
        
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", self._on_mouse_enter)
        motion.connect("leave", self._on_mouse_leave)
        self.add_controller(motion)
        
    def _setup_styling(self):
        """Setup CSS styling from widgets.css and style.css"""
        self.css_provider = Gtk.CssProvider()
        
        # Try widgets.css first (widget-specific styles)
        if self.widget_style_path.exists():
            try:
                self.css_provider.load_from_path(str(self.widget_style_path))
                print(f"[{self.widget_id}] ✅ Loaded widgets.css")
            except Exception as e:
                print(f"[{self.widget_id}] ⚠️  widgets.css error: {e}")
                self.css_provider.load_from_string(self.get_default_css())
        elif self.style_path.exists():
            try:
                self.css_provider.load_from_path(str(self.style_path))
                print(f"[{self.widget_id}] ✅ Loaded style.css")
            except Exception as e:
                print(f"[{self.widget_id}] ⚠️  style.css error: {e}")
                self.css_provider.load_from_string(self.get_default_css())
        else:
            self.css_provider.load_from_string(self.get_default_css())
            
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            self.css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
    def get_current_theme(self):
        """Get current theme"""
        if self.theme_config.exists():
            try:
                with open(self.theme_config, 'r') as f:
                    config = json.load(f)
                    return config.get('theme', 'one-dark')
            except:
                pass
        return 'one-dark'
    
    def apply_theme_class(self):
        """Apply theme class"""
        theme = self.get_current_theme()
        theme_class = f"theme-{theme}"
        
        for cls in ['theme-one-dark', 'theme-gruvbox-dark', 'theme-nord', 
                    'theme-tokyo-night', 'theme-catppuccin-mocha', 
                    'theme-everforest-dark', 'theme-macos-dark']:
            self.remove_css_class(cls)
        
        self.add_css_class(theme_class)
        print(f"[{self.widget_id}] 🎨 Theme: {theme}")
        
    def _watch_theme_changes(self):
        """Watch for theme changes"""
        # Watch widgets.css
        if self.widget_style_path.exists():
            gfile = Gio.File.new_for_path(str(self.widget_style_path))
            self.widget_file_monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
            self.widget_file_monitor.connect("changed", self._on_style_changed)
        
        # Watch style.css
        if self.style_path.exists():
            gfile = Gio.File.new_for_path(str(self.style_path))
            self.file_monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
            self.file_monitor.connect("changed", self._on_style_changed)
        
        # Watch theme config
        if self.theme_config.exists():
            gfile_theme = Gio.File.new_for_path(str(self.theme_config))
            self.theme_monitor = gfile_theme.monitor_file(Gio.FileMonitorFlags.NONE, None)
            self.theme_monitor.connect("changed", self._on_theme_changed)
        
    def _on_style_changed(self, monitor, file, other_file, event_type):
        """Reload CSS"""
        if event_type == Gio.FileMonitorEvent.CHANGES_DONE_HINT:
            Gtk.StyleContext.remove_provider_for_display(
                Gdk.Display.get_default(),
                self.css_provider
            )
            
            self.css_provider = Gtk.CssProvider()
            
            # Reload from appropriate file
            if self.widget_style_path.exists():
                self.css_provider.load_from_path(str(self.widget_style_path))
            elif self.style_path.exists():
                self.css_provider.load_from_path(str(self.style_path))
            
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                self.css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
            
            print(f"[{self.widget_id}] 🔄 CSS reloaded")
    
    def _on_theme_changed(self, monitor, file, other_file, event_type):
        """Reload theme"""
        if event_type == Gio.FileMonitorEvent.CHANGES_DONE_HINT:
            self.apply_theme_class()
            self._on_style_changed(monitor, file, other_file, event_type)
            
    def get_default_css(self):
        """Fallback CSS with transparency"""
        return """
        /* Fallback transparent styles */
        window,
        window.background,
        .background {
            background-color: transparent;
            background: transparent;
        }
        
        .widget-container {
            background: transparent;
        }
        
        .clock-widget-container {
            background-color: transparent;
            background: transparent;
            border: none;
            padding: 35px 45px;
        }
        
        .time-label-transparent {
            font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
            font-size: 120px;
            font-weight: 900;
            color: #ffffff;
            text-shadow: 
                0 0 100px rgba(0, 0, 0, 1),
                0 0 80px rgba(0, 0, 0, 0.95),
                0 5px 50px rgba(0, 0, 0, 1),
                5px 5px 15px rgba(0, 0, 0, 1),
                -5px -5px 15px rgba(0, 0, 0, 1),
                0 0 30px rgba(255, 255, 255, 0.4);
            letter-spacing: -4px;
        }
        
        .date-label-transparent {
            font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
            font-size: 24px;
            font-weight: 800;
            color: #ffffff;
            text-shadow: 
                0 0 50px rgba(0, 0, 0, 1),
                0 3px 30px rgba(0, 0, 0, 1),
                3px 3px 10px rgba(0, 0, 0, 1),
                -3px -3px 10px rgba(0, 0, 0, 1),
                0 0 15px rgba(255, 255, 255, 0.3);
            letter-spacing: 0.5px;
        }
        """
        
    def _on_drag_begin(self, gesture, x, y):
        """Start dragging"""
        self.is_dragging = True
        self.drag_start_x = x
        self.drag_start_y = y
        self.set_cursor(Gdk.Cursor.new_from_name("grabbing"))
        self._sync_position_from_hyprland()
        
    def _on_drag_update(self, gesture, x, y):
        """Update position while dragging"""
        if not self.is_dragging:
            return
            
        new_x = max(0, int(self.current_x + x - self.drag_start_x))
        new_y = max(0, int(self.current_y + y - self.drag_start_y))
        
        # For layer-shell, we need to set margins instead
        if HAS_LAYER_SHELL:
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, new_y)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, new_x)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        else:
            subprocess.run(
                ['hyprctl', 'dispatch', 'movewindowpixel', 
                 f'exact {new_x} {new_y}', f'title:hypr-widget-{self.widget_id}'],
                capture_output=True
            )
        
    def _on_drag_end(self, gesture, x, y):
        """Finish dragging"""
        self.is_dragging = False
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
        if HAS_LAYER_SHELL:
            # Update current position from margins
            self.current_x = Gtk4LayerShell.get_margin(self, Gtk4LayerShell.Edge.LEFT)
            self.current_y = Gtk4LayerShell.get_margin(self, Gtk4LayerShell.Edge.TOP)
        else:
            self._sync_position_from_hyprland()
            
        GLib.timeout_add(100, self.save_position)
        
        if not HAS_LAYER_SHELL:
            GLib.timeout_add(200, self._lower_window)
        
    def _on_mouse_enter(self, controller, x, y):
        """Change cursor on hover"""
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
    def _on_mouse_leave(self, controller):
        """Reset cursor"""
        if not self.is_dragging:
            self.set_cursor(None)
            
    def save_position(self):
        """Save widget position"""
        if not HAS_LAYER_SHELL:
            self._sync_position_from_hyprland()
        
        config = {"widgets": {}}
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
            except:
                pass
        
        if 'widgets' not in config:
            config['widgets'] = {}
            
        config['widgets'][self.widget_id] = {
            'x': self.current_x, 
            'y': self.current_y,
            'enabled': True
        }
        
        try:
            with open(self.config_path, 'w') as f:
                json.dump(config, f, indent=2)
            print(f"[{self.widget_id}] ✅ Saved: ({self.current_x}, {self.current_y})")
        except Exception as e:
            print(f"[{self.widget_id}] ❌ Save failed: {e}")
            
        return False
            
    def load_position(self):
        """Load and apply saved position"""
        default_positions = {
            'clock': (100, 100),
            'weather': (100, 350),
            'system_monitor': (750, 350)
        }
        
        target_x, target_y = default_positions.get(self.widget_id, (100, 100))
        
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                    
                widget_config = config.get('widgets', {}).get(self.widget_id, {})
                target_x = widget_config.get('x', target_x)
                target_y = widget_config.get('y', target_y)
                
                print(f"[{self.widget_id}] 📍 Position: ({target_x}, {target_y})")
            except:
                pass
        
        self.current_x = target_x
        self.current_y = target_y
        
        # Apply position
        if HAS_LAYER_SHELL:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, target_y)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, target_x)
        else:
            subprocess.run(
                ['hyprctl', 'dispatch', 'movewindowpixel', 
                 f'exact {target_x} {target_y}', f'title:hypr-widget-{self.widget_id}'],
                capture_output=True
            )
        
        return False