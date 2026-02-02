#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/clock_widget.py
"""
Clock Widget - Pure transparent background, text only visible
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import datetime
from base_widget import BaseWidget

class ClockWidget(BaseWidget):
    def __init__(self):
        super().__init__("clock")
        
        # Create container
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        container.add_css_class("clock-widget-container")
        container.set_halign(Gtk.Align.CENTER)
        
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
        
        # Update time every second
        self.update_time()
        GLib.timeout_add_seconds(1, self.update_time)
        
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