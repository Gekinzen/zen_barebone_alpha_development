import QtQuick
import QtQuick.Controls

/*
 * ZenComboBox v6.16.3.4.6 — drop-in replacement for QQC2 ComboBox
 *
 * v6.16.3.4.6 enhancements over 3.4.5:
 *   - Dynamic bounds awareness: popup height adapts to the actual
 *     space available between the ComboBox and the Settings window
 *     bottom edge. No more "280px cap but popup still clips past
 *     the window" — if there's only 180px below, popup is 180px.
 *   - Auto-flip upward: if the space below is too cramped AND the
 *     space above is bigger, the popup opens UPWARD instead. This
 *     fixes the case Paul hit: a ComboBox near the bottom of the
 *     Settings window with a 10-item list — previously the popup
 *     extended past the window edge and the last item(s) became
 *     unclickable.
 *   - Always-visible ScrollBar instead of ScrollIndicator. The old
 *     ScrollIndicator fades out after 2-3 seconds; a persistent
 *     ScrollBar makes it obvious when more items are hidden below.
 *
 * v6.16.3.4.5 original:
 *   The stock Qt Controls ComboBox popup grows to fit its full model.
 *   When the model has more items than fit in the window, the popup
 *   extends past the window edge and those items become visible but
 *   UNCLICKABLE (click events land outside the popup region on Wayland).
 *
 * Usage stays identical to the plain ComboBox:
 *
 *   ZenComboBox { model: [...]; onActivated: ... }
 *
 * All standard ComboBox APIs preserved (model, currentIndex, currentText,
 * onActivated, textRole, displayText, etc.).
 *
 * Per-instance overrides:
 *   - maxPopupHeight: int — hard ceiling, default 280. Set larger for
 *     dropdowns with genuinely big lists on huge monitors, or smaller
 *     for tight-space scenarios.
 *   - flipMargin: int — minimum pixels below the ComboBox required
 *     before we'll open the popup downward. If less, flip upward.
 *     Default 140 (roughly 4-5 visible rows).
 *
 * Wala tayong babawasan — stock ComboBox behavior preserved.
 */
ComboBox {
    id: root

    // v6.16.3.5.3: lowered from 280 → 220. Safer default: 220 fits
    // within most Settings windows' usable area even when the
    // ComboBox is near an edge. Individual call sites can opt in to
    // a taller popup via maxPopupHeight if they genuinely need it.
    property int maxPopupHeight: 220

    // Retained for API compatibility — no longer used by the flip
    // decision (see _flipUp below, which uses desired height now).
    property int flipMargin: 140

    popup: Popup {
        id: zenPopup

        // v6.16.3.5.3: defensive window resolution.
        //
        // root.Window.window is Qt's attached property giving the
        // owning QQuickWindow. In 95% of cases this just works. But
        // when the ComboBox is deep inside a ScrollView/Item chain
        // on certain Quickshell window types, we've seen it return
        // null — and the old fallback (maxPopupHeight) effectively
        // disables the bounds check, so popup opens past the window.
        //
        // Chain: Window.window → first ancestor with a 'height' that
        // looks like a window (≥200px) → null. When null, the flip
        // decision below assumes a conservative tight-below scenario.
        readonly property var _window: {
            if (root.Window && root.Window.window) return root.Window.window
            // Walk up looking for a window-like container
            let p = root.parent
            while (p) {
                if (p.height !== undefined && p.height >= 200
                    && p.width !== undefined && p.width >= 200) return p
                p = p.parent
            }
            return null
        }

        readonly property real _availableBelow: {
            if (!_window) return 120   // pessimistic fallback
            const p = root.mapToItem(null, 0, root.height)
            return Math.max(0, _window.height - p.y - 16)
        }

        readonly property real _availableAbove: {
            if (!_window) return 400   // optimistic above (prefers flip up)
            const p = root.mapToItem(null, 0, 0)
            return Math.max(0, p.y - 16)
        }

        // What the popup wants (ignoring where it can actually fit)
        readonly property real _desiredHeight: {
            return Math.min(contentItem.implicitHeight, root.maxPopupHeight)
        }

        // v6.16.3.5.3: aggressive flip policy.
        // Flip up unless below can COMFORTABLY fit the entire desired
        // popup. "Comfortably" = with 20px of breathing room left
        // over. This means a ComboBox anywhere near the window
        // bottom with a non-tiny list will flip up — exactly Paul's
        // Center/Right Module Layout Zone dropdowns case.
        readonly property bool _flipUp: {
            if (_availableBelow >= _desiredHeight + 20) return false
            return _availableAbove > _availableBelow
        }

        // Effective max popup height = min(user cap, space on chosen
        // side, with 4px extra safety). Guaranteed ≥ 80 so an
        // extremely cramped case still shows ~2.5 items + scrollbar.
        readonly property real _effectiveMax: {
            const side = _flipUp ? _availableAbove : _availableBelow
            const capped = Math.min(root.maxPopupHeight, side - 4)
            return Math.max(80, capped)
        }

        y: _flipUp ? -height : root.height
        width: root.width
        padding: 1

        implicitHeight: Math.min(contentItem.implicitHeight, _effectiveMax)

        background: Rectangle {
            color: ThemeService.bg1
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.15)
            radius: 6
        }

        contentItem: ListView {
            id: popupList
            clip: true
            implicitHeight: contentHeight
            model: zenPopup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex

            // v6.16.3.4.6: Centre the current selection when the popup
            // opens. Qt.callLater defers to after ListView has sized
            // itself (positionViewAtIndex on an unsized view is a no-op).
            onModelChanged: if (model) Qt.callLater(positionViewAtIndex, currentIndex, ListView.Center)

            // v6.16.3.4.6: Switched from ScrollIndicator to ScrollBar.
            // ScrollIndicator fades out after a couple seconds of idle;
            // ScrollBar stays visible while there's overflow, which is
            // what the user needs to discover that more items exist
            // below the fold. AsNeeded policy hides it when the list
            // fully fits (no needless clutter on short dropdowns).
            //
            // v6.16.3.5.2: bumped to 12px wide with more contrasty
            // default color so the affordance is visible at a glance,
            // not something the user has to look hard to find.
            ScrollBar.vertical: ScrollBar {
                id: zenScrollBar
                policy: ScrollBar.AsNeeded
                active: true
                width: 12
                contentItem: Rectangle {
                    implicitWidth: 10
                    implicitHeight: 40
                    radius: 5
                    color: zenScrollBar.pressed
                        ? ThemeService.alpha(ThemeService.fg, 0.7)
                        : (zenScrollBar.hovered
                            ? ThemeService.alpha(ThemeService.fg, 0.55)
                            : ThemeService.alpha(ThemeService.fg, 0.45))
                }
            }

            // v6.16.4.12.5: Bottom padding so the LAST item is fully
            // clickable. Without this, the last delegate's bottom edge
            // sits flush with the popup's bottom edge — and on Wayland
            // that 1px row reports as outside the popup region, so
            // clicks on the last item are dropped silently.
            footer: Item { width: 1; height: 4 }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // v6.16.4.12.5: Custom delegate with theme-aware text colors.
    //
    // Stock ComboBox uses Qt's palette for delegate text, which
    // ignores ThemeService and renders dark text on the highlighted
    // (blue-tinted) row. Replacing the delegate with our own
    // ItemDelegate lets us pick text color via WCAG 2.0 luminance
    // — same logic as the rest of the shell.
    //
    // Highlighted row: blue background → fg (white on dark themes,
    // dark on light themes) is computed via Theme.contrastFg().
    // Normal row: default fg color from ThemeService.
    // ─────────────────────────────────────────────────────────────
    delegate: ItemDelegate {
        id: itemDel
        width: root.width
        height: 32

        required property var modelData
        required property int index

        readonly property bool isHighlighted: root.highlightedIndex === index
        readonly property bool isSelected: root.currentIndex === index

        // Resolve display text — prefer textRole when set, else stringify
        readonly property string displayText: {
            if (root.textRole && modelData && modelData[root.textRole] !== undefined)
                return String(modelData[root.textRole])
            return String(modelData)
        }

        background: Rectangle {
            color: itemDel.isHighlighted
                   ? ThemeService.blue
                   : (itemDel.hovered
                      ? ThemeService.alpha(ThemeService.fg, 0.08)
                      : "transparent")

            // Subtle accent bar on the left when highlighted
            Rectangle {
                visible: itemDel.isHighlighted
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: Qt.lighter(ThemeService.blue, 1.3)
            }
        }

        contentItem: Text {
            text: itemDel.displayText
            font: root.font
            verticalAlignment: Text.AlignVCenter
            leftPadding: 12
            rightPadding: 12
            // v6.16.4.12.5: Pick text color based on background luminance.
            // On highlighted blue background, white text on dark themes,
            // dark text on light themes (WCAG 2.0 L=0.5 threshold).
            color: itemDel.isHighlighted
                   ? (_luminance(ThemeService.blue) > 0.5 ? "#000000" : "#FFFFFF")
                   : ThemeService.fg
            elide: Text.ElideRight
        }

        // Inline luminance calc — relative luminance per WCAG 2.0
        function _luminance(c) {
            const rs = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4)
            const gs = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4)
            const bs = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4)
            return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs
        }
    }
}
