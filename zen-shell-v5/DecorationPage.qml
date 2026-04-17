import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * DecorationPage — HyprMod-style Decoration settings
 *
 * Sections: Rounding, Opacity, Dimming, Blur, Shadow.
 * Mirrors HyprMod's options.json decoration group structure.
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 20
        spacing: 18

        // ── Page header ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "Decoration"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Rounding, opacity, dimming, blur, shadows"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        // ═════════════════════════════════════════════════════════
        // ROUNDING
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Rounding"

            HMRow {
                label: "Corner rounding"
                description: "Radius of rounded corners in pixels"
                NumericStepper {
                    from: 0; to: 30; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.rounding
                    onValueEdited: v => {
                        SettingsStateV2.rounding = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword decoration:rounding " + Math.round(v))
                    }
                }
            }

            HMRow {
                label: "Rounding power"
                description: "Higher = smoother super-ellipse; lower = sharper circular"
                NumericStepper {
                    from: 2.0; to: 10.0; stepSize: 0.1; decimals: 1
                    value: SettingsStateV2.roundingPower
                    onValueEdited: v => {
                        SettingsStateV2.roundingPower = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:rounding_power " + v.toFixed(2))
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // OPACITY
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Opacity"

            HMRow {
                label: "Active opacity"
                description: "Opacity of active windows (0.0–1.0)"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: SettingsStateV2.activeOpacity
                    onValueEdited: v => {
                        SettingsStateV2.activeOpacity = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:active_opacity " + v.toFixed(2))
                    }
                }
            }

            HMRow {
                label: "Inactive opacity"
                description: "Opacity of inactive windows (0.0–1.0)"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: SettingsStateV2.inactiveOpacity
                    onValueEdited: v => {
                        SettingsStateV2.inactiveOpacity = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:inactive_opacity " + v.toFixed(2))
                    }
                }
            }

            HMRow {
                label: "Fullscreen opacity"
                description: "Opacity of fullscreen windows"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: SettingsStateV2.fullscreenOpacity
                    onValueEdited: v => {
                        SettingsStateV2.fullscreenOpacity = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:fullscreen_opacity " + v.toFixed(2))
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // DIMMING
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Dimming"

            HMRow {
                label: "Dim inactive"
                description: "Dim inactive windows"
                Switch {
                    checked: SettingsStateV2.dimInactive
                    onToggled: {
                        SettingsStateV2.dimInactive = checked
                        SettingsStateV2.hyprctlNow("decoration:dim_inactive", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.dimInactive
                label: "Dim strength"
                description: "How much to dim inactive windows"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: SettingsStateV2.dimStrength
                    onValueEdited: v => {
                        SettingsStateV2.dimStrength = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:dim_strength " + v.toFixed(2))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.dimInactive
                label: "Dim around"
                description: "Dim factor for floating windows when a dialog is open"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: SettingsStateV2.dimAround
                    onValueEdited: v => {
                        SettingsStateV2.dimAround = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:dim_around " + v.toFixed(2))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.dimInactive
                label: "Dim special"
                description: "Dim the rest of the screen when a special workspace is open"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: SettingsStateV2.dimSpecial
                    onValueEdited: v => {
                        SettingsStateV2.dimSpecial = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:dim_special " + v.toFixed(2))
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // BLUR
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Blur"

            HMRow {
                label: "Enable blur"
                description: "Enable background blur effect"
                Switch {
                    checked: SettingsStateV2.blurEnabled
                    onToggled: {
                        SettingsStateV2.blurEnabled = checked
                        SettingsStateV2.hyprctlNow("decoration:blur:enabled", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Blur size"
                description: "Blur radius in pixels"
                NumericStepper {
                    from: 1; to: 20; stepSize: 1
                    value: SettingsStateV2.blurSize
                    onValueEdited: v => {
                        SettingsStateV2.blurSize = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword decoration:blur:size " + Math.round(v))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Blur passes"
                description: "More passes = smoother blur (costs performance)"
                NumericStepper {
                    from: 1; to: 5; stepSize: 1
                    value: SettingsStateV2.blurPasses
                    onValueEdited: v => {
                        SettingsStateV2.blurPasses = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword decoration:blur:passes " + Math.round(v))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "New optimizations"
                description: "Enable further optimizations to the blur (recommended)"
                Switch {
                    checked: SettingsStateV2.blurNewOptimizations
                    onToggled: {
                        SettingsStateV2.blurNewOptimizations = checked
                        SettingsStateV2.hyprctlNow("decoration:blur:new_optimizations", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "X-ray"
                description: "Floating windows ignore tiled windows in blur calculation"
                Switch {
                    checked: SettingsStateV2.blurXray
                    onToggled: {
                        SettingsStateV2.blurXray = checked
                        SettingsStateV2.hyprctlNow("decoration:blur:xray", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Ignore opacity"
                description: "Blur behavior ignores window opacity"
                Switch {
                    checked: SettingsStateV2.blurIgnoreOpacity
                    onToggled: {
                        SettingsStateV2.blurIgnoreOpacity = checked
                        SettingsStateV2.hyprctlNow("decoration:blur:ignore_opacity", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Noise"
                description: "How much noise to apply to the blur"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.01; decimals: 3
                    value: SettingsStateV2.blurNoise
                    onValueEdited: v => {
                        SettingsStateV2.blurNoise = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:blur:noise " + v.toFixed(4))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Contrast"
                description: "Contrast modulation for blur"
                NumericStepper {
                    from: 0.0; to: 2.0; stepSize: 0.05; decimals: 3
                    value: SettingsStateV2.blurContrast
                    onValueEdited: v => {
                        SettingsStateV2.blurContrast = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:blur:contrast " + v.toFixed(4))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Brightness"
                description: "Brightness modulation for blur"
                NumericStepper {
                    from: 0.0; to: 2.0; stepSize: 0.05; decimals: 3
                    value: SettingsStateV2.blurBrightness
                    onValueEdited: v => {
                        SettingsStateV2.blurBrightness = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:blur:brightness " + v.toFixed(4))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.blurEnabled
                label: "Vibrancy"
                description: "Increase saturation of blurred colors"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 3
                    value: SettingsStateV2.blurVibrancy
                    onValueEdited: v => {
                        SettingsStateV2.blurVibrancy = v
                        SettingsStateV2.scheduleHyprctl("keyword decoration:blur:vibrancy " + v.toFixed(4))
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // SHADOW
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Shadow"

            HMRow {
                label: "Enable shadow"
                description: "Drop shadow for windows"
                Switch {
                    checked: SettingsStateV2.shadowEnabled
                    onToggled: {
                        SettingsStateV2.shadowEnabled = checked
                        SettingsStateV2.hyprctlNow("decoration:shadow:enabled", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.shadowEnabled
                label: "Shadow range"
                description: "Size of the shadow in pixels"
                NumericStepper {
                    from: 0; to: 50; stepSize: 1; suffix: "px"
                    value: SettingsStateV2.shadowRange
                    onValueEdited: v => {
                        SettingsStateV2.shadowRange = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword decoration:shadow:range " + Math.round(v))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.shadowEnabled
                label: "Render power"
                description: "Higher values produce a faster shadow falloff"
                NumericStepper {
                    from: 1; to: 10; stepSize: 1
                    value: SettingsStateV2.shadowRenderPower
                    onValueEdited: v => {
                        SettingsStateV2.shadowRenderPower = Math.round(v)
                        SettingsStateV2.scheduleHyprctl("keyword decoration:shadow:render_power " + Math.round(v))
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.shadowEnabled
                label: "Ignore window"
                description: "Shadow does not render behind the window itself"
                Switch {
                    checked: SettingsStateV2.shadowIgnoreWindow
                    onToggled: {
                        SettingsStateV2.shadowIgnoreWindow = checked
                        SettingsStateV2.hyprctlNow("decoration:shadow:ignore_window", checked ? "true" : "false")
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.shadowEnabled
                label: "Shadow color"
                description: "Color of the shadow (active window)"
                ColorSwatch {
                    value: SettingsStateV2.shadowColor
                    onValueEdited: hex => {
                        SettingsStateV2.shadowColor = hex
                        SettingsStateV2.hyprctlColor("decoration:shadow:color", hex)
                    }
                }
            }

            HMRow {
                visible: SettingsStateV2.shadowEnabled
                label: "Shadow color (inactive)"
                description: "Color of the shadow for inactive windows"
                ColorSwatch {
                    value: SettingsStateV2.shadowColorInactive
                    onValueEdited: hex => {
                        SettingsStateV2.shadowColorInactive = hex
                        SettingsStateV2.hyprctlColor("decoration:shadow:color_inactive", hex)
                    }
                }
            }
        }

        // Footer
        PageFooter {
            description: "Auto-saves • reads current Hyprland values on open"
            onResetRequested: SettingsStateV2.resetDecorationDefaults()
        }

        Item { Layout.preferredHeight: 24 }
    }
}
