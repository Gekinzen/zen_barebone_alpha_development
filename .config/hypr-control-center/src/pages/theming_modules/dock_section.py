"""
═══════════════════════════════════════════════════════════════════════════════
DOCK SECTION - Theming Module for Dock Widget
═══════════════════════════════════════════════════════════════════════════════
Version: 1.1.0

FIXES (v1.1.0):
- Position/visibility/all settings auto-apply on change (save + SIGUSR2)
- Theme Apply properly writes current-theme.json colors BEFORE dock reload
- Background color from theme profile properly syncs to dock CSS
- Debounced auto-apply to avoid spamming SIGUSR2 on rapid spin changes

Integrates into theming.py as an expander section.
Controls: position, visibility, rounding, opacity, icon size, margins.
Smart Waybar collision: auto-adjusts if dock is on same edge as Waybar.
Writes to: ~/.config/hypr-control-center/dock-config.json
Sends SIGUSR2 to running dock for live reload.

Usage in theming.py (located at src/pages/theming.py):
    from theming_modules.dock_section import is_dock_running, build_dock_section, sync_dock_with_theme
    
File location: ~/.config/hypr-control-center/src/pages/theming_modules/dock_section.py
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib

import json
import os
import signal
import subprocess
from pathlib import Path
from typing import Optional, Callable

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR = Path.home() / ".config/hypr-control-center"
DOCK_CONFIG_FILE = CONFIG_DIR / "dock-config.json"
DOCK_PID_FILE = Path("/tmp/hypr-dock.pid")
CURRENT_THEME_FILE = CONFIG_DIR / "current-theme.json"

DEFAULT_DOCK_CONFIG = {
    "position": "bottom",
    "visibility": "always",
    "icon_size": 48,
    "dock_padding": 8,
    "dock_margin": 8,
    "border_radius": 16,
    "opacity": 0.85,
    "autohide_delay_ms": 600,
    "dock_thickness": 64,
    "separator_enabled": True,
    "show_running_indicators": True,
    "centered": True,
    "stretch": False,
    "theme_sync": True,
    "item_spacing": 4,
    "item_padding": 6,
    "waybar_collision": "stack",
}


# ═══════════════════════════════════════════════════════════════════════════════
# DOCK DETECTION & COMMUNICATION
# ═══════════════════════════════════════════════════════════════════════════════

def is_dock_running() -> bool:
    """Check if dock_widget.py daemon is running"""
    try:
        if DOCK_PID_FILE.exists():
            pid = int(DOCK_PID_FILE.read_text().strip())
            os.kill(pid, 0)  # Check if process exists
            return True
    except (ProcessLookupError, ValueError, PermissionError):
        pass
    return False


def is_dock_installed() -> bool:
    """Check if dock_widget.py exists in the expected location"""
    dock_paths = [
        CONFIG_DIR / "dock_widget.py",
        CONFIG_DIR / "src" / "pages" / "dock_widget.py",
        CONFIG_DIR / "panel" / "dock_widget.py",
    ]
    return any(p.exists() for p in dock_paths)


def _load_dock_config() -> dict:
    """Load dock config, merge with defaults"""
    config = DEFAULT_DOCK_CONFIG.copy()
    if DOCK_CONFIG_FILE.exists():
        try:
            saved = json.loads(DOCK_CONFIG_FILE.read_text())
            config.update(saved)
        except Exception:
            pass
    return config


def _save_dock_config(config: dict):
    """Save dock config and notify running dock"""
    try:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        DOCK_CONFIG_FILE.write_text(json.dumps(config, indent=2))
        print(f"[dock_section] ✓ Config saved")
    except Exception as e:
        print(f"[dock_section] Config save error: {e}")


def _reload_dock():
    """Send SIGUSR2 to running dock for hot-reload"""
    try:
        if DOCK_PID_FILE.exists():
            pid = int(DOCK_PID_FILE.read_text().strip())
            os.kill(pid, 0)  # Verify alive
            os.kill(pid, signal.SIGUSR2)
            print(f"[dock_section] ✓ SIGUSR2 sent to dock PID {pid}")
            return True
    except (ProcessLookupError, ValueError, PermissionError) as e:
        print(f"[dock_section] Dock reload failed: {e}")
    return False


def _toggle_dock():
    """Send SIGUSR1 to toggle dock visibility"""
    try:
        if DOCK_PID_FILE.exists():
            pid = int(DOCK_PID_FILE.read_text().strip())
            os.kill(pid, signal.SIGUSR1)
            return True
    except Exception:
        pass
    return False


def _save_and_reload_dock(config: dict):
    """Save config + send SIGUSR2 in one call (convenience)"""
    _save_dock_config(config)
    _reload_dock()


# ═══════════════════════════════════════════════════════════════════════════════
# THEME SYNC
# ═══════════════════════════════════════════════════════════════════════════════

def sync_dock_with_theme(window, colors: dict):
    """
    Sync dock colors with current theme.
    Called from theming.py when theme changes.
    
    KEY FIX (v1.1.0): Write colors to current-theme.json BEFORE reloading dock,
    because dock_widget.py reads colors from that file.
    """
    if not hasattr(window, '_dock_config'):
        return
    
    if not window._dock_config.get("theme_sync", True):
        return
    
    # ─── Write current colors to current-theme.json so dock can read them ───
    try:
        theme_data = {}
        if CURRENT_THEME_FILE.exists():
            try:
                theme_data = json.loads(CURRENT_THEME_FILE.read_text())
            except Exception:
                theme_data = {}
        
        theme_data["colors"] = colors
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        CURRENT_THEME_FILE.write_text(json.dumps(theme_data, indent=2))
        print(f"[dock_section] ✓ Colors written to current-theme.json")
    except Exception as e:
        print(f"[dock_section] ⚠ Failed to write current-theme.json: {e}")
    
    # Now reload dock (it will pick up the new colors)
    _reload_dock()


def apply_dock_settings(window) -> bool:
    """
    Apply all dock settings from the theming UI.
    Called when user clicks "Apply Theme".
    """
    if not hasattr(window, '_dock_config'):
        return False
    
    _save_dock_config(window._dock_config)
    reloaded = _reload_dock()
    
    if reloaded:
        print("[dock_section] ✓ Dock settings applied & reloaded")
    else:
        print("[dock_section] ✓ Dock settings saved (dock not running)")
    
    return True


# ═══════════════════════════════════════════════════════════════════════════════
# DEBOUNCED AUTO-APPLY
# ═══════════════════════════════════════════════════════════════════════════════

_debounce_timer_id = None


def _debounced_save_and_reload(window, delay_ms: int = 300):
    """
    Debounced save + reload. Avoids spamming SIGUSR2 when user drags
    a slider or rapidly clicks a spinbutton.
    """
    global _debounce_timer_id
    
    if _debounce_timer_id is not None:
        GLib.source_remove(_debounce_timer_id)
        _debounce_timer_id = None
    
    def _do_apply():
        global _debounce_timer_id
        _debounce_timer_id = None
        if hasattr(window, '_dock_config'):
            _save_and_reload_dock(window._dock_config)
        return False  # Don't repeat
    
    _debounce_timer_id = GLib.timeout_add(delay_ms, _do_apply)


# ═══════════════════════════════════════════════════════════════════════════════
# UI HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

def _create_setting_row(label_text: str, description: str = "") -> Gtk.Box:
    """Create a setting row with label and optional description"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.set_margin_start(16)
    row.set_margin_end(16)
    row.set_margin_top(4)
    row.set_margin_bottom(4)
    
    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    text_box.set_hexpand(True)
    
    label = Gtk.Label(label=label_text)
    label.set_xalign(0)
    text_box.append(label)
    
    if description:
        desc = Gtk.Label(label=description)
        desc.set_xalign(0)
        desc.add_css_class("dim-label")
        desc.add_css_class("caption")
        text_box.append(desc)
    
    row.append(text_box)
    return row


def _create_section_header(text: str) -> Gtk.Label:
    """Create a section header label"""
    label = Gtk.Label(label=text)
    label.add_css_class("caption")
    label.add_css_class("dim-label")
    label.set_xalign(0)
    label.set_margin_start(16)
    label.set_margin_top(12)
    label.set_margin_bottom(4)
    return label


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SECTION BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_dock_section(window, colors: dict) -> Gtk.Box:
    """
    Build the Dock configuration section for theming.py.
    
    Returns a Gtk.Box to be placed inside an Expander.
    
    v1.1.0 CHANGES:
    - All setting changes auto-apply (debounced save + SIGUSR2)
    - Position change immediately reflects on dock
    - Visibility change immediately reflects on dock
    """
    config = _load_dock_config()
    window._dock_config = config
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    content.set_margin_start(8)
    content.set_margin_end(8)
    content.set_margin_top(8)
    content.set_margin_bottom(16)
    
    # ─── Status indicator ───────────────────────────────────────────────
    status_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    status_row.set_margin_start(16)
    status_row.set_margin_end(16)
    status_row.set_margin_bottom(12)
    
    running = is_dock_running()
    status_icon = Gtk.Label(label="🟢" if running else "🔴")
    status_row.append(status_icon)
    
    status_text = Gtk.Label(label="Dock is running" if running else "Dock is not running")
    status_text.add_css_class("dim-label")
    status_text.set_hexpand(True)
    status_text.set_xalign(0)
    status_row.append(status_text)
    
    def _update_status():
        """Refresh the status indicator"""
        is_running = is_dock_running()
        status_icon.set_text("🟢" if is_running else "🔴")
        status_text.set_text("Dock is running" if is_running else "Dock is not running")
    
    # Toggle button
    toggle_btn = Gtk.Button(label="Toggle" if running else "Start")
    toggle_btn.add_css_class("flat")
    
    def on_toggle_dock(btn):
        if is_dock_running():
            _toggle_dock()
        else:
            # Try to start dock
            dock_paths = [
                CONFIG_DIR / "dock_widget.py",
                CONFIG_DIR / "src" / "pages" / "dock_widget.py",
                CONFIG_DIR / "panel" / "dock_widget.py",
            ]
            for dp in dock_paths:
                if dp.exists():
                    try:
                        subprocess.Popen(
                            ["bash", "-c",
                             f"LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so "
                             f"python3 {dp} --daemon &"],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        # Update status after brief delay
                        GLib.timeout_add(1500, lambda: (_update_status(), False)[-1])
                    except Exception as e:
                        print(f"[dock_section] Start error: {e}")
                    break
    
    toggle_btn.connect("clicked", on_toggle_dock)
    status_row.append(toggle_btn)
    content.append(status_row)
    
    sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
    sep.set_margin_start(16)
    sep.set_margin_end(16)
    sep.set_margin_bottom(8)
    content.append(sep)
    
    # ─── Helper: auto-apply on change (debounced) ───────────────────────
    def _auto_apply():
        """Save config + reload dock with debounce"""
        _debounced_save_and_reload(window)
    
    # ─── POSITION ───────────────────────────────────────────────────────
    content.append(_create_section_header("POSITION"))
    
    # Position dropdown
    pos_row = _create_setting_row("Position", "Screen edge for the dock")
    
    positions = ["bottom", "top", "left", "right"]
    pos_dd = Gtk.DropDown()
    pos_dd.add_css_class("themed-dropdown")
    pos_model = Gtk.StringList()
    current_pos_idx = 0
    for i, p in enumerate(positions):
        pos_model.append(p.title())
        if p == config.get("position", "bottom"):
            current_pos_idx = i
    pos_dd.set_model(pos_model)
    pos_dd.set_selected(current_pos_idx)
    
    def on_position_change(dd, _):
        idx = dd.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION:
            new_pos = positions[idx]
            if window._dock_config.get("position") != new_pos:
                window._dock_config["position"] = new_pos
                _update_collision_info()
                # ── FIX: Position requires dock RESTART (layer shell can't change at runtime)
                # Save config, kill dock, restart it
                _save_dock_config(window._dock_config)
                _restart_dock()
    
    pos_dd.connect("notify::selected", on_position_change)
    pos_row.append(pos_dd)
    content.append(pos_row)
    
    # Waybar collision info
    collision_label = Gtk.Label()
    collision_label.add_css_class("dim-label")
    collision_label.add_css_class("caption")
    collision_label.set_xalign(0)
    collision_label.set_margin_start(16)
    collision_label.set_margin_bottom(8)
    collision_label.set_wrap(True)
    content.append(collision_label)
    
    def _update_collision_info():
        dock_pos = window._dock_config.get("position", "bottom")
        # Read Waybar position
        wb_pos = "bottom"
        config_paths = [
            Path.home() / ".config/waybar/config.jsonc",
            Path.home() / ".config/waybar/config.json",
        ]
        import re
        for cp in config_paths:
            if cp.exists():
                try:
                    raw = cp.read_text()
                    raw = re.sub(r'//.*$', '', raw, flags=re.MULTILINE)
                    raw = re.sub(r'/\*.*?\*/', '', raw, flags=re.DOTALL)
                    raw = re.sub(r',\s*([}\]])', r'\1', raw)
                    data = json.loads(raw)
                    if isinstance(data, list):
                        data = data[0] if data else {}
                    wb_pos = data.get("position", "bottom")
                    break
                except Exception:
                    pass
        
        if dock_pos == wb_pos:
            collision_label.set_text(
                f"⚠️ Same edge as Waybar ({wb_pos}) → Dock will stack inside"
            )
        else:
            collision_label.set_text(
                f"✅ Waybar is on {wb_pos} → No collision"
            )
    
    _update_collision_info()
    
    # Centered toggle
    center_row = _create_setting_row("Centered", "Center dock on its edge")
    center_sw = Gtk.Switch()
    center_sw.set_active(config.get("centered", True))
    center_sw.set_valign(Gtk.Align.CENTER)
    
    def on_centered_change(sw, _):
        window._dock_config["centered"] = sw.get_active()
        if sw.get_active():
            window._dock_config["stretch"] = False
            stretch_sw.set_active(False)
        _auto_apply()
    
    center_sw.connect("notify::active", on_centered_change)
    center_row.append(center_sw)
    content.append(center_row)
    
    # Stretch toggle
    stretch_row = _create_setting_row("Stretch Full Edge", "Extend dock across entire edge")
    stretch_sw = Gtk.Switch()
    stretch_sw.set_active(config.get("stretch", False))
    stretch_sw.set_valign(Gtk.Align.CENTER)
    
    def on_stretch_change(sw, _):
        window._dock_config["stretch"] = sw.get_active()
        if sw.get_active():
            window._dock_config["centered"] = False
            center_sw.set_active(False)
        _auto_apply()
    
    stretch_sw.connect("notify::active", on_stretch_change)
    stretch_row.append(stretch_sw)
    content.append(stretch_row)
    
    # ─── VISIBILITY ─────────────────────────────────────────────────────
    content.append(_create_section_header("VISIBILITY"))
    
    vis_row = _create_setting_row(
        "Visibility Mode",
        "Always = like Waybar (exclusive zone), Autohide = show on hover, Hidden = manual toggle"
    )
    
    vis_modes = ["always", "autohide", "hidden"]
    vis_labels = ["Always Show", "Autohide", "Hidden (Manual)"]
    vis_dd = Gtk.DropDown()
    vis_dd.add_css_class("themed-dropdown")
    vis_model = Gtk.StringList()
    current_vis_idx = 0
    for i, (mode, label) in enumerate(zip(vis_modes, vis_labels)):
        vis_model.append(label)
        if mode == config.get("visibility", "always"):
            current_vis_idx = i
    vis_dd.set_model(vis_model)
    vis_dd.set_selected(current_vis_idx)
    
    def on_vis_change(dd, _):
        idx = dd.get_selected()
        if idx != Gtk.INVALID_LIST_POSITION:
            new_vis = vis_modes[idx]
            if window._dock_config.get("visibility") != new_vis:
                window._dock_config["visibility"] = new_vis
                # Show/hide autohide delay based on mode
                autohide_row.set_visible(new_vis == "autohide")
                # Visibility mode change requires restart (layer shell exclusive zone)
                _save_dock_config(window._dock_config)
                _restart_dock()
    
    vis_dd.connect("notify::selected", on_vis_change)
    vis_row.append(vis_dd)
    content.append(vis_row)
    
    # Autohide delay
    autohide_row = _create_setting_row("Autohide Delay", "ms before hiding after mouse leaves")
    autohide_spin = Gtk.SpinButton.new_with_range(100, 3000, 100)
    autohide_spin.set_value(config.get("autohide_delay_ms", 600))
    autohide_spin.add_css_class("themed-spin")
    autohide_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("autohide_delay_ms", int(s.get_value())),
        _auto_apply(),
    ))
    autohide_row.append(autohide_spin)
    autohide_row.set_visible(config.get("visibility") == "autohide")
    content.append(autohide_row)
    
    # ─── APPEARANCE ─────────────────────────────────────────────────────
    content.append(_create_section_header("APPEARANCE"))
    
    # Icon size
    icon_row = _create_setting_row("Icon Size", "Size of dock icons in pixels")
    icon_spin = Gtk.SpinButton.new_with_range(24, 96, 4)
    icon_spin.set_value(config.get("icon_size", 48))
    icon_spin.add_css_class("themed-spin")
    icon_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("icon_size", int(s.get_value())),
        _auto_apply(),
    ))
    icon_row.append(icon_spin)
    content.append(icon_row)
    
    # Dock thickness
    thick_row = _create_setting_row("Dock Thickness", "Height (horizontal) or width (vertical)")
    thick_spin = Gtk.SpinButton.new_with_range(32, 128, 4)
    thick_spin.set_value(config.get("dock_thickness", 64))
    thick_spin.add_css_class("themed-spin")
    thick_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("dock_thickness", int(s.get_value())),
        _auto_apply(),
    ))
    thick_row.append(thick_spin)
    content.append(thick_row)
    
    # Border radius
    radius_row = _create_setting_row("Border Radius", "Corner rounding of the dock")
    radius_spin = Gtk.SpinButton.new_with_range(0, 40, 1)
    radius_spin.set_value(config.get("border_radius", 16))
    radius_spin.add_css_class("themed-spin")
    radius_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("border_radius", int(s.get_value())),
        _auto_apply(),
    ))
    radius_row.append(radius_spin)
    content.append(radius_row)
    
    # Opacity
    opacity_row = _create_setting_row("Background Opacity", "0 = transparent, 1 = solid")
    opacity_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05)
    opacity_scale.set_value(config.get("opacity", 0.85))
    opacity_scale.set_draw_value(True)
    opacity_scale.set_hexpand(True)
    opacity_scale.set_size_request(180, -1)
    opacity_scale.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("opacity", round(s.get_value(), 2)),
        _auto_apply(),
    ))
    opacity_row.append(opacity_scale)
    content.append(opacity_row)
    
    # Padding
    pad_row = _create_setting_row("Dock Padding", "Inner padding of the dock")
    pad_spin = Gtk.SpinButton.new_with_range(0, 24, 1)
    pad_spin.set_value(config.get("dock_padding", 8))
    pad_spin.add_css_class("themed-spin")
    pad_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("dock_padding", int(s.get_value())),
        _auto_apply(),
    ))
    pad_row.append(pad_spin)
    content.append(pad_row)
    
    # Margin from edge
    margin_row = _create_setting_row("Edge Margin", "Space from screen edge")
    margin_spin = Gtk.SpinButton.new_with_range(0, 40, 1)
    margin_spin.set_value(config.get("dock_margin", 8))
    margin_spin.add_css_class("themed-spin")
    margin_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("dock_margin", int(s.get_value())),
        _auto_apply(),
    ))
    margin_row.append(margin_spin)
    content.append(margin_row)
    
    # Item spacing
    spacing_row = _create_setting_row("Item Spacing", "Gap between dock items")
    spacing_spin = Gtk.SpinButton.new_with_range(0, 16, 1)
    spacing_spin.set_value(config.get("item_spacing", 4))
    spacing_spin.add_css_class("themed-spin")
    spacing_spin.connect("value-changed", lambda s: (
        window._dock_config.__setitem__("item_spacing", int(s.get_value())),
        _auto_apply(),
    ))
    spacing_row.append(spacing_spin)
    content.append(spacing_row)
    
    # ─── BEHAVIOR ───────────────────────────────────────────────────────
    content.append(_create_section_header("BEHAVIOR"))
    
    # Separator toggle
    sep_row = _create_setting_row("Show Separator", "Line between pinned and running apps")
    sep_sw = Gtk.Switch()
    sep_sw.set_active(config.get("separator_enabled", True))
    sep_sw.set_valign(Gtk.Align.CENTER)
    sep_sw.connect("notify::active", lambda sw, _: (
        window._dock_config.__setitem__("separator_enabled", sw.get_active()),
        _auto_apply(),
    ))
    sep_row.append(sep_sw)
    content.append(sep_row)
    
    # Running indicators
    ind_row = _create_setting_row("Running Indicators", "Show dots under running apps")
    ind_sw = Gtk.Switch()
    ind_sw.set_active(config.get("show_running_indicators", True))
    ind_sw.set_valign(Gtk.Align.CENTER)
    ind_sw.connect("notify::active", lambda sw, _: (
        window._dock_config.__setitem__("show_running_indicators", sw.get_active()),
        _auto_apply(),
    ))
    ind_row.append(ind_sw)
    content.append(ind_row)
    
    # Theme sync toggle
    sync_row = _create_setting_row("Theme Sync", "Auto-sync colors from theme")
    sync_sw = Gtk.Switch()
    sync_sw.set_active(config.get("theme_sync", True))
    sync_sw.set_valign(Gtk.Align.CENTER)
    sync_sw.connect("notify::active", lambda sw, _: (
        window._dock_config.__setitem__("theme_sync", sw.get_active()),
        _auto_apply(),
    ))
    sync_row.append(sync_sw)
    content.append(sync_row)
    
    # Waybar collision mode
    collision_row = _create_setting_row(
        "Waybar Collision",
        "Stack = auto-adjust position next to Waybar, Ignore = overlap"
    )
    col_modes = ["stack", "ignore"]
    col_labels = ["Stack (auto-adjust)", "Ignore (overlap)"]
    col_dd = Gtk.DropDown()
    col_dd.add_css_class("themed-dropdown")
    col_model = Gtk.StringList()
    current_col_idx = 0
    for i, (mode, label) in enumerate(zip(col_modes, col_labels)):
        col_model.append(label)
        if mode == config.get("waybar_collision", "stack"):
            current_col_idx = i
    col_dd.set_model(col_model)
    col_dd.set_selected(current_col_idx)
    col_dd.connect("notify::selected", lambda dd, _: (
        window._dock_config.__setitem__(
            "waybar_collision", col_modes[dd.get_selected()]
        ) if dd.get_selected() != Gtk.INVALID_LIST_POSITION else None,
        _auto_apply(),
    ))
    collision_row.append(col_dd)
    content.append(collision_row)
    
    # ─── APPLY BUTTON (manual fallback) ─────────────────────────────────
    apply_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    apply_box.set_halign(Gtk.Align.END)
    apply_box.set_margin_top(16)
    apply_box.set_margin_end(16)
    
    apply_btn = Gtk.Button()
    apply_btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    apply_btn_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
    apply_btn_label = Gtk.Label(label="Apply Dock Settings")
    apply_btn_box.append(apply_btn_icon)
    apply_btn_box.append(apply_btn_label)
    apply_btn.set_child(apply_btn_box)
    apply_btn.add_css_class("suggested-action")
    
    def on_apply_dock(btn):
        apply_dock_settings(window)
        _update_status()
    
    apply_btn.connect("clicked", on_apply_dock)
    apply_box.append(apply_btn)
    content.append(apply_box)
    
    return content


# ═══════════════════════════════════════════════════════════════════════════════
# DOCK RESTART (for position/visibility changes that need layer shell re-init)
# ═══════════════════════════════════════════════════════════════════════════════

def _restart_dock():
    """
    Kill and restart the dock daemon.
    
    Needed when position or visibility mode changes because GTK4 Layer Shell
    anchors/exclusive-zone cannot be changed after window creation — the dock
    must be recreated.
    """
    # Kill existing
    try:
        if DOCK_PID_FILE.exists():
            pid = int(DOCK_PID_FILE.read_text().strip())
            try:
                os.kill(pid, signal.SIGTERM)
                print(f"[dock_section] ✓ Sent SIGTERM to dock PID {pid}")
            except ProcessLookupError:
                pass
    except Exception:
        pass
    
    # Brief delay then restart
    def _do_restart():
        dock_paths = [
            CONFIG_DIR / "dock_widget.py",
            CONFIG_DIR / "src" / "pages" / "dock_widget.py",
            CONFIG_DIR / "panel" / "dock_widget.py",
        ]
        for dp in dock_paths:
            if dp.exists():
                try:
                    subprocess.Popen(
                        ["bash", "-c",
                         f"sleep 0.5 && LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so "
                         f"python3 {dp} --daemon &"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    print(f"[dock_section] ✓ Dock restart initiated: {dp}")
                except Exception as e:
                    print(f"[dock_section] Restart error: {e}")
                break
        return False  # Don't repeat
    
    GLib.timeout_add(300, _do_restart)


# ═══════════════════════════════════════════════════════════════════════════════
# CSS GENERATOR (for theming.py's generate functions)
# ═══════════════════════════════════════════════════════════════════════════════

def generate_dock_widget_css(colors: dict) -> str:
    """
    Generate dock-widget.css from theme colors.
    Called by theming.py's CSS generation system.
    """
    config = _load_dock_config()
    
    bg = colors.get("bg0", "#282c34")
    fg = colors.get("fg", "#abb2bf")
    accent = colors.get("blue", "#61afef")
    bg3 = colors.get("bg3", "#3e4451")
    bg4 = colors.get("bg4", "#4b5263")
    red = colors.get("red", "#e06c75")
    grey1 = colors.get("grey1", "#5c6370")
    
    opacity = config.get("opacity", 0.85)
    radius = config.get("border_radius", 16)
    padding = config.get("dock_padding", 8)
    icon_size = config.get("icon_size", 48)
    item_spacing = config.get("item_spacing", 4)
    item_padding = config.get("item_padding", 6)
    thickness = config.get("dock_thickness", 64)
    
    return f'''/* Dock Widget CSS - Auto-generated by theming.py */

#hypr-dock {{
    background: transparent;
}}

.dock-container {{
    background: alpha({bg}, {opacity});
    border-radius: {radius}px;
    border: 1px solid alpha({fg}, 0.08);
    padding: {padding}px;
}}

.dock-item {{
    background: transparent;
    border: none;
    border-radius: {max(4, radius - 4)}px;
    padding: {item_padding}px;
    margin: {item_spacing // 2}px;
    min-width: {icon_size + item_padding * 2}px;
    min-height: {icon_size + item_padding * 2}px;
    transition: all 150ms ease;
}}

.dock-item:hover {{
    background: alpha({fg}, 0.08);
}}

.dock-item.focused {{
    background: alpha({accent}, 0.12);
}}

.dock-item.not-running {{
    opacity: 0.5;
}}

.dock-item.not-running:hover {{
    opacity: 1;
}}

.dock-icon {{
    color: {fg};
}}

.dock-indicator {{
    background: {accent};
    border-radius: 50%;
    min-width: 6px;
    min-height: 6px;
    margin-bottom: 2px;
}}

.dock-item.focused .dock-indicator {{
    background: {accent};
    min-width: 8px;
}}

.dock-item.multi-window .dock-indicator {{
    min-width: 12px;
    border-radius: 3px;
}}

.dock-separator {{
    background: alpha({fg}, 0.12);
    margin: 4px;
}}

.dock-popover,
.dock-popover > contents {{
    background: alpha({bg}, {min(opacity + 0.1, 1.0)});
    border: 1px solid alpha({accent}, 0.2);
    border-radius: {radius}px;
}}

.dock-window-item {{
    background: transparent;
    border: none;
    border-radius: {max(4, radius - 4)}px;
    padding: 8px 12px;
    margin: 2px;
    color: {fg};
}}

.dock-window-item:hover {{
    background: alpha({accent}, 0.12);
}}

.focus-dot {{
    color: {accent};
}}

.close-btn:hover {{
    color: {red};
}}

tooltip {{
    background: alpha({bg}, {min(opacity + 0.1, 1.0)});
    border: 1px solid alpha({accent}, 0.15);
    border-radius: {min(radius, 8)}px;
}}

tooltip label {{
    color: {fg};
    padding: 6px 10px;
}}
'''


# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

__all__ = [
    'is_dock_running',
    'is_dock_installed',
    'build_dock_section',
    'sync_dock_with_theme',
    'apply_dock_settings',
    'generate_dock_widget_css',
]