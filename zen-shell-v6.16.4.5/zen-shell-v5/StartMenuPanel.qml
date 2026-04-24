import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
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

    // v6.16.2.3.1: True while a blocking external dialog (zenity file
    // picker) is open. shell.qml watches this and suspends the
    // HyprlandFocusGrab so the StartMenu doesn't auto-close when
    // zenity steals focus. Cleared when the Process exits.
    property bool uploadInProgress: false

    // v6.16.2 icons — Nerd Font Material Design glyphs
    readonly property string nfPin: "\uf0403"
    readonly property string nfUser: "\uf007"
    // v6.16.2 FIX: Previous value "\uf024b" was parsed by Qt as \uf024
    // (FontAwesome 'flag' glyph) followed by literal 'b'. Correct Nerd
    // Font folder codepoint is U+F07B (FontAwesome folder).
    readonly property string nfFolder: "\uf07b"
    readonly property string nfSettings: "\uf013"
    readonly property string nfPower: "\u23fb"
    readonly property string nfSearch: "\uf002"
    readonly property string nfPinFill: "\uf0403"    // filled pin for context menu
    readonly property string nfPinOff: "\uf0402"     // unpin variant
    readonly property string nfCalendar: "\uf073"    // for potential future use

    property var allApps: []
    property var pinnedAppIds: ["kitty", "firefox", "code", "thunar", "steam"]
    property string searchQuery: ""
    property bool appsLoaded: false
    property bool powerMenuOpen: false

    // v6.16.2: Right-click context menu state
    property bool contextMenuOpen: false
    property string contextAppId: ""
    property var contextApp: null
    property int contextX: 0
    property int contextY: 0
    property bool contextFromPinned: false   // true = pinned tile, false = all-apps row

    // v6.16.3: System info popover (fastfetch-style). Triggered by clicking
    // the user avatar in the footer. Shows OS, kernel, CPU, GPU, theme, etc.
    property bool sysInfoOpen: false

    function openContextMenu(appId, app, globalX, globalY, fromPinned) {
        contextAppId = appId
        contextApp = app
        contextFromPinned = fromPinned
        // Clamp to panel bounds — menu is 200x variable
        const menuW = 220
        const menuH = fromPinned ? 100 : 140
        contextX = Math.max(8, Math.min(globalX, menuRoot.width - menuW - 8))
        contextY = Math.max(8, Math.min(globalY, menuRoot.height - menuH - 8))
        contextMenuOpen = true
    }

    function closeContextMenu() {
        contextMenuOpen = false
        contextAppId = ""
        contextApp = null
    }

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

    // v6.16.2 FUZZY FINDER:
    // Old implementation used substring-only matching — "typing 'vcd'
    // wouldn't match 'VSCode'. New fuzzy algorithm scores matches by:
    //   1. Exact match (10000)       — name or id === query
    //   2. Prefix match (5000-6000)  — name starts with query
    //   3. Word-boundary match (2500) — query matches after space/hyphen
    //   4. Subsequence match (500-1500) — characters appear in order,
    //      scored by gap size + consecutiveness
    //   5. Substring fallback (800)  — query appears as substring
    //   6. Skip (0)                  — no match
    // Results sorted by score descending, capped to top 50 for perf.
    function _fuzzyScore(text, query) {
        if (!text || !query) return 0
        const t = text.toLowerCase()
        const q = query.toLowerCase()

        // Exact match — highest priority
        if (t === q) return 10000

        // Prefix — very high
        if (t.startsWith(q)) {
            // Shorter texts scored higher (more specific match)
            return 6000 - Math.min(t.length - q.length, 100)
        }

        // Word boundary match — check if query starts after a space/hyphen/underscore
        const wbMatch = new RegExp("(^|[\\s\\-_.])" + q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
        if (wbMatch.test(t)) return 2500

        // Subsequence fuzzy match — "vcd" → "VsCoDe" (chars in order)
        let ti = 0, qi = 0
        let score = 0
        let consecutive = 0
        let lastMatchIdx = -1
        while (ti < t.length && qi < q.length) {
            if (t.charAt(ti) === q.charAt(qi)) {
                // Consecutive char bonus
                if (lastMatchIdx === ti - 1) {
                    consecutive++
                    score += 100 * consecutive
                } else {
                    consecutive = 0
                    score += 30
                }
                // Penalize gap — earlier matches weighted more
                if (qi === 0 && ti > 0) score -= ti * 2
                lastMatchIdx = ti
                qi++
            }
            ti++
        }
        if (qi === q.length) {
            // Full subsequence match — base + accumulated bonuses
            return 500 + score
        }

        // Plain substring fallback — lower priority than subsequence
        if (t.includes(q)) return 800

        return 0
    }

    function filteredApps() {
        if (!searchQuery || searchQuery === "") return allApps
        const q = searchQuery

        // Score every app by max(name score, id score, exec score)
        const scored = []
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i]
            const nameScore = _fuzzyScore(app.name, q)
            const idScore   = _fuzzyScore(app.id, q) * 0.9   // id slightly less weighted
            const execScore = app.exec ? _fuzzyScore(app.exec, q) * 0.6 : 0
            const score = Math.max(nameScore, idScore, execScore)
            if (score > 0) scored.push({ app: app, score: score })
        }

        // Sort by score descending, tie-break alphabetically
        scored.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score
            return a.app.name.localeCompare(b.app.name)
        })

        // Cap to 50 results for rendering perf
        return scored.slice(0, 50).map(s => s.app)
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

                // v6.16.4.5: grid reduced 5 → 4 columns to accommodate
                // the wider tiles (72px instead of 64px). Math:
                //   4 tiles × 72 + 3 gaps × 8 = 288 + 24 = 312px,
                //   fits comfortably in the 360px left pane with
                //   room for padding.
                // Previously 5 × 64 + 4 × 8 = 320 + 32 = 352px, tight
                // but fit. Can't keep 5 columns with wider tiles.
                GridLayout {
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 8
                    Layout.fillWidth: true

                    Repeater {
                        model: menuRoot.pinnedAppIds

                        Rectangle {
                            property string appId: modelData
                            property var entry: menuRoot.findEntry(appId)
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 82
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
                                    // v6.16.4.5: widened from 58px to 66px + reduced
                                    // tile padding — gives labels ~8px more breathing
                                    // room so "Thunar F…" / "Visual St…" / "Crimson…"
                                    // don't look cramped under the icons. Tile width
                                    // also bumped 64→72 to match. At monitor scale
                                    // 1.25x, the extra room prevents the visual
                                    // overlap Paul reported.
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 66
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
                                        const app = menuRoot.findAppById(appId)
                                        if (entry) menuRoot.launchApp(entry)
                                        else if (app) menuRoot.launchApp(app)
                                    } else {
                                        // v6.16.2: right-click → context menu
                                        const pos = mapToItem(menuRoot, mouse.x, mouse.y)
                                        const app = menuRoot.findAppById(appId)
                                        menuRoot.openContextMenu(appId, app || {name: appId, id: appId, entry: entry},
                                                                 pos.x, pos.y, true)
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
                                    if (modelData.entry) menuRoot.launchApp(modelData.entry)
                                    else menuRoot.launchApp(modelData)
                                } else {
                                    // v6.16.2: right-click → context menu
                                    const pos = mapToItem(menuRoot, mouse.x, mouse.y)
                                    menuRoot.openContextMenu(modelData.id, modelData,
                                                             pos.x, pos.y, false)
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

                // v6.16.3: User avatar circle.
                // Shows auto-detected photo from /var/lib/AccountsService/icons,
                // ~/.face, SDDM/GDM face files, or user-uploaded custom avatar.
                // Click toggles a system-info popover (fastfetch-style).
                Rectangle {
                    id: avatarWrap
                    width: 36
                    height: 36
                    radius: width / 2
                    color: Theme.alpha(Theme.blue, 0.2)
                    border.width: 2
                    border.color: avatarMa.containsMouse
                        ? Theme.blue
                        : Theme.alpha(Theme.blue, 0.4)
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    antialiasing: true

                    // v6.16.2.3: shader-based circular mask (FBO approach
                    // didn't reliably render as circle in Paul's Quickshell
                    // build — fragment shader with UV distance test works
                    // across all backends).
                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        anchors.margins: 2
                        source: UserProfileService.effectiveAvatarSource
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(72, 72)
                        visible: false
                        onStatusChanged: console.log("[FooterAvatar] status=" + status + " src=" + source)
                    }
                    Rectangle {
                        id: avatarImgMask
                        anchors.fill: avatarImg
                        radius: width / 2
                        color: "white"
                        visible: false
                    }
                    OpacityMask {
                        anchors.fill: avatarImg
                        source: avatarImg
                        maskSource: avatarImgMask
                        visible: avatarImg.status === Image.Ready
                              && avatarImg.source.toString().length > 0
                    }

                    // Fallback glyph when no photo available
                    Text {
                        anchors.centerIn: parent
                        text: menuRoot.nfUser
                        color: Theme.blue
                        font.family: Theme.monoFont
                        font.pixelSize: 16
                        visible: !avatarImg.visible
                    }

                    MouseArea {
                        id: avatarMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.sysInfoOpen = !menuRoot.sysInfoOpen
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: UserProfileService.userName
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: UserProfileService.hostname
                               ? ("@" + UserProfileService.hostname)
                               : ""
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        visible: text.length > 0
                    }
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
    }   // close main ColumnLayout — context menu below is a SIBLING

    // ═══════════════════════════════════════════════════════════════
    // v6.16.3 SYSTEM INFO POPOVER (fastfetch-style)
    // Triggered by clicking the user avatar in the footer. Floats over
    // the panel showing OS, kernel, CPU, GPU, theme, uptime, etc.
    // ═══════════════════════════════════════════════════════════════
    MouseArea {
        id: sysInfoBackdrop
        anchors.fill: parent
        visible: menuRoot.sysInfoOpen
        z: 95
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: menuRoot.sysInfoOpen = false
    }

    Rectangle {
        id: sysInfoPanel
        visible: menuRoot.sysInfoOpen
        z: 96
        // Anchor above the footer user row, left-aligned to avatar
        x: 20
        y: parent.height - 200 - 72   // 72 = footer height; 200 = this panel
        width: 380
        height: Math.min(sysInfoCol.implicitHeight + 24, 420)
        radius: Math.max(8, (Theme.panelRadius || 12) * 0.6)
        color: Theme.alpha(Theme.bg0 || "#1e1e1e", 0.98)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.14)
        opacity: menuRoot.sysInfoOpen ? 1 : 0
        scale: menuRoot.sysInfoOpen ? 1 : 0.95
        transformOrigin: Item.BottomLeft

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // Drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "#000000"
            opacity: 0.3
            z: -1
        }

        ColumnLayout {
            id: sysInfoCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            // Header row: large avatar + user@host + distro
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: width / 2
                    color: Theme.alpha(Theme.blue, 0.2)
                    border.width: 2
                    border.color: Theme.alpha(Theme.blue, 0.5)
                    antialiasing: true

                    Image {
                        id: popAvatarImg
                        anchors.fill: parent
                        anchors.margins: 2
                        source: UserProfileService.effectiveAvatarSource
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(104, 104)
                        visible: false
                        onStatusChanged: console.log("[PopoverAvatar] status=" + status + " src=" + source)
                    }
                    Rectangle {
                        id: popAvatarImgMask
                        anchors.fill: popAvatarImg
                        radius: width / 2
                        color: "white"
                        visible: false
                    }
                    OpacityMask {
                        anchors.fill: popAvatarImg
                        source: popAvatarImg
                        maskSource: popAvatarImgMask
                        visible: popAvatarImg.status === Image.Ready
                              && popAvatarImg.source.toString().length > 0
                    }
                    Text {
                        anchors.centerIn: parent
                        text: menuRoot.nfUser
                        color: Theme.blue
                        font.family: Theme.monoFont
                        font.pixelSize: 22
                        visible: !popAvatarImg.visible
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: UserProfileService.userName +
                              (UserProfileService.hostname
                                ? "@" + UserProfileService.hostname : "")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: UserProfileService.osName +
                              (UserProfileService.osVersion
                                ? " " + UserProfileService.osVersion : "")
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "up " + (UserProfileService.uptime || "…")
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.alpha(Theme.fg, 0.1)
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            // Specs grid — key / value rows
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 5

                Text { text: "Kernel"; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                Text {
                    Layout.fillWidth: true
                    text: UserProfileService.kernelVersion || "…"
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text { text: "CPU"; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                Text {
                    Layout.fillWidth: true
                    text: UserProfileService.cpuModel
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    text: UserProfileService.gpuNames.length > 1 ? "GPUs" : "GPU"
                    color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true
                    visible: UserProfileService.gpuNames.length > 0
                }
                Text {
                    Layout.fillWidth: true
                    text: UserProfileService.gpuNames.join(" · ")
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    visible: UserProfileService.gpuNames.length > 0
                }

                Text { text: "WM"; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                // v6.16.2.3.2: Hover tooltip shows the FULL Hyprland version
                // string (commit hash, branch, etc.). Without this the row
                // ellipses to "...built from branch v0.54.3 at c..." with
                // no way to see the rest. ToolTip is a Quick Controls
                // attachment that fires after a short hover delay.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: wmText.implicitHeight
                    Text {
                        id: wmText
                        anchors.fill: parent
                        text: "Hyprland " + (UserProfileService.hyprlandVersion || "")
                        color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    ToolTip.visible: wmHoverMa.containsMouse
                                     && (wmText.truncated
                                         || UserProfileService.hyprlandVersion.length > 30)
                    ToolTip.delay: 350
                    ToolTip.text: "Hyprland " + (UserProfileService.hyprlandVersion || "(unknown)")
                    MouseArea {
                        id: wmHoverMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                Text { text: "Shell"; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                Text {
                    Layout.fillWidth: true
                    text: "Zen Shell · Quickshell"
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                }

                Text { text: "Theme"; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                Text {
                    Layout.fillWidth: true
                    text: UserProfileService.themeName
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            // Color palette preview (theme-synced)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                Layout.topMargin: 6
                color: "transparent"
                Row {
                    anchors.fill: parent
                    spacing: 2
                    Repeater {
                        model: [
                            Theme.bg0, Theme.bg1 || Theme.bg0,
                            Theme.fg, Theme.fgDim,
                            Theme.blue, Theme.alpha(Theme.blue, 0.6)
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 36
                            height: 16
                            radius: 3
                            color: modelData
                        }
                    }
                }
            }

            // Change avatar button row
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 6
                    color: changeAvatarMa.containsMouse
                        ? Theme.alpha(Theme.blue, 0.25)
                        : Theme.alpha(Theme.blue, 0.12)
                    border.width: 1
                    border.color: Theme.alpha(Theme.blue, 0.4)
                    Text {
                        anchors.centerIn: parent
                        text: UserProfileService.customAvatarPath
                              ? "Change avatar"
                              : "Upload custom avatar"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: changeAvatarMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: avatarPicker.running = true
                    }
                }

                Rectangle {
                    visible: UserProfileService.customAvatarPath.length > 0
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 6
                    color: resetAvatarMa.containsMouse
                        ? Theme.alpha(Theme.fg, 0.18)
                        : Theme.alpha(Theme.fg, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "↺"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: resetAvatarMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UserProfileService.clearCustomAvatar()
                    }
                }
            }
        }
    }

    // Avatar picker via zenity file dialog
    // v6.16.2.3.1: Flip `uploadInProgress` around the Process lifecycle
    // so shell.qml's HyprlandFocusGrab is suspended while zenity is up.
    // Without this, zenity steals keyboard/pointer focus → FocusGrab
    // onCleared fires → StartMenu closes before the user can pick a file.
    Process {
        id: avatarPicker
        running: false
        command: ["bash", "-c",
            "zenity --file-selection --title='Select Avatar' " +
            "--file-filter='Images | *.png *.jpg *.jpeg *.webp' 2>/dev/null || true"]
        onRunningChanged: menuRoot.uploadInProgress = running
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p) UserProfileService.setCustomAvatar(p)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // v6.16.2 RIGHT-CLICK CONTEXT MENU
    // Rendered as a sibling of the main ColumnLayout so it overlays
    // everything else. Backdrop catches outside clicks to dismiss.
    // ═══════════════════════════════════════════════════════════════
    MouseArea {
        id: ctxBackdrop
        anchors.fill: parent
        visible: menuRoot.contextMenuOpen
        z: 99
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: menuRoot.closeContextMenu()
    }

    Rectangle {
        id: contextMenu
        visible: menuRoot.contextMenuOpen
        z: 100
        x: menuRoot.contextX
        y: menuRoot.contextY
        width: 220
        height: ctxColumn.implicitHeight + 12
        radius: Math.max(8, (Theme.panelRadius || 12) * 0.6)
        color: Theme.alpha(Theme.bg0 || "#1e1e1e", 0.98)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.14)
        opacity: menuRoot.contextMenuOpen ? 1 : 0
        scale: menuRoot.contextMenuOpen ? 1 : 0.95
        transformOrigin: Item.TopLeft

        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        // Subtle drop-shadow illusion via lower-z sibling (no QtGraphicalEffects)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "#000000"
            opacity: 0.25
            z: -1
        }

        ColumnLayout {
            id: ctxColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // Header — app name
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                Image {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.leftMargin: 6
                    source: (menuRoot.contextApp && menuRoot.contextApp.icon)
                        ? Quickshell.iconPath(menuRoot.contextApp.icon)
                        : Quickshell.iconPath("application-x-executable")
                    sourceSize: Qt.size(18, 18)
                }
                Text {
                    Layout.fillWidth: true
                    text: menuRoot.contextApp ? menuRoot.contextApp.name : ""
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 6; Layout.rightMargin: 6
                Layout.preferredHeight: 1
                color: Theme.alpha(Theme.fg, 0.08)
            }

            // Launch
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 6
                color: launchMa.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    spacing: 8
                    Text {
                        text: "\uf0a9"   // arrow-circle-right
                        color: Theme.blue
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                        Layout.preferredWidth: 18
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Launch"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: launchMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (menuRoot.contextApp) {
                            if (menuRoot.contextApp.entry)
                                menuRoot.launchApp(menuRoot.contextApp.entry)
                            else
                                menuRoot.launchApp(menuRoot.contextApp)
                        }
                        menuRoot.closeContextMenu()
                    }
                }
            }

            // Pin / Unpin (dynamic)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 6
                color: pinMa.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"
                readonly property bool pinned: menuRoot.isPinned(menuRoot.contextAppId)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    spacing: 8
                    Text {
                        text: parent.parent.pinned ? menuRoot.nfPinOff : menuRoot.nfPin
                        color: parent.parent.pinned ? Theme.alpha(Theme.fg, 0.7) : Theme.blue
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                        Layout.preferredWidth: 18
                    }
                    Text {
                        Layout.fillWidth: true
                        text: parent.parent.pinned ? "Unpin from Start" : "Pin to Start"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: pinMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.pinned) menuRoot.unpinApp(menuRoot.contextAppId)
                        else menuRoot.pinApp(menuRoot.contextAppId)
                        menuRoot.closeContextMenu()
                    }
                }
            }

            // Copy command (helpful for power users)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 6
                visible: menuRoot.contextApp
                         && (menuRoot.contextApp.execCmd || (menuRoot.contextApp.entry && menuRoot.contextApp.entry.exec))
                color: copyMa.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    spacing: 8
                    Text {
                        text: "\uf0c5"   // copy icon
                        color: Theme.alpha(Theme.fg, 0.7)
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                        Layout.preferredWidth: 18
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Copy launch command"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: copyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const cmd = menuRoot.contextApp.execCmd ||
                                   (menuRoot.contextApp.entry ? menuRoot.contextApp.entry.exec : "")
                        if (cmd) {
                            copyProc.command = ["bash", "-c",
                                "printf '%s' " + JSON.stringify(cmd) + " | wl-copy 2>/dev/null || " +
                                "printf '%s' " + JSON.stringify(cmd) + " | xclip -sel clip 2>/dev/null"]
                            copyProc.running = true
                        }
                        menuRoot.closeContextMenu()
                    }
                }
            }
        }
    }

    // Process for clipboard copy (wl-copy / xclip)
    Process { id: copyProc; running: false }
}

