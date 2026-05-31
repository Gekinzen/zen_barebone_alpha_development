import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * DockPage v7.0.0-beta.1-hf82k — Karui (軽い)
 *
 * Settings page for the dock surface. Mirrors GeneralPage / PanelPage
 * visual conventions: HMSection + HMRow + HMSwitch / NumericStepper /
 * ZenDropdown / ColorSwatch.
 *
 * Three sections:
 *   1. General     — enable, position, mode, monitor target
 *   2. Appearance  — sync from bar OR override per-dock visual fields
 *   3. Modules     — enable/disable + reorder which widgets show
 *
 * Wala tayong babawasan — additive page; sidebar entry added in
 * ZenSettings.qml at index 25 (after Game Detection at 24).
 */
ScrollView {
    id: rootView
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        width: rootView.availableWidth - 48
        spacing: 16

        DenshoPageHeader {
            Layout.fillWidth: true
            title: "Dock"
            subtitle: "A second module surface — pin apps, workspaces, sysrow, control center"
            kanji: "土台"
            romaji: "Dodai"
        }

        // ═════════════════════════════════════════════════════════
        // 1. GENERAL
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "General"
            subtitle: "Enable + position the dock"

            HMRow {
                label: "Enable dock"
                description: "Mounts a second surface alongside the bar"
                HMSwitch {
                    checked: DockState.enabled
                    onToggled: DockState.enabled = checked
                }
            }

            HMRow {
                visible: DockState.enabled
                separator: true
                label: "Position"
                description: "Independent of the bar's position"
                ZenDropdown {
                    width: 140
                    model: ["top", "bottom"]
                    currentIndex: DockState.position === "top" ? 0 : 1
                    onActivated: DockState.position = model[currentIndex]
                }
            }

            HMRow {
                visible: DockState.enabled
                label: "Mode"
                description: "Fullwidth = edge-to-edge · Floating = inset · Island = hug-content centered"
                ZenDropdown {
                    width: 140
                    model: ["fullwidth", "floating", "island"]
                    currentIndex: {
                        if (DockState.mode === "fullwidth") return 0
                        if (DockState.mode === "floating")  return 1
                        return 2
                    }
                    onActivated: DockState.mode = model[currentIndex]
                }
            }

            HMRow {
                visible: DockState.enabled
                label: "Show on monitor"
                description: "primary = first screen · all = every screen · or a specific name (e.g. DP-2)"
                ZenDropdown {
                    width: 160
                    preferAbove: true
                    model: {
                        var base = ["primary", "all"]
                        var screens = Quickshell.screens || []
                        for (var i = 0; i < screens.length; i++) {
                            base.push(screens[i].name)
                        }
                        return base
                    }
                    currentIndex: {
                        var i = model.indexOf(DockState.showOnMonitor)
                        return i >= 0 ? i : 0
                    }
                    onActivated: DockState.showOnMonitor = model[currentIndex]
                }
            }

            HMRow {
                visible: DockState.enabled
                separator: true
                label: "Height"
                description: "Dock height in pixels"
                NumericStepper {
                    from: 40; to: 96; stepSize: 2; suffix: "px"
                    value: DockState.height
                    onValueEdited: v => DockState.height = Math.round(v)
                }
            }

            HMRow {
                visible: DockState.enabled
                separator: true
                label: "Icon size"
                description: "Size of the dock app icons, independent of the bar "
                           + "(100% = same as bar). Big icons enlarge the dock surface."
                NumericStepper {
                    from: 60; to: 200; stepSize: 5; suffix: "%"
                    value: Math.round(DockState.iconSizeScale * 100)
                    onValueEdited: v => DockState.iconSizeScale =
                        Math.max(0.6, Math.min(2.0, Math.round(v) / 100))
                }
            }

            HMRow {
                visible: DockState.enabled
                separator: true
                label: "Minimum icon scale"
                description: "In fullwidth/floating, icons shrink to fit when crowded. "
                           + "This is how small they go (% of normal) before scroll "
                           + "arrows appear instead. 100% = arrows immediately."
                NumericStepper {
                    from: 55; to: 100; stepSize: 5; suffix: "%"
                    value: Math.round(DockState.minIconScale * 100)
                    onValueEdited: v => DockState.minIconScale =
                        Math.max(0.55, Math.min(1.0, Math.round(v) / 100))
                }
            }

            HMRow {
                visible: DockState.enabled
                label: "Edge margin"
                description: "Gap between dock and screen edge"
                NumericStepper {
                    from: 0; to: 60; stepSize: 2; suffix: "px"
                    value: DockState.marginEdge
                    onValueEdited: v => DockState.marginEdge = Math.round(v)
                }
            }

            // v7.0.0-beta.1-hf83: reserve space so the dock pushes
            // tiled windows instead of floating over them.
            HMRow {
                visible: DockState.enabled
                separator: true
                label: "Reserve space"
                description: "Push tiled windows so the dock doesn't overlap them"
                HMSwitch {
                    checked: DockState.reserveSpace
                    onToggled: DockState.reserveSpace = checked
                }
            }

            HMRow {
                visible: DockState.enabled && DockState.reserveSpace
                label: "Reserve gap"
                description: "Extra gap between tiled windows and the dock"
                NumericStepper {
                    from: 0; to: 60; stepSize: 2; suffix: "px"
                    value: DockState.reserveGap
                    onValueEdited: v => DockState.reserveGap = Math.round(v)
                }
            }

            HMRow {
                visible: DockState.enabled && DockState.mode !== "fullwidth"
                label: "Side margin"
                description: "Horizontal inset for floating/island modes"
                NumericStepper {
                    from: 0; to: 200; stepSize: 4; suffix: "px"
                    value: DockState.marginSide
                    onValueEdited: v => DockState.marginSide = Math.round(v)
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // 2. APPEARANCE
        // ═════════════════════════════════════════════════════════
        HMSection {
            visible: DockState.enabled
            title: "Appearance"
            subtitle: "Sync visuals from the bar, or set per-dock overrides"

            HMRow {
                label: "Sync from bar"
                description: "Background color, border, corner radius pulled from bar settings"
                HMSwitch {
                    checked: DockState.syncFromBar
                    onToggled: DockState.syncFromBar = checked
                }
            }

            HMRow {
                visible: !DockState.syncFromBar
                separator: true
                label: "Background color"
                ColorSwatch {
                    value: DockState.overrideBgColor
                    onValueEdited: hex => DockState.overrideBgColor = hex
                }
            }

            HMRow {
                visible: !DockState.syncFromBar
                label: "Background opacity"
                NumericStepper {
                    from: 0.0; to: 1.0; stepSize: 0.05; decimals: 2
                    value: DockState.overrideBgOpacity
                    onValueEdited: v => DockState.overrideBgOpacity = v
                }
            }

            HMRow {
                visible: !DockState.syncFromBar
                label: "Border color"
                ColorSwatch {
                    value: DockState.overrideBorderColor
                    onValueEdited: hex => DockState.overrideBorderColor = hex
                }
            }

            HMRow {
                visible: !DockState.syncFromBar
                label: "Border width"
                NumericStepper {
                    from: 0; to: 6; stepSize: 1; suffix: "px"
                    value: DockState.overrideBorderWidth
                    onValueEdited: v => DockState.overrideBorderWidth = Math.round(v)
                }
            }

            HMRow {
                visible: !DockState.syncFromBar
                label: "Corner radius"
                NumericStepper {
                    from: 0; to: 40; stepSize: 1; suffix: "px"
                    value: DockState.overrideCornerRadius
                    onValueEdited: v => DockState.overrideCornerRadius = Math.round(v)
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // 3. MODULES
        // ═════════════════════════════════════════════════════════
        HMSection {
            visible: DockState.enabled
            title: "Modules"
            subtitle: "Which widgets appear on the dock. Use ↑/↓ to reorder."

            // Module list with per-row up/down/remove buttons. Drag-
            // to-reorder LIST UI is feasible but would more than double
            // this file's size; the up/down approach is feature-equivalent
            // and ships in hf82k. Drag list UI candidate for hf82l.
            Repeater {
                model: DockState.modules

                delegate: HMRow {
                    required property string modelData
                    required property int index

                    label: _moduleLabel(modelData)
                    description: _moduleDescription(modelData)

                    RowLayout {
                        spacing: 4

                        // Up
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: upMa.containsMouse
                                ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)
                                : "transparent"
                            opacity: index > 0 ? 1.0 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: "\uf062"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }
                            MouseArea {
                                id: upMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: index > 0
                                onClicked: DockState.moveModule(index, index - 1)
                            }
                        }

                        // Down
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: downMa.containsMouse
                                ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)
                                : "transparent"
                            opacity: index < DockState.modules.length - 1 ? 1.0 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: "\uf063"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }
                            MouseArea {
                                id: downMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: index < DockState.modules.length - 1
                                onClicked: DockState.moveModule(index, index + 1)
                            }
                        }

                        // Remove
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: rmMa.containsMouse
                                ? Qt.rgba(ThemeService.red.r, ThemeService.red.g, ThemeService.red.b, 0.18)
                                : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 12
                                color: rmMa.containsMouse ? ThemeService.red : ThemeService.fg
                            }
                            MouseArea {
                                id: rmMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DockState.setModuleEnabled(modelData, false)
                            }
                        }
                    }
                }
            }

            HMRow {
                separator: true
                label: "Add module"
                description: "Pick a module not yet in the dock to add it to the end"
                ZenDropdown {
                    id: addPicker
                    width: 200
                    preferAbove: true   // hf95.32 — near window bottom; open up
                    model: {
                        const all = ["start", "taskbar", "workspaces",
                                     "divider", "sysrow", "controlcenter",
                                     "tray", "clock", "battery", "notifications"]
                        return all.filter(m => DockState.modules.indexOf(m) === -1)
                    }
                    currentIndex: 0
                    onActivated: {
                        if (model.length === 0) return
                        DockState.setModuleEnabled(model[currentIndex], true)
                    }
                }
            }

            HMRow {
                separator: true
                label: "Reset modules to default"
                description: "Restores the lean default: taskbar + workspaces"
                                ZenButton {
                    text: "Reset"
                    onClicked: {
                        DockState.modules = ["taskbar", "workspaces"]
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }

    function _moduleLabel(id) {
        switch (id) {
            case "start":         return "Start Menu"
            case "taskbar":       return "Taskbar (pinned + running apps)"
            case "workspaces":    return "Workspaces"
            case "divider":       return "Divider"
            case "sysrow":        return "System Tray Row"
            case "controlcenter": return "Control Center"
            case "tray":          return "System Tray"
            case "clock":         return "Clock"
            case "battery":       return "Battery"
            case "notifications": return "Notification Bell"
        }
        return id
    }

    function _moduleDescription(id) {
        switch (id) {
            case "start":         return "App launcher pill"
            case "taskbar":       return "Pinned + running apps — drag to reorder (hf82g)"
            case "workspaces":    return "Workspace number strip with popup preview"
            case "divider":       return "Vertical separator between adjacent modules"
            case "sysrow":        return "Sound, network, BT, brightness cluster"
            case "controlcenter": return "Quick settings (popup ships in hf82l)"
            case "tray":          return "System tray icons"
            case "clock":         return "Time + date display"
            case "battery":       return "Battery indicator"
            case "notifications": return "Notification count + center"
        }
        return ""
    }
}
