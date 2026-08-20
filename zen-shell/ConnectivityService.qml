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
    // v8.0.0-alpha-hf177 — AUTHORITATIVE CONNECTED STATE
    //
    // "paki ayos yang pag connect sa wifi if connected dapat ganyan yun
    //  naka lagay — prang hindi kasi malaman if gumana ba or hindi"
    //
    // Root cause: `wifiConnected` was derived from ONE source — the first
    // column of `nmcli -t -f active,ssid,signal,security device wifi list`,
    // compared with `parts[0] === "yes"`. On NetworkManager 1.40+ that
    // column is IN-USE, and terse mode prints it as `*` (or an empty
    // string), never `"yes"`. So the compare never matched: every network
    // came back `active: false`, `wifiConnected` stayed false forever, and
    //
    //   · the panel kept showing "Connect" on the network you're ON
    //   · SysRow's network glyph fell through to 󰤮 / 󰈀 instead of the
    //     wifi bars — hence "dito if wifi dapat wifi din"
    //
    // Fix is two-layer. The IN-USE column is still read (now accepting
    // every marker NM has ever used), but the truth now comes from
    // `nmcli connection show --active` filtered to 802-11-wireless, which
    // reports the SSID of the live wireless connection regardless of how
    // the scan table decides to draw its asterisk.
    //
    // `wifiBusy` covers the other half of the complaint: tapping Connect
    // used to look identical to tapping nothing until nmcli converged
    // ~2-4s later. The UI can now render "Connecting…" the instant you tap.
    // ═══════════════════════════════════════════════════════════════

    /** SSID of the live wireless connection per NM, "" when down. */
    property string wifiActiveSsid: ""
    /** v8.0.0-alpha-hf178 — BSSID of the exact AP we are associated to. */
    property string wifiBSSID: ""
    /** v8.0.0-alpha-hf178 — link signal in dBm straight from the driver. */
    property int    wifiSignalDbm: 0
    /** True while a user-initiated connect/disconnect/forget is in flight. */
    property bool   wifiBusy: false
    /** Which SSID the in-flight action targets ("" for device-wide ops). */
    property string wifiBusySsid: ""
    /** "Connecting" | "Disconnecting" | "Forgetting" | "Scanning" */
    property string wifiBusyVerb: ""
    /**
     * v8.0.0-alpha-hf183 — the saved profile's key is agent-owned and no
     * secret agent is running, so NM cannot authenticate and never will
     * without being handed the key again.
     */
    property bool secretsMissing: false

    /**
     * v8.0.0-alpha-hf187 — why the last wifi action failed, in NM's own words.
     *
     * Until now every failure was silent: _runAction fired nmcli, nmcli printed
     * its reason to stderr, and that reason went to console.warn where no user
     * will ever see it. From the outside a failed Connect and a Connect that was
     * never wired up look identical — both are "wala naman" — which is exactly
     * the ambiguity that let the dead button in ZenDashboard hide this long.
     */
    property string wifiLastError: ""
    /** Edge-detector for the keeper. */
    property bool _keeperLastConnected: false

    // ═══════════════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf188 — WIFI KEEPER
    //
    // "bumibitaw, gawin mo smart, dati ok naman e."
    //
    // NetworkManager has its own autoconnect, and when it works you never
    // think about it. It stops working in two situations that both apply here:
    //
    //   1. After a handful of failed activations NM sets an internal
    //      autoconnect block on the profile and simply stops trying. Nothing
    //      in any UI says so. From the outside the wifi is just "off now".
    //   2. When activation fails for want of a secret, retrying is pointless —
    //      NM asks an agent, there is no agent, it fails identically forever.
    //
    // So this is deliberately NOT a dumb retry loop. It:
    //   · remembers the SSID we were last genuinely connected to
    //   · retries only that one, with exponential backoff, capped
    //   · gives up immediately on a secrets error and raises the prompt
    //     instead, because no amount of retrying can supply a password
    //   · never fights the user: an explicit Disconnect disables it until
    //     they choose to connect again
    //   · clears NM's own autoconnect block before retrying, since that block
    //     is invisible and outlives the condition that caused it
    // ═══════════════════════════════════════════════════════════════════════

    /** Master switch for the keeper. */
    property bool autoReconnect: true

    /** The SSID we were last genuinely connected to — the only retry target. */
    property string lastGoodSsid: ""

    /** True after an explicit user Disconnect; suppresses the keeper. */
    property bool userDisconnected: false

    /** Retry counter for the current outage, 0 when healthy. */
    property int reconnectAttempts: 0

    /** Hard cap. Six attempts across the backoff below is ~4 minutes. */
    readonly property int reconnectMaxAttempts: 6

    /** True while the keeper is waiting out a backoff. */
    property bool reconnectPending: false

    /** Which SSID the wrongKey verdict belongs to. */
    property string wrongKeySsid: ""

    /**
     * ══ v8.0.0-alpha-hf191 — WRITE THE KEY INTO THE PROFILE ══
     *
     * "sa terminal naman gumagana, dito lang sa UI natin ang may problema."
     *
     * Exactly right, and it was never the escaping — sixteen special-character
     * passwords were tested through the identical code path and all sixteen
     * arrive at nmcli byte-for-byte intact.
     *
     * The fault is that a FAILED attempt leaves the wrong password saved in
     * the profile. From then on:
     *
     *   terminal   `nmcli connection delete` first → no profile → a new one is
     *              created with the password you just typed → works
     *   the UI     never deletes. The probe sees a profile with psk-flags 0,
     *              answers SAVED, and runs `nmcli connection up` — which uses
     *              the STALE WRONG KEY. You are never even asked for a
     *              password. And `nmcli device wifi connect ... password ...`
     *              would reuse the same stale profile anyway.
     *
     * So the UI could not fix a bad password no matter how many times you
     * typed the right one. It never wrote it anywhere.
     *
     * This builds a command that writes the key straight INTO the profile:
     * key-mgmt, psk and psk-flags 0 together, then activates. When no profile
     * exists it falls back to creating one and pins psk-flags after. Either
     * way the password you typed is the password that gets used.
     */
    function _pwConnectCmd(escSsid, escPw, tail) {
        return "if nmcli -t -f NAME connection show 2>/dev/null | grep -qFx '" + escSsid + "'; then " +
               // Existing profile: overwrite the key rather than hoping
               // `device wifi connect` will. key-mgmt is set alongside it
               // because a profile left half-built by an earlier failure can
               // be missing it, and nmcli then refuses with
               // "802-11-wireless-security.key-mgmt: property is missing".
               "nmcli connection modify '" + escSsid + "' " +
               "802-11-wireless-security.key-mgmt wpa-psk " +
               "802-11-wireless-security.psk '" + escPw + "' " +
               "802-11-wireless-security.psk-flags 0 2>&1 && " +
               "nmcli connection up '" + escSsid + "' 2>&1" + tail + "; " +
               "else " +
               "nmcli device wifi connect '" + escSsid + "' password '" + escPw + "' 2>&1" + tail + " ; " +
               "nmcli connection modify '" + escSsid + "' " +
               "802-11-wireless-security.psk-flags 0 2>/dev/null; " +
               "fi"
    }

    /**
     * v8.0.0-alpha-hf190 — the stored key is present but the AP rejected it.
     * Distinct from `secretsMissing`, which means nothing is stored at all.
     */
    property bool wrongKey: false

    // Looks at the last 60s of supplicant output for the handshake verdict.
    // Runs only after an activation has already failed, so it is never on the
    // hot path.
    Process {
        id: wrongKeyProbe
        running: false
        command: ["bash", "-c",
            "journalctl -b --since '-60 seconds' --no-pager 2>/dev/null " +
            "-u wpa_supplicant -u NetworkManager " +
            "| grep -iE 'WRONG_KEY|4-Way Handshake failed|pre-shared key may be incorrect' " +
            "| tail -3"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hit = text.trim().length > 0
                root.wrongKey = hit
                if (hit) root.wrongKeySsid = root.wifiBusySsid.length > 0
                                             ? root.wifiBusySsid : root.lastGoodSsid
                if (hit) {
                    // Supersede the misleading nmcli wording.
                    root.wifiLastError = "Wrong password for "
                        + (root.wifiBusySsid.length > 0 ? root.wifiBusySsid
                           : (root.lastGoodSsid.length > 0 ? root.lastGoodSsid : "this network"))
                        + " — the network rejected the saved key"
                    console.warn("[ConnectivityService] handshake rejected the stored key")
                }
            }
        }
    }

    /** wifi.powersave state on the device — a common cause of silent drops. */
    property bool powerSaveOn: false
    property bool powerSaveKnown: false

    readonly property bool keeperActive: autoReconnect && reconnectPending

    /** 5s, 10s, 20s, 40s, 60s, 60s — fast enough to feel instant on a blip,
        slow enough not to hammer a genuinely absent AP. */
    function _reconnectDelay(n) {
        const table = [5000, 10000, 20000, 40000, 60000, 60000]
        return table[Math.min(n, table.length - 1)]
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: root._attemptReconnect()
    }

    function _attemptReconnect() {
        reconnectPending = false
        if (!autoReconnect || userDisconnected) return
        if (wifiConnected || wifiBusy) return
        if (!wifiEnabled || lastGoodSsid.length === 0) return
        if (secretsMissing) return          // a prompt is owed, not a retry

        reconnectAttempts += 1
        const esc = lastGoodSsid.replace(/'/g, "'\\''")
        console.log("[ConnectivityService] keeper: attempt",
                    reconnectAttempts, "on", lastGoodSsid)
        _beginWifiAction("Reconnecting", lastGoodSsid)
        // `connection modify ... autoconnect yes` clears NM's invisible
        // autoconnect block; without it `connection up` can be refused before
        // the radio is even asked. Chained with `;` so it never blocks the up.
        _runAction(["bash", "-c",
            "nmcli connection modify '" + esc + "' connection.autoconnect yes 2>/dev/null; " +
            "nmcli connection up '" + esc + "' 2>&1"])
    }

    function _scheduleReconnect() {
        if (!autoReconnect || userDisconnected) return
        if (lastGoodSsid.length === 0 || !wifiEnabled) return
        if (reconnectAttempts >= reconnectMaxAttempts) {
            console.log("[ConnectivityService] keeper: giving up after",
                        reconnectAttempts, "attempts")
            return
        }
        reconnectPending = true
        reconnectTimer.interval = _reconnectDelay(reconnectAttempts)
        reconnectTimer.restart()
    }

    /** Called by the poll whenever the connected state changes. */
    function _keeperOnStateChange() {
        if (wifiConnected) {
            if (wifiSSID.length > 0) lastGoodSsid = wifiSSID
            reconnectAttempts = 0
            reconnectPending = false
            reconnectTimer.stop()
            userDisconnected = false
            return
        }
        // Dropped. Only chase a network we know actually worked here.
        if (lastGoodSsid.length > 0 && !wifiBusy) _scheduleReconnect()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf192 — EXTERNAL MANAGERS
    //
    // "bluetooth dapat live din ito, tas kapag click mag open dito, same sa
    //  audio."
    //
    // Paul already had these as standalone toggle scripts (bluetoothrun.sh,
    // audiotop.sh): if the manager is running, kill it; otherwise launch it.
    // That toggle behaviour is the right one for a panel button — a second
    // click should put the window away, not spawn a second copy — so it is
    // reproduced here rather than replaced with a plain launch.
    //
    // The candidate lists exist because none of these is guaranteed present.
    // Trying each in turn means a Bluetooth button that works on a box with
    // blueman, on one with only overskride, and on a plain GNOME install,
    // without asking the user to configure anything.
    // ═══════════════════════════════════════════════════════════════════════

    /** Toggle the system Bluetooth manager window. */
    function openBluetoothManager() {
        _toggleApp(["blueman-manager", "overskride", "gnome-bluetooth-panel",
                    "blueberry"], "blueman-manager")
    }

    /** Toggle the system audio mixer window. */
    function openAudioManager() {
        _toggleApp(["pavucontrol-qt", "pavucontrol", "easyeffects",
                    "gnome-control-center"], "pavucontrol")
    }

    /**
     * ══ v8.0.0-alpha-hf195 — THE GTK WI-FI SELECTOR ══
     *
     * "if ever click yun ethernet port sa qml bar dapat mag open up din yun
     *  python wifi natin na UI."
     *
     * Paul's own GTK4/libadwaita selector, shipped into scripts/ so it
     * installs with the shell instead of living loose in his home directory.
     *
     * Deliberately NOT wrapped in the pgrep/pkill toggle the other launchers
     * use: this script already guards itself with a PID lockfile — a second
     * invocation SIGTERMs the first and exits. Wrapping it would mean two
     * mechanisms racing over the same window, and the loser leaves a stale
     * /tmp/wifi_selector.pid behind. Just run it and let it manage itself.
     *
     * Falls back to nm-connection-editor, then nmtui in a terminal, so the
     * button still does something useful on a box without GTK4/libadwaita.
     */
    function openWifiSelector() {
        const script = Quickshell.env("HOME") +
                       "/.config/quickshell/zen-shell/scripts/zen-wifi-selector.py"
        wifiSelectorRunner.command = ["bash", "-c",
            "if [ -f '" + script + "' ] && python3 -c 'import gi' 2>/dev/null; then " +
            "setsid python3 '" + script + "' >/dev/null 2>&1 & " +
            "elif command -v nm-connection-editor >/dev/null 2>&1; then " +
            "setsid nm-connection-editor >/dev/null 2>&1 & " +
            "elif command -v alacritty >/dev/null 2>&1; then " +
            "setsid alacritty --title nmtuiWindow -e nmtui >/dev/null 2>&1 & " +
            "else notify-send 'Zen Shell' " +
            "'Wi-Fi selector needs python-gobject, gtk4 and libadwaita' 2>/dev/null; fi"]
        wifiSelectorRunner.running = true
    }

    Process { id: wifiSelectorRunner; running: false }

    /** Toggle EasyEffects — the DSP window, distinct from the mixer. */
    function openEasyEffects() {
        _toggleApp(["easyeffects"], "easyeffects")
    }

    /**
     * If `matchName` is already running, kill it. Otherwise launch the first
     * of `candidates` that exists on PATH.
     *
     * pkill uses -x (exact process name) rather than -f, because -f matches
     * the whole command line and would happily kill this very shell command
     * — the classic way a toggle script takes itself out.
     */
    function _toggleApp(candidates, matchName) {
        let launch = ""
        for (let i = 0; i < candidates.length; i++) {
            launch += (i > 0 ? "elif" : "if") +
                      " command -v " + candidates[i] + " >/dev/null 2>&1; then " +
                      "setsid " + candidates[i] + " >/dev/null 2>&1 & "
        }
        launch += "else notify-send 'Zen Shell' 'None of these are installed: " +
                  candidates.join(", ") + "' 2>/dev/null; fi"

        appToggleRunner.command = ["bash", "-c",
            "if pgrep -x '" + matchName + "' >/dev/null 2>&1; then " +
            "pkill -x '" + matchName + "'; else " + launch + "; fi"]
        appToggleRunner.running = true
    }

    Process { id: appToggleRunner; running: false }

    /** Turn off wifi power saving on the device — needs authentication. */
    function disablePowerSave() {
        _run__ps("[connection]\nwifi.powersave = 2\n")
    }
    function _run__ps(conf) {
        // 2 = disable. Written as a NetworkManager drop-in so it survives
        // reboots and reasserts itself on every activation, which a bare
        // `iw set power_save off` does not.
        powerSaveRunner.command = ["bash", "-c",
            "pkexec sh -c 'mkdir -p /etc/NetworkManager/conf.d && " +
            "printf \"%s\" \"" + conf.replace(/"/g, '\\"') + "\" " +
            "> /etc/NetworkManager/conf.d/zen-wifi-powersave.conf && " +
            "systemctl reload NetworkManager'"]
        powerSaveRunner.running = true
    }
    Process {
        id: powerSaveRunner
        running: false
        onExited: reprobeWifiExtras.restart()
    }
    Timer {
        id: reprobeWifiExtras
        interval: 1200; repeat: false
        onTriggered: wifiExtrasProbe.running = true
    }

    // Power-save state is slow-moving; a 60s poll is plenty and keeps it off
    // the 3s hot path.
    Process {
        id: wifiExtrasProbe
        running: false
        command: ["bash", "-c",
            "W=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | " +
            "awk -F: '$2 == \"wifi\" { print $1; exit }'); " +
            "[ -n \"$W\" ] && iw dev \"$W\" get power_save 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim().toLowerCase()
                if (t.indexOf("power save") >= 0) {
                    root.powerSaveKnown = true
                    root.powerSaveOn = t.indexOf(": on") >= 0
                }
            }
        }
    }
    Timer {
        interval: 60000; repeat: true; running: true
        triggeredOnStart: true
        onTriggered: wifiExtrasProbe.running = true
    }

    /** One line the UI can drop straight into a status label. */
    readonly property string wifiStatusText: {
        if (wifiBusy) return wifiBusyVerb + (wifiBusySsid.length > 0 ? " to " + wifiBusySsid + "…" : "…")
        if (reconnectPending && lastGoodSsid.length > 0)                       // hf188
            return "Reconnecting to " + lastGoodSsid + " — attempt "
                   + (reconnectAttempts + 1) + " of " + reconnectMaxAttempts
        if (wrongKey && !wifiConnected)                                        // hf190
            return "Wrong password — the network rejected the saved key"
        if (wifiLastError.length > 0 && !wifiConnected) return wifiLastError   // hf187
        if (secretsMissing) return "Password needed — saved key is unreadable"
        if (!wifiEnabled) return "Wi-Fi is off"
        if (wifiConnected) return "Connected to " + wifiSSID + " · " + wifiSignal + "%"
        return "Not connected"
    }

    /** True when `ssid` is the network we are actually on right now. */
    function isConnectedTo(ssid) {
        if (!ssid || ssid.length === 0) return false
        return wifiConnected && wifiSSID === ssid
    }

    /** True when the in-flight action targets `ssid`. */
    function isBusyOn(ssid) {
        if (!wifiBusy) return false
        if (wifiBusySsid.length === 0) return false
        return wifiBusySsid === ssid
    }

    /**
     * Arm the busy flag for a user-initiated wifi action. Cleared by the
     * poll as soon as reality agrees with the request, or by the watchdog
     * below if nmcli never gets there (bad password, AP out of range).
     */
    function _beginWifiAction(verb, ssid) {
        wifiLastError = ""          // hf187 — a new attempt supersedes the old reason
        wrongKey = false            // hf190
        wifiBusyVerb = verb || "Working"
        wifiBusySsid = ssid || ""
        wifiBusy = true
        wifiBusyWatchdog.restart()
    }

    function _endWifiAction() {
        wifiBusyWatchdog.stop()
        wifiBusy = false
        wifiBusySsid = ""
        wifiBusyVerb = ""
    }

    // nmcli's own timeout for an association is 90s but a realistic
    // success lands in 2-6s. 20s is generous without leaving a spinner
    // parked on screen forever when the handshake quietly fails.
    Timer {
        id: wifiBusyWatchdog
        interval: 20000
        repeat: false
        onTriggered: root._endWifiAction()
    }

    // ═══════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf177 — nmcli TERSE-OUTPUT SPLITTER
    //
    // `nmcli -t` is colon-separated but escapes literal colons and
    // backslashes inside values as `\:` and `\\`. An SSID containing a
    // colon therefore shifted every field one to the right under a plain
    // String.split(":") — the signal read as garbage and security as the
    // tail of the name. Rare, but it silently corrupts the row rather
    // than dropping it, which is the worst failure mode to debug.
    // ═══════════════════════════════════════════════════════════════
    function _nmSplit(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line.charAt(i)
            if (ch === "\\" && i + 1 < line.length) {
                cur += line.charAt(i + 1)
                i++
            } else if (ch === ":") {
                out.push(cur)
                cur = ""
            } else {
                cur += ch
            }
        }
        out.push(cur)
        return out
    }

    /**
     * Is this IN-USE / ACTIVE cell claiming the row is the live AP?
     * NM has shipped "yes", "*", "✱" and "1" in this column across
     * versions and locales. Accept the lot rather than pin one.
     */
    /**
     * v8.0.0-alpha-hf180 — is this nmcli TYPE cell a wireless connection?
     *
     * nmcli is inconsistent about this by design: `connection show` prints the
     * setting name `802-11-wireless`, while `device show` prints the alias
     * `wifi` in GENERAL.TYPE, and the man page notes nmcli accepts `wifi` as a
     * synonym in several places. Matching one spelling means the answer
     * depends on which subcommand happened to produce the line.
     */
    function _isWirelessType(t) {
        if (!t) return false
        const v = ("" + t).trim().toLowerCase()
        return v === "802-11-wireless" || v === "wifi" || v === "wireless"
               || v === "802-11-wireless-security" || v === "wifi-sec"
    }

    function _nmInUse(cell) {
        if (!cell) return false
        const v = ("" + cell).trim().toLowerCase()
        if (v.length === 0) return false
        return v === "yes" || v === "*" || v === "1"
            || v === "✱" || v === "✓" || v === "true"
    }

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
    // v8.1.0-alpha-hf197 — VOLUME BOOST. The sink volume is no longer
    // clamped at 100%: the slider range is 0..maxVolume (300). PipeWire
    // handles >1.0 natively (software gain past the hardware max — same
    // thing pavucontrol's 153% and GNOME's "over-amplification" do).
    // UI CONTRACT: every volume surface colors the fill by zone —
    //   0..100      normal accent (safe, hardware range)
    //   past 100    yellow → orange → red gradient (hf198): the hue
    //               itself says how far past safe you are; solid red
    //               at 300 = distortion + speaker strain territory.
    // Use volumeColor(vol) below so all surfaces stay in sync.
    property int audioVolume: 0          // 0..maxVolume
    readonly property int maxVolume: 300
    readonly property bool boostActive: audioVolume > 100
    property bool audioMuted: false
    property string audioSinkName: "Speaker"
    property string audioSinkId: "@DEFAULT_AUDIO_SINK@"
    property string audioIcon: "\uf028"  // nerd:  / /

    // v8.1.0-alpha-hf197 — OUTPUT DEVICE LIST (wpctl status → Sinks block).
    // [{ id, name, isDefault }] — feeds the sink-picker dropdowns.
    property var audioSinks: []

    // ═══════════════════════════════════════════════════════════════
    // BOOST GUARD (hf200) — compressor + limiter behind the 300% boost
    //
    // "Use dynamic compression/limiting at around 80% intensity while
    //  allowing up to 3.0x gain" — zen-boost-guard.sh runs a PipeWire
    //  filter-chain sink (SC4 compressor → lookahead limiter → device)
    //  and makes it the DEFAULT sink. The shell's volume plumbing is
    //  untouched: wpctl @DEFAULT_AUDIO_SINK@ now lands on the guard,
    //  where the gain is applied PRE-chain, so the limiter catches the
    //  clipping the hf197 raw boost caused past ~120%.
    // ═══════════════════════════════════════════════════════════════
    readonly property string _guardScript:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/zen-shell/scripts/zen-boost-guard.sh"
    readonly property string _guardFlagPath:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/zen-shell/boost-guard.disabled"
    readonly property string guardSinkNodeName: "zen_boost_sink"

    property bool boostGuardEnabled: true    // user intent (flag file = disabled)
    property bool boostGuardActive: false    // live, from `status` in the poll
    property string boostGuardTarget: ""     // node.name of the real device behind the guard
    property string boostGuardQuality: ""    // "ladspa" (SC4+limiter) | "clamp" (fallback)

    function setBoostGuard(on) {
        boostGuardEnabled = on
        _runAction(["bash", "-c",
            on ? ("rm -f '" + _guardFlagPath + "'; '" + _guardScript + "' start")
               : ("touch '" + _guardFlagPath + "'; '" + _guardScript + "' stop")])
        Qt.callLater(function() { refreshTimer.restart() })
    }

    // Autostart on shell load unless the user disabled it. Delayed a few
    // seconds so PipeWire and the device sinks are up first.
    Timer {
        id: guardBootTimer
        interval: 4000; repeat: false; running: true
        onTriggered: {
            guardBootProc.running = true
        }
    }
    Process {
        id: guardBootProc
        running: false
        command: ["bash", "-c",
            "if [ -f '" + root._guardFlagPath + "' ]; then echo disabled; " +
            "else '" + root._guardScript + "' start >/dev/null 2>&1; echo started; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.boostGuardEnabled = (text.trim() !== "disabled")
                console.log("[Connectivity] boost guard boot:", text.trim())
            }
        }
    }

    // One color rule for every volume fill/label across the shell.    // hf198 — "kapag malakas na warning siya yellow na yun color, orange
    // till red": the boost region is now a smooth GRADIENT instead of two
    // hard steps. ≤100 keeps the normal accent; from 100 the fill walks
    // yellow → orange (at ~200) → red (at 300), so "how loud past safe"
    // reads off the hue itself. Single source of truth — every surface
    // that calls this (all sliders, bar module, OSD) shifts together.
    function _mixColor(a, b, t) {
        t = Math.max(0, Math.min(1, t))
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }
    function volumeColor(vol) {
        if (audioMuted) return ThemeService.grey2
        if (vol <= 100) return ThemeService.blue
        const t = (vol - 100) / (maxVolume - 100)   // 0..1 across the boost band
        return t < 0.5
               ? _mixColor(ThemeService.yellow, ThemeService.orange, t * 2)
               : _mixColor(ThemeService.orange, ThemeService.red, (t - 0.5) * 2)
    }

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

    // v8.0.0-alpha-hf145 — set by setVolume() just now? Then the tick already
    // played there; don't play it again when the wpctl poll echoes the value back.
    property double _selfSetMs: 0

    onAudioVolumeChanged: {
        if (audioVolume !== _lastOsdVolume && _lastOsdVolume >= 0) {
            if (typeof NotificationService !== "undefined"
                && NotificationService.showVolumeOSD) {
                NotificationService.showVolumeOSD(audioMuted ? 0 : (audioVolume / 100))
            }
            // Only the HARDWARE path (keys, external mixer) reaches the tick here;
            // our own setVolume already ticked. 400ms covers the wpctl round-trip.
            const selfSet = (Date.now() - _selfSetMs) < 400
            if (!selfSet && _isWarmedUp() && typeof SoundEffectsService !== "undefined") {
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
    property string lanIcon: "\udb80\ude00"    // nerd: 󰈁

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
        // hf197: clamp to maxVolume (300), not 100 — boost range.
        const clamped = Math.max(0, Math.min(maxVolume, vol))
        _runAction(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100).toFixed(2)])
        // v8.0.0-alpha-hf145 — play the tick ONLY when the value actually moved.
        // This is the user-initiated path (slider drag, scroll, Quick Settings),
        // and it set audioVolume directly — so onAudioVolumeChanged, which is
        // poll-driven, never re-fired and the drag was silent. Hardware keys went
        // through the poll and did tick; the slider did not. Now both do, and the
        // "moved" check keeps a drag that lands on the same integer from double-firing.
        const moved = (clamped !== audioVolume)
        audioVolume = clamped
        _updateAudioIcon()
        if (typeof NotificationService !== "undefined" && NotificationService.showVolumeOSD) {
            NotificationService.showVolumeOSD(clamped / 100)
        }
        if (moved) {
            _selfSetMs = Date.now()
            if (_isWarmedUp() && typeof SoundEffectsService !== "undefined")
                SoundEffectsService.play("volume-change")
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

    // v8.1.0-alpha-hf197 — switch the default output device.
    // `wpctl set-default <id>` moves the default sink; PipeWire's
    // default-audio-sink metadata also MOVES ACTIVE STREAMS to it,
    // so music mid-play jumps to the earphones instantly.
    //
    // hf200 — while the boost guard is up, the DEFAULT must stay the
    // guard sink (that's where the protected gain lives). Picking a
    // device in the dropdown therefore re-TARGETS the guard's output
    // instead: resolve the picked sink's node.name, hand it to
    // `zen-boost-guard.sh set-target`, brief <1s relaunch, streams stay
    // parked on the guard and resume on the new device.
    function setDefaultSink(id) {
        if (id === undefined || id === null) return
        if (boostGuardActive) {
            _runAction(["bash", "-c",
                "N=$(wpctl inspect " + parseInt(id) + " 2>/dev/null " +
                "| grep 'node.name' | head -1 | sed 's/.*= //;s/\"//g'); " +
                "[ -n \"$N\" ] && '" + _guardScript + "' set-target \"$N\""])
        } else {
            _runAction(["bash", "-c", "wpctl set-default " + parseInt(id)])
        }
        // Optimistic UI: flip isDefault locally so the dropdown checkmark
        // moves before the next poll confirms it.
        const next = []
        for (let i = 0; i < audioSinks.length; i++) {
            const s = audioSinks[i]
            next.push({ id: s.id, name: s.name, isDefault: (s.id === parseInt(id)) })
            if (s.id === parseInt(id) && !boostGuardActive) audioSinkName = s.name.substring(0, 30)
        }
        audioSinks = next
        Qt.callLater(function() { refreshTimer.restart() })
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
        // v8.0.0-alpha-hf177: light the "Connecting…" state on the tap, not
        // on nmcli's reply 2-4s later. This is the half of "hindi malaman if
        // gumana ba" that no amount of state-parsing fixes — the user needs
        // the click acknowledged before the radio has an answer.
        // hf188 — an explicit Connect re-arms the keeper and clears any stale
        // secrets flag, so a fresh password attempt is never pre-empted.
        userDisconnected = false
        secretsMissing = false
        wrongKey = false            // hf190
        reconnectAttempts = 0
        _beginWifiAction("Connecting", ssid)

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
        // ══ v8.0.0-alpha-hf183 — "SAVED" WAS NOT THE SAME AS "CONNECTABLE" ══
        //
        // The old probe asked one question: does a profile with this name
        // exist? If yes it ran `nmcli connection up`, which is correct only
        // when NetworkManager can actually READ the pre-shared key.
        //
        // It often cannot. NM stores a PSK one of two ways, chosen by
        // `802-11-wireless-security.psk-flags`:
        //
        //   0  system-owned  — NM keeps it in the profile, always available
        //   1  agent-owned   — NM keeps NOTHING; it asks a running "secret
        //                      agent" (nm-applet, GNOME Shell, plasma-nm)
        //                      for the key every single time
        //
        // A network first joined under GNOME or KDE is usually flag 1, with
        // the key sitting in that desktop's keyring. Zen Shell registers no
        // secret agent — so under Hyprland the key is simply unreachable, and
        // NM's own log says exactly that:
        //
        //   psk mismatch reported by supplicant, asking for new key
        //   no secrets: No agents were available for this request.
        //   state change: need-auth -> failed (reason 'no-secrets')
        //
        // The profile looks perfectly saved in every UI. It just cannot
        // authenticate, forever, with no visible reason. That is the
        // "bumibitaw" — it was never the radio, the cable or the driver.
        //
        // Three outcomes now instead of two:
        //   SAVED      profile exists and the key is readable → connection up
        //   NOSECRET   profile exists, key unreachable        → prompt, repair
        //   NEW        no profile                             → prompt
        // ══ v8.0.0-alpha-hf191 — A KNOWN-BAD KEY IS NOT A USABLE KEY ══
        //
        // The probe answers SAVED whenever a profile exists with psk-flags 0,
        // and SAVED means "just run connection up". That is right until the
        // stored key is the one we have already watched the AP reject — then
        // it is a guarantee of failure, and worse, it means the user is never
        // asked for the correct password. They can click Connect forever.
        //
        // If the last handshake for THIS network came back WRONG_KEY, skip
        // straight to the prompt. hf190 detects it; this acts on it.
        if (root.wrongKey && root.wrongKeySsid === ssid) {
            console.log("[ConnectivityService] known-bad key for", ssid, "— prompting instead")
            savedCredsCheck.forcePrompt = true
        } else {
            savedCredsCheck.forcePrompt = false
        }

        savedCredsCheck.command = ["bash", "-c",
            "if ! nmcli -t -f NAME connection show 2>/dev/null | grep -qFx '" + escSsid + "'; then echo NEW; exit 0; fi; " +
            "F=$(nmcli -t -f 802-11-wireless-security.psk-flags connection show '" + escSsid + "' 2>/dev/null | cut -d: -f2-); " +
            // An open network has no key and needs none — still SAVED.
            "S=$(nmcli -t -f 802-11-wireless-security.key-mgmt connection show '" + escSsid + "' 2>/dev/null | cut -d: -f2-); " +
            "if [ -z \"$S\" ] || [ \"$S\" = \"none\" ]; then echo SAVED; exit 0; fi; " +
            // ══ v8.0.0-alpha-hf189 — DECIDE ON psk-flags ALONE ══
            //
            // hf183 also read the key back with `nmcli -s` and required it to
            // be non-empty. That was my mistake: `--show-secrets` needs polkit
            // authorization to read a SYSTEM connection's secrets, and without
            // an interactive agent nmcli returns the field EMPTY rather than
            // failing. So a perfectly healthy system-owned profile could be
            // read as having no key and classified NOSECRET — a false alarm
            // that prompts for a password already stored and working.
            //
            // psk-flags needs no authorization and is the actual answer:
            //   0 / unset  NM stores the key itself → nothing else is needed
            //   1          agent-owned → NM stores nothing, needs an agent
            //   2          not-saved  → must be supplied every time
            //   4          not-required
            // Anything but 0/unset means an activation can stall on secrets,
            // which is what we are trying to detect. Reading the key was never
            // necessary to know that.
            "case \"$F\" in " +
            "''|0|'0 (none)'|'0 (NONE)') echo SAVED ;; " +
            "*) echo NOSECRET ;; esac"]
        savedCredsCheck.running = true
    }

    // Async helper: checks saved-creds, then either reconnects
    // directly OR opens the in-shell password prompt.
    Process {
        id: savedCredsCheck
        /** hf191 — force the password prompt even if the profile looks saved. */
        property bool forcePrompt: false
        property string targetSsid: ""
        property string escSsid: ""
        property bool isSecured: false
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // hf191: reassigned below when a known-bad key overrides SAVED,
                // so this cannot be const — a const assignment throws at runtime
                // and would take the whole connect path down with it.
                let result = text.trim()
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

                // hf191 — a profile whose key the AP has already rejected is
                // treated as if it had no key at all.
                if (result === "SAVED" && savedCredsCheck.forcePrompt) {
                    console.log("[ConnectivityService] overriding SAVED — key is known bad")
                    result = "NOSECRET"
                }

                if (result === "SAVED") {
                    // Saved network with a key NM can read — reconnect directly
                    _runAction(["bash", "-c",
                        "nmcli connection up '" + savedCredsCheck.escSsid + "'" + metricTail])
                    return
                }

                // v8.0.0-alpha-hf183 — saved, but the key is agent-owned and
                // no agent exists. Prompting is the ONLY way forward; running
                // `connection up` here is what produced the silent
                // need-auth → no-secrets → failed loop.
                if (result === "NOSECRET") {
                    root.secretsMissing = true
                    const escNS = savedCredsCheck.escSsid
                    const ssidNS = savedCredsCheck.targetSsid
                    const tailNS = metricTail
                    const repair = function(password) {
                        const escPw = password.replace(/'/g, "'\\''")
                        // Write the key into the profile AND flip psk-flags to
                        // 0, so NetworkManager owns it from now on and never
                        // needs an agent again — including on autoconnect at
                        // boot, which is the case no prompt can ever serve.
                        _runAction(["bash", "-c",
                            root._pwConnectCmd(escNS, escPw, tailNS)])   // hf191
                        root.secretsMissing = false
                    }
                    if (typeof PasswordPromptService === "undefined") {
                        _runAction(["bash", "-c",
                            "PW=$(zenity --password --title='Wi-Fi key needed: " +
                            escNS.replace(/\$/g, "\\$") + "' 2>/dev/null) || exit 1; " +
                            "[ -z \"$PW\" ] && exit 1; " +
                            "nmcli connection modify '" + escNS + "' " +
                            "802-11-wireless-security.psk \"$PW\" " +
                            "802-11-wireless-security.psk-flags 0 2>/dev/null; " +
                            "nmcli connection up '" + escNS + "'" + tailNS])
                        return
                    }
                    PasswordPromptService.requestPassword(ssidNS, repair, function() {
                        root._endWifiAction()
                    })
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
                    // v8.0.0-alpha-hf183: pin psk-flags 0 straight after the
                    // connect. `nmcli device wifi connect` usually defaults to
                    // system-owned already, but "usually" is what left this
                    // profile unusable in the first place. Chained with `;` so
                    // a failure here never rolls back a good connection.
                    // hf191 — writes the key into the profile; see _pwConnectCmd.
                    _runAction(["bash", "-c",
                        root._pwConnectCmd(escForCb, escPw, metricTailForCb)])
                }, function() {
                    // User cancelled — no action needed
                    // v8.0.0-alpha-hf177: but DO drop the busy state, or the
                    // panel sits on "Connecting…" until the 20s watchdog.
                    root._endWifiAction()
                    console.log("[ConnectivityService] WiFi password prompt cancelled by user")
                })
            }
        }
    }


    function disconnectWifi() {
        // v8.0.0-alpha-hf177: the old command hardcoded `wlan0` and then
        // tried the LITERAL string `wlp*` — bash does not glob interface
        // names, there is no such file to expand against, so on any box
        // using predictable naming (wlp3s0, wlo1) this silently did nothing.
        // Ask nmcli which device is actually wifi and disconnect that one.
        // v8.0.0-alpha-hf188 — deliberate disconnect. The keeper stands down
        // until the user asks for a connection again; nothing is more annoying
        // than a shell that reconnects what you just switched off.
        userDisconnected = true
        reconnectPending = false
        reconnectTimer.stop()
        _beginWifiAction("Disconnecting", root.wifiSSID)
        _runAction(["bash", "-c",
            "DEV=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | " +
            "awk -F: '$2 == \"wifi\" { print $1; exit }'); " +
            "[ -n \"$DEV\" ] && nmcli device disconnect \"$DEV\" 2>/dev/null"])
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
        _beginWifiAction("Forgetting", ssid)   // v8.0.0-alpha-hf177
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
        _beginWifiAction("Connecting", ssid)   // v8.0.0-alpha-hf177
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
        property string lastStderr: ""
        // After any action completes, refresh state immediately +
        // again at +1.5s (nmcli convergence delay).
        //
        // v8.0.0-alpha-hf187 — and a non-zero exit now reaches the UI. nmcli's
        // messages are already human-readable ("Secrets were required, but not
        // provided", "Connection activation failed: ..."), so they are shown
        // nearly as-is: first line, "Error:" prefix stripped, capped at 120
        // chars — the rail has room for a sentence, not a paragraph.
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                let msg = actionRunner.lastStderr.trim()
                if (msg.length === 0) msg = "nmcli exited " + exitCode
                const nl = msg.indexOf("\n")
                if (nl > 0) msg = msg.substring(0, nl)
                msg = msg.replace(/^Error:\s*/i, "")
                if (msg.length > 120) msg = msg.substring(0, 117) + "\u2026"
                root.wifiLastError = msg
                console.warn("[ConnectivityService] action failed:", msg)

                // v8.0.0-alpha-hf188 — classify the failure. A missing secret
                // is not a transient fault: nmcli will fail identically every
                // time until someone hands it a password, so the keeper must
                // stop and the UI must ask. nmcli phrases this several ways
                // depending on the path taken, hence the substring set.
                const low = msg.toLowerCase()
                if (low.indexOf("secret") >= 0
                    || low.indexOf("password for") >= 0
                    || low.indexOf("no agents") >= 0
                    || low.indexOf("without '--ask'") >= 0) {
                    root.secretsMissing = true
                    root.reconnectPending = false
                    reconnectTimer.stop()
                    console.warn("[ConnectivityService] keeper: stopping — needs a password")
                    // ══ v8.0.0-alpha-hf190 — "SECRETS REQUIRED" IS AMBIGUOUS ══
                    //
                    // nmcli says the same thing for two completely different
                    // faults, and the difference is everything:
                    //
                    //   A  no key is stored        → supply one, done
                    //   B  a key IS stored and it is WRONG → the 4-way
                    //      handshake fails, NM concludes the psk must be bad,
                    //      asks for a replacement, finds no agent, and reports
                    //      "Secrets were required, but not provided"
                    //
                    // Case B reads exactly like case A from nmcli alone. It cost
                    // this project most of a night: psk-flags was 0, the key was
                    // stored, NM logged "secrets exist. No new secrets needed."
                    // and handed it over — and the message still said secrets
                    // were missing.
                    //
                    // Only the supplicant knows which it was, so ask it. It says
                    // so unmistakably: "4-Way Handshake failed - pre-shared key
                    // may be incorrect" and "reason=WRONG_KEY".
                    wrongKeyProbe.running = false
                    wrongKeyProbe.running = true
                } else {
                    // Transient: let the keeper back off and try again.
                    root._scheduleReconnect()
                }
                // Nothing is going to converge, so stop the spinner now instead
                // of making the user wait out the 20s watchdog.
                root._endWifiAction()
            }
            actionRunner.lastStderr = ""
            root.update()
            postActionRefreshTimer.restart()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                actionRunner.lastStderr = text
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
            // v8.0.0-alpha-hf177: `in-use` is the modern field name; `active`
            // is the pre-1.40 alias. Ask for in-use first and fall back, so
            // the row marker arrives on both old and new NetworkManager.
            // head cap lifted 20 → 40: in a dense apartment block the AP you
            // are actually on can sort past twenty neighbours.
            //
            // v8.0.0-alpha-hf178: BSSID added, and `--rescan no` on the poll.
            //
            //   · BSSID is what makes one SSID broadcast by two radios
            //     (2.4 + 5GHz, or a mesh node and a repeater) resolvable. Two
            //     rows, one link — without the BSSID there is no way to tell
            //     which row you are actually on.
            //   · `--rescan auto` (the default) makes NM run a fresh scan
            //     whenever the cache is older than 30s. This poll runs every
            //     3s, so it kept that cache warm and NM kept scanning. A scan
            //     takes the radio OFF its operating channel for a few hundred
            //     ms per channel — on a strong link you never notice, on a
            //     59% link that is where packets die. The poll now reads the
            //     cache only; the Rescan button still forces a real scan.
            "(nmcli -t -f in-use,bssid,ssid,signal,security device wifi list --rescan no 2>/dev/null " +
            " || nmcli -t -f in-use,bssid,ssid,signal,security device wifi list 2>/dev/null " +
            " || nmcli -t -f active,bssid,ssid,signal,security device wifi list 2>/dev/null) | head -40; " +

            // v8.0.0-alpha-hf177: THE authoritative answer to \"are we on
            // wifi, and which one\". Independent of how the scan table draws
            // its in-use marker — this is NM's own active-connection table.
            "echo '---WIFI_ACTIVE---'; " +
            // Raw — filtering happens in _parseAll via _nmSplit, because awk
            // -F: would break on the `\:` nmcli emits inside an escaped SSID.
            "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null; " +

            // v8.0.0-alpha-hf178: driver-level truth, below NetworkManager.
            //
            // WIFI_ACTIVE gives the CONNECTION PROFILE NAME, which hf177
            // assumed equals the SSID. It usually does — but NM names a
            // second profile for the same network "KiyuFamilyFibr 1", and a
            // renamed profile can be anything at all. When the name drifts
            // from the SSID, nothing in the scan list matches it and every
            // row loses its Connected badge while the header still claims a
            // connection.
            //
            // `iw dev <dev> link` asks the card. It reports the real SSID,
            // the exact BSSID we are associated to, and the signal in dBm —
            // no scan, no NM opinion, ~1ms.
            "echo '---WIFI_LINK---'; " +
            "WDEV=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | " +
            "awk -F: '$2 == \"wifi\" { print $1; exit }'); " +
            "[ -n \"$WDEV\" ] && iw dev \"$WDEV\" link 2>/dev/null; " +

            // v8.0.0-alpha-hf180: THIRD source, and the least ambiguous of the
            // three. `nmcli device show <dev>` reports GENERAL.CONNECTION (the
            // live profile) and GENERAL.STATE ("100 (connected)") straight off
            // the device, with no scan table and no type-string guessing. It
            // answers even when `iw` is absent and even when the scan cache is
            // stale, which is precisely the hole the other two fell into.
            "echo '---WIFI_DEV---'; " +
            "[ -n \"$WDEV\" ] && nmcli -t -f GENERAL.CONNECTION,GENERAL.STATE " +
            "device show \"$WDEV\" 2>/dev/null; " +

            // v6.16.4.12.9.9: saved wifi connection list
            "echo '---WIFI_SAVED---'; " +
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null | " +
            // hf180: `wifi` is the same thing under a different spelling, and
            // which one you get depends on the nmcli version. Accept both, or
            // the Saved Networks section silently comes back empty.
            "awk -F: '$2 == \"802-11-wireless\" || $2 == \"wifi\" {print $1}'; " +

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

            // hf197: every output device. The Sinks block of `wpctl status`
            // — one line per sink, `*` marks the default:
            //   |  *   55. Family 17h HD Audio Analog Stereo  [vol: 0.75]
            "echo '---AUDIO_SINKS---'; " +
            "wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p'; " +

            // hf200: guard status (ACTIVE/INACTIVE + TARGET= + QUALITY=)
            "echo '---BOOST_GUARD---'; " +
            "'" + _guardScript + "' status 2>/dev/null; " +

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
        let wifiRadio = "", wifiStatus = "", wifiSaved = "", wifiActive = "", wifiLink = "", wifiDev = ""
        let btPower = "", btDevs = "", btPaired = "", btNearby = ""
        let sinkVol = "", sinkName = "", sinksRaw = "", guardRaw = "", sourceVol = "", sourceName = ""
        let lanLines = "", lanIp = ""

        for (let i = 0; i < sections.length; i++) {
            const tag = sections[i].trim()
            const val = (i + 1 < sections.length) ? sections[i + 1].trim() : ""
            switch (tag) {
                case "WIFI_RADIO":       wifiRadio = val; break
                case "WIFI_STATUS":      wifiStatus = val; break
                case "WIFI_ACTIVE":      wifiActive = val; break
                case "WIFI_LINK":        wifiLink = val; break
                case "WIFI_DEV":         wifiDev = val; break
                case "WIFI_SAVED":       wifiSaved = val; break
                case "BT_POWER":         btPower = val; break
                case "BT_DEVICES":       btDevs = val; break
                case "BT_PAIRED":        btPaired = val; break
                case "BT_NEARBY":        btNearby = val; break
                case "AUDIO_SINK":       sinkVol = val; break
                case "AUDIO_SINK_NAME":  sinkName = val; break
                case "AUDIO_SINKS":      sinksRaw = val; break
                case "BOOST_GUARD":      guardRaw = val; break
                case "AUDIO_SOURCE":     sourceVol = val; break
                case "AUDIO_SOURCE_NAME": sourceName = val; break
                case "LAN":             lanLines = val; break
                case "LAN_IP":          lanIp = val; break
            }
        }

        // ── WiFi ──
        wifiEnabled = (wifiRadio.indexOf("enabled") >= 0)

        // v8.0.0-alpha-hf178: ask the CARD first. `iw dev <dev> link` prints
        //
        //     Connected to aa:bb:cc:dd:ee:ff (on wlp3s0)
        //             SSID: KiyuFamilyFibr
        //             signal: -52 dBm
        //
        // That BSSID is the one thing that makes a two-radio network
        // resolvable, and that SSID is the real one rather than a profile
        // name that may have drifted from it.
        let linkSsid = "", linkBssid = "", linkDbm = 0
        if (wifiLink) {
            const lLines = wifiLink.split("\n")
            for (const lLine of lLines) {
                const t = lLine.trim()
                if (t.indexOf("Connected to ") === 0) {
                    const mB = t.match(/Connected to ([0-9a-fA-F:]{17})/)
                    if (mB) linkBssid = mB[1].toLowerCase()
                } else if (t.indexOf("SSID:") === 0) {
                    linkSsid = t.substring(5).trim()
                } else if (t.indexOf("signal:") === 0) {
                    const mS = t.match(/(-?\d+)\s*dBm/)
                    if (mS) linkDbm = parseInt(mS[1]) || 0
                }
            }
        }

        // v8.0.0-alpha-hf177: NM's active-connection table — the fallback
        // when `iw` is not installed. Lines are `NAME:TYPE`; keep the one
        // whose last field is wireless. NOTE this yields the PROFILE NAME,
        // which is only usually the SSID — hence the iw probe above.
        let activeSsid = ""
        if (wifiActive) {
            const aLines = wifiActive.split("\n")
            for (const aLine of aLines) {
                if (!aLine || !aLine.trim()) continue
                const aParts = _nmSplit(aLine)
                if (aParts.length < 2) continue
                const aType = (aParts[aParts.length - 1] || "").trim()
                if (_isWirelessType(aType)) {
                    // NAME may itself have held a colon — rejoin everything
                    // ahead of the type field.
                    activeSsid = aParts.slice(0, aParts.length - 1).join(":")
                    break
                }
            }
        }
        // v8.0.0-alpha-hf180 — the device block. GENERAL.CONNECTION is the
        // live profile name, GENERAL.STATE is "100 (connected)" when up.
        let devConn = "", devUp = false
        if (wifiDev) {
            for (const dLine of wifiDev.split("\n")) {
                const t = dLine.trim()
                if (t.indexOf("GENERAL.CONNECTION:") === 0) {
                    const v = t.substring(19).trim()
                    if (v && v !== "--") devConn = v
                } else if (t.indexOf("GENERAL.STATE:") === 0) {
                    devUp = t.indexOf("connected") >= 0
                            && t.indexOf("disconnected") < 0
                }
            }
        }

        // Precedence: the card, then the device, then the connection table.
        // Each is only consulted when the one above it stayed silent, and any
        // of them alone is enough — see the note on the OR in the scan loop.
        if (linkSsid.length > 0) activeSsid = linkSsid
        else if (devUp && devConn.length > 0) activeSsid = devConn
        wifiActiveSsid = activeSsid
        wifiBSSID = linkBssid
        wifiSignalDbm = linkDbm

        let foundActive = false
        const networks = []
        // ══ v8.0.0-alpha-hf178 — ONE ROW PER NETWORK ══
        //
        // "kapag connected na bigla nawawala... dahil ba naka connect yun lan
        //  cable ko kaya bigla siya bumibitaw?"
        //
        // The screenshot showed KiyuFamilyFibr twice, both badged Connected,
        // at 100% and 59%. That is not two networks and it is not the cable —
        // it is ONE network broadcast by two radios (2.4GHz + 5GHz, or a
        // second mesh node). `nmcli device wifi list` returns a row per
        // BSSID, and hf177 matched rows by SSID, so both lit up.
        //
        // The visible "bumibitaw" follows from the same thing: hf177 sorts
        // connected-first then by signal, both rows claimed connected, and
        // their signal readings drift every 3s poll — so the two rows kept
        // swapping places under the cursor.
        //
        // Fix: fold rows by SSID. The kept row is the one we are actually
        // associated to when the BSSID says so, otherwise the strongest.
        // `bssCount` is retained so the UI can still say "2 access points"
        // rather than pretending the second radio does not exist —
        // wala tayong babawasan, we are hiding a duplicate, not data.
        const bySsid = ({})
        if (wifiStatus) {
            const lines = wifiStatus.split("\n")
            for (const line of lines) {
                if (!line) continue
                const parts = _nmSplit(line)
                if (parts.length >= 5) {
                    // hf178 field order: in-use : bssid : ssid : signal : security
                    const bssidCell = (parts[1] || "").toLowerCase()
                    const ssidCell = parts[2]
                    // ══ v8.0.0-alpha-hf180 — THE FALLBACKS ARE NOT MUTUALLY
                    //    EXCLUSIVE, AND hf178 MADE THEM SO ══
                    //
                    // hf178 wrote the SSID and in-use tests as
                    // `linkBssid.length === 0 && ...`, reasoning that an exact
                    // BSSID match should win. It does — but gating the others
                    // on the BSSID being ABSENT means that the moment `iw`
                    // answers, the other two stop being consulted at all.
                    //
                    // That is fatal in exactly the situation hf178 was written
                    // for. With `--rescan no` the scan cache ages, and on a
                    // two-radio network the cached rows can easily hold the
                    // OTHER BSSID than the one we are associated to. Then:
                    // BSSID match fails (that row is not cached), SSID match
                    // is switched off, in-use match is switched off — and a
                    // perfectly healthy connection reports "Not connected".
                    //
                    // Three independent sources are worth having precisely
                    // because any one of them can be wrong. OR them.
                    const bssidMatch = (linkBssid.length > 0 && bssidCell === linkBssid)
                    const ssidMatch  = (activeSsid.length > 0 && ssidCell === activeSsid)
                    const inUseMatch = _nmInUse(parts[0])
                    const active = bssidMatch || ssidMatch || inUseMatch
                    const ssid = ssidCell
                    const signal = parseInt(parts[3]) || 0
                    // v6.16.4.12.9.11: nmcli -t outputs literal "--"
                    // for null security on open networks. The string "--"
                    // has length 2 → previous code thought open networks
                    // were secured and showed the lock icon + tried to
                    // prompt for a password. Normalize "--" to "" so
                    // downstream isSecured checks work correctly.
                    // hf178: security is field 5 now that bssid is field 2.
                    let security = parts[4] || ""
                    if (security === "--") security = ""
                    if (ssid) {
                        const prev = bySsid[ssid]
                        if (!prev) {
                            bySsid[ssid] = { ssid: ssid, bssid: bssidCell, signal: signal,
                                             security: security, active: active, bssCount: 1 }
                        } else {
                            prev.bssCount += 1
                            // Keep the associated radio if we can identify it,
                            // otherwise the strongest one. Never let a weaker
                            // duplicate overwrite an active row.
                            const better = active || (!prev.active && signal > prev.signal)
                            if (better) {
                                prev.bssid = bssidCell
                                prev.signal = signal
                                prev.active = prev.active || active
                                if (security.length > 0) prev.security = security
                            } else if (active) {
                                prev.active = true
                            }
                        }
                        if (active) {
                            foundActive = true
                            wifiConnected = true
                            wifiSSID = ssid
                            wifiSignal = signal
                        }
                    }
                }
            }
            for (const k in bySsid) networks.push(bySsid[k])
        }

        // v8.0.0-alpha-hf180 — the connected network must always be IN the
        // list, even when the scan cache does not have it. `--rescan no`
        // (hf178) means the cache ages, and an aged cache legitimately loses
        // rows; hf179 then drew a list with no Connected row anywhere on it
        // while the machine was plainly online. Synthesise the row instead —
        // marked so the UI can say the signal figure came from the driver.
        if (activeSsid.length > 0 && !foundActive) {
            let pct = wifiSignal
            if (linkDbm < 0)
                pct = Math.max(0, Math.min(100, Math.round(2 * (linkDbm + 100))))
            networks.unshift({ ssid: activeSsid, bssid: linkBssid,
                               signal: pct, security: "", active: true,
                               bssCount: 1, fromLink: true })
            foundActive = true
            wifiConnected = true
            wifiSSID = activeSsid
            wifiSignal = pct
        }
        if (!foundActive) {
            // v8.0.0-alpha-hf177: a hidden SSID, or one that dropped out of
            // this particular scan sweep, is still a real connection. Trust
            // the active-connection table even with no matching scan row —
            // signal stays at the last known value rather than snapping to 0
            // and flickering the bar glyph down a tier every few seconds.
            if (activeSsid.length > 0) {
                wifiConnected = true
                wifiSSID = activeSsid
                // v8.0.0-alpha-hf178: with `--rescan no` the scan cache can go
                // stale and drop the row for the AP we are sitting on. The
                // driver's dBm is always current, so derive a percentage from
                // it rather than freezing an increasingly old scan number.
                // -30dBm ≈ 100%, -90dBm ≈ 0% — NM's own rough mapping.
                if (linkDbm < 0) {
                    const pct = Math.round(2 * (linkDbm + 100))
                    wifiSignal = Math.max(0, Math.min(100, pct))
                }
            } else {
                wifiConnected = false
                wifiSSID = ""
                wifiSignal = 0
            }
        }
        // v8.0.0-alpha-hf180 — an empty result from a cached scan is "no news",
        // not "no networks". Blanking the list on it is what made the rail
        // flicker rows in and out — the "bumibitaw" that was never the radio.
        if (networks.length > 0 || !wifiEnabled)
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

        // v8.0.0-alpha-hf177: retire the "Connecting…" state the moment
        // reality catches up with what the user asked for. Connect clears on
        // arrival at the target SSID; disconnect clears when nothing is up.
        // v8.0.0-alpha-hf188 — feed the keeper on every poll. Cheap: it only
        // acts when the connected state actually differs from last time.
        if (wifiConnected !== _keeperLastConnected) {
            _keeperLastConnected = wifiConnected
            _keeperOnStateChange()
        } else if (wifiConnected && wifiSSID.length > 0 && lastGoodSsid !== wifiSSID) {
            lastGoodSsid = wifiSSID          // roamed to a different SSID
        }

        if (wifiBusy) {
            const arrived = wifiBusySsid.length > 0
                            && wifiConnected && wifiSSID === wifiBusySsid
            const departed = wifiBusyVerb === "Disconnecting" && !wifiConnected
            const forgotten = wifiBusyVerb === "Forgetting"
                              && savedWifiNetworks.indexOf(wifiBusySsid) < 0
            if (arrived || departed || forgotten) _endWifiAction()
        }

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
            // hf197: ceiling is maxVolume (300), not 100 — an externally
            // boosted volume (pavucontrol, our own boost slider) must round-trip.
            const vm = sinkVol.match(/Volume:\s+([\d.]+)/)
            if (vm) audioVolume = Math.min(maxVolume, Math.round(parseFloat(vm[1]) * 100))
            audioMuted = sinkVol.indexOf("[MUTED]") >= 0
        }
        if (sinkName) audioSinkName = sinkName.substring(0, 30)
        _updateAudioIcon()

        // ── Boost guard status (hf200) ──
        if (guardRaw) {
            boostGuardActive = guardRaw.indexOf("ACTIVE") === 0
            const tm = guardRaw.match(/TARGET=(.+)/)
            const qm = guardRaw.match(/QUALITY=(\w+)/)
            boostGuardTarget = (boostGuardActive && tm) ? tm[1].trim() : ""
            boostGuardQuality = (boostGuardActive && qm) ? qm[1] : ""
        } else {
            boostGuardActive = false
        }

        // ── Output device list (hf197) ──
        // Lines look like:  │  *   55. Device Name Here  [vol: 0.75]
        // `*` = current default. Anything without `NN.` is a header — skip.
        //
        // hf200 — while the guard is up, the guard sink IS the default but
        // it is not a device: hide it from the picker, and mark the sink
        // the guard TARGETS as the "current" one instead, so the dropdown
        // still reads as "which device am I on". Matching is by wpctl's
        // description vs the guard's node.name-based target — wpctl status
        // shows descriptions, so when none matches (name≠description) the
        // list simply shows no dot rather than a wrong one.
        if (sinksRaw) {
            const sinks = []
            for (const sLine of sinksRaw.split("\n")) {
                const sm = sLine.match(/(\*)?\s*(\d+)\.\s+(.+?)\s*\[vol:/)
                if (!sm) continue
                const nm = sm[3].trim()
                if (boostGuardActive && nm.indexOf("Zen Boost") >= 0) continue   // hf200: not a device
                sinks.push({
                    id: parseInt(sm[2]),
                    name: nm,
                    isDefault: boostGuardActive
                               ? (boostGuardTarget.length > 0 && nm === boostGuardTarget)
                               : sLine.indexOf("*") >= 0
                })
            }
            // Only publish on real change — audioSinks feeds Repeaters, and
            // reassigning identical arrays every 3s poll would rebuild them.
            if (JSON.stringify(sinks) !== JSON.stringify(audioSinks))
                audioSinks = sinks
        }

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
