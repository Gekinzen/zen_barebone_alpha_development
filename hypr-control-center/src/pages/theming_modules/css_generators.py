"""CSS GENERATORS - Control Center, Start Menu, Panel Widget CSS"""
from datetime import datetime
from .helpers import is_light_theme

def generate_control_center_css(colors: dict) -> str:
    light = is_light_theme(colors)
    sel_text = "#000000" if light else "#ffffff"
    icon_color = colors['fg'] if light else "#ffffff"
    return f'''/* Control Center CSS - {datetime.now().strftime("%Y-%m-%d %H:%M")} | Light: {light} */
:root {{ --bg0: {colors.get('bg0','#282c34')}; --bg1: {colors.get('bg1','#21252b')}; --bg2: {colors.get('bg2','#2c313a')}; --bg3: {colors.get('bg3','#3e4451')}; --fg: {colors.get('fg','#abb2bf')}; --blue: {colors.get('blue','#61afef')}; --red: {colors.get('red','#e06c75')}; --green: {colors.get('green','#98c379')}; --purple: {colors.get('purple','#c678dd')}; }}
@import url('wallpaper_module.css'); @import url('panel.css'); @import url('panel-widget.css'); @import url('start-menu.css'); @import url('visualizer.css');
window {{ background-color: {colors['bg1']}; color: {colors['fg']}; }}
.sidebar {{ background-color: {colors['bg0']}; border-right: 1px solid {colors['bg3']}; min-width: 240px; }}
.content-area {{ background-color: {colors['bg1']}; }}
label {{ color: {colors['fg']}; }}
.sidebar-title {{ font-size: 18px; font-weight: 700; color: {colors['fg']}; }}
.sidebar-section {{ font-size: 10px; font-weight: 700; color: {colors['grey0']}; letter-spacing: 1.2px; text-transform: uppercase; padding: 16px 16px 8px 16px; }}
.sidebar-item {{ padding: 10px 16px; margin: 2px 8px; border-radius: 8px; color: {colors['fg']}; font-size: 13px; transition: all 0.2s ease; }}
.sidebar-item:hover {{ background-color: {colors['bg2']}; }}
.sidebar-item:selected, .sidebar-item:checked {{ background-color: {colors['blue']}; color: {sel_text}; font-weight: 600; }}
.sidebar-icon {{ font-family: "JetBrainsMono Nerd Font"; font-size: 16px; color: {icon_color}; min-width: 22px; text-align: center; }}
.sidebar image, .sidebar listboxrow image {{ color: {icon_color}; -gtk-icon-style: symbolic; }}
.sidebar listboxrow:selected .sidebar-icon, .sidebar listboxrow:selected image, .sidebar listboxrow:selected label {{ color: #000000; }}
.page-title {{ font-size: 26px; font-weight: 700; color: {colors['fg']}; margin-bottom: 4px; }}
.page-subtitle {{ font-size: 13px; color: {colors['grey1']}; opacity: 0.8; }}
.title-1 {{ font-size: 24px; font-weight: 700; color: {colors['fg']}; }}
.heading {{ font-size: 14px; font-weight: 600; color: {colors['purple']}; letter-spacing: 0.5px; }}
.caption {{ font-size: 11px; color: {colors['grey1']}; }}
.dim-label {{ color: {colors['grey1']}; opacity: 0.8; }}
.card {{ background-color: {colors['bg0']}; border-radius: 12px; padding: 16px; border: 1px solid {colors['bg3']}; }}
.settings-group {{ background-color: {colors['bg0']}; border-radius: 12px; padding: 20px 24px; margin-bottom: 20px; border: 1px solid {colors['bg3']}; }}
.group-title {{ font-size: 12px; font-weight: 700; color: {colors['blue']}; letter-spacing: 0.8px; text-transform: uppercase; margin-bottom: 16px; }}
.setting-row {{ padding: 12px 0; border-bottom: 1px solid {colors['bg2']}; }}
.setting-row:last-child {{ border-bottom: none; }}
.setting-label {{ font-size: 14px; font-weight: 600; color: {colors['fg']}; }}
.setting-description {{ font-size: 12px; color: {colors['grey1']}; opacity: 0.75; margin-top: 2px; }}
.value-mono {{ font-family: "JetBrains Mono"; font-size: 12px; color: {colors['aqua']}; background-color: {colors['bg2']}; padding: 5px 12px; border-radius: 6px; border: 1px solid {colors['bg3']}; }}
button {{ background-color: {colors['bg2']}; color: {colors['fg']}; border: 1px solid {colors['bg3']}; border-radius: 8px; padding: 8px 16px; transition: all 0.2s ease; }}
button:hover {{ background-color: {colors['bg3']}; border-color: {colors['bg4']}; }}
button.suggested-action {{ background-color: {colors['blue']}; color: #ffffff; border-color: {colors['blue']}; }}
button.suggested-action:hover {{ background-color: {colors['aqua']}; border-color: {colors['aqua']}; }}
button.destructive-action {{ background-color: {colors['bg2']}; color: {colors['red']}; border-color: {colors['bg3']}; }}
button.destructive-action:hover {{ background-color: alpha({colors['red']}, 0.15); border-color: {colors['red']}; }}
.linked button {{ border-radius: 0; }}
.linked button:first-child {{ border-top-left-radius: 8px; border-bottom-left-radius: 8px; }}
.linked button:last-child {{ border-top-right-radius: 8px; border-bottom-right-radius: 8px; }}
switch {{ background-color: {colors['bg3']}; border-radius: 14px; min-width: 50px; min-height: 26px; border: none; }}
switch:checked {{ background-color: {colors['blue']}; }}
switch slider {{ background-color: #ffffff; border-radius: 13px; min-width: 22px; min-height: 22px; margin: 2px; box-shadow: 0 1px 3px rgba(0,0,0,0.3); }}
entry {{ background-color: {colors['bg2']}; color: {colors['fg']}; border: 1px solid {colors['bg3']}; border-radius: 8px; padding: 8px 12px; caret-color: {colors['blue']}; }}
entry:focus {{ border-color: {colors['blue']}; background-color: {colors['bg1']}; }}
spinbutton {{ background-color: {colors['bg2']}; color: {colors['fg']}; border: 1px solid {colors['bg3']}; border-radius: 8px; }}
spinbutton button {{ background: transparent; border: none; color: {colors['fg']}; }}
spinbutton button:hover {{ background-color: {colors['bg3']}; }}
dropdown {{ background-color: {colors['bg2']}; color: {colors['fg']}; border: 1px solid {colors['bg3']}; border-radius: 8px; padding: 6px 12px; }}
dropdown popover {{ background-color: {colors['bg1']}; border: 1px solid {colors['bg3']}; border-radius: 8px; }}
dropdown popover modelbutton {{ padding: 8px 12px; color: {colors['fg']}; }}
dropdown popover modelbutton:hover {{ background-color: {colors['bg2']}; }}
dropdown popover modelbutton:selected {{ background-color: {colors['blue']}; color: {sel_text}; }}
scale trough {{ background-color: {colors['bg3']}; border-radius: 4px; min-height: 6px; }}
scale highlight {{ background-color: {colors['blue']}; border-radius: 4px; }}
scale slider {{ background-color: #ffffff; border-radius: 50%; min-width: 18px; min-height: 18px; margin: -6px; box-shadow: 0 2px 4px rgba(0,0,0,0.3); }}
scrollbar slider {{ background-color: {colors['bg3']}; border-radius: 8px; min-width: 8px; }}
scrollbar slider:hover {{ background-color: {colors['bg4']}; }}
listbox row {{ padding: 8px; border-radius: 8px; color: {colors['fg']}; }}
listbox row:hover {{ background-color: {colors['bg2']}; }}
listbox row:selected {{ background-color: {colors['blue']}; color: {sel_text}; }}
flowboxchild {{ padding: 4px; border-radius: 8px; }}
flowboxchild:hover {{ background-color: {colors['bg2']}; }}
flowboxchild:selected {{ background-color: {colors['blue']}; }}
expander title {{ padding: 8px; border-radius: 8px; }}
expander title:hover {{ background-color: {colors['bg2']}; }}
frame {{ border: 1px solid {colors['bg3']}; border-radius: 8px; }}
popover {{ background-color: {colors['bg0']}; border: 1px solid {colors['bg3']}; border-radius: 12px; }}
popover modelbutton {{ padding: 8px 12px; border-radius: 6px; color: {colors['fg']}; }}
popover modelbutton:hover {{ background-color: {colors['bg2']}; }}
.module-chip {{ background-color: {colors['bg2']}; border: 1px solid {colors['bg3']}; border-radius: 8px; padding: 6px 12px; }}
.module-chip:hover {{ background-color: {colors['bg3']}; }}
.placeholder-icon {{ color: {colors['grey0']}; opacity: 0.4; font-size: 64px; }}
.placeholder-title {{ font-size: 24px; font-weight: 700; color: {colors['fg']}; }}
.coming-soon-badge {{ background-color: alpha({colors['purple']}, 0.2); color: {colors['purple']}; font-size: 11px; font-weight: 700; padding: 6px 16px; border-radius: 16px; border: 1px solid alpha({colors['purple']}, 0.3); }}
.theme-card {{ background-color: {colors['bg0']}; border: 2px solid {colors['bg3']}; border-radius: 12px; padding: 16px; }}
.theme-card:hover {{ border-color: {colors['bg4']}; }}
.theme-card-selected {{ border-color: {colors['blue']}; background-color: alpha({colors['blue']}, 0.1); }}
'''

def generate_start_menu_css(colors: dict) -> str:
    return f'''/* Start Menu CSS - {datetime.now().strftime("%Y-%m-%d %H:%M")} */
window {{ background: transparent; }}
.start-menu {{ background: alpha({colors['bg0']}, 0.95); border-radius: 16px; border: 1px solid alpha({colors['fg']}, 0.1); }}
.start-left {{ padding: 20px; border-right: 1px solid alpha({colors['fg']}, 0.08); }}
.start-right {{ padding: 20px; }}
.section-title {{ font-size: 13px; font-weight: 600; color: alpha({colors['fg']}, 0.7); margin-bottom: 12px; }}
.app-tile {{ background: transparent; border: none; border-radius: 8px; padding: 12px 8px; min-width: 72px; transition: all 150ms ease; }}
.app-tile:hover {{ background: alpha({colors['fg']}, 0.08); }}
.app-tile-label {{ font-size: 11px; color: {colors['fg']}; }}
.app-row {{ border-radius: 8px; margin: 2px 0; padding: 8px 12px; transition: all 150ms ease; }}
.app-row:hover {{ background: alpha({colors['fg']}, 0.06); }}
.search-entry {{ background: alpha({colors['fg']}, 0.08); border: 1px solid alpha({colors['fg']}, 0.12); border-radius: 8px; padding: 10px 14px; color: {colors['fg']}; margin-bottom: 12px; }}
.search-entry:focus {{ background: alpha({colors['fg']}, 0.1); border-color: {colors['blue']}; }}
.bottom-bar {{ background: alpha({colors['bg1']}, 0.8); border-top: 1px solid alpha({colors['fg']}, 0.08); padding: 14px 20px; border-radius: 0 0 16px 16px; }}
.user-name {{ font-size: 14px; font-weight: 600; color: {colors['fg']}; }}
.icon-button {{ background: transparent; border: none; border-radius: 8px; padding: 8px; min-width: 40px; min-height: 40px; color: {colors['fg']}; }}
.icon-button:hover {{ background: alpha({colors['fg']}, 0.08); }}
.letter-header {{ font-size: 14px; font-weight: 600; color: {colors['blue']}; padding: 8px 12px 4px; }}
scrollbar slider {{ background: alpha({colors['fg']}, 0.2); border-radius: 4px; min-width: 8px; }}
scrollbar slider:hover {{ background: alpha({colors['fg']}, 0.3); }}
popover {{ background: alpha({colors['bg0']}, 0.95); border: 1px solid alpha({colors['blue']}, 0.3); border-radius: 12px; padding: 6px; }}
popover button {{ background: transparent; border: none; border-radius: 8px; padding: 8px 12px; color: {colors['fg']}; }}
popover button:hover {{ background: alpha({colors['blue']}, 0.15); }}
'''

def generate_panel_widget_css(colors: dict) -> str:
    return f'''/* Panel Widget CSS - {datetime.now().strftime("%Y-%m-%d %H:%M")} */
window {{ background: transparent; }}
.panel-container {{ background: alpha({colors['bg0']}, 0.85); border-radius: 12px; border: 1px solid alpha({colors['fg']}, 0.1); padding: 4px 8px; }}
.taskbar-item {{ background: transparent; border: none; border-radius: 8px; padding: 6px 8px; margin: 2px; min-width: 36px; min-height: 36px; transition: all 150ms ease; }}
.taskbar-item:hover {{ background: alpha({colors['fg']}, 0.08); }}
.taskbar-item.focused {{ background: alpha({colors['blue']}, 0.15); border-bottom: 2px solid {colors['blue']}; }}
.taskbar-item.running {{ border-bottom: 2px solid alpha({colors['blue']}, 0.5); }}
.taskbar-icon {{ color: {colors['fg']}; font-size: 20px; }}
.window-list-popover {{ background: alpha({colors['bg0']}, 0.95); border: 1px solid alpha({colors['blue']}, 0.3); border-radius: 12px; }}
.window-list-item {{ background: transparent; border: none; border-radius: 8px; padding: 8px 12px; margin: 2px; color: {colors['fg']}; }}
.window-list-item:hover {{ background: alpha({colors['blue']}, 0.15); }}
.focus-indicator {{ color: {colors['blue']}; margin-right: 8px; }}
.window-close-btn {{ opacity: 0.5; }}
.window-close-btn:hover {{ opacity: 1; color: {colors['red']}; }}
.dim-label {{ opacity: 0.7; font-size: 0.85em; color: {colors['grey1']}; }}
tooltip {{ background: alpha({colors['bg0']}, 0.95); border: 1px solid alpha({colors['blue']}, 0.2); border-radius: 8px; }}
tooltip label {{ color: {colors['fg']}; padding: 6px 10px; }}
'''
