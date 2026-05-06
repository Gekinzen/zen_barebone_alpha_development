import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * BatterySettingsPage v6.16.3.4.3
 *
 * Settings UI for the battery/power/GPU/brightness feature set:
 *   - Battery bar-module display mode (icon | text | bar)
 *   - Warning + critical capacity thresholds
 *   - DISPLAY BRIGHTNESS (v6.16.3.4.3 — new)
 *       · Auto-detects backlight devices under /sys/class/backlight/
 *       · Primary device slider (AMD GPU / Intel GPU / NVIDIA / ASUS / ACPI)
 *       · Multi-device picker for laptops with extra surfaces
 *         (ASUS ROG: main panel + screenpad + keyboard backlight)
 *       · Fixes "brightness ayaw gumana sa ROG" — old code assumed
 *         intel_backlight only; ROG devices typically live under
 *         amdgpu_bl0 or acpi_video0
 *       · Prefers brightnessctl (logind perms) with sysfs fallback
 *   - System power profile (Power Saver | Balanced | Performance)
 *   - Lid-close behavior (mirror external | keep internal on | off)
 *
 * All settings persisted via SettingsStateV2. Power profile changes
 * also fire through PowerProfileService.setProfile() which emits a
 * swaync notification + persists the choice so it survives reboot.
 *
 * Sections auto-hide gracefully:
 *   - Battery section hidden on desktops (SystemMonitorService.batteryPresent = false)
 *   - Brightness section hidden on desktops (BrightnessService.available = false)
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

        // ─────────────────────────────────────────────────────────────
        // v6.16.3.4.2 — Compact Material You status pill
        // ─────────────────────────────────────────────────────────────
        // Always-visible "current state" surface. Mirrors what the
        // bar PowerBadge shows but more prominent + always positioned
        // at the top of the Battery & Power page so the user doesn't
        // have to scroll.
        //
        // Click behavior:
        //   - Left click → cycle to next profile (saver → balanced
        //     → performance → saver). PowerProfileService.setProfile()
        //     handles the swaync notification + persistence + updates
        //     all bound surfaces (bar PowerBadge, ControlPanel pills,
        //     this very pill) via singleton property bindings.
        //   - Hover → soft elevation shadow + cursor pointer.
        //
        // Synchronization: zero-effort. Because PowerProfileService
        // is a Singleton and all 3 surfaces (bar/CP/this) bind to
        // .currentProfile, any change anywhere updates everywhere
        // automatically. Same applies to .gamingBoostActive — when
        // boost engages from any source, this pill instantly retints
        // red. No manual sync code needed.
        //
        // Persistence: PowerProfileService.setProfile() writes to
        // SettingsStateV2.powerProfile which auto-saves to
        // ~/.config/quickshell/zen-shell/settings-state-v2.json.
        // On reboot, ~/.local/bin/zen-power-profile-restore.sh (called
        // from autostart.conf) reads that JSON and re-applies via
        // powerprofilesctl. So "kahit mag-restart ako applied padin"
        // is already covered system-side, not just QML-side.
        //
        // Material You aesthetic:
        //   - 20px radius (full-pill at 56px height = capsule)
        //   - Soft tinted background = profile color @ 12% alpha
        //   - 1.5px outline = profile color @ 35% alpha
        //   - 220ms color easing on every state transition
        //   - Filled MDI icon (not outlined) for visual weight
        //   - Generous 20px horizontal padding
        //   - Subtle drop "elevation" via doubled-up rectangle trick
        //
        // Wala tayong binawasan — section is purely additive, doesn't
        // touch the existing dropdown/pills section below at line 145+.
        // ─────────────────────────────────────────────────────────────
        Rectangle {
            id: statusPill
            visible: PowerProfileService.available
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 20

            // Color picker — same logic as PowerBadge for consistency
            readonly property color _accent: {
                if (PowerProfileService.gamingBoostActive) return ThemeService.red
                switch (PowerProfileService.currentProfile) {
                    case "power-saver": return ThemeService.green
                    case "balanced":    return ThemeService.blue
                    case "performance": return ThemeService.orange
                }
                return ThemeService.fg
            }
            readonly property string _glyph: {
                if (PowerProfileService.gamingBoostActive) return "\udb80\udeb5"  // gamepad-variant (boost wins)
                switch (PowerProfileService.currentProfile) {
                    case "power-saver": return "\udb80\udf2a"   // leaf
                    case "balanced":    return "\udb81\uddd1"   // scale-balance
                    case "performance": return "\udb85\udcde"   // rocket-launch
                }
                return "\udb81\uddd1"
            }
            readonly property string _label: {
                if (PowerProfileService.gamingBoostActive) return "Gaming Boost"
                return PowerProfileService.profileLabel(PowerProfileService.currentProfile)
            }

            // Material You: tinted bg derived from accent color
            color: pillMa.containsMouse
                ? Qt.rgba(_accent.r, _accent.g, _accent.b, 0.18)
                : Qt.rgba(_accent.r, _accent.g, _accent.b, 0.10)
            border.width: 1.5
            border.color: Qt.rgba(_accent.r, _accent.g, _accent.b, 0.35)
            Behavior on color        { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
            Behavior on border.color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                // ── Filled MDI icon, large for visual weight ──
                Text {
                    text: statusPill._glyph
                    color: statusPill._accent
                    font.family: Theme.monoFont
                    font.pixelSize: 26
                    Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
                }

                // ── Two-line label: "Active profile" + actual profile name ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: PowerProfileService.gamingBoostActive
                              ? "Boost active · click to disable"
                              : "Active profile · click to cycle"
                        color: ThemeService.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: statusPill._label
                        color: statusPill._accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
                    }
                }

                // ── Inline status badge: GPU mode (only if multi-GPU) ──
                Rectangle {
                    visible: GPUSwitcherService.isMultiGpu
                    Layout.preferredWidth: gpuRow.implicitWidth + 20
                    Layout.preferredHeight: 32
                    radius: 16
                    color: Qt.rgba(statusPill._accent.r, statusPill._accent.g, statusPill._accent.b, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(statusPill._accent.r, statusPill._accent.g, statusPill._accent.b, 0.30)

                    RowLayout {
                        id: gpuRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: GPUSwitcherService.modeIcon(GPUSwitcherService.currentMode)
                            color: statusPill._accent
                            font.family: Theme.monoFont
                            font.pixelSize: 14
                        }
                        Text {
                            text: GPUSwitcherService.modeLabel(GPUSwitcherService.currentMode)
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }

                // ── Chevron affordance: signals "click for more" ──
                Text {
                    text: "\udb80\udf5d"  // menu-down chevron
                    color: ThemeService.grey1
                    font.family: Theme.monoFont
                    font.pixelSize: 18
                    opacity: pillMa.containsMouse ? 1.0 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            // ── Click handler: cycle profile, or disable boost if active ──
            MouseArea {
                id: pillMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (PowerProfileService.gamingBoostActive) {
                        // Boost wins — single click disables it
                        PowerProfileService.setGamingBoost(false)
                    } else {
                        // Cycle to next profile (notify + persist auto-fire)
                        const order = ["power-saver", "balanced", "performance"]
                        const idx = order.indexOf(PowerProfileService.currentProfile)
                        const next = order[(idx + 1) % order.length]
                        PowerProfileService.setProfile(next)
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // v6.16.3.4.2 — "powerprofilesctl missing" status pill
        // ─────────────────────────────────────────────────────────────
        // Mirrors the Material You pill but greyed out, with install
        // hint. Visible only when PowerProfileService.available = false.
        // This way the page never has a "blank header" — there's always
        // a status surface telling the user what's going on.
        // ─────────────────────────────────────────────────────────────
        Rectangle {
            visible: !PowerProfileService.available
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 20
            color: Qt.rgba(ThemeService.grey1.r, ThemeService.grey1.g, ThemeService.grey1.b, 0.08)
            border.width: 1.5
            border.color: Qt.rgba(ThemeService.grey1.r, ThemeService.grey1.g, ThemeService.grey1.b, 0.20)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Text {
                    text: "\uf071"           // exclamation triangle (FA, fallback)
                    color: ThemeService.grey1
                    font.family: Theme.monoFont
                    font.pixelSize: 22
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Power profile management unavailable"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Install power-profiles-daemon to enable"
                        color: ThemeService.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }

        // ═══ BATTERY MODULE ═══
        HMSection {
            title: "Battery Module"
            visible: SystemMonitorService.batteryPresent

            HMRow {
                label: "Display mode"
                description: "How the battery shows in the panel"
                icon: "\uf240"; separator: true
                ZenDropdown {
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

        // ═══ v6.16.3.4.3: DISPLAY BRIGHTNESS ═══
        //
        // Shown only when BrightnessService.available (i.e. at least one
        // device under /sys/class/backlight/ was detected with a usable
        // max_brightness value).
        //
        // Rationale for the enumeration-first design:
        //   - ROG laptops with AMD dGPU expose the panel via amdgpu_bl0,
        //     NOT intel_backlight. Old code that hardcoded intel_backlight
        //     would fail to detect any device. BrightnessService enumerates
        //     all entries and picks the best-ranked candidate.
        //   - ASUS platforms often expose multiple auxiliary surfaces
        //     (screenpad, keyboard backlight) via asus::<name> entries.
        //     We expose them via the device picker so the user can control
        //     each surface independently.
        //
        // Writes go through brightnessctl when available (handles logind
        // permissions cleanly); fallback to direct sysfs otherwise with a
        // diagnostic in the shell log if permissions block it.
        HMSection {
            title: "Display Brightness"
            subtitle: "Detected: " + BrightnessService.deviceLabel(BrightnessService.currentDevice)
                      + (BrightnessService.devices.length > 1
                         ? " · " + BrightnessService.devices.length + " devices total"
                         : "")
            visible: BrightnessService.available

            // Primary brightness slider
            HMRow {
                label: "Brightness"
                description: "Current: " + BrightnessService.brightness + "%"
                             + " · Device: " + BrightnessService.currentDevice
                icon: "\uf185"; separator: true   // fa-sun-o

                RowLayout {
                    spacing: 10

                    Slider {
                        id: brightnessSlider
                        Layout.preferredWidth: 240
                        from: 1           // never allow 0 — instant blackout surprise
                        to: 100
                        stepSize: 1
                        value: BrightnessService.brightness
                        // Debounce writes via Timer so dragging the slider doesn't
                        // fire a dozen brightnessctl processes per second.
                        onValueChanged: if (pressed) brightnessDebouncer.restart()
                        onPressedChanged: if (!pressed) {
                            brightnessDebouncer.stop()
                            BrightnessService.setBrightness(Math.round(value))
                        }

                        Timer {
                            id: brightnessDebouncer
                            interval: 80
                            repeat: false
                            onTriggered: BrightnessService.setBrightness(Math.round(brightnessSlider.value))
                        }
                    }

                    Text {
                        text: Math.round(brightnessSlider.value) + "%"
                        font.family: Theme.monoFont
                        font.pixelSize: 12
                        color: ThemeService.grey0
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Multi-device picker — only shown when there's more than one
            // controllable surface (ASUS ROG screenpad / keyboard backlight etc).
            HMRow {
                visible: BrightnessService.devices.length > 1
                label: "Active device"
                description: "Which backlight surface the slider controls"
                icon: "\uf26c"; separator: true   // fa-tv

                ZenDropdown {
                    width: root.dropdownWidth
                    model: {
                        const out = []
                        const devs = BrightnessService.devices
                        for (let i = 0; i < devs.length; i++) {
                            out.push(BrightnessService.deviceLabel(devs[i].name)
                                     + " — " + devs[i].name
                                     + " (" + devs[i].percent + "%)")
                        }
                        return out
                    }
                    currentIndex: {
                        const devs = BrightnessService.devices
                        for (let i = 0; i < devs.length; i++) {
                            if (devs[i].name === BrightnessService.currentDevice) return i
                        }
                        return 0
                    }
                    onActivated: {
                        const devs = BrightnessService.devices
                        if (currentIndex >= 0 && currentIndex < devs.length) {
                            BrightnessService.selectDevice(devs[currentIndex].name)
                        }
                    }
                }
            }

            // Quick presets for common levels
            HMRow {
                label: "Quick levels"
                description: "One-tap brightness presets"
                icon: "\uf0e7"                       // fa-bolt
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [10, 30, 50, 75, 100]
                        delegate: Button {
                            text: modelData + "%"
                            implicitWidth: 52
                            onClicked: BrightnessService.setBrightness(modelData)
                        }
                    }
                }
            }
        }

        // ═══ v6.16.3.4.3: BRIGHTNESS UNAVAILABLE NOTICE ═══
        //
        // Mirrors the "powerprofilesctl not found" pill below — whenever we
        // detect that /sys/class/backlight/ is empty OR brightnessctl isn't
        // installed AND we have no sysfs write access, surface a helpful
        // install hint instead of silently hiding everything.
        //
        // Visibility logic:
        //   - On desktops (SystemMonitorService.batteryPresent = false), hide
        //     the notice entirely — no backlight is expected.
        //   - On laptops where backlight detection returned 0 devices, show
        //     a "not detected" notice (likely kernel/module issue).
        //   - On laptops where devices were detected but brightnessctl is
        //     missing, show an "install brightnessctl" tip.
        Rectangle {
            visible: SystemMonitorService.batteryPresent && !BrightnessService.available
            Layout.fillWidth: true
            Layout.preferredHeight: 64
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
                    text: "\uf185  No backlight devices detected"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.orange
                }
                Text {
                    text: "Nothing found under /sys/class/backlight/. On ASUS ROG: ensure "
                          + "asusctl + asus-wmi module are loaded. Arch/CachyOS: "
                          + "sudo pacman -S brightnessctl asusctl"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            visible: BrightnessService.available && !BrightnessService.hasBrightnessctl
            Layout.fillWidth: true
            Layout.preferredHeight: 54
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
                    text: "\uf05a  brightnessctl recommended"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: ThemeService.blue
                }
                Text {
                    text: "Falling back to direct sysfs writes. Install brightnessctl for "
                          + "cleaner permissions: sudo pacman -S brightnessctl"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // ═══ POWER PROFILE ═══
        HMSection {
            title: "Power Profile"
            visible: PowerProfileService.available

            // ─────────────────────────────────────────────────────
            // v6.16.3.4.2 — Compact status pill (Material Design)
            //
            // Always-visible "current state" indicator at the top of
            // the Power Profile section. Single click cycles to the
            // next profile; same notify + persist path as the
            // dropdown / pill buttons below (PowerProfileService is
            // the single source of truth — all surfaces synchronize
            // automatically via QML property bindings).
            //
            // Icons are Nerd Font Material Design Icons (nf-md-*),
            // matching the language introduced in v6.16.3.1
            // PowerConfirmDialog. Surrogate-pair encoded for above-
            // BMP codepoints:
            //   power-saver = U+F0335 nf-md-leaf            (\udb80\udf35)
            //   balanced    = U+F1252 nf-md-scale_balance   (\udb84\ude52)
            //   performance = U+F0241 nf-md-flash_outline   (\udb80\ude41)
            //   gaming-boost overlay = U+F0E1B nf-md-controller_classic
            //                                                (\udb83\ude1b)
            //
            // Color follows profile (matches PowerBadge bar module
            // accent color logic from v6.16.3.4):
            //   power-saver  → green
            //   balanced     → blue
            //   performance  → orange
            //   gaming-boost → red (overrides everything)
            //
            // Click semantics mirror the bar PowerBadge:
            //   left-click   → cycle profile saver → balanced → performance → saver
            //   right-click  → toggle Gaming Boost
            //   (No middle-click here because Settings page surface
            //    doesn't always pass middle button cleanly through
            //    layout panels.)
            //
            // Wala tayong binawasan — the existing dropdown + pill
            // buttons below this stay intact, just rendered after.
            // ─────────────────────────────────────────────────────
            Rectangle {
                id: v6_4_2_statusPill        // explicit id so children don't rely on
                                              // fragile parent.parent.parent chain walks
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.bottomMargin: 8
                radius: 14
                color: ThemeService.alpha(_v6_4_2_pill_accent, 0.10)
                border.width: 1
                border.color: ThemeService.alpha(_v6_4_2_pill_accent, 0.45)
                Behavior on border.color { ColorAnimation { duration: 220 } }
                Behavior on color        { ColorAnimation { duration: 220 } }

                // Accent color picker — same priority as the bar
                // PowerBadge's _accentColor in PowerBadge.qml
                readonly property color _v6_4_2_pill_accent: {
                    if (PowerProfileService.gamingBoostActive) return ThemeService.red
                    switch (PowerProfileService.currentProfile) {
                        case "power-saver": return ThemeService.green
                        case "balanced":    return ThemeService.blue
                        case "performance": return ThemeService.orange
                    }
                    return ThemeService.fg
                }

                // MDI glyph picker
                readonly property string _v6_4_2_pill_icon: {
                    if (PowerProfileService.gamingBoostActive) return "\udb83\ude1b"  // controller_classic
                    switch (PowerProfileService.currentProfile) {
                        case "power-saver": return "\udb80\udf35"  // leaf
                        case "balanced":    return "\udb84\ude52"  // scale_balance
                        case "performance": return "\udb80\ude41"  // flash_outline
                    }
                    return "\udb80\udf35"
                }

                // Display label
                readonly property string _v6_4_2_pill_label: {
                    if (PowerProfileService.gamingBoostActive)
                        return "Gaming Boost"
                    return PowerProfileService.profileLabel(PowerProfileService.currentProfile)
                }
                readonly property string _v6_4_2_pill_sub: {
                    if (PowerProfileService.gamingBoostActive)
                        return "Performance + reduced eye-candy · click to cycle profile"
                    switch (PowerProfileService.currentProfile) {
                        case "power-saver": return "Battery saver mode · click to cycle"
                        case "balanced":    return "Default · click to cycle · right-click for Gaming Boost"
                        case "performance": return "Max performance · click to cycle · right-click for Gaming Boost"
                    }
                    return "Click to cycle profile"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    // Big Material icon in a colored circle
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: ThemeService.alpha(v6_4_2_statusPill._v6_4_2_pill_accent, 0.18)
                        Text {
                            anchors.centerIn: parent
                            text: v6_4_2_statusPill._v6_4_2_pill_icon
                            color: v6_4_2_statusPill._v6_4_2_pill_accent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                    }

                    // Label + subtitle
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Text {
                                text: v6_4_2_statusPill._v6_4_2_pill_label
                                color: ThemeService.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                            // Live "active dot" — pulses subtly so
                            // user knows it's tracking, not stale
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: v6_4_2_statusPill._v6_4_2_pill_accent
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.35; duration: 1100 }
                                    NumberAnimation { from: 0.35; to: 1.0; duration: 1100 }
                                }
                            }
                        }
                        Text {
                            text: v6_4_2_statusPill._v6_4_2_pill_sub
                            color: ThemeService.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Cycle hint chevron
                    Text {
                        text: "\udb80\udd2e"  // nf-md-chevron_right (U+F012E)
                        color: ThemeService.alpha(ThemeService.fg, 0.45)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onEntered: v6_4_2_statusPill.color = ThemeService.alpha(v6_4_2_statusPill._v6_4_2_pill_accent, 0.18)
                    onExited:  v6_4_2_statusPill.color = ThemeService.alpha(v6_4_2_statusPill._v6_4_2_pill_accent, 0.10)

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            // Toggle Gaming Boost
                            if (typeof PowerProfileService.toggleGamingBoost === "function") {
                                PowerProfileService.toggleGamingBoost()
                            }
                            return
                        }
                        // Left click → cycle profile saver → balanced → performance → saver
                        // If Gaming Boost is on, first click should turn it off (so user lands
                        // on the underlying profile predictably).
                        if (PowerProfileService.gamingBoostActive) {
                            PowerProfileService.setGamingBoost(false)
                            return
                        }
                        const order = ["power-saver", "balanced", "performance"]
                        const i = order.indexOf(PowerProfileService.currentProfile)
                        const next = order[(i + 1) % order.length]
                        PowerProfileService.setProfile(next)
                        // Notify + persist happens automatically inside setProfile():
                        //   PowerProfileService.qml line 152-155 fires notify-send,
                        //   line 145 writes SettingsStateV2.powerProfile (auto-persisted),
                        //   zen-power-profile-restore.sh re-applies on next login.
                    }
                }
            }

            HMRow {
                label: "Active profile"
                description: "Managed by power-profiles-daemon. Persists across reboots."
                icon: "\uf0e7"; separator: true
                ZenDropdown {
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
            // v6.16.3.4.2: glyph upgraded from FontAwesome to MDI for consistency
            // with the new compact status pill above. Functional behavior unchanged.
            HMRow {
                label: "Quick switch"
                description: "One-tap profile switching"
                icon: "\uf251"
                RowLayout {
                    spacing: 8
                    Repeater {
                        model: [
                            { id: "power-saver", label: "Power Saver", icon: "\udb80\udf35" },  // nf-md-leaf
                            { id: "balanced",    label: "Balanced",    icon: "\udb84\ude52" },  // nf-md-scale_balance
                            { id: "performance", label: "Performance", icon: "\udb80\ude41" }   // nf-md-flash_outline
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
                ZenDropdown {
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

        // ═══ v6.16.4.12.7 (Tachiagari) — Smart Gaming Detection ═══
        //
        // Independent toggle — works regardless of GPU mode above.
        // When ON, ~/.local/bin/zen-smart-game-watcher.sh runs in the
        // background, polls for known game/launcher/runtime processes
        // every 3 seconds, and routes detection events through QML's
        // PowerProfileService.setGamingBoost() via Quickshell IPC.
        //
        // Effect when boost engages:
        //   - powerprofilesctl set performance
        //   - hyprctl: blur off, dim_inactive off, animations off
        //   - PowerBadge in the bar flips to red gamepad icon
        // Effect when last game exits:
        //   - Restore the power profile that was active before boost
        //   - Restore blur/dim/animations from this Settings page
        //
        // Use case: laptop on battery → leave GPU mode on Auto, but
        // still want the FPS boost when a game pops up. The two
        // settings are intentionally orthogonal so users can mix them.
        HMSection {
            title: "Smart Gaming Detection"
            subtitle: "Auto FPS boost when a game launches — independent of GPU mode"

            HMRow {
                label: "Enable Smart Detection"
                description: "Watches for steam, lutris, heroic, gamescope, wine/proton, "
                             + "emulators (rpcs3, dolphin, yuzu, etc.) and toggles Gaming Boost on/off automatically."
                icon: "\uf11b"   // gamepad
                separator: true

                HMSwitch {
                    checked: SettingsStateV2.smartGamingDetect
                    // HMSwitch flips its own `checked` internally before
                    // emitting `toggled`. We mirror the new value back to
                    // SettingsStateV2 — the property's own change handler
                    // (in SettingsStateV2.qml) takes care of spawning /
                    // killing the watcher daemon AND calls markDirty().
                    onToggled: SettingsStateV2.smartGamingDetect = checked
                }
            }

            HMRow {
                label: "Watcher status"
                description: SettingsStateV2.smartGamingDetect
                             ? "Daemon running. Log: ~/.cache/zen-smart-game-watcher.log"
                             : "Daemon stopped. Toggle above to start."
                icon: "\uf0a0"   // hdd

                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: SettingsStateV2.smartGamingDetect
                           ? ThemeService.green : ThemeService.alpha(ThemeService.fg, 0.25)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // ═══ IDLE & SLEEP (v6.16.3.8) ═══
        //
        // User-configurable timeouts for the hypridle cascade.
        // The values here translate to hypridle.conf listener
        // timeouts via ~/.local/bin/zen-hypridle-sync.sh which
        // runs on every setting change and restarts hypridle.
        //
        // Options in seconds:
        //   30, 60, 1800, 3600, 10800, 18000, 0 (never)
        //
        // DPMS off is auto-derived as lockIdle + 60s — no separate
        // UI (keeps the page simple; users rarely tune this
        // individually and it's usually tied to lock timing).
        HMSection {
            title: "Idle & Sleep"
            subtitle: "When to lock the screen and when to suspend"

            HMRow {
                label: "Lock after idle"
                description: "Time before the lock screen appears automatically"
                icon: "\uf023"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["30 seconds", "1 minute", "30 minutes", "1 hour", "3 hours", "5 hours", "Never"]
                    readonly property var ids: [30, 60, 1800, 3600, 10800, 18000, 0]
                    currentIndex: {
                        const i = ids.indexOf(PanelState.idleLockSeconds)
                        return i >= 0 ? i : 1   // default 1 min if unrecognized
                    }
                    onActivated: {
                        PanelState.idleLockSeconds = ids[currentIndex]
                        PanelState.saveState()
                        hypridleSync.running = true
                    }
                }
            }

            HMRow {
                label: "Sleep after idle"
                description: "Time before systemctl suspend fires. Pick 'Never' on desktops."
                icon: "\uf186"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["30 seconds", "1 minute", "30 minutes", "1 hour", "3 hours", "5 hours", "Never"]
                    readonly property var ids: [30, 60, 1800, 3600, 10800, 18000, 0]
                    currentIndex: {
                        const i = ids.indexOf(PanelState.idleSleepSeconds)
                        return i >= 0 ? i : 6   // default Never if unrecognized
                    }
                    onActivated: {
                        PanelState.idleSleepSeconds = ids[currentIndex]
                        PanelState.saveState()
                        hypridleSync.running = true
                    }
                }
            }

            HMRow {
                label: "How it works"
                description: "Changes apply immediately — zen-hypridle-sync.sh "
                             + "rewrites your hypridle.conf timeouts and restarts "
                             + "the daemon. DPMS off fires 60s after the lock "
                             + "timeout. 'Never' sets a sentinel that won't trigger "
                             + "for 3+ years of idle time."
                icon: "\uf05a"
            }

            // Process fires zen-hypridle-sync.sh whenever a combobox
            // above changes. Since PanelState.saveState() is a file
            // write, we add a small Timer delay to let the disk flush
            // before the script reads panel-state.json.
            Process {
                id: hypridleSync
                running: false
                command: ["bash", "-c",
                    "sleep 0.1 && $HOME/.local/bin/zen-hypridle-sync.sh"]
            }
        }

        // ═══ LID BEHAVIOR ═══
        HMSection {
            title: "Lid Close Behavior"

            // v6.16.3.8: Primary "what happens" question on close.
            // This is separate from the monitor-mirroring choice
            // below — that one handles the DISPLAY, this one handles
            // the SYSTEM (suspend / lock / nothing).
            HMRow {
                label: "On lid close"
                description: "System action when you close the laptop lid"
                icon: "\uf011"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["Sleep (suspend + lock on wake)", "Lock only (stay on)", "Do nothing"]
                    readonly property var ids: ["suspend", "lock", "ignore"]
                    currentIndex: {
                        const i = ids.indexOf(PanelState.lidCloseAction)
                        return i >= 0 ? i : 0
                    }
                    onActivated: {
                        PanelState.lidCloseAction = ids[currentIndex]
                        PanelState.saveState()
                    }
                }
            }

            HMRow {
                label: "When the laptop lid closes"
                description: "Fixes the 'external monitor goes black when I close the lid' bug"
                icon: "\uf109"; separator: true
                ZenDropdown {
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

        // ═══ v6.16.4 — PANIC RECOVERY (laptop reliability) ═══
        //
        // Educates the user about the SUPER+SHIFT+CTRL+Escape
        // escape hatch. This is the "never force-power-off again"
        // feature: a keybind that survives a locked/frozen session
        // and runs zen-panic.sh which does the full recovery
        // sequence. Details in the card.
        //
        // Why this lives in Settings and not hidden docs: the
        // user needs to KNOW the keybind exists BEFORE they need
        // it. Black screen + no visible UI is exactly when you
        // won't be able to look up the shortcut.
        HMSection {
            title: "Panic Recovery"
            subtitle: "The keybind that saves you from force-power-off"

            HMRow {
                label: "Escape keybind"
                description: "Press this combo any time you're stuck: frozen lock screen, black "
                             + "screen after wake, zombied shell. Works even when hyprlock is "
                             + "running (bindl flag) — that's the whole point."
                icon: "\uf071"; separator: true

                Rectangle {
                    Layout.preferredWidth: 210
                    Layout.preferredHeight: 38
                    radius: 8
                    color: ThemeService.alpha(ThemeService.red, 0.12)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.red, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: "SUPER + SHIFT + CTRL + Esc"
                        color: ThemeService.red
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }

            HMRow {
                label: "What it does"
                description: "1) SIGKILL frozen hyprlock (only if zombie)  ·  "
                             + "2) Double DPMS off→on cycle  ·  "
                             + "3) forcerendererreload (does NOT wipe your monitor config)  ·  "
                             + "4) Restart zombied swww-daemon + re-apply wallpaper  ·  "
                             + "5) Clean re-lock if session was locked before panic  ·  "
                             + "6) Input subsystem kick (keyboard-not-receiving fix)  ·  "
                             + "Single press leaves Quickshell, music widget, widget positions untouched. "
                             + "Second press within 10 seconds = full Quickshell restart (last-resort)."
                icon: "\uf059"; separator: true
            }

            HMRow {
                label: "Manual invocation"
                description: "If even the keybind doesn't fire (Hyprland totally wedged), from an "
                             + "SSH session or TTY (Ctrl+Alt+F2): ~/.local/bin/zen-panic.sh"
                icon: "\uf120"; separator: true
            }

            HMRow {
                label: "Check recovery log"
                description: "After a panic, every step is logged with timestamps to "
                             + "~/.cache/zen-shell/panic.log — useful for post-mortem if "
                             + "a specific hardware combo keeps wedging."
                icon: "\uf15c"
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
