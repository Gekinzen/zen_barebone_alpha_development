import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * BatterySettingsPage v6.16.0
 *
 * Settings UI for the v6.16.0 battery/power feature set:
 *   - Battery bar-module display mode (icon | text | bar)
 *   - Warning + critical capacity thresholds
 *   - System power profile (Power Saver | Balanced | Performance)
 *   - Lid-close behavior (mirror external | keep internal on | off)
 *
 * All settings persisted via SettingsStateV2. Power profile changes
 * also fire through PowerProfileService.setProfile() which emits a
 * swaync notification + persists the choice so it survives reboot.
 *
 * Sections auto-hide gracefully:
 *   - Battery section hidden on desktops (SystemMonitorService.batteryPresent = false)
 *   - Power Profile section hidden if powerprofilesctl isn't installed
 *   - Lid section always visible (laptop users the only realistic audience)
 *
 * Wala tayong babawasan.
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth
    readonly property int dropdownWidth: 320

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 20
        spacing: 18

        // ── Header ──
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "Battery, Power & GPU"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: ThemeService.fg }
            Text { text: "Battery, notifications, power profile, GPU switcher, lid behavior"
                   font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
        }

        // ═══ BATTERY MODULE ═══
        HMSection {
            title: "Battery Module"
            visible: SystemMonitorService.batteryPresent

            HMRow {
                label: "Display mode"
                description: "How the battery shows in the panel"
                icon: "\uf240"; separator: true
                ComboBox {
                    id: modeCombo
                    width: root.dropdownWidth
                    model: ["Icon only", "Text percentage", "Progress bar"]
                    readonly property var ids: ["icon", "text", "bar"]
                    currentIndex: {
                        const idx = ids.indexOf(SettingsStateV2.batteryDisplayMode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: {
                        SettingsStateV2.batteryDisplayMode = ids[currentIndex]
                        SettingsStateV2.markDirty()
                    }
                }
            }

            HMRow {
                label: "Live preview"
                description: "Currently: " + SystemMonitorService.batteryCapacity + "% · "
                             + SystemMonitorService.batteryStatus
                icon: "\uf06e"
                Rectangle {
                    width: root.dropdownWidth; height: 56; radius: 10
                    color: Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.1)

                    Loader {
                        anchors.centerIn: parent
                        source: "Battery.qml"
                    }
                }
            }
        }

        // ═══ NOTIFICATION THRESHOLDS ═══
        HMSection {
            title: "Battery Notifications"
            visible: SystemMonitorService.batteryPresent

            HMRow {
                label: "Warning threshold"
                description: "Swaync notification when battery drops to this %"
                icon: "\uf071"; separator: true
                SpinBox {
                    width: 140
                    from: 10; to: 60; stepSize: 5
                    value: SettingsStateV2.batteryWarnThreshold
                    onValueModified: {
                        SettingsStateV2.batteryWarnThreshold = value
                        SystemMonitorService.batteryWarningThreshold = value
                        SettingsStateV2.markDirty()
                    }
                }
            }

            HMRow {
                label: "Critical threshold"
                description: "Critical notification (urgency=critical, red icon)"
                icon: "\uf2dc"; separator: true
                SpinBox {
                    width: 140
                    from: 3; to: 25; stepSize: 1
                    value: SettingsStateV2.batteryCriticalThreshold
                    onValueModified: {
                        SettingsStateV2.batteryCriticalThreshold = value
                        SystemMonitorService.batteryCriticalThreshold = value
                        SettingsStateV2.markDirty()
                    }
                }
            }

            HMRow {
                label: "Test notification"
                description: "Fire a sample Battery Low notification now"
                icon: "\uf1d8"
                Button {
                    text: "Send test"
                    onClicked: SystemMonitorService._notify("normal",
                        "Battery Low (test)",
                        "This is a test notification at " +
                        SystemMonitorService.batteryCapacity + "%",
                        "battery-low")
                }
            }
        }

        // ═══ POWER PROFILE ═══
        HMSection {
            title: "Power Profile"
            visible: PowerProfileService.available

            HMRow {
                label: "Active profile"
                description: "Managed by power-profiles-daemon. Persists across reboots."
                icon: "\uf0e7"; separator: true
                ComboBox {
                    width: root.dropdownWidth
                    model: ["Power Saver", "Balanced", "Performance"]
                    readonly property var ids: ["power-saver", "balanced", "performance"]
                    currentIndex: {
                        const idx = ids.indexOf(PowerProfileService.currentProfile)
                        return idx >= 0 ? idx : 1
                    }
                    onActivated: PowerProfileService.setProfile(ids[currentIndex])
                }
            }

            // Quick-access pill buttons (same effect as dropdown, just visual)
            HMRow {
                label: "Quick switch"
                description: "One-tap profile switching"
                icon: "\uf251"
                RowLayout {
                    spacing: 8
                    Repeater {
                        model: [
                            { id: "power-saver", label: "Power Saver", icon: "\uf06c" },
                            { id: "balanced",    label: "Balanced",    icon: "\uf24e" },
                            { id: "performance", label: "Performance", icon: "\uf0e7" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isActive: PowerProfileService.currentProfile === modelData.id
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 36
                            radius: 8
                            color: isActive
                                ? ThemeService.alpha(ThemeService.blue, 0.22)
                                : Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.55)
                            border.width: isActive ? 1 : 0
                            border.color: isActive ? ThemeService.blue : "transparent"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: ThemeService.fg
                                }
                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: ThemeService.fg
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfileService.setProfile(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ═══ v6.16.1: GPU SWITCHER ═══
        HMSection {
            title: "GPU Switcher"

            HMRow {
                label: "App GPU mode"
                description: "Controls which GPU new app launches use. "
                             + "Takes effect on next app start (or next login for env-based mode)."
                icon: "\uf1b2"; separator: true
                ComboBox {
                    width: root.dropdownWidth
                    model: [
                        "Auto (default)",
                        "Force Integrated",
                        "Force Dedicated",
                        "Auto + Gaming Boost"
                    ]
                    readonly property var ids: ["auto", "integrated", "dedicated", "auto-gaming"]
                    currentIndex: {
                        const idx = ids.indexOf(GPUSwitcherService.currentMode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: GPUSwitcherService.setMode(ids[currentIndex])
                }
            }

            // Detected topology info
            HMRow {
                label: "Detected GPUs"
                description: "Topology from /sys/class/drm enumeration"
                icon: "\uf05a"; separator: true
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: SystemMonitorService.gpus
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: gpuBadge.implicitWidth + 14
                            Layout.preferredHeight: 24
                            radius: 6
                            color: {
                                const t = modelData.type
                                if (t === "nvidia") return ThemeService.alpha("#76b900", 0.2)
                                if (t === "amd") return ThemeService.alpha("#ed1c24", 0.2)
                                if (t === "intel") return ThemeService.alpha("#0071c5", 0.2)
                                return ThemeService.alpha(ThemeService.fg, 0.1)
                            }
                            border.width: 1
                            border.color: {
                                const t = modelData.type
                                if (t === "nvidia") return ThemeService.alpha("#76b900", 0.6)
                                if (t === "amd") return ThemeService.alpha("#ed1c24", 0.6)
                                if (t === "intel") return ThemeService.alpha("#0071c5", 0.6)
                                return ThemeService.alpha(ThemeService.fg, 0.2)
                            }

                            Text {
                                id: gpuBadge
                                anchors.centerIn: parent
                                text: (modelData.type || "").toUpperCase() + " " + modelData.index
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: ThemeService.fg
                            }
                        }
                    }
                    Text {
                        visible: SystemMonitorService.gpus.length === 0
                        text: "(detecting...)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                }
            }

            HMRow {
                label: "Quick launch on dGPU"
                description: "Use 'prime-run <command>' in terminal for one-shot dedicated-GPU app launches"
                icon: "\uf120"
                Button {
                    text: "prime-run <app>"
                    enabled: false
                    opacity: 0.7
                }
            }
        }

        // ═══ LID BEHAVIOR ═══
        HMSection {
            title: "Lid Close Behavior"

            HMRow {
                label: "When the laptop lid closes"
                description: "Fixes the 'external monitor goes black when I close the lid' bug"
                icon: "\uf109"; separator: true
                ComboBox {
                    width: root.dropdownWidth
                    model: ["Mirror to external monitor", "Keep internal display on", "Turn off internal (default)"]
                    readonly property var ids: ["mirror", "keep", "off"]
                    currentIndex: {
                        const idx = ids.indexOf(SettingsStateV2.lidCloseBehavior)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: {
                        SettingsStateV2.lidCloseBehavior = ids[currentIndex]
                        SettingsStateV2.markDirty()
                        // Fire a hyprctl dispatch to re-evaluate monitor config
                        lidApply.command = ["bash", "-c",
                            "command -v hyprctl >/dev/null && hyprctl reload || true"]
                        lidApply.running = true
                    }
                }
            }

            HMRow {
                label: "How it works"
                description: "The hypr-config/lid-behavior.conf module adds bindl rules for "
                             + "switch:on:Lid. Setting 'Mirror' disables the built-in display "
                             + "on close and re-enables it on open, so external monitors keep "
                             + "rendering without interruption."
                icon: "\uf05a"
            }

            // v6.16.1.6: `hyprctl reload` wipes runtime state. Re-apply
            // SettingsStateV2 after reload completes so user's gaps/borders/
            // blur/etc. don't reset to hyprland.conf defaults.
            Process { id: lidApply; running: false
                onExited: (exitCode) => {
                    if (exitCode === 0) Qt.callLater(SettingsStateV2.applyToHyprland)
                }
            }
        }

        // ═══ NO-BATTERY NOTICE (for desktops) ═══
        Rectangle {
            visible: !SystemMonitorService.batteryPresent
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 10
            color: ThemeService.alpha(ThemeService.blue, 0.08)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.blue, 0.25)

            ColumnLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 4

                Text {
                    text: "\uf108  No battery detected"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                }
                Text {
                    text: "Battery module and notifications are hidden. "
                          + "Power profile section still works if powerprofilesctl is installed."
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // ═══ NO-PPD NOTICE ═══
        Rectangle {
            visible: !PowerProfileService.available
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 10
            color: ThemeService.alpha(ThemeService.orange, 0.08)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.orange, 0.25)

            ColumnLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 4

                Text {
                    text: "\uf071  powerprofilesctl not found"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.orange
                }
                Text {
                    text: "Install power-profiles-daemon to enable profile switching. "
                          + "Arch/CachyOS: sudo pacman -S power-profiles-daemon && "
                          + "sudo systemctl enable --now power-profiles-daemon.service"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        PageFooter {
            description: "Changes auto-save. Power profile + lid behavior persist across reboots."
            onResetRequested: {
                SettingsStateV2.batteryDisplayMode = "icon"
                SettingsStateV2.batteryWarnThreshold = 30
                SettingsStateV2.batteryCriticalThreshold = 10
                SettingsStateV2.lidCloseBehavior = "mirror"
                SystemMonitorService.batteryWarningThreshold = 30
                SystemMonitorService.batteryCriticalThreshold = 10
                SettingsStateV2.markDirty()
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
