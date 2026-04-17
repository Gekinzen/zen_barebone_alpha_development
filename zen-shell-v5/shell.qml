//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
//@ pragma ShellId zen-shell

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var startMenuScreen: null

    function toggleStartMenuOn(screen) {
        if (startMenuScreen === screen) startMenuScreen = null
        else startMenuScreen = screen
    }
    function closeStartMenu() { startMenuScreen = null }

    property bool wallpaperPickerVisible: false
    property bool settingsVisible: false
    property bool settingsFullscreen: false
    property bool keybindCheatsheetVisible: false

    property bool powerConfirmVisible: false
    property string powerAction: ""
    property string powerCommand: ""

    function triggerPowerAction(action, cmd) {
        powerAction = action
        powerCommand = cmd
        powerConfirmVisible = true
    }

    IpcHandler {
        target: "zen"

        function toggleStartMenu() {
            if (Hyprland.focusedMonitor) {
                const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name)
                if (screen) root.toggleStartMenuOn(screen)
            } else if (Quickshell.screens.length > 0) {
                root.toggleStartMenuOn(Quickshell.screens[0])
            }
        }
        function closeStartMenu() { root.closeStartMenu() }

        function toggleWallpaperPicker() {
            root.wallpaperPickerVisible = !root.wallpaperPickerVisible
        }
        function randomWallpaper() { WallpaperServiceV5.randomWallpaper() }
        function refreshWallpapers() { WallpaperServiceV5.refresh() }

        function toggleSettings() { root.settingsVisible = !root.settingsVisible }
        function closeSettings() { root.settingsVisible = false }

        function reloadThemeFromFile() { ThemeService.reload() }
        function refreshThemeList() { ThemeService.refreshThemeList() }

        function toggleControlCenter() { console.log("[zen] Control center (Phase 4)") }
        function toggleKeybindCheatsheet() { root.keybindCheatsheetVisible = !root.keybindCheatsheetVisible }
        function reloadTheme(schemeName: string) { Theme.loadScheme(schemeName) }
        function cycleTheme() { Theme.cycleTheme() }
        function toggleStyle() { Theme.toggleStyle() }

        function powerShutdown() { root.triggerPowerAction("shutdown", "systemctl poweroff") }
        function powerReboot()   { root.triggerPowerAction("reboot", "systemctl reboot") }
        function powerLogout()   { root.triggerPowerAction("logout", "hyprctl dispatch exit") }
        function powerLock()     { root.triggerPowerAction("lock", "hyprlock") }
    }

    // ═══════════════════════════════════════════════════════════════
    // BOTTOM BAR — PanelState mode-aware margins
    //
    // v6.3 fix: "island" mode is now truly responsive — width hugs the
    // Bar's natural content width (via bar.implicitWidth) instead of
    // forcing full-screen minus margins. So kung konti lang laman, konti
    // lang yung island; kung marami, lumalaki siya.
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            // v6.11b: Bar display target — show on all, primary only, or specific monitor
            // "primary" now means screens[0] (first/main monitor), NOT focusedMonitor
            // This prevents the bar from disappearing when cursor moves to another screen
            visible: {
                const target = PanelState.barTargetDisplay
                if (target === "all") return true
                if (target === "primary") {
                    return Quickshell.screens[0] === modelData
                }
                // Specific monitor name
                return modelData.name === target
            }

            anchors.bottom: true

            // Horizontal anchoring:
            //   fullwidth → anchored left+right (stretch)
            //   floating  → anchored left+right (stretch, but with margins)
            //   island    → NOT anchored horizontally (centered, hug-width)
            anchors.left: PanelState.panelMode !== "island"
            anchors.right: PanelState.panelMode !== "island"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "zen-shell-bar"

            // Height includes bottom margin for floating/island modes
            implicitHeight: PanelState.barHeight + PanelState.panelMarginBottom

            // Width strategy per mode:
            //   fullwidth → 0 (auto-stretch via anchors.left+right)
            //   floating  → 0 (ALSO auto-stretch; anchors.left+right with
            //               margins.left/right do the work. Previously we
            //               tried `screen.width - 2*margin` but that fought
            //               with the anchors and caused right-side clipping.)
            //   island    → hug Bar.contentImplicitWidth + inner pad;
            //               clamped to [400, screen - 2*margin].
            implicitWidth: {
                if (PanelState.panelMode === "fullwidth") return 0
                if (PanelState.panelMode === "floating") return 0
                // island: hug content.
                const minW = 400
                const maxW = modelData.width - (PanelState.panelMarginSide * 2)
                const innerPad = 16
                const desired = bar.contentImplicitWidth + innerPad
                return Math.max(minW, Math.min(maxW, desired))
            }

            color: "transparent"

            margins.bottom: PanelState.panelMarginBottom
            margins.left: PanelState.panelMode === "fullwidth" ? 0
                          : (PanelState.panelMode === "floating" ? PanelState.panelMarginSide : 0)
            margins.right: PanelState.panelMode === "fullwidth" ? 0
                           : (PanelState.panelMode === "floating" ? PanelState.panelMarginSide : 0)

            // Bar fills its parent window in ALL modes. The window itself
            // is sized per-mode above (0 for fullwidth, computed for
            // floating/island). Using anchors.fill is the simple, correct
            // way to let the bar's internal RowLayout stretch to the full
            // width of whatever window it lives in.
            Bar {
                id: bar
                anchors.fill: parent
                anchors.margins: PanelState.panelMode === "fullwidth" ? 3 : 0
            }
        }
    }


    // ═══════════════════════════════════════════════════════════════
    // START MENU
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: startMenuWindow
            required property var modelData
            screen: modelData

            visible: root.startMenuScreen === modelData

            anchors.bottom: true
            anchors.left: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-startmenu"
            exclusionMode: ExclusionMode.Ignore

            implicitWidth: 720
            implicitHeight: 600
            color: "transparent"

            // v6.9: Align start menu LEFT EDGE with start button LEFT EDGE
            // (not centered — user expects menu to open directly from the button)
            margins.left: {
                const btnX = PanelState.startButtonCenterX
                if (btnX < 0) return 8  // no report yet
                const w = startMenuWindow.implicitWidth
                const screenW = modelData.width
                // btnX is button CENTER — subtract half button width to get LEFT edge
                const btnHalfW = (Theme.moduleHeight + 4) / 2  // StartMenu button width/2
                const desired = btnX - btnHalfW
                const maxLeft = screenW - w - 8
                return Math.max(8, Math.min(maxLeft, desired))
            }
            margins.bottom: PanelState.barHeight + 8 + PanelState.panelMarginBottom

            HyprlandFocusGrab {
                active: startMenuWindow.visible
                windows: [startMenuWindow]
                onCleared: {
                    if (root.startMenuScreen === modelData) root.startMenuScreen = null
                }
            }

            StartMenuPanel {
                anchors.fill: parent
                visible: startMenuWindow.visible
                onCloseRequested: root.closeStartMenu()
                onAppLaunched: root.closeStartMenu()
                onPowerActionRequested: (action, command) => root.triggerPowerAction(action, command)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // WALLPAPER PICKER (legacy)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wpWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.wallpaperPickerVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: wpWindow.visible
                windows: [wpWindow]
                onCleared: root.wallpaperPickerVisible = false
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.wallpaperPickerVisible = false
                }
            }

            WallpaperPicker {
                anchors.centerIn: parent
                width: Math.min(1100, parent.width - 80)
                height: Math.min(720, parent.height - 80)
                visible: wpWindow.visible
                onCloseRequested: root.wallpaperPickerVisible = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SETTINGS WINDOW (no dim background, transparent click-to-close)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: settingsWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.settingsVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-settings"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: settingsWindow.visible
                windows: [settingsWindow]
                onCleared: root.settingsVisible = false
            }

            // Transparent click-outside (no dim) — disabled when fullscreen
            MouseArea {
                anchors.fill: parent
                enabled: !root.settingsFullscreen
                onClicked: root.settingsVisible = false
            }

            ZenSettings {
                anchors.centerIn: root.settingsFullscreen ? undefined : parent
                anchors.fill: root.settingsFullscreen ? parent : undefined
                width: root.settingsFullscreen ? parent.width : Math.min(1100, parent.width - 80)
                height: root.settingsFullscreen ? parent.height : Math.min(740, parent.height - 80)
                visible: settingsWindow.visible
                isFullscreen: root.settingsFullscreen
                onCloseRequested: root.settingsVisible = false
                onToggleFullscreen: root.settingsFullscreen = !root.settingsFullscreen
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // POWER CONFIRM
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: powerWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.powerConfirmVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-powerconfirm"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: powerWindow.visible
                windows: [powerWindow]
                onCleared: root.powerConfirmVisible = false
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.7)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.powerConfirmVisible = false
                }
            }

            PowerConfirmDialog {
                anchors.centerIn: parent
                width: 420
                height: 480
                visible: powerWindow.visible
                action: root.powerAction
                command: root.powerCommand
                countdown: 60

                onConfirmed: root.powerConfirmVisible = false
                onCancelled: root.powerConfirmVisible = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // KEYBIND CHEATSHEET — Super+/ or Super+F2
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: keybindWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.keybindCheatsheetVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-keybinds"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: keybindWindow.visible
                windows: [keybindWindow]
                onCleared: root.keybindCheatsheetVisible = false
            }

            KeybindCheatsheet {
                anchors.fill: parent
                visible: keybindWindow.visible
                onCloseRequested: root.keybindCheatsheetVisible = false
                Component.onCompleted: if (visible) show()
                onVisibleChanged: if (visible) show()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // DESKTOP WIDGETS — transparent overlay on BACKGROUND layer
    // Shows clock, weather, system monitor behind all windows.
    // Reads enable/disable from widgets-state.json (WidgetsPage).
    // v6.11b: "primary" = screens[0] (fixed monitor, not cursor-follow)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: widgetWindow
            required property var modelData
            screen: modelData

            // v6.11b: "primary" means first screen always — NOT focusedMonitor
            // This prevents widgets from disappearing when cursor moves
            visible: dwInstance.widgetDisplay === "all" ? true : (Quickshell.screens[0] === modelData)

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "zen-shell-widgets"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            DesktopWidgets {
                id: dwInstance
                anchors.fill: parent
            }
        }
    }
}
