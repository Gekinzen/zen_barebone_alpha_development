#!/usr/bin/env python3
"""
Workspaces Module
=================

Hyprland workspaces display and control.
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib

import subprocess
import json
from typing import Dict, Any, List

from .base import BaseModule


class WorkspacesModule(BaseModule):
    """
    Hyprland workspaces module
    
    Config options:
    - format: Format for workspace button
    - persistent-workspaces: Dict of persistent workspaces
    - disable-scroll: Disable scroll to change workspace
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        self.buttons: Dict[int, Gtk.Button] = {}
        self.active_workspace = 1
        super().__init__(name, config, bar)
        
        # Start monitoring
        GLib.timeout_add(100, self._update)
    
    def _build_ui(self):
        """Build workspaces UI"""
        # CSS class already added by BaseModule as 'workspaces'
        self.set_spacing(2)
        
        # Get persistent workspaces config
        persistent = self.config.get('persistent-workspaces', {'*': 5})
        num_workspaces = persistent.get('*', 5)
        
        # Create workspace buttons
        for i in range(1, num_workspaces + 1):
            btn = Gtk.Button()
            btn.add_css_class("workspace-button")
            btn.set_size_request(30, 30)
            
            # Label
            label = Gtk.Label(label=str(i))
            btn.set_child(label)
            
            # Click handler
            btn.connect("clicked", self._on_workspace_click, i)
            
            self.buttons[i] = btn
            self.append(btn)
        
        # Initial update
        self._update()
    
    def _update(self) -> bool:
        """Update workspace states"""
        try:
            # Get active workspace
            result = subprocess.run(
                ['hyprctl', '-j', 'activeworkspace'],
                capture_output=True, text=True, timeout=1
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)
                self.active_workspace = data.get('id', 1)
            
            # Get all workspaces with windows
            result = subprocess.run(
                ['hyprctl', '-j', 'workspaces'],
                capture_output=True, text=True, timeout=1
            )
            occupied = set()
            if result.returncode == 0:
                workspaces = json.loads(result.stdout)
                for ws in workspaces:
                    if ws.get('windows', 0) > 0:
                        occupied.add(ws.get('id', 0))
            
            # Update button states
            for ws_id, btn in self.buttons.items():
                btn.remove_css_class("active")
                btn.remove_css_class("occupied")
                
                if ws_id == self.active_workspace:
                    btn.add_css_class("active")
                elif ws_id in occupied:
                    btn.add_css_class("occupied")
        
        except Exception as e:
            pass
        
        return True  # Keep timer running
    
    def _on_workspace_click(self, button, workspace_id: int):
        """Handle workspace button click"""
        subprocess.Popen(
            ['hyprctl', 'dispatch', 'workspace', str(workspace_id)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )