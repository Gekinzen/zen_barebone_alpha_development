"""
Main Application
"""

import gi
gi.require_version('Adw', '1')
from gi.repository import Adw, Gio

from .window import ControlCenterWindow

class ControlCenterApp(Adw.Application):
    """Main application"""
    
    def __init__(self):
        super().__init__(
            application_id='com.hyprland.controlcenter',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        
    def do_activate(self):
        win = ControlCenterWindow(self)
        win.present()
