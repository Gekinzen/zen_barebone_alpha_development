pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * ConnectivityService v6.13 — WiFi / Bluetooth / Audio / LAN poller
 *
 * Pure QML singleton. No Python, no GTK dependency.
 * Polls system state every 3 seconds via single bash call.
 *
 * WiFi:    nmcli (connected SSID, signal strength, on/off state)
 * BT:      bluetoothctl (powered state, connected device list)
 * Audio:   wpctl (PipeWire — default sink name, volume %, mute state)
 * LAN:     ip link (ethernet interface up/down, carrier detect)
 *
 * Bar modules bind to: wifiConnected, wifiSSID, wifiSignal,
 * btPowered, btDevices, audioVolume, audioMuted, audioSinkName,
 * lanConnected, lanInterface
 */
Singleton {
    id: root

    // ═══════════════════════════════════════════════════════════════
    // WIFI
    // ═══════════════════════════════════════════════════════════════
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiSSID: ""
    property int wifiSignal: 0           // 0-100
    property string wifiIcon: "\uf1eb"   // nerd: 
    property var wifiNetworks: []        // [{ssid, signal, security, active}]

    // ═══════════════════════════════════════════════════════════════
    // BLUETOOTH
    // ═══════════════════════════════════════════════════════════════
    property bool btPowered: false
    property bool btConnected: false
    property string btConnectedName: ""
    property var btDevices: []           // [{name, mac, connected, type}]
    property string btIcon: "\uf293"     // nerd: 

    // ═══════════════════════════════════════════════════════════════
    // AUDIO (PipeWire via wpctl)
    // ═══════════════════════════════════════════════════════════════
    property int audioVolume: 0          // 0-100 (can exceed 100 if boosted)
    property bool audioMuted: false
    property string audioSinkName: "Speaker"
    property string audioSinkId: "@DEFAULT_AUDIO_SINK@"
    property string audioIcon: "\uf028"  // nerd:  / /

    // Mic
    property int micVolume: 0
    property bool micMuted: false
    property string micSourceName: "Microphone"

    // ═══════════════════════════════════════════════════════════════
    // LAN (Ethernet)
    // ═══════════════════════════════════════════════════════════════
    property bool lanConnected: false
    property string lanInterface: ""
    property string lanIP: ""
    property string lanIcon: "\uf6ff"    // nerd: 󰈁

    // ═══════════════════════════════════════════════════════════════
    // ACTIONS — call these from QML controls
    // ═══════════════════════════════════════════════════════════════

    function toggleWifi() {
        const cmd = wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"
        actionRunner.command = ["bash", "-c", cmd]
        actionRunner.running = true
        // Optimistic toggle + refresh after 1s
        wifiEnabled = !wifiEnabled
        Qt.callLater(function() { refreshTimer.restart() })
    }

    function toggleBluetooth() {
        const cmd = btPowered ? "bluetoothctl power off" : "bluetoothctl power on"
        actionRunner.command = ["bash", "-c", cmd]
        actionRunner.running = true
        btPowered = !btPowered
        Qt.callLater(function() { refreshTimer.restart() })
    }

    function setVolume(vol) {
        const clamped = Math.max(0, Math.min(150, vol))
        actionRunner.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100).toFixed(2)]
        actionRunner.running = true
        audioVolume = clamped
        _updateAudioIcon()
    }

    function toggleMute() {
        actionRunner.command = ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
        actionRunner.running = true
        audioMuted = !audioMuted
        _updateAudioIcon()
    }

    function toggleMicMute() {
        actionRunner.command = ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]
        actionRunner.running = true
        micMuted = !micMuted
    }

    // v6.16.4.8: Rewrote from 4.6 — the arg2 type-sniff was
    // matching "WPA2" exactly but nmcli returns "WPA2 802.1X" /
    // "WPA1 WPA2" etc., so composite security strings were being
    // treated as passwords and fed to `nmcli ... password "WPA2 802.1X"`.
    // That silently failed → button felt broken.
    //
    // New approach: named call conventions.
    //   connectWifi(ssid)                     — auto (open or prompt)
    //   connectWifi(ssid, "")                 — explicitly open
    //   connectWifi(ssid, "WPA2 802.1X")      — security string → prompt
    //   connectWifi(ssid, "", "mypassword")   — explicit password, no prompt
    //
    // We also log everything to ~/.cache/zen-shell/wifi.log so when
    // debugging Paul's setup, we can see exactly what nmcli returned.
    function connectWifi(ssid, security, password) {
        const sec = (typeof security === "string") ? security : ""
        const pwd = (typeof password === "string") ? password : ""
        const escSsid = ssid.replace(/'/g, "'\\''")

        // Classify: is this network secured? Any non-empty security
        // string counts as secured. Empty / "--" / "none" / null
        // all mean open.
        const isSecured = sec.length > 0
                       && sec !== "--"
                       && sec.toLowerCase() !== "none"

        // Build the command
        let cmd
        if (pwd.length > 0) {
            // Explicit password path (no prompt, no preflight)
            const escPwd = pwd.replace(/'/g, "'\\''")
            cmd = "nmcli device wifi connect '" + escSsid + "' password '" + escPwd + "'"
        } else {
            // Preflight + prompt path (one bash one-liner)
            const promptBlock = isSecured
                ? ("PW=$(zenity --password --title='Wi-Fi: " + escSsid.replace(/\$/g, "\\$") + "' 2>/dev/null) || exit 2; " +
                   "[ -z \"$PW\" ] && exit 2; " +
                   "nmcli device wifi connect '" + escSsid + "' password \"$PW\"")
                : "nmcli device wifi connect '" + escSsid + "'"

            cmd =
                "LOG=\"$HOME/.cache/zen-shell/wifi.log\"; " +
                "mkdir -p \"$(dirname $LOG)\"; " +
                "echo \"[$(date +%H:%M:%S)] connect '" + escSsid + "' secured=" + (isSecured?1:0) + "\" >> \"$LOG\"; " +
                // Saved creds check
                "if nmcli -t -f NAME connection show 2>/dev/null | grep -qFx '" + escSsid + "'; then " +
                "  echo \"[$(date +%H:%M:%S)] using saved connection profile\" >> \"$LOG\"; " +
                "  nmcli connection up '" + escSsid + "' 2>&1 | tee -a \"$LOG\"; " +
                "  exit $?; " +
                "fi; " +
                // No saved creds path
                "echo \"[$(date +%H:%M:%S)] no saved profile — running prompt/direct\" >> \"$LOG\"; " +
                promptBlock + " 2>&1 | tee -a \"$LOG\""
        }

        actionRunner.command = ["bash", "-c", cmd]
        actionRunner.running = true
    }

    function disconnectWifi() {
        actionRunner.command = ["bash", "-c", "nmcli device disconnect wlan0 2>/dev/null || nmcli device disconnect wlp* 2>/dev/null"]
        actionRunner.running = true
    }

    function connectBtDevice(mac) {
        actionRunner.command = ["bash", "-c", "bluetoothctl connect " + mac]
        actionRunner.running = true
    }

    function disconnectBtDevice(mac) {
        actionRunner.command = ["bash", "-c", "bluetoothctl disconnect " + mac]
        actionRunner.running = true
    }

    function openWifiSettings() {
        settingsLauncher.command = ["bash", "-c", "nm-connection-editor &"]
        settingsLauncher.running = true
    }

    function openBluetoothSettings() {
        settingsLauncher.command = ["bash", "-c", "blueman-manager &"]
        settingsLauncher.running = true
    }

    function openAudioSettings() {
        settingsLauncher.command = ["bash", "-c", "pavucontrol &"]
        settingsLauncher.running = true
    }

    // Force an immediate refresh
    function refresh() { update() }

    // ═══════════════════════════════════════════════════════════════
    // INTERNAL — poller
    // ═══════════════════════════════════════════════════════════════

    // Refresh every 3 seconds
    Timer {
        id: refreshTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.update()
    }

    Process { id: actionRunner; running: false }
    Process { id: settingsLauncher; running: false }

    Process {
        id: poller
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseAll(this.text)
        }
    }

    function update() {
        poller.command = ["bash", "-c",
            // ── WIFI ──
            "echo '---WIFI_RADIO---'; " +
            "nmcli radio wifi 2>/dev/null || echo 'unavailable'; " +

            "echo '---WIFI_STATUS---'; " +
            "nmcli -t -f active,ssid,signal,security device wifi list 2>/dev/null | head -20; " +

            // ── BLUETOOTH ──
            "echo '---BT_POWER---'; " +
            "bluetoothctl show 2>/dev/null | grep -i 'Powered:' | awk '{print $2}'; " +

            "echo '---BT_DEVICES---'; " +
            "bluetoothctl devices Connected 2>/dev/null; " +

            // ── AUDIO (PipeWire / wpctl) ──
            "echo '---AUDIO_SINK---'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; " +

            "echo '---AUDIO_SINK_NAME---'; " +
            "wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.description' | head -1 | sed 's/.*= //;s/\"//g'; " +

            "echo '---AUDIO_SOURCE---'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null; " +

            "echo '---AUDIO_SOURCE_NAME---'; " +
            "wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep 'node.description' | head -1 | sed 's/.*= //;s/\"//g'; " +

            // ── LAN ──
            "echo '---LAN---'; " +
            "ip -j link show 2>/dev/null | " +
            "python3 -c \"" +
            "import json,sys; " +
            "data=json.load(sys.stdin); " +
            "[print(f\\\"{d['ifname']}:{d.get('operstate','UNKNOWN')}:{d.get('address','')}\\\") " +
            "for d in data if d['ifname'].startswith(('eth','enp','eno'))]\" 2>/dev/null; " +

            "echo '---LAN_IP---'; " +
            "ip -4 addr show 2>/dev/null | grep -E '(eth|enp|eno)' | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1; " +

            "echo '---END---'"
        ]
        poller.running = true
    }

    function _parseAll(text) {
        const sections = text.split("---")
        let wifiRadio = "", wifiStatus = ""
        let btPower = "", btDevs = ""
        let sinkVol = "", sinkName = "", sourceVol = "", sourceName = ""
        let lanLines = "", lanIp = ""

        for (let i = 0; i < sections.length; i++) {
            const tag = sections[i].trim()
            const val = (i + 1 < sections.length) ? sections[i + 1].trim() : ""
            switch (tag) {
                case "WIFI_RADIO":       wifiRadio = val; break
                case "WIFI_STATUS":      wifiStatus = val; break
                case "BT_POWER":         btPower = val; break
                case "BT_DEVICES":       btDevs = val; break
                case "AUDIO_SINK":       sinkVol = val; break
                case "AUDIO_SINK_NAME":  sinkName = val; break
                case "AUDIO_SOURCE":     sourceVol = val; break
                case "AUDIO_SOURCE_NAME": sourceName = val; break
                case "LAN":             lanLines = val; break
                case "LAN_IP":          lanIp = val; break
            }
        }

        // ── WiFi ──
        wifiEnabled = (wifiRadio.indexOf("enabled") >= 0)
        let foundActive = false
        const networks = []
        if (wifiStatus) {
            const lines = wifiStatus.split("\n")
            for (const line of lines) {
                if (!line) continue
                const parts = line.split(":")
                if (parts.length >= 4) {
                    const active = parts[0] === "yes"
                    const ssid = parts[1]
                    const signal = parseInt(parts[2]) || 0
                    const security = parts[3] || ""
                    if (ssid) {
                        networks.push({ ssid: ssid, signal: signal, security: security, active: active })
                        if (active) {
                            foundActive = true
                            wifiConnected = true
                            wifiSSID = ssid
                            wifiSignal = signal
                        }
                    }
                }
            }
        }
        if (!foundActive) {
            wifiConnected = false
            wifiSSID = ""
            wifiSignal = 0
        }
        wifiNetworks = networks
        _updateWifiIcon()

        // ── Bluetooth ──
        btPowered = (btPower.toLowerCase() === "yes")
        const devList = []
        if (btDevs) {
            const lines = btDevs.split("\n")
            for (const line of lines) {
                // "Device AA:BB:CC:DD:EE:FF Device Name"
                const m = line.match(/Device\s+([0-9A-Fa-f:]{17})\s+(.+)/)
                if (m) {
                    devList.push({ mac: m[1], name: m[2].trim(), connected: true })
                }
            }
        }
        btDevices = devList
        btConnected = devList.length > 0
        btConnectedName = devList.length > 0 ? devList[0].name : ""
        _updateBtIcon()

        // ── Audio sink ──
        if (sinkVol) {
            // "Volume: 0.75" or "Volume: 0.75 [MUTED]"
            const vm = sinkVol.match(/Volume:\s+([\d.]+)/)
            if (vm) audioVolume = Math.round(parseFloat(vm[1]) * 100)
            audioMuted = sinkVol.indexOf("[MUTED]") >= 0
        }
        if (sinkName) audioSinkName = sinkName.substring(0, 30)
        _updateAudioIcon()

        // ── Audio source (mic) ──
        if (sourceVol) {
            const vm2 = sourceVol.match(/Volume:\s+([\d.]+)/)
            if (vm2) micVolume = Math.round(parseFloat(vm2[1]) * 100)
            micMuted = sourceVol.indexOf("[MUTED]") >= 0
        }
        if (sourceName) micSourceName = sourceName.substring(0, 30)

        // ── LAN ──
        if (lanLines) {
            const lines = lanLines.split("\n")
            for (const line of lines) {
                const parts = line.split(":")
                if (parts.length >= 2) {
                    const iface = parts[0]
                    const state = parts[1]
                    if (state === "UP") {
                        lanConnected = true
                        lanInterface = iface
                        break
                    }
                }
            }
            if (!lanLines.includes(":UP")) {
                lanConnected = false
                lanInterface = ""
            }
        } else {
            lanConnected = false
        }
        lanIP = lanIp || ""
    }

    // ── Icon helpers ──
    function _updateWifiIcon() {
        if (!wifiEnabled) { wifiIcon = "\uf05e"; return }  //  disabled
        if (!wifiConnected) { wifiIcon = "\uf071"; return }  // 
        if (wifiSignal >= 75) wifiIcon = "\uf1eb"       //  strong
        else if (wifiSignal >= 50) wifiIcon = "\udb82\udd20"  //  medium
        else if (wifiSignal >= 25) wifiIcon = "\udb82\udd1f"  //  weak
        else wifiIcon = "\udb82\udd1e"                    //  very weak
    }

    function _updateBtIcon() {
        if (!btPowered) btIcon = "\udb80\udcaf"     //  off
        else if (btConnected) btIcon = "\uf294"      //  connected
        else btIcon = "\uf293"                        //  on but idle
    }

    function _updateAudioIcon() {
        if (audioMuted) { audioIcon = "\uf026"; return }  //  muted
        if (audioVolume >= 66) audioIcon = "\uf028"   //  high
        else if (audioVolume >= 33) audioIcon = "\uf027"  //  medium
        else audioIcon = "\uf026"                      //  low
    }

    // ═══════════════════════════════════════════════════════════════
    // INIT
    // ═══════════════════════════════════════════════════════════════
    Component.onCompleted: {
        Qt.callLater(update)
    }
}
