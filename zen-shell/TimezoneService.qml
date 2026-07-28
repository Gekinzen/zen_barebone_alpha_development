pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * TimezoneService v8.0.0-alpha-hf111 — Karui (軽い)
 *
 * The complete IANA timezone list, read from the system itself:
 *
 *   1. `timedatectl list-timezones`  (systemd, authoritative)
 *   2. `/usr/share/zoneinfo/**`      (works on any distro, no systemd needed)
 *   3. a small built-in list          (last resort — never leaves the picker empty)
 *
 * ~430 zones on a normal install, so Asia/Qatar, Africa/Kigali, Pacific/Chatham
 * and every other zone is there. Region-first ordering keeps the picker sane.
 *
 * Exposes:
 *   zones       [{ id: "Asia/Qatar", label: "Asia / Qatar", region: "Asia", city: "Qatar" }]
 *   loaded      true once the real list is in
 *   indexOf(id) position in `zones`, or -1
 */
Singleton {
    id: root

    property var zones: []
    property bool loaded: false

    readonly property var _fallback: [
        "Asia/Manila", "Asia/Qatar", "Asia/Dubai", "Asia/Tokyo", "Asia/Seoul",
        "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore", "Asia/Kolkata", "Asia/Karachi",
        "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Madrid", "Europe/Moscow",
        "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
        "America/Toronto", "America/Vancouver", "America/Winnipeg", "America/Sao_Paulo",
        "Australia/Sydney", "Australia/Perth", "Pacific/Auckland", "Africa/Cairo",
        "Africa/Lagos", "Africa/Johannesburg", "UTC"
    ]

    function _mk(id) {
        const parts = id.split("/")
        const region = parts.length > 1 ? parts[0] : "Other"
        const city = parts[parts.length - 1].replace(/_/g, " ")
        return { id: id, region: region, city: city,
                 label: (parts.length > 1 ? (region + " / " + city) : id) }
    }

    function indexOf(id) {
        for (let i = 0; i < zones.length; i++) if (zones[i].id === id) return i
        return -1
    }

    function _apply(lines) {
        const seen = {}
        const out = []
        for (let i = 0; i < lines.length; i++) {
            const id = lines[i].trim()
            if (id.length === 0 || seen[id]) continue
            // skip legacy aliases and the posix/right trees
            if (id.indexOf("posix/") === 0 || id.indexOf("right/") === 0) continue
            if (id.indexOf("SystemV/") === 0) continue
            seen[id] = true
            out.push(_mk(id))
        }
        if (out.length === 0) return
        // The zoneinfo walk can miss the bare UTC file on some layouts; the
        // picker must always offer it.
        if (!seen["UTC"]) out.push(_mk("UTC"))
        out.sort((a, b) => a.region === b.region
                           ? a.city.localeCompare(b.city)
                           : a.region.localeCompare(b.region))
        // UTC first — it's the one people reach for
        const utc = out.filter(z => z.id === "UTC")
        const rest = out.filter(z => z.id !== "UTC")
        root.zones = utc.concat(rest)
        root.loaded = true
    }

    Process {
        id: tzList
        running: false
        command: ["bash", "-c",
            // systemd first, then a plain zoneinfo walk (any distro, no systemd)
            "timedatectl list-timezones 2>/dev/null || " +
            // -type l too: UTC (and several aliases) are symlinks, so a plain
            // -type f walk silently drops them.
            "{ find /usr/share/zoneinfo \\( -type f -o -type l \\) " +
            "    -not -name '*.tab' -not -name 'posixrules' -not -name 'localtime' " +
            "    2>/dev/null | sed 's|/usr/share/zoneinfo/||' " +
            "  | grep -E '^[A-Z][A-Za-z_]+/|^UTC$' | sort -u; }"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = (this.text || "").trim()
                if (txt.length > 0) root._apply(txt.split("\n"))
                if (!root.loaded) root._apply(root._fallback)   // never empty
            }
        }
    }

    Component.onCompleted: {
        _apply(_fallback)          // instant, so the picker is never empty
        loaded = false
        tzList.running = true      // then replace with the real list
    }
}
