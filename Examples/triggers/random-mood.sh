#!/bin/bash
# Example MenuBuddy trigger script
# Drop this into ~/.menubuddy/triggers/ and make it executable:
#   cp random-mood.sh ~/.menubuddy/triggers/
#   chmod +x ~/.menubuddy/triggers/random-mood.sh
#
# This script demonstrates the JSON format.
# MenuBuddy runs it every `interval` seconds and reads stdout.

cat <<'EOF'
{
  "name": "Random Mood",
  "interval": 120,
  "trigger": {
    "indicator": "🎲",
    "quips": ["随机心情!", "骰子问好", "掷骰子!"],
    "mood": "🤪",
    "duration": 15
  },
  "metrics": [
    { "label": "RNG", "value": "42", "alert": false, "trend": "" }
  ]
}
EOF
