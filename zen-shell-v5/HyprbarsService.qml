pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * HyprbarsService v7.0.0-beta.1-hf52 — Karui (軽い)
 *
 * Manages the hyprbars Hyprland plugin:
 *   https://github.com/hyprwm/hyprland-plugins/tree/main/hyprbars
 *
 * What it does:
 *
 *   1. INSTALL  — `hyprpm add https://github.com/hyprwm/hyprland-plugins`
 *      (idempotent: detects if already added)
 *
 *   2. ENABLE  — `hyprpm enable hyprbars` + `hyprpm reload`
 *
 *   3. DISABLE — `hyprpm disable hyprbars` + `hyprpm reload`
 *
 *   4. UPDATE  — `hyprpm update` (refresh plugin from upstream)
 *
 *   5. WRITE CONFIG — generates a `plugin { hyprbars { ... } }` block
 *      to ~/.config/hypr/zen-hyprbars.conf based on ThemeService colors
 *      + user preferences (button side, button visibility). Hyprland's
 *      main config sources this file via:
 *
 *          source = ~/.config/hypr/zen-hyprbars.conf
 *
 *      The shell automatically appends that source line on first
 *      enable. Re-runs whenever theme changes, so colors stay in
 *      sync with Zen Shell theme.
 *
 *   6. WATCH THEME — Connections to ThemeService.themeChanged →
 *      re-writes the config file. Hyprland picks up changes via
 *      its file-watcher (or via hyprctl reload).
 *
 * Properties exposed to Settings UI:
 *   - enabled              (bool) — plugin loaded
 *   - installed            (bool) — plugin downloaded but not necessarily enabled
 *   - buttonSide           ("left" | "right") — macOS vs Windows style
 *   - showMinimize         (bool) — show minimize button
 *   - showMaximize         (bool) — show maximize button
 *   - showClose            (bool) — show close button (rarely OFF)
 *   - barHeight            (int) — bar height in px
 *   - barTextSize          (int) — title text size
 *   - barTextFont          (str) — font family
 *   - syncWithTheme        (bool) — auto-update on theme change
 *
 * Persisted to ~/.config/quickshell/zen-shell/hyprbars.json
 *
 * IMPORTANT: hyprbars is a Hyprland plugin (loaded INTO Hyprland
 * itself via hyprpm). It is NOT a Quickshell component. We just
 * orchestrate it from here. Plugin install requires the Hyprland
 * devel headers + cpio/cmake/git/meson/gcc — these are usually
 * already installed on CachyOS/Arch ricer setups but the install
 * step will surface a clear error if not.
 *
 * Hyprbars button alignment:
 *
 *   Default is right (Windows style). Per the upstream README and
 *   forum thread (forum.hypr.land/t/missing-hyprbars-buttons/1106)
 *   the alignment is controlled by `bar_buttons_alignment = left`
 *   inside the plugin block. We toggle this based on `buttonSide`.
 *
 *   When left-aligned, buttons render in left-to-right order. When
 *   right-aligned, they render right-to-left (R→L = close, max, min
 *   from outer edge). The `hyprbars-button = ...` lines we emit are
 *   ordered so the macOS layout (close-min-max from left) and the
 *   Windows layout (min-max-close from right) both feel natural.
 */
Singleton {
    id: root

    // ────────────────────────────────────────────────────────────
    // STATE
    // ────────────────────────────────────────────────────────────

    property bool enabled: false
    property bool installed: false
    property string buttonSide: "right"     // "left" | "right"
    property bool showMinimize: true
    property bool showMaximize: true
    property bool showClose: true
    property int barHeight: 24
    property int barTextSize: 11
    property string barTextFont: "Adwaita Sans"
    property bool barBlur: true
    property bool syncWithTheme: true
    property bool barPartOfWindow: true     // shadows around bar too
    property string lastError: ""

    // v7.0.0-beta.1-hf53 — floating-only rule.
    //
    // v7.0.0-beta.1-hf57: changed default to FALSE.
    //
    // The hyprbars windowrule effects (hyprbars:no_bar) only exist
    // when the plugin is loaded and has registered them. If we emit
    // these rules while the plugin isn't loaded, Hyprland errors out
    // with "config option <windowrule:hyprbars:no_bar> does not exist".
    //
    // Default = false means a fresh install emits a config that's
    // pure plugin block — no windowrules — which always parses
    // cleanly regardless of plugin load state. User can enable
    // floating-only from the Settings UI once they verify the
    // plugin is loaded via "Check status" button.
    property bool floatingOnly: false

    // v7.0.0-beta.1-hf53 — last status message for UI display.
    // Updated by installProc/enableProc stdout. UI shows this in
    // the Status section so user sees what's happening during the
    // 30-60sec plugin compile.
    property string statusMessage: ""
    property bool busy: false

    // v7.0.0-beta.1-hf57 — plugin loading verification.
    //
    // Track whether hyprbars is actually loaded in the running
    // Hyprland instance. The windowrule effects (hyprbars:no_bar,
    // etc.) ONLY exist when the plugin has registered them at runtime.
    // If we emit those windowrules while the plugin isn't loaded,
    // Hyprland's parser errors out with "config option does not exist"
    // — which is the bug user reported in hf56.
    //
    // Set to true when `hyprctl plugin list` confirms hyprbars is
    // active. Set to false on disable or when verification fails.
    property bool pluginLoaded: false

    // v7.0.0-beta.1-hf59 — auto force-load tracking.
    //
    // hf58 added a Force load button that user clicks when hyprpm
    // reload didn't actually inject the .so into Hyprland (upstream
    // bug — manual `hyprctl plugin load <path>` works regardless).
    //
    // Problem: every time Hyprland reloads its config (theme change,
    // monitor hotplug, etc.), it tears down + reloads plugins via
    // the same broken hyprpm path. So the plugin DROPS again and
    // user has to re-click Force load. Painful.
    //
    // Fix: detect this state automatically and auto-trigger the
    // manual load — same code path as the button, just fired
    // automatically when:
    //   - shell boots and enabled=true but plugin not loaded
    //   - writeConfig fires hyprctl reload and plugin drops
    //   - watchdog timer notices plugin missing (every 30s)
    //
    // Bounded to prevent loop spam — max attempts per "session"
    // (session = since last user-triggered install/enable). Reset
    // on any user action so retries restart fresh.
    property int _autoLoadAttemptCount: 0
    readonly property int _autoLoadMaxAttempts: 3
    property bool autoLoadEnabled: true       // user-toggleable via Settings (default ON)
    property bool _autoLoadInProgress: false  // suppresses concurrent attempts

    // v7.0.0-beta.1-hf62 — heavy recovery flag.
    //
    // Modern hyprpm builds plugin .so files into $XDG_RUNTIME_DIR/hyprpm
    // (tmpfs). After `hyprpm reload` finishes loading the enabled
    // plugins, the build dir gets cleaned up — .sos disappear from
    // disk. Plugins that were successfully loaded keep running
    // (mmap'd into Hyprland), but plugins that WEREN'T loaded (e.g.
    // hyprbars when not in hyprpm's enabled list) leave nothing on
    // disk for us to manually inject.
    //
    // So when our lightweight auto-load (`hyprctl plugin load <so>`)
    // can't find a .so anywhere, the only path forward is to ASK
    // hyprpm to rebuild+reload, which atomically:
    //   1. Recompiles the .so into runtime dir
    //   2. Runs `hyprctl plugin load` on enabled plugins
    //   3. Cleans up the build dir
    //
    // We exploit that ~5-10s window where the .so exists on disk by
    // running our own `hyprctl plugin load` BEFORE the cleanup. The
    // entire sequence (enable + reload + find + load) runs in one
    // atomic bash command so timing is tight.
    //
    // Heavy recovery is expensive (rebuilds .so, ~10s blocking),
    // so we run it MAX ONCE per shell session. After that single
    // attempt either succeeds or surfaces a permanent error to UI.
    property bool _heavyRecoveryAttempted: false
    property bool _heavyRecoveryInProgress: false

    // v7.0.0-beta.1-hf60 — surface the actual `hyprctl plugin load`
    // error message + the .so path state so user knows WHY auto-load
    // failed. Previously these went to console.warn only — invisible
    // to anyone who isn't tailing journalctl.
    property string lastLoadError: ""         // stderr from hyprctl plugin load (or empty)
    property string soPath: ""                // path to detected hyprbars*.so (or "" if missing)
    property bool soExists: false             // convenience flag for UI bindings

    // v7.0.0-beta.1-hf60 — mimic visibility override.
    //
    // The HyprbarsMimic is an in-shell faux title bar that renders on
    // Zen Shell's layer-shell popups (ControlPanel, ZenSettings) since
    // the real hyprbars plugin can't paint on layer-shell surfaces
    // (architectural limit of Hyprland — only XDG/X11 toplevels get
    // plugin bars).
    //
    // hf60 default: hide mimic when real plugin isn't loaded. User
    // sees consistent state — bars everywhere or bars nowhere. Set
    // showMimicFallback=true to keep the legacy hf53 behavior where
    // mimic shows whenever `enabled=true` regardless of load state.
    property bool showMimicFallback: false

    // Internal: last config text written to disk (to skip re-write if no change)
    property string _lastWritten: ""

    readonly property string configDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string configPath: configDir + "/zen-hyprbars.conf"
    readonly property string mainHyprlandConf: configDir + "/hyprland.conf"
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/zen-shell"
    readonly property string statePath: stateDir + "/hyprbars.json"

    // v7.0.0-beta.1-hf57 — portable source line using ~/ (tilde).
    //
    // Previously hardcoded as `source = /home/paul/.config/hypr/...`
    // which was BAD because:
    //   1. Not portable across machines/users
    //   2. Doesn't match the style of the user's other source lines
    //      which all use `~/.config/hypr/...`
    //
    // Hyprland natively expands ~/ to $HOME via hyprlang. The user's
    // hyprland.conf already uses this pattern throughout.
    readonly property string sourceLineTilde: "source = ~/.config/hypr/zen-hyprbars.conf"
    readonly property string sourceLineAbsolute: "source = " + configPath

    // ────────────────────────────────────────────────────────────
    // STATE PERSISTENCE
    // ────────────────────────────────────────────────────────────

    Process {
        id: loadStateProc
        running: false
        command: ["bash", "-c", "cat '" + root.statePath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (typeof j.enabled === "boolean")        root.enabled = j.enabled
                    if (typeof j.installed === "boolean")      root.installed = j.installed
                    if (typeof j.buttonSide === "string")      root.buttonSide = j.buttonSide
                    if (typeof j.showMinimize === "boolean")   root.showMinimize = j.showMinimize
                    if (typeof j.showMaximize === "boolean")   root.showMaximize = j.showMaximize
                    if (typeof j.showClose === "boolean")      root.showClose = j.showClose
                    if (typeof j.barHeight === "number")       root.barHeight = j.barHeight
                    if (typeof j.barTextSize === "number")     root.barTextSize = j.barTextSize
                    if (typeof j.barTextFont === "string")     root.barTextFont = j.barTextFont
                    if (typeof j.barBlur === "boolean")        root.barBlur = j.barBlur
                    if (typeof j.syncWithTheme === "boolean")  root.syncWithTheme = j.syncWithTheme
                    if (typeof j.barPartOfWindow === "boolean") root.barPartOfWindow = j.barPartOfWindow
                    if (typeof j.floatingOnly === "boolean")   root.floatingOnly = j.floatingOnly
                    if (typeof j.autoLoadEnabled === "boolean") root.autoLoadEnabled = j.autoLoadEnabled
                    if (typeof j.showMimicFallback === "boolean") root.showMimicFallback = j.showMimicFallback
                } catch (e) {
                    console.warn("[Hyprbars] state parse:", e)
                }
            }
        }
    }

    Process { id: saveStateProc; running: false }
    Timer {
        id: saveDebounce
        interval: 400
        repeat: false
        onTriggered: {
            const obj = {
                enabled: root.enabled,
                installed: root.installed,
                buttonSide: root.buttonSide,
                showMinimize: root.showMinimize,
                showMaximize: root.showMaximize,
                showClose: root.showClose,
                barHeight: root.barHeight,
                barTextSize: root.barTextSize,
                barTextFont: root.barTextFont,
                barBlur: root.barBlur,
                syncWithTheme: root.syncWithTheme,
                barPartOfWindow: root.barPartOfWindow,
                floatingOnly: root.floatingOnly,
                autoLoadEnabled: root.autoLoadEnabled,
                showMimicFallback: root.showMimicFallback
            }
            saveStateProc.command = ["bash", "-c",
                "mkdir -p '" + root.stateDir + "' && cat > '"
                + root.statePath + "' << 'ZSEOF'\n"
                + JSON.stringify(obj, null, 2) + "\nZSEOF"]
            saveStateProc.running = true
        }
    }

    // Auto-save on any change
    onEnabledChanged: saveDebounce.restart()
    onInstalledChanged: saveDebounce.restart()
    onButtonSideChanged: { saveDebounce.restart(); writeConfig() }
    onShowMinimizeChanged: { saveDebounce.restart(); writeConfig() }
    onShowMaximizeChanged: { saveDebounce.restart(); writeConfig() }
    onShowCloseChanged: { saveDebounce.restart(); writeConfig() }
    onBarHeightChanged: { saveDebounce.restart(); writeConfig() }
    onBarTextSizeChanged: { saveDebounce.restart(); writeConfig() }
    onBarTextFontChanged: { saveDebounce.restart(); writeConfig() }
    onBarBlurChanged: { saveDebounce.restart(); writeConfig() }
    onBarPartOfWindowChanged: { saveDebounce.restart(); writeConfig() }
    onFloatingOnlyChanged: { saveDebounce.restart(); writeConfig() }
    onSyncWithThemeChanged: { saveDebounce.restart(); writeConfig() }
    onAutoLoadEnabledChanged: saveDebounce.restart()
    onShowMimicFallbackChanged: saveDebounce.restart()

    // ────────────────────────────────────────────────────────────
    // THEME SYNC
    // ────────────────────────────────────────────────────────────

    Connections {
        target: (typeof ThemeService !== "undefined") ? ThemeService : null
        ignoreUnknownSignals: true
        function onThemeChanged() {
            if (root.syncWithTheme) {
                root.writeConfig()
            }
        }
    }

    // ────────────────────────────────────────────────────────────
    // CONFIG GENERATION
    // ────────────────────────────────────────────────────────────
    //
    // Generates the hyprbars plugin config block based on current
    // theme + user prefs. Color values come from ThemeService when
    // syncWithTheme is on; otherwise we use sensible defaults.

    function _hexToRgbCall(hex) {
        // Hyprland config color format: rgb(RRGGBB) — no alpha here,
        // we use rgba(RRGGBBAA) when we need alpha. Strip leading #.
        if (!hex || typeof hex !== "string") return "rgb(282828)"
        let s = hex.replace("#", "")
        if (s.length === 8) {
            // hex with alpha — keep as rgba
            return "rgba(" + s + ")"
        }
        if (s.length === 6) {
            return "rgb(" + s + ")"
        }
        return "rgb(282828)"
    }

    function _colorOrDefault(svcProp, fallback) {
        try {
            if (typeof ThemeService !== "undefined"
                && ThemeService[svcProp]
                && root.syncWithTheme) {
                const c = ThemeService[svcProp]
                // ThemeService colors are Qt color objects;
                // convert to hex string then to hypr format
                const hex = "" + c
                return root._hexToRgbCall(hex)
            }
        } catch (e) { /* fall through */ }
        return fallback
    }

    function buildConfigText() {
        const barColor   = root._colorOrDefault("bg1", "rgb(282828)")
        const textColor  = root._colorOrDefault("fg",  "rgb(ebdbb2)")
        const closeColor = root._colorOrDefault("red",    "rgb(fb4934)")
        const maxColor   = root._colorOrDefault("yellow", "rgb(fabd2f)")
        const minColor   = root._colorOrDefault("green",  "rgb(b8bb26)")
        const fgOnBtn    = root._colorOrDefault("bg0", "rgb(1d2021)")

        // Build button lines. Hyprbars reads them in declared order
        // and lays them out per `bar_buttons_alignment`:
        //   - right alignment (default): renders R → L (last button = outermost right)
        //   - left alignment: renders L → R (first button = outermost left)
        //
        // We want macOS-style on left = close, minimize, maximize (close at far left)
        // We want Windows-style on right = minimize, maximize, close (close at far right)
        //
        // So:
        //   left  → declare: close, min, max  (close ends up outermost left)
        //   right → declare: min, max, close  (declared order, close outermost right)
        //
        // Button glyphs:
        //   hf64 — removed glyphs (space char). Broke clickability.
        //   hf66 — restored glyphs for real plugin clickability, but
        //   made INVISIBLE by setting fgColor = button bgColor. The
        //   hyprbars plugin needs a real glyph for the hit-test area
        //   to be large enough to click. Visual result: pure color
        //   dots (icon renders same color as background = invisible).
        //
        // Format: hyprbars-button = color, size, icon, on-click[, fgcolor]

        const closeBtn = "hyprbars-button = "  + closeColor + ", " + root.barTextSize + ", "
                       + "\uf00d, hyprctl dispatch killactive, " + closeColor
        const maxBtn   = "hyprbars-button = "  + maxColor   + ", " + root.barTextSize + ", "
                       + "\uf2d0, hyprctl dispatch fullscreen 1, " + maxColor
        const minBtn   = "hyprbars-button = "  + minColor   + ", " + root.barTextSize + ", "
                       + "_, hyprctl dispatch movetoworkspacesilent special:minimized, " + minColor

        const buttonLines = []
        if (root.buttonSide === "left") {
            // declare close first so it ends up outermost-left
            if (root.showClose)    buttonLines.push(closeBtn)
            if (root.showMinimize) buttonLines.push(minBtn)
            if (root.showMaximize) buttonLines.push(maxBtn)
        } else {
            // right (Windows style): min, max, close — close outermost-right
            if (root.showMinimize) buttonLines.push(minBtn)
            if (root.showMaximize) buttonLines.push(maxBtn)
            if (root.showClose)    buttonLines.push(closeBtn)
        }

        const lines = []
        lines.push("# Auto-generated by Zen Shell HyprbarsService — do not edit by hand")
        lines.push("# Regenerated on every theme change while syncWithTheme is enabled.")
        lines.push("# Toggle via Settings → Appearance → Hyprbars in Zen Shell.")
        lines.push("")
        lines.push("plugin {")
        lines.push("    hyprbars {")
        lines.push("        bar_height = " + root.barHeight)
        lines.push("        bar_color = " + barColor)
        lines.push("        col.text = " + textColor)
        lines.push("        bar_text_size = " + root.barTextSize)
        lines.push("        bar_text_font = " + root.barTextFont)
        lines.push("        bar_text_align = " + (root.buttonSide === "left" ? "right" : "left"))
        lines.push("        bar_buttons_alignment = " + root.buttonSide)
        lines.push("        bar_blur = " + (root.barBlur ? "true" : "false"))
        lines.push("        bar_part_of_window = " + (root.barPartOfWindow ? "true" : "false"))
        lines.push("        bar_precedence_over_border = true")
        lines.push("        bar_padding = 10")
        lines.push("        bar_button_padding = 5")
        lines.push("        on_double_click = hyprctl dispatch fullscreen 1")
        lines.push("")
        for (const b of buttonLines) lines.push("        " + b)
        lines.push("    }")
        lines.push("}")
        lines.push("")

        // v7.0.0-beta.1-hf57 — gate windowrules on pluginLoaded.
        //
        // The hyprbars windowrule effects (hyprbars:no_bar) only
        // exist after the plugin registers them at runtime. Emitting
        // them while the plugin isn't loaded causes Hyprland's parser
        // to error out with "config option does not exist".
        //
        // So we only emit the windowrules when:
        //   1. floatingOnly toggle is ON (user opted in), AND
        //   2. pluginLoaded is verified true (plugin actually running)
        //
        // If floatingOnly is on but plugin isn't loaded yet, we emit
        // a helpful comment so the user knows why bars appear on all
        // windows (not just floating ones) — they need to verify
        // v7.0.0-beta.1-hf95.18 — the Zen quick terminal (Super+Shift+T)
        // never wants a title bar. Emitted only when the plugin is loaded
        // (same gate as below), using the proven block syntax, so it can't
        // cause a parse error when hyprbars is off. This is where any
        // per-window no_bar belongs — NOT in the always-parsed static
        // hyprland-layer-rules.conf.
        if (root.pluginLoaded) {
            lines.push("# hf95.18 — no bar on the Zen quick terminal pop-up")
            lines.push("windowrule {")
            lines.push("    name = zen-hyprbars-no-bar-quickterm")
            lines.push("    hyprbars:no_bar = true")
            lines.push("    match:class = ^(zen-quickterm)$")
            lines.push("}")
            lines.push("")
        }

        // plugin install first.
        if (root.floatingOnly && root.pluginLoaded) {
            lines.push("# v7.0.0-beta.1-hf57 — floating-only rules (block syntax)")
            lines.push("# Bars appear only on floating, non-fullscreen windows.")
            lines.push("# Only emitted when plugin is verified loaded —")
            lines.push("# prevents config parse errors when plugin isn't active yet.")
            lines.push("windowrule {")
            lines.push("    name = zen-hyprbars-no-bar-on-tiled")
            lines.push("    hyprbars:no_bar = true")
            lines.push("    match:float = 0")
            lines.push("}")
            lines.push("windowrule {")
            lines.push("    name = zen-hyprbars-no-bar-on-fullscreen")
            lines.push("    hyprbars:no_bar = true")
            lines.push("    match:fullscreen = 1")
            lines.push("}")
            lines.push("")
        } else if (root.floatingOnly && !root.pluginLoaded) {
            lines.push("# Floating-only mode is enabled in Settings, but the")
            lines.push("# hyprbars plugin isn't verified loaded yet — windowrules")
            lines.push("# omitted to prevent parse errors. Click 'Check status'")
            lines.push("# in Settings → Hyprbars to verify, then toggle the")
            lines.push("# floating-only option to re-emit.")
            lines.push("")
        }

        return lines.join("\n")
    }

    // ────────────────────────────────────────────────────────────
    // WRITE CONFIG TO DISK
    // ────────────────────────────────────────────────────────────

    Process { id: writeConfigProc; running: false }

    // v7.0.0-beta.1-hf59 — after writeConfig fires `hyprctl reload`,
    // Hyprland tears down + reloads plugins via hyprpm's (broken)
    // path, often dropping hyprbars. Schedule a re-verify so the
    // auto-load logic in verifyProc can pick it up and recover.
    Timer {
        id: postReloadVerifyTimer
        interval: 1000   // give Hyprland time to settle after reload
        repeat: false
        onTriggered: {
            if (root.enabled) root.verifyPluginLoaded()
        }
    }

    function writeConfig() {
        const text = buildConfigText()
        if (text === root._lastWritten) return    // no change
        root._lastWritten = text
        // Use a heredoc for safe escaping of special chars
        const cmd = "mkdir -p '" + root.configDir + "' && "
                  + "cat > '" + root.configPath + "' << 'ZSHYPRBARS_EOF'\n"
                  + text + "\nZSHYPRBARS_EOF\n"
                  // Try to reload Hyprland to pick up changes
                  + "hyprctl reload >/dev/null 2>&1 || true"
        writeConfigProc.command = ["bash", "-c", cmd]
        writeConfigProc.running = true
        console.log("[Hyprbars] config written:", root.configPath)
        // hf59 — verify plugin state after Hyprland's reload settles,
        // so auto-load can recover if the reload dropped the plugin.
        postReloadVerifyTimer.start()
    }

    // Ensure `source = ~/.config/hypr/zen-hyprbars.conf` is present
    // in the user's main hyprland.conf. Append it if missing.
    // v7.0.0-beta.1-hf57 — ensure source line uses ~/ form + clean up
    // any old absolute-path lines from hf52-hf56 that hardcoded
    // /home/paul/.config/hypr/zen-hyprbars.conf.
    //
    // Migration logic:
    //   1. Remove any line matching `source = /home/.+/.config/hypr/zen-hyprbars.conf`
    //      (handles paul, mom, anyone else's home dir)
    //   2. Add `source = ~/.config/hypr/zen-hyprbars.conf` if missing
    //   3. Both operations idempotent — safe to re-run
    Process { id: ensureSourceProc; running: false }
    function ensureMainConfSources() {
        const tildeLine = root.sourceLineTilde
        // Use sed -E with | delimiter so forward slashes in the
        // path pattern don't need escaping. The pattern matches any
        // home directory: /home/anyuser/.config/hypr/zen-hyprbars.conf
        const cmd = ""
            // Strip any old absolute-path source lines (hf52-hf56 bug)
            + "sed -E -i '\\|^source = /home/[^/]+/\\.config/hypr/zen-hyprbars\\.conf$|d' "
            + "'" + root.mainHyprlandConf + "' 2>/dev/null; "
            // Append portable tilde form if not already present
            + "grep -qxF '" + tildeLine + "' '" + root.mainHyprlandConf + "' 2>/dev/null || "
            + "echo '" + tildeLine + "' >> '" + root.mainHyprlandConf + "'; "
            + "echo 'Source line migrated to portable ~/ form'"
        ensureSourceProc.command = ["bash", "-c", cmd]
        ensureSourceProc.running = true
    }

    // ────────────────────────────────────────────────────────────
    // PLUGIN INSTALL / ENABLE / DISABLE
    // ────────────────────────────────────────────────────────────
    //
    // hyprpm wraps the install + enable workflow. Steps:
    //   1. hyprpm add https://github.com/hyprwm/hyprland-plugins
    //   2. hyprpm enable hyprbars
    //   3. hyprpm reload  (loads enabled plugins into running Hyprland)
    //
    // The `add` step is idempotent — hyprpm detects existing repos
    // and skips. Build deps required: cpio, cmake, git, meson, gcc.
    //
    // v7.0.0-beta.1-hf53 — fixed silent failures:
    //   - statusMessage updated as commands run (visible in Settings UI)
    //   - busy flag set true while running, false on completion
    //   - lastError captured from stderr
    //   - Toast notifications fire for success / failure
    //   - The compile takes 30-60sec — busy flag keeps UI in sync

    function _notify(summary, body, urgency) {
        if (typeof NotificationService !== "undefined"
            && typeof NotificationService.postInternal === "function") {
            try {
                NotificationService.postInternal(summary, body, urgency || 1, "")
            } catch (e) { console.warn("[Hyprbars] notify failed:", e) }
        } else {
            console.log("[Hyprbars]", summary, "—", body)
        }
    }

    Process {
        id: installProc
        running: false
        property string _opName: "install"
        // Capture stdout for status display
        stdout: StdioCollector {
            onStreamFinished: {
                const out = String(this.text || "").trim()
                if (out.length > 0) {
                    root.statusMessage = out.split("\n").slice(-3).join(" | ")
                    console.log("[Hyprbars stdout]", out)
                }
            }
        }
        // Capture stderr for error display
        stderr: StdioCollector {
            onStreamFinished: {
                const err = String(this.text || "").trim()
                if (err.length > 0) {
                    root.lastError = err.split("\n").slice(-2).join(" | ")
                    console.warn("[Hyprbars stderr]", err)
                }
            }
        }
        onExited: function(exitCode) {
            root.busy = false
            if (exitCode === 0) {
                root._notify("Hyprbars",
                    _opName + " complete. " + (root.statusMessage || "Done."),
                    1)
            } else {
                root._notify("Hyprbars",
                    _opName + " failed (exit " + exitCode + "). " + (root.lastError || ""),
                    2)
            }
            // v7.0.0-beta.1-hf57 — verify plugin state after every op
            // so pluginLoaded property reflects reality. Small delay
            // gives Hyprland time to finish reload before we query.
            verifyAfterOpTimer.start()
        }
    }

    // Small delay after install/enable/disable before verifying
    // plugin loaded state — Hyprland needs ~500ms to settle after
    // hyprctl reload.
    Timer {
        id: verifyAfterOpTimer
        interval: 800
        repeat: false
        onTriggered: root.verifyPluginLoaded()
    }

    function installPlugin() {
        root.lastError = ""
        root.statusMessage = "Installing… this may take 30-60 seconds"
        root.busy = true
        // hf59 — user-triggered action: reset auto-load budget so
        // the post-install verify can retry fresh if needed.
        root._autoLoadAttemptCount = 0
        // hf62 — user-triggered action: re-enable heavy recovery
        // path so this session can fall through to it again if
        // light auto-load fails after this install.
        root._heavyRecoveryAttempted = false
        installProc._opName = "install"
        // v7.0.0-beta.1-hf58 — even more robust install:
        //   - Pre-flight: hyprpm + build deps
        //   - Migrate any old absolute-path source lines (sed)
        //   - Ensure tilde-form source line present
        //   - hyprpm update FIRST (refreshes manifest, builds .so)
        //   - hyprpm add (idempotent — only matters first time)
        //   - hyprpm enable hyprbars
        //   - hyprpm reload
        //   - hyprctl reload
        //   - If hyprctl plugin list missing hyprbars → try manual
        //     `hyprctl plugin load <.so path>` as fallback
        //   - Final verify
        const cmd = ""
            + "set +e; "
            + "echo '[Hyprbars] Step 1/8: pre-flight checks'; "
            + "command -v hyprpm >/dev/null 2>&1 || { "
            + "  echo '❌ hyprpm not found. Install hyprland-devel or use AUR.'; "
            + "  exit 10; "
            + "}; "
            + "missing=''; "
            + "for tool in cpio cmake git meson gcc; do "
            + "  command -v $tool >/dev/null 2>&1 || missing=\"$missing $tool\"; "
            + "done; "
            + "if [ -n \"$missing\" ]; then "
            + "  echo \"❌ missing build deps:$missing\"; "
            + "  echo 'Run: sudo pacman -S --needed cpio cmake git meson gcc'; "
            + "  exit 11; "
            + "fi; "
            + "echo '✅ hyprpm + deps OK'; "
            + "echo; "
            + "echo '[Hyprbars] Step 2/8: migrating source line to portable form'; "
            + "sed -E -i '\\|^source = /home/[^/]+/\\.config/hypr/zen-hyprbars\\.conf$|d' "
            + "'" + root.mainHyprlandConf + "' 2>/dev/null; "
            + "TILDE='source = ~/.config/hypr/zen-hyprbars.conf'; "
            + "grep -qxF \"$TILDE\" '" + root.mainHyprlandConf + "' 2>/dev/null || "
            + "  echo \"$TILDE\" >> '" + root.mainHyprlandConf + "'; "
            + "echo '✅ Source line: ~/.config/hypr/zen-hyprbars.conf'; "
            + "echo; "
            + "echo '[Hyprbars] Step 3/8: hyprpm update (refresh manifest + rebuild)'; "
            + "hyprpm update 2>&1 | tail -8; "
            + "echo; "
            + "echo '[Hyprbars] Step 4/8: hyprpm add (idempotent)'; "
            + "hyprpm add https://github.com/hyprwm/hyprland-plugins 2>&1 | tail -5; "
            + "echo; "
            + "echo '[Hyprbars] Step 5/8: hyprpm enable hyprbars'; "
            + "hyprpm enable hyprbars 2>&1 | tail -3; "
            + "echo; "
            + "echo '[Hyprbars] Step 6/8: hyprpm reload'; "
            + "hyprpm reload 2>&1 | tail -3; "
            + "echo; "
            + "echo '[Hyprbars] Step 7/8: hyprctl reload'; "
            + "hyprctl reload 2>&1 | tail -2; "
            + "sleep 0.5; "
            + "echo; "
            + "echo '[Hyprbars] Step 8/8: verification + fallback load'; "
            + "if hyprctl plugin list 2>&1 | grep -qi hyprbars; then "
            + "  echo '✅ hyprbars is LOADED into Hyprland!'; "
            + "else "
            + "  echo '⚠ Plugin not loaded after hyprpm reload — trying manual load'; "
            + "  SO=''; "
            + "  for SEARCH_DIR in "
            + "    \"${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\" "
            + "    \"$HOME/.local/share/hyprpm\" "
            + "    \"$HOME/.cache/hyprpm\" ; do "
            + "    [ -d \"$SEARCH_DIR\" ] || continue; "
            + "    FOUND=$(find \"$SEARCH_DIR\" -name 'hyprbars*.so' 2>/dev/null | head -1); "
            + "    if [ -n \"$FOUND\" ]; then SO=\"$FOUND\"; break; fi; "
            + "  done; "
            + "  if [ -n \"$SO\" ]; then "
            + "    echo 'Found .so:' \"$SO\"; "
            + "    hyprctl plugin load \"$SO\" 2>&1; "
            + "    sleep 0.5; "
            + "    if hyprctl plugin list 2>&1 | grep -qi hyprbars; then "
            + "      echo '✅ Loaded via manual hyprctl plugin load!'; "
            + "    else "
            + "      echo '❌ Manual load failed too — possible ABI mismatch.'; "
            + "      echo '   Your Hyprland version may not have a matching plugin pin.'; "
            + "      echo '   Try: hyprpm update -v in terminal for verbose output.'; "
            + "    fi; "
            + "  else "
            + "    echo '❌ No hyprbars*.so found.'; "
            + "    echo '   Build likely failed silently. Run: hyprpm update -v'; "
            + "  fi; "
            + "fi; "
            + "exit 0"
        installProc.command = ["bash", "-c", cmd]
        installProc.running = true
        writeConfig()
    }

    function enablePlugin() {
        root.lastError = ""
        root.statusMessage = "Enabling…"
        root.busy = true
        // hf59 — user-triggered action: reset auto-load budget.
        root._autoLoadAttemptCount = 0
        root._heavyRecoveryAttempted = false   // hf62
        installProc._opName = "enable"
        // v7.0.0-beta.1-hf59 — beefed-up enable flow.
        //
        // Previous: just hyprpm enable + reload. Same upstream issue
        // applies: hyprpm reload often reports OK but doesn't inject.
        // Now mirrors installPlugin's Step 8 fallback — try manual
        // `hyprctl plugin load` if hyprpm reload didn't actually
        // load the plugin into Hyprland's runtime.
        installProc.command = ["bash", "-c",
            "set +e; "
            + "echo '[Hyprbars] Step 1/4: hyprpm enable'; "
            + "hyprpm enable hyprbars 2>&1 | tail -3; "
            + "echo; "
            + "echo '[Hyprbars] Step 2/4: hyprpm reload'; "
            + "hyprpm reload 2>&1 | tail -3; "
            + "sleep 0.5; "
            + "echo; "
            + "echo '[Hyprbars] Step 3/4: hyprctl reload'; "
            + "hyprctl reload 2>&1 | tail -2; "
            + "sleep 0.5; "
            + "echo; "
            + "echo '[Hyprbars] Step 4/4: verify + manual load fallback'; "
            + "if hyprctl plugin list 2>&1 | grep -qi hyprbars; then "
            + "  echo '✅ hyprbars is LOADED'; "
            + "else "
            + "  echo '⚠ hyprpm reload did not inject — trying manual load'; "
            + "  SO=''; "
            + "  for SEARCH_DIR in "
            + "    \"${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\" "
            + "    \"$HOME/.local/share/hyprpm\" "
            + "    \"$HOME/.cache/hyprpm\" ; do "
            + "    [ -d \"$SEARCH_DIR\" ] || continue; "
            + "    FOUND=$(find \"$SEARCH_DIR\" -name 'hyprbars*.so' 2>/dev/null | head -1); "
            + "    if [ -n \"$FOUND\" ]; then SO=\"$FOUND\"; break; fi; "
            + "  done; "
            + "  if [ -n \"$SO\" ]; then "
            + "    hyprctl plugin load \"$SO\" 2>&1; "
            + "    sleep 0.3; "
            + "    if hyprctl plugin list 2>&1 | grep -qi hyprbars; then "
            + "      echo '✅ Loaded via manual hyprctl plugin load'; "
            + "    else "
            + "      echo '❌ Manual load also failed — possible ABI mismatch'; "
            + "    fi; "
            + "  else "
            + "    echo '❌ No .so found — run Install / reinstall first'; "
            + "  fi; "
            + "fi; "
            + "exit 0"]
        installProc.running = true
        writeConfig()
        ensureMainConfSources()
    }

    function disablePlugin() {
        root.lastError = ""
        root.statusMessage = "Disabling…"
        root.busy = true
        installProc._opName = "disable"
        installProc.command = ["bash", "-c",
            "hyprpm disable hyprbars 2>&1 | tail -3 && "
            + "hyprpm reload 2>&1 | tail -3 && "
            + "echo '[Hyprbars] disabled'"]
        installProc.running = true
    }

    // v7.0.0-beta.1-hf57 — verify plugin is actually loaded.
    //
    // Runs `hyprctl plugin list` and grep for hyprbars. Updates the
    // `pluginLoaded` property based on what Hyprland reports. This
    // is the single source of truth for whether the windowrules
    // can safely be emitted.
    Process {
        id: verifyProc
        running: false
        property bool _wasLoaded: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = String(this.text || "")
                const nowLoaded = /hyprbars/i.test(out) && !/^$/.test(out.trim())
                if (nowLoaded !== root.pluginLoaded) {
                    console.log("[Hyprbars] pluginLoaded:", root.pluginLoaded, "→", nowLoaded)
                    root.pluginLoaded = nowLoaded
                    // Re-emit config now that pluginLoaded changed —
                    // if user has floatingOnly on and plugin just
                    // came up, windowrules can now be emitted safely.
                    if (nowLoaded && root.floatingOnly) {
                        root._lastWritten = ""
                        root.writeConfig()
                    }
                }

                // v7.0.0-beta.1-hf59 — auto force-load.
                //
                // If user has `enabled=true` (they want bars) but the
                // plugin is NOT loaded in Hyprland's runtime, that
                // means hyprpm reload silently failed to inject the
                // .so (known upstream issue). Auto-trigger the same
                // manual load that the Force load button does.
                //
                // Bounded by _autoLoadMaxAttempts so a permanently
                // broken setup (e.g. ABI mismatch — no .so even built)
                // doesn't spin forever.
                if (nowLoaded) {
                    // Plugin is loaded — reset attempt counter so the
                    // NEXT drop (after a future hyprctl reload) gets
                    // a fresh budget of retries.
                    root._autoLoadAttemptCount = 0
                } else if (root.enabled
                           && !root._autoLoadInProgress
                           && !root._heavyRecoveryInProgress
                           && root._autoLoadAttemptCount < root._autoLoadMaxAttempts) {
                    root._autoLoadAttemptCount += 1
                    console.log("[Hyprbars hf59] auto force-load attempt",
                                root._autoLoadAttemptCount, "/",
                                root._autoLoadMaxAttempts)
                    root._autoLoadInProgress = true
                    autoLoadProc.command = ["bash", "-c", root._autoLoadCmd()]
                    autoLoadProc.running = true
                }
                // v7.0.0-beta.1-hf62 — heavy recovery escalation.
                //
                // Lightweight auto-load hit its 3-attempt cap and
                // plugin still isn't loaded. Most likely cause: the
                // .so was cleaned up from $XDG_RUNTIME_DIR after
                // hyprpm's last build session, so `hyprctl plugin
                // load <existing>` keeps finding nothing.
                //
                // Only path forward: ask hyprpm to rebuild + load
                // atomically. Expensive (~10s blocking), so we cap
                // this at ONE attempt per shell session.

                // hf79: event-driven boot followup. When the boot
                // verify completes, fire writeConfig immediately
                // instead of waiting the old fixed 1200ms delay.
                // Shaves ~1s off cold-boot activation time.
                if (root._bootVerifyPending) {
                    root._bootVerifyPending = false
                    bootRewriteFollowupTimer.stop()  // cancel safety fallback
                    if (root.enabled) {
                        console.log("[Hyprbars hf79] boot config write (event-driven, " +
                                    (nowLoaded ? "plugin loaded" : "plugin missing") + ")")
                        root._lastWritten = ""
                        root.writeConfig()
                        root.ensureMainConfSources()
                    }
                }
                else if (!nowLoaded
                         && root.enabled
                         && root._autoLoadAttemptCount >= root._autoLoadMaxAttempts
                         && !root._heavyRecoveryAttempted
                         && !root._heavyRecoveryInProgress
                         && !root._autoLoadInProgress) {
                    console.log("[Hyprbars hf62] firing heavy recovery (hyprpm rebuild + load)")
                    root._heavyRecoveryAttempted = true
                    root._heavyRecoveryInProgress = true
                    heavyRecoveryProc.command = ["bash", "-c", root._heavyRecoveryCmd()]
                    heavyRecoveryProc.running = true
                }
            }
        }
    }

    // v7.0.0-beta.1-hf59 — silent auto-load process.
    // v7.0.0-beta.1-hf60 — now captures stderr to lastLoadError + .so
    // path to soPath so the failure reason is visible in the UI.
    //
    // Separate Process from the user-visible installProc so it
    // doesn't clobber the busy/status UI when running automatically.
    // Same `hyprctl plugin load <so>` as manualLoadPlugin() but no
    // toast spam — only notifies on first successful auto-recovery.
    Process {
        id: autoLoadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = String(this.text || "").trim()
                if (out.length === 0) return
                console.log("[Hyprbars hf60 auto-load]", out)
                // Parse structured key=value tokens our command emits
                // so we can populate UI state without regex contortions.
                //   SO=/path/to/hyprbars.so      (or empty)
                //   STATUS=ok|missing-so|load-failed
                //   ERR=<single-line stderr from hyprctl plugin load>
                for (const line of out.split("\n")) {
                    if (line.startsWith("SO=")) {
                        const p = line.substring(3).trim()
                        root.soPath = p
                        root.soExists = (p.length > 0)
                    } else if (line.startsWith("ERR=")) {
                        const e = line.substring(4).trim()
                        if (e.length > 0) root.lastLoadError = e
                    } else if (line.startsWith("STATUS=ok")) {
                        // Clear any prior error on success
                        root.lastLoadError = ""
                    } else if (line.startsWith("STATUS=missing-so")) {
                        root.lastLoadError = "Plugin .so not built — run `hyprpm update -v` in terminal"
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = String(this.text || "").trim()
                if (err.length > 0) {
                    console.warn("[Hyprbars hf60 auto-load stderr]", err)
                    // Some hyprctl versions write the error to stderr
                    // rather than stdout — also surface it.
                    root.lastLoadError = err.split("\n").slice(-1)[0]
                }
            }
        }
        onExited: function(exitCode) {
            root._autoLoadInProgress = false
            autoLoadVerifyTimer.start()
        }
    }
    Timer {
        id: autoLoadVerifyTimer
        interval: 600
        repeat: false
        onTriggered: {
            // Snapshot prior state so we can detect the
            // "load just succeeded" transition for notification.
            const wasLoaded = root.pluginLoaded
            // verifyPluginLoaded() updates pluginLoaded async.
            // We hook into pluginLoadedChanged once via a one-shot.
            root._autoLoadPriorLoaded = wasLoaded
            root.verifyPluginLoaded()
        }
    }
    property bool _autoLoadPriorLoaded: false

    // v7.0.0-beta.1-hf62 — heavy recovery process.
    //
    // Fires when lightweight auto-load has exhausted its 3 attempts
    // AND _heavyRecoveryAttempted is still false. Runs the atomic
    // hyprpm enable + reload + manual-load chain. Updates
    // statusMessage so user sees progress (this is ~10s, longer than
    // light auto-load, so silent operation would feel laggy).
    Process {
        id: heavyRecoveryProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = String(this.text || "").trim()
                if (out.length === 0) return
                console.log("[Hyprbars hf62 heavy-recovery]\n" + out)
                for (const line of out.split("\n")) {
                    if (line.startsWith("STAGE=")) {
                        root.statusMessage = "Heavy recovery: "
                            + line.substring(6).replace(/-/g, " ")
                    } else if (line.startsWith("SO=")) {
                        const p = line.substring(3).trim()
                        if (p.length > 0) {
                            root.soPath = p
                            root.soExists = true
                        }
                    } else if (line.startsWith("STATUS=ok")) {
                        root.lastLoadError = ""
                        root.statusMessage = "Recovered via heavy reload"
                    } else if (line.startsWith("STATUS=missing-so-after-recovery")) {
                        root.lastLoadError =
                            "hyprpm reload didn't leave .so on disk — "
                            + "check `hyprpm list` in terminal: hyprbars "
                            + "may not be enabled in hyprpm's persistent state"
                    } else if (line.startsWith("STATUS=load-failed-after-recovery")) {
                        root.statusMessage = "Recovery: rebuild OK but load failed"
                    } else if (line.startsWith("ERR=")) {
                        const e = line.substring(4).trim()
                        if (e.length > 0) root.lastLoadError = e
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = String(this.text || "").trim()
                if (err.length > 0) {
                    console.warn("[Hyprbars hf62 heavy-recovery stderr]", err)
                }
            }
        }
        onExited: function(exitCode) {
            root._heavyRecoveryInProgress = false
            // Verify after settle. If still not loaded, the badge
            // will show "exhausted" + the diagnostic card shows what
            // went wrong (lastLoadError populated from stdout above).
            autoLoadVerifyTimer.start()
        }
    }

    onPluginLoadedChanged: {
        // Detect the transition from not-loaded → loaded right
        // after an auto-load attempt finished, and post a single
        // success notification so the user knows the recovery worked.
        if (root.pluginLoaded
            && !root._autoLoadPriorLoaded
            && root._autoLoadAttemptCount > 0) {
            root._notify("Hyprbars",
                "Plugin auto-loaded successfully (attempt "
                + root._autoLoadAttemptCount + ").",
                1)
            root._autoLoadPriorLoaded = true
        }
    }

    // Build the auto-load command — finds the .so via $HOME-based
    // path (works for any user) and runs `hyprctl plugin load`.
    //
    // hf60 — emits structured tokens (SO=, STATUS=, ERR=) so the QML
    // stdout handler can populate UI state. The error from `hyprctl
    // plugin load` is the actual diagnostic value — captures whether
    // it's ABI mismatch, file-not-found, permission, etc.
    //
    // hf61 — CRITICAL FIX: modern hyprpm builds plugins to
    // $XDG_RUNTIME_DIR/hyprpm/$USER/ (e.g. /run/user/1000/hyprpm/paul/
    // hyprbars/hyprbars.so), NOT ~/.local/share/hyprpm/. The old find
    // path returned nothing on systems with modern hyprpm even when
    // the .so was built successfully. Now searches multiple locations
    // in priority order: XDG runtime dir → legacy share dir → cache.
    //
    // Centralized in _findSoSnippet() so every site that needs to
    // locate the .so uses the same lookup logic. Sets shell variable
    // SO to the absolute path if found, empty otherwise.
    function _findSoSnippet() {
        return ""
            + "SO=''; "
            + "for SEARCH_DIR in "
            + "  \"${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\" "
            + "  \"$HOME/.local/share/hyprpm\" "
            + "  \"$HOME/.cache/hyprpm\" ; do "
            + "  [ -d \"$SEARCH_DIR\" ] || continue; "
            + "  FOUND=$(find \"$SEARCH_DIR\" -name 'hyprbars*.so' 2>/dev/null | head -1); "
            + "  if [ -n \"$FOUND\" ]; then SO=\"$FOUND\"; break; fi; "
            + "done; "
    }

    // v7.0.0-beta.1-hf62 — heavy recovery command.
    //
    // Atomic chain: enable + reload + find + load. Runs as one bash
    // process so the .so doesn't get cleaned up between hyprpm's
    // exit and our `hyprctl plugin load`. Modern hyprpm builds into
    // a tmpfs runtime dir that's wiped after reload completes — by
    // the time a separate process starts, the .so is gone.
    //
    // Sequence:
    //   1. `hyprpm enable hyprbars` (idempotent — ensures enabled)
    //   2. `hyprpm reload` (rebuilds + loads enabled plugins)
    //   3. Immediately find .so (still on disk during reload window)
    //   4. `hyprctl plugin load` if not already loaded by step 2
    //   5. Verify result, emit structured tokens for QML to parse
    function _heavyRecoveryCmd() {
        return ""
            + "set +e; "
            + "echo 'STAGE=hyprpm-enable'; "
            + "hyprpm enable hyprbars 2>&1 | tail -3 | sed 's/^/  /'; "
            + "echo 'STAGE=hyprpm-reload'; "
            + "hyprpm reload 2>&1 | tail -5 | sed 's/^/  /'; "
            + "sleep 0.3; "
            + "echo 'STAGE=hyprctl-reload'; "
            + "hyprctl reload 2>&1 | tail -2 | sed 's/^/  /'; "
            + "sleep 0.3; "
            + "echo 'STAGE=verify-1'; "
            + "if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then "
            + "  echo 'STATUS=ok-via-hyprpm'; "
            + "  echo 'RECOVERY=succeeded via hyprpm reload'; "
            + "  exit 0; "
            + "fi; "
            + "echo 'STAGE=find-so-after-rebuild'; "
            + root._findSoSnippet()
            + "echo \"SO=$SO\"; "
            + "if [ -z \"$SO\" ]; then "
            + "  echo 'STATUS=missing-so-after-recovery'; "
            + "  echo 'ERR=hyprpm reload completed but no .so left on disk and plugin not loaded — likely hyprpm did not enable hyprbars (try: hyprpm list | grep hyprbars in terminal)'; "
            + "  exit 1; "
            + "fi; "
            + "echo 'STAGE=manual-load-after-rebuild'; "
            + "LOAD_OUT=$(hyprctl plugin load \"$SO\" 2>&1); "
            + "echo \"LOAD_OUT=$LOAD_OUT\"; "
            + "sleep 0.3; "
            + "if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then "
            + "  echo 'STATUS=ok-via-manual'; "
            + "  echo 'RECOVERY=succeeded via manual load after rebuild'; "
            + "else "
            + "  echo 'STATUS=load-failed-after-recovery'; "
            + "  echo \"ERR=$(echo \"$LOAD_OUT\" | tr '\\n' ' | ' | head -c 240)\"; "
            + "fi; "
            + "exit 0"
    }

    function _autoLoadCmd() {
        return ""
            + "set +e; "
            + root._findSoSnippet()
            + "echo \"SO=$SO\"; "
            + "if [ -z \"$SO\" ]; then "
            + "  echo 'STATUS=missing-so'; "
            + "  exit 1; "
            + "fi; "
            // Capture both stdout and stderr separately; flatten stderr
            // into a single line so QML token parsing stays simple.
            + "LOAD_OUT=$(hyprctl plugin load \"$SO\" 2>&1); "
            + "LOAD_EXIT=$?; "
            + "if hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then "
            + "  echo 'STATUS=ok'; "
            + "else "
            + "  echo 'STATUS=load-failed'; "
            + "  echo \"ERR=$(echo \"$LOAD_OUT\" | tr '\\n' ' | ' | head -c 240)\"; "
            + "fi; "
            + "exit 0"
    }

    function verifyPluginLoaded() {
        verifyProc.command = ["bash", "-c",
            "hyprctl plugin list 2>/dev/null || echo ''"]
        verifyProc.running = true
    }

    // v7.0.0-beta.1-hf62 — user-triggered heavy recovery.
    //
    // Manual button in Settings → Hyprbars to fire the heavy
    // rebuild + load chain without waiting for auto-load to exhaust.
    // Useful when user knows hyprpm needs a kick and doesn't want
    // to wait through 3 lightweight retries first.
    //
    // Same code path as the auto-triggered heavy recovery — but
    // bypasses the once-per-session cap (always allowed manually).
    function triggerHeavyRecovery() {
        if (root._heavyRecoveryInProgress) {
            console.log("[Hyprbars] heavy recovery already in progress, ignoring")
            return
        }
        root.lastError = ""
        root.statusMessage = "Heavy recovery: starting hyprpm rebuild…"
        root._heavyRecoveryAttempted = true
        root._heavyRecoveryInProgress = true
        heavyRecoveryProc.command = ["bash", "-c", root._heavyRecoveryCmd()]
        heavyRecoveryProc.running = true
    }

    function updatePlugin() {
        root.lastError = ""
        root.statusMessage = "Updating from upstream…"
        root.busy = true
        installProc._opName = "update"
        installProc.command = ["bash", "-c",
            "hyprpm update 2>&1 | tail -5 && "
            + "hyprpm reload 2>&1 | tail -3 && "
            + "hyprctl reload 2>&1 | tail -2 && "
            + "echo '[Hyprbars] updated'"]
        installProc.running = true
    }

    // v7.0.0-beta.1-hf54 — diagnostic check.
    // v7.0.0-beta.1-hf58 — comprehensive diagnostic check.
    //
    // Surfaces ALL possible reasons why hyprbars might not be loaded:
    //   1. Hyprland version (for ABI match checking)
    //   2. hyprpm reports plugin as enabled?
    //   3. Plugin .so file actually built?
    //   4. hyprctl plugin list shows it as loaded?
    //   5. Permission management blocking hyprpm?
    //   6. Source line in hyprland.conf?
    function checkStatus() {
        root.lastError = ""
        root.statusMessage = "Running comprehensive diagnostic…"
        root.busy = true
        installProc._opName = "status check"
        const cmd = ""
            + "echo '=== Hyprbars Diagnostic Report ==='; "
            + "echo; "
            + "echo '[1/7] Hyprland version:'; "
            + "hyprctl version 2>&1 | head -2 | sed 's/^/  /' "
            + "  || echo '  ❌ hyprctl not responding'; "
            + "echo; "
            + "echo '[2/7] hyprpm available?'; "
            + "if command -v hyprpm >/dev/null 2>&1; then "
            + "  echo '  ✅ hyprpm found at:' \"$(command -v hyprpm)\"; "
            + "else "
            + "  echo '  ❌ hyprpm NOT FOUND'; "
            + "fi; "
            + "echo; "
            + "echo '[3/7] hyprpm list (state from hyprpm):'; "
            + "hyprpm list 2>&1 | grep -A1 -i hyprbars | sed 's/^/  /' "
            + "  || echo '  (hyprbars not in hyprpm list — never added?)'; "
            + "echo; "
            + "echo '[4/7] Plugin .so file built?'; "
            + "FOUND_SO=''; "
            + "FOUND_IN=''; "
            + "for SEARCH_DIR in "
            + "  \"${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\" "
            + "  \"$HOME/.local/share/hyprpm\" "
            + "  \"$HOME/.cache/hyprpm\" ; do "
            + "  [ -d \"$SEARCH_DIR\" ] || continue; "
            + "  CANDIDATE=$(find \"$SEARCH_DIR\" -name 'hyprbars*.so' 2>/dev/null | head -1); "
            + "  if [ -n \"$CANDIDATE\" ]; then "
            + "    FOUND_SO=\"$CANDIDATE\"; "
            + "    FOUND_IN=\"$SEARCH_DIR\"; "
            + "    break; "
            + "  fi; "
            + "done; "
            + "if [ -n \"$FOUND_SO\" ]; then "
            + "  echo '  ✅ Built .so:'; "
            + "  echo \"    $FOUND_SO\"; "
            + "  echo \"  (found in: $FOUND_IN)\"; "
            + "else "
            + "  echo '  ❌ No hyprbars*.so found in any hyprpm location:'; "
            + "  echo \"    • ${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\"; "
            + "  echo '    • $HOME/.local/share/hyprpm'; "
            + "  echo '    • $HOME/.cache/hyprpm'; "
            + "  echo '  → Build likely failed. Try: hyprpm update -v in terminal'; "
            + "fi; "
            + "echo; "
            + "echo '[5/7] hyprctl plugin list (runtime loaded):'; "
            + "PLUGINS=$(hyprctl plugin list 2>&1); "
            + "if [ -z \"$PLUGINS\" ] || echo \"$PLUGINS\" | grep -qi 'no plugins\\|^$'; then "
            + "  echo '  ⚠ No plugins loaded at all'; "
            + "elif echo \"$PLUGINS\" | grep -qi 'hyprbars'; then "
            + "  echo '  ✅ hyprbars is LOADED:'; "
            + "  echo \"$PLUGINS\" | grep -A1 -i hyprbars | sed 's/^/    /'; "
            + "else "
            + "  echo '  ❌ hyprbars NOT in loaded plugins. Currently loaded:'; "
            + "  echo \"$PLUGINS\" | head -10 | sed 's/^/    /'; "
            + "fi; "
            + "echo; "
            + "echo '[6/7] Permission management check:'; "
            + "if grep -q '^permission' '" + root.mainHyprlandConf + "' 2>/dev/null; then "
            + "  echo '  ⚠ Permission management enabled.'; "
            + "  echo '  hyprpm allow rule:'; "
            + "  if grep -q '^permission.*hyprpm' '" + root.mainHyprlandConf + "' 2>/dev/null; then "
            + "    grep '^permission.*hyprpm' '" + root.mainHyprlandConf + "' | sed 's/^/    /'; "
            + "  else "
            + "    echo '    ❌ MISSING — add this to hyprland.conf:'; "
            + "    echo '    permission = /usr/(bin|local/bin)/hyprpm, plugin, allow'; "
            + "  fi; "
            + "else "
            + "  echo '  ✅ No permission management — no allow rule needed'; "
            + "fi; "
            + "echo; "
            + "echo '[7/7] Source line:'; "
            + "grep zen-hyprbars '" + root.mainHyprlandConf + "' 2>/dev/null | sed 's/^/  /' "
            + "  || echo '  ❌ No source line for zen-hyprbars.conf'; "
            + "echo; "
            + "echo '=== End Report ==='; "
            + "echo; "
            + "echo 'NEXT STEPS:'; "
            + "echo '  • If .so missing → terminal: hyprpm update -v'; "
            + "echo '  • If loaded but bars missing → Super+V to float a window'; "
            + "echo '  • If permission missing → add line to hyprland.conf'; "
            + "echo '  • If built but not loaded → click Force load button'; "
            + "exit 0"
        installProc.command = ["bash", "-c", cmd]
        installProc.running = true
    }

    // v7.0.0-beta.1-hf58 — manual plugin load fallback.
    //
    // When hyprpm reports plugin enabled but `hyprctl plugin list`
    // doesn't show it, the .so file exists but never got injected.
    // Force-load via `hyprctl plugin load <absolute_path>` which is
    // the documented manual workaround per Hyprland wiki.
    function manualLoadPlugin() {
        root.lastError = ""
        root.statusMessage = "Attempting manual plugin load…"
        root.busy = true
        // hf59 — user-triggered action: reset auto-load budget.
        root._autoLoadAttemptCount = 0
        root._heavyRecoveryAttempted = false   // hf62
        installProc._opName = "manual load"
        const cmd = ""
            + "SO=''; "
            + "for SEARCH_DIR in "
            + "  \"${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\" "
            + "  \"$HOME/.local/share/hyprpm\" "
            + "  \"$HOME/.cache/hyprpm\" ; do "
            + "  [ -d \"$SEARCH_DIR\" ] || continue; "
            + "  FOUND=$(find \"$SEARCH_DIR\" -name 'hyprbars*.so' 2>/dev/null | head -1); "
            + "  if [ -n \"$FOUND\" ]; then SO=\"$FOUND\"; break; fi; "
            + "done; "
            + "if [ -z \"$SO\" ]; then "
            + "  echo '❌ No hyprbars*.so found. Searched:'; "
            + "  echo \"  • ${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/hyprpm\"; "
            + "  echo '  • $HOME/.local/share/hyprpm'; "
            + "  echo '  • $HOME/.cache/hyprpm'; "
            + "  echo 'Run Install / reinstall first, then try again.'; "
            + "  exit 1; "
            + "fi; "
            + "echo 'Found .so at:' \"$SO\"; "
            + "echo 'Calling hyprctl plugin load…'; "
            + "hyprctl plugin load \"$SO\" 2>&1; "
            + "sleep 0.5; "
            + "echo 'Verifying via hyprctl plugin list:'; "
            + "if hyprctl plugin list 2>&1 | grep -qi hyprbars; then "
            + "  echo '✅ Plugin loaded successfully!'; "
            + "else "
            + "  echo '❌ Plugin still not loaded.'; "
            + "  echo 'Possible: ABI mismatch with your Hyprland version,'; "
            + "  echo 'or plugin .so is corrupted. Try hyprpm update -v.'; "
            + "fi; "
            + "exit 0"
        installProc.command = ["bash", "-c", cmd]
        installProc.running = true
    }

    // ────────────────────────────────────────────────────────────
    // BOOT
    // ────────────────────────────────────────────────────────────

    Component.onCompleted: {
        loadStateProc.running = true
    }

    // v7.0.0-beta.1-hf55 — auto-fix on startup.
    // v7.0.0-beta.1-hf79 — FASTER BOOT.
    //
    // Old chain: loadState → 800ms → verify → 1200ms → writeConfig
    //            Total: 2+ seconds of dead wait.
    //
    // New chain: loadState → 300ms → verify → onComplete → writeConfig
    //            Total: ~300ms + verify time (~100ms) = ~400ms.
    //
    // The 1200ms bootRewriteFollowupTimer was waiting blindly for
    // verifyPluginLoaded() to return. Now we use an event-driven
    // flag (_bootVerifyPending) that fires the followup the instant
    // verifyProc completes, shaving ~1s off boot.
    //
    // Initial 800ms → 300ms: ThemeService + singletons are ready well
    // within 300ms on modern hardware. Even if ThemeService isn't ready,
    // writeConfig will re-fire on themeChanged anyway, so the worst
    // case is one extra config write (cheap, <10ms).
    property bool _bootVerifyPending: false

    Timer {
        id: bootRewriteTimer
        interval: 300
        repeat: false
        running: false
        onTriggered: {
            root._bootVerifyPending = true
            root.verifyPluginLoaded()
            // Followup now fires from verifyProc.onStreamFinished
            // when _bootVerifyPending is true — no fixed delay.
        }
    }

    // KEPT as fallback safety net — if verifyProc somehow doesn't
    // fire within 2s (broken hyprctl, socket timeout), this ensures
    // config still gets written. Should never fire in practice.
    Timer {
        id: bootRewriteFollowupTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root._bootVerifyPending) {
                root._bootVerifyPending = false
                if (root.enabled) {
                    console.log("[Hyprbars hf79] boot followup (safety fallback)")
                    root._lastWritten = ""
                    root.writeConfig()
                    root.ensureMainConfSources()
                }
            }
        }
    }

    Connections {
        target: loadStateProc
        function onExited(code) {
            bootRewriteTimer.start()
            bootRewriteFollowupTimer.start()  // hf79: safety net
        }
    }

    // v7.0.0-beta.1-hf59 — periodic plugin-loaded watchdog.
    //
    // Polls `hyprctl plugin list` every 30s. If plugin drops mid-
    // session (e.g., user runs `hyprctl reload` manually, monitor
    // hotplug forces Hyprland reload, theme change triggered by
    // ThemeService), the verify auto-load logic recovers it without
    // requiring the user to open Settings and click anything.
    //
    // Cheap: just one hyprctl call returning a small string every
    // 30s. Skips when not enabled or auto-load disabled by user.
    //
    // Reset attempt counter every minute so transient ABI hiccups
    // don't permanently lock out recovery — gives the auto-load 3
    // tries per minute window rather than 3 total per shell session.
    Timer {
        id: watchdogTimer
        interval: 30000           // 30 seconds
        repeat: true
        running: true
        onTriggered: {
            if (root.enabled) {
                root.verifyPluginLoaded()
            }
        }
    }
    Timer {
        id: watchdogResetTimer
        interval: 60000           // 1 minute
        repeat: true
        running: true
        onTriggered: {
            // Only reset if NOT in the middle of an attempt cycle
            // AND we hit the max — gives ABI-mismatch setups a
            // fresh window to retry in case upstream patched the
            // plugin in the background (hyprpm update auto-fetched).
            if (root._autoLoadAttemptCount >= root._autoLoadMaxAttempts
                && !root._autoLoadInProgress) {
                console.log("[Hyprbars hf59 watchdog] resetting auto-load budget")
                root._autoLoadAttemptCount = 0
            }
        }
    }
}
