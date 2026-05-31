pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DockState v7.0.0-beta.1-hf82k — Karui (軽い)
 *
 * Singleton holding all dock-specific state. Separate from PanelState
 * (which is bar-only) so the dock can have its own position/mode/modules
 * independent of the bar. A `syncFromBar` flag pulls visual settings
 * (theme/border/blur) from PanelState/ThemeService when true, letting
 * the user keep both surfaces visually unified without duplicating
 * config rows.
 *
 * State path: ~/.local/share/quickshell/zen-shell/dock-state.json
 *
 * v7.0.0-beta.1-hf82k introduces this singleton. Default `enabled: false`
 * preserves pre-hf82k behavior — the dock is opt-in. Once enabled,
 * the default `modules` array mirrors what's typically in the bar's
 * taskbar slot, giving the user a familiar dock at first launch.
 *
 * Wala tayong babawasan — this is purely additive; no existing
 * state file or singleton is touched.
 */
Singleton {
    id: root

    // ── Persistence ──
    readonly property string statePath:
        Quickshell.dataPath("dock-state.json")

    // ── Master toggle ──
    property bool enabled: false

    // ── Position & mode ──
    //
    // position: "top" | "bottom"  — independent of bar's position
    // mode:     "fullwidth" | "floating" | "island"
    //
    // Defaults: dock at bottom in island mode (Mac-dock-style centered
    // pill that hugs its content width). Users with a top-anchored bar
    // get a natural top-bar + bottom-dock layout out of the box.
    property string position: "bottom"
    property string mode:     "island"

    // ── Module list ──
    //
    // The dock body iterates this array and resolves each entry via
    // ZenDock.qml's getComponent() dispatcher. Order in the array is
    // visual order from left to right.
    //
    // Default (hf82k post-elicitation revision): lean — just the
    // taskbar (drag-and-drop app launcher) and workspaces strip.
    // Mac-dock-style minimal: pinned + running apps plus the
    // workspace counter, nothing else. No sysrow clutter, no start
    // menu duplicate (since the bar already has one), no divider
    // since there are only two adjacent modules anyway.
    //
    // User can add any of the other module ids via DockPage:
    //   "start"         — StartMenu pill (if they want it duplicated)
    //   "divider"       — vertical separator (ZenDivider)
    //   "sysrow"        — system tray cluster (volume/wifi/etc)
    //   "controlcenter" — quick-settings button (stub in hf82k; popup
    //                     ships in hf82l)
    //   "tray"          — system tray
    //   "clock"         — clock display
    //   "battery"       — battery indicator
    //   "notifications" — notification bell
    //
    // Recognized module ids handled by ZenDock.getComponent(). All
    // the previously-default modules are still slot-able — only the
    // factory default array is leaner now.
    property var modules: [
        "taskbar", "workspaces"
    ]

    // ── Sync from Bar (theme/border/blur) ──
    //
    // When true: the dock pulls its background color, border color,
    // border width, blur, and corner radius from the same sources
    // the Bar uses (PanelState.bgColor / ThemeService). Toggle off to
    // give the dock its own visual identity (e.g. transparent
    // background with stronger border).
    property bool syncFromBar: true

    // ── Overrides (used only when syncFromBar === false) ──
    //
    // Stored even when syncFromBar is true, so toggling sync off
    // doesn't reset the user's previous picks.
    property color overrideBgColor: "#1a1d23"
    property color overrideBorderColor: "#454c5e"
    property int   overrideBorderWidth: 1
    property real  overrideBgOpacity: 0.85
    property int   overrideCornerRadius: 16

    // ── Sizing ──
    property int height: 56
    property int marginSide: 16
    property int marginEdge: 10
    property int contentSpacing: 8
    property int contentPadding: 8

    // v7.0.0-beta.1-hf95.31 — minimum icon scale before overflow arrows
    // kick in. In fullwidth/floating, when many apps would overflow the
    // dock shrinks icons down to this fraction of normal size; once it
    // hits this floor and STILL overflows, chevron scroll arrows appear
    // (hybrid resize→arrows). 1.0 = never shrink (arrows immediately);
    // 0.55 = shrink to 55% before arrows. Range enforced 0.55–1.0.
    property real minIconScale: 0.7
    onMinIconScaleChanged: markDirty()

    // v7.0.0-beta.1-hf95.32 — dock icon size multiplier, independent of
    // the bar. 1.0 = same as the bar's module height; >1 makes dock icons
    // bigger, <1 smaller. Applied as a base scale on the dock content
    // (the dynamic fit-scale from crowding still applies on top, down to
    // minIconScale). Range 0.6–2.0.
    property real iconSizeScale: 1.0
    onIconSizeScaleChanged: markDirty()

    // ── Reserve space / push tiled windows (v7.0.0-beta.1-hf83) ──
    //
    // The dock originally mounted with ExclusionMode.Ignore — Mac-dock
    // style, where tiled windows sit UNDER the dock and it floats over
    // them. That overlaps Hyprland tiles, which the user does not want.
    //
    // When reserveSpace is true, the dock window reserves a layer-shell
    // exclusive zone on its anchored edge equal to its height + edge
    // margin + reserveGap. The compositor then keeps tiled windows out
    // of that strip, so the dock no longer overlaps tiles — there's a
    // clean gap between the last tile and the dock.
    //
    // reserveGap is EXTRA breathing room on top of the dock height +
    // edge margin, so windows don't butt right up against the dock.
    //
    // Default true: the dock is opt-in (enabled defaults false), so no
    // existing non-dock user is affected, and a freshly-enabled dock
    // behaves the way the user asked (reserves space). Flip this off to
    // get the old overlapping Mac-dock feel back — wala tayong
    // babawasan, the overlap behavior is preserved as a toggle.
    property bool reserveSpace: true
    property int  reserveGap: 6

    // Computed exclusive zone the dock window feeds to the layer shell
    // when reserveSpace is on. Lives here so shell.qml stays a thin
    // binding and the math has one home.
    readonly property int exclusiveZonePx:
        reserveSpace ? (height + marginEdge + reserveGap) : 0

    // ── Monitor targeting ──
    //
    // "all" — show on every monitor
    // "primary" — show on Quickshell.screens[0]
    // <monitor name> — show only on that monitor (e.g. "DP-2")
    property string showOnMonitor: "primary"

    // ── Live state (not persisted) ──
    property bool _loaded: false

    // ── Derived ──
    readonly property bool isTop:    position === "top"
    readonly property bool isBottom: position === "bottom"

    // ── Persistence: load on startup ──
    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        onLoaded: {
            // hf82b pattern — FileView.text is a callable. Unwrap.
            const raw = (typeof text === "function") ? text() : text
            root._loadFromJson(raw)
            root._loaded = true
        }
        onLoadFailed: {
            // No state file yet — first-run; use defaults.
            root._loaded = true
        }
    }

    function _loadFromJson(raw) {
        if (!raw || !raw.trim || raw.trim().length === 0) return
        try {
            const s = JSON.parse(raw)
            if (typeof s.enabled === "boolean")          enabled = s.enabled
            if (typeof s.position === "string")          position = s.position
            if (typeof s.mode === "string")              mode = s.mode
            if (Array.isArray(s.modules))                modules = s.modules
            if (typeof s.syncFromBar === "boolean")      syncFromBar = s.syncFromBar
            if (typeof s.overrideBgColor === "string")   overrideBgColor = s.overrideBgColor
            if (typeof s.overrideBorderColor === "string") overrideBorderColor = s.overrideBorderColor
            if (typeof s.overrideBorderWidth === "number") overrideBorderWidth = s.overrideBorderWidth
            if (typeof s.overrideBgOpacity === "number") overrideBgOpacity = s.overrideBgOpacity
            if (typeof s.overrideCornerRadius === "number") overrideCornerRadius = s.overrideCornerRadius
            if (typeof s.height === "number")            height = s.height
            if (typeof s.marginSide === "number")        marginSide = s.marginSide
            if (typeof s.marginEdge === "number")        marginEdge = s.marginEdge
            if (typeof s.contentSpacing === "number")    contentSpacing = s.contentSpacing
            if (typeof s.contentPadding === "number")    contentPadding = s.contentPadding
            if (typeof s.minIconScale === "number")
                minIconScale = Math.max(0.55, Math.min(1.0, s.minIconScale))
            if (typeof s.iconSizeScale === "number")
                iconSizeScale = Math.max(0.6, Math.min(2.0, s.iconSizeScale))
            if (typeof s.reserveSpace === "boolean")     reserveSpace = s.reserveSpace
            if (typeof s.reserveGap === "number")        reserveGap = Math.max(0, Math.min(60, s.reserveGap))
            if (typeof s.showOnMonitor === "string")     showOnMonitor = s.showOnMonitor
        } catch (e) {
            console.error("[DockState] Parse error:", e)
        }
    }

    // ── Persistence: save on change (debounced) ──
    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: root._save()
    }

    function _save() {
        if (!root._loaded) return  // don't save before first load completes
        const obj = {
            enabled, position, mode, modules, syncFromBar,
            overrideBgColor: overrideBgColor.toString(),
            overrideBorderColor: overrideBorderColor.toString(),
            overrideBorderWidth, overrideBgOpacity, overrideCornerRadius,
            height, marginSide, marginEdge, contentSpacing, contentPadding,
            minIconScale, iconSizeScale,
            reserveSpace, reserveGap,
            showOnMonitor
        }
        const json = JSON.stringify(obj, null, 2)
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "tmp=$(mktemp) && " +
            "cat > \"$tmp\" << 'ZEN_DOCK_STATE_EOF'\n" + json +
            "\nZEN_DOCK_STATE_EOF\n" +
            "mv \"$tmp\" '" + statePath + "'"]
        saver.running = true
    }

    Process { id: saver; running: false }

    function markDirty() { saveTimer.restart() }

    // Auto-save when any persisted property changes.
    onEnabledChanged:             markDirty()
    onPositionChanged:            markDirty()
    onModeChanged:                markDirty()
    onModulesChanged:             markDirty()
    onSyncFromBarChanged:         markDirty()
    onOverrideBgColorChanged:     markDirty()
    onOverrideBorderColorChanged: markDirty()
    onOverrideBorderWidthChanged: markDirty()
    onOverrideBgOpacityChanged:   markDirty()
    onOverrideCornerRadiusChanged: markDirty()
    onHeightChanged:              markDirty()
    onMarginSideChanged:          markDirty()
    onMarginEdgeChanged:          markDirty()
    onContentSpacingChanged:      markDirty()
    onContentPaddingChanged:      markDirty()
    onReserveSpaceChanged:        markDirty()
    onReserveGapChanged:          markDirty()
    onShowOnMonitorChanged:       markDirty()

    // ── Mutators (called from settings UI) ──

    function setModuleEnabled(moduleId, enabled) {
        const idx = modules.indexOf(moduleId)
        if (enabled && idx === -1) {
            modules = modules.concat([moduleId])
        } else if (!enabled && idx !== -1) {
            const next = modules.slice()
            next.splice(idx, 1)
            modules = next
        }
    }

    function moveModule(fromIndex, toIndex) {
        if (fromIndex === toIndex) return
        if (fromIndex < 0 || fromIndex >= modules.length) return
        if (toIndex < 0   || toIndex   >= modules.length) return
        const next = modules.slice()
        const item = next.splice(fromIndex, 1)[0]
        next.splice(toIndex, 0, item)
        modules = next
    }

    function resetDefaults() {
        position = "bottom"
        mode = "island"
        // hf82k post-elicitation: lean default (taskbar + workspaces).
        // User can re-add start/divider/sysrow/controlcenter via DockPage.
        modules = ["taskbar", "workspaces"]
        syncFromBar = true
        height = 56
        marginSide = 16
        marginEdge = 10
        contentSpacing = 8
        contentPadding = 8
        reserveSpace = true
        reserveGap = 6
        showOnMonitor = "primary"
    }
}
