pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * PanasonicService v8.0.0-alpha-hf179 — Karui (軽い)
 *
 * Panasonic Let's Note support. Everything here is INERT on any other
 * machine: `isPanasonic` gates the settings page's visibility, and with it
 * false nothing polls, nothing writes and nothing appears in the sidebar.
 *
 * WHAT THIS COVERS
 * ────────────────
 *   1. Hardware identity from DMI (CF-SV9, CF-SZ6, CF-LX, FZ-… and so on)
 *   2. zen-wheelpad — circular scrolling for the round touchpad. libinput
 *      offers two-finger, edge and on-button scrolling and nothing else, so
 *      the wheel pad has to be synthesised by a daemon that grabs the pad and
 *      republishes it. This service owns that daemon's config file and its
 *      systemd user unit.
 *   3. panasonic-laptop kernel module — ECO mode (the ~80% battery charge
 *      limit that Let's Note firmware exposes) and sticky keys, via
 *      /sys/devices/platform/panasonic.
 *
 * ECO MODE CAVEAT, stated up front because it will otherwise read as a bug:
 * the kernel driver's own commit message says the setting "is persistent
 * until the next POST cycle which reset it to previous state". Writing it
 * from here holds until the next full power cycle, then the firmware's own
 * value wins again. Setting it in the Panasonic PC Settings Utility under
 * Windows is what makes it stick across reboots.
 *
 * Wala tayong babawasan — new singleton, no existing file changes behaviour
 * because of it.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfgDir: home + "/.config/zen-shell"
    readonly property string cfgPath: cfgDir + "/wheelpad.json"

    // ── Hardware identity ──
    property bool   isPanasonic: false

    // ══ v8.0.0-alpha-hf186 — DEVELOPER OVERRIDE ══
    //
    // `isPanasonic` is pure hardware truth and stays that way. But the page it
    // gates is unreachable on the machine it was WRITTEN on — the Ryzen desktop
    // this was built on is not a Let's Note, so the nav entry filtered itself
    // out and the whole feature looked like it had never shipped.
    //
    // `forceShow` is the override. Two ways in, for two different moments:
    //
    //   ZEN_PANASONIC_FORCE=1 quickshell    one session, nothing persisted
    //   zen-panasonic-setup.sh --force      writes force_page, survives restarts
    //
    // Kept strictly separate from `isPanasonic` so nothing downstream can
    // mistake an override for real hardware: the wheelpad daemon still refuses
    // to start without a Let's Note DMI unless separately told with
    // --any-machine, and the page says plainly that it is only visible because
    // you asked for it.
    property bool forceShow: (Quickshell.env("ZEN_PANASONIC_FORCE") === "1")
                             || (Quickshell.env("ZEN_PANASONIC_FORCE") === "true")

    /** What the sidebar gates on — real hardware OR an explicit override. */
    readonly property bool pageVisible: isPanasonic || forceShow
    property string vendor: ""
    property string model: ""
    property string touchpadName: ""
    property bool   probed: false

    // ── zen-wheelpad ──
    property bool   daemonInstalled: false
    property bool   daemonRunning: false
    property bool   evdevPresent: false
    property bool   inInputGroup: false

    property bool   wheelEnabled: true
    property real   ringInner: 0.62          // 0.40 – 0.90
    property real   degreesPerClick: 18.0    // 6 – 60
    property real   engageDegrees: 12.0
    property bool   naturalScroll: false
    property bool   horizontal: false

    // ── panasonic-laptop ──
    property bool   moduleLoaded: false
    property bool   ecoAvailable: false
    property bool   ecoMode: false
    property bool   stickyAvailable: false
    property bool   stickyKey: false

    readonly property string platformDir: "/sys/devices/platform/panasonic"

    /** Clicks per full revolution of the ring — what the UI should show. */
    readonly property int clicksPerTurn:
        degreesPerClick > 0 ? Math.round(360.0 / degreesPerClick) : 0

    readonly property string statusLine: {
        if (!isPanasonic && forceShow) return "Shown by override — DMI says this is not a Let's Note"
        if (!isPanasonic) return "Not a Panasonic system"
        if (!evdevPresent) return "python-evdev missing — circular scroll unavailable"
        if (!inInputGroup) return "Not in the 'input' group — daemon cannot read the pad"
        if (daemonRunning) return "Circular scroll active"
        if (daemonInstalled) return "Installed, not running"
        return "Not installed — run zen-panasonic-setup"
    }

    // ═══════════════════════════════════════════════════════════════
    // PROBE — one shot on start, and on demand from the settings page
    // ═══════════════════════════════════════════════════════════════
    function probe() {
        prober.running = false
        prober.running = true
    }

    Process {
        id: prober
        running: false
        command: ["bash", "-c",
            "d() { cat /sys/class/dmi/id/$1 2>/dev/null | tr -d '\\0'; }; " +
            "echo \"VENDOR=$(d sys_vendor)\"; " +
            "echo \"MODEL=$(d product_name)\"; " +
            // Touchpad name, first match by capability-ish naming.
            "TP=''; for f in /sys/class/input/event*/device/name; do " +
            "  n=$(cat \"$f\" 2>/dev/null); " +
            "  case \"${n,,}\" in *touchpad*|*trackpad*) TP=\"$n\"; break ;; esac; " +
            "done; echo \"TOUCHPAD=$TP\"; " +
            "python3 -c 'import evdev' 2>/dev/null && echo 'EVDEV=1' || echo 'EVDEV=0'; " +
            "id -nG 2>/dev/null | tr ' ' '\\n' | grep -qx input && echo 'INPUTGRP=1' || echo 'INPUTGRP=0'; " +
            "systemctl --user is-enabled zen-wheelpad.service >/dev/null 2>&1 && echo 'UNIT=1' || echo 'UNIT=0'; " +
            "systemctl --user is-active  zen-wheelpad.service >/dev/null 2>&1 && echo 'ACTIVE=1' || echo 'ACTIVE=0'; " +
            "lsmod 2>/dev/null | grep -q '^panasonic_laptop' && echo 'MODULE=1' || echo 'MODULE=0'; " +
            "P=/sys/devices/platform/panasonic; " +
            "[ -e \"$P/eco_mode\" ] && echo \"ECO=$(cat $P/eco_mode 2>/dev/null)\" || echo 'ECO=-'; " +
            "[ -e \"$P/sticky_key\" ] && echo \"STICKY=$(cat $P/sticky_key 2>/dev/null)\" || echo 'STICKY=-'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                let v = "", m = ""
                for (const raw of lines) {
                    const line = raw.trim()
                    const eq = line.indexOf("=")
                    if (eq < 0) continue
                    const key = line.substring(0, eq)
                    const val = line.substring(eq + 1)
                    switch (key) {
                        case "VENDOR":   v = val; break
                        case "MODEL":    m = val; break
                        case "TOUCHPAD": root.touchpadName = val; break
                        case "EVDEV":    root.evdevPresent = (val === "1"); break
                        case "INPUTGRP": root.inInputGroup = (val === "1"); break
                        case "UNIT":     root.daemonInstalled = (val === "1"); break
                        case "ACTIVE":   root.daemonRunning = (val === "1"); break
                        case "MODULE":   root.moduleLoaded = (val === "1"); break
                        case "ECO":
                            root.ecoAvailable = (val !== "-")
                            // The driver reports 0/1; some builds report the raw
                            // firmware byte (0x03 off, 0x83 on). Treat anything
                            // that is not a plain 0 as on.
                            root.ecoMode = root.ecoAvailable
                                           && val !== "0" && val !== "3" && val !== "0x03"
                            break
                        case "STICKY":
                            root.stickyAvailable = (val !== "-")
                            root.stickyKey = root.stickyAvailable && val !== "0"
                            break
                    }
                }
                root.vendor = v
                root.model = m
                const vl = v.toLowerCase()
                root.isPanasonic = (vl.indexOf("panasonic") >= 0)
                                   || (vl.indexOf("matsushita") >= 0)
                                   || m.toUpperCase().indexOf("CF-") === 0
                                   || m.toUpperCase().indexOf("FZ-") === 0
                root.probed = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // WHEELPAD CONFIG — same JSON the daemon reads
    // ═══════════════════════════════════════════════════════════════
    FileView {
        id: cfgFile
        path: root.cfgPath
        blockLoading: true
        blockAllReads: false
        onLoaded: {
            try {
                const txt = cfgFile.text()
                if (!txt || !txt.trim()) return
                const j = JSON.parse(txt)
                if (typeof j.enabled === "boolean")           root.wheelEnabled = j.enabled
                if (typeof j.ring_inner === "number")         root.ringInner = j.ring_inner
                if (typeof j.degrees_per_click === "number")  root.degreesPerClick = j.degrees_per_click
                if (typeof j.engage_degrees === "number")     root.engageDegrees = j.engage_degrees
                if (typeof j.natural === "boolean")           root.naturalScroll = j.natural
                if (typeof j.horizontal === "boolean")        root.horizontal = j.horizontal
                // hf186 — persisted override; an env var already set still wins.
                if (j.force_page === true) root.forceShow = true
            } catch (e) {
                console.warn("PanasonicService: wheelpad.json unparseable:", e)
            }
        }
        onLoadFailed: saveDebounced.restart()   // first run — write defaults
    }

    Timer {
        id: saveDebounced
        interval: 250
        repeat: false
        onTriggered: root._writeConfig()
    }

    function _writeConfig() {
        const obj = {
            "enabled": root.wheelEnabled,
            "ring_inner": root.ringInner,
            "degrees_per_click": root.degreesPerClick,
            "engage_degrees": root.engageDegrees,
            "natural": root.naturalScroll,
            "horizontal": root.horizontal,
            "force_page": root.forceShow,
            "device": "",
            "require_panasonic": true
        }
        const json = JSON.stringify(obj, null, 2)
        // Atomic write, same pattern as DenshoService / PanelState.
        cfgWriter.command = ["bash", "-c",
            "mkdir -p '" + root.cfgDir + "' && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_WHEELPAD_EOF'\n" + json + "\nZEN_WHEELPAD_EOF\n" +
            "mv \"$tmp\" '" + root.cfgPath + "'"
        ]
        cfgWriter.running = true
    }

    Process { id: cfgWriter; running: false }

    onWheelEnabledChanged:    saveDebounced.restart()
    onRingInnerChanged:       saveDebounced.restart()
    onDegreesPerClickChanged: saveDebounced.restart()
    onEngageDegreesChanged:   saveDebounced.restart()
    onNaturalScrollChanged:   saveDebounced.restart()
    onHorizontalChanged:      saveDebounced.restart()

    // ═══════════════════════════════════════════════════════════════
    // ACTIONS
    // ═══════════════════════════════════════════════════════════════

    /** The daemon re-reads its config on start, so a restart applies edits. */
    function restartDaemon() {
        _run("systemctl --user restart zen-wheelpad.service")
    }
    function startDaemon() {
        _run("systemctl --user enable --now zen-wheelpad.service")
    }
    function stopDaemon() {
        // Stopping is always safe: the kernel drops the EVIOCGRAB with the
        // process, so the physical touchpad returns to the compositor even
        // if the daemon was killed rather than asked nicely.
        _run("systemctl --user disable --now zen-wheelpad.service")
    }

    function setEcoMode(on) {
        if (!ecoAvailable) return
        // Needs root. pkexec puts a polkit prompt in front rather than
        // failing silently, which is the honest behaviour here.
        _run("pkexec sh -c 'echo " + (on ? "1" : "0") +
             " > " + platformDir + "/eco_mode'")
    }

    function setStickyKey(on) {
        if (!stickyAvailable) return
        _run("pkexec sh -c 'echo " + (on ? "1" : "0") +
             " > " + platformDir + "/sticky_key'")
    }

    function loadModule() {
        _run("pkexec modprobe panasonic-laptop")
    }

    function _run(cmd) {
        if (actionRunner.running) actionRunner.running = false
        actionRunner.command = ["bash", "-c", cmd]
        actionRunner.running = true
    }

    Process {
        id: actionRunner
        running: false
        onExited: reprobeTimer.restart()
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0)
                    console.warn("[PanasonicService]:", text.trim())
            }
        }
    }

    Timer {
        id: reprobeTimer
        interval: 900
        repeat: false
        onTriggered: root.probe()
    }

    Component.onCompleted: Qt.callLater(root.probe)
}
