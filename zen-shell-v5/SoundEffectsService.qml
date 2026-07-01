pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * SoundEffectsService v7.0.0-beta.1-hf32 — Karui (軽い)
 *
 * Cute system sound effects like KDE Plasma + Cosmic Pop OS:
 *   - Login/startup chime when shell becomes ready
 *   - Future events (logout, workspace, notification accent, etc.)
 *
 * Uses freedesktop sound theme via canberra-gtk-play. Falls back
 * silently if not installed.
 *
 * Toggleable from Settings → General → "System sound effects".
 * Default: ENABLED — most users like the audible feedback. Disable
 * is a single click away for sound-sensitive setups.
 *
 * State persists to ~/.config/quickshell/zen-shell/sound-effects.json
 *
 * Events mapped to freedesktop sound IDs:
 *   "login"        → service-login
 *   "logout"       → service-logout
 *   "complete"     → complete
 *   "bell"         → bell
 *   "alarm"        → alarm-clock-elapsed
 *   "click"        → button-pressed (subtle — for UI clicks if user opts in)
 *
 * The freedesktop sound theme ships with most distros via the
 * `sound-theme-freedesktop` package. On CachyOS/Arch:
 *   pacman -S sound-theme-freedesktop libcanberra
 *
 * v7.0.0-beta.1-hf32 — playback architecture fix.
 *   Previously played via QML Process spawning `bash -c "canberra-gtk-play ... &"`
 *   This was fragile in two ways:
 *     1. The bash wrapper exits as soon as it backgrounds canberra. The
 *        canberra child inherits bash's session — when bash exits, the
 *        kernel could send SIGHUP to the orphan if it had no controlling
 *        terminal management. Audio buffer would cut mid-play (the
 *        "naputol yung opening sound" symptom).
 *     2. The `if (player.running) return` guard dropped any new play
 *        request while the bash wrapper was still alive, which during
 *        shell startup race could swallow the very first login chime.
 *
 *   Now uses Quickshell.execDetached() which spawns canberra-gtk-play
 *   as a fully session-detached child of Quickshell (effectively
 *   double-fork + setsid semantics). The audio process owns its own
 *   process group, survives parent transitions, and plays the FULL
 *   sample buffer through canberra's own event loop.
 *
 *   Removed the busy-skip guard since detached spawns can't conflict.
 *   The per-event throttle (throttleMs window) still handles spam
 *   from rapid scroll/slider drag.
 */
Singleton {
    id: root

    // ── Persisted config ──
    property bool enabled: true
    property bool playLoginSound: true       // sub-toggle for login/startup
    property bool playClickSounds: false     // sub-toggle for UI clicks (off by default — too chatty)
    property bool playVolumeSounds: true     // sub-toggle for volume up/down ticks
    property real volume: 0.6                // 0.0-1.0, passed to canberra-gtk-play

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/zen-shell/sound-effects.json"

    // ── Throttle ──
    //
    // Rapid events (volume scrolling, slider drag) would spam canberra
    // 10-20 times/sec without throttle. Track last-play timestamp per
    // event so we fire at most once per throttleMs window.
    readonly property int throttleMs: 80
    property var _lastPlayMs: ({})

    // ── Persistence ──
    //
    // v7.0.0-beta.1-hf19: Removed `Component.onCompleted: loader.reload()`
    // and `onLoadFailed: root._save()`. Reasons:
    //   - FileView auto-loads from path; explicit reload was redundant
    //     and could double-fire onLoaded handlers during singleton init
    //   - onLoadFailed spawning a save subprocess during init was racing
    //     with shell startup and contributing to crashes (QEventLoop
    //     warning at shutdown)
    // If the state file doesn't exist, defaults stay in memory; first
    // user toggle writes the file via the normal saveDebounce path.

    FileView {
        id: loader
        path: root.statePath
        onLoaded: {
            try {
                const j = JSON.parse(this.text() || "{}")
                if (typeof j.enabled === "boolean") root.enabled = j.enabled
                if (typeof j.playLoginSound === "boolean") root.playLoginSound = j.playLoginSound
                if (typeof j.playClickSounds === "boolean") root.playClickSounds = j.playClickSounds
                if (typeof j.playVolumeSounds === "boolean") root.playVolumeSounds = j.playVolumeSounds
                if (typeof j.volume === "number") root.volume = j.volume
                console.log("[SoundEffectsService] Loaded: enabled=" + root.enabled
                          + " login=" + root.playLoginSound)
            } catch (e) {
                console.warn("[SoundEffectsService] state parse error:", e)
            }
        }
    }

    function _save() {
        // v7.0.0-beta.1-hf19: don't stack save subprocesses. The debounce
        // Timer already coalesces rapid toggle bursts, but if user
        // somehow triggers two saves <300ms apart through different
        // code paths, we'd overwrite saver.command mid-flight.
        if (saver.running) {
            // Try again after a short delay (next debounce window)
            saveDebounce.restart()
            return
        }
        const obj = {
            enabled: root.enabled,
            playLoginSound: root.playLoginSound,
            playClickSounds: root.playClickSounds,
            playVolumeSounds: root.playVolumeSounds,
            volume: root.volume
        }
        saver.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.statePath + "')\" && " +
            "cat > '" + root.statePath + "' << 'EOF'\n" +
            JSON.stringify(obj, null, 2) + "\n" +
            "EOF"
        ]
        saver.running = true
    }

    Process { id: saver; running: false }

    // Debounce save on rapid toggles
    Timer {
        id: saveDebounce
        interval: 300
        repeat: false
        onTriggered: root._save()
    }
    onEnabledChanged:        saveDebounce.restart()
    onPlayLoginSoundChanged: saveDebounce.restart()
    onPlayClickSoundsChanged: saveDebounce.restart()
    onPlayVolumeSoundsChanged: saveDebounce.restart()
    onVolumeChanged:         saveDebounce.restart()

    // ── Event → sound file mapping ──
    function _eventToSoundId(event) {
        switch (event) {
            case "login":         return "service-login"
            case "logout":        return "service-logout"
            case "complete":      return "complete"
            case "bell":          return "bell"
            case "alarm":         return "alarm-clock-elapsed"
            case "click":         return "button-pressed"
            case "volume-change": return "audio-volume-change"
            case "mute":          return "audio-volume-change"
        }
        return ""
    }

    // ── Public API ──
    //
    // Call from anywhere: SoundEffectsService.play("login")
    //
    // Respects master + per-event toggles. Falls back silently if
    // canberra-gtk-play isn't installed (no error spam).
    //
    // v7.0.0-beta.1-hf32: spawns via Quickshell.execDetached() so the
    // audio plays through to completion regardless of shell state.
    // Per-event throttle still applies (prevents scroll spam).
    function play(event) {
        if (!root.enabled) return
        // Per-event sub-gates
        if (event === "login" && !root.playLoginSound) return
        if (event === "click" && !root.playClickSounds) return
        if ((event === "volume-change" || event === "mute")
            && !root.playVolumeSounds) return

        const soundId = _eventToSoundId(event)
        if (!soundId) {
            console.warn("[SoundEffectsService] Unknown event:", event)
            return
        }

        // v7.0.0-beta.1-hf17: throttle per event so rapid changes
        // (scroll wheel, slider drag) don't spam canberra-gtk-play.
        const now = Date.now()
        const last = root._lastPlayMs[event] || 0
        if (now - last < root.throttleMs) return
        root._lastPlayMs[event] = now

        // v7.0.0-beta.1-hf32: Quickshell.execDetached spawns canberra
        // fully detached (own session, own process group). This means:
        //   - Audio buffer plays to completion (no SIGHUP mid-sample
        //     when QML reloads or the parent bash exits).
        //   - Multiple sounds can overlap if needed (no busy-skip
        //     race).
        //   - No QML Process state object to babysit — no risk of
        //     state corruption from rapid calls (which contributed to
        //     hf19 crash class).
        //
        // The setsid wrapper guarantees session detachment even on
        // shells/distros where canberra-gtk-play doesn't daemonize
        // itself. nohup belt-and-suspenders against SIGHUP.
        //
        // Volume property is multiplied into canberra's stream gain.
        const vol = Math.max(0, Math.min(1, root.volume))
        try {
            Quickshell.execDetached({
                command: ["bash", "-c",
                    "command -v canberra-gtk-play >/dev/null 2>&1 || exit 0; " +
                    "exec setsid -f nohup canberra-gtk-play " +
                    "-i '" + soundId + "' " +
                    "--property=canberra.volume=" + vol +
                    " </dev/null >/dev/null 2>&1"
                ]
            })
        } catch (e) {
            // Quickshell.execDetached not available in very old builds —
            // fall back to the Process path (which the rest of the
            // shell already depends on existing).
            console.warn("[SoundEffectsService] execDetached unavailable, "
                       + "falling back to Process path:", e)
            player.command = ["bash", "-c",
                "command -v canberra-gtk-play >/dev/null 2>&1 && " +
                "setsid -f nohup canberra-gtk-play -i '" + soundId + "' "
                + "--property=canberra.volume=" + vol
                + " </dev/null >/dev/null 2>&1"
            ]
            player.running = true
        }
    }

    // Retained for fallback path only (see play() above).
    Process { id: player; running: false }
}
