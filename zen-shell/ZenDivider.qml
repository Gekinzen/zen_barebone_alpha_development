import QtQuick

/*
 * ZenDivider v7.0.0-beta.1-hf82k — Karui (軽い)
 *
 * Vertical 1px separator for inside the dock (or other RowLayout-based
 * containers). Theme-aware (uses ThemeService.fg at ~25% alpha). Sizes
 * itself to ~60% of its parent's height by default for a "module
 * boundary" look that doesn't bisect the full bar height.
 *
 * Sized via implicitWidth/implicitHeight so a parent RowLayout will
 * respect it without explicit Layout.* annotations. Spacing on either
 * side is handled by the parent's `spacing` property — the divider
 * itself doesn't pad.
 *
 * Wala tayong babawasan — additive widget; no consumer changes.
 */
Item {
    id: root

    // Parent-relative sizing.
    property real heightRatio: 0.6
    property color color: (typeof ThemeService !== "undefined")
        ? Qt.rgba(
            ThemeService.fg.r,
            ThemeService.fg.g,
            ThemeService.fg.b,
            0.25
          )
        : Qt.rgba(1, 1, 1, 0.25)

    implicitWidth: 1
    implicitHeight: parent ? Math.max(8, parent.height * heightRatio) : 32

    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height
        color: root.color
        radius: 0.5
    }
}
