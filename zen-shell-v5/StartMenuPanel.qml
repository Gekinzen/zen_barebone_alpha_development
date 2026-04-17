import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Rectangle {
    id: menuRoot

    // v6.4: honor style mode for radius (rounded/pill) + bind bg to
    // ThemeService so theme changes repaint live. Border also uses
    // ThemeService.fg so selected theme affects outline.
    radius: (PanelState.propagateStyleToModules && Theme.styleMode === "round")
            ? 22
            : 16
    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.92)
    border.width: 1
    border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)
    clip: true

    signal closeRequested()
    signal appLaunched()
    signal powerActionRequested(string action, string command)

    readonly property string nfPin: "\uf0403"
    readonly property string nfUser: "\uf007"
    readonly property string nfFolder: "\uf024b"
    readonly property string nfSettings: "\uf013"
    readonly property string nfPower: "\u23fb"
    readonly property string nfSearch: "\uf002"

    property var allApps: []
    property var pinnedAppIds: ["kitty", "firefox", "code", "thunar", "steam"]
    property string searchQuery: ""
    property bool appsLoaded: false
    property bool powerMenuOpen: false

    Component.onCompleted: {
        loadApps()
        loadPinnedApps()
    }

    // ── Smart app loading from DesktopEntries ──
    function loadApps() {
        try {
            const entries = DesktopEntries.applications.values
            if (entries && entries.length > 0) {
                const apps = []
                for (const entry of entries) {
                    apps.push({
                        id: entry.id || "",
                        name: entry.name || "",
                        icon: entry.icon || "",
                        entry: entry
                    })
                }
                apps.sort((a, b) => a.name.localeCompare(b.name))
                allApps = apps
                appsLoaded = true
                console.log("[StartMenu] Loaded", apps.length, "apps from DesktopEntries")
                return
            }
        } catch(e) {
            console.log("[StartMenu] DesktopEntries not available, using fallback")
        }
        // Fallback: scan .desktop files via bash
        appScanner.running = true
    }

    Process {
        id: appScanner
        command: ["bash", "-c",
            "for f in /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  nodisplay=$(grep -i '^NoDisplay=true' \"$f\" 2>/dev/null); " +
            "  [ -n \"$nodisplay\" ] && continue; " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2); " +
            "  exec_line=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2 | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  id=$(basename \"$f\" .desktop); " +
            "  [ -z \"$name\" ] && continue; " +
            "  printf '%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$icon\" \"$exec_line\"; " +
            "done | sort -t$'\\t' -k2"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                const apps = []
                for (const line of lines) {
                    const parts = line.split("\t")
                    if (parts.length >= 4) {
                        apps.push({
                            id: parts[0],
                            name: parts[1],
                            icon: parts[2],
                            execCmd: parts[3],
                            entry: null  // no DesktopEntry object, use execCmd
                        })
                    }
                }
                menuRoot.allApps = apps
                menuRoot.appsLoaded = true
                console.log("[StartMenu] Loaded", apps.length, "apps from .desktop scan")
            }
        }
    }

    function loadPinnedApps() {
        pinnedLoader.reload()
    }

    FileView {
        id: pinnedLoader
        path: Quickshell.dataPath("pinned-apps.json")
        blockLoading: true
        onLoaded: {
            try {
                const d = JSON.parse(this.text())
                if (d.pinned) menuRoot.pinnedAppIds = d.pinned
            } catch (e) {}
        }
    }

    function savePinnedApps() {
        pinnedSaver.command = ["bash", "-c",
            "echo '" + JSON.stringify({pinned: pinnedAppIds}) + "' > " + Quickshell.dataPath("pinned-apps.json")]
        pinnedSaver.running = true
    }

    Process {
        id: pinnedSaver
        running: false
    }

    function pinApp(appId) {
        if (pinnedAppIds.indexOf(appId) === -1) {
            pinnedAppIds = pinnedAppIds.concat([appId])
            savePinnedApps()
        }
    }

    function unpinApp(appId) {
        pinnedAppIds = pinnedAppIds.filter(id => id !== appId)
        savePinnedApps()
    }

    function isPinned(appId) {
        return pinnedAppIds.indexOf(appId) !== -1
    }

    // ── Smart entry lookup with fallbacks ──
    function findEntry(appId) {
        let entry = DesktopEntries.byId(appId)
        if (entry) return entry
        entry = DesktopEntries.byId(appId.toLowerCase())
        if (entry) return entry
        // Search through all apps
        for (const app of allApps) {
            if (app.id.toLowerCase() === appId.toLowerCase()) return app.entry
            if (app.name.toLowerCase() === appId.toLowerCase()) return app.entry
            if (app.id.toLowerCase().includes(appId.toLowerCase())) return app.entry
        }
        return null
    }

    // ── Find full app object (works even when entry is null in fallback mode) ──
    function findAppById(appId) {
        if (!appId) return null
        const q = appId.toLowerCase()
        for (const app of allApps) {
            if (app.id.toLowerCase() === q) return app
            if (app.name.toLowerCase() === q) return app
        }
        return null
    }

    function launchApp(appOrEntry) {
        if (!appOrEntry) return
        // If it's a DesktopEntry with execute(), use that
        if (appOrEntry.execute) {
            appOrEntry.execute()
        } else if (appOrEntry.entry && appOrEntry.entry.execute) {
            appOrEntry.entry.execute()
        } else if (appOrEntry.execCmd) {
            // Fallback: launch via bash
            fallbackLauncher.command = ["bash", "-c", "setsid " + appOrEntry.execCmd + " > /dev/null 2>&1 < /dev/null & disown"]
            fallbackLauncher.running = true
        }
        appLaunched()
    }

    Process { id: fallbackLauncher; running: false }

    function filteredApps() {
        if (!searchQuery || searchQuery === "") return allApps
        const q = searchQuery.toLowerCase()
        return allApps.filter(app => {
            return app.name.toLowerCase().includes(q) ||
                   app.id.toLowerCase().includes(q)
        })
    }

    Keys.onEscapePressed: closeRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ──── LEFT: Pinned ────
            ColumnLayout {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 16

                Text {
                    text: "Pinned"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                GridLayout {
                    columns: 5
                    columnSpacing: 8
                    rowSpacing: 8
                    Layout.fillWidth: true

                    Repeater {
                        model: menuRoot.pinnedAppIds

                        Rectangle {
                            property string appId: modelData
                            property var entry: menuRoot.findEntry(appId)
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 76
                            radius: 10
                            color: tileMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 36
                                    height: 36
                                    source: entry && entry.icon
                                        ? Quickshell.iconPath(entry.icon)
                                        : Quickshell.iconPath("application-x-executable")
                                    sourceSize: Qt.size(36, 36)
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 58
                                    text: entry ? entry.name : appId
                                    color: Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        // Try DesktopEntry first, fall back to the app object itself
                                        // (which may carry execCmd in fallback mode)
                                        const app = menuRoot.findAppById(appId)
                                        if (entry) menuRoot.launchApp(entry)
                                        else if (app) menuRoot.launchApp(app)
                                    } else {
                                        menuRoot.unpinApp(appId)
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Divider
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            // ──── RIGHT: All apps ────
            ColumnLayout {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 12

                Text {
                    text: "All apps"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    color: Theme.alpha(Theme.fg, 0.08)
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Theme.blue

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: menuRoot.nfSearch
                            color: Theme.fgDim
                            font.family: Theme.monoFont
                            font.pixelSize: 14
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            clip: true
                            onTextChanged: menuRoot.searchQuery = text

                            Text {
                                anchors.fill: parent
                                visible: !searchInput.text
                                text: "Type to search..."
                                color: Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                ListView {
                    id: appListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: menuRoot.filteredApps()
                    spacing: 2

                    section.property: "name"
                    section.criteria: ViewSection.FirstCharacter
                    section.delegate: Text {
                        required property string section
                        text: section.toUpperCase()
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        topPadding: 8
                        leftPadding: 12
                        bottomPadding: 4
                    }

                    delegate: Rectangle {
                        required property var modelData
                        width: appListView.width
                        height: 40
                        radius: 10
                        color: rowMa.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: modelData.icon
                                    ? Quickshell.iconPath(modelData.icon)
                                    : Quickshell.iconPath("application-x-executable")
                                sourceSize: Qt.size(24, 24)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.fgDim
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }

                            Text {
                                visible: menuRoot.isPinned(modelData.id)
                                text: menuRoot.nfPin
                                color: "#ffffff"
                                opacity: 0.6
                                font.family: Theme.monoFont
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    // Prefer DesktopEntry, fall back to modelData
                                    // itself (which carries execCmd in fallback mode).
                                    if (modelData.entry) menuRoot.launchApp(modelData.entry)
                                    else menuRoot.launchApp(modelData)
                                } else {
                                    if (menuRoot.isPinned(modelData.id))
                                        menuRoot.unpinApp(modelData.id)
                                    else
                                        menuRoot.pinApp(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══ Bottom Bar ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Theme.alpha(Theme.bg1, 0.6)

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.alpha(Theme.blue, 0.2)
                    border.width: 2
                    border.color: Theme.alpha(Theme.blue, 0.4)

                    Text {
                        anchors.centerIn: parent
                        text: menuRoot.nfUser
                        color: Theme.blue
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }
                }

                Text {
                    text: Quickshell.env("USER") || "User"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // File Manager
                Rectangle {
                    width: 40
                    height: 40
                    radius: 10
                    color: fmMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: menuRoot.nfFolder
                        color: Theme.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: fmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached({command: ["thunar"]})
                            menuRoot.appLaunched()
                        }
                    }
                }

                // Settings — opens Zen Shell control panel
                Rectangle {
                    width: 40
                    height: 40
                    radius: 10
                    color: stMa.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: menuRoot.nfSettings
                        color: Theme.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: stMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Close start menu first, then open settings via IPC
                            menuRoot.closeRequested()
                            Quickshell.execDetached({
                                command: ["qs", "-c", "zen-shell", "ipc", "call", "zen", "toggleSettings"]
                            })
                        }
                    }
                }

                // Power button — opens a right-side horizontal popover
                Rectangle {
                    id: powerBtn
                    width: 40
                    height: 40
                    radius: 10
                    color: pwMa.containsMouse || menuRoot.powerMenuOpen
                           ? Theme.alpha(Theme.fg, 0.08)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: menuRoot.nfPower
                        color: Theme.fgDim
                        font.family: Theme.monoFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: pwMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.powerMenuOpen = !menuRoot.powerMenuOpen
                    }

                    // ═══ Power Menu Popover — horizontal, right-anchored ═══
                    // Floats above the bottom bar, anchored to the right edge of
                    // the power button. 4 uniform icon-tiles in one row.
                    Rectangle {
                        id: powerPopover
                        visible: menuRoot.powerMenuOpen
                        width: powerRow.implicitWidth + 16
                        height: 64
                        radius: 14
                        color: Theme.alpha(Theme.bg0, 0.96)
                        border.width: 1
                        border.color: Theme.alpha(Theme.fg, 0.12)

                        // Anchor: above the power button, right edge aligned
                        // with the power button's right edge (so it extends left).
                        anchors.right: parent.right
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 10
                        z: 100

                        opacity: menuRoot.powerMenuOpen ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        // Small arrow pointing down toward the power button
                        Canvas {
                            anchors.horizontalCenter: parent.right
                            anchors.horizontalCenterOffset: -20
                            anchors.top: parent.bottom
                            width: 14
                            height: 8
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = Theme.alpha(Theme.bg0, 0.96)
                                ctx.beginPath()
                                ctx.moveTo(0, 0)
                                ctx.lineTo(7, 8)
                                ctx.lineTo(14, 0)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }

                        RowLayout {
                            id: powerRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Repeater {
                                model: [
                                    { icon: "\uf023", label: "Lock",     action: "lock",     cmd: "hyprlock",                destructive: false },
                                    { icon: "\uf2f5", label: "Logout",   action: "logout",   cmd: "hyprctl dispatch exit",  destructive: false },
                                    { icon: "\uf021", label: "Restart",  action: "reboot",   cmd: "systemctl reboot",       destructive: false },
                                    { icon: "\uf011", label: "Shutdown", action: "shutdown", cmd: "systemctl poweroff",     destructive: true  }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.preferredWidth: 72
                                    Layout.preferredHeight: 48
                                    radius: 10

                                    readonly property bool isDestructive: modelData.destructive === true
                                    readonly property color baseColor: isDestructive
                                                                        ? Theme.red
                                                                        : Theme.fgDim

                                    color: pmMa.containsMouse
                                           ? (isDestructive
                                              ? Theme.alpha(Theme.red, 0.18)
                                              : Theme.alpha(Theme.fg, 0.08))
                                           : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.icon
                                            color: parent.parent.baseColor
                                            font.family: Theme.monoFont
                                            font.pixelSize: 18
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.label
                                            color: parent.parent.baseColor
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    MouseArea {
                                        id: pmMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            menuRoot.powerMenuOpen = false
                                            menuRoot.powerActionRequested(modelData.action, modelData.cmd)
                                            menuRoot.closeRequested()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // (Power menu moved to a right-anchored popover attached to the power
        // button — see powerPopover above. This keeps the start menu visually
        // stable and aligns with the HyprMod / Event Horizon interaction model.)
    }
}

