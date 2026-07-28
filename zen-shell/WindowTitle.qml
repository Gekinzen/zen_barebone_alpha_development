import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: titleRoot

    // v7.0.0-beta.1-hf94: explicit vertical mode. Vertical shows the app
    // icon + the title as ROTATED text (reads bottom-to-top) so it fits
    // the thin bar. Default false → original horizontal pill.
    property bool zenVertical: false

    visible: rawTitle !== ""
    implicitWidth: zenVertical ? Math.round(Theme.moduleHeight) : (visible ? titleRow.implicitWidth + 24 : 0)
    implicitHeight: zenVertical ? (visible ? (vTitleCol.implicitHeight + 16) : 0) : Theme.moduleHeight
    height: implicitHeight
    radius: Theme.styleMode === "round" ? (zenVertical ? width / 2 : height / 2) : Theme.moduleRadius
    color: "transparent"

    property var activeToplevel: {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values) return null
        for (const tl of ToplevelManager.toplevels.values) {
            if (tl.activated) return tl
        }
        return null
    }

    property string rawTitle: activeToplevel ? activeToplevel.title || "" : ""
    property string appClass: activeToplevel ? activeToplevel.appId || "" : ""

    property string displayTitle: {
        if (!rawTitle) return ""
        let t = rawTitle
        t = t.replace(/ — Mozilla Firefox$/, "")
        t = t.replace(/ - Mozilla Firefox$/, "")
        t = t.replace(/ - Visual Studio Code$/, "")
        t = t.replace(/ - Code$/, "")
        t = t.replace(/ - kitty$/, "")
        if (t.length > 50) t = t.substring(0, 47) + "..."
        return t
    }

    property string iconName: {
        const cls = appClass.toLowerCase()
        if (cls.includes("firefox")) return "firefox"
        if (cls.includes("code") || cls.includes("vscode")) return "visual-studio-code"
        if (cls.includes("kitty")) return "kitty"
        if (cls.includes("thunar")) return "thunar"
        return appClass || "application-x-executable"
    }

    RowLayout {
        id: titleRow
        visible: !titleRoot.zenVertical
        anchors.centerIn: parent
        spacing: 6

        Image {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            source: Quickshell.iconPath(titleRoot.iconName, true) || ""
            sourceSize: Qt.size(18, 18)
            visible: source !== ""
        }

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            text: titleRoot.displayTitle
            color: Theme.fg
            elide: Text.ElideRight
            Layout.maximumWidth: 350
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    // v7.0.0-beta.1-hf94.1: vertical title — app icon + a very short,
    // clipped horizontal label underneath. (The earlier rotated-text
    // version risked a layout feedback crash; a plain clipped label is
    // bulletproof. Rotation can return in a later, carefully-tested drop.)
    Column {
        id: vTitleCol
        visible: titleRoot.zenVertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 4

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 20; height: 20
            source: Quickshell.iconPath(titleRoot.iconName, true) || ""
            sourceSize: Qt.size(20, 20)
            visible: source !== ""
        }

        Text {
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(Theme.moduleHeight) - 6
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: {
                let t = titleRoot.displayTitle
                if (t.length > 6) t = t.substring(0, 6)
                return t
            }
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }
    }
}
