import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * NotificationPage v6.13.1 — Settings → Notifications
 *
 * Configure SwayNC notification position and display target.
 * Writes to ~/.config/swaync/config.json → restarts swaync.
 *
 * Position options:
 *   top-left, top-center, top-right (default),
 *   bottom-left, bottom-center, bottom-right
 *
 * Display target:
 *   "all" — show on all monitors
 *   "primary" — show only on primary monitor
 *
 * v6.13.1 fixes:
 *   - Process reuse: stop previous run before starting new one
 *   - _restartSwaync: use SIGTERM instead of SIGKILL
 *   - Longer patchTimer delay (500ms) for stateSaver to finish
 *   - Debug logging for state save + patch calls
 */
Item {
    id: root

    property string positionX: "right"   // "left" | "center" | "right"
    property string positionY: "top"     // "top" | "bottom"
    property string display: "all"       // "all" | "primary"

    // v7.0.0-alpha.12-hf6: daemon mode toggle
    //   "zen"    — zen-shell native NotificationService (default)
    //   "swaync" — fallback to SwayNC (legacy daemon)
    property string daemonMode: "zen"

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/notification-state.json"
    readonly property string swayncConfigPath: Quickshell.env("HOME") + "/.config/swaync/config.json"

    // Position string for SwayNC config
    readonly property string swayncPosition: positionY + "-" + positionX

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            // ── Page header ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                Layout.leftMargin: 24
                Layout.topMargin: 24

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    Text {
                        text: "Notifications"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: ThemeService.fg
                    }

                    Text {
                        text: "Position and display settings for SwayNC"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.grey1
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
                spacing: 16

                // ═══════════════════════════════════════
                // DAEMON MODE TOGGLE (v7.0.0-alpha.12-hf6)
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Daemon Mode"
                    subtitle: "Choose which notification daemon handles incoming notifications"

                    Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 12

                        // Zen Shell native
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            radius: 10
                            color: root.daemonMode === "zen"
                                   ? ThemeService.alpha(ThemeService.blue, 0.18)
                                   : ThemeService.alpha(ThemeService.bg2, 0.5)
                            border.width: root.daemonMode === "zen" ? 2 : 1
                            border.color: root.daemonMode === "zen"
                                          ? ThemeService.blue
                                          : ThemeService.alpha(ThemeService.fg, 0.12)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                RowLayout {
                                    spacing: 6
                                    Layout.fillWidth: true

                                    Text {
                                        text: "\uf0eb"   // lightbulb / spark
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: root.daemonMode === "zen"
                                               ? ThemeService.blue
                                               : ThemeService.alpha(ThemeService.fg, 0.7)
                                    }
                                    Text {
                                        text: "Zen Shell (prototype)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: ThemeService.fg
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        visible: root.daemonMode === "zen"
                                        width: 6; height: 6; radius: 3
                                        color: ThemeService.blue
                                    }
                                }

                                Text {
                                    text: "Native daemon, theme-aware toasts, OSD popups"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeService.alpha(ThemeService.fg, 0.65)
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.daemonMode = "zen"
                                    root._saveAndApply()
                                }
                            }
                        }

                        // SwayNC fallback
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            radius: 10
                            color: root.daemonMode === "swaync"
                                   ? ThemeService.alpha(ThemeService.blue, 0.18)
                                   : ThemeService.alpha(ThemeService.bg2, 0.5)
                            border.width: root.daemonMode === "swaync" ? 2 : 1
                            border.color: root.daemonMode === "swaync"
                                          ? ThemeService.blue
                                          : ThemeService.alpha(ThemeService.fg, 0.12)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                RowLayout {
                                    spacing: 6
                                    Layout.fillWidth: true

                                    Text {
                                        text: "\uf013"   // gear (legacy)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: root.daemonMode === "swaync"
                                               ? ThemeService.blue
                                               : ThemeService.alpha(ThemeService.fg, 0.7)
                                    }
                                    Text {
                                        text: "SwayNC (legacy)"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: ThemeService.fg
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        visible: root.daemonMode === "swaync"
                                        width: 6; height: 6; radius: 3
                                        color: ThemeService.blue
                                    }
                                }

                                Text {
                                    text: "Original SwayNC daemon — stable fallback"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeService.alpha(ThemeService.fg, 0.65)
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.daemonMode = "swaync"
                                    root._saveAndApply()
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // POSITION SELECTOR — visual 3x2 grid
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Notification Position"
                    subtitle: "Choose where notifications appear on screen"

                    // Visual position grid
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160

                        // Screen representation
                        Rectangle {
                            anchors.centerIn: parent
                            width: 280
                            height: 150
                            radius: 8
                            color: ThemeService.alpha(ThemeService.bg2, 0.6)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.1)

                            // Grid of 6 position buttons (2 rows × 3 cols)
                            Grid {
                                anchors.fill: parent
                                anchors.margins: 8
                                columns: 3
                                rows: 2
                                spacing: 6

                                Repeater {
                                    model: [
                                        { px: "left",   py: "top",    label: "↖" },
                                        { px: "center", py: "top",    label: "↑" },
                                        { px: "right",  py: "top",    label: "↗" },
                                        { px: "left",   py: "bottom", label: "↙" },
                                        { px: "center", py: "bottom", label: "↓" },
                                        { px: "right",  py: "bottom", label: "↘" }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        property bool selected: root.positionX === modelData.px &&
                                                                root.positionY === modelData.py

                                        width: (280 - 16 - 12) / 3   // parent width minus margins/spacing
                                        height: (150 - 16 - 6) / 2
                                        radius: 6
                                        color: selected
                                               ? ThemeService.alpha(ThemeService.blue, 0.25)
                                               : (posBtnMouse.containsMouse
                                                  ? ThemeService.alpha(ThemeService.fg, 0.08)
                                                  : "transparent")
                                        border.width: selected ? 2 : 0
                                        border.color: ThemeService.blue

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.label
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 18
                                                color: selected ? ThemeService.blue : ThemeService.grey1
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.py + "-" + modelData.px
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 9
                                                color: selected ? ThemeService.fg : ThemeService.grey2
                                            }
                                        }

                                        MouseArea {
                                            id: posBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.positionX = modelData.px
                                                root.positionY = modelData.py
                                                root._saveAndApply()
                                            }
                                        }
                                    }
                                }
                            }

                            // "Monitor" label at bottom
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 2
                                text: "Monitor"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: ThemeService.grey2
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // DISPLAY TARGET
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Display"
                    subtitle: "Which monitor shows notifications"

                    SettingRow {
                        label: "Show on"
                        description: root.display === "all"
                                     ? "Notifications appear on all monitors"
                                     : "Notifications appear on primary monitor only"

                        Row {
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "all",     label: "All" },
                                    { id: "primary", label: "Primary" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    property bool selected: root.display === modelData.id

                                    width: 64; height: 28; radius: 6
                                    color: selected
                                           ? ThemeService.alpha(ThemeService.blue, 0.2)
                                           : (dispMouse.containsMouse
                                              ? ThemeService.alpha(ThemeService.fg, 0.06)
                                              : ThemeService.alpha(ThemeService.fg, 0.03))
                                    border.width: selected ? 1 : 0
                                    border.color: ThemeService.alpha(ThemeService.blue, 0.5)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: selected ? Font.DemiBold : Font.Normal
                                        color: selected ? ThemeService.blue : ThemeService.grey0
                                    }

                                    MouseArea {
                                        id: dispMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.display = modelData.id
                                            root._saveAndApply()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════
                // ACTIONS
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Actions"

                    SettingRow {
                        label: "Restart SwayNC"
                        description: "Apply changes by restarting the notification daemon"

                        Rectangle {
                            width: 72; height: 28; radius: 6
                            color: restartMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.orange, 0.15)
                                   : ThemeService.alpha(ThemeService.orange, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf021  Restart"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ThemeService.orange
                            }

                            MouseArea {
                                id: restartMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._restartSwaync()
                            }
                        }
                    }

                    SettingRow {
                        label: "Clear All Notifications"
                        description: "Dismiss all current notifications"

                        Rectangle {
                            width: 60; height: 28; radius: 6
                            color: clearMouse.containsMouse
                                   ? ThemeService.alpha(ThemeService.red, 0.15)
                                   : ThemeService.alpha(ThemeService.red, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Clear"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.red
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    clearRunner.command = ["bash", "-c", "swaync-client -C"]
                                    clearRunner.running = true
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }

    // ═══════════════════════════════════════════════
    // PERSISTENCE + SWAYNC CONFIG WRITER
    // ═══════════════════════════════════════════════

    Process { id: stateSaver; running: false }
    Process { id: swayncPatcher; running: false }
    Process { id: clearRunner; running: false }

    function _saveAndApply() {
        console.log("[NotificationPage] _saveAndApply: positionX=" + positionX +
                    " positionY=" + positionY + " display=" + display)
        // Step 1: Save zen-shell notification state JSON
        _saveZenState()
        // Step 2: Patch swaync + restart (with 500ms delay for stateSaver to finish)
        patchTimer.restart()
    }

    Timer {
        id: patchTimer
        interval: 500
        repeat: false
        onTriggered: root._patchAndRestart()
    }

    function _saveZenState() {
        const px = positionX
        const py = positionY
        const disp = display
        const dm = daemonMode
        const sp = statePath

        // Stop previous run if still going
        if (stateSaver.running) stateSaver.running = false

        // Use printf to avoid heredoc issues
        stateSaver.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + sp + "')\" && " +
            "printf '%s\\n' '{' " +
            "'  \"positionX\": \"" + px + "\",' " +
            "'  \"positionY\": \"" + py + "\",' " +
            "'  \"display\": \"" + disp + "\",' " +
            "'  \"daemonMode\": \"" + dm + "\"' " +
            "'}' > '" + sp + "' && " +
            "echo '[NotificationPage] State saved: " + py + "-" + px + " daemon=" + dm + "'"
        ]
        stateSaver.running = true

        // v7.0.0-alpha.12-hf3: tell NotificationService to re-read the
        // file so the bar bell + notification panel reposition immediately.
        // 600ms delay so stateSaver finishes writing before reload.
        nsReloadTimer.restart()
    }

    Timer {
        id: nsReloadTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (typeof NotificationService !== "undefined"
                && NotificationService._loadPosition) {
                NotificationService._loadPosition()
            }
        }
    }

    function _patchAndRestart() {
        // Stop previous run if still going (user clicked rapidly)
        if (swayncPatcher.running) swayncPatcher.running = false

        // v7.0.0-beta.1-hf98f — zen mode must NOT start swaync. The old code
        // ran patch-swaync-position.sh unconditionally, which START()s swaync;
        // swaync then grabs the org.freedesktop.Notifications D-Bus name and
        // blocks Quickshell's native NotificationServer, so notifications
        // silently stop ("prang d na gumagana"). Changing the position never
        // flips daemonMode, so NotificationService's own kill logic didn't
        // re-fire. In zen mode we now reuse that robust kill (systemctl stop
        // + disable + pkill) to KEEP swaync dead so the zen daemon owns the
        // bus. The zen-side position is already saved + reloaded by
        // _saveZenState(). swaync mode is unchanged — wala tayong binawasan.
        if (daemonMode === "zen") {
            if (typeof NotificationService !== "undefined"
                && NotificationService._applyDaemonMode) {
                NotificationService._applyDaemonMode()
            } else {
                swayncPatcher.command = ["bash", "-c",
                    "pkill -TERM swaync 2>/dev/null; sleep 0.4; " +
                    "pkill -9 -x swaync 2>/dev/null; true"]
                swayncPatcher.running = true
            }
            return
        }

        const px = positionX
        const py = positionY
        const script = Quickshell.env("HOME") + "/.local/bin/patch-swaync-position.sh"

        console.log("[NotificationPage] _patchAndRestart: calling script with px=" + px + " py=" + py)

        swayncPatcher.command = ["bash", "-c",
            "'" + script + "' '" + px + "' '" + py + "'"
        ]
        swayncPatcher.running = true
    }

    function _patchSwayncConfig() {
        _saveAndApply()
    }

    function _restartSwaync() {
        // Stop previous run if still going
        if (swayncPatcher.running) swayncPatcher.running = false

        // hf98f — in zen mode the "Apply" button must not start swaync. The
        // zen daemon IS Quickshell's always-running NotificationServer, so
        // applying just means freeing the bus name from any stray swaync,
        // then firing a test toast THROUGH the zen daemon to confirm it works.
        if (daemonMode === "zen") {
            swayncPatcher.command = ["bash", "-c",
                "systemctl --user stop swaync.service 2>/dev/null; " +
                "systemctl --user disable swaync.service 2>/dev/null; " +
                "pkill -TERM swaync 2>/dev/null; sleep 1; " +
                "if pgrep -x swaync >/dev/null 2>&1; then pkill -9 -x swaync 2>/dev/null; sleep 0.5; fi; " +
                "notify-send -t 2500 'Zen notifications active' 'Native daemon is handling notifications' 2>/dev/null"
            ]
            swayncPatcher.running = true
            return
        }

        swayncPatcher.command = ["bash", "-c",
            "pkill -TERM swaync 2>/dev/null; sleep 1; " +
            "if pgrep -x swaync >/dev/null 2>&1; then pkill -9 swaync 2>/dev/null; sleep 0.5; fi; " +
            "setsid swaync </dev/null >/dev/null 2>&1 & disown 2>/dev/null; " +
            "sleep 2; notify-send -t 2000 'SwayNC Restarted' '' 2>/dev/null"
        ]
        swayncPatcher.running = true
    }

    function _applyState(text) {
        if (!text) return
        try {
            const s = JSON.parse(text)
            if (s.positionX) positionX = s.positionX
            if (s.positionY) positionY = s.positionY
            if (s.display) display = s.display
            if (s.daemonMode) daemonMode = s.daemonMode
            console.log("[NotificationPage] Loaded state: " + positionY + "-" + positionX +
                        " display=" + display + " daemon=" + daemonMode)
        } catch (e) {
            console.error("[NotificationPage] Parse error:", e)
        }
    }

    FileView {
        id: stateLoader
        path: root.statePath
        blockLoading: false
        onLoaded: root._applyState(this.text())
    }

    Component.onCompleted: stateLoader.reload()
}
