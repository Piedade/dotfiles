# Shared station list for radio-menu and radio-toggle.
# Add more stations below, keeping NAMES, URLS and VOLUMES in sync by index.
# Using plain indexed arrays (not an associative array) so the menu order
# matches the order they're listed here.
#
# A URLS entry can list more than one candidate stream, separated by "|" —
# launch_station tries them in order and falls back to the next one if a
# candidate never connects (see Rádio Comercial below: same station,
# served from two different domains/edge servers).

NAMES=(
    "Antena 1"
    "Rádio Comercial"
    "Comercial Rock"
    "RADIO BOB! Best of Rock"
    "RADIO BOB! Classic Rock"
    "RADIO BOB! Metal"
    "M80"
    "M80 Rock"
    "Smooth FM"
)

URLS=(
    "https://streaming-live.rtp.pt/liveradio/antena180a/chunklist_DVR.m3u8"
    "https://stream-hls.rayo.pt/comercial.aac/playlist.m3u8|https://stream-hls.bauermedia.pt/comercial.aac/playlist.m3u8"
    "https://stream-hls.rayo.pt/rcrock.aac/playlist.m3u8"
    "https://regiocast.streamabc.net/regc-radiobobbestofrock1362412-mp3-192-5332584"
    "https://regiocast.streamabc.net/regc-radiobobclassicrock1594088-mp3-192-3516780"
    "https://regiocast.streamabc.net/regc-radiobobmetal3070164-mp3-192-5354778"
    "https://stream-hls.rayo.pt/m80.aac/playlist.m3u8"
    "https://stream-hls.rayo.pt/m80rock.aac/playlist.m3u8"
    "https://stream-icy.rayo.pt/smooth.aac"
)

# Optional per-station volume (%), same index as NAMES/URLS. Leave empty
# ("") to use whatever VLC's default is (100%).
#
# Antena 1 is the quietest station and is kept as the fixed reference
# (100%); every other value below was measured by recording each stream's
# raw VLC output (RMS over ~9s, first 0.5s skipped) and scaling it down to
# match Antena 1's RMS level. Re-measure and adjust if a stream's
# mastering changes.
VOLUMES=(
    "100"
    "80"
    "80"
    "80"
    "80"
    "80"
    "80"
    "80"
    "80"
)

# Splits a "|"-separated URLS entry into the candidates array, without
# touching the caller's IFS (a plain `local IFS='|'` would leak into any
# function called afterwards, e.g. breaking seq-based for loops elsewhere).
split_candidates() {
    IFS='|' read -ra candidates <<< "$1"
}

# Prints the station name owning the given single concrete URL (matches
# against each "|"-separated candidate), or nothing if not found.
station_name_for_url() {
    local target="$1" candidates candidate
    for i in "${!URLS[@]}"; do
        split_candidates "${URLS[$i]}"
        for candidate in "${candidates[@]}"; do
            if [ "$candidate" = "$target" ]; then
                echo "${NAMES[$i]}"
                return 0
            fi
        done
    done
}

# Prints the configured volume (%) for a given single concrete URL,
# defaulting to 100.
station_volume_for_url() {
    local target="$1" candidates candidate
    for i in "${!URLS[@]}"; do
        split_candidates "${URLS[$i]}"
        for candidate in "${candidates[@]}"; do
            if [ "$candidate" = "$target" ]; then
                echo "${VOLUMES[$i]:-100}"
                return 0
            fi
        done
    done
    echo 100
}

# Waits (up to ~4s, polling every 0.2s) for VLC's audio stream to show up
# in pipewire. Prints its id and returns 0 if it appears, otherwise
# returns 1 with nothing printed — this is how a station that fails to
# connect (dead URL, network hiccup, VLC hanging) gets detected, instead
# of just assuming "cvlc &" launched fine and it's playing.
wait_for_vlc_stream() {
    local id=""
    for _ in $(seq 1 20); do
        id=$(pw-dump | jq -r '.[] | select(.info.props."media.class"=="Stream/Output/Audio" and .info.props."application.process.binary"=="vlc") | .id' | head -n1)
        if [ -n "$id" ]; then
            echo "$id"
            return 0
        fi
        sleep 0.2
    done
    return 1
}

# Launches VLC on the given URL(s) — one, or several "|"-separated
# candidates for the same station — and applies the configured volume.
# Tries each candidate in turn, falling back to the next one if it never
# connects. Returns 0 once playing, or 1 if every candidate failed (VLC is
# left stopped in that case).
launch_station() {
    local urls="$1" candidates candidate id vol
    split_candidates "$urls"
    for candidate in "${candidates[@]}"; do
        pkill -x vlc 2>/dev/null; pidwait -x vlc 2>/dev/null
        cvlc "$candidate" &>/dev/null &
        if id=$(wait_for_vlc_stream); then
            vol=$(station_volume_for_url "$candidate")
            wpctl set-volume "$id" "${vol}%"
            return 0
        fi
    done
    pkill -x vlc 2>/dev/null
    return 1
}
