import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * BarModulesPage v6.8
 *
 * v6.8: Uniform 320px dropdown widths, HMRow icons, separators.
 * Auto-apply: PanelState properties are bound live by ZenClock.qml
 * and ZenWorkspaces.qml (shipped in tarball). User copies them
 * to ~/.config/quickshell/zen-shell/ as Clock.qml / Workspaces.qml
 * and changes apply instantly — no shell restart needed.
 *
 * WALA TAYONG BABAWASAN from v6.6 originals.
 */
ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    Timer {
        id: clockTick; interval: 1000; repeat: true; running: true
        onTriggered: previewDate = new Date()
    }
    property var previewDate: new Date()
    readonly property int dropdownWidth: 320

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 20
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "Bar Modules"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: ThemeService.fg }
            Text { text: "Format options for clock, workspaces, and font family"; font.family: Theme.fontFamily; font.pixelSize: 12; color: ThemeService.grey1 }
        }

        // Auto-apply install hint
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: autoCol.implicitHeight + 20
            radius: 10
            color: ThemeService.alpha(ThemeService.green, 0.08)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.green, 0.25)

            ColumnLayout {
                id: autoCol
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 4

                Text {
                    text: "\uf0e7  Auto-apply: copy ZenClock.qml → Clock.qml and ZenWorkspaces.qml → Workspaces.qml"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.green
                }
                Text {
                    text: "in ~/.config/quickshell/zen-shell/ — changes apply instantly, no restart"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }
            }
        }

        // ═══ CLOCK ═══
        HMSection {
            title: "Clock"

            HMRow {
                label: "Format"; description: "How the clock displays time and date"
                icon: "\uf017"; separator: true
                ZenDropdown {
                    id: clockCombo; width: root.dropdownWidth
                    model: { const m=[]; for(const f of ZenConstants.clockFormats) m.push(f.label); return m }
                    currentIndex: PanelState.clockFormatIndex
                    onActivated: { PanelState.clockFormatIndex = currentIndex; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Preview"; description: "Live preview"; icon: "\uf06e"
                Rectangle {
                    width: root.dropdownWidth; height: 56; radius: 10
                    color: Qt.rgba(ThemeService.bg2.r, ThemeService.bg2.g, ThemeService.bg2.b, 0.6)
                    border.width: 1; border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.1)
                    Text {
                        anchors.centerIn: parent
                        text: { const idx=Math.max(0,Math.min(ZenConstants.clockFormats.length-1,PanelState.clockFormatIndex))
                            return ZenConstants.formatClock(root.previewDate, ZenConstants.clockFormats[idx].format, true) }
                        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                        font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; color: ThemeService.fg
                    }
                }
            }
        }

        // ═══ WORKSPACES ═══
        HMSection {
            title: "Workspaces"

            HMRow {
                label: "Number format"; description: "Icons for workspace 1-10"
                icon: "\uf24d"; separator: true
                ZenDropdown {
                    id: wsCombo; width: root.dropdownWidth
                    property var presetIds: ["numbers","korean","chinese","japanese","roman",
                                             "nerd-dots","nerd-circles","nerd-squares","symbols","empty","custom"]
                    model: { const m=[]; for(const id of presetIds) m.push(ZenConstants.workspaceFormats[id].name); return m }
                    currentIndex: { const idx=presetIds.indexOf(PanelState.workspaceFormat); return idx>=0?idx:0 }
                    onActivated: { PanelState.workspaceFormat = presetIds[currentIndex]; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Visible count"; description: "How many workspaces shown in bar (3-10)"
                icon: "\uf0c8"; separator: true
                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["3", "4", "5", "6", "7", "8", "9", "10"]
                    currentIndex: Math.max(0, Math.min(7, (PanelState.workspaceLimit || 5) - 3))
                    onActivated: { PanelState.workspaceLimit = currentIndex + 3; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Preview"; description: "How workspaces will look in bar"; icon: "\uf06e"
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: PanelState.workspaceLimit || 5
                        delegate: Rectangle {
                            required property int index
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                            color: index===0 ? Qt.rgba(ThemeService.blue.r,ThemeService.blue.g,ThemeService.blue.b,0.3)
                                             : Qt.rgba(ThemeService.bg2.r,ThemeService.bg2.g,ThemeService.bg2.b,0.5)
                            border.width: 1; border.color: Qt.rgba(ThemeService.fg.r,ThemeService.fg.g,ThemeService.fg.b,0.08)
                            Text {
                                anchors.centerIn: parent
                                text: ZenConstants.workspaceIcon(PanelState.workspaceFormat, index+1)
                                font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                                font.pixelSize: 11; color: ThemeService.fg
                            }
                        }
                    }
                }
            }
        }

        // ═══ FONT ═══
        HMSection {
            title: "Font"

            HMRow {
                label: "Font family"; description: "Primary bar font. Falls back to JetBrainsMono Nerd Font Propo."
                icon: "\uf031"; separator: true
                ZenDropdown {
                    id: fontCombo; width: root.dropdownWidth
                    model: { const m=[]; for(const f of ZenConstants.fontFamilies) m.push(f.label); return m }
                    currentIndex: { for(let i=0;i<ZenConstants.fontFamilies.length;i++)
                        if(ZenConstants.fontFamilies[i].id===PanelState.fontFamilyId) return i; return 0 }
                    onActivated: { PanelState.fontFamilyId = ZenConstants.fontFamilies[currentIndex].id; PanelState.saveState() }
                }
            }

            HMRow {
                label: "Preview"; description: "Sample text"; icon: "\uf06e"
                Rectangle {
                    width: root.dropdownWidth; height: 48; radius: 10
                    color: Qt.rgba(ThemeService.bg2.r,ThemeService.bg2.g,ThemeService.bg2.b,0.6)
                    border.width: 1; border.color: Qt.rgba(ThemeService.fg.r,ThemeService.fg.g,ThemeService.fg.b,0.1)
                    Text {
                        anchors.centerIn: parent
                        text: "The quick brown fox  \uf017  \uf015  \uf1e5"
                        font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                        font.pixelSize: 14; color: ThemeService.fg
                    }
                }
            }
        }

        // ═══ START MENU (v7.0.0-alpha.4) ═══
        //
        // Dynamic pinned-grid configuration for the dual-pane Start
        // Menu Panel. Cols clamped 3-6, rows 1-8 by the panel itself;
        // here we surface them as steppers. Changes apply instantly
        // (PanelState fires propertyChanged → menuRoot rebinds).
        HMSection {
            title: "Start Menu"
            subtitle: "Pinned-apps grid layout for the dual-pane panel"

            HMRow {
                label: "Pinned grid columns"
                description: "How many app tiles per row in the pinned section (3-6)"
                icon: "\uf0db"   // columns
                separator: true

                NumericStepper {
                    value: PanelState.pinnedGridCols
                    from: 3
                    to: 6
                    stepSize: 1
                    onValueChanged: {
                        PanelState.pinnedGridCols = value
                        PanelState.saveState()
                    }
                }
            }

            HMRow {
                label: "Pinned grid rows"
                description: "How many rows tall the pinned section grows (1-8)"
                icon: "\uf0c9"   // rows / bars
                separator: true

                NumericStepper {
                    value: PanelState.pinnedGridRows
                    from: 1
                    to: 8
                    stepSize: 1
                    onValueChanged: {
                        PanelState.pinnedGridRows = value
                        PanelState.saveState()
                    }
                }
            }

            HMRow {
                label: "Panel border"
                description: "Off · Match Bar (continuous with bar border) · Thick (emphasized 2× width)"
                icon: "\uf2d2"   // border-style
                separator: true

                ZenDropdown {
                    width: root.dropdownWidth
                    model: ["Off", "Match Bar", "Thick"]
                    currentIndex: {
                        switch (PanelState.startMenuBorderMode) {
                            case "off":       return 0
                            case "match-bar": return 1
                            case "thick":     return 2
                            default:          return 1
                        }
                    }
                    onActivated: {
                        const modes = ["off", "match-bar", "thick"]
                        PanelState.startMenuBorderMode = modes[currentIndex] || "match-bar"
                        PanelState.saveState()
                    }
                }
            }

            HMRow {
                label: "Auto-detect apps"
                description: "Detected from pacman, AUR (yay/paru → ~/.local/share/applications), "
                             + "Flatpak (system + user), and Snap. Auto-refreshes within ~500ms after install."
                icon: "\uf0c2"   // cloud (info-only row)

                Text {
                    text: typeof AppLauncherService !== "undefined"
                        ? AppLauncherService.apps.length + " apps detected"
                        : "service unavailable"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: ThemeService.grey1
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // v6.16.3.4.5 — Bar module visibility toggles
        // ═══════════════════════════════════════════════════════════
        //
        // Source of truth for the full layout is bar-layout.json under
        // Quickshell.dataPath() — the helper scripts in ~/.local/bin/
        // are the canonical mutators (they use jq for JSON-safe edits
        // and write .bak backups).
        //
        // QML side: we bind `checked` to the presence of the module
        // name in Theme.barLayout.right, fire the corresponding helper
        // script on toggle, then call Theme.reloadBarLayout() to
        // propagate the change to every subscribed surface (including
        // Bar.qml's Repeaters, which re-instantiate the component
        // chain immediately — no shell restart needed).
        HMSection {
            title: "Optional Bar Modules"
            subtitle: "Additive toggles — mutates ~/.local/share/quickshell/zen-shell/bar-layout.json"

            HMRow {
                label: "Power Profile badge"
                description: "Small pill showing current power profile + GPU mode. "
                             + "Hides itself on systems without powerprofilesctl or multi-GPU."
                icon: "\uf0e7"   // fa-bolt
                separator: true

                HMSwitch {
                    id: powerBadgeSwitch
                    // Compute from live Theme.barLayout so external edits
                    // (manual jq, another shell instance) reflect here too.
                    checked: {
                        const r = Theme.barLayout.right || []
                        return r.indexOf("powerbadge") >= 0
                    }
                    onToggled: {
                        // Flip the intended state ourselves, then run the
                        // matching script. The reload() call at onExited
                        // picks up the new JSON and re-binds Theme.barLayout
                        // so every other surface (Bar.qml, diagnostic pills,
                        // this very switch) updates automatically.
                        const nextOn = !checked
                        powerBadgeProc.command = nextOn
                            ? ["bash", "-c", "~/.local/bin/zen-bar-add-powerbadge.sh || true"]
                            : ["bash", "-c", "~/.local/bin/zen-bar-add-powerbadge.sh --remove || true"]
                        powerBadgeProc.running = true
                    }
                }
            }

            HMRow {
                label: "Reload shell after change"
                description: "The bar re-renders instantly after toggle — but if the badge "
                             + "doesn't appear, click here to force a shell restart."
                icon: "\uf021"  // fa-refresh
                                ZenButton {
                    text: "Restart shell"
                    onClicked: reloadShellProc.running = true
                }
            }
        }

        Process {
            id: powerBadgeProc
            running: false
            onExited: (exitCode) => {
                // Small delay so the jq write completes flushing to disk
                // before FileView.reload() tries to re-read it.
                Qt.callLater(Theme.reloadBarLayout)
            }
        }
        Process {
            id: reloadShellProc
            running: false
            command: ["bash", "-c", "~/.local/bin/zs-restart.sh &"]
        }

        PageFooter {
            description: "Changes auto-save • copy ZenClock.qml + ZenWorkspaces.qml for instant bar updates"
            onResetRequested: {
                PanelState.clockFormatIndex = 6
                PanelState.workspaceFormat = "numbers"
                PanelState.fontFamilyId = "jetbrains"
                PanelState.saveState()
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
