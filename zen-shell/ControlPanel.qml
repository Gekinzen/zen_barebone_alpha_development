import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ControlPanel v6.16.1 — Quick Settings Popup
 *
 * v6.16.1 ADDITIONS:
 *   - POWER PROFILE section with 3 pills (Saver/Balanced/Performance)
 *     + Gaming Boost toggle. Hidden when powerprofilesctl unavailable.
 *   - Battery % + charging bolt shown in Power Profile header row
 *     (laptops only — auto-hides on desktops via batteryPresent check).
 *
 * macOS Control Center style. Shows on bar click or Super+C.
 * Features:
 *   - Volume slider (PipeWire via wpctl)
 *   - WiFi toggle + SSID + signal
 *   - Bluetooth toggle + connected device name
 *   - LAN status (auto-detect ethernet)
 *   - CPU temp + RAM usage row (from SystemMonitorService)
 *   - Expand arrow (▾) to show full connectivity details
 *   - Draggable by header
 *   - No auto-close on click outside (stays open like Settings panel)
 *
 * Closes via: ✕ button, Esc, or toggle keybind (Super+C)
 *
 * Layout:
 * ┌──────────────────────────────────┐
 * │ ☰ Quick Settings            ✕   │  ← drag handle on title
 * ├──────────────────────────────────┤
 * │ 🔊 ━━━━━━━━━━━━━━━━━━━━━ 75%   │  ← volume slider
 * │ 🎤 ━━━━━━━━━━━━━━━━━━━━━ 100%  │  ← mic slider
 * ├──────────────────────────────────┤
 * │ 📶 WiFi  HomeNetwork    [on]    │
 * │ 🔵 BT    AirPods Pro    [on]    │
 * │ 🔌 LAN   enp5s0         [up]    │
 * ├──────────────────────────────────┤
 * │ 🌡 CPU 42°C  │  RAM 23.4/128GB │
 * │ 🎮 GPU 38°C  │  VRAM 2.1/16GB  │
 * ├──────────────────────────────────┤
 * │            ▾ Expand              │  ← expand arrow
 * └──────────────────────────────────┘
 *
 * Expanded state shows WiFi network list and BT device list.
 */
Rectangle {
    id: root

    signal closeRequested()
    property bool expanded: false
    property bool hasBeenDragged: false

    // v6.16.1.10: Cascade-to-side mode. When expanded content would push
    // the panel past `maxSingleHeight`, split layout into two columns:
    //   Left column (380px): original mainLayout (audio / conn / sysinfo
    //   / power profile). Right column (380px): expandedSection (tabs).
    // Windows Start Menu style — instead of truncating at the bottom, the
    // extra content folds out to the right.
    //
    // v6.16.1.11 CIRCULAR DEPENDENCY FIX:
    //   v6.16.1.10 had: cascadeMode → expandedHeight → implicitHeight
    //                   → root.height → cascadeMode (LOOP).
    //   Result: on expand, recalc ran forever, panel height grew
    //   uncontrollably downward in a runaway feedback loop.
    //   Fix: use a FIXED constant for the expanded section's reserved
    //   height — don't derive it from root.height. Cascade decision then
    //   uses stable inputs (mainLayout.implicitHeight + constant).
    // v7.0.0-beta.1-hf99zk: responsive — on shorter screens the single-column
    // limit drops, so the panel switches to the 2-column cascade sooner
    // instead of growing past the display.
    readonly property int maxSingleHeight: {
        const sh = (parent && parent.height > 0) ? parent.height : 1080
        return Math.max(520, Math.min(720, sh - 120))
    }
    // v7.0.0-beta.1-hf99h: RESPONSIVE width. The panel lives in a
    // full-screen PanelWindow, so `parent.width` is the screen width.
    // Target ~half the screen, clamped to a readable band, so it shrinks
    // on small resolutions and never overflows.
    readonly property int columnWidth: {
        var sw = (parent && parent.width > 0) ? parent.width : 1920
        return Math.round(Math.max(440, Math.min(700, sw * 0.5)))
    }
    // v7.0.0-beta.1-hf99zo: "Glass — Advanced" card treatment for this panel.
    readonly property bool glassLook: PanelState.lookApplyControlPanel && LookService.activeLook === "glass"
    readonly property int expandedReservedHeight: 380   // fixed, not derived
    readonly property bool cascadeMode:
        expanded && (baseHeight + expandedReservedHeight + 16 > maxSingleHeight)

    width: cascadeMode ? (columnWidth * 2 + 2) : columnWidth
    height: {
        if (!expanded) return baseHeight
        if (cascadeMode) return Math.max(baseHeight, expandedReservedHeight + 32)
        return Math.min(maxSingleHeight, baseHeight + expandedReservedHeight + 16)
    }

    readonly property int baseHeight: mainLayout.implicitHeight + 32
    // v6.16.1.11: expandedHeight now references the fixed constant so
    // nothing derives its size from root.height. Retained for code
    // readability elsewhere in the file.
    readonly property int expandedHeight: expandedReservedHeight + 16

    // v8: glass-sync — follow the panel's custom background color +
    // opacity when set (same as the bar / dock / start menu), else theme.
    color: PanelState.bgOverrideEnabled
           ? Qt.rgba(PanelState.bgOverrideColor.r, PanelState.bgOverrideColor.g, PanelState.bgOverrideColor.b, PanelState.controlPanelOpacity)
           : LookService.surfaceColor(ThemeService.bg0, PanelState.controlPanelOpacity)
    radius: 16
    // v7.0.0-beta.1-hf99j: in attached mode, square the two corners that
    // touch the bar so the panel reads as connected to it (Caelestia-style).
    readonly property bool _attachedTop: PanelState.controlPanelAttached && !hasBeenDragged && PanelState.isTop
    readonly property bool _attachedBottom: PanelState.controlPanelAttached && !hasBeenDragged && PanelState.isBottom
    topLeftRadius: _attachedTop ? 0 : radius
    topRightRadius: _attachedTop ? 0 : radius
    bottomLeftRadius: _attachedBottom ? 0 : radius
    bottomRightRadius: _attachedBottom ? 0 : radius
    border.width: 1
    border.color: ThemeService.alpha(ThemeService.fg, LookService.borderAlpha)

    // v7.0.0-beta.1-hf53 — HyprbarsMimic was here.
    // v7.0.0-beta.1-hf64 — REMOVED per user request.
    //
    // User wants the original header (drag handle + fullscreen +
    // close button) to ALWAYS show on the Hypr Control Panel, even
    // when hyprbars is enabled. The mimic was confusing — replace-
    // ing the familiar header with traffic lights felt inconsistent.
    //
    // The real hyprbars plugin handles regular Hyprland windows.
    // Zen Shell popups keep their native Zen header style.
    //
    // HyprbarsMimic instance removed. hyprbarsMimic references
    // below replaced with { visible: false, height: 0 } shim.
    QtObject {
        id: hyprbarsMimic
        property bool visible: false
        property int height: 0
    }
    clip: true

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // v6.16.1.10: vertical divider visible only in cascade mode,
    // separates the two column panels for visual clarity.
    Rectangle {
        visible: root.cascadeMode
        x: root.columnWidth
        y: 12
        width: 1
        height: root.height - 24
        color: ThemeService.alpha(ThemeService.fg, 0.08)
        opacity: root.cascadeMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Keys.onEscapePressed: closeRequested()

    // v7.0.0-alpha.10-hf4: Absorb scroll wheel events at the CC root
    // level. Without this, scroll wheel events on the CC's layer-shell
    // surface were causing focus dance with WlrKeyboardFocus.OnDemand —
    // user reported "scroll ko nag close siya sabay nag open lage kada
    // scroll ko" (CC closes then reopens on every scroll). The handler
    // accepts every wheel event so it never propagates to the layer-
    // shell focus subsystem. Children that genuinely need scroll
    // (ScrollViews inside CC sections) still get their events because
    // they're INSIDE this handler — the handler only catches wheels
    // that bubble all the way up to the root.
    WheelHandler {
        target: null   // don't redirect — just consume
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            // Swallow — event doesn't propagate further. Children that
            // already handled the event (ScrollViews) will have set
            // event.accepted = true before reaching here, so this is
            // a no-op for them. For the empty CC chrome areas, this
            // prevents the wheel from triggering layer-shell focus
            // changes.
            event.accepted = true
        }
    }

    GridLayout {
        id: mainLayout
        anchors.top: parent.top
        anchors.left: parent.left
        // v6.16.1.10: in cascade mode, constrain to left column only
        anchors.right: root.cascadeMode ? undefined : parent.right
        width: root.cascadeMode ? (root.columnWidth - 32) : undefined
        anchors.margins: 16
        // v7.0.0-beta.1-hf54: extra top clearance when HyprbarsMimic
        // is visible so content sits below the mimic bar instead of
        // overlapping it. hyprbarsMimic.height = HyprbarsService.barHeight
        // when visible, 0 when hidden.
        anchors.topMargin: 16 + (hyprbarsMimic.visible ? hyprbarsMimic.height + 4 : 0)
        // v7.0.0-beta.1-hf99zj: a 1-column GridLayout so each section can be
        // placed by Layout.row → drag-to-reorder without moving any code.
        columns: 1
        rowSpacing: 12
        columnSpacing: 0

        // ═══════════════════════════════════════════════
        // HEADER — drag handle + close button
        //
        // v7.0.0-beta.1-hf64: always visible. Previously hidden
        // when HyprbarsMimic was showing. Now mimic is removed
        // from ControlPanel — native header always stays.
        // ═══════════════════════════════════════════════
        Item {
            Layout.row: 0
            Layout.column: 0
            visible: true
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            RowLayout {
                anchors.fill: parent
                spacing: 8

                // Drag handle area (icon + title)
                // v7.0.0-alpha.7-hf3: SearchBar removed from CC header.
                // CC has limited horizontal space (320px column) which
                // can't fit search bar + close button + drag handle.
                // Use Ctrl+F overlay (works system-wide) to search CC
                // entries — same SettingsSearchService backend, just
                // accessed via overlay instead of inline bar.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "\uf0c9"  // bars/hamburger
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: ThemeService.blue
                        }

                        // v7.0.0-alpha.11: Densho mode bilingual title.
                        // 操 (sou) = "operation/control", per the Densho
                        // naming convention (one kanji per major surface).
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                visible: DenshoService.denshoMode
                                text: "操"
                                font.family: "Noto Sans CJK JP"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: ThemeService.alpha(ThemeService.fg, 0.55)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: "Quick Settings"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: ThemeService.fg
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: root
                        drag.axis: Drag.XAndYAxis
                        preventStealing: true
                        onPressed: root.hasBeenDragged = true
                    }
                }

                // Spacer to push search + close to right
                // v7.0.0-alpha.7-hf3: search bar removed from CC header.
                // CC has tight horizontal space (compact 320px panel) —
                // a 240px search bar plus close button plus drag handle
                // didn't fit cleanly. Use Ctrl+F overlay (system-wide
                // global modal) to search Control Center entries —
                // same SettingsSearchService backend, surfaces all
                // CC entries with `surface: "controlpanel"` filter
                // applied automatically.

                // v7.0.0-beta.1-hf99zj: toggle the section-order editor
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: (root.expanded && root.expandedTab === "layout")
                           ? ThemeService.alpha(ThemeService.blue, 0.25)
                           : (editMouse.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent")

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: "\uf0dc"   // sort / reorder
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: (root.expanded && root.expandedTab === "layout") ? ThemeService.blue : ThemeService.grey0
                    }

                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.expanded && root.expandedTab === "layout") {
                                root.expanded = false
                            } else {
                                root.expandedTab = "layout"
                                root.expanded = true
                            }
                        }
                    }
                }

                // Close button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: closeMouse.containsMouse
                           ? ThemeService.alpha(ThemeService.red, 0.2)
                           : "transparent"

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: "\uf00d"  // ✕
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: closeMouse.containsMouse ? ThemeService.red : ThemeService.grey0
                    }

                    MouseArea {
                        id: closeMouse
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
            Layout.row: 1
            Layout.column: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: ThemeService.alpha(ThemeService.fg, 0.08)
        }

        // ═══════════════════════════════════════════════
        // v8: system/user info card (merged from dashboard) — avatar,
        // user@host, distro, Hyprland + Zen version, uptime, date/time,
        // weather, and a DND toggle. Glass surfaces via the section.
        // ═══════════════════════════════════════════════
        SettingsSection {
            Layout.row: PanelState.qsProfileAtBottom ? 18 : (2 + PanelState.qsRowFor("profile"))
            Layout.column: 0
            glass: root.glassLook
            id: infoCard
            property var now: new Date()
            Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: infoCard.now = new Date() }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // avatar circle (same source as start menu / control center)
                Rectangle {
                    Layout.preferredWidth: 58; Layout.preferredHeight: 58
                    radius: 29; clip: true
                    color: ThemeService.alpha(ThemeService.fg, 0.10)
                    border.color: ThemeService.alpha(ThemeService.fg, 0.15); border.width: 1
                    Image {
                        anchors.fill: parent; anchors.margins: 2
                        source: (typeof UserProfileService !== "undefined") ? UserProfileService.effectiveAvatarSource : ""
                        visible: source != ""
                        fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true
                        asynchronous: true; cache: false; sourceSize: Qt.size(64, 64)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        visible: (typeof UserProfileService === "undefined") || UserProfileService.effectiveAvatarSource == ""
                        text: (typeof UserProfileService !== "undefined" && UserProfileService.userName.length > 0)
                              ? UserProfileService.userName.charAt(0).toUpperCase() : "?"
                        color: ThemeService.fg; font.pixelSize: 22; font.bold: true; font.family: Theme.fontFamily
                    }
                }

                // user + versions + uptime
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: UserProfileService.userName + (UserProfileService.hostname ? "@" + UserProfileService.hostname : "")
                        color: ThemeService.fg; font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: UserProfileService.osName + (UserProfileService.osVersion ? " " + UserProfileService.osVersion : "")
                           color: ThemeService.grey1; font.pixelSize: 11; font.family: Theme.fontFamily }
                    // v7.0.0-beta.1-hf99zo: slim profile bar when moved to the bottom
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         visible: !PanelState.qsProfileAtBottom
                           text: "Hyprland " + (UserProfileService.hyprlandVersion || "?")
                           color: ThemeService.grey1; font.pixelSize: 11; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "Zen Shell " + ZenVersion.version + " · " + ZenVersion.channel; color: ThemeService.blue; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: "up " + UserProfileService.uptime; visible: UserProfileService.uptime.length > 0
                           color: ThemeService.grey2; font.pixelSize: 10; font.family: Theme.fontFamily }
                }

                // weather + date/time + DND
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop; spacing: 3
                    RowLayout {
                        Layout.alignment: Qt.AlignRight; spacing: 6
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: (WeatherService.temperature) + "\u00b0"; color: ThemeService.fg; font.pixelSize: 18; font.bold: true; font.family: Theme.fontFamily }
                        // DND toggle
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                            color: NotificationService.dndEnabled ? ThemeService.alpha(ThemeService.red, 0.24) : ThemeService.alpha(ThemeService.fg, 0.08)
                            border.color: NotificationService.dndEnabled ? ThemeService.red : ThemeService.alpha(ThemeService.fg, 0.15); border.width: 1
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: NotificationService.dndEnabled ? "\uf1f6" : "\uf0f3"
                                   font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                   color: NotificationService.dndEnabled ? ThemeService.red : ThemeService.grey1 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.dndEnabled = !NotificationService.dndEnabled }
                        }
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: WeatherService.condition; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignRight }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: Qt.formatDateTime(infoCard.now, "ddd, MMM d"); color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignRight }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: Qt.formatDateTime(infoCard.now, "HH:mm"); color: ThemeService.grey1; font.pixelSize: 11; font.family: "monospace"; Layout.alignment: Qt.AlignRight }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // v7.0.0-beta.1-hf99d: Big weather widget (icon + 7-day forecast)
        // Additive card in Quick Settings. Binds to WeatherService
        // (current conditions + daily forecast). Themed to match the
        // panel (ThemeService colours, not hardcoded white).
        // ═══════════════════════════════════════════════
        // v7.0.0-beta.1-hf99g/h: weather + system stats — side-by-side when
        // the panel is wide enough, auto-STACKED on narrow / small screens.
        GridLayout {
            Layout.row: 2 + PanelState.qsRowFor("weathersys")
            Layout.column: 0
            Layout.fillWidth: true
            columns: root.width >= 620 ? 2 : 1
            rowSpacing: 12
            columnSpacing: 12

        SettingsSection {
            id: weatherCard
            glass: root.glassLook
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            visible: WeatherService.temperature !== 0 || WeatherService.condition !== "Loading..."
            // v7.0.0-beta.1-hf99zl: same behaviour as the desktop widget —
            // tap to expand into the hourly strip + 7-day row.
            property bool wExpanded: false

            // TapHandler (not a MouseArea): SettingsSection's default slot is a
            // ColumnLayout, so an anchored MouseArea would become a layout row.
            // A handler attaches to the content item without taking a slot, and
            // child controls still win the press.
            TapHandler {
                onTapped: weatherCard.wExpanded = !weatherCard.wExpanded
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                // ── Current conditions ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Big emoji icon
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: WeatherService.emojiIcon
                        font.pixelSize: 44
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Temp + condition + location
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: WeatherService.temperature + "\u00b0C"; color: WidgetsState.weatherAccentMode === "default" ? ThemeService.fg : WidgetsState.weatherAccent; font.pixelSize: 30; font.bold: true; font.family: WidgetsState.weatherFont }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: WeatherService.condition; color: ThemeService.grey1; font.pixelSize: 12; font.family: WidgetsState.weatherFont; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: WeatherService.locationName; color: ThemeService.grey2; font.pixelSize: 10; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                    }

                    // Labeled stats (detailed — no guessing which number is what)
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter; spacing: 3
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "Feels " + WeatherService.feelsLike + "\u00b0"; color: ThemeService.grey1; font.pixelSize: 11; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignRight }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "Humidity " + WeatherService.humidity + "%"; color: ThemeService.grey1; font.pixelSize: 11; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignRight }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: "Wind " + WeatherService.windSpeed + " km/h"; color: ThemeService.grey1; font.pixelSize: 11; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignRight }
                    }
                }

                // ── tap hint (collapsed) ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: !weatherCard.wExpanded
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "\u25be tap for hourly + 7-day"
                    color: ThemeService.grey2; font.pixelSize: 9; font.family: WidgetsState.weatherFont
                }

                // ── v7.0.0-beta.1-hf99zl: hourly strip (drag left/right) ──
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: weatherCard.wExpanded && WeatherService.hourly.length > 0
                    text: "Hourly forecast"
                    color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: WidgetsState.weatherFont
                }
                Flickable {
                    visible: weatherCard.wExpanded && WeatherService.hourly.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    contentWidth: qsHourlyRow.width
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: qsHourlyRow
                        spacing: 12
                        Repeater {
                            model: WeatherService.hourly
                            delegate: Column {
                                required property var modelData
                                spacing: 2
                                width: 40
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp + "\u00b0"; color: ThemeService.fg; font.pixelSize: 13; font.bold: true; font.family: WidgetsState.weatherFont }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.horizontalCenter: parent.horizontalCenter; text: modelData.emoji; font.pixelSize: 17 }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.horizontalCenter: parent.horizontalCenter; text: modelData.precip + "%"; color: modelData.precip >= 50 ? WidgetsState.weatherAccent : ThemeService.alpha(WidgetsState.weatherAccent, 0.75); font.pixelSize: 9; font.bold: true; font.family: WidgetsState.weatherFont }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hour; color: ThemeService.grey2; font.pixelSize: 9; font.family: WidgetsState.weatherFont }
                            }
                        }
                    }
                }

                // ── 7-day forecast row (even cells via preferredWidth: 1) ──
                RowLayout {
                    visible: weatherCard.wExpanded
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: {
                            const fc = WeatherService.forecast
                            if (!fc || fc.length === 0) return []
                            return fc.slice(0, 7)
                        }
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 64
                            radius: 8
                            color: index === 0 ? Qt.rgba(WidgetsState.weatherAccent.r, WidgetsState.weatherAccent.g, WidgetsState.weatherAccent.b, 0.16) : ThemeService.alpha(ThemeService.fg, 0.04)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, index === 0 ? 0.15 : 0.06)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: modelData.day || "?"; color: index === 0 ? ThemeService.fg : ThemeService.grey1; font.pixelSize: 9; font.bold: true; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignHCenter }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: modelData.emoji || "\u2601\ufe0f"; font.pixelSize: 16; Layout.alignment: Qt.AlignHCenter }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: (modelData.maxTemp !== undefined ? modelData.maxTemp : "--") + "\u00b0/" + (modelData.minTemp !== undefined ? modelData.minTemp : "--") + "\u00b0"; color: ThemeService.fg; font.pixelSize: 9; font.family: "monospace"; Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }

                    // Loading fallback (forecast not yet fetched)
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        visible: !WeatherService.forecast || WeatherService.forecast.length === 0
                        text: "Loading forecast\u2026"
                        color: ThemeService.grey2; font.pixelSize: 11; font.family: Theme.fontFamily
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        SettingsSection {
            id: sysSection
            glass: root.glassLook
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            property int sysView: 1
            // v7.0.0-beta.1-hf99zm: mirror the desktop System Monitor design.
            readonly property bool _pills: WidgetsState.sysmonStyle === "pills"
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                         text: SystemMonitorService.cpuTemp > 0 ? ("CPU " + SystemMonitorService.cpuTemp + "\u00b0  \u00b7  GPU " + SystemMonitorService.gpuTemp + "\u00b0") : ""
                           color: ThemeService.grey1; font.pixelSize: 10; font.family: "monospace" }
                    Rectangle {
                        visible: !sysSection._pills
                        Layout.leftMargin: 8; Layout.preferredWidth: 56; Layout.preferredHeight: 22; radius: 11
                        color: ThemeService.alpha(ThemeService.fg, 0.08); border.color: ThemeService.alpha(ThemeService.fg, 0.15); border.width: 1
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             anchors.centerIn: parent; text: sysSection.sysView === 0 ? "bars" : "detail"; color: ThemeService.blue; font.pixelSize: 10; font.bold: true; font.family: WidgetsState.sysmonFont }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sysSection.sysView = (sysSection.sysView + 1) % 2 }
                    }
                }
                ColumnLayout { Layout.fillWidth: true; spacing: 8; visible: !sysSection._pills && sysSection.sysView === 0
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "CPU"; color: ThemeService.grey1; font.pixelSize: 11; font.family: WidgetsState.sysmonFont; Layout.preferredWidth: 46 }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: ThemeService.alpha(ThemeService.fg, 0.12)
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, (SystemMonitorService.cpuPercent) / 100)); height: parent.height; radius: parent.radius
                                    color: WidgetsState.sysmonAccentFor(SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)); Behavior on width { NumberAnimation { duration: 300 } } } }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: Math.round(SystemMonitorService.cpuPercent) + "%"; color: ThemeService.fg; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "GPU"; color: ThemeService.grey1; font.pixelSize: 11; font.family: WidgetsState.sysmonFont; Layout.preferredWidth: 46 }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: ThemeService.alpha(ThemeService.fg, 0.12)
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, (SystemMonitorService.gpuUsage) / 100)); height: parent.height; radius: parent.radius
                                    color: WidgetsState.sysmonAccentFor(SystemMonitorService.usageColor(SystemMonitorService.gpuUsage)); Behavior on width { NumberAnimation { duration: 300 } } } }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: Math.round(SystemMonitorService.gpuUsage) + "%"; color: ThemeService.fg; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "RAM"; color: ThemeService.grey1; font.pixelSize: 11; font.family: WidgetsState.sysmonFont; Layout.preferredWidth: 46 }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: ThemeService.alpha(ThemeService.fg, 0.12)
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, (SystemMonitorService.ramPercent) / 100)); height: parent.height; radius: parent.radius
                                    color: WidgetsState.sysmonAccentFor(SystemMonitorService.usageColor(SystemMonitorService.ramPercent)); Behavior on width { NumberAnimation { duration: 300 } } } }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: Math.round(SystemMonitorService.ramPercent) + "%"; color: ThemeService.fg; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "VRAM"; color: ThemeService.grey1; font.pixelSize: 11; font.family: WidgetsState.sysmonFont; Layout.preferredWidth: 46 }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: ThemeService.alpha(ThemeService.fg, 0.12)
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, ((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0)) / 100)); height: parent.height; radius: parent.radius
                                    color: WidgetsState.sysmonAccentFor(SystemMonitorService.usageColor((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0))); Behavior on width { NumberAnimation { duration: 300 } } } }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: Math.round((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0)) + "%"; color: ThemeService.fg; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                        }
                }
                ColumnLayout { Layout.fillWidth: true; spacing: 12; visible: !sysSection._pills && sysSection.sysView === 1
                    RowLayout { Layout.fillWidth: true; spacing: 14
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\uf2db"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: ThemeService.grey1; Layout.alignment: Qt.AlignVCenter }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: SystemMonitorService.cpuName; color: ThemeService.grey1; font.pixelSize: 10; font.family: WidgetsState.sysmonFont; elide: Text.ElideRight; Layout.fillWidth: true }
                                RowLayout { spacing: 6
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: Math.round(SystemMonitorService.cpuPercent) + "%"; color: WidgetsState.sysmonAccentFor(SystemMonitorService.usageColor(SystemMonitorService.cpuPercent)); font.bold: true; font.pixelSize: 14; font.family: WidgetsState.sysmonFont }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: (SystemMonitorService.cpuTemp) + "\u00b0"; color: SystemMonitorService.tempColor(SystemMonitorService.cpuTemp); font.pixelSize: 11; font.family: WidgetsState.sysmonFont; visible: (SystemMonitorService.cpuTemp) > 0 } }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "CPU"; color: ThemeService.grey2; font.pixelSize: 9; font.family: "monospace" } }
                        }
                        // v7.0.0-beta.1-hf99c: vertical divider between the two columns
                        ZenDivider { Layout.alignment: Qt.AlignVCenter; heightRatio: 0.8 }
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\uf1b2"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: ThemeService.grey1; Layout.alignment: Qt.AlignVCenter }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: SystemMonitorService.gpuName; color: ThemeService.grey1; font.pixelSize: 10; font.family: WidgetsState.sysmonFont; elide: Text.ElideRight; Layout.fillWidth: true }
                                RowLayout { spacing: 6
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: Math.round(SystemMonitorService.gpuUsage) + "%"; color: WidgetsState.sysmonAccentFor(SystemMonitorService.usageColor(SystemMonitorService.gpuUsage)); font.bold: true; font.pixelSize: 14; font.family: WidgetsState.sysmonFont }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: (SystemMonitorService.gpuTemp) + "\u00b0"; color: SystemMonitorService.tempColor(SystemMonitorService.gpuTemp); font.pixelSize: 11; font.family: WidgetsState.sysmonFont; visible: (SystemMonitorService.gpuTemp) > 0 } }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "GPU"; color: ThemeService.grey2; font.pixelSize: 9; font.family: "monospace" } }
                        }
                    }
                    Rectangle { visible: false; Layout.fillWidth: true; Layout.preferredHeight: 1; color: ThemeService.alpha(ThemeService.fg, 0.10) }
                    RowLayout { Layout.fillWidth: true; spacing: 14
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\uefc5"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: ThemeService.grey1; Layout.alignment: Qt.AlignVCenter }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "RAM"; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                                RowLayout { spacing: 6
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: Math.round(SystemMonitorService.ramPercent) + "%"; color: SystemMonitorService.usageColor(SystemMonitorService.ramPercent); font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily }
                                     }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: SystemMonitorService.ramUsedGb.toFixed(1) + "/" + SystemMonitorService.ramTotalGb.toFixed(0) + " GB"; color: ThemeService.grey2; font.pixelSize: 9; font.family: "monospace" } }
                        }
                        // v7.0.0-beta.1-hf99c: vertical divider between the two columns
                        ZenDivider { Layout.alignment: Qt.AlignVCenter; heightRatio: 0.8 }
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 10
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 text: "\uefc5"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: ThemeService.grey1; Layout.alignment: Qt.AlignVCenter }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: "VRAM"; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                                RowLayout { spacing: 6
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: Math.round((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0)) + "%"; color: SystemMonitorService.usageColor((SystemMonitorService.gpuVramTotal > 0 ? SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100 : 0)); font.bold: true; font.pixelSize: 14; font.family: Theme.fontFamily }
                                     }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     text: SystemMonitorService.gpuVramUsed.toFixed(1) + "/" + SystemMonitorService.gpuVramTotal.toFixed(0) + " GB"; color: ThemeService.grey2; font.pixelSize: 9; font.family: "monospace" } }
                        }
                    }
                }

                // ── v7.0.0-beta.1-hf99zm: compact Pills row (mirrors the
                // desktop "Pills (Pixel)" System Monitor design) ──
                RowLayout {
                    visible: sysSection._pills
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "CPU",  glyph: "\uf2db", accent: "#1268d3", pct: SystemMonitorService.cpuPercent,
                              sub: SystemMonitorService.cpuTemp > 0 ? (SystemMonitorService.cpuTemp + "\u00b0") : "\u2014" },
                            { label: "GPU",  glyph: "\uf1b2", accent: "#1e8e3e", pct: SystemMonitorService.gpuUsage,
                              sub: SystemMonitorService.gpuTemp > 0 ? (SystemMonitorService.gpuTemp + "\u00b0") : "\u2014" },
                            { label: "RAM",  glyph: "\uefc5", accent: "#1a56db", pct: SystemMonitorService.ramPercent,
                              sub: SystemMonitorService.ramUsedGb.toFixed(1) + "G" },
                            { label: "VRAM", glyph: "\uefc5", accent: "#7c3aed",
                              pct: (SystemMonitorService.gpuVramTotal > 0 ? Math.round(SystemMonitorService.gpuVramUsed / SystemMonitorService.gpuVramTotal * 100) : 0),
                              sub: SystemMonitorService.gpuVramUsed.toFixed(1) + "G" }
                        ]
                        delegate: Rectangle {
                            id: qsPill
                            required property var modelData
                            readonly property color _accent: WidgetsState.sysmonAccentFor(modelData.accent)
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Math.min(width, height) / 2
                            antialiasing: true
                            color: LookService.surfaceColor(ThemeService.bg2, 0.55)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                spacing: 3

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 26; height: 26; radius: 13
                                    color: qsPill._accent
                                    antialiasing: true
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.centerIn: parent; text: qsPill.modelData.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#ffffff" }
                                }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsPill.modelData.label
                                    color: qsPill._accent; font.pixelSize: 9; font.bold: true; font.family: WidgetsState.sysmonFont
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 1
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: qsPill.modelData.pct; color: qsPill._accent; font.pixelSize: 20; font.bold: true; font.family: WidgetsState.sysmonFont }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         anchors.top: parent.top; text: "%"; color: qsPill._accent; font.pixelSize: 9; font.bold: true; font.family: WidgetsState.sysmonFont }
                                }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsPill.modelData.sub
                                    color: ThemeService.grey2; font.pixelSize: 9; font.family: WidgetsState.sysmonFont
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 10; height: 5; radius: 2.5
                                    color: ThemeService.alpha(ThemeService.fg, 0.12)
                                    antialiasing: true
                                    Rectangle {
                                        width: Math.max(parent.height, parent.width * Math.min(1, qsPill.modelData.pct / 100))
                                        height: parent.height; radius: parent.radius
                                        color: qsPill._accent
                                        antialiasing: true
                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }
        }
        Rectangle { visible: false; Layout.fillWidth: true; Layout.preferredHeight: 1; color: ThemeService.alpha(ThemeService.fg, 0.10) }

        // ═══════════════════════════════════════════════
        // v7.0.0-beta.1-hf99h: big time/date + calendar grid (responsive)
        // ═══════════════════════════════════════════════
        GridLayout {
            Layout.row: 2 + PanelState.qsRowFor("timecal")
            Layout.column: 0
            Layout.fillWidth: true
            columns: root.width >= 620 ? 2 : 1
            rowSpacing: 12
            columnSpacing: 12

            // ── Big time / date ──
            SettingsSection {
                id: timeCard
                glass: root.glassLook
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // v7.0.0-beta.1-hf99zm: Analog (Pixel) design mirrors here too.
                    WavyAnalogClock {
                        visible: WidgetsState.clockStyle === "analog"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 132
                        hours: infoCard.now.getHours()
                        minutes: infoCard.now.getMinutes()
                        dayLabel: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][infoCard.now.getDay()] + " " + infoCard.now.getDate()
                    }

                    // v7.0.0-beta.1-hf99zj: mirrors the desktop clock design
                    // (stacked / mono / …) and its font, via WidgetsState.
                    Text {
                        visible: WidgetsState.clockStyle !== "analog"
                        readonly property string _cs: WidgetsState.clockStyle
                        text: _cs === "stacked"
                              ? Qt.formatDateTime(infoCard.now, "HH") + "\n" + Qt.formatDateTime(infoCard.now, "mm")
                              : Qt.formatDateTime(infoCard.now, "HH:mm")
                        lineHeight: _cs === "stacked" ? 0.82 : 1.0
                        color: ThemeService.fg
                        font.pixelSize: 48
                        font.bold: true
                        font.family: _cs === "mono" ? "JetBrainsMono Nerd Font" : WidgetsState.clockFont
                        style: _cs === "raised" ? Text.Raised : Text.Normal
                        styleColor: Qt.rgba(0, 0, 0, 0.45)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        visible: WidgetsState.clockStyle !== "analog"
                        text: Qt.formatDateTime(infoCard.now, "dddd")
                        color: ThemeService.blue; font.pixelSize: 15; font.bold: true; font.family: WidgetsState.clockFont
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: Qt.formatDateTime(infoCard.now, "d MMMM yyyy")
                        color: ThemeService.grey1; font.pixelSize: 12; font.family: WidgetsState.clockFont
                    }
                }
            }

            // ── Calendar month grid ──
            SettingsSection {
                id: calendarCard
                glass: root.glassLook
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop

                // v7.0.0-beta.1-hf99zm: browsable month. The VIEWED month is
                // state (_y/_m); "today" is still derived from the live clock so
                // the highlight only shows when you're looking at this month.
                readonly property int _todayY: infoCard.now.getFullYear()
                readonly property int _todayM: infoCard.now.getMonth()
                // NOTE: no leading underscore — QML derives the change handler
                // from the property name, and `_d` would need `on_DChanged`.
                readonly property int todayD: infoCard.now.getDate()
                property int _y: _todayY
                property int _m: _todayM
                readonly property bool _isThisMonth: _y === _todayY && _m === _todayM
                readonly property int _offset: new Date(_y, _m, 1).getDay()     // 0 = Sun
                readonly property int _dim: new Date(_y, _m + 1, 0).getDate()   // days in month
                function _shift(delta) {
                    let m = _m + delta, y = _y
                    while (m < 0)  { m += 12; y -= 1 }
                    while (m > 11) { m -= 12; y += 1 }
                    _m = m; _y = y
                }
                function _today() { _y = _todayY; _m = _todayM }
                // Follow the clock across a month boundary while viewing "today".
                onTodayDChanged: if (_isThisMonth) _today()

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Rectangle {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 6
                            color: prevMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: "\u2039"; color: ThemeService.grey1; font.pixelSize: 14; font.bold: true }
                            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calendarCard._shift(-1) }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: ["January","February","March","April","May","June","July","August","September","October","November","December"][calendarCard._m] + " " + calendarCard._y
                            color: ThemeService.fg; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarCard._today() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 6
                            color: nextMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                 anchors.centerIn: parent; text: "\u203a"; color: ThemeService.grey1; font.pixelSize: 14; font.bold: true }
                            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calendarCard._shift(1) }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 2

                        Repeater {
                            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                            delegate: Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                required property string modelData
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: ThemeService.grey2; font.pixelSize: 9; font.bold: true; font.family: Theme.fontFamily
                            }
                        }

                        Repeater {
                            model: 42
                            delegate: Item {
                                id: dayCell
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                readonly property int _dayNum: index - calendarCard._offset + 1
                                readonly property bool _valid: _dayNum >= 1 && _dayNum <= calendarCard._dim
                                readonly property bool _isToday: _valid && calendarCard._isThisMonth && _dayNum === calendarCard.todayD

                                Rectangle {
                                    visible: dayCell._valid
                                    anchors.centerIn: parent
                                    width: 22; height: 22; radius: 11
                                    antialiasing: true
                                    color: dayCell._isToday ? ThemeService.blue : "transparent"
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        anchors.centerIn: parent
                                        text: dayCell._valid ? dayCell._dayNum : ""
                                        color: dayCell._isToday ? ThemeService.bg0 : ThemeService.fg
                                        font.pixelSize: 10; font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Rectangle { visible: false; Layout.fillWidth: true; Layout.preferredHeight: 1; color: ThemeService.alpha(ThemeService.fg, 0.10) }

        // ═══════════════════════════════════════════════
        // v7.0.0-alpha.13: WORKFLOW PROFILES
        //
        // 5-tile picker for one-click profile switching:
        // Work / Gaming / Focus / Movie / Sleep
        //
        // Each profile bundles brightness + DND + power profile.
        // Active profile gets blue ring. Click to switch.
        // ═══════════════════════════════════════════════
        SettingsSection {
            Layout.row: 2 + PanelState.qsRowFor("workflow")
            Layout.column: 0
            glass: root.glassLook
            title: ""

            WorkflowProfilePicker {
                Layout.fillWidth: true
            }
        }

        // ═══════════════════════════════════════════════
        // VOLUME SECTION — PipeWire sink + mic
        // ═══════════════════════════════════════════════
        SettingsSection {
            Layout.row: 2 + PanelState.qsRowFor("audio")
            Layout.column: 0
            glass: root.glassLook
            title: ""

            // Speaker volume
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Mute toggle icon
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: volIconMouse.containsMouse
                           ? ThemeService.alpha(ThemeService.blue, 0.15)
                           : "transparent"

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: ConnectivityService.audioIcon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: ConnectivityService.audioMuted ? ThemeService.grey2 : ThemeService.blue
                    }

                    MouseArea {
                        id: volIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ConnectivityService.toggleMute()
                    }
                }

                // Volume slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        // hf197 — the sink name is now a DROPDOWN TRIGGER.
                        // Click it → device list unfolds below the slider,
                        // pick a sink → wpctl set-default moves the stream.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            radius: 5
                            color: sinkPickMa.containsMouse
                                   ? ThemeService.alpha(ThemeService.fg, 0.08)
                                   : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                spacing: 3
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    text: ConnectivityService.audioSinkName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeService.grey0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    visible: ConnectivityService.audioSinks.length > 1
                                    text: cpSinkList.expanded ? "\uf077" : "\uf078"   //  chevrons
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    color: ThemeService.grey1
                                }
                            }
                            MouseArea {
                                id: sinkPickMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                ToolTip.visible: containsMouse && ConnectivityService.audioSinks.length > 1
                                ToolTip.delay: 500
                                ToolTip.text: "Choose output device"
                                onClicked: cpSinkList.expanded = !cpSinkList.expanded
                            }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: ConnectivityService.audioVolume + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            // hf197 — boost zone color: >100 orange, >200 red
                            color: ConnectivityService.audioMuted
                                   ? ThemeService.grey2
                                   : (ConnectivityService.audioVolume > 100
                                      ? ConnectivityService.volumeColor(ConnectivityService.audioVolume)
                                      : ThemeService.fg)
                        }
                    }

                    // v7.0.0-beta.1-hf16: replace QQC2 Slider with the
                    // same custom Rectangle-based slider used in the bar
                    // sound popup. Cleaner drag (no binding loop), full
                    // theme control, and visually consistent with the bar
                    // popup so users see one design across the shell.
                    Item {
                        id: volSliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        // hf197 — the track now maps 0..maxVolume (300).
                        // The tick at 1/3 marks the 100% (hardware max) line.
                        readonly property real ratio:
                            Math.max(0, Math.min(1,
                                ConnectivityService.audioVolume / ConnectivityService.maxVolume))

                        // Track background
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.15)
                        }
                        // Filled portion — zone-colored (blue / orange / red)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * volSliderTrack.ratio
                            height: 4; radius: 2
                            color: ConnectivityService.volumeColor(ConnectivityService.audioVolume)
                            Behavior on width { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        // 100% tick — the safe/boost boundary
                        Rectangle {
                            x: parent.width * (100 / ConnectivityService.maxVolume) - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: 10; radius: 1; antialiasing: true
                            color: ThemeService.alpha(ThemeService.fg, 0.45)
                        }
                        // Knob
                        Rectangle {
                            width: 18; height: 18; radius: 9; antialiasing: true
                            y: (parent.height - height) / 2
                            x: Math.max(0, parent.width * volSliderTrack.ratio - width / 2)
                            color: ThemeService.fg
                            border.width: 1
                            border.color: LookService.surfaceColor(ThemeService.bg0, 0.4)
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        // Drag / click area
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function _set(x) {
                                const r = Math.max(0, Math.min(1, x / width))
                                ConnectivityService.setVolume(Math.round(r * ConnectivityService.maxVolume))
                            }
                            onPressed: function(m) { _set(m.x) }
                            onPositionChanged: function(m) {
                                if (pressed) _set(m.x)
                            }
                            onWheel: function(w) {
                                const cur = ConnectivityService.audioVolume
                                const next = w.angleDelta.y > 0
                                             ? Math.min(ConnectivityService.maxVolume, cur + 5)
                                             : Math.max(0, cur - 5)
                                ConnectivityService.setVolume(next)
                                w.accepted = true
                            }
                        }
                    }

                    // ── hf197: OUTPUT DEVICE LIST (collapsed by default) ──
                    // One row per sink; radio-dot marks the default. Click a
                    // row → setDefaultSink() → active streams jump devices.
                    ColumnLayout {
                        id: cpSinkList
                        property bool expanded: false
                        visible: expanded && ConnectivityService.audioSinks.length > 0
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: cpSinkList.expanded ? ConnectivityService.audioSinks : []
                            delegate: Rectangle {
                                id: cpSinkRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                radius: 7
                                color: cpSinkRowMa.containsMouse
                                       ? ThemeService.alpha(ThemeService.blue, 0.12)
                                       : (cpSinkRow.modelData.isDefault
                                          ? ThemeService.alpha(ThemeService.blue, 0.08)
                                          : "transparent")
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: cpSinkRow.modelData.isDefault ? "\uf192" : "\uf10c"  // dot / circle
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: cpSinkRow.modelData.isDefault ? ThemeService.blue : ThemeService.grey2
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: cpSinkRow.modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: cpSinkRow.modelData.isDefault ? ThemeService.fg : ThemeService.grey0
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                                MouseArea {
                                    id: cpSinkRowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ConnectivityService.setDefaultSink(cpSinkRow.modelData.id)
                                        cpSinkList.expanded = false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Microphone volume
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: micIconMouse.containsMouse
                           ? ThemeService.alpha(ThemeService.purple, 0.15)
                           : "transparent"

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: ConnectivityService.micMuted ? "\udb80\ude36" : "\uf130"  // mic off/on
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.purple
                    }

                    MouseArea {
                        id: micIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ConnectivityService.toggleMicMute()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: ConnectivityService.micSourceName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: ConnectivityService.micVolume + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: ConnectivityService.micMuted ? ThemeService.grey2 : ThemeService.fg
                        }
                    }

                    // v7.0.0-beta.1-hf16: same custom slider design as
                    // speaker above + bar popup (consistent across shell).
                    Item {
                        id: micSliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        readonly property real ratio:
                            Math.max(0, Math.min(1,
                                ConnectivityService.micVolume / 100))

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2
                            color: ThemeService.alpha(ThemeService.fg, 0.15)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * micSliderTrack.ratio
                            height: 4; radius: 2
                            color: ConnectivityService.micMuted
                                   ? ThemeService.grey2
                                   : ThemeService.purple
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                        Rectangle {
                            width: 18; height: 18; radius: 9; antialiasing: true
                            y: (parent.height - height) / 2
                            x: Math.max(0, parent.width * micSliderTrack.ratio - width / 2)
                            color: ThemeService.fg
                            border.width: 1
                            border.color: LookService.surfaceColor(ThemeService.bg0, 0.4)
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function _set(x) {
                                const r = Math.max(0, Math.min(1, x / width))
                                ConnectivityService.setMicVolume(Math.round(r * 100))
                            }
                            onPressed: function(m) { _set(m.x) }
                            onPositionChanged: function(m) {
                                if (pressed) _set(m.x)
                            }
                            onWheel: function(w) {
                                const cur = ConnectivityService.micVolume
                                const next = w.angleDelta.y > 0
                                             ? Math.min(100, cur + 5)
                                             : Math.max(0, cur - 5)
                                ConnectivityService.setMicVolume(next)
                                w.accepted = true
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // CONNECTIVITY TOGGLES — WiFi, BT, LAN
        // ═══════════════════════════════════════════════
        SettingsSection {
            Layout.row: 2 + PanelState.qsRowFor("connectivity")
            Layout.column: 0
            glass: root.glassLook
            title: ""

            // WiFi row
            ConnToggleRow {
                icon: ConnectivityService.wifiIcon
                label: "Wi-Fi"
                sublabel: ConnectivityService.wifiConnected
                          ? ConnectivityService.wifiSSID + " (" + ConnectivityService.wifiSignal + "%)"
                          : (ConnectivityService.wifiEnabled ? "Not connected" : "Off")
                active: ConnectivityService.wifiEnabled
                iconColor: ConnectivityService.wifiConnected ? ThemeService.green : ThemeService.grey0
                onToggled: ConnectivityService.toggleWifi()
                onSettingsClicked: ConnectivityService.openWifiSettings()
            }

            // Bluetooth row
            ConnToggleRow {
                icon: ConnectivityService.btIcon
                label: "Bluetooth"
                sublabel: ConnectivityService.btConnected
                          ? ConnectivityService.btConnectedName
                          : (ConnectivityService.btPowered ? "No devices" : "Off")
                active: ConnectivityService.btPowered
                iconColor: ConnectivityService.btConnected ? ThemeService.blue : ThemeService.grey0
                onToggled: ConnectivityService.toggleBluetooth()
                onSettingsClicked: ConnectivityService.openBluetoothSettings()
            }

            // LAN row (status only, no toggle)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 8
                    color: ThemeService.alpha(
                        ConnectivityService.lanConnected ? ThemeService.green : ThemeService.grey2, 0.12)

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.centerIn: parent
                        text: ConnectivityService.lanIcon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: ConnectivityService.lanConnected ? ThemeService.green : ThemeService.grey2
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Ethernet"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: ThemeService.fg
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: ConnectivityService.lanConnected
                              ? ConnectivityService.lanInterface +
                                (ConnectivityService.lanIP ? " · " + ConnectivityService.lanIP : "")
                              : "Not connected"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Status indicator dot
                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: ConnectivityService.lanConnected ? ThemeService.green : ThemeService.grey2
                }
            }
        }

        // ═══════════════════════════════════════════════
        // POWER PROFILE (v6.16.1) — 3 pill buttons + Gaming Boost
        // Hidden when powerprofilesctl isn't installed, so it only
        // shows up on systems that can actually use it.
        // ═══════════════════════════════════════════════
        SettingsSection {
            Layout.row: 2 + PanelState.qsRowFor("power")
            Layout.column: 0
            glass: root.glassLook
            title: ""
            visible: PowerProfileService.available

            // Header row: label + battery % if laptop
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: "\uf0e7  Power Profile"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: ThemeService.grey0
                    Layout.fillWidth: true
                }

                // Battery % on the right (laptops only)
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    visible: SystemMonitorService.batteryPresent
                    text: {
                        const bolt = SystemMonitorService.batteryCharging ? "\uf0e7 " : ""
                        return bolt + SystemMonitorService.batteryCapacity + "%"
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: {
                        if (SystemMonitorService.batteryCharging) return ThemeService.green
                        if (SystemMonitorService.batteryCapacity <= 10) return ThemeService.red
                        if (SystemMonitorService.batteryCapacity <= 30) return ThemeService.orange
                        return ThemeService.grey0
                    }
                }
            }

            // ── Three profile pills ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { id: "power-saver", label: "Saver",       icon: "\uf06c" },
                        { id: "balanced",    label: "Balanced",    icon: "\uf24e" },
                        { id: "performance", label: "Performance", icon: "\uf0e7" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: PowerProfileService.currentProfile === modelData.id
                                                         && !PowerProfileService.gamingBoostActive
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: isActive
                            ? ThemeService.alpha(ThemeService.blue, 0.22)
                            : (pillMouse.containsMouse
                                ? ThemeService.alpha(ThemeService.fg, 0.08)
                                : LookService.surfaceColor(ThemeService.bg2, 0.55))
                        border.width: isActive ? 1 : 0
                        border.color: isActive ? ThemeService.blue : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Switching to a regular profile turns off
                                // gaming boost if it was active
                                if (PowerProfileService.gamingBoostActive) {
                                    PowerProfileService.setGamingBoost(false)
                                }
                                PowerProfileService.setProfile(modelData.id)
                            }
                        }
                    }
                }
            }

            // ── Gaming Boost toggle ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: PowerProfileService.gamingBoostActive
                    ? ThemeService.alpha(ThemeService.red, 0.22)
                    : (boostMouse.containsMouse
                        ? ThemeService.alpha(ThemeService.fg, 0.08)
                        : LookService.surfaceColor(ThemeService.bg2, 0.55))
                border.width: PowerProfileService.gamingBoostActive ? 1 : 0
                border.color: PowerProfileService.gamingBoostActive
                    ? ThemeService.red : "transparent"

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "🎮"
                        font.pixelSize: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: PowerProfileService.gamingBoostActive
                                ? "Gaming Boost ACTIVE"
                                : "Gaming Boost"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: PowerProfileService.gamingBoostActive
                                ? ThemeService.red : ThemeService.fg
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: PowerProfileService.gamingBoostActive
                                ? "Performance + effects OFF · click to restore"
                                : "Performance + disable blur/dim/anim for max FPS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Toggle switch — visual state only. The outer
                    // row-wide MouseArea (boostMouse) handles clicks.
                    // HMSwitch's own MouseArea is gated off via enabled:false
                    // so it doesn't intercept the row click.
                    HMSwitch {
                        compact: true
                        activeColor: ThemeService.alpha(ThemeService.red, 0.85)
                        checked: PowerProfileService.gamingBoostActive
                        // Click handled by parent row — this switch is visual
                        enabled: false
                        opacity: 1.0  // counteract the default disabled look
                    }
                }

                MouseArea {
                    id: boostMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfileService.toggleGamingBoost()
                }
            }

            // ═══════════════════════════════════════════════════════
            // ── Dark Mode toggle (v6.16.4.12.9.8 / Modori) ──
            //
            // Toggles GTK3 + GTK4 + libadwaita color-scheme in one
            // tap. Script `zen-darkmode.sh` is the source of truth
            // for application — this row is just the visual surface
            // and click target. Auto-hides if the script isn't
            // installed yet (the install.sh phase that drops the
            // script may have been skipped on legacy installs).
            //
            // Affects every GTK3/GTK4 application that respects
            // either gsettings or settings.ini — Thunar, Nautilus,
            // GNOME Settings, GIMP (GTK port), Geary, etc. Apps
            // that have their own theme preference (Firefox,
            // Chromium with their own dark mode) are unaffected.
            // ═══════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: DarkModeService.available
                radius: 8
                color: darkmodeMouse.containsMouse
                       ? ThemeService.alpha(ThemeService.fg, 0.08)
                       : LookService.surfaceColor(ThemeService.bg2, 0.55)

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: DarkModeService.isDark ? "🌙" : "☀️"
                        font.pixelSize: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: DarkModeService.isDark ? "Dark Mode" : "Light Mode"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: DarkModeService.isDark
                                  ? "GTK3 / GTK4 / libadwaita apps using dark theme"
                                  : "GTK3 / GTK4 / libadwaita apps using light theme"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: ThemeService.grey1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Visual switch. The outer row MouseArea handles
                    // the click; we gate the switch's own MouseArea
                    // off (enabled:false) so it doesn't intercept.
                    HMSwitch {
                        compact: true
                        activeColor: ThemeService.alpha(ThemeService.blue, 0.85)
                        checked: DarkModeService.isDark
                        enabled: false
                        opacity: 1.0
                    }
                }

                MouseArea {
                    id: darkmodeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DarkModeService.toggle()
                }
            }
        }

        // ═══════════════════════════════════════════════
        // EXPAND ARROW — toggles expanded section
        // ═══════════════════════════════════════════════


        Rectangle {
            Layout.row: 20
            Layout.column: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: expandMouse.containsMouse
                   ? ThemeService.alpha(ThemeService.fg, 0.05) : "transparent"
            radius: 6

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    // v6.16.1.10: different icon/label in cascade mode —
                    // the expansion goes sideways, not down.
                    text: root.expanded
                        ? (root.cascadeMode ? "◂ Collapse" : "▴ Collapse")
                        : "▸ Expand"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.grey1
                }
            }

            MouseArea {
                id: expandMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }

    }

    // ═══════════════════════════════════════════════
    // EXPANDED SECTION — v6.16.1.8 Tabbed UI
    // Previous ScrollView/Flickable approach had layout-resolution
    // issues (expandedSection.implicitHeight bouncing to 0, panel
    // growing in height but content collapsed). Paul also requested
    // tabs for WiFi/Bluetooth separation.
    //
    // New design: three tabs (WiFi / Bluetooth / Audio). Only one tab's
    // content is visible at a time → smaller implicit height, cleaner
    // layout, and the panel's expanded height is predictable.
    // Each tab's content is a Flickable so long lists scroll internally
    // without fighting the panel's own height calc.
    // ═══════════════════════════════════════════════
    property string expandedTab: "wifi"   // wifi | bluetooth | audio

    Item {
        id: expandedSection
        // v6.16.1.10: Cascade mode moves expandedSection to right column.
        // Non-cascade mode keeps original layout (below mainLayout).
        anchors.top: root.cascadeMode ? parent.top : mainLayout.bottom
        anchors.left: root.cascadeMode ? undefined : parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.cascadeMode ? (root.columnWidth - 32) : undefined
        anchors.topMargin: root.cascadeMode ? 16 : 4
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        anchors.leftMargin: root.cascadeMode ? 0 : 16
        clip: true
        visible: root.expanded
        opacity: root.expanded ? 1 : 0
        // v6.16.1.11: FIXED implicitHeight — must not depend on root.height
        // or we get the infinite-loop bug (cascadeMode → height → implicit
        // → cascade). Use anchors.bottom to fill available space in
        // cascade mode; the implicit value here is just the reservation
        // used by the height-calc.
        implicitHeight: root.expandedReservedHeight

        // v6.16.1.10: slide-in from right when cascade mode activates
        transform: Translate {
            x: root.cascadeMode
                ? (root.expanded ? 0 : 40)
                : 0
            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // ── Tab bar ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { id: "wifi",      label: "Wi-Fi",     icon: "\uf1eb" },
                        { id: "bluetooth", label: "Bluetooth", icon: "\uf294" },
                        { id: "audio",     label: "Audio",     icon: "\uf028" },
                        // v6.16.2.3.2: Input tab — mouse sensitivity/scroll
                        // live-controlled via MouseSettingsService.
                        { id: "input",     label: "Input",     icon: "\uf245" },
                        // v7.0.0-beta.1-hf99i: Notifications tab — click to
                        // see recent notifications (reuses NotificationService).
                        { id: "notifs",    label: "Notifs",    icon: "\uf0f3" },
                        // v7.0.0-beta.1-hf99zk: section-order editor lives in the
                        // side panel now (the bottom list made the panel too tall)
                        { id: "layout",    label: "Layout",    icon: "\uf0dc" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: root.expandedTab === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: isActive
                            ? ThemeService.alpha(ThemeService.blue, 0.22)
                            : (tabMouseArea.containsMouse
                                ? ThemeService.alpha(ThemeService.fg, 0.08)
                                : LookService.surfaceColor(ThemeService.bg2, 0.45))
                        border.width: isActive ? 1 : 0
                        border.color: isActive ? ThemeService.blue : "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: parent.parent.isActive ? ThemeService.fg : ThemeService.grey0
                            }
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandedTab = modelData.id
                        }
                    }
                }
            }

            // ── Tab content area ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: LookService.surfaceColor(ThemeService.bg1, 0.5)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.06)
                clip: true

                // ─── WiFi tab ───
                Flickable {
                    id: wifiFlick
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "wifi"
                    contentWidth: wifiFlick.width
                    contentHeight: wifiCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: wifiCol
                        // v6.16.1.9: explicit id ref instead of parent.parent.width
                        // which was unreliable across Quickshell versions.
                        // v6.16.4.12.9.9 (Modori): full WiFi UI redesign —
                        // saved/available split, larger tap targets,
                        // refresh button, forget button, signal-bars icon.
                        width: wifiFlick.width - 24
                        spacing: 4

                        // ── Computed properties for section split ──
                        // Saved networks that are CURRENTLY visible in
                        // the scan results. Hide the saved section
                        // entirely when out of range.
                        readonly property var _savedAndVisible: {
                            const saved = ConnectivityService.savedWifiNetworks || []
                            const visible = ConnectivityService.wifiNetworks || []
                            const visibleSsids = new Set(visible.map(n => n.ssid))
                            return saved.filter(s => visibleSsids.has(s))
                        }
                        // Available (not-saved, not-active) networks.
                        readonly property var _availableNew: {
                            const all = ConnectivityService.wifiNetworks || []
                            const savedSet = new Set(ConnectivityService.savedWifiNetworks || [])
                            return all.filter(n => !savedSet.has(n.ssid) && !n.active)
                        }

                        // ── Refresh button row (always visible when wifi is on) ──
                        RowLayout {
                            visible: ConnectivityService.wifiEnabled
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 8

                            Item { Layout.fillWidth: true }   // spacer

                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 26
                                radius: 6
                                color: wifiRefreshMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.2)
                                    : LookService.surfaceColor(ThemeService.bg2, 0.5)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.08)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf021"   // fa-refresh
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: ThemeService.blue
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "Rescan"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeService.fg
                                    }
                                }

                                MouseArea {
                                    id: wifiRefreshMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.scanWifi()
                                }
                            }
                        }

                        // ── WiFi off state ──
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: !ConnectivityService.wifiEnabled
                            text: "Wi-Fi is off"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.grey1
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }

                        // ── Empty state ──
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.wifiEnabled
                                     && ConnectivityService.wifiNetworks.length === 0
                            text: "Scanning..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.grey1
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }

                        // ═══════════════════════════════════════
                        // SAVED NETWORKS section
                        // ═══════════════════════════════════════
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.wifiEnabled
                                     && wifiCol._savedAndVisible.length > 0
                            text: "SAVED NETWORKS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                        }

                        Repeater {
                            model: ConnectivityService.wifiEnabled
                                   ? wifiCol._savedAndVisible : []

                            Rectangle {
                                id: savedRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8

                                // v8.0.0-alpha-hf177 — one shared predicate for
                                // "am I on this network", so the panel, the rail
                                // and the bar glyph can never disagree again.
                                readonly property bool isActive: ConnectivityService.isConnectedTo(modelData)
                                readonly property bool isBusy:   ConnectivityService.isBusyOn(modelData)
                                readonly property var _scanInfo: {
                                    const list = ConnectivityService.wifiNetworks || []
                                    for (let i = 0; i < list.length; i++) {
                                        if (list[i].ssid === modelData) return list[i]
                                    }
                                    return { signal: 0, security: "" }
                                }

                                color: savedRow.isActive
                                    ? ThemeService.alpha(ThemeService.green, 0.12)
                                    : (savedRowMouse.containsMouse
                                        ? ThemeService.alpha(ThemeService.fg, 0.06)
                                        : LookService.surfaceColor(ThemeService.bg2, 0.4))
                                border.width: savedRow.isActive ? 1 : 0
                                border.color: savedRow.isActive
                                    ? ThemeService.alpha(ThemeService.green, 0.4)
                                    : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: savedRow.isActive ? "\uf00c" : "\uf1eb"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: savedRow.isActive
                                            ? ThemeService.green : ThemeService.blue
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: savedRow.modelData
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            // v8.0.0-alpha-hf177: a tap now says so
                                            // immediately instead of leaving the row
                                            // reading "tap to reconnect" for the 2-4s
                                            // nmcli takes to associate.
                                            text: savedRow.isBusy
                                                ? ConnectivityService.wifiBusyVerb + "\u2026"
                                                : (savedRow.isActive
                                                   ? "\u2713 Connected · " + savedRow._scanInfo.signal + "%"
                                                   : "Saved · tap to reconnect · " + savedRow._scanInfo.signal + "%")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: savedRow.isActive ? Font.DemiBold : Font.Normal
                                            color: savedRow.isBusy
                                                ? ThemeService.blue
                                                : (savedRow.isActive
                                                   ? ThemeService.green : ThemeService.grey1)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Forget button
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 6
                                        color: forgetMouse.containsMouse
                                            ? ThemeService.alpha(ThemeService.red, 0.18)
                                            : "transparent"

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            anchors.centerIn: parent
                                            text: "\uf2ed"   // fa-trash
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: forgetMouse.containsMouse
                                                ? ThemeService.red : ThemeService.grey1
                                        }

                                        MouseArea {
                                            id: forgetMouse
                                            anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ConnectivityService.forgetWifi(savedRow.modelData)
                                        }
                                    }
                                }

                                // Row click → reconnect (entire row except forget btn)
                                MouseArea {
                                    id: savedRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    anchors.rightMargin: 38
                                    hoverEnabled: true
                                    cursorShape: savedRow.isActive
                                        ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    enabled: !savedRow.isActive
                                    onClicked: ConnectivityService.reconnectWifi(savedRow.modelData)
                                }
                            }
                        }

                        // ═══════════════════════════════════════
                        // AVAILABLE NETWORKS section
                        // ═══════════════════════════════════════
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.wifiEnabled
                                     && wifiCol._availableNew.length > 0
                            text: "AVAILABLE NETWORKS"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                        }

                        Repeater {
                            model: ConnectivityService.wifiEnabled
                                   ? wifiCol._availableNew : []

                            Rectangle {
                                id: availRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8

                                color: availRowMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.fg, 0.06)
                                    : LookService.surfaceColor(ThemeService.bg2, 0.4)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    // Signal-strength colored icon
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf1eb"   // fa-wifi
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: {
                                            const s = availRow.modelData.signal
                                            if (s >= 60) return ThemeService.green
                                            if (s >= 35) return ThemeService.yellow
                                            return ThemeService.grey1
                                        }
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: availRow.modelData.ssid
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            // v8.0.0-alpha-hf177 — acknowledge the tap.
                                            text: ConnectivityService.isBusyOn(availRow.modelData.ssid)
                                                  ? ConnectivityService.wifiBusyVerb + "\u2026"
                                                  : availRow.modelData.signal + "% · "
                                                    + (availRow.modelData.security
                                                       && availRow.modelData.security.length > 0
                                                       ? availRow.modelData.security : "Open")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: ConnectivityService.isBusyOn(availRow.modelData.ssid)
                                                   ? ThemeService.blue : ThemeService.grey1
                                        }
                                    }

                                    // Lock icon for secured networks
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf023"   // fa-lock
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: ThemeService.grey1
                                        visible: availRow.modelData.security
                                                 && availRow.modelData.security.length > 0
                                    }
                                }

                                MouseArea {
                                    id: availRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.connectWifi(
                                        availRow.modelData.ssid, availRow.modelData.security)
                                }
                            }
                        }
                    }
                }

                // ─── Bluetooth tab ───
                Flickable {
                    id: btFlick
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "bluetooth"
                    contentWidth: btFlick.width
                    contentHeight: btCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: btCol
                        // v6.16.1.9: explicit id ref
                        // v6.16.4.12.9.9 (Modori): full BT UI redesign —
                        // connected/paired/nearby split, scan toggle,
                        // pair button, larger tap targets.
                        width: btFlick.width - 24
                        spacing: 6

                        // ── Scan toggle button row (when BT is on) ──
                        RowLayout {
                            visible: ConnectivityService.btPowered
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 8

                            Item { Layout.fillWidth: true }   // spacer

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 26
                                radius: 6
                                color: btScanMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.25)
                                    : (ConnectivityService.btScanning
                                        ? ThemeService.alpha(ThemeService.blue, 0.18)
                                        : LookService.surfaceColor(ThemeService.bg2, 0.5))
                                border.width: ConnectivityService.btScanning ? 1 : 1
                                border.color: ConnectivityService.btScanning
                                    ? ThemeService.blue
                                    : ThemeService.alpha(ThemeService.fg, 0.08)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: ConnectivityService.btScanning
                                            ? "\uf256"   // fa-hand-stop (stop scan)
                                            : "\uf002"   // fa-search (start scan)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: ConnectivityService.btScanning
                                            ? ThemeService.blue : ThemeService.fg
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: ConnectivityService.btScanning
                                            ? "Stop scan" : "Scan nearby"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: ConnectivityService.btScanning
                                            ? ThemeService.blue : ThemeService.fg
                                    }
                                }

                                MouseArea {
                                    id: btScanMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (ConnectivityService.btScanning)
                                            ConnectivityService.stopBtScan()
                                        else
                                            ConnectivityService.startBtScan()
                                    }
                                }
                            }
                        }

                        // ── BT off state ──
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: !ConnectivityService.btPowered
                            text: "Bluetooth is off"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: ThemeService.grey1
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }

                        // ── Empty state ──
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btDevices.length === 0
                                     && ConnectivityService.btPairedDevices.length === 0
                                     && (!ConnectivityService.btScanning
                                         || ConnectivityService.btNearbyDevices.length === 0)
                            text: ConnectivityService.btScanning
                                  ? "Searching for devices..."
                                  : "No paired or connected devices.\nTap 'Scan nearby' to find devices."
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey1
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            Layout.topMargin: 20
                        }

                        // ═══════════════════════════════════════
                        // CONNECTED section
                        // ═══════════════════════════════════════
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btDevices.length > 0
                            text: "CONNECTED"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                        }

                        Repeater {
                            model: ConnectivityService.btPowered
                                   ? ConnectivityService.btDevices : []

                            Rectangle {
                                id: connectedRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: 8
                                color: ThemeService.alpha(ThemeService.green, 0.12)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.green, 0.4)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf294"   // fa-bluetooth
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        color: ThemeService.green
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: connectedRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: "Connected · " + connectedRow.modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: ThemeService.green
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.preferredHeight: 30
                                        radius: 6
                                        color: btDiscMouse.containsMouse
                                            ? ThemeService.alpha(ThemeService.red, 0.25)
                                            : ThemeService.alpha(ThemeService.red, 0.1)
                                        border.width: 1
                                        border.color: ThemeService.alpha(ThemeService.red, 0.3)

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            anchors.centerIn: parent
                                            text: "Disconnect"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: ThemeService.red
                                        }

                                        MouseArea {
                                            id: btDiscMouse
                                            anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ConnectivityService.disconnectBtDevice(connectedRow.modelData.mac)
                                        }
                                    }
                                }
                            }
                        }

                        // ═══════════════════════════════════════
                        // PAIRED (but not connected) section
                        // ═══════════════════════════════════════
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btPairedDevices.length > 0
                            text: "PAIRED · TAP TO RECONNECT"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.grey1
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                        }

                        Repeater {
                            model: ConnectivityService.btPowered
                                   ? ConnectivityService.btPairedDevices : []

                            Rectangle {
                                id: pairedRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8
                                color: pairedRowMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.fg, 0.06)
                                    : LookService.surfaceColor(ThemeService.bg2, 0.4)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf294"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: ThemeService.blue
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: pairedRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: pairedRow.modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: ThemeService.grey2
                                        }
                                    }

                                    // Forget button
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 6
                                        color: btForgetMouse.containsMouse
                                            ? ThemeService.alpha(ThemeService.red, 0.18)
                                            : "transparent"

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            anchors.centerIn: parent
                                            text: "\uf2ed"   // fa-trash
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: btForgetMouse.containsMouse
                                                ? ThemeService.red : ThemeService.grey1
                                        }

                                        MouseArea {
                                            id: btForgetMouse
                                            anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ConnectivityService.unpairBtDevice(pairedRow.modelData.mac)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pairedRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    anchors.rightMargin: 38
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.connectBtDevice(pairedRow.modelData.mac)
                                }
                            }
                        }

                        // ═══════════════════════════════════════
                        // NEARBY (scan-discovered) section
                        // ═══════════════════════════════════════
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: ConnectivityService.btPowered
                                     && ConnectivityService.btScanning
                                     && ConnectivityService.btNearbyDevices.length > 0
                            text: "NEARBY · TAP TO PAIR"
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: ThemeService.blue
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                        }

                        Repeater {
                            model: (ConnectivityService.btPowered
                                    && ConnectivityService.btScanning)
                                   ? ConnectivityService.btNearbyDevices : []

                            Rectangle {
                                id: nearbyRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8
                                color: nearbyRowMouse.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.18)
                                    : LookService.surfaceColor(ThemeService.bg2, 0.4)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.2)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: "\uf002"   // fa-search
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: ThemeService.blue
                                        Layout.preferredWidth: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: nearbyRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: ThemeService.fg
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                            text: "Tap to pair · " + nearbyRow.modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: ThemeService.blue
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nearbyRowMouse
                                    anchors.fill: parent
                                    preventStealing: true   // hf11: stop Flickable from eating the tap
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConnectivityService.pairBtDevice(nearbyRow.modelData.mac)
                                }
                            }
                        }
                    }
                }

                // ─── Audio tab ───
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "audio"
                    spacing: 12

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Audio devices and settings are managed"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.grey0
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "by your system mixer (pavucontrol / wpctl)."
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: ThemeService.grey0
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: openPavuMouse.containsMouse
                            ? ThemeService.alpha(ThemeService.blue, 0.22)
                            : ThemeService.alpha(ThemeService.blue, 0.12)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.blue, 0.5)

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "\uf013  Open pavucontrol"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                        }

                        MouseArea {
                            id: openPavuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConnectivityService.openAudioSettings()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ─── v6.16.2.3.2: Input tab (mouse / touchpad) ───
                // Live-applies via MouseSettingsService → hyprctl keyword.
                // Persists to ~/.config/hypr/zen-mouse.conf (sourced by
                // hyprland.conf) so changes survive Hyprland restarts.
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "input"
                    spacing: 14

                    // Section label
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Mouse"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }

                    // Sensitivity slider  (-1.0 … +1.0)
                    // v7.0.0-beta.1-hf41: replaced QQC2 Slider with the
                    // same custom Rectangle slider used by volume in
                    // the Audio tab. Visually consistent across the
                    // shell, plus cleaner drag behavior (no binding
                    // loop, no theme override quirks).
                    //
                    // Range is signed (-1.0 to +1.0) so the "ratio"
                    // calculation maps -1.0 → 0, 0 → 0.5, +1.0 → 1.0
                    // for the visual fill. Filled portion grows from
                    // CENTER, not left edge, to make the sign visible
                    // — negative = fill left of center, positive =
                    // fill right of center.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: "Sensitivity"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.grey0
                                Layout.fillWidth: true
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: MouseSettingsService.sensitivity.toFixed(2)
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }
                        }
                        Item {
                            id: sensSliderTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            readonly property real value: MouseSettingsService.sensitivity
                            // Map -1.0..+1.0 → 0.0..1.0 (center-anchored visually)
                            readonly property real ratio:
                                Math.max(0, Math.min(1, (value + 1.0) / 2.0))

                            // Track background
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 4; radius: 2
                                color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }
                            // Center tick marker (visual anchor at 0.0)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width / 2 - width / 2
                                width: 2; height: 8
                                color: ThemeService.alpha(ThemeService.fg, 0.35)
                                radius: 1
                            }
                            // Filled portion — grows from CENTER outward
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4; radius: 2
                                color: ThemeService.blue
                                x: sensSliderTrack.value >= 0
                                   ? parent.width / 2
                                   : parent.width * sensSliderTrack.ratio
                                width: Math.abs(
                                    parent.width * sensSliderTrack.ratio
                                    - parent.width / 2)
                                Behavior on width { NumberAnimation { duration: 60 } }
                                Behavior on x { NumberAnimation { duration: 60 } }
                            }
                            // Knob
                            Rectangle {
                                width: 18; height: 18; radius: 9; antialiasing: true
                                y: (parent.height - height) / 2
                                x: Math.max(0,
                                    parent.width * sensSliderTrack.ratio - width / 2)
                                color: ThemeService.fg
                                border.width: 1
                                border.color: LookService.surfaceColor(ThemeService.bg0, 0.4)
                                Behavior on x { NumberAnimation { duration: 60 } }
                            }
                            // Drag / click / wheel area
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                function _setFromX(x) {
                                    const r = Math.max(0, Math.min(1, x / width))
                                    // Map 0..1 → -1.0..+1.0, snap to 0.05
                                    let v = r * 2.0 - 1.0
                                    v = Math.round(v / 0.05) * 0.05
                                    v = Math.max(-1.0, Math.min(1.0, v))
                                    MouseSettingsService.sensitivity = v
                                    MouseSettingsService.apply(true)
                                }
                                onPressed: function(m) { _setFromX(m.x) }
                                onPositionChanged: function(m) {
                                    if (pressed) _setFromX(m.x)
                                }
                                onWheel: function(w) {
                                    const cur = MouseSettingsService.sensitivity
                                    const next = w.angleDelta.y > 0
                                                 ? Math.min(1.0, cur + 0.05)
                                                 : Math.max(-1.0, cur - 0.05)
                                    MouseSettingsService.sensitivity = Math.round(next * 100) / 100
                                    MouseSettingsService.apply(true)
                                    w.accepted = true
                                }
                                // Double-click → reset to 0 (baseline)
                                onDoubleClicked: {
                                    MouseSettingsService.sensitivity = 0.0
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Scroll factor slider (0.1 … 3.0)
                    // v7.0.0-beta.1-hf41: same custom Rectangle slider
                    // design as Sensitivity above. Range is positive-
                    // only (0.1 .. 3.0) with 1.0 as the "baseline" tick.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: "Scroll speed"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: ThemeService.grey0
                                Layout.fillWidth: true
                            }
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                text: MouseSettingsService.scrollFactor.toFixed(2) + "×"
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                color: ThemeService.blue
                            }
                        }
                        Item {
                            id: scrollSliderTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            readonly property real value: MouseSettingsService.scrollFactor
                            // Map 0.1..3.0 → 0.0..1.0
                            readonly property real ratio:
                                Math.max(0, Math.min(1, (value - 0.1) / (3.0 - 0.1)))
                            // Position of 1.0 baseline along the track (0..1)
                            readonly property real baselineRatio:
                                (1.0 - 0.1) / (3.0 - 0.1)

                            // Track background
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 4; radius: 2
                                color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }
                            // Baseline tick at 1.0×
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * scrollSliderTrack.baselineRatio
                                   - width / 2
                                width: 2; height: 8
                                color: ThemeService.alpha(ThemeService.fg, 0.35)
                                radius: 1
                            }
                            // Filled portion (left → current position)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * scrollSliderTrack.ratio
                                height: 4; radius: 2
                                color: ThemeService.blue
                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                            // Knob
                            Rectangle {
                                width: 18; height: 18; radius: 9; antialiasing: true
                                y: (parent.height - height) / 2
                                x: Math.max(0,
                                    parent.width * scrollSliderTrack.ratio - width / 2)
                                color: ThemeService.fg
                                border.width: 1
                                border.color: LookService.surfaceColor(ThemeService.bg0, 0.4)
                                Behavior on x { NumberAnimation { duration: 60 } }
                            }
                            // Drag / click / wheel area
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                function _setFromX(x) {
                                    const r = Math.max(0, Math.min(1, x / width))
                                    let v = 0.1 + r * (3.0 - 0.1)
                                    v = Math.round(v * 10) / 10
                                    v = Math.max(0.1, Math.min(3.0, v))
                                    MouseSettingsService.scrollFactor = v
                                    MouseSettingsService.apply(true)
                                }
                                onPressed: function(m) { _setFromX(m.x) }
                                onPositionChanged: function(m) {
                                    if (pressed) _setFromX(m.x)
                                }
                                onWheel: function(w) {
                                    const cur = MouseSettingsService.scrollFactor
                                    const next = w.angleDelta.y > 0
                                                 ? Math.min(3.0, cur + 0.1)
                                                 : Math.max(0.1, cur - 0.1)
                                    MouseSettingsService.scrollFactor = Math.round(next * 10) / 10
                                    MouseSettingsService.apply(true)
                                    w.accepted = true
                                }
                                // Double-click → reset to 1.0 (baseline)
                                onDoubleClicked: {
                                    MouseSettingsService.scrollFactor = 1.0
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Natural scroll (mouse wheel)
                    // v7.0.0-beta.1-hf43: replaced QQC2 Switch with the
                    // same rounded toggle pill used by Bluetooth/WiFi/
                    // Audio toggles in this same Control Panel. 42×22
                    // pill with sliding 18×18 circular thumb. Green when
                    // active, neutral when off. Visually consistent with
                    // all other on/off controls in the shell.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Natural scroll"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fg
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 22
                            radius: 11
                            color: MouseSettingsService.naturalScroll
                                   ? ThemeService.alpha(ThemeService.green, 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18; height: 18; radius: 9; antialiasing: true
                                color: ThemeService.fg
                                y: 2
                                x: MouseSettingsService.naturalScroll
                                   ? parent.width - width - 2 : 2
                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MouseSettingsService.naturalScroll = !MouseSettingsService.naturalScroll
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Touchpad natural scroll (separate)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: "Touchpad natural scroll"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fg
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 22
                            radius: 11
                            color: MouseSettingsService.touchpadNaturalScroll
                                   ? ThemeService.alpha(ThemeService.green, 0.85)
                                   : ThemeService.alpha(ThemeService.fg, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18; height: 18; radius: 9; antialiasing: true
                                color: ThemeService.fg
                                y: 2
                                x: MouseSettingsService.touchpadNaturalScroll
                                   ? parent.width - width - 2 : 2
                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MouseSettingsService.touchpadNaturalScroll = !MouseSettingsService.touchpadNaturalScroll
                                    MouseSettingsService.apply(true)
                                }
                            }
                        }
                    }

                    // Reset button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 7
                        color: resetInputMa.containsMouse
                            ? ThemeService.alpha(ThemeService.fg, 0.14)
                            : ThemeService.alpha(ThemeService.fg, 0.06)
                        border.width: 1
                        border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "Reset to defaults"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.fgDim
                        }

                        MouseArea {
                            id: resetInputMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MouseSettingsService.sensitivity = 0.0
                                MouseSettingsService.scrollFactor = 1.0
                                MouseSettingsService.naturalScroll = false
                                MouseSettingsService.touchpadNaturalScroll = false
                                MouseSettingsService.apply(true)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ─── v7.0.0-beta.1-hf99zk: Layout tab (section order) ───
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "layout"
                    contentHeight: layoutCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: layoutCol
                        width: parent.width
                        spacing: 6

                        // v7.0.0-beta.1-hf99zo: Glass — Advanced option
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true
                                text: "Profile card at the bottom"
                                color: ThemeService.fg; font.pixelSize: 11; font.family: Theme.fontFamily
                            }
                            Rectangle {
                                Layout.preferredWidth: 40; Layout.preferredHeight: 22; radius: 11
                                color: PanelState.qsProfileAtBottom ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: 18; height: 18; radius: 9; y: 2
                                    x: PanelState.qsProfileAtBottom ? parent.width - width - 2 : 2
                                    color: "#ffffff"
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { PanelState.qsProfileAtBottom = !PanelState.qsProfileAtBottom; PanelState.saveState() }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: ThemeService.alpha(ThemeService.fg, 0.10) }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true
                                text: "Drag a row (or use \u25b2\u25bc) to reorder"
                                color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily
                            }
                            Rectangle {
                                Layout.preferredWidth: 56; Layout.preferredHeight: 24; radius: 7
                                color: resetMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.2) : ThemeService.alpha(ThemeService.fg, 0.06)
                                border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.12)
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     anchors.centerIn: parent; text: "Reset"; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily }
                                MouseArea { id: resetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PanelState.qsResetOrder() }
                            }
                        }

                        Repeater {
                            model: PanelState.qsOrder
                            delegate: Rectangle {
                                id: orderRow
                                required property string modelData
                                required property int index
                                readonly property int rowH: 36
                                Layout.fillWidth: true
                                Layout.preferredHeight: rowH
                                radius: 8
                                color: dragMa.pressed ? ThemeService.alpha(ThemeService.blue, 0.20)
                                                      : LookService.surfaceColor(ThemeService.bg2, 0.5)
                                border.width: 1
                                border.color: dragMa.pressed ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.08)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 8
                                    spacing: 8
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         text: "\uf58e"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: ThemeService.grey2 }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: PanelState.qsSectionLabels[orderRow.modelData] || orderRow.modelData
                                        color: ThemeService.fg; font.pixelSize: 11; font.family: Theme.fontFamily
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 6
                                        visible: orderRow.index > 0
                                        color: upMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             anchors.centerIn: parent; text: "\u25b2"; font.pixelSize: 9; color: ThemeService.grey1 }
                                        MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: PanelState.qsMove(orderRow.index, orderRow.index - 1) }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 6
                                        visible: orderRow.index < PanelState.qsOrder.length - 1
                                        color: dnMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.12) : "transparent"
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             anchors.centerIn: parent; text: "\u25bc"; font.pixelSize: 9; color: ThemeService.grey1 }
                                        MouseArea { id: dnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: PanelState.qsMove(orderRow.index, orderRow.index + 1) }
                                    }
                                }

                                MouseArea {
                                    id: dragMa
                                    anchors.fill: parent
                                    anchors.rightMargin: 56
                                    cursorShape: Qt.SizeVerCursor
                                    property real startY: 0
                                    onPressed: (mouse) => { startY = mouse.y }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        const dy = mouse.y - startY
                                        const t = orderRow.rowH * 0.6
                                        if (dy > t && orderRow.index < PanelState.qsOrder.length - 1) {
                                            PanelState.qsMove(orderRow.index, orderRow.index + 1); startY = mouse.y
                                        } else if (dy < -t && orderRow.index > 0) {
                                            PanelState.qsMove(orderRow.index, orderRow.index - 1); startY = mouse.y
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── v7.0.0-beta.1-hf99i: Notifications tab ───
                // Reuses NotificationService (no new state/daemon). Click the
                // Notifs tab to see recent notifications; ✕ dismisses one,
                // "Clear all" wipes the list.
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.expandedTab === "notifs"
                    contentHeight: notifCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: notifCol
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                                Layout.fillWidth: true
                                text: NotificationService.notifications.length > 0
                                      ? (NotificationService.notifications.length + " notification" + (NotificationService.notifications.length === 1 ? "" : "s"))
                                      : "No notifications"
                                color: ThemeService.grey1; font.pixelSize: 11; font.family: Theme.fontFamily
                            }
                            Rectangle {
                                visible: NotificationService.notifications.length > 0
                                Layout.preferredWidth: clearAllTxt.implicitWidth + 18
                                Layout.preferredHeight: 24
                                radius: 7
                                color: clearAllMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.18) : ThemeService.alpha(ThemeService.fg, 0.06)
                                border.width: 1; border.color: ThemeService.alpha(ThemeService.fg, 0.12)
                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                     id: clearAllTxt; anchors.centerIn: parent; text: "Clear all"; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily }
                                MouseArea { id: clearAllMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.clearAll() }
                            }
                        }

                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            visible: NotificationService.notifications.length === 0
                            Layout.fillWidth: true
                            Layout.topMargin: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: "You're all caught up"
                            color: ThemeService.grey2; font.pixelSize: 12; font.family: Theme.fontFamily
                        }

                        Repeater {
                            model: NotificationService.notifications
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: notifRow.implicitHeight + 16
                                radius: 8
                                color: LookService.surfaceColor(ThemeService.bg2, 0.5)
                                border.width: 1
                                border.color: (modelData && modelData.urgency === 2) ? ThemeService.alpha(ThemeService.red, 0.4) : ThemeService.alpha(ThemeService.fg, 0.06)

                                ColumnLayout {
                                    id: notifRow
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            style: LookService.isClear ? Text.Outline : Text.Normal
                                            styleColor: LookService.clearTextOutline
                                             Layout.fillWidth: true; elide: Text.ElideRight; text: (modelData && modelData.appName) || "Notification"; color: ThemeService.blue; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                                        Rectangle {
                                            Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: 9
                                            color: dismissMa.containsMouse ? ThemeService.alpha(ThemeService.red, 0.25) : "transparent"
                                            Text {
                                                style: LookService.isClear ? Text.Outline : Text.Normal
                                                styleColor: LookService.clearTextOutline
                                                 anchors.centerIn: parent; text: "\u2715"; color: ThemeService.grey1; font.pixelSize: 10 }
                                            MouseArea { id: dismissMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.dismiss(modelData.id) }
                                        }
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         visible: !!(modelData && modelData.summary); Layout.fillWidth: true; elide: Text.ElideRight; text: (modelData && modelData.summary) || ""; color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                         visible: !!(modelData && modelData.body && modelData.body.length > 0); Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; text: (modelData && modelData.body) ? String(modelData.body).replace(/<[^>]*>/g, "") : ""; color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
