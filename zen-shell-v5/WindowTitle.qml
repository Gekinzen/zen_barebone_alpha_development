import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: titleRoot
    visible: rawTitle !== ""
    implicitWidth: visible ? titleRow.implicitWidth + 24 : 0
    height: Theme.moduleHeight
    radius: Theme.styleMode === "round" ? height / 2 : Theme.moduleRadius
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
            text: titleRoot.displayTitle
            color: Theme.fg
            elide: Text.ElideRight
            Layout.maximumWidth: 350
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
