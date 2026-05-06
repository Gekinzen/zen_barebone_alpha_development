pragma Singleton

import Quickshell
import QtQuick

/*
 * PasswordPromptService — Modori v6.16.4.12.9.10
 *
 * Replaces the zenity --password external dialog with an in-shell
 * Wayland-overlay popup. Solves the original UX problem: zenity
 * spawned a separate window that landed BEHIND the Control Panel
 * (or wherever the user's focus was), forcing them to alt-tab to
 * find it. The new prompt is rendered by the shell itself as an
 * overlay layer surface — always on top, centered on screen,
 * impossible to miss.
 *
 * Architecture:
 *   - This singleton holds the prompt state (active SSID, busy
 *     flag, last error message).
 *   - PasswordPromptWindow.qml binds to this state and renders
 *     when active is true.
 *   - Callers invoke requestPassword(ssid, onSubmit, onCancel).
 *     onSubmit is a JS function taking the password string.
 *     onCancel is optional, called on dismiss/Esc.
 *
 * The window is NOT modal in the Wayland sense — Wayland's
 * layer-shell doesn't support that primitive. Instead the window
 * sits at WlrLayer.Overlay (above everything except other overlay
 * surfaces) with a full-screen backdrop that consumes clicks.
 * Visually + interactively this gives the same effect as a modal.
 */
Singleton {
    id: root

    // ───── Public reactive state (read by PasswordPromptWindow) ─────
    property bool active: false
    property string ssid: ""
    property string errorMessage: ""

    // Internal callbacks — set by requestPassword(), invoked when
    // the user submits or cancels. Stored as JS functions in plain
    // properties (var type) since QML can't hold typed function refs.
    property var _onSubmit: null
    property var _onCancel: null

    // ───── Public API ─────

    /**
     * Open the prompt for a given SSID. onSubmit receives the typed
     * password as its only argument when the user hits Connect or
     * presses Enter. onCancel (optional) is called when the user
     * dismisses without submitting.
     *
     * If a previous prompt is still active, that previous one is
     * cancelled before this new one opens (last-call-wins).
     */
    function requestPassword(ssid, onSubmit, onCancel) {
        // Cancel any in-flight prompt before opening a new one
        if (root.active && typeof root._onCancel === "function") {
            try { root._onCancel() } catch (e) { /* swallow */ }
        }
        root.ssid = ssid || ""
        root.errorMessage = ""
        root._onSubmit = (typeof onSubmit === "function") ? onSubmit : null
        root._onCancel = (typeof onCancel === "function") ? onCancel : null
        root.active = true
    }

    /** Programmatically set an error message (e.g. "Wrong password"). */
    function setError(msg) {
        root.errorMessage = msg || ""
    }

    /** Called by the window when user clicks Connect or hits Enter. */
    function _submit(password) {
        const cb = root._onSubmit
        // Clear callbacks BEFORE invoking — defensive against
        // re-entrant requestPassword calls during the callback.
        root._onSubmit = null
        root._onCancel = null
        root.active = false
        root.ssid = ""
        root.errorMessage = ""
        if (typeof cb === "function") {
            try { cb(password) } catch (e) {
                console.warn("[PasswordPromptService] submit cb threw:", e)
            }
        }
    }

    /** Called by the window when user clicks Cancel or hits Esc. */
    function _cancel() {
        const cb = root._onCancel
        root._onSubmit = null
        root._onCancel = null
        root.active = false
        root.ssid = ""
        root.errorMessage = ""
        if (typeof cb === "function") {
            try { cb() } catch (e) {
                console.warn("[PasswordPromptService] cancel cb threw:", e)
            }
        }
    }
}
