"""
One Dark themed CSS styles for Hyprland Control Center
"""

from .constants import ONE_DARK

def get_css() -> str:
    """Returns the complete CSS stylesheet"""
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
    background-color: {ONE_DARK["bg0"]};
    border-radius: 12px;
    padding: 16px 20px;
    margin-bottom: 16px;
}}

.group-title {{
    font-size: 11px;
    font-weight: 600;
    color: {ONE_DARK["blue"]};
    letter-spacing: 1px;
}}

.section-header {{
    font-size: 12px;
    font-weight: 600;
    color: {ONE_DARK["purple"]};
    letter-spacing: 0.5px;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* SETTING ROWS                                                     */
/* ═══════════════════════════════════════════════════════════════ */

.setting-row {{
    padding: 6px 0;
    border-bottom: 1px solid {ONE_DARK["bg2"]};
}}

.setting-row:last-child {{
    border-bottom: none;
}}

.setting-label {{
    font-size: 14px;
    font-weight: 500;
    color: {ONE_DARK["fg"]};
}}

.setting-description {{
    font-size: 12px;
    color: {ONE_DARK["grey0"]};
}}

.value-mono {{
    font-family: "JetBrains Mono", "Fira Code", monospace;
    font-size: 12px;
    color: {ONE_DARK["aqua"]};
    background-color: {ONE_DARK["bg2"]};
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
    border: 2px solid {ONE_DARK["bg3"]};
}}

.spin-input {{
    background-color: {ONE_DARK["bg2"]};
    color: {ONE_DARK["fg"]};
    border-radius: 8px;
    border: 1px solid {ONE_DARK["bg3"]};
    padding: 4px 8px;
    min-width: 80px;
}}

.spin-input:focus {{
    border-color: {ONE_DARK["blue"]};
}}

.opacity-scale {{
    min-width: 150px;
}}

.opacity-scale trough {{
    background-color: {ONE_DARK["bg3"]};
    border-radius: 4px;
    min-height: 6px;
}}

.opacity-scale highlight {{
    background-color: {ONE_DARK["blue"]};
    border-radius: 4px;
}}

.opacity-scale slider {{
    background-color: {ONE_DARK["fg"]};
    border-radius: 50%;
    min-width: 18px;
    min-height: 18px;
    margin: -6px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
}}

switch {{
    background-color: {ONE_DARK["bg3"]};
    border-radius: 14px;
    min-width: 50px;
    min-height: 26px;
}}

switch:checked {{
    background-color: {ONE_DARK["green"]};
}}

switch slider {{
    background-color: {ONE_DARK["fg"]};
    border-radius: 13px;
    min-width: 22px;
    min-height: 22px;
    margin: 2px;
}}

.setting-dropdown {{
    background-color: {ONE_DARK["bg2"]};
    color: {ONE_DARK["fg"]};
    border-radius: 8px;
    padding: 6px 12px;
    border: 1px solid {ONE_DARK["bg3"]};
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
    background-color: {ONE_DARK["red"]};
    color: white;
}}

.reset-button:hover {{
    background-color: #c75f68;
}}

.apply-button {{
    background-color: {ONE_DARK["green"]};
    color: {ONE_DARK["bg1"]};
}}

.apply-button:hover {{
    background-color: #88b369;
}}

/* ═══════════════════════════════════════════════════════════════ */
/* PLACEHOLDER PAGES                                                */
/* ═══════════════════════════════════════════════════════════════ */

.info-banner {{
    background-color: {ONE_DARK["bg2"]};
    border: 1px solid {ONE_DARK["blue"]};
    border-radius: 8px;
    padding: 12px 16px;
}}

.placeholder-page {{
    padding: 48px;
}}

.placeholder-icon {{
    color: {ONE_DARK["grey0"]};
    opacity: 0.5;
    margin-bottom: 8px;
}}

.placeholder-title {{
    font-size: 24px;
    font-weight: 700;
    color: {ONE_DARK["fg"]};
}}

.placeholder-description {{
    font-size: 14px;
    color: {ONE_DARK["grey1"]};
    margin-top: 8px;
}}

.coming-soon-badge {{
    background-color: {ONE_DARK["purple"]};
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
    background-color: {ONE_DARK["bg3"]};
    border-radius: 8px;
    min-width: 8px;
}}

scrollbar slider:hover {{
    background-color: {ONE_DARK["bg4"]};
}}

/* ═══════════════════════════════════════════════════════════════ */
/* PANEL PAGE - MODULE MANAGEMENT                                   */
/* ═══════════════════════════════════════════════════════════════ */

.module-chip {{
    background-color: {ONE_DARK["bg2"]};
    border: 1px solid {ONE_DARK["bg3"]};
    border-radius: 8px;
    padding: 6px 12px;
}}

.module-chip-label {{
    font-size: 13px;
    color: {ONE_DARK["fg"]};
}}

.module-chip-remove {{
    background: transparent;
    color: {ONE_DARK["red"]};
    border: none;
    padding: 2px;
    min-width: 20px;
    min-height: 20px;
}}

.module-chip-remove:hover {{
    background-color: {ONE_DARK["red"]};
    color: white;
    border-radius: 4px;
}}

.module-drop-zone {{
    background-color: {ONE_DARK["bg0"]};
    border: 2px dashed {ONE_DARK["bg3"]};
    border-radius: 12px;
    padding: 16px;
    min-height: 200px;
}}

.drop-zone-title {{
    font-size: 12px;
    font-weight: 600;
    color: {ONE_DARK["blue"]};
    letter-spacing: 1px;
}}

.modules-container {{
    background-color: {ONE_DARK["bg1"]};
    border-radius: 8px;
    padding: 8px;
    min-height: 150px;
}}

.add-module-btn {{
    background-color: {ONE_DARK["green"]};
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
    background-color: {ONE_DARK["bg2"]};
    border-radius: 8px;
    padding: 4px;
}}

.size-btn {{
    background: transparent;
    color: {ONE_DARK["fg"]};
    border: none;
    border-radius: 6px;
    padding: 6px 16px;
    font-size: 12px;
    font-weight: 600;
}}

.size-btn:checked {{
    background-color: {ONE_DARK["blue"]};
    color: white;
}}

.size-btn:hover {{
    background-color: {ONE_DARK["bg3"]};
}}

tabbar {{
    background-color: {ONE_DARK["bg0"]};
}}

tabbar tab {{
    background-color: transparent;
    color: {ONE_DARK["grey1"]};
    border-radius: 8px 8px 0 0;
    padding: 10px 20px;
}}

tabbar tab:checked {{
    background-color: {ONE_DARK["bg1"]};
    color: {ONE_DARK["blue"]};
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
'''