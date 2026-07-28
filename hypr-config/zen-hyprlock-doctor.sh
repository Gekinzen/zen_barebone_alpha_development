#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# zen-hyprlock-doctor — inventory (and optionally repair) ~/.config/hypr/hyprlock.conf
#
#   zen-hyprlock-doctor           # report only. Touches nothing.
#   zen-hyprlock-doctor --fix     # comment out power-button blocks, add source=
#   zen-hyprlock-doctor --undo    # remove every ##zen## prefix
#
# Zen Shell does not own hyprlock.conf. This is how we look at yours without
# asking you to paste it, and how you repair it without waiting for an install.
# ─────────────────────────────────────────────────────────────────────────────
set -u
CONF="${HYPRLOCK_CONF:-$HOME/.config/hypr/hyprlock.conf}"
INCLUDE="$HOME/.config/hypr/zen-hyprlock-power.conf"
TS="$(date +%Y%m%d-%H%M%S)"
BEGIN="# >>> zen-shell hyprlock power buttons >>>"
END="# <<< zen-shell hyprlock power buttons <<<"

[ -f "$CONF" ] || { echo "no $CONF"; exit 1; }

echo "hyprlock: $(hyprlock --version 2>/dev/null | head -1 || echo 'not found')"
echo "config  : $CONF  ($(wc -l < "$CONF") lines)"
echo "include : $([ -f "$INCLUDE" ] && echo present || echo absent)"
active_src=$(grep -cE '^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-power\.conf' "$CONF")
echo "sources our include: $active_src time(s)$([ "$active_src" -gt 1 ] && echo '   <-- DUPLICATE: every widget is drawn twice')"
echo

_awk_inventory() {
awk '
function iscomment(l) { return l ~ /^[ \t]*#/ }
function is_open(l)  { return !iscomment(l) && l ~ /^[ \t]*[A-Za-z_-]+[ \t]*\{[ \t]*$/ }
function is_close(l) { return !iscomment(l) && l ~ /^[ \t]*\}[ \t]*$/ }
function val(l) { sub(/^[ \t]*[a-z_]+[ \t]*=[ \t]*/, "", l); return l }
BEGIN { d=0; printf "%-6s %-11s %-16s %-9s %s\n", "lines", "block", "position", "onclick", "text / notes" }
{
  if (d==0 && is_open($0)) { t=$0; sub(/[ \t]*\{.*/,"",t); gsub(/[ \t]/,"",t); ty=t; st=NR; pos=""; oc=""; tx=""; ff="" }
  if (d>=1 || is_open($0)) {
    if (!iscomment($0)) {
      if ($0 ~ /^[ \t]*position[ \t]*=/)    { pos=val($0); gsub(/[ \t]/,"",pos) }
      if ($0 ~ /^[ \t]*onclick[ \t]*=/)     { oc=val($0) }
      if ($0 ~ /^[ \t]*text[ \t]*=/)        { tx=substr(val($0),1,44) }
      if ($0 ~ /^[ \t]*font_family[ \t]*=/) { ff=val($0) }
    }
  }
  d += is_open($0) ? 1 : (is_close($0) ? -1 : 0)
  if (d==0 && ty!="") {
    if (ty=="label"||ty=="shape"||ty=="image"||ty=="input-field")
      printf "%-6s %-11s %-16s %-9s %s\n", st"-"NR, ty, (pos==""?"-":pos), (oc==""?"-":substr(oc,1,9)), (tx!=""?tx:(ff!=""?"font: "ff:""))
    ty=""
  }
}' "$CONF"
}

case "${1:-}" in
  --undo)
      cp "$CONF" "$CONF.bak.$TS"
      sed -i 's/^##zen## //' "$CONF"
      sed -i -E '/^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-(power|ui)\.conf/d' "$CONF"
      sed -i "/$(printf '%s' "$BEGIN" | sed 's/[]\/$*.^[]/\\&/g')/,/$(printf '%s' "$END" | sed 's/[]\/$*.^[]/\\&/g')/d" "$CONF"
      echo "undone. backup: $CONF.bak.$TS"
      exit 0 ;;
  --status)
      # See what hyprlock will actually draw, without locking the screen.
      UI="$HOME/.config/hypr/zen-hyprlock-ui.conf"
      echo "ui include : $([ -f "$UI" ] && echo "present ($(wc -l < "$UI") lines)" || echo absent)"
      nui=$(grep -cE '^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-ui\.conf' "$CONF")
      npw=$(grep -cE '^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-power\.conf' "$CONF")
      echo "wired      : ui=$nui  power=$npw   (want ui=1 power=0)"
      if [ "$nui" -ge 1 ] && [ "$npw" -ge 1 ]; then
          echo
          echo "  ⚠ BOTH includes are sourced. zen-hyprlock-ui.conf already has the"
          echo "    power buttons, so you are seeing two of each. Fix:"
          echo "      sed -i -E '/^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-power\\.conf/d' $CONF"
          echo
      fi
      echo "live widgets in hyprlock.conf: $(grep -cE '^(label|shape|image|input-field)[[:space:]]*\{[[:space:]]*$' "$CONF")  (want 0 after --ui)"
      if [ -f "$UI" ]; then
          echo
          echo "what the cmd[] labels render right now:"
          grep -E '^[[:space:]]*text[[:space:]]*=[[:space:]]*cmd\[' "$UI" | while IFS= read -r l; do
              c="${l#*]}"
              printf '   %s\n' "$(/bin/sh -c "$c" 2>&1 | head -1)"
          done
      fi
      echo
      echo "hyprlock reads its config at LAUNCH. Lock again to see changes:"
      echo "   hyprlock      (or your Super+L bind)"
      exit 0 ;;
  --ui)
      # Comment out every widget and let zen-hyprlock-ui.conf own the stack.
      UI="$HOME/.config/hypr/zen-hyprlock-ui.conf"
      [ -f "$UI" ] || { echo "missing $UI — run the installer first"; exit 1; }
      cp "$CONF" "$CONF.bak.$TS"
      AWKF="$(mktemp)"
      cat > "$AWKF" <<'ZENAWKEOF'
# Comments out hyprlock widget blocks so a zen-shell include can own them.
#
#   mode=power (default) : only blocks that drive a power action, plus the pill
#                          `shape` that shares their `position`
#   mode=ui              : every label/shape/image/input-field block
#
# Lines are PREFIXED with "##zen## ", never deleted.  Undo:
#   sed -i 's/^##zen## //' file
#
# Structure is read through hyprlang's own comment rule (config.cpp:688-716):
# a bare `#` truncates the rest of the line, `##` is the escape for a literal
# `#`.  Without this, `label {   # the clock` never opens a block, its closing
# `}` drives the depth counter negative, and every widget after it is invisible
# to us.  hyprlock's own example config has exactly that shape.
BEGIN { depth = 0; nb = 0; killed = 0 }

function codeof(l,   p, n) {
    sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
    p = index(l, "#")
    if (p == 1) return ""
    while (p > 0) {
        if (substr(l, p + 1, 1) == "#") {
            l = substr(l, 1, p) substr(l, p + 2)     # "##" -> "#"
            n = index(substr(l, p + 1), "#")
            p = (n > 0) ? p + n : 0
        } else {
            l = substr(l, 1, p - 1)
            break
        }
    }
    sub(/[ \t]+$/, "", l)
    return l
}
function is_open(c)  { return c ~ /^[A-Za-z_-]+[ \t]*\{$/ }
function is_close(c) { return c == "}" }
function opens(c)    { return is_open(c) && c ~ /^(label|shape|image|input-field)[ \t]*\{/ }
function delta(c)    { return is_open(c) ? 1 : (is_close(c) ? -1 : 0) }

{
    line[NR] = $0
    C = codeof($0)

    if (depth == 0 && opens(C)) {
        nb++
        bstart[nb] = NR
        t = C; sub(/[ \t]*\{.*/, "", t)
        btype[nb] = t
        bpos[nb] = ""
        bkill[nb] = (mode == "ui") ? 1 : 0
        inb = nb
    }
    if (inb) {
        if (C ~ /^onclick[ \t]*=.*(poweroff|reboot|shutdown|halt)/) bkill[inb] = 1
        if (C ~ /^position[ \t]*=/) { p = C; sub(/^position[ \t]*=[ \t]*/, "", p); gsub(/[ \t]/, "", p); bpos[inb] = p }
    }
    depth += delta(C)
    if (inb && depth == 0) { bend[inb] = NR; inb = 0 }
}

END {
    if (mode != "ui") {
        for (i = 1; i <= nb; i++) if (bkill[i] && bpos[i] != "") killpos[bpos[i]] = 1
        for (i = 1; i <= nb; i++)
            if (!bkill[i] && btype[i] == "shape" && bpos[i] != "" && (bpos[i] in killpos)) bkill[i] = 1
    }
    for (i = 1; i <= nb; i++) if (bkill[i]) {
        for (n = bstart[i]; n <= bend[i]; n++) mark[n] = 1
        printf("    commented %s block, lines %d-%d (position %s)\n", btype[i], bstart[i], bend[i], (bpos[i]==""?"-":bpos[i])) > "/dev/stderr"
        killed++
    }
    if (mode != "ui")
        for (i = 1; i <= nb; i++)
            if (!bkill[i] && btype[i] == "shape" && killed > 0)
                printf("    NOTE: shape at lines %d-%d (position %s) left alone.\n         If an empty pill remains, comment it too.\n", bstart[i], bend[i], bpos[i]) > "/dev/stderr"
    if (killed == 0) printf("    nothing to comment\n") > "/dev/stderr"
    for (n = 1; n <= NR; n++) print (mark[n] ? "##zen## " line[n] : line[n])
}
ZENAWKEOF
      awk -v mode=ui -f "$AWKF" "$CONF" > "$CONF.tmp" 2>"$CONF.log"
      sed 's/^/  /' "$CONF.log"; rm -f "$CONF.log"
      if [ -s "$CONF.tmp" ]; then mv "$CONF.tmp" "$CONF"; else rm -f "$CONF.tmp"; rm -f "$AWKF"; echo "  nothing changed"; exit 1; fi
      rm -f "$AWKF"
      # exactly one source line, and it points at the UI file
      sed -i -E '/^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-(power|ui)\.conf/d' "$CONF"
      sed -i "/$(printf '%s' "$BEGIN" | sed 's/[]\/$*.^[]/\\&/g')/d;/$(printf '%s' "$END" | sed 's/[]\/$*.^[]/\\&/g')/d" "$CONF"
      { printf '\n%s\n' "$BEGIN"; printf '%s\n' "source = ~/.config/hypr/zen-hyprlock-ui.conf"; printf '%s\n' "$END"; } >> "$CONF"
      echo "  full UI applied. backup: $CONF.bak.$TS"
      echo "  undo : $0 --undo"
      echo
      echo "after:"
      _awk_inventory
      exit 0 ;;
  --fix)
      if grep -qE '^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-ui\.conf' "$CONF"; then
          echo "hyprlock.conf already sources zen-hyprlock-ui.conf, which contains the"
          echo "power buttons. --fix would add a second set. Nothing done."
          exit 0
      fi
      cp "$CONF" "$CONF.bak.$TS"
      AWKF="$(mktemp)"
      cat > "$AWKF" <<'ZENAWKEOF'
# Comments out hyprlock widget blocks so a zen-shell include can own them.
#
#   mode=power (default) : only blocks that drive a power action, plus the pill
#                          `shape` that shares their `position`
#   mode=ui              : every label/shape/image/input-field block
#
# Lines are PREFIXED with "##zen## ", never deleted.  Undo:
#   sed -i 's/^##zen## //' file
#
# Structure is read through hyprlang's own comment rule (config.cpp:688-716):
# a bare `#` truncates the rest of the line, `##` is the escape for a literal
# `#`.  Without this, `label {   # the clock` never opens a block, its closing
# `}` drives the depth counter negative, and every widget after it is invisible
# to us.  hyprlock's own example config has exactly that shape.
BEGIN { depth = 0; nb = 0; killed = 0 }

function codeof(l,   p, n) {
    sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
    p = index(l, "#")
    if (p == 1) return ""
    while (p > 0) {
        if (substr(l, p + 1, 1) == "#") {
            l = substr(l, 1, p) substr(l, p + 2)     # "##" -> "#"
            n = index(substr(l, p + 1), "#")
            p = (n > 0) ? p + n : 0
        } else {
            l = substr(l, 1, p - 1)
            break
        }
    }
    sub(/[ \t]+$/, "", l)
    return l
}
function is_open(c)  { return c ~ /^[A-Za-z_-]+[ \t]*\{$/ }
function is_close(c) { return c == "}" }
function opens(c)    { return is_open(c) && c ~ /^(label|shape|image|input-field)[ \t]*\{/ }
function delta(c)    { return is_open(c) ? 1 : (is_close(c) ? -1 : 0) }

{
    line[NR] = $0
    C = codeof($0)

    if (depth == 0 && opens(C)) {
        nb++
        bstart[nb] = NR
        t = C; sub(/[ \t]*\{.*/, "", t)
        btype[nb] = t
        bpos[nb] = ""
        bkill[nb] = (mode == "ui") ? 1 : 0
        inb = nb
    }
    if (inb) {
        if (C ~ /^onclick[ \t]*=.*(poweroff|reboot|shutdown|halt)/) bkill[inb] = 1
        if (C ~ /^position[ \t]*=/) { p = C; sub(/^position[ \t]*=[ \t]*/, "", p); gsub(/[ \t]/, "", p); bpos[inb] = p }
    }
    depth += delta(C)
    if (inb && depth == 0) { bend[inb] = NR; inb = 0 }
}

END {
    if (mode != "ui") {
        for (i = 1; i <= nb; i++) if (bkill[i] && bpos[i] != "") killpos[bpos[i]] = 1
        for (i = 1; i <= nb; i++)
            if (!bkill[i] && btype[i] == "shape" && bpos[i] != "" && (bpos[i] in killpos)) bkill[i] = 1
    }
    for (i = 1; i <= nb; i++) if (bkill[i]) {
        for (n = bstart[i]; n <= bend[i]; n++) mark[n] = 1
        printf("    commented %s block, lines %d-%d (position %s)\n", btype[i], bstart[i], bend[i], (bpos[i]==""?"-":bpos[i])) > "/dev/stderr"
        killed++
    }
    if (mode != "ui")
        for (i = 1; i <= nb; i++)
            if (!bkill[i] && btype[i] == "shape" && killed > 0)
                printf("    NOTE: shape at lines %d-%d (position %s) left alone.\n         If an empty pill remains, comment it too.\n", bstart[i], bend[i], bpos[i]) > "/dev/stderr"
    if (killed == 0) printf("    nothing to comment\n") > "/dev/stderr"
    for (n = 1; n <= NR; n++) print (mark[n] ? "##zen## " line[n] : line[n])
}
ZENAWKEOF
      awk -f "$AWKF" "$CONF" > "$CONF.tmp" 2>&1 >/dev/null || true
      awk -f "$AWKF" "$CONF" > "$CONF.tmp" 2>"$CONF.log"
      sed 's/^/  /' "$CONF.log"; rm -f "$CONF.log"
      [ -s "$CONF.tmp" ] && mv "$CONF.tmp" "$CONF" || rm -f "$CONF.tmp"
      rm -f "$AWKF"
      # exactly one active source line, ever
      sed -i -E '/^[[:space:]]*source[[:space:]]*=.*zen-hyprlock-power\.conf/d' "$CONF"
      sed -i "/$(printf '%s' "$BEGIN" | sed 's/[]\/$*.^[]/\\&/g')/d;/$(printf '%s' "$END" | sed 's/[]\/$*.^[]/\\&/g')/d" "$CONF"
      { printf '\n%s\n' "$BEGIN"; printf '%s\n' "source = ~/.config/hypr/zen-hyprlock-power.conf"; printf '%s\n' "$END"; } >> "$CONF"
      echo "  fixed. backup: $CONF.bak.$TS"
      echo "  undo : $0 --undo"
      echo
      echo "after:"
      _awk_inventory
      exit 0 ;;
esac

echo "widget inventory (top-level blocks):"
_awk_inventory
echo
echo "--fix   comment power-button blocks, source ours once"
echo "--ui    hand the whole centre stack to zen-hyprlock-ui.conf"
echo "--status  what will hyprlock draw?      --undo  put everything back"
