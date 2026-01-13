#!/usr/bin/env python3
"""
Window Module
=============

Shows active window title.
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Pango

import subprocess
import json
import re
from typing import Dict, Any

from .base import BaseModule


class WindowModule(BaseModule):
    """
    Active window title module
    
    Config options:
    - format: Format string with {title}
    - max-length: Max title length
    - rewrite: Dict of regex rewrites
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        self.label: Gtk.Label = None
        self.max_length = config.get('max-length', 50)
        self.rewrites = config.get('rewrite', {})
        super().__init__(name, config, bar)
        
        # Start monitoring
        GLib.timeout_add(200, self._update)
    
    def _build_ui(self):
        """Build window title UI"""
        self.add_css_class("window")
        
        self.label = Gtk.Label(label="")
        self.label.set_ellipsize(Pango.EllipsizeMode.END)
        self.label.set_max_width_chars(self.max_length)
        self.label.set_xalign(0)
        self.append(self.label)
        
        self._update()
    
    def _update(self) -> bool:
        """Update window title"""
        try:
            result = subprocess.run(
                ['hyprctl', '-j', 'activewindow'],
                capture_output=True, text=True, timeout=1
            )
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                title = data.get('title', '')
                
                if title:
                    # Apply rewrites
                    title = self._apply_rewrites(title)
                    
                    # Truncate
                    if len(title) > self.max_length:
                        title = title[:self.max_length - 3] + "..."
                    
                    self.label.set_text(title)
                else:
                    self.label.set_text("")
        
        except Exception as e:
            pass
        
        return True
    
    def _apply_rewrites(self, title: str) -> str:
        """Apply rewrite rules from config"""
        for pattern, replacement in self.rewrites.items():
            try:
                match = re.match(pattern, title)
                if match:
                    # Replace $1, $2 etc with groups
                    result = replacement
                    for i, group in enumerate(match.groups(), 1):
                        result = result.replace(f'${i}', group or '')
                    return result
            except:
                pass
        
        return title
