"""
Displays Page - Monitor Configuration
Redesigned with expandable sections and working resolution/refresh rate dropdowns
Integrates with nwg-displays and hyprctl
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk
import subprocess
import json
import os
import re
from pathlib import Path
from typing import List, Dict, Optional

# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ════════════════════════════════════════════════════════════════════════════
ICONS = {
    'monitor': '󰍹',
    'monitors': '󰍺',
    'resolution': '󰩨',
    'refresh': '󰓦',
    'scale': '󰩨',
    'rotation': '󰑵',
    'position': '󰆾',
    'settings': '󰒓',
    'apply': '󰄬',
    'refresh_btn': '󰑐',
    'nwg': '󱂬',
    'primary': '󰓒',
    'enabled': '󰈈',
    'disabled': '󰈉',
    'vrr': '󱄄',
    'hdr': '󰌁',
}

# ════════════════════════════════════════════════════════════════════════════
# CUSTOM CSS
# ════════════════════════════════════════════════════════════════════════════
DISPLAYS_PAGE_CSS = """
/* Displays Page Styles */
.displays-section {
    background: alpha(@card_bg_color, 0.6);
    border-radius: 12px;
    border: 1px solid alpha(@borders, 0.3);
    margin-bottom: 12px;
    padding: 0;
}

.displays-section:hover {
    border-color: alpha(@accent_color, 0.4);
}

.displays-section-header {
    padding: 16px 20px;
    border-radius: 12px;
    transition: background 200ms ease;
}

.displays-section-header:hover {
    background: alpha(@card_bg_color, 0.8);
}

.displays-section-header.expanded {
    border-bottom: 1px solid alpha(@borders, 0.2);
    border-radius: 12px 12px 0 0;
}

.displays-section-content {
    padding: 16px 20px;
    background: alpha(@card_bg_color, 0.3);
    border-radius: 0 0 12px 12px;
}

.section-icon {
    font-size: 20px;
    min-width: 32px;
    color: @accent_color;
}

.section-title-text {
    font-size: 15px;
    font-weight: 600;
}

.section-subtitle {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.6);
}

.expand-arrow {
    font-size: 14px;
    color: alpha(@theme_fg_color, 0.5);
}

.expand-arrow.expanded {
    color: @accent_color;
}

/* Monitor Info Card */
.monitor-info-card {
    padding: 16px;
    border-radius: 10px;
    background: linear-gradient(135deg, alpha(@accent_color, 0.1), alpha(@accent_color, 0.03));
    border: 1px solid alpha(@accent_color, 0.2);
    margin-bottom: 16px;
}

.monitor-name {
    font-size: 18px;
    font-weight: 600;
    color: @theme_fg_color;
}

.monitor-description {
    font-size: 13px;
    color: alpha(@theme_fg_color, 0.7);
    margin-top: 4px;
}

.monitor-current {
    font-size: 12px;
    color: @accent_color;
    margin-top: 8px;
    font-family: monospace;
}

.monitor-badge {
    font-size: 11px;
    padding: 4px 10px;
    border-radius: 4px;
    font-weight: 500;
    background: alpha(@accent_color, 0.15);
    color: @accent_color;
}

.monitor-badge.primary {
    background: alpha(@success_color, 0.15);
    color: @success_color;
}

/* Setting Rows */
.display-setting-row {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.display-setting-row:hover {
    background: alpha(@card_bg_color, 0.7);
    border-color: alpha(@accent_color, 0.3);
}

.display-setting-icon {
    font-size: 18px;
    min-width: 28px;
    color: @accent_color;
}

.display-setting-label {
    font-size: 14px;
    font-weight: 500;
}

.display-setting-description {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.5);
}

/* Actions */
.displays-actions {
    padding: 12px 0 4px 0;
    border-top: 1px solid alpha(@borders, 0.15);
    margin-top: 12px;
}

.display-action-btn {
    padding: 8px 16px;
    border-radius: 8px;
    font-size: 13px;
}

/* Quick Actions Card */
.quick-actions-card {
    padding: 16px;
    border-radius: 10px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.quick-actions-card:hover {
    background: alpha(@card_bg_color, 0.7);
}

.subsection-divider {
    margin: 16px 0;
    background: alpha(@borders, 0.2);
}

.subsection-label {
    font-size: 12px;
    font-weight: 600;
    color: alpha(@theme_fg_color, 0.5);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 12px;
}
"""

# ════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def run_command(cmd, timeout=5):
    """Run a shell command"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, 
            text=True, timeout=timeout
        )
        return result.stdout.strip(), result.returncode == 0
    except Exception as e:
        return str(e), False


def get_monitors() -> List[Dict]:
    """Get all monitors with their info and available modes"""
    monitors = []
    
    try:
        result = subprocess.run(
            ['hyprctl', 'monitors', '-j'],
            capture_output=True,
            text=True,
            timeout=3
        )
        
        if result.returncode == 0:
            monitors_data = json.loads(result.stdout)
            
            for m in monitors_data:
                monitor_name = m.get('name', 'Unknown')
                
                # Get available modes for this monitor
                modes = get_monitor_modes(monitor_name)
                
                monitor_info = {
                    'name': monitor_name,
                    'description': m.get('description', 'Monitor'),
                    'make': m.get('make', ''),
                    'model': m.get('model', ''),
                    'serial': m.get('serial', ''),
                    'width': m.get('width', 1920),
                    'height': m.get('height', 1080),
                    'refreshRate': m.get('refreshRate', 60.0),
                    'scale': m.get('scale', 1.0),
                    'x': m.get('x', 0),
                    'y': m.get('y', 0),
                    'transform': m.get('transform', 0),
                    'focused': m.get('focused', False),
                    'dpmsStatus': m.get('dpmsStatus', True),
                    'vrr': m.get('vrr', False),
                    'activeWorkspace': m.get('activeWorkspace', {}),
                    'availableModes': modes,
                }
                monitors.append(monitor_info)
    except Exception as e:
        print(f"[Displays] Error getting monitors: {e}")
    
    return monitors


def get_monitor_modes(monitor_name: str) -> List[Dict]:
    """Get available display modes for a monitor using hyprctl"""
    modes = []
    
    try:
        # Try hyprctl monitors all for available modes
        result = subprocess.run(
            ['hyprctl', 'monitors', 'all', '-j'],
            capture_output=True,
            text=True,
            timeout=3
        )
        
        if result.returncode == 0:
            all_monitors = json.loads(result.stdout)
            
            for m in all_monitors:
                if m.get('name') == monitor_name:
                    available = m.get('availableModes', [])
                    for mode_str in available:
                        # Format: "1920x1080@60.00Hz"
                        match = re.match(r'(\d+)x(\d+)@([\d.]+)Hz', mode_str)
                        if match:
                            modes.append({
                                'width': int(match.group(1)),
                                'height': int(match.group(2)),
                                'refreshRate': float(match.group(3)),
                                'mode_str': mode_str
                            })
                    break
        
        if modes:
            # Sort by resolution (descending) then refresh rate (descending)
            modes.sort(key=lambda m: (m['width'] * m['height'], m['refreshRate']), reverse=True)
            return modes
            
    except Exception as e:
        print(f"[Displays] Error getting modes from hyprctl: {e}")
    
    # Fallback: try wlr-randr
    try:
        result = subprocess.run(['wlr-randr'], capture_output=True, text=True, timeout=3)
        
        if result.returncode == 0:
            in_monitor = False
            
            for line in result.stdout.split('\n'):
                if monitor_name in line and not line.startswith(' ') and not line.startswith('\t'):
                    in_monitor = True
                    continue
                
                if in_monitor and line and not line.startswith(' ') and not line.startswith('\t'):
                    break
                
                if in_monitor and ('x' in line and 'Hz' in line):
                    # Parse: "  1920x1080 px, 60.000000 Hz (current)"
                    line_clean = line.strip()
                    match = re.search(r'(\d+)x(\d+)\s*(?:px)?,?\s*([\d.]+)\s*Hz', line_clean)
                    if match:
                        modes.append({
                            'width': int(match.group(1)),
                            'height': int(match.group(2)),
                            'refreshRate': float(match.group(3)),
                            'mode_str': f"{match.group(1)}x{match.group(2)}@{float(match.group(3)):.2f}Hz"
                        })
            
            if modes:
                modes.sort(key=lambda m: (m['width'] * m['height'], m['refreshRate']), reverse=True)
                return modes
                
    except Exception as e:
        print(f"[Displays] Error getting modes from wlr-randr: {e}")
    
    # Final fallback: common modes
    return [
        {'width': 3840, 'height': 2160, 'refreshRate': 60.0, 'mode_str': '3840x2160@60.00Hz'},
        {'width': 2560, 'height': 1440, 'refreshRate': 144.0, 'mode_str': '2560x1440@144.00Hz'},
        {'width': 2560, 'height': 1440, 'refreshRate': 60.0, 'mode_str': '2560x1440@60.00Hz'},
        {'width': 1920, 'height': 1080, 'refreshRate': 144.0, 'mode_str': '1920x1080@144.00Hz'},
        {'width': 1920, 'height': 1080, 'refreshRate': 60.0, 'mode_str': '1920x1080@60.00Hz'},
        {'width': 1680, 'height': 1050, 'refreshRate': 60.0, 'mode_str': '1680x1050@60.00Hz'},
        {'width': 1440, 'height': 900, 'refreshRate': 60.0, 'mode_str': '1440x900@60.00Hz'},
        {'width': 1366, 'height': 768, 'refreshRate': 60.0, 'mode_str': '1366x768@60.00Hz'},
    ]


def apply_monitor_setting(monitor_name: str, width: int, height: int, refresh: float, scale: float = 1.0, transform: int = 0):
    """Apply monitor settings using hyprctl"""
    try:
        # Build the monitor command
        # Format: hyprctl keyword monitor NAME,RESxRES@RATE,POS,SCALE
        cmd = f"hyprctl keyword monitor {monitor_name},{width}x{height}@{refresh:.2f},auto,{scale}"
        
        if transform > 0:
            cmd += f",transform,{transform}"
        
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)


def write_monitors_conf(monitors_config: List[Dict]):
    """Write monitors.conf file"""
    conf_file = Path.home() / ".config" / "hypr" / "monitors.conf"
    conf_file.parent.mkdir(parents=True, exist_ok=True)
    
    lines = ["# Generated by Hyprland Control Center", ""]
    
    for config in monitors_config:
        name = config['name']
        width = config.get('width', 1920)
        height = config.get('height', 1080)
        refresh = config.get('refreshRate', 60.0)
        scale = config.get('scale', 1.0)
        x = config.get('x', 0)
        y = config.get('y', 0)
        transform = config.get('transform', 0)
        enabled = config.get('enabled', True)
        
        if enabled:
            line = f"monitor={name},{width}x{height}@{refresh:.2f},{x}x{y},{scale}"
            if transform > 0:
                line += f",transform,{transform}"
        else:
            line = f"monitor={name},disable"
        
        lines.append(line)
    
    conf_file.write_text('\n'.join(lines) + '\n')
    return True


# ════════════════════════════════════════════════════════════════════════════
# EXPANDABLE SECTION COMPONENT
# ════════════════════════════════════════════════════════════════════════════

class DisplaysExpandableSection(Gtk.Box):
    """Expandable section for displays page"""
    
    def __init__(self, icon, title, subtitle="", expanded=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('displays-section')
        
        self._expanded = expanded
        self._subtitle_label = None
        
        # Header
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.header.add_css_class('displays-section-header')
        if expanded:
            self.header.add_css_class('expanded')
        
        click_gesture = Gtk.GestureClick.new()
        click_gesture.connect('pressed', self._on_header_clicked)
        self.header.add_controller(click_gesture)
        
        # Icon
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('section-icon')
        self.header.append(icon_label)
        
        # Title box
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_box.set_hexpand(True)
        
        title_label = Gtk.Label(label=title)
        title_label.add_css_class('section-title-text')
        title_label.set_halign(Gtk.Align.START)
        title_box.append(title_label)
        
        self._subtitle_label = Gtk.Label(label=subtitle if subtitle else " ")
        self._subtitle_label.add_css_class('section-subtitle')
        self._subtitle_label.set_halign(Gtk.Align.START)
        title_box.append(self._subtitle_label)
        
        self.header.append(title_box)
        
        # Arrow
        self.arrow = Gtk.Label(label="󰅀" if expanded else "󰅂")
        self.arrow.add_css_class('expand-arrow')
        if expanded:
            self.arrow.add_css_class('expanded')
        self.header.append(self.arrow)
        
        self.append(self.header)
        
        # Content
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.content.add_css_class('displays-section-content')
        
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(200)
        self.revealer.set_reveal_child(expanded)
        self.revealer.set_child(self.content)
        
        self.append(self.revealer)
    
    def _on_header_clicked(self, gesture, n_press, x, y):
        self._expanded = not self._expanded
        self.revealer.set_reveal_child(self._expanded)
        
        if self._expanded:
            self.header.add_css_class('expanded')
            self.arrow.add_css_class('expanded')
            self.arrow.set_text("󰅀")
        else:
            self.header.remove_css_class('expanded')
            self.arrow.remove_css_class('expanded')
            self.arrow.set_text("󰅂")
    
    def set_subtitle(self, text):
        if self._subtitle_label:
            self._subtitle_label.set_text(text)
    
    def add_content(self, widget):
        self.content.append(widget)
    
    def clear_content(self):
        while self.content.get_first_child():
            self.content.remove(self.content.get_first_child())


# ════════════════════════════════════════════════════════════════════════════
# MAIN PAGE BUILDER
# ════════════════════════════════════════════════════════════════════════════

def build_displays_page(window) -> Gtk.Box:
    """Build the Displays configuration page"""
    
    # Apply CSS
    _apply_displays_css()
    
    # Main container
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32)
    page.set_margin_end(32)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Header
    header = _create_page_header(
        f"{ICONS['monitors']} Displays",
        "Configure monitors, resolution, refresh rate, and scaling"
    )
    page.append(header)
    
    # Store widgets
    window.displays_widgets = {}
    window.displays_config = {}  # Store pending changes
    
    # Get monitors
    monitors = get_monitors()
    window.displays_widgets['monitors'] = monitors
    
    if not monitors:
        # No monitors found
        _build_no_monitors_view(page)
        return page
    
    # Build section for each monitor
    for i, monitor in enumerate(monitors):
        is_first = (i == 0)
        section = _build_monitor_section(window, monitor, expanded=is_first)
        page.append(section)
    
    # Quick Actions Section
    actions_section = DisplaysExpandableSection(
        ICONS['settings'],
        "Quick Actions",
        "Apply changes and advanced settings",
        expanded=False
    )
    _build_actions_content(window, actions_section)
    page.append(actions_section)
    
    return page


def _apply_displays_css():
    """Apply custom CSS"""
    provider = Gtk.CssProvider()
    provider.load_from_data(DISPLAYS_PAGE_CSS.encode())
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )


def _create_page_header(title, subtitle):
    """Create page header"""
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    header.set_margin_bottom(24)
    
    title_label = Gtk.Label(label=title)
    title_label.add_css_class('page-title')
    title_label.set_halign(Gtk.Align.START)
    header.append(title_label)
    
    subtitle_label = Gtk.Label(label=subtitle)
    subtitle_label.add_css_class('page-subtitle')
    subtitle_label.set_halign(Gtk.Align.START)
    header.append(subtitle_label)
    
    return header


def _create_setting_row(label, description=None, widget=None, icon=None):
    """Create a setting row"""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    row.add_css_class('display-setting-row')
    
    if icon:
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('display-setting-icon')
        row.append(icon_label)
    
    label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    label_box.set_hexpand(True)
    
    main_label = Gtk.Label(label=label)
    main_label.set_halign(Gtk.Align.START)
    main_label.add_css_class('display-setting-label')
    label_box.append(main_label)
    
    if description:
        desc_label = Gtk.Label(label=description)
        desc_label.set_halign(Gtk.Align.START)
        desc_label.add_css_class('display-setting-description')
        label_box.append(desc_label)
    
    row.append(label_box)
    
    if widget:
        row.append(widget)
    
    return row


def _build_no_monitors_view(page):
    """Build view when no monitors found"""
    empty_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    empty_box.set_valign(Gtk.Align.CENTER)
    empty_box.set_vexpand(True)
    empty_box.set_halign(Gtk.Align.CENTER)
    
    icon = Gtk.Label(label=ICONS['monitor'])
    icon.set_opacity(0.3)
    icon.add_css_class('page-title')
    empty_box.append(icon)
    
    label = Gtk.Label(label="No monitors detected")
    label.add_css_class('dim-label')
    empty_box.append(label)
    
    refresh_btn = Gtk.Button(label=f"{ICONS['refresh_btn']} Refresh")
    refresh_btn.connect('clicked', lambda b: print("Refresh monitors"))
    empty_box.append(refresh_btn)
    
    page.append(empty_box)


def _build_monitor_section(window, monitor: Dict, expanded: bool = False) -> DisplaysExpandableSection:
    """Build section for a single monitor"""
    
    name = monitor['name']
    desc = monitor['description'] or f"{monitor.get('make', '')} {monitor.get('model', '')}".strip()
    current_res = f"{monitor['width']}x{monitor['height']}@{monitor['refreshRate']:.0f}Hz"
    
    section = DisplaysExpandableSection(
        ICONS['monitor'],
        name,
        f"{desc} • {current_res}",
        expanded=expanded
    )
    
    # Store reference
    window.displays_widgets[f'section_{name}'] = section
    
    # Initialize config for this monitor
    window.displays_config[name] = {
        'name': name,
        'width': monitor['width'],
        'height': monitor['height'],
        'refreshRate': monitor['refreshRate'],
        'scale': monitor['scale'],
        'transform': monitor['transform'],
        'x': monitor['x'],
        'y': monitor['y'],
        'enabled': True,
    }
    
    # Monitor Info Card
    info_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    info_card.add_css_class('monitor-info-card')
    
    # Name + badges row
    name_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    name_label = Gtk.Label(label=desc if desc else name)
    name_label.add_css_class('monitor-name')
    name_label.set_halign(Gtk.Align.START)
    name_label.set_ellipsize(3)
    name_row.append(name_label)
    
    if monitor.get('focused', False):
        primary_badge = Gtk.Label(label="Primary")
        primary_badge.add_css_class('monitor-badge')
        primary_badge.add_css_class('primary')
        name_row.append(primary_badge)
    
    info_card.append(name_row)
    
    # Current settings
    current_label = Gtk.Label(label=f"{ICONS['resolution']} {current_res} • Scale: {monitor['scale']}x")
    current_label.add_css_class('monitor-current')
    current_label.set_halign(Gtk.Align.START)
    window.displays_widgets[f'current_label_{name}'] = current_label
    info_card.append(current_label)
    
    section.add_content(info_card)
    
    # ═══ RESOLUTION DROPDOWN ═══
    modes = monitor.get('availableModes', [])
    
    # Get unique resolutions
    resolutions = []
    seen_res = set()
    for mode in modes:
        res_key = f"{mode['width']}x{mode['height']}"
        if res_key not in seen_res:
            seen_res.add(res_key)
            resolutions.append({
                'width': mode['width'],
                'height': mode['height'],
                'label': res_key
            })
    
    if not resolutions:
        resolutions = [{'width': monitor['width'], 'height': monitor['height'], 'label': f"{monitor['width']}x{monitor['height']}"}]
    
    res_dropdown = Gtk.DropDown()
    res_strings = Gtk.StringList()
    
    current_res_idx = 0
    for i, res in enumerate(resolutions):
        res_strings.append(res['label'])
        if res['width'] == monitor['width'] and res['height'] == monitor['height']:
            current_res_idx = i
    
    res_dropdown.set_model(res_strings)
    res_dropdown.set_selected(current_res_idx)
    res_dropdown.set_size_request(180, -1)
    
    def on_resolution_changed(dropdown, _, mon_name=name, res_list=resolutions):
        idx = dropdown.get_selected()
        if idx < len(res_list):
            new_res = res_list[idx]
            window.displays_config[mon_name]['width'] = new_res['width']
            window.displays_config[mon_name]['height'] = new_res['height']
            
            # Update refresh rate options for this resolution
            _update_refresh_rates(window, mon_name, new_res['width'], new_res['height'])
    
    res_dropdown.connect('notify::selected', on_resolution_changed)
    window.displays_widgets[f'res_dropdown_{name}'] = res_dropdown
    
    res_row = _create_setting_row(
        "Resolution",
        "Display resolution",
        res_dropdown,
        ICONS['resolution']
    )
    section.add_content(res_row)
    
    # ═══ REFRESH RATE DROPDOWN ═══
    # Get refresh rates for current resolution
    refresh_rates = []
    for mode in modes:
        if mode['width'] == monitor['width'] and mode['height'] == monitor['height']:
            refresh_rates.append(mode['refreshRate'])
    
    if not refresh_rates:
        refresh_rates = [monitor['refreshRate']]
    
    refresh_rates = sorted(set(refresh_rates), reverse=True)
    
    refresh_dropdown = Gtk.DropDown()
    refresh_strings = Gtk.StringList()
    
    current_refresh_idx = 0
    for i, rate in enumerate(refresh_rates):
        refresh_strings.append(f"{rate:.2f} Hz")
        if abs(rate - monitor['refreshRate']) < 1:
            current_refresh_idx = i
    
    refresh_dropdown.set_model(refresh_strings)
    refresh_dropdown.set_selected(current_refresh_idx)
    refresh_dropdown.set_size_request(150, -1)
    
    def on_refresh_changed(dropdown, _, mon_name=name, rates=refresh_rates):
        idx = dropdown.get_selected()
        if idx < len(rates):
            window.displays_config[mon_name]['refreshRate'] = rates[idx]
    
    refresh_dropdown.connect('notify::selected', on_refresh_changed)
    window.displays_widgets[f'refresh_dropdown_{name}'] = refresh_dropdown
    window.displays_widgets[f'refresh_rates_{name}'] = refresh_rates
    window.displays_widgets[f'all_modes_{name}'] = modes
    
    refresh_row = _create_setting_row(
        "Refresh Rate",
        "Screen refresh rate",
        refresh_dropdown,
        ICONS['refresh']
    )
    section.add_content(refresh_row)
    
    # ═══ SCALE DROPDOWN ═══
    scale_options = ["100%", "110%", "125%", "133%", "150%", "175%", "200%"]
    scale_values = [1.0, 1.1, 1.25, 1.333333, 1.5, 1.75, 2.0]
    
    scale_dropdown = Gtk.DropDown()
    scale_strings = Gtk.StringList()
    
    current_scale = monitor['scale']
    current_scale_idx = 0
    for i, (label, val) in enumerate(zip(scale_options, scale_values)):
        scale_strings.append(label)
        if abs(val - current_scale) < 0.05:
            current_scale_idx = i
    
    scale_dropdown.set_model(scale_strings)
    scale_dropdown.set_selected(current_scale_idx)
    scale_dropdown.set_size_request(120, -1)
    
    def on_scale_changed(dropdown, _, mon_name=name, vals=scale_values):
        idx = dropdown.get_selected()
        if idx < len(vals):
            window.displays_config[mon_name]['scale'] = vals[idx]
    
    scale_dropdown.connect('notify::selected', on_scale_changed)
    
    scale_row = _create_setting_row(
        "Scale",
        "UI scaling factor",
        scale_dropdown,
        ICONS['scale']
    )
    section.add_content(scale_row)
    
    # ═══ ROTATION DROPDOWN ═══
    rotation_options = ["Normal", "90°", "180°", "270°", "Flipped", "Flipped 90°", "Flipped 180°", "Flipped 270°"]
    rotation_values = [0, 1, 2, 3, 4, 5, 6, 7]
    
    rotation_dropdown = Gtk.DropDown()
    rotation_strings = Gtk.StringList()
    
    for opt in rotation_options:
        rotation_strings.append(opt)
    
    rotation_dropdown.set_model(rotation_strings)
    rotation_dropdown.set_selected(monitor.get('transform', 0))
    rotation_dropdown.set_size_request(150, -1)
    
    def on_rotation_changed(dropdown, _, mon_name=name, vals=rotation_values):
        idx = dropdown.get_selected()
        if idx < len(vals):
            window.displays_config[mon_name]['transform'] = vals[idx]
    
    rotation_dropdown.connect('notify::selected', on_rotation_changed)
    
    rotation_row = _create_setting_row(
        "Rotation",
        "Display orientation",
        rotation_dropdown,
        ICONS['rotation']
    )
    section.add_content(rotation_row)
    
    # ═══ ENABLE/DISABLE ═══
    enable_switch = Gtk.Switch()
    enable_switch.set_valign(Gtk.Align.CENTER)
    enable_switch.set_active(True)
    
    def on_enable_changed(switch, _, mon_name=name):
        window.displays_config[mon_name]['enabled'] = switch.get_active()
    
    enable_switch.connect('notify::active', on_enable_changed)
    
    enable_row = _create_setting_row(
        "Enable Display",
        "Turn this display on or off",
        enable_switch,
        ICONS['enabled']
    )
    section.add_content(enable_row)
    
    # Divider
    divider = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
    divider.add_css_class('subsection-divider')
    section.add_content(divider)
    
    # Apply button for this monitor
    apply_btn = Gtk.Button(label=f"{ICONS['apply']} Apply to {name}")
    apply_btn.add_css_class('suggested-action')
    
    def on_apply_single(btn, mon_name=name, sec=section):
        config = window.displays_config.get(mon_name, {})
        if config.get('enabled', True):
            success, msg = apply_monitor_setting(
                mon_name,
                config['width'],
                config['height'],
                config['refreshRate'],
                config['scale'],
                config['transform']
            )
            if success:
                _show_toast(window, f"Applied settings to {mon_name}")
                # Update section subtitle
                new_res = f"{config['width']}x{config['height']}@{config['refreshRate']:.0f}Hz"
                sec.set_subtitle(f"{new_res}")
                # Update current label
                current_lbl = window.displays_widgets.get(f'current_label_{mon_name}')
                if current_lbl:
                    current_lbl.set_text(f"{ICONS['resolution']} {new_res} • Scale: {config['scale']}x")
            else:
                _show_toast(window, f"Failed: {msg[:50]}")
        else:
            # Disable monitor
            subprocess.run(f"hyprctl keyword monitor {mon_name},disable", shell=True)
            _show_toast(window, f"Disabled {mon_name}")
    
    apply_btn.connect('clicked', on_apply_single)
    
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    btn_box.set_halign(Gtk.Align.END)
    btn_box.append(apply_btn)
    section.add_content(btn_box)
    
    return section


def _update_refresh_rates(window, monitor_name: str, width: int, height: int):
    """Update refresh rate dropdown when resolution changes"""
    dropdown = window.displays_widgets.get(f'refresh_dropdown_{monitor_name}')
    modes = window.displays_widgets.get(f'all_modes_{monitor_name}', [])
    
    if not dropdown or not modes:
        return
    
    # Get refresh rates for this resolution
    refresh_rates = []
    for mode in modes:
        if mode['width'] == width and mode['height'] == height:
            refresh_rates.append(mode['refreshRate'])
    
    if not refresh_rates:
        refresh_rates = [60.0]
    
    refresh_rates = sorted(set(refresh_rates), reverse=True)
    window.displays_widgets[f'refresh_rates_{monitor_name}'] = refresh_rates
    
    # Update dropdown
    refresh_strings = Gtk.StringList()
    for rate in refresh_rates:
        refresh_strings.append(f"{rate:.2f} Hz")
    
    dropdown.set_model(refresh_strings)
    dropdown.set_selected(0)
    
    # Update config
    window.displays_config[monitor_name]['refreshRate'] = refresh_rates[0]


def _build_actions_content(window, section):
    """Build quick actions content"""
    
    # Apply All
    apply_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    apply_card.add_css_class('quick-actions-card')
    
    apply_icon = Gtk.Label(label=ICONS['apply'])
    apply_icon.add_css_class('display-setting-icon')
    apply_card.append(apply_icon)
    
    apply_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    apply_info.set_hexpand(True)
    
    apply_title = Gtk.Label(label="Apply All Changes")
    apply_title.add_css_class('display-setting-label')
    apply_title.set_halign(Gtk.Align.START)
    apply_info.append(apply_title)
    
    apply_desc = Gtk.Label(label="Apply all monitor settings and save to monitors.conf")
    apply_desc.add_css_class('display-setting-description')
    apply_desc.set_halign(Gtk.Align.START)
    apply_info.append(apply_desc)
    
    apply_card.append(apply_info)
    
    apply_btn = Gtk.Button(label="Apply All")
    apply_btn.add_css_class('suggested-action')
    apply_btn.set_valign(Gtk.Align.CENTER)
    
    def on_apply_all(btn):
        configs = list(window.displays_config.values())
        
        for config in configs:
            if config.get('enabled', True):
                apply_monitor_setting(
                    config['name'],
                    config['width'],
                    config['height'],
                    config['refreshRate'],
                    config['scale'],
                    config['transform']
                )
        
        # Save to file
        write_monitors_conf(configs)
        _show_toast(window, "All monitor settings applied and saved!")
    
    apply_btn.connect('clicked', on_apply_all)
    apply_card.append(apply_btn)
    
    section.add_content(apply_card)
    
    # nwg-displays
    nwg_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    nwg_card.add_css_class('quick-actions-card')
    
    nwg_icon = Gtk.Label(label=ICONS['nwg'])
    nwg_icon.add_css_class('display-setting-icon')
    nwg_card.append(nwg_icon)
    
    nwg_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    nwg_info.set_hexpand(True)
    
    nwg_title = Gtk.Label(label="Advanced Display Settings")
    nwg_title.add_css_class('display-setting-label')
    nwg_title.set_halign(Gtk.Align.START)
    nwg_info.append(nwg_title)
    
    nwg_desc = Gtk.Label(label="Open nwg-displays for visual configuration")
    nwg_desc.add_css_class('display-setting-description')
    nwg_desc.set_halign(Gtk.Align.START)
    nwg_info.append(nwg_desc)
    
    nwg_card.append(nwg_info)
    
    nwg_btn = Gtk.Button(label="Open")
    nwg_btn.set_valign(Gtk.Align.CENTER)
    
    def on_nwg_clicked(btn):
        try:
            subprocess.Popen(['nwg-displays'])
        except FileNotFoundError:
            _show_toast(window, "nwg-displays not installed")
    
    nwg_btn.connect('clicked', on_nwg_clicked)
    nwg_card.append(nwg_btn)
    
    section.add_content(nwg_card)
    
    # Refresh
    refresh_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    refresh_card.add_css_class('quick-actions-card')
    
    refresh_icon = Gtk.Label(label=ICONS['refresh_btn'])
    refresh_icon.add_css_class('display-setting-icon')
    refresh_card.append(refresh_icon)
    
    refresh_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    refresh_info.set_hexpand(True)
    
    refresh_title = Gtk.Label(label="Refresh Monitors")
    refresh_title.add_css_class('display-setting-label')
    refresh_title.set_halign(Gtk.Align.START)
    refresh_info.append(refresh_title)
    
    refresh_desc = Gtk.Label(label="Reload Hyprland to detect changes")
    refresh_desc.add_css_class('display-setting-description')
    refresh_desc.set_halign(Gtk.Align.START)
    refresh_info.append(refresh_desc)
    
    refresh_card.append(refresh_info)
    
    refresh_btn = Gtk.Button(label="Reload")
    refresh_btn.set_valign(Gtk.Align.CENTER)
    
    def on_refresh_clicked(btn):
        subprocess.run(['hyprctl', 'reload'], timeout=3)
        _show_toast(window, "Hyprland reloaded")
    
    refresh_btn.connect('clicked', on_refresh_clicked)
    refresh_card.append(refresh_btn)
    
    section.add_content(refresh_card)


def _show_toast(window, message):
    """Show toast notification"""
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)
    else:
        print(f"[Displays] {message}")