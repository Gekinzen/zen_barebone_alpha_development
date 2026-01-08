#!/usr/bin/env python3
"""
Test script - Check if gtk4-layer-shell works properly
Run: python3 test_layer_shell.py
"""

import gi
gi.require_version('Gtk', '4.0')

# Try to import layer shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    print("✅ Gtk4LayerShell imported successfully")
    HAS_LAYER_SHELL = True
except Exception as e:
    print(f"❌ Failed to import Gtk4LayerShell: {e}")
    HAS_LAYER_SHELL = False

from gi.repository import Gtk, GLib

def on_activate(app):
    # Create window
    win = Gtk.Window()
    
    if HAS_LAYER_SHELL:
        # CRITICAL: init_for_window must be called BEFORE present()
        print("Calling init_for_window()...")
        Gtk4LayerShell.init_for_window(win)
        
        print("Setting layer to BOTTOM...")
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.BOTTOM)
        
        print("Setting namespace...")
        Gtk4LayerShell.set_namespace(win, "test-widget")
        
        print("Setting exclusive zone...")
        Gtk4LayerShell.set_exclusive_zone(win, -1)
        
        # Set position
        print("Setting anchors and margins...")
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, 100)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.LEFT, 100)
    
    win.set_title("test-layer-widget")
    win.set_decorated(False)
    win.set_application(app)
    
    # Add content
    label = Gtk.Label(label="Layer Shell Test\n\nIf you see this WITHOUT warnings,\nlayer shell is working!\n\nThis window should be BELOW other windows.")
    label.set_margin_top(20)
    label.set_margin_bottom(20)
    label.set_margin_start(20)
    label.set_margin_end(20)
    win.set_child(label)
    
    # Present window
    print("Presenting window...")
    win.present()
    
    print("\n" + "="*50)
    print("If NO warnings appeared above, layer shell works!")
    print("="*50)
    
    # Auto-close after 5 seconds
    GLib.timeout_add_seconds(5, lambda: app.quit())

app = Gtk.Application(application_id="com.test.layershell")
app.connect('activate', on_activate)
print("\nStarting test... (will auto-close in 5 seconds)\n")
app.run(None)