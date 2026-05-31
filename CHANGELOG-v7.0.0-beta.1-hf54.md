# v7.0.0-beta.1-hf54 — Mimic layout fix + robust install with verify

**Channel:** beta (hotfix)
**Released:** 2026-05-17
**Branch:** `dev`

---

## What this hotfix fixes

User report:

> "so bakit ganito itsura hahaha hindi sa top tas yun brave ko nung
> naka float mode wala naman yun hyprbar?"

Two distinct bugs:

1. **HyprbarsMimic mounted weirdly** — looked off-position / not properly
   at the top of Quick Settings + Settings panels. Probably overlapping
   with the existing headers.

2. **Brave still no hyprbar even on float mode** — plugin install
   appeared to "succeed" (no error shown) but Hyprland wasn't actually
   loading the plugin.

---

## Bug 1 — Double-header overlap

### Root cause

`ControlPanel.qml` and `ZenSettings.qml` both already had their own
header rows BEFORE hf53:

**ControlPanel header (existing):**
```
┌──────────────────────────────────────┐
│ ☰ Quick Settings              ✕      │  ← existing header at top
├──────────────────────────────────────┤
│ 🔊 ━━━━━━━━━━━━ 75%                 │
│ ...                                  │
```

When hf53 added HyprbarsMimic at `anchors.top: parent.top, topMargin: 4`,
it rendered ABOVE the existing header. Pero the existing header was
ALSO anchored to the top with `margins: 16`. Result: the mimic sat on
top of part of the existing header → looked like junk overlapping at
the top.

Plus, `mainLayout` had no clearance for the mimic — its `anchors.topMargin`
was the static `16`, so all the content was at the original position.

### Fix

Two-part:

1. **Hide the existing header when the mimic is showing:**
   ```qml
   Item {
       visible: !(typeof HyprbarsService !== "undefined" && HyprbarsService.enabled)
       Layout.preferredHeight: visible ? 36 : 0
       // ... existing header content ...
   }
   ```
   When `HyprbarsService.enabled` is true, the existing header collapses
   to 0 height and hides. The mimic becomes the only header visible.

2. **Push mainLayout down to clear the mimic:**
   ```qml
   ColumnLayout {
       id: mainLayout
       anchors.topMargin: 16 + (hyprbarsMimic.visible
                                ? hyprbarsMimic.height + 4 : 0)
   }
   ```
   When mimic is visible, mainLayout adds `barHeight + 4px` of top
   margin to slide all content below the mimic.

Same fix applied to `ZenSettings.qml`'s gear-icon Settings header.

### Visual result

**Before hf54** (with mimic enabled):
```
┌──────────────────────────────────────┐
│ ╳━━━━━━━━━ Quick Settings ━━━━━━━━╳ │  ← mimic
│ ☰ Quick Settings              ✕      │  ← existing header overlapping!
├──────────────────────────────────────┤
│ 🔊 ━━━━━━━━━━━━                     │
```

**After hf54** (with mimic enabled):
```
┌──────────────────────────────────────┐
│ ╳━━━━━━━━━ Quick Settings ━━━━━━━━╳ │  ← mimic only
├──────────────────────────────────────┤
│ 🔊 ━━━━━━━━━━━━                     │
│ ...                                  │
```

Existing header automatically returns when mimic is hidden (hyprbars
disabled).

---

## Bug 2 — Plugin install silently failing

### Root causes (multiple possible)

The hf52 + hf53 install command did:
```bash
hyprpm add ...
hyprpm enable hyprbars
hyprpm reload
```

But several things could go wrong silently:

1. **hyprpm command not found** — on some distros it's a separate
   package (e.g. `hyprland-devel` on Arch)
2. **Missing build deps** — cpio, cmake, git, meson, gcc — the build
   step crashes mid-way
3. **No source line in hyprland.conf** — the plugin gets loaded by
   hyprpm but the `plugin { hyprbars { ... } }` config never reaches
   Hyprland because we didn't `source = ` the file
4. **hyprctl reload not called** — even if config is sourced, Hyprland
   doesn't pick it up without an explicit reload
5. **hyprpm permission denied** — if user has permission management
   enabled in Hyprland (`permission = ...`), hyprpm needs an allow rule

In all 5 cases, the install command exits 0 (or close to it), and the
user sees no bars. With no diagnostic, impossible to figure out which
one is broken.

### Fix — robust 6-step install with pre-flight + verify

```bash
# Step 1: pre-flight — hyprpm exists?
command -v hyprpm >/dev/null || { echo 'ERROR: hyprpm not found'; exit 10; }

# Step 2: pre-flight — build deps
missing=''
for tool in cpio cmake git meson gcc; do
    command -v $tool >/dev/null || missing="$missing $tool"
done
[ -n "$missing" ] && {
    echo "ERROR: missing build deps:$missing"
    echo 'Run: sudo pacman -S --needed cpio cmake git meson gcc'
    exit 11
}

# Step 3: ensure source line in hyprland.conf (idempotent)
SRC_LINE='source = ~/.config/hypr/zen-hyprbars.conf'
grep -qxF "$SRC_LINE" ~/.config/hypr/hyprland.conf || echo "$SRC_LINE" >> ~/.config/hypr/hyprland.conf

# Step 4: hyprpm add
hyprpm add https://github.com/hyprwm/hyprland-plugins

# Step 5: hyprpm enable + reload (plugin)
hyprpm enable hyprbars
hyprpm reload

# Step 6: hyprctl reload (config)
hyprctl reload

# Verification
hyprctl plugin list | grep -qi hyprbars \
    && echo '✅ hyprbars is loaded' \
    || echo '⚠ hyprbars NOT detected — check permissions/build'
```

The pre-flight checks fail fast with clear error messages. The
verification step at the end actually confirms hyprbars is loaded
into the running Hyprland — if it's missing, surfaces that to the
user immediately via the status message + toast.

---

## NEW: "Check status" diagnostic button

Yellow button beside Install / Update sa Settings UI. Fires:

```bash
echo 'Hyprland version:'
hyprctl version | head -2

echo 'Loaded plugins:'
hyprctl plugin list

echo 'Config file:'
ls -la ~/.config/hypr/zen-hyprbars.conf

echo 'Source line in hyprland.conf:'
grep -F 'zen-hyprbars.conf' ~/.config/hypr/hyprland.conf

echo 'hyprpm enabled plugins:'
hyprpm list | grep -A1 -i hyprbars
```

Output appears in the status message area. Tells you exactly where
the chain is broken if hyprbars isn't working.

---

## Files modified (5)

```
zen-shell-v5/HyprbarsService.qml      — robust install script + checkStatus
zen-shell-v5/HyprbarsSettingsPage.qml — "Check status" button
zen-shell-v5/ControlPanel.qml         — hide existing header when mimic shows,
                                          dynamic mainLayout topMargin
zen-shell-v5/ZenSettings.qml          — hide existing header when mimic shows,
                                          RowLayout topMargin for mimic
zen-shell-v5/ZenVersion.qml           — bumped to hf54
install.sh                             — banner + changelog
```

---

## How to install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf54-mimic-layout-robust-install.tgz
cd zen-shell-v7.0.0-beta.1-hf54
./install.sh
```

`pkill quickshell` to reload.

---

## How to test

### Test 1: Mimic layout

1. Open Quick Settings (Super+C) WITH hyprbars enabled
2. Top of panel should show ONLY the mimic bar (no double header)
3. Content sliders / toggles should be just below the mimic, not cut off
4. Disable hyprbars → existing header reappears, mimic disappears

### Test 2: Robust install + verify

1. Settings → Hyprbars → click "Install / reinstall"
2. Watch the status message progress through steps 1/6 → 6/6
3. At the end: should see "✅ hyprbars is loaded into Hyprland"
4. Open Brave → if floating → bar should appear ✅
5. If you see "⚠ hyprbars NOT detected", the verify step found
   something wrong — read the rest of the output to see which step failed

### Test 3: Diagnostic Check status

1. Settings → Hyprbars → click yellow "Check status" button
2. Status message shows:
   - Hyprland version
   - Loaded plugins list (look for "hyprbars")
   - Config file presence
   - Source line presence in hyprland.conf
   - hyprpm enabled list
3. Anything with ❌ tells you the broken link

---

## Common gotchas (read this if bars still don't appear)

### Permission management

If your `~/.config/hypr/hyprland.conf` has any `permission = ...` line,
hyprpm may be blocked. Add this:

```hypr
permission = /usr/(bin|local/bin)/hyprpm, plugin, allow
```

### Float-mode rule

With "Show bars only on floating windows" ON (default), Brave needs to
ACTUALLY be floating. Default Brave starts tiled in Hyprland.

To float a window:
- Default Hyprland keybind: `Super+V` (toggle floating)
- Or windowrule in hyprland.conf: `windowrule = float, class:^(Brave-browser)$`

Once Brave is floating, the bar should appear instantly (the
`floating:0` rule is dynamic).

### Build fails on first install

Look at the status output. If it says "missing build deps", run:

```bash
sudo pacman -S --needed cpio cmake git meson gcc
```

Then click Install again.

---

## Wala tayong babawasan

All previous fixes preserved:

- ✅ hf53 floating-only + status feedback + Zen popup mimic
- ✅ hf52 hyprbars plugin integration foundation
- ✅ hf51 sticky editor focus-loss safety
- ✅ hf50 click-through + close + widget input/drag/live-sync
- ✅ hf49 sticky drag pattern + panel-level draggable
- ✅ hf48 hyprlock unlock focus reset
- ✅ hf47 sticky as desktop widgets

🍃 The mimic now actually sits at the top properly, and the install
fails loudly with actionable errors when something's wrong instead
of silently producing a no-op.
