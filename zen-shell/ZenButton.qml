import QtQuick

/*
 * ZenButton v7.0.0-beta.1-hf86 — Karui (軽い)
 *
 * Modern, theme-aware push button — the house replacement for the plain
 * QtQuick.Controls `Button {}` (which renders with the flat platform
 * style and looks "basic"). Drop-in: set `text` and handle `clicked`.
 *
 *   ZenButton { text: "Open"; onClicked: foo() }
 *   ZenButton { text: "Create"; accent: true; iconText: "\uf067"; onClicked: ... }
 *
 * Props:
 *   text      — label
 *   iconText  — optional leading Nerd Font glyph
 *   accent    — true → filled accent (primary action); false → subtle
 *               surface fill (secondary). Default false.
 *   danger    — true → red accent (destructive). Overrides `accent` hue.
 *   enabled   — standard; dims + disables hover/press when false.
 *
 * Sizing hugs content (implicitWidth/Height) so it slots into Rows,
 * Layouts, and SettingRow value slots the same way the old Button did.
 *
 * Style: rounded (styleMode-aware), 1px hairline border, hover lift +
 * press sink via color/scale, smooth transitions. Uses ThemeService
 * tokens so it tracks Matugen/theme changes live.
 *
 * Wala tayong babawasan — purely additive component; existing Buttons
 * keep working, this is the modern alternative pages can adopt.
 */
Item {
    id: root

    property string text: ""
    property string iconText: ""
    property bool accent: false
    property bool danger: false
    property bool enabled: true

    // v7.0.0-beta.1-hf87: drop-in compatibility shims so plain
    // QtQuick.Controls Buttons migrate cleanly.
    //   highlighted   → alias for accent (Controls Button had this)
    //   compact       → smaller height + font for dense inline buttons
    //   fontPixelSize → optional label size override (0 = auto)
    property bool highlighted: false
    property bool compact: false
    property int  fontPixelSize: 0

    readonly property bool _accent: accent || highlighted
    readonly property int  _fontPx: fontPixelSize > 0
        ? fontPixelSize : (compact ? 11 : 13)

    signal clicked()

    // Resolve the accent hue (danger wins).
    readonly property color _accentCol: danger ? ThemeService.red : ThemeService.blue

    implicitHeight: compact ? 26 : 34
    implicitWidth: rowLayout.implicitWidth + (compact ? 18 : 28)
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: (Theme.styleMode === "round") ? height / 2 : 9

        // Fill:
        //   accent  → filled accent, brightening on hover, sinking on press
        //   subtle  → translucent surface that lifts on hover
        color: {
            if (root._accent) {
                if (ma.pressed) return Qt.darker(root._accentCol, 1.18)
                if (ma.containsMouse) return Qt.lighter(root._accentCol, 1.12)
                return root._accentCol
            }
            if (ma.pressed) return ThemeService.alpha(root._accentCol, 0.22)
            if (ma.containsMouse) return ThemeService.alpha(ThemeService.fg, 0.12)
            return ThemeService.alpha(ThemeService.fg, 0.06)
        }
        Behavior on color { ColorAnimation { duration: 120 } }

        border.width: 1
        border.color: root._accent
            ? LookService.surfaceColor(ThemeService.bg0, 0.0)
            : (ma.containsMouse
               ? ThemeService.alpha(root._accentCol, 0.55)
               : ThemeService.alpha(ThemeService.fg, 0.16))
        Behavior on border.color { ColorAnimation { duration: 120 } }

        scale: ma.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 7

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                visible: root.iconText.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.iconText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: root._fontPx
                color: root._accent
                    ? ThemeService.bg0
                    : ThemeService.fg
            }

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.family: Theme.fontFamily
                font.pixelSize: root._fontPx
                font.weight: Font.DemiBold
                color: root._accent
                    ? ThemeService.bg0
                    : ThemeService.fg
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: root.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
