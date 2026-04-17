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
 * Bar modules bind to: cpuPercent, cpuTemp, gpuTemp, gpuUsage,
 * ramPercent, ramUsedGb, ramTotalGb, netDown, netUp
 */
Singleton {
    id: root

    // ── CPU ──
    property int cpuPercent: 0
    property int cpuTemp: 0         // °C, 0 = unavailable
    property string cpuName: "CPU"

    // ── GPU ──
    property int gpuUsage: 0
    property int gpuTemp: 0
    property real gpuVramUsed: 0    // GB
    property real gpuVramTotal: 0
    property string gpuName: "GPU"
    property string gpuType: "unknown"  // "amd" | "nvidia" | "intel" | "unknown"

    // ── RAM ──
    property int ramPercent: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0

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

    // ── Auto-refresh every 2s ──
    Timer {
        interval: 2000
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

            "echo '---MEM---'; " +
            "grep -E 'MemTotal|MemAvailable' /proc/meminfo 2>/dev/null; " +

            "echo '---GPU_AMD---'; " +
            "for d in /sys/class/hwmon/hwmon*/; do " +
            "  [ \"$(cat ${d}name 2>/dev/null)\" = 'amdgpu' ] || continue; " +
            "  echo \"temp=$(cat ${d}temp1_input 2>/dev/null)\"; " +
            "  echo \"busy=$(cat ${d}device/gpu_busy_percent 2>/dev/null)\"; " +
            "  vu=${d}device/mem_info_vram_used; vt=${d}device/mem_info_vram_total; " +
            "  [ -f \"$vu\" ] && echo \"vram_used=$(cat $vu)\" && echo \"vram_total=$(cat $vt)\"; " +
            "  break; " +
            "done; " +

            "echo '---GPU_NVIDIA---'; " +
            "command -v nvidia-smi >/dev/null 2>&1 && " +
            "  nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,name " +
            "  --format=csv,noheader,nounits 2>/dev/null; " +

            "echo '---NET---'; " +
            "awk '/^\\s*(eth|wlan|enp|wlp)/' /proc/net/dev 2>/dev/null | " +
            "  awk '{rx+=$2; tx+=$10} END {print rx, tx}'; " +

            "echo '---END---'"
        ]
        statsFetcher.running = true
    }

    function _parseStats(text) {
        const sections = text.split("---")
        let cpuLine = "", cpuTempRaw = "", cpuNameRaw = ""
        let memLines = "", amdLines = "", nvidiaLine = "", netLine = ""

        for (let i = 0; i < sections.length; i++) {
            const tag = sections[i].trim()
            const val = (i + 1 < sections.length) ? sections[i + 1].trim() : ""
            switch (tag) {
                case "CPU_STAT": cpuLine = val; break
                case "CPU_TEMP": cpuTempRaw = val; break
                case "CPU_NAME": cpuNameRaw = val; break
                case "MEM": memLines = val; break
                case "GPU_AMD": amdLines = val; break
                case "GPU_NVIDIA": nvidiaLine = val; break
                case "NET": netLine = val; break
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
}
