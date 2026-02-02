"""
Keybinds Page - Hyprland Keybindings Manager
Read/Edit keybinds from ~/.config/hypr/modules/binds.conf
Detects conflicts and supports reset to default
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk, Pango
import subprocess
import os
import re
from pathlib import Path
from typing import List, Dict, Optional, Tuple

# ════════════════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ════════════════════════════════════════════════════════════════════════════
ICONS = {
    'keybinds': '󰌌',
    'key': '󰌓',
    'add': '󰐕',
    'edit': '󰏫',
    'delete': '󰆴',
    'reset': '󰑐',
    'save': '󰆓',
    'warning': '󰀪',
    'conflict': '󰅙',
    'search': '󰍉',
    'category': '󰉋',
    'app': '󰣆',
    'workspace': '󰍺',
    'window': '󰖯',
    'media': '󰎆',
    'system': '󰒓',
    'custom': '󰣀',
}

# ════════════════════════════════════════════════════════════════════════════
# DEFAULT KEYBINDS (for reset)
# ════════════════════════════════════════════════════════════════════════════
DEFAULT_KEYBINDS = """###################
### KEYBINDINGS ###
###################

# See https://wiki.hypr.land/Configuring/Keywords/
$mainMod = SUPER # Sets "Windows" key as main modifier

# Example binds, see https://wiki.hypr.land/Configuring/Binds/ for more
bind = $mainMod, T, exec, $terminal
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, G, togglefloating,
bind = $mainMod, D, exec, ~/.config/rofi/zenpy-rofi/launcher.sh || pkill rofi
bind = $mainMod, W, exec, ~/.config/waybar/scripts/launch.sh
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, J, togglesplit, # dwindle

bind = $mainMod, F, fullscreen, 1
bind = $mainMod SHIFT, F, fullscreen, 0

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Example special workspace (scratchpad)
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# ==========================================
# MULTIMEDIA KEYS - Volume & Brightness with OSD
# ==========================================

# Volume controls with OSD notifications
binde = , XF86AudioRaiseVolume, exec, ~/.config/hypr-control-center/scripts/volume_osd.sh up
binde = , XF86AudioLowerVolume, exec, ~/.config/hypr-control-center/scripts/volume_osd.sh down
bind = , XF86AudioMute, exec, ~/.config/hypr-control-center/scripts/volume_osd.sh mute
bind = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

# Brightness controls with OSD notifications
binde = , XF86MonBrightnessUp, exec, ~/.config/hypr-control-center/scripts/brightness_osd.sh up
binde = , XF86MonBrightnessDown, exec, ~/.config/hypr-control-center/scripts/brightness_osd.sh down

# Alternative: Use Super key + F1-F6 for volume/brightness
binde = $mainMod, F3, exec, ~/.config/hypr-control-center/scripts/volume_osd.sh up
binde = $mainMod, F2, exec, ~/.config/hypr-control-center/scripts/volume_osd.sh down
bind = $mainMod, F4, exec, ~/.config/hypr-control-center/scripts/volume_osd.sh mute
binde = $mainMod, F6, exec, ~/.config/hypr-control-center/scripts/brightness_osd.sh up
binde = $mainMod, F5, exec, ~/.config/hypr-control-center/scripts/brightness_osd.sh down

# Media player controls (Requires playerctl)
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioPrev, exec, playerctl previous

# ==========================================
# SCREENSHOT
# ==========================================

# Flameshot
bind = SUPER, F12, exec, pkill flameshot || flameshot gui

# ==========================================
# HYPR CONTROL CENTER
# ==========================================

bind = SUPER, F1, exec, cd ~/.config/hypr-control-center && python3 main.py
bind = SUPER ALT,1 , exec, bash ~/.config/hypr-control-center/scripts/start-menu-toggle.sh

# ==========================================
# ZOOM - Alt+Shift+Scroll with Notifications
# ==========================================

# Zoom in: Alt+Shift+Scroll Up
bind = ALT SHIFT, mouse_up, exec, ~/.config/hypr-control-center/scripts/zoom.sh in

# Zoom out: Alt+Shift+Scroll Down
bind = ALT SHIFT, mouse_down, exec, ~/.config/hypr-control-center/scripts/zoom.sh out

# Reset zoom: Alt+Shift+0
bind = ALT SHIFT, 0, exec, ~/.config/hypr-control-center/scripts/zoom.sh reset

# Alt+Shift with +/- keys
binde = ALT SHIFT, equal, exec, ~/.config/hypr-control-center/scripts/zoom.sh in
binde = ALT SHIFT, minus, exec, ~/.config/hypr-control-center/scripts/zoom.sh out




# Hyprspace keybind (correct dispatcher)
bind = $mainMod, TAB, overview:toggle
# or
bind = $mainMod, O, overview:toggle

# Alt+Tab - Window switcher
#bind = ALT, TAB, exec, ~/.config/hypr/scripts/alt-tab-switcher.sh
#bind = ALT, TAB, exec, rofi -show window
#bind = ALT, TAB, exec, ~/.config/hypr/scripts/alt-tab-rofi.sh
#bind = ALT, TAB, exec, ~/.config/hypr/scripts/alt-tab-rofi-minimal.sh
#bind = ALT SHIFT, TAB, exec, rofi -show window -theme-str 'window {location: center;}' -selected-row -1



# Fast cycling
#bind = ALT, TAB, exec, ~/.config/hypr/scripts/alt-tab-cycle-simple.sh

# Visual menu (for when you need to see all windows)
#bind = ALT, grave, exec, ~/.config/hypr/scripts/alt-tab-rofi-clean.sh



# Fast cycling (walang rofi menu)
bind = ALT, TAB, exec, ~/.config/hypr/scripts/alt-tab-rofi-minimal.sh

# Visual rofi menu
#bind = ALT SHIFT, TAB,exec, ~/.config/hypr/scripts/alt-tab-switcher.sh
"""

# ════════════════════════════════════════════════════════════════════════════
# CSS
# ════════════════════════════════════════════════════════════════════════════
KEYBINDS_PAGE_CSS = """
.keybinds-section {
    background: alpha(@card_bg_color, 0.6);
    border-radius: 12px;
    border: 1px solid alpha(@borders, 0.3);
    margin-bottom: 12px;
}

.keybinds-section:hover { border-color: alpha(@accent_color, 0.4); }

.keybinds-section-header {
    padding: 16px 20px;
    border-radius: 12px;
    transition: background 200ms ease;
}

.keybinds-section-header:hover { background: alpha(@card_bg_color, 0.8); }

.keybinds-section-header.expanded {
    border-bottom: 1px solid alpha(@borders, 0.2);
    border-radius: 12px 12px 0 0;
}

.keybinds-section-content {
    padding: 16px 20px;
    background: alpha(@card_bg_color, 0.3);
    border-radius: 0 0 12px 12px;
}

.section-icon { font-size: 20px; min-width: 32px; color: @accent_color; }
.section-title-text { font-size: 15px; font-weight: 600; }
.section-subtitle { font-size: 12px; color: alpha(@theme_fg_color, 0.6); }
.expand-arrow { font-size: 14px; color: alpha(@theme_fg_color, 0.5); }
.expand-arrow.expanded { color: @accent_color; }

.keybind-card {
    padding: 12px 16px;
    border-radius: 8px;
    margin-bottom: 6px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}

.keybind-card:hover {
    background: alpha(@card_bg_color, 0.7);
    border-color: alpha(@accent_color, 0.3);
}

.keybind-card.conflict {
    border-color: @warning_color;
    background: alpha(@warning_color, 0.05);
}

.keybind-card.disabled {
    opacity: 0.5;
}

.keybind-keys {
    font-family: monospace;
    font-size: 13px;
    font-weight: 600;
    color: @accent_color;
    padding: 4px 10px;
    border-radius: 4px;
    background: alpha(@accent_color, 0.15);
    min-width: 120px;
}

.keybind-action { font-size: 13px; color: alpha(@theme_fg_color, 0.8); }
.keybind-command { font-size: 11px; color: alpha(@theme_fg_color, 0.5); font-family: monospace; }

.keybind-type {
    font-size: 10px;
    padding: 2px 8px;
    border-radius: 4px;
    font-weight: 500;
}

.keybind-type.bind { background: alpha(#61afef, 0.15); color: #61afef; }
.keybind-type.binde { background: alpha(#98c379, 0.15); color: #98c379; }
.keybind-type.bindm { background: alpha(#e5c07b, 0.15); color: #e5c07b; }
.keybind-type.bindl { background: alpha(#c678dd, 0.15); color: #c678dd; }

.action-card {
    padding: 14px 16px;
    border-radius: 8px;
    margin-bottom: 8px;
    background: alpha(@card_bg_color, 0.5);
    border: 1px solid alpha(@borders, 0.15);
}
.action-card:hover { background: alpha(@card_bg_color, 0.7); }
.action-icon { font-size: 20px; min-width: 32px; color: @accent_color; }
.action-title { font-size: 14px; font-weight: 500; }
.action-description { font-size: 12px; color: alpha(@theme_fg_color, 0.5); }

.search-entry {
    margin-bottom: 12px;
    border-radius: 8px;
}

.category-label {
    font-size: 11px;
    font-weight: 600;
    color: alpha(@theme_fg_color, 0.5);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 8px 0;
    border-bottom: 1px solid alpha(@borders, 0.2);
    margin-bottom: 8px;
}
"""

# ════════════════════════════════════════════════════════════════════════════
# PATH HELPERS
# ════════════════════════════════════════════════════════════════════════════

def get_binds_conf_path() -> Path:
    return Path.home() / ".config" / "hypr" / "modules" / "binds.conf"


def get_backup_path() -> Path:
    return Path.home() / ".config" / "hypr" / "modules" / "binds.conf.backup"


# ════════════════════════════════════════════════════════════════════════════
# KEYBIND PARSER
# ════════════════════════════════════════════════════════════════════════════

def parse_keybinds(content: str) -> List[Dict]:
    """Parse keybinds from config content"""
    keybinds = []
    
    # Pattern: bind[e|m|l] = MODS, KEY, ACTION, [ARGS]
    pattern = re.compile(r'^(bind[eml]?)\s*=\s*(.+)$', re.MULTILINE)
    
    for match in pattern.finditer(content):
        bind_type = match.group(1)
        rest = match.group(2).strip()
        
        # Check if line is commented
        line_start = content.rfind('\n', 0, match.start()) + 1
        line = content[line_start:match.start()]
        is_disabled = line.strip().startswith('#')
        
        # Parse the bind components
        parts = [p.strip() for p in rest.split(',')]
        
        if len(parts) >= 3:
            mods = parts[0]
            key = parts[1]
            action = parts[2]
            args = ','.join(parts[3:]) if len(parts) > 3 else ''
            
            # Determine category
            category = 'custom'
            if action in ['workspace', 'movetoworkspace', 'togglespecialworkspace']:
                category = 'workspace'
            elif action in ['exec']:
                if 'volume' in args.lower() or 'audio' in key.lower():
                    category = 'media'
                elif 'brightness' in args.lower():
                    category = 'media'
                elif 'playerctl' in args.lower():
                    category = 'media'
                else:
                    category = 'app'
            elif action in ['killactive', 'movewindow', 'resizewindow', 'togglefloating', 'fullscreen', 'movefocus']:
                category = 'window'
            elif action in ['exit', 'pseudo', 'togglesplit']:
                category = 'system'
            
            keybinds.append({
                'type': bind_type,
                'mods': mods,
                'key': key,
                'action': action,
                'args': args,
                'category': category,
                'disabled': is_disabled,
                'raw': match.group(0),
            })
    
    return keybinds


def load_keybinds() -> Tuple[List[Dict], str]:
    """Load keybinds from file"""
    conf_path = get_binds_conf_path()
    
    if conf_path.exists():
        content = conf_path.read_text()
        keybinds = parse_keybinds(content)
        return keybinds, content
    
    return [], ""


def save_keybinds(content: str) -> bool:
    """Save keybinds to file"""
    conf_path = get_binds_conf_path()
    backup_path = get_backup_path()
    
    try:
        # Backup current file
        if conf_path.exists():
            backup_path.write_text(conf_path.read_text())
        
        # Write new content
        conf_path.parent.mkdir(parents=True, exist_ok=True)
        conf_path.write_text(content)
        
        # Reload Hyprland
        subprocess.run(['hyprctl', 'reload'], timeout=3)
        
        return True
    except Exception as e:
        print(f"[Keybinds] Error saving: {e}")
        return False


def reset_to_default() -> bool:
    """Reset keybinds to default"""
    return save_keybinds(DEFAULT_KEYBINDS)


def find_conflicts(keybinds: List[Dict]) -> Dict[str, List[int]]:
    """Find duplicate keybindings"""
    key_map = {}
    conflicts = {}
    
    for i, kb in enumerate(keybinds):
        if kb['disabled']:
            continue
        
        key_combo = f"{kb['mods']}+{kb['key']}".lower().replace(' ', '')
        
        if key_combo in key_map:
            if key_combo not in conflicts:
                conflicts[key_combo] = [key_map[key_combo]]
            conflicts[key_combo].append(i)
        else:
            key_map[key_combo] = i
    
    return conflicts


def format_key_display(mods: str, key: str) -> str:
    """Format key combination for display"""
    mods = mods.replace('$mainMod', 'SUPER').replace('  ', ' ').strip()
    
    # Replace key names
    key_map = {
        'XF86AudioRaiseVolume': '🔊 Vol+',
        'XF86AudioLowerVolume': '🔉 Vol-',
        'XF86AudioMute': '🔇 Mute',
        'XF86MonBrightnessUp': '🔆 Br+',
        'XF86MonBrightnessDown': '🔅 Br-',
        'XF86AudioPlay': '⏯ Play',
        'XF86AudioPause': '⏸ Pause',
        'XF86AudioNext': '⏭ Next',
        'XF86AudioPrev': '⏮ Prev',
        'mouse_down': '🖱↓',
        'mouse_up': '🖱↑',
        'mouse:272': 'LMB',
        'mouse:273': 'RMB',
    }
    
    display_key = key_map.get(key, key.upper())
    
    if mods:
        return f"{mods} + {display_key}"
    return display_key


# ════════════════════════════════════════════════════════════════════════════
# EXPANDABLE SECTION
# ════════════════════════════════════════════════════════════════════════════

class KeybindsExpandableSection(Gtk.Box):
    def __init__(self, icon, title, subtitle="", expanded=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class('keybinds-section')
        self._expanded = expanded
        
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.header.add_css_class('keybinds-section-header')
        if expanded: self.header.add_css_class('expanded')
        
        click = Gtk.GestureClick.new()
        click.connect('pressed', self._on_click)
        self.header.add_controller(click)
        
        icon_lbl = Gtk.Label(label=icon)
        icon_lbl.add_css_class('section-icon')
        self.header.append(icon_lbl)
        
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_box.set_hexpand(True)
        
        title_lbl = Gtk.Label(label=title)
        title_lbl.add_css_class('section-title-text')
        title_lbl.set_halign(Gtk.Align.START)
        title_box.append(title_lbl)
        
        self._subtitle = Gtk.Label(label=subtitle or " ")
        self._subtitle.add_css_class('section-subtitle')
        self._subtitle.set_halign(Gtk.Align.START)
        title_box.append(self._subtitle)
        self.header.append(title_box)
        
        self.arrow = Gtk.Label(label="󰅀" if expanded else "󰅂")
        self.arrow.add_css_class('expand-arrow')
        if expanded: self.arrow.add_css_class('expanded')
        self.header.append(self.arrow)
        self.append(self.header)
        
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.content.add_css_class('keybinds-section-content')
        
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(200)
        self.revealer.set_reveal_child(expanded)
        self.revealer.set_child(self.content)
        self.append(self.revealer)
    
    def _on_click(self, g, n, x, y):
        self._expanded = not self._expanded
        self.revealer.set_reveal_child(self._expanded)
        self.header.add_css_class('expanded') if self._expanded else self.header.remove_css_class('expanded')
        self.arrow.add_css_class('expanded') if self._expanded else self.arrow.remove_css_class('expanded')
        self.arrow.set_text("󰅀" if self._expanded else "󰅂")
    
    def set_subtitle(self, text): self._subtitle.set_text(text)
    def add_content(self, w): self.content.append(w)
    def clear_content(self):
        while self.content.get_first_child(): self.content.remove(self.content.get_first_child())


# ════════════════════════════════════════════════════════════════════════════
# MAIN PAGE
# ════════════════════════════════════════════════════════════════════════════

def build_keybinds_page(window) -> Gtk.Box:
    provider = Gtk.CssProvider()
    provider.load_from_data(KEYBINDS_PAGE_CSS.encode())
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    page.set_margin_start(32); page.set_margin_end(32); page.set_margin_top(24); page.set_margin_bottom(24)
    
    header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    header.set_margin_bottom(24)
    title = Gtk.Label(label=f"{ICONS['keybinds']} Keybinds")
    title.add_css_class('page-title'); title.set_halign(Gtk.Align.START)
    header.append(title)
    subtitle = Gtk.Label(label="Manage Hyprland keyboard shortcuts")
    subtitle.add_css_class('page-subtitle'); subtitle.set_halign(Gtk.Align.START)
    header.append(subtitle)
    page.append(header)
    
    window.keybinds_widgets = {}
    window.keybinds_data = {'keybinds': [], 'content': '', 'conflicts': {}}
    
    # Load keybinds
    keybinds, content = load_keybinds()
    window.keybinds_data['keybinds'] = keybinds
    window.keybinds_data['content'] = content
    window.keybinds_data['conflicts'] = find_conflicts(keybinds)
    
    # Summary Section
    summary = KeybindsExpandableSection(ICONS['key'], "Keybind Summary", f"{len(keybinds)} keybinds configured", True)
    _build_summary(window, summary)
    page.append(summary)
    
    # Categories
    categories = [
        ('app', ICONS['app'], "Applications", "App launchers and commands"),
        ('window', ICONS['window'], "Window Management", "Move, resize, focus windows"),
        ('workspace', ICONS['workspace'], "Workspaces", "Switch and move to workspaces"),
        ('media', ICONS['media'], "Media & Hardware", "Volume, brightness, media controls"),
        ('system', ICONS['system'], "System", "System commands"),
        ('custom', ICONS['custom'], "Custom", "Other keybindings"),
    ]
    
    for cat_id, cat_icon, cat_name, cat_desc in categories:
        cat_keybinds = [kb for kb in keybinds if kb['category'] == cat_id]
        if cat_keybinds:
            section = KeybindsExpandableSection(cat_icon, cat_name, f"{len(cat_keybinds)} keybinds", expanded=(cat_id == 'app'))
            window.keybinds_widgets[f'section_{cat_id}'] = section
            _build_category_content(window, section, cat_keybinds, cat_id)
            page.append(section)
    
    # Actions Section
    actions = KeybindsExpandableSection(ICONS['system'], "Actions", "Add, reset, and manage", False)
    _build_actions(window, actions)
    page.append(actions)
    
    return page


def _build_summary(window, section):
    keybinds = window.keybinds_data['keybinds']
    conflicts = window.keybinds_data['conflicts']
    
    summary_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=24)
    summary_box.set_halign(Gtk.Align.CENTER)
    
    # Total count
    total_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    total_box.set_halign(Gtk.Align.CENTER)
    
    total_count = Gtk.Label(label=str(len(keybinds)))
    total_count.add_css_class('updates-count')
    total_box.append(total_count)
    
    total_label = Gtk.Label(label="Total Keybinds")
    total_label.add_css_class('updates-label')
    total_box.append(total_label)
    summary_box.append(total_box)
    
    # Active count
    active_count = len([kb for kb in keybinds if not kb['disabled']])
    active_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    active_box.set_halign(Gtk.Align.CENTER)
    
    active_lbl = Gtk.Label(label=str(active_count))
    active_lbl.add_css_class('updates-count')
    active_box.append(active_lbl)
    
    active_text = Gtk.Label(label="Active")
    active_text.add_css_class('updates-label')
    active_box.append(active_text)
    summary_box.append(active_box)
    
    # Conflicts count
    if conflicts:
        conflict_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        conflict_box.set_halign(Gtk.Align.CENTER)
        
        conflict_lbl = Gtk.Label(label=str(len(conflicts)))
        conflict_lbl.add_css_class('updates-count')
        conflict_lbl.set_markup(f"<span color='#e5c07b'>{len(conflicts)}</span>")
        conflict_box.append(conflict_lbl)
        
        conflict_text = Gtk.Label(label="Conflicts")
        conflict_text.add_css_class('updates-label')
        conflict_box.append(conflict_text)
        summary_box.append(conflict_box)
    
    section.add_content(summary_box)
    
    # Show conflict warning if any
    if conflicts:
        warning_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        warning_box.set_margin_top(12)
        warning_box.set_halign(Gtk.Align.CENTER)
        
        warning_icon = Gtk.Label(label=ICONS['warning'])
        warning_icon.set_markup(f"<span color='#e5c07b'>{ICONS['warning']}</span>")
        warning_box.append(warning_icon)
        
        warning_text = Gtk.Label(label=f"{len(conflicts)} duplicate keybind(s) detected")
        warning_text.set_markup(f"<span color='#e5c07b'>{len(conflicts)} duplicate keybind(s) detected</span>")
        warning_box.append(warning_text)
        
        section.add_content(warning_box)


def _build_category_content(window, section, keybinds: List[Dict], category: str):
    conflicts = window.keybinds_data['conflicts']
    
    for i, kb in enumerate(keybinds):
        card = _create_keybind_card(window, kb, i, conflicts)
        section.add_content(card)


def _create_keybind_card(window, kb: Dict, index: int, conflicts: Dict) -> Gtk.Box:
    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    card.add_css_class('keybind-card')
    
    # Check if this keybind has conflict
    key_combo = f"{kb['mods']}+{kb['key']}".lower().replace(' ', '')
    if key_combo in conflicts:
        card.add_css_class('conflict')
    
    if kb['disabled']:
        card.add_css_class('disabled')
    
    # Keys display
    keys_label = Gtk.Label(label=format_key_display(kb['mods'], kb['key']))
    keys_label.add_css_class('keybind-keys')
    keys_label.set_halign(Gtk.Align.START)
    card.append(keys_label)
    
    # Action info
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    info_box.set_hexpand(True)
    
    action_text = kb['action']
    if kb['args']:
        action_text += f" {kb['args']}"
    
    action_label = Gtk.Label(label=action_text)
    action_label.add_css_class('keybind-action')
    action_label.set_halign(Gtk.Align.START)
    action_label.set_ellipsize(Pango.EllipsizeMode.END)
    info_box.append(action_label)
    
    card.append(info_box)
    
    # Type badge
    type_label = Gtk.Label(label=kb['type'])
    type_label.add_css_class('keybind-type')
    type_label.add_css_class(kb['type'])
    card.append(type_label)
    
    # Conflict indicator
    if key_combo in conflicts:
        conflict_icon = Gtk.Label(label=ICONS['conflict'])
        conflict_icon.set_markup(f"<span color='#e5c07b'>{ICONS['conflict']}</span>")
        conflict_icon.set_tooltip_text("Duplicate keybind detected")
        card.append(conflict_icon)
    
    # Edit button
    edit_btn = Gtk.Button(label=ICONS['edit'])
    edit_btn.add_css_class('flat')
    edit_btn.set_valign(Gtk.Align.CENTER)
    edit_btn.set_tooltip_text("Edit keybind")
    edit_btn.connect('clicked', lambda b, k=kb: _show_edit_dialog(window, k))
    card.append(edit_btn)
    
    return card


def _build_actions(window, section):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    
    # Add New Keybind
    add_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    add_card.add_css_class('action-card')
    
    add_icon = Gtk.Label(label=ICONS['add']); add_icon.add_css_class('action-icon')
    add_card.append(add_icon)
    
    add_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    add_info.set_hexpand(True)
    add_title = Gtk.Label(label="Add New Keybind"); add_title.add_css_class('action-title'); add_title.set_halign(Gtk.Align.START)
    add_info.append(add_title)
    add_desc = Gtk.Label(label="Create a new keyboard shortcut"); add_desc.add_css_class('action-description'); add_desc.set_halign(Gtk.Align.START)
    add_info.append(add_desc)
    add_card.append(add_info)
    
    add_btn = Gtk.Button(label="Add")
    add_btn.add_css_class('suggested-action')
    add_btn.set_valign(Gtk.Align.CENTER)
    add_btn.connect('clicked', lambda b: _show_add_dialog(window))
    add_card.append(add_btn)
    box.append(add_card)
    
    # Open Config
    open_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    open_card.add_css_class('action-card')
    
    open_icon = Gtk.Label(label=ICONS['edit']); open_icon.add_css_class('action-icon')
    open_card.append(open_icon)
    
    open_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    open_info.set_hexpand(True)
    open_title = Gtk.Label(label="Open Config File"); open_title.add_css_class('action-title'); open_title.set_halign(Gtk.Align.START)
    open_info.append(open_title)
    open_desc = Gtk.Label(label="Edit binds.conf directly"); open_desc.add_css_class('action-description'); open_desc.set_halign(Gtk.Align.START)
    open_info.append(open_desc)
    open_card.append(open_info)
    
    open_btn = Gtk.Button(label="Open")
    open_btn.set_valign(Gtk.Align.CENTER)
    
    def on_open(b):
        editor = os.environ.get('EDITOR', 'nano')
        terminal = os.environ.get('TERMINAL', 'kitty')
        conf_path = get_binds_conf_path()
        subprocess.Popen(f'{terminal} -e {editor} {conf_path}', shell=True)
    
    open_btn.connect('clicked', on_open)
    open_card.append(open_btn)
    box.append(open_card)
    
    # Reset to Default
    reset_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    reset_card.add_css_class('action-card')
    
    reset_icon = Gtk.Label(label=ICONS['reset']); reset_icon.add_css_class('action-icon')
    reset_card.append(reset_icon)
    
    reset_info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    reset_info.set_hexpand(True)
    reset_title = Gtk.Label(label="Reset to Default"); reset_title.add_css_class('action-title'); reset_title.set_halign(Gtk.Align.START)
    reset_info.append(reset_title)
    reset_desc = Gtk.Label(label="Restore default keybindings"); reset_desc.add_css_class('action-description'); reset_desc.set_halign(Gtk.Align.START)
    reset_info.append(reset_desc)
    reset_card.append(reset_info)
    
    reset_btn = Gtk.Button(label="Reset")
    reset_btn.add_css_class('destructive-action')
    reset_btn.set_valign(Gtk.Align.CENTER)
    reset_btn.connect('clicked', lambda b: _show_reset_dialog(window))
    reset_card.append(reset_btn)
    box.append(reset_card)
    
    section.add_content(box)


def _show_add_dialog(window):
    """Show dialog to add new keybind"""
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading="Add New Keybind",
        body="Enter the keybind details:"
    )
    
    content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    content_box.set_margin_top(12)
    
    # Modifier entry
    mods_entry = Gtk.Entry()
    mods_entry.set_placeholder_text("Modifiers (e.g., SUPER, SUPER SHIFT)")
    content_box.append(mods_entry)
    
    # Key entry
    key_entry = Gtk.Entry()
    key_entry.set_placeholder_text("Key (e.g., T, F1, Return)")
    content_box.append(key_entry)
    
    # Action dropdown
    action_combo = Gtk.ComboBoxText()
    for action in ['exec', 'killactive', 'workspace', 'movetoworkspace', 'togglefloating', 'fullscreen', 'movefocus']:
        action_combo.append_text(action)
    action_combo.set_active(0)
    content_box.append(action_combo)
    
    # Args entry
    args_entry = Gtk.Entry()
    args_entry.set_placeholder_text("Arguments (e.g., $terminal, 1, l)")
    content_box.append(args_entry)
    
    dialog.set_extra_child(content_box)
    
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("add", "Add")
    dialog.set_response_appearance("add", Adw.ResponseAppearance.SUGGESTED)
    
    def on_response(d, response):
        if response == "add":
            mods = mods_entry.get_text().strip()
            key = key_entry.get_text().strip()
            action = action_combo.get_active_text()
            args = args_entry.get_text().strip()
            
            if key and action:
                _add_keybind(window, mods, key, action, args)
    
    dialog.connect('response', on_response)
    dialog.present()


def _add_keybind(window, mods: str, key: str, action: str, args: str):
    """Add a new keybind"""
    keybinds = window.keybinds_data['keybinds']
    
    # Check for conflicts
    key_combo = f"{mods}+{key}".lower().replace(' ', '')
    
    for kb in keybinds:
        existing_combo = f"{kb['mods']}+{kb['key']}".lower().replace(' ', '')
        if existing_combo == key_combo and not kb['disabled']:
            _show_conflict_dialog(window, kb, mods, key, action, args)
            return
    
    # No conflict, add directly
    _append_keybind(window, mods, key, action, args)


def _show_conflict_dialog(window, existing_kb: Dict, mods: str, key: str, action: str, args: str):
    """Show conflict dialog"""
    existing_action = f"{existing_kb['action']} {existing_kb['args']}".strip()
    
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading="Keybind Conflict",
        body=f"The keybind '{format_key_display(mods, key)}' is already assigned to:\n\n{existing_action}\n\nWhat would you like to do?"
    )
    
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("replace", "Replace Existing")
    dialog.add_response("add_anyway", "Add Anyway")
    dialog.set_response_appearance("replace", Adw.ResponseAppearance.DESTRUCTIVE)
    
    def on_response(d, response):
        if response == "replace":
            # Comment out old keybind and add new
            _replace_keybind(window, existing_kb, mods, key, action, args)
        elif response == "add_anyway":
            _append_keybind(window, mods, key, action, args)
    
    dialog.connect('response', on_response)
    dialog.present()


def _append_keybind(window, mods: str, key: str, action: str, args: str):
    """Append new keybind to config"""
    content = window.keybinds_data['content']
    
    new_line = f"\nbind = {mods}, {key}, {action}"
    if args:
        new_line += f", {args}"
    
    content += new_line + "\n"
    
    if save_keybinds(content):
        _toast(window, f"Keybind added: {format_key_display(mods, key)}")
        # Reload page would be ideal here
    else:
        _toast(window, "Failed to save keybind")


def _replace_keybind(window, old_kb: Dict, mods: str, key: str, action: str, args: str):
    """Replace existing keybind"""
    content = window.keybinds_data['content']
    
    # Comment out old keybind
    old_line = old_kb['raw']
    content = content.replace(old_line, f"# {old_line}")
    
    # Add new keybind
    new_line = f"\nbind = {mods}, {key}, {action}"
    if args:
        new_line += f", {args}"
    
    content += new_line + "\n"
    
    if save_keybinds(content):
        _toast(window, f"Keybind replaced: {format_key_display(mods, key)}")
    else:
        _toast(window, "Failed to save keybind")


def _show_edit_dialog(window, kb: Dict):
    """Show edit dialog for a keybind"""
    _toast(window, f"Edit: {format_key_display(kb['mods'], kb['key'])} → {kb['action']}")
    # TODO: Implement full edit dialog


def _show_reset_dialog(window):
    """Show reset confirmation dialog"""
    dialog = Adw.MessageDialog(
        transient_for=window,
        heading="Reset to Default?",
        body="This will replace your current keybindings with the default configuration.\n\nA backup will be saved to binds.conf.backup"
    )
    
    dialog.add_response("cancel", "Cancel")
    dialog.add_response("reset", "Reset")
    dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE)
    
    def on_response(d, response):
        if response == "reset":
            if reset_to_default():
                _toast(window, "Keybinds reset to default!")
            else:
                _toast(window, "Failed to reset keybinds")
    
    dialog.connect('response', on_response)
    dialog.present()


def _toast(window, msg):
    if hasattr(window, 'toast_overlay'):
        toast = Adw.Toast(title=msg); toast.set_timeout(3)
        window.toast_overlay.add_toast(toast)