pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * RefreshRateService v7.0.0-beta.1-hf36 — Karui (軽い)
 *
 * Manual 60Hz refresh-rate downgrade toggle for battery savings.
 *
 * USER MODEL (no auto-switching — manual lang, per user request):
 *
 *   Battery & Power settings → "Reduce refresh rate to 60Hz"
 *
 *     OFF (default)
 *       All monitors run at their preferred refresh rate from
 *       ~/.config/hypr/hyprland-monitors.conf (whatever the user
 *       configured via DisplaysPage). E.g. DP-2 at 144Hz.
 *
 *     ON
 *       Snapshot the current per-monitor refresh rate, then
 *       apply 60Hz to every enabled monitor via:
 *         hyprctl keyword monitor <name>,<WxH@60>,<pos>,<scale>
 *       Toast: "Display · Switched to 60Hz to save battery".
 *
 *     OFF (toggling back)
 *       Restore each monitor to its snapshotted rate via the
 *       inverse hyprctl call. Toast: "Display · Restored to native
 *       refresh rate".
 *
 * SCOPE
 *   All enabled monitors (built-in + external) — user's choice
 *   when they said "Lahat ng monitor (including external like your
 *   DP-2 Xiaomi 144Hz)". External monitors benefit slightly too
 *   (less GPU work pushing pixels), so this is reasonable.
 *
 * PERSISTENCE
 *   ~/.config/quickshell/zen-shell/refresh-rate.json
 *   { "downgrade60Hz": bool, "savedRates": { "<name>": <originalHz>, ... } }
 *
 *   On shell startup with `downgrade60Hz: true`, the service snapshots
 *   current monitor rates (which come from hyprland-monitors.conf —
 *   the user's preferred rates) and applies 60Hz. The toggle is
 *   persistent across logout/restart.
 *
 *   Note: this service does NOT write to hyprland-monitors.conf —
 *   DisplaysPage owns that file. We only apply changes live via
 *   hyprctl. That way the user's "preferred" config in the conf
 *   file always reflects their DisplaysPage choices, and toggling
 *   the downgrade off cleanly restores those preferences.
 *
 * INTERACTION WITH DisplaysPage
 *   If toggle is ON and user manually changes a monitor's Hz via
 *   DisplaysPage (e.g. pushes DP-2 to 144Hz), the new rate becomes
 *   the new "preferred" — it stays at whatever the user set. We do
 *   NOT continuously re-apply 60Hz. The toggle is a one-shot apply
 *   per transition, not a sticky enforcement.
 *
 *   Trade-off: if user toggles ON, then manually changes a monitor
 *   in DisplaysPage, then toggles OFF — the toggle-OFF restore
 *   uses the rates we snapshotted at toggle-ON, NOT the DisplaysPage
 *   change. This is intentional — toggle-OFF means "go back to how
 *   it was before I toggled this on."
 *
 * NOTIFICATIONS
 *   Routes through NotificationService.postInternal() (the native
 *   in-shell toast pipeline added in hf32) so the toast renders via
 *   ZenNotifyToast without going through D-Bus/swaync. Consistent
 *   with PowerProfileService.setProfile() behavior.
 *
 * Wala tayong babawasan — additive, no schema migration, doesn't
 * touch DisplaysPage or LaptopModeService.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    // User toggle. Persisted to JSON. When this flips:
    //   false → true : snapshot current rates, apply 60Hz, toast
    //   true → false : restore from snapshot, clear snapshot, toast
    property bool downgrade60Hz: false

    // Per-monitor original refresh rate, captured at the moment we
    // applied the downgrade. Keys are Hyprland monitor names
    // (e.g. "eDP-1", "DP-2"). Values are the rate in Hz as a number
    // (kept as float since Hyprland reports 59.934 etc. for some
    // EDIDs — we round to int for the toast text but preserve
    // precision for restore).
    property var savedRates: ({})

    // Target rate when downgrading. 60Hz is the universal safe
    // target since every modern monitor supports it. Kept as a
    // property in case future hotfix wants 30Hz endurance mode.
    property int targetRateHz: 60

    // ─────────────────────────────────────────────────────────────
    // INTERNAL
    // ─────────────────────────────────────────────────────────────
    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/refresh-rate.json"

    // Anti-loop guard: when we apply downgrade and refresh monitors
    // afterward, the refresh might trigger downstream side effects;
    // we use this flag so re-entry into _applyDowngrade is impossible.
    property bool _applying: false

    // Loaded-from-disk flag — set true after FileView.onLoaded
    // (success or empty path). Used to defer toggle side effects
    // until we know whether persisted state exists.
    property bool _stateLoaded: false

    // ─────────────────────────────────────────────────────────────
    // PERSISTENCE
    // ─────────────────────────────────────────────────────────────
    FileView {
        id: stateLoader
        path: root.statePath
        onLoaded: {
            try {
                const txt = (this.text() || "").trim()
                if (txt) {
                    const j = JSON.parse(txt)
                    if (typeof j.downgrade60Hz === "boolean") {
                        root.downgrade60Hz = j.downgrade60Hz
                    }
                    if (j.savedRates && typeof j.savedRates === "object") {
                        root.savedRates = j.savedRates
                    }
                    if (typeof j.targetRateHz === "number" && j.targetRateHz > 0) {
                        root.targetRateHz = j.targetRateHz
                    }
                }
            } catch (e) {
                console.warn("[RefreshRateService] state parse error:", e)
            }
            root._stateLoaded = true

            // If toggle was ON when the shell last exited, the monitors
            // currently reflect the user's preferred rates (from
            // hyprland-monitors.conf which Hyprland reads on startup).
            // Re-snapshot those and re-apply the downgrade. Small delay
            // so monitor info is ready.
            if (root.downgrade60Hz) {
                restoreDelay.start()
            }
        }
    }

    Timer {
        id: restoreDelay
        interval: 1500   // give Hyprland time to settle monitor state
        repeat: false
        onTriggered: {
            console.log("[RefreshRateService] Reapplying persisted downgrade")
            root._snapshotAndApply()
        }
    }

    function _save() {
        const obj = {
            downgrade60Hz: root.downgrade60Hz,
            savedRates: root.savedRates,
            targetRateHz: root.targetRateHz
        }
        saver.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
            "cat > '" + root.statePath + "' << 'EOF'\n" +
            JSON.stringify(obj, null, 2) + "\n" +
            "EOF"
        ]
        saver.running = true
    }

    Process { id: saver; running: false }

    // Debounce save on rapid toggle bursts (shouldn't happen for a
    // single-click toggle, but defensive — matches SoundEffectsService
    // pattern).
    Timer {
        id: saveDebounce
        interval: 300
        repeat: false
        onTriggered: root._save()
    }

    onDowngrade60HzChanged: {
        if (!root._stateLoaded) return  // ignore during initial load
        saveDebounce.restart()
    }
    onSavedRatesChanged: {
        if (!root._stateLoaded) return
        saveDebounce.restart()
    }

    // ─────────────────────────────────────────────────────────────
    // HYPRCTL QUERY — fetch current monitor list
    // ─────────────────────────────────────────────────────────────
    // Output of `hyprctl monitors -j` is a JSON array of monitors
    // with fields: name, width, height, refreshRate, scale, x, y,
    // transform, disabled, etc. We need name + refreshRate +
    // dimensions + position + scale + transform to construct the
    // monitor keyword string for hyprctl.
    property var _pendingMode: ""   // "apply" | "restore"

    Process {
        id: monQuery
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = (this.text || "").trim()
                if (!txt) {
                    console.warn("[RefreshRateService] hyprctl returned empty")
                    root._applying = false
                    return
                }
                try {
                    const list = JSON.parse(txt)
                    if (!Array.isArray(list)) {
                        console.warn("[RefreshRateService] hyprctl not array:", txt)
                        root._applying = false
                        return
                    }
                    if (root._pendingMode === "apply") {
                        root._doApply(list)
                    } else if (root._pendingMode === "restore") {
                        root._doRestore(list)
                    }
                } catch (e) {
                    console.warn("[RefreshRateService] JSON parse:", e)
                    root._applying = false
                }
            }
        }
    }

    // Setter process — fire-and-forget hyprctl keyword commands.
    // Batched via `--batch` so multi-monitor setups apply atomically.
    Process { id: setter; running: false }

    // ─────────────────────────────────────────────────────────────
    // SNAPSHOT + APPLY (toggle ON path)
    // ─────────────────────────────────────────────────────────────
    function _snapshotAndApply() {
        if (root._applying) return
        root._applying = true
        root._pendingMode = "apply"
        monQuery.running = true
    }

    function _doApply(monitors) {
        const snap = {}
        const cmds = []
        let changedCount = 0

        for (const m of monitors) {
            if (!m || m.disabled) continue
            const name = m.name || ""
            if (!name) continue

            const hz = Number(m.refreshRate || 0)
            const w  = Number(m.width || 0)
            const h  = Number(m.height || 0)
            const sc = Number(m.scale || 1)
            const px = Number(m.x || 0)
            const py = Number(m.y || 0)
            const tr = Number(m.transform || 0)

            if (w <= 0 || h <= 0 || hz <= 0) continue

            // Snapshot the current rate (precise float — we restore
            // to this exact value later for clean toggle-off).
            snap[name] = hz

            // Only apply if currently above target (skip already-60Hz
            // monitors — no need to send a no-op hyprctl command).
            if (hz <= root.targetRateHz + 0.5) continue

            // Build the monitor keyword: name,WxH@Hz,pos,scale[,transform,N]
            const cmd = name + "," + w + "x" + h + "@" + root.targetRateHz.toFixed(2)
                      + "," + px + "x" + py
                      + "," + sc.toFixed(2)
                      + (tr > 0 ? ",transform," + tr : "")
            cmds.push(cmd)
            changedCount++
        }

        root.savedRates = snap

        if (cmds.length === 0) {
            console.log("[RefreshRateService] All monitors already <= "
                      + root.targetRateHz + "Hz — nothing to apply")
            root._applying = false
            _toast("Display",
                   "All monitors already at " + root.targetRateHz + "Hz",
                   0)
            return
        }

        // hyprctl --batch "keyword monitor <cmd1>;keyword monitor <cmd2>;..."
        let batch = ""
        for (const c of cmds) {
            batch += "keyword monitor " + c + ";"
        }

        setter.command = ["hyprctl", "--batch", batch]
        setter.running = true

        console.log("[RefreshRateService] Downgraded " + changedCount
                  + " monitor(s) to " + root.targetRateHz + "Hz")

        // Toast — bullet-list the affected monitor names for clarity
        const names = []
        for (const n in snap) {
            if (snap[n] > root.targetRateHz + 0.5) {
                names.push(n + " " + Math.round(snap[n]) + "Hz → "
                         + root.targetRateHz + "Hz")
            }
        }
        const body = (names.length > 0)
            ? names.join("\n")
            : "Switched to " + root.targetRateHz + "Hz"

        _toast("Display · " + root.targetRateHz + "Hz mode ON",
               body + "\nSaves battery life on laptops.",
               1)

        // Release the guard slightly after the batch should have
        // applied — gives downstream listeners (DisplaysPage, etc.)
        // time to re-read monitor state via their own refresh.
        applyReleaseTimer.restart()
    }

    Timer {
        id: applyReleaseTimer
        interval: 500
        repeat: false
        onTriggered: root._applying = false
    }

    // ─────────────────────────────────────────────────────────────
    // RESTORE (toggle OFF path)
    // ─────────────────────────────────────────────────────────────
    function _queryAndRestore() {
        if (root._applying) return
        root._applying = true
        root._pendingMode = "restore"
        monQuery.running = true
    }

    function _doRestore(monitors) {
        const cmds = []
        let restoredCount = 0
        const restoredNames = []

        // For each enabled monitor whose name has a saved rate, build
        // a restore command using the CURRENT geometry (pos/scale may
        // have changed via DisplaysPage since we snapshotted) but the
        // SAVED Hz. If the monitor doesn't have a saved rate, leave
        // it alone (it was already at 60Hz or below when we toggled
        // ON, so nothing to restore).
        for (const m of monitors) {
            if (!m || m.disabled) continue
            const name = m.name || ""
            if (!name) continue

            const savedHz = Number(root.savedRates[name] || 0)
            if (savedHz <= 0) continue   // no snapshot for this monitor

            const w  = Number(m.width || 0)
            const h  = Number(m.height || 0)
            const sc = Number(m.scale || 1)
            const px = Number(m.x || 0)
            const py = Number(m.y || 0)
            const tr = Number(m.transform || 0)
            const curHz = Number(m.refreshRate || 0)

            if (w <= 0 || h <= 0) continue

            // Skip if monitor is already at the saved rate (user
            // manually restored it via DisplaysPage while toggle was
            // on — leave alone).
            if (Math.abs(curHz - savedHz) < 0.5) continue

            const cmd = name + "," + w + "x" + h + "@" + savedHz.toFixed(2)
                      + "," + px + "x" + py
                      + "," + sc.toFixed(2)
                      + (tr > 0 ? ",transform," + tr : "")
            cmds.push(cmd)
            restoredCount++
            restoredNames.push(name + " → " + Math.round(savedHz) + "Hz")
        }

        if (cmds.length > 0) {
            let batch = ""
            for (const c of cmds) {
                batch += "keyword monitor " + c + ";"
            }
            setter.command = ["hyprctl", "--batch", batch]
            setter.running = true

            console.log("[RefreshRateService] Restored " + restoredCount
                      + " monitor(s) to native refresh rate")

            _toast("Display · Native refresh rate restored",
                   restoredNames.join("\n"),
                   0)
        } else {
            console.log("[RefreshRateService] Nothing to restore "
                      + "(monitors already at native rates)")
            _toast("Display",
                   "Already at native refresh rate",
                   0)
        }

        // Clear the snapshot — next toggle-ON starts fresh.
        root.savedRates = ({})

        applyReleaseTimer.restart()
    }

    // ─────────────────────────────────────────────────────────────
    // TOAST HELPER
    // ─────────────────────────────────────────────────────────────
    function _toast(summary, body, urgency) {
        if (typeof NotificationService === "undefined") {
            console.log("[RefreshRateService] " + summary + " — " + body)
            return
        }
        if (typeof NotificationService.postInternal !== "function") {
            console.log("[RefreshRateService] " + summary + " — " + body)
            return
        }
        try {
            NotificationService.postInternal(summary, body, "Zen Shell",
                                             urgency, "video-display")
        } catch (e) {
            console.warn("[RefreshRateService] toast error:", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PUBLIC API
    // ─────────────────────────────────────────────────────────────
    // Call from settings UI — flips the toggle with proper side effects.
    function setDowngrade(on) {
        if (on === root.downgrade60Hz) return
        root.downgrade60Hz = on
        if (on) {
            _snapshotAndApply()
        } else {
            _queryAndRestore()
        }
    }

    // Convenience for binding to checkbox without writing a function
    // (used by BatterySettingsPage HMSwitch).
    function toggle() {
        setDowngrade(!root.downgrade60Hz)
    }

    // Re-apply downgrade — useful if user added a new monitor while
    // toggle was ON and wants the new monitor included.
    function reapply() {
        if (!root.downgrade60Hz) return
        _snapshotAndApply()
    }
}
