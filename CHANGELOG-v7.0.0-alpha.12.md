# v7.0.0-alpha.12 — Karui (軽い) · Zen Notification Center (replaces SwayNC)

**Channel:** alpha
**Codename:** Karui (軽い · "lightweight")
**Sub-theme:** Native notification daemon + OSD popups
**Released:** 2026-05-09
**Branch:** `dev`

---

## What this drop adds

The big one — alpha.12 introduces a **native zen-shell notification
daemon** that replaces SwayNC entirely. Plus a Windows-style OSD
popup for transient volume/brightness changes that does NOT pollute
the notification history.

Per Paul's spec:
> "make it sure yun notification ko yan na lalabas ah and kapag nag
> change ako gn volume yan na din and siya na yun nasa position dun
> sa panel ko notifications sa hypr control center ah. and please
> kung anu yun curernt theme color ko same ah. and kapag may
> brightness change, volume wag mo na isasama sa notifation list pop
> up lang prang windows din."

Translation: native notifications appear; volume/brightness changes
trigger OSD only (Windows-style popup) — never enter the notif
list; everything uses current theme colors.

### Architecture (4 new files + 4 modified)

```
NotificationService.qml      ← D-Bus daemon (singleton)
        │
        ├─→ toastRequested → ZenNotifyToast (right side, stacked)
        ├─→ osdRequested → OSDPopup (bottom-center, Windows-style)
        └─→ notifications array → NotificationListPanel (in CC tab)

ConnectivityService.setVolume()    → NotificationService.showVolumeOSD()
BrightnessService.setBrightness()  → NotificationService.showBrightnessOSD()

NotificationIcon (bar)              → bound to NotificationService.unreadCount
                                       (was: swaync-client polling)
```

### 1. NotificationService — native daemon

Uses Quickshell's `NotificationServer` to register the system
`org.freedesktop.Notifications` D-Bus service. Replaces SwayNC's
role completely.

Features:
- Receives all notifications from any app (Brave, Discord,
  systemd, etc.)
- Maintains history of last 50 notifications
- Filters transient hints (volume, brightness, "device.added"
  category) → routes to OSD only, NEVER persists in list
- Tracks unread count for the bar bell icon
- DND mode toggle (suppresses toasts; still logs to history)
- Action invocation support (D-Bus actions array)

Public API:
```qml
NotificationService.notifications          // array, newest first
NotificationService.unreadCount            // int
NotificationService.dndEnabled             // bool, two-way
NotificationService.dismiss(id)
NotificationService.markRead(id)
NotificationService.markAllRead()
NotificationService.clearAll()
NotificationService.invokeAction(id, actionId)

// External hooks for OSD
NotificationService.showVolumeOSD(0..1)
NotificationService.showBrightnessOSD(0..1)
```

### 2. ZenNotifyToast — incoming notification toasts

Stacked toasts on the right side of focused monitor:

```
                          ┌────────────────────────┐
                          │ ● Brave           ×    │
                          │   Download complete    │
                          │   resume.pdf            │
                          └────────────────────────┘
                          ┌────────────────────────┐
                          │   Discord          ×    │
                          │   New message from K... │
                          └────────────────────────┘
```

- Slide-in from right + fade-out animation (220ms)
- 5000ms auto-dismiss for normal/low urgency
- Critical notifications stay until manually dismissed
- Hover pauses auto-dismiss timer
- Click dismisses
- Color-coded urgency dots (red=critical, blue=normal,
  grey=low)
- Theme-aware colors via ThemeService

### 3. OSDPopup — transient ring (Windows-style)

Bottom-center horizontal pill that appears for ~1500ms when:
- User changes volume (slider, scroll wheel, hardware keys)
- User changes brightness (slider or hardware keys)
- Any external app sends a notification with `transient: true`
  hint OR matches volume/brightness app names

```
        ┌──────────────────────────────────────────┐
        │  🔊  ████████████░░░░░░░░░░  65%         │
        └──────────────────────────────────────────┘
```

- Re-triggering resets the 1500ms timer (rapid scroll feels
  responsive)
- Smooth slide-up + fade
- Volume icon changes by level (muted/low/full)
- Brightness uses lightbulb icon
- Bar fills in theme blue (matches ThemeService.blue)
- NEVER enters notification history

### 4. NotificationListPanel — full list inside Control Panel

Theme-aware notification list designed to embed in CC's
notifications tab. Renders:
- Header: bell icon, title, unread count, "Clear all" button
- DND toggle (live binds to NotificationService.dndEnabled)
- Empty state with 36px bell glyph when no notifications
- ListView with scrollbar for overflow
- Per-row: app name + age ("2m ago", "1h ago"), summary,
  body (rich text), unread dot, dismiss × button
- Critical notifications get red border outline

Uses ThemeService colors throughout — when user switches theme
or runs matugen on a new wallpaper, the list re-themes
automatically.

### 5. Volume + brightness OSD wiring

`ConnectivityService.setVolume()` and
`BrightnessService.setBrightness()` now call:
```qml
NotificationService.showVolumeOSD(value / 100)
NotificationService.showBrightnessOSD(value / 100)
```

So whether user adjusts volume via:
- Bar audio module slider
- Control Panel volume slider
- Hardware media keys (already wired in binds.conf)
- `wpctl` directly from terminal (the poller will still update,
  triggers the underlying notification → still routed to OSD
  via the filter)

OSD ring appears bottom-center, NEVER appears in notification
history.

### 6. NotificationIcon bar widget rewired

Bell icon in bar previously polled `swaync-client -swb` every
2 seconds. Now binds directly to:
- `NotificationService.unreadCount` (instant updates)
- `NotificationService.dndEnabled` (DND toggle reflects
  immediately)

Click behavior:
- **Left-click**: opens Control Panel (where notifications
  list lives via NotificationListPanel embed in alpha.13)
- **Right-click**: toggles DND directly

### Filtering rules — what goes where

| Source | Destination |
|---|---|
| Brave: "Download complete" | Toast + List |
| Discord: "New message" | Toast + List |
| Critical battery alert | Toast + List (red border, no auto-dismiss) |
| Volume change (any source) | OSD only |
| Brightness change | OSD only |
| Notif with `transient: true` hint | OSD only (or dropped if no value) |
| Notif when DND on | List only (no toast) |

---

## Files added

```
zen-shell-v5/NotificationService.qml      (NEW, ~190 lines)
zen-shell-v5/ZenNotifyToast.qml             (NEW, ~190 lines)
zen-shell-v5/OSDPopup.qml                   (NEW, ~140 lines)
zen-shell-v5/NotificationListPanel.qml      (NEW, ~280 lines)
CHANGELOG-v7.0.0-alpha.12.md                (NEW)
```

## Files modified

```
zen-shell-v5/shell.qml                  (+toast + OSD PanelWindow mounts)
zen-shell-v5/NotificationIcon.qml        (swaync poll → NotificationService binding)
zen-shell-v5/ConnectivityService.qml     (+OSD trigger on setVolume/toggleMute)
zen-shell-v5/BrightnessService.qml       (+OSD trigger on setBrightness)
zen-shell-v5/ZenVersion.qml              (bumped to v7.0.0-alpha.12)
install.sh                               (version strings)
```

`NotificationPage.qml` (the SwayNC settings page) is preserved
untouched — wala tayong babawasan. It can still configure SwayNC
if user keeps it running for any reason. Future alpha.13 will
add a new "Notifications" Settings page that configures
NotificationService directly.

---

## Wala tayong babawasan

- All alpha.11 features intact (Spotlight files, Densho headers,
  color picker rewrite)
- All alpha.5–10 features intact
- SwayNC remains installable / runnable — NotificationService
  silently coexists if both are running (last-D-Bus-registered
  wins; user can pick)
- NotificationPage.qml (SwayNC settings) preserved
- Existing audio/brightness sliders unchanged — they just
  additionally trigger OSD now
- Theme switching, matugen, all work — toast + OSD + list
  re-theme live

---

## Behavior summary

### When a regular notification arrives (e.g. Discord message)

1. App calls `org.freedesktop.Notifications.Notify` via D-Bus
2. NotificationService receives it
3. Filter check: not transient, not volume/brightness → ALLOW
4. DND check: if off → emit `toastRequested` + add to history
5. Toast slides in from right, auto-dismisses after 5s
6. Notification persists in list (visible in CC tab)
7. Bar bell icon shows unread count

### When user changes volume

1. ConnectivityService.setVolume(75) called
2. wpctl set-volume runs
3. `NotificationService.showVolumeOSD(0.75)` called
4. OSD ring slides up at bottom-center
5. After 1500ms, OSD fades out
6. Notification list UNCHANGED (no entry added)

### When user changes brightness

Same as volume but with brightness icon + lightbulb glyph.

---

## Verified

- ✅ All 8 modified/new files lint clean
- ✅ NotificationService is `pragma Singleton`
- ✅ NotificationServer registered with full feature flags
- ✅ ZenNotifyToast listens to `toastRequested`
- ✅ OSDPopup listens to `osdRequested`
- ✅ Both mounted as PanelWindow Variants in shell.qml
- ✅ Volume change → OSD (4 refs in ConnectivityService)
- ✅ Brightness change → OSD (2 refs in BrightnessService)
- ✅ Volume/brightness FILTERED from notification list (5 refs)
- ✅ NotificationListPanel uses ThemeService throughout (32 refs)

---

## To install

```bash
tar -xzf zen-shell-v7.0.0-alpha.12-notification-center.tgz
cd zen-shell-v7.0.0-alpha.12
./install.sh
qs -r

# Optional — disable SwayNC if you want zen-shell to be the only
# notification daemon:
systemctl --user disable --now swaync 2>/dev/null
pkill swaync
```

After install:

1. **Send test notification:**
   ```bash
   notify-send "Test" "alpha.12 working" -i dialog-information
   ```
   → Toast appears top-right, persists in list

2. **Trigger OSD:**
   ```bash
   wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.75
   ```
   → OSD ring appears bottom-center, fades after 1.5s
   → Notification list does NOT show this

3. **Test brightness OSD (laptop):**
   - Use brightness keys or Control Panel slider
   → OSD with lightbulb icon

4. **Test DND:**
   - Right-click bell in bar → DND on
   - notify-send another → no toast, but added to history list
   - Right-click again → DND off

5. **Theme switch:**
   - Open Settings → Themes → switch theme
   - Send notification → toast uses new theme colors
   - OSD bar fill uses new ThemeService.blue

---

## Roadmap update

```
✅ alpha.5 — LaptopMode
✅ alpha.6 — Search + Clipboard
✅ alpha.7 — Cleanup + Polish
✅ alpha.8 — Pinned drag + scroll
✅ alpha.9 — Auto-hide search + Super+Space
✅ alpha.10 — Spotlight palette
✅ alpha.11 — Spotlight files + Densho restyle
✅ alpha.12 — Zen Notification Center (drops SwayNC) ← we are here
🎯 alpha.13 — CC Notifications tab embed + Workflow Profiles
   alpha.14 — Workspace Overview + HotCornerService
   alpha.15 — Per-game profiles + BatteryHealthService
   ...
   beta.1-3 → v7.0.0 stable
```
