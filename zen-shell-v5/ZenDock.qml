import QtQuick
import QtQuick.Layouts

/*
 * ZenDock v7.0.0-beta.1-hf82k — Karui (軽い)
 *
 * The dock body — a Rectangle that hosts a RowLayout of module
 * Loaders driven by DockState.modules. Mirrors Bar.qml's module
 * dispatcher pattern but stays lean: no music-slot tracking, no
 * layout nudger (dock content is mostly static modules, not the
 * width-fluctuating music widget), no overflow logic (dock is hug-
 * content sized).
 *
 * Reuses existing widget Components: Taskbar (with hf82g drag),
 * Workspaces (with popup), StartMenu, SysRow. New widgets used:
 * ZenDivider, ControlCenterButton.
 *
 * Theme integration:
 *   - When DockState.syncFromBar is true, background and border are
 *     pulled from the same sources Bar.qml uses (PanelState +
 *     ThemeService), giving the dock a visually-unified look with
 *     the bar.
 *   - When syncFromBar is false, DockState's own override fields
 *     drive the visual.
 *
 * Sizing:
 *   - implicitWidth comes from RowLayout.implicitWidth + side padding
 *   - implicitHeight is DockState.height
 *
 * Wala tayong babawasan — purely additive. The dock is a separate
 * surface mounted alongside the bar in shell.qml; no existing module
 * or singleton is modified.
 */
Rectangle {
    id: dockRoot

    // v7.0.0-beta.1-hf95.31 — available width the parent gives us. In
    // fullwidth/floating modes this is the (near-)full monitor width; in
    // island mode it's 0 (hug content, no constraint). Set from shell.qml.
    property int availableWidth: 0

    // ── Sizing (consumed by parent PanelWindow) ──
    // hf95.32 — base icon-size scale (user slider, independent of bar).
    readonly property real baseIconScale: DockState.iconSizeScale > 0
        ? DockState.iconSizeScale : 1.0
    // Natural width of the content at the user's chosen icon size (base
    // scale applied), before any crowding shrink.
    readonly property int contentNaturalWidth: Math.round(
        dockRow.implicitWidth * baseIconScale) + DockState.contentPadding * 2
    readonly property int contentImplicitWidth: contentNaturalWidth

    // hf95.31 — DYNAMIC icon scale (hybrid resize→arrows). When the dock
    // is width-constrained (fullwidth/floating) and the apps would
    // overflow, shrink icons to fit — never grown past 1.0, so few apps
    // stay normal and centered. Floor = DockState.minIconScale (user
    // slider); once it hits the floor and STILL overflows, the chevron
    // arrows take over.
    readonly property real dockFitScale: {
        if (availableWidth <= 0) return 1.0                 // island: unconstrained
        const natural = contentNaturalWidth
        if (natural <= availableWidth) return 1.0           // fits: normal size
        const floor = DockState.minIconScale > 0 ? DockState.minIconScale : 0.7
        const s = availableWidth / natural
        return Math.max(floor, s)
    }
    // Final scale applied to the content row: user's base size × crowding
    // fit. (Fit is 1.0 in island mode, so there it's just the base size.)
    readonly property real contentScale: baseIconScale * dockFitScale
    // True when even at the floor scale the apps still overflow → arrows.
    readonly property bool hasOverflow: {
        if (availableWidth <= 0) return false
        const floor = DockState.minIconScale > 0 ? DockState.minIconScale : 0.7
        return contentNaturalWidth * floor > availableWidth
    }

    implicitWidth: contentImplicitWidth
    // hf95.32 — dock surface height grows with the base icon scale so big
    // icons aren't clipped (capped to a sane multiple of the set height).
    implicitHeight: Math.round(DockState.height * Math.min(baseIconScale, 1.6))

    // ── Theme ──
    //
    // When sync is on, inherit from PanelState (bar's source of truth)
    // so changes to the bar's color flow through automatically.
    radius: DockState.syncFromBar
        ? (Theme.styleMode === "round" ? 22 : Theme.barRadius)
        : DockState.overrideCornerRadius

    color: {
        if (DockState.syncFromBar) {
            // Mirror Bar.qml's color resolution: PanelState override
            // wins if enabled; otherwise use ThemeService.bg0 at the
            // configured opacity.
            if (PanelState.bgOverrideEnabled) {
                return Qt.rgba(
                    PanelState.bgColor.r,
                    PanelState.bgColor.g,
                    PanelState.bgColor.b,
                    PanelState.barOpacity
                )
            }
            return Qt.rgba(
                ThemeService.bg0.r,
                ThemeService.bg0.g,
                ThemeService.bg0.b,
                PanelState.barOpacity
            )
        }
        // Independent — use override fields directly.
        return Qt.rgba(
            DockState.overrideBgColor.r,
            DockState.overrideBgColor.g,
            DockState.overrideBgColor.b,
            DockState.overrideBgOpacity
        )
    }

    border.color: DockState.syncFromBar
        ? Qt.rgba(
            ThemeService.fg.r,
            ThemeService.fg.g,
            ThemeService.fg.b,
            0.12
          )
        : DockState.overrideBorderColor
    border.width: DockState.syncFromBar
        ? (PanelState.borderEnabled ? PanelState.borderWidth : 0)
        : DockState.overrideBorderWidth

    // ── Module Components (reuse existing widgets) ──
    //
    // Same pattern as Bar.qml: declare each module as a Component,
    // resolve by name via getComponent(name) in the Repeater delegate.
    // The dock reuses Bar's existing widgets unchanged — drag (hf82g),
    // workspace popup, system tray cluster all just work.
    Component { id: cStart;         StartMenu     {} }
    Component { id: cTaskbar;       Taskbar       {} }
    Component { id: cWorkspaces;    Workspaces    {} }
    Component { id: cSysRow;        SysRow        {} }
    Component { id: cDivider;       ZenDivider    {} }
    Component { id: cControlCenter; ControlCenterButton {} }

    // Optional reuse — these are bar-shared widgets the user can
    // slot into the dock too. If the widget doesn't exist in the
    // install (rare), getComponent returns null and the delegate
    // renders nothing.
    Component { id: cTray;          SystemTray    {} }
    Component { id: cClock;         Clock         {} }
    Component { id: cBattery;       Battery       {} }
    Component { id: cNotifIcon;     NotificationIcon {} }

    function getComponent(name) {
        switch (name) {
            case "start":         return cStart
            case "taskbar":       return cTaskbar
            case "workspaces":    return cWorkspaces
            case "divider":       return cDivider
            case "sysrow":        return cSysRow
            case "controlcenter": return cControlCenter
            case "tray":          return cTray
            case "clock":         return cClock
            case "battery":       return cBattery
            case "notifications": return cNotifIcon
        }
        console.warn("[ZenDock] Unknown module:", name)
        return null
    }

    // ── Layout ──
    //
    // hf95.31 — hybrid resize→arrows. The content row is rendered inside a
    // clipping viewport. A centered `scale` shrinks everything to fit
    // (dockFitScale); once that hits the min-scale floor and still
    // overflows, `hasOverflow` is true and the chevrons scroll the row.
    property real scrollOffset: 0
    onDockFitScaleChanged: scrollOffset = 0   // reset scroll when fit changes

    // Left chevron
    Rectangle {
        visible: dockRoot.hasOverflow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 2
        z: 5
        width: 22; height: parent.height * 0.7
        radius: 6
        color: ThemeService.alpha(ThemeService.bg0, 0.6)
        Text {
            anchors.centerIn: parent; text: "\u2039"
            color: ThemeService.fg; font.pixelSize: 18
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: dockRoot.scrollOffset = Math.max(
                0, dockRoot.scrollOffset - 120)
        }
    }
    // Right chevron
    Rectangle {
        visible: dockRoot.hasOverflow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 2
        z: 5
        width: 22; height: parent.height * 0.7
        radius: 6
        color: ThemeService.alpha(ThemeService.bg0, 0.6)
        Text {
            anchors.centerIn: parent; text: "\u203a"
            color: ThemeService.fg; font.pixelSize: 18
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
                const maxOff = Math.max(0,
                    dockRoot.contentNaturalWidth * dockRoot.dockFitScale
                    - dockRoot.width + 48)
                dockRoot.scrollOffset = Math.min(maxOff,
                    dockRoot.scrollOffset + 120)
            }
        }
    }

    // Clipping viewport for the scaled/scrolled content.
    Item {
        id: dockViewport
        anchors.fill: parent
        anchors.leftMargin: dockRoot.hasOverflow ? 26 : 0
        anchors.rightMargin: dockRoot.hasOverflow ? 26 : 0
        clip: dockRoot.hasOverflow

        RowLayout {
            id: dockRow
            // Centered when it fits; scaled about center; scrolled on X
            // when overflowing. hf95.32 — scale = base icon size × fit.
            anchors.verticalCenter: parent.verticalCenter
            x: dockRoot.hasOverflow
               ? -dockRoot.scrollOffset
               : Math.max(DockState.contentPadding,
                          (parent.width - width * dockRoot.contentScale) / 2)
            spacing: DockState.contentSpacing
            scale: dockRoot.contentScale
            transformOrigin: Item.Left

            Repeater {
                id: moduleRepeater
                model: DockState.modules

                delegate: Loader {
                    id: modLoader
                    required property string modelData
                    required property int index

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: false

                    sourceComponent: dockRoot.getComponent(modelData)
                }
            }
        }
    }

    Behavior on scrollOffset { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // ── Visibility binding (controlled by parent PanelWindow) ──
    //
    // The dock Rectangle itself is always "visible: true"; the
    // PanelWindow that contains it handles the actual show/hide based
    // on DockState.enabled + per-screen targeting. This mirrors how
    // Bar.qml works inside its barWindow.
}
