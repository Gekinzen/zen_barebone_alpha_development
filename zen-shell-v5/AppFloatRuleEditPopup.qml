import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * AppFloatRuleEditPopup v7.0.0-beta.1-hf82v
 *
 * Modal popup to edit per-app float rule overrides:
 *   - Width / Height as %
 *   - Center toggle
 *   - Monitor (auto / specific name)
 *
 * Invoked from AppFloatRulesPage's per-row Edit button. Reads current
 * values from WindowRulesService.ruleFor(wmClass), commits changes
 * via WindowRulesService.updateRule(...).
 *
 * Live preview: the size sliders update a small preview rectangle
 * inside the popup so you can see the proportional shape before
 * applying.
 */
Dialog {
    id: root

    // ── External inputs ──
    property string wmClass: ""
    property string appLabel: ""
    property string appIcon: ""

    // ── Editable state (mirrors WindowRulesService entry) ──
    property int editW: 65
    property int editH: 70
    property bool editCenter: true
    property string editMonitor: "auto"

    // ── Available monitors (populated when opened) ──
    property var availableMonitors: ["auto"]

    title: "Edit float rule  ·  " + appLabel
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 460

    standardButtons: Dialog.Cancel | Dialog.Apply | Dialog.Reset

    function _load() {
        const r = WindowRulesService.ruleFor(wmClass)
        if (r) {
            editW = r.w || 65
            editH = r.h || 70
            editCenter = (r.center !== false)
            editMonitor = r.monitor || "auto"
        }
        // Probe monitors
        monProbe.running = false
        monProbe.running = true
    }

    onOpened: _load()

    Process {
        id: monProbe
        command: ["bash", "-c", "hyprctl monitors -j 2>/dev/null | grep -oP '\"name\":\\s*\"\\K[^\"]+' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                root.availableMonitors = ["auto"].concat(lines)
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 14
        width: parent.width

        // ── Live preview ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            radius: 8
            color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.06)
            border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.15)
            border.width: 1
            // Monitor proxy
            Rectangle {
                id: monitorBox
                anchors.centerIn: parent
                width: parent.width - 24
                height: parent.height - 24
                color: "transparent"
                border.color: Qt.rgba(ThemeService.fg.r, ThemeService.fg.g, ThemeService.fg.b, 0.25)
                border.width: 1
                radius: 4

                // Floating window proxy (scaled to editW/editH %)
                Rectangle {
                    width: monitorBox.width * root.editW / 100
                    height: monitorBox.height * root.editH / 100
                    radius: 4
                    color: Qt.rgba(ThemeService.blue.r, ThemeService.blue.g,
                                   ThemeService.blue.b, 0.30)
                    border.color: ThemeService.blue
                    border.width: 1
                    // Center mode vs not
                    anchors.centerIn: root.editCenter ? parent : undefined
                    x: root.editCenter ? undefined : 8
                    y: root.editCenter ? undefined : 8
                    Behavior on width  { NumberAnimation { duration: 150 } }
                    Behavior on height { NumberAnimation { duration: 150 } }
                }
            }
        }

        // ── Width slider ──
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Width"; color: ThemeService.fg; font.pixelSize: 13
                Layout.preferredWidth: 70
            }
            Slider {
                Layout.fillWidth: true
                from: 10; to: 100; stepSize: 1
                value: root.editW
                onValueChanged: root.editW = Math.round(value)
            }
            Text {
                text: root.editW + "%"
                color: ThemeService.fg
                font.pixelSize: 13
                font.bold: true
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignRight
            }
        }

        // ── Height slider ──
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Height"; color: ThemeService.fg; font.pixelSize: 13
                Layout.preferredWidth: 70
            }
            Slider {
                Layout.fillWidth: true
                from: 10; to: 100; stepSize: 1
                value: root.editH
                onValueChanged: root.editH = Math.round(value)
            }
            Text {
                text: root.editH + "%"
                color: ThemeService.fg
                font.pixelSize: 13
                font.bold: true
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignRight
            }
        }

        // ── Center toggle ──
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Center on screen"
                color: ThemeService.fg
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            Switch {
                checked: root.editCenter
                onToggled: root.editCenter = checked
            }
        }

        // ── Monitor picker ──
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Monitor"
                color: ThemeService.fg
                font.pixelSize: 13
                Layout.preferredWidth: 70
            }
            ComboBox {
                Layout.fillWidth: true
                model: root.availableMonitors
                currentIndex: Math.max(0, root.availableMonitors.indexOf(root.editMonitor))
                onActivated: root.editMonitor = model[currentIndex]
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Tip: % units automatically respect monitor scale (1.25, 1.50, etc.). " +
                  "Use 'auto' monitor to open on the focused screen."
            color: ThemeService.alpha(ThemeService.fg, 0.65)
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }

    onApplied: {
        WindowRulesService.updateRule(wmClass, {
            "w": editW, "h": editH,
            "center": editCenter, "monitor": editMonitor
        }, appLabel, appIcon)
    }

    onReset: {
        // Reset to smart defaults for this class
        const sz = WindowRulesService.smartSizeFor(wmClass)
        root.editW = sz.w
        root.editH = sz.h
        root.editCenter = true
        root.editMonitor = "auto"
    }
}
