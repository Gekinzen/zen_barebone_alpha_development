import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

/*
 * ZenWorkspaces — workspace bar module with configurable limit
 *
 * v6.8: Auto-apply format from PanelState.workspaceFormat.
 * Configurable workspace count (PanelState.workspaceLimit, default 5).
 * Active workspace highlighted, click to switch, animated transitions.
 *
 * Install as Workspaces.qml in ~/.config/quickshell/zen-shell/
 */
Item {
    id: wsRoot
    implicitWidth: wsRow.implicitWidth + 8
    implicitHeight: parent ? parent.height : 40

    // Default limit: 5 workspaces visible. User can change in Bar Modules settings.
    readonly property int wsCount: PanelState.workspaceLimit || 5

    RowLayout {
        id: wsRow
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: wsRoot.wsCount
            delegate: Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: {
                    if (!Hyprland.focusedMonitor) return wsId === 1
                    const ws = Hyprland.focusedMonitor.activeWorkspace
                    return ws ? ws.id === wsId : wsId === 1
                }
                readonly property bool hasWindows: {
                    const ws = Hyprland.workspaces.values.find(w => w.id === wsId)
                    return ws ? ws.windows > 0 : false
                }

                Layout.preferredWidth: isActive ? PanelState.workspaceDotActive : PanelState.workspaceDotInactive
                Layout.preferredHeight: isActive ? PanelState.workspaceDotActive : PanelState.workspaceDotInactive
                radius: Theme.styleMode === "round" ? width / 2 : 5

                color: isActive
                       ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.35)
                       : (hasWindows
                          ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.08)
                          : "transparent")

                border.width: isActive ? 1.5 : (hasWindows ? 1 : 0)
                border.color: isActive
                              ? Qt.rgba(ThemeService.blue.r, ThemeService.blue.g, ThemeService.blue.b, 0.5)
                              : Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.1)

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 120 } }
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    // v7.0.0-alpha.2 (Densho Foundation): when Densho mode +
                    // kanjiWorkspaces sub-toggle are both on, override the
                    // PanelState.workspaceFormat icon with a kanji 一二三...
                    // label. Falls back to the existing behavior otherwise.
                    text: DenshoService.useKanjiWorkspaces
                          ? DenshoService.workspaceKanji(wsId)
                          : ZenConstants.workspaceIcon(PanelState.workspaceFormat, wsId)
                    font.family: DenshoService.useKanjiWorkspaces
                          ? "Noto Serif CJK JP, " + ZenConstants.fontPrimary(PanelState.fontFamilyId)
                          : ZenConstants.fontPrimary(PanelState.fontFamilyId)
                    font.pixelSize: isActive ? PanelState.workspaceFontActive : PanelState.workspaceFontInactive
                    color: isActive ? ThemeService.blue : ThemeService.grey0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }
    }
}
