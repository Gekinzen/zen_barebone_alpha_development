pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * HotCornerService v7.0.0-beta.1-hf37 — Karui (軽い)
 *
 * Trigger actions when the cursor enters defined screen corners.
 * GNOME-style hot corners. Each corner can be assigned an action
 * via the user's preference.
 *
 * v7.0.0-beta.1-hf37 ARCHITECTURE CHANGE — event-driven overlays.
 *
 *   Previous implementation (hf21–hf36) polled `hyprctl cursorpos -j`
 *   every 500ms via a subprocess, parsed JSON, looked up the monitor,
 *   computed corner zones, fired actions. That approach had several
 *   real-world failure modes:
 *
 *     1. Cursor position only sampled twice per second → cursor can
 *        flick through a corner faster than the poll catches it.
 *     2. Subprocess overhead (~5-15ms each call) on every poll, even
 *        when desktop is idle and nothing's hovering.
 *     3. Hyprctl socket sometimes returns stale data right after a
 *        workspace switch or monitor hotplug — corners miss.
 *     4. The hyprctl JSON path was the failure point for user Paul —
 *        corners just "didn't work" with no obvious error in logs.
 *     5. CPU waste from constantly polling even when shell is locked
 *        or no overlay should fire.
 *
 *   New approach: per-screen invisible `PanelWindow`s at
 *   `WlrLayer.Overlay`, each containing 4 small (16-40 px depending
 *   on monitor size) HoverHandler regions anchored to the screen
 *   corners. Wayland delivers cursor events to those surfaces the
 *   moment the cursor enters them. Zero polling. Zero CPU when idle.
 *   Instant trigger. Works correctly across multi-monitor setups
 *   without any monitor-detection logic at all — Wayland just sends
 *   the hover event to whichever screen's surface the cursor entered.
 *
 *   This service now holds CONFIG STATE ONLY. The actual corner
 *   surfaces live in HotCornerOverlay.qml, mounted per-screen via
 *   Variants in shell.qml. The overlays call back into this service
 *   via `triggerCorner(corner)` when their HoverHandler fires.
 *
 * Default mapping:
 *   Top-left      — Spotlight overlay
 *   Top-right     — Notification panel
 *   Bottom-left   — Workspace overview
 *   Bottom-right  — Show desktop (minimize all)
 *
 * Wala tayong babawasan — all previous config keys (cornerSize,
 * debounceMs, actionTopLeft, etc.) preserved. State file schema
 * unchanged. Existing IPC handlers (toggleSearch, toggleNotifications,
 * etc.) reused.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // CONFIG (PUBLIC — read by HotCornerOverlay + Settings UI)
    // ─────────────────────────────────────────────────────────────
    property bool enabled: true

    // Base size of each corner trigger region in CSS pixels. The
    // overlay scales this per-monitor:
    //   ≤ 1920 (FHD)        → cornerSize       (16 px)
    //   1921 - 2560 (QHD)   → cornerSize * 1.5 (24 px)
    //   2561 - 3440 (UWQHD) → cornerSize * 2.0 (32 px)
    //   ≥ 3441 (4K / wider) → cornerSize * 2.5 (40 px)
    //
    // Larger displays need slightly larger trigger areas to feel
    // consistent — the same 16 px feels harder to hit on a 3440-wide
    // display because the cursor crosses more pixels per movement.
    property int cornerSize: 16

    // Debounce after a corner fires. Prevents double-trigger when
    // cursor lingers a few pixels into the zone after the initial
    // entry event.
    property int debounceMs: 800

    // Action ids (free-form strings — handled in _invokeAction):
    //   "toggleSearch", "toggleNotifications", "toggleControlCenter",
    //   "toggleClipboard", "toggleWorkspaceOverview", "showDesktop"
    property string actionTopLeft:     "toggleSearch"
    property string actionTopRight:    "toggleNotifications"
    property string actionBottomLeft:  "toggleWorkspaceOverview"
    property string actionBottomRight: "showDesktop"

    // Per-corner enable flags. Lets user keep specific corners off
    // if they conflict with their UI (e.g. top-right where the
    // close-button tooltip sometimes lives in maximized windows).
    property bool enableTopLeft:     true
    property bool enableTopRight:    true
    property bool enableBottomLeft:  true
    property bool enableBottomRight: true

    // Debug mode — logs every fire + the screen name. Enable via:
    //   ~/.config/quickshell/zen-shell/hotcorners.json: "debug": true
    // Then watch logs:
    //   journalctl --user -f -t quickshell | grep '\[HotCorner\]'
    property bool debug: false

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    property real lastTriggerTime: 0
    property string lastCorner: ""

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/hotcorners.json"

    // ─────────────────────────────────────────────────────────────
    // PUBLIC API — called by HotCornerOverlay's HoverHandlers
    // ─────────────────────────────────────────────────────────────
    /**
     * Called by HotCornerOverlay when its corner HoverHandler enters
     * a hover state. `corner` is one of: "tl", "tr", "bl", "br".
     * `screenName` is the monitor name (e.g. "DP-2") for logging.
     *
     * Debounce logic + per-corner enable check + action dispatch all
     * live here so the overlay component stays dumb (just reports
     * the event and lets the service decide what to do).
     */
    function triggerCorner(corner, screenName) {
        if (!root.enabled) return

        // Per-corner enable check
        let cornerEnabled = false
        switch (corner) {
            case "tl": cornerEnabled = root.enableTopLeft;     break
            case "tr": cornerEnabled = root.enableTopRight;    break
            case "bl": cornerEnabled = root.enableBottomLeft;  break
            case "br": cornerEnabled = root.enableBottomRight; break
        }
        if (!cornerEnabled) {
            if (root.debug) console.log("[HotCorner] " + corner
                                       + " on " + screenName
                                       + " — corner disabled, skip")
            return
        }

        // Debounce — prevent rapid re-fire if cursor lingers in zone
        const now = Date.now()
        if (corner === root.lastCorner
            && (now - root.lastTriggerTime) < root.debounceMs) {
            if (root.debug) console.log("[HotCorner] " + corner
                                       + " on " + screenName
                                       + " — debounced, skip")
            return
        }

        root.lastCorner = corner
        root.lastTriggerTime = now

        // Resolve action id for this corner
        let action = ""
        switch (corner) {
            case "tl": action = root.actionTopLeft;     break
            case "tr": action = root.actionTopRight;    break
            case "bl": action = root.actionBottomLeft;  break
            case "br": action = root.actionBottomRight; break
        }

        if (action) {
            console.log("[HotCornerService] " + corner + " on " + screenName
                      + " → " + action)
            root._invokeAction(action)
        }
    }

    /**
     * Tells HotCornerService that the cursor left a corner zone.
     * Currently a no-op — debounce naturally times out — but kept
     * as a public API for future "fire-on-exit" variants.
     */
    function cornerExited(corner) {
        // Reserved for future hover-out behavior.
    }

    // ─────────────────────────────────────────────────────────────
    // ACTION DISPATCH
    // ─────────────────────────────────────────────────────────────
    function _invokeAction(action) {
        // Direct PanelState/service property flips — instant, no
        // subprocess, no IPC round-trip. Same pattern as hf32.
        switch (action) {
            case "toggleSearch":
                if (typeof PanelState !== "undefined") {
                    PanelState.searchOverlayVisible = !PanelState.searchOverlayVisible
                }
                return
            case "toggleNotifications":
                if (typeof PanelState !== "undefined"
                    && typeof PanelState.toggleNotifPanel === "function") {
                    PanelState.toggleNotifPanel()
                }
                return
            case "toggleControlCenter":
                if (typeof PanelState !== "undefined"
                    && typeof PanelState.toggleControlCenter === "function") {
                    PanelState.toggleControlCenter()
                }
                return
            case "toggleClipboard":
                if (typeof PanelState !== "undefined") {
                    PanelState.clipboardVisible = !PanelState.clipboardVisible
                }
                return
            case "toggleWorkspaceOverview":
                if (typeof PanelState !== "undefined"
                    && typeof PanelState.toggleWorkspaceOverview === "function") {
                    PanelState.toggleWorkspaceOverview()
                }
                return
            case "showDesktop":
                // Hyprland-specific: focus a non-existent tag → no
                // window ends up focused → approximates "show desktop".
                Quickshell.execDetached({command: ["bash", "-c",
                    "hyprctl dispatch focuswindow tag:nonexistent || true"]})
                return
            case "none":
            case "":
                return
        }
        console.warn("[HotCornerService] Unknown action: " + action)
    }

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    function save() {
        const json = JSON.stringify({
            enabled: root.enabled,
            cornerSize: root.cornerSize,
            debounceMs: root.debounceMs,
            actionTopLeft: root.actionTopLeft,
            actionTopRight: root.actionTopRight,
            actionBottomLeft: root.actionBottomLeft,
            actionBottomRight: root.actionBottomRight,
            enableTopLeft: root.enableTopLeft,
            enableTopRight: root.enableTopRight,
            enableBottomLeft: root.enableBottomLeft,
            enableBottomRight: root.enableBottomRight,
            debug: root.debug
        }, null, 2)
        saveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
            "cat > '" + root.statePath + "' << 'EOF'\n" + json + "\nEOF"]
        saveProc.running = true
    }

    Process { id: saveProc; running: false }

    Component.onCompleted: load()

    function load() {
        loadProc.command = ["bash", "-c",
            "cat '" + root.statePath + "' 2>/dev/null || echo '{}'"]
        loadProc.running = true
    }

    Process {
        id: loadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (typeof j.enabled === "boolean") root.enabled = j.enabled
                    if (typeof j.cornerSize === "number") root.cornerSize = j.cornerSize
                    if (typeof j.debounceMs === "number") root.debounceMs = j.debounceMs
                    if (j.actionTopLeft) root.actionTopLeft = j.actionTopLeft
                    if (j.actionTopRight) root.actionTopRight = j.actionTopRight
                    if (j.actionBottomLeft) root.actionBottomLeft = j.actionBottomLeft
                    if (j.actionBottomRight) root.actionBottomRight = j.actionBottomRight
                    if (typeof j.enableTopLeft === "boolean") root.enableTopLeft = j.enableTopLeft
                    if (typeof j.enableTopRight === "boolean") root.enableTopRight = j.enableTopRight
                    if (typeof j.enableBottomLeft === "boolean") root.enableBottomLeft = j.enableBottomLeft
                    if (typeof j.enableBottomRight === "boolean") root.enableBottomRight = j.enableBottomRight
                    if (typeof j.debug === "boolean") root.debug = j.debug
                    if (root.debug) {
                        console.log("[HotCornerService] Config loaded: "
                                  + JSON.stringify(j))
                    }
                } catch (e) {
                    console.warn("[HotCornerService] config parse error:", e)
                }
            }
        }
    }
}
