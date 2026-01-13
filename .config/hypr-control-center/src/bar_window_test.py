#!/usr/bin/env python3
"""Test bar as regular window (not layer shell)"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import sys
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent))
from modules.waveform_visualizer import WaveformVisualizer

class TestBar(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("ZenPyBar Test")
        self.set_default_size(800, 50)
        
        # Create UI
        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        main_box.set_spacing(20)
        main_box.set_margin_start(20)
        main_box.set_margin_end(20)
        main_box.set_margin_top(10)
        main_box.set_margin_bottom(10)
        
        # Left
        left_label = Gtk.Label(label="  ")
        main_box.append(left_label)
        
        # Center - Waveform
        self.waveform = WaveformVisualizer()
        main_box.append(self.waveform)
        
        # Clock
        self.clock = Gtk.Label()
        main_box.append(self.clock)
        GLib.timeout_add_seconds(1, self.update_clock)
        self.update_clock()
        
        # Right
        right_label = Gtk.Label(label="Volume: 50%")
        main_box.append(right_label)
        
        self.set_child(main_box)
    
    def update_clock(self):
        now = datetime.now()
        self.clock.set_label(now.strftime("%H:%M"))
        return True

class TestApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="test.zenpybar")
    
    def do_activate(self):
        win = TestBar(self)
        win.present()

app = TestApp()
app.run(None)
