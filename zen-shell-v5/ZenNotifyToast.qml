import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * ZenNotifyToast v7.0.0-beta.1-hf82c — Karui (軽い)
 *
 * Toast popup for incoming notifications. Listens to
 * NotificationService.toastRequested. Stacks newest at top.
 *
 * Anchored to top-right of the screen by default. Position can be
 * configured via NotificationToastState.position (alpha.13 work).
 * For now, top-right is the default like macOS / GNOME.
 *
 * Each toast:
 *   - Auto-dismisses after dismissDuration ms (5000 default)
 *   - Critical notifications stay until manually dismissed
 *   - Click dismisses
 *   - Slide-in from right + fade-out
 *   - Theme colors via ThemeService (live theme switch supported)
 *
 * Mounted ONCE per screen via Variants in shell.qml. Each instance
 * shows on its own monitor.
 */
Item {
    id: toastHost

    // Anchored area where toasts stack — right side, top-aligned
    // 16px from right edge, 16px from top (below bar)
    width: 380
    height: parent ? (parent.height - 32) : 800

    // ─────────────────────────────────────────────────────────────
    // CONFIG
    // ─────────────────────────────────────────────────────────────
    property int dismissDuration: 5000      // ms
    property int criticalDuration: 0        // 0 = stay forever
    property int maxToasts: 5

    // v7.0.0-beta.1-hf25: warmup gate.
    //
    // During first 3s of shell life, suppress toast rendering.
    // Chat apps (Lark, FB, Workvivo, Teams) often dump backlog of
    // queued messages right after a shell restart. Those queued
    // bursts hit before our Repeater + delegate infra is stable →
    // crash on cold-start. After 3s, normal flow. History still
    // captures messages received during warmup.
    property int _bootMs: Date.now()
    function _isWarmedUp() { return (Date.now() - _bootMs) > 3000 }

    // Active toast queue — newest first
    property var activeQueue: []

    // ─────────────────────────────────────────────────────────────
    // LISTEN for toasts
    // ─────────────────────────────────────────────────────────────
    Connections {
        target: NotificationService
        function onToastRequested(notif) {
            // v7.0.0-beta.1-hf24: bulletproof queue mgmt for chat-app
            // bursts (Lark / FB / Workvivo / Teams). Previously:
            //   - queue.unshift(notif) was O(n) per call
            //   - 50 burst notifs = 50 reallocations + 50 Repeater
            //     diff passes = render storm
            //   - dropped items past maxToasts kept dangling refs
            //     (their Timers still running, accessing destroyed
            //     delegates) → SIGSEGV when Lark spammed
            //
            // Fix: cap the queue to maxToasts in one atomic update.
            // Use slice() to avoid concurrent-mutation of the live
            // array while Repeater is processing.
            try {
                if (!notif) return
                // Warmup gate — skip toast during shell startup
                // (history still records via NotificationService)
                if (!toastHost._isWarmedUp()) return
                const cap = Math.max(1, toastHost.maxToasts)
                const queue = toastHost.activeQueue.slice()
                queue.unshift(notif)
                if (queue.length > cap) {
                    // Hard cap — drop oldest before they cause delegate
                    // churn. New notifs always have priority.
                    queue.length = cap
                }
                toastHost.activeQueue = queue
            } catch (e) {
                console.warn("[ZenNotifyToast] enqueue error:", e)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // STACKED TOASTS
    //
    // v7.0.0-alpha.12-hf6: Inner ColumnLayout anchors now follow
    // NotificationService position. Previously was hardcoded
    // anchors.top + anchors.right which forced toasts to always
    // appear at the top-right of the toast strip regardless of the
    // outer PanelWindow's anchors. Now adapts to all 6 positions.
    // ─────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.top: NotificationService.isTop ? parent.top : undefined
        anchors.bottom: NotificationService.isBottom ? parent.bottom : undefined
        anchors.left: NotificationService.isLeft ? parent.left : undefined
        anchors.right: NotificationService.isRight ? parent.right : undefined
        anchors.horizontalCenter: NotificationService.isCenter
                                  ? parent.horizontalCenter
                                  : undefined

        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Repeater {
            model: toastHost.activeQueue

            delegate: Rectangle {
                id: toast
                required property var modelData
                required property int index

                // v7.0.0-beta.1-hf26: SAFE accessors.
                //
                // When activeQueue mutates while Repeater destroys
                // delegates, modelData becomes undefined for a tick.
                // Every binding that accesses modelData.X then throws
                // TypeError → cascade of binding errors → SIGSEGV.
                //
                // These readonly proxies fall back to safe defaults
                // when modelData is undefined. Bindings re-evaluate
                // through these instead of raw modelData.
                readonly property int _urgency: modelData ? (modelData.urgency || 1) : 1
                readonly property string _appName: modelData ? (modelData.appName || "Notification") : ""
                readonly property string _summary: modelData ? (modelData.summary || "") : ""
                readonly property string _body: {
                    if (!modelData || !modelData.body) return ""
                    // hf79: Sanitize body to prevent SIGSEGV from Lark/Teams/
                    // FB notifications that contain malformed HTML, inline
                    // <img> data URIs, <script> tags, or unclosed elements.
                    // Text.StyledText only supports <b> <i> <br> <font> <a> —
                    // strip everything else.
                    let b = String(modelData.body || "")
                    // Truncate extremely long bodies before parsing
                    if (b.length > 1500) b = b.substring(0, 1500) + "…"
                    // Strip dangerous tags: img, script, style, object, iframe, video, audio, svg
                    b = b.replace(/<\s*\/?\s*(img|script|style|object|iframe|embed|video|audio|svg|table|tr|td|th|div|span|p|ul|ol|li|h[1-6]|form|input|button)\b[^>]*>/gi, "")
                    // Strip data: URIs that can crash the renderer
                    b = b.replace(/data:[^"'\s>]+/gi, "")
                    return b
                }

                Layout.preferredWidth: 360
                Layout.preferredHeight: contentCol.implicitHeight + 24
                radius: 12

                // Theme-aware: uses ThemeService colors so toasts match
                // current theme (matugen/light/dark/etc.)
                color: ThemeService.alpha(ThemeService.bg1, 0.95)
                border.width: 1
                border.color: {
                    if (toast._urgency === 2) return ThemeService.red          // critical
                    if (toast._urgency === 0) return ThemeService.alpha(ThemeService.fg, 0.15)  // low
                    return ThemeService.alpha(ThemeService.blue, 0.4)             // normal
                }

                // ─── Slide-in from right + fade animation ───
                opacity: 0
                Component.onCompleted: {
                    opacity = 1
                    if (toast._urgency !== 2 && toastHost.dismissDuration > 0) {
                        autoDismiss.start()
                    }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                // ─── Auto-dismiss timer ───
                Timer {
                    id: autoDismiss
                    interval: toastHost.dismissDuration
                    repeat: false
                    onTriggered: toast._dismiss()
                }

                function _dismiss() {
                    // v7.0.0-beta.1-hf24: defensive — guard against
                    // multiple dismiss calls + accessing already-
                    // destroyed timers. Chat-app bursts could call
                    // this from hover-leave AND auto-dismiss races.
                    try {
                        if (autoDismiss) autoDismiss.stop()
                        opacity = 0
                        if (removeTimer) removeTimer.start()
                    } catch (e) {}
                }

                Timer {
                    id: removeTimer
                    interval: 250
                    repeat: false
                    onTriggered: {
                        // v7.0.0-beta.1-hf24: defensive removal.
                        // Delegate may already be in destruction phase
                        // when this fires; toast.modelData may be
                        // undefined. Wrap in try-catch + check refs.
                        try {
                            if (!toast || !toast.modelData) return
                            const queue = toastHost.activeQueue.slice()
                            const idx = queue.indexOf(toast.modelData)
                            if (idx >= 0) {
                                queue.splice(idx, 1)
                                toastHost.activeQueue = queue
                            }
                        } catch (e) {}
                    }
                }

                // ─── Hover pauses auto-dismiss ───
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: autoDismiss.stop()
                    onExited: {
                        if (toast._urgency !== 2) autoDismiss.restart()
                    }
                    onClicked: toast._dismiss()
                }

                // ─── Content ───
                ColumnLayout {
                    id: contentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 12
                    spacing: 4

                    // Header: app name + close button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Urgency dot (color-coded)
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: {
                                if (toast._urgency === 2) return ThemeService.red
                                if (toast._urgency === 0) return ThemeService.grey0
                                return ThemeService.blue
                            }
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: toast._appName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.alpha(ThemeService.fg, 0.65)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            // hf82: lock to PlainText. Defaults to
                            // Text.AutoText which auto-detects HTML
                            // and promotes to RichText. Lark/Teams
                            // appNames have been observed to contain
                            // raw markup ("Lark <Beta>"); RichText
                            // parses → SIGSEGV. Service-level
                            // sanitization in hf82 already strips
                            // tags, but defense-in-depth: pin the
                            // renderer to plain text here too.
                            textFormat: Text.PlainText
                        }

                        Text {
                            text: "×"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: ma.containsMouse
                                   ? ThemeService.fg
                                   : ThemeService.alpha(ThemeService.fg, 0.5)
                        }
                    }

                    // Summary (bold)
                    Text {
                        text: toast._summary
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        // hf82: lock to PlainText — same reasoning as
                        // appName above. NotificationService now
                        // sanitizes summary at reception (strips tags
                        // + data: URIs + length-caps), and pinning
                        // textFormat removes the AutoText → RichText
                        // upgrade path entirely. Together: belt +
                        // suspenders against Lark/Teams summary lines
                        // like "<b>@user</b> mentioned you in <i>ch</i>".
                        textFormat: Text.PlainText
                    }

                    // Body
                    Text {
                        visible: toast._body && toast._body.length > 0
                        text: toast._body
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.alpha(ThemeService.fg, 0.8)
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.StyledText  // hf79: was RichText — Lark crash fix
                    }
                }
            }
        }
    }
}
