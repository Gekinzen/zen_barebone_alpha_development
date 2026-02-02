#!/usr/bin/env python3
"""
Clock Widget - Pure transparent background, text only visible
Uses GTK4 Layer Shell approach for true transparency
"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import datetime
import os

# Check if gtk4-layer-shell is available
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[clock] ⚠️ gtk4-layer-shell not found, using fallback transparency")


class ClockWidget(Gtk.Window):
    """Transparent clock widget for desktop"""
    
    def __init__(self):
        super().__init__()
        
        self.set_title("hypr-widget-clock")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Try layer shell first (best transparency)
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply CSS for transparency
        self._apply_css()
        
        # Create UI
        self._build_ui()
        
        # Start clock update
        self.update_time()
        GLib.timeout_add_seconds(1, self.update_time)
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell for true transparency"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
        Gtk4LayerShell.set_namespace(self, "hypr-widget-clock")
        
        # Disable exclusive zone (don't push other windows)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        
        # Set margins if needed
        # Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, 100)
        # Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, 100)
    
    def _apply_css(self):
        """Apply CSS for transparent clock"""
        css_provider = Gtk.CssProvider()
        
        css = """
        /* CRITICAL: Force window transparency */
        window,
        window.background,
        .background {
            background-color: transparent;
            background: transparent;
            box-shadow: none;
            border: none;
        }
        
        /* Clock container - fully transparent */
        .clock-widget-container {
            background-color: transparent;
            background: transparent;
            border: none;
            padding: 35px 45px;
        }
        
        /* Time label with shadow for readability */
        .time-label-transparent {
            font-family: "Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif;
            font-size: 120px;
            font-weight: 900;
            color: #ffffff;
            margin-bottom: 10px;
            text-shadow: 
                0 0 100px rgba(0, 0, 0, 1),
                0 0 80px rgba(0, 0, 0, 0.95),
                0 5px 50px rgba(0, 0, 0, 1),
                5px 5px 15px rgba(0, 0, 0, 1),
                -5px -5px 15px rgba(0, 0, 0, 1),
                0 0 30px rgba(255, 255, 255, 0.4);
            letter-spacing: -4px;
        }
        
        /* Date label */
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
        
        css_provider.load_from_string(css)
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100
        )
    
    def _build_ui(self):
        """Build the clock UI"""
        # Container
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        container.add_css_class("clock-widget-container")
        container.set_halign(Gtk.Align.CENTER)
        container.set_valign(Gtk.Align.CENTER)
        
        # Time label
        self.time_label = Gtk.Label()
        self.time_label.add_css_class("time-label-transparent")
        self.time_label.set_halign(Gtk.Align.CENTER)
        container.append(self.time_label)
        
        # Date label
        self.date_label = Gtk.Label()
        self.date_label.add_css_class("date-label-transparent")
        self.date_label.set_halign(Gtk.Align.CENTER)
        container.append(self.date_label)
        
        self.set_child(container)
    
    def update_time(self):
        """Update clock display"""
        now = datetime.datetime.now()
        time_str = now.strftime("%H:%M")
        date_str = now.strftime("%A, %B %d")
        
        self.time_label.set_text(time_str)
        self.date_label.set_text(date_str)
        return True


def main():
    app = Gtk.Application(application_id="com.hypr.widget.clock")
    
    def on_activate(app):
        widget = ClockWidget()
        widget.set_application(app)
        widget.present()
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()