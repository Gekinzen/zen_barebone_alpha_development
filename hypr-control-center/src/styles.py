"""
One Dark themed CSS styles for Hyprland Control Center
"""

from .constants import ONE_DARK

def get_css() -> str:
    """Returns the complete CSS stylesheet with ONE_DARK theme"""
    return get_css_template().format(**ONE_DARK)

def get_css_template() -> str:
    """Returns CSS template string with color placeholders for theming"""
    return '''
/* ═══════════════════════════════════════════════════════════════ */
/* WINDOW & CONTAINERS                                              */
/* ═══════════════════════════════════════════════════════════════ */

window {{
    background-color: {bg1};
}}

.sidebar {{
    background-color: {bg0};
    border-right: 1px solid {bg3};
}}

.content-area {{
    background-color: {bg1};
    padding: 24px 32px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SIDEBAR                                                          */
/* ═══════════════════════════════════════════════════════════════ */

.sidebar-title {{
    font-size: 18px;
    font-weight: 700;
    color: {fg};
    padding: 16px;
}}

.sidebar-section {{
    font-size: 11px;
    font-weight: 600;
    color: {grey0};
    letter-spacing: 1.2px;
    text-transform: uppercase;
    padding: 16px 16px 8px 16px;
}}

.sidebar-item {{
    padding: 10px 16px;
    margin: 2px 8px;
    border-radius: 8px;
    color: {fg};
    font-size: 13px;
}}

.sidebar-item:hover {{
    background-color: {bg2};
}}

.sidebar-item:selected,
.sidebar-item:checked {{
    background-color: {blue};
    color: {bg1};
}}

/* Make all sidebar icons white - minimalist! */
.sidebar-icon {{
    color: {fg} !important;
    -gtk-icon-palette: {fg} !important;
    -gtk-icon-style: symbolic;
}}

.sidebar-item image {{
    color: {fg} !important;
    -gtk-icon-palette: {fg};
}}

.sidebar-item:selected image,
.sidebar-item:checked image {{
    color: {bg0} !important;
    -gtk-icon-palette: {bg0};
}}

.sidebar-item:selected .sidebar-icon,
.sidebar-item:checked .sidebar-icon {{
    color: {bg0} !important;
    -gtk-icon-palette: {bg0} !important;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* GLOBAL ICON STYLING - ALL WHITE FOR MINIMALIST DESIGN          */
/* ═══════════════════════════════════════════════════════════════ */

/* Make ALL icons white by default - FORCE IT! */
image {{
    color: {fg} !important;
    -gtk-icon-palette: {fg};
    -gtk-icon-style: symbolic;
}}

/* Icon buttons */
button image {{
    color: {fg} !important;
    -gtk-icon-palette: {fg};
}}

/* List box icons */
list image,
listbox image,
listboxrow image,
row image {{
    color: {fg} !important;
    -gtk-icon-palette: {fg};
}}

/* Box icons */
box image {{
    color: {fg} !important;
    -gtk-icon-palette: {fg};
}}

/* Suggested action buttons keep blue background, but white icon */
button.suggested-action image {{
    color: {bg0} !important;
    -gtk-icon-palette: {bg0};
}}

/* Destructive action buttons */
button.destructive-action image {{
    color: {bg0} !important;
    -gtk-icon-palette: {bg0};
}}

/* ═══════════════════════════════════════════════════════════════ */
/* PAGE HEADERS                                                     */
/* ═══════════════════════════════════════════════════════════════ */

.page-title {{
    font-size: 28px;
    font-weight: 700;
    color: {fg};
}}

.page-subtitle {{
    font-size: 14px;
    color: {grey1};
    margin-top: 4px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SETTINGS GROUPS                                                  */
/* ═══════════════════════════════════════════════════════════════ */

.settings-group {{
    background-color: {bg0};
    border-radius: 12px;
    padding: 16px 20px;
    margin-bottom: 16px;
}}

.group-title {{
    font-size: 11px;
    font-weight: 600;
    color: {blue};
    letter-spacing: 1px;
}}

.section-header {{
    font-size: 12px;
    font-weight: 600;
    color: {purple};
    letter-spacing: 0.5px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SETTING ROWS                                                     */
/* ═══════════════════════════════════════════════════════════════ */

.setting-row {{
    padding: 6px 0;
    border-bottom: 1px solid {bg2};
}}

.setting-row:last-child {{
    border-bottom: none;
}}

.setting-label {{
    font-size: 14px;
    font-weight: 500;
    color: {fg};
}}

.setting-description {{
    font-size: 12px;
    color: {grey0};
}}

.value-mono {{
    font-family: "JetBrains Mono", "Fira Code", monospace;
    font-size: 12px;
    color: {aqua};
    background-color: {bg2};
    padding: 4px 10px;
    border-radius: 6px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* INPUT WIDGETS                                                    */
/* ═══════════════════════════════════════════════════════════════ */

.color-button {{
    min-width: 44px;
    min-height: 32px;
    border-radius: 8px;
    border: 2px solid {bg3};
}}

.spin-input {{
    background-color: {bg2};
    color: {fg};
    border-radius: 8px;
    border: 1px solid {bg3};
    padding: 4px 8px;
    min-width: 80px;
}}

.spin-input:focus {{
    border-color: {blue};
}}

.opacity-scale {{
    min-width: 150px;
}}

.opacity-scale trough {{
    background-color: {bg3};
    border-radius: 4px;
    min-height: 6px;
}}

.opacity-scale highlight {{
    background-color: {blue};
    border-radius: 4px;
}}

.opacity-scale slider {{
    background-color: {fg};
    border-radius: 50%;
    min-width: 18px;
    min-height: 18px;
    margin: -6px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
}}

switch {{
    background-color: {bg3};
    border-radius: 14px;
    min-width: 50px;
    min-height: 26px;
}}

switch:checked {{
    background-color: {green};
}}

switch slider {{
    background-color: {fg};
    border-radius: 13px;
    min-width: 22px;
    min-height: 22px;
    margin: 2px;
}}

.setting-dropdown {{
    background-color: {bg2};
    color: {fg};
    border-radius: 8px;
    padding: 6px 12px;
    border: 1px solid {bg3};
    min-width: 120px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* BUTTONS                                                          */
/* ═══════════════════════════════════════════════════════════════ */

.action-button {{
    padding: 10px 24px;
    border-radius: 8px;
    font-weight: 600;
    font-size: 13px;
    margin: 4px;
    border: none;
}}

.reset-button {{
    background-color: {red};
    color: white;
}}

.reset-button:hover {{
    background-color: #c75f68;
}}

.apply-button {{
    background-color: {green};
    color: {bg1};
}}

.apply-button:hover {{
    background-color: #88b369;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* PLACEHOLDER PAGES                                                */
/* ═══════════════════════════════════════════════════════════════ */

.info-banner {{
    background-color: {bg2};
    border: 1px solid {blue};
    border-radius: 8px;
    padding: 12px 16px;
}}

.placeholder-page {{
    padding: 48px;
}}

.placeholder-icon {{
    color: {grey0};
    opacity: 0.5;
    margin-bottom: 8px;
}}

.placeholder-title {{
    font-size: 24px;
    font-weight: 700;
    color: {fg};
}}

.placeholder-description {{
    font-size: 14px;
    color: {grey1};
    margin-top: 8px;
}}

.coming-soon-badge {{
    background-color: {purple};
    color: white;
    font-size: 11px;
    font-weight: 600;
    padding: 6px 16px;
    border-radius: 16px;
    margin-top: 16px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SCROLLBARS                                                       */
/* ═══════════════════════════════════════════════════════════════ */

scrollbar {{
    background-color: transparent;
}}

scrollbar slider {{
    background-color: {bg3};
    border-radius: 8px;
    min-width: 8px;
}}

scrollbar slider:hover {{
    background-color: {bg4};
}}

/* ═══════════════════════════════════════════════════════════════ */
/* PANEL PAGE - MODULE MANAGEMENT                                   */
/* ═══════════════════════════════════════════════════════════════ */

.module-chip {{
    background-color: {bg2};
    border: 1px solid {bg3};
    border-radius: 8px;
    padding: 6px 12px;
}}

.module-chip-label {{
    font-size: 13px;
    color: {fg};
}}

.module-chip-remove {{
    background: transparent;
    color: {red};
    border: none;
    padding: 2px;
    min-width: 20px;
    min-height: 20px;
}}

.module-chip-remove:hover {{
    background-color: {red};
    color: white;
    border-radius: 4px;
}}

.module-drop-zone {{
    background-color: {bg0};
    border: 2px dashed {bg3};
    border-radius: 12px;
    padding: 16px;
    min-height: 200px;
}}

.drop-zone-title {{
    font-size: 12px;
    font-weight: 600;
    color: {blue};
    letter-spacing: 1px;
}}

.modules-container {{
    background-color: {bg1};
    border-radius: 8px;
    padding: 8px;
    min-height: 150px;
}}

.add-module-btn {{
    background-color: {green};
    color: white;
    border-radius: 6px;
    padding: 4px 8px;
    min-width: 32px;
    min-height: 32px;
}}

.add-module-btn:hover {{
    background-color: #88b369;
}}

.size-selector {{
    background-color: {bg2};
    border-radius: 8px;
    padding: 4px;
}}

.size-btn {{
    background: transparent;
    color: {fg};
    border: none;
    border-radius: 6px;
    padding: 6px 16px;
    font-size: 12px;
    font-weight: 600;
}}

.size-btn:checked {{
    background-color: {blue};
    color: white;
}}

.size-btn:hover {{
    background-color: {bg3};
}}

tabbar {{
    background-color: {bg0};
}}

tabbar tab {{
    background-color: transparent;
    color: {grey1};
    border-radius: 8px 8px 0 0;
    padding: 10px 20px;
}}

tabbar tab:checked {{
    background-color: {bg1};
    color: {blue};
}}

/* Window sizing constraints */
window {{
    min-width: 900px;
    min-height: 650px;
}}

/* Content area scrolling */
.content-area {{
    min-height: 0;
}}

scrolledwindow {{
    min-height: 0;
}}

/* Wallpaper thumbnails */
.wallpaper-thumbnail {{
    border-radius: 8px;
    border: 2px solid {bg3};
}}

flowboxchild {{
    border-radius: 12px;
    padding: 8px;
}}

flowboxchild:selected {{
    background-color: {blue};
}}

flowboxchild:selected .wallpaper-thumbnail {{
    border-color: {bg0};
}}

.wallpaper-label {{
    font-size: 12px;
    color: {grey1};
}}
'''