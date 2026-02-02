"""WAYBAR SECTION - Full Waybar Panel Configuration
Complete with ALL features + Bug Fixes

FEATURES:
- Panel style presets with auto-fill
- Workspace visibility toggle (hide/show)
- Workspace number formats (Numbers, Korean, Chinese, Japanese, Nerd Icons, Custom)
- Font family selector (Adwaita Sans, JetBrains Mono, GeistMono, etc.)
- Expanded font size options (8-32px)
- Module and workspace button radius controls
- Panel behavior (Position, Display, Exclusive Zone, Layer)
- Custom pacman module styling
- Start-menu config preservation
- Reset defaults functionality

BUG FIXES:
- Proper JSON handling for workspace visibility (no more parsing errors)
- Reset defaults properly restores ALL sizes and values
- Import error handling for module loading
"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GLib
import json, subprocess, shutil, re
from pathlib import Path
from datetime import datetime

# Handle imports - try relative first, then absolute
try:
    from .panel_styles import PANEL_STYLE_PRESETS, get_preset_defaults
    from .ui_components import ColorPickerRow, create_section_header, create_setting_row, create_size_buttons
    from .previews import WaybarPreviewWidget
    from .helpers import get_monitor_list, get_current_waybar_output, get_current_waybar_position, update_waybar_config_field
except ImportError:
    from panel_styles import PANEL_STYLE_PRESETS, get_preset_defaults
    from ui_components import ColorPickerRow, create_section_header, create_setting_row, create_size_buttons
    from previews import WaybarPreviewWidget
    from helpers import get_monitor_list, get_current_waybar_output, get_current_waybar_position, update_waybar_config_field

WAYBAR_DIR = Path.home() / ".config/waybar"
WAYBAR_STYLE = WAYBAR_DIR / "style.css"
WAYBAR_CONFIG = WAYBAR_DIR / "config.jsonc"
PREFERENCES_DIR = Path.home() / ".config/hypr-control-center/preferences"

# ═══════════════════════════════════════════════════════════════════════════════
# WORKSPACE NUMBER FORMATS
# ═══════════════════════════════════════════════════════════════════════════════

WORKSPACE_NUMBER_FORMATS = {
    "numbers": {
        "name": "Numbers (1-5)",
        "icons": {"1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "7": "7", "8": "8", "9": "9", "10": "10"}
    },
    "korean": {
        "name": "Korean (일-오)",
        "icons": {"1": "일", "2": "이", "3": "삼", "4": "사", "5": "오", "6": "육", "7": "칠", "8": "팔", "9": "구", "10": "십"}
    },
    "chinese": {
        "name": "Chinese (一-五)",
        "icons": {"1": "一", "2": "二", "3": "三", "4": "四", "5": "五", "6": "六", "7": "七", "8": "八", "9": "九", "10": "十"}
    },
    "japanese": {
        "name": "Japanese (壱-伍)",
        "icons": {"1": "壱", "2": "弐", "3": "参", "4": "肆", "5": "伍", "6": "六", "7": "七", "8": "八", "9": "九", "10": "拾"}
    },
    "roman": {
        "name": "Roman (I-V)",
        "icons": {"1": "I", "2": "II", "3": "III", "4": "IV", "5": "V", "6": "VI", "7": "VII", "8": "VIII", "9": "IX", "10": "X"}
    },
    "nerd-dots": {
        "name": "Nerd Dots (󰎤-󰎩)",
        "icons": {"1": "󰎤", "2": "󰎧", "3": "󰎪", "4": "󰎭", "5": "󰎱", "6": "󰎳", "7": "󰎶", "8": "󰎹", "9": "󰎼", "10": "󰽽"}
    },
    "nerd-circles": {
        "name": "Nerd Circles (①-⑤)",
        "icons": {"1": "①", "2": "②", "3": "③", "4": "④", "5": "⑤", "6": "⑥", "7": "⑦", "8": "⑧", "9": "⑨", "10": "⑩"}
    },
    "nerd-squares": {
        "name": "Nerd Squares (󰎣-󰎨)",
        "icons": {"1": "󰎣", "2": "󰎦", "3": "󰎩", "4": "󰎬", "5": "󰎮", "6": "󰎰", "7": "󰎵", "8": "󰎸", "9": "󰎻", "10": "󰎾"}
    },
    "symbols": {
        "name": "Symbols (󰋜 󰈹 󰨞 󰙯 󰝚)",
        "icons": {"1": "󰋜", "2": "󰈹", "3": "󰨞", "4": "󰙯", "5": "󰝚", "6": "󰒱", "7": "󰊗", "8": "󰎈", "9": "󰘐", "10": "󰟀"}
    },
    "empty": {
        "name": "Empty (no labels)",
        "icons": {"1": "", "2": "", "3": "", "4": "", "5": "", "6": "", "7": "", "8": "", "9": "", "10": ""}
    },
    "custom": {
        "name": "Custom",
        "icons": {"1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "7": "7", "8": "8", "9": "9", "10": "10"}
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# FONT FAMILIES
# ═══════════════════════════════════════════════════════════════════════════════

FONT_FAMILIES = [
    ("Adwaita Sans", '"Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif'),
    ("JetBrains Mono", '"JetBrainsMono Nerd Font", "JetBrainsMono Nerd Font Propo", monospace'),
    ("GeistMono", '"GeistMono Nerd Font Mono", "GeistMono Nerd Font", monospace'),
    ("FiraCode", '"FiraCode Nerd Font", "Fira Code", monospace'),
    ("CaskaydiaCove", '"CaskaydiaCove Nerd Font", "Cascadia Code", monospace'),
    ("Iosevka", '"Iosevka Nerd Font", "Iosevka", monospace'),
    ("Hack", '"Hack Nerd Font", "Hack", monospace'),
    ("Ubuntu Mono", '"UbuntuMono Nerd Font", "Ubuntu Mono", monospace'),
    ("SF Pro", '"SF Pro Display", "SF Pro", sans-serif'),
    ("Inter", '"Inter", "Inter Nerd Font", sans-serif'),
]

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER: Parse JSONC (JSON with comments)
# ═══════════════════════════════════════════════════════════════════════════════

def parse_jsonc(content: str) -> dict:
    """Parse JSON with comments"""
    clean = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
    clean = re.sub(r'/\*.*?\*/', '', clean, flags=re.DOTALL)
    clean = re.sub(r',(\s*[}\]])', r'\1', clean)
    return json.loads(clean)


def read_waybar_config() -> dict:
    """Read and parse waybar config.jsonc"""
    try:
        if WAYBAR_CONFIG.exists():
            return parse_jsonc(WAYBAR_CONFIG.read_text())
    except Exception as e:
        print(f"Error reading waybar config: {e}")
    return {}


# ═══════════════════════════════════════════════════════════════════════════════
# START MENU CONFIG PRESERVATION
# ═══════════════════════════════════════════════════════════════════════════════

def ensure_start_menu_config():
    """Ensure start-menu config exists in waybar config.jsonc"""
    try:
        if not WAYBAR_CONFIG.exists():
            return False
        
        content = WAYBAR_CONFIG.read_text()
        
        if '"custom/start-menu"' in content:
            return True
        
        insert_pos = content.rfind('}')
        if insert_pos > 0:
            scripts_dir = Path.home() / ".config/hypr-control-center/scripts"
            start_menu_json = f'''
    "custom/start-menu": {{
        "format": "  ",
        "tooltip": true,
        "on-click": "{scripts_dir}/start-menu-toggle.sh",
        "on-click-right": "{scripts_dir}/start-menu-toggle.sh close"
    }}'''
            
            before_brace = content[:insert_pos].rstrip()
            needs_comma = not before_brace.endswith(',') and not before_brace.endswith('{')
            
            new_content = content[:insert_pos]
            if needs_comma:
                new_content = new_content.rstrip() + ','
            new_content += start_menu_json + '\n' + content[insert_pos:]
            
            WAYBAR_CONFIG.write_text(new_content)
            return True
        return False
    except Exception as e:
        print(f"Error ensuring start-menu config: {e}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# WORKSPACE CONFIG MANAGEMENT - FIXED JSON HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

def get_workspace_config() -> dict:
    """Get current workspace configuration from waybar config"""
    defaults = {
        "visible": True,
        "format": "numbers",
        "persistent_count": 5,
        "disable_scroll": True,
        "sort_by_name": True
    }
    
    try:
        if not WAYBAR_CONFIG.exists():
            return defaults
        
        content = WAYBAR_CONFIG.read_text()
        
        # Check visibility - ONLY look in modules-left array
        modules_left_match = re.search(r'"modules-left"\s*:\s*\[([^\]]*)\]', content, re.DOTALL)
        if modules_left_match:
            modules_left_content = modules_left_match.group(1)
            defaults["visible"] = '"hyprland/workspaces"' in modules_left_content
        
        config = read_waybar_config()
        ws_config = config.get("hyprland/workspaces", {})
        
        # Detect format from icons
        icons = ws_config.get("format-icons", {})
        if icons:
            for fmt_id, fmt_data in WORKSPACE_NUMBER_FORMATS.items():
                if fmt_data["icons"].get("1") == icons.get("1"):
                    defaults["format"] = fmt_id
                    break
        
        # Get persistent count
        persistent = ws_config.get("persistent-workspaces", {})
        if "*" in persistent:
            defaults["persistent_count"] = persistent["*"]
        
        defaults["disable_scroll"] = ws_config.get("disable-scroll", True)
        defaults["sort_by_name"] = ws_config.get("sort-by-name", True)
        
        return defaults
    except Exception as e:
        print(f"Error getting workspace config: {e}")
        return defaults


def update_workspace_visibility(visible: bool) -> bool:
    """Show or hide workspaces in waybar - FIXED with proper JSON handling
    
    IMPORTANT: Only modify the modules-left array, NOT the "hyprland/workspaces": {} definition
    """
    try:
        if not WAYBAR_CONFIG.exists():
            return False
        
        content = WAYBAR_CONFIG.read_text()
        
        # Find the modules-left array boundaries
        modules_left_match = re.search(r'"modules-left"\s*:\s*\[([^\]]*)\]', content, re.DOTALL)
        if not modules_left_match:
            print("Could not find modules-left array")
            return False
        
        modules_left_content = modules_left_match.group(1)
        modules_left_start = modules_left_match.start(1)
        modules_left_end = modules_left_match.end(1)
        
        if visible:
            # Add to modules-left if not present in the array
            if '"hyprland/workspaces"' not in modules_left_content:
                # Add at the beginning of the array
                new_modules_content = '\n        "hyprland/workspaces",' + modules_left_content
                new_content = content[:modules_left_start] + new_modules_content + content[modules_left_end:]
                WAYBAR_CONFIG.write_text(new_content)
        else:
            # Remove ONLY from modules-left array, not from the whole file
            # This preserves the "hyprland/workspaces": {} definition
            
            # Pattern 1: "hyprland/workspaces", (with trailing comma)
            new_modules = re.sub(r'"hyprland/workspaces"\s*,\s*', '', modules_left_content)
            # Pattern 2: , "hyprland/workspaces" (with leading comma)
            new_modules = re.sub(r',\s*"hyprland/workspaces"', '', new_modules)
            # Pattern 3: "hyprland/workspaces" alone
            new_modules = re.sub(r'^\s*"hyprland/workspaces"\s*$', '', new_modules)
            
            # Clean up any double commas or leading/trailing commas
            new_modules = re.sub(r',\s*,', ',', new_modules)
            new_modules = re.sub(r'^\s*,', '', new_modules)
            new_modules = re.sub(r',\s*$', '', new_modules)
            
            new_content = content[:modules_left_start] + new_modules + content[modules_left_end:]
            WAYBAR_CONFIG.write_text(new_content)
        
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
        return True
    except Exception as e:
        print(f"Error updating workspace visibility: {e}")
        return False


def update_workspace_format(format_id: str, custom_icons: dict = None) -> bool:
    """Update workspace number format"""
    try:
        if not WAYBAR_CONFIG.exists():
            return False
        
        content = WAYBAR_CONFIG.read_text()
        
        if format_id == "custom" and custom_icons:
            icons = custom_icons
        else:
            icons = WORKSPACE_NUMBER_FORMATS.get(format_id, WORKSPACE_NUMBER_FORMATS["numbers"])["icons"]
        
        # Build format-icons JSON with proper indentation
        icons_lines = []
        for k, v in icons.items():
            icons_lines.append(f'"{k}": "{v}"')
        icons_str = ',\n                '.join(icons_lines)
        new_icons = '{\n                ' + icons_str + '\n            }'
        
        pattern = r'("format-icons"\s*:\s*)\{[^}]+\}'
        
        if re.search(pattern, content, re.DOTALL):
            content = re.sub(pattern, r'\g<1>' + new_icons, content, flags=re.DOTALL)
            WAYBAR_CONFIG.write_text(content)
            subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
            return True
        
        return False
    except Exception as e:
        print(f"Error updating workspace format: {e}")
        return False


def update_workspace_persistent_count(count: int) -> bool:
    """Update number of persistent workspaces"""
    try:
        if not WAYBAR_CONFIG.exists():
            return False
        
        content = WAYBAR_CONFIG.read_text()
        pattern = r'("persistent-workspaces"\s*:\s*\{\s*"\*"\s*:\s*)\d+'
        
        if re.search(pattern, content):
            content = re.sub(pattern, rf'\g<1>{count}', content)
            WAYBAR_CONFIG.write_text(content)
            subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
            return True
        
        return False
    except Exception as e:
        print(f"Error updating persistent count: {e}")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# PANEL STYLE PREFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

def get_current_panel_style() -> str:
    prefs_file = PREFERENCES_DIR / "panel-style.json"
    if prefs_file.exists():
        try:
            data = json.loads(prefs_file.read_text())
            return data.get("preset_id", "classic")
        except:
            pass
    return "classic"


def save_panel_style_preference(preset_id: str, custom: dict = None):
    PREFERENCES_DIR.mkdir(parents=True, exist_ok=True)
    prefs_file = PREFERENCES_DIR / "panel-style.json"
    data = {"preset_id": preset_id, "custom": custom or {}, "updated": datetime.now().isoformat()}
    prefs_file.write_text(json.dumps(data, indent=2))


# ═══════════════════════════════════════════════════════════════════════════════
# CSS GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

def generate_waybar_css(preset_id: str, custom: dict = None) -> str:
    """Generate complete waybar CSS from preset + custom overrides"""
    preset = PANEL_STYLE_PRESETS.get(preset_id, PANEL_STYLE_PRESETS["classic"])
    base = preset.get("base", {}).copy()
    ws = preset.get("workspaces", {}).copy()
    hover = preset.get("hover", {}).copy()
    colors = preset.get("colors", {}).copy()
    
    # Apply custom overrides
    if custom:
        if "base" in custom:
            base.update(custom["base"])
        if "workspaces" in custom:
            ws.update(custom["workspaces"])
        if "hover" in custom:
            hover.update(custom["hover"])
        if "colors" in custom:
            colors.update(custom["colors"])
    
    # Get values with defaults
    opacity = base.get("opacity", 0.5)
    bar_radius = base.get("bar_radius", 15)
    module_radius = base.get("module_radius", 45)
    font_size = base.get("font_size", 15)
    font_family = base.get("font_family", '"Adwaita Sans", "JetBrainsMono Nerd Font Propo", sans-serif')
    border = base.get("border", "none")
    padding = base.get("padding", "0 15px")
    margin = base.get("margin", "0 0 0 12px")
    
    bar_bg_color = base.get("bar_bg_color", "@bg0")
    module_bg_color = base.get("module_bg_color", "@bg0")
    module_opacity = base.get("module_opacity", 0.9)
    border_color = base.get("border_color", "@bg1")
    
    # Background calculations
    bar_bg = f"alpha({bar_bg_color}, {opacity:.2f})" if opacity > 0 else "transparent"
    module_bg = f"alpha({module_bg_color}, {module_opacity:.2f})" if module_opacity > 0 else "rgba(255, 255, 255, 0.1)"
    
    if "module_background" in base and not base.get("module_bg_color"):
        module_bg = base["module_background"]
    
    # Border style
    if border and border != "none":
        border_css = f"border: {border};"
    elif base.get("border_color"):
        border_css = f"border: 1px solid {border_color};"
    else:
        border_css = "border: 1px solid @bg1;"
    
    # Workspace values
    ws_container_bg = ws.get("container_bg", "alpha(@bg0, 0.21)")
    ws_container_radius = ws.get("container_radius", 26)
    ws_container_padding = ws.get("container_padding", "5px 3px")
    ws_container_border = ws.get("container_border", "1px solid @bg1")
    ws_btn_bg = ws.get("button_bg", "@bg1")
    ws_btn_radius = ws.get("button_radius", 16)
    ws_btn_width = ws.get("button_width", 22)
    ws_active_bg = ws.get("active_bg", "@blue")
    ws_active_width = ws.get("active_width", 50)
    ws_hover_bg = ws.get("hover_bg", "@purple")
    ws_urgent_bg = ws.get("urgent_bg", "@red")
    ws_border_css = f"border: {ws_container_border};" if ws_container_border and ws_container_border != "none" else ""
    
    # Module colors CSS - INCLUDING PACMAN
    module_colors_css = "\n/* Module Colors */\n"
    default_colors = {
        "cpu": "@blue", "memory": "@green", "temperature": "@orange",
        "pulseaudio": "@yellow", "battery": "@green", "bluetooth": "@blue",
        "clock": "@blue", "network": "@purple", "pacman": "@cyan"
    }
    mc = {**default_colors, **colors}
    
    for mod, color in mc.items():
        if mod == "battery_charging":
            module_colors_css += f"#battery.charging {{ color: {color}; }}\n"
        elif mod == "battery_warning":
            module_colors_css += f"#battery.warning:not(.charging) {{ color: {color}; }}\n"
        elif mod == "pacman":
            module_colors_css += f"#custom-pacman {{ color: {color}; }}\n"
        elif mod == "menuApp":
            module_colors_css += f"#custom-menuApp {{ color: {color}; }}\n"
        elif mod == "music":
            module_colors_css += f"#custom-music {{ color: {color}; }}\n"
        elif mod not in ["battery_charging", "battery_warning"]:
            module_colors_css += f"#{mod} {{ color: {color}; }}\n"
    
    # Hover CSS
    hover_type = hover.get("type", "glow")
    hover_css = "\n/* Hover Effects */\n"
    
    modules = ["cpu", "memory", "temperature", "pulseaudio", "battery", "bluetooth", "clock", "network"]
    
    if hover_type == "glow":
        for mod in modules:
            mod_color = mc.get(mod, "@blue")
            hover_css += f"""#{mod}:hover {{
    background: alpha({mod_color}, 0.12);
    text-shadow: 0px 0px 2px alpha({mod_color}, 0.6);
}}
"""
        pacman_color = mc.get("pacman", "@cyan")
        hover_css += f"""#custom-pacman:hover {{
    background: alpha({pacman_color}, 0.12);
    text-shadow: 0px 0px 2px alpha({pacman_color}, 0.6);
}}
"""
    else:
        hover_bg = hover.get("background", "rgba(69,71,90,0.55)")
        hover_text = hover.get("text_color", "")
        hover_radius = hover.get("radius", 16)
        
        for mod in modules:
            hover_css += f"#{mod}:hover {{\n"
            hover_css += f"    background: {hover_bg};\n"
            if hover_radius:
                hover_css += f"    border-radius: {hover_radius}px;\n"
            if hover_text:
                hover_css += f"    color: {hover_text};\n"
            hover_css += "}\n"
        
        hover_css += f"#custom-pacman:hover {{\n"
        hover_css += f"    background: {hover_bg};\n"
        if hover_radius:
            hover_css += f"    border-radius: {hover_radius}px;\n"
        if hover_text:
            hover_css += f"    color: {hover_text};\n"
        hover_css += "}\n"
    
    # Generate full CSS
    css = f"""/* Waybar Style: {preset.get('name', 'Custom')} - Generated {datetime.now().strftime("%Y-%m-%d %H:%M")} */
@import '../hypr/colorscheme/current.css';

* {{
    font-family: {font_family};
    font-size: {font_size}px;
    font-weight: bold;
    min-height: 0;
    border: none;
    border-radius: 0;
    padding: 0;
    margin: 0;
}}

#waybar {{
    background: {bar_bg};
    border-radius: {bar_radius}px;
    color: @fg;
    margin: 3px;
    margin-bottom: 0px;
}}

tooltip {{
    background: @bg0;
    border: 1px solid @bg3;
    border-radius: 12px;
}}

tooltip label {{
    color: @fg;
    padding: 6px;
}}

.modules-center, .modules-left, .modules-right {{
    background-color: transparent;
    margin: 3px;
    padding: 4px;
}}

/* ═══════════════════════════════════════════════════════════════════════════
   SYSTEM MODULES
   ═══════════════════════════════════════════════════════════════════════════ */
#bluetooth, #temperature, #custom-music, #clock, #battery, #pulseaudio,
#network, #cpu, #memory, #custom-menuApp, #custom-power, #custom-switcher,
#custom-notification, #custom-pacman, #tray {{
    background-color: {module_bg};
    padding: {padding};
    margin: {margin};
    border-radius: {module_radius}px;
    {border_css}
    transition: all 0.3s ease;
}}

{module_colors_css}
{hover_css}

/* ═══════════════════════════════════════════════════════════════════════════
   PACMAN UPDATES MODULE - State Classes
   ═══════════════════════════════════════════════════════════════════════════ */
#custom-pacman.updated {{
    color: @green;
    background: alpha(@green, 0.15);
}}

#custom-pacman.pending {{
    color: @blue;
    background: alpha(@blue, 0.15);
}}

#custom-pacman.warning {{
    color: @yellow;
    background: alpha(@yellow, 0.15);
}}

#custom-pacman.critical {{
    color: @red;
    background: alpha(@red, 0.15);
}}

/* ═══════════════════════════════════════════════════════════════════════════
   WORKSPACES
   ═══════════════════════════════════════════════════════════════════════════ */
#workspaces {{
    background-color: {ws_container_bg};
    border-radius: {ws_container_radius}px;
    padding: {ws_container_padding};
    margin-left: 5px;
    {ws_border_css}
    transition: all 0.5s ease-in-out;
}}

#workspaces button {{
    background-color: {ws_btn_bg};
    border-radius: {ws_btn_radius}px;
    padding: 0px;
    margin-right: 5px;
    min-width: {ws_btn_width}px;
    transition: all 0.5s ease-out;
}}

#workspaces button.active {{
    min-width: {ws_active_width}px;
    background-color: {ws_active_bg};
}}

#workspaces button:hover {{
    background-color: {ws_hover_bg};
}}

#workspaces button.urgent {{
    background-color: {ws_urgent_bg};
}}

/* ═══════════════════════════════════════════════════════════════════════════
   TASKBAR
   ═══════════════════════════════════════════════════════════════════════════ */
#taskbar {{
    background-color: {module_bg};
    padding: 5px 6px;
    margin: 0 0 0 24px;
    border-radius: 18px;
    {border_css}
}}

#taskbar button {{
    padding: 0.4em 0.8em;
    margin: 0 4px;
    border-radius: 13px;
    background-color: @bg1;
    color: @fg;
    transition: all 0.25s ease-in-out;
}}

#taskbar button.active {{
    background-color: @blue;
    color: @bg0;
}}

#taskbar button:hover {{
    background-color: @bg3;
    color: @fg;
}}

#custom-taskbar {{
    background-color: {module_bg};
    padding: 0 30px;
    margin: 0 0 0 24px;
    border-radius: {module_radius}px;
    {border_css}
    font-family: "JetBrainsMono Nerd Font Propo";
    font-size: 24px;
    color: @fg;
}}

/* ═══════════════════════════════════════════════════════════════════════════
   START MENU
   ═══════════════════════════════════════════════════════════════════════════ */
#custom-start-menu {{
    background-size: 24px 24px;
    background-repeat: no-repeat;
    background-position: center;
    min-width: 36px;
    min-height: 36px;
    border-radius: 50%;
    padding: 0;
    margin-left: 8px;
}}

#custom-start-menu:hover {{
    background-color: alpha(@bg0, 0.6);
}}

/* ═══════════════════════════════════════════════════════════════════════════
   MUSIC MODULE
   ═══════════════════════════════════════════════════════════════════════════ */
#custom-music {{
    font-size: {max(font_size - 1, 12)}px;
}}

#custom-music:hover {{
    border-radius: 16px;
    background-color: rgba(69, 71, 90, 0.55);
}}

/* ═══════════════════════════════════════════════════════════════════════════
   TRAY
   ═══════════════════════════════════════════════════════════════════════════ */
#tray {{
    padding: 0px 5px;
}}

#tray > .passive {{
    -gtk-icon-effect: dim;
}}

#tray > .needs-attention {{
    -gtk-icon-effect: highlight;
    background-color: @red;
}}
"""
    return css


def apply_waybar_style(preset_id: str, window=None, custom: dict = None) -> bool:
    """Apply waybar style and reload"""
    try:
        css = generate_waybar_css(preset_id, custom)
        
        if WAYBAR_STYLE.exists():
            shutil.copy(WAYBAR_STYLE, WAYBAR_STYLE.with_suffix('.css.bak'))
        
        WAYBAR_STYLE.write_text(css)
        save_panel_style_preference(preset_id, custom)
        ensure_start_menu_config()
        
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
        
        if window and hasattr(window, '_show_toast'):
            window._show_toast(f"✅ Applied: {PANEL_STYLE_PRESETS.get(preset_id, {}).get('name', preset_id)}")
        
        return True
    except Exception as e:
        print(f"Error applying style: {e}")
        return False


def reset_to_defaults(window, preset_id: str = "classic"):
    """Reset all UI controls to preset defaults - COMPLETE RESET"""
    defaults = get_preset_defaults(preset_id)
    preset = PANEL_STYLE_PRESETS.get(preset_id, PANEL_STYLE_PRESETS["classic"])
    preset_ws = preset.get("workspaces", {})
    
    ui = window.ui_controls
    
    # Style dropdown
    if "style_dropdown" in ui:
        preset_ids = list(PANEL_STYLE_PRESETS.keys())
        idx = preset_ids.index(preset_id) if preset_id in preset_ids else 0
        ui["style_dropdown"].set_selected(idx)
    
    # Font settings
    if "font_family_dropdown" in ui:
        ui["font_family_dropdown"].set_selected(0)
    if "font_size_spin" in ui:
        ui["font_size_spin"].set_value(15)
    
    # Panel appearance
    if "opacity_scale" in ui:
        ui["opacity_scale"].set_value(0.5)
    if "bar_radius_spin" in ui:
        ui["bar_radius_spin"].set_value(15)
    if "module_radius_spin" in ui:
        ui["module_radius_spin"].set_value(45)
    if "mod_opacity_scale" in ui:
        ui["mod_opacity_scale"].set_value(0.9)
    if "height_spin" in ui:
        ui["height_spin"].set_value(36)
    
    # Workspace settings
    if "ws_visible_switch" in ui:
        ui["ws_visible_switch"].set_active(True)
    if "ws_format_dropdown" in ui:
        ui["ws_format_dropdown"].set_selected(0)
    if "ws_count_spin" in ui:
        ui["ws_count_spin"].set_value(5)
    if "ws_container_radius_spin" in ui:
        ui["ws_container_radius_spin"].set_value(26)
    if "ws_btn_radius_spin" in ui:
        ui["ws_btn_radius_spin"].set_value(16)
    if "ws_width_spin" in ui:
        ui["ws_width_spin"].set_value(50)
    
    # Hover settings
    if "hover_radius_spin" in ui:
        ui["hover_radius_spin"].set_value(16)
    if "hover_bg_entry" in ui:
        ui["hover_bg_entry"].set_text("rgba(69,71,90,0.55)")
    if "hover_text_entry" in ui:
        ui["hover_text_entry"].set_text("")
    
    # Waybar colors
    color_defaults = {
        "bar_bg_color": "#282c34",
        "module_bg_color": "#282c34",
        "border_color": "#3e4451",
        "ws_active": "#61afef",
        "ws_hover": "#c678dd",
        "ws_urgent": "#e06c75"
    }
    if hasattr(window, 'waybar_color_rows'):
        for key, color in color_defaults.items():
            if key in window.waybar_color_rows:
                window.waybar_color_rows[key].set_color(color)
    
    # Module colors
    module_defaults = {
        "cpu": "#61afef",
        "memory": "#98c379",
        "clock": "#61afef",
        "pulseaudio": "#e5c07b",
        "network": "#c678dd",
        "bluetooth": "#61afef",
        "battery": "#98c379",
        "temperature": "#d19a66",
        "pacman": "#56b6c2"
    }
    if hasattr(window, 'module_color_rows'):
        for key, color in module_defaults.items():
            if key in window.module_color_rows:
                window.module_color_rows[key].set_color(color)
    
    # Clear custom overrides
    window.waybar_custom = {}
    
    # Reset workspace config
    update_workspace_format("numbers")
    update_workspace_visibility(True)
    update_workspace_persistent_count(5)
    
    # Apply the reset
    apply_waybar_style(preset_id, window, None)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN UI BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

def build_waybar_section_for_expander(window) -> Gtk.Widget:
    """Build waybar section content suitable for an Expander widget
    
    This is a wrapper that handles errors gracefully and returns
    content that works well inside an Expander.
    """
    try:
        content = build_waybar_section(window)
        # Remove margins since expander handles them
        content.set_margin_start(0)
        content.set_margin_end(0)
        content.set_margin_top(8)
        content.set_margin_bottom(8)
        return content
    except Exception as e:
        print(f"Error building waybar section: {e}")
        import traceback
        traceback.print_exc()
        
        # Return error message widget
        error_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        error_box.set_margin_start(16)
        error_box.set_margin_end(16)
        error_box.set_margin_top(16)
        error_box.set_margin_bottom(16)
        
        error_label = Gtk.Label()
        error_label.set_markup(f"<span color='#e06c75'>⚠️ Error loading Waybar settings</span>")
        error_label.set_xalign(0)
        error_box.append(error_label)
        
        detail_label = Gtk.Label()
        detail_label.set_markup(f"<small>{str(e)}</small>")
        detail_label.add_css_class("dim-label")
        detail_label.set_xalign(0)
        detail_label.set_wrap(True)
        error_box.append(detail_label)
        
        return error_box


def build_waybar_section(window) -> Gtk.Box:
    """Build the complete Waybar configuration section"""
    main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    main_box.set_margin_start(16)
    main_box.set_margin_end(16)
    main_box.set_margin_top(16)
    main_box.set_margin_bottom(16)
    
    # Initialize storage
    if not hasattr(window, 'waybar_custom'):
        window.waybar_custom = {}
    if not hasattr(window, 'ui_controls'):
        window.ui_controls = {}
    else:
        window.ui_controls = {}  # Reset for fresh build
    
    current_preset = get_current_panel_style()
    defaults = get_preset_defaults(current_preset)
    ws_config = get_workspace_config()
    
    ensure_start_menu_config()
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PREVIEW
    # ═══════════════════════════════════════════════════════════════════════════
    try:
        preview_frame = Gtk.Frame()
        preview_frame.add_css_class("card")
        preview = WaybarPreviewWidget({}, {})
        window.waybar_preview = preview
        preview_frame.set_child(preview)
        main_box.append(preview_frame)
    except Exception as e:
        print(f"Preview widget error: {e}")
    
    # Content container (NO ScrolledWindow - parent expander handles scrolling)
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    content.set_margin_top(8)
    
    # Debounce timer for auto-apply
    if not hasattr(window, '_apply_timeout_id'):
        window._apply_timeout_id = None
    
    def do_apply_now():
        """Actually apply the style"""
        preset_ids = list(PANEL_STYLE_PRESETS.keys())
        idx = window.ui_controls.get("style_dropdown", Gtk.DropDown()).get_selected()
        preset_id = preset_ids[idx] if idx < len(preset_ids) else "classic"
        apply_waybar_style(preset_id, window, window.waybar_custom)
        window._apply_timeout_id = None
        return False
    
    def do_apply():
        """Apply with debounce"""
        if window._apply_timeout_id:
            GLib.source_remove(window._apply_timeout_id)
        window._apply_timeout_id = GLib.timeout_add(300, do_apply_now)
    
    window.do_apply = do_apply
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PANEL STYLE PRESET
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("PANEL STYLE PRESET"))
    
    style_row = create_setting_row("Style", "Choose a preset - auto-fills all settings")
    preset_ids = list(PANEL_STYLE_PRESETS.keys())
    preset_names = [PANEL_STYLE_PRESETS[p]["name"] for p in preset_ids]
    
    style_dd = Gtk.DropDown()
    style_dd.set_model(Gtk.StringList.new(preset_names))
    style_dd.set_selected(preset_ids.index(current_preset) if current_preset in preset_ids else 0)
    style_dd.set_size_request(200, -1)
    window.ui_controls["style_dropdown"] = style_dd
    
    def on_preset_changed(dd, _):
        idx = dd.get_selected()
        if idx == Gtk.INVALID_LIST_POSITION:
            return
        
        preset_id = preset_ids[idx]
        new_defaults = get_preset_defaults(preset_id)
        preset_ws = PANEL_STYLE_PRESETS[preset_id].get("workspaces", {})
        
        # Update description
        desc = PANEL_STYLE_PRESETS[preset_id].get("description", "")
        if "style_desc" in window.ui_controls:
            window.ui_controls["style_desc"].set_text(desc)
        
        # Update all UI controls from preset
        ui = window.ui_controls
        if "opacity_scale" in ui:
            ui["opacity_scale"].set_value(new_defaults.get("opacity", 0.5))
        if "bar_radius_spin" in ui:
            ui["bar_radius_spin"].set_value(new_defaults.get("bar_radius", 15))
        if "module_radius_spin" in ui:
            ui["module_radius_spin"].set_value(new_defaults.get("module_radius", 45))
        if "mod_opacity_scale" in ui:
            mod_opacity = 0.9 if preset_id == "classic" else 0.1
            ui["mod_opacity_scale"].set_value(mod_opacity)
        if "ws_btn_radius_spin" in ui:
            ui["ws_btn_radius_spin"].set_value(new_defaults.get("ws_radius", 16))
        if "ws_width_spin" in ui:
            ui["ws_width_spin"].set_value(new_defaults.get("ws_active_width", 50))
        if "hover_radius_spin" in ui:
            ui["hover_radius_spin"].set_value(new_defaults.get("hover_radius", 16) or 16)
        if "hover_bg_entry" in ui:
            ui["hover_bg_entry"].set_text(new_defaults.get("hover_bg", "rgba(69,71,90,0.55)"))
        if "hover_text_entry" in ui:
            ui["hover_text_entry"].set_text(new_defaults.get("hover_text", ""))
        
        # Update module colors
        preset_colors = new_defaults.get("colors", {})
        if hasattr(window, 'module_color_rows') and preset_colors:
            color_map = {"@blue": "#61afef", "@green": "#98c379", "@yellow": "#e5c07b",
                        "@orange": "#d19a66", "@purple": "#c678dd", "@red": "#e06c75",
                        "@cyan": "#56b6c2", "@fg": "#abb2bf"}
            for mod, row in window.module_color_rows.items():
                if mod in preset_colors:
                    color = preset_colors[mod]
                    if color.startswith("@"):
                        color = color_map.get(color, "#61afef")
                    row.set_color(color)
        
        # Update waybar color pickers
        if hasattr(window, 'waybar_color_rows'):
            ws_colors = {
                "ws_active": preset_ws.get("active_bg", "@blue").replace("@blue", "#61afef"),
                "ws_hover": preset_ws.get("hover_bg", "@purple").replace("@purple", "#c678dd"),
                "ws_urgent": preset_ws.get("urgent_bg", "@red").replace("@red", "#e06c75")
            }
            for key, row in window.waybar_color_rows.items():
                if key in ws_colors:
                    row.set_color(ws_colors[key])
        
        window.waybar_custom = {"preset": preset_id}
        do_apply()
    
    style_dd.connect("notify::selected", on_preset_changed)
    style_row.append(style_dd)
    content.append(style_row)
    
    # Description label
    desc_label = Gtk.Label(label=PANEL_STYLE_PRESETS[current_preset].get("description", ""))
    desc_label.add_css_class("dim-label")
    desc_label.set_xalign(0)
    desc_label.set_margin_start(8)
    desc_label.set_margin_bottom(8)
    window.ui_controls["style_desc"] = desc_label
    content.append(desc_label)
    
    # Button row
    btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    btn_row.set_margin_start(8)
    btn_row.set_margin_end(8)
    
    reset_btn = Gtk.Button(label="Reset Defaults")
    reset_btn.set_tooltip_text("Reset all Waybar settings to Classic preset defaults")
    reset_btn.connect("clicked", lambda b: reset_to_defaults(window, "classic"))
    btn_row.append(reset_btn)
    
    btn_row.append(Gtk.Box(hexpand=True))
    
    apply_btn = Gtk.Button(label="Apply Style")
    apply_btn.add_css_class("suggested-action")
    apply_btn.connect("clicked", lambda b: do_apply_now())
    btn_row.append(apply_btn)
    content.append(btn_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # FONT SETTINGS
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("FONT SETTINGS"))
    
    # Font Family
    font_family_row = create_setting_row("Font Family", "Typeface for entire panel")
    font_names = [f[0] for f in FONT_FAMILIES]
    font_dd = Gtk.DropDown()
    font_dd.set_model(Gtk.StringList.new(font_names))
    font_dd.set_selected(0)
    font_dd.set_size_request(200, -1)
    
    def on_font_family_change(dd, _):
        idx = dd.get_selected()
        if idx < len(FONT_FAMILIES):
            font_css = FONT_FAMILIES[idx][1]
            window.waybar_custom.setdefault("base", {})["font_family"] = font_css
            do_apply()
    
    font_dd.connect("notify::selected", on_font_family_change)
    window.ui_controls["font_family_dropdown"] = font_dd
    font_family_row.append(font_dd)
    content.append(font_family_row)
    
    # Font Size
    font_size_row = create_setting_row("Font Size", "8-32px")
    font_size_spin = Gtk.SpinButton.new_with_range(8, 32, 1)
    font_size_spin.set_value(defaults.get("font_size", 15))
    
    def on_font_size_change(spin):
        window.waybar_custom.setdefault("base", {})["font_size"] = int(spin.get_value())
        do_apply()
    
    font_size_spin.connect('value-changed', on_font_size_change)
    window.ui_controls["font_size_spin"] = font_size_spin
    font_size_row.append(font_size_spin)
    content.append(font_size_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WORKSPACES
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("WORKSPACES"))
    
    # Visibility toggle
    ws_visible_row = create_setting_row("Show Workspaces", "Hide or show workspace buttons")
    ws_visible_switch = Gtk.Switch()
    ws_visible_switch.set_active(ws_config["visible"])
    ws_visible_switch.set_valign(Gtk.Align.CENTER)
    ws_visible_switch.connect('state-set', lambda s, _: update_workspace_visibility(s.get_active()))
    window.ui_controls["ws_visible_switch"] = ws_visible_switch
    ws_visible_row.append(ws_visible_switch)
    content.append(ws_visible_row)
    
    # Number format
    ws_format_row = create_setting_row("Number Format", "Style of workspace labels")
    format_ids = list(WORKSPACE_NUMBER_FORMATS.keys())
    format_names = [WORKSPACE_NUMBER_FORMATS[f]["name"] for f in format_ids]
    
    ws_format_dd = Gtk.DropDown()
    ws_format_dd.set_model(Gtk.StringList.new(format_names))
    current_format_idx = format_ids.index(ws_config["format"]) if ws_config["format"] in format_ids else 0
    ws_format_dd.set_selected(current_format_idx)
    ws_format_dd.set_size_request(200, -1)
    
    def on_ws_format_change(dd, _):
        idx = dd.get_selected()
        if idx < len(format_ids):
            format_id = format_ids[idx]
            update_workspace_format(format_id)
            if hasattr(window, '_custom_ws_box'):
                window._custom_ws_box.set_visible(format_id == "custom")
    
    ws_format_dd.connect("notify::selected", on_ws_format_change)
    window.ui_controls["ws_format_dropdown"] = ws_format_dd
    ws_format_row.append(ws_format_dd)
    content.append(ws_format_row)
    
    # Custom format entry
    custom_ws_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    custom_ws_box.set_margin_start(8)
    custom_ws_box.set_margin_end(8)
    custom_ws_box.set_visible(ws_config["format"] == "custom")
    window._custom_ws_box = custom_ws_box
    
    custom_label = Gtk.Label(label="Custom Icons (comma-separated for WS 1-10)")
    custom_label.add_css_class("dim-label")
    custom_label.add_css_class("caption")
    custom_label.set_xalign(0)
    custom_ws_box.append(custom_label)
    
    custom_entry = Gtk.Entry()
    custom_entry.set_placeholder_text("󰋜, 󰈹, 󰨞, 󰙯, 󰝚, 󰒱, 󰊗, 󰎈, 󰘐, 󰟀")
    custom_entry.set_tooltip_text("Enter Nerd Font icons or text separated by commas")
    
    def on_custom_apply(entry):
        text = entry.get_text().strip()
        if text:
            parts = [p.strip() for p in text.split(',')]
            icons = {str(i+1): parts[i] if i < len(parts) else str(i+1) for i in range(10)}
            update_workspace_format("custom", icons)
    
    custom_entry.connect('activate', on_custom_apply)
    custom_ws_box.append(custom_entry)
    
    custom_apply_btn = Gtk.Button(label="Apply Custom")
    custom_apply_btn.connect("clicked", lambda b: on_custom_apply(custom_entry))
    custom_ws_box.append(custom_apply_btn)
    content.append(custom_ws_box)
    
    # Persistent count
    ws_count_row = create_setting_row("Persistent Count", "Always show N workspaces")
    ws_count_spin = Gtk.SpinButton.new_with_range(1, 10, 1)
    ws_count_spin.set_value(ws_config["persistent_count"])
    ws_count_spin.connect('value-changed', lambda s: update_workspace_persistent_count(int(s.get_value())))
    window.ui_controls["ws_count_spin"] = ws_count_spin
    ws_count_row.append(ws_count_spin)
    content.append(ws_count_row)
    
    # Container radius
    ws_container_radius_row = create_setting_row("Container Radius", "Workspace area roundness (0=square)")
    ws_container_radius_spin = Gtk.SpinButton.new_with_range(0, 50, 1)
    ws_container_radius_spin.set_value(26)
    
    def on_ws_container_radius_change(spin):
        window.waybar_custom.setdefault("workspaces", {})["container_radius"] = int(spin.get_value())
        do_apply()
    
    ws_container_radius_spin.connect('value-changed', on_ws_container_radius_change)
    window.ui_controls["ws_container_radius_spin"] = ws_container_radius_spin
    ws_container_radius_row.append(ws_container_radius_spin)
    content.append(ws_container_radius_row)
    
    # Button radius
    ws_btn_radius_row = create_setting_row("Button Radius", "0=square, 16=rounded, 50=circle")
    ws_btn_radius_spin = Gtk.SpinButton.new_with_range(0, 50, 1)
    ws_btn_radius_spin.set_value(defaults.get("ws_radius", 16))
    
    def on_ws_btn_radius_change(spin):
        window.waybar_custom.setdefault("workspaces", {})["button_radius"] = int(spin.get_value())
        do_apply()
    
    ws_btn_radius_spin.connect('value-changed', on_ws_btn_radius_change)
    window.ui_controls["ws_btn_radius_spin"] = ws_btn_radius_spin
    ws_btn_radius_row.append(ws_btn_radius_spin)
    content.append(ws_btn_radius_row)
    
    # Active width
    ws_width_row = create_setting_row("Active Width", "Width when workspace is active")
    ws_width_spin = Gtk.SpinButton.new_with_range(10, 80, 5)
    ws_width_spin.set_value(defaults.get("ws_active_width", 50))
    
    def on_ws_width_change(spin):
        window.waybar_custom.setdefault("workspaces", {})["active_width"] = int(spin.get_value())
        do_apply()
    
    ws_width_spin.connect('value-changed', on_ws_width_change)
    window.ui_controls["ws_width_spin"] = ws_width_spin
    ws_width_row.append(ws_width_spin)
    content.append(ws_width_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PANEL BEHAVIOR
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("PANEL BEHAVIOR"))
    
    # Position
    pos_row = create_setting_row("Position", "Where the panel appears")
    pos_dd = Gtk.DropDown()
    pos_dd.set_model(Gtk.StringList.new(["top", "bottom"]))
    pos_dd.set_selected(0 if get_current_waybar_position() == "top" else 1)
    pos_dd.connect('notify::selected', lambda d, _: (
        update_waybar_config_field("position", "top" if d.get_selected() == 0 else "bottom"),
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
    ))
    pos_row.append(pos_dd)
    content.append(pos_row)
    
    # Display
    monitors = get_monitor_list()
    disp_row = create_setting_row("Display", "Which monitor to show panel")
    disp_dd = Gtk.DropDown()
    disp_dd.set_model(Gtk.StringList.new(monitors))
    cur_out = get_current_waybar_output()
    sel_idx = next((i for i, m in enumerate(monitors) if m == cur_out), 0)
    disp_dd.set_selected(sel_idx)
    disp_dd.connect('notify::selected', lambda d, _: (
        update_waybar_config_field("output", monitors[d.get_selected()] if d.get_selected() < len(monitors) else ""),
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
    ))
    disp_row.append(disp_dd)
    content.append(disp_row)
    
    # Exclusive Zone
    extend_row = create_setting_row("Exclusive Zone", "Reserve space for panel")
    extend_switch = Gtk.Switch()
    extend_switch.set_active(True)
    extend_switch.set_valign(Gtk.Align.CENTER)
    extend_switch.connect('state-set', lambda s, _: (
        update_waybar_config_field("exclusive", s.get_active()),
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
    ))
    extend_row.append(extend_switch)
    content.append(extend_row)
    
    # Layer
    layer_row = create_setting_row("Layer", "Panel stacking layer")
    layer_dd = Gtk.DropDown()
    layer_dd.set_model(Gtk.StringList.new(["top", "bottom", "overlay"]))
    layer_dd.set_selected(0)
    layer_dd.connect('notify::selected', lambda d, _: (
        update_waybar_config_field("layer", ["top", "bottom", "overlay"][d.get_selected()]),
        subprocess.run(['pkill', '-SIGUSR2', 'waybar'], capture_output=True)
    ))
    layer_row.append(layer_dd)
    content.append(layer_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PANEL APPEARANCE
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("PANEL APPEARANCE"))
    
    # Opacity
    opacity_row = create_setting_row("Bar Opacity", "0 = transparent, 1 = solid")
    opacity_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05)
    opacity_scale.set_value(defaults.get("opacity", 0.5))
    opacity_scale.set_size_request(180, -1)
    opacity_scale.set_draw_value(True)
    opacity_scale.set_value_pos(Gtk.PositionType.RIGHT)
    
    def on_opacity_change(scale):
        window.waybar_custom.setdefault("base", {})["opacity"] = scale.get_value()
        do_apply()
    
    opacity_scale.connect('value-changed', on_opacity_change)
    window.ui_controls["opacity_scale"] = opacity_scale
    opacity_row.append(opacity_scale)
    content.append(opacity_row)
    
    # Bar Radius
    bar_radius_row = create_setting_row("Bar Radius", "Panel corner roundness")
    bar_radius_spin = Gtk.SpinButton.new_with_range(0, 50, 1)
    bar_radius_spin.set_value(defaults.get("bar_radius", 15))
    
    def on_bar_radius_change(spin):
        window.waybar_custom.setdefault("base", {})["bar_radius"] = int(spin.get_value())
        do_apply()
    
    bar_radius_spin.connect('value-changed', on_bar_radius_change)
    window.ui_controls["bar_radius_spin"] = bar_radius_spin
    bar_radius_row.append(bar_radius_spin)
    content.append(bar_radius_row)
    
    # Module Radius
    mod_radius_row = create_setting_row("Module Radius", "0=square, 45=pill shape")
    mod_radius_spin = Gtk.SpinButton.new_with_range(0, 50, 1)
    mod_radius_spin.set_value(defaults.get("module_radius", 45))
    
    def on_mod_radius_change(spin):
        window.waybar_custom.setdefault("base", {})["module_radius"] = int(spin.get_value())
        do_apply()
    
    mod_radius_spin.connect('value-changed', on_mod_radius_change)
    window.ui_controls["module_radius_spin"] = mod_radius_spin
    mod_radius_row.append(mod_radius_spin)
    content.append(mod_radius_row)
    
    # Module Opacity
    mod_opacity_row = create_setting_row("Module Opacity", "Transparency of modules")
    mod_opacity_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05)
    mod_opacity_scale.set_value(0.9)
    mod_opacity_scale.set_size_request(180, -1)
    mod_opacity_scale.set_draw_value(True)
    mod_opacity_scale.set_value_pos(Gtk.PositionType.RIGHT)
    
    def on_mod_opacity_change(scale):
        window.waybar_custom.setdefault("base", {})["module_opacity"] = scale.get_value()
        do_apply()
    
    mod_opacity_scale.connect('value-changed', on_mod_opacity_change)
    window.ui_controls["mod_opacity_scale"] = mod_opacity_scale
    mod_opacity_row.append(mod_opacity_scale)
    content.append(mod_opacity_row)
    
    # Height
    height_row = create_setting_row("Panel Height", "Height in pixels")
    height_spin = Gtk.SpinButton.new_with_range(20, 60, 2)
    height_spin.set_value(36)
    
    def on_height_change(spin):
        val = int(spin.get_value())
        window.waybar_custom.setdefault("base", {})["height"] = val
        update_waybar_config_field("height", val)
        do_apply()
    
    height_spin.connect('value-changed', on_height_change)
    window.ui_controls["height_spin"] = height_spin
    height_row.append(height_spin)
    content.append(height_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # HOVER EFFECTS
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("HOVER EFFECTS"))
    
    hover_radius_row = create_setting_row("Hover Radius")
    hover_radius_spin = Gtk.SpinButton.new_with_range(0, 50, 1)
    hover_radius_spin.set_value(defaults.get("hover_radius", 16) or 16)
    
    def on_hover_radius_change(spin):
        window.waybar_custom.setdefault("hover", {})["radius"] = int(spin.get_value())
        do_apply()
    
    hover_radius_spin.connect('value-changed', on_hover_radius_change)
    window.ui_controls["hover_radius_spin"] = hover_radius_spin
    hover_radius_row.append(hover_radius_spin)
    content.append(hover_radius_row)
    
    hover_bg_row = create_setting_row("Hover Background")
    hover_bg_entry = Gtk.Entry()
    hover_bg_entry.set_text(defaults.get("hover_bg", "rgba(69,71,90,0.55)"))
    hover_bg_entry.set_width_chars(24)
    
    def on_hover_bg_change(entry):
        window.waybar_custom.setdefault("hover", {})["background"] = entry.get_text()
        do_apply()
    
    hover_bg_entry.connect('changed', on_hover_bg_change)
    window.ui_controls["hover_bg_entry"] = hover_bg_entry
    hover_bg_row.append(hover_bg_entry)
    content.append(hover_bg_row)
    
    hover_text_row = create_setting_row("Hover Text Color")
    hover_text_entry = Gtk.Entry()
    hover_text_entry.set_text(defaults.get("hover_text", ""))
    hover_text_entry.set_width_chars(12)
    
    def on_hover_text_change(entry):
        window.waybar_custom.setdefault("hover", {})["text_color"] = entry.get_text()
        do_apply()
    
    hover_text_entry.connect('changed', on_hover_text_change)
    window.ui_controls["hover_text_entry"] = hover_text_entry
    hover_text_row.append(hover_text_entry)
    content.append(hover_text_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # WAYBAR COLORS
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("WAYBAR COLORS"))
    
    window.waybar_color_rows = {}
    
    def on_waybar_color_change(key, value):
        base = window.waybar_custom.setdefault("base", {})
        ws = window.waybar_custom.setdefault("workspaces", {})
        
        if key == "bar_bg_color":
            base["bar_bg_color"] = value
        elif key == "module_bg_color":
            base["module_bg_color"] = value
        elif key == "border_color":
            base["border_color"] = value
            base["border"] = f"1px solid {value}"
        elif key == "ws_active":
            ws["active_bg"] = value
        elif key == "ws_hover":
            ws["hover_bg"] = value
        elif key == "ws_urgent":
            ws["urgent_bg"] = value
        
        do_apply()
    
    # Bar Background Color
    bar_bg_row = ColorPickerRow("Bar Background", "bar_bg_color", "#282c34", on_waybar_color_change)
    bar_bg_row.set_tooltip_text("Background color of the entire panel")
    window.waybar_color_rows["bar_bg_color"] = bar_bg_row
    content.append(bar_bg_row)
    
    # Module Background Color
    mod_bg_row = ColorPickerRow("Module Background", "module_bg_color", "#282c34", on_waybar_color_change)
    mod_bg_row.set_tooltip_text("Background color of individual modules")
    window.waybar_color_rows["module_bg_color"] = mod_bg_row
    content.append(mod_bg_row)
    
    # Border Color
    border_row = ColorPickerRow("Border Color", "border_color", "#3e4451", on_waybar_color_change)
    border_row.set_tooltip_text("Border color around modules")
    window.waybar_color_rows["border_color"] = border_row
    content.append(border_row)
    
    # Workspace Colors
    content.append(create_section_header("WORKSPACE COLORS"))
    
    preset_ws = PANEL_STYLE_PRESETS.get(current_preset, {}).get("workspaces", {})
    
    ws_active_row = ColorPickerRow("Active Button", "ws_active",
        preset_ws.get("active_bg", "#61afef").replace("@blue", "#61afef"), on_waybar_color_change)
    window.waybar_color_rows["ws_active"] = ws_active_row
    content.append(ws_active_row)
    
    ws_hover_row = ColorPickerRow("Hover Button", "ws_hover",
        preset_ws.get("hover_bg", "#c678dd").replace("@purple", "#c678dd"), on_waybar_color_change)
    window.waybar_color_rows["ws_hover"] = ws_hover_row
    content.append(ws_hover_row)
    
    ws_urgent_row = ColorPickerRow("Urgent Button", "ws_urgent",
        preset_ws.get("urgent_bg", "#e06c75").replace("@red", "#e06c75"), on_waybar_color_change)
    window.waybar_color_rows["ws_urgent"] = ws_urgent_row
    content.append(ws_urgent_row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MODULE ICON COLORS
    # ═══════════════════════════════════════════════════════════════════════════
    content.append(create_section_header("MODULE ICON COLORS"))
    
    window.module_color_rows = {}
    preset_colors = defaults.get("colors", {})
    
    def on_module_color_change(key, value):
        window.waybar_custom.setdefault("colors", {})[key] = value
        do_apply()
    
    module_defs = [
        ("cpu", "CPU", preset_colors.get("cpu", "@blue")),
        ("memory", "Memory", preset_colors.get("memory", "@green")),
        ("clock", "Clock", preset_colors.get("clock", "@blue")),
        ("pulseaudio", "Volume", preset_colors.get("pulseaudio", "@yellow")),
        ("network", "Network", preset_colors.get("network", "@purple")),
        ("bluetooth", "Bluetooth", preset_colors.get("bluetooth", "@blue")),
        ("battery", "Battery", preset_colors.get("battery", "@green")),
        ("temperature", "Temperature", preset_colors.get("temperature", "@orange")),
        ("pacman", "Pacman Updates", preset_colors.get("pacman", "@cyan")),
    ]
    
    for key, label, default_val in module_defs:
        color = default_val
        if color.startswith("@"):
            color_map = {"@blue": "#61afef", "@green": "#98c379", "@yellow": "#e5c07b",
                        "@orange": "#d19a66", "@purple": "#c678dd", "@red": "#e06c75",
                        "@cyan": "#56b6c2", "@fg": "#abb2bf"}
            color = color_map.get(color, "#61afef")
        
        row = ColorPickerRow(label, key, color, on_module_color_change)
        window.module_color_rows[key] = row
        content.append(row)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # INFO
    # ═══════════════════════════════════════════════════════════════════════════
    info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    info_box.set_margin_top(16)
    
    info_label = Gtk.Label()
    info_label.set_markup("💡 <small>Start menu icons location:</small>")
    info_label.add_css_class("dim-label")
    info_label.set_xalign(0)
    info_box.append(info_label)
    
    path_label = Gtk.Label()
    path_label.set_markup("<small><tt>~/.config/hypr-control-center/assets/start-icons/</tt></small>")
    path_label.add_css_class("dim-label")
    path_label.set_xalign(0)
    path_label.set_selectable(True)
    info_box.append(path_label)
    
    content.append(info_box)
    
    # Add content directly to main_box (no scroll - expander parent handles it)
    main_box.append(content)
    
    return main_box