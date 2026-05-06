import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * MusicStrings v6.15.2
 *
 * Drop-in replacement for MusicWidget in the bar slot.
 * Loaded by Bar.qml when ZenStringsState.enabled = true.
 *
 * This component:
 *   - Normally INVISIBLE (transparent placeholder in the bar slot)
 *   - Polls playerctl for play state + track metadata
 *   - Runs cava for beat data
 *   - Reports its screen position to ZenStringsState so the
 *     dedicated overlay PanelWindow in shell.qml can position
 *     the ZenStrings visual correctly
 *   - Shows a PopupWindow tooltip on hover (same as SysRowIcon)
 *
 * v6.15.2: Adds a "Loading..." placeholder that is visible only while
 *   ZenStringsState.positionReady = false (i.e. during login, before the
 *   overlay's stability timer confirms the slot position has settled).
 *   The placeholder lives INSIDE the bar's RowLayout, so it is always
 *   rendered at the correct position — RowLayout handles its own
 *   children's layout natively. Once positionReady flips to true, the
 *   placeholder fades out and the ZenStrings overlay fades in on top.
 *
 * The actual ZenStrings visual lives in shell.qml as a separate
 * WlrLayer.Top PanelWindow — so it floats freely above AND below the
 * bar with no clipping, regardless of curveHeight.
 */
Item {
    id: root

    implicitWidth: ZenStringsState.stringLength > 0
        ? ZenStringsState.stringLength
        : 200
    implicitHeight: parent ? parent.height : 40

    // ── Track state ──
    property bool mediaPlaying: false
    property string trackArtist: ""
    property string trackTitle: ""
    property string playerName: ""

    property string trackInfo: {
        if (trackArtist && trackTitle) return trackArtist + " — " + trackTitle
        if (trackTitle)                return trackTitle
        if (trackArtist)               return trackArtist
        if (cavaHasAudio && !mediaPlaying) return "♪ System Audio"
        return ""
    }

    // ── Cava state (shared to ZenStringsState for the overlay) ──
    property bool cavaAvailable: false
    property var cavaData: []

    // v6.15.1: Detect audio from cava output, not just MPRIS.
    // Steam/Proton games, Wine apps, and native players that don't
    // register MPRIS won't show up in `playerctl status` — but cava
    // still picks up their audio from PipeWire/PulseAudio monitor.
    // If any cava bar value > 0.01, audio is playing.
    readonly property bool cavaHasAudio: {
        if (!cavaData || cavaData.length === 0) return false
        for (var i = 0; i < cavaData.length; i++) {
            if (cavaData[i] > 0.01) return true
        }
        return false
    }

    // Audio is active if EITHER playerctl says playing OR cava detects sound
    readonly property bool isAudioActive: (mediaPlaying || cavaHasAudio) && cavaAvailable

    // ── Sync state to ZenStringsState so stringsWindow can read it ──
    onIsAudioActiveChanged: ZenStringsState.isAudioActive = isAudioActive
    onCavaDataChanged:      ZenStringsState.cavaData      = cavaData
    onTrackInfoChanged:     ZenStringsState.trackInfo     = trackInfo
    onMediaPlayingChanged:  ZenStringsState.mediaPlaying  = mediaPlaying
    onCavaHasAudioChanged:  ZenStringsState.cavaHasAudio  = cavaHasAudio


    // ── Poll playerctl every 2s ──
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statusProc.running = true; metadataProc.running = true }
    }

    Process {
        id: statusProc; running: false
        command: ["bash", "-c", "playerctl status 2>/dev/null || echo Stopped"]
        stdout: SplitParser {
            onRead: data => { root.mediaPlaying = (data.trim() === "Playing") }
        }
    }

    Process {
        id: metadataProc; running: false
        command: ["bash", "-c",
            "playerctl metadata --format '{{artist}}|||{{title}}|||{{playerName}}' 2>/dev/null || echo '|||'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|||")
                root.trackArtist = (parts[0] || "").trim()
                root.trackTitle  = (parts[1] || "").trim()
                var pn = (parts[2] || "").trim()
                root.playerName = pn.length > 0
                    ? pn.charAt(0).toUpperCase() + pn.slice(1) : ""
            }
        }
    }

    // ── Cava ──
    Process {
        id: cavaCheck; running: true
        command: ["bash", "-c", "command -v cava >/dev/null 2>&1 && echo yes || echo no"]
        stdout: SplitParser {
            onRead: data => {
                root.cavaAvailable = (data.trim() === "yes")
                if (root.cavaAvailable) cavaStartTimer.restart()
            }
        }
    }

    Timer { id: cavaStartTimer; interval: 300; repeat: false
        onTriggered: cavaProc.running = true }

    Process {
        id: cavaProc; running: false
        command: [Quickshell.env("HOME") + "/.local/bin/zen-cava.sh",
                  "" + ZenStringsState.segments]
        stdout: SplitParser {
            onRead: data => {
                var bars = data.split(";"); bars.pop()
                root.cavaData = bars.map(b => parseFloat(b) / 1000)
            }
        }
        onExited: { if (root.cavaAvailable) cavaStartTimer.restart() }
    }

    Connections {
        target: ZenStringsState
        function onSegmentsChanged() {
            cavaProc.running = false
            if (root.cavaAvailable) cavaStartTimer.restart()
        }
    }

    // ── v6.15.2: Loading placeholder ──
    // Visible only when the stringsWindow overlay hasn't confirmed a
    // stable position yet. Because this Item lives inside the bar's
    // RowLayout, it's always rendered at the correct slot position —
    // so we get a "Loading…" indicator exactly where the strings will
    // appear a moment later. Cross-fades with the overlay via
    // ZenStringsState.positionReady.
    Item {
        id: loadingPlaceholder
        anchors.fill: parent
        opacity: ZenStringsState.positionReady ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        Row {
            id: loadingRow
            anchors.centerIn: parent
            spacing: 8

            // Soft pulsing dot — looks like something is "tuning in"
            Rectangle {
                id: loadingDot
                width: 8; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: ThemeService.alpha(ThemeService.fg, 0.55)

                SequentialAnimation on opacity {
                    running: loadingPlaceholder.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                id: loadingText
                text: "Loading…"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                font.italic: true
                color: ThemeService.alpha(ThemeService.fg, 0.65)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Hover detect ──
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ── Tooltip — same PopupWindow pattern as SysRowIcon ──
    // v6.16.4.12.7.1: 4-direction-aware popup edges.
    PopupWindow {
        id: tipPopup
        anchor.item: root
        anchor.edges: PanelState.popupAnchorEdges
        anchor.gravity: PanelState.popupAnchorGravity
        visible: hoverArea.containsMouse && root.trackInfo.length > 0
        width: tipText.implicitWidth + tipDot.width + tipRow.spacing + 28
        height: tipRow.implicitHeight + 18
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.95)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

            Row {
                id: tipRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    id: tipDot
                    width: 7; height: 7; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.mediaPlaying ? ThemeService.green
                         : root.cavaHasAudio ? ThemeService.orange
                         : ThemeService.grey1
                }

                Text {
                    id: tipText
                    text: root.trackInfo
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
