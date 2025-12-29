"""
Theme Manager - Global theme system for Hyprland Control Center
Manages themes for: Control Center UI, Waybar, and Rofi
"""

import os
import json
from pathlib import Path
from typing import Dict, List, Optional

class ThemeManager:
    """Manages application themes and applies them globally"""
    
    THEMES = {
        "one-dark": {
            "name": "One Dark",
            "description": "Atom's iconic dark theme",
            "colors": {
                "bg0": "#282c34",
                "bg1": "#21252b",
                "bg2": "#2c313a",
                "bg3": "#3e4451",
                "bg4": "#4b5263",
                "red": "#e06c75",
                "orange": "#d19a66",
                "yellow": "#e5c07b",
                "green": "#98c379",
                "aqua": "#56b6c2",
                "blue": "#61afef",
                "purple": "#c678dd",
                "fg": "#abb2bf",
                "grey0": "#5c6370",
                "grey1": "#828997",
                "grey2": "#abb2bf"
            }
        },
        "gruvbox-dark": {
            "name": "Gruvbox Dark",
            "description": "Retro groove color scheme",
            "colors": {
                "bg0": "#282828",
                "bg1": "#1d2021",
                "bg2": "#32302f",
                "bg3": "#3c3836",
                "bg4": "#504945",
                "red": "#cc241d",
                "orange": "#d65d0e",
                "yellow": "#d79921",
                "green": "#98971a",
                "aqua": "#689d6a",
                "blue": "#458588",
                "purple": "#b16286",
                "fg": "#ebdbb2",
                "grey0": "#665c54",
                "grey1": "#928374",
                "grey2": "#a89984"
            }
        },
        "nord": {
            "name": "Nord",
            "description": "Arctic, north-bluish color palette",
            "colors": {
                "bg0": "#2e3440",
                "bg1": "#3b4252",
                "bg2": "#434c5e",
                "bg3": "#4c566a",
                "bg4": "#5e81ac",
                "red": "#bf616a",
                "orange": "#d08770",
                "yellow": "#ebcb8b",
                "green": "#a3be8c",
                "aqua": "#88c0d0",
                "blue": "#81a1c1",
                "purple": "#b48ead",
                "fg": "#eceff4",
                "grey0": "#616e88",
                "grey1": "#7b88a1",
                "grey2": "#d8dee9"
            }
        },
        "tokyo-night-storm": {
            "name": "Tokyo Night Storm",
            "description": "Clean, stormy night theme",
            "colors": {
                "bg0": "#1a1b26",
                "bg1": "#16161e",
                "bg2": "#24283b",
                "bg3": "#414868",
                "bg4": "#565f89",
                "red": "#f7768e",
                "orange": "#ff9e64",
                "yellow": "#e0af68",
                "green": "#9ece6a",
                "aqua": "#7dcfff",
                "blue": "#7aa2f7",
                "purple": "#bb9af7",
                "fg": "#c0caf5",
                "grey0": "#565f89",
                "grey1": "#787c99",
                "grey2": "#a9b1d6"
            }
        },
        "catppuccin-mocha": {
            "name": "Catppuccin Mocha",
            "description": "Soothing pastel theme",
            "colors": {
                "bg0": "#1e1e2e",
                "bg1": "#181825",
                "bg2": "#313244",
                "bg3": "#45475a",
                "bg4": "#585b70",
                "red": "#f38ba8",
                "orange": "#fab387",
                "yellow": "#f9e2af",
                "green": "#a6e3a1",
                "aqua": "#94e2d5",
                "blue": "#89b4fa",
                "purple": "#cba6f7",
                "fg": "#cdd6f4",
                "grey0": "#6c7086",
                "grey1": "#9399b2",
                "grey2": "#bac2de"
            }
        },
        "everforest-dark": {
            "name": "Everforest Dark",
            "description": "Comfortable greenish theme",
            "colors": {
                "bg0": "#2b3339",
                "bg1": "#232a2e",
                "bg2": "#323c41",
                "bg3": "#3a464c",
                "bg4": "#4f5b58",
                "red": "#e67e80",
                "orange": "#e69875",
                "yellow": "#dbbc7f",
                "green": "#a7c080",
                "aqua": "#83c092",
                "blue": "#7fbbb3",
                "purple": "#d699b6",
                "fg": "#d3c6aa",
                "grey0": "#7a8478",
                "grey1": "#9da9a0",
                "grey2": "#c1c7be"
            }
        },
        "mac-os-dark-blue": {
            "name": "macOS Dark Blue",
            "description": "macOS dark mode inspired",
            "colors": {
                "bg0": "#021C37",
                "bg1": "#021C37",
                "bg2": "#1C5587",
                "bg3": "#196595",
                "bg4": "#26628E",
                "red": "#4E646F",
                "orange": "#2C6991",
                "yellow": "#196595",
                "green": "#1C5587",
                "aqua": "#467497",
                "blue": "#26628E",
                "purple": "#2C6991",
                "fg": "#9fbfba",
                "grey0": "#6f8582",
                "grey1": "#4E646F",
                "grey2": "#9fbfba"
            }
        }
    }
    
    def __init__(self):
        self.config_dir = Path.home() / ".config" / "hypr-control-center"
        self.theme_file = self.config_dir / "theme.json"
        self.waybar_colors_dir = Path.home() / ".config" / "waybar" / "colors"
        
    def get_available_themes(self) -> List[Dict[str, str]]:
        """Get list of available themes"""
        return [
            {
                "id": theme_id,
                "name": theme["name"],
                "description": theme["description"]
            }
            for theme_id, theme in self.THEMES.items()
        ]
    
    def get_current_theme(self) -> str:
        """Get currently active theme ID"""
        if self.theme_file.exists():
            try:
                with open(self.theme_file, 'r') as f:
                    data = json.load(f)
                    return data.get("current_theme", "one-dark")
            except:
                pass
        return "one-dark"
    
    def get_theme_colors(self, theme_id: str) -> Optional[Dict[str, str]]:
        """Get color palette for a theme"""
        theme = self.THEMES.get(theme_id)
        return theme["colors"] if theme else None
    
    def apply_theme(self, theme_id: str) -> bool:
        """Apply theme globally"""
        if theme_id not in self.THEMES:
            return False
        
        try:
            # Save current theme
            self.config_dir.mkdir(parents=True, exist_ok=True)
            with open(self.theme_file, 'w') as f:
                json.dump({"current_theme": theme_id}, f, indent=2)
            
            # Apply to Control Center (CSS)
            self._apply_to_control_center(theme_id)
            
            # Apply to Waybar
            self._apply_to_waybar(theme_id)
            
            # TODO: Apply to Rofi (future)
            # self._apply_to_rofi(theme_id)
            
            return True
        except Exception as e:
            print(f"Error applying theme: {e}")
            return False
    
    def _apply_to_control_center(self, theme_id: str):
        """Apply theme to Control Center CSS"""
        colors = self.THEMES[theme_id]["colors"]
        
        # Generate CSS variables
        css_vars = "/* Theme: {} */\n:root {{\n".format(self.THEMES[theme_id]["name"])
        for key, value in colors.items():
            css_vars += f"    --{key}: {value};\n"
        css_vars += "}\n"
        
        # Read existing CSS
        css_file = self.config_dir / "assets" / "style.css"
        if css_file.exists():
            content = css_file.read_text()
            
            # Replace theme section
            if ":root {" in content:
                # Find and replace :root section
                import re
                pattern = r'/\* Theme:.*?\*/\s*:root\s*\{[^}]+\}'
                if re.search(pattern, content, re.DOTALL):
                    content = re.sub(pattern, css_vars.strip(), content, flags=re.DOTALL)
                else:
                    # Insert at top
                    content = css_vars + "\n" + content
            else:
                content = css_vars + "\n" + content
            
            css_file.write_text(content)
    
    def _apply_to_waybar(self, theme_id: str):
        """Apply theme to Waybar"""
        colors = self.THEMES[theme_id]["colors"]
        theme_name = self.THEMES[theme_id]["name"]
        
        # Create waybar colors directory
        self.waybar_colors_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate waybar color CSS
        waybar_css = f"/* {theme_name} Color Palette for Waybar */\n"
        for key, value in colors.items():
            waybar_css += f"@define-color {key} {value};\n"
        
        # Write to waybar colors file
        # Use theme_id as filename
        color_file = self.waybar_colors_dir / f"{theme_id}.css"
        color_file.write_text(waybar_css)
        
        # Update waybar style.css to import this theme
        waybar_style = Path.home() / ".config" / "waybar" / "style.css"
        if waybar_style.exists():
            content = waybar_style.read_text()
            
            # Replace @import line
            import re
            pattern = r"@import\s+['\"]colors/[^'\"]+\.css['\"];"
            new_import = f"@import 'colors/{theme_id}.css';"
            
            if re.search(pattern, content):
                content = re.sub(pattern, new_import, content)
            else:
                # Add at top
                content = new_import + "\n\n" + content
            
            waybar_style.write_text(content)
            
            # Reload waybar
            os.system("pkill waybar && waybar &")
    
    def _apply_to_rofi(self, theme_id: str):
        """Apply theme to Rofi (TODO)"""
        # Will implement rofi theme application later
        pass