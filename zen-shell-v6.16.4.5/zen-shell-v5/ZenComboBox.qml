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
        }
    }
}
