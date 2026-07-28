import QtQuick
import Quickshell

/*
 * DenshoBrushSeparator v7.0.0-alpha.2
 *
 * A horizontal line that fades to transparent on both ends, mimicking
 * a sumi brush stroke that lifts off the paper. Used as a Densho-mode
 * replacement for hard 1px separator/underline lines in the Bar.
 *
 * Default behavior when DenshoService.useBrushSeparators is FALSE:
 *   renders as a flat 0.5px line (host-compatible fallback).
 *
 * When TRUE: renders as a 1px gradient with alpha fade-in/fade-out.
 *
 * Usage (drop-in replacement for Rectangle separator):
 *
 *   DenshoBrushSeparator {
 *       width: 240
 *       color: ThemeService.fg
 *   }
 *
 * Width is required from caller. Height is fixed at 1px.
 */
Item {
    id: root

    property color color: ThemeService ? ThemeService.fg : "#1A1410"
    property real lineOpacity: 0.5

    height: 1
    implicitHeight: 1

    // Plain mode — single rectangle, hard edges
    Rectangle {
        visible: !DenshoService.useBrushSeparators
        anchors.fill: parent
        color: root.color
        opacity: root.lineOpacity * 0.6   // hard line is more visible, dim it
    }

    // Brush mode — three-rect gradient stand-in. (Rectangle.gradient
    // doesn't support per-stop alpha cleanly, so we composite three
    // overlapping rects with linear-fade-friendly opacity profile.)
    Row {
        visible: DenshoService.useBrushSeparators
        anchors.fill: parent
        spacing: 0

        // Left fade-in (20% of width)
        Rectangle {
            width: parent.width * 0.20
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.lineOpacity) }
            }
        }
        // Solid mid (60%)
        Rectangle {
            width: parent.width * 0.60
            height: parent.height
            color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.lineOpacity)
        }
        // Right fade-out (20%)
        Rectangle {
            width: parent.width * 0.20
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.lineOpacity) }
                GradientStop { position: 1.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0) }
            }
        }
    }
}
