import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/*
 * BarVertical.qml v7.0.0-beta.1-hf90.2 — Karui (軽い)
 *
 * Dedicated VERTICAL bar content — Tategaki (縦書き).
 *
 * This is a SEPARATE component from Bar.qml on purpose (the end-4
 * architecture: a dedicated vertical content tree rather than cramming
 * orientation logic into the horizontal bar). shell.qml mounts this via
 * its own Loader that is active only when PanelState.isVertical, so the
 * horizontal Bar.qml is never touched by vertical logic and top/bottom
 * cannot regress.
 *
 * Layout: three vertical zones — TOP / CENTER (fills) / BOTTOM — mapped
 * from the user's existing bar layout:
 *   Theme.barLayout.left   → TOP
 *   Theme.barLayout.center → CENTER
 *   Theme.barLayout.right  → BOTTOM
 * Modules are AlignHCenter so they sit centered in the thin bar.
 *
 * Each module is wrapped in a VerticalModuleHost that constrains its
 * width to the bar thickness and lets tall content flow downward, so a
 * horizontally-designed module degrades gracefully (clipped to the
 * thickness) instead of forcing the bar wide. Modules that already adapt
 * (Workspaces in a column, single-icon, Clock, Battery) look correct;
 * the wide cluster modules (Taskbar, SysRow) get proper vertical modes
 * in a follow-up (Phase 2).
 *
 * Wala tayong babawasan — this only adds a vertical renderer; nothing
 * about the horizontal bar changes.
 */
Rectangle {
    id: barRootV
    radius: Theme.styleMode === "round" ? 22 : Theme.barRadius

    // Same background treatment as the horizontal bar.
    color: {
        if (PanelState.bgOverrideEnabled) {
            return Qt.rgba(
                PanelState.bgOverrideColor.r,
                PanelState.bgOverrideColor.g,
                PanelState.bgOverrideColor.b,
                PanelState.bgOverrideOpacity
            )
        }
        return Qt.rgba(
            ThemeService.bg0.r,
            ThemeService.bg0.g,
            ThemeService.bg0.b,
            Theme.barOpacity
        )
    }

    border.width: PanelState.borderEnabled ? PanelState.borderWidth : 0
    border.color: PanelState.borderColor

    // The thickness available for module content (bar width minus a small
    // inset). Modules are constrained to this so the bar stays thin.
    readonly property int contentThickness: Math.max(24, width - 8)

    // v7.0.0-beta.1-hf95.7: GLOBAL scale-to-fit. When the stacked modules
    // need more height than the bar has, scale the WHOLE column down so
    // everything stays visible (same idea as SysRow's expanded cluster,
    // applied to the entire vertical bar). 1.0 when it already fits → no
    // change for users whose bar isn't full. Modules are pinned to their
    // preferred height (see VerticalModuleHost) so they OVERFLOW rather
    // than squish, and this single scale then compresses the overflow to
    // fit cleanly. The music string overlay reads the same factor so it
    // scales in sync. Wala tayong babawasan.
    readonly property real vFitScale: (rootColV.implicitHeight > 0
                                       && rootColV.height > 0
                                       && rootColV.implicitHeight > rootColV.height)
                                      ? (rootColV.height / rootColV.implicitHeight)
                                      : 1.0
    onVFitScaleChanged: ZenStringsState.verticalFitScale = vFitScale
    Component.onCompleted: ZenStringsState.verticalFitScale = vFitScale

    // ─── Module component map (mirrors Bar.qml getComponent) ───
    function getComponent(name) {
        switch(name) {
            case "start":         return cStartMenuV
            case "taskbar":       return cTaskbarV
            case "workspaces":    return cWorkspacesV
            case "window":        return cWindowTitleV
            case "music":         return cMusicV
            case "sysrow":        return cSysRowV
            case "tray":          return cTrayV
            case "notifications": return cNotifV
            case "clock":         return cClockV
            case "weather":       return cWeatherV
            case "clipboard":     return cClipboardV
            case "sysmonitor":    return cSysMonitorV
            case "battery":       return cBatteryV
            case "powerbadge":    return cPowerBadgeV
            case "calendar":      return cCalendarV
            case "workflow":      return cWorkflowV
            case "quicknotes":      return cQuickNotesV
            case "focusspaces":     return cFocusSpacesV
            case "networkpulse":    return cNetworkPulseV
            case "smartdim":        return cSmartDimV
            case "titletranslator": return cTitleTranslatorV
        }
        return null
    }

    // Each module gets its own Component so loads are independent.
    Component { id: cStartMenuV;      StartMenu {} }
    Component { id: cTaskbarV;        Taskbar { zenVertical: true } }
    Component { id: cWorkspacesV;     Workspaces { zenVertical: true } }
    Component { id: cWindowTitleV;    WindowTitle { zenVertical: true } }
    // v7.0.0-beta.1-hf95.5: vertical music host. When strings are enabled
    // we load the (invisible) MusicStrings placeholder so cava + track
    // polling run and the vertical strings overlay has data — mirroring
    // Bar.qml's horizontal cMusic. When disabled, the normal MusicWidget
    // play/pause icon shows. Either way the slot reports its Y + height up
    // to ZenStringsState so stringsWindowV (shell.qml) can center the
    // rotated string on this slot. Wala tayong babawasan — the disabled
    // path is the original MusicWidget { zenVertical: true }.
    Component {
        id: cMusicV
        Item {
            id: vMusicSlot
            // Keep the slot thin (bar thickness) horizontally. Vertically,
            // when strings are enabled, RESERVE the string's length as the
            // slot height — mirroring the horizontal bar, where the music
            // slot is as WIDE as the string. This gives the vertical
            // string its own space in the column so it no longer overlaps
            // its neighbours; the global vFitScale shrinks it with
            // everything else when the column gets too tall.
            implicitWidth: barRootV.contentThickness
            implicitHeight: ZenStringsState.enabled
                            ? ZenStringsState.verticalStringLength
                            : Math.round(Theme.moduleHeight)

            Loader {
                id: vMusicLoader
                anchors.fill: parent
                source: ZenStringsState.enabled ? "MusicStrings.qml" : "MusicWidget.qml"
                onLoaded: {
                    // MusicWidget has zenVertical; MusicStrings does not.
                    if (item && item.zenVertical !== undefined) item.zenVertical = true
                }
            }

            // ── Report slot Y + height to ZenStringsState ──
            // Parent-chain walk to barRootV (sum .y), same robust approach
            // Bar.qml uses for X. The vertical bar window is full-height at
            // the screen edge, so this Y doubles as screen-space Y.
            function updateVPos() { Qt.callLater(vMusicSlot._doUpdateVPos) }
            function _doUpdateVPos() {
                if (!vMusicSlot.parent) return
                if (barRootV.height < 100) return
                var item = vMusicSlot
                var y = 0
                var safety = 0
                while (item && item !== barRootV && safety < 24) {
                    y += item.y
                    item = item.parent
                    safety++
                }
                if (item !== barRootV) return
                if (y < 0 || y > barRootV.height) return
                var h = vMusicSlot.height
                if (h < 4) return
                if (Math.abs(ZenStringsState.musicSlotLocalY - y) > 2.0
                    || Math.abs(ZenStringsState.musicSlotLocalHeight - h) > 2.0) {
                    ZenStringsState.musicSlotLocalY = y
                    ZenStringsState.musicSlotLocalHeight = h
                }
                // hf95.6: we have a real slot position now — flip
                // positionReady so MusicStrings drops its "Loading…"
                // placeholder and the vertical string overlay shows.
                // (The horizontal stringsWindow owns this flag on
                // horizontal bars; only one bar is ever active.)
                if (!ZenStringsState.positionReady)
                    ZenStringsState.positionReady = true
            }

            onYChanged: updateVPos()
            onHeightChanged: updateVPos()
            Component.onCompleted: updateVPos()

            Connections {
                target: PanelState
                function onPanelPositionChanged() { vMusicSlot.updateVPos() }
                function onPanelModeChanged()     { vMusicSlot.updateVPos() }
                function onBarHeightChanged()     { vMusicSlot.updateVPos() }
            }
            Connections {
                target: ZenStringsState
                function onEnabledChanged()      { vMusicSlot.updateVPos() }
                function onStringLengthChanged() { vMusicSlot.updateVPos() }
            }

            // Safety poll — catches layout settles that don't emit a
            // yChanged on this exact item (e.g. a sibling above grows).
            Timer {
                interval: 700; running: true; repeat: true
                onTriggered: vMusicSlot._doUpdateVPos()
            }
        }
    }
    Component { id: cSysRowV;         SysRow { zenVertical: true } }
    Component { id: cTrayV;           SystemTray { zenVertical: true } }
    Component { id: cNotifV;          NotificationIcon {} }
    Component { id: cClockV;          Clock { zenVertical: true } }
    Component { id: cWeatherV;        ZenWeather {} }
    Component { id: cSysMonitorV;     ZenSysMonitor {} }
    Component { id: cClipboardV;      ClipboardModule {} }
    Component { id: cBatteryV;        Battery {} }
    Component { id: cPowerBadgeV;     PowerBadge {} }
    Component { id: cCalendarV;       Clock { zenVertical: true } }
    Component { id: cWorkflowV;       WorkflowProfileBadge {} }
    Component { id: cQuickNotesV;     QuickNotesModule {} }
    Component { id: cFocusSpacesV;    FocusSpacesModule {} }
    Component { id: cNetworkPulseV;   NetworkPulseModule {} }
    Component { id: cSmartDimV;       SmartDimModule {} }
    Component { id: cTitleTranslatorV; TitleTranslatorModule {} }

    // A host that centers a module horizontally in the thin bar. It
    // forwards the module's implicit size up to the layout. Width is
    // clamped to the bar thickness (so a too-wide module is centered, not
    // stretching the bar), but height is whatever the module needs.
    component VerticalModuleHost: Item {
        id: host
        property Component source: null
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: barRootV.contentThickness
        Layout.preferredHeight: hostLoader.item
            ? Math.max(1, hostLoader.item.implicitHeight, hostLoader.item.height || 0)
            : 0
        // v7.0.0-beta.1-hf95.7: never shrink below the preferred height.
        // This makes an over-full column OVERFLOW rather than squish its
        // modules into each other — barRootV.vFitScale then scales the
        // whole column down to fit cleanly.
        Layout.minimumHeight: Layout.preferredHeight
        Loader {
            id: hostLoader
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            sourceComponent: host.source
            active: host.source !== null && PanelState.isVertical
        }
    }

    ColumnLayout {
        id: rootColV
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        // v7.0.0-beta.1-hf95.7: scale the whole column to fit the bar when
        // it would overflow (origin Top → shrink downward from the top).
        scale: barRootV.vFitScale
        transformOrigin: Item.Top
        spacing: 6

        // TOP zone
        ColumnLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.left || []
                VerticalModuleHost { source: barRootV.getComponent(modelData) }
            }
        }

        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // CENTER zone
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.center || []
                VerticalModuleHost { source: barRootV.getComponent(modelData) }
            }
        }

        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // BOTTOM zone
        ColumnLayout {
            Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.right || []
                VerticalModuleHost { source: barRootV.getComponent(modelData) }
            }
        }
    }
}
