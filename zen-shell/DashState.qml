pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

/*
 * DashState.qml  —  Zen Unified Dashboard (v8)
 *
 * Holds the open/close + active-tab state for the unified glass
 * dashboard (Quick Settings + Notifications + Media, Caelestia-style).
 * Screen pinning uses the monitor NAME (string) — the same reliable
 * pattern shell.qml uses for its other popups.
 */
Singleton {
    id: root

    property string screenName: ""            // "" = hidden
    property string tab: "controls"           // controls | notifs

    function focusedScreenName() {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name
        if (Quickshell.screens.length > 0)
            return Quickshell.screens[0].name || ""
        return ""
    }
    function toggle(name) { screenName = (screenName === name) ? "" : name }
    function open(name)   { screenName = name }
    function close()      { screenName = "" }
}
