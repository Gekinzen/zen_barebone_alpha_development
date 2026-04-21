import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ScrollView {
    id: root
    clip: true

    property string currentPreset: "Default (Current)"

    // v6.9: Persist selected preset name so it survives logout/reload
    readonly property string animStatePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/animation-state.json"

    function saveAnimState() {
        animStateSaver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + animStatePath + "') && " +
            "echo '{\"preset\":\"" + currentPreset.replace(/"/g, '\\"') + "\"}' > '" + animStatePath + "'"]
        animStateSaver.running = true
    }
    Process { id: animStateSaver; running: false }

    FileView {
        id: animStateLoader
        path: root.animStatePath
        blockLoading: false
        onLoaded: {
            try {
                const s = JSON.parse(this.text())
                if (s.preset && root.presetNames.indexOf(s.preset) >= 0) {
                    root.currentPreset = s.preset
                }
            } catch (e) {}
        }
    }
    Component.onCompleted: animStateLoader.reload()

    readonly property var presetNames: [
        "Default (Current)", "Classic", "HyDe Diablo-1", "HyDe Diablo-2",
        "Disabled", "HyDe Dynamic", "End4 Animation", "Fast", "High",
        "Ja (JaKooLit)", "LimeFrenzy", "Me-1", "Me-2", "Minimal-1",
        "Minimal-2", "Moving", "Optimized", "Standard", "Vertical",
        "Elifouts", "Linuxfam"
    ]

    readonly property var presets: ({
"Default (Current)": "animations {\n    enabled = yes, please :)\n    bezier = easeOutQuint, 0.23, 1, 0.32, 1\n    bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1\n    bezier = linear, 0, 0, 1, 1\n    bezier = almostLinear, 0.5, 0.5, 0.75, 1\n    bezier = quick, 0.15, 0, 0.1, 1\n    animation = global, 1, 10, default\n    animation = border, 1, 5.39, easeOutQuint\n    animation = windows, 1, 4.79, easeOutQuint\n    animation = windowsIn, 1, 4.1, easeOutQuint, popin 87%\n    animation = windowsOut, 1, 1.49, linear, popin 87%\n    animation = fadeIn, 1, 1.73, almostLinear\n    animation = fadeOut, 1, 1.46, almostLinear\n    animation = fade, 1, 3.03, quick\n    animation = layers, 1, 3.81, easeOutQuint\n    animation = layersIn, 1, 4, easeOutQuint, fade\n    animation = layersOut, 1, 1.5, linear, fade\n    animation = fadeLayersIn, 1, 1.79, almostLinear\n    animation = fadeLayersOut, 1, 1.39, almostLinear\n    animation = workspaces, 1, 1.94, almostLinear, fade\n    animation = workspacesIn, 1, 1.21, almostLinear, fade\n    animation = workspacesOut, 1, 1.94, almostLinear, fade\n    animation = zoomFactor, 1, 7, quick\n}",
"Classic": "animations {\n    enabled = true\n    bezier = myBezier, 0.05, 0.9, 0.1, 1.05\n    animation = windows, 1, 7, myBezier\n    animation = windowsOut, 1, 7, default, popin 80%\n    animation = border, 1, 10, default\n    animation = borderangle, 1, 8, default\n    animation = fade, 1, 7, default\n    animation = workspaces, 1, 6, default\n}",
"HyDe Diablo-1": "animations {\n    enabled = 1\n    bezier = default, 0.05, 0.9, 0.1, 1.05\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = overshot, 0.13, 0.99, 0.29, 1.08\n    bezier = liner, 1, 1, 1, 1\n    bezier = bounce, 0.4, 0.9, 0.6, 1.0\n    bezier = snappyReturn, 0.4, 0.9, 0.6, 1.0\n    animation = windows, 1, 5, snappyReturn, slidevert\n    animation = windowsIn, 1, 5, snappyReturn, slidevert right\n    animation = windowsOut, 1, 5, snappyReturn, slide\n    animation = windowsMove, 1, 6, bounce, slide\n    animation = layersOut, 1, 5, bounce, slidevert right\n    animation = fadeIn, 1, 10, default\n    animation = fadeOut, 1, 10, default\n    animation = workspaces, 1, 7, overshot, slidevert\n    animation = border, 1, 1, liner\n    animation = layers, 1, 4, bounce, slidevert right\n    animation = borderangle, 1, 30, liner, loop\n}",
"HyDe Diablo-2": "animations {\n    enabled = 1\n    bezier = default, 0.05, 0.9, 0.1, 1.05\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = overshot, 0.13, 0.99, 0.29, 1.08\n    bezier = liner, 1, 1, 1, 1\n    animation = windows, 1, 7, wind, popin\n    animation = windowsIn, 1, 7, overshot, popin\n    animation = windowsOut, 1, 5, overshot, popin\n    animation = windowsMove, 1, 6, overshot, slide\n    animation = layers, 1, 5, default, popin\n    animation = fadeIn, 1, 10, default\n    animation = fadeOut, 1, 10, default\n    animation = workspaces, 1, 7, overshot, slidevert\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 30, liner, loop\n}",
"Disabled": "animations {\n    enabled = false\n}",
"HyDe Dynamic": "animations {\n    enabled = true\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = winIn, 0.1, 1.1, 0.1, 1.1\n    bezier = winOut, 0.3, -0.3, 0, 1\n    bezier = liner, 1, 1, 1, 1\n    animation = windows, 1, 6, wind, slide\n    animation = windowsIn, 1, 6, winIn, slide\n    animation = windowsOut, 1, 5, winOut, slide\n    animation = windowsMove, 1, 5, wind, slide\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 30, liner, loop\n    animation = fade, 1, 10, default\n    animation = workspaces, 1, 5, wind\n}",
"End4 Animation": "animations {\n    enabled = true\n    bezier = md3_decel, 0.05, 0.7, 0.1, 1\n    bezier = md3_accel, 0.3, 0, 0.8, 0.15\n    bezier = overshot, 0.05, 0.9, 0.1, 1.1\n    bezier = menu_decel, 0.1, 1, 0, 1\n    bezier = menu_accel, 0.38, 0.04, 1, 0.07\n    animation = windows, 1, 3, md3_decel, popin 60%\n    animation = windowsIn, 1, 3, md3_decel, popin 60%\n    animation = windowsOut, 1, 3, md3_accel, popin 60%\n    animation = border, 1, 10, default\n    animation = fade, 1, 3, md3_decel\n    animation = layersIn, 1, 3, menu_decel, slide\n    animation = layersOut, 1, 1.6, menu_accel\n    animation = fadeLayersIn, 1, 2, menu_decel\n    animation = fadeLayersOut, 1, 4.5, menu_accel\n    animation = workspaces, 1, 7, menu_decel, slide\n    animation = specialWorkspace, 1, 3, md3_decel, slidevert\n}",
"Fast": "animations {\n    enabled = true\n    bezier = md3_decel, 0.05, 0.7, 0.1, 1\n    animation = windows, 1, 3, md3_decel, popin 60%\n    animation = border, 1, 10, default\n    animation = fade, 1, 2.5, md3_decel\n    animation = workspaces, 1, 3.5, md3_decel, slide\n}",
"High": "animations {\n    enabled = true\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = winIn, 0.1, 1.1, 0.1, 1.1\n    bezier = winOut, 0.3, -0.3, 0, 1\n    bezier = liner, 1, 1, 1, 1\n    animation = windows, 1, 6, wind, slide\n    animation = windowsIn, 1, 6, winIn, slide\n    animation = windowsOut, 1, 5, winOut, slide\n    animation = windowsMove, 1, 5, wind, slide\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 30, liner, loop\n    animation = fade, 1, 10, default\n    animation = workspaces, 1, 5, wind\n}",
"Ja (JaKooLit)": "animations {\n    enabled = yes\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = winIn, 0.1, 1.1, 0.1, 1.1\n    bezier = winOut, 0.3, -0.3, 0, 1\n    bezier = liner, 1, 1, 1, 1\n    bezier = overshot, 0.05, 0.9, 0.1, 1.05\n    bezier = smoothOut, 0.5, 0, 0.99, 0.99\n    bezier = smoothIn, 0.5, -0.5, 0.68, 1.5\n    animation = windows, 1, 6, wind, slide\n    animation = windowsIn, 1, 5, winIn, slide\n    animation = windowsOut, 1, 3, smoothOut, slide\n    animation = windowsMove, 1, 5, wind, slide\n    animation = border, 1, 1, liner\n    animation = fade, 1, 3, smoothOut\n    animation = workspaces, 1, 5, overshot\n}",
"LimeFrenzy": "animations {\n    enabled = 1\n    bezier = overshot, 0.18, 0.95, 0.22, 1.03\n    bezier = liner, 1, 1, 1, 1\n    animation = windows, 1, 5, overshot, popin 60%\n    animation = windowsIn, 1, 6, overshot, popin 60%\n    animation = windowsOut, 1, 4, overshot, popin 60%\n    animation = layers, 1, 4, default, popin\n    animation = fadeIn, 1, 7, default\n    animation = fadeOut, 1, 7, default\n    animation = workspaces, 1, 5, overshot, slidevert\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 24, liner, loop\n}",
"Me-1": "animations {\n    enabled = true\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = winIn, 0.1, 1.1, 0.1, 1.1\n    bezier = liner, 1, 1, 1, 1\n    bezier = md3_decel, 0.05, 0.7, 0.1, 1\n    bezier = menu_decel, 0.1, 1, 0, 1\n    bezier = menu_accel, 0.38, 0.04, 1, 0.07\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 30, liner, loop\n    animation = windows, 1, 6, wind, slide\n    animation = windowsIn, 1, 6, winIn, slide\n    animation = windowsOut, 1, 5, wind, slide\n    animation = windowsMove, 1, 5, wind, slide\n    animation = fade, 1, 3, md3_decel\n    animation = layersIn, 1, 3, menu_decel, slide\n    animation = layersOut, 1, 1.6, menu_accel\n    animation = fadeLayersIn, 1, 2, menu_decel\n    animation = fadeLayersOut, 1, 4.5, menu_accel\n    animation = workspaces, 1, 7, menu_decel, slide\n    animation = specialWorkspace, 1, 3, md3_decel, slidevert\n}",
"Me-2": "animations {\n    enabled = true\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = winIn, 0.1, 1.1, 0.1, 1.1\n    bezier = liner, 1, 1, 1, 1\n    bezier = md3_decel, 0.05, 0.7, 0.1, 1\n    bezier = menu_decel, 0.1, 1, 0, 1\n    bezier = menu_accel, 0.38, 0.04, 1, 0.07\n    bezier = OutBack, 0.34, 1.56, 0.64, 1\n    bezier = easeInOutCirc, 0.85, 0, 0.15, 1\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 30, liner, loop\n    animation = windowsIn, 1, 6, winIn, slide\n    animation = windows, 1, 5, easeInOutCirc\n    animation = windowsOut, 1, 5, OutBack\n    animation = windowsMove, 1, 5, wind, slide\n    animation = fade, 1, 3, md3_decel\n    animation = layersIn, 1, 3, menu_decel, slide\n    animation = layersOut, 1, 1.6, menu_accel\n    animation = fadeLayersIn, 1, 2, menu_decel\n    animation = fadeLayersOut, 1, 4.5, menu_accel\n    animation = workspaces, 1, 7, menu_decel, slide\n    animation = specialWorkspace, 1, 3, md3_decel, slidevert\n}",
"Minimal-1": "animations {\n    enabled = true\n    bezier = wind, 0.05, 0.9, 0.1, 1.05\n    bezier = liner, 1, 1, 1, 1\n    animation = windows, 1, 6, wind, slide\n    animation = windowsIn, 1, 6, wind, slide\n    animation = windowsOut, 1, 5, wind, slide\n    animation = windowsMove, 1, 5, wind, slide\n    animation = border, 1, 1, liner\n    animation = borderangle, 1, 30, liner, loop\n    animation = fade, 1, 10, default\n    animation = workspaces, 1, 5, wind\n}",
"Minimal-2": "animations {\n    enabled = yes\n    bezier = quart, 0.25, 1, 0.5, 1\n    animation = windows, 1, 6, quart, slide\n    animation = border, 1, 6, quart\n    animation = borderangle, 1, 6, quart\n    animation = fade, 1, 6, quart\n    animation = workspaces, 1, 6, quart\n}",
"Moving": "animations {\n    enabled = true\n    bezier = overshot, 0.05, 0.9, 0.1, 1.05\n    bezier = smoothOut, 0.5, 0, 0.99, 0.99\n    bezier = smoothIn, 0.5, -0.5, 0.68, 1.5\n    animation = windows, 1, 5, overshot, slide\n    animation = windowsOut, 1, 3, smoothOut\n    animation = windowsIn, 1, 3, smoothOut\n    animation = windowsMove, 1, 4, smoothIn, slide\n    animation = border, 1, 5, default\n    animation = fade, 1, 5, smoothIn\n    animation = fadeDim, 1, 5, smoothIn\n    animation = workspaces, 1, 6, default\n}",
"Optimized": "animations {\n    enabled = true\n    bezier = wind, 0.05, 0.85, 0.03, 0.97\n    bezier = winIn, 0.07, 0.88, 0.04, 0.99\n    bezier = liner, 1, 1, 1, 1\n    bezier = md3_decel, 0.05, 0.80, 0.10, 0.97\n    bezier = menu_decel, 0.05, 0.82, 0, 1\n    bezier = menu_accel, 0.20, 0, 0.82, 0.10\n    bezier = easeOutCirc, 0, 0.48, 0.38, 1\n    animation = border, 1, 1.6, liner\n    animation = borderangle, 1, 82, liner, loop\n    animation = windowsIn, 1, 3.2, winIn, slide\n    animation = windowsOut, 1, 2.8, easeOutCirc\n    animation = windowsMove, 1, 3.0, wind, slide\n    animation = fade, 1, 1.8, md3_decel\n    animation = layersIn, 1, 1.8, menu_decel, slide\n    animation = layersOut, 1, 1.5, menu_accel\n    animation = fadeLayersIn, 1, 1.6, menu_decel\n    animation = fadeLayersOut, 1, 1.8, menu_accel\n    animation = workspaces, 1, 4.0, menu_decel, slide\n    animation = specialWorkspace, 1, 2.3, md3_decel, slidefadevert 15%\n}",
"Standard": "animations {\n    enabled = true\n    bezier = myBezier, 0.05, 0.9, 0.1, 1.05\n    animation = windows, 1, 7, myBezier\n    animation = windowsOut, 1, 7, default, popin 80%\n    animation = border, 1, 10, default\n    animation = borderangle, 1, 8, default\n    animation = fade, 1, 7, default\n    animation = workspaces, 1, 6, default\n}",
"Vertical": "animations {\n    bezier = fluent_decel, 0, 0.2, 0.4, 1\n    bezier = easeOutCirc, 0, 0.55, 0.45, 1\n    bezier = easeOutCubic, 0.33, 1, 0.68, 1\n    bezier = easeinoutsine, 0.37, 0, 0.63, 1\n    animation = windowsIn, 1, 1.5, easeinoutsine, popin 60%\n    animation = windowsOut, 1, 1.5, easeOutCubic, popin 60%\n    animation = windowsMove, 1, 1.5, easeinoutsine, slide\n    animation = fade, 1, 2.5, fluent_decel\n    animation = fadeLayersIn, 0\n    animation = border, 0\n    animation = layers, 1, 1.5, easeinoutsine, popin\n    animation = workspaces, 1, 3, fluent_decel, slidefadevert 30%\n    animation = specialWorkspace, 1, 2, fluent_decel, slidefade 10%\n}",
"Elifouts": "animations {\n    enabled = true\n    bezier = fluid, 0.15, 0.85, 0.25, 1\n    bezier = snappy, 0.3, 1, 0.4, 1\n    animation = windows, 1, 3, fluid, popin 5%\n    animation = windowsOut, 1, 2.5, snappy\n    animation = fade, 1, 4, snappy\n    animation = workspaces, 1, 1.7, snappy, slide\n    animation = specialWorkspace, 1, 4, fluid, slidefadevert -35%\n    animation = layers, 1, 2, snappy, popin 70%\n}",
"Linuxfam": "animations {\n    enabled = true\n    bezier = myBezier, 0.05, 0.9, 0.1, 1.05\n    animation = windows, 1, 7, myBezier\n    animation = windowsIn, 1, 8, default, slide bottom\n    animation = windowsOut, 1, 7, default, slide right\n    animation = border, 1, 10, default\n    animation = borderangle, 1, 8, default\n    animation = fade, 1, 7, default\n    animation = workspaces, 1, 6, default\n}"
    })

    function applyPreset(name) {
        if (!presets[name]) return
        currentPreset = name
        saveAnimState()
        const path = Quickshell.env("HOME") + "/.config/hypr/modules/animations.conf"
        const content = "# Generated by Zen Settings — preset: " + name + "\n" + presets[name] + "\n"
        writeProc.command = ["bash", "-c",
            "mkdir -p $(dirname '" + path + "') && cat > '" + path + "' << 'ZENEOF'\n" + content + "\nZENEOF\n" +
            "hyprctl reload && echo OK"]
        writeProc.running = true
    }

    // v6.16.1.6: After `hyprctl reload`, Hyprland re-parses ~/.config/hypr/hyprland.conf
    // from scratch, which WIPES all runtime-applied keyword values from SettingsStateV2
    // (gaps, borders, rounding, blur, etc. reset to hyprland.conf defaults). Settings
    // appeared to "come back" only when the user opened Themes page because that re-
    // triggers applyToHyprland(). Fix: after reload completes, immediately re-push
    // SettingsStateV2's saved values so the user sees their configured state preserved.
    Process { id: writeProc; running: false
        onExited: (exitCode) => {
            if (typeof SettingsStateV2 !== "undefined" && exitCode === 0) {
                Qt.callLater(SettingsStateV2.applyToHyprland)
            }
        }
    }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Animations"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "21 community presets — auto-applies to Hyprland"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        ControlCenterBanner {
            feature: "Animation Bezier Editor"
            description: "Custom curves, per-animation tuning"
        }

        SettingsSection {
            title: "Preset"

            SettingRow {
                label: "Select Preset"
                description: "Writes to ~/.config/hypr/modules/animations.conf + hyprctl reload"

                ComboBox {
                    width: 220
                    model: root.presetNames
                    currentIndex: model.indexOf(root.currentPreset)
                    onActivated: root.applyPreset(currentText)
                }
            }
        }

        SettingsSection {
            title: "Preview"

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                color: ThemeService.alpha(ThemeService.bg0, 0.8)
                radius: 8
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.1)
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    contentWidth: previewText.implicitWidth
                    contentHeight: previewText.implicitHeight
                    clip: true

                    Text {
                        id: previewText
                        text: root.presets[root.currentPreset] || ""
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                        color: ThemeService.grey0
                    }
                }
            }
        }

        PageFooter {
            description: "Applies instantly via hyprctl reload"
            onResetRequested: root.applyPreset("Default (Current)")
        }

        Item { Layout.preferredHeight: 24 }
    }
}
