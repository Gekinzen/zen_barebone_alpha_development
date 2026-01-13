#!/usr/bin/env python3
"""
Hyprland Panel Widget v3 - Smart Floating Taskbar
==================================================

Floating GTK4 panel that:
- Positions based on custom/panel location in Waybar config
- Auto-resizes based on number of taskbar items
- Updates Waybar spacer width via IPC
- Visually integrates with Waybar (same style, no borders)

Run: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 panel_widget.py
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf

import json
import subprocess
import asyncio
import threading
import os
from pathlib import Path
from typing import Optional, Dict, List
import sys

# Check GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False
    print("[Panel] ⚠️ GTK4 Layer Shell not found!")

# Add panel directory to path
_panel_dir = Path(__file__).parent
if str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

# Import local modules
try:
    from hypr_ipc import hyprctl_json
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon
    HAS_MODULES = True
except ImportError as e:
    print(f"[Panel] ⚠️ Import error: {e}")
    HAS_MODULES = False


# ═══════════════════════════════════════════════════════════════════════════════
# WAYBAR CONFIG READER (Inline simplified version)
# ═══════════════════════════════════════════════════════════════════════════════

class WaybarConfig:
    """Read Waybar config and determine panel position"""
    
    def __init__(self):
        self.config_path = Path.home() / ".config/waybar"
        self.config = self._load_config()
        self.theme = self._load_theme()
        
    def _load_config(self) -> dict:
        """Load Waybar config.jsonc"""
        import re
        
        for name in ["config.jsonc", "config.json"]:
            path = self.config_path / name
            if path.exists():
                try:
                    content = path.read_text()
                    # Remove comments
                    content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
                    content = re.sub(r'/\*[\s\S]*?\*/', '', content)
                    content = re.sub(r',(\s*[}\]])', r'\1', content)
                    data = json.loads(content)
                    if isinstance(data, list):
                        data = data[0]
                    return data
                except Exception as e:
                    print(f"[WaybarConfig] Error: {e}")
        return {}
    
    def _load_theme(self) -> dict:
        """Load theme colors from style.css"""
        import re
        
        theme = {
            'bg': '#1a1b26',
            'fg': '#c0caf5',
            'blue': '#7aa2f7',
            'red': '#f7768e',
            'border_radius': 12,
        }
        
        style_path = self.config_path / "style.css"
        if not style_path.exists():
            return theme
            
        try:
            content = style_path.read_text()
            
            # Check @import
            import_match = re.search(r'@import\s+["\']([^"\']+)["\']', content)
            if import_match:
                import_path = import_match.group(1)
                if import_path.startswith('../'):
                    full_path = (self.config_path / import_path).resolve()
                    if full_path.exists():
                        content = full_path.read_text() + "\n" + content
            
            # Parse colors
            color_map = {
                'bg0': 'bg', 'bg': 'bg', 'background': 'bg',
                'fg': 'fg', 'foreground': 'fg',
                'blue': 'blue', 'accent': 'blue',
                'red': 'red',
            }
            
            for match in re.finditer(r'@define-color\s+(\w+)\s+([^;]+);', content):
                var = match.group(1).strip()
                val = match.group(2).strip()
                if var in color_map:
                    theme[color_map[var]] = val
                    
        except Exception as e:
            print(f"[WaybarConfig] Theme error: {e}")
            
        return theme
    
    def get_position(self) -> str:
        """Get Waybar position (top/bottom)"""
        return self.config.get('position', 'bottom')
    
    def get_height(self) -> int:
        """Get Waybar height"""
        return self.config.get('height', 40)
    
    def get_margins(self) -> dict:
        """Get Waybar margins"""
        return {
            'top': self.config.get('margin-top', 0),
            'bottom': self.config.get('margin-bottom', 0),
            'left': self.config.get('margin-left', 0),
            'right': self.config.get('margin-right', 0),
        }
    
    def find_panel_location(self, module_name: str = "custom/panel") -> tuple:
        """
        Find where the panel module is in the config.
        Returns: (location, index, modules_before, modules_after)
        """
        modules_left = self.config.get('modules-left', [])
        modules_center = self.config.get('modules-center', [])
        modules_right = self.config.get('modules-right', [])
        
        # Check each section
        if module_name in modules_left:
            idx = modules_left.index(module_name)
            return ('left', idx, modules_left[:idx], modules_left[idx+1:])
        
        if module_name in modules_center:
            idx = modules_center.index(module_name)
            return ('center', idx, modules_center[:idx], modules_center[idx+1:])
        
        if module_name in modules_right:
            idx = modules_right.index(module_name)
            return ('right', idx, modules_right[:idx], modules_right[idx+1:])
        
        return ('left', 0, [], [])  # Default


# ═══════════════════════════════════════════════════════════════════════════════
# TASKBAR ITEM
# ═══════════════════════════════════════════════════════════════════════════════

class TaskbarItem(Gtk.Button):
    """Single taskbar icon button"""
    
    ICON_SIZE = 24
    
    def __init__(self, panel: 'SmartPanel', app_id: str,
                 pinned_app: Optional[PinnedApp] = None,
                 app_group: Optional[AppGroup] = None):
        super().__init__()
        
        self.panel = panel
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self.add_css_class("taskbar-item")
        self._build_ui()
        self._update_state()
        self._setup_events()
    
    @property
    def wm_class(self) -> str:
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _build_ui(self):
        """Create icon"""
        resolver = get_resolver()
        self.icon = resolver.create_icon_image(self.wm_class, size=self.ICON_SIZE, use_nerd_fallback=True)
        self.icon.add_css_class("taskbar-icon")
        self.set_child(self.icon)
        self._update_tooltip()
    
    def _update_state(self):
        """Update visual state"""
        for cls in ["focused", "running", "pinned-only"]:
            self.remove_css_class(cls)
        
        if self.is_focused:
            self.add_css_class("focused")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("pinned-only")
    
    def _update_tooltip(self):
        name = self.pinned_app.name if self.pinned_app and self.pinned_app.name else self.wm_class
        count = self.app_group.window_count if self.app_group else 0
        
        tooltip = name
        if count > 1:
            tooltip += f" ({count} windows)"
        self.set_tooltip_text(tooltip)
    
    def _setup_events(self):
        # Left click
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
        """Left click - focus or launch"""
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                win = self.app_group.most_recent_window
                if win:
                    self.panel.focus_window(win.address)
            else:
                self._show_window_list()
        else:
            self.panel.launch_app(self.wm_class)
    
    def _on_middle_click(self, gesture, n, x, y):
        """Middle click - close all"""
        if self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n, x, y):
        """Right click - context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show window picker"""
        if not self.app_group:
            return
        
        pop = Gtk.Popover()
        pop.set_parent(self)
        pop.add_css_class("panel-popover")
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(6)
        box.set_margin_end(6)
        
        for win in self.app_group.windows.values():
            row = Gtk.Button()
            row.add_css_class("window-row")
            
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            # Focus indicator
            if win.is_focused:
                dot = Gtk.Label(label="●")
                dot.add_css_class("focus-dot")
                hbox.append(dot)
            
            # Title
            title = Gtk.Label(label=win.title[:35] if win.title else "Window")
            title.set_xalign(0)
            title.set_hexpand(True)
            title.set_ellipsize(3)
            hbox.append(title)
            
            # Close btn
            close = Gtk.Button(label="✕")
            close.add_css_class("flat")
            close.add_css_class("close-btn")
            close.connect("clicked", lambda b, a=win.address: self.panel.close_window(a))
            hbox.append(close)
            
            row.set_child(hbox)
            row.connect("clicked", lambda b, a=win.address: (pop.popdown(), self.panel.focus_window(a)))
            box.append(row)
        
        pop.set_child(box)
        pop.popup()
    
    def _show_context_menu(self):
        """Show context menu"""
        pop = Gtk.Popover()
        pop.set_parent(self)
        pop.add_css_class("panel-popover")
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(6)
        box.set_margin_end(6)
        
        # Pin/Unpin
        if self.is_pinned:
            btn = Gtk.Button(label="📍 Unpin")
            btn.connect("clicked", lambda b: (pop.popdown(), self.panel.unpin_app(self.app_id)))
        else:
            btn = Gtk.Button(label="📌 Pin")
            btn.connect("clicked", lambda b: (pop.popdown(), self.panel.pin_app(self.wm_class)))
        btn.add_css_class("flat")
        box.append(btn)
        
        # New window
        new_btn = Gtk.Button(label="🆕 New window")
        new_btn.add_css_class("flat")
        new_btn.connect("clicked", lambda b: (pop.popdown(), self.panel.launch_app(self.wm_class)))
        box.append(new_btn)
        
        # Close all
        if self.is_running and self.app_group:
            close_btn = Gtk.Button(label=f"❌ Close all ({self.app_group.window_count})")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: (pop.popdown(), self.panel.close_app(self.app_group.wm_class)))
            box.append(close_btn)
        
        pop.set_child(box)
        pop.popup()
    
    def update(self, app_group: Optional[AppGroup]):
        """Update state"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


# ═══════════════════════════════════════════════════════════════════════════════
# SMART PANEL
# ═══════════════════════════════════════════════════════════════════════════════

class SmartPanel(Gtk.Window):
    """
    Smart floating panel that:
    - Reads position from Waybar config
    - Auto-resizes based on items
    - Positions correctly (left/center/right)
    """
    
    ITEM_WIDTH = 40  # Width per taskbar item
    PADDING = 16     # Container padding
    
    def __init__(self, module_name: str = "custom/panel"):
        super().__init__()
        
        self.module_name = module_name
        self.set_title("hypr-panel")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Config
        self.config_dir = Path.home() / ".config/hypr-control-center"
        self.waybar = WaybarConfig()
        
        # Get position info
        self.location, self.idx, self.mods_before, self.mods_after = \
            self.waybar.find_panel_location(module_name)
        
        print(f"[Panel] 📍 Location: {self.location}")
        print(f"[Panel] 📋 Before: {self.mods_before}")
        print(f"[Panel] 📋 After: {self.mods_after}")
        
        # Items
        self.items: Dict[str, TaskbarItem] = {}
        
        # Tracker
        self.tracker: Optional[WindowTracker] = None
        self.pinned_mgr: Optional[PinnedManager] = None
        self._async_loop = None
        self._tracker_thread = None
        
        # Setup
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        self._apply_css()
        self._build_ui()
        self._init_tracker()
    
    def _setup_layer_shell(self):
        """Configure layer shell"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "hypr-panel")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        Gtk4LayerShell.set_exclusive_zone(self, 0)
        
        margins = self.waybar.get_margins()
        position = self.waybar.get_position()
        
        # Vertical anchor
        if position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, margins['bottom'] + 4)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, margins['top'] + 4)
        
        # Horizontal anchor based on location
        self._update_horizontal_position()
    
    def _update_horizontal_position(self):
        """Update horizontal position - called when items change"""
        if not HAS_LAYER_SHELL:
            return
        
        margins = self.waybar.get_margins()
        
        # Calculate offset based on modules before
        offset = self._calc_modules_width(self.mods_before)
        
        if self.location == "left":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, margins['left'] + offset + 8)
            
        elif self.location == "center":
            # For center, we need to calculate from both sides
            # Panel will auto-center between the margins
            left_offset = self._calc_modules_width(self.waybar.config.get('modules-left', [])) + margins['left']
            right_offset = self._calc_modules_width(self.waybar.config.get('modules-right', [])) + margins['right']
            
            # Add offset for modules before panel in center section
            center_before_width = self._calc_modules_width(self.mods_before)
            center_after_width = self._calc_modules_width(self.mods_after)
            
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, left_offset + center_before_width + 8)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, right_offset + center_after_width + 8)
            
        else:  # right
            offset_after = self._calc_modules_width(self.mods_after)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, margins['right'] + offset_after + 8)
    
    def _calc_modules_width(self, modules: List[str]) -> int:
        """Estimate width of modules"""
        widths = {
            'clock': 120,
            'custom/clock': 120,
            'hyprland/workspaces': 180,
            'custom/music': 180,
            'custom/notification': 35,
            'tray': 80,
            'pulseaudio': 35,
            'network': 35,
            'battery': 50,
            'cpu': 50,
            'memory': 50,
        }
        
        total = 0
        for mod in modules:
            total += widths.get(mod, 60)
        return total
    
    def _apply_css(self):
        """Apply CSS"""
        t = self.waybar.theme
        
        css = f'''
        window {{
            background: transparent;
        }}
        
        .panel-box {{
            background: {t['bg']};
            border-radius: 10px;
            padding: 4px 8px;
            border: 1px solid alpha({t['fg']}, 0.1);
        }}
        
        .taskbar-item {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 4px;
            margin: 2px;
            min-width: 36px;
            min-height: 36px;
        }}
        
        .taskbar-item:hover {{
            background: alpha({t['fg']}, 0.1);
        }}
        
        .taskbar-item.focused {{
            background: {t['blue']};
        }}
        
        .taskbar-item.running {{
            border-bottom: 2px solid {t['blue']};
        }}
        
        .taskbar-item.pinned-only {{
            opacity: 0.5;
        }}
        
        .taskbar-item.pinned-only:hover {{
            opacity: 1;
        }}
        
        .taskbar-icon {{
            color: {t['fg']};
            font-size: 18px;
        }}
        
        .taskbar-item.focused .taskbar-icon {{
            color: {t['bg']};
        }}
        
        .separator {{
            background: alpha({t['fg']}, 0.15);
            min-width: 1px;
            margin: 6px 4px;
        }}
        
        .panel-popover {{
            background: {t['bg']};
            border: 1px solid alpha({t['fg']}, 0.2);
            border-radius: 12px;
        }}
        
        .panel-popover > contents {{
            background: transparent;
        }}
        
        .window-row {{
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 8px 12px;
        }}
        
        .window-row:hover {{
            background: alpha({t['fg']}, 0.1);
        }}
        
        .focus-dot {{
            color: {t['blue']};
        }}
        
        .close-btn {{
            opacity: 0.5;
            min-width: 20px;
        }}
        
        .close-btn:hover {{
            opacity: 1;
            color: {t['red']};
        }}
        
        tooltip {{
            background: {t['bg']};
            border-radius: 8px;
        }}
        
        tooltip label {{
            color: {t['fg']};
            padding: 4px 8px;
        }}
        '''
        
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _build_ui(self):
        """Build UI"""
        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.box.add_css_class("panel-box")
        self.box.set_halign(Gtk.Align.CENTER)
        
        # Pinned section
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.box.append(self.pinned_box)
        
        # Separator
        self.sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self.sep.add_css_class("separator")
        self.box.append(self.sep)
        
        # Running section
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.box.append(self.running_box)
        
        self.set_child(self.box)
    
    def _init_tracker(self):
        """Initialize window tracker"""
        if not HAS_MODULES:
            return
        
        self.pinned_mgr = get_pinned_manager(self.config_dir)
        self.pinned_mgr.on_change(self._on_pinned_change)
        
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_tracker_change)
        
        GLib.idle_add(self._rebuild)
        
        def run():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except Exception as e:
                print(f"[Panel] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run, daemon=True)
        self._tracker_thread.start()
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild)
    
    def _rebuild(self):
        """Rebuild taskbar"""
        self.items.clear()
        
        # Clear
        while (c := self.pinned_box.get_first_child()):
            self.pinned_box.remove(c)
        while (c := self.running_box.get_first_child()):
            self.running_box.remove(c)
        
        pinned = self.pinned_mgr.get_pinned_apps() if self.pinned_mgr else []
        groups = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        # Pinned
        for p in pinned:
            grp = groups.get(p.wm_class.lower()) if p.wm_class else groups.get(p.app_id.lower())
            item = TaskbarItem(self, p.app_id, pinned_app=p, app_group=grp)
            self.items[p.app_id] = item
            self.pinned_box.append(item)
        
        # Running (not pinned)
        pinned_ids = set()
        for p in pinned:
            pinned_ids.add(p.app_id.lower())
            if p.wm_class:
                pinned_ids.add(p.wm_class.lower())
        
        for wc, grp in groups.items():
            if wc not in pinned_ids and grp.wm_class.lower() not in pinned_ids:
                item = TaskbarItem(self, wc, app_group=grp)
                self.items[wc] = item
                self.running_box.append(item)
        
        # Separator visibility
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.sep.set_visible(has_pinned and has_running)
        
        # Update position after rebuild
        self._update_horizontal_position()
        
        return False
    
    def _update(self):
        """Update existing items"""
        if not self.tracker:
            return False
        
        groups = {g.wm_class.lower(): g for g in self.tracker.get_app_groups()}
        pinned_ids = set()
        
        if self.pinned_mgr:
            for p in self.pinned_mgr.get_pinned_apps():
                pinned_ids.add(p.app_id.lower())
                if p.wm_class:
                    pinned_ids.add(p.wm_class.lower())
        
        # Update existing
        for aid, item in list(self.items.items()):
            grp = groups.get(aid.lower()) or groups.get(item.wm_class.lower())
            item.update(grp)
        
        # Add new
        for wc in groups:
            if wc not in self.items and wc not in pinned_ids:
                grp = groups[wc]
                if grp.wm_class.lower() not in pinned_ids:
                    item = TaskbarItem(self, wc, app_group=grp)
                    self.items[wc] = item
                    self.running_box.append(item)
        
        # Remove closed
        for aid in list(self.items.keys()):
            if aid.lower() not in pinned_ids and aid.lower() not in groups:
                item = self.items.pop(aid)
                self.running_box.remove(item)
        
        # Separator
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.sep.set_visible(has_pinned and has_running)
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════
    # ACTIONS
    # ═══════════════════════════════════════════════════════════════════════
    
    def focus_window(self, addr: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(self.tracker.focus_window(addr), self._async_loop)
    
    def close_window(self, addr: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(self.tracker.close_window(addr), self._async_loop)
    
    def close_app(self, wm_class: str):
        if self._async_loop and self.tracker:
            asyncio.run_coroutine_threadsafe(self.tracker.close_app(wm_class), self._async_loop)
    
    def launch_app(self, app_id: str):
        if self.pinned_mgr:
            self.pinned_mgr.launch_app(app_id)
    
    def pin_app(self, app_id: str):
        if self.pinned_mgr:
            self.pinned_mgr.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        if self.pinned_mgr:
            self.pinned_mgr.unpin_app(app_id)
    
    def cleanup(self):
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("""
╔════════════════════════════════════════════════════════════════╗
║     HYPRLAND SMART PANEL - Floating Waybar Taskbar             ║
║     Auto-positions based on config.jsonc location              ║
╚════════════════════════════════════════════════════════════════╝
""")
    
    # Find module name
    waybar = WaybarConfig()
    module = "custom/panel"
    
    for name in ["custom/panel", "custom/taskbar"]:
        loc, _, _, _ = waybar.find_panel_location(name)
        all_mods = (waybar.config.get('modules-left', []) + 
                    waybar.config.get('modules-center', []) + 
                    waybar.config.get('modules-right', []))
        if name in all_mods:
            module = name
            break
    
    print(f"[Panel] Using module: {module}")
    
    panel = SmartPanel(module)
    panel.present()
    
    print("[Panel] ✅ Panel running!")
    
    loop = GLib.MainLoop()
    panel.connect("destroy", lambda w: (panel.cleanup(), loop.quit()))
    
    try:
        loop.run()
    except KeyboardInterrupt:
        panel.cleanup()


if __name__ == "__main__":
    main()