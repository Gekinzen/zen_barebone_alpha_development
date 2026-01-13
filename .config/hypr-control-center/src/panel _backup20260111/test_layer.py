#!/usr/bin/env python3
"""
Simple Layer Shell Test
Run: python3 test_layer.py
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')

from gi.repository import Gtk, GLib
from gi.repository import Gtk4LayerShell as LayerShell

class LayerWindow(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        # Initialize layer shell FIRST
        LayerShell.init_for_window(self)
        print("✅ Layer shell initialized")
        
        # Set layer to OVERLAY
        LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(self, "test-panel")
        print("✅ Layer set to OVERLAY")
        
        # Anchor to bottom
        LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
        LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
        
        # Margins
        LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, 3)
        LayerShell.set_margin(self, LayerShell.Edge.LEFT, 500)
        LayerShell.set_margin(self, LayerShell.Edge.RIGHT, 500)
        
        # No exclusive zone
        LayerShell.set_exclusive_zone(self, 0)
        LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
        
        print("✅ Anchors and margins set")
        
        # Simple content
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)
        
        label = Gtk.Label(label="🔥 Layer Shell Test - OVERLAY 🔥")
        label.set_margin_top(10)
        label.set_margin_bottom(10)
        label.set_margin_start(20)
        label.set_margin_end(20)
        box.append(label)
        
        self.set_child(box)
        
        # Style
        css = Gtk.CssProvider()
        css.load_from_string("""
            window {
                background: rgba(26, 27, 38, 0.95);
                border-radius: 20px;
                border: 2px solid #7aa2f7;
            }
            label {
                color: white;
                font-size: 16px;
                font-weight: bold;
            }
        """)
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

def on_activate(app):
    win = LayerWindow()
    win.set_application(app)
    win.present()
    print("✅ Window presented")
    print("\nRun 'hyprctl layers | grep -A2 overlay' to check")

app = Gtk.Application(application_id='com.test.layershell')
app.connect('activate', on_activate)
app.run(None)