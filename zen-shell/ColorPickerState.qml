pragma Singleton

import QtQuick

/*
 * ColorPickerState v7.0.0-alpha.11-hf4
 *
 * Singleton state bridge between ColorSwatch components and the
 * global ColorPickerOverlay. Any ColorSwatch can request the
 * picker to open via:
 *
 *   ColorPickerState.requestOpen(initialHex, function(newHex){
 *       // user's onApply callback
 *   })
 *
 * The overlay (mounted once in ZenSettings root) listens to
 * `openRequested` signal and shows itself with the supplied
 * initial color. When the user clicks Apply, it invokes the
 * callback stored here.
 *
 * Why singleton: we want exactly ONE picker instance shared
 * across all swatches. Every swatch having its own Popup
 * caused the "escape outside Settings panel" bug because each
 * Popup tried to find its own parent context.
 */
QtObject {
    id: state

    // Emitted when a swatch wants the picker shown. The overlay
    // listens to this signal in its Connections block.
    signal openRequested(string initialHex)

    // Called by the overlay when the user clicks Apply. Invokes
    // the swatch's stored callback then clears it.
    function commit(hex) {
        if (state._pendingCallback) {
            try { state._pendingCallback(hex) } catch (e) { console.warn("[ColorPickerState] callback error:", e) }
        }
        state._pendingCallback = null
    }

    // Called by the overlay when user dismisses without applying.
    function cancel() {
        state._pendingCallback = null
    }

    // Internal: stored callback from the most recent requestOpen call.
    // Cleared on commit/cancel.
    property var _pendingCallback: null

    // Public entry: swatch calls this with its current value + a
    // callback to invoke when user picks a color.
    function requestOpen(initialHex, callback) {
        state._pendingCallback = callback
        state.openRequested(initialHex || "#ffffffff")
    }
}
