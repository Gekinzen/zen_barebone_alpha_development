#!/usr/bin/env python3
"""Debug version with error catching"""

import sys
import traceback

try:
    print("Starting imports...")
    
    import gi
    print("✓ gi imported")
    
    gi.require_version('Gtk', '4.0')
    print("✓ GTK4 version set")
    
    gi.require_version('Gtk4LayerShell', '1.0')
    print("✓ Gtk4LayerShell version set")
    
    from gi.repository import Gtk, GLib, Gdk, Gtk4LayerShell as LayerShell
    print("✓ All gi modules imported")
    
    import subprocess
    import os
    from pathlib import Path
    from datetime import datetime
    print("✓ Standard modules imported")
    
    sys.path.insert(0, str(Path(__file__).parent))
    from modules.waveform_visualizer import WaveformVisualizer
    print("✓ WaveformVisualizer imported")
    
    print("\nStarting application...")
    
    class SimpleBar(Gtk.ApplicationWindow):
        def __init__(self, app):
            print("  Creating window...")
            super().__init__(application=app)
            self.set_default_size(800, 50)
            
            print("  Setting up layer shell...")
            LayerShell.init_for_window(self)
            LayerShell.set_layer(self, LayerShell.Layer.TOP)
            LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
            LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
            LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
            LayerShell.auto_exclusive_zone_enable(self)
            
            print("  Creating UI...")
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            box.set_spacing(20)
            box.set_margin_start(20)
            box.set_margin_end(20)
            box.set_margin_top(10)
            box.set_margin_bottom(10)
            
            # Add waveform
            print("  Adding waveform...")
            self.waveform = WaveformVisualizer()
            box.append(self.waveform)
            
            # Add clock
            print("  Adding clock...")
            self.clock = Gtk.Label(label="00:00")
            box.append(self.clock)
            
            self.set_child(box)
            print("  Window setup complete!")
    
    class DebugApp(Gtk.Application):
        def __init__(self):
            print("  Initializing GTK Application...")
            super().__init__(application_id="debug.zenpybar")
        
        def do_activate(self):
            print("  Application activated!")
            try:
                win = SimpleBar(self)
                win.present()
                print("  Window presented!")
            except Exception as e:
                print(f"  ✗ Error in do_activate: {e}")
                traceback.print_exc()
    
    print("\nCreating app...")
    app = DebugApp()
    
    print("Running app...")
    exit_code = app.run(None)
    print(f"App exited with code: {exit_code}")

except Exception as e:
    print(f"\n✗ FATAL ERROR: {e}")
    traceback.print_exc()
    sys.exit(1)
