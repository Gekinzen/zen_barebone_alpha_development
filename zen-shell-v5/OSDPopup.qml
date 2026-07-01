import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * OSDPopup v7.0.0-alpha.12 — Karui (軽い)
 *
 * Transient on-screen display for volume + brightness changes.
 * Windows / macOS / GNOME all do this — a small horizontal pill
 * at the bottom-center showing the current value with a progress
 * bar that auto-dismisses after ~1.5s.
 *
 * Listens to NotificationService.osdRequested(kind, value, label).
 * Renders ONLY transient state — never persists in notification
 * history. Visual changes match current ThemeService colors.
 *
 * Mounted ONCE per screen via Variants in shell.qml. Anchored
 * bottom-center, ~120px above the bar.
 *
 * Visual:
 *
 *   ┌────────────────────────────────────────────────┐
 *   │  🔊  ████████████████░░░░░░░░░░░░  65%         │
 *   └────────────────────────────────────────────────┘
 *
 *   Auto-dismisses after 1500ms. Re-triggering resets the timer
 *   so rapid scroll-wheel changes feel responsive.
 */
Rectangle {
    id: osd

    // v7.0.0-beta.1-hf22: ALWAYS visible at the QML layer. The fade
    // in/out is purely opacity-based. PanelWindow surface stays
    // mounted (always-on with empty mask = click-through). This
    // decouples our "is OSD showing?" state from Wayland surface
    // lifecycle, which was causing the spam-click silent failure.
    visible: true
    width: 320
    height: 56
    radius: 12

    // Start hidden. opacity flips to 1 when triggered, fades back
    // to 0 via Behavior + autoHide.
    opacity: 0

    color: ThemeService.alpha(ThemeService.bg1, 0.95)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.18)

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    property string kind: "volume"        // "volume" | "brightness"
    property real   value01: 0.0          // 0.0 - 1.0 (TARGET value)
    property string label: "Volume"

    // v7.0.0-beta.1-hf31: smooth interpolated value.
    //
    // _animatedValue chases value01 with an animation. Bar width AND
    // percentage text both bind to _animatedValue → both animate
    // smoothly together when volume jumps from e.g. 45% → 50%.
    //
    // Without this, the bar would slide (via Behavior on width) but
    // the percentage text would snap instantly to "50%" — jarring.
    property real   _animatedValue: 0.0
    Behavior on _animatedValue {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    onValue01Changed: _animatedValue = value01

    readonly property string iconGlyph: {
        if (kind === "brightness") return "\uf0eb"  // Nerd Font: lightbulb
        if (kind === "volume" && value01 <= 0.001) return "\uf026"  // muted
        if (kind === "volume" && value01 < 0.5) return "\uf027"     // low
        return "\uf028"                              // full
    }

    // ─────────────────────────────────────────────────────────────
    // ANIMATION (opacity-only — works on every trigger)
    // ─────────────────────────────────────────────────────────────
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // ─────────────────────────────────────────────────────────────
    // AUTO-DISMISS TIMER (1500ms)
    // ─────────────────────────────────────────────────────────────
    Timer {
        id: autoHide
        interval: 1500
        repeat: false
        onTriggered: osd.opacity = 0
    }

    // ─────────────────────────────────────────────────────────────
    // LISTEN for OSD requests
    // ─────────────────────────────────────────────────────────────
    Connections {
        target: NotificationService
        function onOsdRequested(kind, value, label) {
            // v7.0.0-beta.1-hf30: diagnostic — confirms OSD signal
            // actually reaches the popup. If notifications fire but
            // OSD doesn't show, this log will tell us.
            console.log("[OSDPopup] osdRequested kind=" + kind
                      + " value=" + value + " label=" + label)
            osd.kind = kind
            osd.value01 = value
            osd.label = label
            // v7.0.0-beta.1-hf22: opacity-only trigger.
            //
            // Setting opacity to the same value (e.g. already 1) is a
            // no-op for Qt — so we don't need a false→true dance.
            // Each call just sets opacity=1 (re-shows OR keeps showing)
            // and restarts the autoHide timer. Reliable for ANY number
            // of rapid triggers because opacity is a simple real value
            // with no lifecycle gotchas.
            osd.opacity = 1
            autoHide.restart()
        }
    }

    // ─────────────────────────────────────────────────────────────
    // CONTENT
    // ─────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Icon
        Text {
            text: osd.iconGlyph
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            color: ThemeService.blue
            Layout.preferredWidth: 28
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }

        // Progress bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            radius: 3
            color: ThemeService.alpha(ThemeService.fg, 0.12)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // v7.0.0-beta.1-hf31: bind to interpolated value so bar
                // animates smoothly (animation upstream on _animatedValue).
                width: parent.width * osd._animatedValue
                radius: parent.radius
                color: ThemeService.blue
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
                // No need for Behavior on width — _animatedValue already
                // interpolates upstream via Behavior on _animatedValue.
            }
        }

        // Percentage label
        Text {
            // v7.0.0-beta.1-hf31: ticks up/down smoothly with bar
            text: Math.round(osd._animatedValue * 100) + "%"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeService.fg
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
