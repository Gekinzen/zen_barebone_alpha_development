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

    // v7.0.0-beta.1-hf91.1: explicit vertical mode (end-4 style). When the
    // bar is zenVertical, BarVertical sets `vertical: true` and the dots stack
    // in a column. Default false → original horizontal row.
    property bool zenVertical: false

    implicitWidth: zenVertical ? Math.round(Theme.moduleHeight) : (wsRow.implicitWidth + 8)
    implicitHeight: zenVertical ? (wsRow.implicitHeight + 8) : Math.round(Theme.moduleHeight)

    // v7.0.0-beta.1-hf84: dots + labels scale with the bar when
    // Fit-contents is on (1.0 otherwise → user's configured dot sizes
    // are used unchanged).
    readonly property real _fit: (typeof Theme !== "undefined" && Theme.barContentScale)
                                 ? Theme.barContentScale : 1.0

    // Default limit: 5 workspaces visible. User can change in Bar Modules settings.
    readonly property int wsCount: PanelState.workspaceLimit || 5

    // v7.0.0-beta.1-hf91.1: GridLayout flips by column count — 1 column
    // when zenVertical (dots stack), wsCount columns when horizontal (one
    // row, identical to the original RowLayout).
    GridLayout {
        id: wsRow
        anchors.centerIn: parent
        columns: wsRoot.zenVertical ? 1 : wsRoot.wsCount
        rowSpacing: 3
        columnSpacing: 3

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

                Layout.preferredWidth: Math.round((isActive ? PanelState.workspaceDotActive : PanelState.workspaceDotInactive) * wsRoot._fit)
                Layout.preferredHeight: Math.round((isActive ? PanelState.workspaceDotActive : PanelState.workspaceDotInactive) * wsRoot._fit)
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
                    text: ZenConstants.workspaceIcon(PanelState.workspaceFormat, wsId)
                    font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
                    font.pixelSize: Math.round((isActive ? PanelState.workspaceFontActive : PanelState.workspaceFontInactive) * wsRoot._fit)
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
