import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/*
 * CursorPage — v8.0.0-alpha-hf168
 * Mouse cursor theme picker. Lists installed Xcursor themes (via CursorService,
 * which scans ~/.icons, ~/.themes, ~/.cursor, ~/.local/share/{icons,cursors} and
 * the system paths) and applies the chosen one live + persists it.
 */
ScrollView {
    id: root
    clip: true

    ColumnLayout {
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Cursor & Icons"
                font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold
                color: ThemeService.fg
            }
            Text {
                style: LookService.isClear ? Text.Outline : Text.Normal
                styleColor: LookService.clearTextOutline
                text: "Mouse cursor + GTK icon themes — reads your installed themes and applies instantly"
                font.family: Theme.fontFamily; font.pixelSize: 12
                color: ThemeService.grey1
            }
        }

        SettingsSection {
            title: "Cursor theme"
            subtitle: "Scanned from ~/.icons, ~/.themes, ~/.cursor and the system icon paths"

            SettingRow {
                label: "Theme"
                Row {
                    spacing: 8
                    ZenDropdown {
                        width: 240
                        model: CursorService.themes.map(function(t){ return t.name })
                        currentIndex: {
                            const i = CursorService.themes.findIndex(function(t){ return t.name === CursorService.current })
                            return i < 0 ? 0 : i
                        }
                        onActivated: function(i) {
                            const names = CursorService.themes.map(function(t){ return t.name })
                            if (names[i]) CursorService.apply(names[i])
                        }
                    }
                    ZenButton {
                        iconText: "\uf021"   // refresh — rescan installed themes
                        onClicked: CursorService.scan()
                    }
                }
            }

            SettingRow {
                label: "Applied"
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: CursorService.current !== "" ? CursorService.current : "— (pick a theme above)"
                    color: CursorService.current !== "" ? ThemeService.fg : ThemeService.grey2
                    font.family: Theme.fontFamily; font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        SettingsSection {
            title: "Cursor size"
            subtitle: "Applies live via hyprctl + gsettings"

            SettingRow {
                label: "Size"
                Row {
                    spacing: 8
                    ZenSlider {
                        width: 220; from: 12; to: 64; stepSize: 2
                        value: CursorService.size
                        onValueChanged: if (Math.round(value) !== CursorService.size) CursorService.setSize(value)
                    }
                    Text {
                        style: LookService.isClear ? Text.Outline : Text.Normal
                        styleColor: LookService.clearTextOutline
                        text: CursorService.size + "px"; color: ThemeService.fg
                        font.family: Theme.fontFamily; font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        SettingsSection {
            title: "Icon theme"
            subtitle: "GTK app icons — set here instead of opening a separate GTK settings tool"

            SettingRow {
                label: "Theme"
                Row {
                    spacing: 8
                    ZenDropdown {
                        width: 240
                        model: IconThemeService.themes.map(function(t){ return t.name })
                        currentIndex: {
                            const i = IconThemeService.themes.findIndex(function(t){ return t.name === IconThemeService.current })
                            return i < 0 ? 0 : i
                        }
                        onActivated: function(i) {
                            const names = IconThemeService.themes.map(function(t){ return t.name })
                            if (names[i]) IconThemeService.apply(names[i])
                        }
                    }
                    ZenButton {
                        iconText: "\uf021"   // refresh — rescan installed icon themes
                        onClicked: IconThemeService.scan()
                    }
                }
            }

            SettingRow {
                label: "Applied"
                Text {
                    style: LookService.isClear ? Text.Outline : Text.Normal
                    styleColor: LookService.clearTextOutline
                    text: IconThemeService.current !== "" ? IconThemeService.current : "— (pick a theme above)"
                    color: IconThemeService.current !== "" ? ThemeService.fg : ThemeService.grey2
                    font.family: Theme.fontFamily; font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            style: LookService.isClear ? Text.Outline : Text.Normal
            styleColor: LookService.clearTextOutline
            wrapMode: Text.WordWrap
            text: "Tip: for a theme to actually apply, it needs to live in a standard Xcursor path "
                  + "(~/.icons/<name>/cursors/ is safest). A theme only in ~/.themes or ~/.cursor may "
                  + "list here but not apply, since the cursor loader won't find it there."
            color: ThemeService.grey2; font.family: Theme.fontFamily; font.pixelSize: 11
        }

        Item { Layout.preferredHeight: 12 }
    }

    Component.onCompleted: { CursorService.scan(); IconThemeService.scan() }
}
