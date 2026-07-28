import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * ShellLookPage v7.0.0-beta.1-hf99l — Settings page for Shell Look.
 *
 * Pick one UI "personality" (Classic / Zen / Glass / Minimal / Custom) and
 * choose which surfaces follow it. Additive — Zen is the current default,
 * left untouched; switching just re-reads LookService tokens.
 */
Item {
    id: root

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 24
            spacing: 16

            DenshoPageHeader {
                Layout.fillWidth: true
                title: "Shell Look"
                subtitle: "One UI personality — applied across surfaces. Switch anytime, no restart."
                kanji: "装い"
                romaji: "Yosooi"
            }

            // ── Active Look picker ──
            HMSection {
                title: "Active Look"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: LookService.order
                        delegate: Rectangle {
                            required property string modelData
                            readonly property var look: LookService.looks[modelData]
                            readonly property bool selected: LookService.activeLook === modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 10
                            color: selected
                                   ? ThemeService.alpha(ThemeService.blue, 0.16)
                                   : (lookMa.containsMouse ? ThemeService.alpha(ThemeService.fg, 0.06)
                                                           : LookService.surfaceColor(ThemeService.bg2, 0.4))
                            border.width: selected ? 1.5 : 1
                            border.color: selected ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                // Mini swatch that hints at the look
                                Rectangle {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 30
                                    radius: Math.round(8 * (look ? look.radiusScale : 1))
                                    color: LookService.surfaceColor(ThemeService.bg0, look ? look.panelOpacity : 0.96)
                                    border.width: 1
                                    border.color: ThemeService.alpha(ThemeService.fg, look ? look.borderAlpha : 0.12)
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18; height: 5; radius: 2.5
                                        color: (look && look.glow) ? ThemeService.blue : ThemeService.alpha(ThemeService.fg, 0.5)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: look ? look.name : modelData
                                        color: ThemeService.fg
                                        font.pixelSize: 13
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        style: LookService.isClear ? Text.Outline : Text.Normal
                                        styleColor: LookService.clearTextOutline
                                        text: look ? look.desc : ""
                                        color: ThemeService.grey1
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    style: LookService.isClear ? Text.Outline : Text.Normal
                                    styleColor: LookService.clearTextOutline
                                    visible: selected
                                    text: "\uf00c"   // check
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: ThemeService.blue
                                }
                            }

                            MouseArea {
                                id: lookMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // v8.0.0-alpha-hf146 — no chime on look switch.
                                // hf144 added one on a misread; removed with the
                                // notification chime.
                                onClicked: LookService.setLook(modelData)
                            }
                        }
                    }
                }
            }

            // ── Live Preview ──
            HMSection {
                title: "Live Preview"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: 12
                    clip: true
                    // faux wallpaper so glass transparency actually reads
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2a2140" }
                        GradientStop { position: 1.0; color: "#402a5e" }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        // mini bar
                        Rectangle {
                            width: parent.width
                            height: 30
                            radius: Math.round(10 * LookService.radiusScale)
                            color: LookService.surfaceColor(ThemeService.bg0, LookService.panelOpacity)
                            border.width: 1
                            border.color: LookService.glow
                                          ? ThemeService.alpha(ThemeService.blue, 0.5)
                                          : ThemeService.alpha(ThemeService.fg, LookService.borderAlpha)
                            Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 10
                                spacing: 6
                                Rectangle { width: 16; height: 6; radius: 3; color: ThemeService.blue; anchors.verticalCenter: parent.verticalCenter }
                                Repeater { model: 3; delegate: Rectangle { width: 6; height: 6; radius: 3; color: ThemeService.alpha(ThemeService.fg, 0.4); anchors.verticalCenter: parent.verticalCenter } }
                            }
                        }

                        // mini control-panel (with a faux glow halo when glow=on)
                        Item {
                            width: parent.width * 0.6
                            height: 74

                            Rectangle {   // glow halo
                                visible: LookService.glow
                                anchors.centerIn: miniPanel
                                width: miniPanel.width + 10
                                height: miniPanel.height + 10
                                radius: miniPanel.radius + 5
                                color: "transparent"
                                border.width: 4
                                border.color: ThemeService.alpha(ThemeService.blue, 0.22)
                            }

                            Rectangle {
                                id: miniPanel
                                anchors.fill: parent
                                radius: Math.round(14 * LookService.radiusScale)
                                color: LookService.surfaceColor(ThemeService.bg0, LookService.panelOpacity)
                                border.width: 1
                                border.color: LookService.glow
                                              ? ThemeService.alpha(ThemeService.blue, 0.5)
                                              : ThemeService.alpha(ThemeService.fg, LookService.borderAlpha)
                                Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 7
                                    Rectangle { width: parent.width * 0.7; height: 7; radius: 3.5; color: ThemeService.alpha(ThemeService.fg, 0.5) }
                                    Rectangle { width: parent.width; height: 6; radius: 3; color: ThemeService.alpha(ThemeService.fg, 0.18) }
                                    Row {
                                        spacing: 8
                                        Rectangle { width: 22; height: 12; radius: 6; color: ThemeService.blue }
                                        Rectangle { width: 22; height: 12; radius: 6; color: ThemeService.alpha(ThemeService.fg, 0.2) }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.margins: 8
                        text: LookService.current.name + "  ·  live"
                        color: ThemeService.alpha(ThemeService.fg, 0.7)
                        font.pixelSize: 9; font.family: Theme.fontFamily
                    }
                }
            }

            // ── v8.0.0-alpha-hf144: the frost slider (Glass+ only) ──
            //
            // "tas may draggable siya kung gaano ka-glassy ganun." One knob, and
            // it moves fill AND blur together — see LookService.glassFill /
            // glassBlur. Only shown when the clear look is active, because it is
            // the only look that reads it. Border is intentionally not affected.
            HMSection {
                visible: LookService.isClear
                title: "Frost"

                HMRow {
                    label: "Glassiness"
                    description: "How clear the panels go — 5 levels. 1 = a faint pane you can still read a card in, "
                               + "5 = almost pure blur. Applies to the Control Center, notifications, dock, "
                               + "start menu and desktop."
                    iconFont: "Material Symbols Rounded"
                    icon: "blur_on"
                    separator: true
                    RowLayout {
                        spacing: 10
                        // v8.0.0-alpha-hf173 — 5 levels instead of a 0–100% drag. The old
                        // slider had 50 stops but only about five visually distinct results,
                        // so the in-between positions were false precision. stepSize 0.25
                        // snaps to exactly 0 / .25 / .5 / .75 / 1 — the SAME curve
                        // glassFill and glassBlur already use, just quantised, so no range
                        // is lost. Default is now level 5 (Paul: "default naka 100 percent").
                        ZenSlider {
                            id: frostSlider
                            Layout.preferredWidth: 190
                            from: 0.0; to: 1.0; stepSize: 0.25
                            snapMode: Slider.SnapAlways
                            value: PanelState.glassStrength
                            onMoved: { PanelState.glassStrength = value; PanelState.saveState() }
                        }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            text: {
                                const lv = Math.round(frostSlider.value * 4) + 1
                                return lv + " · " + ["Card", "Frosted", "Glass", "Clear", "Pure"][lv - 1]
                            }
                            color: ThemeService.fg; font.pixelSize: 12
                            font.family: Theme.fontFamily
                            Layout.preferredWidth: 74; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // v8.0.0-alpha-hf146 — "toggle na lalabas kapag Glass+ pinili:
                // clear or normal icons." White app icons in the dock and bars, or
                // your normal colourful ones. On by default under the clear look.
                HMRow {
                    label: "White app icons"
                    description: "Dock and bar app icons become a uniform white. Off = your normal colourful icons."
                    iconFont: "Material Symbols Rounded"
                    icon: "invert_colors"
                    separator: true
                    HMSwitch {
                        checked: PanelState.monoIcons
                        onToggled: { PanelState.monoIcons = checked; PanelState.saveState() }
                    }
                }

                // v8.0.0-alpha-hf178 — "prang pang macbook prang naka float nga yun
                // design e kaya ko pinapaalis yun background nung taskbar ko sa dock".
                // Off = no plate behind the icons at all; the running dot still marks
                // what's open and a faint wash still marks what you're hovering, which
                // is exactly how macOS does it. Nothing is removed — this brings the
                // pills back.
                HMRow {
                    label: "Icon backgrounds"
                    description: "Off — dock icons float with no plate behind them, macOS style. "
                               + "The dot under an icon still shows it's running. On — the rounded "
                               + "plate returns."
                    iconFont: "Material Symbols Rounded"
                    icon: "rounded_corner"
                    separator: true
                    HMSwitch {
                        checked: PanelState.taskbarIconBackgrounds
                        onToggled: { PanelState.taskbarIconBackgrounds = checked; PanelState.saveState() }
                    }
                }

                // a tiny live proof: a frosted chip that thins as you drag
                HMRow {
                    label: "Preview"
                    description: "Live — this chip uses the same fill the panels do."
                    Rectangle {
                        Layout.preferredWidth: 190; Layout.preferredHeight: 40
                        radius: 12
                        color: LookService.panelColor(ThemeService.bg0, LookService.panelOpacity)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.30)
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                            anchors.centerIn: parent
                            text: "clear"
                            color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily
                        }
                    }
                }
            }

            // ── v8.0.0-alpha-hf112: opacity, per surface ──
            HMSection {
                title: "Opacity"

                HMRow { label: "Control Center"; description: "The Zen Control Center window"; iconFont: "Material Symbols Rounded"; icon: "opacity"; separator: true
                    RowLayout {
                        spacing: 10
                        ZenSlider { id: dashOp; Layout.preferredWidth: 190; from: 0.30; to: 1.0; stepSize: 0.02
                                    value: PanelState.dashOpacity
                                    onMoved: { PanelState.dashOpacity = value; PanelState.saveState() } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(dashOp.value * 100) + "%"; color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                    }
                }
                HMRow { label: "Quick Settings"; description: "The Quick Settings popup"; iconFont: "Material Symbols Rounded"; icon: "opacity"; separator: true
                    RowLayout {
                        spacing: 10
                        ZenSlider { id: cpOp; Layout.preferredWidth: 190; from: 0.30; to: 1.0; stepSize: 0.02
                                    value: PanelState.controlPanelOpacity
                                    onMoved: { PanelState.controlPanelOpacity = value; PanelState.saveState() } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(cpOp.value * 100) + "%"; color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                    }
                }
                HMRow { label: "Start Menu"; description: "Start Menu panel"; iconFont: "Material Symbols Rounded"; icon: "opacity"; separator: true
                    RowLayout {
                        spacing: 10
                        ZenSlider { id: smOp; Layout.preferredWidth: 190; from: 0.30; to: 1.0; stepSize: 0.02
                                    value: PanelState.startMenuOpacity
                                    onMoved: { PanelState.startMenuOpacity = value; PanelState.saveState() } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(smOp.value * 100) + "%"; color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                    }
                }
                // v8.0.0-alpha-hf181 — the dock's own plate. This is the only opacity
                // slider that starts at 0 rather than 30%: at 0 the plate, its border and
                // its inner highlight all stop drawing and the icons float straight on the
                // wallpaper. Pair it with Icon backgrounds off for the full macOS dock.
                HMRow { label: "Dock plate"; description: "The panel behind the dock icons. Drag to 0% and the icons float on the wallpaper — pair with Icon backgrounds off."; iconFont: "Material Symbols Rounded"; icon: "opacity"; separator: true
                    RowLayout {
                        spacing: 10
                        ZenSlider { id: tbOp; Layout.preferredWidth: 190; from: 0.0; to: 1.0; stepSize: 0.02
                                    value: PanelState.taskbarOpacity
                                    onMoved: { PanelState.taskbarOpacity = value; PanelState.saveState() } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(tbOp.value * 100) + "%"; color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                    }
                }
                HMRow { label: "Notifications"; description: "Notification centre"; iconFont: "Material Symbols Rounded"; icon: "opacity"; separator: false
                    RowLayout {
                        spacing: 10
                        ZenSlider { id: nOp; Layout.preferredWidth: 190; from: 0.30; to: 1.0; stepSize: 0.02
                                    value: PanelState.notificationOpacity
                                    onMoved: { PanelState.notificationOpacity = value; PanelState.saveState() } }
                        Text {
                            style: LookService.isClear ? Text.Outline : Text.Normal
                            styleColor: LookService.clearTextOutline
                             text: Math.round(nOp.value * 100) + "%"; color: ThemeService.fg; font.pixelSize: 12; font.family: Theme.fontFamily; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                    }
                }
            }

            // ── Apply To ──
            HMSection {
                title: "Apply To"

                HMRow {
                    label: "Bar"
                    icon: "\uf07e"
                    HMSwitch { checked: PanelState.lookApplyBar; onToggled: { PanelState.lookApplyBar = checked; PanelState.saveState() } }
                }
                HMRow {
                    label: "Control Panel"
                    icon: "\uf0ca"
                    HMSwitch { checked: PanelState.lookApplyControlPanel; onToggled: { PanelState.lookApplyControlPanel = checked; PanelState.saveState() } }
                }
                HMRow {
                    label: "Start Menu"
                    icon: "\uf17c"
                    HMSwitch { checked: PanelState.lookApplyStartMenu; onToggled: { PanelState.lookApplyStartMenu = checked; PanelState.saveState() } }
                }
                HMRow {
                    label: "Dock"
                    icon: "\uf52b"
                    HMSwitch { checked: PanelState.lookApplyDock; onToggled: { PanelState.lookApplyDock = checked; PanelState.saveState() } }
                }
                HMRow {
                    label: "Notifications"
                    icon: "\uf0f3"
                    HMSwitch { checked: PanelState.lookApplyNotifications; onToggled: { PanelState.lookApplyNotifications = checked; PanelState.saveState() } }
                }
                HMRow {
                    label: "OSD / Toasts"
                    icon: "\uf028"
                    separator: false
                    HMSwitch { checked: PanelState.lookApplyOsd; onToggled: { PanelState.lookApplyOsd = checked; PanelState.saveState() } }
                }
            }

            // ── Note ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: noteCol.implicitHeight + 24
                radius: 10
                color: ThemeService.alpha(ThemeService.blue, 0.08)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.blue, 0.2)
                ColumnLayout {
                    id: noteCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14; anchors.rightMargin: 14
                    spacing: 3
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "Picking a look WRITES these values into your settings — your sliders stay in charge afterwards. \"Custom\" never touches them."
                        color: ThemeService.fg; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: "A look is a LookService token set. Glass frost = Hyprland "
                              + "layer blur on the zen-shell-* surfaces — applied at runtime on "
                              + "start, and persisted via ~/.config/hypr/zen-shell-look.conf "
                              + "(the installer sources it). Bar, Dock, Control Panel, Start Menu "
                              + "and Notifications all follow the look."
                        color: ThemeService.grey1; font.pixelSize: 10; font.family: Theme.fontFamily
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
