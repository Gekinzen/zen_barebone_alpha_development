import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

/*
 * ZenDropdown v6.16.4.12.6.14 — modern Justinmind-style dropdown
 *
 * Extends QQC2 ComboBox (same base as ZenComboBox.qml) so it inherits the
 * proven popup positioning + flip logic + Wayland-safe sizing. On top of
 * that base we add:
 *   - Modern trigger styling (rounded, subtle border, hover bg, blue
 *     accent border when open)
 *   - Soft scale-in popup animation (160ms cubic, with translate offset)
 *   - Justinmind fade-on-hover (siblings dim to 0.55 when one item is
 *     hovered)
 *   - Optional inline search bar (auto-shown at >= searchThreshold items)
 *   - Section headers + per-item swatches/icons/disabled state via the
 *     rich entry model
 *   - "current" meta label on the active item
 *
 * USAGE — backwards compatible with ZenComboBox (plain string list):
 *
 *   ZenDropdown {
 *       width: 220
 *       model: ["Option A", "Option B", "Option C"]
 *       currentIndex: 0
 *       onActivated: (idx) => console.log("picked", idx)
 *   }
 *
 * USAGE — rich entry model (sections, swatches, disabled items):
 *
 *   ZenDropdown {
 *       width: 260
 *       model: [
 *           { kind: "section", text: "Built-in" },
 *           { text: "Tokyo Night", value: "tokyo-night",
 *             swatch: "#7aa2f7" },
 *           { kind: "section", text: "Custom" },
 *           { text: "Matugen Auto", value: "matugen-auto",
 *             swatch: "#f3bf48",
 *             enabled: ThemeService.matugenEnabled,
 *             meta: "auto" }
 *       ]
 *       onSelected: (entry) => console.log(entry.value)
 *   }
 *
 * The component normalizes both forms internally. For string-list mode it
 * looks/behaves identical to ZenComboBox (drop-in replacement). For rich
 * mode you get sections/swatches/disabled-with-reason.
 *
 * Wala tayo babawasan: ZenComboBox.qml stays untouched. This is a
 * separate component — pages opt in by changing `ZenComboBox {` →
 * `ZenDropdown {`. Pages that don't migrate keep working exactly as
 * before.
 */
ComboBox {
    id: root

    // ── Public API extensions ──
    property int  maxPopupHeight: 320
    property int  flipMargin: 80
    property int  searchThreshold: 6
    property string emptyText: "No matches"

    signal selected(var entry)

    // ── Internal: normalized entries ──
    property var _entries: []
    property var _filteredIndices: []
    property string _query: ""

    function _normalize() {
        const out = []
        const m = model
        if (!m) { _entries = out; _filteredIndices = []; return }
        const len = (m.length !== undefined) ? m.length : 0
        for (var i = 0; i < len; i++) {
            const e = m[i]
            if (typeof e === "string") {
                out.push({
                    kind: "item", text: e, value: e,
                    swatch: "", icon: "", meta: "", enabled: true
                })
            } else if (e && typeof e === "object") {
                out.push({
                    kind: e.kind || "item",
                    text: e.text || e.label || e.name || "",
                    value: e.value !== undefined ? e.value
                         : (e.id || e.text || ""),
                    swatch: e.swatch || "",
                    icon: e.icon || "",
                    meta: e.meta || "",
                    enabled: e.enabled === undefined ? true : !!e.enabled
                })
            }
        }
        _entries = out
        _refilter()
    }

    function _refilter() {
        const q = (_query || "").toLowerCase().trim()
        const arr = []
        for (var i = 0; i < _entries.length; i++) {
            const e = _entries[i]
            if (e.kind === "section") { arr.push(i); continue }
            if (!q) { arr.push(i); continue }
            if ((e.text || "").toLowerCase().indexOf(q) >= 0) arr.push(i)
        }
        // Drop section headers that have no following items in the filtered set
        const cleaned = []
        for (var j = 0; j < arr.length; j++) {
            const idx = arr[j]
            if (_entries[idx].kind === "section") {
                var hasItem = false
                for (var k = j + 1; k < arr.length; k++) {
                    if (_entries[arr[k]].kind === "section") break
                    hasItem = true; break
                }
                if (!hasItem) continue
            }
            cleaned.push(idx)
        }
        _filteredIndices = cleaned
    }

    onModelChanged: _normalize()
    Component.onCompleted: _normalize()

    // ── displayText so trigger shows the right label ──
    // ComboBox normally pulls displayText from the model + textRole. With
    // our rich entries we override it explicitly.
    displayText: {
        if (currentIndex < 0 || currentIndex >= _entries.length) return ""
        return (_entries[currentIndex] || {}).text || ""
    }

    // ── Custom trigger (contentItem + indicator + background) ──
    background: Rectangle {
        implicitHeight: 36
        radius: 8
        color: root.popup.visible || mouseHover.containsMouse
                ? ThemeService.alpha(ThemeService.fg, 0.06)
                : ThemeService.alpha(ThemeService.bg2, 0.5)
        border.width: 1
        border.color: root.popup.visible
                ? ThemeService.alpha(ThemeService.blue, 0.45)
                : (mouseHover.containsMouse
                       ? ThemeService.alpha(ThemeService.fg, 0.20)
                       : ThemeService.alpha(ThemeService.fg, 0.10))
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Hover detector (lives under the contentItem so clicks still
        // reach ComboBox's built-in handler)
        MouseArea {
            id: mouseHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // pass clicks through to ComboBox
        }
    }

    contentItem: RowLayout {
        spacing: 8
        Item { Layout.preferredWidth: 4 }   // left padding

        // Active swatch (if entry has one)
        Rectangle {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            radius: 6
            visible: {
                const e = _entries[currentIndex]
                return e && e.swatch && e.swatch.length > 0
            }
            color: visible ? _entries[currentIndex].swatch : "transparent"
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.20)
        }

        // Active icon glyph
        Text {
            visible: {
                const e = _entries[currentIndex]
                return e && e.icon && e.icon.length > 0
            }
            text: visible ? _entries[currentIndex].icon : ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: ThemeService.fg
            Layout.preferredWidth: visible ? 14 : 0
        }

        Text {
            Layout.fillWidth: true
            text: root.displayText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: currentIndex >= 0 ? Font.Medium : Font.Normal
            color: currentIndex >= 0 ? ThemeService.fg : ThemeService.grey1
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    indicator: Item {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = ThemeService.alpha(ThemeService.fg, 0.55)
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(2, 4)
                ctx.lineTo(width / 2, height - 4)
                ctx.lineTo(width - 2, 4)
                ctx.stroke()
            }
            Connections {
                target: ThemeService
                function onThemeChanged() { parent.requestPaint() }
            }
        }
    }

    // ── Modern popup with sections + search + fade-on-hover ──
    popup: Popup {
        id: zenPopup
        // y: bound below with flip-aware logic (after spaceAbove/spaceBelow
        // are computed). v6.16.4.12.6.14 had a duplicate `y:` here that
        // caused the QML loader to bail with "Property value set multiple
        // times". v15 fix: keep only the flip-aware binding below.
        width: Math.max(root.width, 200)
        padding: 8

        // Bound height to lesser of: content, maxPopupHeight, available space
        readonly property int spaceBelow: {
            const win = root.Window.window
            if (!win) return root.maxPopupHeight
            const triggerBottom = root.mapToItem(null, 0, root.height).y
            return Math.max(120, win.height - triggerBottom - 16)
        }
        readonly property int spaceAbove: {
            const win = root.Window.window
            if (!win) return root.maxPopupHeight
            return Math.max(120, root.mapToItem(null, 0, 0).y - 16)
        }

        // Auto-flip upward if there's not enough space below AND more above
        readonly property bool flipUp:
            (popupCol.implicitHeight + 16 > spaceBelow)
            && (spaceAbove > spaceBelow)
        y: flipUp
            ? -(Math.min(maxPopupHeight, popupCol.implicitHeight + 16)) - 6
            : (root.height + 6)

        height: Math.min(
            root.maxPopupHeight,
            popupCol.implicitHeight + 16,
            flipUp ? spaceAbove : spaceBelow)

        background: Rectangle {
            radius: 10
            color: Qt.rgba(ThemeService.bg1.r, ThemeService.bg1.g,
                           ThemeService.bg1.b, 0.98)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.12)
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 160; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; from: 1; to: 0.97; duration: 140; easing.type: Easing.InCubic }
            }
        }

        contentItem: ColumnLayout {
            id: popupCol
            spacing: 4
            // Internal: which entry is currently hovered
            property int _hoveredIndex: -1

            // Search bar (auto-shown when >= searchThreshold)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                visible: _entries.length >= root.searchThreshold
                radius: 6
                color: ThemeService.alpha(ThemeService.fg, 0.04)
                border.width: 1
                border.color: searchInput.activeFocus
                              ? ThemeService.alpha(ThemeService.blue, 0.40)
                              : ThemeService.alpha(ThemeService.fg, 0.08)

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    text: _query
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.fg
                    clip: true
                    onTextChanged: { _query = text; _refilter() }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search…"
                        font: searchInput.font
                        color: ThemeService.alpha(ThemeService.fg, 0.45)
                        visible: searchInput.text.length === 0
                    }
                }
            }

            // Scrollable item list
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(
                    contentHeight,
                    root.maxPopupHeight
                        - (_entries.length >= root.searchThreshold ? 44 : 16))
                clip: true
                model: _filteredIndices.length

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    width: listView.width
                    height: rowEntry && rowEntry.kind === "section" ? 22 : 32

                    property var rowEntry: _entries[_filteredIndices[index]]
                    property int realIndex: _filteredIndices[index]

                    // Section header
                    Item {
                        anchors.fill: parent
                        visible: rowEntry && rowEntry.kind === "section"

                        Rectangle {
                            visible: index > 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            height: 1
                            color: ThemeService.alpha(ThemeService.fg, 0.08)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: rowEntry ? (rowEntry.text || "") : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            font.capitalization: Font.AllUppercase
                            color: ThemeService.grey1
                        }
                    }

                    // Item row
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        visible: rowEntry && rowEntry.kind !== "section"
                        radius: 6

                        // Justinmind fade: when ANY item is hovered, others dim
                        opacity: {
                            if (!rowEntry || !rowEntry.enabled) return 0.35
                            if (popupCol._hoveredIndex < 0) return 1.0
                            return popupCol._hoveredIndex === realIndex
                                   ? 1.0 : 0.55
                        }
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        color: {
                            if (!rowEntry) return "transparent"
                            if (realIndex === root.currentIndex)
                                return ThemeService.alpha(ThemeService.blue, 0.18)
                            if (itemMouse.containsMouse && rowEntry.enabled)
                                return ThemeService.alpha(ThemeService.fg, 0.06)
                            return "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: 90 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 11
                                Layout.preferredHeight: 11
                                radius: 6
                                visible: rowEntry && rowEntry.swatch
                                         && rowEntry.swatch.length > 0
                                color: visible ? rowEntry.swatch : "transparent"
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }

                            Text {
                                visible: rowEntry && rowEntry.icon
                                         && rowEntry.icon.length > 0
                                text: visible ? rowEntry.icon : ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ThemeService.fg
                                Layout.preferredWidth: visible ? 14 : 0
                            }

                            Text {
                                Layout.fillWidth: true
                                text: rowEntry ? (rowEntry.text || "") : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: realIndex === root.currentIndex
                                             ? Font.Medium : Font.Normal
                                color: realIndex === root.currentIndex
                                       ? ThemeService.blue : ThemeService.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: (rowEntry && rowEntry.meta
                                          && rowEntry.meta.length > 0)
                                         || realIndex === root.currentIndex
                                text: realIndex === root.currentIndex
                                      ? "current"
                                      : (rowEntry ? (rowEntry.meta || "") : "")
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: ThemeService.grey1
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: rowEntry && rowEntry.enabled
                            cursorShape: enabled ? Qt.PointingHandCursor
                                                 : Qt.ForbiddenCursor
                            onContainsMouseChanged: {
                                if (containsMouse)
                                    popupCol._hoveredIndex = realIndex
                                else if (popupCol._hoveredIndex === realIndex)
                                    popupCol._hoveredIndex = -1
                            }
                            onClicked: {
                                if (!rowEntry || !rowEntry.enabled) return
                                root.currentIndex = realIndex
                                root.activated(realIndex)
                                root.selected(rowEntry)
                                _query = ""
                                searchInput.text = ""
                                _refilter()
                                zenPopup.close()
                            }
                        }
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                visible: _filteredIndices.length === 0
                Text {
                    anchors.centerIn: parent
                    text: root.emptyText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }
            }
        }
    }
}
