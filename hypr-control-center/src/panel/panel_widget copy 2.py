#!/usr/bin/env python3
"""
Hyprland Panel Widget - Waybar Overlay Taskbar
==============================================

A GTK4 Layer Shell overlay that positions itself exactly where
custom/panel is placed in Waybar config (left, center, or right).

Features:
- Dynamic position sync with Waybar config
- Pin/Unpin apps (Windows-style)
- Window list popover
- Context menu
- Theme sync from Waybar style.css
- Smart close: closes when mouse leaves panel and clicks outside
- ENHANCED: Auto-detection for Flatpak, Pacman, AUR, Snap apps

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
import re
from pathlib import Path
from typing import Optional, Dict, List, Tuple, NamedTuple
from dataclasses import dataclass, field
from enum import Enum, auto
import sys

# Check GTK4 Layer Shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
    print("[Panel] ✅ GTK4 Layer Shell available")
except:
    HAS_LAYER_SHELL = False
    print("[Panel] ⚠️ GTK4 Layer Shell not found!")

# Add panel directory to path
_panel_dir = Path(__file__).parent
if str(_panel_dir) not in sys.path:
    sys.path.insert(0, str(_panel_dir))

# Import local modules
try:
    from hypr_ipc import HyprlandIPC, HyprEvent, HyprEventType, HyprWindow, hyprctl_json
    from window_tracker import WindowTracker, AppGroup
    from pinned_manager import PinnedManager, PinnedApp, get_pinned_manager
    from icon_resolver import get_resolver, get_nerd_icon
    from waybar_config_reader import WaybarConfigReader, get_waybar_reader, PanelPosition, WaybarTheme
    HAS_MODULES = True
    print("[Panel] ✅ All modules loaded")
except ImportError as e:
    print(f"[Panel] ❌ Import error: {e}")
    HAS_MODULES = False


# ═══════════════════════════════════════════════════════════════════════════════
# ENHANCED APP DETECTION SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

class AppType(Enum):
    """Application installation type"""
    NATIVE = auto()      # Pacman / AUR
    FLATPAK = auto()     # Flatpak
    SNAP = auto()        # Snap
    APPIMAGE = auto()    # AppImage
    UNKNOWN = auto()


@dataclass
class AppInfo:
    """Comprehensive application information"""
    app_id: str
    name: str
    exec_cmd: str
    app_type: AppType
    desktop_file: Optional[Path] = None
    icon_name: Optional[str] = None
    wm_class: Optional[str] = None
    flatpak_id: Optional[str] = None
    categories: List[str] = field(default_factory=list)
    keywords: List[str] = field(default_factory=list)
    terminal: bool = False
    score: int = 0  # Match confidence score


class AppDetector:
    """
    Advanced application detector that handles:
    - Native packages (pacman, AUR)
    - Flatpak applications
    - Snap packages
    - AppImages
    
    Uses multiple strategies for matching:
    1. Exact WM_CLASS match
    2. Desktop file name match
    3. StartupWMClass match
    4. Exec command analysis
    5. Fuzzy name matching
    """
    
    # Desktop file directories with their types and priorities
    DESKTOP_DIRS: List[Tuple[Path, AppType, int]] = [
        # User local (highest priority)
        (Path.home() / ".local/share/applications", AppType.NATIVE, 100),
        # Flatpak user
        (Path.home() / ".local/share/flatpak/exports/share/applications", AppType.FLATPAK, 95),
        # System native
        (Path("/usr/share/applications"), AppType.NATIVE, 90),
        (Path("/usr/local/share/applications"), AppType.NATIVE, 85),
        # Flatpak system
        (Path("/var/lib/flatpak/exports/share/applications"), AppType.FLATPAK, 80),
        # Snap
        (Path("/var/lib/snapd/desktop/applications"), AppType.SNAP, 75),
        (Path.home() / "snap" / "applications", AppType.SNAP, 70),
        # XDG data dirs
        *[(Path(p) / "applications", AppType.NATIVE, 60) 
          for p in os.environ.get("XDG_DATA_DIRS", "").split(":") if p],
    ]
    
    # Cache for desktop file parsing
    _cache: Dict[str, AppInfo] = {}
    _desktop_files: Optional[Dict[str, List[Tuple[Path, AppType, int]]]] = None
    
    @classmethod
    def clear_cache(cls):
        """Clear the application cache"""
        cls._cache.clear()
        cls._desktop_files = None
    
    @classmethod
    def _index_desktop_files(cls) -> Dict[str, List[Tuple[Path, AppType, int]]]:
        """Index all desktop files for quick lookup"""
        if cls._desktop_files is not None:
            return cls._desktop_files
        
        cls._desktop_files = {}
        
        for desktop_dir, app_type, priority in cls.DESKTOP_DIRS:
            if not desktop_dir.exists():
                continue
            
            try:
                for desktop_file in desktop_dir.glob("*.desktop"):
                    # Index by filename (without .desktop)
                    key = desktop_file.stem.lower()
                    if key not in cls._desktop_files:
                        cls._desktop_files[key] = []
                    cls._desktop_files[key].append((desktop_file, app_type, priority))
                    
                    # Also index by simple name (last part of reverse domain)
                    # e.g., "org.mozilla.firefox" -> "firefox"
                    if "." in key:
                        simple_key = key.split(".")[-1]
                        if simple_key not in cls._desktop_files:
                            cls._desktop_files[simple_key] = []
                        cls._desktop_files[simple_key].append((desktop_file, app_type, priority - 5))
            except PermissionError:
                continue
        
        print(f"[AppDetector] 📚 Indexed {len(cls._desktop_files)} desktop file entries")
        return cls._desktop_files
    
    @classmethod
    def find_app(cls, app_id: str, wm_class: Optional[str] = None) -> Optional[AppInfo]:
        """
        Find application by app_id or WM_CLASS.
        
        Search strategy:
        1. Check cache
        2. Try exact filename match
        3. Parse desktop files and score them
        4. Return best match above threshold
        """
        # Normalize identifiers
        app_id_lower = app_id.lower().replace(" ", "-").replace("_", "-")
        wm_class_lower = wm_class.lower() if wm_class else app_id_lower
        
        # Check cache
        cache_key = f"{app_id_lower}:{wm_class_lower}"
        if cache_key in cls._cache:
            return cls._cache[cache_key]
        
        # Index desktop files if not done
        desktop_index = cls._index_desktop_files()
        
        # Collect candidates
        candidates: List[AppInfo] = []
        checked_files: set = set()
        
        # Strategy 1: Direct filename match
        for key in [app_id_lower, wm_class_lower, app_id_lower.split(".")[-1]]:
            if key in desktop_index:
                for desktop_file, app_type, priority in desktop_index[key]:
                    if desktop_file in checked_files:
                        continue
                    checked_files.add(desktop_file)
                    
                    app_info = cls._parse_and_score(
                        desktop_file, app_type, priority,
                        app_id_lower, wm_class_lower
                    )
                    if app_info and app_info.score > 0:
                        candidates.append(app_info)
        
        # Strategy 2: Full scan for harder matches (only if no good candidates)
        if not candidates or max(c.score for c in candidates) < 50:
            for desktop_dir, app_type, priority in cls.DESKTOP_DIRS:
                if not desktop_dir.exists():
                    continue
                
                try:
                    for desktop_file in desktop_dir.glob("*.desktop"):
                        if desktop_file in checked_files:
                            continue
                        checked_files.add(desktop_file)
                        
                        app_info = cls._parse_and_score(
                            desktop_file, app_type, priority,
                            app_id_lower, wm_class_lower
                        )
                        if app_info and app_info.score > 30:
                            candidates.append(app_info)
                except PermissionError:
                    continue
        
        if not candidates:
            return None
        
        # Sort by score (highest first)
        candidates.sort(key=lambda x: x.score, reverse=True)
        best = candidates[0]
        
        # Cache result
        cls._cache[cache_key] = best
        
        print(f"[AppDetector] ✅ Found: {best.name} ({best.app_type.name}) score={best.score}")
        return best
    
    @classmethod
    def _parse_and_score(cls, desktop_file: Path, default_type: AppType, 
                         base_priority: int, app_id: str, wm_class: str) -> Optional[AppInfo]:
        """Parse a desktop file and score how well it matches"""
        try:
            content = desktop_file.read_text(errors='ignore')
        except:
            return None
        
        # Parse desktop entry
        entry = cls._parse_desktop_entry(content)
        if not entry:
            return None
        
        exec_cmd = entry.get("Exec", "")
        name = entry.get("Name", desktop_file.stem)
        icon = entry.get("Icon", "")
        startup_wm_class = entry.get("StartupWMClass", "").lower()
        flatpak_id = entry.get("X-Flatpak", "")
        terminal = entry.get("Terminal", "").lower() == "true"
        categories = entry.get("Categories", "").split(";")
        keywords = entry.get("Keywords", "").split(";")
        
        # Determine actual app type
        app_type = default_type
        if flatpak_id or "flatpak run" in exec_cmd:
            app_type = AppType.FLATPAK
            if not flatpak_id and "flatpak run" in exec_cmd:
                # Extract flatpak ID from exec
                match = re.search(r'flatpak run\s+([^\s]+)', exec_cmd)
                if match:
                    flatpak_id = match.group(1)
        elif "/snap/" in exec_cmd:
            app_type = AppType.SNAP
        elif ".appimage" in exec_cmd.lower() or ".AppImage" in exec_cmd:
            app_type = AppType.APPIMAGE
        
        # Calculate match score
        score = base_priority
        filename = desktop_file.stem.lower()
        name_lower = name.lower()
        
        # Exact matches (high score)
        if startup_wm_class == wm_class:
            score += 100
        elif startup_wm_class == app_id:
            score += 95
        
        if filename == wm_class or filename == app_id:
            score += 90
        elif filename.endswith(wm_class) or filename.endswith(app_id):
            score += 70
        
        if name_lower == wm_class or name_lower == app_id:
            score += 85
        
        # Partial matches
        if wm_class in filename or app_id in filename:
            score += 50
        if wm_class in name_lower or app_id in name_lower:
            score += 45
        if wm_class in startup_wm_class:
            score += 60
        
        # Flatpak ID matching (org.mozilla.firefox -> firefox)
        if flatpak_id:
            flatpak_simple = flatpak_id.lower().split(".")[-1]
            if flatpak_simple == wm_class or flatpak_simple == app_id:
                score += 80
            elif wm_class in flatpak_id.lower() or app_id in flatpak_id.lower():
                score += 55
        
        # Exec command analysis
        exec_lower = exec_cmd.lower()
        exec_basename = Path(exec_cmd.split()[0] if exec_cmd else "").stem.lower()
        
        if exec_basename == wm_class or exec_basename == app_id:
            score += 65
        elif wm_class in exec_lower or app_id in exec_lower:
            score += 35
        
        # Keywords match
        for kw in keywords:
            if kw.lower() == wm_class or kw.lower() == app_id:
                score += 40
                break
        
        # No match penalty
        if score <= base_priority:
            return None
        
        return AppInfo(
            app_id=desktop_file.stem,
            name=name,
            exec_cmd=exec_cmd,
            app_type=app_type,
            desktop_file=desktop_file,
            icon_name=icon,
            wm_class=startup_wm_class or filename,
            flatpak_id=flatpak_id,
            categories=[c for c in categories if c],
            keywords=[k for k in keywords if k],
            terminal=terminal,
            score=score
        )
    
    @classmethod
    def _parse_desktop_entry(cls, content: str) -> Optional[Dict[str, str]]:
        """Parse [Desktop Entry] section from desktop file"""
        entry = {}
        in_desktop_entry = False
        
        for line in content.splitlines():
            line = line.strip()
            
            if line == "[Desktop Entry]":
                in_desktop_entry = True
                continue
            elif line.startswith("[") and line.endswith("]"):
                if in_desktop_entry:
                    break  # End of Desktop Entry section
                continue
            
            if not in_desktop_entry or not line or line.startswith("#"):
                continue
            
            if "=" in line:
                key, _, value = line.partition("=")
                entry[key.strip()] = value.strip()
        
        return entry if entry else None
    
    @classmethod
    def get_launch_command(cls, app_info: AppInfo) -> str:
        """Generate the best launch command for an app"""
        exec_cmd = app_info.exec_cmd
        
        # Clean field codes (%u %U %f %F etc.)
        exec_cmd = re.sub(r'\s+%[a-zA-Z]', '', exec_cmd)
        
        # Handle different app types
        if app_info.app_type == AppType.FLATPAK and app_info.flatpak_id:
            # Use flatpak run for reliability
            return f"flatpak run {app_info.flatpak_id}"
        
        elif app_info.app_type == AppType.SNAP:
            # Snap apps - use exec as-is
            return exec_cmd
        
        elif app_info.app_type == AppType.APPIMAGE:
            # AppImage - use exec as-is
            return exec_cmd
        
        else:
            # Native - clean up env vars if at the start
            parts = exec_cmd.split()
            clean_parts = []
            skip_env = True
            
            for part in parts:
                if skip_env and ("=" in part or part == "env"):
                    continue
                skip_env = False
                clean_parts.append(part)
            
            return " ".join(clean_parts) if clean_parts else exec_cmd
    
    @classmethod
    def is_flatpak_installed(cls, app_id: str) -> Tuple[bool, Optional[str]]:
        """Check if app is installed as flatpak and get its ID"""
        try:
            result = subprocess.run(
                ["flatpak", "list", "--app", "--columns=application"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                app_id_lower = app_id.lower()
                for line in result.stdout.splitlines():
                    flatpak_id = line.strip()
                    if not flatpak_id:
                        continue
                    # Check if app_id matches the flatpak ID
                    if app_id_lower in flatpak_id.lower():
                        return True, flatpak_id
                    # Check simple name (last part)
                    simple = flatpak_id.split(".")[-1].lower()
                    if simple == app_id_lower:
                        return True, flatpak_id
        except:
            pass
        return False, None
    
    @classmethod
    def is_native_installed(cls, app_id: str) -> bool:
        """Check if app is installed natively (pacman/AUR)"""
        # Try which command
        try:
            result = subprocess.run(
                ["which", app_id],
                capture_output=True, timeout=2
            )
            if result.returncode == 0:
                return True
        except:
            pass
        
        # Try pacman query
        try:
            result = subprocess.run(
                ["pacman", "-Qq", app_id],
                capture_output=True, timeout=2
            )
            if result.returncode == 0:
                return True
        except:
            pass
        
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# TASKBAR ITEM
# ═══════════════════════════════════════════════════════════════════════════════

class TaskbarItem(Gtk.Button):
    """Single taskbar item with icon, click handlers, and context menu"""
    
    def __init__(self, panel: 'PanelWidget', app_id: str, 
                 pinned_app: Optional[PinnedApp] = None,
                 app_group: Optional[AppGroup] = None):
        super().__init__()
        
        self.panel = panel
        self.app_id = app_id
        self.pinned_app = pinned_app
        self.app_group = app_group
        
        # Detect app info
        wm_class = self._get_wm_class()
        self.app_info = AppDetector.find_app(app_id, wm_class)
        
        self.add_css_class("taskbar-item")
        
        self.is_pinned = pinned_app is not None
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        
        self._build_ui()
        self._update_state()
        self._setup_clicks()
    
    def _build_ui(self):
        """Build icon widget"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box.set_valign(Gtk.Align.CENTER)
        
        resolver = get_resolver()
        wm_class = self._get_wm_class()
        
        # Use detected icon if available
        icon_name = None
        if self.app_info and self.app_info.icon_name:
            icon_name = self.app_info.icon_name
        
        # Try to create icon
        self.icon_widget = resolver.create_icon_image(
            icon_name or wm_class, 
            size=24, 
            use_nerd_fallback=True
        )
        self.icon_widget.add_css_class("taskbar-icon")
        box.append(self.icon_widget)
        
        self.set_child(box)
        self._update_tooltip()
    
    def _get_wm_class(self) -> str:
        if self.app_group:
            return self.app_group.wm_class
        if self.pinned_app:
            return self.pinned_app.wm_class or self.pinned_app.app_id
        return self.app_id
    
    def _update_state(self):
        """Update CSS classes based on state"""
        for cls in ["focused", "running", "not-running"]:
            self.remove_css_class(cls)
        
        if self.is_focused:
            self.add_css_class("focused")
        elif self.is_running:
            self.add_css_class("running")
        elif self.is_pinned:
            self.add_css_class("not-running")
    
    def _update_tooltip(self):
        name = ""
        if self.app_info:
            name = self.app_info.name
        elif self.pinned_app:
            name = self.pinned_app.name or self.pinned_app.app_id
        elif self.app_group:
            name = self.app_group.wm_class
        else:
            name = self.app_id
        
        tooltip = name
        
        # Add app type indicator
        if self.app_info:
            type_icons = {
                AppType.FLATPAK: "📦",
                AppType.SNAP: "🔷",
                AppType.APPIMAGE: "📀",
                AppType.NATIVE: "",
            }
            type_icon = type_icons.get(self.app_info.app_type, "")
            if type_icon:
                tooltip = f"{type_icon} {tooltip}"
        
        if self.app_group and self.app_group.window_count > 1:
            tooltip += f" ({self.app_group.window_count} windows)"
        
        self.set_tooltip_text(tooltip)
    
    def _setup_clicks(self):
        # Left click
        self.connect("clicked", self._on_left_click)
        
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
    
    def _on_left_click(self, btn):
        """Left click - focus or launch"""
        print(f"[TaskbarItem] Click: {self.app_id}")
        
        if self.is_running and self.app_group:
            if self.app_group.window_count == 1:
                window = self.app_group.most_recent_window
                if window:
                    self.panel.focus_window(window.address)
                    GLib.timeout_add(100, self.panel.close)
            else:
                self._show_window_list()
        elif self.is_pinned:
            self.panel.launch_app(self.app_id, self.app_info)
            GLib.timeout_add(100, self.panel.close)
    
    def _on_middle_click(self, gesture, n_press, x, y):
        """Middle click - close all"""
        if self.is_running and self.app_group:
            self.panel.close_app(self.app_group.wm_class)
    
    def _on_right_click(self, gesture, n_press, x, y):
        """Right click - context menu"""
        self._show_context_menu()
    
    def _show_window_list(self):
        """Show window list popover"""
        if not self.app_group:
            return
        
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("window-list-popover")
        
        self.panel.register_popover(popover)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        
        for window in self.app_group.windows.values():
            row = Gtk.Button()
            row.add_css_class("window-list-item")
            
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            
            if window.is_focused:
                indicator = Gtk.Label(label="●")
                indicator.add_css_class("focus-indicator")
                row_box.append(indicator)
            
            title_text = window.title[:40] if window.title else "Untitled"
            title = Gtk.Label(label=title_text)
            title.set_xalign(0)
            title.set_hexpand(True)
            title.set_ellipsize(3)
            row_box.append(title)
            
            close_btn = Gtk.Button()
            close_btn.set_icon_name("window-close-symbolic")
            close_btn.add_css_class("flat")
            close_btn.add_css_class("window-close-btn")
            close_btn.connect("clicked", lambda b, addr=window.address: self._close_single(addr, popover))
            row_box.append(close_btn)
            
            row.set_child(row_box)
            row.connect("clicked", lambda b, addr=window.address: self._focus_single(addr, popover))
            box.append(row)
        
        popover.set_child(box)
        popover.popup()
    
    def _show_context_menu(self):
        """Show context menu with app type info"""
        popover = Gtk.Popover()
        popover.set_parent(self)
        popover.add_css_class("context-menu")
        
        self.panel.register_popover(popover)
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(4)
        box.set_margin_bottom(4)
        box.set_margin_start(4)
        box.set_margin_end(4)
        
        # App type header
        if self.app_info:
            type_labels = {
                AppType.FLATPAK: "📦 Flatpak",
                AppType.SNAP: "🔷 Snap",
                AppType.APPIMAGE: "📀 AppImage",
                AppType.NATIVE: "💻 Native",
            }
            type_label = type_labels.get(self.app_info.app_type, "")
            if type_label:
                header = Gtk.Label(label=type_label)
                header.add_css_class("dim-label")
                header.set_xalign(0)
                header.set_margin_start(8)
                header.set_margin_bottom(4)
                box.append(header)
                
                sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
                sep.set_margin_bottom(4)
                box.append(sep)
        
        # Pin/Unpin
        if self.is_pinned:
            btn = Gtk.Button(label="📍 Unpin from taskbar")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: self._do_action_and_close(
                popover, lambda: self.panel.unpin_app(self.app_id)))
            box.append(btn)
        else:
            btn = Gtk.Button(label="📌 Pin to taskbar")
            btn.add_css_class("flat")
            btn.connect("clicked", lambda b: self._do_action_and_close(
                popover, lambda: self.panel.pin_app(self._get_wm_class())))
            box.append(btn)
        
        # New window
        new_btn = Gtk.Button(label="🆕 New window")
        new_btn.add_css_class("flat")
        new_btn.connect("clicked", lambda b: self._do_action_and_close(
            popover, lambda: self.panel.launch_app(self._get_wm_class(), self.app_info)))
        box.append(new_btn)
        
        # Close all
        if self.is_running:
            close_btn = Gtk.Button(label="❌ Close all windows")
            close_btn.add_css_class("flat")
            close_btn.connect("clicked", lambda b: self._do_action_and_close(
                popover, lambda: self.panel.close_app(self.app_group.wm_class)))
            box.append(close_btn)
        
        popover.set_child(box)
        popover.popup()
    
    def _do_action_and_close(self, popover: Gtk.Popover, action):
        """Execute action, close popover, then close panel"""
        popover.popdown()
        action()
        GLib.timeout_add(100, self.panel.close)
    
    def _focus_single(self, address: str, popover: Gtk.Popover):
        """Focus window and close panel"""
        popover.popdown()
        self.panel.focus_window(address)
        GLib.timeout_add(100, self.panel.close)
    
    def _close_single(self, address: str, popover: Gtk.Popover):
        """Close a single window"""
        self.panel.close_window(address)
    
    def update(self, app_group: Optional[AppGroup] = None):
        """Update state"""
        self.app_group = app_group
        self.is_running = app_group is not None and app_group.window_count > 0
        self.is_focused = app_group.has_focus if app_group else False
        self._update_state()
        self._update_tooltip()


# ═══════════════════════════════════════════════════════════════════════════════
# PANEL WIDGET
# ═══════════════════════════════════════════════════════════════════════════════

class PanelWidget(Gtk.Window):
    """
    Panel overlay widget that syncs position with Waybar.
    
    Positions itself exactly where custom/panel module is in Waybar config.
    
    Smart Close Behavior:
    - Once mouse enters the panel, it becomes "armed"
    - When mouse leaves the panel (after entering), monitor for clicks outside
    - Any click outside the panel will close it
    """
    
    def __init__(self, module_name: str = "custom/panel"):
        super().__init__()
        
        self.module_name = module_name
        self.set_title("hypr-panel")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Config directory
        self.config_dir = Path.home() / ".config/hypr-control-center"
        
        # Load Waybar config
        self.waybar_reader = get_waybar_reader()
        self.position = self.waybar_reader.get_panel_position(module_name)
        self.theme = self.waybar_reader.get_theme()
        
        print(f"[Panel] 📍 Position: {self.position.location}")
        print(f"[Panel] 📏 Margins: L={self.position.margin_left}, R={self.position.margin_right}")
        
        # Setup layer shell
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # Components
        self.items: Dict[str, TaskbarItem] = {}
        self.tracker: Optional[WindowTracker] = None
        self.pinned_manager: Optional[PinnedManager] = None
        self._async_loop = None
        self._tracker_thread = None
        
        # Smart close state
        self._mouse_has_entered = False
        self._mouse_inside = False
        self._close_timer_id = None
        self._active_popover = None
        
        # Initialize
        self._init_components()
        
        # Track mouse enter/leave
        motion_controller = Gtk.EventControllerMotion()
        motion_controller.connect("enter", self._on_mouse_enter)
        motion_controller.connect("leave", self._on_mouse_leave)
        self.add_controller(motion_controller)
    
    def _on_mouse_enter(self, controller, x, y):
        """Mouse entered the panel"""
        self._mouse_has_entered = True
        self._mouse_inside = True
        
        if hasattr(self, '_close_timer_id') and self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
            self._close_timer_id = None
    
    def _on_mouse_leave(self, controller):
        """Mouse left the panel"""
        self._mouse_inside = False
        
        if self._mouse_has_entered:
            def delayed_close():
                self._close_timer_id = None
                if not self._mouse_inside and not self._has_open_popover():
                    print("[Panel] ⏱️ Timer expired - closing")
                    self._close_panel()
                return False
            
            self._close_timer_id = GLib.timeout_add(400, delayed_close)
    
    def _has_open_popover(self) -> bool:
        """Check if any popover is currently open"""
        if hasattr(self, '_active_popover') and self._active_popover:
            return self._active_popover.is_visible()
        return False
    
    def register_popover(self, popover: Gtk.Popover):
        """Register a popover so panel knows not to close while it's open"""
        self._active_popover = popover
        
        def on_popover_closed(p):
            self._active_popover = None
            if not self._mouse_inside and self._mouse_has_entered:
                def delayed_close():
                    if not self._mouse_inside and not self._has_open_popover():
                        self._close_panel()
                    return False
                GLib.timeout_add(300, delayed_close)
        
        popover.connect("closed", on_popover_closed)
    
    def _close_panel(self):
        """Close the panel"""
        if self._has_open_popover():
            return False
        
        print("[Panel] 🚪 Closing panel")
        self._mouse_has_entered = False
        self.close()
        return False
    
    def _setup_layer_shell(self):
        """Setup GTK4 Layer Shell with dynamic positioning"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_namespace(self, "hypr-panel")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        Gtk4LayerShell.set_exclusive_zone(self, 0)
        
        # Vertical position
        if self.position.waybar_position == "bottom":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, 
                                      self.position.waybar_margin_bottom + 6)
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP,
                                      self.position.waybar_margin_top + 6)
        
        # Horizontal position
        if self.position.location == "left":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.position.margin_left)
            print(f"[Panel] ⬅️ Anchored LEFT, margin={self.position.margin_left}")
            
        elif self.position.location == "center":
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.position.margin_left)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[Panel] ⬛ Anchored CENTER, L={self.position.margin_left}, R={self.position.margin_right}")
            
        else:
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, False)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, self.position.margin_right)
            print(f"[Panel] ➡️ Anchored RIGHT, margin={self.position.margin_right}")
        
        print("[Panel] ✅ Layer Shell configured")
    
    def _get_hyprland_config(self) -> dict:
        """Read Hyprland config for colors and opacity"""
        config = {
            "active_opacity": 1.0,
            "inactive_opacity": 1.0,
            "active_border_color": "#61afef",
            "inactive_border_color": "#5c6370",
            "rounding": 8,
        }
        
        hypr_conf = Path.home() / ".config/hypr/hyprland.conf"
        conf_files = [hypr_conf]
        conf_dir = Path.home() / ".config/hypr"
        
        for extra in ["colors.conf", "theme.conf", "decoration.conf", "appearance.conf"]:
            extra_path = conf_dir / extra
            if extra_path.exists():
                conf_files.append(extra_path)
        
        for conf_file in conf_files:
            if not conf_file.exists():
                continue
            
            try:
                content = conf_file.read_text()
                
                for line in content.splitlines():
                    line = line.strip()
                    
                    if line.startswith("#") or not line:
                        continue
                    
                    if "active_opacity" in line:
                        try:
                            val = line.split("=")[1].strip().split("#")[0].strip()
                            config["active_opacity"] = float(val)
                        except:
                            pass
                    
                    elif "inactive_opacity" in line:
                        try:
                            val = line.split("=")[1].strip().split("#")[0].strip()
                            config["inactive_opacity"] = float(val)
                        except:
                            pass
                    
                    elif "rounding" in line and "border" not in line.lower():
                        try:
                            val = line.split("=")[1].strip().split("#")[0].strip()
                            config["rounding"] = int(val)
                        except:
                            pass
                    
                    elif "col.active_border" in line:
                        try:
                            val = line.split("=")[1].strip().split("#")[0].strip()
                            config["active_border_color"] = self._parse_hypr_color(val)
                        except:
                            pass
                    
                    elif "col.inactive_border" in line:
                        try:
                            val = line.split("=")[1].strip().split("#")[0].strip()
                            config["inactive_border_color"] = self._parse_hypr_color(val)
                        except:
                            pass
                            
            except Exception as e:
                print(f"[Panel] ⚠️ Error reading {conf_file}: {e}")
        
        print(f"[Panel] 🎨 Hyprland config: opacity={config['active_opacity']}, "
              f"border={config['active_border_color']}, rounding={config['rounding']}")
        
        return config
    
    def _parse_hypr_color(self, color_str: str) -> str:
        """Parse Hyprland color format to CSS hex"""
        color_str = color_str.strip()
        
        if color_str.startswith("rgba(") or color_str.startswith("rgb("):
            inner = color_str.split("(")[1].rstrip(")")
            if len(inner) == 8:
                return f"#{inner[:6]}"
            elif len(inner) == 6:
                return f"#{inner}"
        
        if color_str.startswith("0x"):
            hex_part = color_str[2:]
            if len(hex_part) >= 6:
                return f"#{hex_part[:6]}"
        
        if color_str.startswith("$"):
            var_map = {
                "$blue": "#61afef",
                "$red": "#e06c75",
                "$green": "#98c379",
                "$yellow": "#e5c07b",
                "$purple": "#c678dd",
                "$cyan": "#56b6c2",
                "$orange": "#d19a66",
            }
            return var_map.get(color_str.lower(), "#61afef")
        
        if color_str.startswith("#"):
            return color_str[:7]
        
        return "#61afef"
    
    def _get_waybar_colors(self) -> dict:
        """Parse colors from Waybar style.css"""
        colors = {
            "bg": None,
            "fg": None,
            "accent": None,
            "red": "#e06c75",
            "green": "#98c379",
            "yellow": "#e5c07b",
            "blue": "#61afef",
        }
        
        waybar_css_paths = [
            Path.home() / ".config/waybar/style.css",
            Path.home() / ".config/waybar/themes/current.css",
            Path.home() / ".config/waybar/colors.css",
        ]
        
        for css_path in waybar_css_paths:
            if not css_path.exists():
                continue
                
            try:
                content = css_path.read_text()
                
                for line in content.splitlines():
                    line = line.strip()
                    
                    if line.startswith("@define-color"):
                        parts = line.replace("@define-color", "").strip().rstrip(";").split()
                        if len(parts) >= 2:
                            name = parts[0].lower()
                            color = parts[1]
                            
                            if "bg" in name or "background" in name or "base" in name:
                                if not colors["bg"]:
                                    colors["bg"] = color
                            elif "fg" in name or "foreground" in name or "text" in name:
                                if not colors["fg"]:
                                    colors["fg"] = color
                            elif "accent" in name or "blue" in name or "primary" in name:
                                if not colors["accent"]:
                                    colors["accent"] = color
                            elif "red" in name or "error" in name:
                                colors["red"] = color
                            elif "green" in name or "success" in name:
                                colors["green"] = color
                            elif "yellow" in name or "warning" in name:
                                colors["yellow"] = color
                    
                    elif line.startswith("--") and ":" in line:
                        name, _, value = line.partition(":")
                        name = name.strip().lower()
                        value = value.strip().rstrip(";").strip()
                        
                        if "bg" in name or "background" in name:
                            if not colors["bg"]:
                                colors["bg"] = value
                        elif "fg" in name or "foreground" in name:
                            if not colors["fg"]:
                                colors["fg"] = value
                        elif "accent" in name or "primary" in name:
                            if not colors["accent"]:
                                colors["accent"] = value
                    
                    elif "background:" in line or "background-color:" in line:
                        value = line.split(":")[-1].strip().rstrip(";").strip()
                        if value.startswith("#") or value.startswith("rgb"):
                            if not colors["bg"]:
                                colors["bg"] = value
                    elif "color:" in line and "background" not in line:
                        value = line.split(":")[-1].strip().rstrip(";").strip()
                        if value.startswith("#") or value.startswith("rgb"):
                            if not colors["fg"]:
                                colors["fg"] = value
                
                print(f"[Panel] 🎨 Parsed Waybar CSS: {css_path.name}")
                
            except Exception as e:
                print(f"[Panel] ⚠️ Error parsing {css_path}: {e}")
        
        return colors
    
    def _apply_css(self):
        """Apply theme CSS from external file"""
        t = self.theme
        h = self._get_hyprland_config()
        w = self._get_waybar_colors()
        
        accent_color = w["accent"] or h["active_border_color"] or t.blue
        bg_color = w["bg"] or t.bg0
        fg_color = w["fg"] or t.fg
        red_color = w["red"] or t.red
        
        opacity = h["active_opacity"]
        inactive_opacity = h["inactive_opacity"]
        rounding = h["rounding"]
        rounding_lg = min(rounding + 4, rounding * 1.5)
        
        variables = {
            "@accent_color": accent_color,
            "@bg_color": bg_color,
            "@fg_color": fg_color,
            "@opacity": str(opacity),
            "@inactive_opacity": str(inactive_opacity * 0.6),
            "@rounding": f"{rounding}px",
            "@rounding_lg": f"{int(rounding_lg)}px",
            "@red_color": red_color,
            "@green_color": w["green"] or t.green,
            "@yellow_color": w["yellow"] or t.yellow,
            "@blue_color": w["blue"] or t.blue,
        }
        
        css_file = self.config_dir / "assets" / "panel-widget.css"
        css = None
        
        if css_file.exists():
            try:
                css = css_file.read_text()
                print(f"[Panel] 📄 Loaded: {css_file}")
            except Exception as e:
                print(f"[Panel] ⚠️ Failed to load {css_file}: {e}")
        
        if not css:
            css = self._get_default_css()
            self._save_default_css(css_file, css)
        
        for var, value in variables.items():
            css = css.replace(var, value)
        
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
        print(f"[Panel] 🎨 Theme applied: accent={accent_color}, bg={bg_color}, rounding={rounding}px")
    
    def _get_default_css(self) -> str:
        """Get default embedded CSS template"""
        return '''
/* Panel Widget - Auto-generated CSS */
window {
    background: transparent;
}

.panel-container {
    background: alpha(@bg_color, @opacity);
    border-radius: @rounding_lg;
    border: 1px solid alpha(@fg_color, 0.1);
    padding: 4px 8px;
}

.taskbar-item {
    background: transparent;
    border: none;
    border-radius: @rounding;
    padding: 6px 8px;
    margin: 2px;
    min-width: 36px;
    min-height: 36px;
    transition: all 150ms ease;
}

.taskbar-item:hover {
    background: alpha(@fg_color, 0.08);
}

.taskbar-item.focused {
    background: alpha(@accent_color, 0.15);
    border-bottom: 2px solid @accent_color;
}

.taskbar-item.running {
    border-bottom: 2px solid alpha(@accent_color, 0.5);
}

.taskbar-item.not-running {
    opacity: @inactive_opacity;
}

.taskbar-item.not-running:hover {
    opacity: 1;
}

.taskbar-icon {
    color: @fg_color;
    font-size: 20px;
}

.separator {
    background: alpha(@fg_color, 0.15);
    min-width: 1px;
    margin: 8px 4px;
}

.window-list-popover,
.context-menu {
    background: alpha(@bg_color, @opacity);
    border: 1px solid alpha(@accent_color, 0.3);
    border-radius: @rounding_lg;
}

.window-list-popover > contents,
.context-menu > contents {
    background: transparent;
    padding: 4px;
}

.window-list-item,
.context-menu button {
    background: transparent;
    border: none;
    border-radius: @rounding;
    padding: 8px 12px;
    margin: 2px;
    color: @fg_color;
}

.window-list-item:hover,
.context-menu button:hover {
    background: alpha(@accent_color, 0.15);
}

.focus-indicator {
    color: @accent_color;
    margin-right: 8px;
}

.window-close-btn {
    opacity: 0.5;
    min-width: 24px;
    min-height: 24px;
}

.window-close-btn:hover {
    opacity: 1;
    color: @red_color;
}

.dim-label {
    opacity: 0.7;
    font-size: 0.85em;
}

tooltip {
    background: alpha(@bg_color, @opacity);
    border: 1px solid alpha(@accent_color, 0.2);
    border-radius: @rounding;
}

tooltip label {
    color: @fg_color;
    padding: 6px 10px;
}
'''
    
    def _save_default_css(self, css_file: Path, css: str):
        """Save default CSS file"""
        try:
            css_file.parent.mkdir(parents=True, exist_ok=True)
            
            header = '''/*
 * Panel Widget Stylesheet
 * ========================
 * Location: ~/.config/hypr-control-center/assets/panel-widget.css
 * 
 * Auto-generated - Feel free to customize!
 */

'''
            css_file.write_text(header + css)
            print(f"[Panel] 💾 Created: {css_file}")
        except Exception as e:
            print(f"[Panel] ⚠️ Could not save CSS: {e}")
    
    def _build_ui(self):
        """Build panel UI"""
        self.container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.add_css_class("panel-container")
        self.container.set_halign(Gtk.Align.CENTER)
        self.container.set_valign(Gtk.Align.CENTER)
        
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.pinned_box)
        
        self.separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        self.separator.add_css_class("separator")
        self.container.append(self.separator)
        
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.container.append(self.running_box)
        
        self.set_child(self.container)
    
    def _init_components(self):
        """Initialize tracker and pinned manager"""
        self.pinned_manager = get_pinned_manager(self.config_dir)
        self.pinned_manager.on_change(self._on_pinned_change)
        
        self.tracker = WindowTracker()
        self.tracker.on_change(self._on_tracker_change)
        
        GLib.idle_add(self._rebuild_ui)
        
        def run_tracker():
            self._async_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._async_loop)
            try:
                self._async_loop.run_until_complete(self.tracker.start())
            except Exception as e:
                print(f"[Panel] Tracker error: {e}")
        
        self._tracker_thread = threading.Thread(target=run_tracker, daemon=True)
        self._tracker_thread.start()
        
        print("[Panel] ✅ Components initialized")
    
    def _on_tracker_change(self):
        GLib.idle_add(self._update_ui)
    
    def _on_pinned_change(self):
        GLib.idle_add(self._rebuild_ui)
    
    def _rebuild_ui(self):
        """Rebuild entire taskbar"""
        self.items.clear()
        
        while (child := self.pinned_box.get_first_child()):
            self.pinned_box.remove(child)
        while (child := self.running_box.get_first_child()):
            self.running_box.remove(child)
        
        pinned_apps = self.pinned_manager.get_pinned_apps() if self.pinned_manager else []
        running_groups = {g.wm_class.lower(): g for g in (self.tracker.get_app_groups() if self.tracker else [])}
        
        for pinned in pinned_apps:
            app_group = None
            if pinned.wm_class and pinned.wm_class.lower() in running_groups:
                app_group = running_groups[pinned.wm_class.lower()]
            elif pinned.app_id.lower() in running_groups:
                app_group = running_groups[pinned.app_id.lower()]
            
            item = TaskbarItem(self, pinned.app_id, pinned_app=pinned, app_group=app_group)
            self.items[pinned.app_id] = item
            self.pinned_box.append(item)
        
        pinned_classes = set()
        for p in pinned_apps:
            if p.wm_class:
                pinned_classes.add(p.wm_class.lower())
            pinned_classes.add(p.app_id.lower())
        
        for wm_class, group in running_groups.items():
            if wm_class not in pinned_classes and group.wm_class.lower() not in pinned_classes:
                item = TaskbarItem(self, wm_class, app_group=group)
                self.items[wm_class] = item
                self.running_box.append(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        print(f"[Panel] 🔄 Rebuilt: {len(self.items)} items")
        return False
    
    def _update_ui(self):
        """Update existing items"""
        if not self.tracker:
            return False
        
        running_groups = {g.wm_class.lower(): g for g in self.tracker.get_app_groups()}
        pinned_classes = set()
        
        if self.pinned_manager:
            for p in self.pinned_manager.get_pinned_apps():
                if p.wm_class:
                    pinned_classes.add(p.wm_class.lower())
                pinned_classes.add(p.app_id.lower())
        
        for app_id, item in list(self.items.items()):
            wm_class = item._get_wm_class().lower()
            app_group = running_groups.get(app_id.lower()) or running_groups.get(wm_class)
            item.update(app_group)
        
        current_ids = set(self.items.keys())
        for wm_class in running_groups:
            if wm_class not in current_ids and wm_class not in pinned_classes:
                group = running_groups[wm_class]
                if group.wm_class.lower() not in pinned_classes:
                    item = TaskbarItem(self, wm_class, app_group=group)
                    self.items[wm_class] = item
                    self.running_box.append(item)
        
        for app_id in list(self.items.keys()):
            if app_id.lower() not in pinned_classes and app_id.lower() not in running_groups:
                item = self.items.pop(app_id)
                self.running_box.remove(item)
        
        has_pinned = self.pinned_box.get_first_child() is not None
        has_running = self.running_box.get_first_child() is not None
        self.separator.set_visible(has_pinned and has_running)
        
        return False
    
    # ═══════════════════════════════════════════════════════════════════════
    # ACTIONS
    # ═══════════════════════════════════════════════════════════════════════
    
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
    
    def launch_app(self, app_id: str, app_info: Optional[AppInfo] = None):
        """
        Launch an app with smart detection.
        
        Priority:
        1. Use provided AppInfo if available
        2. Detect app type automatically
        3. Fall back to direct execution
        """
        print(f"[Panel] 🚀 Launching: {app_id}")
        
        # Use provided app_info or detect
        if not app_info:
            app_info = AppDetector.find_app(app_id)
        
        if app_info:
            return self._launch_with_info(app_info)
        
        # No desktop file found - try smart fallback
        print(f"[Panel] ⚠️ No .desktop found for {app_id}, trying smart detection...")
        
        # Check if it's a flatpak
        is_flatpak, flatpak_id = AppDetector.is_flatpak_installed(app_id)
        if is_flatpak and flatpak_id:
            print(f"[Panel] 📦 Found as Flatpak: {flatpak_id}")
            return self._exec_command(f"flatpak run {flatpak_id}")
        
        # Check if it's native
        if AppDetector.is_native_installed(app_id):
            print(f"[Panel] 💻 Found as native: {app_id}")
            return self._exec_command(app_id)
        
        # Last resort: try direct execution
        print(f"[Panel] ❓ Unknown app, trying direct: {app_id}")
        return self._exec_command(app_id)
    
    def _launch_with_info(self, app_info: AppInfo) -> bool:
        """Launch app using detected AppInfo"""
        cmd = AppDetector.get_launch_command(app_info)
        
        type_names = {
            AppType.FLATPAK: "Flatpak",
            AppType.SNAP: "Snap",
            AppType.APPIMAGE: "AppImage",
            AppType.NATIVE: "Native",
        }
        
        print(f"[Panel] 🚀 {type_names.get(app_info.app_type, 'Unknown')}: {app_info.name}")
        print(f"[Panel] 📝 Command: {cmd}")
        
        # Handle terminal apps
        if app_info.terminal:
            term = os.environ.get("TERMINAL", "kitty")
            cmd = f"{term} -e {cmd}"
            print(f"[Panel] 🖥️ Terminal wrapped: {cmd}")
        
        success = self._exec_command(cmd)
        
        if not success:
            # Fallback: try gtk-launch
            try:
                desktop_name = app_info.desktop_file.stem if app_info.desktop_file else app_info.app_id
                print(f"[Panel] 🔄 Fallback: gtk-launch {desktop_name}")
                subprocess.Popen(
                    ["gtk-launch", desktop_name],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                return True
            except:
                pass
        
        return success
    
    def _exec_command(self, cmd: str) -> bool:
        """Execute command via hyprctl"""
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "exec", cmd],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return True
        except Exception as e:
            print(f"[Panel] ❌ Exec failed: {e}")
            return False
    
    def pin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.pin_app(app_id)
    
    def unpin_app(self, app_id: str):
        if self.pinned_manager:
            self.pinned_manager.unpin_app(app_id)

    def cleanup(self):
        if hasattr(self, '_close_timer_id') and self._close_timer_id:
            GLib.source_remove(self._close_timer_id)
        if self.tracker:
            self.tracker.stop()
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)


def main():
    print("""
╔══════════════════════════════════════════════════════════════════════╗
║       HYPRLAND PANEL - Waybar Overlay Taskbar                        ║
║       ─────────────────────────────────────────────────────────────  ║
║       ✅ Auto-detection: Flatpak, Pacman/AUR, Snap, AppImage         ║
║       ✅ Smart app matching with scoring system                      ║
║       ✅ Theme sync from Waybar + Hyprland                           ║
║       ✅ Auto-close when mouse leaves panel                          ║
╚══════════════════════════════════════════════════════════════════════╝
""")
    
    if not HAS_MODULES:
        print("[Panel] ❌ Missing required modules!")
        return
    
    # Check which module name to use
    reader = get_waybar_reader()
    module_name = "custom/panel"
    
    for name in ["custom/panel", "custom/taskbar", "wlr/taskbar"]:
        if reader.has_module(name):
            module_name = name
            break
    
    print(f"[Panel] Using module: {module_name}")
    
    panel = PanelWidget(module_name)
    panel.present()
    
    print("[Panel] ✅ Panel started!")
    
    loop = GLib.MainLoop()
    
    def on_destroy(win):
        panel.cleanup()
        loop.quit()
    
    panel.connect("destroy", on_destroy)
    
    try:
        loop.run()
    except KeyboardInterrupt:
        print("\n[Panel] Shutting down...")
        panel.cleanup()
        loop.quit()


if __name__ == "__main__":
    main()