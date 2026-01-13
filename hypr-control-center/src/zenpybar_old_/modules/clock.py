#!/usr/bin/env python3
"""
Clock Module
============

Shows date and time.
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib

import datetime
from typing import Dict, Any

from .base import BaseModule


class ClockModule(BaseModule):
    """
    Clock module
    
    Config options:
    - format: strftime format string
    - interval: Update interval in seconds
    - tooltip-format: Tooltip format
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        self.label: Gtk.Label = None
        # Parse format - Waybar uses {:%H:%M} style
        self.time_format = self._parse_format(config.get('format', '{:%H:%M}'))
        super().__init__(name, config, bar)
        
        # Update every second
        GLib.timeout_add_seconds(1, self._update)
    
    def _parse_format(self, fmt: str) -> str:
        """Convert Waybar format to strftime"""
        # Waybar uses {:%Y-%m-%d %H:%M:%S}
        # Extract the strftime part
        if '{:' in fmt and '}' in fmt:
            start = fmt.index('{:') + 2
            end = fmt.index('}', start)
            return fmt[start:end]
        return '%H:%M'
    
    def _build_ui(self):
        """Build clock UI"""
        self.add_css_class("clock")
        
        self.label = Gtk.Label()
        self.label.add_css_class("clock-label")
        self.append(self.label)
        
        self._update()
    
    def _update(self) -> bool:
        """Update clock display"""
        now = datetime.datetime.now()
        try:
            time_str = now.strftime(self.time_format)
            self.label.set_text(time_str)
        except:
            self.label.set_text(now.strftime('%H:%M'))
        
        return True
