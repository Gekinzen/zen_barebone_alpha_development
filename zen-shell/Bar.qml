import QtQuick
import QtQuick.Layouts

/*
 * Bar.qml v6.16.0.2
 *
 * v6.16.0: Added Battery module. Registered as "battery" in the
 *   barLayout map. Hides itself automatically on desktops (when
 *   no /sys/class/power_supply/BAT* exists) so the same layout
 *   config works on laptops AND desktops without branching.
 *   Three display modes via SettingsStateV2.batteryDisplayMode:
 *   icon (default) | text | bar.
 *
 * v6.16.0.1 HOTFIX: Battery.qml Rectangle popup (was ToolTip which
 *   needs QtQuick.Controls not available in Quickshell).
 *
 * v6.16.0.2: PanelState migration — upgraders with existing
 *   panel-state.json now get "battery" auto-injected into barLayout.right
 *   on first load (was only taking effect on fresh installs before).
 *
 * v6.15: music module now toggleable as ZenStrings.
 *   - cMusic component: kapag ZenStringsState.enabled → loads MusicStrings
 *     otherwise → loads normal MusicWidget (unchanged)
 *   - No other modules affected. Wala tayong babawasan.
 *
 * (v6.15.x history — see CHANGELOG files)
 *
 * v6.15.4 FIXES POSITION-STUCK-UNTIL-INTERACTION:
 *   Symptom: on login, Loading placeholder resolves correctly but
 *   ZenStrings renders at wrong slot position (typically far left).
 *   Only fixes itself once the user hovers ANY bar module or clicks
 *   anything in the bar.
 *
 *   Root cause: on login, the Wayland layer-shell surface
 *   (barWindow) negotiates its final geometry asynchronously with
 *   the compositor. QML's initial layout pass happens before
 *   negotiation completes; when the surface resizes, Qt should
 *   re-run the parent RowLayout, but in some cases it caches stale
 *   positions for right-anchored children (rightRow). User input
 *   events cause QML binding re-evaluation that forces the layout
 *   recompute — that's why hovering fixes it.
 *
 *   Three-pronged fix:
 *     1. Parent-chain walk replaces mapToItem. mapToItem reads from
 *        the scene graph, which caches transforms and can return
 *        stale coordinates even when QML properties are fresh. Walking
 *        up .parent.x values reads property state directly.
 *     2. layoutNudger Timer toggles musicSlotItem.Layout.preferredWidth
 *        by 0.1px every 250ms for the first 30 seconds after bar
 *        creation. This forces RowLayout to recompute child positions
 *        on each tick — the same kind of recompute that hovering
 *        produces, but automatic.
 *     3. safetyPoll reverted to forever-running (v6.15.3 stopped it
 *        after positionReady — wrong, because the layout could
 *        un-stick later). Tiered interval: 100ms for the first 3s
 *        (aggressive catch-up), then 500ms steady-state.
 *
 *   Also bar.width < 100 guard — prevents writing pre-negotiation
 *   positions which would be nonsense.
 */
Rectangle {
    id: barRoot
    // v8.0.0-alpha-hf112: the look writes Theme.barRadius as a preset; the
    // slider owns it afterwards. No render-time override.
    radius: Theme.styleMode === "round" ? 22 : Theme.barRadius

    readonly property int contentImplicitWidth: {
        const lw = leftRow.implicitWidth
        const cw = centerRow.implicitWidth
        const rw = rightRow.implicitWidth
        const spacer = (cw > 0 ? 48 : 24) * 2
        return lw + cw + rw + spacer + 16
    }

    // v7.0.0-beta.1-hf83: natural height of the bar's contents — the
    // tallest of the three module zones. PanelState.barAutoHeight uses
    // this (via the bar window's implicitHeight in shell.qml) to hug
    // the bar to its contents instead of a fixed pixel height. Each
    // zone's implicitHeight already reflects max(child preferredHeight)
    // thanks to the per-Loader Layout.preferredHeight forwarding added
    // in v6.16.4.12.6.51. Clamped to a sane floor so an empty bar (all
    // zones 0) doesn't collapse to nothing during first layout.
    readonly property int contentImplicitHeight: {
        const lh = leftRow.implicitHeight
        const ch = centerRow.implicitHeight
        const rh = rightRow.implicitHeight
        return Math.max(20, lh, ch, rh)
    }

    // v8.0.0-alpha-hf147 — clear look: one frosted white body, no border.
    // Any other look: the caller's own value, unchanged.
    color: LookService.bodyColor((function() {
        if (PanelState.bgOverrideEnabled) {
            return Qt.rgba(
                PanelState.bgOverrideColor.r,
                PanelState.bgOverrideColor.g,
                PanelState.bgOverrideColor.b,
                PanelState.bgOverrideOpacity
            )
        }
        return Qt.rgba(
            ThemeService.bg0.r,
            ThemeService.bg0.g,
            ThemeService.bg0.b,
            Theme.barOpacity
        )
    })())

    border.width: LookService.bodyBorderWidth(PanelState.borderEnabled ? PanelState.borderWidth : 0)
    border.color: LookService.bodyBorderColor(PanelState.borderColor)

    // ── Module factory ──
    Component { id: cStartMenu;   StartMenu {} }
    Component { id: cTaskbar;     Taskbar {} }
    Component { id: cWorkspaces;  Workspaces {} }
    Component { id: cWindowTitle; WindowTitle {} }
    Component { id: cSysRow;      SysRow {} }
    Component { id: cTray;        SystemTray {} }
    Component { id: cNotif;       NotificationIcon {} }
    // v6.16.4.12.6.51 (Hikari): cClock and cCalendar are now the SAME
    // component. Clock.qml is a fork of CalendarButton.qml with a live
    // time display in place of the static date label, plus right-click
    // format-cycle and scroll-wheel month navigation. Both barLayout
    // tokens "clock" and "calendar" resolve to the same module so
    // existing user layouts keep working without migration.
    Component { id: cClock;       Clock {} }
    Component { id: cWeather;     ZenWeather {} }
    Component { id: cSysMonitor;  ZenSysMonitor {} }
    // v7.0.0-alpha.6: clipboard module
    Component { id: cClipboard;   ClipboardModule {} }
    // v6.16.0: Battery module (hides itself on desktops)
    Component { id: cBattery;     Battery {} }
    // v6.16.3.4: Power profile + GPU mode badge.
    // Hides itself when neither powerprofilesctl nor multi-GPU
    // detection succeeds (single-GPU desktop with no PPD = invisible).
    Component { id: cPowerBadge;  PowerBadge {} }
    // v6.16.4.12.6.51 (Hikari): "calendar" now resolves to the same
    // merged Clock component as "clock" — keeping the symbol so
    // existing barLayouts that include "calendar" still work.
    Component { id: cCalendar;    Clock {} }

    // v7.0.0-alpha.13: workflow profile badge (Work/Gaming/Focus/Movie/Sleep)
    // Left-click → open Control Panel. Right-click → cycle to next profile.
    Component { id: cWorkflow;    WorkflowProfileBadge {} }

    // v7.0.0-beta.1-hf39 — five new feature modules. User opts in by
    // adding any of "quicknotes", "focusspaces", "networkpulse",
    // "smartdim", "titletranslator" to their barLayout array.
    Component { id: cQuickNotes;      QuickNotesModule {} }
    Component { id: cFocusSpaces;     FocusSpacesModule {} }
    Component { id: cNetworkPulse;    NetworkPulseModule {} }
    Component { id: cSmartDim;        SmartDimModule {} }
    Component { id: cTitleTranslator; TitleTranslatorModule {} }

    // v6.15: music slot — toggles between MusicWidget and MusicStrings
    // musicSlotLocalX / musicSlotLocalWidth: bar-local coordinates of the
    // music slot. Written to ZenStringsState by the cMusic Item.
    // shell.qml reads ZenStringsState so ZenStrings sibling can align.
    // v8.0.0-alpha-hf118: which monitor this bar is on. Set by shell.qml.
    // Only the bar on ZenStringsState.stringScreen may publish slot
    // coordinates — see the comment in ZenStringsState.
    property string screenName: ""

    property real musicSlotLocalX: -1
    property real musicSlotLocalWidth: 200

    Component {
        id: cMusic
        Item {
            id: musicSlotItem
            Layout.alignment: Qt.AlignVCenter

            implicitWidth:  innerLoader.implicitWidth  > 0 ? innerLoader.implicitWidth  : 200
            implicitHeight: innerLoader.implicitHeight > 0 ? innerLoader.implicitHeight : PanelState.barHeight

            Loader {
                id: innerLoader
                anchors.fill: parent
                // v8.0.0-alpha-hf118: strings only on the owning screen; the
                // other bars keep the plain music widget.
                source: (ZenStringsState.enabled && ZenStringsState.ownsStrings(barRoot.screenName))
                        ? "MusicStrings.qml" : "MusicWidget.qml"
            }

            // v6.15.1: Position tracking with 16ms micro-debounce.
            // Writing to ZenStringsState triggers stringsWindow margins
            // → Wayland layer surface reposition → compositor round-trip.
            // Rapid-fire signals (tray expand, workspace switch) would
            // flood this path = hang. 16ms = 1 frame at 60fps.
            // Also: only write if value actually changed (>0.5px delta).
            //
            // v6.15.2: Qt.callLater wraps the actual mapToItem read so it
            // runs AFTER the current layout pass completes — stale
            // coordinates were the main reason login positions were wrong.
            //
            // v6.15.3: Bumped write threshold from 0.5px to 2.0px. Clock
            // module ticks every 1000ms and its text implicitWidth varies
            // by ~0.5-2px between digit transitions (non-monospaced font).
            //
            // v6.15.4: Switched from mapToItem to manual parent-chain walk.
            // mapToItem() consults the scene graph, which on login can
            // return stale values until some event forces a re-sync
            // (observed: user hovering any bar module suddenly "unsticks"
            // the cached transforms). Parent-chain walk reads .x directly
            // from each QML Item up to barRoot — always returns current
            // QML state, no scene graph dependency. Also added width
            // sanity gate: don't write if bar itself hasn't sized yet
            // (prevents committing to pre-layout coordinates).
            function updatePos() {
                Qt.callLater(musicSlotItem._doUpdatePos)
            }
            function _doUpdatePos() {
                if (!musicSlotItem.parent || !barRoot) return
                // v8.0.0-alpha-hf118: single publisher. Two bars writing one
                // global bar-local coordinate is what broke fullwidth/floating.
                if (!ZenStringsState.ownsStrings(barRoot.screenName)) return
                // v6.15.4 sanity gate: bar must have a sensible width
                // before we trust any coordinate read.
                if (barRoot.width < 100) return

                // v6.15.9: Force synchronous layout pass before reading
                // positions during mode transitions. Qt's RowLayout
                // normally defers child .x updates across frames for
                // efficiency, which is the root cause of the island
                // mode "commit at start-menu position" bug — bar.width
                // stabilizes but children's .x values are still
                // propagating through the layout engine. Calling
                // forceLayout() collapses the entire layout pass into
                // a single synchronous update, so the parent-chain walk
                // immediately below always reads fully-settled values.
                //
                // We only force during transitions to avoid paying the
                // synchronous layout cost on every safetyPoll tick in
                // steady state. In steady state, layouts are already
                // settled and forceLayout would be a no-op anyway.
                if (musicSlotItem._modeTransitioning) {
                    if (barMainLayout && typeof barMainLayout.forceLayout === "function") {
                        barMainLayout.forceLayout()
                    }
                    if (leftRow && typeof leftRow.forceLayout === "function") {
                        leftRow.forceLayout()
                    }
                    if (centerRow && typeof centerRow.forceLayout === "function") {
                        centerRow.forceLayout()
                    }
                    if (rightRow && typeof rightRow.forceLayout === "function") {
                        rightRow.forceLayout()
                    }
                }

                // Parent-chain walk: sum .x up to (but not including) barRoot
                var item = musicSlotItem
                var x = 0
                var safety = 0
                while (item && item !== barRoot && safety < 20) {
                    x += item.x
                    item = item.parent
                    safety++
                }
                if (item !== barRoot) return  // didn't reach barRoot, bail

                // v6.15.8: Bounds sanity — x must be within the bar.
                // Catches cases where parent-chain walk reads partially-
                // propagated layout state (e.g., rightRow.x still reflects
                // old wide-bar position after bar shrunk to island size).
                if (x < 0 || x > barRoot.width) return
                if (musicSlotItem.width < 10 || musicSlotItem.width > barRoot.width) return

                // v6.15.8: Stable-read gating during mode transitions.
                // See _modeTransitioning property block for the full
                // rationale. In short: require (a) bar.width has been
                // idle for 300ms AND (b) current (x, width) read matches
                // previous read within 2px. Only then commit to writing.
                // This replaces v6.15.7's single-point unlock which was
                // vulnerable to multi-frame layout settling in island mode.
                //
                // v6.15.9: With forceLayout() above, positions are fresh
                // every call. This typically makes the very first and
                // second reads identical, unlocking after ~100ms instead
                // of the 200-400ms it took with pure async layout.
                // We keep the stable-read check as a safety net — if
                // forceLayout is a no-op on some sub-layout (shouldn't
                // happen with QQuickLayout), the check catches it.
                if (musicSlotItem._modeTransitioning) {
                    if (!musicSlotItem._barWidthStable) {
                        // Bar still resizing, just record and bail
                        musicSlotItem._lastReadX = x
                        musicSlotItem._lastReadWidth = musicSlotItem.width
                        return
                    }
                    if (Math.abs(x - musicSlotItem._lastReadX) < 2.0
                        && Math.abs(musicSlotItem.width - musicSlotItem._lastReadWidth) < 2.0) {
                        // Two consecutive stable reads → layout settled,
                        // lift the lockout and proceed to write below.
                        musicSlotItem._modeTransitioning = false
                    } else {
                        // Not stable yet, record and wait for next read
                        musicSlotItem._lastReadX = x
                        musicSlotItem._lastReadWidth = musicSlotItem.width
                        return
                    }
                }

                if (x >= 0 && musicSlotItem.width > 10) {
                    if (Math.abs(ZenStringsState.musicSlotLocalX - x) > 2.0
                        || Math.abs(ZenStringsState.musicSlotLocalWidth - musicSlotItem.width) > 2.0) {
                        barRoot.musicSlotLocalX     = x
                        barRoot.musicSlotLocalWidth = musicSlotItem.width
                        ZenStringsState.musicSlotLocalX     = x
                        ZenStringsState.musicSlotLocalWidth = musicSlotItem.width
                    }
                }
            }

            Timer {
                id: posTimer; interval: 16; repeat: false
                onTriggered: musicSlotItem.updatePos()
            }

            onXChanged:     posTimer.restart()
            onWidthChanged: posTimer.restart()

            Connections {
                target: innerLoader
                function onItemChanged()  { posTimer.restart(); settleTimer.restart() }
                function onWidthChanged() { posTimer.restart() }
                function onHeightChanged(){ posTimer.restart() }
            }

            // v6.15.7: Mode transition lockout. When PanelState.panelMode
            // changes, barWindow renegotiates its Wayland layer-shell
            // geometry asynchronously. The bar's RowLayout goes through
            // several intermediate sizes/positions before settling in the
            // new mode. If we write to musicSlotLocalX during this
            // transition, we commit STALE coordinates that may match the
            // old mode's geometry — causing the orphaned-string bug we
            // reported during rapid Island→FW→Float→Island cycling.
            //
            // v6.15.8: Enhanced with stable-read verification. The 300ms
            // bar-width idle alone isn't enough for transitions INTO
            // island mode (Floating→Island, FW→Island), because island
            // has a feedback loop: barWindow.implicitWidth reads
            // bar.contentImplicitWidth, and bar re-layouts when
            // barWindow resizes. The bar.width can stabilize while
            // children's internal positions are still propagating
            // through multiple frames. A single read after barSettling
            // expired could catch an intermediate stale state — that's
            // what produced the "string lands at start-menu position"
            // bug in v6.15.7.
            //
            // Fix: require TWO CONSECUTIVE stable (x, width) reads (within
            // 2px) AND barWidth-idle before lifting the lockout. Since
            // safetyPoll fires every 100ms, we get multiple reads per
            // second — stable reads typically occur 100-300ms after layout
            // actually finishes settling. Guarantees we never commit a
            // mid-propagation value.
            //
            // Mechanism:
            //   - On panelModeChanged: _modeTransitioning=true,
            //     _barWidthStable=false, reset _lastReadX/Width,
            //     start barSettlingTimer (300ms).
            //   - On barRoot.widthChanged with delta > 20px: reset
            //     _barWidthStable=false, restart barSettlingTimer.
            //     Small deltas (≤20px from layoutNudger or runtime
            //     reflows) don't reset.
            //   - When barSettlingTimer fires: _barWidthStable=true.
            //   - In _doUpdatePos (called by posTimer/safetyPoll/
            //     settleTimer): while _modeTransitioning, check if
            //     (a) _barWidthStable is true, AND
            //     (b) current read (x, width) matches previous within 2px.
            //     If both → lift lockout, proceed to write.
            //     Otherwise → record current, return without writing.
            //
            // Worst case: lockout lifts ~500-800ms into transition
            // (barWidth-idle 300ms + 2 stable reads). Typical case:
            // 300-500ms. Acceptable Loading duration.
            property bool _modeTransitioning: false
            property bool _barWidthStable: true
            property real _lastReadX: -999999
            property real _lastReadWidth: -999999
            property real _lastBarWidth: -1

            Timer {
                id: barSettlingTimer
                interval: 300
                repeat: false
                onTriggered: musicSlotItem._barWidthStable = true
            }

            Connections {
                target: barRoot
                function onWidthChanged() {
                    if (musicSlotItem._modeTransitioning) {
                        if (musicSlotItem._lastBarWidth > 0
                            && Math.abs(barRoot.width - musicSlotItem._lastBarWidth) > 20) {
                            // Significant width change while transitioning
                            // → extend the settle window, clear stability
                            musicSlotItem._barWidthStable = false
                            barSettlingTimer.restart()
                        }
                    }
                    musicSlotItem._lastBarWidth = barRoot.width
                    posTimer.restart()
                }
                function onContentImplicitWidthChanged() { posTimer.restart() }
            }

            // v6.15.2: Listen directly to each zone's RowLayout. Since
            // musicSlotItem's `x` is local to its Loader parent, it never
            // fires onXChanged when a grandparent RowLayout repositions
            // (e.g. rightRow shifts left when sysrow adds an icon because
            // rightRow is AlignRight-anchored). contentImplicitWidthChanged
            // catches most cases but not all — listening to the zone rows
            // directly is the most reliable signal for layout reflow.
            Connections {
                target: leftRow
                function onWidthChanged()         { posTimer.restart() }
                function onImplicitWidthChanged() { posTimer.restart() }
                function onXChanged()             { posTimer.restart() }
            }
            Connections {
                target: centerRow
                function onWidthChanged()         { posTimer.restart() }
                function onImplicitWidthChanged() { posTimer.restart() }
                function onXChanged()             { posTimer.restart() }
            }
            Connections {
                target: rightRow
                function onWidthChanged()         { posTimer.restart() }
                function onImplicitWidthChanged() { posTimer.restart() }
                function onXChanged()             { posTimer.restart() }
            }

            Component.onCompleted: {
                posTimer.restart()
                settleTimer.ticks = 0
                settleTimer.restart()
                safetyPoll.start()
                layoutNudger.start()
            }

            Timer {
                id: settleTimer; interval: 150; repeat: true
                property int ticks: 0
                onTriggered: { musicSlotItem.updatePos(); ticks++; if (ticks >= 8) { stop(); ticks = 0 } }
            }

            // v6.15.2: Continuous low-frequency safety poll. Runs forever
            // at 500ms, calls updatePos which no-ops if nothing changed.
            //
            // v6.15.4: REVERTED stop-on-ready optimization from v6.15.3.
            // Turns out the poll needs to run forever to catch layout
            // "un-stickings" that happen long after positionReady fired.
            // Tiered interval — 100ms for the first 3 seconds (aggressive
            // catch-up during login), then 500ms steady-state. Cost at
            // 500ms steady = one mapToItem-free parent-chain walk every
            // 0.5s = negligible.
            Timer {
                id: safetyPoll
                interval: 100
                repeat: true
                running: false
                triggeredOnStart: false
                property int fastTicks: 0
                onTriggered: {
                    musicSlotItem.updatePos()
                    fastTicks++
                    if (fastTicks === 30) {
                        // 30 × 100ms = 3s of aggressive polling done,
                        // downshift to steady 500ms
                        interval = 500
                    }
                }
            }

            // v6.15.4: Layout nudger. Root cause of the "wrong position
            // until user hovers" bug: on login, the bar's RowLayout does
            // an initial layout pass BEFORE the Wayland layer-shell
            // surface finishes negotiating its final width. When the
            // surface later resizes, Qt should re-run layout, but in
            // some cases the RowLayout caches stale positions for its
            // right-anchored children (rightRow). User interaction
            // (hover, click, focus change) causes QML binding
            // re-evaluation which unsticks the layout.
            //
            // Fix: periodically toggle Layout.preferredWidth on the
            // music slot by 0.1px — invisible visually, but forces
            // RowLayout to recompute ALL child positions. Does that
            // 120 times over 30 seconds, then stops. Paired with the
            // zone-row Connections above, the nudge → rightRow.x
            // changes → posTimer restarts → parent-chain walk reads
            // the fresh value → write to ZenStringsState → stability
            // timer finally converges on the correct position.
            Timer {
                id: layoutNudger
                interval: 250
                repeat: true
                running: false
                property int ticks: 0
                property bool phase: false
                onTriggered: {
                    phase = !phase
                    // Toggle preferredWidth between "auto" (-1 = use
                    // implicit) and implicitWidth + 0.1 → triggers
                    // RowLayout recomputation without visual change.
                    musicSlotItem.Layout.preferredWidth = phase
                        ? -1
                        : (musicSlotItem.implicitWidth + 0.1)
                    ticks++
                    if (ticks >= 120) {
                        stop()
                        ticks = 0
                        // Reset to auto so we don't keep an overriding value
                        musicSlotItem.Layout.preferredWidth = -1
                    }
                }
            }

            Connections {
                target: ZenStringsState
                function onEnabledChanged()      {
                    posTimer.restart(); settleTimer.ticks = 0; settleTimer.restart()
                    safetyPoll.interval = 100; safetyPoll.fastTicks = 0; safetyPoll.restart()
                    layoutNudger.ticks = 0; layoutNudger.restart()
                }
                function onStringLengthChanged() {
                    posTimer.restart(); settleTimer.ticks = 0; settleTimer.restart()
                    safetyPoll.interval = 100; safetyPoll.fastTicks = 0; safetyPoll.restart()
                }
            }

            // v6.15.6: Panel mode transition handling — mirrors the
            // stringsWindow handler in shell.qml. When mode changes, the
            // bar's RowLayout re-anchors and re-sizes, but the initial
            // layout pass is async with the Wayland layer-shell
            // negotiation (same root cause as login). We need to re-run
            // the full discovery stack (nudger + fast poll + settle) to
            // find the slot's new position. Reset musicSlotLocalX to -1
            // so shell.qml's sanity gate refuses to commit stale values
            // during the transition.
            //
            // v6.15.7: Also engage the _modeTransitioning lockout so
            // _doUpdatePos skips writes until barRoot.width is stable
            // for 300ms. This prevents the orphaned-string bug during
            // rapid mode cycling (Island→FW→Float→Island), where the
            // bar's intermediate resize states would leak stale x
            // coordinates into ZenStringsState before the new mode's
            // geometry finished negotiating.
            //
            // v6.15.8: Additionally reset the stable-read tracking
            // (_barWidthStable, _lastReadX, _lastReadWidth) so the
            // transition verification starts fresh for every mode
            // change. See _modeTransitioning property block above.
            Connections {
                target: PanelState
                function onPanelModeChanged() {
                    barRoot.musicSlotLocalX = -1
                    ZenStringsState.musicSlotLocalX = -1
                    musicSlotItem._modeTransitioning = true
                    musicSlotItem._barWidthStable = false
                    musicSlotItem._lastReadX = -999999
                    musicSlotItem._lastReadWidth = -999999
                    barSettlingTimer.restart()
                    // v6.15.9: Preemptive forceLayout to collapse the
                    // async layout propagation into a single sync pass.
                    // Called via callLater so the panelMode property
                    // binding has time to fire barWindow.implicitWidth
                    // re-evaluation first — we force layout AFTER the
                    // new target geometry is known.
                    Qt.callLater(function() {
                        if (barMainLayout && typeof barMainLayout.forceLayout === "function") {
                            barMainLayout.forceLayout()
                        }
                        if (leftRow && typeof leftRow.forceLayout === "function") {
                            leftRow.forceLayout()
                        }
                        if (centerRow && typeof centerRow.forceLayout === "function") {
                            centerRow.forceLayout()
                        }
                        if (rightRow && typeof rightRow.forceLayout === "function") {
                            rightRow.forceLayout()
                        }
                    })
                    posTimer.restart()
                    settleTimer.ticks = 0; settleTimer.restart()
                    safetyPoll.interval = 100; safetyPoll.fastTicks = 0; safetyPoll.restart()
                    layoutNudger.ticks = 0; layoutNudger.restart()
                }
            }
        }
    }

    function getComponent(name) {
        switch(name) {
            case "start":         return cStartMenu
            case "taskbar":       return cTaskbar
            case "workspaces":    return cWorkspaces
            case "window":        return cWindowTitle
            case "music":         return cMusic
            case "sysrow":        return cSysRow
            case "tray":          return cTray
            case "notifications": return cNotif
            case "clock":         return cClock
            case "weather":       return cWeather
            case "clipboard":     return cClipboard   // v7.0.0-alpha.6
            case "sysmonitor":    return cSysMonitor
            case "battery":       return cBattery
            // v6.16.3.4: power profile + GPU mode badge
            case "powerbadge":    return cPowerBadge
            // v6.16.4.12: calendar + notif center (Hikari)
            case "calendar":      return cCalendar
            // v7.0.0-alpha.13: workflow profile badge
            case "workflow":      return cWorkflow
            // v7.0.0-beta.1-hf39 — five new feature modules
            case "quicknotes":      return cQuickNotes
            case "focusspaces":     return cFocusSpaces
            case "networkpulse":    return cNetworkPulse
            case "smartdim":        return cSmartDim
            case "titletranslator": return cTitleTranslator
        }
        console.warn("[Bar] Unknown module:", name)
        return null
    }

    // ═══════════════════════════════════════════════════════════════════════
    // v8.0.0-alpha-hf193 — THE CENTRE ZONE NOW ACTUALLY STAYS CENTRED
    //
    // "kapag may add ako sa left, lalo na window kapag mahahaba words, yun
    //  center ko dynamically umuusog-usog. Dapat as is sila sa pwesto."
    //
    // This was a RowLayout of five items:
    //
    //     leftRow │ leftSpacer(fill) │ centerRow │ rightSpacer(fill) │ rightRow
    //
    // Two fillWidth spacers split the leftover space EQUALLY, which sounds
    // like centring and is not. Work it through:
    //
    //     spacer      = (W - left - centre - right) / 2
    //     centre.mid  = left + spacer + centre/2
    //                 = W/2 + (left - right)/2
    //
    // The centre sits half the LEFT-MINUS-RIGHT difference away from true
    // centre. Add an icon on the left and the centre slides right by half its
    // width. A long window title on the left pushes it further still. It is
    // only ever genuinely centred when the two side zones happen to be exactly
    // the same width, which is never.
    //
    // Spacer-based centring cannot be fixed by tuning; it is the wrong
    // mechanism. Anchors are the right one: each zone is positioned against
    // the bar itself, not against its neighbours, so none of the three can
    // move any other. Left is left, right is right, centre is centre, whatever
    // is in them.
    //
    // The one thing anchoring gives up is automatic collision avoidance — a
    // flow layout can't overlap, anchored items can. So the centre gets an
    // explicit budget (see centerMaxWidth) and a clipping slot: it holds the
    // true centre and gives up width symmetrically rather than sliding away.
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        id: barMainLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        // v7.0.0-beta.1-hf85: guaranteed top/bottom breathing room so
        // modules stay centered with an even gap when the bar height
        // changes. Zones fillHeight within the inset area; modules are
        // AlignVCenter, so they sit centered with symmetric padding.
        anchors.topMargin: PanelState.barContentPaddingV
        anchors.bottomMargin: PanelState.barContentPaddingV

        /** Breathing room kept between the centre zone and either side. */
        readonly property int zoneGap: 12

        /**
         * How wide the centre may be while staying centred AND clear of both
         * sides. Symmetric by construction: whichever side is wider decides,
         * so the centre never has to move to make room for one of them.
         */
        readonly property real centerMaxWidth: Math.max(0,
            2 * Math.min(width / 2 - leftRow.width  - zoneGap,
                         width / 2 - rightRow.width - zoneGap))

        RowLayout {
            id: leftRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.left || []
                Loader {
                    id: modLoader
                    sourceComponent: barRoot.getComponent(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    active: sourceComponent !== null

                    // v6.16.4.12.6.51 (Hikari) hotfix: forward the loaded
                    // item's implicit size up to the Loader's Layout
                    // properties. Without this, RowLayout sizes the Loader
                    // by its own implicitWidth (which is 0 for an unsized
                    // Loader), and the loaded module gets 0×0 — killing
                    // the MouseArea input area silently. This is why the
                    // Clock module's hover/click never registered despite
                    // Layout hints inside the loaded item itself: those
                    // hints don't propagate UP through the Loader.
                    Layout.preferredWidth:  item ? Math.max(item.implicitWidth,  item.width  || 0) : 0
                    Layout.preferredHeight: item ? Math.max(item.implicitHeight, item.height || 0) : 0
                }
            }
        }

        // v8.0.0-alpha-hf193: leftSpacer and rightSpacer are gone. They were
        // the centring mechanism, and the centring mechanism was the bug.
        // (Historical note, since it was documented here: those Items had
        // already been reduced to pure layout placeholders in
        // v6.16.4.12.6.51 — an earlier build put an invisible click target
        // in them that opened the calendar. That trigger has lived on the
        // Clock module ever since, so nothing is lost by removing them.)

        // The slot holds the true centre of the bar and never moves. When the
        // side zones grow enough to squeeze it, it narrows and clips evenly on
        // both edges — so the centre content stays visually centred as it
        // shrinks, instead of the whole zone sliding sideways.
        Item {
            id: centerSlot
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(centerRow.implicitWidth, barMainLayout.centerMaxWidth)
            height: centerRow.implicitHeight
            clip: width < centerRow.implicitWidth
            visible: width > 0

        RowLayout {
            id: centerRow
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: Theme.barLayout.center || []
                Loader {
                    id: modLoader
                    sourceComponent: barRoot.getComponent(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    active: sourceComponent !== null

                    // v6.16.4.12.6.51 (Hikari) hotfix: forward the loaded
                    // item's implicit size up to the Loader's Layout
                    // properties. Without this, RowLayout sizes the Loader
                    // by its own implicitWidth (which is 0 for an unsized
                    // Loader), and the loaded module gets 0×0 — killing
                    // the MouseArea input area silently. This is why the
                    // Clock module's hover/click never registered despite
                    // Layout hints inside the loaded item itself: those
                    // hints don't propagate UP through the Loader.
                    Layout.preferredWidth:  item ? Math.max(item.implicitWidth,  item.width  || 0) : 0
                    Layout.preferredHeight: item ? Math.max(item.implicitHeight, item.height || 0) : 0
                }
            }
        }

        }   // centerSlot

        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: Theme.barLayout.right || []
                Loader {
                    id: modLoader
                    sourceComponent: barRoot.getComponent(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    active: sourceComponent !== null

                    // v6.16.4.12.6.51 (Hikari) hotfix: forward the loaded
                    // item's implicit size up to the Loader's Layout
                    // properties. Without this, RowLayout sizes the Loader
                    // by its own implicitWidth (which is 0 for an unsized
                    // Loader), and the loaded module gets 0×0 — killing
                    // the MouseArea input area silently. This is why the
                    // Clock module's hover/click never registered despite
                    // Layout hints inside the loaded item itself: those
                    // hints don't propagate UP through the Loader.
                    Layout.preferredWidth:  item ? Math.max(item.implicitWidth,  item.width  || 0) : 0
                    Layout.preferredHeight: item ? Math.max(item.implicitHeight, item.height || 0) : 0
                }
            }
        }
    }
}
