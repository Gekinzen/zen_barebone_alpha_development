import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * ThemesPage v6 — Full theme management UI
 * - Dropdown shows all available themes (builtin + custom)
 * - Live swatch preview
 * - Import: file picker → copy to custom/
 * - Export: save current theme to external path
 * - Delete: only custom themes (builtin protected)
 */
ScrollView {
    id: root
    clip: true

    Process {
        id: filePicker
        running: false
        property string mode: "import"
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim()
                if (!path) return
                if (filePicker.mode === "import") {
                    ThemeService.importTheme(path)
                } else if (filePicker.mode === "export") {
                    ThemeService.exportCurrentTheme(path)
                }
            }
        }
    }

    function openImportPicker() {
        filePicker.mode = "import"
        filePicker.command = ["bash", "-c",
            "if command -v zenity > /dev/null; then " +
            "  zenity --file-selection --title='Import Theme JSON' --file-filter='*.json' 2>/dev/null; " +
            "elif command -v kdialog > /dev/null; then " +
            "  kdialog --getopenfilename '" + Quickshell.env("HOME") + "' '*.json' 2>/dev/null; " +
            "fi"]
        filePicker.running = true
    }

    function openExportPicker() {
        filePicker.mode = "export"
        filePicker.command = ["bash", "-c",
            "if command -v zenity > /dev/null; then " +
            "  zenity --file-selection --save --confirm-overwrite --title='Export Theme' " +
            "    --filename='" + ThemeService.themeId + ".json' 2>/dev/null; " +
            "elif command -v kdialog > /dev/null; then " +
            "  kdialog --getsavefilename '" + Quickshell.env("HOME") + "/" + ThemeService.themeId + ".json' '*.json' 2>/dev/null; " +
            "fi"]
        filePicker.running = true
    }

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        // Header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Themes"
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                text: "Switch, import, export color themes"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        ControlCenterBanner {
            feature: "Advanced Theme Editing"
            description: "Per-app color tuning, bezier/curves, palette editor in Hypr Control Center"
        }

        // ── Theme Switcher ──
        SettingsSection {
            title: "Current Theme"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 12
                    color: ThemeService.bg1
                    border.width: 2
                    border.color: ThemeService.blue

                    // Theme color preview — 4 accent dots instead of broken icon
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: 4

                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.blue }
                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.green }
                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.red }
                        Rectangle { width: 18; height: 18; radius: 4; color: ThemeService.purple }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: ThemeService.themeName
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }
                    Text {
                        text: ThemeService.themeDescription || ("ID: " + ThemeService.themeId)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    Text {
                        text: ThemeService.currentIsBuiltin ? "● Builtin theme" : "◆ Custom theme"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.currentIsBuiltin ? ThemeService.green : ThemeService.orange
                    }
                }
            }

            // Theme picker dropdown
            // v6.16.4.12.6.6: disabled when Matugen is ON because the
            // wallpaper drives the theme — manually picking would just
            // get overwritten on the next wallpaper switch (or even
            // immediately, since matugen runs against the current
            // wallpaper as soon as the toggle is flipped). Hint shown
            // below the dropdown when disabled.
            SettingRow {
                label: "Switch Theme"
                description: ThemeService.matugenEnabled
                    ? "Disabled — Matugen is ON, theme is wallpaper-driven. Toggle Matugen OFF below to pick manually."
                    : ("Found " + ThemeService.availableThemes.length + " themes (" +
                       ThemeService.availableThemes.filter(t => t.is_builtin).length + " builtin, " +
                       ThemeService.availableThemes.filter(t => !t.is_builtin).length + " custom)")

                RowLayout {
                    spacing: 8

                    // v6.16.4.12.6.14: Migrated to ZenDropdown — rich entry
                    // shape with built-in/custom sections, color swatches
                    // taken from each theme's primary color, and per-item
                    // disabled state for the matugen-auto entry when the
                    // toggle is OFF.
                    //
                    // Wala tayo babawasan: behavior preserved exactly:
                    //   - same disabled binding (matugenEnabled gates everything)
                    //   - same currentIndex resolution
                    //   - same onActivated → applyTheme() flow
                    ZenDropdown {
                        id: themeCombo
                        Layout.preferredWidth: 260
                        enabled: !ThemeService.matugenEnabled
                        opacity: enabled ? 1.0 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        model: {
                            const out = []
                            const themes = ThemeService.availableThemes || []
                            const builtins = themes.filter(t => t.is_builtin)
                            const customs  = themes.filter(t => !t.is_builtin)
                            if (builtins.length > 0) {
                                out.push({ kind: "section", text: "Built-in" })
                                for (var i = 0; i < builtins.length; i++) {
                                    const t = builtins[i]
                                    out.push({
                                        text: t.name,
                                        value: t.id,
                                        swatch: (t.colors && t.colors.blue)
                                                ? t.colors.blue : ""
                                    })
                                }
                            }
                            if (customs.length > 0) {
                                out.push({ kind: "section", text: "Custom" })
                                for (var j = 0; j < customs.length; j++) {
                                    const c = customs[j]
                                    out.push({
                                        text: c.name,
                                        value: c.id,
                                        swatch: (c.colors && c.colors.blue)
                                                ? c.colors.blue : ""
                                    })
                                }
                            }
                            return out
                        }
                        currentIndex: {
                            // Need to translate from the ID-indexed
                            // availableThemes array to our model index, since
                            // section headers shift the indices.
                            const themes = ThemeService.availableThemes || []
                            const id = ThemeService.themeId
                            var ix = 0
                            const builtins = themes.filter(t => t.is_builtin)
                            const customs  = themes.filter(t => !t.is_builtin)
                            if (builtins.length > 0) ix++   // section header
                            for (var i = 0; i < builtins.length; i++) {
                                if (builtins[i].id === id) return ix
                                ix++
                            }
                            if (customs.length > 0) ix++    // section header
                            for (var j = 0; j < customs.length; j++) {
                                if (customs[j].id === id) return ix
                                ix++
                            }
                            return 0
                        }
                        onSelected: (entry) => {
                            const theme = (ThemeService.availableThemes || [])
                                .find(t => t.id === entry.value)
                            if (theme) ThemeService.applyTheme(theme)
                        }
                    }

                    Button {
                        text: "\uf021"
                        font.family: "JetBrainsMono Nerd Font"
                        enabled: !ThemeService.matugenEnabled
                        opacity: enabled ? 1.0 : 0.45
                        onClicked: ThemeService.refreshThemeList()
                        ToolTip.visible: hovered
                        ToolTip.text: enabled ? "Refresh list"
                                              : "Disabled while Matugen is ON"
                    }
                }
            }
        }

        // ─── v6.16.4.12.6: Matugen (Material You from wallpaper) ───
        SettingsSection {
            title: "Matugen — Wallpaper-Driven Theme"
            subtitle: ThemeService.matugenAvailable
                      ? "When ON, every wallpaper switch regenerates the theme from its dominant colors. When OFF, your selected theme is preserved."
                      : "matugen binary not detected. Install with: paru -S matugen-bin (or yay -S matugen)"

            SettingRow {
                label: "Auto-theme from wallpaper"
                description: ThemeService.matugenEnabled
                             ? "ON — wallpaper drives the theme"
                             : "OFF — your selected theme is preserved across wallpaper changes"

                RowLayout {
                    spacing: 12

                    // Native QtQuick.Controls Switch — matches the look of
                    // other toggles on this page without needing the HMSwitch
                    // component (which lives in the Hypr Control Center side).
                    Switch {
                        id: matugenSwitch
                        checked: ThemeService.matugenEnabled
                        enabled: ThemeService.matugenAvailable
                        onToggled: ThemeService.setMatugenEnabled(checked)
                    }

                    Button {
                        text: "\uf021  Re-apply now"
                        font.family: "JetBrainsMono Nerd Font"
                        enabled: ThemeService.matugenEnabled
                              && ThemeService.matugenAvailable
                              && WallpaperServiceV5.currentWallpaper.length > 0
                        onClicked: ThemeService.applyMatugenFromWallpaper(
                                       WallpaperServiceV5.currentWallpaper)
                        ToolTip.visible: hovered
                        ToolTip.text: enabled
                                      ? "Regenerate theme from current wallpaper"
                                      : "Enable Matugen + set a wallpaper first"
                    }
                }
            }

            // Status line — surfaces matugen probe / run results
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: ThemeService.matugenStatus.length > 0 ? 28 : 0
                visible: ThemeService.matugenStatus.length > 0
                radius: 6
                color: ThemeService.alpha(ThemeService.purple, 0.12)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.purple, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: ThemeService.matugenStatus
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: ThemeService.fg
                }
            }

            // v6.16.4.12.6.7: Wallpaper-hook activity meter. Lets Paul
            // verify that switching wallpapers actually triggers the
            // Matugen auto-regen path. Counter increments every time
            // shell.qml's WallpaperServiceV5.wallpaperApplied Connections
            // fires — regardless of toggle state — so a stuck-at-zero
            // counter means the hook itself isn't wired (probably needs
            // a full shell restart, not just `reloadThemeFromFile`).
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                radius: 6
                color: ThemeService.alpha(ThemeService.fg, 0.04)
                border.width: 1
                border.color: ThemeService.alpha(ThemeService.fg, 0.10)

                Text {
                    anchors.centerIn: parent
                    text: ThemeService.wallpaperHookCount === 0
                          ? "Wallpaper hook: not fired yet (try switching wallpapers)"
                          : ("Wallpaper hook fired " + ThemeService.wallpaperHookCount
                             + "× · last: " + ThemeService.wallpaperHookLastAt
                             + (ThemeService.wallpaperHookLastPath.length > 0
                                ? " · " + ThemeService.wallpaperHookLastPath.split("/").pop()
                                : ""))
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: ThemeService.wallpaperHookCount === 0
                           ? ThemeService.grey1
                           : ThemeService.green
                }
            }
        }

        // ── Palette ──
        // v6.16.4.12.6.1: was "Palette Preview" (read-only Rectangles).
        // Now editable — single source of truth for palette edits, as the
        // v6.16.4.11.2 changelog originally promised. Each swatch opens
        // a small hex-input popup; edits hit ThemeService.setAccent() so
        // the bar repaints live. To persist, hit "Save as custom profile"
        // at the bottom — that writes through ThemeService.saveAsCustomTheme()
        // which cascades terminal + swaync regen scripts.
        SettingsSection {
            id: paletteSection
            title: "Palette Editor"
            subtitle: ThemeService.matugenEnabled
                ? "Disabled — Matugen is ON. Manual edits would be overwritten on the next wallpaper switch. Toggle Matugen OFF above to edit colors directly."
                : "Click any color to edit. Live-preview applies instantly; save below to persist."

            // Section-level enabled gates the entire palette UI when
            // Matugen is in charge of the colors.
            enabled: !ThemeService.matugenEnabled
            opacity: enabled ? 1.0 : 0.5
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // Tracks whether the user has touched any color since last save.
            // Save button is disabled until an edit happens, then re-disables
            // after a successful save.
            property bool palettedDirty: false

            // Shared editor popup. Single instance reused by every swatch
            // click — opens at the click position with the current color.
            //
            // v6.16.4.12.6.2 fix:
            //   - Positioning matches ColorSwatch's proven v6.16.4.6 pattern:
            //     anchorBox.mapToItem(parent, ...) where `parent` is the
            //     popup's auto-assigned container (Overlay/Window contentItem).
            //     Old code used mapToItem(null, ...) → window coords, but
            //     Popup.x/y is parent-relative, hence the bottom-right drift.
            //   - We deliberately do NOT set `parent: Overlay.overlay` —
            //     ColorSwatch in this same Settings window doesn't either,
            //     and it works. Some Quickshell window types don't expose
            //     Overlay attached property; relying on the default keeps
            //     us compatible.
            //   - Replaced bare hex TextField with full HSL color picker:
            //     hue×saturation Canvas + lightness Slider + live preview +
            //     hex display + Apply. Cancel button kept. Hex still
            //     editable via the input field below the slider for users
            //     who want to type exact values from a design spec.
            Popup {
                id: hexEditor
                modal: false
                focus: true
                width: 280
                height: 350
                padding: 0
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: Rectangle {
                    radius: 12
                    color: Qt.rgba(ThemeService.bg0.r, ThemeService.bg0.g, ThemeService.bg0.b, 0.97)
                    border.width: 1
                    border.color: ThemeService.alpha(ThemeService.fg, 0.18)
                    // Shadow ring
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: 14
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(0, 0, 0, 0.18)
                        z: -1
                    }
                }

                property string editingKey: ""
                property string editingLabel: ""
                property var anchorBox: null

                function _reposition() {
                    if (!parent || !anchorBox) return
                    const pt = anchorBox.mapToItem(parent, 0, anchorBox.height + 8)
                    let nx = pt.x - (width - anchorBox.width) / 2
                    let ny = pt.y
                    const pw = parent.width  || 1920
                    const ph = parent.height || 1080
                    if (nx + width  + 16 > pw) nx = pw - width  - 16
                    if (ny + height + 16 > ph) ny = ph - height - 16
                    if (nx < 16) nx = 16
                    if (ny < 16) ny = 16
                    x = nx
                    y = ny
                }

                function openFor(key, label, currentHex, anchorItem) {
                    editingKey = key
                    editingLabel = label
                    anchorBox = anchorItem
                    // Initialize HSL picker from the incoming hex
                    const h = currentHex.replace(/^#/, "")
                    if (h.length >= 6) {
                        const rr = parseInt(h.substring(0, 2), 16) / 255
                        const gg = parseInt(h.substring(2, 4), 16) / 255
                        const bb = parseInt(h.substring(4, 6), 16) / 255
                        const max = Math.max(rr, gg, bb)
                        const min = Math.min(rr, gg, bb)
                        let hh = 0, ss = 0, ll = (max + min) / 2
                        if (max !== min) {
                            const d = max - min
                            ss = ll > 0.5 ? d / (2 - max - min) : d / (max + min)
                            if (max === rr) hh = ((gg - bb) / d + (gg < bb ? 6 : 0)) / 6
                            else if (max === gg) hh = ((bb - rr) / d + 2) / 6
                            else hh = ((rr - gg) / d + 4) / 6
                        }
                        hsCanvas.pickerHue = hh
                        hsCanvas.pickerSat = ss
                        lightnessSlider.value = ll
                        hsCanvas.requestPaint()
                    }
                    pickerHexInput.text = "#" + h.substring(0, 6).toLowerCase()
                    open()
                }

                onOpened: _reposition()

                function _currentColor() {
                    return Qt.hsla(hsCanvas.pickerHue, hsCanvas.pickerSat, lightnessSlider.value, 1.0)
                }
                function _currentHex() {
                    const c = _currentColor()
                    const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
                    const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
                    const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
                    return "#" + r + g + b
                }

                function applyAndClose() {
                    let h
                    // Prefer typed hex if user touched the input + it's valid;
                    // else use HSL picker state.
                    const t = pickerHexInput.text.trim().replace(/^#/, "")
                    if (/^[0-9a-fA-F]{6}$/.test(t)) {
                        h = "#" + t.toLowerCase()
                    } else {
                        h = _currentHex()
                    }
                    ThemeService.setAccent(editingKey, h)
                    paletteSection.palettedDirty = true
                    close()
                }

                contentItem: ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header
                    Text {
                        text: "\uf53f  Edit " + hexEditor.editingLabel
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: ThemeService.fg
                    }

                    // ── Hue × Saturation canvas ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        clip: true

                        Canvas {
                            id: hsCanvas
                            anchors.fill: parent

                            property real pickerHue: 0.0
                            property real pickerSat: 1.0

                            onPaint: {
                                const ctx = getContext("2d")
                                const w = width, h = height
                                if (w <= 0 || h <= 0) return
                                for (let xx = 0; xx < w; xx += 2) {
                                    const hueVal = xx / w
                                    const grad = ctx.createLinearGradient(xx, 0, xx, h)
                                    grad.addColorStop(0, Qt.hsla(hueVal, 1.0, 0.5, 1.0))
                                    grad.addColorStop(1, Qt.hsla(hueVal, 0.0, 0.5, 1.0))
                                    ctx.fillStyle = grad
                                    ctx.fillRect(xx, 0, 2, h)
                                }
                            }

                            // Crosshair indicator
                            Rectangle {
                                x: Math.max(0, Math.min(hsCanvas.width  - 12, hsCanvas.pickerHue * hsCanvas.width  - 6))
                                y: Math.max(0, Math.min(hsCanvas.height - 12, (1.0 - hsCanvas.pickerSat) * hsCanvas.height - 6))
                                width: 12; height: 12; radius: 6
                                color: "transparent"
                                border.width: 2; border.color: "#ffffff"
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8; height: 8; radius: 4
                                    color: "transparent"
                                    border.width: 1; border.color: "#000000"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                function pick(mouse) {
                                    hsCanvas.pickerHue = Math.max(0, Math.min(1, mouse.x / hsCanvas.width))
                                    hsCanvas.pickerSat = Math.max(0, Math.min(1, 1.0 - mouse.y / hsCanvas.height))
                                    pickerHexInput.text = hexEditor._currentHex()
                                }
                                onPressed: function(mouse) { pick(mouse) }
                                onPositionChanged: function(mouse) { if (pressed) pick(mouse) }
                            }

                            Component.onCompleted: requestPaint()
                        }
                    }

                    // ── Lightness slider ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "L"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey0
                        }

                        Slider {
                            id: lightnessSlider
                            Layout.fillWidth: true
                            from: 0.05
                            to: 0.95
                            value: 0.5
                            onMoved: pickerHexInput.text = hexEditor._currentHex()
                        }

                        Text {
                            text: (lightnessSlider.value * 100).toFixed(0) + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: ThemeService.grey0
                            Layout.preferredWidth: 34
                        }
                    }

                    // ── Live preview + hex input ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 28
                            radius: 6
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.20)
                            color: hexEditor._currentColor()
                        }

                        TextField {
                            id: pickerHexInput
                            Layout.fillWidth: true
                            placeholderText: "#rrggbb"
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            color: ThemeService.fg
                            selectByMouse: true
                            background: Rectangle {
                                radius: 6
                                color: ThemeService.alpha(ThemeService.bg2, 0.6)
                                border.width: 1
                                border.color: pickerHexInput.activeFocus
                                              ? ThemeService.blue
                                              : ThemeService.alpha(ThemeService.fg, 0.10)
                            }
                            // Allow typing hex → updates canvas + slider
                            onEditingFinished: {
                                const t = text.trim().replace(/^#/, "")
                                if (/^[0-9a-fA-F]{6}$/.test(t)) {
                                    const rr = parseInt(t.substring(0, 2), 16) / 255
                                    const gg = parseInt(t.substring(2, 4), 16) / 255
                                    const bb = parseInt(t.substring(4, 6), 16) / 255
                                    const max = Math.max(rr, gg, bb)
                                    const min = Math.min(rr, gg, bb)
                                    let hh = 0, ss = 0, ll = (max + min) / 2
                                    if (max !== min) {
                                        const d = max - min
                                        ss = ll > 0.5 ? d / (2 - max - min) : d / (max + min)
                                        if (max === rr) hh = ((gg - bb) / d + (gg < bb ? 6 : 0)) / 6
                                        else if (max === gg) hh = ((bb - rr) / d + 2) / 6
                                        else hh = ((rr - gg) / d + 4) / 6
                                    }
                                    hsCanvas.pickerHue = hh
                                    hsCanvas.pickerSat = ss
                                    lightnessSlider.value = ll
                                    hsCanvas.requestPaint()
                                    text = "#" + t.toLowerCase()
                                }
                            }
                        }
                    }

                    // ── Cancel + Apply ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: cancelMa.containsMouse
                                   ? ThemeService.alpha(ThemeService.fg, 0.10)
                                   : ThemeService.alpha(ThemeService.fg, 0.05)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.fg, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: ThemeService.fg
                            }
                            MouseArea {
                                id: cancelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hexEditor.close()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: applyMa.containsMouse
                                   ? ThemeService.alpha(ThemeService.blue, 0.30)
                                   : ThemeService.alpha(ThemeService.blue, 0.18)
                            border.width: 1
                            border.color: ThemeService.alpha(ThemeService.blue, 0.40)

                            Text {
                                anchors.centerIn: parent
                                text: "Apply"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: ThemeService.blue
                            }
                            MouseArea {
                                id: applyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hexEditor.applyAndClose()
                            }
                        }
                    }
                }
            }

            // Helper: hex string for a QML color (no alpha) — matches what
            // hexInput expects and what ThemeService stores.
            function colorHex(c) {
                if (typeof c === "string") {
                    const h = c.replace(/^#/, "")
                    if (h.length >= 6) return "#" + h.substring(0, 6).toLowerCase()
                    return c
                }
                const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
                const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
                const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
                return "#" + r + g + b
            }

            // Reusable delegate component — shared by all three groups
            // (backgrounds / fg+greys / accents). Avoids duplicating the
            // 60x60 + label + click-to-edit pattern three times.
            Component {
                id: editableSwatchDelegate
                ColumnLayout {
                    required property var modelData
                    spacing: 4
                    Rectangle {
                        id: swatchBox
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        radius: 8
                        color: modelData.color
                        border.width: editorMa.containsMouse ? 2 : 1
                        border.color: editorMa.containsMouse
                                      ? ThemeService.blue
                                      : ThemeService.alpha(ThemeService.fg, 0.15)
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Subtle pencil glyph on hover hints at editability
                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            text: "\uf040"   // FA pencil
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: ThemeService.alpha(ThemeService.fg, 0.85)
                            opacity: editorMa.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: editorMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hexEditor.openFor(
                                modelData.key,
                                modelData.label,
                                paletteSection.colorHex(modelData.color),
                                swatchBox)
                        }
                    }
                    Text {
                        text: modelData.label
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        color: ThemeService.grey1
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Section's own id is at the top of this SettingsSection so the
            // delegate Component can reach `paletteSection.palettedDirty` and
            // `paletteSection.colorHex()` from inside its scope.

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // Backgrounds
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Backgrounds"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { key: "bg0", label: "bg0", color: ThemeService.bg0 },
                                { key: "bg1", label: "bg1", color: ThemeService.bg1 },
                                { key: "bg2", label: "bg2", color: ThemeService.bg2 },
                                { key: "bg3", label: "bg3", color: ThemeService.bg3 },
                                { key: "bg4", label: "bg4", color: ThemeService.bg4 }
                            ]
                            delegate: editableSwatchDelegate
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // Foreground & Greys
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Foreground & Greys"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { key: "fg",    label: "fg",    color: ThemeService.fg },
                                { key: "grey0", label: "grey0", color: ThemeService.grey0 },
                                { key: "grey1", label: "grey1", color: ThemeService.grey1 },
                                { key: "grey2", label: "grey2", color: ThemeService.grey2 }
                            ]
                            delegate: editableSwatchDelegate
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // Accents
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Accents"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.grey1
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { key: "red",    label: "red",    color: ThemeService.red },
                                { key: "orange", label: "orange", color: ThemeService.orange },
                                { key: "yellow", label: "yellow", color: ThemeService.yellow },
                                { key: "green",  label: "green",  color: ThemeService.green },
                                { key: "aqua",   label: "aqua",   color: ThemeService.aqua },
                                { key: "blue",   label: "blue",   color: ThemeService.blue },
                                { key: "purple", label: "purple", color: ThemeService.purple }
                            ]
                            delegate: editableSwatchDelegate
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // Save-as-custom-profile row
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 8
                    color: ThemeService.alpha(ThemeService.fg, 0.08)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Save edits as custom profile"
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: paletteSection.palettedDirty
                                  ? "● Unsaved edits — click Save to write to themes/custom/"
                                  : "○ No pending edits"
                            color: paletteSection.palettedDirty
                                   ? ThemeService.orange
                                   : ThemeService.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    TextField {
                        id: profileNameInput
                        Layout.preferredWidth: 160
                        placeholderText: "name (optional)"
                        font.family: Theme.fontFamily
                        color: ThemeService.fg
                        background: Rectangle {
                            radius: 6
                            color: ThemeService.bg2
                            border.width: 1
                            border.color: profileNameInput.activeFocus
                                          ? ThemeService.blue
                                          : ThemeService.alpha(ThemeService.fg, 0.20)
                        }
                    }

                    Button {
                        text: "\uf0c7  Save"
                        font.family: "JetBrainsMono Nerd Font"
                        enabled: paletteSection.palettedDirty
                        onClicked: {
                            ThemeService.saveAsCustomTheme(profileNameInput.text)
                            paletteSection.palettedDirty = false
                            profileNameInput.text = ""
                        }
                    }
                }
            }
        }

        // ── Import / Export / Delete ──
        SettingsSection {
            title: "Share Themes"
            subtitle: "Import JSON files, export to share with friends, delete custom themes"

            SettingRow {
                label: "Import Theme"
                description: "Load a .json theme file into your custom folder"

                Button {
                    text: "\uf019  Import..."
                    font.family: "JetBrainsMono Nerd Font"
                    onClicked: root.openImportPicker()
                }
            }

            SettingRow {
                label: "Export Current"
                description: "Save the current theme as a JSON file"

                Button {
                    text: "\uf093  Export..."
                    font.family: "JetBrainsMono Nerd Font"
                    onClicked: root.openExportPicker()
                }
            }

            SettingRow {
                label: "Delete Current"
                description: ThemeService.currentIsBuiltin
                             ? "⚠ Cannot delete builtin themes"
                             : "Delete the current custom theme"

                Button {
                    text: "\uf1f8  Delete"
                    font.family: "JetBrainsMono Nerd Font"
                    enabled: !ThemeService.currentIsBuiltin
                    onClicked: {
                        const current = ThemeService.availableThemes.find(t => t.id === ThemeService.themeId)
                        if (current && !current.is_builtin) ThemeService.deleteCustomTheme(current)
                    }
                }
            }
        }

        // ── Status message ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ThemeService.statusMsg.length > 0 ? 32 : 0
            visible: ThemeService.statusMsg.length > 0
            radius: 6
            color: ThemeService.alpha(ThemeService.blue, 0.15)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.blue, 0.3)

            Text {
                anchors.centerIn: parent
                text: ThemeService.statusMsg
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: ThemeService.fg
            }
        }

        PageFooter {
            description: "Applies via current-theme.json"
            onResetRequested: {
                const dflt = ThemeService.availableThemes.find(t => t.id === "tokyo-night")
                if (dflt) ThemeService.applyTheme(dflt)
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
