pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * GPUSwitcherService v6.16.1 — GPU selection for app launches
 *
 * Controls which GPU next-launched apps should render on. Unlike
 * Hyprland's AQ_DRM_DEVICES (which switches the compositor's GPU),
 * this service targets APPLICATION launches — think of it as a
 * persistent "run next app on NVIDIA" switch.
 *
 * Modes:
 *   "auto"       → no env override, apps pick their default GPU
 *                  (usually integrated on laptops)
 *   "integrated" → force iGPU (AMD/Intel). Sets:
 *                    DRI_PRIME=0 (Mesa PRIME offload disabled)
 *                    __NV_PRIME_RENDER_OFFLOAD=0 (NVIDIA offload off)
 *   "dedicated"  → force dGPU (NVIDIA/AMD discrete). Sets:
 *                    DRI_PRIME=1 (Mesa PRIME offload)
 *                    __NV_PRIME_RENDER_OFFLOAD=1
 *                    __GLX_VENDOR_LIBRARY_NAME=nvidia
 *                    __VK_LAYER_NV_optimus=NVIDIA_only
 *   "auto-gaming" → auto + Gaming Boost detection. When a known game
 *                   process launches (Steam, Lutris, heroic, minecraft),
 *                   trigger Performance profile + AQ_DRM_DEVICES points
 *                   to dGPU. On game exit, restore.
 *
 * Writes env vars to: ~/.config/environment.d/zen-gpu.conf
 * which systemd sources for user sessions. Takes effect on next login.
 *
 * Also writes: ~/.local/bin/prime-run wrapper for one-shot launches
 * without relogin — `prime-run firefox` runs Firefox on dedicated GPU.
 *
 * Detects GPU topology on startup:
 *   - isMultiGpu: true if SystemMonitorService.gpuCount >= 2
 *   - hasNvidia, hasAmd, hasIntel flags for UI logic
 *
 * Emits swaync notification on every setMode() call.
 *
 * Wala tayong babawasan.
 */
Singleton {
    id: root

    // ── State ──
    property string currentMode: "auto"     // auto | integrated | dedicated | auto-gaming
    property bool isMultiGpu: false
    property bool hasNvidia: false
    property bool hasAmd: false
    property bool hasIntel: false

    // ── Paths ──
    readonly property string envDir:  Quickshell.env("HOME") + "/.config/environment.d"
    readonly property string envFile: envDir + "/zen-gpu.conf"
    readonly property string binDir:  Quickshell.env("HOME") + "/.local/bin"
    readonly property string primeRun: binDir + "/prime-run"

    // ── Gaming detection processes ──
    // Known process-name patterns that trigger auto-gaming boost.
    // Matched against `pgrep -fla` output.
    readonly property var gamingProcesses: [
        "steam", "steamwebhelper", "Lutris", "heroic",
        "minecraft", "dolphin-emu", "cemu", "rpcs3",
        "gamescope", "wine ", "proton"
    ]

    // ── Label helper ──
    function modeLabel(mode) {
        switch(mode) {
            case "auto":         return "Auto (default)"
            case "integrated":   return "Integrated GPU"
            case "dedicated":    return "Dedicated GPU"
            case "auto-gaming":  return "Auto + Gaming Boost"
        }
        return mode
    }

    function modeIcon(mode) {
        switch(mode) {
            case "auto":         return "\uf1eb"   // wifi → "auto pick"
            case "integrated":   return "\uf2db"   // microchip
            case "dedicated":    return "\uf1b2"   // cube → gpu
            case "auto-gaming":  return "\uf11b"   // gamepad
        }
        return "\uf128"
    }

    // ── Vendor detection from SystemMonitorService.gpus[] ──
    function _updateDetection() {
        const gpus = SystemMonitorService.gpus || []
        hasNvidia = gpus.some(g => g.type === "nvidia")
        hasAmd    = gpus.some(g => g.type === "amd")
        hasIntel  = gpus.some(g => g.type === "intel")
        isMultiGpu = gpus.length >= 2
    }

    Connections {
        target: SystemMonitorService
        function onGpusChanged() { root._updateDetection() }
    }

    // ── Set mode ──
    Process { id: setter;   running: false }
    Process { id: notifier; running: false }

    function setMode(mode) {
        if (mode !== "auto" && mode !== "integrated"
            && mode !== "dedicated" && mode !== "auto-gaming") {
            console.warn("[GPUSwitcherService] Invalid mode:", mode)
            return
        }
        root.currentMode = mode

        // Build env file contents
        var envContent = "# Zen Shell GPU Switcher — managed file (v6.16.1)\n"
                       + "# Mode: " + mode + "\n"
                       + "# Written: " + new Date().toISOString() + "\n\n"

        switch (mode) {
            case "integrated":
                envContent += "DRI_PRIME=0\n"
                envContent += "__NV_PRIME_RENDER_OFFLOAD=0\n"
                break
            case "dedicated":
                envContent += "DRI_PRIME=1\n"
                if (root.hasNvidia) {
                    envContent += "__NV_PRIME_RENDER_OFFLOAD=1\n"
                    envContent += "__GLX_VENDOR_LIBRARY_NAME=nvidia\n"
                    envContent += "__VK_LAYER_NV_optimus=NVIDIA_only\n"
                }
                break
            case "auto-gaming":
                // Auto mode with zen-game-watcher.sh monitoring
                envContent += "# Gaming watcher active — see ~/.local/bin/zen-game-watcher.sh\n"
                break
            case "auto":
            default:
                envContent += "# No overrides — apps use their default GPU\n"
                break
        }

        // Persist to SettingsStateV2 for restore on login
        if (typeof SettingsStateV2 !== "undefined") {
            SettingsStateV2.gpuMode = mode
            SettingsStateV2.markDirty()
        }

        // Write env file
        const safeEnv = envContent.replace(/'/g, "'\\''")
        setter.command = ["bash", "-c",
            "mkdir -p '" + envDir + "' && "
            + "cat > '" + envFile + "' << 'ZGSENV'\n"
            + envContent
            + "ZGSENV\n"
            + "chmod 644 '" + envFile + "'"]
        setter.running = true

        // Swaync notification
        var body = ""
        if (mode === "auto") body = "Apps will use their default GPU"
        else if (mode === "integrated") body = "Apps will use iGPU (DRI_PRIME=0)"
        else if (mode === "dedicated") body = "Apps will use dGPU (DRI_PRIME=1)"
        else if (mode === "auto-gaming") body = "Games detected → dGPU + Performance"

        notifier.command = ["bash", "-c",
            "notify-send -a 'Zen Shell' -i display -u normal "
            + "'GPU Switcher' "
            + "'" + modeLabel(mode) + " — " + body
            + "\n(Takes effect on next app launch)'"]
        notifier.running = true

        // Start or stop the game watcher
        if (mode === "auto-gaming") {
            watcherProc.command = ["bash", "-c",
                "pkill -f zen-game-watcher.sh 2>/dev/null; "
                + "nohup '" + binDir + "/zen-game-watcher.sh' "
                + ">/dev/null 2>&1 &"]
            watcherProc.running = true
        } else {
            watcherProc.command = ["bash", "-c", "pkill -f zen-game-watcher.sh 2>/dev/null; true"]
            watcherProc.running = true
        }
    }

    Process { id: watcherProc; running: false }

    // ── Restore on startup from SettingsStateV2 ──
    Timer {
        id: restoreTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            if (typeof SettingsStateV2 === "undefined") return
            const saved = SettingsStateV2.gpuMode || "auto"
            if (saved !== "auto") {
                root.currentMode = saved
                // Re-start game watcher if needed (don't re-fire notification
                // on every login — just silently reapply)
                if (saved === "auto-gaming") {
                    watcherProc.command = ["bash", "-c",
                        "pkill -f zen-game-watcher.sh 2>/dev/null; "
                        + "nohup '" + binDir + "/zen-game-watcher.sh' "
                        + ">/dev/null 2>&1 &"]
                    watcherProc.running = true
                }
            }
        }
    }

    Component.onCompleted: {
        _updateDetection()
        restoreTimer.start()
    }
}
