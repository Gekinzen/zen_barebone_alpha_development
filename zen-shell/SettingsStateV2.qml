pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * SettingsStateV2 — expanded central persistence singleton
 *
 * Designed as a SUPERSET of the original SettingsState.qml — di sinisira
 * yung original. Both can coexist; pages na bago (GeneralPage, DecorationPage)
 * use V2; yung AppearancePage.qml mo gumagamit pa rin ng lumang SettingsState.
 *
 * Covers every option in HyprMod's General + Decoration sections:
 *   General:    gaps_in, gaps_out, border_size, resize_on_border,
 *               extend_border_grab_area, hover_icon_on_border,
 *               col.active_border, col.inactive_border,
 *               layout, allow_tearing, snap.enabled, snap.window_gap,
 *               snap.monitor_gap, snap.border_overlap, snap.respect_gaps
 *   Decoration: rounding, rounding_power, active_opacity, inactive_opacity,
 *               fullscreen_opacity, dim_inactive, dim_strength, dim_around,
 *               dim_special, blur.enabled, blur.size, blur.passes,
 *               blur.ignore_opacity, blur.new_optimizations, blur.xray,
 *               blur.noise, blur.contrast, blur.brightness, blur.vibrancy,
 *               blur.vibrancy_darkness, blur.special, blur.popups,
 *               shadow.enabled, shadow.range, shadow.render_power,
 *               shadow.ignore_window, shadow.offset, shadow.scale,
 *               shadow.color, shadow.color_inactive
 *
 * Persists to ~/.config/quickshell/zen-shell/settings-state-v2.json
 * (separate file so original settings-state.json is never touched).
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/settings-state-v2.json"

    // ═════════════════════════════════════════════════════════════
    // GENERAL
    // ═════════════════════════════════════════════════════════════
    property int gapsIn: 5
    property int gapsOut: 20
    property int borderSize: 2
    property bool resizeOnBorder: false
    property int extendBorderGrabArea: 15
    property bool hoverIconOnBorder: true

    // Border colors: stored as hex "#RRGGBBAA" for the UI,
    // converted to "rgba(AA,RR,GG,BB)" hyprctl format at apply time.
    property string activeBorderColor: "#33ccffff"
    property string inactiveBorderColor: "#595959aa"

    property string layout: "dwindle"            // "dwindle" | "master"
    property bool allowTearing: false

    property bool snapEnabled: false
    property int snapWindowGap: 10
    property int snapMonitorGap: 10
    property int snapBorderOverlap: 0
    property bool snapRespectGaps: false

    // ═════════════════════════════════════════════════════════════
    // DECORATION
    // ═════════════════════════════════════════════════════════════
    property int rounding: 10
    property real roundingPower: 2.0
    property real activeOpacity: 1.0
    property real inactiveOpacity: 0.95
    property real fullscreenOpacity: 1.0

    property bool dimInactive: false
    property real dimStrength: 0.5
    property real dimAround: 0.4
    property real dimSpecial: 0.2

    // Blur
    property bool blurEnabled: true
    property int blurSize: 8
    property int blurPasses: 2
    property bool blurIgnoreOpacity: true
    property bool blurNewOptimizations: true
    property bool blurXray: false
    property real blurNoise: 0.0117
    property real blurContrast: 0.8916
    property real blurBrightness: 0.8172
    property real blurVibrancy: 0.1696
    property real blurVibrancyDarkness: 0.0
    property bool blurSpecial: false
    property bool blurPopups: false

    // Shadow
    property bool shadowEnabled: true
    property int shadowRange: 4
    property int shadowRenderPower: 3
    property bool shadowIgnoreWindow: true
    property string shadowOffset: "0 0"         // "x y"
    property real shadowScale: 1.0
    property string shadowColor: "#1a1a1aee"
    property string shadowColorInactive: "#1a1a1aee"

    // ═════════════════════════════════════════════════════════════
    // v6.16.0 — BATTERY + POWER PROFILE
    // ═════════════════════════════════════════════════════════════
    // Battery bar module display style:
    //   "icon" → Nerd Font glyph (default)
    //   "text" → "87%" text
    //   "bar"  → mini progress bar
    property string batteryDisplayMode: "icon"

    // Notification thresholds (exposed so power users can tune)
    property int batteryWarnThreshold: 30
    property int batteryCriticalThreshold: 10

    // Last-known system power profile ("power-saver" | "balanced" | "performance").
    // PowerProfileService reads this on startup (via ~/.local/bin/zen-power-profile-restore.sh)
    // and re-applies it to powerprofilesctl, so the user's choice survives reboot.
    property string powerProfile: "balanced"

    // v6.16.1: Gaming Boost persistence. When gamingBoostActive=true on
    // shell restart, PowerProfileService re-applies boost state on init.
    // gamingBoostPreProfile stores what was active before boost so we
    // can restore it on toggle-off.
    property bool gamingBoostActive: false
    property string gamingBoostPreProfile: "balanced"

    // v6.16.1: GPU Switcher mode. Values: "auto" | "integrated" |
    // "dedicated" | "auto-gaming". GPUSwitcherService writes the
    // corresponding env vars to ~/.config/environment.d/zen-gpu.conf.
    property string gpuMode: "auto"

    // v6.16.4.12.7 (Tachiagari): Smart gaming detection — independent
    // of gpuMode. When true, ~/.local/bin/zen-smart-game-watcher.sh is
    // launched on shell init and runs in the background. It pgrep-polls
    // for known game/launcher processes (steam, lutris, gamescope,
    // wine/proton, dolphin-emu, retroarch, etc.) and fires Gaming Boost
    // ON when any are detected; restores previous power profile + blur
    // state when all of them exit.
    //
    // Why a separate toggle from gpuMode="auto-gaming":
    //   - gpuMode controls which GPU runs apps (iGPU vs dGPU env vars).
    //     A user might want to stay on integrated GPU but STILL get the
    //     CPU/blur tuning when a game launches (laptop on battery, e.g.).
    //   - Or they might be on a desktop with one GPU but still want the
    //     compositor effects toned down for max FPS while a game runs.
    // Splitting the responsibilities lets the user mix-and-match.
    //
    // The watcher script wraps PowerProfileService.setGamingBoost() via
    // Quickshell IPC so the same code path is used whether boost is
    // toggled manually from the panel or automatically from the daemon.
    property bool smartGamingDetect: false

    // Lid-close behavior (laptops):
    //   "mirror" → duplicate to external when lid closes (default)
    //   "keep"   → keep internal display on even with lid closed
    //   "off"    → disable internal display when lid closes (default hyprland behavior)
    property string lidCloseBehavior: "mirror"

    // ── Flags ──
    property bool initialized: false
    property bool dirty: false

    // ─────────────────────────────────────────────────────────────
    // COLOR HELPERS
    // Hyprland hex color format in configs is "rgba(RRGGBBAA)" WITHOUT
    // the leading #. So convert.
    // ─────────────────────────────────────────────────────────────

    function hexToHyprRgba(hex: string): string {
        if (!hex) return "rgba(ffffffff)"
        let h = hex.replace(/^#/, "")
        if (h.length === 6) h = h + "ff"
        if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2] + "ff"
        return "rgba(" + h.toLowerCase() + ")"
    }

    function hyprRgbaToHex(rgba: string): string {
        if (!rgba) return "#ffffffff"
        const m = rgba.match(/rgba\(([0-9a-fA-F]{8})\)/)
        if (m) return "#" + m[1].toLowerCase()
        return rgba  // assume already hex
    }

    // ─────────────────────────────────────────────────────────────
    // DEBOUNCED PERSIST
    // ─────────────────────────────────────────────────────────────

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: root.saveState()
    }

    function markDirty() {
        dirty = true
        saveTimer.restart()
    }

    // ─────────────────────────────────────────────────────────────
    // HYPRCTL (debounced batch + immediate)
    // ─────────────────────────────────────────────────────────────

    property string pendingHyprctl: ""

    Timer {
        id: hyprTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.pendingHyprctl.length > 0) {
                hyprProc.command = ["hyprctl", "--batch", root.pendingHyprctl]
                hyprProc.running = true
                root.pendingHyprctl = ""
            }
        }
    }

    function scheduleHyprctl(cmd: string) {
        pendingHyprctl = (pendingHyprctl.length > 0 ? pendingHyprctl + ";" : "") + cmd
        hyprTimer.restart()
        markDirty()
    }

    function hyprctlNow(key: string, val): void {
        hyprProc.command = ["hyprctl", "keyword", key, "" + val]
        hyprProc.running = true
        markDirty()
    }

    // Convenience for color keys (converts hex to hyprland rgba format).
    // Applied immediately (not debounced) so live color preview works.
    function hyprctlColor(key: string, hex: string) {
        const rgba = hexToHyprRgba(hex)
        hyprProc.command = ["hyprctl", "keyword", key, rgba]
        hyprProc.running = true
        markDirty()
    }

    Process { id: hyprProc; running: false }

    // ─────────────────────────────────────────────────────────────
    // SAVE / LOAD
    // ─────────────────────────────────────────────────────────────

    function saveState() {
        const state = {
            general: {
                gapsIn: gapsIn, gapsOut: gapsOut, borderSize: borderSize,
                resizeOnBorder: resizeOnBorder,
                extendBorderGrabArea: extendBorderGrabArea,
                hoverIconOnBorder: hoverIconOnBorder,
                activeBorderColor: activeBorderColor,
                inactiveBorderColor: inactiveBorderColor,
                layout: layout, allowTearing: allowTearing,
                snapEnabled: snapEnabled, snapWindowGap: snapWindowGap,
                snapMonitorGap: snapMonitorGap, snapBorderOverlap: snapBorderOverlap,
                snapRespectGaps: snapRespectGaps
            },
            decoration: {
                rounding: rounding, roundingPower: roundingPower,
                activeOpacity: activeOpacity, inactiveOpacity: inactiveOpacity,
                fullscreenOpacity: fullscreenOpacity,
                dimInactive: dimInactive, dimStrength: dimStrength,
                dimAround: dimAround, dimSpecial: dimSpecial,
                blurEnabled: blurEnabled, blurSize: blurSize, blurPasses: blurPasses,
                blurIgnoreOpacity: blurIgnoreOpacity,
                blurNewOptimizations: blurNewOptimizations,
                blurXray: blurXray, blurNoise: blurNoise,
                blurContrast: blurContrast, blurBrightness: blurBrightness,
                blurVibrancy: blurVibrancy, blurVibrancyDarkness: blurVibrancyDarkness,
                blurSpecial: blurSpecial, blurPopups: blurPopups,
                shadowEnabled: shadowEnabled, shadowRange: shadowRange,
                shadowRenderPower: shadowRenderPower,
                shadowIgnoreWindow: shadowIgnoreWindow,
                shadowOffset: shadowOffset, shadowScale: shadowScale,
                shadowColor: shadowColor, shadowColorInactive: shadowColorInactive
            },
            // v6.16.0 — battery + power profile + lid behavior
            // v6.16.1 — + gaming boost persistence
            system: {
                batteryDisplayMode: batteryDisplayMode,
                batteryWarnThreshold: batteryWarnThreshold,
                batteryCriticalThreshold: batteryCriticalThreshold,
                powerProfile: powerProfile,
                gamingBoostActive: gamingBoostActive,
                gamingBoostPreProfile: gamingBoostPreProfile,
                gpuMode: gpuMode,
                smartGamingDetect: smartGamingDetect,
                lidCloseBehavior: lidCloseBehavior
            }
        }
        const json = JSON.stringify(state, null, 2)
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSVEOF'\n" + json + "\nZSVEOF"]
        saver.running = true
        dirty = false
    }

    Process { id: saver; running: false }

    function loadFromJson(text: string) {
        if (!text) return
        try {
            const s = JSON.parse(text)
            const g = s.general || {}
            if (g.gapsIn !== undefined) gapsIn = g.gapsIn
            if (g.gapsOut !== undefined) gapsOut = g.gapsOut
            if (g.borderSize !== undefined) borderSize = g.borderSize
            if (typeof g.resizeOnBorder === "boolean") resizeOnBorder = g.resizeOnBorder
            if (g.extendBorderGrabArea !== undefined) extendBorderGrabArea = g.extendBorderGrabArea
            if (typeof g.hoverIconOnBorder === "boolean") hoverIconOnBorder = g.hoverIconOnBorder
            if (g.activeBorderColor) activeBorderColor = g.activeBorderColor
            if (g.inactiveBorderColor) inactiveBorderColor = g.inactiveBorderColor
            if (g.layout) layout = g.layout
            if (typeof g.allowTearing === "boolean") allowTearing = g.allowTearing
            if (typeof g.snapEnabled === "boolean") snapEnabled = g.snapEnabled
            if (g.snapWindowGap !== undefined) snapWindowGap = g.snapWindowGap
            if (g.snapMonitorGap !== undefined) snapMonitorGap = g.snapMonitorGap
            if (g.snapBorderOverlap !== undefined) snapBorderOverlap = g.snapBorderOverlap
            if (typeof g.snapRespectGaps === "boolean") snapRespectGaps = g.snapRespectGaps

            const d = s.decoration || {}
            if (d.rounding !== undefined) rounding = d.rounding
            if (d.roundingPower !== undefined) roundingPower = d.roundingPower
            if (d.activeOpacity !== undefined) activeOpacity = d.activeOpacity
            if (d.inactiveOpacity !== undefined) inactiveOpacity = d.inactiveOpacity
            if (d.fullscreenOpacity !== undefined) fullscreenOpacity = d.fullscreenOpacity
            if (typeof d.dimInactive === "boolean") dimInactive = d.dimInactive
            if (d.dimStrength !== undefined) dimStrength = d.dimStrength
            if (d.dimAround !== undefined) dimAround = d.dimAround
            if (d.dimSpecial !== undefined) dimSpecial = d.dimSpecial
            if (typeof d.blurEnabled === "boolean") blurEnabled = d.blurEnabled
            if (d.blurSize !== undefined) blurSize = d.blurSize
            if (d.blurPasses !== undefined) blurPasses = d.blurPasses
            if (typeof d.blurIgnoreOpacity === "boolean") blurIgnoreOpacity = d.blurIgnoreOpacity
            if (typeof d.blurNewOptimizations === "boolean") blurNewOptimizations = d.blurNewOptimizations
            if (typeof d.blurXray === "boolean") blurXray = d.blurXray
            if (d.blurNoise !== undefined) blurNoise = d.blurNoise
            if (d.blurContrast !== undefined) blurContrast = d.blurContrast
            if (d.blurBrightness !== undefined) blurBrightness = d.blurBrightness
            if (d.blurVibrancy !== undefined) blurVibrancy = d.blurVibrancy
            if (d.blurVibrancyDarkness !== undefined) blurVibrancyDarkness = d.blurVibrancyDarkness
            if (typeof d.blurSpecial === "boolean") blurSpecial = d.blurSpecial
            if (typeof d.blurPopups === "boolean") blurPopups = d.blurPopups
            if (typeof d.shadowEnabled === "boolean") shadowEnabled = d.shadowEnabled
            if (d.shadowRange !== undefined) shadowRange = d.shadowRange
            if (d.shadowRenderPower !== undefined) shadowRenderPower = d.shadowRenderPower
            if (typeof d.shadowIgnoreWindow === "boolean") shadowIgnoreWindow = d.shadowIgnoreWindow
            if (d.shadowOffset) shadowOffset = d.shadowOffset
            if (d.shadowScale !== undefined) shadowScale = d.shadowScale
            if (d.shadowColor) shadowColor = d.shadowColor
            if (d.shadowColorInactive) shadowColorInactive = d.shadowColorInactive

            // v6.16.0 — system block (battery + power profile + lid)
            // v6.16.1 — + gaming boost persistence
            const sys = s.system || {}
            if (sys.batteryDisplayMode) batteryDisplayMode = sys.batteryDisplayMode
            if (typeof sys.batteryWarnThreshold === "number") batteryWarnThreshold = sys.batteryWarnThreshold
            if (typeof sys.batteryCriticalThreshold === "number") batteryCriticalThreshold = sys.batteryCriticalThreshold
            if (sys.powerProfile) powerProfile = sys.powerProfile
            if (typeof sys.gamingBoostActive === "boolean") gamingBoostActive = sys.gamingBoostActive
            if (sys.gamingBoostPreProfile) gamingBoostPreProfile = sys.gamingBoostPreProfile
            if (sys.gpuMode) gpuMode = sys.gpuMode
            // v6.16.4.12.7 (Tachiagari): smart gaming detect persistence
            if (typeof sys.smartGamingDetect === "boolean") smartGamingDetect = sys.smartGamingDetect
            if (sys.lidCloseBehavior) lidCloseBehavior = sys.lidCloseBehavior

            console.log("[SettingsStateV2] Loaded from JSON")
        } catch(e) {
            console.error("[SettingsStateV2] Parse error:", e)
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        // v6.15.1: onLoaded moved to Connections block below for
        // apply-to-Hyprland logic. Do not load here.
    }

    // ─────────────────────────────────────────────────────────────
    // READ CURRENT VALUES from Hyprland
    // ─────────────────────────────────────────────────────────────

    function readFromHyprland() {
        hyprReader.command = ["bash", "-c",
            "echo '{'; " +
            // general
            "echo '\"gaps_in\":'; hyprctl getoption general:gaps_in -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"gaps_out\":'; hyprctl getoption general:gaps_out -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"border_size\":'; hyprctl getoption general:border_size -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"resize_on_border\":'; hyprctl getoption general:resize_on_border -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"extend_border_grab_area\":'; hyprctl getoption general:extend_border_grab_area -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"hover_icon_on_border\":'; hyprctl getoption general:hover_icon_on_border -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"layout\":'; hyprctl getoption general:layout -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"allow_tearing\":'; hyprctl getoption general:allow_tearing -j 2>/dev/null || echo '{}'; echo ','; " +
            // decoration
            "echo '\"rounding\":'; hyprctl getoption decoration:rounding -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"rounding_power\":'; hyprctl getoption decoration:rounding_power -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"active_opacity\":'; hyprctl getoption decoration:active_opacity -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"inactive_opacity\":'; hyprctl getoption decoration:inactive_opacity -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"fullscreen_opacity\":'; hyprctl getoption decoration:fullscreen_opacity -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"dim_inactive\":'; hyprctl getoption decoration:dim_inactive -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"dim_strength\":'; hyprctl getoption decoration:dim_strength -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_enabled\":'; hyprctl getoption decoration:blur:enabled -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_size\":'; hyprctl getoption decoration:blur:size -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_passes\":'; hyprctl getoption decoration:blur:passes -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_new_optimizations\":'; hyprctl getoption decoration:blur:new_optimizations -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"blur_xray\":'; hyprctl getoption decoration:blur:xray -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"shadow_enabled\":'; hyprctl getoption decoration:shadow:enabled -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"shadow_range\":'; hyprctl getoption decoration:shadow:range -j 2>/dev/null || echo '{}'; echo ','; " +
            "echo '\"shadow_render_power\":'; hyprctl getoption decoration:shadow:render_power -j 2>/dev/null || echo '{}'; " +
            "echo '}'"]
        hyprReader.running = true
    }

    Process {
        id: hyprReader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    // helpers
                    function geti(k) { return d[k] && d[k].int !== undefined ? d[k].int : null }
                    function getf(k) { return d[k] && d[k].float !== undefined ? d[k].float : null }
                    function getb(k) { return d[k] && d[k].set !== undefined ? d[k].set : null }
                    function gets(k) { return d[k] && d[k].str !== undefined ? d[k].str : null }

                    // general
                    if (geti("gaps_in") !== null) root.gapsIn = geti("gaps_in")
                    if (geti("gaps_out") !== null) root.gapsOut = geti("gaps_out")
                    if (geti("border_size") !== null) root.borderSize = geti("border_size")
                    if (getb("resize_on_border") !== null) root.resizeOnBorder = getb("resize_on_border")
                    if (geti("extend_border_grab_area") !== null) root.extendBorderGrabArea = geti("extend_border_grab_area")
                    if (getb("hover_icon_on_border") !== null) root.hoverIconOnBorder = getb("hover_icon_on_border")
                    const lay = gets("layout")
                    if (lay) root.layout = lay
                    if (getb("allow_tearing") !== null) root.allowTearing = getb("allow_tearing")

                    // decoration
                    if (geti("rounding") !== null) root.rounding = geti("rounding")
                    if (getf("rounding_power") !== null) root.roundingPower = getf("rounding_power")
                    if (getf("active_opacity") !== null) root.activeOpacity = getf("active_opacity")
                    if (getf("inactive_opacity") !== null) root.inactiveOpacity = getf("inactive_opacity")
                    if (getf("fullscreen_opacity") !== null) root.fullscreenOpacity = getf("fullscreen_opacity")
                    if (getb("dim_inactive") !== null) root.dimInactive = getb("dim_inactive")
                    if (getf("dim_strength") !== null) root.dimStrength = getf("dim_strength")
                    if (getb("blur_enabled") !== null) root.blurEnabled = getb("blur_enabled")
                    if (geti("blur_size") !== null) root.blurSize = geti("blur_size")
                    if (geti("blur_passes") !== null) root.blurPasses = geti("blur_passes")
                    if (getb("blur_new_optimizations") !== null) root.blurNewOptimizations = getb("blur_new_optimizations")
                    if (getb("blur_xray") !== null) root.blurXray = getb("blur_xray")
                    if (getb("shadow_enabled") !== null) root.shadowEnabled = getb("shadow_enabled")
                    if (geti("shadow_range") !== null) root.shadowRange = geti("shadow_range")
                    if (geti("shadow_render_power") !== null) root.shadowRenderPower = geti("shadow_render_power")

                    root.initialized = true
                    root.saveState()
                    console.log("[SettingsStateV2] Read from Hyprland OK, gaps=" + root.gapsIn + "/" + root.gapsOut)
                } catch(e) {
                    console.log("[SettingsStateV2] hyprctl read fallback (not in Hyprland?):", e)
                    root.initialized = true
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // DEFAULTS
    // ─────────────────────────────────────────────────────────────

    function resetGeneralDefaults() {
        gapsIn = 5; gapsOut = 20; borderSize = 2
        resizeOnBorder = false
        extendBorderGrabArea = 15
        hoverIconOnBorder = true
        activeBorderColor = "#33ccffff"
        inactiveBorderColor = "#595959aa"
        layout = "dwindle"; allowTearing = false
        snapEnabled = false; snapWindowGap = 10; snapMonitorGap = 10
        snapBorderOverlap = 0; snapRespectGaps = false

        hyprProc.command = ["hyprctl", "--batch",
            "keyword general:gaps_in 5;" +
            "keyword general:gaps_out 20;" +
            "keyword general:border_size 2;" +
            "keyword general:resize_on_border false;" +
            "keyword general:extend_border_grab_area 15;" +
            "keyword general:hover_icon_on_border true;" +
            "keyword general:col.active_border rgba(33ccffff);" +
            "keyword general:col.inactive_border rgba(595959aa);" +
            "keyword general:layout dwindle;" +
            "keyword general:allow_tearing false;" +
            "keyword general:snap:enabled false"]
        hyprProc.running = true
        saveState()
    }

    function resetDecorationDefaults() {
        rounding = 10; roundingPower = 2.0
        activeOpacity = 1.0; inactiveOpacity = 0.95; fullscreenOpacity = 1.0
        dimInactive = false; dimStrength = 0.5; dimAround = 0.4; dimSpecial = 0.2
        blurEnabled = true; blurSize = 8; blurPasses = 2
        blurIgnoreOpacity = true; blurNewOptimizations = true; blurXray = false
        blurNoise = 0.0117; blurContrast = 0.8916; blurBrightness = 0.8172
        blurVibrancy = 0.1696; blurVibrancyDarkness = 0.0
        blurSpecial = false; blurPopups = false
        shadowEnabled = true; shadowRange = 4; shadowRenderPower = 3
        shadowIgnoreWindow = true; shadowOffset = "0 0"; shadowScale = 1.0
        shadowColor = "#1a1a1aee"; shadowColorInactive = "#1a1a1aee"

        hyprProc.command = ["hyprctl", "--batch",
            "keyword decoration:rounding 10;" +
            "keyword decoration:rounding_power 2.0;" +
            "keyword decoration:active_opacity 1.0;" +
            "keyword decoration:inactive_opacity 0.95;" +
            "keyword decoration:fullscreen_opacity 1.0;" +
            "keyword decoration:dim_inactive false;" +
            "keyword decoration:dim_strength 0.5;" +
            "keyword decoration:blur:enabled true;" +
            "keyword decoration:blur:size 8;" +
            "keyword decoration:blur:passes 2;" +
            "keyword decoration:blur:new_optimizations true;" +
            "keyword decoration:shadow:enabled true;" +
            "keyword decoration:shadow:range 4;" +
            "keyword decoration:shadow:render_power 3"]
        hyprProc.running = true
        saveState()
    }

    // ─────────────────────────────────────────────────────────────
    // APPLY SAVED STATE TO HYPRLAND
    // v6.15.1: Called after loadFromJson to push saved values back
    // to Hyprland. Without this, Hyprland uses defaults from
    // hyprland.conf and the user's saved settings are ignored.
    // ─────────────────────────────────────────────────────────────
    function applyToHyprland() {
        // v6.15.6: Expanded to cover the FULL set of V2 properties.
        // Previously this function only wrote ~24 keywords — omitting the
        // 4 snap.* keywords and ~10 blur/shadow secondary keywords. On
        // startup / after theme reload, those omitted properties silently
        // reverted to whatever hyprland.conf (or hyprctl defaults) had,
        // wiping the user's configured snap:window_gap / snap:monitor_gap
        // / snap:respect_gaps values + secondary blur/shadow tuning.
        //
        // Paul reported this specifically for snap gaps resetting after
        // theme changes. Theme change doesn't directly touch Hyprland,
        // but shell reload chains can cause SettingsStateV2 to re-apply,
        // and the omitted properties were never re-asserted — first time
        // they get written was never, so Hyprland kept its config defaults.
        var batch = ""
            + "keyword general:gaps_in " + gapsIn + ";"
            + "keyword general:gaps_out " + gapsOut + ";"
            + "keyword general:border_size " + borderSize + ";"
            + "keyword general:resize_on_border " + (resizeOnBorder ? "true" : "false") + ";"
            + "keyword general:extend_border_grab_area " + extendBorderGrabArea + ";"
            + "keyword general:hover_icon_on_border " + (hoverIconOnBorder ? "true" : "false") + ";"
            + "keyword general:col.active_border " + hexToHyprRgba(activeBorderColor) + ";"
            + "keyword general:col.inactive_border " + hexToHyprRgba(inactiveBorderColor) + ";"
            + "keyword general:layout " + layout + ";"
            + "keyword general:allow_tearing " + (allowTearing ? "true" : "false") + ";"
            // v6.15.6: snap.* — previously missing, the whole reason
            // snap_window_gap / snap_monitor_gap / snap_respect_gaps
            // "disappeared" after theme reload.
            + "keyword general:snap:enabled " + (snapEnabled ? "true" : "false") + ";"
            + "keyword general:snap:window_gap " + snapWindowGap + ";"
            + "keyword general:snap:monitor_gap " + snapMonitorGap + ";"
            + "keyword general:snap:border_overlap " + snapBorderOverlap + ";"
            + "keyword general:snap:respect_gaps " + (snapRespectGaps ? "true" : "false") + ";"
            // decoration
            + "keyword decoration:rounding " + rounding + ";"
            + "keyword decoration:rounding_power " + roundingPower + ";"
            + "keyword decoration:active_opacity " + activeOpacity + ";"
            + "keyword decoration:inactive_opacity " + inactiveOpacity + ";"
            + "keyword decoration:fullscreen_opacity " + fullscreenOpacity + ";"
            + "keyword decoration:dim_inactive " + (dimInactive ? "true" : "false") + ";"
            + "keyword decoration:dim_strength " + dimStrength + ";"
            + "keyword decoration:dim_special " + dimSpecial + ";"
            // v6.15.6: blur.* — added missing secondary properties
            + "keyword decoration:blur:enabled " + (blurEnabled ? "true" : "false") + ";"
            + "keyword decoration:blur:size " + blurSize + ";"
            + "keyword decoration:blur:passes " + blurPasses + ";"
            + "keyword decoration:blur:ignore_opacity " + (blurIgnoreOpacity ? "true" : "false") + ";"
            + "keyword decoration:blur:new_optimizations " + (blurNewOptimizations ? "true" : "false") + ";"
            + "keyword decoration:blur:xray " + (blurXray ? "true" : "false") + ";"
            + "keyword decoration:blur:noise " + blurNoise + ";"
            + "keyword decoration:blur:contrast " + blurContrast + ";"
            + "keyword decoration:blur:brightness " + blurBrightness + ";"
            + "keyword decoration:blur:vibrancy " + blurVibrancy + ";"
            + "keyword decoration:blur:vibrancy_darkness " + blurVibrancyDarkness + ";"
            + "keyword decoration:blur:special " + (blurSpecial ? "true" : "false") + ";"
            + "keyword decoration:blur:popups " + (blurPopups ? "true" : "false") + ";"
            // v6.15.6: shadow.* — added missing secondary properties
            + "keyword decoration:shadow:enabled " + (shadowEnabled ? "true" : "false") + ";"
            + "keyword decoration:shadow:range " + shadowRange + ";"
            + "keyword decoration:shadow:render_power " + shadowRenderPower + ";"
            + "keyword decoration:shadow:ignore_window " + (shadowIgnoreWindow ? "true" : "false") + ";"
            + "keyword decoration:shadow:offset " + shadowOffset + ";"
            + "keyword decoration:shadow:scale " + shadowScale + ";"
            + "keyword decoration:shadow:color " + hexToHyprRgba(shadowColor) + ";"
            + "keyword decoration:shadow:color_inactive " + hexToHyprRgba(shadowColorInactive)

        hyprProc.command = ["hyprctl", "--batch", batch]
        hyprProc.running = true
        console.log("[SettingsStateV2] Applied full state to Hyprland (v6.15.6 expanded batch)")
    }

    // ─────────────────────────────────────────────────────────────
    // INIT
    // v6.15.1: If we have saved JSON, load it and push values TO
    // Hyprland. Only read FROM Hyprland on first run (no JSON).
    // Previous bug: readFromHyprland() always ran and overwrote
    // saved JSON values with Hyprland defaults from hyprland.conf.
    // ─────────────────────────────────────────────────────────────

    property bool _jsonLoaded: false

    // ─────────────────────────────────────────────────────────────
    // v6.16.4.12.7 (Tachiagari) — Smart Gaming Detection daemon
    // lifecycle. When `smartGamingDetect` flips true, spawn the
    // watcher script as a detached background process. When it
    // flips false, send SIGTERM to whatever the script's PID file
    // remembers (the script's EXIT trap then flushes any active
    // boost back to OFF before exiting cleanly).
    //
    // We deliberately do NOT auto-launch on startup just because
    // the saved value is true — startup launch is gated on the
    // `_jsonLoaded` guard via Component.onCompleted below to avoid
    // double-spawning if this Singleton is constructed before the
    // saved JSON has had a chance to load.
    // ─────────────────────────────────────────────────────────────
    Process { id: smartGameWatcherProc; running: false }

    function _startSmartGameWatcher() {
        smartGameWatcherProc.command = ["bash", "-c",
            "pkill -f zen-smart-game-watcher.sh 2>/dev/null; "
            + "sleep 0.2; "
            + "nohup \"$HOME/.local/bin/zen-smart-game-watcher.sh\" "
            + ">> \"$HOME/.cache/zen-smart-game-watcher.log\" 2>&1 &"]
        smartGameWatcherProc.running = true
    }
    function _stopSmartGameWatcher() {
        smartGameWatcherProc.command = ["bash", "-c",
            "pkill -TERM -f zen-smart-game-watcher.sh 2>/dev/null || true"]
        smartGameWatcherProc.running = true
    }

    onSmartGamingDetectChanged: {
        if (!initialized) return    // wait for init to settle
        if (smartGamingDetect) {
            _startSmartGameWatcher()
        } else {
            _stopSmartGameWatcher()
        }
        markDirty()
    }

    Component.onCompleted: {
        stateFile.reload()
    }

    // FileView.onLoaded fires after stateFile.reload() — check if
    // JSON had actual data. If yes → apply to Hyprland. If empty
    // (first run) → read current Hyprland values as seed.
    Connections {
        target: stateFile
        function onLoaded() {
            const text = stateFile.text()
            if (text && text.trim().length > 2) {
                root.loadFromJson(text)
                root._jsonLoaded = true
                // Push saved values to Hyprland so they take effect
                Qt.callLater(root.applyToHyprland)
            } else {
                // First run — no saved state, read from Hyprland
                root._jsonLoaded = false
                Qt.callLater(root.readFromHyprland)
            }
            root.initialized = true

            // v6.16.4.12.7 (Tachiagari): respect saved smartGamingDetect
            // on startup. If the user had it on across sessions, restart
            // the watcher daemon now that initialized=true (so the
            // onSmartGamingDetectChanged handler also works for live
            // toggling from the panel).
            if (root.smartGamingDetect) {
                Qt.callLater(root._startSmartGameWatcher)
            }
        }
    }
}
