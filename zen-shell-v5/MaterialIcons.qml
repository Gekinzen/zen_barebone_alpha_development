pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * MaterialIcons v7.0.0-alpha.6-hf1 — Google Material Symbols Outlined registry
 *
 * Provides icon-name → unicode codepoint resolution for the Material
 * Symbols Outlined font family. Used by the new search bar UI in
 * Settings + Hypr Control Center per Paul's request, and by the
 * Clipboard module/panel.
 *
 * IMPORTANT: This co-exists with the existing JetBrainsMono Nerd Font
 * — we don't replace anything. Surfaces that already use Nerd Font
 * keep using Nerd Font. Only NEW UIs introduced in alpha.6+ that
 * specifically request Material aesthetics use these codepoints.
 *
 * Font dependency: install one of these system fonts:
 *   - ttf-material-symbols (AUR, recommended)
 *   - or download from https://fonts.google.com/icons?icon.style=Outlined
 *
 * If the font is missing, the .text values render as boxes — install
 * advisory shown in install.sh on first run.
 *
 * The codepoints below are sourced from Google's Material Symbols
 * Outlined codepoint reference (variable font axis: FILL=0, weight=400).
 *
 * Pattern (per-call, no instance state):
 *
 *   Text {
 *       text: MaterialIcons.icon("search")
 *       font.family: MaterialIcons.fontFamily
 *       font.pixelSize: 18
 *   }
 *
 * Wala tayong babawasan — purely additive singleton. Surfaces using
 * Nerd Font \uXXXX glyphs work unchanged.
 *
 * hf1: changed root from `Singleton { ... }` (Quickshell-only type)
 * to QtObject (canonical Qt singleton base). This service holds only
 * data + pure functions — no Quickshell APIs needed, so QtObject is
 * the cleanest root.
 */
QtObject {
    id: root

    // hf1: Auto-detected at startup. Defaults to FALSE; the Process
    // probe below flips it to TRUE if Material Symbols Outlined font
    // is found on the system via `fc-list`. Once detected, every
    // consumer surface auto-switches to the Material codepoints +
    // family without any manual edits.
    //
    // Users who installed via install.sh (which now offers ttf-material-
    // symbols-variable-git as an optional install) will get crisp
    // Material glyphs automatically. Users who skipped the install
    // get the Nerd Font fallback.
    //
    // v7.0.0-alpha.10-hf6: HARDCODED to false. The Material Symbols
    // Outlined font uses DIFFERENT codepoints than the older Material
    // Icons Outlined font that the registry was built for, so even
    // with the new font installed, glyphs render as empty boxes.
    // Sticking with Nerd Font fallback (which has known-correct
    // codepoints) until the registry is updated to match the new
    // Material Symbols Outlined codepoint scheme. Tradeoff: less
    // crisp glyphs, but ALWAYS visible.
    property bool materialAvailable: false

    // Font probe disabled in hf6 — leaving the Process declaration
    // commented out for future re-enabling once the registry is
    // updated to match Material Symbols Outlined.
    /*
    property var _fontProbe: Process {
        running: true
        command: ["bash", "-c",
            "fc-list 2>/dev/null | grep -iq 'Material Symbols Outlined' && echo INSTALLED || echo MISSING"]
        stdout: StdioCollector {
            onStreamFinished: {
                if ((this.text || "").indexOf("INSTALLED") >= 0) {
                    root.materialAvailable = true
                }
            }
        }
    }
    */

    // System font family. Material Symbols Outlined is the variable
    // font; Material Icons Outlined is the legacy static font.
    //
    // hf4: If Material Symbols isn't installed at all, the chain
    // falls all the way to Nerd Font — but Nerd Font has DIFFERENT
    // codepoints than Material, so the icons render as garbage glyphs
    // (the X's the user reported). To avoid that, we auto-switch
    // BOTH the font family AND the codepoint registry based on
    // `materialAvailable`. Consumers just use:
    //
    //   font.family: MaterialIcons.fontFamily
    //   text:        MaterialIcons.icon("search")
    //
    // and get a coherent (font, codepoint) pair regardless of which
    // font is actually installed.
    //
    // Effective fontFamily binding — switches based on the auto-
    // detected `materialAvailable` flag set by the Process probe
    // above. When Material Symbols is installed, the chain prefers
    // it; otherwise we use Nerd Font directly so the font + codepoint
    // pair stays in sync.
    readonly property string fontFamily: materialAvailable
        ? "Material Symbols Outlined, Material Icons Outlined, JetBrainsMono Nerd Font"
        : "JetBrainsMono Nerd Font, monospace"

    function icon(name) {
        if (materialAvailable) return registry[name] || ""
        return nerdFallback[name] || ""
    }

    function has(name) {
        return registry[name] !== undefined
    }

    // Icon-name → codepoint registry. Add more here as needed.
    // Codepoints from https://fonts.google.com/icons (Outlined style).
    readonly property var registry: ({
        // Search & navigation
        "search":           "\ue8b6",
        "close":            "\ue5cd",
        "arrow_back":       "\ue5c4",
        "arrow_forward":    "\ue5c8",
        "chevron_right":    "\ue5cc",
        "chevron_left":     "\ue5cb",
        "expand_more":      "\ue5cf",
        "expand_less":      "\ue5ce",
        "menu":             "\ue5d2",

        // Settings categories (mapped to existing nav items)
        "tune":             "\ue429",   // general / preferences
        "palette":          "\ue40a",   // themes
        "brush":            "\ue3ae",   // decoration
        "animation":        "\ue71c",   // animations
        "monitor":          "\ue1af",   // displays
        "mouse":            "\ue323",   // input
        "view_quilt":       "\ue8f0",   // panel
        "widgets":          "\ue1bd",   // bar modules / widgets
        "memory":           "\ue322",   // system tray / system
        "wifi":             "\ue63e",   // sound & network
        "notifications":    "\ue7f4",
        "battery_full":     "\ue1a4",
        "person":           "\ue7fd",   // user profile
        "refresh":          "\ue5d5",   // updates
        "image":            "\ue3f4",   // wallpaper

        // Clipboard
        "content_paste":    "\ue14f",
        "content_copy":     "\ue14d",
        "history":          "\ue889",
        "push_pin":         "\uf10d",
        "delete":           "\ue872",
        "assignment":       "\ue85d",   // v7.0.0-alpha.6-hf3 — preferred clipboard glyph (clipboard with checklist lines)

        // Misc
        "settings":         "\ue8b8",
        "info":             "\ue88e",
        "warning":          "\ue002",
        "check":            "\ue5ca",
        "star":             "\ue838",
        "computer":         "\ue30a",
        "speed":            "\ue9e4",
        "bolt":             "\uea0b",
        "power_settings":   "\ue8ac",
        "lock":              "\ue897",
        "logout":           "\ue9ba"
    })

    // Nerd Font codepoint fallback — used when Material Symbols isn't
    // installed. Mappings chosen for visual similarity (clipboard →
    // clipboard nerd glyph, search → search nerd glyph, etc.). Where
    // no perfect Nerd equivalent exists, the closest available is
    // picked. Consumers transparently get the right glyph via the
    // icon() function which checks materialAvailable.
    readonly property var nerdFallback: ({
        // Search & navigation
        "search":           "\uf002",
        "close":            "\uf00d",
        "arrow_back":       "\uf060",
        "arrow_forward":    "\uf061",
        "chevron_right":    "\uf054",
        "chevron_left":     "\uf053",
        "expand_more":      "\uf078",
        "expand_less":      "\uf077",
        "menu":             "\uf0c9",

        // Settings categories
        "tune":             "\uf013",
        "palette":          "\uf1fc",   // hf6: was \uf53f (paint-brush filled, not in older Nerd Fonts), now \uf1fc (paint-brush — universally available)
        "brush":            "\uf1fc",
        "animation":        "\uf021",
        "monitor":          "\uf108",
        "mouse":            "\uf245",
        "view_quilt":       "\uf009",
        "widgets":          "\uf1bd",
        "memory":           "\uf538",
        "wifi":             "\uf1eb",
        "notifications":    "\uf0f3",
        "battery_full":     "\uf240",
        "person":           "\uf007",
        "refresh":          "\uf021",
        "image":            "\uf03e",
        "rocket_launch":    "\uf135",   // hf6 — for app launching results
        "calculator":       "\uf1ec",   // hf6 — for calc results
        "description":      "\uf15b",   // alpha.11 — file/document icon
        "folder":           "\uf07b",   // alpha.11 — directory icon (future)

        // Clipboard
        "content_paste":    "\uf0ea",
        "content_copy":     "\uf0c5",
        "history":          "\uf1da",
        "push_pin":         "\uf08d",
        "delete":           "\uf2ed",
        "assignment":       "\uf46d",   // clipboard with check (closest Nerd equiv)

        // Misc
        "settings":         "\uf013",
        "info":             "\uf05a",
        "warning":          "\uf071",
        "check":            "\uf00c",
        "star":             "\uf005",
        "computer":         "\uf108",
        "speed":            "\uf3fd",
        "bolt":             "\uf0e7",
        "power_settings":   "\uf011",
        "lock":             "\uf023",
        "logout":           "\uf2f5"
    })
}
