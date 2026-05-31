import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell

/*
 * ZenSettings — Unified settings window (v6.2)
 *
 * Changes from v6.1:
 * - Added "General" and "Decoration" nav entries (HyprMod-style)
 *   AppearancePage kept as "Appearance (legacy)" for backward compat —
 *   walang sinira, may dagdag lang.
 * - Fixed fullscreen UI:
 *     * Sidebar width scales (220 windowed / 260 fullscreen) para pantay
 *       ang spacing across resolutions.
 *     * Inner content area gets a max-content-width clamp (1000px) and
 *       horizontal centering when fullscreen, so yung UI hindi ma-stretch
 *       at ma-irregular sa wide monitor.
 *     * Consistent 24px inner padding top/bottom across all pages.
 *
 * Layout (sidebar / content):
 * ┌──────────────────────────────────────────────┐
 * │ [⚙] Settings                          [□] [×]│
 * ├─────────────┬────────────────────────────────┤
 * │ APPEARANCE  │                                 │
 * │ • General   │                                 │
 * │ • Decoration│       [active page content]    │
 * │ • Animations│                                 │
 * │ • Themes    │                                 │
 * │ INPUT/DISPLAY                                 │
 * │ • Displays  │                                 │
 * │ • Panel     │                                 │
 * │ OTHER                                         │
 * │ • Wallpaper │                                 │
 * │ • Appearance(legacy)                          │
 * └─────────────┴────────────────────────────────┘
 */
Rectangle {
    id: root

    signal closeRequested()
    signal toggleFullscreen()

    property bool isFullscreen: false
    property bool hasBeenDragged: false  // v6.13: set true on drag to break anchors.centerIn
    // hf95.20: expose the hyprbars mimic bar so the floating search (mounted
    // in shell.qml) can rest below it when it's showing.
    property alias hyprbarsMimic: hyprbarsMimic

    color: ThemeService.alpha(ThemeService.bg0, 0.96)
    // v6.4: honor Theme.styleMode — rounded style gives 22, pill gives 16
    radius: isFullscreen
            ? 0
            : ((PanelState.propagateStyleToModules && Theme.styleMode === "round") ? 22 : 16)
    border.width: isFullscreen ? 0 : 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)
    clip: true

    // v7.0.0-beta.1-hf95.22 — Settings mimic title bar DISABLED per user
    // request. It's kept in the tree (wiring intact: center title, drag,
    // theme/align) but force-hidden, so the Settings window just uses its
    // native header again. Flip `wantBar` back to the hyprbars-enabled
    // check to re-enable. Wala tayong babawasan.
    HyprbarsMimic {
        id: hyprbarsMimic
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 50
        // hf95.22: hard-disabled (was: hyprbars-enabled && !fullscreen).
        property bool wantBar: false
        visible: wantBar
        alwaysShowWhenEnabled: true
        title: "Zen-Shell-Hypr-Control-Center"
        centerTitle: true
        dragTarget: root.isFullscreen ? null : root
        onDragRequested: root.hasBeenDragged = true
        showMinimizeButton: false
        onMinimizeClicked: { /* no-op */ }
        onCloseClicked: root.closeRequested()
        onMaximizeClicked: root.isFullscreen = !root.isFullscreen
        // Drag is handled by the existing header/title band below; the
        // mimic's drag area is harmless but we don't need to rewire it.
    }

    // ── Nav state ──
    property string currentPage: "general"

    // v7.0.0-beta.1-hf83: full-width title header.
    //
    // When true, the "⚙ Settings" title (+ maximize/close + drag) is
    // rendered as a header bar spanning the FULL width of the window,
    // sitting above both the sidebar and the content area — instead of
    // tucked into the top of the sidebar column. The old in-sidebar
    // header is hidden (not removed — wala tayong babawasan) so its
    // wiring survives if this is ever toggled off.
    property bool fullWidthHeader: true

    // v7.0.0-alpha.9: Tracks whether the user is actively scrolling
    // the current page's content. Used by the floating search bar
    // (mounted at PanelWindow level in shell.qml) to auto-hide while
    // scrolling, then re-show after a short debounce.
    //
    // v7.0.0-beta.1-hf85: auto-hide REMOVED per user request. The search
    // bar now lives pinned in the full-width header (hf83), so tucking it
    // away on scroll just made it disappear from where the user expects
    // it. Hard-returning false keeps the search bar (and kills the
    // peek-tab) permanently visible. The scroll-detection code is left
    // below as a comment so the behavior can be restored if ever wanted —
    // wala tayong babawasan.
    property bool isContentScrolling: false
    /*  (former auto-hide detection — disabled hf85)
    property bool isContentScrolling: {
        if (typeof pageStack === "undefined") return false
        const page = pageStack.itemAt(pageStack.currentIndex)
        if (!page) return false
        if (page.contentItem && page.contentItem.movingVertically !== undefined) {
            return page.contentItem.movingVertically
        }
        return false
    }
    */

    // Sidebar structure: header + items. Use null header entries to break
    // the list into sections (APPEARANCE / INPUT & DISPLAY / OTHER).
    //
    // v7.0.0-alpha.3 (Densho Surfaces): each entry now carries optional
    // `kanji` + `romaji` fields. When DenshoService.denshoMode is on,
    // the sidebar delegate renders kanji-primary with romaji subtitle
    // (e.g. "一般" / "General · Ippan"). When off, falls back to the
    // existing icon + label layout. Section headers also bilingualify
    // when Densho mode is on.
    readonly property var navItems: [
        { header: "APPEARANCE", kanji: "外観", romaji: "Gaikan" },
        { id: "general",     label: "General",            icon: "\uf0c9",            kanji: "一般", romaji: "Ippan" },
        { id: "decoration",  label: "Decoration",         icon: "\uf1fc",            kanji: "装飾", romaji: "Sōshoku" },
        { id: "animations",  label: "Animations",         icon: "\uf021",            kanji: "動き", romaji: "Ugoki" },
        { id: "themes",      label: "Themes",             icon: "\udb80\udd0e",      kanji: "主題", romaji: "Shudai" },
        // v7.0.0-beta.1-hf52 — hyprbars plugin manager
        { id: "hyprbars",    label: "Hyprbars (title bars)", icon: "\uf2d2",        kanji: "窓枠", romaji: "Madowaku" },
        { header: "INPUT & DISPLAY", kanji: "入出力", romaji: "Nyūshutsuryoku" },
        { id: "displays",    label: "Displays",           icon: "\uf26c",            kanji: "画面", romaji: "Gamen" },
        // v6.16.2.3.2-hotfix: full Input page (mirrors Control Panel
        // → Input tab; same backing service, both stay in sync).
        { id: "input",       label: "Input",              icon: "\uf245",            kanji: "入力", romaji: "Nyūryoku" },
        { id: "panel",       label: "Panel",              icon: "\uf03a",            kanji: "板",   romaji: "Ban" },
        { id: "barmodules",  label: "Bar Modules",        icon: "\uf017",            kanji: "部品", romaji: "Buhin" },
        { id: "sysrow",     label: "System Tray",         icon: "\uf2db",            kanji: "系統盤", romaji: "Keitōban" },
        // v7.0.0-alpha.14: Hot Corners — cursor-trigger zones
        { id: "hotcorners",  label: "Hot Corners",        icon: "\uf0a4",            kanji: "角",   romaji: "Kado" },
        { header: "CONNECTIVITY", kanji: "接続", romaji: "Setsuzoku" },
        { id: "connectivity", label: "Sound & Network",   icon: "\uf1eb",            kanji: "通信", romaji: "Tsūshin" },
        { id: "notifications", label: "Notifications",    icon: "\uf0f3",            kanji: "通知", romaji: "Tsūchi" },
        { header: "SYSTEM", kanji: "系統", romaji: "Keitō" },
        // v6.16.0.2: Battery & Power page (previously unregistered — oversight)
        { id: "battery",     label: "Battery & Power",    icon: "\uf240",            kanji: "電池", romaji: "Denchi" },
        // v7.0.0-beta.1-hf79 — Game Detection settings page
        { id: "gaming",      label: "Game Detection",     icon: "\uf11b",            kanji: "遊戯", romaji: "Yūgi" },
        // v7.0.0-beta.1-hf82k — Dock (second module surface)
        { id: "dock",        label: "Dock",               icon: "\uf52b",            kanji: "土台", romaji: "Dodai" },
        // v6.16.4: User Profile — avatar upload + system info
        { id: "userprofile", label: "User Profile",       icon: "\uf007",            kanji: "利用者", romaji: "Riyōsha" },
        // v7.0.0-beta.1-hf82p — User Management (CRUD via pkexec)
        { id: "usermgmt",    label: "User Management",   icon: "\uf0c0",            kanji: "利用者管理", romaji: "Riyōsha Kanri" },
        { id: "sddmlogin",   label: "Login Screen (SDDM)", icon: "\uf2f6",          kanji: "ログイン", romaji: "Roguin" },
        // v7.0.0-alpha.1 (Karui): Updates page — check + rollback
        { id: "updates",     label: "Updates",            icon: "\uf021",            kanji: "更新", romaji: "Kōshin" },
        // v6.16.4.12.6.51 (Hikari): Hyprland Plugins page TEMPORARILY HIDDEN.
        // The hyprpm sub-system needs more stability work before being
        // surfaced again — toggling currently requires a sudo-prompting
        // terminal popup and individual plugin builds can still fail
        // against newer Hyprland versions. Page implementation kept on
        // disk (PluginsPage.qml) and instantiated below for completeness,
        // but no sidebar entry — users will not see it.
        // To re-enable: uncomment the line below + uncomment the
        // "case 'plugins':" line in the StackLayout currentIndex switch.
        // { id: "plugins",     label: "Hyprland Plugins",   icon: "\uf12e" },  // puzzle-piece
        { header: "OTHER", kanji: "その他", romaji: "Sonota" },
        { id: "widgets",     label: "Desktop Widgets",    icon: "\uf1b2",            kanji: "飾り",   romaji: "Kazari" },
        { id: "wallpaper",   label: "Wallpaper",          icon: "\uf03e",            kanji: "壁紙",   romaji: "Kabegami" },
        // v7.0.0-beta.1-hf82o — Desktop icons + widgets
        { id: "desktop",     label: "Desktop",            icon: "\uf108",            kanji: "卓上",   romaji: "Takujō" },
        // v7.0.0-beta.1-hf39 — productivity features
        { header: "PRODUCTIVITY", kanji: "生産性", romaji: "Seisansei" },
        { id: "focusspaces",     label: "Focus Spaces",       icon: "\uf2bb",            kanji: "領域",   romaji: "Ryōiki" },
        { id: "quicknotes",      label: "Quick Notes",        icon: "\uf249",            kanji: "覚書",   romaji: "Oboegaki" },
        { id: "networkpulse",    label: "Network Pulse",      icon: "\uf0e8",            kanji: "通信",   romaji: "Tsūshin" },
        { id: "smartdim",        label: "Smart Dim",          icon: "\uf185",            kanji: "明暗",   romaji: "Meian" },
        { id: "titletranslator", label: "Title Translator",   icon: "\uf1ab",            kanji: "翻訳",   romaji: "Honyaku" },
        // v7.0.0-beta.1-hf82n — default apps + app float rules
        { id: "defaultapps",    label: "Default Apps",        icon: "\uf085",            kanji: "既定",   romaji: "Kitei" },
        { id: "appfloatrules",  label: "App Float Rules",     icon: "\uf2d2",            kanji: "窓規則", romaji: "Madokisoku" }
    ]

    // v7.0.0-beta.1-hf39 — watch PanelState.pendingSettingsPage so
    // bar modules can deep-link to their config page via
    // PanelState.openSettingsPage("quicknotes") etc. The watcher
    // applies the page id then clears the flag so subsequent
    // navigations re-fire correctly.
    Connections {
        target: PanelState
        function onPendingSettingsPageChanged() {
            const id = PanelState.pendingSettingsPage
            if (id && id.length > 0) {
                root.currentPage = id
                PanelState.pendingSettingsPage = ""
            }
        }
    }

    // Fullscreen-aware sidebar width
    readonly property int sidebarWidth: isFullscreen ? 260 : 220
    readonly property int contentInnerMaxWidth: 1100  // clamp content when fullscreen

    Keys.onEscapePressed: closeRequested()

    // v7.0.0-beta.1-hf83: outer ColumnLayout so the title can span the
    // full window width above the sidebar+content row. When
    // fullWidthHeader is false this header collapses (height 0, hidden)
    // and the old in-sidebar header takes over again — wala tayong
    // babawasan.
    ColumnLayout {
        anchors.fill: parent
        // v7.0.0-beta.1-hf95.19: when the hyprbars mimic title bar is
        // shown, push the ENTIRE settings UI (including the native
        // "Settings" top header) below it. Previously only the inner
        // sidebar+content row was offset, so the mimic overlapped the
        // native header at the very top. 0 when the mimic is hidden, so
        // the layout is unchanged for non-hyprbars users.
        anchors.topMargin: hyprbarsMimic.visible ? hyprbarsMimic.height : 0
        spacing: 0
        // ── Full-width title header ──
        Rectangle {
            id: topHeader
            visible: root.fullWidthHeader
            Layout.fillWidth: true
            Layout.preferredHeight: root.fullWidthHeader ? 48 : 0
            // Match the sidebar's tint so the header reads as one band
            // across the top; top corners follow the window radius.
            color: ThemeService.alpha(ThemeService.bg1, 0.85)
            topLeftRadius: root.radius
            topRightRadius: root.radius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: "\uf013"  // gear
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: ThemeService.blue
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Settings"
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: ThemeService.fg
                    Layout.alignment: Qt.AlignVCenter
                }

                // Drag handle fills the empty stretch between the title
                // and the window buttons.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.isFullscreen
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: root
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 0
                        drag.minimumY: 0
                        preventStealing: true
                        onPressed: root.hasBeenDragged = true
                    }
                }

                // Maximize / Restore
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 14
                    color: maxBtnAreaTop.containsMouse
                           ? ThemeService.alpha(ThemeService.green, 0.2)
                           : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: root.isFullscreen ? "\uf066" : "\uf065"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: ThemeService.fg
                    }
                    MouseArea {
                        id: maxBtnAreaTop
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleFullscreen()
                    }
                }

                // Close
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 14
                    color: closeBtnAreaTop.containsMouse
                           ? ThemeService.alpha(ThemeService.red, 0.2)
                           : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: ThemeService.fg
                    }
                    MouseArea {
                        id: closeBtnAreaTop
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // v7.0.0-beta.1-hf54: top clearance for HyprbarsMimic so the
        // sidebar + content area don't overlap with the title bar.
        // v7.0.0-beta.1-hf95.19: the OUTER ColumnLayout now carries this
        // offset (so the native header clears too), making an inner offset
        // redundant — it would double up. Kept at 0 here.
        anchors.topMargin: 0
        spacing: 0

        // ═══════════════════════════════════════════════
        // SIDEBAR — v6.8: rounded left corners match parent radius
        // ═══════════════════════════════════════════════
        Item {
            Layout.preferredWidth: root.sidebarWidth
            Layout.fillHeight: true
            clip: true

            Rectangle {
                anchors.fill: parent
                // Extend right edge past clip boundary to hide right corners
                anchors.rightMargin: -root.radius
                radius: root.radius
                color: ThemeService.alpha(ThemeService.bg1, 0.85)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 2

                // Header — v6.13: also serves as drag handle for the panel
                //
                // v7.0.0-beta.1-hf54: hidden when HyprbarsMimic is showing
                // to avoid double-header. Close + maximize functionality
                // migrates to the mimic's buttons (already wired via
                // onCloseClicked and onMaximizeClicked signals).
                // v6.16.4.12.6.51 (Hikari): always visible. Mimic removed.
                // v7.0.0-beta.1-hf83: hidden (height 0) when the full-width
                // header is on — the title moved to the top band. Wiring is
                // kept intact so toggling fullWidthHeader off restores it.
                Item {
                    visible: !root.fullWidthHeader
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.fullWidthHeader ? 0 : 48

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // v6.13: Drag handle — covers gear icon + "Settings" text only.
                        // Close/maximize buttons are outside this Item so they stay clickable.
                        // v7.0.0-alpha.7-hf3: Search bar moved to BOTTOM of sidebar
                        // (was in this header) — it competed with the maximize/close
                        // buttons for visible width and got squeezed below 240px.
                        // Sidebar mount has guaranteed sidebarWidth space.
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 0
                                spacing: 10

                                Text {
                                    text: "\uf013"  // gear
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: ThemeService.blue
                                }

                                Text {
                                    text: "Settings"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    color: ThemeService.fg
                                    Layout.fillWidth: true
                                }
                            }

                            // Drag MouseArea — LAST child = highest input priority.
                            // Covers the gear+Settings text area for dragging.
                            // Sets hasBeenDragged=true on press to break anchors.centerIn
                            // so drag.target can freely move the panel.
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.isFullscreen
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: root
                                drag.axis: Drag.XAndYAxis
                                drag.minimumX: 0
                                drag.minimumY: 0
                                preventStealing: true
                                onPressed: root.hasBeenDragged = true
                            }
                        }

                        // Maximize / Restore button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: maxBtnArea.containsMouse
                                   ? ThemeService.alpha(ThemeService.green, 0.2)
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: root.isFullscreen ? "\uf066" : "\uf065"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ThemeService.fg
                            }

                            MouseArea {
                                id: maxBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleFullscreen()
                            }
                        }

                        // Close button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: closeBtnArea.containsMouse
                                   ? ThemeService.alpha(ThemeService.red, 0.2)
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }

                            MouseArea {
                                id: closeBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeRequested()
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: ThemeService.alpha(ThemeService.fg, 0.08)
                    Layout.bottomMargin: 6
                    Layout.topMargin: 4
                }

                // v6.16.0.2 (fixed v6.16.1.2): Scrollable nav area.
                // Initial ScrollView wrapper in v6.16.0.2 had two bugs:
                //   1) `width: parent.parent.availableWidth` didn't
                //      resolve — parent.parent is the ScrollView's
                //      contentItem, not the ScrollView. Result: zero
                //      or undefined width → icons got clipped at the
                //      left edge of the sidebar, "Decoration" rendered
                //      as " ecoration" etc.
                //   2) ScrollView's internal Flickable was eating
                //      press events before they reached the nav
                //      MouseAreas — clicks appeared to do nothing.
                //
                // Fixed by switching to Flickable directly (explicit
                // control over dimensions + interactive flag) and
                // anchoring the inner ColumnLayout to the Flickable's
                // contentItem with proper width binding.
                Flickable {
                    id: navFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: navFlick.width
                    contentHeight: navCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    // Only scroll when content actually overflows — prevents
                    // accidental "flick" of a short nav list.
                    interactive: contentHeight > height

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    ColumnLayout {
                        id: navCol
                        width: navFlick.width
                        spacing: 2

                        // Nav items (with section headers)
                        Repeater {
                            model: root.navItems
                            delegate: Item {
                                id: navEntry
                                required property var modelData

                                readonly property bool isHeader: modelData.header !== undefined
                                readonly property bool active: !isHeader && root.currentPage === modelData.id

                                Layout.fillWidth: true
                                implicitHeight: isHeader ? 28 : 38

                                // SECTION HEADER (uppercase small text)
                                // v7.0.0-alpha.3 (Densho Surfaces): when Densho is
                                // on, prepend the kanji label so headers read
                                // e.g. "外観 · APPEARANCE · GAIKAN".
                                Text {
                                    visible: navEntry.isHeader
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 4
                                    anchors.bottomMargin: 4
                                    text: {
                                        const h = navEntry.modelData
                                        if (!h || !h.header) return ""
                                        if (DenshoService.denshoMode && h.kanji) {
                                            return h.kanji + " · " + h.header +
                                                   (h.romaji ? " · " + h.romaji.toUpperCase() : "")
                                        }
                                        return h.header
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    color: ThemeService.grey0
                                }

                        // NAV ITEM
                        Rectangle {
                            visible: !navEntry.isHeader
                            anchors.fill: parent
                            // v7.0.0-beta.1-hf86: rounded vs square hover style
                            radius: PanelState.settingsHoverStyle === "square" ? 2 : 8
                            color: navEntry.active
                                   ? (DenshoService.denshoMode
                                      ? ThemeService.alpha(ThemeService.red, 0.14)
                                      : ThemeService.alpha(ThemeService.blue, 0.18))
                                   : (navMouse.containsMouse
                                      ? ThemeService.alpha(ThemeService.fg, 0.06)
                                      : "transparent")

                            // v7.0.0-alpha.3 (Densho Surfaces): shu-iro accent
                            // strip on the active row when Densho is on. Mirrors
                            // the pattern shown in the Densho identity mockup.
                            Rectangle {
                                visible: DenshoService.denshoMode && navEntry.active
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2
                                color: ThemeService.red
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                // ── Default mode: Nerd Font icon ──
                                Text {
                                    visible: !DenshoService.denshoMode
                                    text: navEntry.isHeader ? "" : (navEntry.modelData.icon || "")
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: navEntry.active ? ThemeService.blue : ThemeService.grey0
                                    Layout.preferredWidth: 18
                                }

                                // ── Default mode: single-line label ──
                                Text {
                                    visible: !DenshoService.denshoMode
                                    text: navEntry.isHeader ? "" : (navEntry.modelData.label || "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: navEntry.active ? Font.DemiBold : Font.Normal
                                    color: navEntry.active ? ThemeService.fg : ThemeService.grey0
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // ── Densho mode: kanji-primary, no nerd icon ──
                                Text {
                                    visible: DenshoService.denshoMode
                                    text: navEntry.isHeader
                                          ? ""
                                          : (navEntry.modelData.kanji || navEntry.modelData.label || "")
                                    font.family: "Noto Serif CJK JP, " + Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: navEntry.active
                                           ? ThemeService.red
                                           : ThemeService.fg
                                    Layout.preferredWidth: 38
                                }

                                // ── Densho mode: bilingual subtitle ──
                                Text {
                                    visible: DenshoService.denshoMode
                                    text: {
                                        if (navEntry.isHeader) return ""
                                        const m = navEntry.modelData
                                        if (!m) return ""
                                        const lbl = m.label || ""
                                        const rom = m.romaji || ""
                                        return rom ? lbl + " · " + rom : lbl
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: navEntry.active
                                           ? ThemeService.fg
                                           : ThemeService.grey1
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!navEntry.isHeader) root.currentPage = navEntry.modelData.id
                                }
                            }
                        }
                    }
                        }
                    }
                }  // close Flickable

                // ═══════════════════════════════════════════════════════
                // v6.16.4.12.7 (Tachiagari): Sidebar user row
                //
                // The previous footer showed only the active theme
                // status ("Matugen (Auto from Wallpaper)"). User asked
                // to surface their identity here too — same pattern as
                // StartMenuPanel's footer (avatar + username/hostname).
                //
                // We keep the theme status as a thin secondary row so
                // no information is lost (wala tayong babawasan).
                //
                // Avatar resolves through UserProfileService.effectiveAvatarSource
                // which already handles the auto-detect → custom override
                // chain (~/.face, /var/lib/AccountsService, ~/.config/
                // zen-shell/user-avatar.* etc). Empty source → fall back
                // to a Nerd Font glyph in the same blue accent so the
                // row never looks empty even before the user uploads
                // a custom avatar.
                //
                // Circular masking uses the OpacityMask shader pattern
                // (same as StartMenuPanel.qml) — `layer.enabled: true`
                // with a Rectangle radius is unreliable for transparent
                // backgrounds in this Quickshell build, so we go the
                // shader route which works everywhere.
                // ═══════════════════════════════════════════════════════
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // ── User row — avatar + name@host ──
                    Rectangle {
                        id: sidebarUserBg
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 8
                        color: ThemeService.alpha(ThemeService.bg2, 0.6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            // Avatar circle (32px)
                            Rectangle {
                                id: sidebarAvatarWrap
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: width / 2
                                color: ThemeService.alpha(ThemeService.blue, 0.2)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                                antialiasing: true

                                Image {
                                    id: sidebarAvatarImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: (typeof UserProfileService !== "undefined")
                                            ? UserProfileService.effectiveAvatarSource : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(64, 64)
                                    visible: false
                                }
                                Rectangle {
                                    id: sidebarAvatarMask
                                    anchors.fill: sidebarAvatarImg
                                    radius: width / 2
                                    color: "white"
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.fill: sidebarAvatarImg
                                    source: sidebarAvatarImg
                                    maskSource: sidebarAvatarMask
                                    visible: sidebarAvatarImg.status === Image.Ready
                                          && sidebarAvatarImg.source.toString().length > 0
                                }

                                // Fallback glyph when no photo available
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf007"   // fa-user
                                    color: ThemeService.blue
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    visible: !sidebarAvatarImg.visible
                                            || sidebarAvatarImg.status !== Image.Ready
                                            || sidebarAvatarImg.source.toString().length === 0
                                }
                            }

                            // Username + @hostname
                            //
                            // v6.16.4.12.9.6 (Modori) hotfix: bulletproof
                            // version. Previous .9.5 fix used a plain Item
                            // + Column to escape Layout-system races, but
                            // user reported the labels STILL disappeared
                            // when the Settings window crossed monitors.
                            //
                            // Re-investigation found a deeper cause: the
                            // labels' `text` properties referenced
                            // `UserProfileService.userName` and
                            // `UserProfileService.hostname`. The avatar's
                            // fallback glyph showing in the screenshot
                            // (blue user-icon, not the actual photo)
                            // confirmed the SERVICE itself was in a
                            // transient bad state after the window move
                            // — its `effectiveAvatarSource` was returning
                            // empty. When a singleton's properties go
                            // null/empty, every binding pointing at it
                            // gets the empty value too. Texts elide to
                            // empty.
                            //
                            // Fix: read username DIRECTLY from
                            // `Quickshell.env("USER")`. That env var is
                            // populated at process start and never
                            // changes within the shell's lifetime — no
                            // service-state involvement. For hostname we
                            // keep UserProfileService as the primary
                            // source (it parses /etc/hostname), but fall
                            // back to env "HOSTNAME" or empty if both
                            // fail. Cached in local readonly properties
                            // outside the Texts so they're computed
                            // ONCE at component load, never re-bound.
                            //
                            // Also: ensure the labels are ALWAYS visible
                            // (no `visible: text.length > 0` gating on
                            // username — env USER is always present on
                            // any Linux system Zen Shell can launch on).
                            Item {
                                id: userTextWrap
                                Layout.fillWidth: true
                                Layout.minimumWidth: 60
                                Layout.preferredHeight: 32
                                implicitWidth: Math.max(60, sidebarUserBg.width - 32 - 26)
                                implicitHeight: 32

                                // Cache values at component-completed time so
                                // the Texts NEVER lose their content even if
                                // UserProfileService transiently empties.
                                readonly property string _envUser: Quickshell.env("USER") || "user"
                                readonly property string _envHost: Quickshell.env("HOSTNAME") || ""
                                readonly property string resolvedName: {
                                    // Prefer service value (handles /etc/passwd full names)
                                    if (typeof UserProfileService !== "undefined"
                                        && UserProfileService.userName
                                        && UserProfileService.userName.length > 0) {
                                        return UserProfileService.userName
                                    }
                                    return _envUser
                                }
                                readonly property string resolvedHost: {
                                    if (typeof UserProfileService !== "undefined"
                                        && UserProfileService.hostname
                                        && UserProfileService.hostname.length > 0) {
                                        return UserProfileService.hostname
                                    }
                                    return _envHost
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text {
                                        id: nameText
                                        width: parent.width
                                        text: userTextWrap.resolvedName
                                        color: ThemeService.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: hostText
                                        width: parent.width
                                        text: userTextWrap.resolvedHost.length > 0
                                              ? ("@" + userTextWrap.resolvedHost)
                                              : ""
                                        color: ThemeService.grey0
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                }
                            }
                        }

                        // ═══════════════════════════════════════════════
                        // v6.16.4.12.9.7 (Modori) hotfix: MouseArea +
                        // hover overlay are now SIBLINGS of the RowLayout
                        // (children of the outer sidebarUserBg Rectangle),
                        // NOT children of the RowLayout itself.
                        //
                        // Previous bug: a MouseArea with `anchors.fill:
                        // parent` placed INSIDE a RowLayout devours the
                        // layout flow space — the layout system tries to
                        // include it in horizontal distribution, but
                        // since it has no Layout.* hints and uses
                        // anchors instead, the result is undefined
                        // sizing for ALL siblings. The Item containing
                        // the username/hostname Texts collapsed to 0
                        // width, and the labels rendered as empty even
                        // though the env-fallback resolution was working
                        // perfectly (the Texts had correct .text values
                        // — they just had nowhere to render).
                        //
                        // Lesson: never put non-Layout positioned items
                        // (anchors-based) inside a Layout. They either
                        // get coerced into the layout flow with broken
                        // sizing, or break the flow for everyone else.
                        // ═══════════════════════════════════════════════

                        // Click → jump to User Profile page
                        MouseArea {
                            id: userRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPage = "userprofile"
                        }

                        // Subtle hover highlight
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            border.width: userRowMa.containsMouse ? 1 : 0
                            border.color: ThemeService.alpha(ThemeService.blue, 0.4)
                            Behavior on border.width { NumberAnimation { duration: 120 } }
                        }
                    }

                    // ── Theme status row (preserved from previous footer) ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 6
                        color: ThemeService.alpha(ThemeService.bg2, 0.4)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: ThemeService.blue
                            }

                            Text {
                                text: ThemeService.themeName
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: ThemeService.grey0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // CONTENT AREA
        // ═══════════════════════════════════════════════
        Rectangle {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // When fullscreen, center content with max-width clamp so it doesn't
            // sprawl awkwardly on wide monitors. When windowed, use full width.
            Item {
                id: contentClamp
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.isFullscreen
                       ? Math.min(parent.width - 48, root.contentInnerMaxWidth + 48)
                       : parent.width

                StackLayout {
                    id: pageStack
                    anchors.fill: parent
                    anchors.margins: 0

                    currentIndex: {
                        switch (root.currentPage) {
                            case "general":       return 0
                            case "decoration":    return 1
                            case "animations":    return 2
                            case "themes":        return 3
                            case "displays":      return 4
                            case "input":         return 5    // v6.16.2.3.2-hotfix
                            case "panel":         return 6
                            case "barmodules":    return 7
                            case "sysrow":        return 8
                            case "hotcorners":    return 9    // v7.0.0-alpha.14
                            case "connectivity":  return 10
                            case "notifications": return 11
                            case "battery":       return 12
                            case "userprofile":   return 13
                            case "updates":       return 14
                            case "widgets":       return 15
                            case "wallpaper":     return 16
                            case "plugins":       return 17
                            // v7.0.0-beta.1-hf39 — productivity features
                            case "focusspaces":     return 18
                            case "quicknotes":      return 19
                            case "networkpulse":    return 20
                            case "smartdim":        return 21
                            case "titletranslator": return 22
                            // v7.0.0-beta.1-hf52 — hyprbars
                            case "hyprbars":        return 23
                            // v7.0.0-beta.1-hf79 — game detection
                            case "gaming":          return 24
                            // v7.0.0-beta.1-hf82k — dock (second module surface)
                            case "dock":            return 25
                            // v7.0.0-beta.1-hf82n — default apps + app float rules
                            case "defaultapps":     return 26
                            case "appfloatrules":   return 27
                            // v7.0.0-beta.1-hf82o — desktop icons + widgets
                            case "desktop":         return 28
                            // v7.0.0-beta.1-hf82p — user management
                            case "usermgmt":        return 29
                            // v7.0.0-beta.1-hf95.12 — SDDM login screen
                            case "sddmlogin":       return 30
                            default:              return 0
                        }
                    }

                    GeneralPage { }
                    DecorationPage { }
                    AnimationsPage { }
                    ThemesPage { }
                    DisplaysPage { }
                    InputPage { }
                    PanelPage { }
                    BarModulesPage { }
                    SysRowPage { }
                    HotCornersPage { }                 // v7.0.0-alpha.14 (index 9)
                    ConnectivityPage { }
                    NotificationPage { }
                    BatterySettingsPage { }
                    UserProfilePage { }
                    UpdatesPage { }
                    WidgetsPage { }
                    WallpaperPage { }
                    PluginsPage { }
                    // v7.0.0-beta.1-hf39 — productivity feature pages
                    FocusSpacesPage { }       // index 18
                    QuickNotesPage { }        // index 19
                    NetworkPulsePage { }      // index 20
                    SmartDimPage { }          // index 21
                    TitleTranslatorPage { }   // index 22
                    // v7.0.0-beta.1-hf52 — hyprbars settings
                    HyprbarsSettingsPage { }  // index 23
                    // v7.0.0-beta.1-hf79 — game detection settings
                    GamingPage { }            // index 24
                    // v7.0.0-beta.1-hf82k — dock (second module surface)
                    DockPage { }              // index 25
                    // v7.0.0-beta.1-hf82n — default apps + app float rules
                    DefaultAppsPage { }       // index 26
                    AppFloatRulesPage { }     // index 27
                    // v7.0.0-beta.1-hf82o — desktop icons + widgets
                    DesktopPage { }           // index 28
                    // v7.0.0-beta.1-hf82p — user management
                    UserManagementPage { }    // index 29
                    // v7.0.0-beta.1-hf95.12 — SDDM login screen
                    SddmLoginPage { }         // index 30
                }
            }
        }
    }
    }  // ← v7.0.0-beta.1-hf83: close outer ColumnLayout (full-width header wrapper)

    // ═══════════════════════════════════════════════════════════════
    // v7.0.0-alpha.11-hf4 — Global ColorPickerOverlay
    //
    // Mounted ONCE here as the last child of the ZenSettings root
    // Rectangle so it z-stacks ABOVE all sidebar + content + page
    // elements. Shared across all ColorSwatch components via the
    // ColorPickerState singleton.
    //
    // Anchored to fill the entire ZenSettings panel — guaranteed
    // to stay INSIDE the visible panel bounds (no escape outside
    // the layer-shell surface like the previous Popup approach
    // had).
    // ═══════════════════════════════════════════════════════════════
    ColorPickerOverlay {
        anchors.fill: parent
        z: 9999
    }
}

