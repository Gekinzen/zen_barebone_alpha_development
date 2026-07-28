import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ZenDashNavRow v8.0.0-alpha-hf129
 *
 * One row of the Zen Control Center sidebar nav. Extracted because hf129
 * renders it in three places — the standalone Dashboard row, the children of
 * a collapsible category group, and the flat icon list a narrow sidebar falls
 * back to. Three copies of the same 25 lines is how a pill ends up looking
 * different in one of them.
 *
 * The row is layout-neutral on purpose: no Layout.* attached properties and
 * no width binding live here, because the accordion body is a plain Column
 * (arithmetic height, so a collapsed group costs nothing) while the other two
 * call sites are ColumnLayouts. The caller owns the geometry; this owns the
 * look.
 *
 * Wala tayong babawasan — pixel-for-pixel the same pill hf128 drew: 32px tall,
 * radius 9, 20% blue when selected, 7% fg on hover, 12px left inset, 13px Nerd
 * Font glyph, 12px label that bolds when it is the current page.
 */
Rectangle {
    id: row

    property string label: ""
    property string icon: ""
    property bool   selected: false
    /** Icon-only mode — the sidebar collapses to 62px under `dash.narrow`. */
    property bool   narrow: false
    property string tooltip: ""
    /** Extra left inset. Group children sit slightly in from their header. */
    property int    indent: 0

    // ══ v8.0.0-alpha-hf177 — DENSHO REACHES THE SIDEBAR ══
    //
    // Densho mode kanji-fied the workspaces, the clock, the separators and
    // every settings page header — then stopped at the nav rail, so the
    // page said 色 · Iro · Themes while the row you clicked to get there
    // still said "Themes" next to a Nerd Font palette glyph.
    //
    // Now the glyph slot carries the kanji and the row gains a faint romaji
    // tail. Collapsed (`narrow`) sidebars become a kanji column, which is
    // the single best-looking thing this mode does.
    //
    // Wala tayong babawasan — both properties default to "" and `_densho`
    // requires DenshoService.denshoMode, so with Densho off (or a label the
    // vocabulary doesn't cover) this file renders exactly as hf129 drew it.
    property string kanji: ""
    property string romaji: ""
    readonly property bool _densho: (typeof DenshoService !== "undefined")
                                    && DenshoService.denshoMode
                                    && row.kanji.length > 0

    signal activated()

    implicitHeight: 32
    radius: 9
    antialiasing: true
    color: row.selected ? ThemeService.alpha(ThemeService.blue, 0.20)
                        : (navRowMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.07)
                                                  : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12 + row.indent
        anchors.rightMargin: 8
        spacing: 10

        Text {
            // Kanji in Densho mode, Nerd glyph otherwise. Fixed width in
            // Densho so a two-character word and a one-character word start
            // their labels on the same column — a ragged left edge is what
            // makes a mixed-script list look broken.
            text: row._densho ? row.kanji : row.icon
            font.family: row._densho ? "Noto Sans CJK JP" : "JetBrainsMono Nerd Font"
            font.pixelSize: row._densho ? 12 : 13
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: row._densho ? 30 : implicitWidth
            color: row.selected ? ThemeService.blue : LookService.textFaintColor(ThemeService.grey1)
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
        }
        Text {
            visible: !row.narrow
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
            text: row.label
            color: row.selected ? LookService.textColor(ThemeService.fg) : LookService.textDimColor(ThemeService.grey1)
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            font.pixelSize: 12
            font.bold: row.selected
            font.family: Theme.fontFamily
        }
        Text {
            // Romaji tail — the "wordings". Shrinks out of the way first
            // when the sidebar is tight, so it can never push the English
            // label into an ellipsis.
            visible: !row.narrow && row._densho && row.romaji.length > 0
            text: row.romaji
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.italic: true
            elide: Text.ElideRight
            Layout.maximumWidth: 64
            color: ThemeService.alpha(row.selected ? ThemeService.blue : ThemeService.grey1, 0.65)
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
        }
    }

    MouseArea {
        id: navRowMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
        ToolTip.visible: containsMouse && row._tooltipText.length > 0
        ToolTip.delay: 450
        ToolTip.text: row._tooltipText
    }

    // A collapsed Densho sidebar is kanji-only, so the tooltip is the only
    // place the English name survives — always give it one there.
    readonly property string _tooltipText: {
        if (row.tooltip.length > 0) return row.tooltip
        if (row._densho && row.narrow)
            return row.kanji + (row.romaji.length > 0 ? " · " + row.romaji : "") + " · " + row.label
        if (row._densho && row.romaji.length > 0) return row.kanji + " · " + row.romaji
        return ""
    }
}
