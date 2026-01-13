#!/usr/bin/env python3
"""
Layer Shell Test v2 - Using realize signal
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')

from gi.repository import Gtk, GLib
from gi.repository import Gtk4LayerShell as LayerShell

class LayerWindow(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        # Check if layer shell is supported
        if not LayerShell.is_supported():
            print("❌ Layer Shell is NOT supported!")
            return
        
        print("✅ Layer Shell is supported")
        
        # Initialize layer shell FIRST - before anything else
        LayerShell.init_for_window(self)
        
        # Verify it's now a layer surface
        if LayerShell.is_layer_window(self):
            print("✅ Window IS a layer surface!")
        else:
            print("❌ Window is NOT a layer surface")
            return
        
        # Set layer to OVERLAY
        LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(self, "test-panel")
        
        # Anchor to bottom center
        LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
        LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
        
        LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, 3)
        LayerShell.set_margin(self, LayerShell.Edge.LEFT, 500)
        LayerShell.set_margin(self, LayerShell.Edge.RIGHT, 500)
        
        LayerShell.set_exclusive_zone(self, 0)
        LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
        
        print("✅ Layer shell configured")
        
        # Content
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)
        
        label = Gtk.Label(label="🔥 OVERLAY TEST 🔥")
        label.set_margin_top(15)
        label.set_margin_bottom(15)
        label.set_margin_start(30)
        label.set_margin_end(30)
        box.append(label)
        
        self.set_child(box)
        
        # CSS
        css = Gtk.CssProvider()
        css.load_from_string("""
            window { 
                background: #1a1b26; 
                border-radius: 20px; 
                border: 2px solid #7aa2f7; 
            }
            label { 
                color: #c0caf5; 
                font-size: 18px; 
                font-weight: bold; 
            }
        """)
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

def main():
    app = Gtk.Application(application_id='com.test.layer2')
    
    def on_activate(app):
        win = LayerWindow()
        win.set_application(app)
        win.present()
    
    app.connect('activate', on_activate)
    app.run(None)

if __name__ == "__main__":
    main()