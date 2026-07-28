import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * DefaultAppsPage v7.0.0-beta.1-hf82n — Karui (軽い)
 *
 * Settings page for picking default applications per category
 * (browser, PDF, video, image, music, email, terminal, text-editor,
 * archive, file-manager).
 *
 * Visual: matches GeneralPage conventions — DenshoPageHeader →
 * HMSection → HMRow with a ZenDropdown picker on the right.
 *
 * Backend: MimeAppsService singleton handles xdg-mime calls.
 * Available app list comes from AppLauncherService.allApps (already
 * filters NoDisplay=true entries + handles XDG_CURRENT_DESKTOP
 * visibility).
 *
 * Wala tayong babawasan — additive page; sidebar entry added in
 * ZenSettings.qml under PRODUCTIVITY section.
 */
ScrollView {
    id: rootView
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth

    // Build a filtered app list for the dropdowns. We exclude:
    //   - apps with noDisplay=true (intentionally hidden)
    //   - apps with empty exec (broken .desktop files)
    //   - apps with no name fallback (corrupted entries)
    //
    // Sorted alphabetically by name for the dropdown.
    //
    // hf82r FIX: AppLauncherService exposes `apps`, NOT `allApps`.
    // Pre-hf82r I had this wrong → dropdowns showed empty (none) for
    // every category because pickableApps was always [].
    readonly property var pickableApps: {
        const apps = (AppLauncherService.apps || []).slice()
        const filtered = apps.filter(a =>
            a && !a.noDisplay && a.name && a.exec && a.id)
        filtered.sort((a, b) =>
            (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()))
        return filtered
    }

    // Build the dropdown model: an array of display names. The
    // currentIndex maps back to pickableApps by index.
    readonly property var pickerModel: {
        const out = ["(none)"]
        for (let i = 0; i < pickableApps.length; i++) {
            out.push(pickableApps[i].name)
        }
        return out
    }

    function _appDesktopFileFor(category) {
        // Convert MimeAppsService's currentDefaults[category] (e.g.
        // "firefox.desktop") to the index in pickerModel + 0 = (none).
        const current = (MimeAppsService.currentDefaults || {})[category] || ""
        if (!current) return 0
        for (let i = 0; i < pickableApps.length; i++) {
            const id = pickableApps[i].id
            // Quickshell's DesktopEntry id sometimes lacks the
            // ".desktop" suffix; match either way.
            if (id === current
                || (id + ".desktop") === current
                || id === current.replace(/\.desktop$/, "")) {
                return i + 1
            }
        }
        return 0
    }

    ColumnLayout {
        // hf82r: match GeneralPage spacing exactly — x:24 y:20 spacing:18
        // (was: only `width: availableWidth - 48 ; spacing: 16` so the
        //  page stuck to the top and titles felt wider than General).
        width: rootView.availableWidth - 48
        x: 24
        y: 20
        spacing: 18

        DenshoPageHeader {
            Layout.fillWidth: true
            title: "Default Applications"
            subtitle: "Pick the app that opens each file type / URL scheme"
            kanji: "既定"
            romaji: "Kitei"
        }

        // ═════════════════════════════════════════════════════════
        // Status row — last action feedback
        // ═════════════════════════════════════════════════════════
        Rectangle {
            visible: MimeAppsService.lastAction.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 8
            color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.06)
            border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.12)
            border.width: 1
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: MimeAppsService.lastAction
                color: ThemeService.fg
                font.pixelSize: 13
            }
        }

        // ═════════════════════════════════════════════════════════
        // Per-category picker
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Default Applications"
            subtitle: "Backed by ~/.config/mimeapps.list — uses xdg-mime"

            // We instantiate the same delegate shape for each known
            // category. Categories live in MimeAppsService.categoryAnchors
            // so adding a new category later is just one map entry +
            // a Repeater iteration here.
            Repeater {
                model: ["browser", "pdf", "video", "image", "music",
                        "email", "terminal", "text-editor", "archive",
                        "file-manager"]

                delegate: HMRow {
                    id: catRow
                    required property string modelData
                    required property int index

                    label: (MimeAppsService.categoryLabels || {})[modelData] || modelData
                    description: (MimeAppsService.categoryDescriptions || {})[modelData] || ""
                    separator: index > 0

                    ZenDropdown {
                        width: 240
                        model: rootView.pickerModel
                        currentIndex: rootView._appDesktopFileFor(catRow.modelData)
                        onActivated: {
                            if (currentIndex === 0) {
                                MimeAppsService.clearDefault(catRow.modelData)
                            } else {
                                const app = rootView.pickableApps[currentIndex - 1]
                                if (app) {
                                    // xdg-mime expects the .desktop
                                    // suffix; append if missing.
                                    let id = app.id
                                    if (!id.endsWith(".desktop")) id += ".desktop"
                                    MimeAppsService.setDefault(catRow.modelData, id)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════
        // Refresh + bulk actions
        // ═════════════════════════════════════════════════════════
        HMSection {
            title: "Maintenance"
            subtitle: "Refresh the cache, or test that your defaults work"

            HMRow {
                label: "Refresh defaults"
                description: "Re-read ~/.config/mimeapps.list to pick up external changes"
                                ZenButton {
                    text: "Refresh"
                    onClicked: MimeAppsService._refreshAll()
                }
            }

            HMRow {
                separator: true
                label: "Test browser default"
                description: "Opens https://hypr.land in your configured browser"
                                ZenButton {
                    text: "Test"
                    onClicked: tester.run("https://hypr.land")
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }

    // Test launcher — uses xdg-open which respects the same mimeapps
    // we just edited, so it's a true round-trip verification.
    QtObject {
        id: tester
        function run(url) {
            testProc.command = ["xdg-open", url]
            testProc.running = false
            testProc.running = true
        }
    }
    Process { id: testProc; running: false }
}
