# v6.16.4.12.9.7 — Modori (戻り) · hotfix 7

**Channel:** alpha
**Release date:** 2026-05-06
**Predecessor:** v6.16.4.12.9.6 — Modori hotfix 6

## Summary

Sidebar user labels were STILL not rendering after .9.6. User
screenshot showed: avatar circle with fallback glyph visible,
"SYSTEM" label visible, "Matugen (Auto from Wallpaper)" theme
status visible — but the entire space to the right of the
avatar was blank. Not "wrong text" or "elided text" — completely
empty.

The .9.5 + .9.6 fixes were chasing the wrong root cause. The
data path (env-fallback resolution) was working fine — text
properties had correct values. The problem was the RENDER
SURFACE: the Item containing the Texts had collapsed to 0
width, so even with correct text content the labels had
nowhere to draw.

## Real root cause

**MouseArea inside RowLayout with `anchors.fill: parent`.**

The user row structure inherited from Tachiagari .7 was:

```qml
Rectangle {                       // sidebarUserBg
    RowLayout {                   // horizontal flow
        Rectangle { /* avatar */ }
        Item { /* text container */ }
        MouseArea {               // ← THIS
            anchors.fill: parent
        }
    }
}
```

The MouseArea has no `Layout.*` hints — it uses `anchors.fill:
parent` to cover the whole row. But it's a CHILD of RowLayout,
which means RowLayout tries to include it in horizontal
distribution. The combination of "Layout child but with no
Layout hints, sized via anchors" produces undefined behavior:

- The MouseArea claims to fill the parent → grabs all available
  space.
- RowLayout still tries to distribute space among its children.
- The Item (text container) and avatar Rectangle compete for
  whatever space is left after the MouseArea grabs the full
  width.
- In Qt 6 / Quickshell's specific layout implementation, the
  result was the Item collapsing to 0 width.

This is why the previous fix attempts didn't work:
- .9.5 changed ColumnLayout → Item + Column (right idea, wrong
  level — the OUTER container was already broken, not the inner
  one).
- .9.6 added env-fallback resolution (right defensive measure
  but the labels still couldn't render because the surface was
  0 width).

## Fix

Move MouseArea + hover-overlay Rectangle OUT of the RowLayout.
Make them siblings of the RowLayout (children of the outer
sidebarUserBg Rectangle):

```qml
Rectangle {                       // sidebarUserBg
    RowLayout {
        Rectangle { /* avatar */ }
        Item { /* text container, now gets full width */ }
    }
    MouseArea { anchors.fill: parent }       // sibling now
    Rectangle { /* hover overlay */ }        // sibling now
}
```

The MouseArea still covers the entire user row (anchors.fill:
parent now refers to sidebarUserBg, which is the same visual
area). The click target is unchanged. But now RowLayout has
only TWO children — avatar and text wrap — and distributes
space properly: 32px for avatar, the rest for text wrap.

Also added `Layout.minimumWidth: 60` to the Item as a belt-and-
suspenders measure, so even if some other layout pathology
appears in future Qt versions, the labels still get at minimum
60px of render space.

## Lesson

**Never put non-Layout positioned items (anchors-based) inside
a Layout.** They either get coerced into the layout flow with
broken sizing, or break the flow for everyone else.

The pattern shipped in Tachiagari .7 because it worked under
the conditions that release was tested in. It broke later
because of slight differences in the runtime Layout solver
behavior — a compiler optimization or version difference in
Quickshell can shift which sibling "wins" the space-grab race.
The fix is structural: don't create the conflict in the first
place.

## Files changed

| File | Change |
|---|---|
| `zen-shell-v5/ZenVersion.qml` | Bumped to v6.16.4.12.9.7. |
| `zen-shell-v5/ZenSettings.qml` | Sidebar user-row MouseArea + hover-overlay Rectangle moved from inside the RowLayout (where they were coercing the layout flow) to be siblings of the RowLayout (children of the outer `sidebarUserBg` Rectangle). RowLayout now contains only avatar + text wrap, distributes space correctly. `Item` containing username + hostname Texts gets `Layout.minimumWidth: 60` as belt-and-suspenders. Click target and hover behavior unchanged. Comment block above explains why this structure is required. |
| `install.sh` | Banner version + success banner + final "Done. Enjoy" message bumped. |
| `CHANGELOG-v6.16.4.12.9.7.md` | NEW (this file). |

## Migration

```bash
cd zen_barebone_alpha_development
git pull
git checkout alpha-v6.16.4.12.9.7
./install.sh
pkill -x quickshell
qs -c zen-shell &
```

After the fix, the labels should render IMMEDIATELY at startup,
visible at all times regardless of any window manipulation. The
fact that they were missing on a fresh shell start — not just
after a window-monitor crossing — was the clue that this was a
structural layout bug, not a transient state issue.

## Carry-forward

All Modori .9.6 features preserved:

- Smart-contrast theme engine
- Modori Dark + Light themes + paired procedural wallpapers
- Default wallpaper switched to Modori Dark on fresh install
- Settings persistence fix
- Slider-drag save corruption fix
- Left/Right panel position cards hidden + L/R-to-Bottom
  migration safety net
- Env-fallback name resolution (still active — defensive
  measure for the case where UserProfileService is empty)
- Updated README image URLs pointing to actual demo repo files
- All Tachiagari .7.1 features

## Wala tayong babawasan

Same UI exactly. Avatar circle, username, @hostname, hover
border, click-to-userprofile — every visible feature unchanged.
Only the QML structure rearranged so the layout actually has a
chance to render the Texts.
