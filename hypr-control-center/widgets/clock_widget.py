#!/usr/bin/env python3
"""
Clock Widget - Based on working transparency test
Simple approach: CSS + Layer Shell = Transparent!
"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import datetime
import json
from pathlib import Path

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[clock] ⚠️ gtk4-layer-shell not found")


class ClockWidget(Gtk.Window):
    """Transparent clock widget - simple working approach"""
    
    def __init__(self, app):
        super().__init__(application=app)
        
        self.set_title("hypr-widget-clock")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Position tracking
        self.current_x = 100
        self.current_y = 100
        self.drag_origin_x = 0
        self.drag_origin_y = 0
        self.is_dragging = False
        
        # Config
        self.config_dir = Path.home() / ".config/hypr-control-center/preferences"
        self.config_path = self.config_dir / "widgets.json"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Load position
        self._load_position()
        
        # Apply CSS FIRST
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # Setup layer shell AFTER UI
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Setup drag
        self._setup_drag()
        
        # Start updates
        self.update_time()
        GLib.timeout_add_seconds(1, self.update_time)
    
    def _load_position(self):
        """Load saved position"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                widget_config = config.get('widgets', {}).get('clock', {})
                self.current_x = widget_config.get('x', 100)
                self.current_y = widget_config.get('y', 100)
            except:
                pass
    
    def _save_position(self):
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
        
        config['widgets']['clock'] = {
            'x': self.current_x,
            'y': self.current_y,
            'enabled': True
        }
        
        with open(self.config_path, 'w') as f:
            json.dump(config, f, indent=2)
    
    def _apply_css(self):
        """Apply CSS - same pattern as working test"""
        css = Gtk.CssProvider()
        css.load_from_string("""
            * {
                background: transparent;
                background-color: rgba(0,0,0,0);
            }
            
            .clock-container {
                padding: 20px 30px;
            }
            
            .time-label {
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
            
            .date-label {
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
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
    
    def _build_ui(self):
        """Build clock UI"""
        # Container - spacing=0 for tight layout
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        container.add_css_class("clock-container")
        container.set_halign(Gtk.Align.CENTER)
        container.set_valign(Gtk.Align.CENTER)
        
        # Time label
        self.time_label = Gtk.Label()
        self.time_label.add_css_class("time-label")
        self.time_label.set_halign(Gtk.Align.CENTER)
        container.append(self.time_label)
        
        # Date label
        self.date_label = Gtk.Label()
        self.date_label.add_css_class("date-label")
        self.date_label.set_halign(Gtk.Align.CENTER)
        container.append(self.date_label)
        
        self.set_child(container)
    
    def _setup_layer_shell(self):
        """Setup layer shell"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
        Gtk4LayerShell.set_namespace(self, "hypr-widget-clock")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
        
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.current_y)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.current_x)
    
    def _setup_drag(self):
        """Setup drag gesture"""
        drag = Gtk.GestureDrag.new()
        drag.set_button(1)
        drag.connect("drag-begin", self._on_drag_begin)
        drag.connect("drag-update", self._on_drag_update)
        drag.connect("drag-end", self._on_drag_end)
        self.add_controller(drag)
        
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", lambda c,x,y: self.set_cursor(Gdk.Cursor.new_from_name("grab")))
        motion.connect("leave", lambda c: self.set_cursor(None) if not self.is_dragging else None)
        self.add_controller(motion)
    
    def _on_drag_begin(self, gesture, x, y):
        self.is_dragging = True
        self.drag_origin_x = self.current_x
        self.drag_origin_y = self.current_y
        self.set_cursor(Gdk.Cursor.new_from_name("grabbing"))
    
    def _on_drag_update(self, gesture, offset_x, offset_y):
        if not self.is_dragging:
            return
        
        new_x = max(0, int(self.drag_origin_x + offset_x))
        new_y = max(0, int(self.drag_origin_y + offset_y))
        
        self.current_x = new_x
        self.current_y = new_y
        
        if HAS_LAYER_SHELL:
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, new_y)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, new_x)
    
    def _on_drag_end(self, gesture, offset_x, offset_y):
        self.is_dragging = False
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
        self.current_x = max(0, int(self.drag_origin_x + offset_x))
        self.current_y = max(0, int(self.drag_origin_y + offset_y))
        
        self._save_position()
    
    def update_time(self):
        """Update clock"""
        now = datetime.datetime.now()
        self.time_label.set_text(now.strftime("%H:%M"))
        self.date_label.set_text(now.strftime("%A, %B %d"))
        return True


def main():
    app = Gtk.Application(application_id="com.hypr.widget.clock")
    
    def on_activate(app):
        widget = ClockWidget(app)
        widget.present()
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()