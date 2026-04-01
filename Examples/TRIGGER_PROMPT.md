# MenuBuddy Trigger Script Generator Prompt

Copy this prompt to any AI assistant (Claude, ChatGPT, etc.) to generate a custom trigger script for MenuBuddy.

---

## Prompt

```
Help me create a MenuBuddy trigger script. MenuBuddy is a macOS menu bar companion pet that reacts to external data via executable scripts placed in ~/.menubuddy/triggers/.

The script must:
1. Be an executable shell/python/node script
2. Print valid JSON to stdout
3. Exit with code 0

JSON format:
{
  "name": "Display Name",          // shown in Settings (optional, defaults to filename)
  "interval": 60,                  // polling interval in seconds (optional, default 60, min 5)
  "trigger": {                     // optional — fires a companion reaction
    "indicator": "📈",             // emoji shown in menu bar (required)
    "quips": ["text1", "text2"],   // speech bubble texts, one picked at random
    "mood": "🤑",                  // companion mood emoji override (optional)
    "eyeOverride": "$",            // replaces the eye character in menu bar face (optional)
    "duration": 30                 // how long indicator stays in seconds (optional, default 30)
  },
  "metrics": [                     // optional — live status strip pills
    {
      "label": "BTC",              // short label (required)
      "value": "$67,000",          // display value (required)
      "alert": false,              // highlight in orange (optional, default false)
      "trend": "↑"                 // "↑", "↓", or "" (optional, default "")
    }
  ]
}

Rules:
- "trigger" and "metrics" are both optional top-level fields
- If "trigger" is absent, no companion reaction fires (metrics-only mode)
- If "metrics" is absent, no status strip pill shown (trigger-only mode)
- Script should handle network errors gracefully (output metrics with "--" value)
- Use /tmp/ for state files if you need cross-run persistence
- Avoid dependencies beyond standard system tools (curl, awk, bc, python3, jq)
- The script runs in the user's home directory

My request: [DESCRIBE WHAT YOU WANT TO MONITOR AND WHEN TO TRIGGER]

Examples of what you can monitor:
- Stock/crypto prices (alert on % change)
- Weather (alert on rain/extreme temps)
- CI/CD pipeline status (alert on failure)
- Server uptime / response time
- GitHub notifications count
- Exchange rates
- Air quality index
- Any API that returns JSON
```

---

## Example requests

- "Monitor Bitcoin price via CoinGecko API, alert when 24h change exceeds 5%"
- "Check if my server at example.com is responding, alert if down"
- "Monitor GitHub notifications count, alert when > 5 unread"
- "Track USD/CNY exchange rate, alert on >0.5% daily change"
- "Check weather in Shanghai, alert on rain or temp > 35°C"
