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
    // v8.0.0-alpha-hf171 — false = moving the cursor to another monitor does NOT focus
    // it, so new windows open on the focused (last-clicked) monitor, not the cursor's.
    property bool mouseMoveFocusesMonitor: true

    // v8.0.0-alpha-hf177 — FOCUS BEHAVIOUR. Together these are the levers behind
    // "the Lark/Zoom call popup closes before I can click the smiley / end call".
    // An Electron call popup is a FLOATING window sitting over TILED ones. Hyprland's
    // default is follow_mouse=1, and it has a documented quirk: focus always changes on
    // mouse enter when you cross between a floating window and a tiled one. So the
    // moment the cursor drifts off the popup, the parent takes focus and the popup
    // hides itself. float_switch_override_focus=0 is what actually kills that quirk
    // (upstream: with it at 0, floating dialogs "retain focus even if the mouse leaves
    // the window"). focus_on_activate lets the popup take focus when it first asks —
    // Hyprland ignores that request by default, which is the other half of the same bug.
    property int  followMouse: 1                  // 0 disabled · 1 full (Hyprland default) · 2 loose
    property int  floatSwitchOverrideFocus: 1     // 0 keeps floating focus · 1 Hyprland default
    property bool focusOnActivate: false          // Hyprland default

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
            "hyprctl keyword misc:mouse_move_focuses_monitor " + (mouseMoveFocusesMonitor ? "true" : "false") + " >/dev/null 2>&1; " +
            "hyprctl keyword input:follow_mouse " + followMouse + " >/dev/null 2>&1; " +
            "hyprctl keyword input:float_switch_override_focus " + floatSwitchOverrideFocus + " >/dev/null 2>&1; " +
            "hyprctl keyword misc:focus_on_activate " + (focusOnActivate ? "true" : "false") + " >/dev/null 2>&1; " +
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
                     "    follow_mouse    = " + followMouse + "\n" +
                     "    float_switch_override_focus = " + floatSwitchOverrideFocus + "\n" +
                     "    touchpad {\n" +
                     "        natural_scroll = " + (touchpadNaturalScroll ? "true" : "false") + "\n" +
                     "    }\n" +
                     "}\n" +
                     "misc {\n" +
                     "    mouse_move_focuses_monitor = " + (mouseMoveFocusesMonitor ? "true" : "false") + "\n" +
                     "    focus_on_activate = " + (focusOnActivate ? "true" : "false") + "\n" +
                     "}\n"
        const state = JSON.stringify({
            sensitivity: sensitivity,
            scrollFactor: scrollFactor,
            naturalScroll: naturalScroll,
            touchpadNaturalScroll: touchpadNaturalScroll,
            mouseMoveFocusesMonitor: mouseMoveFocusesMonitor,
            followMouse: followMouse,
            floatSwitchOverrideFocus: floatSwitchOverrideFocus,
            focusOnActivate: focusOnActivate
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
                if (typeof s.mouseMoveFocusesMonitor === "boolean") root.mouseMoveFocusesMonitor = s.mouseMoveFocusesMonitor
                if (typeof s.followMouse === "number") root.followMouse = s.followMouse
                if (typeof s.floatSwitchOverrideFocus === "number") root.floatSwitchOverrideFocus = s.floatSwitchOverrideFocus
                if (typeof s.focusOnActivate === "boolean") root.focusOnActivate = s.focusOnActivate
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
