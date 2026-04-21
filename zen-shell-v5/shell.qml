//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
//@ pragma ShellId zen-shell

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var startMenuScreen: null

    function toggleStartMenuOn(screen) {
        if (startMenuScreen === screen) startMenuScreen = null
        else startMenuScreen = screen
    }
    function closeStartMenu() { startMenuScreen = null }

    property bool wallpaperPickerVisible: false
    property bool settingsVisible: false
    property bool settingsFullscreen: false
    property bool keybindCheatsheetVisible: false
    property bool controlPanelVisible: false
    property bool calendarVisible: false

    property bool powerConfirmVisible: false
    property string powerAction: ""
    property string powerCommand: ""
    // v6.15: screenshot rope overlay
    property bool screenshotRopeVisible: false
    // v6.15: monitor name where the screenshot rope should appear
    // (queried from hyprctl cursorpos at trigger time so it follows
    //  the cursor, not the stale focusedMonitor)
    property string screenshotRopeTargetMonitor: ""

    function triggerPowerAction(action, cmd) {
        powerAction = action
        powerCommand = cmd
        powerConfirmVisible = true
    }

    // v6.15: Screenshot rope monitor state — populated at trigger time
    // from hyprctl. Used by ZenScreenshotOverlay to compute correct
    // global screen coordinates when calling grim on multi-monitor setups.
    property real screenshotRopeMonitorX: 0
    property real screenshotRopeMonitorY: 0
    property real screenshotRopeMonitorW: 0
    property real screenshotRopeMonitorH: 0

    // v6.15: Query the monitor the cursor is currently on via hyprctl
    // and store name + offset + size. grim needs GLOBAL coords across
    // all monitors, but QML selection coords are monitor-local — so we
    // add the monitor offset in captureToFile.
    //
    // Output format: name|x|y|w|h  (single pipe-separated line)
    Process {
        id: cursorMonitorQuery
        command: ["bash", "-c",
            "hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused == true) | "
            + "\"\\(.name)|\\(.x)|\\(.y)|\\(.width)|\\(.height)\"' 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const parts = (data || "").trim().split("|")
                if (parts.length >= 5 && parts[0].length > 0) {
                    root.screenshotRopeTargetMonitor = parts[0]
                    root.screenshotRopeMonitorX = parseInt(parts[1]) || 0
                    root.screenshotRopeMonitorY = parseInt(parts[2]) || 0
                    root.screenshotRopeMonitorW = parseInt(parts[3]) || 0
                    root.screenshotRopeMonitorH = parseInt(parts[4]) || 0
                }
                // Only show the overlay AFTER we know the target monitor
                if (ZenStringsState.screenshotRopeEnabled) {
                    root.screenshotRopeVisible = true
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // v6.15.10: NUCLEAR SHELL RESTART on Float/FullWidth → Island
    // v6.15.11: Fixed respawn command — Paul's actual invocation is
    //           `quickshell -p ~/.config/quickshell/zen-shell`, NOT
    //           `qs -c zen-shell` as v6.15.10 assumed. That's why
    //           v6.15.10 pkill didn't match and restart didn't fire.
    // ═══════════════════════════════════════════════════════════════════
    //
    // After v6.15.2 through v6.15.9 all attempted progressively more
    // sophisticated QML-layer workarounds for the island-mode layout
    // settling problem, none fully solve the "string commits at
    // start-menu position" bug for Float/FW → Island. The remaining
    // issue is in Quickshell/Wayland layer-shell renegotiation timing
    // that QML can't reach.
    //
    // The nuclear fix: kill + relaunch the entire shell process when
    // this specific problematic transition happens. PanelState.saveState()
    // persists the new "island" mode to JSON first, so the reborn shell
    // starts cleanly in island mode from fresh state.
    //
    // v6.15.11 respawn mechanism:
    //   1. Write a plain bash helper script to /tmp
    //      (no nested QML-string quoting = no escape bugs)
    //   2. Helper script content (Paul's exact reload pattern):
    //        pkill -f zen-shell
    //        sleep 0.2
    //        quickshell -p ~/.config/quickshell/zen-shell
    //   3. Launch via setsid -f (or nohup fallback) for full
    //      detachment from Quickshell's process tree
    //
    // Scope: ONLY triggers when prev=fullwidth|floating AND curr=island.
    // All other transitions continue using the v6.15.8+v6.15.9 QML
    // mechanisms (stable reads + forceLayout).
    //
    // Trade-off: ~500-800ms brief flicker as shell respawns. Ephemeral
    // UI state (open Settings/Control Panel/calendar popups) closes.
    // Music stream (cava) keeps running. Everything else (theme,
    // SettingsStateV2, SysRow state, bar layout, wallpaper) persists
    // via JSON state files and reloads automatically.
    //
    // Paul's explicit choice:
    //   "sige nga paki gawa option 2 haha" (forceLayout attempt)
    //   then after forceLayout didn't work:
    //   "next workaround na nuclear na shell restart option kapag once
    //   na galing sa float or full width tas switch papuntang island
    //   thats the time lang execute nuclear"
    //   then after v6.15.10 didn't fire:
    //   "hindi nag restart yung mismong qml ko pre quickshell mismo
    //   panu force restart ?"
    //   "pkill -f zen-shell; sleep 0.2; quickshell -p
    //   ~/.config/quickshell/zen-shell & pre ganito nalang"
    //
    // Also added:
    //   - Recovery timer: clears _nuclearRestartPending after 3s so if
    //     the respawn fails silently, another Float/FW → Island will
    //     trigger a fresh attempt
    //   - Console logging of every transition + nuclear match for
    //     debugging via `journalctl --user -f`
    //   - IpcHandler endpoint `testNuclearRestart` for manual testing
    property string _previousPanelMode: PanelState.panelMode
    property bool _nuclearRestartPending: false

    Timer {
        id: nuclearRestartDelay
        interval: 250  // allow PanelState.saveState() to commit
        repeat: false
        onTriggered: {
            if (typeof PanelState.saveState === "function") {
                PanelState.saveState()
            }
            console.log("[ZenShell v6.15.12] Nuclear restart triggered: "
                        + "Float/FW → Island. Dispatching respawn.")
            nuclearRestartProcess.running = true
            nuclearRestartFlagClear.restart()
        }
    }

    // v6.15.11: Recovery timer. If the restart fires successfully, the
    // shell dies before this timer can fire (so it's harmless). If the
    // restart fails silently, this clears the flag so user can try again.
    Timer {
        id: nuclearRestartFlagClear
        interval: 3000
        repeat: false
        onTriggered: {
            root._nuclearRestartPending = false
            console.log("[ZenShell v6.15.12] Nuclear flag cleared — "
                        + "if shell is still alive, respawn may have failed")
        }
    }

    // v6.15.12 respawn strategy:
    //   Invoke the pre-installed helper script at
    //   ~/.local/bin/zs-restart.sh (installed by install.sh alongside
    //   regen-swaync-theme.sh etc.). The script is specifically named
    //   WITHOUT "zen-shell" in its path because v6.15.11 had a subtle
    //   self-suicide bug:
    //
    //     v6.15.11 wrote helper to /tmp/zen-shell-nuclear-restart.sh
    //     Script's cmdline contained "zen-shell"
    //     Script ran `pkill -f zen-shell`
    //     That pattern matched the script's OWN bash process
    //     Script killed itself mid-execution
    //     → pkill fired on Quickshell, then script died before the
    //       relaunch step → no respawn → Paul reported
    //       "nung nag pkill -f zen-shell wala na hindi nag load yung
    //       sleep mo 0.2 quickshell -p ..."
    //
    //   v6.15.12 fixes:
    //     1. Helper renamed to "zs-restart.sh" — no "zen-shell" in path
    //     2. pkill pattern tightened to 'quickshell.*zen-shell' which
    //        matches ONLY quickshell invocations, not our script
    //     3. Helper installed permanently at ~/.local/bin/ via
    //        install.sh step 5 (scripts section)
    //
    //   Fallback: if the installed helper isn't present (user applied
    //   a hotfix patch without re-running install.sh), write inline
    //   copy to /tmp/zs-restart.sh — also with the safe filename.
    Process {
        id: nuclearRestartProcess
        command: ["bash", "-c",
            "SCRIPT=\"$HOME/.local/bin/zs-restart.sh\"; "
          + "if [ ! -x \"$SCRIPT\" ]; then "
                // Fallback: inline version to /tmp, safe filename
          + "    SCRIPT=/tmp/zs-restart.sh; "
          + "    cat > \"$SCRIPT\" << 'ZSREOF'\n"
          + "#!/usr/bin/env bash\n"
          + "# Zen Shell v6.15.12 fallback zs-restart helper\n"
          + "# (run install.sh for the full installed version)\n"
          + "exec >> /tmp/zs-restart.log 2>&1\n"
          + "echo \"[$(date -Iseconds)] fallback zs-restart: starting\"\n"
          + "sleep 0.3\n"
          + "pkill -f 'quickshell.*zen-shell' 2>/dev/null\n"
          + "echo \"[$(date -Iseconds)] fallback zs-restart: pkilled\"\n"
          + "sleep 0.3\n"
          + "quickshell -p \"$HOME/.config/quickshell/zen-shell\" </dev/null >/dev/null 2>&1 &\n"
          + "disown\n"
          + "echo \"[$(date -Iseconds)] fallback zs-restart: dispatched\"\n"
          + "ZSREOF\n"
          + "    chmod +x \"$SCRIPT\"; "
          + "    echo \"[ZenShell] zs-restart.sh not installed, using /tmp fallback\" >&2; "
          + "fi; "
            // Launch fully detached. setsid -f forks into new session
            // so the helper isn't a child of Quickshell's process tree.
            // Fallback to nohup + disown if setsid unavailable (rare).
          + "( setsid -f \"$SCRIPT\" </dev/null >/dev/null 2>&1 ) "
          + "|| ( nohup \"$SCRIPT\" </dev/null >/dev/null 2>&1 & disown )"
        ]
        running: false
    }

    Connections {
        target: PanelState
        function onPanelModeChanged() {
            const prev = root._previousPanelMode
            const curr = PanelState.panelMode

            console.log("[ZenShell v6.15.12] Panel mode: " + prev + " → " + curr)

            if (!root._nuclearRestartPending
                && curr === "island"
                && (prev === "fullwidth" || prev === "floating")) {
                console.log("[ZenShell v6.15.12] Nuclear trigger matched "
                            + "(prev=" + prev + ", curr=island) — scheduling restart in 250ms")
                root._nuclearRestartPending = true
                nuclearRestartDelay.restart()
            }

            root._previousPanelMode = curr
        }
    }
    // ═══════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "zen"

        function toggleStartMenu() {
            if (Hyprland.focusedMonitor) {
                const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name)
                if (screen) root.toggleStartMenuOn(screen)
            } else if (Quickshell.screens.length > 0) {
                root.toggleStartMenuOn(Quickshell.screens[0])
            }
        }
        function closeStartMenu() { root.closeStartMenu() }

        function toggleWallpaperPicker() {
            root.wallpaperPickerVisible = !root.wallpaperPickerVisible
        }
        function randomWallpaper() { WallpaperServiceV5.randomWallpaper() }
        function refreshWallpapers() { WallpaperServiceV5.refresh() }

        function toggleSettings() { root.settingsVisible = !root.settingsVisible }
        function closeSettings() { root.settingsVisible = false }

        function reloadThemeFromFile() {
            ThemeService.reload()
            // v6.15.6: Defensively re-assert user's SettingsStateV2 values
            // to Hyprland after theme reload. Paul reported snap gaps
            // (and general gaps/border) getting wiped after theme change.
            // Theme apply itself doesn't write Hyprland keywords, but
            // various downstream effects (terminal themer, swaync reload,
            // external hypr-control-center watchers) can cascade into
            // hyprctl reloads that drop user state back to hyprland.conf
            // defaults. Re-calling applyToHyprland here guarantees user
            // config survives any theme-related reload.
            Qt.callLater(SettingsStateV2.applyToHyprland)
        }

        // v6.15.11: Manual test trigger for the nuclear restart mechanism.
        // Usage: qs -c zen-shell ipc call zen testNuclearRestart
        //    or: quickshell -p ~/.config/quickshell/zen-shell ipc call zen testNuclearRestart
        // If respawn works, you'll see a brief flicker then fresh shell.
        // Check /tmp/zs-restart.log for diagnostics.
        function testNuclearRestart() {
            console.log("[ZenShell v6.15.12] Manual nuclear restart requested via IPC")
            if (typeof PanelState.saveState === "function") {
                PanelState.saveState()
            }
            root._nuclearRestartPending = true
            nuclearRestartProcess.running = true
            nuclearRestartFlagClear.restart()
        }
        function refreshThemeList() { ThemeService.refreshThemeList() }

        function toggleControlCenter() { root.controlPanelVisible = !root.controlPanelVisible }
        function closeControlCenter() { root.controlPanelVisible = false }
        function toggleCalendar() { root.calendarVisible = !root.calendarVisible }
        function closeCalendar() { root.calendarVisible = false }
        function toggleKeybindCheatsheet() { root.keybindCheatsheetVisible = !root.keybindCheatsheetVisible }
        function reloadTheme(schemeName: string) { Theme.loadScheme(schemeName) }
        function cycleTheme() { Theme.cycleTheme() }
        function toggleStyle() { Theme.toggleStyle() }

        function powerShutdown() { root.triggerPowerAction("shutdown", "systemctl poweroff") }
        function powerReboot()   { root.triggerPowerAction("reboot", "systemctl reboot") }
        function powerLogout()   { root.triggerPowerAction("logout", "hyprctl dispatch exit") }
        function powerLock()     { root.triggerPowerAction("lock", "hyprlock") }

        // v6.15: Screenshot rope overlay
        // Triggers cursor-monitor query → Process stdout handler sets
        // screenshotRopeTargetMonitor + shows the overlay on that monitor
        function zenScreenshotRope() {
            if (!ZenStringsState.screenshotRopeEnabled) return
            // Re-run query every time so cursor-follow is live
            cursorMonitorQuery.running = false
            cursorMonitorQuery.running = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // BOTTOM BAR — PanelState mode-aware margins
    //
    // v6.3 fix: "island" mode is now truly responsive — width hugs the
    // Bar's natural content width (via bar.implicitWidth) instead of
    // forcing full-screen minus margins. So kung konti lang laman, konti
    // lang yung island; kung marami, lumalaki siya.
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            // v6.11b: Bar display target — show on all, primary only, or specific monitor
            // "primary" now means screens[0] (first/main monitor), NOT focusedMonitor
            // This prevents the bar from disappearing when cursor moves to another screen
            visible: {
                const target = PanelState.barTargetDisplay
                if (target === "all") return true
                if (target === "primary") {
                    return Quickshell.screens[0] === modelData
                }
                // Specific monitor name
                return modelData.name === target
            }

            anchors.bottom: true

            // Horizontal anchoring:
            //   fullwidth → anchored left+right (stretch)
            //   floating  → anchored left+right (stretch, but with margins)
            //   island    → NOT anchored horizontally (centered, hug-width)
            anchors.left: PanelState.panelMode !== "island"
            anchors.right: PanelState.panelMode !== "island"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "zen-shell-bar"

            // Original height — unchanged
            implicitHeight: PanelState.barHeight + PanelState.panelMarginBottom

            // Width strategy per mode:
            //   fullwidth → 0 (auto-stretch via anchors.left+right)
            //   floating  → 0 (ALSO auto-stretch; anchors.left+right with
            //               margins.left/right do the work. Previously we
            //               tried `screen.width - 2*margin` but that fought
            //               with the anchors and caused right-side clipping.)
            //   island    → hug Bar.contentImplicitWidth + inner pad;
            //               clamped to [400, screen - 2*margin].
            implicitWidth: {
                if (PanelState.panelMode === "fullwidth") return 0
                if (PanelState.panelMode === "floating") return 0
                // island: hug content.
                const minW = 400
                const maxW = modelData.width - (PanelState.panelMarginSide * 2)
                const innerPad = 16
                const desired = bar.contentImplicitWidth + innerPad
                return Math.max(minW, Math.min(maxW, desired))
            }

            color: "transparent"

            margins.bottom: PanelState.panelMarginBottom
            margins.left: PanelState.panelMode === "fullwidth" ? 0
                          : (PanelState.panelMode === "floating" ? PanelState.panelMarginSide : 0)
            margins.right: PanelState.panelMode === "fullwidth" ? 0
                           : (PanelState.panelMode === "floating" ? PanelState.panelMarginSide : 0)

            // Bar fills its parent window in ALL modes. The window itself
            // is sized per-mode above (0 for fullwidth, computed for
            // floating/island). Using anchors.fill is the simple, correct
            // way to let the bar's internal RowLayout stretch to the full
            // width of whatever window it lives in.
            Bar {
                id: bar
                anchors.fill: parent
                anchors.margins: PanelState.panelMode === "fullwidth" ? 3 : 0
            }

            // Publish the bar window's left edge in screen coords so
            // the floating strings overlay can align correctly in
            // island and floating modes.
            //   fullwidth → 0
            //   floating  → panelMarginSide
            //   island    → (screenW - islandWidth) / 2
            function _publishBarLeft() {
                if (PanelState.panelMode === "fullwidth") {
                    ZenStringsState.barWindowLeft = 0
                } else if (PanelState.panelMode === "floating") {
                    ZenStringsState.barWindowLeft = PanelState.panelMarginSide
                } else {
                    // island: centered
                    const islandW = barWindow.implicitWidth
                    const screenW = modelData.width
                    ZenStringsState.barWindowLeft = Math.max(0, (screenW - islandW) / 2)
                }
            }
            onImplicitWidthChanged: _publishBarLeft()
            Component.onCompleted: _publishBarLeft()
            Connections {
                target: PanelState
                function onPanelModeChanged() { barWindow._publishBarLeft() }
            }

            // ZenStrings moved out of barWindow to a floating PanelWindow
            // below — barWindow is a Wayland layer-shell surface with fixed
            // height, so curves that bow above/below the bar were getting
            // hard-clipped by Wayland (clip:false couldn't help). The
            // dedicated overlay window below has extra vertical headroom.
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ZEN STRINGS — FLOATING OVERLAY
    //
    // Separate WlrLayer.Overlay surface per screen, positioned over the
    // music slot. Extra vertical padding (curveHeight each side) so the
    // beat-reactive curves can bow ABOVE and BELOW the bar slot without
    // being clipped by the bar window's height.
    //
    // exclusionMode: Ignore — doesn't push content or steal space.
    // Position:
    //   x = barWindow.margins.left + musicSlotLocalX
    //   anchored to bottom, with height = barHeight + 2*padding
    //   margins.bottom = panelMarginBottom - padding  (string overflows
    //                                                  below bar edge too)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: stringsWindow
            required property var modelData
            screen: modelData

            // Only show on the monitor(s) where the bar is shown
            property bool isBarMonitor: {
                const target = PanelState.barTargetDisplay
                if (target === "all") return true
                if (target === "primary") return Quickshell.screens[0] === modelData
                return modelData.name === target
            }

            // v6.15.1: Don't show strings until bar is fully laid out.
            // ...
            //
            // v6.15.2: stability-based readiness (600ms no changes).
            // v6.15.3: added 4s absolute max-wait fuse.
            //
            // v6.15.4: Max-wait bumped to 15s AND guarded by a bar-width
            // sanity check. The 4s fuse was firing with the wrong
            // position committed — symptom: string shows at far-left
            // until user hovers a bar module, then snaps to correct
            // position. Root cause is a Wayland layer-shell negotiation
            // delay combined with a QML layout recompute that doesn't
            // happen without user input (see Bar.qml v6.15.4 for the
            // layoutNudger fix on the producer side). Giving the system
            // 15s plus the layoutNudger's forced recomputes means
            // positionReady fires only after the position is genuinely
            // correct. The sanity gate also refuses to fire ready if
            // the position still looks like a pre-layout default
            // (musicSlotLocalX < 20, which no sensible music-slot
            // position will ever be — the bar has 8px left padding
            // and start button is ~60px wide).
            property bool positionReady: false

            Timer {
                id: stringsStabilityTimer
                interval: 600
                repeat: false
                onTriggered: stringsWindow._tryMarkReady(false)
            }

            // v6.15.4: 15s hard timeout. If we get here, just show the
            // strings at whatever position is current — the user has
            // been staring at a Loading placeholder for way too long.
            Timer {
                id: stringsMaxWaitTimer
                interval: 15000
                repeat: false
                running: true
                onTriggered: stringsWindow._tryMarkReady(true)
            }

            function _tryMarkReady(force) {
                // Sanity gate: don't commit if position still looks
                // pre-layout. Must be at least past the start-button
                // zone to count as real. If forced (max-wait), skip
                // the gate so we don't hang on Loading forever in
                // pathological setups.
                if (!force && ZenStringsState.musicSlotLocalX < 20) {
                    stringsStabilityTimer.restart()
                    return
                }
                stringsWindow.positionReady = true
                ZenStringsState.positionReady = true
                stringsStabilityTimer.stop()
                stringsMaxWaitTimer.stop()
            }

            visible: isBarMonitor
                     && ZenStringsState.enabled
                     && ZenStringsState.musicSlotLocalX >= 0
                     && ZenStringsState.musicSlotLocalWidth > 10
                     && positionReady

            function _onPosChanged() {
                // Once ready, stay ready — margin bindings follow smoothly
                if (stringsWindow.positionReady) return
                // Pre-ready: restart stability countdown
                stringsStabilityTimer.restart()
            }

            Connections {
                target: ZenStringsState
                function onMusicSlotLocalXChanged()     { stringsWindow._onPosChanged() }
                function onMusicSlotLocalWidthChanged() { stringsWindow._onPosChanged() }
                // v6.15.7: Also restart stability on barWindowLeft changes.
                // During panel mode transitions, barWindow._publishBarLeft
                // updates this asynchronously via its own panelModeChanged
                // Connection. If we don't watch it here, stability can fire
                // after musicSlotLocalX settles but BEFORE barWindowLeft
                // has updated — producing a brief margins.left = stale_offset
                // + new_x = wrong position. Watching it means stability waits
                // for ALL geometry to settle, not just musicSlotLocalX.
                function onBarWindowLeftChanged()       { stringsWindow._onPosChanged() }
                function onEnabledChanged() {
                    if (ZenStringsState.enabled) {
                        stringsWindow.positionReady = false
                        ZenStringsState.positionReady = false
                        stringsStabilityTimer.restart()
                        stringsMaxWaitTimer.restart()
                    }
                }
                function onStringLengthChanged() {
                    stringsWindow.positionReady = false
                    ZenStringsState.positionReady = false
                    stringsStabilityTimer.restart()
                    stringsMaxWaitTimer.restart()
                }
            }

            // v6.15.6: Panel mode transition handling. When user switches
            // between fullwidth / floating / island via PanelPage, EVERY
            // coordinate involved changes simultaneously but asynchronously:
            //   - barLeftOffset (below, this file)
            //   - ZenStringsState.barWindowLeft (_publishBarLeft on barWindow)
            //   - ZenStringsState.musicSlotLocalX (Bar.qml re-read)
            // v6.15.5 added Behavior animations on margins.left/implicitWidth,
            // which tried to animate SMOOTHLY through those inconsistent
            // intermediate states — producing the "loko-loko" flight across
            // the screen Paul reported (v6.15.6 video).
            //
            // Fix: treat a panel-mode change exactly like login. Reset
            // positionReady → stringsWindow becomes invisible, MusicStrings
            // Loading placeholder shows in the bar slot at its new (correct
            // via RowLayout) position. Bar.qml's own panelModeChanged
            // handler (mirrors this) kicks layoutNudger + safetyPoll to
            // force fresh position reads. When stability re-fires after the
            // bar has settled in its new mode, positionReady flips back to
            // true and strings appear at the correct new position without
            // any sweeping animation.
            //
            // Also: invalidate the current musicSlotLocalX so the sanity
            // gate in _tryMarkReady refuses to commit until Bar.qml reports
            // a fresh value — ensures we never reuse stale coordinates.
            Connections {
                target: PanelState
                function onPanelModeChanged() {
                    stringsWindow.positionReady = false
                    ZenStringsState.positionReady = false
                    // Invalidate so sanity gate waits for a fresh read
                    ZenStringsState.musicSlotLocalX = -1
                    stringsStabilityTimer.restart()
                    stringsMaxWaitTimer.restart()
                }
            }

            Component.onCompleted: {
                ZenStringsState.positionReady = false
                stringsStabilityTimer.restart()
            }

            // Vertical padding — how much the string is allowed to bow
            // above AND below the bar slot.
            readonly property int vPad: ZenStringsState.verticalPadding > 0
                ? ZenStringsState.verticalPadding
                : ZenStringsState.curveHeight

            // Bar's horizontal offset from screen edge (for island/floating)
            // Mirrors the logic used by barWindow itself so we stay aligned
            // no matter the panel mode.
            readonly property int barLeftOffset: {
                if (PanelState.panelMode === "fullwidth") return 0
                if (PanelState.panelMode === "floating")  return PanelState.panelMarginSide
                // island: bar is centered with hug-content width.
                // Recompute barWindow.implicitWidth identically:
                const minW = 400
                const maxW = modelData.width - (PanelState.panelMarginSide * 2)
                const innerPad = 16
                // bar.contentImplicitWidth isn't accessible from here, but
                // barWindowLeft is written by barWindow itself via a
                // Connections below. Use it when available; else fall back
                // to marginSide (visually close for most module layouts).
                if (ZenStringsState.barWindowLeft > 0) {
                    return ZenStringsState.barWindowLeft
                }
                return PanelState.panelMarginSide
            }

            anchors.bottom: true
            anchors.left: true

            // v6.15.1: Changed from Overlay → Top so strings hide
            // together with the bar when a window goes fullscreen.
            // WlrLayer.Overlay stays visible over fullscreen windows.
            // Strings render on top of bar because they're mapped after
            // barWindow in the QML tree (later map = higher z within layer).
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "zen-shell-strings"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // Horizontal: match music slot's screen X
            margins.left: barLeftOffset + ZenStringsState.musicSlotLocalX

            // v6.15.5: Smooth animation on margin/width changes so runtime
            // layout shifts (tray expand, taskbar app open/close, etc.) glide
            // into place instead of "snap after 40-60ms". The delay is
            // physically unavoidable — posTimer debounce (16ms) + one event
            // loop tick + Wayland layer-shell margin round-trip. Animating
            // over 180ms turns that visible hitch into a smooth slide.
            //
            // Guarded by `enabled: positionReady` so the INITIAL placement
            // (from default -1 → real position on login) doesn't animate
            // across the whole screen — only runtime adjustments do.
            //
            // Wayland traffic cost: ~11 margin updates over 180ms per
            // animation. Acceptable because Bar.qml's 2px write threshold
            // prevents animations from firing on sub-pixel jitter (clock
            // ticks, badge width shifts). Only genuine layout changes
            // (20px+ deltas) trigger animation.
            Behavior on margins.left {
                enabled: stringsWindow.positionReady
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Vertical: sit over the bar, extending vPad above and below
            // barWindow is anchored to screen bottom with margin panelMarginBottom.
            // Strings window bottom edge = panelMarginBottom - vPad
            // (so the string extends vPad BELOW the bar's bottom edge too,
            //  which is fine because exclusionMode is Ignore).
            margins.bottom: Math.max(0, PanelState.panelMarginBottom - vPad)

            implicitWidth: ZenStringsState.musicSlotLocalWidth
            implicitHeight: PanelState.barHeight + vPad * 2

            // v6.15.5: Same smooth-transition treatment for width changes
            // (e.g. user resizes stringLength via settings, or a future
            // feature dynamically resizes the music slot).
            Behavior on implicitWidth {
                enabled: stringsWindow.positionReady
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            ZenStrings {
                anchors.fill: parent

                // v6.15.1: Fade in when position is ready
                opacity: stringsWindow.positionReady ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                // slotCenterY: middle of the actual bar within this
                // taller window. Account for the fact that margins.bottom
                // may have been clamped to 0 (when vPad > panelMarginBottom),
                // which shifts the bar's apparent position within our window.
                //
                // Window's bottom edge is at:
                //   screenBottom - actualMarginBottom
                // Bar's bottom edge is at:
                //   screenBottom - panelMarginBottom
                // So bar bottom within this window is:
                //   windowHeight - (panelMarginBottom - actualMarginBottom)
                //        = (barHeight + 2*vPad) - (panelMarginBottom - margins.bottom)
                // Bar center Y = bar bottom - barHeight/2
                slotCenterY: {
                    const actualBottomMargin = stringsWindow.margins.bottom
                    const barBottomInWindow = stringsWindow.implicitHeight
                        - (PanelState.panelMarginBottom - actualBottomMargin)
                    return barBottomInWindow - PanelState.barHeight / 2
                }
                isAudioActive: ZenStringsState.isAudioActive
                cavaData: ZenStringsState.cavaData
            }

            // v6.15.1: Hover tooltip on the stringsWindow itself.
            // The visible strings float in this PanelWindow — hovering
            // the bar's MusicStrings slot doesn't work because the
            // stringsWindow covers it. So tooltip lives here.
            MouseArea {
                id: stringsHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // v6.15.4: Tooltip anchor at the BAR's top edge within
            // this stringsWindow. Previous version anchored the
            // PopupWindow to stringsWindow.contentItem (the full
            // overlay, 60px above bar due to vPad). Result: tooltip
            // floated ~60px above the bar with a big empty gap —
            // inconsistent with SysRow tooltips that anchor snugly
            // to the bar edge. This invisible 1px-tall Item sits at
            // the bar's actual top edge, so PopupWindow anchored to
            // its Top shows directly above the bar, matching
            // SysRowIcon's tooltip positioning.
            Item {
                id: barTopAnchor
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(10, ZenStringsState.musicSlotLocalWidth)
                height: 1
                // Y = where the bar's TOP edge sits inside stringsWindow.
                // stringsWindow height = barHeight + 2*vPad.
                // Bar is anchored to screen-bottom with margin
                // panelMarginBottom; stringsWindow bottom-margin may have
                // been clamped to 0 when vPad > panelMarginBottom.
                // Bar's bottom-in-window = stringsWindow.implicitHeight
                //                         - (panelMarginBottom - margins.bottom)
                // Bar's top-in-window    = bar's bottom-in-window - barHeight
                y: {
                    const actualBottomMargin = stringsWindow.margins.bottom
                    const barBottomInWindow = stringsWindow.implicitHeight
                        - (PanelState.panelMarginBottom - actualBottomMargin)
                    return barBottomInWindow - PanelState.barHeight
                }
            }

            PopupWindow {
                anchor.item: barTopAnchor
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Top
                visible: stringsHover.containsMouse
                         && ZenStringsState.trackInfo.length > 0
                width: stTipText.implicitWidth + stTipDot.width + stTipRow.spacing + 28
                height: stTipRow.implicitHeight + 18
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.95)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                    Row {
                        id: stTipRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            id: stTipDot
                            width: 7; height: 7; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: ZenStringsState.mediaPlaying ? ThemeService.green
                                 : ZenStringsState.cavaHasAudio ? ThemeService.orange
                                 : ThemeService.grey1
                        }

                        Text {
                            id: stTipText
                            text: ZenStringsState.trackInfo
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: ThemeService.fg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }


    // ═══════════════════════════════════════════════════════════════
    // START MENU
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: startMenuWindow
            required property var modelData
            screen: modelData

            visible: root.startMenuScreen === modelData

            anchors.bottom: true
            anchors.left: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-startmenu"
            exclusionMode: ExclusionMode.Ignore

            implicitWidth: 720
            implicitHeight: 600
            color: "transparent"

            // v6.9: Align start menu LEFT EDGE with start button LEFT EDGE
            // (not centered — user expects menu to open directly from the button)
            margins.left: {
                const btnX = PanelState.startButtonCenterX
                if (btnX < 0) return 8  // no report yet
                const w = startMenuWindow.implicitWidth
                const screenW = modelData.width
                // btnX is button CENTER — subtract half button width to get LEFT edge
                const btnHalfW = (Theme.moduleHeight + 4) / 2  // StartMenu button width/2
                const desired = btnX - btnHalfW
                const maxLeft = screenW - w - 8
                return Math.max(8, Math.min(maxLeft, desired))
            }
            margins.bottom: PanelState.barHeight + 8 + PanelState.panelMarginBottom

            HyprlandFocusGrab {
                active: startMenuWindow.visible
                windows: [startMenuWindow]
                onCleared: {
                    if (root.startMenuScreen === modelData) root.startMenuScreen = null
                }
            }

            StartMenuPanel {
                anchors.fill: parent
                visible: startMenuWindow.visible
                onCloseRequested: root.closeStartMenu()
                onAppLaunched: root.closeStartMenu()
                onPowerActionRequested: (action, command) => root.triggerPowerAction(action, command)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // WALLPAPER PICKER (legacy)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wpWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.wallpaperPickerVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: wpWindow.visible
                windows: [wpWindow]
                onCleared: root.wallpaperPickerVisible = false
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.wallpaperPickerVisible = false
                }
            }

            WallpaperPicker {
                anchors.centerIn: parent
                width: Math.min(1100, parent.width - 80)
                height: Math.min(720, parent.height - 80)
                visible: wpWindow.visible
                onCloseRequested: root.wallpaperPickerVisible = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SETTINGS WINDOW — draggable, no auto-close on click-outside
    // v6.13: Panel stays open until explicitly closed (X btn / Super+,)
    // Draggable via title bar (top 48px). No dim background.
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: settingsWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.settingsVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-settings"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // v6.13 fix: Removed HyprlandFocusGrab AND backdrop MouseArea.
            // The panel no longer closes on click-outside — only via:
            //   1. The X close button inside ZenSettings
            //   2. Super+, toggle (same keybind that opens it)
            //   3. Esc key
            // This matches desktop app behavior (settings stays open until
            // explicitly closed). Panel is also now draggable.

            // v6.13: No backdrop MouseArea — panel doesn't close on click-outside
            // and the backdrop was blocking drag events on the settings panel.
            // Desktop clicks pass through the transparent PanelWindow naturally.

            ZenSettings {
                id: zenSettingsPanel
                width: root.settingsFullscreen ? parent.width : Math.min(1100, parent.width - 80)
                height: root.settingsFullscreen ? parent.height : Math.min(740, parent.height - 80)
                visible: settingsWindow.visible
                isFullscreen: root.settingsFullscreen
                onCloseRequested: root.settingsVisible = false
                onToggleFullscreen: root.settingsFullscreen = !root.settingsFullscreen

                // Center by default — anchors.centerIn is the most reliable
                // centering method in QML. Gets cleared when drag starts
                // (hasBeenDragged is set true by drag MouseArea inside ZenSettings).
                anchors.centerIn: (!root.settingsFullscreen && !hasBeenDragged) ? parent : undefined
                anchors.fill: root.settingsFullscreen ? parent : undefined

                // Reset drag state when panel reopens or leaves fullscreen
                onVisibleChanged: if (visible) hasBeenDragged = false
                onIsFullscreenChanged: hasBeenDragged = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // POWER CONFIRM
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: powerWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.powerConfirmVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-powerconfirm"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: powerWindow.visible
                windows: [powerWindow]
                onCleared: root.powerConfirmVisible = false
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.7)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.powerConfirmVisible = false
                }
            }

            PowerConfirmDialog {
                anchors.centerIn: parent
                width: 420
                height: 480
                visible: powerWindow.visible
                action: root.powerAction
                command: root.powerCommand
                countdown: 60

                onConfirmed: root.powerConfirmVisible = false
                onCancelled: root.powerConfirmVisible = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CONTROL PANEL — Quick Settings popup (Super+C)
    // v6.13: Draggable, no auto-close, expand arrow for details.
    // Real system icons — WiFi/BT/Audio from ConnectivityService,
    // CPU/GPU/RAM from SystemMonitorService.
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: controlPanelWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.controlPanelVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-controlpanel"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // v6.16.0.2: Added click-outside-to-close backdrop.
            // Without this, the whole screen was blocked because the
            // PanelWindow spans top/bottom/left/right as an Overlay.
            // Paul reported not being able to click desktop until he
            // pressed ✕.
            //
            // Pattern: a MouseArea below the ControlPanel instance in
            // z-order. ControlPanel + its children handle their own
            // clicks first (natural QML stacking — later siblings are
            // above earlier ones). Any click that reaches this area is
            // by definition outside ControlPanel → close.
            //
            // Right-click also closes (match macOS Control Center UX).
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                enabled: controlPanelWindow.visible
                onPressed: {
                    // Reaching this handler means click missed all
                    // child MouseAreas inside ControlPanel → outside
                    root.controlPanelVisible = false
                }
            }

            ControlPanel {
                id: controlPanelInstance
                visible: controlPanelWindow.visible
                onCloseRequested: root.controlPanelVisible = false

                // Center by default, break anchor on drag
                anchors.centerIn: (!hasBeenDragged) ? parent : undefined

                onVisibleChanged: if (visible) {
                    hasBeenDragged = false
                    expanded = false
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SYSROW TOOLTIP — v6.14: REMOVED
    // Tooltip is now a PopupWindow inside each SysRowIcon.qml,
    // using anchor.item (same as Taskbar.qml). No manual coordinate
    // math needed — Quickshell handles positioning automatically.
    // Old PanelWindow approach broke in floating/island bar modes.
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // CALENDAR — Click clock in bar to toggle
    // v6.13: Separate overlay window so calendar renders above bar
    // without PanelWindow clipping. Positioned bottom-right, just
    // above the bar.
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: calendarWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.calendarVisible && isFocusedMonitor

            anchors.bottom: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-calendar"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            implicitWidth: 300
            implicitHeight: 340

            margins.bottom: PanelState.barHeight + 12 + PanelState.panelMarginBottom
            margins.right: 12

            HyprlandFocusGrab {
                active: calendarWindow.visible
                windows: [calendarWindow]
                onCleared: root.calendarVisible = false
            }

            ZenCalendar {
                anchors.fill: parent
                visible: calendarWindow.visible

                onVisibleChanged: {
                    if (visible) {
                        viewYear = new Date().getFullYear()
                        viewMonth = new Date().getMonth()
                    }
                }

                onCloseRequested: root.calendarVisible = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // KEYBIND CHEATSHEET — Super+/ or Super+F2
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: keybindWindow
            required property var modelData
            screen: modelData

            property bool isFocusedMonitor: {
                if (!Hyprland.focusedMonitor) return Quickshell.screens[0] === modelData
                return Hyprland.focusedMonitor.name === modelData.name
            }

            visible: root.keybindCheatsheetVisible && isFocusedMonitor

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-keybinds"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: keybindWindow.visible
                windows: [keybindWindow]
                onCleared: root.keybindCheatsheetVisible = false
            }

            KeybindCheatsheet {
                anchors.fill: parent
                visible: keybindWindow.visible
                onCloseRequested: root.keybindCheatsheetVisible = false
                Component.onCompleted: if (visible) show()
                onVisibleChanged: if (visible) show()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // DESKTOP WIDGETS — transparent overlay on BOTTOM layer
    // v6.12 fix: Changed from Background → Bottom layer. Background
    // sits BEHIND the wallpaper (swww/swaybg), making widgets invisible.
    // Bottom sits above wallpaper but below all application windows.
    // Reads enable/disable from widgets-state.json (WidgetsPage).
    // v6.11b: "primary" = screens[0] (fixed monitor, not cursor-follow)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: widgetWindow
            required property var modelData
            screen: modelData

            // v6.11b: "primary" means first screen always — NOT focusedMonitor
            // This prevents widgets from disappearing when cursor moves
            visible: dwInstance.widgetDisplay === "all" ? true : (Quickshell.screens[0] === modelData)

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "zen-shell-widgets"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            DesktopWidgets {
                id: dwInstance
                anchors.fill: parent
            }
        }
    }


    // ═══════════════════════════════════════════════════════════════
    // SCREENSHOT ROPE OVERLAY — v6.14.2 PROTOTYPE
    // Fullscreen overlay with physics rope strings from corners.
    // Triggered via IPC: `qs msg -i zen -f zenScreenshotRope`
    // Only if ZenStringsState.screenshotRopeEnabled = true.
    //
    // v6.15: Monitor targeting now queries `hyprctl monitors` at trigger
    // time (cursorMonitorQuery Process) to reliably pick the monitor
    // where the cursor currently is, instead of a stale focusedMonitor
    // binding.
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: screenshotRopeWindow
            required property var modelData
            screen: modelData

            // Target monitor = the one where the cursor was at trigger
            // time. Fallback: the focused monitor; final fallback: first.
            property bool isTargetMonitor: {
                const tgt = root.screenshotRopeTargetMonitor
                if (tgt && tgt.length > 0) {
                    return modelData.name === tgt
                }
                if (Hyprland.focusedMonitor) {
                    return Hyprland.focusedMonitor.name === modelData.name
                }
                return Quickshell.screens[0] === modelData
            }

            // v6.15: overlay can ask to temporarily hide the whole
            // PanelWindow during capture so the rope + annotations
            // don't get included in the screenshot. The compositor
            // needs a frame or two to actually remove the layer,
            // which is why ZenScreenshotOverlay has a 150ms delay
            // between hideWindowRequested() and the grim call.
            property bool captureInProgress: false
            visible: root.screenshotRopeVisible && isTargetMonitor && !captureInProgress

            // Reset captureInProgress whenever a new screenshot session
            // starts (screenshotRopeVisible goes true). Without this,
            // the second Super+Shift+S after a successful capture would
            // find captureInProgress still true from the previous run
            // and the overlay would never become visible.
            Connections {
                target: root
                function onScreenshotRopeVisibleChanged() {
                    if (root.screenshotRopeVisible) {
                        screenshotRopeWindow.captureInProgress = false
                    }
                }
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zen-shell-screenshot-rope"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            HyprlandFocusGrab {
                active: screenshotRopeWindow.visible
                windows: [screenshotRopeWindow]
                onCleared: root.screenshotRopeVisible = false
            }

            ZenScreenshotOverlay {
                anchors.fill: parent
                visible: screenshotRopeWindow.visible
                // Pass monitor offset so grim gets global coords
                monitorOffsetX: root.screenshotRopeMonitorX
                monitorOffsetY: root.screenshotRopeMonitorY
                onCaptureComplete: root.screenshotRopeVisible = false
                onCaptureCancelled: root.screenshotRopeVisible = false
                onHideWindowRequested: screenshotRopeWindow.captureInProgress = true
                onShowWindowRequested: screenshotRopeWindow.captureInProgress = false
            }
        }
    }
}
