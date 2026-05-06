# ZenDropdown migration guide — v6.16.4.12.6.14

## TL;DR (Taglish)

Bagong component `ZenDropdown.qml` na pwedeng gamitin INSTEAD OF `ZenComboBox`
sa control panel pages. Walang masisira — yung existing ZenComboBox usage sa
mga page na hindi pa migrated, gagana pa rin as before. Drop-in lang, page
by page, kung gusto mo.

## When to use which

**Use `ZenComboBox`** (existing) when:
- Page already uses it and you don't want to touch
- Need 100% compatibility with QQC2 ComboBox API (textRole, displayText, etc)
- Simple list of plain strings, no swatches/sections needed

**Use `ZenDropdown`** (new) when:
- Want the modern Justinmind-style look (fade-on-hover, swatches, sections)
- Need per-item disabled state with visible reason ("toggle on")
- Long list that benefits from inline search (auto-shown at >= 6 items)
- Want section grouping (Built-in / Custom, etc.)

## Side-by-side examples

### 1. Simple replacement (string list)

```qml
// BEFORE
ZenComboBox {
    Layout.preferredWidth: 260
    model: ["Option A", "Option B", "Option C"]
    currentIndex: 0
    onActivated: console.log(currentIndex)
}

// AFTER (visually nicer, identical behavior)
ZenDropdown {
    Layout.preferredWidth: 260
    model: ["Option A", "Option B", "Option C"]
    currentIndex: 0
    onActivated: console.log(currentIndex)
}
```

### 2. Theme picker with swatches + sections + disabled item

```qml
// Modern rich-model usage — use this pattern for ThemesPage:
ZenDropdown {
    Layout.preferredWidth: 260
    enabled: !ThemeService.matugenEnabled
    model: {
        const list = []
        const themes = ThemeService.availableThemes
        const builtins = themes.filter(t => t.is_builtin)
        const customs  = themes.filter(t => !t.is_builtin)
        if (builtins.length > 0) {
            list.push({ kind: "section", text: "Built-in" })
            for (const t of builtins) {
                list.push({
                    text: t.name,
                    value: t.id,
                    swatch: t.colors && t.colors.blue ? t.colors.blue : ""
                })
            }
        }
        if (customs.length > 0) {
            list.push({ kind: "section", text: "Custom" })
            for (const t of customs) {
                list.push({
                    text: t.name,
                    value: t.id,
                    swatch: t.colors && t.colors.blue ? t.colors.blue : "",
                    enabled: !ThemeService.matugenEnabled
                                || t.id === "matugen-auto",
                    meta: ThemeService.matugenEnabled
                            && t.id !== "matugen-auto"
                          ? "Matugen ON" : ""
                })
            }
        }
        return list
    }
    currentIndex: ThemeService.availableThemes.findIndex(
        t => t.id === ThemeService.themeId)
    onSelected: (entry) => {
        const theme = ThemeService.availableThemes.find(t => t.id === entry.value)
        if (theme) ThemeService.applyTheme(theme)
    }
}
```

## API reference

### Properties

| Property         | Type    | Default     | Description                                         |
|------------------|---------|-------------|-----------------------------------------------------|
| `model`          | array   | `[]`        | Plain strings OR rich entry objects (see schema)    |
| `currentIndex`   | int     | `-1`        | Selected entry index (`-1` = nothing selected)      |
| `placeholder`    | string  | `""`        | Trigger label when nothing selected                 |
| `maxPopupHeight` | int     | `320`       | Hard ceiling on popup height                        |
| `flipMargin`     | int     | `80`        | Min space below trigger before flipping upward      |
| `searchThreshold`| int     | `6`         | Min item count to auto-show search bar              |
| `emptyText`      | string  | `"No matches"` | Shown when search returns 0 hits                 |
| `currentText`    | string  | (read-only) | Text of currently-selected entry                    |
| `currentEntry`   | object  | (read-only) | Full entry object of current selection              |

### Signals

| Signal               | Args            | When                                                  |
|----------------------|-----------------|-------------------------------------------------------|
| `activated(index)`   | int             | After selection, with the new index                   |
| `selected(entry)`    | object          | After selection, with the full entry object           |

### Rich entry schema

```js
{
    kind:    "item" | "section",   // "section" = header (no click)
    text:    "Display label",
    value:   "any-internal-id",    // returned via .selected(entry)
    swatch:  "#7aa2f7",            // optional small color circle
    icon:    "\uf015",             // optional Nerd Font glyph (alt to swatch)
    meta:    "current",            // optional right-side hint label
    enabled: true                   // false = grayed out, unclickable
}
```

## Migration plan (page by page, no rush)

1. **ThemesPage** — first candidate (theme switcher already shown in mockup)
2. **GeneralPage** — font family, clock format dropdowns
3. **AnimationsPage** — animation curve / duration presets
4. **DecorationPage** — corner radius preset, blur strength preset
5. **DisplaysPage** — monitor mode, refresh rate, transform
6. **PanelPage** — bar position, font size preset
7. **BarModulesPage** — module on/off (uses checkboxes, not dropdown — skip)
8. **InputPage** — keyboard layout, mouse acceleration profile
9. **SoundNetworkPage** — default audio device, default network device

Stop midway if the visual change is too jarring. Wala tayo babawasan: any
unmigrated page keeps using ZenComboBox and works exactly as before.
