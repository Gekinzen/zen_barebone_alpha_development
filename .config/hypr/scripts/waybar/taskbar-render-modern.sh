#!/usr/bin/env bash

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
STYLE_FILE="$HOME/.config/waybar/style.css"
ICON_SCRIPT="$HOME/.config/hypr/scripts/waybar/get-app-icon.py"

mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

CACHE_DIR="$HOME/.cache/waybar"
mkdir -p "$CACHE_DIR"
APPS_FILE="$CACHE_DIR/taskbar-apps"

ACTIVE_CLASS="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')"

# Get pinned apps
PINNED_JSON=$(cat "$PIN_FILE")

# ═══════════════════════════════════════════════════════════════
# DETECT PANEL STYLE (minimal = nerd fonts, modern = system icons)
# ═══════════════════════════════════════════════════════════════
PANEL_STYLE="minimal"
if [ -f "$STYLE_FILE" ]; then
    if grep -q "rgba(49,50,68" "$STYLE_FILE"; then
        PANEL_STYLE="modern"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# GENERATE TASKBAR JSON
# ═══════════════════════════════════════════════════════════════

if [ "$PANEL_STYLE" = "modern" ]; then
    # MODERN: System icons with colored PNG (24px)
    
    # Get all running + pinned apps first
    HYPRCTL_DATA=$(hyprctl clients -j 2>/dev/null)
    
    echo "$HYPRCTL_DATA" | jq -rc --arg active "$ACTIVE_CLASS" --argjson pinned "$PINNED_JSON" '
      group_by(.class)
      | map({
          app_id: .[0].class,
          count: length,
          active: (.[0].class == $active),
          titles: map(.title),
          running: true
        })
      | . as $running
      
      | ($pinned.pinned // [])
      | map(select(. as $p | $running | map(.app_id) | index($p) | not))
      | map({
          app_id: .,
          count: 0,
          active: false,
          titles: [],
          running: false
        })
      | $running + .
    ' | jq -r '.[].app_id' | while IFS= read -r app_id; do
        # Get icon using Python script
        icon=$("$ICON_SCRIPT" "$app_id")
        
        # If it's a file path (starts with file://), use img tag with 24px height
        if [[ "$icon" == file://* ]]; then
            echo "{\"app\":\"$app_id\",\"icon\":\"<img src='$icon' height='24'/>\"}"
        else
            # It's a Nerd Font character (fallback)
            echo "{\"app\":\"$app_id\",\"icon\":\"$icon\"}"
        fi
    done | jq -s --arg active "$ACTIVE_CLASS" --argjson pinned "$PINNED_JSON" --argjson hyprctl_data "$HYPRCTL_DATA" '
      . as $icons |
      
      # Get running apps from the passed data
      ($hyprctl_data | group_by(.class) | map({
          app_id: .[0].class,
          count: length,
          active: (.[0].class == $active),
          titles: map(.title),
          running: true
        })
      ) as $running |
      
      # Get pinned apps that are not running
      (($pinned.pinned // [])
      | map(select(. as $p | $running | map(.app_id) | index($p) | not))
      | map({
          app_id: .,
          count: 0,
          active: false,
          titles: [],
          running: false
        })) as $pinned_apps |
      
      # Combine running + pinned
      ($running + $pinned_apps) as $all_apps |
      
      # Map icons to apps
      $all_apps | map(
        . as $item |
        ($icons | map(select(.app == $item.app_id)) | .[0].icon // "󰣆") as $icon |
        {
          icon: $icon,
          count: $item.count,
          app_id: $item.app_id,
          titles: $item.titles,
          running: $item.running,
          active: $item.active
        }
      )
      | {
          text: (map(.icon + (if .count > 1 then " (" + (.count | tostring) + ")" else "" end)) | join("  ")),
          tooltip: (map(
            .app_id + 
            (if .running then " (" + (.count | tostring) + " window" + (if .count > 1 then "s" else "" end) + ")"
             else " (pinned - click to launch)" 
             end) +
            (if (.titles | length) > 0 then "\n• " + (.titles | join("\n• ")) else "" end)
          ) | join("\n\n")),
          class: "taskbar"
        }
    '
    
else
    # MINIMAL: Nerd Font icons ONLY (no system icons)
    hyprctl clients -j 2>/dev/null | jq -rc --arg active "$ACTIVE_CLASS" --argjson pinned "$PINNED_JSON" '
      group_by(.class)
      | map({
          app_id: .[0].class,
          count: length,
          active: (.[0].class == $active),
          titles: map(.title),
          running: true
        })
      | . as $running
      
      | ($pinned.pinned // [])
      | map(select(. as $p | $running | map(.app_id) | index($p) | not))
      | map({
          app_id: .,
          count: 0,
          active: false,
          titles: [],
          running: false
        })
      | $running + .
      
      | map(
          . as $item |
          ($item.app_id | ascii_downcase) as $lower |
          (
            # Browsers
            if ($lower | test("firefox|mozilla")) then "󰈹"
            elif ($lower | test("chromium")) then "󰊯"
            elif ($lower | test("chrome|google-chrome")) then "󰊯"
            elif ($lower | test("brave")) then "󰖟"
            elif ($lower | test("vivaldi")) then "󰖟"
            elif ($lower | test("opera")) then "󰖟"
            elif ($lower | test("edge|msedge")) then "󰇩"

            # Code Editors & IDEs
            elif ($lower | test("code|vscode|vscodium")) then "󰨞"
            elif ($lower | test("neovim|nvim")) then ""
            elif ($lower | test("vim")) then ""
            elif ($lower | test("emacs")) then ""
            elif ($lower | test("sublime")) then ""
            elif ($lower | test("jetbrains|idea|pycharm|webstorm|phpstorm")) then ""

            # Terminals
            elif ($lower | test("kitty")) then "󰆍"
            elif ($lower | test("alacritty")) then "󰆍"
            elif ($lower | test("wezterm")) then "󰆍"
            elif ($lower | test("foot")) then "󰆍"
            elif ($lower | test("konsole")) then "󰆍"
            elif ($lower | test("terminal")) then "󰆍"

            # File Managers
            elif ($lower | test("thunar")) then "󰝰"
            elif ($lower | test("nautilus")) then "󰝰"
            elif ($lower | test("dolphin")) then "󰝰"
            elif ($lower | test("pcmanfm")) then "󰝰"
            elif ($lower | test("nemo")) then "󰝰"
            elif ($lower | test("ranger|yazi")) then "󰝰"

            # Media
            elif ($lower | test("spotify")) then "󰓇"
            elif ($lower | test("vlc")) then "󰕼"
            elif ($lower | test("mpv")) then "󰐹"
            elif ($lower | test("celluloid")) then "󰐹"
            elif ($lower | test("rhythmbox|clementine|strawberry")) then "󰓃"

            # Communication
            elif ($lower | test("discord")) then "󰙯"
            elif ($lower | test("telegram")) then "󰚩"
            elif ($lower | test("slack")) then "󰒱"
            elif ($lower | test("teams")) then "󰊻"
            elif ($lower | test("zoom")) then "󰍫"
            elif ($lower | test("signal")) then "󰍡"
            elif ($lower | test("whatsapp")) then "󰖣"
            elif ($lower | test("thunderbird")) then "󰇰"

            # Creative
            elif ($lower | test("gimp")) then "󰏘"
            elif ($lower | test("inkscape")) then "󰕙"
            elif ($lower | test("blender")) then "󰂫"
            elif ($lower | test("krita")) then "󰏘"
            elif ($lower | test("obs")) then "󰑋"
            elif ($lower | test("kdenlive|shotcut")) then "󰕧"
            elif ($lower | test("figma")) then "󰕧"

            # Gaming
            elif ($lower | test("steam")) then "󰓓"
            elif ($lower | test("lutris")) then "󰺷"
            elif ($lower | test("heroic")) then "󰺷"
            elif ($lower | test("minecraft")) then "󰍳"

            # Office / Notes
            elif ($lower | test("libreoffice")) then "󰈙"
            elif ($lower | test("notion")) then "󰈙"
            elif ($lower | test("obsidian")) then "󱓷"
            elif ($lower | test("logseq|joplin")) then "󰈙"

            # System / Tools
            elif ($lower | test("htop|btop")) then "󰄪"
            elif ($lower | test("nvtop")) then "󰾲"
            elif ($lower | test("gparted")) then "󰋊"

            # Documents
            elif ($lower | test("zathura|evince|okular")) then "󰈦"
            elif ($lower | test("calibre")) then "󰂺"

            # Torrent
            elif ($lower | test("qbittorrent|transmission|deluge")) then "󰥩"

            # Virtualization
            elif ($lower | test("virt-manager|qemu")) then "󰆧"
            elif ($lower | test("virtualbox")) then "󰆧"

            # Game Dev
            elif ($lower | test("unreal|unrealengine")) then "󰆧"
            elif ($lower | test("unity")) then "󰆧"
            elif ($lower | test("godot")) then "󰆧"

            # Fallback
            else "󰣆"
            end
          ) as $icon |
          {
            icon: $icon,
            count: $item.count,
            app_id: $item.app_id,
            titles: $item.titles,
            running: $item.running
          }
        )
      | {
          text: (map(.icon + (if .count > 1 then "(" + (.count | tostring) + ")" else "" end)) | join(" ")),
          tooltip: (map(
            .app_id + 
            (if .running then " (" + (.count | tostring) + " window" + (if .count > 1 then "s" else "" end) + ")"
             else " (pinned - click to launch)" 
             end) +
            (if (.titles | length) > 0 then "\n• " + (.titles | join("\n• ")) else "" end)
          ) | join("\n\n")),
          class: "taskbar"
        }
    '
fi

# Save all apps to cache
hyprctl clients -j 2>/dev/null | jq -r --argjson pinned "$PINNED_JSON" '
  (group_by(.class) | map(.[0].class)) + ($pinned.pinned // []) | unique | .[]
' > "$APPS_FILE"