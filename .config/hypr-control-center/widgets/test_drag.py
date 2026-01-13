#!/usr/bin/env python3
"""
Test script - Check if layer shell receives mouse events
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell

app = Gtk.Application(application_id='test.drag')

def on_activate(app):
    win = Gtk.Window()
    
    # Layer shell
    Gtk4LayerShell.init_for_window(win)
    Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.BOTTOM)
    Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
    Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
    Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, 100)
    Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.LEFT, 100)
    Gtk4LayerShell.set_exclusive_zone(win, -1)
    
    win.set_title('test-drag-widget')
    win.set_decorated(False)
    win.set_default_size(300, 150)
    
    label = Gtk.Label(label='CLICK AND DRAG ME')
    label.set_margin_top(30)
    label.set_margin_bottom(30)
    label.set_margin_start(30)
    label.set_margin_end(30)
    win.set_child(label)
    
    # Click handler
    def on_click(gesture, n_press, x, y):
        print(f'CLICK at ({x:.0f}, {y:.0f})')
    
    click = Gtk.GestureClick.new()
    click.connect('pressed', on_click)
    win.add_controller(click)
    
    # Drag handler
    def on_drag_begin(gesture, x, y):
        print(f'DRAG BEGIN at ({x:.0f}, {y:.0f})')
    
    def on_drag_update(gesture, offset_x, offset_y):
        print(f'DRAG UPDATE offset ({offset_x:.0f}, {offset_y:.0f})')
    
    def on_drag_end(gesture, offset_x, offset_y):
        print(f'DRAG END')
    
    drag = Gtk.GestureDrag.new()
    drag.connect('drag-begin', on_drag_begin)
    drag.connect('drag-update', on_drag_update)
    drag.connect('drag-end', on_drag_end)
    win.add_controller(drag)
    
    win.set_application(app)
    win.present()
    print('Window ready - try clicking and dragging the window')
    print('Press Ctrl+C to exit')

app.connect('activate', on_activate)
app.run(None)