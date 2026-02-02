"""
THEME APPLIER - Applies to all apps: Control Center, Waybar, Rofi, Kitty
"""

import subprocess
import re
import json
from pathlib import Path
from datetime import datetime
from .themes import THEMES


class ThemeApplier:
    """Applies themes to all components"""
    
    def __init__(self):
        self.home = Path.home()
        self.assets_dir = self.home / ".config/hypr-control-center/assets"
        self.prefs_dir = self.home / ".config/hypr-control-center/preferences"
        self.waybar_dir = self.home / ".config/waybar"
        self.colorscheme_dir = self.home / ".config/hypr/colorscheme"
        self.rofi_dir = self.home / ".config/rofi"
        self.kitty_dir = self.home / ".config/kitty"
        
        for d in [self.assets_dir, self.prefs_dir, self.colorscheme_dir]:
            d.mkdir(parents=True, exist_ok=True)
    
    def apply_theme(self, theme_id: str) -> bool:
        if theme_id not in THEMES:
            return False
        
        theme = THEMES[theme_id]
        colors = theme["colors"]
        
        try:
            # Control Center CSS
            self._write_style_css(colors)
            self._write_panel_css(colors)
            self._write_widgets_css(colors)
            
            # Waybar colorscheme
            self._write_waybar_colorscheme(theme_id, colors)
            self._update_waybar_import(theme_id)
            
            # Rofi
            if "rofi" in theme:
                self._write_rofi_theme(theme_id, theme["rofi"])
                self._update_rofi_import(theme_id)
            
            # Kitty
            if "kitty" in theme:
                self._write_kitty_theme(theme["kitty"])
                self._update_kitty_include()
            
            self._save_preference(theme_id)
            self._reload_waybar()
            return True
        except Exception as e:
            print(f"[ThemeApplier] Error: {e}")
            return False
    
    def _write_style_css(self, c):
        css = f''':root {{
    --bg0: {c['bg0']}; --bg1: {c['bg1']}; --bg2: {c['bg2']}; --bg3: {c['bg3']}; --bg4: {c['bg4']};
    --fg: {c['fg']}; --grey0: {c['grey0']}; --grey1: {c['grey1']}; --grey2: {c['grey2']};
    --red: {c['red']}; --orange: {c['orange']}; --yellow: {c['yellow']};
    --green: {c['green']}; --aqua: {c['aqua']}; --blue: {c['blue']}; --purple: {c['purple']};
}}
@import url('panel.css');
@import url('widgets.css');

window {{ background-color: var(--bg1); }}
.sidebar {{ background-color: var(--bg0); border-right: 1px solid var(--bg3); }}
.content-area {{ background-color: var(--bg1); }}
.sidebar-item:selected {{ background-color: var(--blue); color: #000; }}
.page-title {{ color: var(--fg); }}
.settings-group {{ background-color: var(--bg0); border: 1px solid var(--bg3); border-radius: 12px; }}
.group-title {{ color: var(--blue); }}
.setting-label {{ color: var(--fg); }}
.setting-description {{ color: var(--grey1); }}
switch:checked {{ background-color: var(--blue); }}
.apply-button {{ background-color: var(--blue); color: white; }}
.reset-button {{ color: var(--red); }}
'''
        (self.assets_dir / "style.css").write_text(css)
    
    def _write_panel_css(self, c):
        css = f'''.panel-container {{ background: alpha({c['bg1']}, 0.9); border-radius: 14px; }}
.taskbar-item.focused {{ background: alpha({c['blue']}, 0.25); }}
.running-indicator {{ background: {c['blue']}; }}
'''
        (self.assets_dir / "panel.css").write_text(css)
    
    def _write_widgets_css(self, c):
        css = f'''.start-menu {{ background-color: alpha({c['bg0']}, 0.95); }}
.weather-compact {{ background: alpha({c['bg0']}, 0.92); }}
.sysmon-clean {{ background: alpha({c['bg0']}, 0.92); }}
'''
        (self.assets_dir / "widgets.css").write_text(css)
    
    def _write_waybar_colorscheme(self, theme_id, c):
        css = f'''/* {theme_id} */
@define-color bg0 {c['bg0']};
@define-color bg1 {c['bg1']};
@define-color bg2 {c['bg2']};
@define-color bg3 {c['bg3']};
@define-color bg4 {c['bg4']};
@define-color fg {c['fg']};
@define-color grey0 {c['grey0']};
@define-color grey1 {c['grey1']};
@define-color grey2 {c['grey2']};
@define-color red {c['red']};
@define-color orange {c['orange']};
@define-color yellow {c['yellow']};
@define-color green {c['green']};
@define-color aqua {c['aqua']};
@define-color blue {c['blue']};
@define-color purple {c['purple']};
'''
        self.colorscheme_dir.mkdir(parents=True, exist_ok=True)
        (self.colorscheme_dir / f"{theme_id}.css").write_text(css)
    
    def _update_waybar_import(self, theme_id):
        style_file = self.waybar_dir / "style.css"
        if not style_file.exists():
            return
        
        content = style_file.read_text()
        new_import = f"@import '../hypr/colorscheme/{theme_id}.css';"
        
        # Replace existing @import colorscheme
        if re.search(r"@import\s+['\"]?[^;]*colorscheme[^;]*", content):
            content = re.sub(r"@import\s+['\"]?[^;]*colorscheme[^;]*['\"]?;?", new_import, content)
        else:
            content = new_import + "\n\n" + content
        
        style_file.write_text(content)
    
    def _write_rofi_theme(self, theme_id, rofi):
        rasi = f'''* {{
    background:     {rofi['background']}FF;
    background-alt: {rofi['background-alt']}FF;
    foreground:     {rofi['foreground']}FF;
    selected:       {rofi['selected']}FF;
    active:         {rofi['active']}FF;
    urgent:         {rofi['urgent']}FF;
}}
'''
        # Write to colors folder
        (self.rofi_dir / "colors").mkdir(parents=True, exist_ok=True)
        (self.rofi_dir / "colors" / f"{theme_id}.rasi").write_text(rasi)
    
    def _update_rofi_import(self, theme_id):
        """Update @import in rofi colors.rasi - checks zenpy-rofi first"""
        possible_files = [
            self.rofi_dir / "zenpy-rofi" / "colors.rasi",
            self.rofi_dir / "colors.rasi",
        ]
        
        new_import = f'@import "~/.config/rofi/colors/{theme_id}.rasi"'
        
        for colors_file in possible_files:
            if colors_file.exists():
                content = colors_file.read_text()
                # Replace @import line
                if "@import" in content:
                    content = re.sub(r'@import\s+"[^"]*\.rasi"', new_import, content)
                else:
                    content = new_import + "\n" + content
                colors_file.write_text(content)
                return
        
        # Create if not exists
        (self.rofi_dir / "zenpy-rofi").mkdir(parents=True, exist_ok=True)
        (self.rofi_dir / "zenpy-rofi" / "colors.rasi").write_text(f'{new_import}\n')
    
    def _write_kitty_theme(self, kitty):
        """Write ~/.config/kitty/theme.conf"""
        self.kitty_dir.mkdir(parents=True, exist_ok=True)
        
        lines = ["# Auto-generated by Hyprland Control Center", ""]
        for key, val in kitty.items():
            lines.append(f"{key}  {val}")
        
        (self.kitty_dir / "theme.conf").write_text("\n".join(lines))
    
    def _update_kitty_include(self):
        """Add include theme.conf to kitty.conf and remove inline colors"""
        kitty_conf = self.kitty_dir / "kitty.conf"
        if not kitty_conf.exists():
            return
        
        content = kitty_conf.read_text()
        
        if "include theme.conf" in content:
            return
        
        # Remove existing color definitions
        lines = []
        skip_patterns = ['background ', 'foreground ', 'cursor ', 'selection_',
                         'color0 ', 'color1 ', 'color2 ', 'color3 ', 'color4 ',
                         'color5 ', 'color6 ', 'color7 ', 'color8 ', 'color9 ',
                         'color10 ', 'color11 ', 'color12 ', 'color13 ', 'color14 ', 'color15 ']
        
        for line in content.split('\n'):
            stripped = line.strip()
            # Skip color definitions
            if any(stripped.startswith(p) for p in skip_patterns):
                continue
            # Skip color-related comments
            if stripped.startswith('#') and any(x in stripped.lower() for x in 
                ['gruvbox', 'color', 'theme', 'auto-generated', 'adapta', 'red', 'green', 'blue', 'yellow', 'magenta', 'cyan', 'black', 'white']):
                continue
            lines.append(line)
        
        lines.append("")
        lines.append("# Theme - managed by Hyprland Control Center")
        lines.append("include theme.conf")
        
        kitty_conf.write_text("\n".join(lines))
    
    def _save_preference(self, theme_id):
        self.prefs_dir.mkdir(parents=True, exist_ok=True)
        (self.prefs_dir / "theme.json").write_text(json.dumps({
            "current_theme": theme_id,
            "last_updated": datetime.now().isoformat()
        }, indent=2))
    
    def get_current_theme(self) -> str:
        prefs = self.prefs_dir / "theme.json"
        if prefs.exists():
            try:
                return json.loads(prefs.read_text()).get("current_theme", "one-dark")
            except:
                pass
        return "one-dark"
    
    def _reload_waybar(self):
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], check=False)
