#!/usr/bin/env python3
"""
Base Module Class
=================

All bar modules inherit from this.
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib

from typing import Dict, Any, Optional


class BaseModule(Gtk.Box):
    """
    Base class for all bar modules
    
    Subclasses should implement:
    - _build_ui(): Build the module's UI
    - _update(): Update the module (called periodically if interval set)
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL)
        
        self.module_name = name
        self.config = config
        self.bar = bar
        
        # Add CSS class based on module name (matches Waybar selectors)
        # e.g., 'hyprland/workspaces' -> 'workspaces'
        # e.g., 'custom/music' -> 'custom-music'
        self.add_css_class(self._get_css_class())
        
        # Tooltip
        if 'tooltip' in config and config['tooltip']:
            tooltip_format = config.get('tooltip-format', '')
            if tooltip_format:
                self.set_tooltip_text(tooltip_format)
        
        # Build UI
        self._build_ui()
        
        # Setup update interval if specified
        interval = config.get('interval', 0)
        if interval > 0:
            GLib.timeout_add_seconds(interval, self._on_interval)
    
    def _get_css_class(self) -> str:
        """Get CSS class name from module name - matches Waybar"""
        # 'hyprland/workspaces' -> 'workspaces'
        # 'custom/music' -> 'custom-music'
        # 'clock' -> 'clock'
        if self.module_name.startswith('custom/'):
            return 'custom-' + self.module_name.split('/')[-1]
        elif '/' in self.module_name:
            return self.module_name.split('/')[-1]
        return self.module_name
    
    def _build_ui(self):
        """Build module UI - override in subclass"""
        label = Gtk.Label(label=self.module_name)
        self.append(label)
    
    def _update(self):
        """Update module - override in subclass"""
        pass
    
    def _on_interval(self) -> bool:
        """Called on interval timer"""
        self._update()
        return True  # Keep timer running
    
    def get_format(self) -> str:
        """Get format string from config"""
        return self.config.get('format', '{}')
    
    def format_output(self, **kwargs) -> str:
        """Format output using config format string"""
        fmt = self.get_format()
        try:
            return fmt.format(**kwargs)
        except:
            return fmt
