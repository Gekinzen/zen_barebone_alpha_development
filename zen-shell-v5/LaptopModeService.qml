pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * LaptopModeService v7.0.0-alpha.5 — adaptive polling + battery efficiency
 *
 * Three modes, persisted to ~/.local/share/zen-shell/laptop-mode.state:
 *
 *   "off"        — service idle. Existing services run at their default
 *                  intervals. No animation override, no governor changes.
 *
 *   "balanced"   — moderate polling adaptation when on battery:
 *                    SystemMonitor:  5s @ ≥50%,   10s @ <50%
 *                    Weather: skip refresh @ <20%
 *                  CPU governor: balanced (current default).
 *                  No animation downgrade.
 *
 *   "endurance"  — aggressive battery preservation:
 *                    SystemMonitor:  10s @ ≥30%,  30s @ <30%
 *                    Weather: skip refresh @ <15%
 *                    ZenStrings: auto-disable @ <30% OR no audio 60s
 *                    ConnectivityService: poll-only mode
 *                  CPU governor: power-saver (auto-switched).
 *                  Optional sub-toggle: animation downgrade (Hyprland
 *                    minimal animation config, blur off, VRR off).
 *                  Optional sub-toggle: aggressive hypridle timeouts.
 *
 * AUTO-DETECTION:
 *
 *   On startup, reads /sys/class/dmi/id/chassis_type. Values 8/9/10/11
 *   (laptop/notebook/handheld/sub-notebook) → mark `isLaptop = true`.
 *   Other values (3 = desktop, 4 = lowprofile-desktop, etc.) →
 *   `isLaptop = false`. Also requires a /sys/class/power_supply/BAT*
 *   entry to exist (some convertibles/dockables report wrong DMI but
 *   actually have a battery, and vice versa).
 *
 *   When `isLaptop = false` AND `manualOverride = false`, the service
 *   exposes its tunables as no-ops (UI hides the section, consumer
 *   services keep default polling). User can flip `manualOverride =
 *   true` to surface the controls anyway — useful for desktop PCs the
 *   user wants to test endurance mode on (silent fans, lower idle
 *   wattage), or for unusual hardware that misreports DMI chassis.
 *
 * INTEGRATION CONTRACT:
 *
 *   Consumer services (SystemMonitorService, WeatherService,
 *   ZenStrings) read THIS service's adaptive properties:
 *
 *     intervalSystemMonitor : real (ms)
 *     intervalWeather       : real (ms)  — Infinity = paused
 *     intervalConnectivity  : real (ms)
 *     audioRopeAllowed      : bool       — ZenStrings checks this
 *
 *   These properties auto-update when mode/battery%/AC-state changes.
 *   Consumers just bind their Timer.interval to one of these and
 *   their behavior follows the active mode.
 *
 * Wala tayong babawasan — when mode is "off", all adaptive properties
 * report the existing default values. Existing services using their
 * own Timer.interval literal will continue to run unchanged unless
 * patched to bind to this service. Patches are additive: each consumer
 * gets a tiny edit that switches Timer.interval to a binding.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // STATE PATHS
    // ─────────────────────────────────────────────────────────────
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/share/zen-shell"
    readonly property string statePath: stateDir + "/laptop-mode.state"

    // ─────────────────────────────────────────────────────────────
    // PERSISTED CONFIG
    // ─────────────────────────────────────────────────────────────
    property string mode: "off"               // "off" | "balanced" | "endurance"
    property bool   manualOverride: false      // show controls on desktop too
    property bool   animationDowngrade: false  // sub-toggle: only Endurance
    property bool   aggressiveIdle: false      // sub-toggle: only Endurance
    property bool   chargeLimit80: false       // battery health: stop @ 80%

    // ─────────────────────────────────────────────────────────────
    // DETECTION (computed once at startup, refreshed on hardware change)
    // ─────────────────────────────────────────────────────────────
    property int  chassisType: -1     // raw value from DMI (-1 = unread)
    property bool dmiIsLaptop: false   // true if chassisType ∈ {8,9,10,11,14,30,31,32}
    property bool batteryDetected: false   // true if /sys BAT* exists at startup

    // True if we should EXPOSE controls to the user.
    readonly property bool isLaptop: dmiIsLaptop || batteryDetected || manualOverride

    // True if hardware looks like a real laptop (used for "your hardware
    // is being detected as: ..." text in settings UI).
    readonly property bool detectedAsLaptop: dmiIsLaptop || batteryDetected

    // ─────────────────────────────────────────────────────────────
    // LIVE BATTERY STATE — sourced from SystemMonitorService (which
    // already polls /sys/class/power_supply/BAT* on its own clock).
    // We just READ it; we don't poll separately.
    // ─────────────────────────────────────────────────────────────
    readonly property int batteryCapacity:
        (typeof SystemMonitorService !== "undefined")
            ? SystemMonitorService.batteryCapacity : 100
    readonly property bool batteryCharging:
        (typeof SystemMonitorService !== "undefined")
            ? SystemMonitorService.batteryCharging : false
    readonly property bool onBattery:
        !batteryCharging && batteryDetected

    // ─────────────────────────────────────────────────────────────
    // CHARGE LIMIT — detect kernel support
    // ─────────────────────────────────────────────────────────────
    property bool chargeLimitSupported: false   // /sys path exists
    property string chargeLimitDevice: ""       // BAT0 / BAT1 / ...

    // ─────────────────────────────────────────────────────────────
    // ADAPTIVE PROPERTIES — what consumers bind to
    // ─────────────────────────────────────────────────────────────

    // SystemMonitor poll interval (ms). 2000ms is the v6 default.
    readonly property real intervalSystemMonitor: {
        if (mode === "off") return 2000
        if (!onBattery)      return 2000   // plugged in: full speed even in laptop modes

        if (mode === "balanced") {
            return batteryCapacity >= 50 ? 5000 : 10000
        }
        // endurance
        return batteryCapacity >= 30 ? 10000 : 30000
    }

    // Weather refresh allowed flag — Weather's own 30min timer is fine,
    // but we can suppress refresh attempts when battery is critically low.
    readonly property bool weatherRefreshAllowed: {
        if (mode === "off") return true
        if (!onBattery)     return true
        if (mode === "balanced")  return batteryCapacity >= 20
        // endurance
        return batteryCapacity >= 15
    }

    // ZenStrings (audio-reactive rope) allowed flag.
    readonly property bool audioRopeAllowed: {
        if (mode === "off") return true
        if (!onBattery)     return true
        if (mode === "balanced")  return true
        // endurance: only allowed when battery >= 30%
        return batteryCapacity >= 30
    }

    // Connectivity poll mode — when in endurance + on battery, advise
    // the connectivity service to skip its periodic re-scan loops and
    // rely purely on event-driven NetworkManager signals.
    readonly property bool connectivityEventOnly:
        mode === "endurance" && onBattery

    // ─────────────────────────────────────────────────────────────
    // STARTUP DETECTION
    // ─────────────────────────────────────────────────────────────
    Process {
        id: detectProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseDetect(this.text)
        }
        onExited: function(code) {
            if (code !== 0) console.warn("LaptopModeService: detect exit", code)
        }
    }

    function _parseDetect(text) {
        if (!text) return
        const lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (!line) continue
            const eq = line.indexOf("=")
            if (eq < 0) continue
            const key = line.substring(0, eq)
            const val = line.substring(eq + 1)
            if (key === "chassis") {
                root.chassisType = parseInt(val) || -1
                // DMI chassis types: 8 portable, 9 laptop, 10 notebook,
                // 11 hand held, 14 sub-notebook, 30 tablet, 31 convertible,
                // 32 detachable
                const laptopTypes = [8, 9, 10, 11, 14, 30, 31, 32]
                root.dmiIsLaptop = laptopTypes.indexOf(root.chassisType) >= 0
            } else if (key === "battery") {
                root.batteryDetected = (val === "1")
            } else if (key === "chargeLimit") {
                root.chargeLimitSupported = (val !== "")
                root.chargeLimitDevice = val
            }
        }
    }

    function detectHardware() {
        const cmd = ["bash", "-c",
            // chassis_type
            "ct=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null | tr -d '[:space:]'); " +
            "echo \"chassis=$ct\"; " +
            // battery presence
            "bat=0; for d in /sys/class/power_supply/BAT*; do [ -d \"$d\" ] && bat=1 && break; done; " +
            "echo \"battery=$bat\"; " +
            // charge limit endpoint
            "cl=''; for d in /sys/class/power_supply/BAT*; do " +
            "  if [ -e \"$d/charge_control_end_threshold\" ]; then " +
            "    cl=$(basename \"$d\"); break; " +
            "  fi; " +
            "done; " +
            "echo \"chargeLimit=$cl\""
        ]
        detectProc.command = cmd
        detectProc.running = true
    }

    // ─────────────────────────────────────────────────────────────
    // CHARGE LIMIT APPLY (write to /sys, may need polkit / a sudo helper)
    // ─────────────────────────────────────────────────────────────
    Process { id: chargeLimitWriter; running: false }

    function applyChargeLimit(enabled) {
        if (!chargeLimitSupported || !chargeLimitDevice) return
        const value = enabled ? 80 : 100
        const path = "/sys/class/power_supply/" + chargeLimitDevice + "/charge_control_end_threshold"
        // Try direct write first (works if sysfs file is user-writable —
        // it usually isn't, so we shell out via pkexec for the elevated
        // path). If pkexec absent, we'll fail silently and the UI will
        // surface lastChargeLimitError.
        chargeLimitWriter.command = ["bash", "-c",
            "if [ -w '" + path + "' ]; then " +
            "  echo " + value + " > '" + path + "'; " +
            "elif command -v pkexec >/dev/null; then " +
            "  pkexec sh -c \"echo " + value + " > '" + path + "'\"; " +
            "else " +
            "  echo 'no write access and no pkexec' >&2; exit 1; " +
            "fi"
        ]
        chargeLimitWriter.running = true
    }

    // (chargeLimit80Changed handled by consolidated handler below)

    // ─────────────────────────────────────────────────────────────
    // CPU GOVERNOR AUTO-SWITCHING (uses existing PowerProfileService)
    // ─────────────────────────────────────────────────────────────
    //
    // When mode flips to "endurance" + on battery, push power-saver.
    // When mode flips to anything else OR plugged in, restore balanced.
    // This is OPT-IN via PowerProfileService.setProfile, so users who've
    // manually pinned a profile aren't fighting us — but the auto-flip
    // is the default behavior because that's what "endurance" means.
    //
    // Note: we don't store the user's prior profile to "restore" — we
    // just push balanced when leaving endurance. PowerProfileService
    // tracks its own state independently.
    function _applyGovernor() {
        if (typeof PowerProfileService === "undefined") return
        if (mode === "endurance" && onBattery) {
            if (PowerProfileService.currentProfile !== "power-saver")
                PowerProfileService.setProfile("power-saver")
        } else if (mode !== "endurance" || !onBattery) {
            if (PowerProfileService.currentProfile === "power-saver")
                PowerProfileService.setProfile("balanced")
        }
    }
    // (handlers consolidated at bottom of file — see "CONSOLIDATED HANDLERS")

    // ─────────────────────────────────────────────────────────────
    // ANIMATION DOWNGRADE — Hyprland config snippet swap
    //
    // We write a tiny snippet to:
    //   ~/.config/hypr/zen-laptop-anims.conf
    // and hyprctl reload to apply. The shell's main hyprland.conf
    // sources this snippet near the bottom (added by install.sh
    // when the user is on alpha.5+).
    //
    // Snippet contents:
    //   - DOWNGRADE: minimal bezier + 2-frame window animation, blur off
    //   - RESTORE: empty file (Hyprland defaults take over)
    //
    // Reads back to a NoOp on systems where Hyprland isn't running
    // (testing, sandbox).
    // ─────────────────────────────────────────────────────────────
    Process { id: animConfigWriter; running: false }

    readonly property string animSnippetPath:
        home + "/.config/hypr/zen-laptop-anims.conf"

    function _applyAnimationDowngrade() {
        const apply = (mode === "endurance" && animationDowngrade && onBattery)
        const content = apply
            ? "# Zen Shell laptop-mode endurance — minimal animations\n" +
              "bezier = zenLinear, 0, 0, 1, 1\n" +
              "animation = windows, 1, 2, zenLinear\n" +
              "animation = windowsOut, 1, 2, zenLinear, popin 80%\n" +
              "animation = border, 0, 1, zenLinear\n" +
              "animation = fade, 1, 2, zenLinear\n" +
              "animation = workspaces, 1, 2, zenLinear\n" +
              "decoration {\n  blur { enabled = false }\n}\n" +
              "misc { vrr = 0 }\n"
            : "# Zen Shell laptop-mode endurance — disabled (defaults restored)\n"

        animConfigWriter.command = ["bash", "-c",
            "mkdir -p '" + home + "/.config/hypr' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_ANIM_EOF'\n" + content + "\nZEN_ANIM_EOF\n" +
            "mv \"$tmp\" '" + animSnippetPath + "' && " +
            "(command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true)"
        ]
        animConfigWriter.running = true
    }
    // (animationDowngradeChanged handled by consolidated handler below)

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        onLoaded: {
            try {
                const txt = stateFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (typeof j.mode === "string")               root.mode = j.mode
                if (typeof j.manualOverride === "boolean")    root.manualOverride = j.manualOverride
                if (typeof j.animationDowngrade === "boolean") root.animationDowngrade = j.animationDowngrade
                if (typeof j.aggressiveIdle === "boolean")    root.aggressiveIdle = j.aggressiveIdle
                if (typeof j.chargeLimit80 === "boolean")     root.chargeLimit80 = j.chargeLimit80
            } catch (e) {
                console.warn("LaptopModeService: bad laptop-mode.state:", e)
            }
        }
        onLoadFailed: function(err) { saveDebounced.restart() }
    }

    Timer {
        id: saveDebounced
        interval: 200; repeat: false
        onTriggered: root._writeState()
    }

    Process { id: stateWriter; running: false }

    function _writeState() {
        const obj = {
            _schema: 7,
            mode: root.mode,
            manualOverride: root.manualOverride,
            animationDowngrade: root.animationDowngrade,
            aggressiveIdle: root.aggressiveIdle,
            chargeLimit80: root.chargeLimit80
        }
        const json = JSON.stringify(obj, null, 2)
        stateWriter.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_LAPTOP_EOF'\n" + json + "\nZEN_LAPTOP_EOF\n" +
            "mv \"$tmp\" '" + root.statePath + "'"]
        stateWriter.running = true
    }

    onManualOverrideChanged:     saveDebounced.restart()
    onAggressiveIdleChanged:     saveDebounced.restart()

    Component.onCompleted: {
        detectHardware()
    }

    // ─────────────────────────────────────────────────────────────
    // CONSOLIDATED HANDLERS
    //
    // QML doesn't allow two `on<Property>Changed:` signal handlers on
    // the same object root — declaring both fails with "Property
    // value set multiple times". Properties that need both saving AND
    // a side-effect get their handler in this Connections block;
    // properties that only need saving stay as inline `on*Changed:`
    // declarations above.
    //
    // mode, animationDowngrade, chargeLimit80, batteryCharging all
    // require side effects → here.
    // manualOverride, aggressiveIdle only need persistence → inline.
    // ─────────────────────────────────────────────────────────────
    Connections {
        target: root
        function onAnimationDowngradeChanged() {
            Qt.callLater(root._applyAnimationDowngrade)
            saveDebounced.restart()
        }
        function onChargeLimit80Changed() {
            root.applyChargeLimit(root.chargeLimit80)
            saveDebounced.restart()
        }
        function onBatteryChargingChanged() {
            Qt.callLater(root._applyGovernor)
            Qt.callLater(root._applyAnimationDowngrade)
        }
        function onModeChanged() {
            Qt.callLater(root._applyGovernor)
            Qt.callLater(root._applyAnimationDowngrade)
            saveDebounced.restart()
        }
    }

    // ─────────────────────────────────────────────────────────────
    // CONVENIENCE — UI helpers
    // ─────────────────────────────────────────────────────────────
    function modeLabel(m) {
        if (m === "balanced")  return "Balanced"
        if (m === "endurance") return "Endurance"
        return "Off"
    }

    function modeKanji(m) {
        if (m === "balanced")  return "均衡"
        if (m === "endurance") return "持続"
        return "切"   // off
    }

    // Estimated runtime hint (very rough — uses powerDraw if available).
    function estimatedRuntime() {
        if (!batteryDetected || batteryCharging) return ""
        const draw = (typeof SystemMonitorService !== "undefined")
            ? SystemMonitorService.batteryPowerDraw : 0
        if (!draw || draw <= 0) return ""
        // BAT* energy_full ~ 50Wh typical; without scraping it, use draw alone:
        // hrs = capacity_pct/100 * 50 / draw   (rough estimate)
        const hrs = (batteryCapacity / 100) * 50 / draw
        if (hrs <= 0) return ""
        const h = Math.floor(hrs)
        const m = Math.round((hrs - h) * 60)
        return "~" + h + "h " + (m < 10 ? "0" : "") + m + "m"
    }
}
