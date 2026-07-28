import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

/*
 * PanasonicPage v8.0.0-alpha-hf179 — Settings → Panasonic (Let's Note)
 *
 * Only reachable when PanasonicService.isPanasonic is true. On any other
 * machine the nav entry is not built at all, so this file costs nothing.
 */
Item {
    id: root

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            DenshoPageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.topMargin: 24
                title: "Panasonic"
                subtitle: "Let's Note wheel pad, ECO battery limit, sticky keys"
                kanji: "松下"
                romaji: "Matsushita"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
                spacing: 16

                // ═══════════════════════════════════════
                // HARDWARE
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Hardware"
                    subtitle: PanasonicService.statusLine

                    // v8.0.0-alpha-hf186 — say so, loudly, when the page is
                    // only here because of the override. Everything below
                    // reads real sysfs, so on non-Panasonic hardware the rows
                    // will be empty or absent rather than wrong — but that
                    // needs stating, not discovering.
                    ControlCenterBanner {
                        Layout.fillWidth: true
                        visible: PanasonicService.forceShow && !PanasonicService.isPanasonic
                        feature: "Developer override active"
                        description: "DMI does not report a Panasonic Let's Note. "
                                     + "This page is visible because ZEN_PANASONIC_FORCE "
                                     + "is set or force_page is in wheelpad.json. The "
                                     + "readings below come from real sysfs, so most will "
                                     + "be empty here. The wheelpad daemon still refuses "
                                     + "to start without Let's Note hardware unless run "
                                     + "with --any-machine."
                    }

                    SettingRow {
                        icon: "\uf109"
                        label: "Model"
                        description: PanasonicService.model.length > 0
                                     ? (PanasonicService.vendor + " · " + PanasonicService.model)
                                     : "Reading DMI…"
                    }

                    SettingRow {
                        icon: "\uf245"
                        label: "Touchpad"
                        description: PanasonicService.touchpadName.length > 0
                                     ? PanasonicService.touchpadName
                                     : "Auto-detected by capability"
                    }

                    SettingRow {
                        icon: "\uf021"
                        label: "Re-probe"
                        description: "Re-read DMI, module state and daemon status"
                        ZenButton {
                            text: "Probe"
                            onClicked: PanasonicService.probe()
                        }
                    }
                }

                // ═══════════════════════════════════════
                // WHEEL PAD
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Wheel Pad · circular scrolling"
                    subtitle: "Draw circles around the outer ring to scroll, "
                              + "the way the Windows driver does"

                    // The honest disclosure. Users will otherwise assume this
                    // is a toggle in the compositor and wonder why it needs a
                    // daemon and a group membership.
                    ControlCenterBanner {
                        Layout.fillWidth: true
                        feature: "Why this needs a daemon"
                        description: "libinput offers only two-finger, edge and "
                                     + "on-button scrolling — circular is not "
                                     + "available on Wayland at all. Zen Shell "
                                     + "synthesises it by grabbing the pad and "
                                     + "republishing it. Stop the daemon at any "
                                     + "time and the pad reverts to stock."
                    }

                    SettingRow {
                        icon: "\uf0e7"
                        label: "Circular scrolling"
                        description: PanasonicService.daemonRunning
                                     ? "Running"
                                     : (PanasonicService.evdevPresent
                                        ? (PanasonicService.inInputGroup
                                           ? "Stopped"
                                           : "Blocked — add yourself to the 'input' group")
                                        : "Blocked — install python-evdev")
                        HMSwitch {
                            compact: true
                            enabled: PanasonicService.evdevPresent
                                     && PanasonicService.inInputGroup
                            activeColor: ThemeService.alpha(ThemeService.green, 0.85)
                            checked: PanasonicService.daemonRunning
                            onToggled: {
                                if (PanasonicService.daemonRunning)
                                    PanasonicService.stopDaemon()
                                else
                                    PanasonicService.startDaemon()
                            }
                        }
                    }

                    // ── Live ring preview ──
                    // A number like "0.62" means nothing; the drawn ring shows
                    // exactly how much of the pad stops being a pointer.
                    SettingRow {
                        icon: "\uf06e"
                        label: "Ring preview"
                        description: "Shaded band scrolls · centre still points"

                        Item {
                            width: 92; height: 92

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: ThemeService.alpha(ThemeService.fg, 0.06)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }
                            // The scrolling band is everything OUTSIDE the inner
                            // disc, so the inner disc is what we draw.
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * PanasonicService.ringInner
                                height: width
                                radius: width / 2
                                color: ThemeService.alpha(ThemeService.blue, 0.30)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.6)
                                Behavior on width { NumberAnimation { duration: 120 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: PanasonicService.clicksPerTurn + "\u21bb"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: ThemeService.fg
                                style: LookService.isClear ? Text.Outline : Text.Normal
                                styleColor: LookService.clearTextOutline
                            }
                        }
                    }

                    SettingRow {
                        icon: "\uf111"
                        label: "Ring width"
                        description: "Where the scroll band starts. Lower = a "
                                     + "wider band, but less pad left for pointing."
                        NumericStepper {
                            from: 40; to: 90; stepSize: 2
                            value: Math.round(PanasonicService.ringInner * 100)
                            suffix: "%"
                            onValueEdited: v => PanasonicService.ringInner = v / 100.0
                        }
                    }

                    SettingRow {
                        icon: "\uf01e"
                        label: "Scroll sensitivity"
                        description: "Degrees of travel per click — "
                                     + PanasonicService.clicksPerTurn
                                     + " clicks per full turn"
                        NumericStepper {
                            from: 6; to: 60; stepSize: 2
                            value: Math.round(PanasonicService.degreesPerClick)
                            suffix: "\u00b0"
                            onValueEdited: v => PanasonicService.degreesPerClick = v
                        }
                    }

                    SettingRow {
                        icon: "\uf0b2"
                        label: "Engage threshold"
                        description: "How far round the ring before scrolling "
                                     + "takes over. Raise it if taps near the "
                                     + "edge scroll by accident."
                        NumericStepper {
                            from: 4; to: 45; stepSize: 2
                            value: Math.round(PanasonicService.engageDegrees)
                            suffix: "\u00b0"
                            onValueEdited: v => PanasonicService.engageDegrees = v
                        }
                    }

                    SettingRow {
                        icon: "\uf07d"
                        label: "Natural direction"
                        description: "Clockwise scrolls up instead of down"
                        HMSwitch {
                            compact: true
                            checked: PanasonicService.naturalScroll
                            onToggled: PanasonicService.naturalScroll = !PanasonicService.naturalScroll
                        }
                    }

                    SettingRow {
                        icon: "\uf021"
                        label: "Apply changes"
                        description: "The daemon reads its settings on start"
                        ZenButton {
                            text: "Restart daemon"
                            enabled: PanasonicService.daemonRunning
                            onClicked: PanasonicService.restartDaemon()
                        }
                    }
                }

                // ═══════════════════════════════════════
                // FIRMWARE
                // ═══════════════════════════════════════
                SettingsSection {
                    title: "Firmware · panasonic-laptop"
                    subtitle: PanasonicService.moduleLoaded
                              ? "Module loaded"
                              : "Module not loaded — hotkeys and ECO unavailable"

                    SettingRow {
                        visible: !PanasonicService.moduleLoaded
                        icon: "\uf085"
                        label: "Load the module"
                        description: "modprobe panasonic-laptop (asks for authentication)"
                        ZenButton {
                            text: "Load"
                            onClicked: PanasonicService.loadModule()
                        }
                    }

                    SettingRow {
                        icon: "\uf240"
                        label: "ECO mode · battery charge limit"
                        description: PanasonicService.ecoAvailable
                            ? "Stops charging at about 80% to preserve battery life. "
                              + "Resets to the firmware's own value on the next full "
                              + "power cycle — set it in the Panasonic utility under "
                              + "Windows to make it stick."
                            : "Not exposed by this model or module build"
                        HMSwitch {
                            compact: true
                            enabled: PanasonicService.ecoAvailable
                            activeColor: ThemeService.alpha(ThemeService.green, 0.85)
                            checked: PanasonicService.ecoMode
                            onToggled: PanasonicService.setEcoMode(!PanasonicService.ecoMode)
                        }
                    }

                    SettingRow {
                        icon: "\uf11c"
                        label: "Sticky keys"
                        description: PanasonicService.stickyAvailable
                                     ? "Firmware-level modifier latching"
                                     : "Not exposed by this model or module build"
                        HMSwitch {
                            compact: true
                            enabled: PanasonicService.stickyAvailable
                            checked: PanasonicService.stickyKey
                            onToggled: PanasonicService.setStickyKey(!PanasonicService.stickyKey)
                        }
                    }
                }

                PageFooter {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
