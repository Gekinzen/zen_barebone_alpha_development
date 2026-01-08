#!/usr/bin/env bash

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
STYLE_FILE="$HOME/.config/waybar/style.css"
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
# GET SYSTEM ICON FUNCTION (for modern style)
# ═══════════════════════════════════════════════════════════════
get_system_icon() {
    local app_id="$1"
    local app_lower="$(echo "$app_id" | tr '[:upper:]' '[:lower:]')"
    
    # Get icon theme from GTK settings
    local icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    [ -z "$icon_theme" ] && icon_theme="Papirus"
    
    # Search paths for icons
    local search_paths=(
        "$HOME/.local/share/icons/$icon_theme"
        "$HOME/.icons/$icon_theme"
        "/usr/share/icons/$icon_theme"
        "$HOME/.local/share/icons/hicolor"
        "/usr/share/icons/hicolor"
    )
    
    # Icon sizes to try
    local sizes=(48 32 24 scalable)
    
    # Try multiple name variations
    local name_variations=(
        "$app_id"
        "$app_lower"
        "${app_lower}-browser"
        "${app_lower}-app"
    )
    
    # Special app name mappings
    case "$app_lower" in
        org.mozilla.firefox|firefox) name_variations+=("firefox") ;;
        google-chrome|chrome) name_variations+=("google-chrome" "chrome") ;;
        chromium|chromium-browser) name_variations+=("chromium" "chromium-browser") ;;
        code|vscode) name_variations+=("code" "vscode" "visual-studio-code") ;;
        org.gnome.nautilus|nautilus) name_variations+=("nautilus" "org.gnome.Nautilus") ;;
        thunar) name_variations+=("thunar" "Thunar") ;;
        kitty) name_variations+=("kitty" "terminal") ;;
        alacritty) name_variations+=("alacritty" "Alacritty") ;;
        discord) name_variations+=("discord" "Discord") ;;
        telegram|telegram-desktop) name_variations+=("telegram" "telegram-desktop") ;;
        spotify) name_variations+=("spotify" "spotify-client") ;;
        vlc) name_variations+=("vlc") ;;
        gimp*) name_variations+=("gimp" "org.gimp.GIMP") ;;
        obs) name_variations+=("obs" "com.obsproject.Studio") ;;
        steam) name_variations+=("steam") ;;
    esac
    
    # Search for icon
    for name in "${name_variations[@]}"; do
        for path in "${search_paths[@]}"; do
            if [ ! -d "$path" ]; then continue; fi
            
            for size in "${sizes[@]}"; do
                # Try different size directories
                for size_dir in "${size}x${size}" "$size"; do
                    # Try different app directories
                    for app_dir in "apps" "categories" "places"; do
                        icon_dir="$path/$size_dir/$app_dir"
                        if [ ! -d "$icon_dir" ]; then continue; fi
                        
                        # Try .png and .svg
                        for ext in png; do
                            icon_file="$icon_dir/${name}.$ext"
                            if [ -f "$icon_file" ]; then
                                echo "$icon_file"
                                return 0
                            fi
                        done
                    done
                done
            done
        done
    done
    
    # Fallback: Try .desktop file
    # Fallback: Try .desktop file (PNG ONLY)
    local desktop_file=$(find ~/.local/share/applications /usr/share/applications -iname "*${app_lower}*.desktop" 2>/dev/null | head -1)
    if [ -n "$desktop_file" ]; then
        local icon_name=$(grep "^Icon=" "$desktop_file" | head -1 | cut -d'=' -f2)
        if [ -n "$icon_name" ]; then
            for path in "${search_paths[@]}"; do
                [ ! -d "$path" ] && continue
                local found=$(find "$path" -name "${icon_name}.png" 2>/dev/null | head -1)
                if [ -n "$found" ]; then
                    echo "$found"
                    return 0
                fi
            done
        fi
    fi
    
    return 1
}

# ═══════════════════════════════════════════════════════════════
# GENERATE TASKBAR JSON
# ═══════════════════════════════════════════════════════════════

if [ "$PANEL_STYLE" = "modern" ]; then
    # MODERN: System icons with HTML img tags
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
      | map(.app_id)
    ' | while IFS= read -r app_id; do
        # Try to get system icon
        icon_path=$(get_system_icon "$app_id")
        
        if [ -n "$icon_path" ]; then
            # Use HTML img tag for system icon
            echo "{\"app\":\"$app_id\",\"icon\":\"<img src='file://$icon_path' height='18'/>\"}"
        else
            # Fallback to nerd font
            icon=""
            case "$(echo "$app_id" | tr '[:upper:]' '[:lower:]')" in
                *firefox*|*mozilla*) icon="󰈹" ;;
                *chrom*) icon="󰊯" ;;
                *brave*) icon="󰖟" ;;
                *code*|*vscode*) icon="󰨞" ;;
                *kitty*|*alacritty*|*terminal*) icon="󰆍" ;;
                *thunar*|*nautilus*|*dolphin*) icon="󰝰" ;;
                *spotify*) icon="󰓇" ;;
                *discord*) icon="󰙯" ;;
                *telegram*) icon="󰚩" ;;
                *) icon="󰣆" ;;
            esac
            echo "{\"app\":\"$app_id\",\"icon\":\"$icon\"}"
        fi
    done | jq -s --arg active "$ACTIVE_CLASS" --argjson pinned "$PINNED_JSON" '
      . as $icons |
      (
        (env.hyprctl_clients // "" | fromjson? // [])
        | group_by(.class)
        | map({
            app_id: .[0].class,
            count: length,
            active: (.[0].class == $active),
            titles: map(.title),
            running: true
          })
      ) as $running |
      
      ($pinned.pinned // [])
      | map(select(. as $p | $running | map(.app_id) | index($p) | not))
      | map({
          app_id: .,
          count: 0,
          active: false,
          titles: [],
          running: false
        })
      | ($running + .) as $all_apps |
      
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
    ' hyprctl_clients="$(hyprctl clients -j 2>/dev/null)"
    
else
    # MINIMAL: Nerd Font icons (your original script)
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
            if ($lower | test("firefox|mozilla")) then "󰈹"
            elif ($lower | test("chromium")) then "󰊯"
            elif ($lower | test("chrome|google-chrome")) then "󰊯"
            elif ($lower | test("brave")) then "󰖟"
            elif ($lower | test("vivaldi")) then "󰖟"
            elif ($lower | test("opera")) then "󰖟"
            elif ($lower | test("edge|msedge")) then "󰇩"
            elif ($lower | test("code|vscode|vscodium")) then "󰨞"
            elif ($lower | test("neovim|nvim")) then ""
            elif ($lower | test("vim")) then ""
            elif ($lower | test("emacs")) then ""
            elif ($lower | test("sublime")) then ""
            elif ($lower | test("jetbrains|idea|pycharm|webstorm|phpstorm")) then ""
            elif ($lower | test("kitty")) then "󰆍"
            elif ($lower | test("alacritty")) then "󰆍"
            elif ($lower | test("wezterm")) then "󰆍"
            elif ($lower | test("foot")) then "󰆍"
            elif ($lower | test("konsole")) then "󰆍"
            elif ($lower | test("terminal")) then "󰆍"
            elif ($lower | test("thunar")) then "󰝰"
            elif ($lower | test("nautilus")) then "󰝰"
            elif ($lower | test("dolphin")) then "󰝰"
            elif ($lower | test("pcmanfm")) then "󰝰"
            elif ($lower | test("nemo")) then "󰝰"
            elif ($lower | test("ranger|yazi")) then "󰝰"
            elif ($lower | test("spotify")) then "󰓇"
            elif ($lower | test("vlc")) then "󰕼"
            elif ($lower | test("mpv")) then "󰐹"
            elif ($lower | test("celluloid")) then "󰐹"
            elif ($lower | test("rhythmbox|clementine|strawberry")) then "󰓃"
            elif ($lower | test("discord")) then "󰙯"
            elif ($lower | test("telegram")) then "󰚩"
            elif ($lower | test("slack")) then "󰒱"
            elif ($lower | test("teams")) then "󰊻"
            elif ($lower | test("zoom")) then "󰍫"
            elif ($lower | test("signal")) then "󰍡"
            elif ($lower | test("whatsapp")) then "󰖣"
            elif ($lower | test("thunderbird")) then "󰇰"
            elif ($lower | test("gimp")) then "󰏘"
            elif ($lower | test("inkscape")) then "󰕙"
            elif ($lower | test("blender")) then "󰂫"
            elif ($lower | test("krita")) then "󰏘"
            elif ($lower | test("obs")) then "󰑋"
            elif ($lower | test("kdenlive|shotcut")) then "󰕧"
            elif ($lower | test("figma")) then "󰕧"
            elif ($lower | test("steam")) then "󰓓"
            elif ($lower | test("lutris")) then "󰺷"
            elif ($lower | test("heroic")) then "󰺷"
            elif ($lower | test("minecraft")) then "󰍳"
            elif ($lower | test("libreoffice")) then "󰈙"
            elif ($lower | test("notion")) then "󰈙"
            elif ($lower | test("obsidian")) then "󱓷"
            elif ($lower | test("logseq|joplin")) then "󰈙"
            elif ($lower | test("htop|btop")) then "󰄪"
            elif ($lower | test("nvtop")) then "󰾲"
            elif ($lower | test("gparted")) then "󰋊"
            elif ($lower | test("zathura|evince|okular")) then "󰈦"
            elif ($lower | test("calibre")) then "󰂺"
            elif ($lower | test("qbittorrent|transmission|deluge")) then "󰥩"
            elif ($lower | test("virt-manager|qemu")) then "󰆧"
            elif ($lower | test("virtualbox")) then "󰆧"
            elif ($lower | test("unreal|unrealengine")) then "󰆧"
            elif ($lower | test("unity")) then "󰆧"
            elif ($lower | test("godot")) then "󰆧"
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