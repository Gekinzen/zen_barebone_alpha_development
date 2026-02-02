"""
Input Devices Page - Comprehensive Hardware Configuration
Redesigned with Expandable Sections for better UX
Includes: Keyboard, Mouse/Touchpad, Bluetooth, Network, Audio
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gio, Gdk
import subprocess
import os
import json
import re
from pathlib import Path

# ════════════════════════════════════════════════════════════════════════════
# DYNAMIC PATH DETECTION
# ════════════════════════════════════════════════════════════════════════════
def get_user_home():
    """Get current user's home directory"""
    return os.path.expanduser("~")

def get_config_dir():
    """Get hypr-control-center config directory"""
    return os.path.join(get_user_home(), ".config", "hypr-control-center")

def get_hypr_config_dir():
    """Get Hyprland config directory"""
    return os.path.join(get_user_home(), ".config", "hypr")

# Script paths - dynamically resolved
SCRIPT_PATHS = {
    'bluetooth': os.path.join(get_user_home(), ".config", "alacritty", "bluetoothrun.sh"),
    'wifi_selector': os.path.join(get_config_dir(), "scripts", "wifi_selector.py"),
    'audio_top': os.path.join(get_user_home(), ".config", "kitty", "modules", "audiotop.sh"),
}

# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ════════════════════════════════════════════════════════════════════════════
ICONS = {
    'keyboard': '󰌌',
    'mouse': '󰍽',
    'touchpad': '󰟸',
    'bluetooth': '󰂯',
    'bluetooth_connected': '󰂱',
    'bluetooth_off': '󰂲',
    'wifi': '󰖩',
    'wifi_off': '󰖪',
    'ethernet': '󰈀',
    'network': '󰛳',
    'audio': '󰕾',
    'audio_muted': '󰖁',
    'microphone': '󰍬',
    'microphone_muted': '󰍭',
    'settings': '󰒓',
    'refresh': '󰑐',
    'connected': '󰄬',
    'disconnected': '󰅖',
    'device': '󰌢',
    'headphones': '󰋋',
    'speaker': '󰓃',
    'expand': '󰅀',
    'collapse': '󰅃',
}

# ════════════════════════════════════════════════════════════════════════════
# KEYBOARD LAYOUTS
# ════════════════════════════════════════════════════════════════════════════
KEYBOARD_LAYOUTS = {
    'us': 'English (US)',
    'gb': 'English (UK)',
    'de': 'German',
    'fr': 'French',
    'es': 'Spanish',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'jp': 'Japanese',
    'kr': 'Korean',
    'cn': 'Chinese',
    'br': 'Portuguese (Brazil)',
    'latam': 'Spanish (Latin America)',
    'dvorak': 'Dvorak',
    'colemak': 'Colemak',
    'ph': 'Filipino',
}

# ════════════════════════════════════════════════════════════════════════════
# CUSTOM CSS FOR INPUT PAGE
# ════════════════════════════════════════════════════════════════════════════
INPUT_PAGE_CSS = """
/* ═══════════════════════════════════════════════════════════════════════════
   INPUT DEVICES PAGE STYLES - Expandable Sections Design
   ═══════════════════════════════════════════════════════════════════════════ */

/* Main Section Container */
.input-section {
    background: alpha(@card_bg_color, 0.6);
    border-radius: 12px;
    border: 1px solid alpha(@borders, 0.3);
    margin-bottom: 12px;
    padding: 0;
}

.input-section:hover {
    border-color: alpha(@accent_color, 0.4);
}

/* Section Header (Clickable) */
.input-section-header {
    padding: 16px 20px;
    border-radius: 12px;
    transition: background 200ms ease;
}

.input-section-header:hover {
    background: alpha(@card_bg_color, 0.8);
}

.input-section-header.expanded {
    border-bottom: 1px solid alpha(@borders, 0.2);
    border-radius: 12px 12px 0 0;
}

/* Section Icon */
.section-icon {
    font-size: 20px;
    min-width: 32px;
    color: @accent_color;
}

/* Section Title */
.section-title-text {
    font-size: 15px;
    font-weight: 600;
    color: @theme_fg_color;
}

/* Section Subtitle/Status */
.section-subtitle {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.6);
    margin-top: 2px;
}

/* Expand Arrow */
.expand-arrow {
    font-size: 14px;
    color: alpha(@theme_fg_color, 0.5);
    transition: transform 200ms ease;
}

.expand-arrow.expanded {
    color: @accent_color;
}

/* Section Content (Expandable) */
.input-section-content {
    padding: 16px 20px;
    background: alpha(@card_bg_color, 0.3);
    border-radius: 0 0 12px 12px;
}

/* Setting Row inside sections */
.input-setting-row {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.input-setting-row:hover {
    background: alpha(@card_bg_color, 0.7);
    border-color: alpha(@accent_color, 0.3);
}

.input-setting-row:last-child {
    margin-bottom: 0;
}

/* Setting Labels */
.input-setting-label {
    font-size: 14px;
    font-weight: 500;
    color: @theme_fg_color;
}

.input-setting-description {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.5);
}

/* Setting Icon */
.input-setting-icon {
    font-size: 16px;
    min-width: 24px;
    color: alpha(@theme_fg_color, 0.7);
}

/* Value Display */
.input-value-badge {
    background: alpha(@accent_color, 0.15);
    color: @accent_color;
    padding: 4px 12px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
}

/* Device Card (for Bluetooth/Network) */
.device-card {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.device-card:hover {
    background: alpha(@card_bg_color, 0.7);
}

.device-card.connected {
    border-color: alpha(@success_color, 0.4);
    background: alpha(@success_color, 0.08);
}

.device-name {
    font-size: 14px;
    font-weight: 500;
}

.device-status {
    font-size: 12px;
    color: alpha(@theme_fg_color, 0.6);
}

.device-status.connected {
    color: @success_color;
}

/* Action Buttons Row */
.input-actions {
    padding: 12px 0 4px 0;
    border-top: 1px solid alpha(@borders, 0.15);
    margin-top: 12px;
}

.input-action-btn {
    padding: 8px 16px;
    border-radius: 8px;
    font-size: 13px;
    background: alpha(@card_bg_color, 0.6);
    border: 1px solid alpha(@borders, 0.2);
}

.input-action-btn:hover {
    background: alpha(@accent_color, 0.15);
    border-color: alpha(@accent_color, 0.4);
}

/* Volume Sliders */
.volume-container {
    padding: 12px 16px;
    border-radius: 8px;
    background: alpha(@card_bg_color, 0.4);
    margin-top: 8px;
}

.volume-label {
    font-size: 13px;
    font-weight: 500;
    margin-bottom: 8px;
    color: alpha(@theme_fg_color, 0.8);
}

/* Subsection Divider */
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

/* Empty State */
.empty-state {
    padding: 24px;
    text-align: center;
    color: alpha(@theme_fg_color, 0.5);
    font-size: 13px;
}

.empty-state-icon {
    font-size: 32px;
    margin-bottom: 8px;
    opacity: 0.5;
}
"""


# ════════════════════════════════════════════════════════════════════════════
# SYSTEM DETECTION FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def run_command(cmd, timeout=5):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, 
            text=True, timeout=timeout
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except (subprocess.TimeoutExpired, Exception):
        return ""

def get_hyprland_input_config():
    """Get current Hyprland input configuration"""
    config = {
        'kb_layout': 'us',
        'kb_variant': '',
        'kb_options': '',
        'numlock_by_default': False,
        'repeat_rate': 25,
        'repeat_delay': 600,
        'sensitivity': 0.0,
        'accel_profile': 'flat',
        'natural_scroll': False,
        'scroll_method': 'two_finger',
        'tap_to_click': True,
        'disable_while_typing': True,
        'clickfinger_behavior': False,
        'middle_emulation': False,
        'scroll_factor': 1.0,
    }
    
    try:
        output = run_command("hyprctl getoption input:kb_layout -j")
        if output:
            data = json.loads(output)
            config['kb_layout'] = data.get('str', 'us')
        
        output = run_command("hyprctl getoption input:kb_variant -j")
        if output:
            data = json.loads(output)
            config['kb_variant'] = data.get('str', '')
        
        output = run_command("hyprctl getoption input:repeat_rate -j")
        if output:
            data = json.loads(output)
            config['repeat_rate'] = data.get('int', 25)
        
        output = run_command("hyprctl getoption input:repeat_delay -j")
        if output:
            data = json.loads(output)
            config['repeat_delay'] = data.get('int', 600)
        
        output = run_command("hyprctl getoption input:sensitivity -j")
        if output:
            data = json.loads(output)
            config['sensitivity'] = data.get('float', 0.0)
        
        output = run_command("hyprctl getoption input:accel_profile -j")
        if output:
            data = json.loads(output)
            config['accel_profile'] = data.get('str', 'flat')
        
        output = run_command("hyprctl getoption input:natural_scroll -j")
        if output:
            data = json.loads(output)
            config['natural_scroll'] = data.get('int', 0) == 1
        
        output = run_command("hyprctl getoption input:touchpad:natural_scroll -j")
        if output:
            data = json.loads(output)
            config['touchpad_natural_scroll'] = data.get('int', 0) == 1
        
        output = run_command("hyprctl getoption input:touchpad:tap-to-click -j")
        if output:
            data = json.loads(output)
            config['tap_to_click'] = data.get('int', 1) == 1
        
        output = run_command("hyprctl getoption input:touchpad:disable_while_typing -j")
        if output:
            data = json.loads(output)
            config['disable_while_typing'] = data.get('int', 1) == 1
        
        output = run_command("hyprctl getoption input:touchpad:scroll_factor -j")
        if output:
            data = json.loads(output)
            config['scroll_factor'] = data.get('float', 1.0)
            
    except Exception as e:
        print(f"[Input] Error reading Hyprland config: {e}")
    
    return config


def get_bluetooth_devices():
    """Get Bluetooth devices and their status"""
    devices = []
    
    bt_status = run_command("bluetoothctl show 2>/dev/null | grep 'Powered:' | awk '{print $2}'")
    if bt_status.lower() != 'yes':
        return devices, False
    
    output = run_command("bluetoothctl devices Paired 2>/dev/null")
    if output:
        for line in output.split('\n'):
            if line.startswith('Device '):
                parts = line.split(' ', 2)
                if len(parts) >= 3:
                    mac = parts[1]
                    name = parts[2]
                    
                    info = run_command(f"bluetoothctl info {mac} 2>/dev/null")
                    connected = 'Connected: yes' in info
                    
                    device_type = 'device'
                    if 'Icon: audio-headphones' in info or 'Icon: audio-headset' in info:
                        device_type = 'headphones'
                    elif 'Icon: input-keyboard' in info:
                        device_type = 'keyboard'
                    elif 'Icon: input-mouse' in info:
                        device_type = 'mouse'
                    
                    devices.append({
                        'mac': mac,
                        'name': name,
                        'connected': connected,
                        'type': device_type
                    })
    
    return devices, True


def get_network_status():
    """Get current network connection status"""
    status = {
        'wifi': None,
        'ethernet': None,
        'wifi_enabled': False,
    }
    
    wifi_output = run_command("nmcli -t -f ACTIVE,SSID device wifi | grep '^yes'")
    if wifi_output:
        parts = wifi_output.split(':')
        if len(parts) >= 2:
            status['wifi'] = parts[1]
    
    wifi_status = run_command("nmcli radio wifi")
    status['wifi_enabled'] = wifi_status.strip().lower() == 'enabled'
    
    eth_output = run_command("nmcli -t -f TYPE,STATE device | grep 'ethernet:connected'")
    if eth_output:
        eth_name = run_command("nmcli -t -f DEVICE,TYPE,STATE device | grep 'ethernet:connected' | cut -d: -f1")
        status['ethernet'] = eth_name if eth_name else 'Connected'
    
    return status


def get_audio_status():
    """Get current audio status using pactl/wpctl"""
    status = {
        'sink': None,
        'sink_volume': 100,
        'sink_muted': False,
        'source': None,
        'source_volume': 100,
        'source_muted': False,
    }
    
    try:
        sink_vol = run_command("wpctl get-volume @DEFAULT_AUDIO_SINK@")
        if sink_vol:
            match = re.search(r'Volume:\s*([\d.]+)', sink_vol)
            if match:
                status['sink_volume'] = int(float(match.group(1)) * 100)
            status['sink_muted'] = '[MUTED]' in sink_vol
        
        source_vol = run_command("wpctl get-volume @DEFAULT_AUDIO_SOURCE@")
        if source_vol:
            match = re.search(r'Volume:\s*([\d.]+)', source_vol)
            if match:
                status['source_volume'] = int(float(match.group(1)) * 100)
            status['source_muted'] = '[MUTED]' in source_vol
        
        sink_info = run_command("pactl get-default-sink")
        if sink_info:
            sink_desc = run_command(f"pactl list sinks | grep -A1 'Name: {sink_info}' | grep 'Description' | cut -d: -f2")
            status['sink'] = sink_desc.strip() if sink_desc else sink_info
        
        source_info = run_command("pactl get-default-source")
        if source_info:
            source_desc = run_command(f"pactl list sources | grep -A1 'Name: {source_info}' | grep 'Description' | cut -d: -f2")
            status['source'] = source_desc.strip() if source_desc else source_info
            
    except Exception as e:
        print(f"[Input] Error getting audio status: {e}")
    
    return status


# ════════════════════════════════════════════════════════════════════════════
# HYPRLAND CONFIGURATION FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def apply_hyprland_setting(option, value):
    """Apply a Hyprland input setting"""
    try:
        if isinstance(value, bool):
            value = 'true' if value else 'false'
        elif isinstance(value, float):
            value = str(value)
        elif isinstance(value, int):
            value = str(value)
        
        cmd = f"hyprctl keyword {option} {value}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0
    except Exception as e:
        print(f"[Input] Error applying setting {option}: {e}")
        return False


# ════════════════════════════════════════════════════════════════════════════
# EXPANDABLE SECTION COMPONENT
# ════════════════════════════════════════════════════════════════════════════

class ExpandableSection(Gtk.Box):
    """Reusable expandable section component"""
    
    def __init__(self, icon, title, subtitle="", expanded=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('input-section')
        
        self._expanded = expanded
        self._subtitle_label = None
        
        # Header (clickable)
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.header.add_css_class('input-section-header')
        if expanded:
            self.header.add_css_class('expanded')
        
        # Make header clickable
        click_gesture = Gtk.GestureClick.new()
        click_gesture.connect('pressed', self._on_header_clicked)
        self.header.add_controller(click_gesture)
        
        # Icon
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('section-icon')
        self.header.append(icon_label)
        
        # Title & Subtitle
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
        
        # Expand arrow
        self.arrow = Gtk.Label(label="󰅂" if not expanded else "󰅀")
        self.arrow.add_css_class('expand-arrow')
        if expanded:
            self.arrow.add_css_class('expanded')
        self.header.append(self.arrow)
        
        self.append(self.header)
        
        # Content area (expandable)
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.content.add_css_class('input-section-content')
        
        # Revealer for smooth animation
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(200)
        self.revealer.set_reveal_child(expanded)
        self.revealer.set_child(self.content)
        
        self.append(self.revealer)
    
    def _on_header_clicked(self, gesture, n_press, x, y):
        """Toggle section expansion"""
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
        """Update subtitle text"""
        if self._subtitle_label:
            self._subtitle_label.set_text(text)
    
    def add_content(self, widget):
        """Add widget to content area"""
        self.content.append(widget)
    
    def clear_content(self):
        """Clear all content"""
        while self.content.get_first_child():
            self.content.remove(self.content.get_first_child())


# ════════════════════════════════════════════════════════════════════════════
# UI BUILDING FUNCTIONS  
# ════════════════════════════════════════════════════════════════════════════

def build_input_page(window):
    """Build the Input Devices page with expandable sections"""
    
    # Apply custom CSS
    _apply_input_css()
    
    # Main scrollable container
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32)
    page.set_margin_end(32)
    page.set_margin_top(24)
    page.set_margin_bottom(24)
    
    # Page header
    header = _create_page_header(
        f"{ICONS['keyboard']} Input Devices",
        "Configure keyboard, mouse, touchpad, and connected devices"
    )
    page.append(header)
    
    # Store widgets for updates
    window.input_widgets = {}
    
    # Get initial config
    config = get_hyprland_input_config()
    
    # ═══ KEYBOARD SECTION ═══
    kb_layout_name = KEYBOARD_LAYOUTS.get(config['kb_layout'], config['kb_layout'].upper())
    keyboard_section = ExpandableSection(
        ICONS['keyboard'], 
        "Keyboard",
        f"Layout: {kb_layout_name}",
        expanded=True
    )
    window.input_widgets['keyboard_section'] = keyboard_section
    _build_keyboard_content(window, keyboard_section, config)
    page.append(keyboard_section)
    
    # ═══ MOUSE & TOUCHPAD SECTION ═══
    mouse_section = ExpandableSection(
        ICONS['mouse'], 
        "Mouse & Touchpad",
        f"Sensitivity: {config['sensitivity']:.1f} • {config['accel_profile'].capitalize()}"
    )
    window.input_widgets['mouse_section'] = mouse_section
    _build_mouse_content(window, mouse_section, config)
    page.append(mouse_section)
    
    # ═══ BLUETOOTH SECTION ═══
    devices, bt_enabled = get_bluetooth_devices()
    connected_count = sum(1 for d in devices if d['connected'])
    bt_subtitle = f"{connected_count} connected" if connected_count > 0 else ("No devices" if bt_enabled else "Disabled")
    
    bluetooth_section = ExpandableSection(
        ICONS['bluetooth'], 
        "Bluetooth Devices",
        bt_subtitle
    )
    window.input_widgets['bluetooth_section'] = bluetooth_section
    _build_bluetooth_content(window, bluetooth_section)
    page.append(bluetooth_section)
    
    # ═══ NETWORK SECTION ═══
    network_status = get_network_status()
    net_subtitle = network_status['wifi'] or network_status['ethernet'] or "Not connected"
    
    network_section = ExpandableSection(
        ICONS['network'], 
        "Network",
        f"Connected: {net_subtitle}" if (network_status['wifi'] or network_status['ethernet']) else "Not connected"
    )
    window.input_widgets['network_section'] = network_section
    _build_network_content(window, network_section)
    page.append(network_section)
    
    # ═══ AUDIO SECTION ═══
    audio_status = get_audio_status()
    vol_text = f"{audio_status['sink_volume']}%" + (" (Muted)" if audio_status['sink_muted'] else "")
    
    audio_section = ExpandableSection(
        ICONS['audio'], 
        "Audio",
        f"Volume: {vol_text}"
    )
    window.input_widgets['audio_section'] = audio_section
    _build_audio_content(window, audio_section)
    page.append(audio_section)
    
    # Initial data refresh
    GLib.timeout_add(500, lambda: _refresh_all_sections(window) or False)
    
    return page


def _apply_input_css():
    """Apply custom CSS for input page"""
    provider = Gtk.CssProvider()
    provider.load_from_data(INPUT_PAGE_CSS.encode())
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
    row.add_css_class('input-setting-row')
    
    if icon:
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('input-setting-icon')
        row.append(icon_label)
    
    label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    label_box.set_hexpand(True)
    
    main_label = Gtk.Label(label=label)
    main_label.set_halign(Gtk.Align.START)
    main_label.add_css_class('input-setting-label')
    label_box.append(main_label)
    
    if description:
        desc_label = Gtk.Label(label=description)
        desc_label.set_halign(Gtk.Align.START)
        desc_label.add_css_class('input-setting-description')
        label_box.append(desc_label)
    
    row.append(label_box)
    
    if widget:
        row.append(widget)
    
    return row


def _create_action_buttons(buttons_data):
    """Create action buttons row"""
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    box.add_css_class('input-actions')
    
    for label, callback in buttons_data:
        btn = Gtk.Button(label=label)
        btn.add_css_class('input-action-btn')
        btn.add_css_class('flat')
        btn.connect('clicked', callback)
        box.append(btn)
    
    return box


# ════════════════════════════════════════════════════════════════════════════
# KEYBOARD SECTION CONTENT
# ════════════════════════════════════════════════════════════════════════════

def _build_keyboard_content(window, section, config):
    """Build keyboard settings content"""
    
    # Current Layout Badge
    layout_name = KEYBOARD_LAYOUTS.get(config['kb_layout'], config['kb_layout'].upper())
    layout_badge = Gtk.Label(label=layout_name)
    layout_badge.add_css_class('input-value-badge')
    window.input_widgets['kb_layout_badge'] = layout_badge
    
    layout_row = _create_setting_row(
        "Current Layout",
        f"Code: {config['kb_layout']}" + (f" • Variant: {config['kb_variant']}" if config['kb_variant'] else ""),
        layout_badge
    )
    section.add_content(layout_row)
    
    # Layout Dropdown
    layout_dropdown = Gtk.DropDown()
    layout_strings = Gtk.StringList()
    layout_list = list(KEYBOARD_LAYOUTS.keys())
    
    for layout in layout_list:
        layout_strings.append(f"{KEYBOARD_LAYOUTS[layout]} ({layout})")
    
    layout_dropdown.set_model(layout_strings)
    layout_dropdown.set_size_request(200, -1)
    
    try:
        current_idx = layout_list.index(config['kb_layout'])
        layout_dropdown.set_selected(current_idx)
    except ValueError:
        pass
    
    def on_layout_changed(dropdown, _):
        idx = dropdown.get_selected()
        new_layout = layout_list[idx]
        if apply_hyprland_setting('input:kb_layout', new_layout):
            new_name = KEYBOARD_LAYOUTS.get(new_layout, new_layout)
            window.input_widgets['kb_layout_badge'].set_text(new_name)
            section.set_subtitle(f"Layout: {new_name}")
            _show_toast(window, f"Layout changed to {new_name}")
    
    layout_dropdown.connect('notify::selected', on_layout_changed)
    
    dropdown_row = _create_setting_row(
        "Change Layout",
        "Select a keyboard layout",
        layout_dropdown
    )
    section.add_content(dropdown_row)
    
    # Repeat Rate
    repeat_adj = Gtk.Adjustment(value=config['repeat_rate'], lower=10, upper=100, step_increment=5)
    repeat_spin = Gtk.SpinButton(adjustment=repeat_adj)
    repeat_spin.set_digits(0)
    
    def on_repeat_rate_changed(spin):
        apply_hyprland_setting('input:repeat_rate', int(spin.get_value()))
    
    repeat_spin.connect('value-changed', on_repeat_rate_changed)
    
    repeat_row = _create_setting_row(
        "Repeat Rate",
        "Characters per second when holding a key",
        repeat_spin
    )
    section.add_content(repeat_row)
    
    # Repeat Delay
    delay_adj = Gtk.Adjustment(value=config['repeat_delay'], lower=100, upper=1000, step_increment=50)
    delay_spin = Gtk.SpinButton(adjustment=delay_adj)
    delay_spin.set_digits(0)
    
    def on_repeat_delay_changed(spin):
        apply_hyprland_setting('input:repeat_delay', int(spin.get_value()))
    
    delay_spin.connect('value-changed', on_repeat_delay_changed)
    
    delay_row = _create_setting_row(
        "Repeat Delay",
        "Delay before key repeat starts (ms)",
        delay_spin
    )
    section.add_content(delay_row)
    
    # NumLock
    numlock_switch = Gtk.Switch()
    numlock_switch.set_valign(Gtk.Align.CENTER)
    numlock_switch.set_active(config.get('numlock_by_default', False))
    
    def on_numlock_changed(switch, _):
        apply_hyprland_setting('input:numlock_by_default', switch.get_active())
    
    numlock_switch.connect('notify::active', on_numlock_changed)
    
    numlock_row = _create_setting_row(
        "NumLock by Default",
        "Enable NumLock on startup",
        numlock_switch
    )
    section.add_content(numlock_row)


# ════════════════════════════════════════════════════════════════════════════
# MOUSE & TOUCHPAD SECTION CONTENT
# ════════════════════════════════════════════════════════════════════════════

def _build_mouse_content(window, section, config):
    """Build mouse and touchpad settings content"""
    
    # Mouse Subsection Label
    mouse_label = Gtk.Label(label="MOUSE")
    mouse_label.add_css_class('subsection-label')
    mouse_label.set_halign(Gtk.Align.START)
    section.add_content(mouse_label)
    
    # Sensitivity
    sens_adj = Gtk.Adjustment(value=config['sensitivity'], lower=-1.0, upper=1.0, step_increment=0.1)
    sens_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=sens_adj)
    sens_scale.set_digits(2)
    sens_scale.set_size_request(180, -1)
    sens_scale.set_draw_value(True)
    
    def on_sensitivity_changed(scale):
        value = scale.get_value()
        apply_hyprland_setting('input:sensitivity', value)
        section.set_subtitle(f"Sensitivity: {value:.1f} • {config['accel_profile'].capitalize()}")
    
    sens_scale.connect('value-changed', on_sensitivity_changed)
    
    sens_row = _create_setting_row(
        "Sensitivity",
        "Pointer speed (-1.0 to 1.0)",
        sens_scale,
        ICONS['mouse']
    )
    section.add_content(sens_row)
    
    # Acceleration Profile
    accel_dropdown = Gtk.DropDown()
    accel_strings = Gtk.StringList()
    accel_profiles = ['flat', 'adaptive']
    
    for profile in accel_profiles:
        accel_strings.append(profile.capitalize())
    
    accel_dropdown.set_model(accel_strings)
    
    try:
        current_idx = accel_profiles.index(config['accel_profile'])
        accel_dropdown.set_selected(current_idx)
    except ValueError:
        pass
    
    def on_accel_changed(dropdown, _):
        idx = dropdown.get_selected()
        apply_hyprland_setting('input:accel_profile', accel_profiles[idx])
    
    accel_dropdown.connect('notify::selected', on_accel_changed)
    
    accel_row = _create_setting_row(
        "Acceleration Profile",
        "Mouse acceleration behavior",
        accel_dropdown
    )
    section.add_content(accel_row)
    
    # Natural Scroll (Mouse)
    natural_switch = Gtk.Switch()
    natural_switch.set_valign(Gtk.Align.CENTER)
    natural_switch.set_active(config.get('natural_scroll', False))
    
    def on_natural_changed(switch, _):
        apply_hyprland_setting('input:natural_scroll', switch.get_active())
    
    natural_switch.connect('notify::active', on_natural_changed)
    
    natural_row = _create_setting_row(
        "Natural Scrolling",
        "Invert mouse scroll direction",
        natural_switch
    )
    section.add_content(natural_row)
    
    # Divider
    divider = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
    divider.add_css_class('subsection-divider')
    section.add_content(divider)
    
    # Touchpad Subsection Label
    touchpad_label = Gtk.Label(label="TOUCHPAD")
    touchpad_label.add_css_class('subsection-label')
    touchpad_label.set_halign(Gtk.Align.START)
    section.add_content(touchpad_label)
    
    # Tap to Click
    tap_switch = Gtk.Switch()
    tap_switch.set_valign(Gtk.Align.CENTER)
    tap_switch.set_active(config.get('tap_to_click', True))
    
    def on_tap_changed(switch, _):
        apply_hyprland_setting('input:touchpad:tap-to-click', switch.get_active())
    
    tap_switch.connect('notify::active', on_tap_changed)
    
    tap_row = _create_setting_row(
        "Tap to Click",
        "Click by tapping the touchpad",
        tap_switch,
        ICONS['touchpad']
    )
    section.add_content(tap_row)
    
    # Disable While Typing
    dwt_switch = Gtk.Switch()
    dwt_switch.set_valign(Gtk.Align.CENTER)
    dwt_switch.set_active(config.get('disable_while_typing', True))
    
    def on_dwt_changed(switch, _):
        apply_hyprland_setting('input:touchpad:disable_while_typing', switch.get_active())
    
    dwt_switch.connect('notify::active', on_dwt_changed)
    
    dwt_row = _create_setting_row(
        "Disable While Typing",
        "Prevent accidental touches",
        dwt_switch
    )
    section.add_content(dwt_row)
    
    # Natural Scroll (Touchpad)
    tp_natural_switch = Gtk.Switch()
    tp_natural_switch.set_valign(Gtk.Align.CENTER)
    tp_natural_switch.set_active(config.get('touchpad_natural_scroll', False))
    
    def on_tp_natural_changed(switch, _):
        apply_hyprland_setting('input:touchpad:natural_scroll', switch.get_active())
    
    tp_natural_switch.connect('notify::active', on_tp_natural_changed)
    
    tp_natural_row = _create_setting_row(
        "Natural Scrolling",
        "Invert touchpad scroll direction",
        tp_natural_switch
    )
    section.add_content(tp_natural_row)
    
    # Scroll Factor
    scroll_adj = Gtk.Adjustment(value=config.get('scroll_factor', 1.0), lower=0.1, upper=3.0, step_increment=0.1)
    scroll_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=scroll_adj)
    scroll_scale.set_digits(1)
    scroll_scale.set_size_request(180, -1)
    scroll_scale.set_draw_value(True)
    
    def on_scroll_factor_changed(scale):
        apply_hyprland_setting('input:touchpad:scroll_factor', scale.get_value())
    
    scroll_scale.connect('value-changed', on_scroll_factor_changed)
    
    scroll_row = _create_setting_row(
        "Scroll Speed",
        "Touchpad scroll multiplier",
        scroll_scale
    )
    section.add_content(scroll_row)


# ════════════════════════════════════════════════════════════════════════════
# BLUETOOTH SECTION CONTENT
# ════════════════════════════════════════════════════════════════════════════

def _build_bluetooth_content(window, section):
    """Build Bluetooth devices content"""
    
    # Devices container
    devices_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    window.input_widgets['bluetooth_devices'] = devices_box
    section.add_content(devices_box)
    
    # Action buttons
    actions = _create_action_buttons([
        (f"{ICONS['settings']} Bluetooth Manager", lambda b: _open_bluetooth_manager(window)),
        (f"{ICONS['refresh']} Refresh", lambda b: _refresh_bluetooth(window)),
    ])
    section.add_content(actions)
    
    # Initial load
    _refresh_bluetooth(window)


def _open_bluetooth_manager(window):
    """Open Bluetooth manager"""
    script_path = SCRIPT_PATHS.get('bluetooth')
    if script_path and os.path.exists(script_path):
        subprocess.Popen(['bash', script_path])
    else:
        subprocess.Popen(['blueman-manager'])


def _refresh_bluetooth(window):
    """Refresh Bluetooth devices list"""
    devices_box = window.input_widgets.get('bluetooth_devices')
    section = window.input_widgets.get('bluetooth_section')
    
    if not devices_box:
        return
    
    # Clear existing
    while devices_box.get_first_child():
        devices_box.remove(devices_box.get_first_child())
    
    devices, bt_enabled = get_bluetooth_devices()
    
    if not bt_enabled:
        empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        empty.add_css_class('empty-state')
        
        icon = Gtk.Label(label=ICONS['bluetooth_off'])
        icon.add_css_class('empty-state-icon')
        empty.append(icon)
        
        label = Gtk.Label(label="Bluetooth is disabled")
        empty.append(label)
        
        devices_box.append(empty)
        if section:
            section.set_subtitle("Disabled")
        return
    
    if not devices:
        empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        empty.add_css_class('empty-state')
        
        label = Gtk.Label(label="No paired devices")
        empty.append(label)
        
        devices_box.append(empty)
        if section:
            section.set_subtitle("No devices")
        return
    
    connected_count = 0
    for device in devices:
        card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        card.add_css_class('device-card')
        if device['connected']:
            card.add_css_class('connected')
            connected_count += 1
        
        # Device icon
        icon = ICONS['bluetooth_connected'] if device['connected'] else ICONS['bluetooth']
        if device['type'] == 'headphones':
            icon = ICONS['headphones']
        elif device['type'] == 'keyboard':
            icon = ICONS['keyboard']
        elif device['type'] == 'mouse':
            icon = ICONS['mouse']
        
        icon_label = Gtk.Label(label=icon)
        icon_label.add_css_class('input-setting-icon')
        card.append(icon_label)
        
        # Device info
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        info_box.set_hexpand(True)
        
        name_label = Gtk.Label(label=device['name'])
        name_label.add_css_class('device-name')
        name_label.set_halign(Gtk.Align.START)
        info_box.append(name_label)
        
        status_text = "Connected" if device['connected'] else "Paired"
        status_label = Gtk.Label(label=status_text)
        status_label.add_css_class('device-status')
        if device['connected']:
            status_label.add_css_class('connected')
        status_label.set_halign(Gtk.Align.START)
        info_box.append(status_label)
        
        card.append(info_box)
        devices_box.append(card)
    
    if section:
        section.set_subtitle(f"{connected_count} connected" if connected_count > 0 else f"{len(devices)} paired")


# ════════════════════════════════════════════════════════════════════════════
# NETWORK SECTION CONTENT
# ════════════════════════════════════════════════════════════════════════════

def _build_network_content(window, section):
    """Build network status content"""
    
    # Status container
    network_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    window.input_widgets['network_status'] = network_box
    section.add_content(network_box)
    
    # Action buttons
    actions = _create_action_buttons([
        (f"{ICONS['wifi']} WiFi Selector", lambda b: _open_wifi_selector(window)),
        (f"{ICONS['refresh']} Refresh", lambda b: _refresh_network(window)),
    ])
    section.add_content(actions)
    
    # Initial load
    _refresh_network(window)


def _open_wifi_selector(window):
    """Open WiFi selector"""
    script_path = SCRIPT_PATHS.get('wifi_selector')
    if script_path and os.path.exists(script_path):
        subprocess.Popen(['python3', script_path])
    else:
        _show_toast(window, "WiFi selector not found")


def _refresh_network(window):
    """Refresh network status"""
    network_box = window.input_widgets.get('network_status')
    section = window.input_widgets.get('network_section')
    
    if not network_box:
        return
    
    while network_box.get_first_child():
        network_box.remove(network_box.get_first_child())
    
    status = get_network_status()
    
    # WiFi Card
    wifi_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    wifi_card.add_css_class('device-card')
    
    if status['wifi']:
        wifi_card.add_css_class('connected')
        wifi_icon = ICONS['wifi']
        wifi_status_text = f"Connected to {status['wifi']}"
    elif status['wifi_enabled']:
        wifi_icon = ICONS['wifi']
        wifi_status_text = "Not connected"
    else:
        wifi_icon = ICONS['wifi_off']
        wifi_status_text = "WiFi disabled"
    
    wifi_icon_label = Gtk.Label(label=wifi_icon)
    wifi_icon_label.add_css_class('input-setting-icon')
    wifi_card.append(wifi_icon_label)
    
    wifi_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    wifi_info.set_hexpand(True)
    
    wifi_name = Gtk.Label(label="WiFi")
    wifi_name.add_css_class('device-name')
    wifi_name.set_halign(Gtk.Align.START)
    wifi_info.append(wifi_name)
    
    wifi_status = Gtk.Label(label=wifi_status_text)
    wifi_status.add_css_class('device-status')
    if status['wifi']:
        wifi_status.add_css_class('connected')
    wifi_status.set_halign(Gtk.Align.START)
    wifi_info.append(wifi_status)
    
    wifi_card.append(wifi_info)
    network_box.append(wifi_card)
    
    # Ethernet Card (if connected)
    if status['ethernet']:
        eth_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        eth_card.add_css_class('device-card')
        eth_card.add_css_class('connected')
        
        eth_icon_label = Gtk.Label(label=ICONS['ethernet'])
        eth_icon_label.add_css_class('input-setting-icon')
        eth_card.append(eth_icon_label)
        
        eth_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        eth_info.set_hexpand(True)
        
        eth_name = Gtk.Label(label="Ethernet")
        eth_name.add_css_class('device-name')
        eth_name.set_halign(Gtk.Align.START)
        eth_info.append(eth_name)
        
        eth_status = Gtk.Label(label=f"Connected ({status['ethernet']})")
        eth_status.add_css_class('device-status')
        eth_status.add_css_class('connected')
        eth_status.set_halign(Gtk.Align.START)
        eth_info.append(eth_status)
        
        eth_card.append(eth_info)
        network_box.append(eth_card)
    
    # Update section subtitle
    if section:
        if status['wifi']:
            section.set_subtitle(f"WiFi: {status['wifi']}")
        elif status['ethernet']:
            section.set_subtitle(f"Ethernet: {status['ethernet']}")
        else:
            section.set_subtitle("Not connected")


# ════════════════════════════════════════════════════════════════════════════
# AUDIO SECTION CONTENT
# ════════════════════════════════════════════════════════════════════════════

def _build_audio_content(window, section):
    """Build audio settings content"""
    
    # Device info container
    audio_info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    window.input_widgets['audio_info'] = audio_info_box
    section.add_content(audio_info_box)
    
    # Volume controls container
    volume_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    volume_box.add_css_class('volume-container')
    window.input_widgets['volume_controls'] = volume_box
    section.add_content(volume_box)
    
    # Action buttons
    actions = _create_action_buttons([
        (f"{ICONS['settings']} Audio Monitor", lambda b: _open_audio_top(window)),
        (f"{ICONS['speaker']} Volume Control", lambda b: _toggle_pavucontrol()),
        (f"{ICONS['refresh']} Refresh", lambda b: _refresh_audio(window)),
    ])
    section.add_content(actions)
    
    # Initial load
    _refresh_audio(window)


def _open_audio_top(window):
    """Open audio monitor"""
    script_path = SCRIPT_PATHS.get('audio_top')
    if script_path and os.path.exists(script_path):
        subprocess.Popen(['bash', script_path])
    else:
        _show_toast(window, "Audio monitor not found")


def _toggle_pavucontrol():
    """Toggle pavucontrol"""
    result = run_command("pgrep -f pavucontrol")
    if result:
        subprocess.run("pkill -f pavucontrol", shell=True)
    else:
        subprocess.Popen(['pavucontrol'])


def _refresh_audio(window):
    """Refresh audio status and controls"""
    audio_info_box = window.input_widgets.get('audio_info')
    volume_box = window.input_widgets.get('volume_controls')
    section = window.input_widgets.get('audio_section')
    
    if not audio_info_box or not volume_box:
        return
    
    # Clear existing
    while audio_info_box.get_first_child():
        audio_info_box.remove(audio_info_box.get_first_child())
    while volume_box.get_first_child():
        volume_box.remove(volume_box.get_first_child())
    
    status = get_audio_status()
    
    # Output Device Card
    sink_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    sink_card.add_css_class('device-card')
    
    sink_icon = ICONS['audio_muted'] if status['sink_muted'] else ICONS['speaker']
    sink_icon_label = Gtk.Label(label=sink_icon)
    sink_icon_label.add_css_class('input-setting-icon')
    sink_card.append(sink_icon_label)
    
    sink_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    sink_info.set_hexpand(True)
    
    sink_name = Gtk.Label(label="Output Device")
    sink_name.add_css_class('device-name')
    sink_name.set_halign(Gtk.Align.START)
    sink_info.append(sink_name)
    
    sink_desc = status['sink'][:45] + "..." if status['sink'] and len(status['sink']) > 45 else (status['sink'] or 'Unknown')
    sink_status = Gtk.Label(label=sink_desc)
    sink_status.add_css_class('device-status')
    sink_status.set_halign(Gtk.Align.START)
    sink_info.append(sink_status)
    
    sink_card.append(sink_info)
    audio_info_box.append(sink_card)
    
    # Input Device Card
    source_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    source_card.add_css_class('device-card')
    
    source_icon = ICONS['microphone_muted'] if status['source_muted'] else ICONS['microphone']
    source_icon_label = Gtk.Label(label=source_icon)
    source_icon_label.add_css_class('input-setting-icon')
    source_card.append(source_icon_label)
    
    source_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    source_info.set_hexpand(True)
    
    source_name = Gtk.Label(label="Input Device")
    source_name.add_css_class('device-name')
    source_name.set_halign(Gtk.Align.START)
    source_info.append(source_name)
    
    source_desc = status['source'][:45] + "..." if status['source'] and len(status['source']) > 45 else (status['source'] or 'Unknown')
    source_status = Gtk.Label(label=source_desc)
    source_status.add_css_class('device-status')
    source_status.set_halign(Gtk.Align.START)
    source_info.append(source_status)
    
    source_card.append(source_info)
    audio_info_box.append(source_card)
    
    # Output Volume Slider
    vol_label = Gtk.Label(label=f"{ICONS['audio']} Output Volume")
    vol_label.add_css_class('volume-label')
    vol_label.set_halign(Gtk.Align.START)
    volume_box.append(vol_label)
    
    vol_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    vol_adj = Gtk.Adjustment(value=status['sink_volume'], lower=0, upper=150, step_increment=5)
    vol_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=vol_adj)
    vol_scale.set_digits(0)
    vol_scale.set_hexpand(True)
    vol_scale.set_draw_value(True)
    vol_scale.add_mark(100, Gtk.PositionType.BOTTOM, "100%")
    
    def on_volume_changed(scale):
        value = int(scale.get_value())
        subprocess.run(f"wpctl set-volume @DEFAULT_AUDIO_SINK@ {value}%", shell=True)
        vol_text = f"{value}%" + (" (Muted)" if status['sink_muted'] else "")
        if section:
            section.set_subtitle(f"Volume: {vol_text}")
    
    vol_scale.connect('value-changed', on_volume_changed)
    vol_row.append(vol_scale)
    
    mute_btn = Gtk.ToggleButton(label=ICONS['audio_muted'])
    mute_btn.set_active(status['sink_muted'])
    mute_btn.add_css_class('flat')
    
    def on_mute_toggled(btn):
        subprocess.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", shell=True)
        GLib.timeout_add(100, lambda: _refresh_audio(window) or False)
    
    mute_btn.connect('toggled', on_mute_toggled)
    vol_row.append(mute_btn)
    
    volume_box.append(vol_row)
    
    # Input Volume Slider
    mic_label = Gtk.Label(label=f"{ICONS['microphone']} Input Volume")
    mic_label.add_css_class('volume-label')
    mic_label.set_halign(Gtk.Align.START)
    mic_label.set_margin_top(8)
    volume_box.append(mic_label)
    
    mic_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    
    mic_adj = Gtk.Adjustment(value=status['source_volume'], lower=0, upper=150, step_increment=5)
    mic_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=mic_adj)
    mic_scale.set_digits(0)
    mic_scale.set_hexpand(True)
    mic_scale.set_draw_value(True)
    mic_scale.add_mark(100, Gtk.PositionType.BOTTOM, "100%")
    
    def on_mic_volume_changed(scale):
        value = int(scale.get_value())
        subprocess.run(f"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ {value}%", shell=True)
    
    mic_scale.connect('value-changed', on_mic_volume_changed)
    mic_row.append(mic_scale)
    
    mic_mute_btn = Gtk.ToggleButton(label=ICONS['microphone_muted'])
    mic_mute_btn.set_active(status['source_muted'])
    mic_mute_btn.add_css_class('flat')
    
    def on_mic_mute_toggled(btn):
        subprocess.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", shell=True)
        GLib.timeout_add(100, lambda: _refresh_audio(window) or False)
    
    mic_mute_btn.connect('toggled', on_mic_mute_toggled)
    mic_row.append(mic_mute_btn)
    
    volume_box.append(mic_row)
    
    # Update section subtitle
    if section:
        vol_text = f"{status['sink_volume']}%" + (" (Muted)" if status['sink_muted'] else "")
        section.set_subtitle(f"Volume: {vol_text}")


# ════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

def _refresh_all_sections(window):
    """Refresh all input device sections"""
    _refresh_bluetooth(window)
    _refresh_network(window)
    _refresh_audio(window)
    return False


def _show_toast(window, message):
    """Show a toast notification"""
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=message)
        toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)
    else:
        print(f"[Input] Toast: {message}")