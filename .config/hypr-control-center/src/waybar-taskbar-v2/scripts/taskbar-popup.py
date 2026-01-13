#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
Taskbar Item Popup - Shows real PNG icon + actions on click
═══════════════════════════════════════════════════════════════════════════════

Usage: taskbar-popup.py <app_id> [--index N]

Called by waybar-taskbar C++ module on click.
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf

import json
import os
import sys
import subprocess
from pathlib import Path

# Try layer shell
try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell as LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False

# Add panel directory to path for imports
panel_dir = Path.home() / ".config/hypr-control-center/src/panel"
if panel_dir.exists():
    sys.path.insert(0, str(panel_dir))

# Try to import icon resolver
try:
    from icon_resolver import get_resolver
    HAS_RESOLVER = True
except ImportError:
    HAS_RESOLVER = False
    print("[Popup] Warning: icon_resolver not found")


class TaskbarPopup(Gtk.ApplicationWindow):
    """Popup window showing app info and actions"""
    
    def __init__(self, app, item_data: dict):
        super().__init__(application=app)
        
        self.item = item_data
        self.app_id = item_data.get('app_id', '')
        self.wm_class = item_data.get('wm_class', self.app_id)
        self.is_running = item_data.get('is_running', False)
        self.is_pinned = item_data.get('is_pinned', False)
        self.is_focused = item_data.get('is_focused', False)
        self.window_count = item_data.get('window_count', 0)
        self.icon_path = item_data.get('icon_path', '')
        
        # Get mouse position
        self.mouse_x, self.mouse_y = self._get_mouse_pos()
        
        # Setup window
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(280, -1)
        
        # Layer shell - position ABOVE taskbar (bottom-left of screen, above waybar)
        if HAS_LAYER_SHELL:
            LayerShell.init_for_window(self)
            LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
            LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.ON_DEMAND)
            
            # Anchor to BOTTOM-LEFT (above waybar)
            LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
            LayerShell.set_anchor(self, LayerShell.Edge.LEFT, True)
            LayerShell.set_anchor(self, LayerShell.Edge.TOP, False)
            LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, False)
            
            # Margin from bottom (waybar height + gap)
            LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, 60)
            LayerShell.set_margin(self, LayerShell.Edge.LEFT, 10)
        
        self._build_ui()
        self._apply_css()
        self._setup_close_handlers()
    
    def _get_mouse_pos(self):
        """Get mouse position via hyprctl"""
        try:
            result = subprocess.run(
                ['hyprctl', 'cursorpos', '-j'],
                capture_output=True, text=True, timeout=1
            )
            data = json.loads(result.stdout)
            return data.get('x', 500), data.get('y', 500)
        except:
            return 500, 500
    
    def _build_ui(self):
        """Build popup UI"""
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        main_box.set_margin_top(16)
        main_box.set_margin_bottom(16)
        main_box.set_margin_start(16)
        main_box.set_margin_end(16)
        main_box.add_css_class('popup-container')
        
        # Header with icon and name
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        header.set_halign(Gtk.Align.START)
        
        # Icon - try real PNG first
        icon_widget = self._create_icon(64)
        header.append(icon_widget)
        
        # Info
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        info_box.set_valign(Gtk.Align.CENTER)
        
        # App name
        name = self.app_id.replace('-', ' ').replace('_', ' ').title()
        name_label = Gtk.Label(label=name)
        name_label.add_css_class('app-name')
        name_label.set_halign(Gtk.Align.START)
        info_box.append(name_label)
        
        # Status line
        status_parts = []
        if self.is_pinned:
            status_parts.append("📌 Pinned")
        if self.is_running:
            status_parts.append(f"▶ {self.window_count} window{'s' if self.window_count != 1 else ''}")
        if self.is_focused:
            status_parts.append("● Focused")
        
        status_text = " · ".join(status_parts) if status_parts else "Not running"
        status_label = Gtk.Label(label=status_text)
        status_label.add_css_class('app-status')
        status_label.set_halign(Gtk.Align.START)
        info_box.append(status_label)
        
        header.append(info_box)
        main_box.append(header)
        
        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        main_box.append(sep)
        
        # Actions
        actions_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        
        if self.is_running:
            # Focus
            focus_btn = self._make_action_btn("▶  Focus Window", self._on_focus)
            actions_box.append(focus_btn)
            
            # Close all
            close_btn = self._make_action_btn("✕  Close All Windows", self._on_close)
            actions_box.append(close_btn)
        else:
            # Launch
            launch_btn = self._make_action_btn("▶  Launch Application", self._on_launch)
            actions_box.append(launch_btn)
        
        # Pin/Unpin
        pin_text = "📍  Unpin from Taskbar" if self.is_pinned else "📌  Pin to Taskbar"
        pin_btn = self._make_action_btn(pin_text, self._on_toggle_pin)
        actions_box.append(pin_btn)
        
        main_box.append(actions_box)
        self.set_child(main_box)
    
    def _create_icon(self, size: int) -> Gtk.Widget:
        """Create icon widget - try real icon first, fallback to generic"""
        # Try icon_path from state
        if self.icon_path and os.path.exists(self.icon_path):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    self.icon_path, size, size, True
                )
                texture = Gdk.Texture.new_for_pixbuf(pixbuf)
                img = Gtk.Image.new_from_paintable(texture)
                img.set_pixel_size(size)
                return img
            except Exception as e:
                print(f"[Popup] Icon load error: {e}")
        
        # Try icon resolver
        if HAS_RESOLVER:
            try:
                resolver = get_resolver()
                icon_path = resolver.get_icon_path(self.wm_class, size)
                if not icon_path:
                    icon_path = resolver.get_icon_path(self.app_id, size)
                
                if icon_path and os.path.exists(icon_path):
                    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                        icon_path, size, size, True
                    )
                    texture = Gdk.Texture.new_for_pixbuf(pixbuf)
                    img = Gtk.Image.new_from_paintable(texture)
                    img.set_pixel_size(size)
                    return img
            except Exception as e:
                print(f"[Popup] Resolver error: {e}")
        
        # Fallback to GTK icon theme
        img = Gtk.Image.new_from_icon_name('application-x-executable')
        img.set_pixel_size(size)
        return img
    
    def _make_action_btn(self, label: str, callback) -> Gtk.Button:
        btn = Gtk.Button(label=label)
        btn.add_css_class('action-btn')
        btn.connect('clicked', callback)
        return btn
    
    def _apply_css(self):
        css = b'''
        window {
            background: transparent;
        }
        
        .popup-container {
            background: alpha(#1a1b26, 0.95);
            border-radius: 16px;
            border: 1px solid alpha(#c0caf5, 0.1);
            box-shadow: 0 8px 32px rgba(0,0,0,0.4);
        }
        
        .app-name {
            font-size: 16px;
            font-weight: bold;
            color: #c0caf5;
        }
        
        .app-status {
            font-size: 12px;
            color: #565f89;
        }
        
        .action-btn {
            background: transparent;
            border: none;
            border-radius: 8px;
            padding: 10px 14px;
            color: #c0caf5;
            font-size: 14px;
            min-height: 36px;
        }
        
        .action-btn:hover {
            background: alpha(#7aa2f7, 0.2);
        }
        
        separator {
            background: alpha(#414868, 0.5);
            min-height: 1px;
            margin: 8px 0;
        }
        '''
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _setup_close_handlers(self):
        """Close on focus lost or Escape"""
        # Focus lost
        focus_ctrl = Gtk.EventControllerFocus()
        focus_ctrl.connect('leave', lambda c: GLib.timeout_add(100, self.close))
        self.add_controller(focus_ctrl)
        
        # Escape key
        key_ctrl = Gtk.EventControllerKey()
        key_ctrl.connect('key-pressed', self._on_key)
        self.add_controller(key_ctrl)
    
    def _on_key(self, ctrl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False
    
    def _run_cmd(self, *args):
        """Run waybar-taskbar command"""
        taskbar_bin = Path.home() / ".config/hypr-control-center/src/waybar-taskbar/waybar-taskbar"
        if not taskbar_bin.exists():
            taskbar_bin = Path.home() / ".config/waybar/scripts/waybar-taskbar"
        
        cmd = [str(taskbar_bin)] + list(args)
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    def _on_focus(self, btn):
        self._run_cmd('focus', self.wm_class)
        self.close()
    
    def _on_launch(self, btn):
        self._run_cmd('launch', self.app_id)
        self.close()
    
    def _on_close(self, btn):
        self._run_cmd('close', self.wm_class)
        self.close()
    
    def _on_toggle_pin(self, btn):
        self._run_cmd('pin', self.app_id)
        self.close()


class PopupApp(Gtk.Application):
    def __init__(self, item_data: dict):
        super().__init__(application_id='com.hypr.taskbar.popup')
        self.item_data = item_data
    
    def do_activate(self):
        popup = TaskbarPopup(self, self.item_data)
        popup.present()


def load_state() -> list:
    """Load taskbar state from runtime file"""
    runtime_dir = os.environ.get('XDG_RUNTIME_DIR', '/tmp')
    state_file = Path(runtime_dir) / 'waybar-taskbar' / 'state.json'
    
    if not state_file.exists():
        return []
    
    try:
        with open(state_file) as f:
            return json.load(f)
    except Exception as e:
        print(f"[Popup] Error loading state: {e}")
        return []


def find_item(items: list, identifier: str) -> dict:
    """Find item by app_id, wm_class, or index"""
    # Try as index
    try:
        idx = int(identifier)
        for item in items:
            if item.get('index') == idx:
                return item
    except ValueError:
        pass
    
    # Try as app_id or wm_class
    identifier_lower = identifier.lower()
    for item in items:
        if item.get('app_id', '').lower() == identifier_lower:
            return item
        if item.get('wm_class', '').lower() == identifier_lower:
            return item
    
    return {}


def main():
    if len(sys.argv) < 2:
        print("Usage: taskbar-popup.py <app_id|index>")
        print("  Shows popup for taskbar item")
        sys.exit(1)
    
    identifier = sys.argv[1]
    
    # Load state
    items = load_state()
    if not items:
        print("[Popup] No taskbar state found")
        sys.exit(1)
    
    # Find item
    item = find_item(items, identifier)
    if not item:
        print(f"[Popup] Item not found: {identifier}")
        sys.exit(1)
    
    print(f"[Popup] Showing: {item.get('app_id')} (running={item.get('is_running')})")
    
    # Run popup
    app = PopupApp(item)
    app.run([])


if __name__ == '__main__':
    main()