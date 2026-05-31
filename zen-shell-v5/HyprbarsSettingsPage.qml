import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * HyprbarsSettingsPage v7.0.0-beta.1-hf52 — Karui (軽い)
 *
 * Settings UI for the hyprbars Hyprland plugin.
 *
 * Layout:
 *   ┌──────────────────────────────────────────────────────────┐
 *   │ Hyprbars                                                 │
 *   │ Window title bars for Hyprland (close/min/max buttons)   │
 *   ├──────────────────────────────────────────────────────────┤
 *   │ Status                                                   │
 *   │   Plugin enabled              [pill toggle]              │
 *   │   [Install / Update] button                              │
 *   │   "Last action: …"                                       │
 *   ├──────────────────────────────────────────────────────────┤
 *   │ Buttons                                                  │
 *   │   Button side  ( Left  |  Right* )                       │
 *   │   Show close                  [pill]                     │
 *   │   Show maximize               [pill]                     │
 *   │   Show minimize               [pill]                     │
 *   ├──────────────────────────────────────────────────────────┤
 *   │ Appearance                                               │
 *   │   Sync colors with theme      [pill]                     │
 *   │   Bar height                  [slider 16-40]             │
 *   │   Text size                   [slider 8-16]              │
 *   │   Font family                 [dropdown]                 │
 *   │   Blur background             [pill]                     │
 *   │   Bar part of window          [pill]                     │
 *   ├──────────────────────────────────────────────────────────┤
 *   │ Disable on specific windows                              │
 *   │   Add `windowrule = hyprbars:no_bar, class:Brave` etc.   │
 *   │   to your Hyprland config to exclude individual apps.    │
 *   └──────────────────────────────────────────────────────────┘
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 20
        spacing: 18

        // ── Header ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Hyprbars"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Window title bars for Hyprland with close/minimize/maximize buttons. "
                    + "Auto-synced with your current Zen Shell theme."
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // ── STATUS SECTION ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statusCol.implicitHeight + 32
            radius: 8
            color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.6)
            border.color: ThemeService.alpha(ThemeService.fg, 0.10)
            border.width: 1

            ColumnLayout {
                id: statusCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "Status"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: ThemeService.fg
                }

                // Enable toggle row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Enable hyprbars"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.fg
                        }
                        Text {
                            text: HyprbarsService.enabled
                                  ? "Window title bars active"
                                  : "Currently disabled"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                        }
                    }

                    // Rounded pill toggle (same as Bluetooth / WiFi)
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 22
                        radius: 11
                        color: HyprbarsService.enabled
                               ? ThemeService.alpha(ThemeService.green || "#98c379", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: ThemeService.fg
                            y: 2
                            x: HyprbarsService.enabled
                               ? parent.width - width - 2 : 2
                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (HyprbarsService.enabled) {
                                    HyprbarsService.disablePlugin()
                                    HyprbarsService.enabled = false
                                } else {
                                    HyprbarsService.installPlugin()
                                    HyprbarsService.enabled = true
                                    HyprbarsService.installed = true
                                }
                            }
                        }
                    }
                }

                // Install + Update buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 140
                        radius: 6
                        color: installMa.containsMouse
                               ? ThemeService.alpha(ThemeService.blue || "#61afef", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Install / reinstall"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: installMa.containsMouse ? "#ffffff" : ThemeService.fg
                        }
                        MouseArea {
                            id: installMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HyprbarsService.installPlugin()
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 120
                        radius: 6
                        color: updateMa.containsMouse
                               ? ThemeService.alpha(ThemeService.blue || "#61afef", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Update plugin"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: updateMa.containsMouse ? "#ffffff" : ThemeService.fg
                        }
                        MouseArea {
                            id: updateMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HyprbarsService.updatePlugin()
                        }
                    }

                    // v7.0.0-beta.1-hf54 — diagnostic button
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 110
                        radius: 6
                        color: checkMa.containsMouse
                               ? ThemeService.alpha(ThemeService.yellow || "#fabd2f", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Check status"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: checkMa.containsMouse ? "#1d2021" : ThemeService.fg
                        }
                        MouseArea {
                            id: checkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HyprbarsService.checkStatus()
                        }
                    }

                    // v7.0.0-beta.1-hf58 — manual force-load button
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 110
                        radius: 6
                        color: forceLoadMa.containsMouse
                               ? ThemeService.alpha(ThemeService.purple || "#c678dd", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Force load"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: forceLoadMa.containsMouse ? "#ffffff" : ThemeService.fg
                        }
                        MouseArea {
                            id: forceLoadMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HyprbarsService.manualLoadPlugin()
                        }

                        ToolTip.visible: forceLoadMa.containsMouse
                        ToolTip.text: "Manually run `hyprctl plugin load` if hyprpm didn't load it"
                        ToolTip.delay: 600
                    }

                    // v7.0.0-beta.1-hf62 — heavy rebuild button (orange)
                    //
                    // Forces hyprpm to rebuild + reload the plugin in
                    // one atomic shell command, exploiting the
                    // ~5-10s window where the .so exists on disk in
                    // the runtime tmpfs. Use when Force load reports
                    // "no .so found" — means the .so was cleaned up
                    // and needs a fresh hyprpm rebuild.
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 120
                        radius: 6
                        color: rebuildMa.containsMouse
                               ? ThemeService.alpha(ThemeService.orange
                                                    || ThemeService.yellow
                                                    || "#d19a66", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.10)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: HyprbarsService._heavyRecoveryInProgress
                                  ? "Rebuilding…"
                                  : "Rebuild + load"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: rebuildMa.containsMouse ? "#1d2021" : ThemeService.fg
                        }
                        MouseArea {
                            id: rebuildMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !HyprbarsService._heavyRecoveryInProgress
                            onClicked: HyprbarsService.triggerHeavyRecovery()
                        }

                        ToolTip.visible: rebuildMa.containsMouse
                        ToolTip.text: "Atomic chain: hyprpm enable + reload + manual load. "
                                    + "Use when .so was cleaned up from runtime dir."
                        ToolTip.delay: 600
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    visible: HyprbarsService.lastError.length > 0
                    text: "⚠ " + HyprbarsService.lastError
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.red || "#e06c75"
                    wrapMode: Text.WordWrap
                }

                // v7.0.0-beta.1-hf57 — plugin loaded verification badge
                // v7.0.0-beta.1-hf59 — surfaces auto-load status too
                RowLayout {
                    Layout.fillWidth: true
                    visible: HyprbarsService.enabled
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: HyprbarsService.pluginLoaded
                               ? (ThemeService.green || "#98c379")
                               : (HyprbarsService._autoLoadInProgress
                                  || HyprbarsService._heavyRecoveryInProgress)
                                 ? (ThemeService.yellow || "#fabd2f")
                                 : (ThemeService.red || "#e06c75")
                    }

                    Text {
                        Layout.fillWidth: true
                        text: HyprbarsService.pluginLoaded
                              ? "Plugin loaded in Hyprland — bars active"
                              : HyprbarsService._heavyRecoveryInProgress
                                ? "Heavy recovery in progress — rebuilding via hyprpm…"
                                : HyprbarsService._autoLoadInProgress
                                  ? ("Auto-loading plugin… (attempt "
                                     + HyprbarsService._autoLoadAttemptCount + " of "
                                     + HyprbarsService._autoLoadMaxAttempts + ")")
                                  : HyprbarsService._heavyRecoveryAttempted
                                      && HyprbarsService._autoLoadAttemptCount
                                         >= HyprbarsService._autoLoadMaxAttempts
                                    ? "Heavy recovery exhausted — click 'Rebuild + load' "
                                      + "to retry, or check terminal"
                                    : HyprbarsService._autoLoadAttemptCount
                                        >= HyprbarsService._autoLoadMaxAttempts
                                      ? "Auto-load exhausted — heavy recovery will start…"
                                      : "Plugin NOT verified loaded — click 'Check status' or 'Install / reinstall'"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: HyprbarsService.pluginLoaded
                               ? ThemeService.fg
                               : (HyprbarsService._autoLoadInProgress
                                  || HyprbarsService._heavyRecoveryInProgress)
                                 ? (ThemeService.yellow || "#fabd2f")
                                 : (ThemeService.red || "#e06c75")
                        wrapMode: Text.WordWrap
                    }
                }

                // v7.0.0-beta.1-hf59 — was a toggleable auto-load pill.
                // v7.0.0-beta.1-hf70 — SIMPLIFIED. Auto-load is now
                // unconditional when enabled=true. No toggle needed.
                // If hyprbars is on, it will always try to load the
                // plugin on boot and after every Hyprland reload.
                Text {
                    visible: HyprbarsService.enabled
                    text: "Auto-loads plugin on every boot / Hyprland reload when enabled."
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.italic: true
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // v7.0.0-beta.1-hf60 — diagnostic detail panel.
                //
                // Surfaces the actual reason auto-load failed: .so
                // existence + last error message from `hyprctl plugin
                // load`. Only visible when there's something to show
                // (plugin not loaded AND we have detail to display).
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: diagCol.implicitHeight + 20
                    radius: 6
                    visible: HyprbarsService.enabled
                             && !HyprbarsService.pluginLoaded
                             && (HyprbarsService.lastLoadError.length > 0
                                 || HyprbarsService.soPath.length > 0
                                 || HyprbarsService._autoLoadAttemptCount > 0)
                    color: ThemeService.alpha(ThemeService.red || "#e06c75", 0.08)
                    border.color: ThemeService.alpha(ThemeService.red || "#e06c75", 0.30)
                    border.width: 1

                    ColumnLayout {
                        id: diagCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: "Diagnostic detail"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: ThemeService.red || "#e06c75"
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: HyprbarsService.soPath.length > 0
                            text: "Built .so: " + HyprbarsService.soPath
                            font.family: Theme.monoFontFamily || Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.grey1
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !HyprbarsService.soExists
                                     && HyprbarsService._autoLoadAttemptCount > 0
                            text: "No hyprbars*.so found in any hyprpm location "
                                + "(checked $XDG_RUNTIME_DIR/hyprpm, "
                                + "~/.local/share/hyprpm, ~/.cache/hyprpm) — "
                                + "plugin build failed. Run in terminal:  hyprpm update -v"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.fg
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: HyprbarsService.lastLoadError.length > 0
                            text: "hyprctl plugin load error:  "
                                + HyprbarsService.lastLoadError
                            font.family: Theme.monoFontFamily || Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.fg
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Most common cause: ABI mismatch — your Hyprland version "
                                + "(check 'hyprctl version') doesn't have a matching commit "
                                + "pin for hyprbars yet. Wait for upstream pin update, or "
                                + "build hyprbars manually against your Hyprland commit."
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.grey1
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // v7.0.0-beta.1-hf60 — fallback mimic toggle row.
                //
                // OFF (default): no fake bars on popups when real
                // plugin is dead. Consistent UX — bars everywhere or
                // bars nowhere.
                //
                // ON: legacy hf53 behavior — mimic shows on Zen popups
                // whenever hyprbars is enabled, even if real plugin
                // failed. Useful if user wants visual title bars on
                // popups regardless of plugin state.
                RowLayout {
                    Layout.fillWidth: true
                    visible: HyprbarsService.enabled
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Show fallback bars on Zen popups when plugin unavailable"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fg
                        }
                        Text {
                            text: "Paints an in-shell mimic bar on Control Panel / Settings "
                                + "even when the real hyprbars plugin can't load. The real "
                                + "plugin physically can't paint on layer-shell surfaces "
                                + "(Hyprland architectural limit)."
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: ThemeService.grey1
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // Pill toggle
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 18
                        radius: 9
                        color: HyprbarsService.showMimicFallback
                               ? ThemeService.alpha(ThemeService.green || "#98c379", 0.85)
                               : ThemeService.alpha(ThemeService.fg, 0.18)
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: "#ffffff"
                            y: 2
                            x: HyprbarsService.showMimicFallback ? parent.width - width - 2 : 2
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HyprbarsService.showMimicFallback
                                       = !HyprbarsService.showMimicFallback
                        }
                    }
                }

                // v7.0.0-beta.1-hf53 — busy / status display
                RowLayout {
                    Layout.fillWidth: true
                    visible: HyprbarsService.busy || HyprbarsService.statusMessage.length > 0
                    spacing: 8

                    Rectangle {
                        visible: HyprbarsService.busy
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        radius: 7
                        color: "transparent"
                        border.color: ThemeService.alpha(ThemeService.blue || "#61afef", 0.85)
                        border.width: 2

                        // Simple rotation spinner
                        RotationAnimation on rotation {
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: HyprbarsService.busy
                        }

                        // Mask half to make it look like a spinner
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width / 2
                            color: ThemeService.bg0 || "#1d2021"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: HyprbarsService.statusMessage
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.grey1
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Requires build dependencies: cpio, cmake, git, meson, gcc.\n"
                        + "On Arch/CachyOS: sudo pacman -S --needed cpio cmake git meson gcc"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ── BUTTONS SECTION ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: buttonsCol.implicitHeight + 32
            radius: 8
            color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.6)
            border.color: ThemeService.alpha(ThemeService.fg, 0.10)
            border.width: 1

            ColumnLayout {
                id: buttonsCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "Buttons"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: ThemeService.fg
                }

                // Button side — left (macOS) vs right (Windows)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Button side"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.fg
                        }
                        Text {
                            text: HyprbarsService.buttonSide === "left"
                                  ? "Left (macOS style: 🔴 🟡 🟢 _ □ ✕)"
                                  : "Right (Windows style: _ □ ✕)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                        }
                    }

                    // Segmented control: [Left] [Right]
                    Row {
                        spacing: 0
                        Rectangle {
                            width: 60; height: 28
                            radius: 6
                            color: HyprbarsService.buttonSide === "left"
                                   ? ThemeService.alpha(ThemeService.blue || "#61afef", 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.10)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: "Left"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: HyprbarsService.buttonSide === "left"
                                       ? "#ffffff" : ThemeService.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: HyprbarsService.buttonSide = "left"
                            }
                        }
                        Rectangle {
                            width: 60; height: 28
                            radius: 6
                            color: HyprbarsService.buttonSide === "right"
                                   ? ThemeService.alpha(ThemeService.blue || "#61afef", 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.10)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: "Right"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: HyprbarsService.buttonSide === "right"
                                       ? "#ffffff" : ThemeService.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: HyprbarsService.buttonSide = "right"
                            }
                        }
                    }
                }

                // Show close
                Hf52ToggleRow {
                    label: "Show close button (✕)"
                    sublabel: "Kills active window"
                    active: HyprbarsService.showClose
                    onToggled: HyprbarsService.showClose = !HyprbarsService.showClose
                }

                // Show maximize
                Hf52ToggleRow {
                    label: "Show maximize button (□)"
                    sublabel: "Toggles fullscreen"
                    active: HyprbarsService.showMaximize
                    onToggled: HyprbarsService.showMaximize = !HyprbarsService.showMaximize
                }

                // Show minimize
                Hf52ToggleRow {
                    label: "Show minimize button (_)"
                    sublabel: "Sends window to special:minimized workspace"
                    active: HyprbarsService.showMinimize
                    onToggled: HyprbarsService.showMinimize = !HyprbarsService.showMinimize
                }

                // v7.0.0-beta.1-hf53 — floating-only rule
                Hf52ToggleRow {
                    label: "Show bars only on floating windows"
                    sublabel: "Tiled and fullscreen windows have no bar (recommended). "
                            + "Uses block-form windowrules — only syntax that works on Hyprland 0.53+."
                    active: HyprbarsService.floatingOnly
                    onToggled: HyprbarsService.floatingOnly = !HyprbarsService.floatingOnly
                }
            }
        }

        // ── APPEARANCE SECTION ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: appearanceCol.implicitHeight + 32
            radius: 8
            color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.6)
            border.color: ThemeService.alpha(ThemeService.fg, 0.10)
            border.width: 1

            ColumnLayout {
                id: appearanceCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "Appearance"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: ThemeService.fg
                }

                // Sync with theme
                Hf52ToggleRow {
                    label: "Sync colors with current theme"
                    sublabel: "Bar background = bg1, text = fg, buttons = red/yellow/green from your palette"
                    active: HyprbarsService.syncWithTheme
                    onToggled: HyprbarsService.syncWithTheme = !HyprbarsService.syncWithTheme
                }

                // Bar blur
                Hf52ToggleRow {
                    label: "Blur background"
                    sublabel: "Translucent bar with Hyprland blur"
                    active: HyprbarsService.barBlur
                    onToggled: HyprbarsService.barBlur = !HyprbarsService.barBlur
                }

                // Bar part of window
                Hf52ToggleRow {
                    label: "Bar is part of window"
                    sublabel: "Window shadow surrounds the bar too (Off = bar floats above)"
                    active: HyprbarsService.barPartOfWindow
                    onToggled: HyprbarsService.barPartOfWindow = !HyprbarsService.barPartOfWindow
                }

                // Bar height slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Bar height"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.fg
                        }
                        Text {
                            text: HyprbarsService.barHeight + "px"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey1
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 16
                        to: 40
                        stepSize: 1
                        value: HyprbarsService.barHeight
                        onMoved: HyprbarsService.barHeight = Math.round(value)
                    }
                }

                // Text size slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Text size"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.fg
                        }
                        Text {
                            text: HyprbarsService.barTextSize + "pt"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey1
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 8
                        to: 16
                        stepSize: 1
                        value: HyprbarsService.barTextSize
                        onMoved: HyprbarsService.barTextSize = Math.round(value)
                    }
                }
            }
        }

        // ── EXCLUDE WINDOWS INFO ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: excludeCol.implicitHeight + 32
            radius: 8
            color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.3)
            border.color: ThemeService.alpha(ThemeService.fg, 0.10)
            border.width: 1

            ColumnLayout {
                id: excludeCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Text {
                    text: "Exclude specific apps"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: ThemeService.fg
                }

                Text {
                    Layout.fillWidth: true
                    text: "Add Hyprland windowrules to disable hyprbars on specific apps. "
                        + "Examples (paste into your ~/.config/hypr/hyprland.conf):"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: codeText.implicitHeight + 16
                    radius: 4
                    color: ThemeService.alpha(ThemeService.bg0 || "#1d2021", 0.6)
                    Text {
                        id: codeText
                        anchors.fill: parent
                        anchors.margins: 8
                        text: "# Block form (works on Hyprland 0.53+):\n"
                            + "windowrule {\n"
                            + "    name = no-bar-brave\n"
                            + "    hyprbars:no_bar = true\n"
                            + "    match:class = ^(Brave-browser)$\n"
                            + "}\n"
                            + "\n"
                            + "windowrule {\n"
                            + "    name = no-bar-vscode\n"
                            + "    hyprbars:no_bar = true\n"
                            + "    match:class = ^(code-oss)$\n"
                            + "}\n"
                            + "\n"
                            + "# Per-window bar color override:\n"
                            + "windowrule {\n"
                            + "    name = kitty-bar-color\n"
                            + "    hyprbars:bar_color = rgb(282828)\n"
                            + "    match:class = ^(kitty)$\n"
                            + "}"
                        font.family: Theme.monoFont || "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: ThemeService.fg
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 40 }   // bottom padding
    }
}
