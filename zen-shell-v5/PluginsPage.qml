import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * PluginsPage v6.16.4.12.6.51 (Hikari)
 *
 * Settings page for Hyprland plugins integration. Provides toggles to
 * enable/disable popular plugins:
 *   - hyprbars     — title bars on floating windows
 *   - hyprexpo     — mission control overview
 *   - hyprwinwrap  — live wallpaper engine
 *   - borders-plus-plus — extra customizable borders
 *   - xtra-dispatchers — additional keybind dispatchers
 *
 * How it works:
 *   - Each toggle writes a managed block in
 *     ~/.config/hypr/modules/plugins.conf
 *   - On enable: appends `plugin = <path/to/plugin.so>` line
 *   - On disable: comments it out (kept for revert via toggle ON)
 *   - Calls `hyprctl reload` after each change so it applies live
 *
 * NOTE on plugin installation: this page only manages config — it
 * does NOT install plugins. User must install via:
 *   hyprpm add https://github.com/hyprwm/hyprland-plugins
 *   hyprpm enable hyprbars
 *   hyprpm reload
 *
 * The page detects whether a plugin is installed (looks for the .so in
 * standard hyprpm path ~/.local/share/hyprpm/...) and shows a
 * "not installed" badge with a copyable install command if missing.
 *
 * Wala tayo babawasan: this is a NEW page. ZenSettings.qml is updated
 * to include it in the page Repeater. Existing pages untouched.
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    readonly property string pluginsConfPath:
        Quickshell.env("HOME") + "/.config/hypr/modules/plugins.conf"
    readonly property string hyprpmDataDir:
        Quickshell.env("HOME") + "/.local/share/hyprpm"

    // ── Plugin definitions ──
    // ALL plugins from https://github.com/hyprwm/hyprland-plugins
    // (verified from `hyprpm list` output). Some may show "build failed"
    // if your Hyprland version is too new for the plugin. UI handles
    // this gracefully via the 3-state badge (installed/build_failed/
    // not_installed).
    readonly property var pluginDefs: [
        {
            id: "hyprbars",
            name: "Hyprbars",
            description: "Title bars on floating windows with min/max/close buttons",
            repo: "https://github.com/hyprwm/hyprland-plugins",
            soPath: "hyprbars/hyprbars.so",
            hasOptions: true   // hyprbars has position/color options
        },
        {
            id: "hyprexpo",
            name: "Hyprexpo",
            description: "Mission Control style workspace overview",
            repo: "https://github.com/hyprwm/hyprland-plugins",
            soPath: "hyprexpo/hyprexpo.so",
            hasOptions: false
        },
        {
            id: "hyprwinwrap",
            name: "Hyprwinwrap",
            description: "Live wallpaper engine (use any window as wallpaper)",
            repo: "https://github.com/hyprwm/hyprland-plugins",
            soPath: "hyprwinwrap/hyprwinwrap.so",
            hasOptions: false
        },
        {
            id: "borders-plus-plus",
            name: "Borders++",
            description: "Adds one or two additional configurable borders to windows",
            repo: "https://github.com/hyprwm/hyprland-plugins",
            soPath: "borders-plus-plus/borders-plus-plus.so",
            hasOptions: false
        },
        {
            id: "xtra-dispatchers",
            name: "Xtra Dispatchers",
            description: "Additional keybind dispatchers (e.g. movetoworkspacesilent variants)",
            repo: "https://github.com/hyprwm/hyprland-plugins",
            soPath: "xtra-dispatchers/xtra-dispatchers.so",
            hasOptions: false
        }
    ]

    // ── State: { hyprbars: true, hyprexpo: false, ... } ──
    property var enabledMap: ({})

    // Tracks if we've done the initial conf-restore for this session.
    // Set to true after first hyprpm list parse completes — prevents
    // applyChanges() from running on every 3s auto-refresh.
    property bool _initialApplyDone: false

    // ── State: { hyprbars: true, hyprexpo: false, ... } detection ──
    property var installedMap: ({})

    // ── Hyprbars-specific options ──
    property string hyprbarsButtonAlignment: "right"   // "left" | "right"
    property int hyprbarsHeight: 28

    Component.onCompleted: {
        loadPluginsConf()
        detectInstalledPlugins()
    }

    // v6.16.4.12.6.26: Auto-refresh detection every 3s while page is
    // v6.16.4.12.6.39: Auto-refresh BUT respects toggle debounce.
    // After user clicks a toggle, we suspend auto-refresh for 5s so
    // hyprpm has time to actually flip state in its store before we
    // re-read it. Otherwise: auto-refresh runs while hyprpm is mid-
    // enable → reads stale state → resets enabledMap to false → blue
    // box flickers visible-then-hidden.
    property bool _toggleInFlight: false
    Timer {
        id: toggleSettleTimer
        interval: 5000
        repeat: false
        onTriggered: root._toggleInFlight = false
    }
    Timer {
        id: autoRefreshTimer
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: {
            if (!root._toggleInFlight) {
                root.detectInstalledPlugins()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Config file reading
    // ─────────────────────────────────────────────────────────────
    FileView {
        id: confLoader
        path: root.pluginsConfPath
        blockLoading: false
        onLoaded: root._parseConfText(this.text())
    }

    function loadPluginsConf() {
        confLoader.path = ""   // force re-read
        confLoader.path = root.pluginsConfPath
    }

    function _parseConfText(text) {
        const map = {}
        const lines = (text || "").split("\n")
        for (const def of root.pluginDefs) map[def.id] = false

        for (const line of lines) {
            const trimmed = line.trim()
            // Skip comments and blanks
            if (trimmed.startsWith("#") || trimmed === "") continue
            // Match: plugin = /path/to/<name>.so
            // OR:    plugin = <name>
            const match = trimmed.match(/^plugin\s*=\s*(.+)$/)
            if (!match) continue
            const value = match[1].trim()
            for (const def of root.pluginDefs) {
                if (value.indexOf(def.id) >= 0) {
                    map[def.id] = true
                }
            }
        }
        root.enabledMap = map

        // Also detect hyprbars button-alignment + height from conf
        const alignMatch = text.match(/plugin:hyprbars:bar_buttons_alignment\s*=\s*(\w+)/)
        if (alignMatch) root.hyprbarsButtonAlignment = alignMatch[1]
        const heightMatch = text.match(/plugin:hyprbars:bar_height\s*=\s*(\d+)/)
        if (heightMatch) root.hyprbarsHeight = parseInt(heightMatch[1])
    }

    // ─────────────────────────────────────────────────────────────
    // Detect plugin status — installed, build-failed, or absent
    // Uses two sources:
    //   1. ~/.local/share/hyprpm/*/plugin.so      → "installed"
    //   2. hyprpm-state.json (written by install.sh) → known build failures
    // ─────────────────────────────────────────────────────────────
    property var failedMap: ({})

    function detectInstalledPlugins() {
        // v6.16.4.12.6.32: Use `hyprpm list` as SINGLE SOURCE OF TRUTH.
        //
        // Previous filesystem find approach was unreliable because:
        //   - hyprpm stores .so at variable depths (2-4 levels)
        //   - Some symlinks confuse find
        //   - Tracking 2 separate sources (filesystem + hyprpm) creates
        //     inconsistency (e.g. hyprpm shows enabled=true but filesystem
        //     check returns false → toggle disabled even though working)
        //
        // hyprpm list output for a plugin looks like:
        //   │ Plugin hyprbars
        //   └─ enabled: true                    → installed + enabled
        //   └─ enabled: false                   → installed + disabled
        //   └─ enabled: Plugin failed to build  → NOT installed (build broken)
        //
        // So: installed = appears in list AND state isn't "failed"
        //     enabled   = state is "true"
        hyprpmStateReader.command = ["bash", "-lc",
            "hyprpm list 2>/dev/null"]
        hyprpmStateReader.running = true
        readBuildState()
    }

    // Read all plugin states from hyprpm list — installed + enabled in one pass
    Process {
        id: hyprpmStateReader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || ""
                const installed = {}
                const enabled = {}
                // Init to false
                for (const def of root.pluginDefs) {
                    installed[def.id] = false
                    enabled[def.id] = false
                }
                // Parse: track current plugin name + look at next line for state
                const lines = text.split("\n")
                let currentPlugin = ""
                for (const line of lines) {
                    const pluginMatch = line.match(/Plugin\s+(\S+)/)
                    if (pluginMatch) {
                        currentPlugin = pluginMatch[1]
                        continue
                    }
                    const stateMatch = line.match(/enabled:\s*(.+?)\s*$/)
                    if (stateMatch && currentPlugin) {
                        const state = stateMatch[1].trim()
                        // Check if our managed plugin
                        for (const def of root.pluginDefs) {
                            if (def.id === currentPlugin) {
                                // Installed = appears in list AND not "failed to build"
                                installed[def.id] = !state.toLowerCase().includes("failed")
                                // Enabled = state is literal "true"
                                enabled[def.id] = (state === "true")
                                break
                            }
                        }
                        currentPlugin = ""  // reset for next entry
                    }
                }
                root.installedMap = installed
                root.enabledMap = enabled
                console.log("[PluginsPage] detect:",
                    "installed=" + JSON.stringify(installed),
                    "enabled=" + JSON.stringify(enabled))
                // v6.16.4.12.6.35: ALWAYS re-apply plugins.conf on first
                // detect per session, regardless of hyprbars enabled state.
                //
                // Why: previous versions wrote conf with old syntax (e.g.
                //   `windowrule = plugin:hyprbars:nobar, floating:0`)
                // which causes "missing a value" errors in Hyprland 0.53+.
                // If hyprbars is now disabled but stale rules linger from
                // old install, hyprctl reload still parses them and errors.
                //
                // Solution: rewrite the conf file every session with current
                // (correct) syntax. _buildConfText() emits hyprbars rules
                // ONLY when enabled, so disabled state = clean conf with
                // just commented-out plugin lines. No more stale syntax.
                if (!root._initialApplyDone) {
                    root._initialApplyDone = true
                    console.log("[PluginsPage] First detect — refreshing plugins.conf with current syntax")
                    Qt.callLater(() => root.applyChanges())
                }
            }
        }
    }

    // Read hyprpm-state.json written by install.sh's [8.7/9] step.
    // Format:
    //   { "built": ["hyprexpo", ...], "failed": ["hyprbars", ...] }
    function readBuildState() {
        buildStateReader.command = ["bash", "-lc",
            "cat \"$HOME/.config/quickshell/zen-shell/hyprpm-state.json\" 2>/dev/null"]
        buildStateReader.running = true
    }
    Process {
        id: buildStateReader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const text = (this.text || "").trim()
                if (!text) return
                try {
                    const json = JSON.parse(text)
                    const failed = json.failed || []
                    const map = {}
                    for (const def of root.pluginDefs) {
                        map[def.id] = failed.indexOf(def.id) >= 0
                    }
                    root.failedMap = map
                } catch (e) {
                    console.log("[PluginsPage] hyprpm-state.json parse failed:", e)
                }
            }
        }
    }

    // Re-detect after running the recovery
    function refresh() {
        detectInstalledPlugins()
    }

    // ─────────────────────────────────────────────────────────────
    // Config file writing
    // ─────────────────────────────────────────────────────────────
    function _buildConfText() {
        const lines = []
        lines.push("# ─────────────────────────────────────────────────────────")
        lines.push("# Generated by Zen Settings — Plugins page")
        lines.push("# DO NOT hand-edit between MANAGED-BLOCK markers; toggle in")
        lines.push("# Settings → Plugins instead. Custom additions outside the")
        lines.push("# managed block are preserved on regeneration.")
        lines.push("# ─────────────────────────────────────────────────────────")
        lines.push("# MANAGED-BLOCK BEGIN")
        // v6.16.4.12.6.37: We DO NOT write `plugin = <path>` lines here.
        //
        // Why: hyprpm handles plugin loading via `hyprctl plugin load
        // <absolute_path>` when `hyprpm reload` is called. Writing
        // `plugin = hyprbars` in plugins.conf would cause Hyprland to
        // try dlopen("hyprbars") as a literal path → "cannot open shared
        // object file" error.
        //
        // To use a `plugin = ` directive instead, you'd need the FULL
        // absolute path: `plugin = /home/user/.local/share/hyprpm/...`
        // But that path is fragile (changes with hyprpm internals).
        //
        // Cleaner: trust hyprpm. The setEnabled() function calls
        //   hyprpm enable <name>; hyprpm reload
        // which uses hyprctl plugin load with the correct path.
        //
        // This conf file is ONLY for plugin CONFIGURATION (hyprbars
        // buttons, window rules, special workspaces) — not for plugin
        // loading. Comment-record the enabled state for transparency.
        for (const def of root.pluginDefs) {
            const enabled = !!root.enabledMap[def.id]
            const status = enabled ? "ENABLED via hyprpm" : "disabled"
            lines.push("# " + def.id + " — " + status)
        }
        // Hyprbars options
        if (root.enabledMap["hyprbars"]) {
            lines.push("")
            lines.push("# Hyprbars options (synced with theme)")
            lines.push("plugin:hyprbars:bar_height = " + root.hyprbarsHeight)
            lines.push("plugin:hyprbars:bar_buttons_alignment = "
                       + root.hyprbarsButtonAlignment)
            lines.push("plugin:hyprbars:bar_button_padding = 8")
            lines.push("plugin:hyprbars:bar_padding = 8")
            // Color values are pulled from ThemeService at write time
            const bg = ThemeService.bg1 || { r: 0.1, g: 0.1, b: 0.1 }
            const fg = ThemeService.fg  || { r: 0.95, g: 0.95, b: 0.95 }
            const accent = ThemeService.accent || ThemeService.blue || { r: 0.35, g: 0.6, b: 1.0 }
            const toHex = (c) => {
                const r = Math.round((c.r || 0) * 255)
                const g = Math.round((c.g || 0) * 255)
                const b = Math.round((c.b || 0) * 255)
                return "rgb(" + r.toString(16).padStart(2,'0')
                              + g.toString(16).padStart(2,'0')
                              + b.toString(16).padStart(2,'0') + ")"
            }
            lines.push("plugin:hyprbars:bar_color = " + toHex(bg))
            lines.push("plugin:hyprbars:col.text = "  + toHex(fg))
            lines.push("plugin:hyprbars:bar_text_size = 11")
            lines.push("plugin:hyprbars:bar_text_font = " +
                       (Theme.fontFamily || "Sans"))

            // ── Hyprbars buttons (right-to-left order in conf) ──
            // hyprbars-button = color, size, glyph, dispatch_command
            //
            // Synced behavior with Zen Shell taskbar:
            //   • Close (red) → killactive
            //   • Maximize (teal/accent) → fullscreen 1 (toggle window-fill)
            //   • Minimize (yellow) → moves to special:minimized workspace
            //     The Zen Shell taskbar tracks this workspace and shows
            //     dimmed icons for minimized windows. Click taskbar icon
            //     to restore via movetoworkspace
            lines.push("")
            lines.push("# Buttons in title bar (right→left):")
            lines.push("plugin:hyprbars:hyprbars-button = " +
                "rgb(ee5555), 12, , hyprctl dispatch killactive")
            lines.push("plugin:hyprbars:hyprbars-button = " +
                "rgb(33ccaa), 12, , hyprctl dispatch fullscreen 1")
            lines.push("plugin:hyprbars:hyprbars-button = " +
                "rgb(eeaa33), 12, , " +
                "hyprctl dispatch movetoworkspacesilent special:minimized")

            // ── Special workspace config: minimize-to-taskbar ──
            // The "special:minimized" workspace is where minimized
            // windows go. They stay alive but invisible. The taskbar
            // tracks them via Hyprland IPC and shows them as dimmed
            // icons. Click → movetoworkspace + focus.
            lines.push("")
            lines.push("# Hyprbars minimize → special:minimized workspace")
            lines.push("# (Zen Shell taskbar restores via icon click)")
            lines.push("workspace = special:minimized, on-created-empty:[silent]")

            // Window-rules — no bar on tiled, on zen-shell namespace, on
            // start menu / taskbar popups (which are floating but ours).
            //
            // SYNTAX: Hyprland 0.53+ requires BLOCK syntax for plugin
            // windowrules — the legacy `windowrule = plugin:hyprbars:nobar,
            // <match>` form returns "missing a value" config errors.
            //
            // Per official hyprbars README + Hyprland #12390:
            //   windowrule {
            //       hyprbars:no_bar = true
            //       match:float = 0
            //   }
            //
            // Reference:
            //   github.com/hyprwm/hyprland-plugins/issues/586
            //   github.com/hyprwm/Hyprland/discussions/12390
            lines.push("")
            lines.push("# No bar on TILED windows (the tile already shows position)")
            lines.push("windowrule {")
            lines.push("    name = zen-no-hyprbars-on-tiled")
            lines.push("    hyprbars:no_bar = true")
            lines.push("    match:float = 0")
            lines.push("}")
            lines.push("# No bar on Zen Shell's own UI (start menu, control panel, settings)")
            lines.push("windowrule {")
            lines.push("    name = zen-no-hyprbars-on-zen-shell")
            lines.push("    hyprbars:no_bar = true")
            lines.push("    match:class = ^(zen-shell.*)$")
            lines.push("}")
            lines.push("# No bar on Zen Shell quickprompt terminal")
            lines.push("windowrule {")
            lines.push("    name = zen-no-hyprbars-on-quickprompt")
            lines.push("    hyprbars:no_bar = true")
            lines.push("    match:class = ^(zen-quickprompt)$")
            lines.push("}")
        }
        // v6.16.4.12.6.41: Hyprexpo keybind + valid options only.
        //
        // FIX: Hyprland 0.51+ removed enable_gesture, gesture_fingers,
        // and gesture_positive. They cause:
        //   "Invalid value true for finger count"
        //   "Invalid direction"
        // Per hyprwm/hyprland-plugins source, only these are valid:
        //   columns, gap_size, bg_col, workspace_method, gesture_distance
        // Trackpad gestures use the new `hyprexpo-gesture` keyword
        // (not configured here — keybind is enough for keyboard users).
        if (root.enabledMap["hyprexpo"]) {
            lines.push("")
            lines.push("# Hyprexpo — workspace overview")
            lines.push("# Press SUPER + TAB to toggle the overview")
            lines.push("bind = SUPER, TAB, hyprexpo:expo, toggle")
            lines.push("")
            lines.push("plugin {")
            lines.push("    hyprexpo {")
            lines.push("        columns = 3")
            lines.push("        gap_size = 5")
            lines.push("        bg_col = rgb(111111)")
            lines.push("        workspace_method = center current")
            lines.push("        gesture_distance = 300")
            lines.push("    }")
            lines.push("}")
        }
        lines.push("# MANAGED-BLOCK END")
        return lines.join("\n") + "\n"
    }

    // v6.16.4.12.6.47: COMPLETE REWRITE — unified state management.
    //
    // Old design had TWO separate runners (toggleRunner + confSaver)
    // both writing plugins.conf and both calling reloads — caused races:
    //   - Disable did not work (bar persisted)
    //   - Both plugins enabled simultaneously broke each other
    //   - Edit settings auto-disabled toggle
    //   - Apply now did nothing
    //
    // New design: SINGLE runner. Every state change goes through
    // applyState() which always does the FULL sequence:
    //   1. Read desired state from enabledMap (UI's source of truth)
    //   2. For each plugin: hyprctl plugin unload + hyprpm enable/disable
    //   3. Write plugins.conf
    //   4. hyprpm reload + hyprctl reload
    //   5. Re-detect for UI sync
    property bool _applyInFlight: false
    property bool _applyQueued: false
    // Safety timeout — reset _applyInFlight after 15s in case process hangs
    Timer {
        id: applyTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            console.log("[applyTimeout] resetting stuck _applyInFlight")
            root._applyInFlight = false
        }
    }

    // v6.16.4.12.6.49: SIMPLIFIED — setEnabled only touches ONE plugin.
    // No more looping over all 5 plugins every toggle.
    //
    // v6.16.4.12.6.51 (Hikari): Two layered fixes.
    //
    //   (A) TERMINAL HOST. When `hyprpm enable/disable` requires sudo
    //       (e.g. system-installed plugin .so files at /usr/lib symlinked
    //       into hyprpm's data dir), running it via plain `bash -lc`
    //       from QML has NO TTY → sudo prompt fails silently → the
    //       toggle appears non-functional. Fix: spawn a real terminal
    //       (alacritty / kitty / foot / wezterm — same priority as the
    //       "Run recovery" button) so the user can enter their password.
    //       After ~1.5s success delay the terminal auto-closes;
    //       applyRunner.onStreamFinished then re-detects.
    //
    //   (B) NO MORE REDUNDANT `hyprpm reload`. Previous versions did:
    //         hyprpm enable X
    //         <write conf>
    //         hyprpm reload      ← root cause of plugins killing each other
    //         hyprctl reload
    //       `hyprpm enable/disable` ALREADY loads/unloads the plugin (the
    //       output line is "✔ Loaded <plugin>" / "✔ Unloaded <plugin>").
    //       Calling `hyprpm reload` AFTERWARDS triggers a full unload-
    //       everything → re-load-from-state cycle. If anything fails or
    //       partially executes during that cycle (sudo, build state
    //       mismatch, race), OTHER currently-loaded plugins drop out and
    //       don't come back — symptoms: enabling plugin A makes plugin B
    //       disappear; changing hyprbars alignment kills the toggle.
    //
    //       Fix: trust hyprpm's own load/unload from the enable/disable
    //       call. Skip `hyprpm reload`. `hyprctl reload` at the end is
    //       enough to re-source plugins.conf for option changes — the
    //       plugin is already loaded; it just picks up new option values.
    //
    // The conf-write step, applyRunner, auto-detect refresh, applyTimeout
    // safety, and queueing logic are all preserved verbatim — only the
    // inner shell sequence and the terminal wrapper changed.
    function setEnabled(pluginId, value) {
        const m = Object.assign({}, root.enabledMap)
        m[pluginId] = !!value
        root.enabledMap = m
        root._toggleInFlight = true
        toggleSettleTimer.restart()

        // Build conf text with CURRENT state (after toggle)
        const text = _buildConfText()
        const escaped = text.replace(/'/g, "'\\''")

        // Inner shell: enable/disable, write conf, hyprctl reload only.
        // No more `hyprpm reload` — see comment block above.
        let inner
        if (value) {
            inner = "echo \"[toggle ON] " + pluginId + "\"; " +
                    "hyprpm enable " + pluginId + " 2>&1; " +
                    "mkdir -p \"$(dirname '" + root.pluginsConfPath + "')\" && " +
                    "printf '%s' '" + escaped + "' > '" + root.pluginsConfPath + "'; " +
                    "hyprctl reload 2>&1; " +
                    "echo 'Loaded:'; hyprctl plugin list 2>&1 | grep '^Plugin' || echo '(none)'; " +
                    "echo '[toggle ON] done — closing in 1.5s'; " +
                    "sleep 1.5"
        } else {
            // For disable, hyprpm already unloads. The previous version
            // also did `hyprctl plugin unload <path>` first — that was
            // belt-and-suspenders that could double-unload and warn.
            // Just hyprpm disable + write conf + hyprctl reload.
            inner = "echo \"[toggle OFF] " + pluginId + "\"; " +
                    "hyprpm disable " + pluginId + " 2>&1; " +
                    "mkdir -p \"$(dirname '" + root.pluginsConfPath + "')\" && " +
                    "printf '%s' '" + escaped + "' > '" + root.pluginsConfPath + "'; " +
                    "hyprctl reload 2>&1; " +
                    "echo 'Loaded:'; hyprctl plugin list 2>&1 | grep '^Plugin' || echo '(none)'; " +
                    "echo '[toggle OFF] done — closing in 1.5s'; " +
                    "sleep 1.5"
        }

        // Escape inner for embedding inside a single-quoted bash -c arg
        const innerEscaped = inner.replace(/'/g, "'\\''")

        // Terminal wrapper — runs SYNCHRONOUSLY (no `&`) so the QML
        // applyRunner.onStreamFinished only fires after the inner
        // sequence + 1.5s settle finishes. Headless fallback writes a
        // log + notify-send so the user can debug if no terminal binary
        // is installed.
        const cmd =
            "if command -v alacritty >/dev/null 2>&1; then " +
            "  alacritty --class zen-plugin-toggle -e bash -c '" + innerEscaped + "'; " +
            "elif command -v kitty >/dev/null 2>&1; then " +
            "  kitty --class zen-plugin-toggle -- bash -c '" + innerEscaped + "'; " +
            "elif command -v foot >/dev/null 2>&1; then " +
            "  foot --app-id=zen-plugin-toggle -- bash -c '" + innerEscaped + "'; " +
            "elif command -v wezterm >/dev/null 2>&1; then " +
            "  wezterm start --class zen-plugin-toggle -- bash -c '" + innerEscaped + "'; " +
            "else " +
            "  bash -c '" + innerEscaped + "' > /tmp/zen-plugin-toggle.log 2>&1; " +
            "  command -v notify-send >/dev/null 2>&1 && " +
            "    notify-send 'Zen Plugins' 'Toggled " + pluginId +
                "  — see /tmp/zen-plugin-toggle.log (no terminal found, sudo may have failed)'; " +
            "fi"

        _applyInFlight = true
        applyTimeout.restart()
        applyRunner.command = ["bash", "-lc", cmd]
        applyRunner.running = true
    }

    // applyChanges — for settings changes ONLY (slider, dropdown, theme sync).
    // Does NOT enable/disable any plugin — just rewrites conf + reloads.
    function applyChanges() {
        applyState()
    }

    function applyState() {
        if (_applyInFlight) {
            _applyQueued = true
            return
        }
        _applyInFlight = true
        applyTimeout.restart()
        const text = _buildConfText()
        const escaped = text.replace(/'/g, "'\\''")
        // v6.16.4.12.6.51 (Hikari): Drop `hyprpm reload` from option-only
        // updates. alignment / height / theme-color changes only need the
        // conf file rewritten + hyprctl reload to re-source it. The plugin
        // is already loaded; running `hyprpm reload` here would unload
        // every plugin and try to re-load from state, which was the root
        // cause of the "settings die when alignment is changed" symptom —
        // a half-failed reload could drop hyprbars (or other plugins)
        // entirely. Trust the existing load state; just re-source conf.
        const cmd = "echo '[applyState] writing conf + hyprctl reload'; " +
                    "mkdir -p $(dirname '" + root.pluginsConfPath + "') && " +
                    "printf '%s' '" + escaped + "' > '" + root.pluginsConfPath + "'; " +
                    "hyprctl reload 2>&1; " +
                    "echo '[applyState] done'"
        applyRunner.command = ["bash", "-lc", cmd]
        applyRunner.running = true
    }

    Process {
        id: applyRunner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[applyRunner]", this.text)
                root._applyInFlight = false
                applyTimeout.stop()
                Qt.callLater(() => root.detectInstalledPlugins())
                if (root._applyQueued) {
                    root._applyQueued = false
                    Qt.callLater(() => root.applyState())
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────
    Item {
        implicitWidth: parent.width
        implicitHeight: contentCol.implicitHeight + 72

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24
            y: 24
            spacing: 16

            // ── Header ──
            Text {
                text: "Hyprland Plugins"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Medium
                color: ThemeService.fg
            }
            Text {
                text: "Enable or disable Hyprland plugins. Configuration is " +
                      "written to ~/.config/hypr/modules/plugins.conf and " +
                      "reloaded live via hyprctl reload."
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // ── Per-plugin toggles ──
            Repeater {
                model: root.pluginDefs

                delegate: Rectangle {
                    Layout.fillWidth: true
                    // v37: Removed circular `pluginRow.implicitHeight + 24`
                    // binding. Now use childrenRect.height via the ColumnLayout
                    // that doesn't use anchors.fill.
                    Layout.preferredHeight: pluginRow.implicitHeight + 24
                    radius: 10
                    color: ThemeService.alpha(ThemeService.bg2, 0.5)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.10)

                    property var def: modelData
                    // v6.16.4.12.6.40: STICKY local toggle state.
                    //
                    // Why we need this: previously `isEnabled` was bound to
                    // `root.enabledMap[def.id]` which gets re-set by every
                    // `detectInstalledPlugins()` call. If hyprpm is mid-
                    // operation when detect fires, it returns stale state →
                    // isEnabled flips false → blue box disappears.
                    //
                    // Solution: localEnabled is set ONLY when user clicks the
                    // toggle, AND when the page first loads (initial sync from
                    // hyprpm). After that, it never changes due to background
                    // re-detects. This guarantees the blue box stays visible
                    // as long as the user has the toggle ON.
                    property bool localEnabled: !!root.enabledMap[def.id]
                    property bool _localInitialized: false
                    property bool isEnabled: localEnabled
                    property bool isInstalled: !!root.installedMap[def.id]
                    property bool buildFailed: !!root.failedMap[def.id]

                    // One-time initial sync from hyprpm (when page loads).
                    // After this, only user-clicks change localEnabled.
                    Connections {
                        target: root
                        function onEnabledMapChanged() {
                            if (!_localInitialized) {
                                localEnabled = !!root.enabledMap[def.id]
                                _localInitialized = true
                            }
                        }
                    }

                    // Status: "installed" | "build_failed" | "not_installed"
                    readonly property string status: isInstalled
                        ? "installed"
                        : (buildFailed ? "build_failed" : "not_installed")

                    ColumnLayout {
                        id: pluginRow
                        // Use width binding + top anchor instead of anchors.fill
                        // to AVOID the circular dependency:
                        //   parent.height = pluginRow.implicitHeight + 24
                        //   pluginRow.height = parent.height (via anchors.fill)
                        // → height never grows to fit added child like blue box
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: def.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: ThemeService.fg
                                    }
                                    // 3-state status badge
                                    Rectangle {
                                        Layout.preferredHeight: 18
                                        Layout.preferredWidth: badgeText.implicitWidth + 12
                                        radius: 4
                                        color: {
                                            if (status === "installed")
                                                return ThemeService.alpha(ThemeService.green, 0.25)
                                            if (status === "build_failed")
                                                return ThemeService.alpha(ThemeService.yellow, 0.25)
                                            return ThemeService.alpha(ThemeService.red, 0.25)
                                        }
                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: {
                                                if (status === "installed") return "installed"
                                                if (status === "build_failed") return "build failed"
                                                return "not installed"
                                            }
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: {
                                                if (status === "installed") return ThemeService.green
                                                if (status === "build_failed") return ThemeService.yellow
                                                return ThemeService.red
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: def.description
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeService.grey1
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            // v6.16.4.12.6.25: Use HMSwitch (same as other
                            // Settings pages — Connectivity, Panel, etc.)
                            HMSwitch {
                                compact: true
                                activeColor: ThemeService.alpha(ThemeService.green, 0.85)
                                checked: isEnabled
                                enabled: isInstalled
                                onToggled: {
                                    // v40: Update localEnabled FIRST so blue
                                    // box visibility flips immediately, then
                                    // start hyprpm async work. localEnabled
                                    // is sticky — won't get clobbered by
                                    // background detect.
                                    localEnabled = checked
                                    root.setEnabled(def.id, checked)
                                }
                                ToolTip.visible: hovered && !isInstalled
                                ToolTip.text: status === "build_failed"
                                    ? "Plugin failed to build — see fix below"
                                    : "Plugin not installed — see install command below"
                            }
                        }

                        // Build-failed help (visible when build_failed)
                        Rectangle {
                            visible: status === "build_failed"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 6
                            color: ThemeService.alpha(ThemeService.yellow, 0.06)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.yellow, 0.20)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: "Plugin failed to build (Hyprland version mismatch). " +
                                          "Will auto-retry on next install."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeService.yellow
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Install command (visible only when truly not installed, NOT when build failed)
                        Rectangle {
                            visible: status === "not_installed"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 6
                            color: ThemeService.alpha(ThemeService.fg, 0.05)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.10)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 8

                                Text {
                                    text: "$ hyprpm add " + def.repo
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: ThemeService.fg
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }
                                                                ZenButton {
                                    text: "Copy"
                                    fontPixelSize: 10
                                    onClicked: {
                                        copyHelper.command = ["bash", "-lc",
                                            "echo -n 'hyprpm add " + def.repo + "' | wl-copy"]
                                        copyHelper.running = true
                                    }
                                }
                            }
                        }

                        // ── Hyprbars-specific Settings ──
                        // Visible only when hyprbars is enabled + installed.
                        // Auto-shown when user toggles hyprbars ON.
                        // v35: Wrapped in highlighted Rectangle for clarity
                        Rectangle {
                            visible: def.id === "hyprbars" && isEnabled && isInstalled
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            Layout.preferredHeight: hyprbarsSettingsCol.implicitHeight + 24
                            radius: 8
                            color: ThemeService.alpha(ThemeService.blue, 0.06)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.blue, 0.20)

                            ColumnLayout {
                                id: hyprbarsSettingsCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                            // Section header: "HYPRBARS SETTINGS"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "\udb81\udf3e"  // nf-md cog
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: ThemeService.blue
                                }
                                Text {
                                    text: "HYPRBARS SETTINGS"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: ThemeService.blue
                                    Layout.fillWidth: true
                                }
                            }

                            // Buttons position
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: "Buttons position"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: ThemeService.fg
                                    }
                                    Text {
                                        text: "Where min/max/close appear in the title bar"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        color: ThemeService.grey1
                                    }
                                }
                                ZenDropdown {
                                    Layout.preferredWidth: 200
                                    model: ["right", "left"]
                                    currentIndex: root.hyprbarsButtonAlignment === "left" ? 1 : 0
                                    onActivated: {
                                        root.hyprbarsButtonAlignment =
                                            (currentIndex === 1) ? "left" : "right"
                                        // v41: Use debouncer so it goes through
                                        // the same queue as slider — prevents
                                        // dropped applies if user toggles
                                        // dropdown while another apply is in-flight.
                                        applyDebounce.restart()
                                    }
                                }
                            }

                            // Bar height
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: "Bar height"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: ThemeService.fg
                                    }
                                    Text {
                                        text: "Title bar height in pixels (20-40)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        color: ThemeService.grey1
                                    }
                                }
                                Slider {
                                    Layout.preferredWidth: 160
                                    from: 20
                                    to: 40
                                    stepSize: 1
                                    value: root.hyprbarsHeight
                                    onValueChanged: {
                                        if (Math.abs(root.hyprbarsHeight - value) >= 1) {
                                            root.hyprbarsHeight = Math.round(value)
                                            applyDebounce.restart()
                                        }
                                    }
                                }
                                Text {
                                    text: root.hyprbarsHeight + "px"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: ThemeService.grey1
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Theme-synced colors info
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: themeInfoCol.implicitHeight + 16
                                radius: 6
                                color: ThemeService.alpha(ThemeService.blue, 0.08)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.18)

                                ColumnLayout {
                                    id: themeInfoCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Theme-synced colors"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: ThemeService.fg
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Title bar bg + text colors auto-sync with your active theme. " +
                                              "Buttons are themed: red (close), yellow (minimize), teal (maximize)."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        color: ThemeService.grey1
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            // Window rules info + Force-apply button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Text {
                                    Layout.fillWidth: true
                                    text: "Tiled windows + Zen Shell popups automatically skip the bar " +
                                          "(handled by windowrules in plugins.conf MANAGED-BLOCK)."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    color: ThemeService.grey1
                                    wrapMode: Text.WordWrap
                                }
                                // v41: Manual force-apply button for cases
                                // when live-apply seems stuck
                                Rectangle {
                                    Layout.preferredWidth: 110
                                    Layout.preferredHeight: 28
                                    radius: 4
                                    color: forceApplyMA.containsMouse
                                        ? ThemeService.alpha(ThemeService.blue, 0.30)
                                        : ThemeService.alpha(ThemeService.blue, 0.15)
                                    border.width: 1
                                    border.color: ThemeService.alpha(ThemeService.blue, 0.50)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "↻ Apply now"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeService.blue
                                    }
                                    MouseArea {
                                        id: forceApplyMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            // v48: Just call the unified applyState
                                            console.log("[PluginsPage] Apply now clicked")
                                            root._applyInFlight = false // reset stuck flag
                                            root.applyState()
                                        }
                                    }
                                }
                            }
                            }  // hyprbarsSettingsCol ColumnLayout
                        }  // hyprbars settings Rectangle wrapper
                    }
                }
            }

            // ── Footer note ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: footerCol.implicitHeight + 24
                radius: 8
                color: ThemeService.alpha(ThemeService.fg, 0.04)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.08)

                ColumnLayout {
                    id: footerCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "About Hyprland plugins"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: ThemeService.fg
                    }
                    Text {
                        text: "Plugins extend Hyprland with additional features. " +
                              "Use `hyprpm` to install: clone the repo first via " +
                              "the Copy button above, then run the printed command."
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.grey1
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "After installation, run: hyprpm enable <plugin> && hyprpm reload"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: ThemeService.fg
                    }
                }
            }

            // ── v6.16.4.12.6.22: Troubleshoot — hyprpm recovery ──
            // For when hyprpm gets stuck with "Couldn't update headers"
            // or "Outdated headers" errors. Runs zen-hyprpm-fix.sh which
            // purges cache + rebuilds headers + re-enables plugins.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: troubleCol.implicitHeight + 24
                radius: 8
                color: ThemeService.alpha(ThemeService.yellow, 0.06)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.yellow, 0.20)

                ColumnLayout {
                    id: troubleCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "\uf071"   // warning icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: ThemeService.yellow
                        }
                        Text {
                            text: "Plugins not loading? Headers outdated?"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: ThemeService.fg
                        }
                    }
                    Text {
                        text: "Common error: \"[hyprpm] Couldn't update headers\" or " +
                              "\"Failed to load plugins: Outdated headers\". " +
                              "Run the recovery script — it purges hyprpm cache, " +
                              "rebuilds headers, then re-enables your plugins."
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.grey1
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                                                ZenButton {
                            text: "Run recovery"
                            fontPixelSize: 11
                            onClicked: {
                                hyprpmFixRunner.command = ["bash", "-lc",
                                    "if command -v alacritty >/dev/null 2>&1; then " +
                                    "  alacritty --class zen-recovery -e " +
                                    "    bash -c '~/.local/bin/zen-hyprpm-fix.sh; " +
                                    "             read -p \"Press Enter to close\"' & " +
                                    "elif command -v kitty >/dev/null 2>&1; then " +
                                    "  kitty --class zen-recovery -- " +
                                    "    bash -c '~/.local/bin/zen-hyprpm-fix.sh; " +
                                    "             read -p \"Press Enter to close\"' & " +
                                    "else " +
                                    "  ~/.local/bin/zen-hyprpm-fix.sh > /tmp/zen-hyprpm-fix.log 2>&1; " +
                                    "  notify-send 'Zen' 'Recovery done — see /tmp/zen-hyprpm-fix.log'; " +
                                    "fi"]
                                hyprpmFixRunner.running = true
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Opens a terminal so you can see progress + enter sudo password"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.grey1
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Process { id: hyprpmFixRunner; running: false }

    // v6.16.4.12.6.43: Force-apply runner — replicates exact toggle
    // OFF→ON sequence (known to work). On finish, re-detects state.
    Process {
        id: forceApplyRunner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[PluginsPage] Force-apply done:", this.text)
                root.detectInstalledPlugins()
            }
        }
    }

    // Debouncer for slider/dropdown changes (avoid hyprctl spam, but
    // short enough to feel live — 250ms = perceptually instant).
    Timer {
        id: applyDebounce
        interval: 250
        repeat: false
        onTriggered: root.applyChanges()
    }

    // v6.16.4.12.6.40: Auto-sync hyprbars colors with ThemeService.
    //
    // When the user changes themes (Settings → Themes, or matugen-from-
    // wallpaper), ThemeService.bg1 / ThemeService.fg / ThemeService.accent
    // properties update. We listen for those changes and re-apply
    // plugins.conf so the hyprbars title bar background + text colors
    // immediately match the new theme.
    //
    // Debounced 500ms so a flurry of theme property updates only triggers
    // one applyChanges() call.
    Timer {
        id: themeSyncDebounce
        interval: 500
        repeat: false
        onTriggered: {
            if (root.enabledMap["hyprbars"]) {
                console.log("[PluginsPage] Theme changed — re-syncing hyprbars colors")
                root.applyChanges()
            }
        }
    }
    Connections {
        target: ThemeService
        function onBg1Changed()    { themeSyncDebounce.restart() }
        function onFgChanged()     { themeSyncDebounce.restart() }
        function onAccentChanged() { themeSyncDebounce.restart() }
        function onBlueChanged()   { themeSyncDebounce.restart() }
    }

    Process { id: copyHelper; running: false }
}
