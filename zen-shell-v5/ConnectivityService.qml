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

    // v6.16.4.12.9.9 (Modori): saved networks for the convenient
    // "Saved Networks" section in the Control Panel WiFi tab. Read
    // via `nmcli connection show` filtered to type=802-11-wireless.
    // Updated alongside wifiNetworks during the regular update poll.
    property var savedWifiNetworks: []   // ["SSID1", "SSID2", ...]

    // ═══════════════════════════════════════════════════════════════
    // BLUETOOTH
    // ═══════════════════════════════════════════════════════════════
    property bool btPowered: false
    property bool btConnected: false
    property string btConnectedName: ""
    property var btDevices: []           // [{name, mac, connected, type}] - currently connected
    property string btIcon: "\uf293"     // nerd: 

    // v6.16.4.12.9.9 (Modori): all-known-devices list (paired but
    // possibly not currently connected) and nearby-scan results.
    // Lets the Control Panel show "tap to reconnect" for paired
    // devices that aren't currently connected, and a Pair button
    // for nearby unknown devices.
    property var btPairedDevices: []     // [{name, mac}] - paired (may or may not be connected)
    property var btNearbyDevices: []     // [{name, mac}] - scan results, not yet paired
    property bool btScanning: false      // true while bluetoothctl scan on is active

    // ═══════════════════════════════════════════════════════════════
    // AUDIO (PipeWire via wpctl)
    // ═══════════════════════════════════════════════════════════════
    property int audioVolume: 0          // 0-100 (clamped, no boost)
    property bool audioMuted: false
    property string audioSinkName: "Speaker"
    property string audioSinkId: "@DEFAULT_AUDIO_SINK@"
    property string audioIcon: "\uf028"  // nerd:  / /

    // v7.0.0-beta.1-hf11: track previous volume so we can fire OSD on
    // every external change (e.g. from XF86 media keys via the
    // zen-volume-notify.sh script). The script uses wpctl which our
    // poll picks up — but without this handler, the OSD only fires
    // when we ourselves called setVolume() inside QML.
    property int _lastOsdVolume: -1
    // v7.0.0-beta.1-hf19: skip sound effects during first 3s of shell life.
    // The first poll happens almost immediately; if the user already has
    // unusual values (e.g. mic muted), the onChanged handlers would fire
    // mid-init while many singletons are still constructing their
    // Process objects, contributing to crashes.
    property int _serviceStartMs: Date.now()
    function _isWarmedUp() {
        return (Date.now() - _serviceStartMs) > 3000
    }

    onAudioVolumeChanged: {
        if (audioVolume !== _lastOsdVolume && _lastOsdVolume >= 0) {
            if (typeof NotificationService !== "undefined"
                && NotificationService.showVolumeOSD) {
                NotificationService.showVolumeOSD(audioMuted ? 0 : (audioVolume / 100))
            }
            // v7.0.0-beta.1-hf17: play volume-change tick sound on every
            // user-initiated change. Guarded by warmup so we don't fire
            // during the first poll storm right after shell start.
            if (_isWarmedUp() && typeof SoundEffectsService !== "undefined") {
                SoundEffectsService.play("volume-change")
            }
        }
        _lastOsdVolume = audioVolume
    }
    onAudioMutedChanged: {
        if (typeof NotificationService !== "undefined"
            && NotificationService.showVolumeOSD) {
            NotificationService.showVolumeOSD(audioMuted ? 0 : (audioVolume / 100))
        }
        // v7.0.0-beta.1-hf17 + hf19 warmup guard
        if (_isWarmedUp() && typeof SoundEffectsService !== "undefined") {
            SoundEffectsService.play("mute")
        }
    }

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
        _runAction(["bash", "-c", cmd])
        // Optimistic toggle + refresh after 1s
        wifiEnabled = !wifiEnabled
        Qt.callLater(function() { refreshTimer.restart() })
    }

    function toggleBluetooth() {
        const cmd = btPowered ? "bluetoothctl power off" : "bluetoothctl power on"
        _runAction(["bash", "-c", cmd])
        btPowered = !btPowered
        Qt.callLater(function() { refreshTimer.restart() })
    }

    function setVolume(vol) {
        const clamped = Math.max(0, Math.min(100, vol))
        _runAction(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100).toFixed(2)])
        audioVolume = clamped
        _updateAudioIcon()
        // v7.0.0-alpha.12: surface OSD ring on direct user volume changes
        if (typeof NotificationService !== "undefined" && NotificationService.showVolumeOSD) {
            NotificationService.showVolumeOSD(clamped / 100)
        }
    }

    // v7.0.0-beta.1-hf11: mic volume setter (was missing — the
    // Quick Settings mic slider was a no-op because the setter
    // didn't exist).
    function setMicVolume(vol) {
        const clamped = Math.max(0, Math.min(100, vol))
        _runAction(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + (clamped / 100).toFixed(2)])
        micVolume = clamped
    }

    function toggleMute() {
        _runAction(["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"])
        audioMuted = !audioMuted
        _updateAudioIcon()
        // v7.0.0-alpha.12: OSD ring shows muted state (volume 0 visually)
        if (typeof NotificationService !== "undefined" && NotificationService.showVolumeOSD) {
            NotificationService.showVolumeOSD(audioMuted ? 0 : (audioVolume / 100))
        }
    }

    function toggleMicMute() {
        _runAction(["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"])
        micMuted = !micMuted
    }

    // v6.16.4.6: Connect Wi-Fi with saved-creds preflight.
    // v6.16.4.12.9.10 (Modori): Replaced zenity password prompt with
    // in-shell PasswordPromptService. The previous zenity --password
    // dialog opened in a SEPARATE window that often landed behind
    // the Control Panel on Wayland WMs without strict focus
    // stealing — user clicked Connect, nothing visible happened.
    // The in-shell prompt is a Quickshell PanelWindow at
    // WlrLayer.Overlay, always rendered above every other surface.
    //
    // Flow:
    //   1. Check if NetworkManager has saved credentials for this
    //      SSID via `nmcli -t connection show`. If yes, connect
    //      directly — skips the prompt entirely.
    //   2. If no saved creds AND security != "" (secured network),
    //      open the in-shell PasswordPromptService prompt. The
    //      callback fires with the typed password and runs the
    //      actual connect command.
    //   3. Open networks (no security): direct connect.
    //
    // Legacy (ssid, password) string call still supported for
    // direct programmatic invocation (e.g. unit tests).
    function connectWifi(ssid, security) {
        // Legacy direct-password path
        if (arguments.length >= 2 && typeof arguments[1] === "string"
            && arguments[1].length > 0
            && !["--", "WPA2", "WPA", "WEP", "WPA3"].includes(arguments[1])) {
            const pwd = arguments[1]
            const escSsidP = ssid.replace(/'/g, "'\\''")
            const escPwdP  = pwd.replace(/'/g, "'\\''")
            _runAction(["bash", "-c",
                "nmcli device wifi connect '" + escSsidP + "' password '" + escPwdP + "'"])
            return
        }

        const escSsid = ssid.replace(/'/g, "'\\''")
        const isSecured = (security && security.length > 0)

        // Step 1: try saved credentials first via a quick async check.
        // We run it as a small Process and dispatch based on result.
        savedCredsCheck.targetSsid = ssid
        savedCredsCheck.escSsid = escSsid
        savedCredsCheck.isSecured = isSecured
        savedCredsCheck.command = ["bash", "-c",
            "if nmcli -t -f NAME connection show 2>/dev/null | grep -qFx '" + escSsid + "'; then echo SAVED; else echo NEW; fi"]
        savedCredsCheck.running = true
    }

    // Async helper: checks saved-creds, then either reconnects
    // directly OR opens the in-shell password prompt.
    Process {
        id: savedCredsCheck
        property string targetSsid: ""
        property string escSsid: ""
        property bool isSecured: false
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim()
                // v6.16.4.12.9.11: route-metric tail. Appended to every
                // connect command so that explicit user-tap to connect
                // makes WiFi the preferred default route even when LAN
                // is plugged in. Default NetworkManager metrics are
                // ethernet=100, wifi=600 (LAN wins). We set wifi to 50
                // so wifi wins. Persistent — also applied to future
                // auto-reconnects of this saved network.
                //
                // Non-fatal: chained with `;` not `&&` so a metric-set
                // failure (e.g. connection profile not yet visible
                // immediately after connect) doesn't roll back the
                // connect itself. Worst case: connected but metric
                // unchanged, default route still uses LAN. The next
                // tap or background sweep will retry.
                const metricTail = " ; nmcli connection modify '" + savedCredsCheck.escSsid + "' ipv4.route-metric 50 ipv6.route-metric 50 2>/dev/null"

                if (result === "SAVED") {
                    // Saved network — reconnect directly
                    _runAction(["bash", "-c",
                        "nmcli connection up '" + savedCredsCheck.escSsid + "'" + metricTail])
                    return
                }
                // New network
                if (!savedCredsCheck.isSecured) {
                    // Open network — direct connect
                    _runAction(["bash", "-c",
                        "nmcli device wifi connect '" + savedCredsCheck.escSsid + "'" + metricTail])
                    return
                }
                // Secured + new → in-shell password prompt
                if (typeof PasswordPromptService === "undefined") {
                    console.warn("[ConnectivityService] PasswordPromptService unavailable — falling back to zenity")
                    _runAction(["bash", "-c",
                        "PW=$(zenity --password --title='Wi-Fi: " + savedCredsCheck.escSsid.replace(/\$/g, "\\$") + "' 2>/dev/null) || exit 1; " +
                        "[ -z \"$PW\" ] && exit 1; " +
                        "nmcli device wifi connect '" + savedCredsCheck.escSsid + "' password \"$PW\"" + metricTail])
                    return
                }
                const ssidForCb = savedCredsCheck.targetSsid
                const escForCb = savedCredsCheck.escSsid
                const metricTailForCb = metricTail   // capture for closure
                PasswordPromptService.requestPassword(ssidForCb, function(password) {
                    // User submitted — run the connect with their password,
                    // then chain the metric set so wifi takes precedence
                    // over ethernet on default route.
                    const escPw = password.replace(/'/g, "'\\''")
                    _runAction(["bash", "-c",
                        "nmcli device wifi connect '" + escForCb + "' password '" + escPw + "'" + metricTailForCb])
                }, function() {
                    // User cancelled — no action needed
                    console.log("[ConnectivityService] WiFi password prompt cancelled by user")
                })
            }
        }
    }


    function disconnectWifi() {
        _runAction(["bash", "-c", "nmcli device disconnect wlan0 2>/dev/null || nmcli device disconnect wlp* 2>/dev/null"])
    }

    function connectBtDevice(mac) {
        _runAction(["bash", "-c", "bluetoothctl connect " + mac])
    }

    function disconnectBtDevice(mac) {
        _runAction(["bash", "-c", "bluetoothctl disconnect " + mac])
    }

    // ═══════════════════════════════════════════════════════════════
    // v6.16.4.12.9.9 (Modori) — Convenient WiFi+BT helpers
    //
    // Adds the missing primitives that the Control Panel's WiFi+BT
    // tabs need to feel like a real network selector instead of a
    // bare list:
    //
    //   - forgetWifi(ssid)     — delete saved connection
    //   - scanWifi()           — explicit rescan (refresh button)
    //   - reconnectWifi(ssid)  — quick re-up of saved connection
    //                            (skips zenity preflight)
    //   - startBtScan() / stopBtScan() — toggle bluetoothctl scan on/off
    //   - pairBtDevice(mac)    — pair + trust + connect in one shot
    //   - unpairBtDevice(mac)  — remove a paired device
    // ═══════════════════════════════════════════════════════════════

    function forgetWifi(ssid) {
        const escSsid = ssid.replace(/'/g, "'\\''")
        _runAction(["bash", "-c",
            "nmcli connection delete '" + escSsid + "' 2>/dev/null"])
    }

    function scanWifi() {
        _runAction(["bash", "-c",
            "nmcli device wifi rescan 2>/dev/null; sleep 0.4"])
        // Trigger an immediate poll so the UI refreshes ASAP.
        // The actionRunner finish handler also calls update() but
        // that's after the rescan delay; this gets the user a
        // visual response sooner.
        Qt.callLater(update)
    }

    function reconnectWifi(ssid) {
        const escSsid = ssid.replace(/'/g, "'\\''")
        // v6.16.4.12.9.11: same metric chain as connectWifi — explicit
        // tap-to-reconnect signals user preference, so make wifi the
        // preferred default route over LAN.
        _runAction(["bash", "-c",
            "nmcli connection up '" + escSsid + "' 2>/dev/null" +
            " ; nmcli connection modify '" + escSsid + "' ipv4.route-metric 50 ipv6.route-metric 50 2>/dev/null"])
    }

    function startBtScan() {
        // bluetoothctl scan blocks until cancelled, so we run it
        // detached and track the PID. The scan runner polls the
        // bluetoothctl devices output during the scan to populate
        // btNearbyDevices.
        btScanProc.running = true
        root.btScanning = true
    }

    function stopBtScan() {
        btScanStopProc.running = true
        root.btScanning = false
    }

    function pairBtDevice(mac) {
        // pair + trust + connect chain. trust is critical — without
        // it, the device disconnects after first sleep cycle and
        // user has to re-enter the pair PIN.
        _runAction(["bash", "-c",
            "echo -e 'pair " + mac + "\\ntrust " + mac + "\\nconnect " + mac + "\\nquit\\n' | bluetoothctl"])
    }

    function unpairBtDevice(mac) {
        _runAction(["bash", "-c",
            "bluetoothctl remove " + mac + " 2>/dev/null"])
    }

    // BT scan runner — runs `bluetoothctl scan on` detached.
    // The actual device discovery is read by the regular update()
    // poller (which queries `bluetoothctl devices` to get all
    // known-and-nearby devices).
    Process {
        id: btScanProc
        command: ["bash", "-c",
            // Run scan in background, save PID for stop.
            "pkill -f 'bluetoothctl scan on' 2>/dev/null; " +
            "(bluetoothctl scan on >/dev/null 2>&1 &) ; " +
            "sleep 0.2"]
        running: false
    }

    Process {
        id: btScanStopProc
        command: ["bash", "-c",
            "pkill -f 'bluetoothctl scan on' 2>/dev/null; true"]
        running: false
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

    // ═══════════════════════════════════════════════════════════════
    // v6.16.4.12.9.11 (Modori) — actionRunner improvements
    //
    // Fixes two real-world issues:
    //
    // 1. **Re-entry bug**. When a click fires while a previous
    //    actionRunner invocation is still pending (running=true),
    //    setting running=true again is a no-op — Qt sees the
    //    property going from true→true and skips the change.
    //    Result: the second click is silently dropped.
    //    Fix: _runAction() helper resets running to false first,
    //    THEN sets command + running=true. Forces Qt to fire the
    //    change.
    //
    // 2. **Stale state after action**. nmcli connect/disconnect
    //    takes ~1-3s to settle. The next regular poll happens
    //    every 5s (refreshTimer interval). User taps Connect,
    //    sees nothing for 5s, thinks the action failed.
    //    Fix: actionRunner.onExited triggers an immediate update()
    //    + a delayed update() at +1.5s (catches slow nmcli
    //    convergence).
    // ═══════════════════════════════════════════════════════════════
    function _runAction(cmdArr) {
        // Reset to force re-trigger even if previous still pending.
        // Setting running=true while it's already true is a no-op
        // in Qt (property change suppressed because old===new), so
        // a quick double-tap was silently dropping the second call.
        if (actionRunner.running) {
            actionRunner.running = false
        }
        actionRunner.command = cmdArr
        actionRunner.running = true
    }

    Process {
        id: actionRunner
        running: false
        // After any action completes, refresh state immediately +
        // again at +1.5s (nmcli convergence delay).
        onExited: function(exitCode, exitStatus) {
            root.update()
            postActionRefreshTimer.restart()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("[ConnectivityService action stderr]:", text.trim())
                }
            }
        }
    }
    Timer {
        id: postActionRefreshTimer
        interval: 1500
        repeat: false
        onTriggered: root.update()
    }
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

            // v6.16.4.12.9.9: saved wifi connection list
            "echo '---WIFI_SAVED---'; " +
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null | " +
            "awk -F: '$2 == \"802-11-wireless\" {print $1}'; " +

            // ── BLUETOOTH ──
            "echo '---BT_POWER---'; " +
            "bluetoothctl show 2>/dev/null | grep -i 'Powered:' | awk '{print $2}'; " +

            "echo '---BT_DEVICES---'; " +
            "bluetoothctl devices Connected 2>/dev/null; " +

            // v6.16.4.12.9.9: all paired devices (may not be currently
            // connected). Lets the Control Panel show "tap to reconnect"
            // for known devices that are off/asleep.
            "echo '---BT_PAIRED---'; " +
            "bluetoothctl devices Paired 2>/dev/null; " +

            // v6.16.4.12.9.9: nearby devices (visible during scan).
            // Subset = (devices) - (Paired). The scan runs separately
            // via startBtScan(); this just picks up the discovery
            // results that bluetoothctl already cached.
            "echo '---BT_NEARBY---'; " +
            "bluetoothctl devices 2>/dev/null; " +

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
        let wifiRadio = "", wifiStatus = "", wifiSaved = ""
        let btPower = "", btDevs = "", btPaired = "", btNearby = ""
        let sinkVol = "", sinkName = "", sourceVol = "", sourceName = ""
        let lanLines = "", lanIp = ""

        for (let i = 0; i < sections.length; i++) {
            const tag = sections[i].trim()
            const val = (i + 1 < sections.length) ? sections[i + 1].trim() : ""
            switch (tag) {
                case "WIFI_RADIO":       wifiRadio = val; break
                case "WIFI_STATUS":      wifiStatus = val; break
                case "WIFI_SAVED":       wifiSaved = val; break
                case "BT_POWER":         btPower = val; break
                case "BT_DEVICES":       btDevs = val; break
                case "BT_PAIRED":        btPaired = val; break
                case "BT_NEARBY":        btNearby = val; break
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
                    // v6.16.4.12.9.11: nmcli -t outputs literal "--"
                    // for null security on open networks. The string "--"
                    // has length 2 → previous code thought open networks
                    // were secured and showed the lock icon + tried to
                    // prompt for a password. Normalize "--" to "" so
                    // downstream isSecured checks work correctly.
                    let security = parts[3] || ""
                    if (security === "--") security = ""
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

        // v6.16.4.12.9.9 — saved wifi networks
        // Each line is the connection name (which == SSID for normal
        // networks). We just collect the non-empty lines.
        const saved = []
        if (wifiSaved) {
            const sLines = wifiSaved.split("\n")
            for (const line of sLines) {
                const trimmed = line.trim()
                if (trimmed) saved.push(trimmed)
            }
        }
        savedWifiNetworks = saved

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

        // v6.16.4.12.9.9 — paired devices (may not be currently connected)
        // Filter out the currently-connected ones so the UI can show
        // them in a separate "tap to reconnect" section.
        const connectedMacs = new Set(devList.map(d => d.mac))
        const paired = []
        if (btPaired) {
            const lines = btPaired.split("\n")
            for (const line of lines) {
                const m = line.match(/Device\s+([0-9A-Fa-f:]{17})\s+(.+)/)
                if (m && !connectedMacs.has(m[1])) {
                    paired.push({ mac: m[1], name: m[2].trim() })
                }
            }
        }
        btPairedDevices = paired

        // v6.16.4.12.9.9 — nearby (scan-discovered) devices
        // Filter out anything already paired or connected.
        const knownMacs = new Set([
            ...devList.map(d => d.mac),
            ...paired.map(d => d.mac),
        ])
        const nearby = []
        if (btNearby) {
            const lines = btNearby.split("\n")
            for (const line of lines) {
                const m = line.match(/Device\s+([0-9A-Fa-f:]{17})\s+(.+)/)
                if (m && !knownMacs.has(m[1])) {
                    nearby.push({ mac: m[1], name: m[2].trim() })
                }
            }
        }
        btNearbyDevices = nearby

        // ── Audio sink ──
        if (sinkVol) {
            // "Volume: 0.75" or "Volume: 0.75 [MUTED]"
            const vm = sinkVol.match(/Volume:\s+([\d.]+)/)
            if (vm) audioVolume = Math.min(100, Math.round(parseFloat(vm[1]) * 100))
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
