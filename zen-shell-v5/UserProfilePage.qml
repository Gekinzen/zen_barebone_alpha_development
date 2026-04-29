import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

/*
 * UserProfilePage v6.16.4 — Settings page for user avatar + system info
 *
 * Provides:
 *   - Live avatar preview (72px) with auto-detection status
 *   - Upload custom avatar button (zenity file picker)
 *   - Clear custom avatar button (reverts to auto-detected)
 *   - System information display (fastfetch-style)
 *   - Auto-detected source path display
 *
 * This is the entry point for customizing the user avatar that
 * appears in the StartMenu footer + system info popover.
 */
Flickable {
    id: root

    property int availableWidth: width

    contentWidth: width
    contentHeight: contentCol.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: contentCol
        width: root.availableWidth - 48
        x: 24; y: 24
        spacing: 20

        // ═══ Header ═══
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "User Profile"
                color: ThemeService.fg
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                text: "Your avatar appears in the Start Menu footer. Auto-detected from GDM / SDDM / GNOME sources, or upload a custom image."
                color: ThemeService.grey0
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // ═══ AVATAR SECTION ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: avatarSectionCol.implicitHeight + 32
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: avatarSectionCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                Text {
                    text: "Avatar"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    // v6.16.2.3: Large live circular avatar preview.
                    // Previous layer.enabled approach didn't produce a
                    // proper circle in some setups. This version uses
                    // the "Rectangle with layer.enabled + radius" pattern
                    // that's known to work reliably when antialiasing is
                    // explicitly enabled and the Rectangle has a solid
                    // color (not transparent).
                    // v6.16.2.3.2-hotfix4: OpacityMask circular avatar.
                    // Replaces the v6.16.2.3 shader approach which silently
                    // failed on some Qt builds (file loaded, shader compiled
                    // to no-op, image rendered as raw square or invisible).
                    // OpacityMask is the canonical Qt 5/6 circular-mask
                    // pattern and uses the same Qt5Compat.GraphicalEffects
                    // module ZenStrings already imports for Glow.
                    Rectangle {
                        id: avatarPreviewRing
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        radius: width / 2
                        color: ThemeService.alpha(ThemeService.blue, 0.18)
                        border.width: 2
                        border.color: ThemeService.alpha(ThemeService.blue, 0.5)
                        antialiasing: true

                        // Inner image — uses layer.enabled + layer.effect
                        // ShaderEffect with a simple circular mask. The
                        // mask is computed from UV coordinates: pixels
                        // outside a centered circle (dist > 0.5) are set
                        // to alpha 0. This works in base Qt without
                        // QtGraphicalEffects.
                        // Hidden source — OpacityMask reads pixels from this
                        Image {
                            id: avatarBigImg
                            anchors.fill: parent
                            anchors.margins: 2
                            source: UserProfileService.effectiveAvatarSource
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(192, 192)
                            visible: false
                            // Diagnostic: log every load attempt to journalctl
                            // so users can `journalctl --user -f | grep AvatarBigImg`
                            onStatusChanged: {
                                console.log("[AvatarBigImg] status=" + status
                                          + " src=" + source)
                                if (status === Image.Error) {
                                    console.warn("[AvatarBigImg] LOAD FAILED for: " + source)
                                }
                            }
                            onSourceChanged: console.log("[AvatarBigImg] source set to: " + source)
                        }
                        // Mask shape — circle filling the inner area
                        Rectangle {
                            id: avatarBigMask
                            anchors.fill: avatarBigImg
                            radius: width / 2
                            color: "white"
                            visible: false
                        }
                        // Composited result — what the user actually sees
                        OpacityMask {
                            anchors.fill: avatarBigImg
                            source: avatarBigImg
                            maskSource: avatarBigMask
                            visible: avatarBigImg.status === Image.Ready
                                  && avatarBigImg.source.toString().length > 0
                        }
                        // Fallback glyph when no avatar OR load failed
                        Text {
                            anchors.centerIn: parent
                            text: "\uf007"
                            color: ThemeService.blue
                            font.family: Theme.monoFont
                            font.pixelSize: 42
                            visible: avatarBigImg.status !== Image.Ready
                                  || avatarBigImg.source.toString().length === 0
                        }
                    }

                    // Info + controls
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: UserProfileService.userName +
                                  (UserProfileService.hostname
                                    ? "@" + UserProfileService.hostname : "")
                            color: ThemeService.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (UserProfileService.customAvatarPath)
                                    return "Using custom avatar"
                                if (UserProfileService.avatarPath)
                                    return "Auto-detected"
                                return "No avatar — using fallback glyph"
                            }
                            color: UserProfileService.customAvatarPath || UserProfileService.avatarPath
                                ? ThemeService.blue
                                : ThemeService.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            text: UserProfileService.customAvatarPath
                                ? UserProfileService.customAvatarPath
                                : (UserProfileService.avatarPath || "")
                            color: ThemeService.grey0
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                            visible: text.length > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 34
                                radius: 7
                                color: uploadMa.containsMouse
                                    ? ThemeService.alpha(ThemeService.blue, 0.3)
                                    : ThemeService.alpha(ThemeService.blue, 0.15)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.blue, 0.5)
                                Text {
                                    anchors.centerIn: parent
                                    text: UserProfileService.customAvatarPath
                                        ? "Change avatar..."
                                        : "Upload avatar..."
                                    color: ThemeService.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: uploadMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: avatarPickerProc.running = true
                                }
                            }

                            Rectangle {
                                visible: UserProfileService.customAvatarPath.length > 0
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 34
                                radius: 7
                                color: resetMa.containsMouse
                                    ? ThemeService.alpha(ThemeService.fg, 0.14)
                                    : ThemeService.alpha(ThemeService.fg, 0.07)
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: "Reset"
                                    color: ThemeService.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: resetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: UserProfileService.clearCustomAvatar()
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                Text {
                    text: "Auto-detection searches: ~/.config/zen-shell/user-avatar.png → ~/.face → /var/lib/AccountsService/icons/$USER → SDDM faces directory. If you've set a photo in your greeter (GDM/SDDM/COSMIC), it will be used automatically."
                    color: ThemeService.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                }
            }
        }

        // ═══ PERSONAL PREFERENCES SECTION (v6.16.3.6) ═══
        //
        // Single setting for now: lock-screen message flavor (gender).
        // This controls which pool of rotating care messages
        // zen-lock-message.sh picks from. "Neutral" is safe and
        // inclusive default. "Male" / "Female" unlock gendered
        // phrasings ("What's up, man!" / "What's up, miss!") for
        // users who prefer that vibe.
        //
        // Saved via PanelState.saveState() → panel-state.json →
        // read by zen-lock-message.sh at lock time.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: prefsCol.implicitHeight + 32
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: prefsCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "Personal Preferences"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    text: "Flavors your lock-screen rotating messages. "
                        + "Neutral works for everyone; Male / Female unlock gendered phrasings."
                    color: ThemeService.grey0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 12

                    Text {
                        text: "Address me as"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        Layout.preferredWidth: 140
                    }

                    ZenDropdown {
                        Layout.preferredWidth: 200
                        model: ["Neutral (they / friend)", "Male (man / bro)", "Female (miss / queen)"]
                        readonly property var ids: ["neutral", "male", "female"]
                        currentIndex: Math.max(0, ids.indexOf(PanelState.userGender))
                        onActivated: {
                            PanelState.userGender = ids[currentIndex]
                            PanelState.saveState()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // ═══ SYSTEM INFO SECTION (fastfetch-style) ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: sysInfoCol.implicitHeight + 32
            radius: 12
            color: ThemeService.alpha(ThemeService.bg1 || ThemeService.bg0, 0.5)
            border.width: 1
            border.color: ThemeService.alpha(ThemeService.fg, 0.08)

            ColumnLayout {
                id: sysInfoCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "System Information"
                    color: ThemeService.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    text: "Also accessible by clicking your avatar in the Start Menu footer."
                    color: ThemeService.grey0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    Layout.bottomMargin: 6
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 7

                    Text { text: "User"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.userName +
                              (UserProfileService.hostname
                                ? " @ " + UserProfileService.hostname : "")
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text { text: "OS"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.osName +
                              (UserProfileService.osVersion
                                ? " " + UserProfileService.osVersion : "")
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text { text: "Kernel"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.kernelVersion || "…"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text { text: "Uptime"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.uptime || "…"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text { text: "CPU"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.cpuModel
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        text: UserProfileService.gpuNames.length > 1 ? "GPUs" : "GPU"
                        color: ThemeService.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        visible: UserProfileService.gpuNames.length > 0
                    }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.gpuNames.join(" · ")
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        visible: UserProfileService.gpuNames.length > 0
                    }

                    Text { text: "WM"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: "Hyprland " + (UserProfileService.hyprlandVersion || "")
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text { text: "Shell"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        // v6.16.3.4.4: surface the current shell version
                        // straight from the ZenVersion singleton. Updating
                        // ZenVersion.version once propagates to every bound
                        // surface — no more hand-chasing scattered strings.
                        text: "Zen Shell " + ZenVersion.version + " · " + ZenVersion.channel + " · Quickshell"
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    // v6.16.3.4.4: dedicated version / release-date row for
                    // users who want a quick visual reference of "am I on
                    // the latest drop?". Matches the "Device" / "BIOS" row
                    // layout pattern used below.
                    Text { text: "Version"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: ZenVersion.version + "  ·  released " + ZenVersion.releaseDate
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    // v6.16.2.3.1: Device + BIOS rows from /sys/class/dmi/id
                    // (no sudo required). Hidden when the sysfs files are
                    // unreadable (VMs, containers, WSL, exotic hardware).
                    Text {
                        text: "Device"
                        color: ThemeService.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        visible: UserProfileService.productName.length > 0
                              || UserProfileService.systemVendor.length > 0
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            const vendor = UserProfileService.systemVendor
                            const name   = UserProfileService.productName
                            const ver    = UserProfileService.productVersion
                            let s = ""
                            if (vendor) s += vendor
                            if (name)   s += (s ? " " : "") + name
                            if (ver && ver !== "1.0" && ver !== "Default string")
                                s += " (v" + ver + ")"
                            return s || "—"
                        }
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        visible: UserProfileService.productName.length > 0
                              || UserProfileService.systemVendor.length > 0
                    }

                    Text {
                        text: "BIOS"
                        color: ThemeService.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        visible: UserProfileService.biosVersion.length > 0
                              || UserProfileService.biosVendor.length > 0
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            const vend = UserProfileService.biosVendor
                            const ver  = UserProfileService.biosVersion
                            const date = UserProfileService.biosDate
                            let s = ""
                            if (ver)  s += ver
                            if (vend) s += (s ? " · " : "") + vend
                            if (date) s += (s ? " · " : "") + date
                            return s || "—"
                        }
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        visible: UserProfileService.biosVersion.length > 0
                              || UserProfileService.biosVendor.length > 0
                    }

                    Text { text: "Theme"; color: ThemeService.blue; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: UserProfileService.themeName
                        color: ThemeService.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // Color palette preview
                Text {
                    text: "Theme palette"
                    color: ThemeService.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    Layout.topMargin: 6
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: [
                            { c: ThemeService.bg0, label: "bg0" },
                            { c: ThemeService.bg1 || ThemeService.bg0, label: "bg1" },
                            { c: ThemeService.fg, label: "fg" },
                            { c: ThemeService.fgDim || ThemeService.grey0, label: "fgDim" },
                            { c: ThemeService.blue, label: "accent" }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            spacing: 2
                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 28
                                radius: 5
                                color: modelData.c
                                border.width: 1
                                border.color: ThemeService.alpha(ThemeService.fg, 0.15)
                            }
                            Text {
                                text: modelData.label
                                color: ThemeService.grey0
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: 56
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    // ═══ Zenity file picker ═══
    Process {
        id: avatarPickerProc
        running: false
        command: ["bash", "-c",
            "zenity --file-selection --title='Select Avatar' " +
            "--file-filter='Images | *.png *.jpg *.jpeg *.webp' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p.length > 0) UserProfileService.setCustomAvatar(p)
            }
        }
    }
}
