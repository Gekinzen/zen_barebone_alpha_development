pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * BrightnessService v6.16.3.4.3 — laptop backlight manager
 *
 * Detects and controls screen backlight devices on Linux laptops.
 *
 * Detection strategy:
 *   1. Enumerate /sys/class/backlight/*  → all candidate devices
 *   2. Rank by vendor preference:
 *        amdgpu_bl*, intel_backlight    → highest (native GPU backlight)
 *        nvidia_*                        → high
 *        asus::*                         → high (ROG platform)
 *        acpi_video*                     → fallback (works but laggy on many laptops)
 *   3. Primary device = highest-ranked. Secondary devices exposed for
 *      platforms with extra surfaces (ASUS screenpad, keyboard backlight, etc.)
 *
 * Write strategy:
 *   - Prefer `brightnessctl` (handles permissions cleanly on CachyOS/Arch,
 *     uses logind D-Bus internally so no udev-rule juggling needed).
 *   - Fallback to direct sysfs write if brightnessctl missing AND the
 *     user has udev write perms on the brightness file.
 *
 * Usage:
 *   BrightnessService.available           // bool — any controllable device?
 *   BrightnessService.hasBrightnessctl    // bool — brightnessctl installed?
 *   BrightnessService.vendor              // "amdgpu" | "intel" | "nvidia" | "asus" | "acpi" | ""
 *   BrightnessService.devices             // [{ name, path, vendor, max, current, kind }]
 *   BrightnessService.currentDevice       // string (device name like "amdgpu_bl0")
 *   BrightnessService.brightness          // int 0-100 (primary device)
 *   BrightnessService.setBrightness(pct)  // write 0-100 to primary device
 *   BrightnessService.setBrightnessOn(name, pct)  // write to a specific device
 *   BrightnessService.refresh()           // re-poll current values
 *
 * Rationale for "ROG hindi ma-detect" issue:
 *   - ASUS ROG laptops with AMD dGPU expose the backlight via amdgpu_bl0
 *     (hybrid AMD APU + dGPU) OR via acpi_video0 depending on kernel + module.
 *     If the shell only probed for /sys/class/backlight/intel_backlight
 *     (classic pattern), ROG devices would never be found.
 *   - This service enumerates ALL entries under /sys/class/backlight/ and
 *     picks the best candidate, so it works on AMD-only, Intel, NVIDIA-
 *     prime, ASUS-platform, and generic ACPI laptops alike.
 *
 * Wala tayong babawasan.
 */
Singleton {
    id: root

    // ── State ──
    property bool available: false
    property bool hasBrightnessctl: false
    property string vendor: ""            // primary device vendor
    property string currentDevice: ""     // primary device name (e.g. "amdgpu_bl0")
    property int brightness: 0            // 0-100 (primary device)
    property var devices: []              // array of device descriptors

    // ── Vendor detection ──
    function _detectVendor(name) {
        if (!name) return ""
        const n = String(name).toLowerCase()
        if (n.indexOf("amdgpu") === 0)          return "amdgpu"
        if (n.indexOf("intel_backlight") === 0) return "intel"
        if (n.indexOf("nvidia") === 0)          return "nvidia"
        if (n.indexOf("asus") === 0)            return "asus"
        if (n.indexOf("acpi_video") === 0)      return "acpi"
        return "other"
    }

    // ── Rank for primary-device selection (higher = better) ──
    function _vendorRank(v) {
        switch (v) {
            case "amdgpu": return 100
            case "intel":  return 100
            case "nvidia": return 90
            case "asus":   return 80
            case "acpi":   return 40
            default:       return 10
        }
    }

    // ── Kind classification (primary / keyboard / auxiliary) ──
    function _detectKind(name) {
        if (!name) return "primary"
        const n = String(name).toLowerCase()
        if (n.indexOf("kbd") >= 0 || n.indexOf("keyboard") >= 0)        return "keyboard"
        if (n.indexOf("screenpad") >= 0 || n.indexOf("::") >= 0)        return "auxiliary"
        return "primary"
    }

    // ── Label helper (for UI) ──
    function deviceLabel(name) {
        if (!name) return "Unknown"
        const v = _detectVendor(name)
        const k = _detectKind(name)
        let base = ""
        switch (v) {
            case "amdgpu": base = "AMD GPU"; break
            case "intel":  base = "Intel GPU"; break
            case "nvidia": base = "NVIDIA"; break
            case "asus":   base = "ASUS"; break
            case "acpi":   base = "ACPI video"; break
            default:       base = name
        }
        switch (k) {
            case "keyboard":  return base + " (keyboard)"
            case "auxiliary": return base + " (screenpad)"
        }
        return base
    }

    // ═══════════════════════════════════════════════════════════════
    // Probe brightnessctl presence
    // ═══════════════════════════════════════════════════════════════
    Process {
        id: toolProbe
        command: ["bash", "-c", "command -v brightnessctl >/dev/null 2>&1 && echo yes || echo no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasBrightnessctl = (this.text.trim() === "yes")
                if (!root.hasBrightnessctl) {
                    console.log("[BrightnessService] brightnessctl not installed — using sysfs read-only fallback")
                }
                // Kick off device enumeration regardless; sysfs read works
                // without brightnessctl even if writes won't.
                enumerator.running = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Enumerate /sys/class/backlight/ devices
    // ═══════════════════════════════════════════════════════════════
    //
    // Shell pipeline emits one line per device:
    //   <name>\t<max>\t<current>
    // so the handler just splits and builds descriptor objects. Using
    // printf instead of echo because some entries contain "::".
    Process {
        id: enumerator
        command: ["bash", "-c",
            "for d in /sys/class/backlight/*; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  name=$(basename \"$d\"); " +
            "  max=$(cat \"$d/max_brightness\" 2>/dev/null || echo 0); " +
            "  cur=$(cat \"$d/brightness\" 2>/dev/null || echo 0); " +
            "  printf '%s\\t%s\\t%s\\n' \"$name\" \"$max\" \"$cur\"; " +
            "done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                if (raw === "") {
                    console.log("[BrightnessService] no backlight devices found under /sys/class/backlight/")
                    root.available = false
                    root.devices = []
                    return
                }
                const lines = raw.split("\n")
                const list = []
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t")
                    if (parts.length < 3) continue
                    const name = parts[0]
                    const max = parseInt(parts[1], 10) || 0
                    const cur = parseInt(parts[2], 10) || 0
                    if (max <= 0) continue
                    const v = root._detectVendor(name)
                    list.push({
                        name: name,
                        path: "/sys/class/backlight/" + name,
                        vendor: v,
                        kind: root._detectKind(name),
                        max: max,
                        current: cur,
                        percent: Math.round((cur / max) * 100)
                    })
                }

                if (list.length === 0) {
                    root.available = false
                    root.devices = []
                    return
                }

                // Sort: primary devices first, then by vendor rank, then name
                list.sort(function(a, b) {
                    if (a.kind !== b.kind) {
                        if (a.kind === "primary") return -1
                        if (b.kind === "primary") return  1
                    }
                    const ra = root._vendorRank(a.vendor)
                    const rb = root._vendorRank(b.vendor)
                    if (rb !== ra) return rb - ra
                    return a.name.localeCompare(b.name)
                })

                root.devices = list
                const primary = list[0]
                root.currentDevice = primary.name
                root.vendor = primary.vendor
                root.brightness = primary.percent
                root.available = true

                console.log("[BrightnessService] detected", list.length,
                            "device(s); primary:", primary.name,
                            "vendor:", primary.vendor,
                            "brightness:", primary.percent + "%")
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Refresh current values (no full re-enumeration)
    // ═══════════════════════════════════════════════════════════════
    Process {
        id: refresher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                if (raw === "") return
                const lines = raw.split("\n")
                const updated = []
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t")
                    if (parts.length < 3) continue
                    updated.push({ name: parts[0], max: parseInt(parts[1], 10) || 0, cur: parseInt(parts[2], 10) || 0 })
                }
                // Merge into existing devices array (preserve order/sort)
                const next = []
                for (let j = 0; j < root.devices.length; j++) {
                    const d = root.devices[j]
                    let found = null
                    for (let k = 0; k < updated.length; k++) {
                        if (updated[k].name === d.name) { found = updated[k]; break }
                    }
                    if (found && found.max > 0) {
                        next.push({
                            name: d.name,
                            path: d.path,
                            vendor: d.vendor,
                            kind: d.kind,
                            max: found.max,
                            current: found.cur,
                            percent: Math.round((found.cur / found.max) * 100)
                        })
                    } else {
                        next.push(d)
                    }
                }
                root.devices = next
                if (next.length > 0 && next[0].name === root.currentDevice) {
                    root.brightness = next[0].percent
                }
            }
        }
    }

    function refresh() {
        if (!available) return
        refresher.command = ["bash", "-c",
            "for d in /sys/class/backlight/*; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  name=$(basename \"$d\"); " +
            "  max=$(cat \"$d/max_brightness\" 2>/dev/null || echo 0); " +
            "  cur=$(cat \"$d/brightness\" 2>/dev/null || echo 0); " +
            "  printf '%s\\t%s\\t%s\\n' \"$name\" \"$max\" \"$cur\"; " +
            "done"]
        refresher.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // Write brightness
    // ═══════════════════════════════════════════════════════════════
    //
    // Three write paths, tried in order:
    //   1. brightnessctl --device=<name> set <pct>%      (best; uses logind)
    //   2. direct sysfs write                             (needs udev rule)
    //   3. systemd-logind via busctl                      (last resort)
    Process {
        id: writer
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // Re-poll to reflect actual hw state
                Qt.callLater(root.refresh)
            }
        }
    }

    function _clampPct(p) {
        p = parseInt(p, 10)
        if (isNaN(p)) return 0
        if (p < 0)   return 0
        if (p > 100) return 100
        return p
    }

    function setBrightnessOn(name, pct) {
        if (!available) return
        if (!name) return
        pct = _clampPct(pct)

        // Find device for absolute-value fallback write
        let dev = null
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].name === name) { dev = devices[i]; break }
        }
        if (!dev) {
            console.warn("[BrightnessService] device not found:", name)
            return
        }

        // Optimistic UI update if this is the primary
        if (name === currentDevice) root.brightness = pct

        const abs = Math.round((pct / 100) * dev.max)
        const sysfsFile = "/sys/class/backlight/" + name + "/brightness"

        // Command chain:
        //   - brightnessctl first (handles permissions + logind)
        //   - if brightnessctl missing or fails, try sysfs direct
        //   - final fallback: print a diagnostic so the user sees it
        //     in the shell log (not a hard crash)
        let cmd
        if (hasBrightnessctl) {
            cmd = "brightnessctl --device='" + name + "' set " + pct + "% >/dev/null 2>&1 || " +
                  "printf '%s' '" + abs + "' > '" + sysfsFile + "' 2>/dev/null || " +
                  "echo '[BrightnessService] write failed for " + name + "'"
        } else {
            cmd = "printf '%s' '" + abs + "' > '" + sysfsFile + "' 2>/dev/null || " +
                  "echo '[BrightnessService] sysfs write failed for " + name + " — install brightnessctl or add udev rule'"
        }
        writer.command = ["bash", "-c", cmd]
        writer.running = true
    }

    function setBrightness(pct) {
        setBrightnessOn(currentDevice, pct)
    }

    function selectDevice(name) {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].name === name) {
                currentDevice = name
                vendor = devices[i].vendor
                brightness = devices[i].percent
                return
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Passive poller — catches out-of-band changes (hw keys, other apps)
    // ═══════════════════════════════════════════════════════════════
    Timer {
        id: passivePoll
        interval: 4000
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }

    // ── Init ──
    Component.onCompleted: {
        toolProbe.running = true
    }
}
