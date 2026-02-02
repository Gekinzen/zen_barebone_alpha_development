#!/usr/bin/env python3
"""
Hyprland Control Center
A Cosmic-inspired control panel for Hyprland configuration
Location: ~/.config/hypr-control-center/
"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gio
from src.app import ControlCenterApp


def main():
    """Main entry point"""
    app = ControlCenterApp()
    return app.run(None)


if __name__ == "__main__":
    main()