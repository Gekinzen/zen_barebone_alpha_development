pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * DesktopIconsState v7.0.0-beta.1-hf82o — Karui (軽い)
 *
 * Singleton for the FILE/FOLDER ICON layer of the desktop overlay.
 * Widgets (clock, weather, sysmon, sticky notes) are handled by the
 * pre-existing DesktopWidgets.qml + DesktopStickyNotes.qml system —
 * this singleton ONLY manages icon-related state.
 *
 * Persistence: ~/.local/share/quickshell/zen-shell/desktop-icons.json
 *
 * Format:
 * {
 *   "enabled": false,
 *   "scanPath": "/home/paul/Desktop",
 *   "showFolderIcons": true,
 *   "iconSize": 64,
 *   "labelColor": "auto",
 *   "iconPositions": {
 *     "Documents":     { "x": 60,  "y": 80  },
 *     "Steam.desktop": { "x": 240, "y": 80  }
 *   }
 * }
 *
 * Free-form drag: every icon gets an (x, y) saved per-drop. No grid
 * snap by default (true Android-style placement).
 *
 * Wala tayong babawasan — singleton purely additive; widget state
 * lives elsewhere unchanged.
 */
Singleton {
    id: root

    // ── Persistence ──
    readonly property string statePath:
        Quickshell.dataPath("desktop-icons.json")

    // ── Master toggle ──
    property bool enabled: false

    // ── Scan source ──
    property string scanPath: Quickshell.env("HOME") + "/Desktop"
    property bool showFolderIcons: true
    property int iconSize: 64
    property string labelColor: "auto"  // "auto" | "light" | "dark" | "#RRGGBB"

    // ── Arrange mode (hf82r) ──
    //
    // "free"  — Android-style: drag anywhere, position saved per-icon (default)
    // "grid"  — Snap to nearest grid cell on drop (still draggable)
    // "auto"  — Auto-arrange: icons flow top-left → bottom-right, drag disabled
    //
    // gridSize is the snap unit when arrangeMode is "grid" (also used as
    // the flow step in "auto" mode).
    property string arrangeMode: "free"
    property int gridSize: 96

    // ── Style (hf82w) ──
    //
    // Independent of arrangeMode. Controls visual rendering of each icon:
    //   "default" — normal 128px icons with label below
    //   "compact"   — small/dense 48px icons, tight 64px grid, label on hover only
    //               (Windows-style "Small icons" view)
    //   "squircle" — squircle homescreen: squircle mask, drop shadow, subtle bg tile,
    //               drop-to-create-folder gesture
    //
    // When style changes, iconSize + gridSize defaults adapt automatically
    // unless user has explicitly overridden them. Two helpers below compute
    // the EFFECTIVE size used for rendering.
    property string style: "default"

    // Effective icon size for rendering (style-aware override)
    readonly property int effectiveIconSize: {
        if (style === "compact")   return 48
        if (style === "squircle") return 96
        return iconSize  // default uses the user-configurable iconSize
    }

    // Effective grid size for snap/flow (style-aware override)
    readonly property int effectiveGridSize: {
        if (style === "compact")   return 64
        if (style === "squircle") return 120
        return gridSize
    }

    // Show label always vs on-hover only (compact mode hides label to save space)
    readonly property bool labelAlwaysVisible: (style !== "compact")

    // ── Single-widget mode (v7.0.0-beta.1-hf83) ──
    //
    // When true, the scattered free-form icons are replaced by ONE
    // movable + resizable panel (DesktopIconsWidget) that holds every
    // icon in a reflowing grid. Drag the title bar to move it; drag the
    // bottom-right handle to resize it (the grid reflows to fit). Icons
    // inside use the SAME icon-theme resolution the taskbar uses (via
    // AppLauncherService / Quickshell.iconPath), so launchers show their
    // real app icons.
    //
    // Default false → existing installs keep the scattered layout until
    // the user opts in. Wala tayong babawasan: the scatter path in
    // DesktopSurface is untouched, just gated behind !widgetMode.
    property bool widgetMode: false

    // Panel geometry (screen-local px). Persisted across sessions.
    property int widgetX: 80
    property int widgetY: 80
    property int widgetW: 560
    property int widgetH: 380

    // Icon size used INSIDE the widget grid (independent of the
    // scattered iconSize). Resizing the panel reflows columns; this
    // controls each tile's glyph size.
    property int widgetIconSize: 56

    // Clamp bounds so a bad drag/resize can't make the panel unusable.
    readonly property int widgetMinW: 220
    readonly property int widgetMinH: 160

    // ── Custom PNG icon overrides (v7.0.0-beta.1-hf85) ──
    //
    // Map of entry name → absolute image path. Highest-priority icon
    // source: if an entry has a custom icon set, it wins over theme /
    // .desktop / taskbar resolution. Set via right-click → "Set custom
    // icon…" on a tile in the desktop-icons widget (spawns a file
    // picker). Persisted with the rest of the icon state.
    property var customIcons: ({})
    //
    // Per-monitor list of rectangles to AVOID when auto-flowing icons.
    // DesktopWidgets + DesktopStickyNotes can register their bounding
    // boxes here so icons don't get placed on top of the user's clock
    // / weather / sysmon widgets.
    //
    // Format: array of { x, y, w, h } in screen-local coordinates.
    // Updated at runtime — NOT persisted (each widget re-registers
    // on shell startup).
    property var collisionRegions: []

    // ── Icon positions (free-form drag) ──
    //
    // Map of file/folder name → { x, y }. Missing entries get
    // auto-flowed in a top-left-to-bottom-right column.
    property var iconPositions: ({})

    // ── Live state (not persisted) ──
    property bool _loaded: false

    // ── Persistence: load on startup ──
    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: false
        onLoaded: {
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
            if (typeof s.scanPath === "string")          scanPath = s.scanPath
            if (typeof s.showFolderIcons === "boolean")  showFolderIcons = s.showFolderIcons
            if (typeof s.iconSize === "number")          iconSize = s.iconSize
            if (typeof s.labelColor === "string")        labelColor = s.labelColor
            if (typeof s.arrangeMode === "string")       arrangeMode = s.arrangeMode
            if (typeof s.gridSize === "number")          gridSize = s.gridSize
            if (typeof s.style === "string")             style = s.style
            // v7.0.0-beta.1-hf83: single-widget mode + geometry
            if (typeof s.widgetMode === "boolean")       widgetMode = s.widgetMode
            if (typeof s.widgetX === "number")           widgetX = s.widgetX
            if (typeof s.widgetY === "number")           widgetY = s.widgetY
            if (typeof s.widgetW === "number")           widgetW = Math.max(widgetMinW, s.widgetW)
            if (typeof s.widgetH === "number")           widgetH = Math.max(widgetMinH, s.widgetH)
            if (typeof s.widgetIconSize === "number")    widgetIconSize = Math.max(32, Math.min(128, s.widgetIconSize))
            if (s.customIcons && typeof s.customIcons === "object") customIcons = s.customIcons
            if (s.iconPositions && typeof s.iconPositions === "object") {
                iconPositions = s.iconPositions
            }
        } catch (e) {
            console.error("[DesktopIconsState] Parse error:", e)
        }
    }

    // ── Persistence: save on change (debounced 500ms) ──
    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: root._save()
    }

    function _save() {
        if (!root._loaded) return  // don't save before first load completes
        const obj = {
            enabled, scanPath, showFolderIcons, iconSize, labelColor,
            arrangeMode, gridSize, style,
            // v7.0.0-beta.1-hf83: single-widget mode + its geometry
            widgetMode, widgetX, widgetY, widgetW, widgetH, widgetIconSize,
            customIcons,
            iconPositions
        }
        const json = JSON.stringify(obj, null, 2)
        const escaped = json.replace(/'/g, "'\\''")
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "tmp=$(mktemp) && " +
            "printf '%s' '" + escaped + "' > \"$tmp\" && " +
            "mv \"$tmp\" '" + statePath + "'"]
        saver.running = true
    }

    Process { id: saver; running: false }

    function markDirty() { saveTimer.restart() }

    onEnabledChanged:         markDirty()
    onScanPathChanged:        markDirty()
    onShowFolderIconsChanged: markDirty()
    onIconSizeChanged:        markDirty()
    onLabelColorChanged:      markDirty()
    onArrangeModeChanged:     markDirty()
    onGridSizeChanged:        markDirty()
    onIconPositionsChanged:   markDirty()
    // v7.0.0-beta.1-hf83
    onWidgetModeChanged:      markDirty()
    onWidgetXChanged:         markDirty()
    onWidgetYChanged:         markDirty()
    onWidgetWChanged:         markDirty()
    onWidgetHChanged:         markDirty()
    onWidgetIconSizeChanged:  markDirty()
    onCustomIconsChanged:     markDirty()

    // v7.0.0-beta.1-hf83: commit panel geometry from the widget after a
    // drag/resize, clamped to sane minimums. One call so a move+resize
    // only triggers a single debounced save.
    function setWidgetGeometry(x, y, w, h) {
        widgetX = Math.round(x)
        widgetY = Math.round(y)
        widgetW = Math.max(widgetMinW, Math.round(w))
        widgetH = Math.max(widgetMinH, Math.round(h))
    }

    // v7.0.0-beta.1-hf85: per-entry custom PNG icon override.
    function setCustomIcon(entryName, path) {
        if (!entryName) return
        const next = {}
        for (const k in customIcons) next[k] = customIcons[k]
        if (path && path.length > 0) next[entryName] = path
        else delete next[entryName]
        customIcons = next
    }
    function clearCustomIcon(entryName) { setCustomIcon(entryName, "") }

    // ── Mutators ──

    function setIconPosition(iconName, x, y) {
        // Copy-on-write so QML's binding system detects the change.
        // In "grid" mode, snap (x, y) to nearest gridSize boundary.
        let nx = Math.round(x)
        let ny = Math.round(y)
        if (arrangeMode === "grid") {
            nx = Math.round(nx / gridSize) * gridSize
            ny = Math.round(ny / gridSize) * gridSize
        }
        const next = {}
        for (const k in iconPositions) next[k] = iconPositions[k]
        next[iconName] = { "x": nx, "y": ny }
        iconPositions = next
    }

    function removeIconPosition(iconName) {
        const next = {}
        for (const k in iconPositions) {
            if (k !== iconName) next[k] = iconPositions[k]
        }
        iconPositions = next
    }

    // ── Collision region API (hf82r) ──
    //
    // Called by widget components (DesktopWidgets, DesktopStickyNotes,
    // future widget types) on mount/move/resize to register the area
    // they occupy. DesktopSurface's auto-flow consults these when
    // placing icons without saved positions.
    //
    // regionId: a unique key per widget (e.g. "clock-screen-DP-2").
    //           Re-registering with the same id replaces the previous
    //           entry — handy when a widget moves.
    function registerCollisionRegion(regionId, x, y, w, h) {
        const next = (collisionRegions || []).filter(r => r.id !== regionId)
        next.push({
            "id": regionId,
            "x": Math.round(x), "y": Math.round(y),
            "w": Math.round(w), "h": Math.round(h)
        })
        collisionRegions = next
    }

    function unregisterCollisionRegion(regionId) {
        collisionRegions = (collisionRegions || []).filter(r => r.id !== regionId)
    }

    // ── Test helper: does (x, y, w, h) overlap any collision region? ──
    function rectIntersectsCollision(x, y, w, h) {
        const regs = collisionRegions || []
        for (let i = 0; i < regs.length; i++) {
            const r = regs[i]
            if (x < r.x + r.w && x + w > r.x
             && y < r.y + r.h && y + h > r.y) {
                return true
            }
        }
        return false
    }

    function resetDefaults() {
        scanPath = Quickshell.env("HOME") + "/Desktop"
        showFolderIcons = true
        iconSize = 64
        labelColor = "auto"
        arrangeMode = "free"
        gridSize = 96
        widgetMode = false
        widgetX = 80
        widgetY = 80
        widgetW = 560
        widgetH = 380
        widgetIconSize = 56
        customIcons = ({})
        iconPositions = ({})
    }
}
