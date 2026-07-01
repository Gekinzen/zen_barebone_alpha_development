import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * SettingsSearchBar v7.0.0-alpha.6
 *
 * Reusable search bar with Material Symbols Outlined search icon and
 * a floating dropdown of matched results. Drop into any settings or
 * control-panel surface as a leading child of the toolbar/header.
 *
 * Public API:
 *   - property string surfaceFilter   "settings" | "controlpanel" | ""
 *                                     (filter results to a single surface;
 *                                      empty = include all)
 *   - signal navigateRequested(var entry)
 *                                     fired when user picks a result;
 *                                     consumer flips to entry.page
 *
 * The result list shows up to 8 entries below the bar in a floating
 * Rectangle with shadow-sim border. Press Enter to navigate to the
 * top result; arrow keys to walk the list; Esc to close.
 *
 * Material Symbols Outlined codepoints come from MaterialIcons
 * singleton — Paul's request was specifically Google Material Icons
 * for this UI.
 *
 * Wala tayong babawasan — purely additive component. Existing nav
 * patterns (sidebar click) continue to work unchanged.
 */
Item {
    id: bar

    // ── Public API ──
    property string surfaceFilter: ""
    signal navigateRequested(var entry)

    implicitHeight: 36
    implicitWidth: 320

    // ── Internal state ──
    property string query: ""
    property bool dropdownOpen: false
    property int  highlightIndex: 0

    readonly property var results: {
        const all = SettingsSearchService.search(bar.query)
        if (!bar.surfaceFilter) return all.slice(0, 12)
        return all.filter(function(e){
            return e.surface === bar.surfaceFilter
        }).slice(0, 12)
    }

    // ─────────────────────────────────────────────────────────
    // BAR
    //
    // hf1: Layout fixes for the cramped header version. The icon
    // had no fixed width, so on systems where Material Symbols
    // wasn't installed (font.family fallback to Nerd Font) and
    // the glyph resolved to a non-fixed-width character, the
    // icon and placeholder text overlapped visually.
    //
    // Fixes:
    //   - Icon Item with explicit 18px width + centered Text
    //   - TextField padding 0 (no implicit Qt control padding)
    //   - Slightly larger font (12 → 13) + tighter row margins
    //   - placeholderText shorter ("Search…" not "Search settings…")
    //     so it fits cleanly in 240px even with 2 inline icons
    // ─────────────────────────────────────────────────────────
    Rectangle {
        id: barRect
        anchors.fill: parent
        radius: 10
        color: ThemeService.alpha(ThemeService.bg2, 0.6)
        border.color: input.activeFocus
                      ? ThemeService.alpha(ThemeService.blue, 0.5)
                      : ThemeService.alpha(ThemeService.fg, 0.10)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // Search icon — wrapped in fixed-width Item so the icon
            // glyph (which can vary in width across fonts) doesn't
            // shift the TextField left/right.
            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: MaterialIcons.icon("search")
                    font.family: MaterialIcons.fontFamily
                    font.pixelSize: 16
                    color: input.activeFocus ? ThemeService.blue : ThemeService.grey0
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            TextField {
                id: input
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                placeholderText: "Search…"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.fg
                placeholderTextColor: ThemeService.grey1
                background: Item {}
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                // Strip default Qt control padding so the text sits
                // flush against the icon
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0

                onTextChanged: {
                    bar.query = text
                    bar.highlightIndex = 0
                    bar.dropdownOpen = text.length > 0
                }
                onActiveFocusChanged: {
                    if (activeFocus && text.length > 0) bar.dropdownOpen = true
                }

                Keys.onEscapePressed: {
                    if (text.length > 0) { text = ""; bar.dropdownOpen = false }
                    else focus = false
                }
                Keys.onReturnPressed: {
                    if (bar.results.length > 0) {
                        bar.navigateRequested(bar.results[Math.max(0, bar.highlightIndex)])
                        bar.dropdownOpen = false
                        text = ""
                    }
                }
                Keys.onDownPressed: {
                    bar.highlightIndex = Math.min(bar.results.length - 1,
                                                   bar.highlightIndex + 1)
                }
                Keys.onUpPressed: {
                    bar.highlightIndex = Math.max(0, bar.highlightIndex - 1)
                }
            }

            // Clear button — wrapped in fixed-width Item, only takes
            // up space when input has text
            Item {
                Layout.preferredWidth: input.text.length > 0 ? 18 : 0
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                visible: input.text.length > 0
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: MaterialIcons.icon("close")
                    font.family: MaterialIcons.fontFamily
                    font.pixelSize: 14
                    color: clearMa.containsMouse ? ThemeService.fg : ThemeService.grey0
                }

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        input.text = ""
                        bar.dropdownOpen = false
                        input.forceActiveFocus()
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // DROPDOWN — floating results list, anchored below the bar
    // ─────────────────────────────────────────────────────────
    Rectangle {
        id: dropdown
        visible: bar.dropdownOpen && bar.results.length > 0
        anchors.top: barRect.bottom
        anchors.topMargin: 4
        anchors.left: barRect.left
        anchors.right: barRect.right
        height: Math.min(bar.results.length, 8) * 44 + 8
        radius: 10
        color: Qt.rgba(ThemeService.bg1.r, ThemeService.bg1.g, ThemeService.bg1.b, 0.98)
        border.color: ThemeService.alpha(ThemeService.fg, 0.14)
        border.width: 1
        z: 1000

        opacity: bar.dropdownOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        ListView {
            id: resultsList
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 0
            cacheBuffer: 200
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: bar.results.length > 8

            model: bar.results

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 44
                radius: 6
                color: (bar.highlightIndex === index || resultMa.containsMouse)
                       ? ThemeService.alpha(ThemeService.blue, 0.10)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Material icon on the left
                    Text {
                        text: MaterialIcons.icon(modelData.icon || "tune")
                        font.family: MaterialIcons.fontFamily
                        font.pixelSize: 18
                        color: ThemeService.grey1
                        Layout.preferredWidth: 22
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: modelData.title || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: ThemeService.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.subtitle || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Surface badge (Settings / Control Center)
                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: surfaceText.implicitWidth + 12
                        radius: 9
                        color: ThemeService.alpha(ThemeService.fg, 0.06)

                        Text {
                            id: surfaceText
                            anchors.centerIn: parent
                            text: SettingsSearchService.surfaceLabel(modelData.surface)
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: ThemeService.grey0
                        }
                    }
                }

                MouseArea {
                    id: resultMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: bar.highlightIndex = index
                    onClicked: {
                        bar.navigateRequested(modelData)
                        bar.dropdownOpen = false
                        input.text = ""
                    }
                }
            }
        }
    }

    // Click-outside-to-close dropdown
    MouseArea {
        // Sits BEHIND the dropdown but ABOVE everything else;
        // catches clicks outside the dropdown's footprint.
        visible: bar.dropdownOpen
        z: 999
        anchors.fill: parent
        anchors.topMargin: barRect.height + 4
        propagateComposedEvents: true
        onPressed: function(m) {
            // If click landed inside dropdown bounds, let it through
            const inside = m.x >= 0 && m.x <= dropdown.width
                        && m.y >= 0 && m.y <= dropdown.height
            if (!inside) bar.dropdownOpen = false
            m.accepted = false
        }
    }
}
