import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * ZenClock v6.16.4.12.6.53 (Hiraki 開き) — Hiraki hotfix 1
 *
 * Bar clock module that drives the GLOBAL calendar window (shell.qml's
 * `calendarWindow` → `ZenNotificationCenter`) via PanelState.
 *
 * Why we NOT use a local anchored PopupWindow:
 *   Multiple attempts to render a Quickshell `PopupWindow` anchored
 *   to the clock module failed in this user's setup — the popup
 *   either didn't render or rendered off-screen on top-bars. The
 *   global `calendarWindow` is known-good (the user has seen it open
 *   from the spacer trigger and from this same path in hotfix 3).
 *
 *   Hotfix 1 (.53) wires the clock's GLOBAL screen coordinates into
 *   PanelState so the global calendarWindow can anchor its right
 *   edge to the clock's right edge — visually identical to a
 *   PopupWindow anchored to the clock, but using the known-good
 *   layer-shell window. The popup now appears directly above (or
 *   below, for top bars) the clock instead of pinned to the screen
 *   edge.
 *
 * ─────────────────────────────────────────────────────────────────
 * Hiraki change (v6.16.4.12.6.52) — CLICK-TO-OPEN, NO HOVER-OPEN
 * ─────────────────────────────────────────────────────────────────
 *   The previous Hikari behaviour opened the calendar on a 150ms
 *   hover-intent delay. v6.16.4.12.6.52 made the calendar a strict
 *   CLICK-ONLY surface, matching the StartMenu pattern. Hover keeps
 *   the visual highlight (theme blue tint) so the module still feels
 *   reactive — but the popup itself only appears when the user
 *   actually clicks. Same approach kept here.
 *
 * ─────────────────────────────────────────────────────────────────
 * Hotfix 1 (v6.16.4.12.6.53) — POPUP ABOVE THE CLOCK
 * ─────────────────────────────────────────────────────────────────
 *   Previously the global calendarWindow was anchored to the screen's
 *   right edge with a hardcoded `margins.right: 12`. Visually correct
 *   in the common case (clock is rightmost in the right zone), but
 *   wrong whenever the user's bar layout puts other modules to the
 *   right of the clock, or when the bar layout changes between top
 *   and bottom positions.
 *
 *   Hotfix 1 reports the clock module's GLOBAL screen-space center-X
 *   and right-edge-X to PanelState on every click, BEFORE toggling
 *   the calendar. shell.qml's calendarWindow then binds
 *   `margins.right` to `screenWidth - clockRightEdgeX` (with
 *   clamping). The popup now appears directly above/below the clock
 *   no matter where the clock sits in the bar.
 *
 * Behaviour (unchanged from .52):
 *   • Hover the clock              → visual highlight ONLY (no popup)
 *   • Click the clock              → reports position, then toggles calendar
 *   • Right-click the clock        → cycles clock format
 *   • Scroll wheel                 → cycles calendar months IF the
 *                                    calendar is already open
 *
 * To dismiss the calendar: click the clock again, or click outside
 * the calendar window (HyprlandFocusGrab in shell.qml fires
 * onCleared → calendarVisible = false).
 *
 * ─────────────────────────────────────────────────────────────────
 * z-stacking — clock module always on top of the bar row
 * ─────────────────────────────────────────────────────────────────
 *   `z: 1` keeps the Clock above any sibling Loader/Item in the
 *   right-zone RowLayout so its MouseArea always wins click hits.
 *   Same value used on StartMenu for consistency.
 *
 * Sizing fix (CRITICAL — unchanged):
 *   width is computed from clockText + iconText.implicitWidth
 *   directly, NOT through `layoutRow.implicitWidth`. The latter
 *   creates a binding loop in the Loader→RowLayout→Loader hierarchy
 *   of Bar.qml that can resolve the Rectangle to 0×0, killing the
 *   MouseArea input area. Layout.preferredWidth/Height + Layout.alignment
 *   give the parent Loader-in-RowLayout explicit size hints.
 *
 * Theme sync:
 *   Background, border, text colours follow ThemeService — same
 *   approach used by start menu, taskbar, and ZenNotificationCenter.
 *
 * Install as Clock.qml in ~/.config/quickshell/zen-shell/.
 *
 * Wala tayong babawasan — only hover-to-open behaviour was removed.
 * All other Hikari plumbing (format cycle, wheel-month, theme
 * sync, sizing) preserved. .53 only ADDS the position reporter.
 */
Rectangle {
    id: root

    // v7.0.0-beta.1-hf91.1: explicit vertical mode (end-4 style). In a
    // vertical bar the clock sizes to the bar thickness and stacks its
    // text so the full date/time fits. Default false → original.
    property bool zenVertical: false

    // ── z-stack — Clock stays above sibling bar modules ──
    z: 1

    // ── Sizing — width from text widths directly ──
    readonly property real _contentW: iconText.implicitWidth
                                    + 8                   // RowLayout spacing
                                    + clockText.implicitWidth
    width:  zenVertical ? Math.round(Theme.moduleHeight) : (_contentW + 24)
    height: zenVertical ? (vClockCol.implicitHeight + 12) : Theme.moduleHeight
    Layout.preferredWidth:  zenVertical ? Math.round(Theme.moduleHeight) : (_contentW + 24)
    Layout.preferredHeight: zenVertical ? (vClockCol.implicitHeight + 12) : Theme.moduleHeight
    Layout.alignment: Qt.AlignVCenter

    // ── Theme-synced background ──
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
    color: ma.containsMouse || PanelState.calendarVisible
           ? ThemeService.alpha(ThemeService.blue, 0.25)
           : ThemeService.alpha(ThemeService.bg0, 0.9)
    border.width: 1
    border.color: ma.containsMouse || PanelState.calendarVisible
                  ? ThemeService.blue
                  : ThemeService.alpha(ThemeService.fg, 0.12)
    Behavior on color        { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    // ── Live time driver ──
    property var now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }

    // ─────────────────────────────────────────────────────────────
    // VISIBLE CONTENT — clock icon + live time
    // ─────────────────────────────────────────────────────────────
    RowLayout {
        id: layoutRow
        visible: !root.zenVertical
        anchors.centerIn: parent
        spacing: 8

        // v7.0.0-alpha.3 (Densho Surfaces): vertical kanji year column
        // + day-of-week kanji in shu-iro accent. Visible only when
        // DenshoService.useVerticalDate is true; collapses to zero
        // width otherwise so existing layout is unaffected.
        DenshoVerticalDate {
            now: root.now
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: iconText
            text: "\uf017"  // Nerd Font clock face
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: ma.containsMouse || PanelState.calendarVisible
                   ? ThemeService.blue
                   : ThemeService.fg
            Behavior on color { ColorAnimation { duration: 150 } }
            // v7.0.0-alpha.3: hide the Nerd Font clock icon when Densho
            // vertical date is on — the kanji column already serves as
            // the leading visual anchor for the clock module.
            visible: !DenshoService.useVerticalDate
        }

        Text {
            id: clockText
            text: {
                const idx = Math.max(0, Math.min(
                    ZenConstants.clockFormats.length - 1,
                    PanelState.clockFormatIndex))
                return ZenConstants.formatClock(
                    root.now,
                    ZenConstants.clockFormats[idx].format,
                    false)
            }
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: ThemeService.fg
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.15
        }
    }

    // v7.0.0-beta.1-hf93: vertical clock — 2-row readout. Top row is the
    // time stacked as H over MM (e.g. 9 / 29) so it fits the thin bar and
    // reads as the time; bottom is a compact MM/DD date. No leading-zero
    // on the hour (9, not 09).
    Column {
        id: vClockCol
        visible: root.zenVertical
        anchors.centerIn: parent
        spacing: 2

        // Hour (no leading zero) over minutes — the "time" block.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "h")
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 15
            font.weight: Font.Bold
            color: ThemeService.fg
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "mm")
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 15
            font.weight: Font.Bold
            color: ThemeService.fg
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.55; height: 1
            color: ThemeService.alpha(ThemeService.fg, 0.25)
        }

        // Date row: MM/DD stacked small.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "MM")
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 10
            color: ThemeService.grey1
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dd")
            font.family: ZenConstants.fontPrimary(PanelState.fontFamilyId)
            font.pixelSize: 10
            color: ThemeService.grey1
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Mirrors the StartMenu.qml pattern: compute the clock's GLOBAL
    // screen-space center-X and right-edge-X, push them to PanelState
    // for shell.qml's calendarWindow to consume. Called from
    // onClicked just before the calendar is toggled OPEN, so the
    // popup positions itself correctly on the very first frame.
    function reportPositionToPanelState() {
        const win = QsWindow.window
        if (!win) return

        const screenW = win.screen ? win.screen.width  : 1920
        const screenH = win.screen ? win.screen.height : 1080

        // Map clock module's local coordinates into the bar window's
        // local coordinates (item == null → window-local).
        const localCenter = root.mapToItem(null, root.width / 2, root.height / 2)
        const localRight  = root.mapToItem(null, root.width,     root.height / 2)

        // Compute the bar window's actual screen X offset. Layer
        // shell windows always report win.x = 0, so we have to
        // reconstruct the offset from the panel mode (mirrors the
        // StartMenu logic).
        let barScreenX = 0
        if (PanelState.panelMode === "island") {
            const barW = win.width || screenW
            barScreenX = (screenW - barW) / 2
        } else if (PanelState.panelMode === "floating") {
            barScreenX = PanelState.panelMarginSide
        }
        // else fullwidth: barScreenX = 0

        const globalCenterX = barScreenX + localCenter.x
        const globalRightX  = barScreenX + localRight.x

        if (typeof PanelState.reportClockPosition === "function") {
            PanelState.reportClockPosition(globalCenterX, globalRightX, screenW)
        } else {
            // Older PanelState without the reporter — fall back to
            // writing the properties directly. Harmless if absent.
            if (typeof PanelState.clockCenterX !== "undefined")
                PanelState.clockCenterX = globalCenterX
            if (typeof PanelState.clockRightEdgeX !== "undefined")
                PanelState.clockRightEdgeX = globalRightX
            if (screenW > 0 && typeof PanelState.screenWidth !== "undefined")
                PanelState.screenWidth = screenW
        }
        if (typeof screenH === "number" && screenH > 0
            && typeof PanelState.screenHeight !== "undefined") {
            PanelState.screenHeight = screenH
        }
    }

    // ─────────────────────────────────────────────────────────────
    // INPUT — hover (visual only), click, scroll
    // ─────────────────────────────────────────────────────────────
    // v6.16.4.12.6.52 (Hiraki): the 150ms hover-intent timer that
    // opened the calendar on hover has been REMOVED. Hover only
    // drives the visual highlight (background + border tint).

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true                     // ← still true, for visual highlight
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // No onEntered / onExited handlers — hover does NOT open the
        // calendar anymore. Same pattern as StartMenu.qml.

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // Right-click cycles clock format
                const n = ZenConstants.clockFormats.length
                PanelState.clockFormatIndex = (PanelState.clockFormatIndex + 1) % n
                PanelState.saveState()
                console.log("[Clock] format cycled →", PanelState.clockFormatIndex)
                return
            }

            // Hotfix 1 (.53): push the clock's screen-space position
            // into PanelState BEFORE toggling the calendar so
            // shell.qml's calendarWindow can anchor itself above the
            // clock on the very first frame it becomes visible.
            root.reportPositionToPanelState()

            // Left-click toggles the global calendar window
            const wantOpen = !PanelState.calendarVisible
            console.log("[Clock] click → calendarVisible should be:", wantOpen)
            if (wantOpen) {
                if (typeof PanelState.openCalendar === "function") {
                    PanelState.openCalendar()
                } else {
                    PanelState.calendarVisible = true
                }
            } else {
                if (typeof PanelState.closeCalendar === "function") {
                    PanelState.closeCalendar()
                } else {
                    PanelState.calendarVisible = false
                }
            }
        }
    }

    // Scroll wheel cycles calendar months — but ONLY when the
    // calendar is already open. Hiraki (.52) removed the
    // auto-open-on-scroll behaviour; scroll over a closed clock is
    // a no-op so it doesn't accidentally summon the popup.
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (!PanelState.calendarVisible) {
                event.accepted = false
                return
            }
            const dir = event.angleDelta.y > 0 ? -1 : +1   // wheel up → previous
            PanelState.calendarMonthDelta += dir
            event.accepted = true
        }
    }
}
