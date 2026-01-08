#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/base_widget.py
"""
Base Widget Class - Layer Shell with WORKING drag support
Key fix: Layer shell needs special keyboard/mouse interactivity settings
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, Gio
import json
import subprocess
from pathlib import Path

# Layer shell
HAS_LAYER_SHELL = False
Gtk4LayerShell = None

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell as LayerShell
    Gtk4LayerShell = LayerShell
    HAS_LAYER_SHELL = True
except (ValueError, ImportError) as e:
    print(f"⚠️  gtk4-layer-shell not available: {e}")


class BaseWidget(Gtk.Window):
    def __init__(self, widget_id):
        self.widget_id = widget_id
        self._layer_shell_ready = False
        
        super().__init__()
        
        # ═══════════════════════════════════════════════════════════
        # LAYER SHELL INIT
        # ═══════════════════════════════════════════════════════════
        if HAS_LAYER_SHELL and Gtk4LayerShell:
            try:
                Gtk4LayerShell.init_for_window(self)
                self._layer_shell_ready = True
                
                # BOTTOM layer
                Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
                Gtk4LayerShell.set_namespace(self, f"hypr-widget-{self.widget_id}")
                Gtk4LayerShell.set_exclusive_zone(self, -1)
                
                # ═══════════════════════════════════════════════════════════
                # CRITICAL: Enable keyboard/mouse interactivity for dragging!
                # Without this, layer shell surfaces don't receive input
                # ═══════════════════════════════════════════════════════════
                Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
                
                # Anchors - only TOP-LEFT for positioning
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
                Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
                
                print(f"[{self.widget_id}] ✅ Layer Shell ready")
            except Exception as e:
                print(f"[{self.widget_id}] ❌ Layer Shell failed: {e}")
                self._layer_shell_ready = False
        
        # Window properties
        self.set_title(f"hypr-widget-{self.widget_id}")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # ═══════════════════════════════════════════════════════════
        # IMPORTANT: Make window focusable for input events
        # ═══════════════════════════════════════════════════════════
        self.set_can_focus(True)
        self.set_focusable(True)
        
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
        self.drag_origin_x = 0
        self.drag_origin_y = 0
        self.is_dragging = False
        
        # Load saved position
        self._load_saved_position()
        
        # Apply initial position
        if self._layer_shell_ready:
            self._apply_layer_shell_position()
        
        # CSS
        self._apply_transparency_css()
        self._setup_styling()
        
        # ═══════════════════════════════════════════════════════════
        # DRAG SETUP - Using click gesture + motion controller
        # ═══════════════════════════════════════════════════════════
        self._setup_drag_v2()
        
        # Theme
        self.apply_theme_class()
        self._watch_theme_changes()
        
        # Signals
        self.connect('realize', self._on_realize)
        self.connect('map', self._on_map)
    
    def _load_saved_position(self):
        """Load position from widgets.json"""
        default_positions = {
            'clock': (100, 100),
            'weather': (100, 350),
            'system_monitor': (750, 350)
        }
        
        self.current_x, self.current_y = default_positions.get(self.widget_id, (100, 100))
        
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                
                widget_config = config.get('widgets', {}).get(self.widget_id, {})
                
                if widget_config.get('enabled', True):
                    saved_x = widget_config.get('x')
                    saved_y = widget_config.get('y')
                    
                    if saved_x is not None:
                        self.current_x = saved_x
                    if saved_y is not None:
                        self.current_y = saved_y
                    
                    print(f"[{self.widget_id}] 📍 Loaded: ({self.current_x}, {self.current_y})")
            except Exception as e:
                print(f"[{self.widget_id}] ⚠️ Load error: {e}")
    
    def _apply_layer_shell_position(self):
        """Apply position using layer shell margins"""
        if not self._layer_shell_ready:
            return
        
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.current_y)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.current_x)
    
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
        if not self._layer_shell_ready:
            GLib.timeout_add(500, self._lower_window)
    
    def _on_map(self, widget):
        if not self._layer_shell_ready:
            GLib.timeout_add(300, self._lower_window)
            GLib.timeout_add(100, self._apply_hyprctl_position)
    
    def _apply_hyprctl_position(self):
        subprocess.run(
            ['hyprctl', 'dispatch', 'movewindowpixel', 
             f'exact {self.current_x} {self.current_y}', 
             f'title:hypr-widget-{self.widget_id}'],
            capture_output=True
        )
        return False
    
    def _lower_window(self):
        if self._layer_shell_ready:
            return False
        subprocess.run(
            ['hyprctl', 'dispatch', 'alterzorder', 'bottom', 
             f'title:hypr-widget-{self.widget_id}'],
            capture_output=True
        )
        return False
    
    def _setup_drag_v2(self):
        """Setup drag using GestureDrag - works with layer shell"""
        # Primary drag gesture
        self.drag_gesture = Gtk.GestureDrag.new()
        self.drag_gesture.set_button(1)  # Left mouse button
        self.drag_gesture.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        
        self.drag_gesture.connect("drag-begin", self._on_drag_begin)
        self.drag_gesture.connect("drag-update", self._on_drag_update)
        self.drag_gesture.connect("drag-end", self._on_drag_end)
        
        self.add_controller(self.drag_gesture)
        
        # Motion controller for cursor changes
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", self._on_mouse_enter)
        motion.connect("leave", self._on_mouse_leave)
        self.add_controller(motion)
        
        # Click gesture to ensure we can receive clicks
        click = Gtk.GestureClick.new()
        click.set_button(1)
        click.connect("pressed", self._on_click_pressed)
        click.connect("released", self._on_click_released)
        self.add_controller(click)
        
        print(f"[{self.widget_id}] 🖱️ Drag controllers attached")
        
    def _setup_styling(self):
        """Load CSS styling"""
        self.css_provider = Gtk.CssProvider()
        
        if self.widget_style_path.exists():
            try:
                self.css_provider.load_from_path(str(self.widget_style_path))
            except:
                self.css_provider.load_from_string(self.get_default_css())
        elif self.style_path.exists():
            try:
                self.css_provider.load_from_path(str(self.style_path))
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
        if self.theme_config.exists():
            try:
                with open(self.theme_config, 'r') as f:
                    config = json.load(f)
                    return config.get('theme', 'one-dark')
            except:
                pass
        return 'one-dark'
    
    def apply_theme_class(self):
        theme = self.get_current_theme()
        theme_class = f"theme-{theme}"
        
        for cls in ['theme-one-dark', 'theme-gruvbox-dark', 'theme-nord', 
                    'theme-tokyo-night', 'theme-catppuccin-mocha', 
                    'theme-everforest-dark', 'theme-macos-dark']:
            self.remove_css_class(cls)
        
        self.add_css_class(theme_class)
        
    def _watch_theme_changes(self):
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
        if event_type == Gio.FileMonitorEvent.CHANGES_DONE_HINT:
            Gtk.StyleContext.remove_provider_for_display(
                Gdk.Display.get_default(), self.css_provider)
            
            self.css_provider = Gtk.CssProvider()
            if self.widget_style_path.exists():
                self.css_provider.load_from_path(str(self.widget_style_path))
            elif self.style_path.exists():
                self.css_provider.load_from_path(str(self.style_path))
            
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), self.css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    
    def _on_theme_changed(self, monitor, file, other_file, event_type):
        if event_type == Gio.FileMonitorEvent.CHANGES_DONE_HINT:
            self.apply_theme_class()
            self._on_style_changed(monitor, file, other_file, event_type)
            
    def get_default_css(self):
        return """
        window, window.background, .background {
            background-color: transparent;
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
    
    # ═══════════════════════════════════════════════════════════════
    # DRAG HANDLERS
    # ═══════════════════════════════════════════════════════════════
    
    def _on_click_pressed(self, gesture, n_press, x, y):
        """Handle click - for debugging"""
        print(f"[{self.widget_id}] 🖱️ Click at ({x:.0f}, {y:.0f})")
    
    def _on_click_released(self, gesture, n_press, x, y):
        pass
        
    def _on_drag_begin(self, gesture, x, y):
        """Start drag"""
        self.is_dragging = True
        self.drag_origin_x = self.current_x
        self.drag_origin_y = self.current_y
        self.set_cursor(Gdk.Cursor.new_from_name("grabbing"))
        print(f"[{self.widget_id}] 🎯 Drag START at ({x:.0f}, {y:.0f}), origin: ({self.drag_origin_x}, {self.drag_origin_y})")
        
    def _on_drag_update(self, gesture, offset_x, offset_y):
        """Update position smoothly"""
        if not self.is_dragging:
            return
        
        new_x = max(0, int(self.drag_origin_x + offset_x))
        new_y = max(0, int(self.drag_origin_y + offset_y))
        
        self.current_x = new_x
        self.current_y = new_y
        
        if self._layer_shell_ready:
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, new_y)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, new_x)
        else:
            subprocess.run(
                ['hyprctl', 'dispatch', 'movewindowpixel', 
                 f'exact {new_x} {new_y}', f'title:hypr-widget-{self.widget_id}'],
                capture_output=True
            )
        
    def _on_drag_end(self, gesture, offset_x, offset_y):
        """End drag and save"""
        self.is_dragging = False
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
        self.current_x = max(0, int(self.drag_origin_x + offset_x))
        self.current_y = max(0, int(self.drag_origin_y + offset_y))
        
        print(f"[{self.widget_id}] 🎯 Drag END, final: ({self.current_x}, {self.current_y})")
        
        self.save_position()
        
        if not self._layer_shell_ready:
            GLib.timeout_add(200, self._lower_window)
        
    def _on_mouse_enter(self, controller, x, y):
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
    def _on_mouse_leave(self, controller):
        if not self.is_dragging:
            self.set_cursor(None)
            
    def save_position(self):
        """Save position to widgets.json"""
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