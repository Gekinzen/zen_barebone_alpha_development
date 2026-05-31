pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick

/*
 * NotificationService v7.0.0-beta.1-hf82c — Karui (軽い)
 *
 * Native zen-shell notification daemon. Replaces SwayNC entirely.
 *
 * Responsibilities:
 *   1. Register as the system org.freedesktop.Notifications D-Bus
 *      service via Quickshell's NotificationServer
 *   2. Receive incoming notifications from any application
 *   3. Maintain history of recent notifications (last 50)
 *   4. Filter "transient" hints (volume, brightness) to OSD only
 *      so they don't pollute the persistent list
 *   5. Track unread count for the bar's bell icon
 *
 * Public API:
 *   readonly notifications: array of {id, summary, body, appName, appIcon,
 *                                       timestamp, urgency, transient, actions}
 *   readonly unreadCount: int
 *   property bool dndEnabled: bool — when true, suppress all toasts
 *
 *   signal toastRequested(notif)   — emitted when a toast should appear
 *                                     (filtered: transient hints excluded)
 *   signal osdRequested(kind, value, label)
 *                                   — emitted for volume/brightness changes
 *                                     so OSDPopup can show transient ring
 *
 *   function dismiss(id)            — remove a notification from history
 *   function clearAll()              — wipe history
 *
 * Wala tayong babawasan — fully additive. Existing NotificationIcon
 * bar widget can re-bind to NotificationService.unreadCount instead
 * of swaync count once we ship the bar wiring.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // CONFIG
    // ─────────────────────────────────────────────────────────────
    property int    maxHistory: 30

    // v7.0.0-beta.1-hf20 + hf24: burst guard for chat-app spam.
    //
    // hf20: 8 toasts / 2000ms
    // hf24: 5 toasts / 2000ms — chat apps (Lark, FB, Workvivo, Teams)
    //       routinely burst 10-20 messages in 2 seconds. Lower
    //       threshold = faster suppression = no render storm.
    //       All entries still recorded in history.
    property int burstWindowMs: 2000
    property int burstThreshold: 5
    property var _recentToastMs: []
    property bool _inBurst: false
    property bool   dndEnabled: false

    // v7.0.0-beta.1-hf5: DND now also silences notification sounds.
    //
    // Quickshell's NotificationServer doesn't expose the freedesktop
    // suppress-sound hint, and apps that play notification sounds do
    // so via their own canberra/paplay processes — independent of our
    // toast pipeline. So "silencing" means actively killing any sound
    // that fires while DND is on.
    //
    // Strategy: when DND toggles on, kill any in-flight canberra/paplay
    // notification processes. On each new notification while DND is on,
    // kill again as a guard (apps can spawn audio after we drop the
    // visual toast). On DND off, restore normal flow.
    onDndEnabledChanged: {
        if (root.dndEnabled) {
            // v7.0.0-beta.1-hf13: route through debounce
            silenceDebounce.restart()
        }
        // v7.0.0-beta.1-hf7: persist DND state to notification-state.json
        // so it survives shell restarts. Debounced via Timer to coalesce
        // rapid toggles.
        dndSaveDebounce.restart()
    }

    Process { id: soundKiller; running: false }

    // v7.0.0-beta.1-hf13: Debounce sound kill to prevent subprocess
    // flood when many notifications arrive while DND is on.
    //
    // Without this, each silent notification triggered a fresh
    // pkill subprocess. 30+ notifs in quick succession = 30+ bash
    // forks = system pressure → crash when user opens the panel.
    //
    // Timer fires once 500ms after the latest request, coalescing
    // bursts into a single kill.
    Timer {
        id: silenceDebounce
        interval: 500
        repeat: false
        onTriggered: {
            soundKiller.command = ["bash", "-c",
                "pkill -f 'canberra-gtk-play' 2>/dev/null; " +
                "pkill -f 'paplay.*notification' 2>/dev/null; " +
                "true"]
            soundKiller.running = true
        }
    }

    // v7.0.0-beta.1-hf7: DND persistence
    Timer {
        id: dndSaveDebounce
        interval: 300
        repeat: false
        onTriggered: root._saveDndState()
    }

    Process { id: dndStateSaver; running: false }

    function _saveDndState() {
        // Read current JSON, update dndEnabled key, write back atomically.
        // Using a single bash command to avoid race with positionLoader.
        const sp = root.statePath
        const dnd = root.dndEnabled ? "true" : "false"
        dndStateSaver.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + sp + "')\" && " +
            "tmp=$(mktemp) && " +
            "if [ -f '" + sp + "' ]; then " +
            "  python3 -c \"" +
            "import json, sys; " +
            "f = open('" + sp + "'); d = json.load(f); f.close(); " +
            "d['dndEnabled'] = " + (root.dndEnabled ? "True" : "False") + "; " +
            "open('$tmp','w').write(json.dumps(d, indent=2))" +
            "\" 2>/dev/null && mv \"$tmp\" '" + sp + "'; " +
            "else " +
            "  echo '{\\\"dndEnabled\\\": " + dnd + "}' > '" + sp + "'; " +
            "fi"
        ]
        dndStateSaver.running = true
    }

    function _silenceIfDnd() {
        if (root.dndEnabled) {
            // v7.0.0-beta.1-hf13: route through debounce to prevent
            // subprocess flood when many notifications arrive in burst
            silenceDebounce.restart()
        }
    }
    readonly property int unreadCount: notifications.filter(function(n){
        return !n.read
    }).length

    // ─────────────────────────────────────────────────────────────
    // POSITION (v7.0.0-alpha.12-hf3)
    //
    // Read from ~/.config/quickshell/zen-shell/notification-state.json
    // which NotificationPage writes to. Bar bell click + auto-toast
    // use these properties to position both surfaces consistently.
    //
    // positionX: "left" | "center" | "right"
    // positionY: "top" | "bottom"
    //
    // v7.0.0-alpha.12-hf5: Added displayTarget — "primary" or "all".
    // Controls whether toasts/OSD appear on primary monitor only or
    // every monitor.
    // ─────────────────────────────────────────────────────────────
    property string positionX: "right"
    property string positionY: "top"
    property string displayTarget: "primary"   // "primary" | "all"

    // v7.0.0-alpha.12-hf6: daemon mode — choose which notification
    // daemon handles incoming notifications:
    //   "zen"    — zen-shell native (default, uses NotificationServer)
    //   "swaync" — fallback to SwayNC (zen daemon disabled, swaync runs)
    //
    // When set to "swaync", the NotificationServer below sets
    // tracked=false to release D-Bus name, allowing swaync to take
    // over. Toasts/list panel still work but are sourced from swaync's
    // poll output instead of native events.
    property string daemonMode: "zen"
    readonly property bool isZenMode: daemonMode === "zen"
    readonly property bool isSwayNCMode: daemonMode === "swaync"

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/notification-state.json"

    // Convenience properties for QML layout binds
    readonly property bool isTop: positionY === "top"
    readonly property bool isBottom: positionY === "bottom"
    readonly property bool isLeft: positionX === "left"
    readonly property bool isCenter: positionX === "center"
    readonly property bool isRight: positionX === "right"

    Component.onCompleted: _loadPosition()

    function _loadPosition() {
        positionLoader.command = ["bash", "-c",
            "cat '" + statePath + "' 2>/dev/null || echo '{}'"]
        positionLoader.running = true
    }

    Process {
        id: positionLoader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text || "{}")
                    if (j.positionX) root.positionX = j.positionX
                    if (j.positionY) root.positionY = j.positionY
                    if (j.display)   root.displayTarget = j.display
                    if (j.daemonMode) root.daemonMode = j.daemonMode
                    // v7.0.0-beta.1-hf7: persist DND state across restarts
                    if (typeof j.dndEnabled === "boolean") root.dndEnabled = j.dndEnabled

                    // v7.0.0-beta.1-hf31: ALWAYS apply daemon mode on load,
                    // not just on change. If user has "zen" mode saved but
                    // swaync is autostarted (by Hyprland exec-once, systemd
                    // user service, etc.), onDaemonModeChanged never fires
                    // because nothing toggled. Result: swaync stays alive,
                    // grabs the D-Bus name, our toasts + OSD never trigger
                    // because notifs go to swaync instead.
                    //
                    // Force apply after a short delay (500ms) so other
                    // singletons finish booting first.
                    daemonModeApplyTimer.start()
                } catch (e) {
                    // Default to top-right primary zen mode (already set)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    property var notifications: []   // newest first

    // v7.0.0-beta.1-hf27: CRASH FIX — separate native ref storage.
    //
    // Previously each entry in `notifications` had `_native: notification`
    // pointing directly to a C++ Notification QObject. When that QObject
    // got destroyed (after tracked=false), the JS ref went stale. Next
    // Repeater delegate incubation tried to convert the QVariantMap to
    // a JS object → accessed dangling pointer → SEGV inside
    // QV4::VariantAssociationPrototype::fromQVariantMap → SIGSEGV.
    //
    // Confirmed via Quickshell crash report stack trace:
    //   #7  QV4::VariantAssociationPrototype::fromQVariantMap
    //   #14-16 libQt6QmlModels.so.6
    //   #17 QQmlIncubatorPrivate::incubate
    //
    // Fix: keep _native refs in a SEPARATE map keyed by entry.id.
    // Model entries are now pure data (no C++ refs). Model-driven
    // delegate incubation is safe — there's nothing in the variant
    // map that can dangle.
    property var _nativeMap: ({})
    // hf80: per-app rate limiter state
    property var _rateLimitMap: ({})
    // hf80: max native refs. Prune oldest when exceeding cap.
    readonly property int _nativeMapCap: 100

    function _getNative(id) {
        if (id === undefined || id === null) return null
        return root._nativeMap[id] || null
    }
    function _setNative(id, nativeRef) {
        if (id === undefined || id === null) return
        root._nativeMap[id] = nativeRef
        // hf80: prune if over cap — drop oldest to prevent unbounded
        // growth from Lark/Teams bursts holding native pixmap refs.
        const keys = Object.keys(root._nativeMap)
        if (keys.length > root._nativeMapCap) {
            const excess = keys.length - root._nativeMapCap
            for (let i = 0; i < excess; i++) {
                try {
                    const ref = root._nativeMap[keys[i]]
                    if (ref && typeof ref.tracked !== "undefined") ref.tracked = false
                } catch (e) {}
                delete root._nativeMap[keys[i]]
            }
        }
    }
    function _clearNative(id) {
        if (id === undefined || id === null) return
        // hf80 FIX: was calling root._clearNative(id) — infinite
        // recursion → stack overflow → SIGSEGV. Now correctly
        // deletes from _nativeMap and releases the tracked ref.
        try {
            const ref = root._nativeMap[id]
            if (ref && typeof ref.tracked !== "undefined") ref.tracked = false
        } catch (e) {}
        delete root._nativeMap[id]
    }

    // ─────────────────────────────────────────────────────────────
    // SIGNALS
    // ─────────────────────────────────────────────────────────────
    signal toastRequested(var notif)
    signal osdRequested(string kind, real value, string label)

    // ─────────────────────────────────────────────────────────────
    // D-BUS NOTIFICATION SERVER
    //
    // Quickshell's NotificationServer registers the
    // org.freedesktop.Notifications service automatically when this
    // component loads. Each incoming notification fires the
    // `notification` signal which we handle below.
    // ─────────────────────────────────────────────────────────────
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        // hf80: DISABLED — was true. Lark/Teams embed <img> tags with
        // inline base64 data URIs (50-100KB each) in the body HTML.
        // 20 burst notifications × 60KB = 1.2MB of body strings held
        // in history → memory pressure → SIGSEGV. Setting false tells
        // notification senders to use plain text bodies instead.
        bodyImagesSupported: false
        imageSupported: true
        persistenceSupported: true

        // v7.0.0-alpha.12-hf1: Quickshell's NotificationServer signal
        // is named `notification` — handler must be `onNotification`
        // matching the signal name. Wrapped body in try/catch since
        // the Notification object's API surface may vary across
        // Quickshell versions, and a single notification with an
        // unexpected shape shouldn't crash the entire daemon.
        onNotification: function(notification) {
            try {
                if (!notification) return

                console.log("[NotificationService] received notif: app="
                          + (notification.appName || "?")
                          + " summary=" + (notification.summary || "?")
                          + " urgency=" + (notification.urgency || 1)
                          + " transient=" + (notification.transient || false))

                if (root.isSwayNCMode) {
                    console.log("[NotificationService] SwayNC mode active — dropping notif")
                    return
                }

                // ─── hf80: Per-app rate limiter ───────────────────
                // Lark/Teams/Workvivo can fire 20-50 notifications in
                // 2 seconds (chat burst, channel flood). Each one
                // allocates a native Notification object + body string
                // + image data. Without throttling, this causes memory
                // exhaustion → SIGSEGV.
                //
                // Rate limit: max 5 notifications per app per 3 seconds.
                // Excess notifications are silently dropped (not queued).
                // Urgency 2 (critical) notifications bypass the limiter.
                const appKey = String(notification.appName || "unknown").toLowerCase()
                const now = Date.now()
                const urgency = notification.urgency || 1

                if (urgency < 2) {  // don't rate-limit critical
                    if (!root._rateLimitMap) root._rateLimitMap = {}
                    const rl = root._rateLimitMap[appKey] || { timestamps: [] }
                    // Prune entries older than 3 seconds
                    rl.timestamps = rl.timestamps.filter(ts => (now - ts) < 3000)
                    if (rl.timestamps.length >= 5) {
                        console.log("[NotificationService] rate-limited: " + appKey
                                  + " (" + rl.timestamps.length + " in 3s)")
                        return  // drop silently
                    }
                    rl.timestamps.push(now)
                    root._rateLimitMap[appKey] = rl
                }

                // Hold the notification so its data persists past the signal
                //
                // hf82c: defensive wrap. The `tracked` setter is a
                // C++-bridged property exposed by Quickshell's native
                // Notification object. If the native peer has already
                // been destroyed (e.g. spec-violating sender that
                // released the dbus message immediately after emit,
                // or our prior _clearNative call raced with a
                // re-emission of the same id), setting `tracked = true`
                // will dereference a freed pointer → SIGSEGV in C++,
                // not catchable by the outer try/catch. We can't fully
                // prevent that race, but we CAN guard the obvious
                // null-shape case and verify the property is still
                // writable before touching it.
                try {
                    if (notification
                        && typeof notification === "object"
                        && typeof notification.tracked !== "undefined"
                        && notification.tracked === false) {
                        // Only flip if currently false — avoids a
                        // redundant write if Quickshell already
                        // tracked it (some versions auto-track).
                        notification.tracked = true
                    }
                } catch (eTracked) {
                    console.warn("[NotificationService] hf82c tracked= failed:", eTracked)
                    // Continue — entry will still be added to history,
                    // just without a native ref for action invocation.
                }

                // ─── hf80: Sanitize body at RECEPTION ─────────────
                // Strip dangerous HTML before storing in history. This
                // is defense-in-depth — even with bodyImagesSupported
                // set to false, some apps (Lark) ignore the flag and
                // send HTML anyway. Sanitize once here instead of on
                // every render in ZenNotifyToast/NotificationListPanel.
                let safeBody = String(notification.body || "")
                if (safeBody.length > 2000) safeBody = safeBody.substring(0, 2000)
                // Strip all HTML tags except safe subset
                safeBody = safeBody.replace(/<\s*\/?\s*(img|script|style|object|iframe|embed|video|audio|svg|table|tr|td|th|div|span|p|ul|ol|li|h[1-6]|form|input|button)\b[^>]*>/gi, "")
                // Strip data: URIs
                safeBody = safeBody.replace(/data:[^"'\s>]{100,}/gi, "[image]")

                // ─── hf80: Sanitize image field ───────────────────
                // notification.image may be a file path (safe) or a
                // large data URI / pixmap ref. Only store short strings.
                let safeImage = ""
                const rawImage = notification.image
                if (rawImage && typeof rawImage === "string") {
                    if (rawImage.length < 500 && !rawImage.startsWith("data:")) {
                        safeImage = rawImage  // safe file path or icon name
                    }
                    // else: drop large data URIs / base64 images
                }

                // ─── hf82: Sanitize SUMMARY at reception ──────────
                // hf79 + hf80 handled body. The summary line was left
                // raw on the assumption that notification summaries
                // are plain text per the freedesktop spec — Lark,
                // Teams, Workvivo, and Discord all violate that:
                //
                //   "<b>@username</b> mentioned you in <i>channel</i>"
                //
                // The downstream Text { text: entry.summary } in
                // ZenNotifyToast + NotificationListPanel had no
                // `textFormat` set, so Qt's Text.AutoText kicked in
                // and auto-promoted the string to RichText the moment
                // it spotted an HTML-looking tag. RichText is the
                // exact parser hf79 KO'd for body specifically because
                // malformed/exotic markup from chat apps SIGSEGV's it.
                //
                // Defense in depth: sanitize here at reception, AND
                // lock Text elements to PlainText downstream.
                //
                // Same regex shape as body — strip dangerous tags,
                // strip data: URIs, hard cap length. Summaries by
                // convention are short, so 400 chars is generous.
                let safeSummary = String(notification.summary || "")
                if (safeSummary.length > 400) safeSummary = safeSummary.substring(0, 400)
                safeSummary = safeSummary.replace(/<\s*\/?\s*(img|script|style|object|iframe|embed|video|audio|svg|table|tr|td|th|div|span|p|ul|ol|li|h[1-6]|form|input|button|a|font|b|i|u|s|br|center|strong|em)\b[^>]*>/gi, "")
                safeSummary = safeSummary.replace(/data:[^"'\s>]+/gi, "")
                // Collapse runs of whitespace from the strip so we
                // don't leave "<b>foo</b>  bar" → "  foo  bar".
                safeSummary = safeSummary.replace(/\s{2,}/g, " ").trim()

                // ─── hf82: Sanitize APP NAME ──────────────────────
                // Same reasoning — appName is shown via Text {} in
                // the toast header row. Some apps (especially Wine-
                // wrapped chat clients) put unicode + occasional
                // markup in the registered app name string.
                let safeAppName = String(notification.appName || "")
                if (safeAppName.length > 80) safeAppName = safeAppName.substring(0, 80)
                safeAppName = safeAppName.replace(/<[^>]+>/g, "").replace(/\s{2,}/g, " ").trim()

                // ─── hf82c: Sanitize ACTIONS array ────────────────
                // Notification actions are stored on the entry and
                // passed to invokeAction() later. Some non-spec
                // senders (Discord, Slack Wine wrappers, custom
                // Electron apps) deliver malformed action entries:
                //   - non-array actions field (object/string)
                //   - actions with missing identifier or label
                //   - extremely long labels with embedded markup
                //   - action arrays with >50 entries
                // Pass through only well-shaped entries, cap the
                // array at 8 (toast can only render ~3 anyway), and
                // truncate labels to 80 chars. Don't touch identifier
                // since invokeAction() round-trips it back to the
                // server — but verify it's a string first.
                let safeActions = []
                try {
                    const rawActions = notification.actions
                    if (Array.isArray(rawActions)) {
                        for (let i = 0; i < rawActions.length && safeActions.length < 8; i++) {
                            const a = rawActions[i]
                            if (!a || typeof a !== "object") continue
                            const identifier = (typeof a.identifier === "string") ? a.identifier : ""
                            if (!identifier) continue
                            let label = (typeof a.text === "string") ? a.text
                                      : (typeof a.label === "string") ? a.label
                                      : identifier
                            if (label.length > 80) label = label.substring(0, 80)
                            label = label.replace(/<[^>]+>/g, "").replace(/\s{2,}/g, " ").trim()
                            safeActions.push({ identifier: identifier, text: label, label: label })
                        }
                    }
                } catch (eActions) {
                    console.warn("[NotificationService] hf82c actions sanitization error:", eActions)
                    safeActions = []
                }

                // ─── hf82c: Sanitize APP ICON ─────────────────────
                // Lark on Wayland is known to send pixmap-style
                // appIcon strings that are 100KB+ base64 PNGs. The
                // image hint already gets dropped at line above for
                // data: URIs; mirror the same defense here. Keep
                // file paths and icon-theme names; drop anything
                // suspiciously long.
                let safeAppIcon = ""
                const rawIcon = notification.appIcon
                if (rawIcon && typeof rawIcon === "string") {
                    if (rawIcon.length < 500 && !rawIcon.startsWith("data:")) {
                        safeAppIcon = rawIcon
                    }
                }

                const entry = {
                    id: notification.id || Date.now(),
                    summary: safeSummary,
                    body: safeBody,
                    appName: safeAppName,
                    appIcon: safeAppIcon,
                    image: safeImage,
                    urgency: urgency,
                    transient: notification.transient || false,
                    timestamp: Date.now(),
                    read: false,
                    actions: safeActions
                }
                // Store native ref separately by id
                // hf82c: try/catch — _setNative is JS-only but the
                // stored ref may have a destroyed native peer that
                // crashes when later accessed via .tracked or
                // .actions[i].invoke. We catch here, but the real
                // safety comes from the warmup gate (3s after start)
                // and the _nativeMap cap (100 entries).
                if (entry.id) {
                    try {
                        root._setNative(entry.id, notification)
                    } catch (eSetNative) {
                        console.warn("[NotificationService] hf82c _setNative failed:", eSetNative)
                    }
                }

            // ─────────────────────────────────────────────
            // FILTER: Volume / brightness OSD hints
            //
            // Some daemons send notifications with the hint
            // `x-canonical-private-synchronous` or `category`
            // = "device.added" / "device" for volume/brightness
            // changes. We intercept these and route to OSD popup
            // instead of the persistent notification list.
            //
            // We also recognize known senders for these:
            //   - volume: appName contains "volume", "audio", "sound"
            //   - brightness: appName contains "brightness", "backlight"
            // ─────────────────────────────────────────────
            const lowSummary = entry.summary.toLowerCase()
            const lowApp = entry.appName.toLowerCase()
            const isVolumeOSD = (
                lowApp.indexOf("volume") >= 0 ||
                lowApp.indexOf("audio") >= 0 ||
                lowSummary.indexOf("volume") >= 0
            )
            const isBrightnessOSD = (
                lowApp.indexOf("brightness") >= 0 ||
                lowApp.indexOf("backlight") >= 0 ||
                lowSummary.indexOf("brightness") >= 0
            )

            if (entry.transient || isVolumeOSD || isBrightnessOSD) {
                // Route to OSD only — DON'T add to history list
                if (isVolumeOSD) {
                    const m = entry.body.match(/(\d+)/) || entry.summary.match(/(\d+)/)
                    const val = m ? parseInt(m[1]) : 50
                    root.osdRequested("volume", val / 100.0, "Volume")
                } else if (isBrightnessOSD) {
                    const m = entry.body.match(/(\d+)/) || entry.summary.match(/(\d+)/)
                    const val = m ? parseInt(m[1]) : 50
                    root.osdRequested("brightness", val / 100.0, "Brightness")
                }
                // v7.0.0-beta.1-hf22: OSD-routed/transient — untrack
                // immediately since we don't store this entry anywhere.
                // hf27: also clean up _nativeMap entry just in case
                // (we just set it above).
                try {
                    if (notification
                        && typeof notification.tracked !== "undefined") {
                        notification.tracked = false
                    }
                    root._clearNative(entry.id)
                } catch (e) {}
                // Auto-dismiss the underlying notification — caller
                // doesn't expect it in the list
                return
            }

            // ─────────────────────────────────────────────
            // DND mode: drop toast, but still log to history,
            // AND kill any notification sound that fired
            // ─────────────────────────────────────────────
            if (root.dndEnabled) {
                root._addToHistory(entry)
                root._silenceIfDnd()
                return
            }

            // ─────────────────────────────────────────────
            // Normal flow: add to history + fire toast
            //
            // v7.0.0-beta.1-hf20: burst suppression. If chat app
            // floods us, history still records everything but we
            // skip toasts to avoid render storm.
            // ─────────────────────────────────────────────
            root._addToHistory(entry)

            const nowMs = Date.now()
            // Prune timestamps older than burstWindowMs
            const recent = root._recentToastMs.filter(function(t){
                return nowMs - t < root.burstWindowMs
            })
            recent.push(nowMs)
            root._recentToastMs = recent

            if (recent.length > root.burstThreshold) {
                if (!root._inBurst) {
                    root._inBurst = true
                    console.log("[NotificationService] Burst detected ("
                              + recent.length + " in "
                              + root.burstWindowMs + "ms) — toasts suppressed")
                }
                // Don't fire toast — entry is still in history
            } else {
                if (root._inBurst) {
                    root._inBurst = false
                    console.log("[NotificationService] Burst ended")
                }
                root.toastRequested(entry)
            }
            } catch (e) {
                console.warn("[NotificationService] error handling notification:", e)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PUBLIC API
    // ─────────────────────────────────────────────────────────────

    function dismiss(id) {
        // v7.0.0-beta.1-hf27: untrack via _nativeMap (entry no longer holds _native)
        try {
            const nativeRef = root._getNative(id)
            if (nativeRef && typeof nativeRef.tracked !== "undefined") {
                nativeRef.tracked = false
            }
            root._clearNative(id)
        } catch (e) {}
        const next = notifications.filter(function(n){ return n.id !== id })
        if (next.length !== notifications.length) {
            notifications = next
        }
    }

    function markRead(id) {
        const next = notifications.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) next[i].read = true
        }
        notifications = next
    }

    function markAllRead() {
        const next = notifications.slice()
        for (var i = 0; i < next.length; i++) next[i].read = true
        notifications = next
    }

    function clearAll() {
        // v7.0.0-beta.1-hf27: untrack all via _nativeMap then wipe both
        try {
            for (const id in root._nativeMap) {
                const nativeRef = root._getNative(id)
                if (nativeRef && typeof nativeRef.tracked !== "undefined") {
                    nativeRef.tracked = false
                }
            }
        } catch (e) {}
        root._nativeMap = ({})
        notifications = []
    }

    function invokeAction(id, actionId) {
        // v7.0.0-beta.1-hf27: look up via _nativeMap
        try {
            const nativeRef = root._getNative(id)
            if (nativeRef && nativeRef.actions) {
                const action = nativeRef.actions.find(function(a){ return a.identifier === actionId })
                if (action && action.invoke) action.invoke()
            }
        } catch (e) {
            console.warn("[NotificationService] invokeAction error:", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // INTERNAL
    // ─────────────────────────────────────────────────────────────

    function _addToHistory(entry) {
        // v7.0.0-beta.1-hf20 + hf27: untrack pruned entries via _nativeMap.
        // Entries themselves are pure data (no _native field) so they're
        // safe to convert to QVariantMap for Repeater delegate binding.
        const next = [entry].concat(notifications)
        if (next.length > maxHistory) {
            // Release tracked refs + delete from map for ones being dropped
            for (let i = maxHistory; i < next.length; i++) {
                try {
                    const drop = next[i]
                    if (drop && drop.id !== undefined) {
                        const nativeRef = root._getNative(drop.id)
                        if (nativeRef && typeof nativeRef.tracked !== "undefined") {
                            nativeRef.tracked = false
                        }
                        root._clearNative(drop.id)
                    }
                } catch (e) {
                    // Already destroyed or odd state — GC will reap it
                }
            }
            next.length = maxHistory
        }
        notifications = next
    }

    // ─────────────────────────────────────────────────────────────
    // EXTERNAL OSD HOOK
    //
    // Called by ConnectivityService.setVolume() and
    // BrightnessService.setBrightness() so direct user actions also
    // trigger OSD ring (not just D-Bus notifications from external
    // tools). Centralizes the OSD trigger.
    // ─────────────────────────────────────────────────────────────
    function showVolumeOSD(volume01) {
        root.osdRequested("volume", Math.max(0, Math.min(1, volume01)), "Volume")
    }

    function showBrightnessOSD(brightness01) {
        root.osdRequested("brightness", Math.max(0, Math.min(1, brightness01)), "Brightness")
    }

    // ─────────────────────────────────────────────────────────────
    // INTERNAL POST (v7.0.0-beta.1-hf32)
    //
    // Public API for in-shell QML services to post a notification
    // through the zen-shell native pipeline — same code path that
    // _fireBatteryAlert uses internally.
    //
    // Use this INSTEAD of spawning `notify-send`. Reason: notify-send
    // talks to whatever D-Bus daemon owns org.freedesktop.Notifications.
    // In zen mode that daemon IS Quickshell's NotificationServer so the
    // round-trip works, but on transient races (during shell reload or
    // when swaync is briefly killed in hf31's kill cycle) the bus name
    // may not be claimed yet and the notification is lost. Going through
    // postInternal() bypasses D-Bus entirely — direct in-process call.
    //
    // Callers (v7.0.0-beta.1-hf32):
    //   - PowerProfileService.setProfile()       → power profile switch
    //   - PowerProfileService.setGamingBoost()   → gaming boost toggle
    //
    // Future callers can use this for any shell-internal event that
    // should surface as a toast WITHOUT bouncing through notify-send.
    //
    // Parameters:
    //   summary  : string — short title (e.g. "Power Profile")
    //   body     : string — detail line (e.g. "Switched to Balanced")
    //   appName  : string — origin label shown in toast (e.g. "Zen Shell")
    //   urgency  : int    — 0=low, 1=normal, 2=critical (critical bypasses DND)
    //   iconHint : string — freedesktop icon name OR empty string
    //
    // Returns the generated entry id (string) for callers that want
    // to dismiss later via dismiss(id).
    //
    // Respects DND: non-critical entries while DND is on go to history
    // only (no toast), same as battery low warnings.
    //
    // Wala tayong babawasan — fully additive, reuses existing
    // _addToHistory() + toastRequested() so the list panel + bar bell
    // unread count both update automatically.
    // ─────────────────────────────────────────────────────────────
    function postInternal(summary, body, appName, urgency, iconHint) {
        try {
            const u = (typeof urgency === "number") ? urgency : 1
            const entry = {
                id: "zen-internal-" + Date.now() + "-" + Math.floor(Math.random() * 10000),
                summary: String(summary || ""),
                body: String(body || ""),
                appName: String(appName || "Zen Shell"),
                appIcon: String(iconHint || ""),
                image: "",
                urgency: u,
                transient: false,
                timestamp: Date.now(),
                read: false,
                actions: []
                // No _native field — synthetic entry, no QObject to track.
                // _addToHistory's _nativeMap untrack path is null-safe for these.
            }
            // Critical bypasses DND (matches _fireBatteryAlert semantics)
            if (u === 2 || !root.dndEnabled) {
                root._addToHistory(entry)
                root.toastRequested(entry)
            } else {
                // Normal/low urgency while DND is on → list only, no toast
                root._addToHistory(entry)
            }
            return entry.id
        } catch (e) {
            console.warn("[NotificationService] postInternal error:", e)
            return ""
        }
    }

    // ─────────────────────────────────────────────────────────────
    // BATTERY LOW MONITOR (v7.0.0-alpha.12-hf4)
    //
    // Watches SystemMonitorService.batteryCapacity. Fires CRITICAL
    // notifications at thresholds:
    //   - 20% → "Battery low" (Normal urgency, dismissable)
    //   - 10% → "Battery critically low" (Critical urgency, persistent)
    //   -  5% → "Plug in immediately" (Critical, repeats every 60s)
    //
    // Won't fire while charging. Once user crosses each threshold
    // upward (charging) the warning state resets so the next discharge
    // cycle re-arms the warnings.
    // ─────────────────────────────────────────────────────────────
    property bool _warned20: false
    property bool _warned10: false
    property bool _warned5: false

    Connections {
        target: typeof SystemMonitorService !== "undefined"
                ? SystemMonitorService
                : null
        function onBatteryCapacityChanged() {
            if (!SystemMonitorService.batteryPresent) return
            const pct = SystemMonitorService.batteryCapacity
            const charging = SystemMonitorService.batteryCharging

            if (charging) {
                // Reset warnings when charging — re-arm for next discharge
                if (pct >= 25) root._warned20 = false
                if (pct >= 15) root._warned10 = false
                if (pct >= 10) root._warned5 = false
                return
            }

            // Discharging — fire warnings at thresholds
            if (pct <= 5 && !root._warned5) {
                root._warned5 = true
                root._fireBatteryAlert("Plug in immediately",
                    "Battery at " + pct + "%. System will shut down soon.", 2)
            } else if (pct <= 10 && !root._warned10) {
                root._warned10 = true
                root._fireBatteryAlert("Battery critically low",
                    "Battery at " + pct + "%. Plug in soon.", 2)
            } else if (pct <= 20 && !root._warned20) {
                root._warned20 = true
                root._fireBatteryAlert("Battery low",
                    "Battery at " + pct + "%.", 1)
            }
        }
    }

    function _fireBatteryAlert(summary, body, urgency) {
        const entry = {
            id: "battery-" + Date.now(),
            summary: summary,
            body: body,
            appName: "Battery",
            appIcon: "",
            image: "",
            urgency: urgency,
            transient: false,
            timestamp: Date.now(),
            read: false,
            actions: []
            // v7.0.0-beta.1-hf27: no _native field — synthetic entry,
            // no underlying QObject to track
        }
        // Critical bypasses DND
        if (urgency === 2 || !root.dndEnabled) {
            root._addToHistory(entry)
            root.toastRequested(entry)
        } else {
            // Normal-urgency low-battery in DND mode → list only
            root._addToHistory(entry)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // DAEMON LIFECYCLE (v7.0.0-alpha.12-hf6)
    //
    // When daemonMode flips between "zen" and "swaync", we need to
    // start/stop swaync accordingly:
    //
    //   zen mode    → kill swaync (zen-shell handles notifications)
    //   swaync mode → start swaync (it takes over D-Bus name; we
    //                  drop incoming notifications via early return
    //                  in onNotification handler)
    //
    // The actual D-Bus name registration is "last writer wins" on
    // most setups — when swaync starts, it grabs the name from us.
    // When swaync exits, we grab it back.
    // ─────────────────────────────────────────────────────────────
    onDaemonModeChanged: _applyDaemonMode()

    function _applyDaemonMode() {
        if (root.isSwayNCMode) {
            // Start swaync (idempotent — `pgrep` first to avoid double-start)
            daemonProc.command = ["bash", "-c",
                "pgrep -x swaync >/dev/null 2>&1 || swaync &"]
        } else {
            // v7.0.0-beta.1-hf31: kill swaync HARD + wait so D-Bus name
            // is released, then nudge Quickshell to re-register. Multiple
            // attempts because swaync may auto-restart from systemd.
            daemonProc.command = ["bash", "-c",
                "systemctl --user stop swaync.service 2>/dev/null; " +
                "systemctl --user disable swaync.service 2>/dev/null; " +
                "pkill -x swaync 2>/dev/null; " +
                "sleep 0.3; " +
                "pkill -9 -x swaync 2>/dev/null; " +
                "true"]
        }
        daemonProc.running = true
    }

    Process { id: daemonProc; running: false }

    // v7.0.0-beta.1-hf31: delayed apply on load
    Timer {
        id: daemonModeApplyTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("[NotificationService] Applying daemon mode on load: "
                      + root.daemonMode)
            root._applyDaemonMode()
        }
    }
}
