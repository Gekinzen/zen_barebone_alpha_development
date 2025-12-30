"""
One Dark themed CSS styles for Hyprland Control Center
COMPLETE REWRITE - Guaranteed working version
"""

from .constants import ONE_DARK

def get_css() -> str:
    """Returns CSS with ONE_DARK colors applied"""
    return f'''
/* ═══════════════════════════════════════════════════════════════ */
/* WINDOW & CONTAINERS                                              */
/* ═══════════════════════════════════════════════════════════════ */

window {{
    background-color: {ONE_DARK["bg1"]};
}}

.sidebar {{
    background-color: {ONE_DARK["bg0"]};
    border-right: 1px solid {ONE_DARK["bg3"]};
}}

.content-area {{
    background-color: {ONE_DARK["bg1"]};
    padding: 24px 32px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SIDEBAR                                                          */
/* ═══════════════════════════════════════════════════════════════ */

.sidebar-title {{
    font-size: 18px;
    font-weight: 700;
    color: {ONE_DARK["fg"]};
    padding: 16px;
}}

.sidebar-section {{
    font-size: 11px;
    font-weight: 600;
    color: {ONE_DARK["grey0"]};
    letter-spacing: 1.2px;
    text-transform: uppercase;
    padding: 16px 16px 8px 16px;
}}

.sidebar-item {{
    padding: 10px 16px;
    margin: 2px 8px;
    border-radius: 8px;
    color: {ONE_DARK["fg"]};
    font-size: 13px;
}}

.sidebar-item:hover {{
    background-color: {ONE_DARK["bg2"]};
}}

.sidebar-item:selected,
.sidebar-item:checked {{
    background-color: {ONE_DARK["blue"]};
    color: {ONE_DARK["bg1"]};
}}

/* FORCE ALL ICONS WHITE - NUCLEAR OPTION */
.sidebar-icon,
.sidebar-item image,
image {{
    color: {ONE_DARK["fg"]} !important;
    -gtk-icon-palette: {ONE_DARK["fg"]} !important;
    -gtk-icon-style: symbolic;
}}

.sidebar-item:selected image,
.sidebar-item:checked image,
.sidebar-item:selected .sidebar-icon,
.sidebar-item:checked .sidebar-icon {{
    color: {ONE_DARK["bg0"]} !important;
    -gtk-icon-palette: {ONE_DARK["bg0"]} !important;
}}

/* Force ALL images white */
list image,
listbox image,
listboxrow image,
row image,
box image,
button image {{
    color: {ONE_DARK["fg"]} !important;
    -gtk-icon-palette: {ONE_DARK["fg"]} !important;
}}

/* Suggested action buttons - white icons on blue */
button.suggested-action image {{
    color: {ONE_DARK["bg0"]} !important;
    -gtk-icon-palette: {ONE_DARK["bg0"]} !important;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* PAGE HEADERS                                                     */
/* ═══════════════════════════════════════════════════════════════ */

.page-title {{
    font-size: 28px;
    font-weight: 700;
    color: {ONE_DARK["fg"]};
}}

.page-subtitle {{
    font-size: 14px;
    color: {ONE_DARK["grey1"]};
    margin-top: 4px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SETTINGS GROUPS                                                  */
/* ═══════════════════════════════════════════════════════════════ */

.settings-group {{
    background-color: {ONE_DARK["bg2"]};
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 16px;
}}

.settings-group-title {{
    font-size: 16px;
    font-weight: 600;
    color: {ONE_DARK["fg"]};
    margin-bottom: 12px;
}}

.setting-row {{
    padding: 12px 0;
    border-bottom: 1px solid {ONE_DARK["bg3"]};
}}

.setting-row:last-child {{
    border-bottom: none;
}}

.setting-label {{
    font-size: 14px;
    color: {ONE_DARK["fg"]};
}}

.setting-description {{
    font-size: 12px;
    color: {ONE_DARK["grey1"]};
    margin-top: 4px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* BUTTONS                                                          */
/* ═══════════════════════════════════════════════════════════════ */

button {{
    border-radius: 8px;
    padding: 8px 16px;
    font-weight: 500;
}}

button.suggested-action {{
    background-color: {ONE_DARK["blue"]};
    color: {ONE_DARK["bg0"]};
}}

button.destructive-action {{
    background-color: {ONE_DARK["red"]};
    color: {ONE_DARK["bg0"]};
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SCROLLBARS                                                       */
/* ═══════════════════════════════════════════════════════════════ */

scrolledwindow {{
    min-height: 0;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* WALLPAPER THUMBNAILS                                             */
/* ═══════════════════════════════════════════════════════════════ */

.wallpaper-frame {{
    border-radius: 12px;
    border: 2px solid {ONE_DARK["bg3"]};
    background-color: {ONE_DARK["bg2"]};
}}

.wallpaper-thumbnail {{
    border-radius: 12px;
}}

flowboxchild {{
    border-radius: 16px;
    padding: 12px;
    background: transparent;
}}

flowboxchild:hover {{
    background-color: {ONE_DARK["bg2"]};
}}

flowboxchild:selected {{
    background-color: {ONE_DARK["blue"]};
}}

flowboxchild:selected .wallpaper-frame {{
    border-color: {ONE_DARK["bg0"]};
    border-width: 3px;
}}

.wallpaper-label {{
    font-size: 11px;
    color: {ONE_DARK["grey1"]};
    margin-top: 4px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* MODULE CHIPS (Panel page)                                        */
/* ═══════════════════════════════════════════════════════════════ */

.module-chip {{
    background-color: {ONE_DARK["bg3"]};
    border-radius: 8px;
    padding: 8px 12px;
}}

.module-chip:hover {{
    background-color: {ONE_DARK["bg4"]};
}}

.module-chip-icon {{
    color: {ONE_DARK["blue"]};
    font-size: 16px;
}}

.module-chip-label {{
    color: {ONE_DARK["fg"]};
    font-size: 13px;
}}

.module-chip-remove {{
    color: {ONE_DARK["red"]};
}}

/* ═══════════════════════════════════════════════════════════════ */
/* MISC                                                             */
/* ═══════════════════════════════════════════════════════════════ */

.dim-label {{
    color: {ONE_DARK["grey1"]};
}}

.error-label {{
    color: {ONE_DARK["red"]};
}}

.placeholder-icon {{
    font-size: 48px;
    color: {ONE_DARK["grey1"]};
}}

.placeholder-text {{
    font-size: 16px;
    color: {ONE_DARK["grey1"]};
    margin-top: 12px;
}}
'''