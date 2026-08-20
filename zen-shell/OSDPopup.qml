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

    color: LookService.surfaceColor(ThemeService.bg1, 0.95)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.18)

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────
    property string kind: "volume"        // "volume" | "brightness"
    // hf198 — value01 is the TRUE fraction (volume/100). Since the boost
    // it can exceed 1.0 (up to maxVolume/100 = 3.0 for volume). The BAR
    // maps it against the ceiling below; the LABEL shows the true percent
    // — 250% reads "250%" over a ~83%-full bar, not a full bar at "100%".
    property real   value01: 0.0
    property string label: "Volume"

    // Ceiling for the raw value: 3.0 for volume (boost), 1.0 otherwise.
    readonly property real _ceil:
        (kind === "volume" && typeof ConnectivityService !== "undefined")
        ? ConnectivityService.maxVolume / 100 : 1.0
    // Bar fraction — hf201: 100% FILLS the bar. The hf198 mapping
    // (fraction of the 300% ceiling) was mathematically honest and
    // perceptually broken: at everyday 100% the bar sat one-third full
    // and read as a bug ("mali padin yun sa notification"). Now:
    //   0–100%   → bar fills 0→100, normal accent
    //   past 100 → bar STAYS full; the fill walks the yellow→orange→red
    //              gradient and the label shows the true percent — the
    //              COLOR is the boost meter, the bar is the safe meter.
    readonly property real _barFrac: Math.max(0, Math.min(1, _animatedValue))
    // True percent for the label + the warning-gradient lookup.
    readonly property int  _pct: Math.round(_animatedValue * 100)
    // hf198 — bar/label color: shared boost gradient past 100%
    // (yellow → orange → red via ConnectivityService.volumeColor).
    readonly property color _fillColor:
        (kind === "volume" && typeof ConnectivityService !== "undefined"
         && _pct > 100)
        ? ConnectivityService.volumeColor(_pct)
        : ThemeService.blue

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
            // v8: no backlight (desktop / external monitor) — suppress the
            // brightness OSD entirely so scroll-to-brightness shows nothing.
            if (kind === "brightness" && !BrightnessService.available) return
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
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
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
                // hf201: 100% fills the bar; boosted values keep it full
                // and the gradient fill + true-percent label carry the rest.
                width: parent.width * osd._barFrac
                radius: parent.radius
                color: osd._fillColor
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
                // No need for Behavior on width — _animatedValue already
                // interpolates upstream via Behavior on _animatedValue.
            }
        }

        // Percentage label
        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            // hf198: TRUE percent — reads "250%" while boosted, and the
            // text picks up the same warning gradient as the bar.
            text: osd._pct + "%"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: osd._pct > 100 ? osd._fillColor : ThemeService.fg
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
