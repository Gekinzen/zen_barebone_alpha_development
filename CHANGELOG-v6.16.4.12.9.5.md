# v6.16.4.12.9.5 — Modori (戻り) · hotfix 5

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.4 — Modori hotfix 4

## Summary

Single-purpose UI-stability fix. User reported that **moving the
Settings window across monitors and back** caused the username +
@hostname text labels in the sidebar bottom user row to **vanish
permanently** for that session. The avatar stayed visible (it has
a fixed preferred width), but the text container collapsed to 0
width and the labels elided to nothing.

This was a `Layout.fillWidth: true` race condition: when the
Settings window crosses a monitor boundary, the parent width
computation can transiently drop to 0 during the move. The Layout
system's recovery path doesn't always fire when the move
completes, leaving the inner ColumnLayout stuck at 0 width even
after the window settles.

## Root cause

The user-row footer in `ZenSettings.qml` had this structure:

```qml
RowLayout {
    Rectangle { /* avatar 32×32, Layout.preferredWidth: 32 */ }
    ColumnLayout {                  // ← collapses to 0 on cross-monitor move
        Layout.fillWidth: true
        Text { /* username */ Layout.fillWidth: true }
        Text { /* @hostname */ Layout.fillWidth: true }
    }
}
```

The avatar's fixed-width hint propagates correctly. The
ColumnLayout's `fillWidth` propagation does NOT recover after the
parent width transient. Inner Text elements with `Layout.fillWidth:
true` inherit from the broken ColumnLayout and elide to empty.

## Fix

Replaced the ColumnLayout with a plain `Item` containing a `Column`
of Text elements. The Item gets explicit `implicitWidth` math from
the outer Rectangle's width minus the avatar minus row spacing/
margins:

```qml
Item {
    id: userTextWrap
    Layout.fillWidth: true
    implicitWidth: Math.max(60, sidebarUserBg.width - 32 - 26)
    implicitHeight: nameText.implicitHeight + hostText.implicitHeight

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        Text { id: nameText; width: parent.width; ... }
        Text { id: hostText; width: parent.width; ... }
    }
}
```

Plain Item with explicit-width binding (and a 60px floor as a
sanity net) recovers cleanly when the window settles. Even if the
binding briefly evaluates to 0, the `Math.max(60, ...)` floor
keeps the labels visible. The inner `Column` sizes its children
via `width: parent.width` — also explicit, no Layout-system
propagation involved.

The outer `Rectangle` (the bg2 pill behind the avatar + texts) got
a new `id: sidebarUserBg` so the inner Item can read its width.
Everything else in the user row block is unchanged: avatar
masking, fallback glyph, hover MouseArea, click-to-userprofile.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.5. |
| `zen-shell-v5/ZenSettings.qml` | Sidebar user-row outer Rectangle gets `id: sidebarUserBg`. Inner username + hostname container switched from `ColumnLayout { Layout.fillWidth: true }` to `Item { implicitWidth: Math.max(60, sidebarUserBg.width - 32 - 26) }` containing a plain `Column` of Texts. Texts use `width: parent.width` instead of `Layout.fillWidth`. Comment block above explains the Layout-recovery race. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped to .9.5. |
| `CHANGELOG-v6.16.4.12.9.5.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.5
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

After the fix, moving Settings across monitors should leave the
sidebar user row labels intact regardless of motion path. If you
still see the labels disappear, please screenshot AND grab the
quickshell log (`tail -100 /tmp/zen-shell.log`) so I can see if
there's a different code path triggering the same symptom.

## Carry-forward

All Modori .9.4 features preserved:

- Smart-contrast theme engine (WCAG luminance-based foreground
  auto-correction)
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- Left/Right panel position cards hidden + L/R-to-Bottom
  migration safety net
- All Tachiagari .7.1 features

## Wala tayong babawasan

Pure UI-stability fix. The user row still shows the same content
(avatar + username + @hostname), still routes click → User Profile
page, still uses the same bg2 pill backdrop, still has the same
hover-highlight border. Only the inner-container element type
changed (ColumnLayout → Item + Column) and the sizing math became
explicit instead of relying on Layout-system propagation.
