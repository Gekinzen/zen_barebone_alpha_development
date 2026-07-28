pragma Singleton

import Quickshell
import QtQuick

/*
 * ZenConstants — static lookup tables for format pickers.
 *
 * Ported from Paul's Python Waybar section:
 *   - CLOCK_FORMATS (13 options)
 *   - WORKSPACE_NUMBER_FORMATS (11 presets)
 *   - FONT_FAMILIES (10 nerd font options w/ fallback chain)
 *
 * These are read by the Panel page dropdowns and by whichever bar module
 * renders the clock / workspaces. Selecting a new value updates the
 * matching property on PanelState / Theme which the module watches.
 */
Singleton {
    id: root

    // Clock glyph prefix (Nerd Font f017 = clock icon)
    readonly property string clockIcon: "\uf017"

    // Clock format options. Each entry has:
    //   - format: JavaScript date formatter string (uses {H}, {M}, etc. — see
    //     formatClock() below for the mapping; mimics Python's %I/%M syntax
    //     so it's identical to Paul's Python constants)
    //   - label: human-readable dropdown label
    readonly property var clockFormats: [
        { format: "%I:%M %p",                    label: "12-hour (3:45 PM)" },
        { format: "%H:%M",                       label: "24-hour (15:45)" },
        { format: "%I:%M:%S %p",                 label: "12-hour with seconds (3:45:30 PM)" },
        { format: "%H:%M:%S",                    label: "24-hour with seconds (15:45:30)" },
        { format: "%Y-%m-%d  %I:%M %p",          label: "Date + 12-hour" },
        { format: "%Y-%m-%d  %H:%M",             label: "Date + 24-hour" },
        { format: "%Y-%m-%d \n %I:%M:%S %p",     label: "Date + 12h multiline (default)" },
        { format: "%Y-%m-%d \n %H:%M:%S",        label: "Date + 24h multiline" },
        { format: "%Y-%m-%d",                    label: "Date only" },
        { format: "%A, %B %d\n%I:%M:%S %p",      label: "Full weekday + 12h" },
        { format: "%A, %B %d\n%I:%M %p",         label: "Weekday + 12h" },
        { format: "%a %b %d  %I:%M %p",          label: "Short date + 12h" },
        { format: "%a %b %d  %H:%M",             label: "Short date + 24h" }
    ]

    // JavaScript/QML Date-aware version of Python's strftime for the
    // subset of format codes used in clockFormats.
    function formatClock(date: var, fmtStr: string, withIcon: bool): string {
        const pad2 = n => String(n).padStart(2, "0")
        const weekdaysShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const weekdaysLong = ["Sunday", "Monday", "Tuesday", "Wednesday",
                              "Thursday", "Friday", "Saturday"]
        const monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        const monthsLong = ["January", "February", "March", "April", "May",
                            "June", "July", "August", "September", "October",
                            "November", "December"]

        const h24 = date.getHours()
        const h12 = h24 === 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
        const ap = h24 < 12 ? "AM" : "PM"

        let out = fmtStr
            .replace(/%I/g, pad2(h12))
            .replace(/%H/g, pad2(h24))
            .replace(/%M/g, pad2(date.getMinutes()))
            .replace(/%S/g, pad2(date.getSeconds()))
            .replace(/%p/g, ap)
            .replace(/%Y/g, String(date.getFullYear()))
            .replace(/%m/g, pad2(date.getMonth() + 1))
            .replace(/%d/g, pad2(date.getDate()))
            .replace(/%A/g, weekdaysLong[date.getDay()])
            .replace(/%a/g, weekdaysShort[date.getDay()])
            .replace(/%B/g, monthsLong[date.getMonth()])
            .replace(/%b/g, monthsShort[date.getMonth()])

        return withIcon ? (clockIcon + " " + out) : out
    }

    // ═════════════════════════════════════════════════════════════════
    // WORKSPACE NUMBER FORMATS — 11 presets supporting 1-10
    // ═════════════════════════════════════════════════════════════════
    readonly property var workspaceFormats: ({
        "numbers": {
            name: "Numbers (1-10)",
            icons: { "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
                     "6": "6", "7": "7", "8": "8", "9": "9", "10": "10" }
        },
        "korean": {
            name: "Korean (일-십)",
            icons: { "1": "일", "2": "이", "3": "삼", "4": "사", "5": "오",
                     "6": "육", "7": "칠", "8": "팔", "9": "구", "10": "십" }
        },
        "chinese": {
            name: "Chinese (一-十)",
            icons: { "1": "一", "2": "二", "3": "三", "4": "四", "5": "五",
                     "6": "六", "7": "七", "8": "八", "9": "九", "10": "十" }
        },
        "japanese": {
            name: "Japanese (壱-拾)",
            icons: { "1": "壱", "2": "弐", "3": "参", "4": "肆", "5": "伍",
                     "6": "六", "7": "七", "8": "八", "9": "九", "10": "拾" }
        },
        "roman": {
            name: "Roman (I-X)",
            icons: { "1": "I", "2": "II", "3": "III", "4": "IV", "5": "V",
                     "6": "VI", "7": "VII", "8": "VIII", "9": "IX", "10": "X" }
        },
        "nerd-dots": {
            name: "Nerd Dots (󰎤-󰽽)",
            icons: { "1": "\udb80\udfa4", "2": "\udb80\udfa7", "3": "\udb80\udfaa",
                     "4": "\udb80\udfad", "5": "\udb80\udfb1", "6": "\udb80\udfb3",
                     "7": "\udb80\udfb6", "8": "\udb80\udfb9", "9": "\udb80\udfbc",
                     "10": "\udb82\udffd" }
        },
        "nerd-circles": {
            name: "Nerd Circles (①-⑩)",
            icons: { "1": "①", "2": "②", "3": "③", "4": "④", "5": "⑤",
                     "6": "⑥", "7": "⑦", "8": "⑧", "9": "⑨", "10": "⑩" }
        },
        "classic-dots": {
            name: "Classic Dots (● pill)",
            icons: { "1": "\u25cf", "2": "\u25cf", "3": "\u25cf", "4": "\u25cf", "5": "\u25cf",
                     "6": "\u25cf", "7": "\u25cf", "8": "\u25cf", "9": "\u25cf", "10": "\u25cf" }
        },
        "nerd-squares": {
            name: "Nerd Squares (󰎣-󰎾)",
            icons: { "1": "\udb80\udfa3", "2": "\udb80\udfa6", "3": "\udb80\udfa9",
                     "4": "\udb80\udfac", "5": "\udb80\udfae", "6": "\udb80\udfb0",
                     "7": "\udb80\udfb5", "8": "\udb80\udfb8", "9": "\udb80\udfbb",
                     "10": "\udb80\udfbe" }
        },
        "symbols": {
            name: "Symbols (󰋜 󰈹 ...)",
            icons: { "1": "\udb80\udedc", "2": "\udb80\ude39", "3": "\udb82\udea1",
                     "4": "\udb82\ude6f", "5": "\udb82\ude76", "6": "\udb81\ude4b",
                     "7": "\udb80\ude97", "8": "\udb83\udf88", "9": "\udb80\ude10",
                     "10": "\udb83\udf7c" }
        },
        "empty": {
            name: "Empty (no labels)",
            icons: { "1": "", "2": "", "3": "", "4": "", "5": "",
                     "6": "", "7": "", "8": "", "9": "", "10": "" }
        },
        "custom": {
            name: "Custom",
            icons: { "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
                     "6": "6", "7": "7", "8": "8", "9": "9", "10": "10" }
        }
    })

    // Returns the icon for workspace `n` using the current format preset
    function workspaceIcon(presetId: string, wsNum: var): string {
        const preset = workspaceFormats[presetId] || workspaceFormats["numbers"]
        const key = "" + wsNum
        if (preset.icons.hasOwnProperty(key)) return preset.icons[key]
        // For workspaces > 10, fall back to the numeric representation
        return key
    }

    // ═════════════════════════════════════════════════════════════════
    // FONT FAMILIES — 10 presets with Nerd Font fallback chain
    // ═════════════════════════════════════════════════════════════════
    readonly property var fontFamilies: [
        { id: "adwaita",    label: "Adwaita Sans",
          css: "\"Adwaita Sans\", \"JetBrainsMono Nerd Font Propo\", sans-serif" },
        { id: "jetbrains",  label: "JetBrains Mono",
          css: "\"JetBrainsMono Nerd Font\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "geist",      label: "GeistMono",
          css: "\"GeistMono Nerd Font Mono\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "firacode",   label: "FiraCode",
          css: "\"FiraCode Nerd Font\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "caskaydia",  label: "CaskaydiaCove",
          css: "\"CaskaydiaCove Nerd Font\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "iosevka",    label: "Iosevka",
          css: "\"Iosevka Nerd Font\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "hack",       label: "Hack",
          css: "\"Hack Nerd Font\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "ubuntu",     label: "Ubuntu Mono",
          css: "\"UbuntuMono Nerd Font\", \"JetBrainsMono Nerd Font Propo\", monospace" },
        { id: "sfpro",      label: "SF Pro",
          css: "\"SF Pro Display\", \"JetBrainsMono Nerd Font Propo\", sans-serif" },
        { id: "inter",      label: "Inter",
          css: "\"Inter\", \"JetBrainsMono Nerd Font Propo\", sans-serif" }
    ]

    // For QML Text.font.family — takes the primary font name (no quotes)
    function fontPrimary(fontId: string): string {
        for (const f of fontFamilies) {
            if (f.id === fontId) {
                // Extract first quoted string from css
                const m = f.css.match(/"([^"]+)"/)
                return m ? m[1] : "sans-serif"
            }
        }
        return "sans-serif"
    }
}
