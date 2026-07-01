import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * TitleTranslatorPage v7.0.0-beta.1-hf39 — Settings page for Title
 * Translator.
 */
Item {
    id: root

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: contentCol.implicitHeight
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 24
            spacing: 16

            DenshoPageHeader {
                Layout.fillWidth: true
                title: "Title Translator"
                subtitle: "Auto-translate non-Latin window titles"
                kanji: "翻訳"
                romaji: "Honyaku"
            }

            HMSection {
                title: "Detection"

                HMRow {
                    label: "Enable detection"
                    description: "Watch the active window title for non-Latin scripts "
                               + "(Japanese, Chinese, Korean, Cyrillic, Arabic)."
                    icon: "\uf1ab"
                    separator: true

                    HMSwitch {
                        checked: TitleTranslatorService.enabled
                        onToggled: TitleTranslatorService.enabled = checked
                    }
                }

                HMRow {
                    label: "Auto-translate"
                    description: "Fetch translation automatically when foreign title detected. "
                               + "Off = only translate when you click the bar module."
                    icon: "\uf021"

                    HMSwitch {
                        checked: TitleTranslatorService.autoTranslate
                        onToggled: TitleTranslatorService.autoTranslate = checked
                    }
                }
            }

            HMSection {
                title: "Translation Backend"

                HMRow {
                    label: "LibreTranslate URL"
                    description: "Public or self-hosted LibreTranslate API endpoint."
                    icon: "\uf0c1"
                    separator: true

                    TextField {
                        Layout.preferredWidth: 220
                        text: TitleTranslatorService.libreTranslateUrl
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: ThemeService.fg
                        onEditingFinished: TitleTranslatorService.libreTranslateUrl = text
                        background: Rectangle {
                            radius: 4
                            color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.6)
                            border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                            border.width: 1
                        }
                    }
                }

                HMRow {
                    label: "Target language"
                    description: "ISO 639-1 code: en, es, ja, zh, ko, fr, de, etc."
                    icon: "\uf0ac"

                    TextField {
                        Layout.preferredWidth: 60
                        text: TitleTranslatorService.targetLang
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: ThemeService.fg
                        horizontalAlignment: TextInput.AlignHCenter
                        onEditingFinished: TitleTranslatorService.targetLang = text.toLowerCase().trim()
                        background: Rectangle {
                            radius: 4
                            color: ThemeService.alpha(ThemeService.bg2 || ThemeService.bg1, 0.6)
                            border.color: ThemeService.alpha(ThemeService.fg, 0.2)
                            border.width: 1
                        }
                    }
                }
            }

            HMSection {
                title: "Cache & Recent"
                subtitle: "Translations are cached on disk at ~/.cache/zen-shell/title-translations.json"

                HMRow {
                    label: "Cached translations"
                    icon: "\uf187"
                    separator: TitleTranslatorService.recent.length > 0

                    Text {
                        text: Object.keys(TitleTranslatorService.cache).length + " entries"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Repeater {
                    model: TitleTranslatorService.recent.slice(0, 10)

                    HMRow {
                        label: modelData.original
                        description: TitleTranslatorService.langLabel(modelData.sourceLang)
                                   + " → " + modelData.translated
                        icon: "\uf1ab"
                        separator: index < Math.min(10, TitleTranslatorService.recent.length) - 1
                    }
                }
            }
        }
    }
}
