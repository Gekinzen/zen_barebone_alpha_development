#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/base_widget.py
"""
Base Widget Class - Desktop widget with Layer Shell
CRITICAL FIX: Layer shell init must be the VERY FIRST call after window creation
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, Gio
import json
import subprocess
from pathlib import Path

# Check for gtk4-layer-shell
HAS_LAYER_SHELL = False
Gtk4LayerShell = None

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell as LayerShell
    Gtk4LayerShell = LayerShell
    HAS_LAYER_SHELL = True
    print("✅ gtk4-layer-shell available")
except (ValueError, ImportError) as e:
    print(f"⚠️  gtk4-layer-shell not available: {e}")
    print("   Install: sudo pacman -S gtk4-layer-shell")


class BaseWidget(Gtk.Window):
    def __init__(self, widget_id):
        self.widget_id = widget_id
        self._layer_shell_ready = False
        
        # ═══════════════════════════════════════════════════════════
        # STEP 1: Call parent init
        # ═══════════════════════════════════════════════════════════
        super().__init__()
        
        # ═══════════════════════════════════════════════════════════
        # STEP 2: IMMEDIATELY init layer shell - BEFORE anything else!
        # This MUST happen before set_title, set_decorated, etc.
        # ═══════════════════════════════════════════════════════════
        if HAS_LAYER_SHELL and Gtk4LayerShell:
            try:
                Gtk4LayerShell.init_for_window(self)
                self._layer_shell_ready = True
                print(f"[{self.widget_id}] ✅ Layer shell initialized")
            except Exception as e:
                print(f"[{self.widget_id}] ❌ Layer shell init failed: {e}")
                self._layer_shell_ready = False
        
        # ═══════════════════════════════════════════════════════════
        # STEP 3: Now configure layer shell (if initialized)
        # ═══════════════════════════════════════════════════════════
        if self._layer_shell_ready:
            try:
                # BOTTOM layer = below all windows
                Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
                
                # Namespace for identification
                Gtk4LayerShell.set_namespace(self, f"hypr-widget-{self.widget_id}")
                
                # Don't reserve space
                Gtk4LayerShell.set_exclusive_zone(self, -1)
                
                # Keyboard on demand
                Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
                
                print(f"[{self.widget_id}] ✅ Layer shell configured - BOTTOM layer")
            except Exception as e:
                print(f"[{self.widget_id}] ❌ Layer shell config failed: {e}")
                self._layer_shell_ready = False
        
        # ═══════════════════════════════════════════════════════════
        # STEP 4: Now set window properties (AFTER layer shell)
        # ═══════════════════════════════════════════════════════════
        self.set_title(f"hypr-widget-{self.widget_id}")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center/preferences"
        self.config_path = self.config_dir / "widgets.json"
        self.style_path = Path.home() / ".config/hypr-control-center/assets/style.css"
        self.widget_style_path = Path.home() / ".config/hypr-control-center/assets/widgets.css"
        self.theme_config = self.config_dir / "appearance.json"
        
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Position tracking
        self.current_x = 0
        self.current_y = 0
        self.is_dragging = False
        self.drag_start_x = 0
        self.drag_start_y = 0
        
        # Apply transparency CSS
        self._apply_transparency_css()
        
        # Setup drag
        self._setup_drag()
        
        # Setup styling
        self._setup_styling()
        
        # Apply theme
        self.apply_theme_class()
        
        # Watch changes
        self._watch_theme_changes()
        
        # Connect signals
        self.connect('realize', self._on_realize)
        self.connect('map', self._on_map)
    
    def _apply_transparency_css(self):
        """Apply CSS for transparent background"""
        css_provider = Gtk.CssProvider()
        
        css = """
        window,
        window.background,
        .background {
            background-color: transparent;
            background: transparent;
            box-shadow: none;
            border: none;
        }
        """
        
        css_provider.load_from_string(css)
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1000
        )
        
    def _on_realize(self, widget):
        """After window is realized"""
        GLib.timeout_add(100, self._apply_initial_position)
        
        if not self._layer_shell_ready:
            GLib.timeout_add(500, self._lower_window)
            GLib.timeout_add(2000, self._lower_window)
    
    def _apply_initial_position(self):
        """Apply initial position"""
        self.load_position()
        return False
        
    def _on_map(self, widget):
        """After window is mapped"""
        if not self._layer_shell_ready:
            GLib.timeout_add(300, self._lower_window)
    
    def _lower_window(self):
        """Fallback: lower window using hyprctl"""
        if self._layer_shell_ready:
            return False
            
        try:
            subprocess.run(
                ['hyprctl', 'dispatch', 'alterzorder', 'bottom', 
                 f'title:hypr-widget-{self.widget_id}'],
                capture_output=True, text=True
            )
            print(f"[{self.widget_id}] 📍 Lowered (hyprctl fallback)")
        except Exception as e:
            print(f"[{self.widget_id}] ⚠️ Lower failed: {e}")
        
        return False
            
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
        """Load CSS styling"""
        self.css_provider = Gtk.CssProvider()
        
        if self.widget_style_path.exists():
            try:
                self.css_provider.load_from_path(str(self.widget_style_path))
                print(f"[{self.widget_id}] ✅ Loaded widgets.css")
            except Exception as e:
                print(f"[{self.widget_id}] ⚠️ widgets.css error: {e}")
                self.css_provider.load_from_string(self.get_default_css())
        elif self.style_path.exists():
            try:
                self.css_provider.load_from_path(str(self.style_path))
                print(f"[{self.widget_id}] ✅ Loaded style.css")
            except:
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
        """Watch for theme/style changes"""
        if self.widget_style_path.exists():
            gfile = Gio.File.new_for_path(str(self.widget_style_path))
            self.widget_file_monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
            self.widget_file_monitor.connect("changed", self._on_style_changed)
        
        if self.style_path.exists():
            gfile = Gio.File.new_for_path(str(self.style_path))
            self.file_monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
            self.file_monitor.connect("changed", self._on_style_changed)
        
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
        """Fallback CSS"""
        return """
        window, window.background, .background {
            background-color: transparent;
            background: transparent;
        }
        .clock-widget-container {
            background-color: transparent;
            padding: 35px 45px;
        }
        .time-label-transparent {
            font-size: 120px;
            font-weight: 900;
            color: #ffffff;
            text-shadow: 0 5px 50px rgba(0, 0, 0, 1);
        }
        .date-label-transparent {
            font-size: 24px;
            font-weight: 800;
            color: #ffffff;
            text-shadow: 0 3px 30px rgba(0, 0, 0, 1);
        }
        """
        
    def _on_drag_begin(self, gesture, x, y):
        """Start drag"""
        self.is_dragging = True
        self.drag_start_x = x
        self.drag_start_y = y
        self.set_cursor(Gdk.Cursor.new_from_name("grabbing"))
        
        if self._layer_shell_ready:
            self.current_x = Gtk4LayerShell.get_margin(self, Gtk4LayerShell.Edge.LEFT)
            self.current_y = Gtk4LayerShell.get_margin(self, Gtk4LayerShell.Edge.TOP)
        else:
            self._sync_position_from_hyprland()
        
    def _on_drag_update(self, gesture, x, y):
        """Update position"""
        if not self.is_dragging:
            return
            
        new_x = max(0, int(self.current_x + x - self.drag_start_x))
        new_y = max(0, int(self.current_y + y - self.drag_start_y))
        
        if self._layer_shell_ready:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, new_y)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, new_x)
        else:
            subprocess.run(
                ['hyprctl', 'dispatch', 'movewindowpixel', 
                 f'exact {new_x} {new_y}', f'title:hypr-widget-{self.widget_id}'],
                capture_output=True
            )
        
    def _on_drag_end(self, gesture, x, y):
        """End drag"""
        self.is_dragging = False
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
        if self._layer_shell_ready:
            self.current_x = Gtk4LayerShell.get_margin(self, Gtk4LayerShell.Edge.LEFT)
            self.current_y = Gtk4LayerShell.get_margin(self, Gtk4LayerShell.Edge.TOP)
        else:
            self._sync_position_from_hyprland()
            
        GLib.timeout_add(100, self.save_position)
        
        if not self._layer_shell_ready:
            GLib.timeout_add(200, self._lower_window)
    
    def _sync_position_from_hyprland(self):
        """Get position from hyprctl"""
        try:
            result = subprocess.run(
                ['hyprctl', 'clients', '-j'],
                capture_output=True, text=True, timeout=1
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
        
    def _on_mouse_enter(self, controller, x, y):
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
    def _on_mouse_leave(self, controller):
        if not self.is_dragging:
            self.set_cursor(None)
            
    def save_position(self):
        """Save position"""
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
        """Load and apply position"""
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
        
        if self._layer_shell_ready:
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