#!/usr/bin/env python3
"""
Hyprland Start Menu - Auto-Positioned Edition
==============================================
Windows 11-style launcher with smart position detection

Features:
- ✅ AUTO-DETECTS position from Waybar config (same as panel widget)
- ✅ Positions itself exactly over custom/start-menu button
- ✅ Smart margin calculation based on module index
- ✅ Supports top/bottom Waybar placement
- ✅ Works with left/center/right module positions
- ✅ Auto-close on mouse leave
- ✅ Pinned apps + search + all apps
- ✅ Power controls

Location: ~/.config/hypr-control-center/start-menu.py
Run: LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 start-menu.py
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GLib, Gio, GdkPixbuf, Gdk
import json
import subprocess
import os
import sys
import re
from pathlib import Path

# Check for GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
    print("[StartMenu] ✅ GTK4 Layer Shell available")
except:
    HAS_LAYER_SHELL = False
    print("[StartMenu] ⚠️ GTK4 Layer Shell not found")


class StartMenu(Gtk.ApplicationWindow):
    def __init__(self, app):
        print("[StartMenu] Initializing...")
        super().__init__(application=app, title="Start Menu")
        
        # Paths
        self.config_dir = Path.home() / ".config/hypr-control-center"
        self.assets_dir = self.config_dir / "assets"
        self.pinned_file = self.config_dir / "preferences/start-menu-pinned.json"
        
        # Ensure directories exist
        self.pinned_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Load data
        self.pinned_apps = self.load_pinned_apps()
        self.all_apps = self.load_all_apps()
        print(f"[StartMenu] Loaded {len(self.all_apps)} apps, {len(self.pinned_apps)} pinned")
        
        # Window setup
        self.set_default_size(720, 580)
        self.set_resizable(False)
        self.set_decorated(False)
        
        # Smart close tracking
        self._mouse_inside = False
        self._mouse_entered = False
        self._close_timer_id = None
        self._active_popover = None
        
        # Get position from Waybar config (AUTO-COMPUTED!)
        self.waybar_position = self._get_waybar_position()
        
        # Setup Layer Shell with computed position
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Load CSS
        self.load_css()
        
        # Build UI
        self.build_ui()
        
        # Setup mouse tracking for auto-close
        self._setup_mouse_tracking()
        
        # ESC to close
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self._on_key_pressed)
        self.add_controller(key_controller)
        
        print("[StartMenu] ✅ Ready!")
    
    def _get_waybar_position(self) -> dict:
        """
        AUTO-DETECT where custom/start-menu is positioned in Waybar config
        Returns position info for Layer Shell anchoring
        
        Auto-computes position based on:
        - Waybar position (top/bottom)
        - Module location (left/center/right)
        - Module index in array (for precise margin calculation)
        - Waybar height and margins
        
        This is the SAME detection logic as panel_widget.py!
        """
        position = {
            "location": "left",       # left, center, right
            "waybar_position": "bottom", # top or bottom
            "margin_left": 8,
            "margin_right": 8,
            "margin_bottom": 48,      # Above waybar
            "margin_top": 48,
            "module_index": 0,        # Position in module array
            "total_modules_before": 0 # Modules before this one (for width calculation)
        }
        
        waybar_config_paths = [
            Path.home() / ".config/waybar/config.jsonc",
            Path.home() / ".config/waybar/config.json",
            Path.home() / ".config/waybar/config",
        ]
        
        config_content = None
        config_path_used = None
        for config_path in waybar_config_paths:
            if config_path.exists():
                try:
                    content = config_path.read_text()
                    # Remove comments for JSON parsing
                    content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
                    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                    config_content = content
                    config_path_used = config_path
                    print(f"[StartMenu] 📄 Read config: {config_path}")
                    break
                except Exception as e:
                    print(f"[StartMenu] ⚠️ Error reading {config_path}: {e}")
        
        if not config_content:
            print("[StartMenu] ⚠️ Could not read Waybar config, using defaults")
            return position
        
        try:
            config = json.loads(config_content)
            
            # Check waybar position (top/bottom)
            waybar_pos = config.get("position", "top")
            position["waybar_position"] = waybar_pos
            
            # Get waybar dimensions for margin calculation
            waybar_height = config.get("height", 40)
            waybar_margin_bottom = config.get("margin-bottom", 0)
            waybar_margin_top = config.get("margin-top", 0)
            waybar_margin_left = config.get("margin-left", 0)
            waybar_margin_right = config.get("margin-right", 0)
            
            # Calculate vertical margin (distance from screen edge)
            if waybar_pos == "bottom":
                position["margin_bottom"] = waybar_height + waybar_margin_bottom + 8
            else:
                position["margin_top"] = waybar_height + waybar_margin_top + 8
            
            # Find which module group has start-menu
            module_name = "custom/start-menu"
            
            modules_left = config.get("modules-left", [])
            modules_center = config.get("modules-center", [])
            modules_right = config.get("modules-right", [])
            
            # Calculate module width (approximate, for better positioning)
            # This helps align the overlay exactly over the button
            estimated_module_width = 40  # Base width for a button module
            
            if module_name in modules_left:
                position["location"] = "left"
                idx = modules_left.index(module_name)
                position["module_index"] = idx
                position["total_modules_before"] = idx
                
                # Calculate margin: waybar margin + (modules before * width) + spacing
                # More accurate calculation
                modules_width_before = idx * estimated_module_width
                position["margin_left"] = waybar_margin_left + modules_width_before + 8
                
                print(f"[StartMenu] 📍 Found in modules-left at index {idx}/{len(modules_left)}")
                print(f"[StartMenu] 📐 Calculated: {idx} modules × {estimated_module_width}px = {modules_width_before}px offset")
                
            elif module_name in modules_center:
                position["location"] = "center"
                idx = modules_center.index(module_name)
                position["module_index"] = idx
                position["total_modules_before"] = idx
                
                # For center, we need to account for offset from true center
                # If it's not the first module, offset left/right
                if idx > 0:
                    offset = (idx - len(modules_center) // 2) * estimated_module_width
                    if offset < 0:
                        position["margin_left"] = abs(offset)
                    else:
                        position["margin_right"] = offset
                
                print(f"[StartMenu] 📍 Found in modules-center at index {idx}/{len(modules_center)}")
                
            elif module_name in modules_right:
                position["location"] = "right"
                idx = modules_right.index(module_name)
                position["module_index"] = idx
                modules_after = len(modules_right) - 1 - idx
                position["total_modules_before"] = modules_after  # From right side
                
                # Calculate margin: waybar margin + (modules after * width) + spacing
                modules_width_after = modules_after * estimated_module_width
                position["margin_right"] = waybar_margin_right + modules_width_after + 8
                
                print(f"[StartMenu] 📍 Found in modules-right at index {idx}/{len(modules_right)}")
                print(f"[StartMenu] 📐 Calculated: {modules_after} modules after × {estimated_module_width}px = {modules_width_after}px offset")
            
            else:
                print(f"[StartMenu] ⚠️ Module '{module_name}' not found in any module list!")
                print(f"[StartMenu] 📋 Available modules:")
                print(f"[StartMenu]   Left: {modules_left}")
                print(f"[StartMenu]   Center: {modules_center}")
                print(f"[StartMenu]   Right: {modules_right}")
            
            print(f"[StartMenu] 📍 Final Position: {position['location'].upper()}, waybar: {position['waybar_position'].upper()}")
            print(f"[StartMenu] 📏 Margins: L={position['margin_left']}px, R={position['margin_right']}px, "
                  f"T={position['margin_top']}px, B={position['margin_bottom']}px")
            
        except json.JSONDecodeError as e:
            print(f"[StartMenu] ⚠️ JSON parse error in {config_path_used}: {e}")
            print(f"[StartMenu] 💡 Tip: Check for trailing commas or syntax errors in Waybar config")
        except Exception as e:
            print(f"[StartMenu] ⚠️ Config read error: {e}")
            import traceback
            traceback.print_exc()
        
        return position
    
    def _setup_layer_shell(self):
        """
        Setup GTK4 Layer Shell with AUTO-COMPUTED position
        Uses the exact same anchoring logic as panel_widget.py
        """
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "start-menu")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        
        pos = self.waybar_position
        
        # Vertical positioning based on Waybar position
        if pos["waybar_position"] == "bottom":
            # Waybar at bottom - anchor to bottom, menu appears above
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, pos["margin_bottom"])
            print(f"[StartMenu] ⬇️ Anchored BOTTOM, margin={pos['margin_bottom']}px")
        else:
            # Waybar at top - anchor to top, menu appears below
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, pos["margin_top"])
            print(f"[StartMenu] ⬆️ Anchored TOP, margin={pos['margin_top']}px")
        
        # Horizontal positioning based on module location
        if pos["location"] == "left":
            # Anchor LEFT only - this is key!
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, pos["margin_left"])
            print(f"[StartMenu] ⬅️ Anchored LEFT, margin={pos['margin_left']}px")
            
        elif pos["location"] == "center":
            # Center - no anchors, window will center itself
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            print("[StartMenu] ⬛ Centered (no horizontal anchor)")
            
        else:  # right
            # Anchor RIGHT only
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, pos["margin_right"])
            print(f"[StartMenu] ➡️ Anchored RIGHT, margin={pos['margin_right']}px")
        
        print("[StartMenu] ✅ Layer Shell configured with auto-computed position")
    
    def _setup_mouse_tracking(self):
        """Setup mouse enter/leave for smart close"""
        motion = Gtk.EventControllerMotion()
        motion.connect("enter", self._on_mouse_enter)
        motion.connect("leave", self._on_mouse_leave)
        self.add_controller(motion)
    
    def _on_mouse_enter(self, controller, x, y):
        """Mouse entered - cancel any pending close"""
        self._mouse_inside = True
        self._mouse_entered = True
        if self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
            self._close_timer_id = None
    
    def _on_mouse_leave(self, controller):
        """Mouse left - start close timer unless popover is open"""
        self._mouse_inside = False
        
        if self._mouse_entered and not self._has_open_popover():
            def delayed_close():
                self._close_timer_id = None
                if not self._mouse_inside and not self._has_open_popover():
                    print("[StartMenu] ⏱️ Mouse left - closing")
                    self.close()
                return False
            
            self._close_timer_id = GLib.timeout_add(400, delayed_close)
    
    def _has_open_popover(self) -> bool:
        """Check if any popover is open"""
        if self._active_popover:
            return self._active_popover.is_visible()
        return False
    
    def register_popover(self, popover):
        """Register popover to prevent close while open"""
        self._active_popover = popover
        
        def on_closed(p):
            self._active_popover = None
            if not self._mouse_inside:
                GLib.timeout_add(300, lambda: self.close() if not self._mouse_inside else None)
        
        popover.connect("closed", on_closed)
    
    def _on_key_pressed(self, controller, keyval, keycode, state):
        """ESC to close"""
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False
    
    def load_css(self):
        """Load CSS from assets"""
        css_files = [
            self.assets_dir / "start-menu.css",
            self.assets_dir / "style.css",
        ]
        
        for css_file in css_files:
            if css_file.exists():
                try:
                    provider = Gtk.CssProvider()
                    provider.load_from_path(str(css_file))
                    Gtk.StyleContext.add_provider_for_display(
                        self.get_display(),
                        provider,
                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                    )
                    print(f"[StartMenu] 🎨 CSS loaded: {css_file.name}")
                    return
                except Exception as e:
                    print(f"[StartMenu] ⚠️ CSS error: {e}")
        
        self._apply_default_css()
    
    def _apply_default_css(self):
        """Apply default embedded CSS"""
        css = '''
        .start-menu {
            background: alpha(#282c34, 0.95);
            border-radius: 12px;
            border: 1px solid alpha(white, 0.1);
        }
        
        .start-left, .start-right {
            padding: 16px;
        }
        
        .section-title {
            font-size: 13px;
            font-weight: 600;
            color: alpha(white, 0.7);
            margin-bottom: 12px;
        }
        
        .app-tile {
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 12px 8px;
            min-width: 72px;
        }
        
        .app-tile:hover {
            background: alpha(white, 0.1);
        }
        
        .app-tile-label {
            font-size: 11px;
            color: white;
        }
        
        .app-row {
            border-radius: 8px;
            margin: 2px 0;
        }
        
        .app-row:hover {
            background: alpha(white, 0.08);
        }
        
        .search-entry {
            background: alpha(white, 0.1);
            border: 1px solid alpha(white, 0.1);
            border-radius: 8px;
            padding: 8px 12px;
            color: white;
            margin-bottom: 12px;
        }
        
        .bottom-bar {
            background: alpha(black, 0.2);
            border-top: 1px solid alpha(white, 0.1);
            padding: 12px 16px;
        }
        
        .icon-button {
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 8px;
            min-width: 36px;
            min-height: 36px;
        }
        
        .icon-button:hover {
            background: alpha(white, 0.1);
        }
        
        .user-name {
            font-size: 14px;
            font-weight: 500;
            color: white;
        }
        
        .letter-header {
            font-size: 14px;
            font-weight: 600;
            color: #61afef;
            padding: 8px 12px 4px;
        }
        '''
        
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def load_pinned_apps(self):
        """Load pinned apps from JSON"""
        try:
            if self.pinned_file.exists():
                with open(self.pinned_file, 'r') as f:
                    data = json.load(f)
                    return data.get('pinned', [])
            else:
                default = ["firefox", "code", "thunar", "kitty"]
                self.save_pinned_apps(default)
                return default
        except Exception as e:
            print(f"[StartMenu] Error loading pinned: {e}")
            return []
    
    def save_pinned_apps(self, apps):
        """Save pinned apps to JSON"""
        try:
            with open(self.pinned_file, 'w') as f:
                json.dump({'pinned': apps}, f, indent=2)
        except Exception as e:
            print(f"[StartMenu] Error saving: {e}")
    
    def pin_app(self, app_id):
        if app_id not in self.pinned_apps:
            self.pinned_apps.append(app_id)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
    
    def unpin_app(self, app_id):
        if app_id in self.pinned_apps:
            self.pinned_apps.remove(app_id)
            self.save_pinned_apps(self.pinned_apps)
            self.refresh_pinned_section()
    
    def get_app_id(self, app_info):
        name = app_info['name'].lower()
        name = re.sub(r'[^\w\s]', '', name)
        name = name.replace(' ', '-')
        name = re.sub(r'-+', '-', name)
        return name.strip('-')[:50]
    
    def is_pinned(self, app_info):
        return self.get_app_id(app_info) in self.pinned_apps
    
    def load_all_apps(self):
        """Load all installed applications"""
        apps = []
        desktop_dirs = [
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications"),
            Path.home() / ".local/share/applications",
            Path.home() / ".local/share/flatpak/exports/share/applications",
            Path("/var/lib/flatpak/exports/share/applications"),
        ]
        
        seen = set()
        for desktop_dir in desktop_dirs:
            if not desktop_dir.exists():
                continue
            
            for desktop_file in desktop_dir.glob("*.desktop"):
                try:
                    app_info = self.parse_desktop_file(desktop_file)
                    if app_info and app_info['name'] not in seen:
                        apps.append(app_info)
                        seen.add(app_info['name'])
                except:
                    pass
        
        apps.sort(key=lambda x: x['name'].lower())
        return apps
    
    def parse_desktop_file(self, desktop_file):
        """Parse .desktop file"""
        try:
            with open(desktop_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except:
            return None
        
        if 'NoDisplay=true' in content:
            return None
        
        name = icon = exec_cmd = None
        
        for line in content.split('\n'):
            if line.startswith('Name=') and not name:
                name = line.split('=', 1)[1].strip()
            elif line.startswith('Icon='):
                icon = line.split('=', 1)[1].strip()
            elif line.startswith('Exec='):
                exec_cmd = line.split('=', 1)[1].strip()
                exec_cmd = re.sub(r'%[a-zA-Z]', '', exec_cmd).strip()
        
        if not name:
            return None
        
        return {
            'name': name,
            'icon': icon,
            'exec': exec_cmd,
            'desktop_file': str(desktop_file)
        }
    
    def build_ui(self):
        """Build the main UI"""
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.add_css_class("start-menu")
        
        # Content area (split left/right)
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        content.set_vexpand(True)
        
        # LEFT SIDE - Pinned Apps
        self.left_side = self.create_left_side()
        content.append(self.left_side)
        
        # RIGHT SIDE - All Apps
        right_side = self.create_right_side()
        content.append(right_side)
        
        main_box.append(content)
        
        # BOTTOM BAR
        bottom_bar = self.create_bottom_bar()
        main_box.append(bottom_bar)
        
        self.set_child(main_box)
    
    def create_left_side(self):
        """Create left side with pinned apps"""
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        left_box.add_css_class("start-left")
        left_box.set_size_request(360, -1)
        
        pinned_label = Gtk.Label(label="Pinned")
        pinned_label.add_css_class("section-title")
        pinned_label.set_xalign(0)
        left_box.append(pinned_label)
        
        self.pinned_grid = Gtk.FlowBox()
        self.pinned_grid.set_valign(Gtk.Align.START)
        self.pinned_grid.set_max_children_per_line(5)
        self.pinned_grid.set_column_spacing(8)
        self.pinned_grid.set_row_spacing(8)
        self.pinned_grid.set_selection_mode(Gtk.SelectionMode.NONE)
        
        self.refresh_pinned_section()
        left_box.append(self.pinned_grid)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(left_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_margin_start(20)
        scroll.set_margin_end(20)
        scroll.set_margin_top(20)
        scroll.set_margin_bottom(20)
        
        return scroll
    
    def refresh_pinned_section(self):
        """Refresh pinned apps grid"""
        while (child := self.pinned_grid.get_first_child()):
            self.pinned_grid.remove(child)
        
        for app_id in self.pinned_apps:
            app_info = self.find_app_by_id(app_id)
            if app_info:
                self.pinned_grid.append(self.create_app_tile(app_info))
    
    def create_right_side(self):
        """Create right side with all apps and search"""
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right_box.add_css_class("start-right")
        right_box.set_size_request(360, -1)
        
        header = Gtk.Label(label="All Apps")
        header.add_css_class("section-title")
        header.set_xalign(0)
        right_box.append(header)
        
        search_entry = Gtk.SearchEntry()
        search_entry.set_placeholder_text("Type here to search")
        search_entry.add_css_class("search-entry")
        search_entry.connect("search-changed", self.on_search_changed)
        right_box.append(search_entry)
        
        self.apps_list_box = Gtk.ListBox()
        self.apps_list_box.add_css_class("apps-list")
        self.apps_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.apps_list_box.connect("row-activated", self.on_app_activated)
        
        self.populate_apps_list()
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.apps_list_box)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        right_box.append(scroll)
        
        wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        wrapper.append(right_box)
        wrapper.set_margin_start(20)
        wrapper.set_margin_end(20)
        wrapper.set_margin_top(20)
        wrapper.set_margin_bottom(20)
        
        return wrapper
    
    def populate_apps_list(self, filter_text=""):
        """Populate apps list"""
        while (row := self.apps_list_box.get_row_at_index(0)):
            self.apps_list_box.remove(row)
        
        filtered = [a for a in self.all_apps if filter_text.lower() in a['name'].lower()]
        
        groups = {}
        for app in filtered:
            letter = app['name'][0].upper()
            if letter not in groups:
                groups[letter] = []
            groups[letter].append(app)
        
        for letter in sorted(groups.keys()):
            if not filter_text:
                header = Gtk.Label(label=letter)
                header.add_css_class("letter-header")
                header.set_xalign(0)
                row = Gtk.ListBoxRow()
                row.set_selectable(False)
                row.set_activatable(False)
                row.set_child(header)
                self.apps_list_box.append(row)
            
            for app in groups[letter]:
                self.apps_list_box.append(self.create_app_row(app))
    
    def create_app_tile(self, app_info):
        """Create pinned app tile"""
        button = Gtk.Button()
        button.add_css_class("app-tile")
        button.connect("clicked", lambda b: self.launch_app(app_info))
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.append(self.create_app_icon(app_info['icon'], 48))
        
        label = Gtk.Label(label=app_info['name'])
        label.add_css_class("app-tile-label")
        label.set_max_width_chars(10)
        label.set_ellipsize(3)
        box.append(label)
        
        button.set_child(box)
        
        # Right-click menu
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)
        gesture.connect("pressed", lambda g, n, x, y: self.show_pinned_context_menu(button, app_info))
        button.add_controller(gesture)
        
        return button
    
    def create_app_row(self, app_info):
        """Create app list row"""
        row = Gtk.ListBoxRow()
        row.add_css_class("app-row")
        row.set_activatable(True)
        row.app_info = app_info
        
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        
        box.append(self.create_app_icon(app_info['icon'], 32))
        
        label = Gtk.Label(label=app_info['name'])
        label.set_xalign(0)
        label.set_hexpand(True)
        box.append(label)
        
        if self.is_pinned(app_info):
            pin = Gtk.Image.new_from_icon_name("emblem-favorite")
            pin.set_pixel_size(16)
            box.append(pin)
        
        row.set_child(box)
        
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)
        gesture.connect("pressed", lambda g, n, x, y: self.show_app_context_menu(row, app_info))
        row.add_controller(gesture)
        
        return row
    
    def show_pinned_context_menu(self, widget, app_info):
        """Context menu for pinned apps"""
        menu = Gio.Menu()
        menu.append("Unpin", "app.unpin")
        
        popover = Gtk.PopoverMenu()
        popover.set_menu_model(menu)
        popover.set_parent(widget)
        
        self.current_context_app = app_info
        self.register_popover(popover)
        popover.popup()
    
    def show_app_context_menu(self, widget, app_info):
        """Context menu for all apps"""
        menu = Gio.Menu()
        if self.is_pinned(app_info):
            menu.append("Unpin from Start", "app.unpin")
        else:
            menu.append("Pin to Start", "app.pin")
        
        popover = Gtk.PopoverMenu()
        popover.set_menu_model(menu)
        popover.set_parent(widget)
        
        self.current_context_app = app_info
        self.register_popover(popover)
        popover.popup()
    
    def create_app_icon(self, icon_name, size):
        """Create app icon"""
        if icon_name and icon_name.startswith('/') and os.path.exists(icon_name):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(icon_name, size, size, True)
                icon = Gtk.Image.new_from_pixbuf(pixbuf)
                icon.set_pixel_size(size)
                return icon
            except:
                pass
        
        icon = Gtk.Image.new_from_icon_name(icon_name or "application-x-executable")
        icon.set_pixel_size(size)
        return icon
    
    def create_bottom_bar(self):
        """Create bottom bar"""
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bar.add_css_class("bottom-bar")
        bar.set_margin_start(20)
        bar.set_margin_end(20)
        bar.set_margin_top(12)
        bar.set_margin_bottom(20)
        
        # User info
        user_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        avatar = Gtk.Image.new_from_icon_name("avatar-default")
        avatar.set_pixel_size(40)
        user_box.append(avatar)
        
        username = os.getenv("USER", "User")
        user_label = Gtk.Label(label=username.capitalize())
        user_label.add_css_class("user-name")
        user_box.append(user_label)
        
        bar.append(user_box)
        
        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        bar.append(spacer)
        
        # Buttons
        folder_btn = Gtk.Button()
        folder_btn.set_icon_name("folder")
        folder_btn.add_css_class("icon-button")
        folder_btn.connect("clicked", lambda b: self.launch_thunar())
        bar.append(folder_btn)
        
        settings_btn = Gtk.Button()
        settings_btn.set_icon_name("emblem-system")
        settings_btn.add_css_class("icon-button")
        settings_btn.connect("clicked", lambda b: self.launch_control_center())
        bar.append(settings_btn)
        
        power_btn = Gtk.MenuButton()
        power_btn.set_icon_name("system-shutdown")
        power_btn.add_css_class("icon-button")
        
        power_menu = Gio.Menu()
        power_menu.append("🔒 Lock", "app.lock")
        power_menu.append("🚪 Logout", "app.logout")
        power_menu.append("🔄 Restart", "app.restart")
        power_menu.append("⏻ Shutdown", "app.shutdown")
        power_btn.set_menu_model(power_menu)
        bar.append(power_btn)
        
        return bar
    
    def find_app_by_id(self, app_id):
        """Find app by ID"""
        for app in self.all_apps:
            if self.get_app_id(app) == app_id:
                return app
        
        for app in self.all_apps:
            if app_id.lower() in app['name'].lower():
                return app
        
        return None
    
    def launch_app(self, app_info):
        """Launch app"""
        if app_info and app_info['exec']:
            try:
                subprocess.Popen(app_info['exec'], shell=True)
                self.close()
            except Exception as e:
                print(f"[StartMenu] Launch error: {e}")
    
    def launch_thunar(self):
        subprocess.Popen(['thunar'])
        self.close()
    
    def launch_control_center(self):
        subprocess.Popen(['python3', str(self.config_dir / 'main.py')])
        self.close()
    
    def on_app_activated(self, list_box, row):
        if hasattr(row, 'app_info'):
            self.launch_app(row.app_info)
    
    def on_search_changed(self, entry):
        self.populate_apps_list(entry.get_text())


class StartMenuApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.hyprland.startmenu",
                        flags=Gio.ApplicationFlags.FLAGS_NONE)
        
    def do_activate(self):
        windows = self.get_windows()
        if windows:
            windows[0].present()
            return
        
        win = StartMenu(self)
        
        # Actions
        for name, handler in [
            ("pin", self.on_pin),
            ("unpin", self.on_unpin),
            ("lock", lambda a, p: subprocess.Popen(['hyprlock'])),
            ("logout", lambda a, p: subprocess.Popen(['hyprctl', 'dispatch', 'exit'])),
            ("restart", lambda a, p: subprocess.Popen(['systemctl', 'reboot'])),
            ("shutdown", lambda a, p: subprocess.Popen(['systemctl', 'poweroff'])),
        ]:
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", handler)
            self.add_action(action)
        
        win.present()
    
    def on_pin(self, action, param):
        win = self.get_active_window()
        if win and hasattr(win, 'current_context_app'):
            app_id = win.get_app_id(win.current_context_app)
            win.pin_app(app_id)
            win.populate_apps_list()
    
    def on_unpin(self, action, param):
        win = self.get_active_window()
        if win and hasattr(win, 'current_context_app'):
            app_id = win.get_app_id(win.current_context_app)
            win.unpin_app(app_id)
            win.populate_apps_list()


if __name__ == "__main__":
    print("""
╔══════════════════════════════════════════════════════════════╗
║          HYPRLAND START MENU - Auto-Positioned               ║
║          Detects position from Waybar config                 ║
║          Same logic as panel_widget.py                       ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    app = StartMenuApp()
    sys.exit(app.run(None))