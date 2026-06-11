# Zen Shell — Quickshell-native desktop for Hyprland

**Current version: v7.0.0-alpha.6 "Karui" (軽い)** — alpha
**Repo branch:** `dev` (v7 line)

> **v7.0.0-alpha.6 note** — Karui ("lightweight") · LaptopModeService.
> First of the v7 performance trio. Three modes (Off / Balanced /
> Endurance) drive adaptive polling on existing services so battery
> drain drops without sacrificing responsiveness when plugged in.
>
> - **SystemMonitorService**: 2s default → 5–30s adaptive based on
>   mode + battery%
> - **WeatherService**: refresh suppressed below low-battery threshold
> - **ZenStrings (audio rope)**: falls back to static when battery is
>   critical in Endurance
> - **CPU governor**: auto-switch to power-saver via existing
>   `PowerProfileService` when in Endurance + on battery
> - **Hyprland animations**: optional Endurance sub-toggle pushes a
>   minimal-animation snippet to `~/.config/hypr/zen-laptop-anims.conf`
>   and `hyprctl reload`s — restored to defaults when unplugged
> - **Battery health**: optional 80% charge limit if the kernel
>   exposes `charge_control_end_threshold` for your BAT*
> - **Auto-detect**: hides itself on desktops (chassis_type + BAT*
>   sniff). Manual override available for users who want it on desktop.
>
> Coming next: alpha.6 ZenCleanupService (RAM cleaner + zombie reaper),
> alpha.7 QML lazy-load pass. Wala tayong babawasan.
> Brand-new Win11-inspired dual-pane Start Menu, fully replacing the
> v6 single-list panel. Highlights:
>
> - **Dynamic pinned grid** (3-6 columns × 1-8 rows, configurable in
>   Settings → Bar Modules → Start Menu)
> - **Auto-detection** of every installed app from pacman, AUR, Flatpak
>   (system + user), and Snap. Auto-refresh within ~500ms after install
>   via inotifywait fallback layered on Quickshell's DesktopEntries
>   watcher
> - **Recent files** from `~/.local/share/recently-used.xbel` (the
>   freedesktop XBEL spec — covers GTK, KDE, GNOME, Nautilus, etc.)
> - **Most Used** subsection driven by per-app launch counts
> - **Memory/perf-friendly**: ListView with reuseItems + cacheBuffer,
>   asynchronous icon loading, debounced search, capped `sourceSize`
> - **Dynamic theme colors** via the existing Modori smart-contrast
>   layer — readable against ANY palette including Matugen-generated
>   themes
> - **Densho-aware** when toggle on: 固定 Pinned · 最近 Recent ·
>   全アプリ All Apps · 常用 Most Used · 全て All

A QML desktop environment built on [Quickshell](https://quickshell.outfoxxed.me/)
for [Hyprland](https://hyprland.org/) 0.54+. Includes a configurable bar,
start menu, control panel, settings UI, system monitoring, wallpaper
manager, audio-reactive music visualization, unified theme engine with
**WCAG-aware smart contrast**, in-shell WiFi/Bluetooth selectors with
proper Wayland-overlay password prompt, and on-the-fly dark mode toggle
synced across GTK3/4/libadwaita apps.

> **v6.16.4.12.9.10 note** — Modori ("return / coming back"). After
> the Tategaki vertical-bar attempt hit three startup-blocking parser
> errors and a broken empty-bar render, we rolled the bar code back
> to the proven Tachiagari .7.1 base. Modori then added back ONLY
> the narrowly-scoped, low-risk fixes that solved real user-reported
> bugs, plus shipped a series of UX-completeness drops:
>
> - **Smart-contrast theme engine** that detects light vs dark
>   backgrounds and auto-adjusts foreground tones to ensure readable
>   WCAG 4.5:1 contrast on every theme — including custom user themes
> - **Two new built-in themes** (Modori Dark / Modori Light) with
>   paired procedural wallpapers (calligraphic enso ink-wash)
> - **Bulletproof sidebar user labels** that survive monitor crossings
>   and singleton transients (env-fallback resolution)
> - **GTK Dark Mode toggle** in the Control Panel that syncs gsettings
>   + GTK3/4 settings.ini + libadwaita in one tap
> - **Convenient WiFi+BT redesign** — saved/available split, larger
>   tap targets, refresh button, forget button, BT scan + pair flow
> - **In-shell password prompt** at WlrLayer.Overlay — replaces the
>   zenity dialog that was getting hidden behind the Control Panel

![Zen Shell Modori desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg)

---

## What's new in Modori (v6.16.4.12.9.x) — alpha

| Area | Change |
|---|---|
| **In-shell WiFi password prompt (NEW · .9.10)** | Replaces `zenity --password` with a proper Wayland overlay popup at `WlrLayer.Overlay`. Floats above all other surfaces including the Control Panel that triggered it — impossible to hide. Centered on focused monitor with dimmed backdrop. Auto-focuses password field on open, Enter to submit, Esc to cancel. Show/hide password toggle (eye icon). Click outside backdrop or any surface outside the prompt → cancel via `HyprlandFocusGrab`. Uses theme-aware colors so it matches the rest of the shell. |
| **Convenient WiFi+BT redesign (NEW · .9.9)** | Major Control Panel WiFi + Bluetooth tab redesign. WiFi: Saved Networks section at top (tap to reconnect, trash to forget), Available Networks below sorted by signal, larger 44px rows, signal-strength colored icons (green ≥60%, yellow ≥35%, grey below), lock icon for secured, whole-row tap targets, explicit Rescan button. Bluetooth: Connected/Paired/Nearby section split, scan toggle button, tap-to-reconnect for paired-but-disconnected devices, tap-to-pair for nearby (pair + trust + connect chain), trash button to unpair. New ConnectivityService API: `forgetWifi`, `scanWifi`, `reconnectWifi`, `startBtScan` / `stopBtScan`, `pairBtDevice`, `unpairBtDevice`, `savedWifiNetworks`, `btPairedDevices`, `btNearbyDevices`, `btScanning`. |
| **GTK Dark Mode toggle (NEW · .9.8)** | Toggle row in Control Panel (Super+C) right after Gaming Boost. One tap flips four sync points atomically: `gsettings color-scheme` (libadwaita + GTK4), `gsettings gtk-theme` (legacy GTK3), `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`. State persists to `~/.local/share/zen-shell/darkmode.state`. Affects every GTK3/4/libadwaita app that respects gsettings or settings.ini — Thunar, Nautilus, GNOME Settings, Geary, GIMP, gnome-text-editor. Apps with their own theme preference (Firefox, Chromium) are unaffected by design. Custom GTK theme override via `$ZEN_GTK_DARK` / `$ZEN_GTK_LIGHT` env vars (defaults `Adwaita-dark` / `Adwaita`). |
| **Bulletproof sidebar user labels (.9.7)** | Username + @hostname text labels in the Settings sidebar bottom row are now structurally guaranteed to render. Three-step fix: (1) MouseArea moved out of the RowLayout (it was inside, with `anchors.fill: parent`, which corrupted the RowLayout's space distribution and collapsed the text container to 0 width), (2) Item with explicit `Math.max(60, sidebarUserBg.width - 32 - 26)` width math + 60px floor as a sanity net, (3) env-fallback resolution — labels read from `Quickshell.env("USER")` and `Quickshell.env("HOSTNAME")` if `UserProfileService` transiently empties (e.g. after window-monitor crossing). Avatar still uses the service's `effectiveAvatarSource` with the blue fallback glyph. |
| **Smart contrast theme engine (.9.4)** | `ThemeService.qml` runs every loaded theme through a luminance check. If `bg0` is light and `fg`/`grey0`/`grey1`/`grey2` would be unreadable against it (or the inverse for dark themes), the foreground tones get auto-nudged toward black/white using a binary search until the WCAG 4.5:1 contrast ratio is reached. Themes that are already correct pass through unchanged. Custom user themes get the same protection on import. Accent colors (red/orange/blue/etc.) are deliberately NOT corrected — those are decorative-fill, not body-text, and their hue is part of the theme's identity. |
| **Modori Dark + Light themes (.9.2)** | Two new built-in themes (under `themes-builtin/`) sharing the same persimmon accent (`#e87554`) for visual continuity. Modori Dark: deep midnight indigo bg, bone-white fg. Modori Light: warm washi cream bg, sumi-ink black fg. |
| **Modori Dark + Light wallpapers (.9.2)** | Two paired procedural wallpapers (2560×1440 PNG, ~5MB each) in `wallpapers-builtin/`. Composition: imperfect enso (zen circle, open at bottom-left) drawn with multi-layer ink wash + "Sho" calligraphic pressure curve, persimmon dot inside marking "home", subtle 戻 kanji watermark. Both share the same composition — same scene at different times of day. Dark variant has scattered star specks; light variant has paper fiber texture. |
| **Settings persistence fix (.9)** | `Theme.qml`'s layout loader stopped reading stale `style` from `bar-layout.json`. Module Shape (Pill/Round), Bar Opacity, Bar Corner Radius are owned by PanelState exclusively now. The clobber bug that silently reverted these on restart is dead. |
| **Slider-drag save corruption fix (.9)** | `PanelState.saveState()` is debounced through a 200ms Timer. Rapid slider drags previously fired `saveState()` ~60×/second, each spawning an overlapping bash heredoc write — corrupting the JSON. Now one bash spawn per gesture. |
| **Fresh-install default wallpaper (.9.4)** | `install.sh` detects "no existing user wallpaper" via `wallpaper-state.json` absence/staleness and applies `modori-wallpaper-dark.png` automatically via swww. Fetched from `Gekinzen/images-demo` if curl is available; falls back to the local copy in `wallpapers-builtin/` if offline. Existing user wallpapers are NEVER overwritten on re-install. |
| **L/R panel position (hidden) (.9.3)** | Settings → Panel → Panel Position no longer shows Left or Right cards. Vertical bar rendering is deferred to a properly-validated future drop. Top + Bottom only. PanelState includes a migration safety net: any saved `panelPosition: "left"/"right"` from previous testing auto-migrates to `"bottom"` on load. |

Wala tayong babawasan — every Tachiagari .7.1 feature is preserved
verbatim. Smart-contrast logic is additive (themes with already-good
contrast pass through unchanged). The L/R picker hide is a UI
visibility change; the underlying popup-direction logic for vertical
bars stays in PanelState ready for the future drop.

---

## Codename history (recent)

| Version | Codename | Channel | What it brought |
|---|---|---|---|
| **v6.16.4.12.9.10** | **Modori (戻り) hf10** | alpha | In-shell WiFi password prompt at WlrLayer.Overlay (replaces zenity that was hiding behind the Control Panel) |
| v6.16.4.12.9.9      | Modori (戻り) hf9       | alpha | WiFi+BT Control Panel redesign — saved/available split, refresh, forget, BT scan+pair, larger tap targets |
| v6.16.4.12.9.8      | Modori (戻り) hf8       | alpha | GTK Dark Mode toggle wired into Control Panel (DarkModeService + zen-darkmode.sh ported from Kintsugi line) |
| v6.16.4.12.9.7      | Modori (戻り) hf7       | alpha | Sidebar user labels structurally fixed (MouseArea moved out of RowLayout — was corrupting flow) |
| v6.16.4.12.9.6      | Modori (戻り) hf6       | alpha | Bulletproof sidebar user labels (env-fallback) + README image URLs corrected to actual demo repo files |
| v6.16.4.12.9.5      | Modori (戻り) hf5       | alpha | First sidebar label fix attempt (Layout-system races) — incomplete, deeper structural issue surfaced |
| v6.16.4.12.9.4      | Modori (戻り) hf4       | alpha | Smart-contrast theme engine + fresh-install default-wallpaper switch to Modori Dark + comprehensive README rewrite |
| v6.16.4.12.9.3      | Modori (戻り) hf3       | alpha | Hide Left/Right panel-position cards (broke Settings sidebar) + L/R-to-Bottom migration safety net |
| v6.16.4.12.9.2      | Modori (戻り) hf2       | alpha | Modori Dark + Light wallpapers (procedural enso) + matching themes |
| v6.16.4.12.9.1      | Modori (戻り) hf1       | alpha | Removed redundant title-bar user pill (sidebar bottom row was already showing it — was double) |
| v6.16.4.12.9        | **Modori (戻り)**        | alpha | Rolled back Tategaki vertical-bar attempt; kept settings-persistence fix + debounced save + title-bar user pill |
| v6.16.4.12.8.x      | Tategaki (縦書き) ❌    | alpha (rolled back) | Vertical bar rendering attempt — 3 startup crashes; reverted in Modori .9 |
| v6.16.4.12.7.1      | Tachiagari (立ち上がり) hf1 | alpha | 4-direction popup edge logic (Top/Bottom/Left/Right anchor flips) |
| v6.16.4.12.7        | **Tachiagari (立ち上がり)** | alpha | Pill fix + sidebar user row + smart gaming + start-button border + top-bar popup adaptation + monitor-fix-v2 merge |
| v6.16.4.12.6.53     | Hiraki (開き) hf1       | alpha | install.sh ZenClock-clobber fix + calendar popup x-tracks-clock |
| v6.16.4.12.6.52     | Hiraki (開き)           | alpha | Click-to-open Clock + StartMenu (no hover open) |
| v6.16.4.12.6.51     | Hikari (光)             | alpha | Bar/clock UX cleanup, plugin system overhaul |

---

## In-shell WiFi password prompt — how it works

The previous WiFi connect flow used `zenity --password` to prompt for
new secured-network credentials. zenity opens its own X11/XWayland
window which, on Hyprland (and most wlroots compositors without
strict focus stealing), often landed BEHIND the Control Panel that
the user had just clicked. User clicked Connect, nothing visible
happened, the connect attempt felt broken — they had to alt-tab
to find the prompt.

The new prompt is a Quickshell `PanelWindow` rendered at
`WlrLayer.Overlay` (the topmost compositor layer). It cannot be
hidden by any other surface — the layer-shell protocol guarantees
it sits above every regular client window AND every other shell
surface (including the Control Panel). The prompt is centered on
the focused monitor with a dimmed backdrop covering the rest of
the screen.

Layout:

```
┌─────────────────────────────────────┐
│ 🔒  Wi-Fi password required        │
│      KiyuFamilyFibr                 │
│                                     │
│ ┌─────────────────────────────┬──┐  │
│ │ Password                    │👁│  │
│ └─────────────────────────────┴──┘  │
│                                     │
│              [ Cancel ]  [Connect]  │
└─────────────────────────────────────┘
```

Behavior:

- **Auto-focus** the password field on open — start typing
  immediately, no extra click needed
- **Enter** submits, **Esc** cancels
- **Eye icon** toggles show/hide password (between `TextInput.Password`
  and `TextInput.Normal` echoMode)
- **Click outside** the card on the dimmed backdrop → cancel
- **Click any other surface** outside the overlay window
  (e.g. the bar, a desktop widget) → cancel via
  `HyprlandFocusGrab.onCleared`
- **Connect button** is disabled while the password field is empty
- **Themed colors** match the active Zen Shell theme (uses
  `ThemeService.alpha`, `ThemeService.bg0`, `ThemeService.blue`,
  `ThemeService.fg` — no GTK theme dependency)

Architecture:

- **`PasswordPromptService.qml`** — singleton holding `active`,
  `ssid`, `errorMessage` reactive properties. Public API:
  `requestPassword(ssid, onSubmit, onCancel)`. Callbacks are
  stored as JS function refs and invoked safely with try/catch.
- **`PasswordPromptPanel.qml`** — visual content (backdrop +
  centered card with TextField + buttons). Reads service state
  reactively.
- **`shell.qml`** — `Variants { model: Quickshell.screens }` block
  mounts a `PanelWindow` per screen, but only the focused-monitor
  instance is ever visible. `WlrLayershell.layer: WlrLayer.Overlay`,
  `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`,
  `HyprlandFocusGrab` for outside-click cancel.
- **`ConnectivityService.connectWifi()`** rewritten as async
  pipeline: saved-creds check → branch (saved → reconnect; new
  + open → connect; new + secured → request password via service
  with callback that runs the actual `nmcli device wifi connect ...
  password ...`).

If `PasswordPromptService` is somehow undefined (extremely unlikely
since it's a singleton auto-discovered by Quickshell), the code
falls back to the old zenity invocation. Worst-case regression =
behaves like before.

---

## Smart contrast theme engine — how it works

Themes ship with hex colors that may or may not have been tested for
WCAG-style readability. Light themes are especially prone to subtle
traps: a designer picks `grey0: #aaa` because it looks fine against
the dark `bg0: #1a1b26` they were working on, but when `grey0` gets
applied as secondary text against a light theme's `bg0: #f5ede0`,
the contrast collapses to ~1.4:1 and the text becomes essentially
unreadable.

`ThemeService.qml`'s `_autoContrast()` pass intercepts every
theme load (built-in OR user-imported), runs each foreground tone
through:

1. **Compute relative luminance** of `bg0` using the WCAG formula
   (`0.2126·R + 0.7152·G + 0.0722·B` on linearized sRGB).
2. **Compute current contrast ratio** between each foreground tone
   and `bg0`: `(L_bright + 0.05) / (L_dark + 0.05)`.
3. **If the ratio meets the target**, pass through unchanged.
4. **Otherwise**, binary-search the smallest lerp toward black (light
   bg) or white (dark bg) that brings the ratio up to target. Stop AT
   the threshold rather than overshooting — the theme keeps as much
   of its designed warmth as possible.

Targets (WCAG-aligned):

| Tone | Used for | Target ratio |
|---|---|---|
| `fg` | Body text, primary labels | **4.5:1** (WCAG AA) |
| `grey0` | Secondary text, subtitles | **4.5:1** |
| `grey1` | Tertiary text, placeholders | **3.5:1** |
| `grey2` | Borders, dividers, dim states | **2.5:1** |

Accent colors (`red`, `orange`, `yellow`, `green`, `aqua`, `blue`,
`purple`) are deliberately **NOT corrected**. Those are used as fills,
borders, and badges — not primary readable text — and the accent
hue is part of the theme's visual identity. Forcing them toward
black/white would mute the theme's character.

Custom user themes (imported via Settings → Themes → Import) get the
same correction pass automatically. There's no opt-out — readability
is non-negotiable for body text. If a theme designer specifically
wants a near-invisible secondary tone for stylistic reasons, the
`bg2`/`bg3` slots are still passed through unchanged and can be used
as a tone instead.

---

## Modori built-in wallpapers + themes

Two paired wallpapers ship under `wallpapers-builtin/`, automatically
copied to `~/.config/zen-shell/wallpapers/` on `./install.sh`. Both
share the same composition — an imperfect enso (zen calligraphic
circle), open at the bottom-left, with a small persimmon dot inside
marking "home". The dark variant places this against a deep
night-into-dawn gradient with subtle stars; the light variant uses
warm washi paper texture with sumi-ink black for the enso. The
persimmon accent (`#e87554`) is identical in both — giving them the
sense of being the same scene at different times of day.

A faint **戻** kanji watermark sits in the lower-right corner on both.

The wallpapers are rendered procedurally with PIL/Pillow + numpy +
scipy (script in source: `render_wallpapers.py`, not shipped in the
tarball). The enso uses circle-stamping (800 stamps along the path,
no line-segment artifacts), 3-layer ink wash (wide pale halo + mid
bleed + narrow dark core), and a "Sho" calligraphic pressure curve
along the stroke (peaks at 30% of the path, 1.6-power lift-off taper
for the final 15%).

Two matching themes ship under `themes-builtin/modori-{dark,light}.json`.
Both share the persimmon `orange` accent and a calm, low-saturation
palette overall — fits the "calm return to baseline" aesthetic of the
codename.

---

## Modori demo gallery — v6.16.4.12.9.x

Live captures from the Modori release cycle. Browse the full set in
the [`zen_6_16_4_12_9_3/` folder of `Gekinzen/images-demo`](https://github.com/Gekinzen/images-demo/tree/main/zen_6_16_4_12_9_3):

![Modori demo 1](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg)

[Open original →](https://github.com/Gekinzen/images-demo/blob/main/zen_6_16_4_12_9_3/139a7e9c-15f9-4a32-bf1c-01af9e733206.jpeg)

![Modori demo 2](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/6f6b715b-23ff-4848-9951-271b37c9d181.jpeg)

[Open original →](https://github.com/Gekinzen/images-demo/blob/main/zen_6_16_4_12_9_3/6f6b715b-23ff-4848-9951-271b37c9d181.jpeg)

![Modori demo 3](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/88899f5d-988a-40a3-b617-11793c725ace.jpeg)

[Open original →](https://github.com/Gekinzen/images-demo/blob/main/zen_6_16_4_12_9_3/88899f5d-988a-40a3-b617-11793c725ace.jpeg)

![Modori demo 4](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/ba068284-016a-4c0f-9558-d3a75856ed23.jpeg)

[Open original →](https://github.com/Gekinzen/images-demo/blob/main/zen_6_16_4_12_9_3/ba068284-016a-4c0f-9558-d3a75856ed23.jpeg)

![Modori demo 5](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/caceb645-19f7-4d12-b7ce-dbac49945fbb.jpeg)

[Open original →](https://github.com/Gekinzen/images-demo/blob/main/zen_6_16_4_12_9_3/caceb645-19f7-4d12-b7ce-dbac49945fbb.jpeg)

![Modori demo 6](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_12_9_3/cde0b11c-cf67-40ca-9153-5d88008cd884.jpeg)

[Open original →](https://github.com/Gekinzen/images-demo/blob/main/zen_6_16_4_12_9_3/cde0b11c-cf67-40ca-9153-5d88008cd884.jpeg)

---

## Upcoming alpha — coming soon

Next items planned for the alpha series. Order is approximate; some
may shuffle based on user feedback.

### Wrong-password feedback

The current in-shell password prompt closes immediately on submit
and runs `nmcli` in the background. If `nmcli` returns an
authentication error, the Control Panel just shows the network as
still not active — no "wrong password" feedback in the prompt
itself. Better: watch the `actionRunner` exit code, re-open the
prompt with `setError("Authentication failed")` if it failed.

### "Connect automatically" checkbox in password prompt

Add a checkbox to the in-shell prompt that sets
`connection.autoconnect=true` on the newly-created nmcli
connection. Most users want this enabled by default; current
behavior is whatever `nmcli`'s default is for the system.

### WPA-Enterprise (802.1X) support

Enterprise networks (university campuses, corporate WiFi) need
more fields than just a password — typically username, identity,
EAP method, CA certificate path. The current prompt treats them
as standard WPA which fails silently. Plan: detect 802.1X security
in the network scan, switch the prompt to a multi-field expanded
form when needed.

### Confirm dialogs for destructive actions

Forget WiFi network and Unpair Bluetooth device currently fire on
single tap. Easy to misclick. Plan: small confirm popup using the
same overlay pattern as the password prompt — "Forget {SSID}? This
will require entering the password again next time."

### Auto-rescan WiFi every 30s while tab is open

Currently the WiFi list updates only on initial poll + manual
Rescan button click. While the user has the WiFi tab open, a
periodic background rescan (every 30s) would keep the signal
strengths and discovered networks fresh without manual action.

### Bluetooth audio sink routing

When connecting Bluetooth headphones/speakers, prompt to switch
the active PipeWire audio sink to the BT device. Avoids the
"connected my headphones but audio still goes to laptop speakers"
confusion. Requires PipeWire integration via `wpctl`.

### Multi-bar signal-strength glyphs

The current WiFi rows use a single fa-wifi glyph color-coded by
signal strength. Nerd Font has separate tier glyphs (`\uf683`
`\uf682` `\uf681` etc.) that show fewer bars at lower strength.
Visual upgrade only — same data underneath.

### In-app browser for community wallpapers

Settings → Wallpapers already supports folder scanning, slideshow
scheduling, and transition effects. Upcoming: an in-app browser
for the `Gekinzen/images-demo/wallpapers/` repo so users can
preview and one-click-apply community wallpapers without leaving
the panel. The Modori wallpapers will appear there as featured.

### Theme importer with smart-contrast preview

Settings → Themes → Import currently just copies a JSON file in.
Upcoming: a side-by-side preview pane showing the theme as
designed vs the theme after smart-contrast correction, so users
can see what the engine adjusted. Designers who want to opt out of
correction can add `"smart_contrast": false` to the theme JSON.

### Matugen (Material You) integration polish

Matugen wallpaper-driven theming was added in v6.16.4.12.6
(opt-in); upcoming work makes it a first-class citizen in the
Settings → Themes page with live preview, palette extraction
visualization, and per-mode (light/dark) target controls. The
smart-contrast pass already protects Matugen-generated themes from
the same readability traps — that integration is the ground truth.

### Plugin system v2

The plugin manager was hidden in Hikari .51 because the plugin
loading interface was being reworked. v2 brings: signed-manifest
plugins (avoid arbitrary code execution surprises), per-plugin
sandboxing for QML scope, dependency declaration, and a community
registry. Target: a properly-stable plugin API by the time the
beta channel opens.

### Tategaki redux (vertical bar rendering, properly)

The Tategaki vertical-bar attempt failed the first time because it
tried to convert ~12 bar modules + Bar.qml outer layout + shell.qml
window dimensions + MusicStrings rotation all in one drop, with no
runtime test infrastructure. The next attempt will be staged
differently:

1. **One module at a time.** Convert `Workspaces` to vertical-aware,
   ship, validate. Then `SysRow` alone, ship, validate. Then
   `Taskbar` (the trickiest — has chevron-paginated scroll). Each
   module becomes a separate drop within the cycle.
2. **Bar.qml uses Loader-driven RowLayout/ColumnLayout swap**, not
   GridLayout flow tricks. The flow-swap approach didn't size
   children the way RowLayout did in the live Quickshell build,
   causing the empty-bar symptom in the .8.3 test.
3. **No 90° text rotation transforms inside the bar.** Mainstream
   vertical-panel desktops (KDE Plasma, Waybar) keep text horizontal
   and just stack icons; the rotation is a stylistic choice that
   adds risk without strong UX justification.
4. **MusicStrings stays auto-hidden on vertical** for the early
   drops. Rotating PanelWindow surfaces is delicate; revisit only
   after the bar itself is solid.
5. **Audit every `PanelState.isVertical` consumer outside the bar**
   — the Modori .9.3 hotfix had to hide Left/Right cards because
   ZenSettings.qml's sidebar reacted to `isVertical` but the bar
   stayed horizontal after rollback. That kind of inconsistency
   needs to be impossible by design before the cards return.

### Beta channel preparation

The current alpha line aims to converge by **v6.17.x** with a
beta-stable cut. Concrete blockers tracked in `BETA-BLOCKERS.md`:
plugin system v2, Tategaki redux complete, Matugen polish, the
Wayland layer-shell positioning math reconciled with multi-monitor
edge cases, and a complete settings-persistence audit (the kind of
thing that surfaced the bar-layout.json clobber bug in Modori).


## What's new in Hiraki hotfix 1 (v6.16.4.12.6.53) — alpha

Two follow-up fixes on top of the .52 click-to-open drop. Both
reported against .52: the new Clock.qml wasn't clickable after
running `install.sh` (manual copy worked), and the calendar popup
appeared near the screen's right edge instead of above the clock.

### 1. install.sh no longer clobbers the new Clock.qml

The size-aware module auto-applier (introduced in v6.16.4.12.6.13
to keep `Clock.qml` and the legacy `ZenClock.qml` in lockstep
during early Hikari development) was actively breaking the .52
install. Mechanism:

1. Tarball unpacks the new 10KB `Clock.qml` and the legacy 43KB
   `ZenClock.qml` into `~/.config/quickshell/zen-shell/`.
2. Auto-applier compares sizes: `ratio = 43000 * 100 / 10000 ≈ 430`.
3. Heuristic: ratio ≥ 80 → "src is canonical" → copy `ZenClock.qml`
   over `Clock.qml`. The new click-to-open `Clock.qml` is replaced
   with the stale legacy version. The clock is now non-clickable
   because the legacy ZenClock.qml has different binding plumbing.
4. User does `cp Clock.qml ~/.config/quickshell/zen-shell/`
   manually after the install completes — works, because they're
   bypassing the auto-applier.

Fix: drop the `ZenClock.qml:Clock.qml` pair from the auto-applier
loop. Since Hikari (.51), `Clock.qml` is the canonical module —
forked from `CalendarButton.qml` — and `ZenClock.qml` is unused at
runtime (`Bar.qml` uses `Clock {}` directly). The pair entry is
preserved as a comment block in `install.sh` for reference. The
`Workspaces` and `SysMonitor` pairs still go through the heuristic
since those modules haven't diverged the same way.

### 2. Calendar popup now appears directly above the clock

Previously `calendarWindow` in `shell.qml` was anchored to the
right edge of the screen with `margins.right: 12`. Visually
correct in the common case (clock is rightmost), but wrong
whenever the user adds a system tray, weather widget, or any
module to the right of the clock — the popup floats away from
its trigger.

Fix:

- `PanelState.qml` adds two runtime properties — `clockCenterX`
  and `clockRightEdgeX` — plus a `reportClockPosition(centerX,
  rightX, sw)` function. Mirrors the existing
  `reportStartButtonPosition` plumbing.
- `Clock.qml` computes its global screen-X (center and right
  edge) on every click using `mapToItem(null, ...)` and the same
  panel-mode offset reconstruction the `StartMenu` already uses
  (layer-shell windows always report `win.x = 0`, so the bar's
  actual screen-X has to be reconstructed from `panelMode`).
  Reports the position **before** toggling the calendar, so
  `calendarWindow` positions itself correctly on the very first
  frame it becomes visible.
- `shell.qml`'s `calendarWindow.margins.right` is now a binding:
  `screenW - clockRightEdgeX`, clamped between `12` and
  `screenW - calendarWindow.implicitWidth - 12` so the 330px-wide
  popup never overflows the left edge of a narrow monitor.
  Falls back to the historical `12` when `clockRightEdgeX == -1`
  (the clock hasn't been clicked since the shell started, or
  PanelState was reset).

Result: regardless of where the clock sits in the bar, the
calendar popup's right edge aligns with the clock's right edge —
the popup grows leftward from the clock. Both top-bar and
bottom-bar layouts are handled by the existing
`anchors.top`/`anchors.bottom` switches.

Files changed: `install.sh` (auto-applier loop), `Clock.qml`
(position reporter), `PanelState.qml` (2 props + 1 function),
`shell.qml` (margins.right binding), `ZenVersion.qml`,
`README.md`.

Wala tayong babawasan — every Hiraki .52 behaviour is preserved
verbatim. .53 only adds the position reporter and removes the
broken auto-applier pair.

---

## What was new in Hiraki (v6.16.4.12.6.52) — alpha

The **Hiraki** drop (開き — "opening") follows directly from Hikari and
focuses on bar-trigger UX. Two changes:

### 1. Calendar opens on click, not hover

The bar's `Clock` module no longer pops the calendar / notification
center on hover. Hover keeps the visual highlight (theme blue tint
on background + border) so the module still feels reactive — but
the popup itself only appears when you actually **click** the clock.
This makes date selection feel deliberate again — the popup doesn't
flash up while you're panning the cursor past the clock to reach the
system tray.

The 150ms `hoverShowDelay` Timer in `Clock.qml` is gone. Scroll-wheel
month-cycling no longer auto-opens the calendar either; scroll over a
closed clock is a no-op so it doesn't accidentally summon the popup.
Left-click toggles, right-click cycles format, scroll cycles months
**only when the calendar is already open** — same as before.

### 2. Same approach on StartMenu (canonical pattern)

`StartMenu.qml` already opened only on click — Hiraki documents this
as the canonical Zen-bar trigger pattern (hover → visual highlight,
click → action) and adds the matching `z: 1` so the start button
always wins click hits over any sibling Loader/Item in the bar's
left zone. The Clock module gets the same `z: 1`. This satisfies
the "clock variable nasa top" request — the trigger modules sit on
top of the bar row's stacking order, so neither neighbouring
modules nor future widgets can shadow their hit areas.

Files changed: `Clock.qml`, `StartMenu.qml`, `ZenVersion.qml`,
`install.sh` (banner only), `README.md`.

Wala tayong babawasan — only hover-to-open behaviour was removed.
All Hikari plumbing (format cycle, wheel-month, theme sync, sizing
fix, layer-overlay calendar window) preserved verbatim.

---

## What was new in Hikari (v6.16.4.12.6.51)

The **Hikari** drop focuses on bar/clock UX cleanup and plugin-system
stabilisation. Three changes:

### 1. Clock is the calendar surface

The bar's `Clock` module is now the sole calendar trigger in the bar.
Hover the clock label → the calendar/notifications popup opens
(anchored to the clock, same pattern as `CalendarButton` and the
`SysRowIcon` tooltips). Click the clock → the popup pins open until you
click again or click outside. Right-click still cycles clock format,
scroll wheel still cycles calendar months when the popup is open.

The previous invisible click region in the empty bar gap between the
left zone (start, taskbar) and the centre zone (workspaces, window) —
and the equivalent gap on the right — has been removed. The
`leftSpacer` and `rightSpacer` items are now pure layout placeholders
(`Layout.fillWidth: true`); no hover tint, no MouseArea, no calendar
trigger. Bar row spacing is unchanged.

### 2. Plugin toggle no longer kills sibling plugins

Two issues that surfaced together in v6.16.4.12.6.49 are fixed:

- Toggling one plugin off would sometimes also stop a sibling plugin
  from loading after the next reload.
- Changing hyprbars button alignment (or any hyprbars option) would
  occasionally cause the toggle to flip back to OFF.

Root cause: the previous toggle/apply sequence was
`hyprpm enable X` → write `plugins.conf` → `hyprpm reload` → `hyprctl reload`.
The `hyprpm reload` step is redundant — `hyprpm enable/disable` already
loads/unloads the plugin (it prints `✔ Loaded <plugin>` or `✔ Unloaded
<plugin>`). Calling `hyprpm reload` afterwards triggers a full
unload-everything → re-load-from-state cycle. If anything fails or
partially executes during that cycle (sudo prompt missing a TTY, build
state mismatch, race), other currently-loaded plugins drop out and
don't come back.

Fix: trust `hyprpm enable/disable` for load state. Skip `hyprpm reload`.
`hyprctl reload` at the end is enough to re-source `plugins.conf` for
option changes — the plugin is already loaded; it just picks up new
option values.

The toggle command also now spawns a real terminal
(`alacritty` → `kitty` → `foot` → `wezterm`, headless fallback writes
to `/tmp/zen-plugin-toggle.log` + `notify-send`) so sudo prompts are
interactive when `hyprpm` requires them (e.g. system-installed plugin
.so files at `/usr/lib` symlinked into hyprpm's data dir).

### 3. Plugin manager temporarily hidden

The Settings → **Hyprland Plugins** sidebar entry is commented out and
the installer's `[8.7/9] hyprpm auto-install` step is wrapped in
`if false; then ... fi`. The page implementation (`PluginsPage.qml`)
and the installer block are kept on disk so re-enabling is a one-line
diff in each. Manual install is still possible:

```bash
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm update
hyprpm enable hyprbars     # or any plugin
hyprpm reload
```

---

## What was new in Tsubasa (v6.16.4.12.6.40)

The **Tsubasa · Plumage** release introduces a complete Hyprland plugin
manager built into the Settings UI. Five official plugins from the
`hyprwm/hyprland-plugins` repository can be installed, enabled,
configured, and themed from the new **Settings → Hyprland Plugins**
page — no terminal commands, no manual config editing, no hand-rolled
keybinds.

### Hyprland Plugins page

A new sidebar entry under **INPUT & DISPLAY** lists all five supported
plugins. Each row shows the plugin name, description, install status
(green badge), and an enable/disable toggle. When a plugin is enabled,
its `hyprpm` state is updated and `plugins.conf` is regenerated with the
correct configuration block — both in one click.

Supported plugins:

| Plugin | What it does |
|---|---|
| `hyprbars` | Title bars on floating windows with min/max/close buttons |
| `hyprexpo` | Mission Control style workspace overview (Super + Tab) |
| `hyprwinwrap` | Use any window as a live wallpaper |
| `borders-plus-plus` | Add one or two extra configurable borders to windows |
| `xtra-dispatchers` | Additional keybind dispatchers (e.g. `movetoworkspacesilent` variants) |

### Hyprbars sub-section (theme-synced)

Toggling `hyprbars` ON reveals a highlighted blue **HYPRBARS SETTINGS**
sub-section directly below the toggle row, containing:

- **Buttons position** dropdown — choose `right` or `left` alignment for the
  min/max/close buttons. Applied live (no retoggle).
- **Bar height** slider — 20 to 40 pixels, applied live with a 400 ms debounce.
- **Theme-synced colors** — the title bar background, text color, and button
  colors automatically follow the active Zen Shell theme. When you change
  themes (Settings → Themes, or matugen-from-wallpaper), `plugins.conf` is
  regenerated and `hyprctl reload` is fired so floating windows pick up the
  new colors immediately. No manual sync needed.

The three buttons are themed as a traffic-light cluster:

- **Close** — soft red (`rgb(ee5555)`), runs `hyprctl dispatch killactive`
- **Maximize** — teal (`rgb(33ccaa)`), toggles fullscreen mode 1
- **Minimize** — amber (`rgb(eeaa33)`), moves the window to the
  `special:minimized` workspace (restore by clicking its taskbar pill)

Tiled windows, Zen Shell popups (`zen-shell-*`), and the Zen quickprompt
terminal automatically skip the title bar via window rules — only true
floating windows get bars.

### Hyprexpo Super + Tab keybind

When `hyprexpo` is enabled, the keybind `SUPER + TAB` is added to
`plugins.conf` and bound to `hyprexpo:expo, toggle`. Three-finger swipe
gestures are also enabled by default. Disabling `hyprexpo` removes the
keybind cleanly — no orphaned bindings.

### Architecture

Plugin loading is delegated entirely to `hyprpm`. The previous approach
of writing `plugin = <name>` directives into `plugins.conf` is broken
since Hyprland 0.53 (the directive requires an absolute path, and that
path lives inside `~/.local/share/hyprpm/...` which is fragile). Instead:

- `plugins.conf` carries **configuration only** — `plugin:hyprbars:*`
  options, window rules, plugin-specific keybinds.
- Plugin loading is handled by `exec-once = hyprpm reload -n` in
  `autostart.conf`, which calls `hyprctl plugin load <absolute_path>`
  internally for every plugin marked enabled in the `hyprpm` state.
- Toggling a plugin in Settings runs `hyprpm enable <name>; hyprpm reload`
  and rewrites `plugins.conf` in one transaction.

If you ever hit the `[hyprpm] Couldn't update headers` or
`Failed to load plugin: Outdated headers` errors after a Hyprland
upgrade, the **Run recovery** button in the Plugins page footer opens a
terminal that runs `zen-hyprpm-fix.sh` — purges the hyprpm cache,
rebuilds the headers, and re-enables your plugins.

### Standalone hyprbars installer

For users on AUR-only setups where the `hyprland-plugins` repo doesn't
build cleanly through `hyprpm`, a fallback script `install-hyprbars.sh`
in `~/.local/bin/` installs `hyprland-plugin-hyprbars-git` from the AUR
and wires it into `hyprpm`'s state without rebuilding headers from
source.



Live captures from v6.16.4.12 running on Hyprland 0.54 with the Kintsugi Dark theme.

### Wallpaper engine

Full wallpaper picker with folder scanning, slideshow scheduling, transition effects, and the online Gekinzen/images-demo repo browser.

![Wallpaper picker](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_01_wallpaper_picker.gif)

### Animation presets (Material ZenComboBox)

21 community animation presets, live-applied via `hyprctl reload`. The new Material-style ZenComboBox auto-contrasts text using WCAG 2.0 luminance — readable on any theme.

![Animations dropdown](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_02_animations_dropdown.gif)

### Themes page with PaletteBox

Unified theme engine with 19 built-in themes (including the new **Kintsugi Light** and **Kintsugi Dark**). Click any 60×60 palette box to open the Quickshell PopupWindow color picker with live hex typing.

![Themes palette](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_03_themes_palette.gif)

### Panel drag-drop + bar modes

Drag modules between Left / Center / Right zones — state persists to `panel-state.json`. Fullwidth ↔ Island mode toggle with `panelStateLoaded` gate prevents the old revert-on-reboot bug.

![Panel drag-drop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_04_panel_drag_drop.gif)

### Control Panel + Dark Mode sync

Super+C opens the Quick Settings panel — volume sliders, WiFi / Bluetooth / Ethernet, Ryzen 9 5950X temps, RX 6800 GPU, Power Profile, Gaming Boost, and the **Dark Mode toggle** that syncs GTK3/4/libadwaita apps via gsettings + GTK3 settings.ini + GTK4 settings.ini.

![Control Panel dark mode](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_16_4_11_2_demo_2026/gif_05_control_panel.gif)

---

## Video demos

### 🟢 Latest — v6.16.4.12.5 "Hikari" Release Showcase

[![Zen Shell v6.16.4.11.2 Kintsugi — Release Showcase](https://img.youtube.com/vi/nS2L9dIQbF4/maxresdefault.jpg)](https://www.youtube.com/watch?v=nS2L9dIQbF4)

**Watch on YouTube:** https://www.youtube.com/watch?v=nS2L9dIQbF4

1:35 walkthrough of the Kintsugi release — hero desktop, wallpaper engine, Material ZenComboBox with WCAG auto-contrast, Themes page with PaletteBox, Panel drag-drop + island mode, Control Panel with Dark Mode toggle, WiFi picker.

### Historical tours

| Era | Video | Focus |
|---|---|---|
| v6.15.x · **Ensō** | [Full Tour](https://www.youtube.com/watch?v=dNwGRBhA97g) | Strings music module, screenshot ropes, settings, complete desktop experience |
| v6.14 · **Yugen** | [v6.14 Demo](https://www.youtube.com/watch?v=YQxrh5_naMQ) | Theme switching, panel modes, control center in the QML-rewrite era |
| v6.10 · **Yugen foundations** | [v6.10 Demo](https://www.youtube.com/watch?v=ao89J3DEqiA) | The fresh QML rewrite — where the new stack began |

---

## Previous showcases — v6.15.3 era

Preserved so the evolution stays visible. These assets are from the Ensō series (v6.15.x) before the Kintsugi v4 alpha cycle began.

### v6.15.3 — Desktop composition

![v6.15.3 Desktop](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample1.png)

### v6.15.3 — Workspace + Control Panel

![v6.15.3 Workspace](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample2.png)

### v6.15.3 — Settings pages

![v6.15.3 Settings](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/sample3.png)

### Adaptive theming across every surface

![Adaptive theming](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_01_adaptive_theming.gif)

### Settings tour · 14 pages

![Settings tour](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_02_settings_tour.gif)

### Screenshot Ropes · Super+Shift+S

![Screenshot Ropes](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_6_15_3_demo_2026/zen_shell_03_screenshot_module_ultrawide.gif)

---

## Legacy archive — 2025 Alpha (Koke · 苔)

Historical reference from the pre-Quickshell lineage. Hyprland 0.52 era. Python + GTK4 + Libadwaita stack. Custom dock, 13+ theme engine, Hypr Control Center. Preserved on branch [`zen-alpha-deprecated-0.52`](https://github.com/Gekinzen/zen_barebone_alpha_development/tree/zen-alpha-deprecated-0.52).

### Main demo

![Alpha main demo](https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/main.gif)

### Theming + Wallpaper + Panel

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/theming.gif" alt="Alpha theme switching" width="420"/><br/><sub>Theme switching</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/changewallpaper.gif" alt="Alpha wallpaper picker" width="420"/><br/><sub>Wallpaper picker</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/paneldemo.gif" alt="Alpha panel modes" width="420"/><br/><sub>Panel modes</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/desktoplooks.png" alt="Alpha desktop looks" width="420"/><br/><sub>Desktop looks</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/dock.png" alt="Alpha dock" width="420"/><br/><sub>Custom dock</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenter.png" alt="Alpha control center" width="420"/><br/><sub>Hypr Control Center (GTK4)</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprcontrolcenteranimation.png" alt="Alpha animation editor" width="420"/><br/><sub>Animation editor (Bezier)</sub></td>
<td><img src="https://raw.githubusercontent.com/Gekinzen/images-demo/main/zen_demo_old_archive_2025/hyprlandappearance.png" alt="Alpha appearance settings" width="420"/><br/><sub>Appearance settings</sub></td>
</tr>
</table>

---

## What v6.16.4.12.6 "Hikari · Frosted" ships

Polish + opt-in features on top of v6.16.4.12.5. Wala tayo babawasan.

| Area | Change |
|---|---|
| **Frosted bar modules** | Music / Tray / Notification / PowerBadge / Taskbar bg dropped from alpha 0.9 → 0.32. Now sit below Hyprland's `ignore_alpha 0.5` blur threshold for the `zen-shell-bar` layer (with bar's own 0.5 fill they composite to ~0.66 — frosted, not transparent). Modules read as part of the bar instead of solid embedded pills. |
| **Start menu polish** | Root alpha 0.92 → 0.72 + footer rebound to ThemeService. Live theme switches and Matugen repaint instantly. |
| **Pkill close** | Taskbar Close-all path: graceful `requestClose()` first, then 250 ms watchdog runs `pkill -f -- <appId>` then `pkill -9 -f -- <appId>`. Stuck Electron / Lark windows can no longer ignore the close. AppId sanitized before bash. Per-window X stays graceful-only. |
| **Clock CPU/RAM/GPU peek** | Hover popup adds a live stats row from `SystemMonitorService` — CPU%, RAM% + GB used, GPU% + temp. Same 350 ms hover-intent delay. GPU column hides on undetected systems. |
| **Matugen toggle** | New opt-in: when ON, every wallpaper switch regenerates the theme from its dominant colors via `matugen image <path> --json hex`. When OFF, your selected theme is preserved. Settings → Themes → Matugen. Includes a "Re-apply now" button for the current wallpaper. Auto-detects matugen at init; toggle disabled with install hint when binary missing. |

Full changelog: `CHANGELOG-v6.16.4.12.6.md`.

### Previous: v6.16.4.12.5 "Hikari"

<details>
<summary>Click to expand v6.16.4.12.5 changelog</summary>

## What v6.16.4.12.5 ships

This release opens the Hikari (光 — "Light") cycle. Illumination across every surface.

| Area | Change |
|---|---|
| **Panel position** | Bar can sit at top or bottom of screen. Visual selector in Settings → Panel → Position. All overlay windows (start menu, calendar, ZenStrings) flip correctly. |
| **Profile export/import** | Full-system snapshot: theme + panel + settings + bar layout + wallpaper → portable JSON. Save, load, rename, delete, share with friends. `~/.config/zen-shell/profiles/`. |
| **Per-monitor widgets** | Widget Display replaced with per-monitor toggles. Pick exactly which monitors show desktop widgets. Auto-detects connected displays. |
| **Display settings v2** | Preview rewritten with GPU-composited QML items (was Canvas). Smooth drag, zoom controls (+/−/Fit), per-monitor enable/disable toggle. |
| **Volume hard cap** | Sliders and keyboard keys now cap at 100%. Was 150%. No more accidental boost. |
| **Notification center** | Clock click opens unified panel: notifications top (count badge, DND toggle, swaync toggle), full calendar center, system quick-action icons bottom (BT, WiFi, Lock, Logout, Restart, Shutdown). Replaces standalone calendar popup. |
| **Calendar → swaync** | Notification row opens swaync when clicked. DND toggle via bell icon. Falls back gracefully if swaync not installed. |
| **Start menu sticky** | Menu gap reduced to 2px — feels attached to bar. Position-aware for top/bottom. |

Full changelog: `CHANGELOG-v6.16.4.12.5.md`.

</details>

### Previous: v6.16.4.11.2 "Kintsugi"

<details>
<summary>Click to expand v6.16.4.11.2 changelog</summary>

| Area | Change |
|---|---|
| **Panic keybind** | `SUPER+SHIFT+CTRL+Esc` works even through a frozen hyprlock — kills the shell, clears runtime state, respawns. No more force-power-off. |
| **Kintsugi themes** | Two new built-in themes matching the signature sage / gold / bone / ink palette. **Kintsugi Dark** is the default for fresh installs; existing users keep their selected theme. |
| **ZenComboBox rebuild** | Material-style dropdown — rotating chevron, accent dots, left accent bar on highlight. Text color picked via WCAG 2.0 luminance (threshold L=0.5). Readable on every theme, light or dark. |
| **Theme Palette relocated** | Moved from General page → Themes page. Single source of truth for palette edits. Old General HMSection preserved via `visible:false` — zero feature removal. |
| **PaletteBox component** | New 60×60 clickable palette swatches with hover pencil overlay. Click opens Quickshell `PopupWindow` picker with HS canvas + Lightness slider + live hex typing. Save / Rename / Delete custom themes via jq. |
| **Color picker (4 attempts)** | Qt `Popup` has Wayland coord quirks; switched to Quickshell `PopupWindow` primitive (xdg_popup, compositor-managed). Live hex input commits on every valid keystroke. |
| **Dark Mode toggle** | New `DarkModeService.qml` + `zen-darkmode.sh`. Syncs GTK3 (`settings.ini`), GTK4 (`settings.ini`), libadwaita (gsettings `color-scheme`). State at `~/.local/share/zen-shell/darkmode.state`. |
| **Super+T terminal** | `zen-terminal.sh` auto-detect chain: `$TERMINAL` → kitty → alacritty → ghostty → wezterm → foot → konsole → gnome-terminal. No more hardcoded kitty. |
| **WiFi rewrite** | Named-argument pattern replaces type-sniffing. Handles composite `nmcli` security strings like `WPA2 802.1X`. Audit log at `/tmp/zen-wifi-debug.log`. |
| **Start Menu breathing** | 64px → 72px pinned tiles. Better touch targets, cleaner grid rhythm. |
| **Widget Scale slider** | Live-updates desktop widgets (clock / weather / sysmon) without restart. Persists to widget state. |
| **Displays → gaps preserved** | Changing monitor config no longer wipes Hyprland gaps from `modules/appearance.conf`. |

</details>

---

## Codename history

Each release era gets a codename from Japanese zen vocabulary.

| Codename | Kanji | Meaning | Versions |
|---|---|---|---|
| Wakaba | 若葉 | Young leaf | Alpha v0.91 — Waybar + Python + rofi |
| Koke | 苔 | Moss | Alpha v2.x (v2.1.3) — GTK4 / Libadwaita era |
| Yugen | 幽玄 | Subtle profound grace | v6.10 – v6.14 — QML rewrite |
| Ensō | 円相 | The zen circle | v6.15.x · v6.16 base — unified stack |
| Ma | 間 | The space between | v6.16.1.x — cascade Control Panel |
| Shibui | 渋い | Understated refinement | v6.16.2.3.x — click-through masks |
| Sabi | 寂 | Beauty of age & patina | v6.16.3.x — lock screen, PowerBadge |
| Kintsugi | 金継ぎ | Golden-repair | v6.16.4.x · v6.16.4.11.2 |
| Hikari | 光 | Light — illumination across every surface | v6.16.4.12.5 – v6.16.4.12.6 · v6.16.4.12.6.51 |
| Tsubasa | 翼 | Wings · plumage — title bars take flight | v6.16.4.12.6.40 – v6.16.4.12.6.49 (interlude) |
| Hiraki | 開き | Opening — click-to-open bar triggers | v6.16.4.12.6.52 |
| **Hiraki** *(hotfix 1)* | **開き** | **Opening — popup-above-clock + installer fix** | **v6.16.4.12.6.53 — current alpha** |
| Michi *(planned)* | 道 | The way | v6.16.5 — in-app Updates Manager |

---

## Hikari version timeline

The **Hikari** (光 — "Light") cycle opened in v6.16.4.12.5 and ran
through v6.16.4.12.6 with a Tsubasa interlude in the late .6.x range,
then returned for the Clock-as-calendar UX cleanup at v6.16.4.12.6.51
before handing off to **Hiraki** (this drop). For convenience here is
the full chain — the changelog files for every entry below are
shipped in the project root and named `CHANGELOG-<version>.md`.

| Version | Codename | Theme of the drop |
|---|---|---|
| v6.16.4.12.5 | Hikari opens | Illumination cycle begins; lighting pass across every surface (bar, control panel, start menu, settings). |
| v6.16.4.12.6 | Hikari · Frosted | Frosted-glass material — translucent backgrounds across overlay surfaces. |
| v6.16.4.12.6.40 | Tsubasa (Wings/Plumage) | Hyprbars plugin manager built into Settings; title bars take flight. |
| v6.16.4.12.6.46 | Tsubasa (cont.) | Five official `hyprwm/hyprland-plugins` integrations (hyprbars, hyprexpo, hyprwinwrap, csgo-vulkan-fix, hyprtrails). |
| v6.16.4.12.6.49 | Tsubasa (late) | Last Tsubasa hotfix before the Hikari return; revealed the plugin-toggle sibling-kill bug. |
| v6.16.4.12.6.51 | Hikari (returns) | Bar/clock UX cleanup: Clock becomes the sole calendar surface; invisible spacer triggers removed; `hyprpm reload` redundancy fixed; plugin manager temporarily hidden behind `if false`. |
| v6.16.4.12.6.52 | Hiraki (opens) | Click-to-open: hover-to-open removed from Clock; canonical click-only pattern documented on StartMenu; `z: 1` on both trigger modules. |
| **v6.16.4.12.6.53** | **Hiraki (hotfix 1)** | **install.sh no longer clobbers Clock.qml with the legacy ZenClock.qml; calendar popup now anchors above the clock module instead of the screen edge.** |

Hiraki sits at the seam — same major (6.16.4.12.6) as the Hikari /
Tsubasa drops, branching off the Hikari .51 endpoint. The next
codename change (Michi 道 — "the way") is reserved for v6.16.5 when
the in-app Updates Manager lands.

---

## Install

### Quick

```bash
git clone https://github.com/Gekinzen/zen_barebone_alpha_development.git
cd zen_barebone_alpha_development
git checkout v6.16.4.11.2
./install.sh --bootstrap
```

`install.sh` auto-detects whether bootstrap is needed (missing
Hyprland / Quickshell / grim / slurp / wl-copy / swww / cava /
playerctl / jq / notify-send), runs bootstrap if any are missing,
then installs. At the end, kills any existing zen-shell process
and spawns exactly ONE new instance.

### Expected output

```
[7/9] Themes...
    19 builtin themes
    ★ NEW: Kintsugi Light + Kintsugi Dark (v6.16.4.11.2 codename palette)
    Default theme: kintsugi-dark (Kintsugi 金継ぎ)
...
╔═══════════════════════════════════════════════════════════════╗
║     🎉  ZEN SHELL v6.16.4.11.2 · KINTSUGI INSTALLED  🎉      ║
╚═══════════════════════════════════════════════════════════════╝

  ── Install summary ──
    QML files installed:   76
    Toggle scripts:        22 in /home/you/.local/bin
    Builtin themes:        19
    Active theme:          kintsugi-dark
```

### Verify after install

```bash
# Should print 1
pgrep -fa 'quickshell.*zen-shell' | wc -l

# Confirm Kintsugi themes present
ls ~/.config/hypr-control-center/themes/builtin/ | grep kintsugi
# → kintsugi-dark.json
# → kintsugi-light.json

# Confirm active theme
cat ~/.config/hypr-control-center/current-theme.json | grep '"id"'
# → "id": "kintsugi-dark"
```

---

## Keybinds (defaults)

```
Super+A                     Start menu
Super+,                     Settings
Super+C                     Control Panel (quick toggles)
Super+W                     Wallpaper picker
Super+T                     Terminal (auto-detect)
Super+/                     Keybind cheatsheet
Super+SHIFT+S               Screenshot rope (region capture + annotation)
Super+SHIFT+CTRL+Esc        Panic recovery (kills + respawns shell)
```

---

## Project structure

```
zen_barebone_alpha_development/
├── install.sh                  Smart installer (auto-detects bootstrap need)
├── bootstrap.sh                One-time system setup (deps via paru)
├── zen-shell-v5/               QML files for Quickshell
│   ├── shell.qml               Root shell (windows + IPC handlers)
│   ├── Bar.qml                 The status bar
│   ├── ControlPanel.qml        Quick-toggles popup (Super+C)
│   ├── ZenSettings.qml         Full settings UI (Super+,)
│   ├── StartMenuPanel.qml      App launcher (Super+A)
│   ├── WallpaperPicker.qml     Wallpaper grid + Online repo tab
│   ├── ColorPicker.qml         PopupWindow color picker (v4.10 rewrite)
│   ├── PaletteBox.qml          Clickable 60×60 palette swatch (v4.11.2)
│   ├── ZenComboBox.qml         Material dropdown with WCAG contrast
│   ├── DarkModeService.qml     GTK/libadwaita dark mode sync (v4.7)
│   ├── *Service.qml            Singleton state services
│   ├── UserProfileExportService.qml  Profile snapshot/restore (v6.16.4.12)
│   ├── ProfileManagerSection.qml     Profile management UI (v6.16.4.12)
│   ├── ZenNotificationCenter.qml     Calendar + notifs + system icons (v6.16.4.12)
│   └── *Page.qml               Settings page components
├── hypr-config/                Hyprland config modules + template
├── scripts/                    Helper scripts
│   ├── zs-restart.sh
│   ├── zen-terminal.sh         Super+T auto-detect chain (v4.7)
│   ├── zen-darkmode.sh         GTK/libadwaita dark mode sync (v4.7)
│   └── zen-panic.sh            Panic recovery (v6.16.4)
├── themes-builtin/             19 pre-installed theme JSON files
│   ├── kintsugi-dark.json      ← NEW in v6.16.4.11.2 (default)
│   ├── kintsugi-light.json     ← NEW in v6.16.4.11.2
│   ├── tokyo-night.json
│   ├── nord.json
│   └── ... (16 more)
├── bin/                        Toggle scripts copied to ~/.local/bin
├── CHANGELOG-v6.16.4.12.5.md    Detailed changelog for THIS release
└── CHANGELOG-v6.16.4.*.md      Historical alpha cycle notes
```

---

## Locations & state files

| Path | Purpose |
|---|---|
| `~/.config/quickshell/zen-shell/` | All QML files |
| `~/.config/hypr-control-center/themes/builtin/` | Built-in theme JSONs (19) |
| `~/.config/hypr-control-center/themes/custom/` | User-created themes (v4.11) |
| `~/.config/hypr-control-center/current-theme.json` | Active theme snapshot |
| `~/.config/zen-shell/user-avatar-*.png` | Versioned uploaded avatars |
| `~/.config/zen-shell/wallpapers/` | Local wallpaper folder |
| `~/.config/zen-shell/user-profile.json` | Avatar override JSON |
| `~/.config/hypr/zen-mouse.conf` | Mouse sensitivity (sourced by hyprland.conf) |
| `~/.config/quickshell/zen-shell/panel-state.json` | Panel mode, bar layout, module zones, **position** |
| `~/.config/zen-shell/profiles/` | Profile JSON storage (v6.16.4.12) |
| `~/.config/zen-shell/profiles/active-profile.state` | Currently loaded profile name |
| `~/.config/quickshell/zen-shell/wallpaper-state.json` | Current wallpaper path |
| `~/.cache/zen-shell/wallpapers/listing.json` | Cached GitHub API repo listing |
| `~/.local/share/zen-shell/darkmode.state` | Dark mode toggle state (v4.7) |
| `~/.local/bin/zs-restart.sh` | Restart helper |
| `~/.local/bin/zen-terminal.sh` | Super+T dispatcher (v4.7) |
| `~/.local/bin/zen-darkmode.sh` | Dark mode sync helper (v4.7) |
| `~/.local/bin/zen-panic.sh` | Panic recovery script (v6.16.4) |
| `/tmp/zen-avatar-debug.log` | Avatar upload diagnostic trace |
| `/tmp/zen-wifi-debug.log` | WiFi Connect audit log (v4.8) |
| `/tmp/zs-restart.log` | Restart helper trace |

---

## Diagnostic commands

```bash
# What zen-shell processes are running?
pgrep -fa 'quickshell.*zen-shell'

# What did the last avatar upload do?
tail -50 /tmp/zen-avatar-debug.log

# What did the last WiFi connect attempt do?
tail -50 /tmp/zen-wifi-debug.log

# What did the last nuclear restart do?
tail -50 /tmp/zs-restart.log

# Live shell logs (errors, warnings, console.log output)
journalctl --user -f -t quickshell

# Verify current mouse settings reached Hyprland
hyprctl getoption input:sensitivity
hyprctl getoption input:scroll_factor
hyprctl getoption input:natural_scroll

# Check dark mode sync state
cat ~/.local/share/zen-shell/darkmode.state
gsettings get org.gnome.desktop.interface color-scheme
```

---

## Re-install (replace running shell cleanly)

The installer's end-of-install launch sequence:

1. Lists all existing `quickshell.*zen-shell` processes
2. SIGTERM × 3 rounds (300ms apart) — graceful shutdown chance
3. SIGKILL × 2 rounds — forced termination
4. **Verifies** nothing survived. If anything did, REFUSES to spawn another.
5. `setsid -f quickshell -p ~/.config/quickshell/zen-shell`

Result: exactly ONE shell, every time. No more stacked duplicate bars.

---

## Known caveats

- **Quickshell version**: Tested on Quickshell 0.2.1+ with `PopupWindow`
  support (required for v4.10 color picker rewrite). If Settings/Control
  Panel still blocks click-through, update Quickshell.
- **Hyprland version**: 0.54+ required. New `windowrule` / `layerrule`
  anonymous syntax used throughout (not deprecated `windowrulev2` or old
  block format).
- **GitHub API rate limit**: Wallpaper repo browser uses unauthenticated
  GitHub API (60 req/hr per IP). Cached listing means normal use never
  hits this.
- **DMI sysfs**: Device / BIOS rows in User Profile read from
  `/sys/class/dmi/id/*`. On VMs / containers / WSL these files may be
  empty or contain placeholder strings — the rows hide automatically.
- **Existing users keep their theme**: The v4.11.2 installer sets
  Kintsugi Dark as the default **only for fresh installs** (when
  `current-theme.json` doesn't exist). If you're upgrading and want to
  switch, open Settings → Themes → Kintsugi Dark.

---

## License

Personal project by [Gekinzen / zenpy](https://github.com/Gekinzen).
No license attached at the moment; please open an issue or contact via
GitHub before redistributing.
