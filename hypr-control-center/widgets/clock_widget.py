#!/usr/bin/env python3
"""
Clock Widget - Timezone Aware Version
Features:
- Configurable timezone from widgets.json
- 24h/12h format support
- Position persistence
- Draggable
"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import json
from pathlib import Path
from datetime import datetime

try:
    import pytz
    HAS_PYTZ = True
except ImportError:
    HAS_PYTZ = False
    print("[clock] ⚠️ pytz not installed, using local time")

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[clock] ⚠️ gtk4-layer-shell not found")


class ClockWidget(Gtk.Window):
    """Transparent clock widget with timezone support"""
    
    def __init__(self, app, is_secondary=False):
        super().__init__(application=app)
        
        self.is_secondary = is_secondary
        self.config_key = "clock_secondary" if is_secondary else "clock"
        
        if is_secondary:
            self.set_title("hypr-widget-clock-secondary")
            self.namespace = "hypr-widget-clock-secondary"
        else:
            self.set_title("hypr-widget-clock")
            self.namespace = "hypr-widget-clock"
        
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Position tracking
        self.current_x = 100
        self.current_y = 100 if not is_secondary else 250
        self.drag_origin_x = 0
        self.drag_origin_y = 0
        self.is_dragging = False
        
        # Config
        self.config_dir = Path.home() / ".config/hypr-control-center/preferences"
        self.config_path = self.config_dir / "widgets.json"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Default settings
        self.timezone = "Asia/Manila"
        self.format_24h = True
        
        # Load config
        self._load_config()
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # Setup layer shell
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Setup drag
        self._setup_drag()
        
        # Start updates
        self.update_time()
        GLib.timeout_add_seconds(1, self.update_time)
        
        # Watch config changes
        GLib.timeout_add_seconds(5, self._check_config_changes)
    
    def _load_config(self):
        """Load configuration"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                
                widget_config = config.get('widgets', {}).get(self.config_key, {})
                self.current_x = widget_config.get('x', self.current_x)
                self.current_y = widget_config.get('y', self.current_y)
                self.timezone = widget_config.get('timezone', self.timezone)
                self.format_24h = widget_config.get('format_24h', self.format_24h)
                
            except Exception as e:
                print(f"[clock] Config load error: {e}")
    
    def _save_config(self):
        """Save position to config"""
        config = {"widgets": {}}
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
            except:
                pass
        
        if 'widgets' not in config:
            config['widgets'] = {}
        
        if self.config_key not in config['widgets']:
            config['widgets'][self.config_key] = {}
        
        config['widgets'][self.config_key].update({
            'x': self.current_x,
            'y': self.current_y,
            'enabled': True
        })
        
        with open(self.config_path, 'w') as f:
            json.dump(config, f, indent=2)
    
    def _check_config_changes(self) -> bool:
        """Check for config changes (timezone, format)"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                
                widget_config = config.get('widgets', {}).get(self.config_key, {})
                new_tz = widget_config.get('timezone', self.timezone)
                new_format = widget_config.get('format_24h', self.format_24h)
                
                if new_tz != self.timezone or new_format != self.format_24h:
                    self.timezone = new_tz
                    self.format_24h = new_format
                    self.update_time()
                    
            except:
                pass
        
        return True
    
    def _apply_css(self):
        """Apply CSS"""
        # Different color for secondary clock
        if self.is_secondary:
            time_color = "#87ceeb"  # Light blue
            glow_color = "rgba(135, 206, 235, 0.4)"
        else:
            time_color = "#ffffff"
            glow_color = "rgba(255, 255, 255, 0.4)"
        
        css = Gtk.CssProvider()
        css.load_from_string(f"""
            * {{
                background: transparent;
                background-color: rgba(0,0,0,0);
            }}
            
            .clock-container {{
                padding: 20px 30px;
            }}
            
            .time-label {{
                font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
                font-size: 120px;
                font-weight: 900;
                color: {time_color};
                text-shadow: 
                    0 0 100px rgba(0, 0, 0, 1),
                    0 0 80px rgba(0, 0, 0, 0.95),
                    0 5px 50px rgba(0, 0, 0, 1),
                    5px 5px 15px rgba(0, 0, 0, 1),
                    -5px -5px 15px rgba(0, 0, 0, 1),
                    0 0 30px {glow_color};
                letter-spacing: -4px;
            }}
            
            .date-label {{
                font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
                font-size: 24px;
                font-weight: 800;
                color: {time_color};
                text-shadow: 
                    0 0 50px rgba(0, 0, 0, 1),
                    0 3px 30px rgba(0, 0, 0, 1),
                    3px 3px 10px rgba(0, 0, 0, 1),
                    -3px -3px 10px rgba(0, 0, 0, 1),
                    0 0 15px {glow_color};
                letter-spacing: 0.5px;
            }}
            
            .timezone-label {{
                font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
                font-size: 14px;
                font-weight: 600;
                color: rgba(255, 255, 255, 0.6);
                text-shadow: 
                    0 0 30px rgba(0, 0, 0, 1),
                    2px 2px 8px rgba(0, 0, 0, 1);
                margin-top: 8px;
            }}
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
    
    def _build_ui(self):
        """Build clock UI"""
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
        
        # Timezone label (only for secondary or non-local)
        self.tz_label = Gtk.Label()
        self.tz_label.add_css_class("timezone-label")
        self.tz_label.set_halign(Gtk.Align.CENTER)
        container.append(self.tz_label)
        
        self.set_child(container)
    
    def _setup_layer_shell(self):
        """Setup layer shell"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
        Gtk4LayerShell.set_namespace(self, self.namespace)
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
        
        self._save_config()
    
    def update_time(self) -> bool:
        """Update clock display"""
        try:
            if HAS_PYTZ:
                tz = pytz.timezone(self.timezone)
                now = datetime.now(tz)
            else:
                now = datetime.now()
            
            # Format time
            if self.format_24h:
                self.time_label.set_text(now.strftime("%H:%M"))
            else:
                self.time_label.set_text(now.strftime("%I:%M %p"))
            
            # Date
            self.date_label.set_text(now.strftime("%A, %B %d"))
            
            # Timezone indicator
            if self.is_secondary or self.timezone != "Asia/Manila":
                tz_short = self.timezone.split('/')[-1].replace('_', ' ')
                self.tz_label.set_text(tz_short)
                self.tz_label.set_visible(True)
            else:
                self.tz_label.set_visible(False)
            
        except Exception as e:
            print(f"[clock] Time update error: {e}")
            self.time_label.set_text("--:--")
        
        return True


def main():
    import sys
    
    # Check if running as secondary clock
    is_secondary = "--secondary" in sys.argv or "secondary" in sys.argv
    
    if is_secondary:
        app_id = "com.hypr.widget.clock.secondary"
    else:
        app_id = "com.hypr.widget.clock"
    
    app = Gtk.Application(application_id=app_id)
    
    def on_activate(app):
        widget = ClockWidget(app, is_secondary=is_secondary)
        widget.present()
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()