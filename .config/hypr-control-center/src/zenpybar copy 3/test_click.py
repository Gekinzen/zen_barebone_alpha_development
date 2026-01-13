#!/usr/bin/env python3
"""
Minimal test - does GTK4 Layer Shell receive clicks?
"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib

class TestBar(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_title("test-click-bar")
        self.set_decorated(False)
        
        # Layer Shell setup
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "test-click-bar")
        
        # Anchors
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        
        # Margins
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, 10)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, 100)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, 100)
        
        # Exclusive zone
        Gtk4LayerShell.set_exclusive_zone(self, 50)
        
        # Keyboard mode
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        
        # Build UI - simple buttons
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)
        
        # Apply CSS
        css = Gtk.CssProvider()
        css.load_from_string('''
            window { background: #1a1b26; }
            button { 
                background: #7aa2f7; 
                color: #1a1b26;
                padding: 10px 20px;
                border-radius: 10px;
                font-size: 16px;
                font-weight: bold;
            }
            button:hover { background: #bb9af7; }
        ''')
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
        # Test buttons
        for i in range(5):
            btn = Gtk.Button(label=f"Click {i+1}")
            btn.connect("clicked", lambda b, n=i+1: print(f"✅ CLICKED BUTTON {n}!"))
            box.append(btn)
        
        self.set_child(box)
        print("[TestBar] Created - try clicking the buttons!")

def main():
    app = Gtk.Application(application_id="com.test.clickbar")
    
    def on_activate(app):
        bar = TestBar()
        bar.set_application(app)
        bar.present()
    
    app.connect("activate", on_activate)
    app.run(None)

if __name__ == "__main__":
    main()