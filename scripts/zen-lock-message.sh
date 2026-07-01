#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# zen-lock-message.sh v6.16.3.6
# ────────────────────────────────────────────────────────────────
# Outputs a single line for the hyprlock labels, contextual to:
#   - Time of day (morning / afternoon / evening / night)
#   - Weather condition (from ~/.cache/zen-shell/weather.json,
#     populated by WeatherService)
#   - User gender preference (from panel-state.json → userGender:
#     "neutral" | "male" | "female")
#   - Random seed (minute-of-day) so the care line rotates
#     naturally without feeling repetitive
#
# Usage:
#   zen-lock-message.sh weather   → "Rainy afternoon 🌧️"
#   zen-lock-message.sh care      → "What's up, man!"
#
# Called from hyprlock.conf label{} blocks every 60s.
# ════════════════════════════════════════════════════════════════

set -u

MODE="${1:-care}"
WEATHER_JSON="$HOME/.cache/zen-shell/weather.json"
PANEL_STATE="$HOME/.local/share/quickshell/zen-shell/panel-state.json"

# ── Inputs ──
HOUR=$(date +%H); HOUR=${HOUR#0}
MIN=$(date +%M); MIN=${MIN#0}

CONDITION=""
if [ -f "$WEATHER_JSON" ] && command -v jq >/dev/null 2>&1; then
    CONDITION=$(jq -r '.condition // ""' "$WEATHER_JSON" 2>/dev/null)
fi

GENDER="neutral"
if [ -f "$PANEL_STATE" ] && command -v jq >/dev/null 2>&1; then
    GENDER=$(jq -r '.userGender // "neutral"' "$PANEL_STATE" 2>/dev/null)
fi
case "$GENDER" in male|female|neutral) ;; *) GENDER="neutral" ;; esac

# ── Time-of-day bucket ──
if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 12 ];  then TOD="morning"
elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 17 ]; then TOD="afternoon"
elif [ "$HOUR" -ge 17 ] && [ "$HOUR" -lt 22 ]; then TOD="evening"
else                                                 TOD="night"
fi

# ── Weather bucket ──
WBUCKET="clear"
case "$CONDITION" in
    *Rain*|*Drizzle*|*rain*|*drizzle*)         WBUCKET="rain" ;;
    *Snow*|*snow*)                              WBUCKET="snow" ;;
    *Thunder*|*Storm*|*thunder*|*storm*)        WBUCKET="storm" ;;
    *Cloud*|*Overcast*|*cloud*|*overcast*)      WBUCKET="cloudy" ;;
    *Fog*|*Mist*|*fog*|*mist*|*Haze*|*haze*)    WBUCKET="foggy" ;;
    *Clear*|*Sun*|*clear*|*sun*|"")             WBUCKET="clear" ;;
    *)                                           WBUCKET="clear" ;;
esac

if [ "$TOD" = "night" ] && [ "$WBUCKET" = "clear" ]; then
    WBUCKET="starry"
fi

# ════════════════════════════════════════════════════════════════
# GREETING LINE (hf98c2) — time-aware greeting + WEATHER-matched emoji
# ════════════════════════════════════════════════════════════════
# Shown right below the lock-screen clock. Paul: "dapat may Hi, yun
# username" + "kung maulan dapat same din yung emoji dun sa pagbati."
# So the trailing emoji follows the SAME weather bucket as the mood line
# below — rainy greeting gets 🌧️, stormy gets ⛈️, not a fixed sun.
# Placed AFTER WBUCKET is computed so it can read the weather.
#   zen-lock-message.sh greet       -> "Good afternoon, Paul ⛈️"
#   zen-lock-message.sh greet hi    -> "Hi, Paul ⛈️"
if [ "$MODE" = "greet" ]; then
    UNAME_RAW="${USER:-$(id -un 2>/dev/null)}"
    [ -z "$UNAME_RAW" ] && UNAME_RAW="there"
    # Capitalise the first letter (paul -> Paul). GNU sed \U.
    UNAME_CAP="$(printf '%s' "$UNAME_RAW" | sed 's/^\(.\)/\U\1/' 2>/dev/null)"
    [ -z "$UNAME_CAP" ] && UNAME_CAP="$UNAME_RAW"

    # Emoji matches the weather bucket (clear is time-aware).
    case "$WBUCKET" in
        rain)    GREET_EMO="🌧️" ;;
        storm)   GREET_EMO="⛈️" ;;
        snow)    GREET_EMO="🌨️" ;;
        cloudy)  GREET_EMO="☁️" ;;
        foggy)   GREET_EMO="🌫️" ;;
        starry)  GREET_EMO="🌌" ;;
        clear)
            case "$TOD" in
                morning)   GREET_EMO="☀️" ;;
                afternoon) GREET_EMO="🌤️" ;;
                evening)   GREET_EMO="🌇" ;;
                night)     GREET_EMO="🌙" ;;
            esac ;;
        *)       GREET_EMO="💭" ;;
    esac

    if [ "${2:-time}" = "hi" ]; then
        echo "Hi, $UNAME_CAP $GREET_EMO"
        exit 0
    fi
    case "$TOD" in
        morning)   echo "Good morning, $UNAME_CAP $GREET_EMO" ;;
        afternoon) echo "Good afternoon, $UNAME_CAP $GREET_EMO" ;;
        evening)   echo "Good evening, $UNAME_CAP $GREET_EMO" ;;
        night)     echo "Working late, $UNAME_CAP $GREET_EMO" ;;
    esac
    exit 0
fi

pick() {
    local pool=("$@")
    local count=${#pool[@]}
    [ "$count" -eq 0 ] && return
    local seed=$(( (HOUR * 60 + MIN) % count ))
    printf '%s\n' "${pool[$seed]}"
}

# ════════════════════════════════════════════════════════════════
# WEATHER MOOD LINE (gender-neutral — weather is weather)
# ════════════════════════════════════════════════════════════════
if [ "$MODE" = "weather" ]; then
    case "$WBUCKET" in
        clear)
            case "$TOD" in
                morning)   echo "Sunny morning ☀️" ;;
                afternoon) echo "Bright afternoon 🌤️" ;;
                evening)   echo "Clear evening 🌇" ;;
                night)     echo "Quiet night 🌙" ;;
            esac ;;
        starry)  echo "Starry night sky 🌌" ;;
        cloudy)
            case "$TOD" in
                morning)   echo "Cloudy morning ☁️" ;;
                afternoon) echo "Overcast afternoon ⛅" ;;
                evening)   echo "Cloudy evening 🌥️" ;;
                night)     echo "Cloudy night ☁️🌙" ;;
            esac ;;
        rain)
            case "$TOD" in
                morning)   echo "Rainy morning 🌧️" ;;
                afternoon) echo "Rainy afternoon 🌧️" ;;
                evening)   echo "Rainy evening 🌧️" ;;
                night)     echo "Rainy night 🌧️" ;;
            esac ;;
        snow)    echo "Snowy ${TOD} 🌨️" ;;
        storm)   echo "Stormy ${TOD} ⛈️" ;;
        foggy)   echo "Foggy ${TOD} 🌫️" ;;
        *)       echo "Hope you're doing well 💭" ;;
    esac
    exit 0
fi

# ════════════════════════════════════════════════════════════════
# CARE LINE — rotating well-being message
# ════════════════════════════════════════════════════════════════
# Three gendered pools for every (time, weather) bucket.
#   neutral = safe, no gendered address
#   male    = "man", "bro", "dude", "boss", "sir"
#   female  = "miss", "queen", "madam"
# All English.

# ─── MORNING CLEAR ──────────────────────────────────────────────
MORN_CLEAR_N=(
    "Have a great day ahead"
    "Rise and shine"
    "Hope today's good to you"
    "Good to see you"
    "You got this"
    "Morning's on your side"
)
MORN_CLEAR_M=(
    "What's up, man!"
    "Rise and grind, bro"
    "Let's get it today, boss"
    "Morning, sir — hope it's a good one"
    "You got this, dude"
    "Good morning, chief"
)
MORN_CLEAR_F=(
    "Good morning, miss!"
    "Rise and shine, queen"
    "Let's own the day, miss"
    "Morning, madam — hope it's lovely"
    "You got this, queen"
    "Good morning, sunshine"
)

# ─── MORNING RAIN ───────────────────────────────────────────────
MORN_RAIN_N=(
    "Slow rainy morning — take your time"
    "Perfect weather for a quiet start"
    "Stay warm and cozy"
    "Rain's good company this morning"
)
MORN_RAIN_M=(
    "Stay cozy, man"
    "Coffee weather, bro"
    "Slow start suits you today, boss"
    "Rainy morning — perfect excuse to ease in, sir"
)
MORN_RAIN_F=(
    "Stay cozy, miss"
    "Tea weather, queen"
    "Slow rainy start, madam — take it gentle"
    "Rainy morning — make it a soft one, miss"
)

# ─── MORNING CLOUDY ─────────────────────────────────────────────
MORN_CLOUDY_N=(
    "Gentle morning light today"
    "Soft start to the day"
    "Hope today treats you kindly"
)
MORN_CLOUDY_M=(
    "Soft morning, man"
    "Easy does it, bro"
    "Take it gentle today, boss"
)
MORN_CLOUDY_F=(
    "Soft morning, miss"
    "Easy does it, queen"
    "Gentle day ahead, madam"
)

# ─── AFTERNOON CLEAR ────────────────────────────────────────────
AFT_CLEAR_N=(
    "Taking a break? You've earned it"
    "How's your day going?"
    "Step outside later maybe — sun's out"
    "You're doing great"
    "Hope the afternoon's good to you"
)
AFT_CLEAR_M=(
    "How's it going, man?"
    "Grab some fresh air, bro"
    "You're crushing it today, boss"
    "Sun's out — touch grass, dude"
    "Keep it up, sir"
)
AFT_CLEAR_F=(
    "How's the day going, miss?"
    "Grab some sunshine, queen"
    "You're killing it today, madam"
    "Take a breather, miss"
    "Keep shining"
)

# ─── AFTERNOON RAIN ─────────────────────────────────────────────
AFT_RAIN_N=(
    "Rain's nice company this afternoon"
    "Tea or coffee weather ☕"
    "Take it slow — the day's not a race"
    "Hope you're staying cozy"
)
AFT_RAIN_M=(
    "Tea or coffee, bro? ☕"
    "Stay cozy, man"
    "Perfect afternoon to slow down, boss"
)
AFT_RAIN_F=(
    "Tea time, miss? ☕"
    "Stay cozy, queen"
    "Perfect afternoon to slow down, madam"
)

# ─── AFTERNOON CLOUDY ───────────────────────────────────────────
AFT_CLOUDY_N=(
    "Easy afternoon vibes"
    "Chill pace suits today"
    "Hope you're doing ok"
)
AFT_CLOUDY_M=(
    "Chill afternoon, man"
    "Take it easy, bro"
    "Quiet vibes today, boss"
)
AFT_CLOUDY_F=(
    "Chill afternoon, miss"
    "Take it easy, queen"
    "Quiet vibes today, madam"
)

# ─── EVENING CLEAR ──────────────────────────────────────────────
EVE_CLEAR_N=(
    "Winding down? You've had a good day"
    "Hope today was kind to you"
    "Sunset's a good excuse for a pause"
    "You made it through — take the evening"
)
EVE_CLEAR_M=(
    "Winding down, man?"
    "Hope you had a good one, bro"
    "Evening's yours now, boss"
    "You made it, sir — take the night off"
)
EVE_CLEAR_F=(
    "Winding down, miss?"
    "Hope today was good to you, queen"
    "Evening's yours now, madam"
    "You made it — relax, miss"
)

# ─── EVENING RAIN ───────────────────────────────────────────────
EVE_RAIN_N=(
    "Rainy evenings are for resting"
    "Blanket weather 🫖"
    "Let the rain do the talking tonight"
    "Hope you're staying warm"
)
EVE_RAIN_M=(
    "Blanket weather, bro 🫖"
    "Stay warm, man"
    "Rain's perfect for resting, boss"
)
EVE_RAIN_F=(
    "Blanket weather, miss 🫖"
    "Stay warm, queen"
    "Perfect rest weather, madam"
)

# ─── EVENING CLOUDY ─────────────────────────────────────────────
EVE_CLOUDY_N=(
    "Quiet evening ahead"
    "Soft skies. Soft evening."
    "Hope you're taking it easy"
)
EVE_CLOUDY_M=(
    "Quiet evening, man"
    "Take it easy tonight, bro"
)
EVE_CLOUDY_F=(
    "Quiet evening, miss"
    "Take it easy tonight, queen"
)

# ─── NIGHT CLEAR ────────────────────────────────────────────────
NIGHT_CLEAR_N=(
    "Working late? Don't forget to rest"
    "Hope you're doing ok this late"
    "Quiet night — take care"
    "Take care of yourself"
)
NIGHT_CLEAR_M=(
    "Working late, man?"
    "Don't stay up too late, bro"
    "Take care of yourself, boss"
    "Rest up, sir"
)
NIGHT_CLEAR_F=(
    "Working late, miss?"
    "Don't stay up too late, queen"
    "Take care of yourself, madam"
    "Rest up, miss"
)

# ─── NIGHT STARRY ───────────────────────────────────────────────
NIGHT_STARRY_N=(
    "Stars look nice tonight"
    "Clear sky — good sleeping weather"
    "Don't stay up too late 🌙"
    "Hope you rest well tonight"
)
NIGHT_STARRY_M=(
    "Stars are out, man 🌌"
    "Clear night — rest up, bro"
    "Sleep well, boss"
)
NIGHT_STARRY_F=(
    "Stars are out, miss 🌌"
    "Clear night — rest up, queen"
    "Sleep well, madam"
)

# ─── NIGHT RAIN ─────────────────────────────────────────────────
NIGHT_RAIN_N=(
    "Rain at night is the best kind"
    "Sleep weather tonight"
    "Let the rain tuck you in"
    "Hope you're warm and dry"
)
NIGHT_RAIN_M=(
    "Sleep weather, bro"
    "Stay warm, man"
    "Rain's putting you to sleep, boss"
)
NIGHT_RAIN_F=(
    "Sleep weather, miss"
    "Stay warm, queen"
    "Rain's putting you to sleep, madam"
)

# ─── NIGHT CLOUDY ───────────────────────────────────────────────
NIGHT_CLOUDY_N=(
    "Muffled quiet night"
    "Heavy sky, light rest"
    "Hope you're doing ok tonight"
)
NIGHT_CLOUDY_M=(
    "Quiet cloudy night, man"
    "Rest easy, bro"
)
NIGHT_CLOUDY_F=(
    "Quiet cloudy night, miss"
    "Rest easy, queen"
)

# ─── WEATHER-EXOTIC (any time of day) ───────────────────────────
SNOW_N=(
    "Stay warm — it's snowing out there 🌨️"
    "Hot cocoa weather"
    "Snow makes everything quieter"
)
SNOW_M=(
    "Stay warm, man — it's snowing ❄️"
    "Hot cocoa weather, bro"
)
SNOW_F=(
    "Stay warm, miss — it's snowing ❄️"
    "Hot cocoa weather, queen"
)

STORM_N=(
    "Storm's rough — hope you're safe inside ⛈️"
    "Stay away from windows"
    "Loud sky. Stay warm and safe."
)
STORM_M=(
    "Stay safe, man — storm's rough ⛈️"
    "Away from windows, bro"
)
STORM_F=(
    "Stay safe, miss — storm's rough ⛈️"
    "Away from windows, queen"
)

FOGGY_N=(
    "Fog's soft on the world today"
    "Slow morning energy — fog will lift"
    "Take it carefully out there"
)
FOGGY_M=(
    "Foggy out, man — drive careful"
    "Slow pace today, bro"
)
FOGGY_F=(
    "Foggy out, miss — drive careful"
    "Slow pace today, queen"
)

# ─── Pool selection helper ──────────────────────────────────────
# Uses bash namerefs (declare -n) to resolve the array by dynamic
# name. Falls back to the neutral pool if the gendered pool
# happens to be empty (e.g. I haven't written a gendered version
# of that specific time/weather bucket yet).
pool_pick() {
    local prefix="$1"
    local g
    case "$GENDER" in
        male)   g="M" ;;
        female) g="F" ;;
        *)      g="N" ;;
    esac
    local varname="${prefix}_${g}"
    declare -n pool_ref="$varname"
    if [ "${#pool_ref[@]}" -eq 0 ]; then
        unset -n pool_ref
        declare -n pool_ref="${prefix}_N"
    fi
    pick "${pool_ref[@]}"
}

# ─── Selection ──────────────────────────────────────────────────
case "$WBUCKET" in
    snow)    pool_pick SNOW;    exit ;;
    storm)   pool_pick STORM;   exit ;;
    foggy)   pool_pick FOGGY;   exit ;;
    starry)  pool_pick NIGHT_STARRY; exit ;;
esac

case "${TOD}_${WBUCKET}" in
    morning_clear)    pool_pick MORN_CLEAR ;;
    morning_rain)     pool_pick MORN_RAIN ;;
    morning_cloudy)   pool_pick MORN_CLOUDY ;;
    afternoon_clear)  pool_pick AFT_CLEAR ;;
    afternoon_rain)   pool_pick AFT_RAIN ;;
    afternoon_cloudy) pool_pick AFT_CLOUDY ;;
    evening_clear)    pool_pick EVE_CLEAR ;;
    evening_rain)     pool_pick EVE_RAIN ;;
    evening_cloudy)   pool_pick EVE_CLOUDY ;;
    night_clear)      pool_pick NIGHT_CLEAR ;;
    night_rain)       pool_pick NIGHT_RAIN ;;
    night_cloudy)     pool_pick NIGHT_CLOUDY ;;
    *)                echo "Hope you're doing well 💭" ;;
esac
