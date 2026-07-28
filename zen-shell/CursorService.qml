pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * CursorService — v8.0.0-alpha-hf165
 *
 * Lists installed Xcursor themes (any directory that has a `cursors/` subdir under
 * the standard icon paths) and applies the chosen one LIVE via `hyprctl setcursor`
 * plus gsettings (so GTK apps follow too). The choice is persisted to cursor.json and
 * re-applied on shell start, so it survives a relogin without editing hyprland.conf.
 */
Singleton {
    id: root

    property var    themes: []        // [{ name }]
    property string current: ""       // active cursor theme name
    property int    size: 24          // cursor size in px

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/cursor.json"
    // v8.0.0-alpha-hf172 — Hyprland reads env at LAUNCH, so writing the cursor theme/size
    // here (sourced by hyprland.conf) sets the cursor from the very start of a session
    // on the next login — no beat of the default cursor before the shell re-applies.
    readonly property string envConfPath:
        Quickshell.env("HOME") + "/.config/hypr/modules/zen-cursor-env.conf"

    // ── scan installed cursor themes ──────────────────────────────────────────
    function scan() { themeScanner.running = true }

    Process {
        id: themeScanner
        running: false
        command: ["bash", "-c",
            "for d in \"$HOME/.icons\" \"$HOME/.local/share/icons\" \"$HOME/.themes\" \"$HOME/.cursor\" \"$HOME/.local/share/cursors\" /usr/share/icons /usr/local/share/icons; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  for t in \"$d\"/*/; do " +
            "    { [ -d \"${t}cursors\" ] || [ -f \"${t}manifest.hl\" ] || [ -d \"${t}hyprcursors\" ]; } && basename \"$t\"; " +
            "  done; " +
            "done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = (this.text || "").trim().split("\n").filter(l => l.length > 0)
                const seen = {}
                const list = []
                for (const n of names) if (!seen[n]) { seen[n] = true; list.push({ name: n }) }
                root.themes = list
                console.log("[CursorService] found", list.length, "cursor themes")
            }
        }
    }

    // ── apply live + persist ──────────────────────────────────────────────────
    function apply(theme) {
        if (!theme) return
        current = theme
        // path is passed positionally, never interpolated into the program.
        applier.command = ["bash", "-c",
            "T=\"$1\"; S=\"$2\"; " +
            "hyprctl setcursor \"$T\" \"$S\" >/dev/null 2>&1; " +
            "if command -v gsettings >/dev/null 2>&1; then " +
            "  gsettings set org.gnome.desktop.interface cursor-theme \"$T\" >/dev/null 2>&1; " +
            "  gsettings set org.gnome.desktop.interface cursor-size \"$S\" >/dev/null 2>&1; " +
            "fi; true",
            "_", theme, String(size)]
        applier.running = true
        saveState()
    }
    Process { id: applier; running: false }

    function setSize(s) {
        size = Math.max(8, Math.min(96, Math.round(s)))
        if (current) apply(current)
    }

    // ── persistence ───────────────────────────────────────────────────────────
    function saveState() {
        const envConf = "# Zen Shell — managed cursor env (edit via Control Center → Cursor & Icons).\n"
            + "env = XCURSOR_THEME," + current + "\n"
            + "env = HYPRCURSOR_THEME," + current + "\n"
            + "env = XCURSOR_SIZE," + size + "\n"
            + "env = HYPRCURSOR_SIZE," + size + "\n"
        stateSaver.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\" \"$(dirname \"$3\")\"; " +
            "printf '%s' \"$2\" > \"$1\"; " +
            "printf '%s' \"$4\" > \"$3\"",
            "_", statePath, JSON.stringify({ current: current, size: size }), envConfPath, envConf]
        stateSaver.running = true
    }
    Process { id: stateSaver; running: false }

    FileView {
        id: stateLoader
        path: root.statePath
        onLoaded: {
            try {
                const s = JSON.parse(this.text())
                if (typeof s.size === "number") root.size = s.size
                if (typeof s.current === "string" && s.current) {
                    // re-apply the saved cursor on shell start (survives relogin)
                    root.apply(s.current)
                }
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        scan()
        stateLoader.reload()
    }
}
