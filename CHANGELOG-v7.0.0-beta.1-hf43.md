# v7.0.0-beta.1-hf43 — Quick Notes panel clipping + rounded toggle pills in Input tab

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report (with screenshots):

> "yung notes bakit ganito hahaha pangit and yung toggle dito sa input
> dapat rounded design natin katulad nung mga bluetooth natin"

Two visual bugs in the same window:

1. **Quick Notes panel:** the editor pane's title text was escaping
   the panel bounds — rendering at the top-right of the screen instead
   of inside the editor. Long auto-titles (the user's first-line text
   "dfsfsfsdfsdf...") caused the layout to break.

2. **ControlPanel Input tab:** the Natural scroll + Touchpad natural
   scroll toggles used generic Qt Quick Controls `Switch` — they looked
   off compared to the rounded pill toggles used for Bluetooth/WiFi/
   Audio in the same panel.

---

## #1 — Quick Notes panel: hard clip + bounded title

### Root cause

`QuickNotesPanel.qml` editor pane header had:

```qml
RowLayout {
    Layout.fillWidth: true
    Text {
        Layout.fillWidth: true
        text: noteTitle  // could be 50+ chars
        elide: Text.ElideRight
    }
    Rectangle { Layout.preferredWidth: 24 ... }  // sticky ⭐
    Rectangle { Layout.preferredWidth: 24 ... }  // pin ★
}
```

**Problem:** `Layout.fillWidth` + `elide: Text.ElideRight` alone is
NOT enough to constrain Text in a `RowLayout`. In certain Qt
versions / layouts, the Text claims its full natural width (60+
characters of "dfsfsf..." → ~400px), and `RowLayout` honors that
implicitly. When the parent Rectangle doesn't have `clip: true`,
the child Text renders WHEREVER it ends up — even outside the panel.

### Fix — defense in depth

```qml
Item {
    id: panel
    width: 720; height: 480
    clip: true   // hf43: hard clip at root
    ...

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 100
        clip: true   // hf43: editor Rectangle clips too
        ...
        RowLayout {
            Layout.maximumHeight: 28   // hf43: clamp header height
            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: parent.width - 60   // hf43: reserve 60px for 2 buttons
                elide: Text.ElideRight
                maximumLineCount: 1   // hf43: force single line
                clip: true            // hf43: extra safety on Text itself
            }
        }
    }
}
```

Five layers of defense:
1. **`clip: true` on root Item** — hard panel boundary
2. **`clip: true` on editor Rectangle** — internal pane boundary
3. **`clip: true` on sidebar delegate** — list items can't bleed
4. **`Layout.maximumWidth` on title Text** — explicit upper bound
   based on parent width minus reserved button space
5. **`clip: true` on Text + `maximumLineCount: 1`** — Text element
   refuses to render past its bounds

If any one of these fails, the others catch it. Belt-and-suspenders.

---

## #2 — Input tab rounded toggle pills

### Before

```qml
Switch {
    checked: MouseSettingsService.naturalScroll
    onToggled: { ... }
}
```

That renders Qt Quick Controls' default Switch — varying appearance
depending on Qt style. On Paul's Material-like environment it shows
as a stubby toggle with a track + thumb, but the proportions and
animation feel different from the bluetooth toggle in the same panel.

### After

Same exact pattern as `ConnToggleRow.qml` (used by Bluetooth, WiFi,
Audio toggles in Quick Settings):

```qml
Rectangle {
    Layout.preferredWidth: 42
    Layout.preferredHeight: 22
    radius: 11   // half-pill
    color: MouseSettingsService.naturalScroll
           ? ThemeService.alpha(ThemeService.green, 0.85)
           : ThemeService.alpha(ThemeService.fg, 0.15)
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: 18; height: 18; radius: 9   // circular thumb
        color: ThemeService.fg
        y: 2
        x: MouseSettingsService.naturalScroll
           ? parent.width - width - 2 : 2
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            MouseSettingsService.naturalScroll = !MouseSettingsService.naturalScroll
            MouseSettingsService.apply(true)
        }
    }
}
```

42×22 pill, 18×18 circular thumb, green when on, neutral when off,
150ms OutCubic slide animation. **Identical** to the Bluetooth /
WiFi / Audio toggles you can see in the same Control Panel.

---

## Files changed (3)

```
zen-shell-v5/QuickNotesPanel.qml   — 5 layers of clip + title constraints
zen-shell-v5/ControlPanel.qml      — 2 toggle switches replaced
zen-shell-v5/ZenVersion.qml        — bumped to hf43
install.sh                          — banner + changelog
```

No new files. Surgical edits only.

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf43-quicknotes-clip-toggle-pills.tgz
cd zen-shell-v7.0.0-beta.1-hf43
./install.sh
```

---

## How to verify

### Quick Notes panel doesn't overflow

1. Press `Super+Shift+N` → panel opens
2. Type a really long first line like "this is a stupidly long note title to test elide behavior aaaaaaaaaaaaaaaa"
3. Click a different note in sidebar → come back to this one
4. **Title in editor header** should show truncated with "…"
5. **Nothing renders outside the panel bounds** anymore

### Input tab toggles match Bluetooth design

1. `Super+C` → Control Panel → Input tab
2. Look at "Natural scroll" toggle — should be a pill, not a generic Switch
3. Click it → thumb slides smoothly left↔right with green/neutral fill
4. Switch to **Wi-Fi** tab → look at the Bluetooth toggle row
5. The two toggle pills should be **visually identical** in size,
   shape, color, and animation

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf42 modules visible + usage docs
- ✅ hf41 collapsible Settings search + Input tab custom sliders
- ✅ hf40 Quick Notes keybinds + sticky notes
- ✅ hf39 5 productivity features
- ✅ hf38 string colors + annotation transparency
- ✅ hf37 event-driven hot corners
- ✅ hf36 refresh rate toggle

Pure visual polish hotfix. No new features, no behavioral changes
outside the two surfaces. 🍃
