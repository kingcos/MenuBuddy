#!/bin/bash
# MenuBuddy trigger script: CPU & Memory Monitor
# Shows CPU and memory usage, triggers reactions when overloaded.
#
# Install:
#   cp Examples/triggers/cpu-memory.sh ~/.menubuddy/triggers/
#   chmod +x ~/.menubuddy/triggers/cpu-memory.sh

# CPU usage (percentage, integer)
cpu=$(ps -A -o %cpu | awk '{sum+=$1} END {printf "%d", sum / 1}')
# Clamp to 0-100 range (sum of all processes can exceed 100 on multi-core)
total_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 8)
cpu_pct=$((cpu > total_cores * 100 ? 100 : cpu * 100 / (total_cores * 100)))

# Memory usage
mem_info=$(vm_stat 2>/dev/null)
page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
pages_free=$(echo "$mem_info" | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
pages_inactive=$(echo "$mem_info" | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')
total_mem=$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592)
free_bytes=$(( (pages_free + pages_inactive) * page_size ))
mem_pct=$(( 100 - free_bytes * 100 / total_mem ))

# CPU alert & trigger
cpu_alert=false
cpu_trend=""
trigger=""

if [ "$cpu_pct" -ge 80 ]; then
    cpu_alert=true
    cpu_trend="↑"
    trigger='"trigger": {
    "indicator": "🔥",
    "quips": ["CPU is on fire!", "so hot...", "fan spinning!"],
    "mood": "😰",
    "eyeOverride": "x",
    "duration": 20
  },'
elif [ "$cpu_pct" -ge 50 ]; then
    cpu_trend="↑"
fi

# Memory alert (override trigger if memory is worse)
mem_alert=false
mem_trend=""

if [ "$mem_pct" -ge 90 ]; then
    mem_alert=true
    mem_trend="↑"
    trigger='"trigger": {
    "indicator": "🧠",
    "quips": ["brain full!", "too much stuff...", "need more RAM"],
    "mood": "😵",
    "eyeOverride": "~",
    "duration": 20
  },'
elif [ "$mem_pct" -ge 70 ]; then
    mem_trend="↑"
fi

cat <<EOF
{
  "name": "CPU & Memory",
  "interval": 15,
  ${trigger}
  "metrics": [
    { "label": "CPU", "value": "${cpu_pct}%", "alert": ${cpu_alert}, "trend": "${cpu_trend}" },
    { "label": "MEM", "value": "${mem_pct}%", "alert": ${mem_alert}, "trend": "${mem_trend}" }
  ]
}
EOF
