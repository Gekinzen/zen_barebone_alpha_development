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

    color: ThemeService.alpha(ThemeService.bg0, 0.96)
    // v6.4: honor Theme.styleMode — rounded style gives 22, pill gives 16
    radius: isFullscreen
            ? 0
            : ((PanelState.propagateStyleToModules && Theme.styleMode === "round") ? 22 : 16)
    border.width: isFullscreen ? 0 : 1
    border.color: ThemeService.alpha(ThemeService.fg, 0.12)
    clip: true

    // ── Nav state ──
    property string currentPage: "general"

    // Sidebar structure: header + items. Use null header entries to break
    // the list into sections (APPEARANCE / INPUT & DISPLAY / OTHER).
    readonly property var navItems: [
        { header: "APPEARANCE" },
        { id: "general",     label: "General",            icon: "\uf0c9" },  // bars
        { id: "decoration",  label: "Decoration",         icon: "\uf1fc" },  // paintbrush
        { id: "animations",  label: "Animations",         icon: "\uf021" },  // refresh
        { id: "themes",      label: "Themes",             icon: "\udb80\udd0e" },  // palette 󰔎
        { header: "INPUT & DISPLAY" },
        { id: "displays",    label: "Displays",           icon: "\uf26c" },  // tv
        // v6.16.2.3.2-hotfix: full Input page (mirrors Control Panel
        // → Input tab; same backing service, both stay in sync).
        { id: "input",       label: "Input",              icon: "\uf245" },  // mouse
        { id: "panel",       label: "Panel",              icon: "\uf03a" },  // list
        { id: "barmodules",  label: "Bar Modules",        icon: "\uf017" },  // clock
        { id: "sysrow",     label: "System Tray",        icon: "\uf2db" },  // cpu chip
        { header: "CONNECTIVITY" },
        { id: "connectivity", label: "Sound & Network",   icon: "\uf1eb" },  // wifi
        { id: "notifications", label: "Notifications",    icon: "\uf0f3" },  // bell
        { header: "SYSTEM" },
        // v6.16.0.2: Battery & Power page (previously unregistered — oversight)
        { id: "battery",     label: "Battery & Power",    icon: "\uf240" },  // battery
        // v6.16.4: User Profile — avatar upload + system info
        { id: "userprofile", label: "User Profile",       icon: "\uf007" },  // user
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
        { header: "OTHER" },
        { id: "widgets",     label: "Desktop Widgets",    icon: "\uf1b2" },  // cube
        { id: "wallpaper",   label: "Wallpaper",          icon: "\uf03e" }   // image
    ]

    // Fullscreen-aware sidebar width
    readonly property int sidebarWidth: isFullscreen ? 260 : 220
    readonly property int contentInnerMaxWidth: 1100  // clamp content when fullscreen

    Keys.onEscapePressed: closeRequested()

    RowLayout {
        anchors.fill: parent
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
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // v6.13: Drag handle — covers gear icon + "Settings" text only.
                        // Close/maximize buttons are outside this Item so they stay clickable.
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
                                Text {
                                    visible: navEntry.isHeader
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 4
                                    anchors.bottomMargin: 4
                                    text: navEntry.modelData.header || ""
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
                            radius: 8
                            color: navEntry.active
                                   ? ThemeService.alpha(ThemeService.blue, 0.18)
                                   : (navMouse.containsMouse
                                      ? ThemeService.alpha(ThemeService.fg, 0.06)
                                      : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: navEntry.isHeader ? "" : (navEntry.modelData.icon || "")
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: navEntry.active ? ThemeService.blue : ThemeService.grey0
                                    Layout.preferredWidth: 18
                                }

                                Text {
                                    text: navEntry.isHeader ? "" : (navEntry.modelData.label || "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: navEntry.active ? Font.DemiBold : Font.Normal
                                    color: navEntry.active ? ThemeService.fg : ThemeService.grey0
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
                            case "connectivity":  return 9
                            case "notifications": return 10
                            case "battery":       return 11   // v6.16.0.2 (was 10)
                            case "userprofile":   return 12   // v6.16.4 (was 11)
                            case "widgets":       return 13
                            case "wallpaper":     return 14
                            case "plugins":       return 15   // v6.16.4.12.6.19 — Hyprland plugins
                            default:              return 0
                        }
                    }

                    GeneralPage { }
                    DecorationPage { }
                    AnimationsPage { }
                    ThemesPage { }
                    DisplaysPage { }
                    InputPage { }                      // v6.16.2.3.2-hotfix (index 5)
                    PanelPage { }
                    BarModulesPage { }
                    SysRowPage { }
                    ConnectivityPage { }
                    NotificationPage { }
                    BatterySettingsPage { }            // v6.16.0.2 (now index 11)
                    UserProfilePage { }                // v6.16.4 (now index 12)
                    WidgetsPage { }
                    WallpaperPage { }
                    PluginsPage { }                    // v6.16.4.12.6.19 (index 15)
                }
            }
        }
    }
}

