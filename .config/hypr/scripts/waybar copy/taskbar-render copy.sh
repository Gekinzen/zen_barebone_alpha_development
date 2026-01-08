#!/usr/bin/env bash

PIN_FILE="$HOME/.config/hypr-control-center/preferences/taskbar.json"
mkdir -p "$(dirname "$PIN_FILE")"
[ ! -f "$PIN_FILE" ] && echo '{ "pinned": [] }' > "$PIN_FILE"

CACHE_DIR="$HOME/.cache/waybar"
mkdir -p "$CACHE_DIR"
APPS_FILE="$CACHE_DIR/taskbar-apps"

ACTIVE_CLASS="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')"

# Save app list
hyprctl clients -j 2>/dev/null | jq -r 'group_by(.class) | map(.[0].class) | .[]' > "$APPS_FILE"

# Generate taskbar with comprehensive icon mapping
hyprctl clients -j 2>/dev/null | jq -rc --arg active "$ACTIVE_CLASS" '
  group_by(.class)
  | map({
      app_id: .[0].class,
      count: length,
      active: (.[0].class == $active),
      titles: map(.title)
    })
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
  elif ($lower | test("neovim|nvim")) then ""
  elif ($lower | test("vim")) then ""
  elif ($lower | test("emacs")) then ""
  elif ($lower | test("sublime")) then ""
  elif ($lower | test("jetbrains|idea|pycharm|webstorm|phpstorm")) then ""

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

  # Fallback (IMPORTANT)
  else "󰣆"
  end
      ) as $icon |
      {
        icon: $icon,
        count: $item.count,
        app_id: $item.app_id,
        titles: $item.titles
      }
    )
  | {
      text: (map(.icon + (if .count > 1 then "(" + (.count | tostring) + ")" else "" end)) | join(" ")),
      tooltip: (map(.app_id + " (" + (.count | tostring) + " window" + (if .count > 1 then "s" else "" end) + ")" + (if (.titles | length) > 0 then "\n• " + (.titles | join("\n• ")) else "" end)) | join("\n\n")),
      class: "taskbar"
    }
'