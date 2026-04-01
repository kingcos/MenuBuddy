#!/bin/bash
# MenuBuddy trigger script: Network Speed Monitor
# Monitors network throughput and triggers reactions on speed changes.
#
# Install:
#   cp Examples/triggers/network-speed.sh ~/.menubuddy/triggers/
#   chmod +x ~/.menubuddy/triggers/network-speed.sh

STATE_FILE="/tmp/.menubuddy_net_state"

# Get current bytes across all non-loopback interfaces
get_bytes() {
    netstat -ibn 2>/dev/null | awk '
        NR > 1 && $1 !~ /^lo/ && $4 ~ /^[0-9]/ {
            in_bytes += $7; out_bytes += $10
        }
        END { print in_bytes + 0, out_bytes + 0 }
    '
}

read -r cur_in cur_out <<< "$(get_bytes)"
now=$(date +%s)

# Read previous state
if [ -f "$STATE_FILE" ]; then
    read -r prev_in prev_out prev_time < "$STATE_FILE"
else
    # First run — save baseline and output metrics only
    echo "$cur_in $cur_out $now" > "$STATE_FILE"
    cat <<EOF
{
  "name": "Network Speed",
  "interval": 10,
  "metrics": [
    { "label": "↓", "value": "-- KB/s" },
    { "label": "↑", "value": "-- KB/s" }
  ]
}
EOF
    exit 0
fi

# Save current state
echo "$cur_in $cur_out $now" > "$STATE_FILE"

# Calculate speed
elapsed=$((now - prev_time))
[ "$elapsed" -le 0 ] && elapsed=1

down_bps=$(( (cur_in - prev_in) / elapsed ))
up_bps=$(( (cur_out - prev_out) / elapsed ))
total_bps=$((down_bps + up_bps))

# Format human-readable
format_speed() {
    local bps=$1
    if [ "$bps" -ge 1048576 ]; then
        printf "%.1f MB/s" "$(echo "scale=1; $bps / 1048576" | bc)"
    elif [ "$bps" -ge 1024 ]; then
        printf "%d KB/s" "$((bps / 1024))"
    else
        printf "%d B/s" "$bps"
    fi
}

down_str=$(format_speed $down_bps)
up_str=$(format_speed $up_bps)

down_alert=false
up_alert=false
[ "$down_bps" -ge 5242880 ] && down_alert=true
[ "$up_bps" -ge 5242880 ] && up_alert=true

# Determine trend (compare to rough threshold)
down_trend=""
up_trend=""
[ "$down_bps" -ge 1048576 ] && down_trend="↑"
[ "$up_bps" -ge 1048576 ] && up_trend="↑"
[ "$down_bps" -lt 1024 ] && down_trend="↓"
[ "$up_bps" -lt 1024 ] && up_trend="↓"

# Build trigger (only fire if speed is notable)
trigger=""
if [ "$total_bps" -ge 5242880 ]; then
    trigger='"trigger": {
    "indicator": "⚡",
    "quips": ["downloading fast!", "data incoming!", "network go brrrr"],
    "mood": "🚀",
    "duration": 15
  },'
elif [ "$total_bps" -ge 1048576 ]; then
    trigger='"trigger": {
    "indicator": "📡",
    "quips": ["busy network!", "bytes flowing~"],
    "duration": 10
  },'
fi

cat <<EOF
{
  "name": "Network Speed",
  "interval": 10,
  ${trigger}
  "metrics": [
    { "label": "↓", "value": "${down_str}", "alert": ${down_alert}, "trend": "${down_trend}" },
    { "label": "↑", "value": "${up_str}", "alert": ${up_alert}, "trend": "${up_trend}" }
  ]
}
EOF
