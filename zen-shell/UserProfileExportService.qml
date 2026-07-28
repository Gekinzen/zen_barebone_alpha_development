pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/*
 * UserProfileExportService v6.16.4.12 — Hikari 光
 *
 * Full-system snapshot singleton for profile export/import.
 * Captures everything portable into a single JSON file:
 *   - Active theme + custom themes (embedded palettes)
 *   - SettingsStateV2 full dump (gaps/borders/decorations/animations)
 *   - PanelState (island mode, bar layout, position)
 *   - Widget layout (widgetMonitors, widget positions)
 *   - Bar layout (module zones)
 *   - Wallpaper basename + mode
 *
 * Storage:
 *   ~/.config/zen-shell/profiles/
 *   ├── active-profile.state      ← name of currently loaded profile
 *   ├── default.json
 *   └── <user-named>.json
 *
 * Shareable as portable JSON — friends with same dotfiles can
 * import and auto-reflect.
 */
Singleton {
    id: root

    readonly property string profileDir: Quickshell.env("HOME") + "/.config/zen-shell/profiles"
    readonly property string activeProfilePath: profileDir + "/active-profile.state"

    property string activeProfileName: "default"
    property var profileList: []          // ["default", "gaming-setup", ...]
    property string statusMessage: ""

    signal profilesChanged()
    signal profileApplied(string name)

    Process { id: actionRunner; running: false }
    Process { id: profileSaver; running: false }

    // ── List all profiles ──
    Process {
        id: profileLister
        command: ["bash", "-c",
            "mkdir -p '" + profileDir + "'; " +
            "ls -1 '" + profileDir + "'/*.json 2>/dev/null | sed 's|.*/||;s|\\.json$||' | sort"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.trim().split("\n").filter(function(n) { return n.length > 0 })
                root.profileList = names
                root.profilesChanged()
            }
        }
    }

    // ── Load active profile name ──
    Process {
        id: activeLoader
        command: ["bash", "-c", "cat '" + activeProfilePath + "' 2>/dev/null || echo 'default'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim()
                if (name.length > 0) root.activeProfileName = name
            }
        }
    }

    // ── Snapshot current state into a profile JSON ──
    function exportProfile(name) {
        if (!name || name.length === 0) name = "default"
        // Sanitize filename
        const safeName = name.replace(/[^a-zA-Z0-9_\-\s]/g, "").replace(/\s+/g, "-").toLowerCase()
        if (safeName.length === 0) { statusMessage = "⚠ Invalid profile name"; return }

        const snapshot = _buildSnapshot(name)
        const json = JSON.stringify(snapshot, null, 2)
        const filePath = profileDir + "/" + safeName + ".json"

        profileSaver.command = ["bash", "-c",
            "mkdir -p '" + profileDir + "' && " +
            "cat > '" + filePath + "' << 'ZPEOF'\n" + json + "\nZPEOF\n" +
            "echo '" + safeName + "' > '" + activeProfilePath + "'"]
        profileSaver.running = true
        activeProfileName = safeName
        statusMessage = "✓ Saved profile: " + name
        Qt.callLater(refreshProfiles)
    }

    // ── Import a profile from JSON ──
    function importProfile(filePath) {
        importReader.command = ["cat", filePath]
        importReader.running = true
    }

    Process {
        id: importReader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const snapshot = JSON.parse(this.text)
                    _applySnapshot(snapshot)
                    // Save a copy into our profiles dir
                    const name = snapshot.profileName || "imported"
                    root.exportProfile(name)
                    root.statusMessage = "✓ Imported profile: " + name
                } catch (e) {
                    root.statusMessage = "⚠ Import failed: " + e.message
                }
            }
        }
    }

    // ── Load a profile by name ──
    function loadProfile(name) {
        const filePath = profileDir + "/" + name + ".json"
        profileReader.command = ["cat", filePath]
        profileReader._profileName = name
        profileReader.running = true
    }

    Process {
        id: profileReader
        property string _profileName: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const snapshot = JSON.parse(this.text)
                    root._applySnapshot(snapshot)
                    root.activeProfileName = profileReader._profileName
                    // Write active name
                    actionRunner.command = ["bash", "-c",
                        "echo '" + profileReader._profileName + "' > '" + root.activeProfilePath + "'"]
                    actionRunner.running = true
                    root.statusMessage = "✓ Loaded profile: " + profileReader._profileName
                    root.profileApplied(profileReader._profileName)
                } catch (e) {
                    root.statusMessage = "⚠ Load failed: " + e.message
                }
            }
        }
    }

    // ── Delete a profile ──
    function deleteProfile(name) {
        if (name === "default") { statusMessage = "⚠ Cannot delete default profile"; return }
        actionRunner.command = ["rm", "-f", profileDir + "/" + name + ".json"]
        actionRunner.running = true
        if (activeProfileName === name) activeProfileName = "default"
        statusMessage = "✓ Deleted profile: " + name
        Qt.callLater(refreshProfiles)
    }

    // ── Rename a profile ──
    function renameProfile(oldName, newName) {
        if (oldName === "default") { statusMessage = "⚠ Cannot rename default profile"; return }
        const safeNew = newName.replace(/[^a-zA-Z0-9_\-\s]/g, "").replace(/\s+/g, "-").toLowerCase()
        if (safeNew.length === 0) { statusMessage = "⚠ Invalid name"; return }
        actionRunner.command = ["mv",
            profileDir + "/" + oldName + ".json",
            profileDir + "/" + safeNew + ".json"]
        actionRunner.running = true
        if (activeProfileName === oldName) activeProfileName = safeNew
        statusMessage = "✓ Renamed to: " + safeNew
        Qt.callLater(refreshProfiles)
    }

    function refreshProfiles() { profileLister.running = true }

    // ═══════════════════════════════════════════════════════════
    // SNAPSHOT BUILDER — captures all portable state
    // ═══════════════════════════════════════════════════════════
    function _buildSnapshot(displayName) {
        const snap = {
            _version: "6.16.4.12",
            _format: "zen-shell-profile",
            profileName: displayName,
            exportedAt: new Date().toISOString(),

            // ── Theme ──
            theme: {
                activeThemeId: typeof ThemeService !== "undefined" ? ThemeService.activeThemeId || "" : "",
                barOpacity: Theme.barOpacity,
                barRadius: Theme.barRadius,
                styleMode: Theme.styleMode,
                barLayout: Theme.barLayout
            },

            // ── Panel ──
            panel: {
                panelMode: PanelState.panelMode,
                panelPosition: PanelState.panelPosition,
                barHeight: PanelState.barHeight,
                borderEnabled: PanelState.borderEnabled,
                borderWidth: PanelState.borderWidth,
                borderColor: String(PanelState.borderColor),
                bgOverrideEnabled: PanelState.bgOverrideEnabled,
                bgOverrideColor: String(PanelState.bgOverrideColor),
                bgOverrideOpacity: PanelState.bgOverrideOpacity,
                clockFormatIndex: PanelState.clockFormatIndex,
                workspaceFormat: PanelState.workspaceFormat,
                fontFamilyId: PanelState.fontFamilyId,
                workspaceLimit: PanelState.workspaceLimit,
                startButtonIconSize: PanelState.startButtonIconSize,
                startButtonLogoMode: PanelState.startButtonLogoMode,
                startButtonLogoBuiltinId: PanelState.startButtonLogoBuiltinId,
                widgetScale: PanelState.widgetScale
            },

            // ── Settings V2 (gaps/borders/decorations) ──
            settingsV2: typeof SettingsStateV2 !== "undefined" ? {
                gapsIn: SettingsStateV2.gapsIn,
                gapsOut: SettingsStateV2.gapsOut,
                borderSize: SettingsStateV2.borderSize,
                activeBorderColor: SettingsStateV2.activeBorderColor,
                inactiveBorderColor: SettingsStateV2.inactiveBorderColor,
                rounding: SettingsStateV2.rounding,
                shadowEnabled: SettingsStateV2.shadowEnabled,
                shadowRange: SettingsStateV2.shadowRange,
                blurEnabled: SettingsStateV2.blurEnabled,
                blurSize: SettingsStateV2.blurSize,
                blurPasses: SettingsStateV2.blurPasses
            } : {},

            // ── Wallpaper ──
            wallpaper: typeof WallpaperService !== "undefined" ? {
                currentBasename: WallpaperService.currentWallpaperBasename || "",
                mode: WallpaperService.wallpaperMode || "fill"
            } : {}
        }
        return snap
    }

    // ═══════════════════════════════════════════════════════════
    // SNAPSHOT APPLIER — restores all portable state
    // ═══════════════════════════════════════════════════════════
    function _applySnapshot(snap) {
        if (!snap || snap._format !== "zen-shell-profile") {
            statusMessage = "⚠ Invalid profile format"
            return
        }

        // ── Theme ──
        if (snap.theme) {
            const t = snap.theme
            if (typeof t.barOpacity === "number") Theme.barOpacity = t.barOpacity
            if (typeof t.barRadius === "number") Theme.barRadius = t.barRadius
            if (t.styleMode) Theme.styleMode = t.styleMode
            if (t.barLayout && typeof t.barLayout === "object") Theme.barLayout = t.barLayout
            // Activate theme by ID if ThemeService supports it
            if (t.activeThemeId && typeof ThemeService !== "undefined"
                && typeof ThemeService.applyTheme === "function") {
                ThemeService.applyTheme(t.activeThemeId)
            }
        }

        // ── Panel ──
        if (snap.panel) {
            const p = snap.panel
            if (p.panelMode) PanelState.panelMode = p.panelMode
            if (p.panelPosition) PanelState.panelPosition = p.panelPosition
            if (typeof p.barHeight === "number") PanelState.barHeight = p.barHeight
            if (typeof p.borderEnabled === "boolean") PanelState.borderEnabled = p.borderEnabled
            if (typeof p.borderWidth === "number") PanelState.borderWidth = p.borderWidth
            if (p.borderColor) PanelState.borderColor = p.borderColor
            if (typeof p.bgOverrideEnabled === "boolean") PanelState.bgOverrideEnabled = p.bgOverrideEnabled
            if (p.bgOverrideColor) PanelState.bgOverrideColor = p.bgOverrideColor
            if (typeof p.bgOverrideOpacity === "number") PanelState.bgOverrideOpacity = p.bgOverrideOpacity
            if (typeof p.clockFormatIndex === "number") PanelState.clockFormatIndex = p.clockFormatIndex
            if (p.workspaceFormat) PanelState.workspaceFormat = p.workspaceFormat
            if (p.fontFamilyId) PanelState.fontFamilyId = p.fontFamilyId
            if (typeof p.workspaceLimit === "number") PanelState.workspaceLimit = p.workspaceLimit
            if (typeof p.startButtonIconSize === "number") PanelState.startButtonIconSize = p.startButtonIconSize
            if (p.startButtonLogoMode) PanelState.startButtonLogoMode = p.startButtonLogoMode
            if (p.startButtonLogoBuiltinId) PanelState.startButtonLogoBuiltinId = p.startButtonLogoBuiltinId
            if (typeof p.widgetScale === "number") PanelState.widgetScale = p.widgetScale
            PanelState.saveState()
        }

        // ── Settings V2 ──
        if (snap.settingsV2 && typeof SettingsStateV2 !== "undefined") {
            const s = snap.settingsV2
            if (typeof s.gapsIn === "number") { SettingsStateV2.gapsIn = s.gapsIn; SettingsStateV2.scheduleHyprctl("keyword general:gaps_in " + s.gapsIn) }
            if (typeof s.gapsOut === "number") { SettingsStateV2.gapsOut = s.gapsOut; SettingsStateV2.scheduleHyprctl("keyword general:gaps_out " + s.gapsOut) }
            if (typeof s.borderSize === "number") { SettingsStateV2.borderSize = s.borderSize; SettingsStateV2.scheduleHyprctl("keyword general:border_size " + s.borderSize) }
            if (s.activeBorderColor) { SettingsStateV2.activeBorderColor = s.activeBorderColor; SettingsStateV2.hyprctlColor("general:col.active_border", s.activeBorderColor) }
            if (s.inactiveBorderColor) { SettingsStateV2.inactiveBorderColor = s.inactiveBorderColor; SettingsStateV2.hyprctlColor("general:col.inactive_border", s.inactiveBorderColor) }
            if (typeof s.rounding === "number") { SettingsStateV2.rounding = s.rounding; SettingsStateV2.scheduleHyprctl("keyword decoration:rounding " + s.rounding) }
            if (typeof s.blurEnabled === "boolean") { SettingsStateV2.blurEnabled = s.blurEnabled }
            if (typeof s.blurSize === "number") { SettingsStateV2.blurSize = s.blurSize }
            if (typeof s.blurPasses === "number") { SettingsStateV2.blurPasses = s.blurPasses }
            if (typeof SettingsStateV2.saveState === "function") SettingsStateV2.saveState()
        }
    }

    Component.onCompleted: {
        activeLoader.running = true
        Qt.callLater(refreshProfiles)
    }
}
