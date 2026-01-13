#!/usr/bin/env python3
"""
ZenPyBar v0.5.0 - Optimized GTK4 Bar
====================================

Based on working FastBar test - instant load, lazy module creation.
"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib

import subprocess
import json
import datetime
from pathlib import Path
from typing import Dict, List, Optional


def get_monitors() -> List[dict]:
    """Get monitors from hyprctl"""
    try:
        result = subprocess.run(['hyprctl', '-j', 'monitors'],
                                capture_output=True, text=True, timeout=1)
        if result.returncode == 0:
            return json.loads(result.stdout)
    except:
        pass
    return []


def get_workspaces() -> tuple:
    """Get active workspace and occupied workspaces"""
    active = 1
    occupied = set()
    try:
        result = subprocess.run(['hyprctl', '-j', 'activeworkspace'],
                                capture_output=True, text=True, timeout=1)
        if result.returncode == 0:
            active = json.loads(result.stdout).get('id', 1)
        
        result = subprocess.run(['hyprctl', '-j', 'workspaces'],
                                capture_output=True, text=True, timeout=1)
        if result.returncode == 0:
            for ws in json.loads(result.stdout):
                if ws.get('windows', 0) > 0:
                    occupied.add(ws.get('id', 0))
    except:
        pass
    return active, occupied


class ZenPyBar(Gtk.Window):
    """Fast, optimized bar window"""
    
    def __init__(self, monitor_name: str = None, monitor_info: dict = None):
        super().__init__()
        
        self.monitor_name = monitor_name
        self.monitor_info = monitor_info or {}
        
        self.set_title(f"zenpybar-{monitor_name}" if monitor_name else "zenpybar")
        self.set_decorated(False)
        
        # Layer shell FIRST - critical for visibility
        self._setup_layer_shell()
        
        # CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # Start updates
        GLib.timeout_add(100, self._update_workspaces)
        GLib.timeout_add(1000, self._update_clock)
    
    def _setup_layer_shell(self):
        """Setup layer shell immediately"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, f"zenpybar-{self.monitor_name}" if self.monitor_name else "zenpybar")
        
        # Set monitor
        if self.monitor_name:
            display = self.get_display()
            monitors = display.get_monitors()
            for i in range(monitors.get_n_items()):
                mon = monitors.get_item(i)
                if mon.get_connector() == self.monitor_name:
                    Gtk4LayerShell.set_monitor(self, mon)
                    break
        
        # Anchors - full width at bottom
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
        
        # Margins
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, 3)
        
        # Exclusive zone
        Gtk4LayerShell.set_exclusive_zone(self, 50)
    
    def _apply_css(self):
        """Apply CSS"""
        css = Gtk.CssProvider()
        css.load_from_string('''
/* ZenPyBar CSS */
window {
    background-color: rgba(26, 27, 38, 0.92);
}

label {
    color: #c0caf5;
    font-family: "JetBrainsMono Nerd Font Propo", sans-serif;
    font-size: 14px;
    font-weight: bold;
}

.zenpy-bar {
    background-color: rgba(26, 27, 38, 0.92);
    min-height: 40px;
}

/* Workspaces */
.workspaces {
    background-color: rgba(26, 27, 38, 0.4);
    padding: 5px 3px;
    margin: 0 0 0 12px;
    border-radius: 26px;
    border: 1px solid #16161e;
}

.workspace-btn {
    min-width: 30px;
    min-height: 30px;
    padding: 0 6px;
    margin: 0 3px;
    border-radius: 16px;
    background-color: #16161e;
    border: none;
}

.workspace-btn label {
    color: transparent;
}

.workspace-btn.active {
    background-color: #7aa2f7;
    min-width: 50px;
}

.workspace-btn.active label {
    color: #1a1b26;
}

.workspace-btn.occupied {
    background-color: #24283b;
}

/* Clock */
.clock {
    background-color: rgba(26, 27, 38, 0.9);
    padding: 0 15px;
    margin: 0 12px;
    border-radius: 45px;
    border: 1px solid #16161e;
}

.clock label {
    color: #7aa2f7;
}

/* Taskbar placeholder */
.taskbar {
    background-color: rgba(26, 27, 38, 0.9);
    padding: 5px 14px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid #16161e;
}

/* Music */
.music {
    background-color: rgba(26, 27, 38, 0.9);
    padding: 0 15px;
    margin: 0 0 0 12px;
    border-radius: 45px;
    border: 1px solid #16161e;
}

.music label {
    color: #bb9af7;
}

/* Notification */
.notification {
    background-color: rgba(26, 27, 38, 0.9);
    padding: 0 15px;
    margin: 0 12px;
    border-radius: 45px;
    border: 1px solid #16161e;
}
        ''')
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 100
        )
    
    def _build_ui(self):
        """Build bar UI - simple and fast"""
        main = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        main.add_css_class("zenpy-bar")
        main.set_hexpand(True)
        
        # LEFT
        left = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        left.set_halign(Gtk.Align.START)
        left.set_hexpand(True)
        
        # Taskbar placeholder
        taskbar = Gtk.Box()
        taskbar.add_css_class("taskbar")
        taskbar.append(Gtk.Label(label="󰣆 Apps"))
        left.append(taskbar)
        
        # Music placeholder
        music = Gtk.Box()
        music.add_css_class("music")
        music.append(Gtk.Label(label="󰎈 Music"))
        left.append(music)
        
        # CENTER
        center = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        center.set_halign(Gtk.Align.CENTER)
        
        # Workspaces
        self.workspaces_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.workspaces_box.add_css_class("workspaces")
        self.workspace_btns = {}
        
        for i in range(1, 6):
            btn = Gtk.Button()
            btn.add_css_class("workspace-btn")
            btn.set_child(Gtk.Label(label=str(i)))
            btn.connect("clicked", self._on_workspace_click, i)
            self.workspace_btns[i] = btn
            self.workspaces_box.append(btn)
        
        center.append(self.workspaces_box)
        
        # RIGHT
        right = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        right.set_halign(Gtk.Align.END)
        right.set_hexpand(True)
        
        # Notification
        notif = Gtk.Box()
        notif.add_css_class("notification")
        notif.append(Gtk.Label(label="󰂜"))
        right.append(notif)
        
        # Clock
        clock_box = Gtk.Box()
        clock_box.add_css_class("clock")
        self.clock_label = Gtk.Label(label=datetime.datetime.now().strftime("%I:%M:%S %p"))
        clock_box.append(self.clock_label)
        right.append(clock_box)
        
        main.append(left)
        main.append(center)
        main.append(right)
        
        self.set_child(main)
    
    def _on_workspace_click(self, btn, ws_id):
        """Switch workspace"""
        subprocess.Popen(['hyprctl', 'dispatch', 'workspace', str(ws_id)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    def _update_workspaces(self) -> bool:
        """Update workspace buttons"""
        active, occupied = get_workspaces()
        
        for ws_id, btn in self.workspace_btns.items():
            btn.remove_css_class("active")
            btn.remove_css_class("occupied")
            
            if ws_id == active:
                btn.add_css_class("active")
            elif ws_id in occupied:
                btn.add_css_class("occupied")
        
        return True
    
    def _update_clock(self) -> bool:
        """Update clock"""
        self.clock_label.set_label(datetime.datetime.now().strftime("%I:%M:%S %p"))
        return True


def main():
    print("[ZenPyBar] Starting v0.5.0...")
    
    app = Gtk.Application(application_id="com.hyprland.zenpybar")
    
    def on_activate(app):
        monitors = get_monitors()
        
        if not monitors:
            bar = ZenPyBar()
            bar.set_application(app)
            bar.present()
        else:
            for mon in monitors:
                name = mon.get('name')
                print(f"[ZenPyBar] Creating bar for: {name}")
                bar = ZenPyBar(monitor_name=name, monitor_info=mon)
                bar.set_application(app)
                bar.present()
        
        print("[ZenPyBar] ✅ Ready!")
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()