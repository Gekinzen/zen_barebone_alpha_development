"""WORKSPACE SECTION - Hyprland Workspace Configuration
Controls workspace orientation, multi-monitor behavior, and workspace settings.

═══════════════════════════════════════════════════════════════════════════════
FEATURES:
═══════════════════════════════════════════════════════════════════════════════
- Workspace Orientation: Vertical (default) or Horizontal arrangements
- Multi-Monitor Behavior: 
  * Independent: Each monitor has WS 1-5 separately (requires plugin)
  * Shared: Workspaces can move freely between monitors
  * Bound: WS 1-5 on Monitor 1, WS 6-10 on Monitor 2
- Persistent Workspaces: Configure per-monitor workspace counts
- Layout Options: Dwindle/Master layout settings
═══════════════════════════════════════════════════════════════════════════════
"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import json, subprocess, re, os
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ═══════════════════════════════════════════════════════════════════════════════
# DYNAMIC PATHS
# ═══════════════════════════════════════════════════════════════════════════════

HOME = Path.home()
USERNAME = HOME.name
HYPR_CONFIG = HOME / ".config/hypr/hyprland.conf"
HYPR_CONF_DIR = HOME / ".config/hypr"
HYPR_CONTROL_CENTER = HOME / ".config/hypr-control-center"
PREFERENCES_DIR = HYPR_CONTROL_CENTER / "preferences"

# Import shared UI components
try:
    from .ui_components import create_section_header, create_setting_row
    from .helpers import get_monitor_list
except ImportError:
    from ui_components import create_section_header, create_setting_row
    from helpers import get_monitor_list

# ═══════════════════════════════════════════════════════════════════════════════
# WORKSPACE ORIENTATION OPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

ORIENTATION_OPTIONS = {
    "vertical": {
        "name": "Vertical (Top/Bottom)",
        "description": "Windows split vertically - new windows appear below",
        "dwindle_force_split": 2,
        "master_orientation": "top"
    },
    "horizontal": {
        "name": "Horizontal (Left/Right)", 
        "description": "Windows split horizontally - new windows appear to the right",
        "dwindle_force_split": 1,
        "master_orientation": "left"
    },
    "auto": {
        "name": "Auto (Follow Mouse)",
        "description": "Split direction follows mouse position",
        "dwindle_force_split": 0,
        "master_orientation": "left"
    }
}

MONITOR_BEHAVIOR_OPTIONS = {
    "independent": {
        "name": "Independent (1-5 per monitor)",
        "description": "Each monitor has its own WS 1-5. Requires split-monitor-workspaces plugin.",
        "needs_plugin": True,
        "plugin_name": "split-monitor-workspaces"
    },
    "shared": {
        "name": "Shared Workspaces",
        "description": "Workspaces move freely between monitors. WS 1-10 available on any monitor."
    },
    "bound": {
        "name": "Bound (Split by Monitor)",
        "description": "WS 1-5 stays on Monitor 1, WS 6-10 stays on Monitor 2."
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# HYPRLAND CONFIG READING/WRITING
# ═══════════════════════════════════════════════════════════════════════════════

def read_hyprland_config() -> str:
    """Read the main hyprland.conf file"""
    try:
        if HYPR_CONFIG.exists():
            return HYPR_CONFIG.read_text()
    except Exception as e:
        print(f"Error reading hyprland.conf: {e}")
    return ""


def get_config_value(config: str, section: str, key: str, default: str = "") -> str:
    """Extract a value from hyprland config"""
    try:
        # Try section format: section { ... key = value ... }
        section_pattern = rf'{section}\s*\{{([^}}]*)\}}'
        section_match = re.search(section_pattern, config, re.DOTALL | re.IGNORECASE)
        
        if section_match:
            section_content = section_match.group(1)
            key_pattern = rf'{key}\s*=\s*([^\n,}}]+)'
            key_match = re.search(key_pattern, section_content, re.IGNORECASE)
            if key_match:
                return key_match.group(1).strip()
        
        # Try top-level: key = value
        top_pattern = rf'^{key}\s*=\s*(.+)$'
        top_match = re.search(top_pattern, config, re.MULTILINE | re.IGNORECASE)
        if top_match:
            return top_match.group(1).strip()
            
    except Exception as e:
        print(f"Error getting config value {section}.{key}: {e}")
    
    return default


def set_config_value(section: str, key: str, value: str) -> bool:
    """Set a value in hyprland config"""
    try:
        config = read_hyprland_config()
        if not config:
            return False
        
        # Try to find and update in section
        section_pattern = rf'({section}\s*\{{[^}}]*){key}\s*=\s*[^\n,}}]+([^}}]*\}})'
        
        if re.search(section_pattern, config, re.DOTALL | re.IGNORECASE):
            new_config = re.sub(
                section_pattern,
                rf'\g<1>{key} = {value}\g<2>',
                config,
                flags=re.DOTALL | re.IGNORECASE
            )
        else:
            section_check = rf'{section}\s*\{{'
            if re.search(section_check, config, re.IGNORECASE):
                new_config = re.sub(
                    rf'({section}\s*\{{)',
                    rf'\g<1>\n    {key} = {value}',
                    config,
                    flags=re.IGNORECASE
                )
            else:
                new_config = config + f"\n\n{section} {{\n    {key} = {value}\n}}\n"
        
        HYPR_CONFIG.write_text(new_config)
        reload_hyprland()
        return True
        
    except Exception as e:
        print(f"Error setting config {section}.{key} = {value}: {e}")
        return False


def reload_hyprland():
    """Reload Hyprland configuration"""
    subprocess.run(['hyprctl', 'reload'], capture_output=True)


# ═══════════════════════════════════════════════════════════════════════════════
# PLUGIN MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

def check_plugin_installed(plugin_name: str) -> bool:
    """Check if a Hyprland plugin is installed and loaded"""
    try:
        result = subprocess.run(['hyprctl', 'plugins', 'list'], capture_output=True, text=True)
        return plugin_name in result.stdout.lower()
    except:
        return False


def get_plugin_status() -> dict:
    """Get status of split-monitor-workspaces plugin"""
    installed = check_plugin_installed("split-monitor-workspaces")
    
    # Also check if it's in hyprland.conf
    config = read_hyprland_config()
    configured = "split-monitor-workspaces" in config or "hyprsplit" in config
    
    return {
        "installed": installed,
        "configured": configured,
        "active": installed and configured
    }


def enable_split_monitor_plugin() -> bool:
    """Enable split-monitor-workspaces plugin in config"""
    try:
        config = read_hyprland_config()
        
        # Check if already has plugin line
        if "plugin = split-monitor-workspaces" in config:
            return True
        
        # Add plugin line
        plugin_line = "\n# Independent workspaces per monitor\nplugin = split-monitor-workspaces\n"
        
        # Add after other plugins or at the start
        if "plugin =" in config:
            # Add after last plugin line
            lines = config.split('\n')
            new_lines = []
            added = False
            for i, line in enumerate(lines):
                new_lines.append(line)
                if line.strip().startswith("plugin =") and not added:
                    # Check if next line is also plugin
                    if i + 1 < len(lines) and not lines[i + 1].strip().startswith("plugin ="):
                        new_lines.append("plugin = split-monitor-workspaces")
                        added = True
            if not added:
                new_lines.append("plugin = split-monitor-workspaces")
            config = '\n'.join(new_lines)
        else:
            # Add at the beginning after any source lines
            config = plugin_line + config
        
        HYPR_CONFIG.write_text(config)
        reload_hyprland()
        return True
        
    except Exception as e:
        print(f"Error enabling plugin: {e}")
        return False


def disable_split_monitor_plugin() -> bool:
    """Disable split-monitor-workspaces plugin"""
    try:
        config = read_hyprland_config()
        
        # Remove plugin line
        config = re.sub(r'\n?#[^\n]*independent workspaces[^\n]*\n?', '\n', config, flags=re.IGNORECASE)
        config = re.sub(r'\n?plugin\s*=\s*split-monitor-workspaces\n?', '\n', config, flags=re.IGNORECASE)
        
        HYPR_CONFIG.write_text(config)
        reload_hyprland()
        return True
        
    except Exception as e:
        print(f"Error disabling plugin: {e}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# WORKSPACE SETTINGS FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def get_current_orientation() -> str:
    """Get current workspace orientation setting"""
    config = read_hyprland_config()
    force_split = get_config_value(config, "dwindle", "force_split", "0")
    
    try:
        fs_int = int(force_split)
        if fs_int == 2:
            return "vertical"
        elif fs_int == 1:
            return "horizontal"
    except:
        pass
    
    return "auto"


def set_orientation(orientation: str) -> bool:
    """Set workspace orientation"""
    if orientation not in ORIENTATION_OPTIONS:
        return False
    
    opts = ORIENTATION_OPTIONS[orientation]
    success = set_config_value("dwindle", "force_split", str(opts["dwindle_force_split"]))
    set_config_value("master", "orientation", opts["master_orientation"])
    save_workspace_preference("orientation", orientation)
    
    return success


def get_current_monitor_behavior() -> str:
    """Get current multi-monitor workspace behavior"""
    # Check if split-monitor-workspaces plugin is active
    plugin_status = get_plugin_status()
    if plugin_status["active"]:
        return "independent"
    
    # Check for workspace bindings
    config = read_hyprland_config()
    if re.search(r'workspace\s*=\s*\d+,\s*monitor:', config):
        return "bound"
    
    return "shared"


def set_monitor_behavior(behavior: str, monitors: List[str] = None) -> bool:
    """Set multi-monitor workspace behavior"""
    if behavior not in MONITOR_BEHAVIOR_OPTIONS:
        return False
    
    try:
        config = read_hyprland_config()
        
        # Remove existing workspace monitor bindings
        config = re.sub(r'\n?#[^\n]*Workspace Monitor Bindings[^\n]*\n?', '\n', config)
        config = re.sub(r'\n?#[^\n]*Auto-generated[^\n]*\n?', '\n', config)
        config = re.sub(r'workspace\s*=\s*\d+,\s*monitor:[^\n]+\n?', '', config)
        config = re.sub(r'workspace\s*=\s*\d+,\s*persistent:true,\s*monitor:[^\n]+\n?', '', config)
        
        if behavior == "independent":
            # Enable split-monitor-workspaces plugin
            enable_split_monitor_plugin()
            
        elif behavior == "bound" and monitors and len(monitors) >= 2:
            # Disable plugin if enabled
            disable_split_monitor_plugin()
            
            # WS 1-5 on Monitor 1, WS 6-10 on Monitor 2
            bindings = []
            bindings.append("\n# Workspace Monitor Bindings (Auto-generated)")
            
            for ws in range(1, 6):
                bindings.append(f"workspace = {ws}, monitor:{monitors[0]}, persistent:true")
            
            for ws in range(6, 11):
                bindings.append(f"workspace = {ws}, monitor:{monitors[1]}, persistent:true")
            
            config += "\n".join(bindings) + "\n"
            
        else:  # shared
            # Disable plugin, remove all bindings
            disable_split_monitor_plugin()
        
        HYPR_CONFIG.write_text(config)
        reload_hyprland()
        save_workspace_preference("monitor_behavior", behavior)
        
        # Sync to waybar
        sync_waybar_workspaces(monitors or [], behavior)
        
        return True
        
    except Exception as e:
        print(f"Error setting monitor behavior: {e}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# PREFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

def load_workspace_preferences() -> dict:
    """Load saved workspace preferences"""
    prefs_file = PREFERENCES_DIR / "workspace-settings.json"
    if prefs_file.exists():
        try:
            return json.loads(prefs_file.read_text())
        except:
            pass
    return {}


def save_workspace_preference(key: str, value):
    """Save a workspace preference"""
    PREFERENCES_DIR.mkdir(parents=True, exist_ok=True)
    prefs_file = PREFERENCES_DIR / "workspace-settings.json"
    
    prefs = load_workspace_preferences()
    prefs[key] = value
    
    prefs_file.write_text(json.dumps(prefs, indent=2))


# ═══════════════════════════════════════════════════════════════════════════════
# WAYBAR INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

def sync_waybar_workspaces(monitors: List[str], behavior: str):
    """Sync workspace settings to waybar config"""
    try:
        from . import waybar_section
        waybar_config = waybar_section.read_waybar_config()
        
        if "hyprland/workspaces" in waybar_config:
            ws = waybar_config["hyprland/workspaces"]
            
            if behavior == "independent":
                # Each monitor shows its own 1-5
                ws["show-special"] = False
                ws["all-outputs"] = False
                # Update persistent workspaces for plugin
                ws["persistent-workspaces"] = {"*": 5}
            elif behavior == "bound":
                # Show only workspaces for this monitor
                ws["all-outputs"] = False
                ws["persistent-workspaces"] = {"*": 5}
            else:  # shared
                ws["all-outputs"] = True
                ws["persistent-workspaces"] = {"*": 5}
            
            waybar_config_file = waybar_section.WAYBAR_CONFIG
            waybar_config_file.write_text(json.dumps(waybar_config, indent=4, ensure_ascii=False))
            subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
            
    except Exception as e:
        print(f"Error syncing waybar workspaces: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# UI BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_workspace_section(window) -> Gtk.Box:
    """Build the Workspace configuration section"""
    main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    main_box.set_margin_start(16)
    main_box.set_margin_end(16)
    main_box.set_margin_top(16)
    main_box.set_margin_bottom(16)
    
    # Get current settings
    current_orientation = get_current_orientation()
    current_behavior = get_current_monitor_behavior()
    monitors = get_monitor_list()
    plugin_status = get_plugin_status()
    
    if not hasattr(window, 'workspace_ui'):
        window.workspace_ui = {}
    
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WORKSPACE ORIENTATION
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("WORKSPACE ORIENTATION"))
    
    orient_desc = Gtk.Label()
    orient_desc.set_markup("<small>Choose how windows are arranged when splitting</small>")
    orient_desc.add_css_class("dim-label")
    orient_desc.set_xalign(0)
    orient_desc.set_margin_start(8)
    orient_desc.set_margin_bottom(8)
    content.append(orient_desc)
    
    # Orientation dropdown
    orient_row = create_setting_row("Split Direction", "How new windows are positioned")
    
    orient_ids = list(ORIENTATION_OPTIONS.keys())
    orient_names = [ORIENTATION_OPTIONS[o]["name"] for o in orient_ids]
    
    orient_dd = Gtk.DropDown()
    orient_dd.set_model(Gtk.StringList.new(orient_names))
    orient_dd.set_selected(orient_ids.index(current_orientation) if current_orientation in orient_ids else 0)
    orient_dd.set_size_request(220, -1)
    
    orient_detail = Gtk.Label()
    orient_detail.set_markup(f"<small>{ORIENTATION_OPTIONS[current_orientation]['description']}</small>")
    orient_detail.add_css_class("dim-label")
    orient_detail.set_xalign(0)
    orient_detail.set_margin_start(8)
    orient_detail.set_wrap(True)
    
    def on_orientation_change(dd, _):
        idx = dd.get_selected()
        if idx < len(orient_ids):
            orient_id = orient_ids[idx]
            if set_orientation(orient_id):
                orient_detail.set_markup(f"<small>{ORIENTATION_OPTIONS[orient_id]['description']}</small>")
                if hasattr(window, '_show_toast'):
                    window._show_toast(f"Orientation: {ORIENTATION_OPTIONS[orient_id]['name']}")
    
    orient_dd.connect('notify::selected', on_orientation_change)
    window.workspace_ui['orientation_dropdown'] = orient_dd
    
    orient_row.append(orient_dd)
    content.append(orient_row)
    content.append(orient_detail)
    
    # Visual preview
    preview_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
    preview_box.set_margin_top(8)
    preview_box.set_margin_start(8)
    preview_box.set_halign(Gtk.Align.CENTER)
    
    # Vertical preview
    v_frame = Gtk.Frame()
    v_frame.add_css_class("card")
    v_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    v_box.set_margin_start(8)
    v_box.set_margin_end(8)
    v_box.set_margin_top(8)
    v_box.set_margin_bottom(8)
    
    v_label = Gtk.Label(label="Vertical")
    v_label.add_css_class("caption")
    v_box.append(v_label)
    
    v_preview = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    for _ in range(2):
        bar = Gtk.Box()
        bar.set_size_request(60, 20)
        bar.add_css_class("card")
        v_preview.append(bar)
    v_box.append(v_preview)
    v_frame.set_child(v_box)
    preview_box.append(v_frame)
    
    # Horizontal preview
    h_frame = Gtk.Frame()
    h_frame.add_css_class("card")
    h_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    h_box.set_margin_start(8)
    h_box.set_margin_end(8)
    h_box.set_margin_top(8)
    h_box.set_margin_bottom(8)
    
    h_label = Gtk.Label(label="Horizontal")
    h_label.add_css_class("caption")
    h_box.append(h_label)
    
    h_preview = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
    for _ in range(2):
        bar = Gtk.Box()
        bar.set_size_request(30, 40)
        bar.add_css_class("card")
        h_preview.append(bar)
    h_box.append(h_preview)
    h_frame.set_child(h_box)
    preview_box.append(h_frame)
    
    content.append(preview_box)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MULTI-MONITOR BEHAVIOR
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("MULTI-MONITOR BEHAVIOR"))
    
    monitor_desc = Gtk.Label()
    monitor_desc.set_markup("<small>Configure how workspaces operate across multiple screens</small>")
    monitor_desc.add_css_class("dim-label")
    monitor_desc.set_xalign(0)
    monitor_desc.set_margin_start(8)
    monitor_desc.set_margin_bottom(8)
    content.append(monitor_desc)
    
    # Show detected monitors
    if monitors:
        monitors_info = Gtk.Label()
        monitors_info.set_markup(f"<small>🖥️ Detected: <b>{', '.join(monitors)}</b></small>")
        monitors_info.add_css_class("dim-label")
        monitors_info.set_xalign(0)
        monitors_info.set_margin_start(8)
        monitors_info.set_margin_bottom(8)
        content.append(monitors_info)
    
    # Behavior dropdown
    behavior_row = create_setting_row("Workspace Mode", "How workspaces are distributed")
    
    behavior_ids = list(MONITOR_BEHAVIOR_OPTIONS.keys())
    behavior_names = [MONITOR_BEHAVIOR_OPTIONS[b]["name"] for b in behavior_ids]
    
    behavior_dd = Gtk.DropDown()
    behavior_dd.set_model(Gtk.StringList.new(behavior_names))
    behavior_dd.set_selected(behavior_ids.index(current_behavior) if current_behavior in behavior_ids else 1)
    behavior_dd.set_size_request(250, -1)
    
    behavior_detail = Gtk.Label()
    behavior_detail.set_markup(f"<small>{MONITOR_BEHAVIOR_OPTIONS[current_behavior]['description']}</small>")
    behavior_detail.add_css_class("dim-label")
    behavior_detail.set_xalign(0)
    behavior_detail.set_margin_start(8)
    behavior_detail.set_wrap(True)
    
    # Plugin status indicator
    plugin_status_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    plugin_status_box.set_margin_start(8)
    plugin_status_box.set_margin_top(4)
    
    plugin_icon = Gtk.Label()
    plugin_label = Gtk.Label()
    plugin_label.add_css_class("dim-label")
    
    def update_plugin_status_ui():
        status = get_plugin_status()
        if status["active"]:
            plugin_icon.set_text("✅")
            plugin_label.set_markup("<small>split-monitor-workspaces plugin active</small>")
        elif status["installed"]:
            plugin_icon.set_text("⚠️")
            plugin_label.set_markup("<small>Plugin installed but not configured</small>")
        else:
            plugin_icon.set_text("📦")
            plugin_label.set_markup("<small>Plugin not installed - install via hyprpm</small>")
    
    update_plugin_status_ui()
    plugin_status_box.append(plugin_icon)
    plugin_status_box.append(plugin_label)
    
    # Only show plugin status when independent is selected
    plugin_status_box.set_visible(current_behavior == "independent")
    
    def on_behavior_change(dd, _):
        idx = dd.get_selected()
        if idx < len(behavior_ids):
            behavior_id = behavior_ids[idx]
            
            # Show/hide plugin status
            plugin_status_box.set_visible(behavior_id == "independent")
            
            if set_monitor_behavior(behavior_id, monitors):
                behavior_detail.set_markup(f"<small>{MONITOR_BEHAVIOR_OPTIONS[behavior_id]['description']}</small>")
                update_plugin_status_ui()
                
                if hasattr(window, '_show_toast'):
                    window._show_toast(f"Mode: {MONITOR_BEHAVIOR_OPTIONS[behavior_id]['name']}")
    
    behavior_dd.connect('notify::selected', on_behavior_change)
    window.workspace_ui['behavior_dropdown'] = behavior_dd
    
    behavior_row.append(behavior_dd)
    content.append(behavior_row)
    content.append(behavior_detail)
    content.append(plugin_status_box)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # VISUAL EXPLANATION
    # ═══════════════════════════════════════════════════════════════════════════
    
    explain_frame = Gtk.Frame()
    explain_frame.add_css_class("card")
    explain_frame.set_margin_top(12)
    explain_frame.set_margin_start(8)
    explain_frame.set_margin_end(8)
    
    explain_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    explain_box.set_margin_start(12)
    explain_box.set_margin_end(12)
    explain_box.set_margin_top(12)
    explain_box.set_margin_bottom(12)
    
    explain_title = Gtk.Label()
    explain_title.set_markup("<b>Mode Comparison</b>")
    explain_title.set_xalign(0)
    explain_box.append(explain_title)
    
    modes_grid = Gtk.Grid()
    modes_grid.set_column_spacing(16)
    modes_grid.set_row_spacing(8)
    
    # Headers
    for col, header in enumerate(["Mode", "Monitor 1", "Monitor 2"]):
        lbl = Gtk.Label()
        lbl.set_markup(f"<b>{header}</b>")
        lbl.set_xalign(0)
        modes_grid.attach(lbl, col, 0, 1, 1)
    
    # Independent
    modes_grid.attach(Gtk.Label(label="Independent"), 0, 1, 1, 1)
    m1_ind = Gtk.Label()
    m1_ind.set_markup("<tt>WS 1,2,3,4,5</tt>")
    m1_ind.set_xalign(0)
    modes_grid.attach(m1_ind, 1, 1, 1, 1)
    m2_ind = Gtk.Label()
    m2_ind.set_markup("<tt>WS 1,2,3,4,5</tt>")
    m2_ind.set_xalign(0)
    modes_grid.attach(m2_ind, 2, 1, 1, 1)
    
    # Shared
    modes_grid.attach(Gtk.Label(label="Shared"), 0, 2, 1, 1)
    m1_sha = Gtk.Label()
    m1_sha.set_markup("<tt>WS 1-10 (any)</tt>")
    m1_sha.set_xalign(0)
    modes_grid.attach(m1_sha, 1, 2, 1, 1)
    m2_sha = Gtk.Label()
    m2_sha.set_markup("<tt>WS 1-10 (any)</tt>")
    m2_sha.set_xalign(0)
    modes_grid.attach(m2_sha, 2, 2, 1, 1)
    
    # Bound
    modes_grid.attach(Gtk.Label(label="Bound"), 0, 3, 1, 1)
    m1_bnd = Gtk.Label()
    m1_bnd.set_markup("<tt>WS 1,2,3,4,5</tt>")
    m1_bnd.set_xalign(0)
    modes_grid.attach(m1_bnd, 1, 3, 1, 1)
    m2_bnd = Gtk.Label()
    m2_bnd.set_markup("<tt>WS 6,7,8,9,10</tt>")
    m2_bnd.set_xalign(0)
    modes_grid.attach(m2_bnd, 2, 3, 1, 1)
    
    explain_box.append(modes_grid)
    explain_frame.set_child(explain_box)
    content.append(explain_frame)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ADDITIONAL SETTINGS
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("ADDITIONAL SETTINGS"))
    
    config = read_hyprland_config()
    
    # Preserve split ratio
    preserve_split = get_config_value(config, "dwindle", "preserve_split", "true") == "true"
    
    preserve_row = create_setting_row("Preserve Split Ratio", "Keep window sizes when layout changes")
    preserve_switch = Gtk.Switch()
    preserve_switch.set_active(preserve_split)
    preserve_switch.set_valign(Gtk.Align.CENTER)
    preserve_switch.connect('notify::active', lambda s, _: set_config_value("dwindle", "preserve_split", "true" if s.get_active() else "false"))
    preserve_row.append(preserve_switch)
    content.append(preserve_row)
    
    # Smart split
    smart_split = get_config_value(config, "dwindle", "smart_split", "false") == "true"
    
    smart_row = create_setting_row("Smart Split", "Split based on cursor position")
    smart_switch = Gtk.Switch()
    smart_switch.set_active(smart_split)
    smart_switch.set_valign(Gtk.Align.CENTER)
    smart_switch.connect('notify::active', lambda s, _: set_config_value("dwindle", "smart_split", "true" if s.get_active() else "false"))
    smart_row.append(smart_switch)
    content.append(smart_row)
    
    # No gaps when only one window (this is in "general" section, not "dwindle")
    no_gaps_single = get_config_value(config, "general", "no_gaps_when_only", "0") != "0"
    
    nogaps_row = create_setting_row("No Gaps When Single", "Remove gaps when only one window")
    nogaps_switch = Gtk.Switch()
    nogaps_switch.set_active(no_gaps_single)
    nogaps_switch.set_valign(Gtk.Align.CENTER)
    nogaps_switch.connect('notify::active', lambda s, _: set_config_value("general", "no_gaps_when_only", "1" if s.get_active() else "0"))
    nogaps_row.append(nogaps_switch)
    content.append(nogaps_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PLUGIN INSTALL HELP
    # ═══════════════════════════════════════════════════════════════════════════
    
    if not plugin_status["installed"]:
        content.append(create_section_header("INSTALL PLUGIN"))
        
        install_info = Gtk.Label()
        install_info.set_markup(
            "<small>To use <b>Independent</b> mode, install the plugin:\n\n"
            "<tt>hyprpm add https://github.com/Duckonaut/split-monitor-workspaces</tt>\n"
            "<tt>hyprpm enable split-monitor-workspaces</tt></small>"
        )
        install_info.add_css_class("dim-label")
        install_info.set_xalign(0)
        install_info.set_margin_start(8)
        install_info.set_selectable(True)
        content.append(install_info)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # INFO
    # ═══════════════════════════════════════════════════════════════════════════
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    info_box.set_margin_top(16)
    
    info_label = Gtk.Label()
    info_label.set_markup(f"<small>📁 Config: <tt>{HYPR_CONFIG}</tt></small>")
    info_label.add_css_class("dim-label")
    info_label.set_xalign(0)
    info_label.set_selectable(True)
    info_box.append(info_label)
    
    content.append(info_box)
    
    main_box.append(content)
    return main_box


def build_workspace_section_for_expander(window) -> Gtk.Widget:
    """Build workspace section for use in an expander"""
    try:
        content = build_workspace_section(window)
        content.set_margin_start(0)
        content.set_margin_end(0)
        content.set_margin_top(8)
        content.set_margin_bottom(8)
        return content
    except Exception as e:
        print(f"Error building workspace section: {e}")
        import traceback
        traceback.print_exc()
        
        error_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        error_box.set_margin_start(16)
        error_box.set_margin_end(16)
        
        error_label = Gtk.Label()
        error_label.set_markup(f"<span color='#e06c75'>⚠️ Error loading Workspace settings</span>")
        error_label.set_xalign(0)
        error_box.append(error_label)
        
        return error_box