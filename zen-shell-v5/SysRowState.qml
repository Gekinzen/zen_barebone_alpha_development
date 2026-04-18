pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * SysRowState v6.13 — SysRow configuration + rice export/import
 *
 * Persists to ~/.config/quickshell/zen-shell/sysrow-state.json
 *
 * Controls which modules are visible in the SysRow expand drawer,
 * display mode (icon+bargraph vs text label), custom per-module
 * colors, and the full Zen Shell settings export/import system.
 *
 * Export: saves ALL Zen Shell settings (PanelState + SysRowState +
 * theme ID) as a single JSON file for sharing rices.
 * Import: reads JSON, applies everything, restarts shell.
 */
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/sysrow-state.json"
    readonly property string exportDir: Quickshell.env("HOME") + "/.config/quickshell/zen-shell/exports"

    // ── Module visibility toggles ──
    property bool showSound: true
    property bool showCpu: true
    property bool showRam: true
    property bool showTemp: true
    property bool showNetwork: true
    property bool showBluetooth: true

    // ── Display mode: "icon" (icon + bargraph) or "text" (label + value) ──
    property string displayMode: "icon"   // "icon" | "text"

    // ── Custom colors (empty = use theme-reactive default) ──
    property string cpuColor: ""          // "" = auto from ThemeService
    property string ramColor: ""
    property string tempColor: ""
    property string soundColor: ""
    property string networkColor: ""
    property string btColor: ""

    // ── Collapse delay (ms) ──
    property int collapseDelay: 800

    // ── Expand arrow style ──
    property string arrowCollapsed: "❮"
    property string arrowExpanded: "❯"

    // ── Tooltip state (read by shell.qml tooltip overlay) ──
    property bool tooltipVisible: false
    property string tooltipTitle: ""
    property string tooltipDetail: ""
    property real tooltipX: 0    // global X position (center of hovered icon)

    function showTooltip(title, detail, globalX) {
        tooltipTitle = title
        tooltipDetail = detail
        tooltipX = globalX
        tooltipVisible = true
    }

    function hideTooltip() {
        tooltipVisible = false
    }

    // ── Signals ──
    signal stateChanged()
    signal importCompleted()

    // ── Color resolver: returns custom color or theme default ──
    function resolveColor(customColor, themeDefault) {
        if (customColor && customColor.length > 0) return customColor
        return themeDefault
    }

    // ── Save state ──
    function saveState() {
        const state = {
            showSound: showSound,
            showCpu: showCpu,
            showRam: showRam,
            showTemp: showTemp,
            showNetwork: showNetwork,
            showBluetooth: showBluetooth,
            displayMode: displayMode,
            cpuColor: cpuColor,
            ramColor: ramColor,
            tempColor: tempColor,
            soundColor: soundColor,
            networkColor: networkColor,
            btColor: btColor,
            collapseDelay: collapseDelay,
            arrowCollapsed: arrowCollapsed,
            arrowExpanded: arrowExpanded
        }
        const json = JSON.stringify(state, null, 2)
        saver.command = ["bash", "-c",
            "mkdir -p $(dirname '" + statePath + "') && " +
            "cat > '" + statePath + "' << 'ZSEOF'\n" + json + "\nZSEOF"]
        saver.running = true
        stateChanged()
    }

    function applyState(text) {
        if (!text) return
        try {
            const s = JSON.parse(text)
            if (typeof s.showSound === "boolean") showSound = s.showSound
            if (typeof s.showCpu === "boolean") showCpu = s.showCpu
            if (typeof s.showRam === "boolean") showRam = s.showRam
            if (typeof s.showTemp === "boolean") showTemp = s.showTemp
            if (typeof s.showNetwork === "boolean") showNetwork = s.showNetwork
            if (typeof s.showBluetooth === "boolean") showBluetooth = s.showBluetooth
            if (s.displayMode) displayMode = s.displayMode
            if (s.cpuColor !== undefined) cpuColor = s.cpuColor
            if (s.ramColor !== undefined) ramColor = s.ramColor
            if (s.tempColor !== undefined) tempColor = s.tempColor
            if (s.soundColor !== undefined) soundColor = s.soundColor
            if (s.networkColor !== undefined) networkColor = s.networkColor
            if (s.btColor !== undefined) btColor = s.btColor
            if (typeof s.collapseDelay === "number") collapseDelay = s.collapseDelay
            if (s.arrowCollapsed) arrowCollapsed = s.arrowCollapsed
            if (s.arrowExpanded) arrowExpanded = s.arrowExpanded
        } catch (e) {
            console.error("[SysRowState] Parse error:", e)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // EXPORT / IMPORT — Full Zen Shell rice config
    // ═══════════════════════════════════════════════════════════════

    /*
     * exportRice(name) — exports ALL settings as a single JSON file.
     * File saved to: ~/.config/quickshell/zen-shell/exports/<name>.json
     *
     * Contains:
     *   - panelState: all PanelState properties
     *   - sysRowState: all SysRowState properties
     *   - themeId: current theme ID
     *   - barLayout: current Theme.barLayout
     *   - meta: export timestamp, version, hostname
     */
    function exportRice(name) {
        const ts = new Date().toISOString()
        const safeName = name.replace(/[^a-zA-Z0-9_-]/g, "-").toLowerCase() || ("rice-" + Date.now())

        const rice = {
            meta: {
                name: name || safeName,
                version: "6.13",
                exported: ts,
                format: "zen-shell-rice-v1"
            },
            panelState: {
                panelMode: PanelState.panelMode,
                barHeight: PanelState.barHeight,
                borderEnabled: PanelState.borderEnabled,
                borderWidth: PanelState.borderWidth,
                borderColor: "" + PanelState.borderColor,
                bgOverrideEnabled: PanelState.bgOverrideEnabled,
                bgOverrideColor: "" + PanelState.bgOverrideColor,
                bgOverrideOpacity: PanelState.bgOverrideOpacity,
                clockFormatIndex: PanelState.clockFormatIndex,
                workspaceFormat: PanelState.workspaceFormat,
                fontFamilyId: PanelState.fontFamilyId,
                workspaceLimit: PanelState.workspaceLimit,
                barTargetDisplay: PanelState.barTargetDisplay,
                startButtonIconSize: PanelState.startButtonIconSize,
                workspaceDotActive: PanelState.workspaceDotActive,
                workspaceDotInactive: PanelState.workspaceDotInactive,
                workspaceFontActive: PanelState.workspaceFontActive,
                workspaceFontInactive: PanelState.workspaceFontInactive
            },
            sysRowState: {
                showSound: showSound,
                showCpu: showCpu,
                showRam: showRam,
                showTemp: showTemp,
                showNetwork: showNetwork,
                showBluetooth: showBluetooth,
                displayMode: displayMode,
                cpuColor: cpuColor,
                ramColor: ramColor,
                tempColor: tempColor,
                soundColor: soundColor,
                networkColor: networkColor,
                btColor: btColor,
                collapseDelay: collapseDelay
            },
            themeId: ThemeService.themeId,
            barLayout: Theme.barLayout
        }

        const json = JSON.stringify(rice, null, 2)
        const path = exportDir + "/" + safeName + ".json"
        exportSaver.command = ["bash", "-c",
            "mkdir -p '" + exportDir + "' && " +
            "cat > '" + path + "' << 'ZSEOF'\n" + json + "\nZSEOF"]
        exportSaver.running = true
        return path
    }

    /*
     * importRice(jsonText) — applies ALL settings from an exported rice JSON.
     * Applies PanelState, SysRowState, theme, and barLayout.
     * Both singletons save their state after import.
     */
    function importRice(jsonText) {
        try {
            const rice = JSON.parse(jsonText)

            if (rice.meta && rice.meta.format !== "zen-shell-rice-v1") {
                console.warn("[SysRowState] Unknown rice format:", rice.meta.format)
            }

            // Apply PanelState
            if (rice.panelState) {
                PanelState.applyState(JSON.stringify(rice.panelState))
                PanelState.saveState()
            }

            // Apply SysRowState
            if (rice.sysRowState) {
                applyState(JSON.stringify(rice.sysRowState))
                saveState()
            }

            // Apply theme
            if (rice.themeId) {
                ThemeService.applyTheme(rice.themeId)
            }

            // Apply bar layout
            if (rice.barLayout) {
                Theme.barLayout = rice.barLayout
            }

            importCompleted()
            return true
        } catch (e) {
            console.error("[SysRowState] Import error:", e)
            return false
        }
    }

    // List available export files
    function listExports() {
        exportLister.command = ["bash", "-c",
            "ls -1 '" + exportDir + "'/*.json 2>/dev/null | while read f; do " +
            "  name=$(basename \"$f\" .json); " +
            "  date=$(stat -c '%y' \"$f\" 2>/dev/null | cut -d. -f1); " +
            "  echo \"$name|$date|$f\"; " +
            "done"]
        exportLister.running = true
    }

    property var exportList: []

    function resetDefaults() {
        showSound = true
        showCpu = true
        showRam = true
        showTemp = true
        showNetwork = true
        showBluetooth = true
        displayMode = "icon"
        cpuColor = ""
        ramColor = ""
        tempColor = ""
        soundColor = ""
        networkColor = ""
        btColor = ""
        collapseDelay = 800
        arrowCollapsed = "❮"
        arrowExpanded = "❯"
        saveState()
    }

    // ── Persistence ──
    Process { id: saver; running: false }
    Process { id: exportSaver; running: false }

    Process {
        id: exportLister
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                const items = lines.map(l => {
                    const parts = l.split("|")
                    return { name: parts[0] || "", date: parts[1] || "", path: parts[2] || "" }
                })
                root.exportList = items
            }
        }
    }

    FileView {
        id: stateLoader
        path: root.statePath
        blockLoading: false
        onLoaded: root.applyState(this.text())
    }

    Component.onCompleted: stateLoader.reload()
}
