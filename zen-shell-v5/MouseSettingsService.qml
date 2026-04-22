pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * MouseSettingsService v6.16.2.3.2
 *
 * Live-applies mouse sensitivity / scroll factor / natural scroll via
 * `hyprctl keyword` AND persists the values to a conf file that
 * hyprland.conf sources. Two-tier write ensures changes are immediate
 * AND survive Hyprland restarts.
 *
 * Conf file: ~/.config/hypr/zen-mouse.conf
 *   general {
 *     # (nothing — mouse settings live in `input` section)
 *   }
 *   input {
 *       sensitivity     = 0.0
 *       scroll_factor   = 1.0
 *       natural_scroll  = false
 *   }
 *
 * hyprland.conf needs one line: `source = ~/.config/hypr/zen-mouse.conf`
 * install.sh ensures that's present (idempotent).
 *
 * Paths use $HOME via Quickshell.env — no hardcoded /home/<user>.
 */
Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string confPath: homeDir + "/.config/hypr/zen-mouse.conf"
    readonly property string statePath: homeDir + "/.config/quickshell/zen-shell/mouse-settings.json"

    // ── Live values (bound to sliders in UI) ──
    // sensitivity: -1.0 (slow) to +1.0 (fast). Hyprland default 0.
    property real sensitivity: 0.0
    // scroll_factor: 0.1 (very slow) to 3.0 (very fast). Hyprland default 1.
    property real scrollFactor: 1.0
    // natural_scroll: inverts scroll direction (macOS-style).
    property bool naturalScroll: false
    // Touchpad-specific natural scroll (separate hyprland key).
    property bool touchpadNaturalScroll: false

    property bool _loaded: false

    // ── Apply live via hyprctl + save ──
    function apply(persist) {
        if (!_loaded) return   // don't write before initial load finishes
        // Live apply via hyprctl keyword (zero-lag feedback on slider drag)
        applyProc.command = ["bash", "-c",
            "hyprctl keyword input:sensitivity "        + root._fmt(sensitivity)        + " >/dev/null 2>&1; " +
            "hyprctl keyword input:scroll_factor "      + root._fmt(scrollFactor)       + " >/dev/null 2>&1; " +
            "hyprctl keyword input:natural_scroll "     + (naturalScroll ? "true" : "false") + " >/dev/null 2>&1; " +
            "hyprctl keyword input:touchpad:natural_scroll " + (touchpadNaturalScroll ? "true" : "false") + " >/dev/null 2>&1; " +
            "true"]
        applyProc.running = true

        if (persist !== false) saveDebounce.restart()
    }

    function _fmt(v) {
        // hyprctl accepts decimals. Limit to 3 dp to avoid noise.
        return (Math.round(v * 1000) / 1000).toString()
    }

    Process { id: applyProc; running: false }

    // Debounce writes — a slider drag shouldn't fsync every frame.
    Timer {
        id: saveDebounce
        interval: 250
        repeat: false
        onTriggered: root._saveAll()
    }

    function _saveAll() {
        // Conf file (sourced by hyprland.conf — survives restart)
        const conf = "# Zen Shell v6.16.2.3.2 — managed mouse settings\n" +
                     "# Edit via Control Panel → Input, not by hand.\n" +
                     "input {\n" +
                     "    sensitivity     = " + _fmt(sensitivity) + "\n" +
                     "    scroll_factor   = " + _fmt(scrollFactor) + "\n" +
                     "    natural_scroll  = " + (naturalScroll ? "true" : "false") + "\n" +
                     "    touchpad {\n" +
                     "        natural_scroll = " + (touchpadNaturalScroll ? "true" : "false") + "\n" +
                     "    }\n" +
                     "}\n"
        const state = JSON.stringify({
            sensitivity: sensitivity,
            scrollFactor: scrollFactor,
            naturalScroll: naturalScroll,
            touchpadNaturalScroll: touchpadNaturalScroll
        }, null, 2)
        saveProc.command = ["bash", "-c",
            "mkdir -p \"$HOME/.config/hypr\" \"$HOME/.config/quickshell/zen-shell\"; " +
            "cat > \"" + confPath + "\" << 'ZSHCONF'\n" + conf + "ZSHCONF\n" +
            "cat > \"" + statePath + "\" << 'ZSHJSON'\n" + state + "\nZSHJSON"]
        saveProc.running = true
    }

    Process { id: saveProc; running: false
        // ─────────────────────────────────────────────────────────
        // v6.16.3.4.1 — Hyprland-auto-reload re-push (THE root fix)
        //
        // After we write zen-mouse.conf, Hyprland 0.40+ detects the
        // inotify change (because hyprland.conf has a `source =
        // ~/.config/hypr/zen-mouse.conf` line) and triggers an
        // INTERNAL `hyprctl reload`. That reload re-parses
        // hyprland.conf from scratch — which WIPES every runtime
        // hyprctl-keyword value not present in the conf files,
        // including the user's custom gaps_in / gaps_out / blur /
        // shadow / etc.
        //
        // V6.16.3.2.1 fixed the QML-side init bug (reading hyprctl
        // and overwriting saved state on cold start). It did NOT
        // and could NOT address this case, because the wiping
        // happens INSIDE Hyprland after a file write — no QML
        // singleton re-instantiation involved.
        //
        // Real fix: after our save process completes, wait long
        // enough for Hyprland's inotify-driven reload to land
        // (~250-400ms in practice on AMD/Intel; longer on slow
        // disks), then re-push BOTH SettingsState V1 + V2's saved
        // values. Both are idempotent — re-pushing values that are
        // already correct is a no-op at the hyprctl level.
        //
        // This is symmetrical to the existing pattern in
        // AnimationsPage.qml v6.16.1.6 and BatterySettingsPage.qml
        // v6.16.1.6 — both of those re-push after their own
        // explicit hyprctl reload calls. Mouse changes never had
        // an explicit reload here in QML, so the pattern was
        // missed; the reload was happening transparently in
        // Hyprland.
        // ─────────────────────────────────────────────────────────
        onExited: rePushTimer.restart()
    }

    Timer {
        id: rePushTimer
        interval: 400          // covers ~99% of inotify-reload latency
        repeat: false
        onTriggered: {
            // Re-push V2 (the canonical singleton with most state)
            if (typeof SettingsStateV2 !== "undefined"
                && typeof SettingsStateV2.applyToHyprland === "function") {
                SettingsStateV2.applyToHyprland()
            }
            // Re-push V1 (the older, smaller singleton — Appearance page)
            if (typeof SettingsState !== "undefined"
                && typeof SettingsState.applyToHyprland === "function") {
                SettingsState.applyToHyprland()
            }
        }
    }

    // ── Initial load ──
    FileView {
        id: stateLoader
        path: root.statePath
        blockLoading: false
        onLoaded: {
            try {
                const t = this.text()
                if (!t || t.trim().length < 2) { root._loaded = true; return }
                const s = JSON.parse(t)
                if (typeof s.sensitivity === "number")  root.sensitivity  = s.sensitivity
                if (typeof s.scrollFactor === "number") root.scrollFactor = s.scrollFactor
                if (typeof s.naturalScroll === "boolean") root.naturalScroll = s.naturalScroll
                if (typeof s.touchpadNaturalScroll === "boolean")
                    root.touchpadNaturalScroll = s.touchpadNaturalScroll
            } catch (e) {
                console.warn("[MouseSettings] load:", e)
            }
            root._loaded = true
            // Apply on load so the session matches saved values even if
            // hyprland.conf hasn't been re-sourced since last reboot.
            apply(false)
        }
    }

    Component.onCompleted: {
        // Small delay so FileView has a chance to fire onLoaded; if the
        // state file doesn't exist, mark loaded so later writes flow.
        loadFallback.restart()
    }

    Timer {
        id: loadFallback
        interval: 500
        repeat: false
        onTriggered: if (!root._loaded) { root._loaded = true }
    }
}
