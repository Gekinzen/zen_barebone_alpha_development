import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/*
 * TitleTranslatorModule v7.0.0-beta.1-hf39 — Karui (軽い)
 *
 * Bar widget for Title Translator. Shows a small flag icon for the
 * detected language of the active window title, OR a globe icon if
 * no foreign title currently detected. Hover → translation tooltip.
 * Click → translate now (if not auto). Right-click → Settings.
 */
Item {
    id: tm

    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight
    visible: TitleTranslatorService.enabled

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: 2
        radius: 6
        color: ma.containsMouse
               ? ThemeService.alpha(ThemeService.fg, 0.10)
               : "transparent"
        border.color: ma.containsMouse
                      ? ThemeService.alpha(ThemeService.fg, 0.15)
                      : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Pulse when new foreign title detected (rare but visible cue)
    SequentialAnimation {
        id: pulseAnim
        running: false
        loops: 1
        NumberAnimation { target: bg; property: "scale"; from: 1.0; to: 1.18; duration: 150 }
        NumberAnimation { target: bg; property: "scale"; from: 1.18; to: 1.0; duration: 200 }
    }
    Connections {
        target: TitleTranslatorService
        function onCurrentLangChanged() {
            if (TitleTranslatorService.currentLang) pulseAnim.start()
        }
    }

    Text {
        style: LookService.isClear ? Text.Outline : Text.Normal
        styleColor: LookService.clearTextOutline
        anchors.centerIn: parent
        text: {
            const lang = TitleTranslatorService.currentLang
            if (!lang) return "\uf0ac"   // globe (no foreign title)
            // Use generic translate icon when active
            return "\uf1ab"   // language icon
        }
        font.family: Theme.iconFontFamily
        font.pixelSize: 13
        color: TitleTranslatorService.currentLang
               ? ThemeService.blue
               : ThemeService.alpha(ThemeService.fg, 0.5)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Lang code badge (bottom-right)
    Rectangle {
        visible: TitleTranslatorService.currentLang.length > 0
        width: langText.implicitWidth + 4
        height: 10
        radius: 5
        color: ThemeService.alpha(ThemeService.blue, 0.9)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 1
        anchors.bottomMargin: 1

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            id: langText
            anchors.centerIn: parent
            text: TitleTranslatorService.currentLang.toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: 7
            font.weight: Font.Bold
            color: "white"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelState.openSettingsPage("titletranslator")
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                // Middle-click → inline LibreTranslate API attempt
                // (for users who actually configured a working backend)
                if (TitleTranslatorService.currentLang) {
                    TitleTranslatorService.translateCurrent()
                }
                return
            }
            // Left-click — v7.0.0-beta.1-hf45 — opens Google Translate
            // sa browser with the current title pre-filled. Most
            // reliable UX (no API key, no rate limit, full translation
            // page with examples). Requires xdg-open which all desktop
            // Linux installs have.
            if (TitleTranslatorService.currentLang
                && TitleTranslatorService.currentTitle) {
                TitleTranslatorService.translateInBrowser()
            }
        }
    }

    // Tooltip with translation
    Rectangle {
        visible: ma.containsMouse && TitleTranslatorService.currentLang
        z: 100
        radius: 6
        color: LookService.surfaceColor(ThemeService.bg1, 0.97)
        border.color: ThemeService.alpha(ThemeService.fg, 0.2)
        border.width: 1
        width: Math.max(180, ttCol.implicitWidth + 16)
        height: ttCol.implicitHeight + 12
        anchors.top: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 4

        ColumnLayout {
            id: ttCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 6
            spacing: 2

            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                Layout.fillWidth: true
                text: TitleTranslatorService.langLabel(TitleTranslatorService.currentLang)
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                color: ThemeService.alpha(ThemeService.fg, 0.6)
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                Layout.fillWidth: true
                text: TitleTranslatorService.currentTitle
                font.family: Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                color: ThemeService.fg
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ThemeService.alpha(ThemeService.fg, 0.15)
                visible: TitleTranslatorService.currentTranslation.length > 0
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                Layout.fillWidth: true
                text: TitleTranslatorService.currentTranslation
                      || (TitleTranslatorService.autoTranslate
                          ? "Translating…"
                          : "Left-click: open in browser  ·  Middle-click: inline API")
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.italic: !TitleTranslatorService.currentTranslation
                color: TitleTranslatorService.currentTranslation
                       ? ThemeService.blue
                       : ThemeService.alpha(ThemeService.fg, 0.55)
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
