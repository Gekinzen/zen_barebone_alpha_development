"""
Main Application
"""

import gi
gi.require_version('Adw', '1')
from gi.repository import Adw, Gio

from .window import ControlCenterWindow

class ControlCenterApp(Adw.Application):
    """Main application with single instance support"""
    
    def __init__(self):
        super().__init__(
            application_id='com.hyprland.controlcenter',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        
    def do_activate(self):
        """Activate application - creates window or presents existing one"""
        # Check if window already exists
        windows = self.get_windows()
        if windows:
            # Window already exists, just present it
            windows[0].present()
            return
        
        # No window exists, create new one
        win = ControlCenterWindow(self)
        win.present()