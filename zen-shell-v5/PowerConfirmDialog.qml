import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * PowerConfirmDialog — confirm overlay for shutdown / restart / suspend /
 * logout / lock with auto-execute countdown.
 *
 * ── v6.16.3.1 changes (Material Design icons + theme-synced palette) ──
 *
 *   1. Action icons swapped from FontAwesome to Material Design Icons
 *      (Nerd Font nf-md range). Visually matches Google Material Symbols
 *      while keeping our existing JetBrains Mono Nerd Font dependency —
 *      no new font installed, no bootstrap.sh change.
 *
 *      Codepoints used (above-BMP, written as UTF-16 surrogate pairs to
 *      match the codebase's "\uXXXX" escape convention):
 *
 *        shutdown  = U+F0425  nf-md-power
 *        reboot    = U+F0709  nf-md-restart
 *        suspend   = U+F0904  nf-md-power_sleep   (NEW — additive)
 *        logout    = U+F0343  nf-md-logout        (also fixes pre-3.1 bug,
 *                                                  see point 3 below)
 *        lock      = U+F033E  nf-md-lock
 *        warning   = U+F0028  nf-md-alert_circle  (default fallback)
 *        clock     = U+F0150  nf-md-clock_outline (countdown chip)
 *        cancel    = U+F0156  nf-md-close
 *        confirm   = U+F012C  nf-md-check
 *
 *   2. Theme-synced colors: the existing Theme.{red,orange,yellow,blue}
 *      tokens are already palette-pulled — they're rewritten on every
 *      Theme.applyScheme() call from the active scheme JSON. Kept as-is
 *      so each action keeps its semantic accent (red=destructive,
 *      orange=disruptive, yellow=session-end, blue=safe), but the EXACT
 *      hex now follows whatever theme the user picked. Wala tayong
 *      babawasan — same color slots, just sourced cleanly.
 *
 *   3. Suspend support: added an additional case in actionInfo. Caller
 *      can now pass `action: "suspend"` and the dialog renders correctly.
 *      No existing caller invokes this yet (StartMenuPanel power buttons
 *      stay shutdown/reboot/logout/lock for now), so this is a pure
 *      forward-compat addition for whichever v6.16.3.X item wires the
 *      Start Menu suspend button.
 *
 *   4. Bug fix: the pre-3.1 logout glyph literal "\uf0343" was a JS
 *      string-escape malformity — \u takes exactly 4 hex digits, so it
 *      was being parsed as "\uf034" + literal "3". The icon rendered as
 *      the FontAwesome text-height glyph followed by a stray "3". Now
 *      uses a proper surrogate pair for U+F0343.
 *
 * Public API (unchanged from v6.16.2.x):
 *   property string action      // "shutdown" | "reboot" | "suspend" |
 *                               //   "logout" | "lock"
 *   property string command     // bash -c command to execute on confirm
 *   property int    countdown   // seconds before auto-execute (default 60)
 *   signal confirmed()
 *   signal cancelled()
 *   function executeAction()
 *   function cancel()
 */

Rectangle {
    id: dialogRoot
    radius: 20
    color: ThemeService.alpha(ThemeService.bg0, 0.97)
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.15)

    property string action: ""      // "shutdown" | "reboot" | "suspend" | "logout" | "lock"
    property string command: ""
    property int countdown: 60

    signal confirmed()
    signal cancelled()

    // ── Action metadata ──
    // Icon glyphs are Nerd Font Material Design Icons (nf-md-*). Colors
    // pull from Theme.* tokens which are repopulated from the active
    // scheme JSON via Theme.applyScheme(), so the palette follows
    // whatever theme the user has selected.
    readonly property var actionInfo: {
        switch(action) {
            case "shutdown":
                return { icon:    "\udb81\udc25",                     // nf-md-power
                         title:   "Shutdown",
                         color:   ThemeService.red,
                         subtitle:"System will power off" }
            case "reboot":
                return { icon:    "\udb81\udf09",                     // nf-md-restart
                         title:   "Restart",
                         color:   ThemeService.orange,
                         subtitle:"System will reboot" }
            case "suspend":
                return { icon:    "\udb82\udd04",                     // nf-md-power_sleep
                         title:   "Suspend",
                         color:   ThemeService.purple,
                         subtitle:"System will sleep" }
            case "logout":
                return { icon:    "\udb80\udf43",                     // nf-md-logout
                         title:   "Logout",
                         color:   ThemeService.yellow,
                         subtitle:"Exit Hyprland session" }
            case "lock":
                return { icon:    "\udb80\udf3e",                     // nf-md-lock
                         title:   "Lock",
                         color:   ThemeService.blue,
                         subtitle:"Lock the screen" }
        }
        return { icon:    "\udb80\udc28",                             // nf-md-alert_circle
                 title:   "Action",
                 color:   ThemeService.fg,
                 subtitle:"" }
    }

    // ── Countdown timer ──
    Timer {
        id: countdownTimer
        interval: 1000
        running: dialogRoot.visible   // hf65 — only run when actually visible
        repeat: true
        onTriggered: {
            if (dialogRoot.countdown > 0) {
                dialogRoot.countdown--
            } else {
                running = false
                dialogRoot.executeAction()
            }
        }
    }

    // hf65 — safety: reset countdown when dialog appears, stop when hidden.
    // Prevents stale countdown from a previously-cancelled action carrying
    // over to the next power dialog invocation.
    onVisibleChanged: {
        if (visible) {
            countdown = 60
            countdownTimer.running = true
        } else {
            countdownTimer.running = false
        }
    }

    function executeAction() {
        countdownTimer.running = false
        if (command) {
            Quickshell.execDetached({command: ["bash", "-c", command]})
        }
        confirmed()
    }

    function cancel() {
        countdownTimer.running = false
        cancelled()
    }

    // Keyboard: Enter = confirm, Escape = cancel
    Keys.onEscapePressed: cancel()
    Keys.onReturnPressed: executeAction()
    Keys.onEnterPressed: executeAction()
    focus: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 20

        // ── Action icon (Material Design, theme-tinted halo) ──
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            radius: 48
            color: ThemeService.alpha(dialogRoot.actionInfo.color, 0.15)
            border.width: 2
            border.color: dialogRoot.actionInfo.color

            Text {
                anchors.centerIn: parent
                text: dialogRoot.actionInfo.icon
                color: dialogRoot.actionInfo.color
                font.family: Theme.monoFont
                font.pixelSize: 48                  // bumped from 42 → 48,
                                                    // MDI glyphs read smaller
                                                    // than FA at the same px
                                                    // size. Visually balances
                                                    // the 96px halo.
            }
        }

        // ── Title ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: dialogRoot.actionInfo.title
            color: ThemeService.fg
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.bold: true
        }

        // ── Subtitle ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: dialogRoot.actionInfo.subtitle
            color: ThemeService.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        // ── Countdown chip ──
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 44
            radius: 22
            color: ThemeService.alpha(dialogRoot.actionInfo.color, 0.12)
            border.width: 1
            border.color: ThemeService.alpha(dialogRoot.actionInfo.color, 0.3)

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "\udb80\udd50"            // nf-md-clock_outline
                    color: dialogRoot.actionInfo.color
                    font.family: Theme.monoFont
                    font.pixelSize: 16              // MDI sizing tweak
                }
                Text {
                    text: "Auto in " + dialogRoot.countdown + "s"
                    color: dialogRoot.actionInfo.color
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        // ── Progress bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: ThemeService.alpha(ThemeService.fg, 0.1)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (dialogRoot.countdown / 60)
                radius: 2
                color: dialogRoot.actionInfo.color
                Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 12 }

        // ── Buttons ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Cancel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: cancelMa.containsMouse ? ThemeService.bg2 : ThemeService.bg1
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "\udb80\udd56"        // nf-md-close
                        color: ThemeService.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 16
                    }
                    Text {
                        text: "Cancel"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: "Esc"
                        color: ThemeService.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialogRoot.cancel()
                }
            }

            // Confirm
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: confirmMa.containsMouse
                    ? dialogRoot.actionInfo.color
                    : ThemeService.alpha(dialogRoot.actionInfo.color, 0.75)
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "\udb80\udd2c"        // nf-md-check
                        color: ThemeService.bg0
                        font.family: Theme.monoFont
                        font.pixelSize: 16
                    }
                    Text {
                        text: "Confirm now"
                        color: ThemeService.bg0
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: "Enter"
                        color: Qt.rgba(0, 0, 0, 0.4)
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: confirmMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialogRoot.executeAction()
                }
            }
        }
    }
}
