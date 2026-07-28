pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * IconThemeService — v8.0.0-alpha-hf170
 *
 * Lists installed GTK icon themes (a directory with an index.theme that has a
 * `Directories=` line — which is what separates a real icon theme from a cursor
 * theme) and applies the chosen one via gsettings, so you don't have to open a
 * separate GTK settings tool. gsettings/dconf persists the choice across reboots,
 * and we read the current value back so the UI reflects what's actually set.
 */
Singleton {
    id: root

    property var    themes: []        // [{ name }]
    property string current: ""       // active GTK icon theme

    function scan() { scanner.running = true; currentReader.running = true }

    Process {
        id: scanner
        running: false
        command: ["bash", "-c",
            "for d in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/share/icons /usr/local/share/icons; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  for t in \"$d\"/*/; do " +
            "    [ -f \"${t}index.theme\" ] && grep -q '^Directories=' \"${t}index.theme\" 2>/dev/null && basename \"$t\"; " +
            "  done; " +
            "done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = (this.text || "").trim().split("\n").filter(l => l.length > 0)
                const seen = {}
                const list = []
                for (const n of names) if (!seen[n]) { seen[n] = true; list.push({ name: n }) }
                root.themes = list
                console.log("[IconThemeService] found", list.length, "icon themes")
            }
        }
    }

    // Read the currently-set GTK icon theme so the dropdown shows the real value.
    Process {
        id: currentReader
        running: false
        command: ["bash", "-c",
            "command -v gsettings >/dev/null 2>&1 && gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \"'\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = (this.text || "").trim()
                if (v) root.current = v
            }
        }
    }

    function apply(theme) {
        if (!theme) return
        current = theme
        // theme is a positional arg, never interpolated into the program.
        applier.command = ["bash", "-c",
            "T=\"$1\"; " +
            "if command -v gsettings >/dev/null 2>&1; then " +
            "  gsettings set org.gnome.desktop.interface icon-theme \"$T\" >/dev/null 2>&1; " +
            "fi; true",
            "_", theme]
        applier.running = true
    }
    Process { id: applier; running: false }

    Component.onCompleted: scan()
}
