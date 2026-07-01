import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Effects
import SddmComponents 2.0

/*
 * Zen Tokyo — SDDM greeter (v7.0.0-beta.1-hf95.10, Karui)
 *
 * A faithful replica of the Zen Shell hyprlock screen
 * (hyprlock.conf v6.16.3.2.1), extended with the bits a login
 * greeter needs that a lock screen doesn't:
 *   - mouse cursor (lock hides it; greeter shows it)
 *   - user selector (multi-user)
 *   - session selector + power controls
 *
 * Design parity with hyprlock:
 *   - live wallpaper, blurred + darkened (here via MultiEffect, since
 *     SDDM can't run hyprlock's native blur)
 *   - huge centred clock in the configured clock font
 *   - mood + care lines under the clock (optional)
 *   - pill-shaped password input, Tokyo-Night colours
 *
 * Everything visual reads from theme.conf via config.*, so the sync
 * hook can retheme it to match your desktop. Qt6 (QtQuick.Effects /
 * MultiEffect is Qt 6.5+, which current Arch/CachyOS ships).
 */
Rectangle {
    id: root
    width: 1920; height: 1080
    color: config.colorBackground || "#16161e"

    // ── Config helpers ──
    readonly property color cBg:      config.colorBackground || "#16161e"
    readonly property color cSurface: config.colorSurface    || "#24283b"
    readonly property color cText:    config.colorText       || "#dce2f8"
    readonly property color cDim:     config.colorTextDim     || "#94a3c2"
    readonly property color cAccent:  config.colorAccent      || "#7aa2f7"
    readonly property color cAccentT: config.colorAccentText  || "#16161e"
    readonly property color cOk:      config.colorSuccess     || "#9ece6a"
    readonly property color cErr:     config.colorError       || "#f7768e"
    readonly property color cBorder:  config.colorBorder      || "#3b4261"
    readonly property string clockFont: config.clockFont || "Adwaita Sans Black"
    readonly property string textFont:  config.textFont  || "Adwaita Sans"
    // v7.0.0-beta.1-hf95.12: the widget clock (DesktopWidgets) renders
    // `font.family: "Adwaita Sans"` + `font.weight: Font.Black`. A
    // weight-SUFFIXED family name like "Adwaita Sans Black" often fails to
    // resolve as a Qt family and silently falls back to a default font —
    // which is why the greeter clock didn't match. Strip a trailing weight
    // word and apply the weight via font.weight instead, exactly like the
    // widget. Mapping mirrors the weights zen-sddm-sync.sh emits.
    readonly property var _weightWords: ["Black","Heavy","ExtraBold","Extra Bold",
                                         "DemiBold","SemiBold","Bold","Medium","Light"]
    readonly property string clockFontFamily: {
        var f = clockFont
        for (var i = 0; i < _weightWords.length; i++) {
            var suffix = " " + _weightWords[i]
            if (f.length > suffix.length && f.slice(-suffix.length) === suffix)
                return f.slice(0, f.length - suffix.length)
        }
        return f
    }
    readonly property int clockFontWeight: {
        var f = clockFont
        if (f.indexOf("Black") >= 0 || f.indexOf("Heavy") >= 0) return Font.Black
        if (f.indexOf("ExtraBold") >= 0 || f.indexOf("Extra Bold") >= 0) return Font.ExtraBold
        if (f.indexOf("Bold") >= 0) return Font.Bold
        if (f.indexOf("Medium") >= 0) return Font.Medium
        if (f.indexOf("Light") >= 0) return Font.Light
        return Font.Black   // default matches the widget
    }

    property int sessionIndex: sessionModel.lastIndex
    property string errorText: ""
    // Selected username — kept as a plain string updated by the user
    // ListView's currentItem, so we never depend on fragile
    // Qt.UserRole+N indexing (which varies across SDDM/Qt versions and
    // would otherwise render blank). Seeded to the last user below.
    property string selectedUser: ""
    // hf95.12: the selected user's avatar path (SDDM `icon` role). Tracked
    // alongside selectedUser so the big avatar shows their profile image.
    property string selectedUserIcon: ""

    // ════════════════════════════════════════════════════════════
    // BACKGROUND — live wallpaper, blurred + darkened
    // ════════════════════════════════════════════════════════════
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background || "backgrounds/current"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false   // shown through the blur effect below
    }
    // hf95.12: "matugen" mode → flat scheme colour, no wallpaper/blur.
    readonly property bool useWallpaper: (config.backgroundMode || "wallpaper") !== "matugen"
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: Number(config.blurRadius) || 64
        visible: root.useWallpaper && wallpaper.status === Image.Ready
    }
    // Flat fallback if the wallpaper is missing OR matugen mode is on.
    Rectangle {
        anchors.fill: parent
        color: root.cBg
        visible: !root.useWallpaper || wallpaper.status !== Image.Ready
    }
    // Darkening overlay (only meaningful over a wallpaper)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: Number(config.dimOpacity) || 0.45
        visible: root.useWallpaper
    }
    // Subtle vignette for vaxry-style readability
    Rectangle {
        anchors.fill: parent
        visible: config.vignette !== "false"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#66000000" }
        }
    }

    // ════════════════════════════════════════════════════════════
    // TOP BARS — keyboard layout (left), connectivity (right)
    // ════════════════════════════════════════════════════════════
    Row {
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: 18
        spacing: 7
        visible: config.showKeyboardLayout !== "false"
        Text {
            text: keyboard.layouts.length > 0
                  ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase()
                  : "EN"
            color: root.cDim; font.family: root.textFont; font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ════════════════════════════════════════════════════════════
    // CENTRE COLUMN — clock, greeting, avatar, user chips, password
    // ════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0
        width: Math.min(parent.width * 0.9, 720)

        // ── Big clock ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: config.showClock !== "false"
            text: Qt.formatTime(timeSource.now, config.clockFormat || "HH:mm")
            color: Qt.rgba(1,1,1,0.97)
            font.family: root.clockFontFamily
            font.pixelSize: Number(config.clockPixelSize) || 152
            font.weight: root.clockFontWeight
        }

        // ── Greeting (computed live from hour) ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            visible: config.showGreeting !== "false"
            text: root.greeting()
            color: Qt.rgba(0.86, 0.886, 0.97, 0.92)
            font.family: root.textFont; font.pixelSize: 20
        }

        // ── Optional mood line ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            visible: root.moodLine.length > 0
            text: root.moodLine
            color: Qt.rgba(0.71, 0.75, 0.86, 0.82)
            font.family: root.textFont; font.pixelSize: 14
        }

        // ── User avatar ──
        // hf95.12: show the user's profile image (same source the start
        // menu uses — SDDM exposes it via the model `icon` role, which
        // reads /var/lib/AccountsService/icons + /usr/share/sddm/faces;
        // the sync hook also publishes the zen-shell custom avatar there).
        // Falls back to the letter initial if no image.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 30
            width: 72; height: 72; radius: 36
            color: root.cSurface
            border.color: root.cAccent; border.width: 2
            clip: true

            Image {
                id: avatarImg
                anchors.fill: parent
                anchors.margins: 2
                source: root.selectedUserIcon
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true; asynchronous: true; cache: false
                sourceSize: Qt.size(140, 140)
                visible: false
            }
            Rectangle {
                id: avatarMask
                anchors.fill: avatarImg
                radius: width / 2
                visible: false
            }
            // Circular avatar via OpacityMask (same technique as the
            // start menu), shown only when an image actually loaded.
            MultiEffect {
                anchors.fill: avatarImg
                source: avatarImg
                maskEnabled: true
                maskSource: avatarMask
                visible: avatarImg.status === Image.Ready
                         && root.selectedUserIcon.length > 0
            }
            // Letter fallback when there's no profile image.
            Text {
                anchors.centerIn: parent
                visible: !(avatarImg.status === Image.Ready
                           && root.selectedUserIcon.length > 0)
                text: root.currentUserInitial()
                color: root.cAccent
                font.family: root.textFont; font.pixelSize: 26; font.weight: Font.Medium
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            text: root.selectedUser
            color: root.cText
            font.family: root.textFont; font.pixelSize: 15; font.weight: Font.Medium
        }

        // ── User selector chips ──
        ListView {
            id: userList
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.preferredHeight: 36
            Layout.preferredWidth: Math.min(contentWidth, root.width * 0.85)
            visible: config.showUserSelector !== "false" && userModel.count > 1
            orientation: ListView.Horizontal
            spacing: 10
            clip: true
            model: userModel
            currentIndex: userModel.lastIndex
            onCurrentIndexChanged: {
                if (currentItem && currentItem.userName !== undefined)
                    root.selectedUser = currentItem.userName
                if (currentItem && currentItem.userIcon !== undefined)
                    root.selectedUserIcon = currentItem.userIcon
            }

            delegate: Rectangle {
                height: 34
                width: chipRow.implicitWidth + 22
                radius: 17
                property string userName: model.name
                property string userIcon: (model.icon !== undefined && model.icon)
                                          ? ("" + model.icon) : ""
                color: userList.currentIndex === index
                       ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                       : Qt.rgba(1,1,1,0.04)
                border.width: 1
                border.color: userList.currentIndex === index
                              ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45)
                              : Qt.rgba(1,1,1,0.10)
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: userList.currentIndex === index ? root.cAccent : root.cSurface
                        Text {
                            anchors.centerIn: parent
                            text: (model.name || "?").charAt(0).toUpperCase()
                            color: userList.currentIndex === index ? root.cAccentT : root.cDim
                            font.family: root.textFont; font.pixelSize: 11; font.weight: Font.Medium
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.name
                        color: userList.currentIndex === index ? root.cText : root.cDim
                        font.family: root.textFont; font.pixelSize: 12
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { userList.currentIndex = index; passwordField.forceActiveFocus() }
                }
            }
        }

        // ── Pill password input ──
        Rectangle {
            id: pwPill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 26
            width: 360; height: 56; radius: 28
            color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.72)
            border.width: 2
            border.color: root.errorText.length > 0 ? root.cErr : root.cAccent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20; anchors.rightMargin: 8
                spacing: 9

                TextInput {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.cText
                    font.family: root.textFont; font.pixelSize: 16
                    clip: true
                    focus: true
                    onAccepted: root.doLogin()
                    onTextChanged: root.errorText = ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordField.text.length === 0
                        text: root.errorText.length > 0 ? root.errorText : "Input password"
                        color: root.errorText.length > 0 ? root.cErr : root.cDim
                        font.family: root.textFont; font.pixelSize: 13; font.italic: true
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 40; height: 40; radius: 20
                    color: root.cAccent
                    Text {
                        anchors.centerIn: parent
                        text: "\u2192"   // arrow
                        color: root.cAccentT
                        font.pixelSize: 20; font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doLogin()
                    }
                }
            }
        }

        // ── Caps lock indicator ──
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            visible: keyboard.capsLock
            text: "\u21ea CAPS LOCK"
            color: Qt.rgba(root.cErr.r, root.cErr.g, root.cErr.b, 0.85)
            font.family: root.textFont; font.pixelSize: 14
        }
    }

    // ════════════════════════════════════════════════════════════
    // BOTTOM BAR — session selector + power controls
    // ════════════════════════════════════════════════════════════
    Item {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 54

        Rectangle { anchors.fill: parent; color: "#8c101019" }

        // Session selector
        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: config.showSessionSelector !== "false"
            height: 36; width: sessRow.implicitWidth + 26; radius: 8
            color: Qt.rgba(1,1,1,0.05)
            Row {
                id: sessRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        var v = sessionModel.data(sessionModel.index(root.sessionIndex,0), Qt.UserRole + 4)
                        return (v && v.length > 0) ? v : "Session"
                    }
                    color: root.cText; font.family: root.textFont; font.pixelSize: 13
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u25be"; color: root.cDim; font.pixelSize: 12
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.count)
            }
        }

        // Power controls
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: config.showPowerControls !== "false"
            spacing: 6

            Rectangle {
                width: 38; height: 38; radius: 8
                color: Qt.rgba(1,1,1,0.05)
                Text { anchors.centerIn: parent; text: "\u23fb"; color: root.cDim; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.suspend() }
            }
            Rectangle {
                width: 38; height: 38; radius: 8
                color: Qt.rgba(1,1,1,0.05)
                Text { anchors.centerIn: parent; text: "\u21bb"; color: root.cDim; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.reboot() }
            }
            Rectangle {
                width: 38; height: 38; radius: 8
                color: Qt.rgba(root.cErr.r, root.cErr.g, root.cErr.b, 0.14)
                Text { anchors.centerIn: parent; text: "\u23fb"; color: root.cErr; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.powerOff() }
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // LOGIC
    // ════════════════════════════════════════════════════════════
    QtObject {
        id: timeSource
        property var now: new Date()
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: timeSource.now = new Date()
    }

    property string moodLine: ""
    Component.onCompleted: {
        // Seed selected user (covers the single-user case where the
        // chip ListView is hidden and never fires onCurrentIndexChanged).
        if (root.selectedUser.length === 0 && userModel.count > 0) {
            var idx = userModel.lastIndex
            root.selectedUser = userModel.data(userModel.index(idx, 0), Qt.UserRole + 1) || ""
            var ic = userModel.data(userModel.index(idx, 0), Qt.UserRole + 4)
            root.selectedUserIcon = ic ? ("" + ic) : ""
        }
        // Optional mood/care line exported by the sync hook.
        if (config.moodCareFile && config.moodCareFile.length > 0) {
            var xhr = new XMLHttpRequest()
            try {
                xhr.open("GET", config.moodCareFile, false)
                xhr.send(null)
                if (xhr.status === 200 || xhr.status === 0)
                    root.moodLine = (xhr.responseText || "").trim()
            } catch (e) { root.moodLine = "" }
        }
        passwordField.forceActiveFocus()
    }

    function greeting() {
        var h = timeSource.now.getHours()
        var part = (h >= 5 && h < 12)  ? "Good morning"
                 : (h >= 12 && h < 17) ? "Good afternoon"
                 : (h >= 17 && h < 22) ? "Good evening"
                 :                       "Working late"
        return root.selectedUser.length > 0 ? part + ", " + root.selectedUser : part
    }

    function currentUserInitial() {
        return root.selectedUser.length > 0
               ? root.selectedUser.charAt(0).toUpperCase() : "?"
    }

    function doLogin() {
        if (root.selectedUser.length === 0) {
            root.errorText = "No user selected"
            return
        }
        sddm.login(root.selectedUser, passwordField.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { root.errorText = "" }
        function onLoginFailed() {
            root.errorText = "Incorrect password"
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }
}
