#!/usr/bin/env python3
"""
Music Module
============

Shows currently playing music with playerctl.
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib

import subprocess
from typing import Dict, Any

from .base import BaseModule


class MusicModule(BaseModule):
    """
    Music/media player module
    
    Uses playerctl to get current track info.
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        self.label: Gtk.Label = None
        self.max_length = config.get('max-length', 40)
        super().__init__(name, config, bar)
        
        # Setup clicks
        self._setup_clicks()
        
        # Update every 2 seconds
        GLib.timeout_add_seconds(2, self._update)
    
    def _build_ui(self):
        """Build music module UI"""
        self.add_css_class("music")
        
        # Icon
        icon = Gtk.Label(label="󰎆 ")  # Nerd font music icon
        icon.add_css_class("music-icon")
        self.append(icon)
        
        # Track info
        self.label = Gtk.Label(label="")
        self.label.set_max_width_chars(self.max_length)
        self.label.set_ellipsize(3)  # END
        self.append(self.label)
        
        self._update()
    
    def _setup_clicks(self):
        """Setup click handlers"""
        # Left click - play/pause
        click = Gtk.GestureClick.new()
        click.set_button(1)
        click.connect("pressed", lambda g, n, x, y: self._playerctl("play-pause"))
        self.add_controller(click)
        
        # Right click - next
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", lambda g, n, x, y: self._playerctl("next"))
        self.add_controller(right)
        
        # Middle click - previous
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", lambda g, n, x, y: self._playerctl("previous"))
        self.add_controller(middle)
    
    def _update(self) -> bool:
        """Update music display"""
        try:
            # Get player status
            result = subprocess.run(
                ['playerctl', 'status'],
                capture_output=True, text=True, timeout=2
            )
            
            if result.returncode != 0 or 'No players' in result.stderr:
                self.label.set_text("No music")
                return True
            
            status = result.stdout.strip()
            
            # Get track info
            result = subprocess.run(
                ['playerctl', 'metadata', '--format', '{{artist}} - {{title}}'],
                capture_output=True, text=True, timeout=2
            )
            
            if result.returncode == 0:
                track = result.stdout.strip()
                
                # Add status icon
                if status == "Playing":
                    icon = "▶ "
                elif status == "Paused":
                    icon = "⏸ "
                else:
                    icon = ""
                
                # Truncate if needed
                if len(track) > self.max_length:
                    track = track[:self.max_length - 3] + "..."
                
                self.label.set_text(f"{icon}{track}")
            else:
                self.label.set_text("No track")
        
        except Exception as e:
            self.label.set_text("No music")
        
        return True
    
    def _playerctl(self, command: str):
        """Run playerctl command"""
        subprocess.Popen(
            ['playerctl', command],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
