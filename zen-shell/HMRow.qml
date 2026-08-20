import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * HMRow — HyprMod-style settings row
 *
 * Differs from the original SettingRow.qml:
 * - Larger minHeight (56 vs 48) so controls breathe (para pantay pag fullscreen)
 * - Right-aligned control slot with fixed Layout.alignment
 * - Explicit anchors.leftMargin 16 / rightMargin 16 (was 12)
 * - Subtle bottom separator line (optional, toggle via `separator`)
 * - Optional leading icon (Nerd Font glyph)
 *
 * v6.16.4.12.6.51 (Hikari) hotfix:
 *   Height now ADAPTS to wrapped description text. Previously
 *   `implicitHeight: 56` was hardcoded, but `description` Text uses
 *   `wrapMode: Text.WordWrap + Layout.fillWidth: true` — long
 *   descriptions wrap to multiple lines that render BEYOND the
 *   56px row bounds (no clip), visually overlapping with the next
 *   row in the section. The Battery & Power → Panic Recovery
 *   section's "What it does" (8 long bullets) was the trigger:
 *   its 4-line wrapped description bled down into "Manual invocation".
 *
 *   Fix: implicitHeight = max(56, contentRow.implicitHeight + 16).
 *   Min height 56 preserved for short rows; long rows expand to fit
 *   their wrapped description plus 8px top + 8px bottom padding.
 *
 * Drop-in compatible: kept the same `label` + `description` + default
 * content slot API.
 */
Rectangle {
    id: root

    property string label: ""
    property string description: ""
    property string icon: ""               // optional Nerd Font glyph
    // v7.0.0-beta.1-hf99zh: allow a different icon font (e.g. Google's
    // "Material Symbols Rounded", which uses ligature names like "palette").
    property string iconFont: "JetBrainsMono Nerd Font"
    property bool separator: false         // draw thin divider at bottom
    default property alias control: controlSlot.data

    Layout.fillWidth: true
    // v6.16.4.12.6.51 (Hikari): Adapt height to content. min 56 for
    // short rows; long wrapped descriptions push the row taller.
    implicitHeight: Math.max(56, contentRow.implicitHeight + 16)
    color: rowMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.04) : "transparent"
    radius: 8

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 14

        // Optional leading icon
        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: 15
            color: LookService.textDimColor(ThemeService.grey0)
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            Layout.preferredWidth: 20
            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
            // Align icon to top so it sits with the label, not the
            // visual center of a tall wrapped description.
            topPadding: 1
        }

        // Text column: label + description
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: LookService.textColor(ThemeService.fg)
                style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: root.description
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: LookService.textFaintColor(ThemeService.grey1)
                style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
                visible: root.description.length > 0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // Right-aligned control slot
        //
        // hf199 — this was a plain Item, and an Item STACKS its children
        // at (0,0). Every page that dropped ONE control in the slot never
        // noticed; DesktopPage drops THREE (icon preview + Choose + Reset)
        // and they rendered superimposed — one unreadable pill on the
        // right ("hindi mabasa yun mga nasa right side"). A RowLayout lays
        // them out left→right AND honors the Layout.preferredWidth /
        // fillWidth attached props existing pages already put on their
        // single slot child — so one-child rows are visually unchanged.
        RowLayout {
            id: controlSlot
            spacing: 8
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            Layout.topMargin: 0
        }
    }

    // Optional bottom separator
    Rectangle {
        visible: root.separator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: 1
        color: ThemeService.alpha(ThemeService.fg, 0.06)
    }
}
