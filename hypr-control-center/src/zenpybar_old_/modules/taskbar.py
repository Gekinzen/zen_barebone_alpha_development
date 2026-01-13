#!/usr/bin/env python3
"""
Taskbar Module
==============

Full taskbar with pinned apps and running windows.
Reuses code from panel_widget.py
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, GdkPixbuf

import sys
import asyncio
import threading
from pathlib import Path
from typing import Dict, Any, Optional

from .base import BaseModule

# Import from our panel code
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'panel'))
from window_tracker import WindowTracker, AppGroup
from pinned_manager import PinnedManager, get_pinned_manager
from icon_resolver import get_resolver


class TaskbarItem(Gtk.Button):
    """Taskbar item button"""
    
    def __init__(self, module, app_id: str, pinned_app=None, app_group=None):
        super().__init__()
        
        self.module = module
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        self.add_css_class("taskbar-item")
        
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self._build_ui()
        self._update_state()
        self._setup_clicks()
    
    def _build_ui(self):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        box.set_valign(Gtk.Align.CENTER)
        
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        self.icon = resolver.create_icon_image(wm_class, size=24, use_nerd_fallback=True)
        box.append(self.icon)
        
        self.set_child(box)
        self._update_tooltip()
    
    def _get_wm_class(self) -> str:
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _update_state(self):
        self.remove_css_class("active")
        self.remove_css_class("running")
        self.remove_css_class("pinned")
        
        if self.is_focused:
            self.add_css_class("active")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("pinned")
    
    def _update_tooltip(self):
        name = ""
        if self.pinned_app:
            name = self.pinned_app.name
        elif self.app_group:
            name = self.app_group.wm_class
        
        if self.app_group and self.app_group.window_count > 1:
            name += f" ({self.app_group.window_count})"
        
        self.set_tooltip_text(name)
    
    def _setup_clicks(self):
        self.connect("clicked", self._on_click)
        
        # Middle click
        middle = Gtk.GestureClick.new()
        middle.set_button(2)
        middle.connect("pressed", self._on_middle_click)
        self.add_controller(middle)
        
        # Right click
        right = Gtk.GestureClick.new()
        right.set_button(3)
        right.connect("pressed", self._on_right_click)
        self.add_controller(right)
    
    def _on_click(self, btn):
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.module.focus_window(window.address)
            else:
                self._show_window_list()
        elif self.is_pinned:
            self.module.launch_app(self.app_id)
    
    def _on_middle_click(self, gesture, n, x, y):
        if self.is_running and self.app_group:
            self.module.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n, x, y):
        self._show_context_menu()
    
    def _show_window_list(self):
        if not self.app_group:
            return
        
        popover = Gtk.Popover()
        popover.set_parent(self)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        for window in self.app_group.windows.values():
            row = Gtk.Button()
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            title = Gtk.Label(label=window.title[:40] if window.title else "Window")
            title.set_xalign(0)
            title.set_hexpand(True)
            row_box.append(title)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, addr=window.address: self._focus_window(addr, popover))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _show_context_menu(self):
        popover = Gtk.Popover()
        popover.set_parent(self)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        box.set_margin_start(4)
        box.set_margin_end(4)
        
        if self.is_pinned:
            btn = Gtk.Button(label="Unpin")
            btn.connect("clicked", lambda b: self._unpin(popover))
            box.append(btn)
        else:
            btn = Gtk.Button(label="Pin")
            btn.connect("clicked", lambda b: self._pin(popover))
            box.append(btn)
        
        if self.is_running:
            btn = Gtk.Button(label="Close")
            btn.connect("clicked", lambda b: self._close_all(popover))
            box.append(btn)
        
        btn = Gtk.Button(label="New Window")
        btn.connect("clicked", lambda b: self._launch(popover))
        box.append(btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _focus_window(self, addr, popover):
        popover.popdown()
        self.module.focus_window(addr)
    
    def _pin(self, popover):
        popover.popdown()
        self.module.pin_app(self._get_wm_class())
    
    def _unpin(self, popover):
        popover.popdown()
        self.module.unpin_app(self.app_id)
    
    def _close_all(self, popover):
        popover.popdown()
        if self.app_group:
            self.module.close_app(self.app_group.wm_class)
    
    def _launch(self, popover):
        popover.popdown()
        self.module.launch_app(self._get_wm_class())
    
    def update(self, app_group=None):
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


class TaskbarModule(BaseModule):
    """
    Full taskbar module with pinned apps and running windows
    """
    
    def __init__(self, name: str, config: Dict[str, Any], bar):
        self.items: Dict[str, TaskbarItem] = {}
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop = None
        self._tracker_thread = None
        
        self.config_dir = Path.home() / ".config/hypr-control-center"
        
        super().__init__(name, config, bar)
        
        self._init_components()
    
    def _build_ui(self):
        """Build taskbar UI"""
        self.add_css_class("taskbar")
        self.set_spacing(2)
        
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.append(self.pinned_box)
        
        self.separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self.separator.set_margin_start(4)
        self.separator.set_margin_end(4)
        self.append(self.separator)
        
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.append(self.running_box)
    
    def _init_components(self):
        """Initialize tracker and pinned manager"""
        self.pinned_manager = get_pinned_manager(self.config_dir)
        self.pinned_manager.on_change(self._on_change)
        
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_change)
        
        GLib.idle_add(self._rebuild)
        
        def run_tracker():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except:
                pass
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
    
    def _on_change(self):
        GLib.idle_add(self._update_items)
    
    def _rebuild(self):
        """Full rebuild"""
        self.items.clear()
        
        while (child := self.pinned_box.get_first_child()):
            self.pinned_box.remove(child)
        while (child := self.running_box.get_first_child()):
            self.running_box.remove(child)
        
        pinned = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        for p in pinned:
            group = running.get(p.wm_class.lower() if p.wm_class else p.app_id.lower())
            item = TaskbarItem(self, p.app_id, pinned_app=p, app_group=group)
            self.items[p.app_id] = item
            self.pinned_box.append(item)
        
        pinned_ids = {p.app_id.lower() for p in pinned}
        pinned_ids.update(p.wm_class.lower() for p in pinned if p.wm_class)
        
        for wm_class, group in running.items():
            if wm_class not in pinned_ids:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.items[wm_class] = item
                self.running_box.append(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    def _update_items(self):
        """Update existing items"""
        if not self.tracker:
            return False
        
        running = {g.wm_class.lower(): g for g in self.tracker.get_app_groups()}
        
        for app_id, item in self.items.items():
            group = running.get(app_id.lower())
            item.update(group)
        
        return False
    
    # Actions
    def focus_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.focus_window(address),
                self._async_loop
            )
    
    def close_window(self, address: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_window(address),
                self._async_loop
            )
    
    def close_app(self, wm_class: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(
                self.tracker.close_app(wm_class),
                self._async_loop
            )
    
    def launch_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.launch_app(app_id)
    
    def pin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)
