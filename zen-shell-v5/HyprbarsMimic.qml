import QtQuick
import QtQuick.Layouts

/*
 * HyprbarsMimic v7.0.0-beta.1-hf53 — Karui (軽い)
 *
 * In-shell title bar component that visually + behaviorally mimics
 * the hyprbars plugin on Zen Shell's own layer-shell popup surfaces
 * (ControlPanel / ZenSettings / etc).
 *
 * User request:
 *   "yung hypr control center natin , quick settings may hyprbars
 *    din kapag naka enable"
 *
 * Why we need a mimic:
 *   The hyprbars plugin runs INSIDE Hyprland and applies only to
 *   regular Hyprland windows (XDG/X11 toplevels). Quickshell
 *   layer-shell surfaces (ControlPanel popup, ZenSettings panel)
 *   are NOT Hyprland-managed windows — they live on layer-shell.
 *   So hyprbars never renders on them naturally.
 *
 *   Solution: render an equivalent title bar from inside Zen Shell
 *   that follows HyprbarsService's settings (colors, button side,
 *   visibility, height). Visually indistinguishable from a real
 *   hyprbars bar on a regular window.
 *
 * Usage:
 *   At the top of any popup surface (ControlPanel.qml, ZenSettings,
 *   etc.), add:
 *
 *       HyprbarsMimic {
 *           anchors.top: parent.top
 *           anchors.left: parent.left
 *           anchors.right: parent.right
 *           title: "Quick Settings"
 *           onCloseClicked: parent.closeRequested()
 *           onDragRequested: { ... drag logic ... }
 *       }
 *
 *   The component automatically:
 *     - Shows only when HyprbarsService.enabled is true
 *     - Uses HyprbarsService colors (synced with theme)
 *     - Uses HyprbarsService.buttonSide (left/right)
 *     - Uses HyprbarsService.showMinimize/showMaximize/showClose
 *     - Sizes to HyprbarsService.barHeight
 *
 * For surfaces that don't have minimize/maximize semantics (popup
 * panels don't typically minimize), the minimize button is a
 * no-op or hidden via the standalone `showMinimizeButton` property.
 */
Rectangle {
    id: bar

    // v7.0.0-beta.1-hf60 — gate on pluginLoaded.
    // v7.0.0-beta.1-hf63 — per-instance override for layer-shell surfaces.
    //
    // Default: only visible when real plugin is loaded (consistent UX).
    //
    // BUT layer-shell surfaces (ControlPanel, ZenSettings) can NEVER
    // get real hyprbars — the plugin only draws on XDG toplevels. So
    // those surfaces set `alwaysShowWhenEnabled: true` to show the
    // mimic whenever the user has hyprbars turned on. This is the
    // ONLY way to get title bar UX on those surfaces.
    //
    // When hyprbars is disabled, the mimic hides and the parent
    // surface's native header (draggable + X button) re-appears.
    property bool alwaysShowWhenEnabled: false

    visible: typeof HyprbarsService !== "undefined"
             && HyprbarsService.enabled
             && (HyprbarsService.pluginLoaded
                 || bar.alwaysShowWhenEnabled
                 || HyprbarsService.showMimicFallback)
    height: visible ? HyprbarsService.barHeight : 0

    // Title shown in the bar
    property string title: ""

    // Surface-level controls — let parent decide what each button does.
    // Sensible defaults provided so the bar works as a basic drag handle
    // + close button with zero parent wiring.
    signal closeClicked()
    signal maximizeClicked()
    signal minimizeClicked()
    signal dragRequested()   // emitted on press of drag area

    // Per-instance overrides for button visibility (useful when a
    // popup doesn't have a maximize semantic). Defaults to whatever
    // HyprbarsService says.
    property bool showCloseButton:   typeof HyprbarsService !== "undefined" ? HyprbarsService.showClose : true
    property bool showMaximizeButton: typeof HyprbarsService !== "undefined" ? HyprbarsService.showMaximize : true
    property bool showMinimizeButton: typeof HyprbarsService !== "undefined" ? HyprbarsService.showMinimize : true

    // Colors mirror what hyprbars renders on real windows
    color: {
        if (typeof ThemeService === "undefined") return "#282828"
        if (typeof HyprbarsService !== "undefined" && HyprbarsService.syncWithTheme) {
            return ThemeService.bg1 || ThemeService.bg0 || "#282828"
        }
        return "#282828"
    }
    radius: 6

    // Apply blur backdrop semantics where available. PanelWindow
    // children inherit the parent surface's blur, so just keep the
    // color slightly translucent when blur is on.
    opacity: (typeof HyprbarsService !== "undefined" && HyprbarsService.barBlur)
             ? 0.92 : 1.0

    // hf95.20: when true, the title is centered across the WHOLE bar
    // (ignoring button side) instead of hugging the side opposite the
    // buttons. Used by the Settings/Control-Center window so
    // "Zen-Shell-Hypr-Control-Center" sits dead-center.
    property bool centerTitle: false

    // ── Title text ──
    Text {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        // Centered mode: anchor to the bar's horizontal center. Otherwise
        // keep the original side-aware anchoring.
        anchors.horizontalCenter: bar.centerTitle ? parent.horizontalCenter : undefined
        anchors.left: bar.centerTitle ? undefined
                       : ((HyprbarsService && HyprbarsService.buttonSide === "left")
                          ? buttonRow.right : parent.left)
        anchors.right: bar.centerTitle ? undefined
                        : ((HyprbarsService && HyprbarsService.buttonSide === "right")
                           ? buttonRow.left : parent.right)
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        text: bar.title
        color: {
            if (typeof ThemeService === "undefined") return "#ebdbb2"
            return ThemeService.fg || "#ebdbb2"
        }
        font.family: Theme.fontFamily
        font.pixelSize: HyprbarsService ? HyprbarsService.barTextSize : 11
        font.weight: Font.Medium
        horizontalAlignment: bar.centerTitle ? Text.AlignHCenter
                              : ((HyprbarsService && HyprbarsService.buttonSide === "left")
                                 ? Text.AlignRight : Text.AlignLeft)
        elide: Text.ElideRight
    }

    // ── Drag area covers the title region ──
    // FIRST sibling so buttons render on top via natural QML order
    // (proven pattern from hf49/hf50 — no z: -1 needed).
    // hf95.20: optional window to drag directly. When set (e.g. the
    // ZenSettings root), the title bar's drag area moves it just like the
    // native header — so the bar is actually draggable. When null, it
    // only emits dragRequested() as before.
    property var dragTarget: null

    MouseArea {
        id: dragArea
        anchors.fill: parent
        // Reserve the button area so clicks on buttons aren't stolen
        anchors.leftMargin:  (HyprbarsService && HyprbarsService.buttonSide === "left")
                              ? buttonRow.width + 6 : 0
        anchors.rightMargin: (HyprbarsService && HyprbarsService.buttonSide === "right")
                              ? buttonRow.width + 6 : 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: bar.dragTarget
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.minimumY: 0
        preventStealing: true
        onPressed: bar.dragRequested()
    }

    // ── Button row ──
    // Anchored to whichever side the user picked
    Row {
        id: buttonRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: (HyprbarsService && HyprbarsService.buttonSide === "left")
                       ? parent.left : undefined
        anchors.right: (HyprbarsService && HyprbarsService.buttonSide === "right")
                        ? parent.right : undefined
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 4

        // Buttons render LEFT→RIGHT in this Row. We pre-compute which
        // glyph goes in which slot based on buttonSide so close ends
        // up at the outermost edge (matches hyprbars layout).
        //
        // Left side  (macOS):  close, minimize, maximize
        // Right side (Win):    minimize, maximize, close

        Component {
            id: btnComponent
            Rectangle {
                property string glyph: ""
                property color bgColor: "#fb4934"
                property color fgColor: "#1d2021"
                property var onActivate: function() {}
                property string tooltip: ""

                width: 14
                height: 14
                radius: 7
                color: ma.containsMouse ? Qt.lighter(bgColor, 1.15) : bgColor
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: parent.glyph
                    color: parent.fgColor
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 8
                    visible: ma.containsMouse
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.onActivate()
                }
            }
        }

        // Helper to build a button instance with a given config
        // We use Repeater + a data model for compact, declarative code.
        Repeater {
            model: {
                const arr = []
                const closeBtn = {
                    glyph: "\uf00d",
                    bg: (typeof ThemeService !== "undefined" && HyprbarsService && HyprbarsService.syncWithTheme)
                        ? (ThemeService.red || "#fb4934") : "#fb4934",
                    fg: (typeof ThemeService !== "undefined" && HyprbarsService && HyprbarsService.syncWithTheme)
                        ? (ThemeService.bg0 || "#1d2021") : "#1d2021",
                    action: function() { bar.closeClicked() },
                    visible: bar.showCloseButton,
                    key: "close"
                }
                const minBtn = {
                    glyph: "_",
                    bg: (typeof ThemeService !== "undefined" && HyprbarsService && HyprbarsService.syncWithTheme)
                        ? (ThemeService.green || "#b8bb26") : "#b8bb26",
                    fg: (typeof ThemeService !== "undefined" && HyprbarsService && HyprbarsService.syncWithTheme)
                        ? (ThemeService.bg0 || "#1d2021") : "#1d2021",
                    action: function() { bar.minimizeClicked() },
                    visible: bar.showMinimizeButton,
                    key: "min"
                }
                const maxBtn = {
                    glyph: "\uf2d0",
                    bg: (typeof ThemeService !== "undefined" && HyprbarsService && HyprbarsService.syncWithTheme)
                        ? (ThemeService.yellow || "#fabd2f") : "#fabd2f",
                    fg: (typeof ThemeService !== "undefined" && HyprbarsService && HyprbarsService.syncWithTheme)
                        ? (ThemeService.bg0 || "#1d2021") : "#1d2021",
                    action: function() { bar.maximizeClicked() },
                    visible: bar.showMaximizeButton,
                    key: "max"
                }
                if (HyprbarsService && HyprbarsService.buttonSide === "left") {
                    // macOS: close, min, max from leftmost
                    if (closeBtn.visible) arr.push(closeBtn)
                    if (minBtn.visible)   arr.push(minBtn)
                    if (maxBtn.visible)   arr.push(maxBtn)
                } else {
                    // Windows: min, max, close from leftmost (close rightmost)
                    if (minBtn.visible)   arr.push(minBtn)
                    if (maxBtn.visible)   arr.push(maxBtn)
                    if (closeBtn.visible) arr.push(closeBtn)
                }
                return arr
            }

            delegate: Rectangle {
                width: 14
                height: 14
                radius: 7
                // hf64 — hover = brighter highlight, no glyph icon.
                // Pure macOS-style color dots.
                color: btnMa.containsMouse
                       ? Qt.lighter(modelData.bg, 1.25)
                       : modelData.bg
                Behavior on color { ColorAnimation { duration: 100 } }

                // hf64 — glyphs REMOVED per user request.
                // Pure color dots only — no icon reveal on hover.

                MouseArea {
                    id: btnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.action()
                }
            }
        }
    }
}
