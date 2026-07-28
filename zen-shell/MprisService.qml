pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * MprisService v7.0.0-beta.1-hf99zy — Karui (軽い)
 *
 * Media controls for whatever MPRIS player is active (Spotify, mpv, browsers…).
 * Backed by `playerctl`, polled once a second — no D-Bus binding needed, and it
 * degrades quietly to `available: false` when playerctl isn't installed or no
 * player is running.
 *
 * Exposes:
 *   available, status ("Playing"/"Paused"/"Stopped"), playing
 *   title, artist, album, artUrl, playerName
 *   positionSec, lengthSec, progress (0..1)
 *   playPause(), next(), previous()
 */
Singleton {
    id: root

    property bool   available: false
    property string status: "Stopped"
    readonly property bool playing: status === "Playing"

    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string playerName: ""

    property int positionSec: 0
    property int lengthSec: 0
    readonly property real progress: lengthSec > 0 ? Math.min(1, positionSec / lengthSec) : 0

    function _fmt(sec) {
        if (sec <= 0) return "0:00"
        const m = Math.floor(sec / 60), s = sec % 60
        return m + ":" + String(s).padStart(2, "0")
    }
    readonly property string positionText: _fmt(positionSec)
    readonly property string lengthText: _fmt(lengthSec)

    // ── Controls ──
    function playPause() { _ctl.command = ["bash", "-c", "playerctl play-pause 2>/dev/null || true"]; _ctl.running = true }
    function next()      { _ctl.command = ["bash", "-c", "playerctl next 2>/dev/null || true"];       _ctl.running = true }
    function previous()  { _ctl.command = ["bash", "-c", "playerctl previous 2>/dev/null || true"];   _ctl.running = true }

    Process { id: _ctl; running: false }

    // ── Poll ──
    // One call, pipe-separated, so a missing field can't shift the others.
    Process {
        id: _poll
        running: false
        command: ["bash", "-c",
            "command -v playerctl >/dev/null 2>&1 || { echo 'NOPLAYERCTL'; exit 0; }; " +
            "st=$(playerctl status 2>/dev/null) || { echo 'NOPLAYER'; exit 0; }; " +
            "printf '%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\n' " +
            "\"$st\" " +
            "\"$(playerctl metadata title 2>/dev/null)\" " +
            "\"$(playerctl metadata artist 2>/dev/null)\" " +
            "\"$(playerctl metadata album 2>/dev/null)\" " +
            "\"$(playerctl metadata mpris:artUrl 2>/dev/null)\" " +
            "\"$(playerctl metadata --format '{{ position }}' 2>/dev/null)\" " +
            "\"$(playerctl metadata --format '{{ mpris:length }}' 2>/dev/null)\"; " +
            "playerctl -l 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function _parse(txt) {
        const raw = (txt || "").trim()
        if (raw === "" || raw.indexOf("NOPLAYERCTL") === 0 || raw.indexOf("NOPLAYER") === 0) {
            available = false
            status = "Stopped"
            title = ""; artist = ""; album = ""; artUrl = ""
            positionSec = 0; lengthSec = 0
            return
        }
        const lines = raw.split("\n")
        const f = lines[0].split("\u001f")
        if (f.length < 7) { available = false; return }

        available = true
        status = f[0].trim() || "Stopped"
        title  = f[1].trim()
        artist = f[2].trim()
        album  = f[3].trim()
        artUrl = f[4].trim()

        // playerctl reports both in microseconds
        const pos = parseInt(f[5], 10)
        const len = parseInt(f[6], 10)
        positionSec = isNaN(pos) ? 0 : Math.floor(pos / 1000000)
        lengthSec   = isNaN(len) ? 0 : Math.floor(len / 1000000)

        playerName = (lines.length > 1) ? lines[1].trim() : ""
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!_poll.running) _poll.running = true
    }
}
