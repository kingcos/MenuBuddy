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
    "quips": ["feeling random!", "dice says hi", "🎲🎲🎲"],
    "mood": "🤪",
    "duration": 15
  },
  "metrics": [
    { "label": "RNG", "value": "42", "alert": false, "trend": "" }
  ]
}
EOF
