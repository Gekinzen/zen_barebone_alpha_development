import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * SettingsSearchOverlay v7.0.0-alpha.6-hf2 — Spotlight-style search modal
 *
 * Full-screen-dimmed overlay with a centered search panel. Bound to
 * Ctrl+F (and optionally Super+Space if user wires it). Mounted as
 * a global PanelWindow at WlrLayer.Overlay so it sits above all
 * shell surfaces and can be summoned from anywhere.
 *
 * Behavior:
 *   - Search field auto-focused on show
 *   - Live-filtered results below (up to 10 visible)
 *   - ↑/↓ to navigate, Enter to commit, Esc to close
 *   - Click result row → close overlay + open Settings/ControlPanel
 *     to that page
 *   - Click outside the inner panel → close overlay
 *
 * Public API (mirrors StartMenuPanel pattern):
 *   - signal closeRequested()
 *   - signal navigateRequested(var entry)
 *
 * Wala tayong babawasan — separate component, independent of the
 * inline SettingsSearchBar in the Settings header. Both consume the
 * same SettingsSearchService data — same results, two surfaces.
 */
Item {
    id: overlay

    signal closeRequested()
    signal navigateRequested(var entry)

    property string query: ""
    property int    highlightIndex: 0

    readonly property var results: SettingsSearchService.search(query).slice(0, 10)

    // Re-focus + reset on every show
    onVisibleChanged: {
        if (visible) {
            query = ""
            highlightIndex = 0
            input.text = ""
            Qt.callLater(function(){ input.forceActiveFocus() })
        }
    }

    // ── Dim background is now on the PanelWindow itself (v7.0.0-alpha.10-hf4)
    // The PanelWindow's `color: Qt.rgba(0,0,0,0.55)` provides the dim,
    // and a MouseArea on the PanelWindow handles click-outside-to-close.
    // No child Rectangle needed here — keeps the surface simple and
    // avoids double-dim composition.

    // ── Centered panel ──
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.18   // ~18% from top — Spotlight-y
        width: 600
        height: Math.min(parent.height * 0.7, contentCol.implicitHeight + 24)
        radius: 14
        color: LookService.popupColor(0.98)
        border.color: LookService.popupInkAlpha(0.18)
        border.width: 1
        clip: true

        // Click on the panel doesn't propagate to the dim layer
        MouseArea {
            anchors.fill: parent
            onClicked: {}   // swallow
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Search input row ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 10
                color: "transparent"
                border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                border.width: input.activeFocus ? 1.5 : 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Text {
                        style: Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: MaterialIcons.icon("search")
                        font.family: MaterialIcons.fontFamily
                        font.pixelSize: 22
                        color: LookService.isClear ? LookService.popupInk : ThemeService.blue
                    }

                    TextField {
                        id: input
                        Layout.fillWidth: true
                        placeholderText: "Search settings, panels, themes…"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        color: LookService.popupInk
                        placeholderTextColor: LookService.popupInkDim
                        background: Item {}
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true

                        onTextChanged: {
                            overlay.query = text
                            overlay.highlightIndex = 0
                        }

                        Keys.onEscapePressed: {
                            if (text.length > 0) text = ""
                            else overlay.closeRequested()
                        }
                        Keys.onReturnPressed: {
                            if (overlay.results.length > 0) {
                                overlay.navigateRequested(
                                    overlay.results[Math.max(0, overlay.highlightIndex)])
                                overlay.closeRequested()
                            }
                        }
                        Keys.onDownPressed: {
                            overlay.highlightIndex = Math.min(
                                overlay.results.length - 1, overlay.highlightIndex + 1)
                        }
                        Keys.onUpPressed: {
                            overlay.highlightIndex = Math.max(0, overlay.highlightIndex - 1)
                        }
                    }

                    // Esc hint
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: escText.implicitWidth + 12
                        radius: 4
                        color: LookService.popupInkAlpha(0.08)

                        Text {
                            style: Text.Normal
                            styleColor: LookService.clearTextOutline
                            id: escText
                            anchors.centerIn: parent
                            text: "Esc"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: LookService.popupInkDim
                        }
                    }
                }
            }

            // ── Results list ──
            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(overlay.results.length, 8) * 56
                visible: overlay.results.length > 0
                clip: true
                spacing: 2
                cacheBuffer: 200
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: overlay.results.length > 8

                model: overlay.results

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 54
                    radius: 8
                    color: (overlay.highlightIndex === index || resultMa.containsMouse)
                           ? ThemeService.alpha(ThemeService.blue, 0.14)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        Text {
                            style: Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: MaterialIcons.icon(modelData.icon || "tune")
                            font.family: MaterialIcons.fontFamily
                            font.pixelSize: 22
                            color: (overlay.highlightIndex === index || resultMa.containsMouse)
                                   ? (LookService.isClear ? LookService.popupInk : ThemeService.blue)
                                   : LookService.popupInkDim
                            Layout.preferredWidth: 28
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                style: Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.title || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: LookService.popupInk
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                style: Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.subtitle || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: LookService.popupInkDim
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: surfText.implicitWidth + 14
                            radius: 11
                            color: LookService.popupInkAlpha(0.08)

                            Text {
                                style: Text.Normal
                                styleColor: LookService.clearTextOutline
                                id: surfText
                                anchors.centerIn: parent
                                text: SettingsSearchService.surfaceLabel(modelData.surface)
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: LookService.popupInkDim
                            }
                        }
                    }

                    MouseArea {
                        id: resultMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: overlay.highlightIndex = index
                        onClicked: {
                            overlay.navigateRequested(modelData)
                            overlay.closeRequested()
                        }
                    }
                }
            }

            // ── Empty state ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: overlay.query.length >= 2 ? 80 : 0
                visible: overlay.query.length >= 2 && overlay.results.length === 0

                Text {
                    style: Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "No matches for \"" + overlay.query + "\""
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: LookService.popupInkDim
                }
            }

            // ── Hint footer ──
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 14
                visible: overlay.query.length === 0

                Text {
                    style: Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "Try: brave · 2+2 · resume.pdf · densho · battery"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.italic: true
                    color: LookService.popupInkDim
                    Layout.fillWidth: true
                }

                Text {
                    style: Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "↑↓ navigate · ↵ open"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: LookService.popupInkDim
                }
            }
        }
    }
}
