# v7.0.0-beta.1-hf82v — Smart Float Rules

**Channel:** beta (hotfix on hf82u)
**Released:** 2026-05-26
**Scope:** 4 files (WindowRulesService rewrite, AppFloatRuleEditPopup new,
             AppFloatRulesPage modified, install.sh 2-pass migration, ZenVersion bump)

## What it does

Per your spec: smart float rules with per-app size/center/monitor, notification on toggle,
scale-aware via Hyprland's native % units, per-app override popup with live preview.

### Smart per-app size buckets

| App class regex | Size W × H |
|---|---|
| `calc*` | 25% × 35% (tiny — calculators don't need much space) |
| `Picture-in-Picture` | 30% × 30% (corner overlay) |
| `brave`, `firefox`, `chromium`, `vivaldi`, `opera` | 75% × 75% (comfortable browsing) |
| `code`, `codium`, `vscode` | 80% × 80% (IDE needs space) |
| `kitty`, `foot`, `wezterm`, `alacritty`, `gnome-terminal` | 60% × 70% (terminal) |
| `pavucontrol`, `blueman`, `nm-connection-editor` | 40% × 60% (system tools) |
| `steam`, `lutris`, `heroic` | 70% × 80% (game launchers) |
| `thunar`, `nautilus`, `dolphin`, `nemo`, `pcmanfm` | 65% × 70% (file managers) |
| anything else | 65% × 70% (sensible default) |

### Output format (Hyprland 0.55 canonical)

```
windowrule = match:class ^(Brave-browser)$, float on, center on, size 75% 75%  # zen-shell-float
```

- `match:class` — required by 0.53+ syntax overhaul
- `float on` — required value (not bare `float`)
- `center on` — Hyprland built-in centering directive
- `size W% H%` — % units are **monitor-scale-aware automatically** per upstream wiki
  (your 1.25 + 1.50 monitors will both get correctly-proportioned windows
   without any code-side math)

### Per-app overrides UI

Click the gear icon next to any toggled-ON app → opens a popup with:
- Live preview rectangle (shows proportional size + center status)
- Width slider (10-100%)
- Height slider (10-100%)
- Center on screen toggle
- Monitor picker (auto / your actual monitors probed via `hyprctl monitors -j`)
- Apply / Reset (to smart defaults) / Cancel

### notify-send on every change

```
$ notify-send -a "Zen Shell" -i <app-icon> -t 3500 \
    "Brave-browser" "Float enabled  ·  75% × 75%, centered"
```

Toggle ON  → "Float enabled  ·  W% × H%, centered"
Toggle OFF → "Float disabled"
Override   → "Float updated  ·  W% × H%, centered"
Clear all  → "All float rules cleared"

### State persistence

- **Source of truth**: `~/.local/share/quickshell/zen-shell/window-rules.json`
  ```json
  {
    "floatRules": [
      { "class": "Brave-browser", "w": 75, "h": 75, "center": true, "monitor": "auto" },
      { "class": "kitty",         "w": 60, "h": 70, "center": true, "monitor": "auto" }
    ]
  }
  ```
- **Hyprland-readable output**: `~/.config/hypr/modules/zen-window-rules.conf`
  (auto-generated from JSON on every change; never hand-edited)

## install.sh — 2-pass migration

For users upgrading from hf82n-u (any prior float-rules version), install.sh runs:

**Pass A — Fix syntax** (formats 1+2 → format 3):
- `windowrulev2 = float, class:^(N)$` → `windowrule = match:class ^(N)$, float on`
- `windowrule = float, class:^(N)$` → `windowrule = match:class ^(N)$, float on`

**Pass B — Add smart defaults** (format 3 → format 4):
- Any bare `windowrule = match:class ^(N)$, float on` line gets `, center on, size W% H%`
  appended using the same smart bucket table as the QML service.

Idempotent — re-running is safe. Format 4 lines pass through unchanged.
Backup created at `.pre-hf82v-<timestamp>`.

## Files

| File | Status | Lines | Change |
|---|---|---|---|
| `WindowRulesService.qml` | rewritten | 250 | smart rules + JSON persistence + notify-send |
| `AppFloatRuleEditPopup.qml` | **NEW** | 200 | per-app override Dialog with live preview |
| `AppFloatRulesPage.qml` | modified | +50 | Edit button per row + popup wiring |
| `install.sh` | extended | +60 | 2-pass Perl migration with smart defaults |
| `ZenVersion.qml` | bumped | — | hf82u → hf82v |

## Install

```bash
tar -xzf zen-shell-v7_0_0-beta_1-hf82v.tgz
cd zen-shell-v7.0.0-beta.1-hf82v
./install.sh
pkill -f quickshell && sleep 1
quickshell -p ~/.config/quickshell/zen-shell &
```

## Verify

1. **Existing rules migrated**:
   ```bash
   cat ~/.config/hypr/modules/zen-window-rules.conf
   ```
   Every `# zen-shell-float` line should be: `windowrule = match:class ^(N)$, float on, center on, size W% H%`

2. **No Hyprland error overlay** after install or after toggling any app

3. **Notification on toggle**: Toggle Brave float → desktop notification appears

4. **Auto-center + sized**: Open Brave → opens floating, centered, ~75% screen size
   (your 1.25 monitor: actual pixels = 0.75 × (3440÷1.25) ≈ 2064px ≈ 75% of effective area)

5. **Per-app override**: Gear icon → popup opens with sliders → adjust → Apply → notification confirms

6. **Backup exists**: `ls ~/.config/hypr/modules/zen-window-rules.conf.pre-hf82v-*`

## Bucket adjustment

If you want to tweak the smart size bucket for your apps, edit
`~/.local/share/quickshell/zen-shell/window-rules.json` directly (then restart
Quickshell to re-load), OR open Settings → App Float Rules → gear icon → adjust
sliders. The JSON method is faster for bulk edits.

## Open threads

- Drag-easier (your 3rd question from earlier — still need pick)
- Samsung folder-style icon groups
- Profile setup popup positioning bug
- Dock Phase 2 / Phase 3
