#!/usr/bin/env python3
"""
Custom Module
=============

Handles custom/* modules that use exec scripts.
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Pango

import subprocess
import json
from typing import Dict, Any

from .base import BaseModule


class CustomModule(BaseModule):
    """
    Custom module that runs exec scripts
    
    Config options:
    - exec: Command to run
    - exec-if: Condition command
    - return-type: 'json' or text
    - format: Format string
    - interval: Update interval
    - on-click, on-click-right, on-click-middle: Click handlers
    - escape: Whether to escape markup
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        self.label: Gtk.Label = None
        self.exec_cmd = config.get('exec', '')
        self.return_type = config.get('return-type', 'text')
        self.escape = config.get('escape', True)
        super().__init__(name, config, bar)
        
        # Setup clicks
        self._setup_clicks()
        
        # Initial update
        if self.exec_cmd:
            self._update()
    
    def _build_ui(self):
        """Build custom module UI"""
        # Use module name as CSS class
        css_class = self.module_name.replace('/', '-').replace('custom-', '')
        self.add_css_class(css_class)
        
        self.label = Gtk.Label()
        self.label.set_use_markup(not self.escape)
        self.append(self.label)
    
    def _setup_clicks(self):
        """Setup click handlers"""
        # Left click
        if 'on-click' in self.config:
            click = Gtk.GestureClick.new()
            click.set_button(1)
            click.connect("pressed", self._on_click)
            self.add_controller(click)
        
        # Right click
        if 'on-click-right' in self.config:
            right = Gtk.GestureClick.new()
            right.set_button(3)
            right.connect("pressed", self._on_right_click)
            self.add_controller(right)
        
        # Middle click
        if 'on-click-middle' in self.config:
            middle = Gtk.GestureClick.new()
            middle.set_button(2)
            middle.connect("pressed", self._on_middle_click)
            self.add_controller(middle)
    
    def _update(self) -> bool:
        """Update by running exec command"""
        if not self.exec_cmd:
            return True
        
        try:
            # Check exec-if first
            exec_if = self.config.get('exec-if', '')
            if exec_if:
                result = subprocess.run(
                    exec_if, shell=True,
                    capture_output=True, timeout=2
                )
                if result.returncode != 0:
                    self.label.set_text('')
                    return True
            
            # Run main exec
            result = subprocess.run(
                self.exec_cmd, shell=True,
                capture_output=True, text=True, timeout=5
            )
            
            if result.returncode == 0:
                output = result.stdout.strip()
                
                if self.return_type == 'json':
                    self._handle_json_output(output)
                else:
                    self._handle_text_output(output)
        
        except Exception as e:
            pass
        
        return True
    
    def _handle_json_output(self, output: str):
        """Handle JSON output from exec"""
        try:
            data = json.loads(output)
            
            text = data.get('text', '')
            tooltip = data.get('tooltip', '')
            css_class = data.get('class', '')
            
            # Set text
            fmt = self.get_format()
            if '{}' in fmt:
                text = fmt.replace('{}', text)
            
            if self.escape:
                self.label.set_text(text)
            else:
                self.label.set_markup(text)
            
            # Set tooltip
            if tooltip:
                self.set_tooltip_text(tooltip)
            
            # Set CSS class
            if css_class:
                self.add_css_class(css_class)
        
        except json.JSONDecodeError:
            self.label.set_text(output)
    
    def _handle_text_output(self, output: str):
        """Handle plain text output"""
        fmt = self.get_format()
        if '{}' in fmt:
            output = fmt.replace('{}', output)
        
        self.label.set_text(output)
    
    def _on_click(self, gesture, n, x, y):
        cmd = self.config.get('on-click', '')
        if cmd:
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    def _on_right_click(self, gesture, n, x, y):
        cmd = self.config.get('on-click-right', '')
        if cmd:
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    def _on_middle_click(self, gesture, n, x, y):
        cmd = self.config.get('on-click-middle', '')
        if cmd:
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
