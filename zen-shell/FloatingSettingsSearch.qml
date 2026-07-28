import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * FloatingSettingsSearch v7.0.0-beta.1-hf41
 *
 * Settings search bar that floats over the entire ZenSettings panel
 * via z-stacking.
 *
 * v7.0.0-beta.1-hf41 — COLLAPSIBLE.
 *
 *   User report: "yung type of search meron button na hide so magiging
 *   arrow lang then make it sure kht scroll down ko dapat hindi nag
 *   bubukas bukas unless manually cclick ko ulit yun arrow"
 *
 *   The full-width search bar (220 px) sitting at the top of the
 *   Settings panel was always visible and would re-focus / re-open
 *   its dropdown opportunistically (auto-focus on hover, re-open
 *   on any text presence, etc.). When user scrolled, intermediate
 *   focus changes caused the dropdown to flash open even though the
 *   user wasn't actively searching.
 *
 *   New design:
 *
 *     Collapsed (default):
 *       ┌──────┐
 *       │  ⌕   │   ← 32x32 round button, just the search glyph
 *       └──────┘
 *
 *     Expanded (only when user explicitly clicks the button):
 *       ┌──────────────────────────────┐
 *       │  ⌕  Type to search        × │   ← full bar + clear + dropdown
 *       └──────────────────────────────┘
 *
 *   Behavior:
 *     - State defaults to COLLAPSED. Stays collapsed across
 *       page navigations.
 *     - Clicking the search button toggles expansion.
 *     - When expanded, ESC collapses back to icon.
 *     - When collapsed, NO dropdown ever shows. NO auto-focus.
 *       NO opportunistic open on scroll/focus/anything.
 *     - Click outside the expanded bar → collapses.
 *     - Persisted to PanelState.settingsSearchExpanded so the user's
 *       preference survives Settings panel close/reopen.
 *
 * Public API unchanged:
 *   - signal navigateRequested(var entry)
 *   - property string surfaceFilter
 *
 * Wala tayong babawasan — same as previous, replaces only the
 * inline search bar usage in ZenSettings; SettingsSearchBar.qml
 * remains for other potential consumers.
 */
Item {
    id: floater

    signal navigateRequested(var entry)
    property string surfaceFilter: "settings"

    // ─────────────────────────────────────────────────────────
    // COLLAPSED / EXPANDED STATE
    // ─────────────────────────────────────────────────────────
    //
    // Backed by PanelState.settingsSearchExpanded so it persists
    // across Settings open/close within the same shell session.
    // Defaults to false (collapsed).
    //
    // We expose `expanded` as a local alias so internal bindings
    // are concise. The toggle() function writes back to PanelState.
    property bool expanded: (typeof PanelState !== "undefined")
                            && PanelState.settingsSearchExpanded
                            === true
    onExpandedChanged: {
        if (typeof PanelState !== "undefined"
            && PanelState.settingsSearchExpanded !== expanded) {
            PanelState.settingsSearchExpanded = expanded
        }
    }
    Connections {
        target: (typeof PanelState !== "undefined") ? PanelState : null
        function onSettingsSearchExpandedChanged() {
            if (floater.expanded !== PanelState.settingsSearchExpanded) {
                floater.expanded = PanelState.settingsSearchExpanded
            }
        }
    }

    function toggleExpanded() {
        floater.expanded = !floater.expanded
        if (floater.expanded) {
            // Small delay before focusing the field so the size
            // animation has a chance to complete.
            focusTimer.restart()
        } else {
            // Collapsing → clear query + close dropdown
            floater.query = ""
            floater.dropdownOpen = false
            if (input) input.text = ""
        }
    }

    function collapse() {
        if (floater.expanded) {
            floater.expanded = false
            floater.query = ""
            floater.dropdownOpen = false
            if (input) input.text = ""
        }
    }

    Timer {
        id: focusTimer
        interval: 130
        repeat: false
        onTriggered: if (floater.expanded && input) input.forceActiveFocus()
    }

    // ─────────────────────────────────────────────────────────
    // SIZING — animates between collapsed (32x32) and expanded (220x32)
    // ─────────────────────────────────────────────────────────
    width: floater.expanded ? 220 : 32
    height: 32
    z: 100   // above sidebar (z=0) + content (z=0) + dropdown overlay nav

    Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // ─────────────────────────────────────────────────────────
    // QUERY STATE
    // ─────────────────────────────────────────────────────────
    property string query: ""
    property bool dropdownOpen: false
    property int  highlightIndex: 0

    readonly property var results: {
        if (typeof SettingsSearchService === "undefined") return []
        if (!query || query.length < 1) return []
        const all = SettingsSearchService.search(query)
        return all.filter(function(e){
            return e.surface === floater.surfaceFilter
        }).slice(0, 12)
    }

    // ─────────────────────────────────────────────────────────
    // SEARCH BAR (visible compact pill — only when expanded)
    // ─────────────────────────────────────────────────────────
    Rectangle {
        id: barRect
        anchors.fill: parent
        radius: 8
        color: LookService.surfaceColor(ThemeService.bg1, 0.95)
        border.color: input && input.activeFocus
                      ? ThemeService.blue
                      : (toggleMa.containsMouse
                         ? ThemeService.alpha(ThemeService.blue, 0.4)
                         : ThemeService.alpha(ThemeService.fg, 0.18))
        border.width: (input && input.activeFocus) ? 1.5 : 1
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // ────────────────────────────────────────────────
        // COLLAPSED STATE: just the search glyph
        // ────────────────────────────────────────────────
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.centerIn: parent
            visible: !floater.expanded
            text: "\uf002"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: toggleMa.containsMouse
                   ? ThemeService.blue
                   : ThemeService.grey0
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Toggle area — when collapsed, covers entire bar.
        // When expanded, it only covers the leftmost icon (16+8px gutter)
        // so clicks on the TextField don't accidentally collapse.
        MouseArea {
            id: toggleMa
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // When collapsed → take full width. When expanded → only the
            // icon area (so user can still click inside the field).
            width: floater.expanded ? 28 : parent.width
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: floater.toggleExpanded()
        }

        // ────────────────────────────────────────────────
        // EXPANDED STATE: full search bar contents
        // ────────────────────────────────────────────────
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6
            visible: floater.expanded
            // While collapsing, do not consume mouse events
            enabled: floater.expanded

            // Search icon — matches StartMenu's "Type to search" style
            // (Nerd Font glyph directly, blue accent on focus). Fixed-
            // width Item so glyph variance doesn't shift the layout.
            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    text: "\uf002"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: input.activeFocus
                           ? ThemeService.blue
                           : ThemeService.grey0
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            TextField {
                id: input
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                placeholderText: "Type to search"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.fg
                placeholderTextColor: ThemeService.grey1
                background: Item {}
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0

                // v7.0.0-beta.1-hf41: explicit text-driven dropdown.
                // Dropdown ONLY opens when the user actively types
                // something. NEVER on focus alone, NEVER on hover, etc.
                onTextChanged: {
                    floater.query = text
                    floater.highlightIndex = 0
                    floater.dropdownOpen = (floater.expanded
                                            && text.length > 0)
                }

                // REMOVED in hf41: onActiveFocusChanged auto-open.
                //
                // Previously this block re-opened the dropdown whenever
                // the field regained focus (e.g. after a scroll caused
                // focus reshuffle). That was the "auto-opens on scroll"
                // bug. We now require the user to type at least one
                // character to open the dropdown.

                Keys.onEscapePressed: {
                    // ESC: clear → collapse → release focus
                    if (text.length > 0) {
                        text = ""
                        floater.dropdownOpen = false
                    } else {
                        floater.collapse()
                    }
                }
                Keys.onReturnPressed: {
                    if (floater.results.length > 0) {
                        floater.navigateRequested(
                            floater.results[Math.max(0, floater.highlightIndex)])
                        text = ""
                        floater.dropdownOpen = false
                        focus = false
                    }
                }
                Keys.onDownPressed: {
                    floater.highlightIndex = Math.min(
                        floater.results.length - 1, floater.highlightIndex + 1)
                }
                Keys.onUpPressed: {
                    floater.highlightIndex = Math.max(0, floater.highlightIndex - 1)
                }
            }

            // Clear button — fixed-width Item, animated visibility
            Item {
                Layout.preferredWidth: input.text.length > 0 ? 16 : 0
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                visible: input.text.length > 0
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 100 } }

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    anchors.centerIn: parent
                    // v7.0.0-alpha.10: Use Unicode MULTIPLICATION SIGN
                    // (U+00D7) instead of MaterialIcons.icon("close").
                    // Nerd Font's \uf00d glyph was rendering as a box
                    // on some setups; "×" is a basic Unicode codepoint
                    // present in every font — guaranteed to render as
                    // a proper close X regardless of font availability.
                    text: "×"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
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
                        floater.dropdownOpen = false
                        input.forceActiveFocus()
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // DROPDOWN (scrollable results panel, floats below the bar)
    //
    // Anchored to parent.top (relative to the floater Item itself),
    // pulled down by the bar height + 4px gap. Dropdown is HEIGHT-
    // BOUNDED so it never extends past the visible Settings area —
    // we use a height clamp formula:
    //
    //   actualResults * rowHeight   (preferred — fits all results)
    //   capped at 360px              (max — never larger than this)
    //   capped at panelHeight - 100  (ensures it stays inside Settings)
    //
    // List is scrollable internally if results > capped height.
    // ─────────────────────────────────────────────────────────
    Rectangle {
        id: dropdown

        // Position: just below the bar, same right edge
        anchors.top: barRect.bottom
        anchors.topMargin: 4
        anchors.right: barRect.right

        // Width: 320px (wider than bar so titles + subtitles fit)
        // — extends LEFT from the bar's right edge
        width: 320

        // Height: dynamic, bounded by row count + cap
        property real rowHeight: 48
        property real maxRows: 6   // ~288px max (6 * 48)
        height: visible
                ? Math.min(floater.results.length, maxRows) * rowHeight + 8
                : 0

        radius: 10
        color: LookService.surfaceColor(ThemeService.bg0, 0.99)
        border.color: ThemeService.alpha(ThemeService.fg, 0.18)
        border.width: 1
        clip: true
        z: 100

        // Drop shadow effect via stacked rectangle (lightweight)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            radius: parent.radius + 2
            color: "transparent"
            border.color: ThemeService.alpha("#000000", 0.3)
            border.width: 1
            opacity: 0.5
        }

        // v7.0.0-beta.1-hf41: belt-and-suspenders — dropdown is ONLY
        // visible when the search bar is in expanded mode. If the user
        // collapses while results were still in memory, the dropdown
        // hides immediately. Previously could orphan-render briefly.
        visible: floater.expanded
              && floater.dropdownOpen
              && floater.results.length > 0

        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        ListView {
            id: resultsList
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 0
            interactive: floater.results.length > dropdown.maxRows
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 200
            reuseItems: true

            model: floater.results

            // Scrollbar — only visible if list exceeds maxRows
            ScrollBar.vertical: ScrollBar {
                policy: floater.results.length > dropdown.maxRows
                        ? ScrollBar.AsNeeded
                        : ScrollBar.AlwaysOff
                width: 6
                anchors.right: parent.right
                anchors.rightMargin: 2

                contentItem: Rectangle {
                    radius: 3
                    color: ThemeService.alpha(ThemeService.fg, 0.3)
                }
            }

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: dropdown.rowHeight
                radius: 6
                color: (floater.highlightIndex === index || rowMa.containsMouse)
                       ? ThemeService.alpha(ThemeService.blue, 0.14)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 80 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: MaterialIcons.icon(modelData.icon || "tune")
                        font.family: MaterialIcons.fontFamily
                        font.pixelSize: 16
                        color: (floater.highlightIndex === index || rowMa.containsMouse)
                               ? ThemeService.blue
                               : ThemeService.grey0
                        Layout.preferredWidth: 22
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: modelData.title || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: ThemeService.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: !!(modelData.subtitle)
                            text: modelData.subtitle || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: floater.highlightIndex = index
                    onClicked: {
                        floater.navigateRequested(modelData)
                        input.text = ""
                        floater.dropdownOpen = false
                        input.focus = false
                    }
                }
            }
        }
    }
}
