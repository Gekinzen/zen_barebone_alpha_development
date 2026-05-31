import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * AppFloatRulesPage v7.0.0-beta.1-hf82n — Karui (軽い)
 *
 * Settings page listing all installed .desktop apps with a per-app
 * "Float window" toggle on the right side. Toggling writes a
 * `windowrulev2 = float, class:^(name)$` line to
 * ~/.config/hypr/modules/zen-window-rules.conf and runs hyprctl
 * reload so the rule applies immediately.
 *
 * App list: AppLauncherService.allApps (which scans
 * /usr/share/applications, ~/.local/share/applications, etc. via
 * Quickshell.DesktopEntries). Filtered to GUI apps (noDisplay=false).
 *
 * Search box at the top filters live.
 *
 * Visual: matches GeneralPage conventions (DenshoPageHeader,
 * HMSection, HMRow, HMSwitch).
 *
 * Wala tayong babawasan — additive page; sidebar entry added in
 * ZenSettings.qml under INPUT & DISPLAY section.
 */
ScrollView {
    id: rootView
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

    property string searchQuery: ""

    // Filter + sort the app list.
    //
    // - noDisplay=true → hidden by .desktop intent
    // - empty name/exec → corrupted entry, skip
    // - searchQuery → fuzzy match on name + id (case-insensitive)
    //
    // Sorted: floating apps first (so user sees what's currently on),
    // then alphabetical.
    //
    // hf82r FIX: AppLauncherService exposes `apps`, NOT `allApps`.
    // Pre-hf82r the page showed "Found 0 apps" because the source
    // property was undefined → filter ran on [].
    readonly property var filteredApps: {
        const all = (AppLauncherService.apps || []).slice()
        const q = searchQuery.toLowerCase()
        let filtered = all.filter(a => {
            if (!a || !a.name || !a.exec) return false
            if (a.noDisplay) return false
            if (q.length === 0) return true
            const name = (a.name || "").toLowerCase()
            const id = (a.id || "").toLowerCase()
            return name.indexOf(q) >= 0 || id.indexOf(q) >= 0
        })
        filtered.sort((a, b) => {
            // Float-on apps first
            const aFloat = WindowRulesService.isFloating(_classFor(a))
            const bFloat = WindowRulesService.isFloating(_classFor(b))
            if (aFloat && !bFloat) return -1
            if (!aFloat && bFloat) return 1
            return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
        })
        return filtered
    }

    // Determine the WM class string we'll use for the windowrulev2
    // rule. Order of preference:
    //   1. The .desktop file's StartupWMClass field (not currently
    //      surfaced by AppLauncherService.allApps' adapter — would
    //      need to extend it; for now we fall back)
    //   2. The .desktop file's id with .desktop stripped (common
    //      convention — e.g. "firefox.desktop" → class is "firefox")
    //   3. The first word of Exec (last-resort heuristic)
    //
    // This isn't 100% reliable across every app, but covers the
    // ~80% case. Users with edge-case apps can still hand-craft
    // rules in their own conf file.
    function _classFor(app) {
        if (!app) return ""
        if (app.id) {
            // Strip .desktop suffix if present
            return app.id.replace(/\.desktop$/, "")
        }
        const ex = (app.exec || "").trim()
        if (ex) {
            // Take the basename of the first token
            const first = ex.split(/\s+/)[0]
            return first.split("/").pop()
        }
        return ""
    }

    ColumnLayout {
        // hf82r: match GeneralPage spacing exactly — x:24 y:20 spacing:18
        width: rootView.availableWidth - 48
        x: 24
        y: 20
        spacing: 18

        DenshoPageHeader {
            Layout.fillWidth: true
            title: "Window Rules — App Float"
            subtitle: "Toggle individual apps to always open as floating windows"
            kanji: "窓規則"
            romaji: "Madokisoku"
        }

        // ═════════════════════════════════════════════════════════
        // Search + count
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Apps"
            subtitle: {
                const total = (AppLauncherService.apps || []).length
                const floating = (WindowRulesService.floatRules || []).length
                return "Found " + total + " apps • " + floating + " set to float"
            }

            HMRow {
                label: "Search"
                description: "Filter by app name or id"
                TextField {
                    width: 240
                    placeholderText: "e.g. firefox"
                    text: rootView.searchQuery
                    onTextChanged: rootView.searchQuery = text
                    color: ThemeService.fg
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(ThemeService.fg.r,
                                       ThemeService.fg.g,
                                       ThemeService.fg.b, 0.06)
                        border.color: parent && parent.activeFocus
                            ? ThemeService.blue
                            : Qt.rgba(ThemeService.fg.r,
                                      ThemeService.fg.g,
                                      ThemeService.fg.b, 0.15)
                        border.width: 1
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // App list with per-app HMSwitch
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Float toggles"
            subtitle: "Apps marked ON open as floating windows. Hyprland reloads automatically on toggle."

            Repeater {
                model: rootView.filteredApps

                delegate: HMRow {
                    id: appRow
                    required property var modelData
                    required property int index

                    readonly property string wmClass: rootView._classFor(modelData)
                    // hf82s: track floating state EXPLICITLY in this row so
                    // the HMSwitch.checked binding doesn't get broken when
                    // HMSwitch internally toggles itself on click.
                    //
                    // hf82v: signal name changed to onFloatRulesChanged
                    // (floatRules is now an array of rule objects, not just
                    // strings — the property name changed in WindowRulesService).
                    property bool rowFloating: WindowRulesService.isFloating(wmClass)
                    property var rowRule: WindowRulesService.ruleFor(wmClass)

                    Connections {
                        target: WindowRulesService
                        function onFloatRulesChanged() {
                            appRow.rowFloating =
                                WindowRulesService.isFloating(appRow.wmClass)
                            appRow.rowRule =
                                WindowRulesService.ruleFor(appRow.wmClass)
                        }
                    }

                    label: modelData.name || "(unnamed)"
                    description: {
                        let s = "Class: " + wmClass
                        if (rowFloating && rowRule) {
                            s += "  •  " + rowRule.w + "% × " + rowRule.h + "%"
                            if (rowRule.center !== false) s += ", centered"
                        }
                        if (modelData.comment) s += "  •  " + modelData.comment
                        return s
                    }
                    separator: index > 0

                    RowLayout {
                        spacing: 6

                        // Edit button — only enabled when float is ON
                        Rectangle {
                            width: 28; height: 28; radius: 6
                            opacity: appRow.rowFloating ? 1.0 : 0.35
                            color: editMa.containsMouse && appRow.rowFloating
                                ? Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                          ThemeService.fg.b, 0.12)
                                : "transparent"
                            border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g,
                                                  ThemeService.fg.b, 0.15)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "\uf013"   // gear icon (Font Awesome)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }
                            MouseArea {
                                id: editMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: appRow.rowFloating
                                    ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                enabled: appRow.rowFloating
                                onClicked: {
                                    editPopup.wmClass = appRow.wmClass
                                    editPopup.appLabel = appRow.modelData.name || appRow.wmClass
                                    editPopup.appIcon = appRow.modelData.icon || ""
                                    editPopup.open()
                                }
                            }
                        }

                        HMSwitch {
                            checked: appRow.rowFloating
                            onToggled: {
                                // Optimistic update so the switch flips visually
                                // even before the file write + reload completes.
                                appRow.rowFloating = checked
                                WindowRulesService.setFloating(
                                    appRow.wmClass, checked,
                                    appRow.modelData.name,
                                    appRow.modelData.icon)
                            }
                        }
                    }
                }
            }

            HMRow {
                visible: rootView.filteredApps.length === 0
                label: "No apps match"
                description: rootView.searchQuery.length > 0
                    ? "Try clearing the search box."
                    : "Install some .desktop apps under /usr/share/applications or ~/.local/share/applications."
            }
        }

        // ═════════════════════════════════════════════════════════
        // Bulk actions
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Maintenance"

            HMRow {
                label: "Clear all float rules"
                description: "Removes every rule from ~/.config/hypr/modules/zen-window-rules.conf"
                                ZenButton {
                    text: "Clear all"
                    onClicked: WindowRulesService.clearAll()
                }
            }

            HMRow {
                separator: true
                label: "Refresh from disk"
                description: "Re-read the conf file (catches manual edits)"
                                ZenButton {
                    text: "Refresh"
                    onClicked: WindowRulesService._migrateFromConf()
                }
            }

            HMRow {
                separator: true
                label: "Reload Hyprland"
                description: "Manual hyprctl reload — auto-fires after every toggle, but this is a safety button"
                                ZenButton {
                    text: "Reload"
                    onClicked: reloadProc.running = true
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }

    Process {
        id: reloadProc
        running: false
        command: ["hyprctl", "reload"]
    }

    // hf82v: Per-app override popup. Opened by Edit button on each row.
    AppFloatRuleEditPopup {
        id: editPopup
    }
}
