import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
 * ZenBarPill v6.16.4.12.7 — clickable pill wrapper for bar modules
 *
 * Wala tayo babawasan: this is a NEW additive component. Existing bar
 * modules (SysRow, Music, Notification, Tray, Battery, Network, etc.)
 * keep working untouched. Use this wrapper to add hover-state + click
 * feedback + optional popup hosting around any bar module's content.
 *
 * It does NOT replace any module — it's a wrapper you can opt-in to per
 * module by replacing the module's outer Item/Rectangle with this. Or
 * leave the module as-is; both styles work.
 *
 * Provides:
 *   - subtle hover background tint (like Clock.qml's hover rect)
 *   - active/pressed scale-down feedback
 *   - cursor shape pointer
 *   - clicked() signal you can wire up
 *   - tooltip via tooltipText
 *
 * USAGE (wrapping any existing content):
 *
 *   ZenBarPill {
 *       tooltipText: "CPU usage"
 *       onClicked: PanelState.openSysMonitor()
 *
 *       RowLayout {
 *           anchors.centerIn: parent
 *           // existing CPU pill content here
 *       }
 *   }
 *
 * Per-instance overrides:
 *   - hoverAlpha       (real)  hover bg alpha against ThemeService.fg
 *                              (default 0.10)
 *   - activeBorderAlpha (real) hover border alpha against ThemeService.blue
 *                              (default 0.35)
 *   - pressedScale     (real)  scale-down on press (default 0.96)
 *   - cornerRadius     (int)   default 8
 *   - paddingH         (int)   horizontal padding (default 8)
 *   - hoverDelayMs     (int)   delay before hover state visually engages,
 *                              prevents flicker on cursor flyovers.
 *                              Default 0 (instant). Set 80–120 for the
 *                              "intent-aware" feel.
 *   - usePointerCursor (bool)  default true
 */
Item {
    id: pill

    // ── public API ──
    property string tooltipText: ""
    property real   hoverAlpha:        0.10
    property real   activeBorderAlpha: 0.35
    property real   pressedScale:      0.96
    property int    cornerRadius:      8
    property int    paddingH:          8
    property int    hoverDelayMs:      0
    property bool   usePointerCursor:  true

    signal clicked()
    signal pressedDown()
    signal released()

    // ── implicit sizing matches content ──
    default property alias _contentChildren: contentSlot.data
    implicitWidth:  contentSlot.implicitWidth + paddingH * 2
    implicitHeight: contentSlot.implicitHeight > 0 ? contentSlot.implicitHeight : 28

    // ── hover state (with optional delay) ──
    property bool _hoverActive: false
    Timer {
        id: hoverDelayTimer
        interval: pill.hoverDelayMs
        repeat: false
        onTriggered: pill._hoverActive = pillMouse.containsMouse
    }

    // ── visuals ──
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: cornerRadius
        color: pillMouse.pressed
                   ? ThemeService.alpha(ThemeService.fg, hoverAlpha + 0.06)
                   : (pill._hoverActive
                          ? ThemeService.alpha(ThemeService.fg, hoverAlpha)
                          : "transparent")
        border.width: pill._hoverActive ? 1 : 0
        border.color: ThemeService.alpha(ThemeService.blue, activeBorderAlpha)
        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on border.width { NumberAnimation { duration: 110 } }
    }

    // ── content slot (children placed here) ──
    Item {
        id: contentSlot
        anchors.fill: parent
        anchors.leftMargin: pill.paddingH
        anchors.rightMargin: pill.paddingH
        // Children added to ZenBarPill go here via default property alias
    }

    scale: pillMouse.pressed ? pressedScale : 1.0
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

    // ── interaction ──
    MouseArea {
        id: pillMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pill.usePointerCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton

        onEntered: {
            if (pill.hoverDelayMs <= 0) pill._hoverActive = true
            else hoverDelayTimer.restart()
        }
        onExited: {
            hoverDelayTimer.stop()
            pill._hoverActive = false
        }
        onPressed: pill.pressedDown()
        onReleased: pill.released()
        onClicked: pill.clicked()
    }

    // ── tooltip (lightweight — uses Qt's native ToolTip pattern) ──
    // Only attached when text is provided. Rendered via TapHandler-free
    // path so the MouseArea above retains all events.
    ToolTip {
        visible: tooltipText.length > 0 && pill._hoverActive
        text: tooltipText
        delay: 600
        timeout: 5000
    }
}
