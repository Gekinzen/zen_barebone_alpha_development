pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * SystemMonitorService — system stats provider for bar + desktop widgets
 *
 * v6.8: Pure QML replacement for Python system_monitor_widget.py.
 * Reads from /proc/stat, /proc/meminfo, /sys/class/hwmon, etc.
 * No Python or psutil dependency. Updates every 2 seconds.
 *
 * v6.16.0: Added battery section (/sys/class/power_supply/BAT*) +
 * swaync notifications at 30% warning and 10% critical (with hysteresis
 * so notifications only fire once per threshold crossing). batteryPresent
 * stays false on desktops so UI components can hide cleanly.
 *
 * Bar modules bind to: cpuPercent, cpuTemp, gpuTemp, gpuUsage,
 * ramPercent, ramUsedGb, ramTotalGb, netDown, netUp,
 * batteryCapacity, batteryStatus, batteryCharging, batteryPresent
 */
Singleton {
    id: root

    // ── CPU ──
    property int cpuPercent: 0
    property int cpuTemp: 0         // °C, 0 = unavailable
    // v7.0.0-beta.1-hf99zf: clock speeds (MHz, 0 = unavailable)
    property int cpuMhz: 0
    property int gpuMhz: 0
    property string cpuName: "CPU"

    // ── GPU ──
    property int gpuUsage: 0
    property int gpuTemp: 0
    property real gpuVramUsed: 0    // GB
    property real gpuVramTotal: 0
    property string gpuName: "GPU"
    property string gpuType: "unknown"  // "amd" | "nvidia" | "intel" | "unknown"

    // ── v6.16.1: Multi-GPU support ──
    // Extends the single-GPU model above without removing it. The first
    // entry in gpus[] mirrors gpuUsage/gpuTemp/etc (primary GPU). Additional
    // entries represent secondary/discrete GPUs. DesktopWidgets tabs bind
    // to gpus[n].
    //
    // Each entry:
    //   { index, name, type, usage, temp, vramUsed, vramTotal, history, driver }
    // where history is a Nth-sample array (40 points) for sparklines.
    //
    // On single-GPU systems, gpus.length === 1. On multi-GPU (Optimus
    // laptops like Paul's ROG, or dual-card workstations), gpus.length >= 2.
    property var gpus: []
    property int gpuCount: 0   // convenience: gpus.length

    // ── RAM ──
    property int ramPercent: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    // ── v6.16.0: Battery ──
    // batteryPresent = false on desktops (no BAT0/BAT1 under /sys/class/power_supply).
    // UI components bind to batteryPresent to hide cleanly on desktops.
    //
    // batteryStatus mirrors the kernel's status string: "Charging",
    // "Discharging", "Full", "Not charging", "Unknown".
    //
    // batteryCharging is derived: true if status is "Charging", else false.
    // (Keeps consumers simple — they don't have to parse the string.)
    //
    // batteryCriticalNotified / batteryWarningNotified are debounce flags
    // so we only fire one notification per threshold crossing. Reset when
    // the battery climbs back above threshold+5 (hysteresis).
    property bool batteryPresent: false
    property int batteryCapacity: 0
    property string batteryStatus: "Unknown"
    property bool batteryCharging: false
    property real batteryPowerDraw: 0.0           // watts (0 if unknown)
    property string batteryTimeRemaining: ""      // human-readable (from upower)
    property string batteryDevice: ""             // e.g. "BAT0" / "BAT1" / ""

    // Notification debounce state
    property bool _batteryWarningFired: false
    property bool _batteryCriticalFired: false
    property int batteryWarningThreshold: 30
    property int batteryCriticalThreshold: 10

    // ── Network ──
    property string netDown: "0 B/s"
    property string netUp: "0 B/s"
    property real netDownBps: 0
    property real netUpBps: 0

    // ── History (for graphs) ──
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property var netHistory: []
    readonly property int historyMax: 40

    // ── Internal ──
    property real _prevRx: 0
    property real _prevTx: 0
    property bool _firstRun: true

    // ── Color helpers ──
    function tempColor(temp) {
        if (temp < 50) return ThemeService.green
        if (temp < 65) return ThemeService.yellow
        if (temp < 80) return ThemeService.orange
        return ThemeService.red
    }

    function usageColor(pct) {
        if (pct < 50) return ThemeService.green
        if (pct < 70) return ThemeService.yellow
        if (pct < 85) return ThemeService.orange
        return ThemeService.red
    }

    // ── Auto-refresh ──
    //
    // v7.0.0-alpha.5 (Karui Laptop Mode): Timer interval is now bound to
    // LaptopModeService.intervalSystemMonitor. Defaults to 2000ms (the
    // pre-v7 value) when LaptopModeService.mode === "off". Adapts down
    // to 5000–30000ms based on mode + battery%/AC state. See
    // LaptopModeService.qml header comment for the full table.
    Timer {
        interval: (typeof LaptopModeService !== "undefined")
            ? LaptopModeService.intervalSystemMonitor
            : 2000
        repeat: true
        running: true
        onTriggered: root.update()
    }

    // ── All-in-one stats fetcher ──
    Process {
        id: statsFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._parseStats(this.text)
            }
        }
    }

    function update() {
        // Single bash call that gathers everything at once — efficient
        statsFetcher.command = ["bash", "-c",
            "echo '---CPU_STAT---'; " +
            "head -1 /proc/stat 2>/dev/null; " +

            "echo '---CPU_TEMP---'; " +
            // k10temp (AMD) → coretemp (Intel) → zenpower → fallback
            "for d in /sys/class/hwmon/hwmon*/; do " +
            "  name=$(cat ${d}name 2>/dev/null); " +
            "  case $name in k10temp|coretemp|zenpower) " +
            "    for f in ${d}temp*_input; do " +
            "      [ -f \"$f\" ] && cat \"$f\" 2>/dev/null && break 2; " +
            "    done;; esac; " +
            "done; " +

            "echo '---CPU_NAME---'; " +
            "grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2; " +

            // v7.0.0-beta.1-hf99zf: average current CPU clock (MHz)
            "echo '---CPU_MHZ---'; " +
            "awk '/cpu MHz/{s+=$4;n++}END{if(n>0)printf \"%.0f\\n\", s/n}' /proc/cpuinfo 2>/dev/null; " +

            "echo '---MEM---'; " +
            "grep -E 'MemTotal|MemAvailable' /proc/meminfo 2>/dev/null; " +

            "echo '---GPU_AMD---'; " +
            "for d in /sys/class/hwmon/hwmon*/; do " +
            "  [ \"$(cat ${d}name 2>/dev/null)\" = 'amdgpu' ] || continue; " +
            "  echo \"temp=$(cat ${d}temp1_input 2>/dev/null)\"; " +
            "  echo \"busy=$(cat ${d}device/gpu_busy_percent 2>/dev/null)\"; " +
            // v7.0.0-beta.1-hf99zf: current GPU core clock (marked '*' line)
            "  [ -f ${d}device/pp_dpm_sclk ] && echo \"sclk=$(awk '/\\*/{print $2; exit}' ${d}device/pp_dpm_sclk 2>/dev/null | tr -dc 0-9)\"; " +
            "  vu=${d}device/mem_info_vram_used; vt=${d}device/mem_info_vram_total; " +
            "  [ -f \"$vu\" ] && echo \"vram_used=$(cat $vu)\" && echo \"vram_total=$(cat $vt)\"; " +
            "  break; " +
            "done; " +

            "echo '---GPU_NVIDIA---'; " +
            "command -v nvidia-smi >/dev/null 2>&1 && " +
            "  nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,name " +
            "  --format=csv,noheader,nounits 2>/dev/null; " +

            // v6.16.1: Enumerate ALL GPUs (for multi-GPU widget tabs).
            // Output format: idx|vendor|name, one line per GPU card.
            // vendor: "amd" | "nvidia" | "intel" | "unknown"
            // idx corresponds to /dev/dri/cardN.
            "echo '---GPU_LIST---'; " +
            "i=0; for d in /sys/class/drm/card[0-9]*; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  [ -f \"$d/device/vendor\" ] || continue; " +
            "  v=$(cat $d/device/vendor 2>/dev/null); " +
            "  case \"$v\" in " +
            "    0x1002) vendor=amd ;; " +
            "    0x10de) vendor=nvidia ;; " +
            "    0x8086) vendor=intel ;; " +
            "    *) vendor=unknown ;; " +
            "  esac; " +
            "  gpu_name=$(lspci -s $(basename $(readlink $d/device) 2>/dev/null) 2>/dev/null | " +
            "    sed -n 's/.*: //p' | sed -n 's/ (rev.*//p' | head -c 60); " +
            "  [ -z \"$gpu_name\" ] && gpu_name=\"Unknown\"; " +
            "  echo \"${i}|${vendor}|${gpu_name}\"; " +
            "  i=$((i+1)); " +
            "done; " +

            "echo '---NET---'; " +
            "awk '/^\\s*(eth|wlan|enp|wlp)/' /proc/net/dev 2>/dev/null | " +
            "  awk '{rx+=$2; tx+=$10} END {print rx, tx}'; " +

            // v6.16.0: Battery — picks first BAT* under /sys/class/power_supply.
            // If none exist, section is empty → batteryPresent stays false.
            // Reads capacity (%), status, power_now (µW → W), energy_now/full
            // for time-remaining estimation.
            "echo '---BATTERY---'; " +
            "for b in /sys/class/power_supply/BAT*; do " +
            "  [ -d \"$b\" ] || continue; " +
            "  echo \"device=$(basename $b)\"; " +
            "  [ -f \"$b/capacity\" ] && echo \"capacity=$(cat $b/capacity 2>/dev/null)\"; " +
            "  [ -f \"$b/status\" ] && echo \"status=$(cat $b/status 2>/dev/null)\"; " +
            "  [ -f \"$b/power_now\" ] && echo \"power_now=$(cat $b/power_now 2>/dev/null)\"; " +
            "  [ -f \"$b/energy_now\" ] && echo \"energy_now=$(cat $b/energy_now 2>/dev/null)\"; " +
            "  [ -f \"$b/energy_full\" ] && echo \"energy_full=$(cat $b/energy_full 2>/dev/null)\"; " +
            "  break; " +
            "done; " +

            "echo '---END---'"
        ]
        statsFetcher.running = true
    }

    function _parseStats(text) {
        const sections = text.split("---")
        let cpuLine = "", cpuTempRaw = "", cpuNameRaw = "", cpuMhzRaw = ""
        let memLines = "", amdLines = "", nvidiaLine = "", netLine = ""
        let batteryLines = ""
        let gpuListRaw = ""

        for (let i = 0; i < sections.length; i++) {
            const tag = sections[i].trim()
            const val = (i + 1 < sections.length) ? sections[i + 1].trim() : ""
            switch (tag) {
                case "CPU_STAT": cpuLine = val; break
                case "CPU_TEMP": cpuTempRaw = val; break
                case "CPU_NAME": cpuNameRaw = val; break
                case "CPU_MHZ": cpuMhzRaw = val; break
                case "MEM": memLines = val; break
                case "GPU_AMD": amdLines = val; break
                case "GPU_NVIDIA": nvidiaLine = val; break
                case "GPU_LIST": gpuListRaw = val; break
                case "NET": netLine = val; break
                case "BATTERY": batteryLines = val; break
            }
        }

        // ── CPU usage from /proc/stat ──
        // Previous idle/total vs current — need two samples.
        // For simplicity, we use the instant values and compute a rough percentage.
        if (cpuLine) {
            const parts = cpuLine.replace(/^cpu\s+/, "").split(/\s+/).map(Number)
            if (parts.length >= 4) {
                const idle = parts[3]
                const total = parts.reduce((a, b) => a + b, 0)
                if (!root._firstRun && root._prevTotal > 0) {
                    const dTotal = total - root._prevTotal
                    const dIdle = idle - root._prevIdle
                    cpuPercent = dTotal > 0 ? Math.round(100 * (1 - dIdle / dTotal)) : 0
                }
                root._prevTotal = total
                root._prevIdle = idle
            }
        }

        // ── CPU temp ──
        if (cpuTempRaw) {
            const t = parseInt(cpuTempRaw)
            if (t > 0) cpuTemp = t > 1000 ? Math.round(t / 1000) : t
        }

        // ── CPU name ──
        if (cpuNameRaw && cpuName === "CPU") {
            let n = cpuNameRaw.trim()
            // Shorten: "AMD Ryzen 9 5950X 16-Core" → "Ryzen 9 5950X"
            const rMatch = n.match(/Ryzen \d+ \d+\w*/)
            if (rMatch) { cpuName = rMatch[0] }
            else {
                const iMatch = n.match(/Core i\d+-?\d+\w*/)
                if (iMatch) cpuName = iMatch[0]
                else cpuName = n.substring(0, 18)
            }
        }

        // ── v7.0.0-beta.1-hf99zf: CPU clock (MHz) ──
        if (cpuMhzRaw) {
            const mhz = parseInt(cpuMhzRaw.trim())
            if (!isNaN(mhz) && mhz > 0) cpuMhz = mhz
        }

        // ── Memory ──
        if (memLines) {
            const totalMatch = memLines.match(/MemTotal:\s+(\d+)/)
            const availMatch = memLines.match(/MemAvailable:\s+(\d+)/)
            if (totalMatch && availMatch) {
                const totalKb = parseInt(totalMatch[1])
                const availKb = parseInt(availMatch[1])
                const usedKb = totalKb - availKb
                ramTotalGb = Math.round(totalKb / 1048576 * 10) / 10
                ramUsedGb = Math.round(usedKb / 1048576 * 10) / 10
                ramPercent = Math.round(usedKb / totalKb * 100)
            }
        }

        // ── GPU (AMD) ──
        if (amdLines && amdLines.indexOf("temp=") >= 0) {
            gpuType = "amd"
            const lines = amdLines.split("\n")
            for (const l of lines) {
                if (l.startsWith("temp=")) {
                    const t = parseInt(l.split("=")[1])
                    gpuTemp = t > 1000 ? Math.round(t / 1000) : t
                }
                if (l.startsWith("busy=")) gpuUsage = parseInt(l.split("=")[1]) || 0
                if (l.startsWith("sclk=")) gpuMhz = parseInt(l.split("=")[1]) || 0
                if (l.startsWith("vram_used=")) gpuVramUsed = parseInt(l.split("=")[1]) / (1024*1024*1024)
                if (l.startsWith("vram_total=")) gpuVramTotal = parseInt(l.split("=")[1]) / (1024*1024*1024)
            }
            if (gpuName === "GPU") {
                // Try to detect name from lspci (one-time)
                gpuName = "Radeon"
                gpuNameDetector.running = true
            }
        }

        // ── GPU (NVIDIA) ──
        if (nvidiaLine && nvidiaLine.indexOf(",") >= 0) {
            gpuType = "nvidia"
            const p = nvidiaLine.split(",").map(s => s.trim())
            if (p.length >= 5) {
                gpuTemp = parseInt(p[0]) || 0
                gpuUsage = parseInt(p[1]) || 0
                gpuVramUsed = (parseFloat(p[2]) || 0) / 1024
                gpuVramTotal = (parseFloat(p[3]) || 0) / 1024
                if (gpuName === "GPU") gpuName = p[4].replace("NVIDIA GeForce ", "").replace("NVIDIA ", "").substring(0, 14)
            }
        }

        // ── v6.16.1: Multi-GPU list build ──
        // Build gpus[] from the GPU_LIST enum output. First entry mirrors
        // the primary GPU (gpuUsage/gpuTemp/etc above). Subsequent entries
        // carry vendor + name only — live metrics for secondary GPUs would
        // require additional probes (nvidia-smi -i N for NVIDIA, separate
        // hwmon lookup for multi-AMD); we show them with 0 usage + "(no metrics)"
        // until the user expands that GPU's tab (future v6.16.x).
        if (gpuListRaw && gpuListRaw.length > 0) {
            const lines = gpuListRaw.split("\n").filter(l => l.trim().length > 0)
            const newGpus = []
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split("|")
                if (parts.length < 3) continue
                const idx = parseInt(parts[0]) || 0
                const vendor = parts[1] || "unknown"
                const name = parts[2] || "Unknown"
                // Primary GPU (index 0) gets live metrics from the existing
                // single-GPU fields; others get placeholder values.
                const isPrimary = (i === 0)
                newGpus.push({
                    index: idx,
                    name: isPrimary ? (gpuName !== "GPU" ? gpuName : name) : name,
                    type: vendor,
                    usage: isPrimary ? gpuUsage : 0,
                    temp: isPrimary ? gpuTemp : 0,
                    vramUsed: isPrimary ? gpuVramUsed : 0,
                    vramTotal: isPrimary ? gpuVramTotal : 0,
                    history: isPrimary ? gpuHistory : new Array(historyMax).fill(0),
                    hasMetrics: isPrimary
                })
            }
            root.gpus = newGpus
            root.gpuCount = newGpus.length
        } else if (gpuCount === 0) {
            // No GPU_LIST data but we had single-GPU info — synthesize a
            // 1-entry array so widgets can still render.
            if (gpuName !== "GPU" || gpuType !== "unknown") {
                root.gpus = [{
                    index: 0, name: gpuName, type: gpuType,
                    usage: gpuUsage, temp: gpuTemp,
                    vramUsed: gpuVramUsed, vramTotal: gpuVramTotal,
                    history: gpuHistory, hasMetrics: true
                }]
                root.gpuCount = 1
            }
        }

        // ── Network ──
        if (netLine) {
            const np = netLine.split(/\s+/)
            if (np.length >= 2) {
                const rx = parseFloat(np[0]) || 0
                const tx = parseFloat(np[1]) || 0
                if (!root._firstRun && root._prevRx > 0) {
                    const dRx = (rx - root._prevRx) / 2  // per second (2s interval)
                    const dTx = (tx - root._prevTx) / 2
                    netDownBps = dRx
                    netUpBps = dTx
                    netDown = _fmtSpeed(dRx)
                    netUp = _fmtSpeed(dTx)
                }
                root._prevRx = rx
                root._prevTx = tx
            }
        }

        // ── v6.16.0: Battery parsing + threshold notifications ──
        // Fires swaync notifications at:
        //   - 30% (warning — orange icon)
        //   - 10% (critical — red icon, urgency=critical)
        // Only fires ONCE per threshold crossing. Hysteresis: re-armed
        // when battery climbs above threshold + 5 (prevents oscillation
        // near the boundary or notification spam on slow discharge).
        // Never fires while charging.
        if (batteryLines && batteryLines.length > 0) {
            batteryPresent = true
            const lines = batteryLines.split("\n")
            let cap = batteryCapacity
            let stat = batteryStatus
            let powW = 0
            let energyNow = 0, energyFull = 0
            for (const l of lines) {
                if (l.startsWith("device=")) batteryDevice = l.split("=")[1] || ""
                else if (l.startsWith("capacity=")) cap = parseInt(l.split("=")[1]) || 0
                else if (l.startsWith("status=")) stat = l.split("=")[1] || "Unknown"
                else if (l.startsWith("power_now=")) powW = (parseInt(l.split("=")[1]) || 0) / 1000000
                else if (l.startsWith("energy_now=")) energyNow = parseInt(l.split("=")[1]) || 0
                else if (l.startsWith("energy_full=")) energyFull = parseInt(l.split("=")[1]) || 0
            }
            batteryCapacity = Math.max(0, Math.min(100, cap))
            batteryStatus = stat
            batteryCharging = (stat === "Charging")
            batteryPowerDraw = powW
            // Time remaining estimate (rough — kernel doesn't expose this
            // directly without upower). energyNow is in µWh, power in W.
            if (powW > 0.1 && energyNow > 0 && energyFull > 0) {
                let hours
                if (batteryCharging) {
                    hours = (energyFull - energyNow) / 1000000 / powW
                    const h = Math.floor(hours)
                    const m = Math.round((hours - h) * 60)
                    batteryTimeRemaining = h + "h " + m + "m until full"
                } else if (stat === "Discharging") {
                    hours = energyNow / 1000000 / powW
                    const h = Math.floor(hours)
                    const m = Math.round((hours - h) * 60)
                    batteryTimeRemaining = h + "h " + m + "m remaining"
                } else {
                    batteryTimeRemaining = ""
                }
            } else {
                batteryTimeRemaining = ""
            }

            // ── Threshold notifications (only when discharging) ──
            if (!batteryCharging && stat === "Discharging") {
                if (batteryCapacity <= batteryCriticalThreshold && !_batteryCriticalFired) {
                    _notify("critical",
                        "Battery Critical",
                        "Only " + batteryCapacity + "% left. Plug in now!",
                        "battery-caution")
                    _batteryCriticalFired = true
                    _batteryWarningFired = true  // suppress the warning as well
                } else if (batteryCapacity <= batteryWarningThreshold && !_batteryWarningFired) {
                    _notify("normal",
                        "Battery Low",
                        "Battery at " + batteryCapacity + "%. Consider plugging in.",
                        "battery-low")
                    _batteryWarningFired = true
                }
            }
            // Re-arm hysteresis (charging or back above threshold+5)
            if (batteryCharging || batteryCapacity > batteryWarningThreshold + 5) {
                _batteryWarningFired = false
            }
            if (batteryCharging || batteryCapacity > batteryCriticalThreshold + 5) {
                _batteryCriticalFired = false
            }
        } else {
            batteryPresent = false
        }

        // ── Push to history ──
        _pushHistory("cpuHistory", cpuPercent)
        _pushHistory("ramHistory", ramPercent)
        _pushHistory("gpuHistory", gpuUsage)
        _pushHistory("netHistory", Math.min(100, netDownBps / (1024 * 1024) * 10))

        root._firstRun = false
    }

    property real _prevTotal: 0
    property real _prevIdle: 0

    function _pushHistory(propName, value) {
        let arr = root[propName].slice()
        arr.push(value)
        if (arr.length > historyMax) arr = arr.slice(arr.length - historyMax)
        root[propName] = arr
    }

    function _fmtSpeed(bps) {
        if (bps < 1024) return Math.round(bps) + " B/s"
        if (bps < 1048576) return Math.round(bps / 1024) + " KB/s"
        return (bps / 1048576).toFixed(1) + " MB/s"
    }

    // ── GPU name detection (one-time, AMD only) ──
    Process {
        id: gpuNameDetector
        running: false
        command: ["bash", "-c", "lspci 2>/dev/null | grep -i 'VGA\\|Display' | grep -ioP 'RX\\s*\\d+\\s*\\w*' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim()
                if (name) root.gpuName = name
            }
        }
    }

    // ── Init ──
    Component.onCompleted: {
        // Initialize history arrays
        cpuHistory = new Array(historyMax).fill(0)
        ramHistory = new Array(historyMax).fill(0)
        gpuHistory = new Array(historyMax).fill(0)
        netHistory = new Array(historyMax).fill(0)
        // First update
        Qt.callLater(update)
    }

    // ─────────────────────────────────────────────────────────────
    // v6.16.0: Notification helper (swaync via notify-send)
    // ─────────────────────────────────────────────────────────────
    // Urgency levels: "low" | "normal" | "critical"
    // Named icon falls back to system theme (hicolor etc). Always safe
    // to call — if notify-send isn't installed, just logs to console.
    Process { id: _notifyProc; running: false }
    function _notify(urgency, title, body, iconName) {
        _notifyProc.command = ["bash", "-c",
            "command -v notify-send >/dev/null 2>&1 && " +
            "notify-send -a 'Zen Shell' -u '" + urgency + "' " +
            "-i '" + (iconName || "dialog-information") + "' " +
            "'" + title.replace(/'/g, "") + "' " +
            "'" + body.replace(/'/g, "") + "' || true"]
        _notifyProc.running = true
    }
}
