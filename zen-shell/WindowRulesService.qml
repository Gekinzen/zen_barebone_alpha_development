pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * WindowRulesService v7.0.0-beta.1-hf82v — Karui (軽い)
 *
 * SMART FLOAT RULES singleton. Per-app windowrule with:
 *   - float on
 *   - center on  (Hyprland built-in directive)
 *   - size W% H% (Hyprland's % units are monitor-scale-aware)
 *
 * Architecture:
 *   - JSON state: ~/.local/share/quickshell/zen-shell/window-rules.json
 *     (rich: per-app size/center/monitor overrides)
 *   - Hyprland conf: ~/.config/hypr/modules/zen-window-rules.conf
 *     (Hyprland 0.55 syntax: windowrule = match:class ^(N)$, float on,
 *      center on, size W% H%  # zen-shell-float)
 *   - notify-send fires after every toggle
 *
 * JSON is source of truth. On first run, conf is parsed for legacy
 * migration from hf82n-u.
 */
Singleton {
    id: root

    readonly property string confDir:
        Quickshell.env("HOME") + "/.config/hypr/modules"
    readonly property string confPath:
        confDir + "/zen-window-rules.conf"
    readonly property string statePath:
        Quickshell.dataPath("window-rules.json")

    // Smart size buckets (regex → percentage size)
    readonly property var sizeBuckets: [
        { rx: /calc/i,                                                       w: 25, h: 35 },
        { rx: /picture[\s\-_]?in[\s\-_]?picture/i,                           w: 30, h: 30 },
        { rx: /^(brave|firefox|chromium|vivaldi|opera|brave-browser)/i,      w: 75, h: 75 },
        { rx: /^(code|codium|vscode)/i,                                      w: 80, h: 80 },
        { rx: /(kitty|foot|wezterm|alacritty|gnome-terminal|xterm)/i,        w: 60, h: 70 },
        { rx: /(pavucontrol|blueman|nm-connection|nm-applet)/i,              w: 40, h: 60 },
        { rx: /(steam|lutris|heroic)/i,                                      w: 70, h: 80 },
        { rx: /(thunar|nautilus|dolphin|nemo|pcmanfm)/i,                     w: 65, h: 70 }
    ]

    function smartSizeFor(wmClass) {
        for (let i = 0; i < sizeBuckets.length; i++) {
            if (sizeBuckets[i].rx.test(wmClass)) {
                return { w: sizeBuckets[i].w, h: sizeBuckets[i].h }
            }
        }
        return { w: 65, h: 70 }
    }

    // floatRules: array of { class, w, h, center, monitor }
    property var floatRules: []
    property bool _loaded: false

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        onLoaded: {
            const raw = (typeof text === "function") ? text() : text
            root._loadFromJson(raw)
            root._loaded = true
            root._writeConf()
        }
        onLoadFailed: {
            // No JSON yet — try migrating from existing conf file
            root._migrateFromConf()
            root._loaded = true
        }
    }

    function _loadFromJson(raw) {
        if (!raw || raw.trim().length === 0) return
        try {
            const s = JSON.parse(raw)
            if (Array.isArray(s.floatRules)) {
                root.floatRules = s.floatRules
            }
        } catch (e) {
            console.error("[WindowRulesService] JSON parse error:", e)
        }
    }

    function _migrateFromConf() {
        migrateProc.command = ["bash", "-c",
            "[ -f '" + confPath + "' ] && cat '" + confPath + "' || echo ''"]
        migrateProc.running = false
        migrateProc.running = true
    }

    Process {
        id: migrateProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const rules = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    let m = line.match(/^windowrule\s*=\s*match:class\s*\^\(([^)]+)\)\$.*float\s+on.*#\s*zen-shell-float/)
                    if (!m) m = line.match(/^windowrule(?:v2)?\s*=\s*float\s*,\s*class:\^\(([^)]+)\)\$.*#\s*zen-shell-float/)
                    if (m && m[1]) {
                        const cls = m[1]
                        const sz = root.smartSizeFor(cls)
                        rules.push({
                            "class": cls, "w": sz.w, "h": sz.h,
                            "center": true, "monitor": "auto"
                        })
                    }
                }
                root.floatRules = rules
                root._writeConf()
            }
        }
    }

    // ── Public API ──

    function isFloating(wmClass) {
        if (!wmClass) return false
        for (let i = 0; i < floatRules.length; i++) {
            if (floatRules[i].class === wmClass) return true
        }
        return false
    }

    function ruleFor(wmClass) {
        for (let i = 0; i < floatRules.length; i++) {
            if (floatRules[i].class === wmClass) return floatRules[i]
        }
        return null
    }

    function setFloating(wmClass, floating, appLabel, appIcon) {
        if (!wmClass) return
        const idx = _indexOf(wmClass)
        const next = floatRules.slice()
        if (floating && idx === -1) {
            const sz = smartSizeFor(wmClass)
            next.push({
                "class": wmClass, "w": sz.w, "h": sz.h,
                "center": true, "monitor": "auto"
            })
            floatRules = next
            _writeConf()
            _notify(appLabel || wmClass, appIcon,
                "Float enabled  ·  " + sz.w + "% × " + sz.h + "%, centered")
        } else if (!floating && idx >= 0) {
            next.splice(idx, 1)
            floatRules = next
            _writeConf()
            _notify(appLabel || wmClass, appIcon, "Float disabled")
        }
    }

    function updateRule(wmClass, props, appLabel, appIcon) {
        if (!wmClass) return
        const idx = _indexOf(wmClass)
        if (idx === -1) return
        const next = floatRules.slice()
        const merged = {}
        for (const k in next[idx]) merged[k] = next[idx][k]
        for (const k in props) merged[k] = props[k]
        next[idx] = merged
        floatRules = next
        _writeConf()
        const cen = merged.center ? ", centered" : ""
        _notify(appLabel || wmClass, appIcon,
            "Float updated  ·  " + merged.w + "% × " + merged.h + "%" + cen)
    }

    function _indexOf(wmClass) {
        for (let i = 0; i < floatRules.length; i++) {
            if (floatRules[i].class === wmClass) return i
        }
        return -1
    }

    // ── JSON save (debounced) ──
    onFloatRulesChanged: { if (_loaded) saveTimer.restart() }
    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root._saveJson()
    }

    function _saveJson() {
        const json = JSON.stringify({ "floatRules": floatRules }, null, 2)
        const escaped = json.replace(/'/g, "'\\''")
        jsonWriter.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "tmp=$(mktemp) && printf '%s' '" + escaped + "' > \"$tmp\" && " +
            "mv \"$tmp\" '" + statePath + "'"]
        jsonWriter.running = true
    }
    Process { id: jsonWriter; running: false }

    // ── Hyprland conf write + hyprctl reload ──
    function _writeConf() {
        const sorted = floatRules.slice().sort((a, b) => a.class.localeCompare(b.class))
        let content = ""
        content += "# Managed by Zen Shell — Settings → App Float Rules\n"
        content += "# Generated from ~/.local/share/quickshell/zen-shell/window-rules.json\n"
        content += "# DO NOT EDIT MANUALLY — Settings UI will overwrite.\n"
        content += "#\n"
        for (let i = 0; i < sorted.length; i++) {
            const r = sorted[i]
            const center = (r.center !== false) ? "center on, " : ""
            const sz = "size " + (r.w || 65) + "% " + (r.h || 70) + "%"
            const mon = (r.monitor && r.monitor !== "auto" && r.monitor !== "current")
                ? ", monitor " + r.monitor : ""
            content += "windowrule = match:class ^(" + r.class + ")$, float on, "
                + center + sz + mon + "  # zen-shell-float\n"
        }
        const escaped = content.replace(/'/g, "'\\''")
        confWriter.command = ["bash", "-c",
            "mkdir -p '" + confDir + "' && " +
            "tmp=$(mktemp) && printf '%s' '" + escaped + "' > \"$tmp\" && " +
            "mv \"$tmp\" '" + confPath + "' && " +
            "hyprctl reload >/dev/null 2>&1 || true"]
        confWriter.running = false
        confWriter.running = true
    }
    Process { id: confWriter; running: false }

    // ── notify-send helper ──
    function _notify(title, iconHint, body) {
        const icon = (iconHint && iconHint.length > 0)
            ? iconHint : "preferences-system-windows"
        notifier.command = ["notify-send",
            "-a", "Zen Shell",
            "-i", icon,
            "-t", "3500",
            title, body]
        notifier.running = false
        notifier.running = true
    }
    Process { id: notifier; running: false }

    // ── Bulk ──
    function clearAll() {
        floatRules = []
        _writeConf()
        _notify("Zen Shell", "", "All float rules cleared")
    }

    function reloadHyprland() {
        reloadProc.running = false
        reloadProc.running = true
    }
    Process { id: reloadProc; running: false; command: ["hyprctl", "reload"] }
}
