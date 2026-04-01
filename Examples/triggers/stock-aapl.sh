#!/bin/bash
# MenuBuddy trigger script: AAPL Stock Price (via East Money API)
# Monitors Apple stock price during US market hours, alerts on >2% swing.
#
# Install:
#   cp Examples/triggers/stock-aapl.sh ~/.menubuddy/triggers/
#   chmod +x ~/.menubuddy/triggers/stock-aapl.sh
#
# Data source: 东方财富 push API (public, no key required)
# Market: NASDAQ (code 105)

# --- Config ---
SYMBOL="AAPL"
MARKET="105"          # 105=NASDAQ, 106=NYSE
ALERT_PCT=2.0         # trigger when |change%| > this
POLL_INTERVAL=30      # seconds between polls

# --- Check if US market is likely open ---
# US Eastern: UTC-4 (EDT) or UTC-5 (EST)
# Market hours: 9:30-16:00 ET → roughly 21:30-04:00+1 Beijing, 13:30-20:00 UTC
# We just fetch regardless — API returns last known price when closed.
DOW=$(date -u +%u)  # 1=Mon ... 7=Sun
UTC_H=$(date -u +%H)
is_trading=false
# Rough UTC window for US market hours (summer time): 13:30 - 20:00
if [ "$DOW" -le 5 ] && [ "$UTC_H" -ge 13 ] && [ "$UTC_H" -lt 21 ]; then
    is_trading=true
fi

# --- Fetch from East Money API ---
URL="http://push2.eastmoney.com/api/qt/stock/get?secid=${MARKET}.${SYMBOL}&fields=f43,f44,f45,f46,f58,f170,f171"
RESP=$(curl -sL --max-time 5 "$URL" 2>/dev/null)

if [ -z "$RESP" ]; then
    # Network error — output metrics only with placeholder
    cat <<EOF
{
  "name": "AAPL",
  "interval": ${POLL_INTERVAL},
  "metrics": [
    { "label": "AAPL", "value": "--", "alert": false, "trend": "" }
  ]
}
EOF
    exit 0
fi

# --- Parse JSON (using built-in tools, no jq dependency) ---
# Extract fields from the flat JSON response
extract() {
    echo "$RESP" | grep -o "\"$1\":[^,}]*" | head -1 | sed 's/.*://'
}

raw_price=$(extract f43)      # current price × 1000
raw_open=$(extract f46)       # open price × 1000
raw_high=$(extract f44)       # high × 1000
raw_low=$(extract f45)        # low × 1000
raw_change=$(extract f170)    # change % × 100 (e.g. 250 = 2.50%)
raw_name=$(extract f58)       # stock name

# Validate
if [ -z "$raw_price" ] || [ "$raw_price" = "null" ] || [ "$raw_price" = "\"-\"" ]; then
    cat <<EOF
{
  "name": "AAPL",
  "interval": ${POLL_INTERVAL},
  "metrics": [
    { "label": "AAPL", "value": "N/A", "alert": false, "trend": "" }
  ]
}
EOF
    exit 0
fi

# Convert: East Money returns US stock prices × 1000, change% × 100
price=$(awk "BEGIN {printf \"%.2f\", $raw_price / 1000}")
change_pct=$(awk "BEGIN {printf \"%.2f\", $raw_change / 100}")

# Format display
price_str="\$${price}"

# Determine trend arrow
trend=""
if awk "BEGIN {exit !($change_pct > 0)}"; then
    trend="↑"
elif awk "BEGIN {exit !($change_pct < 0)}"; then
    trend="↓"
fi

change_str="${change_pct}%"
alert=false

# Check if |change%| exceeds alert threshold
abs_change=$(echo "$change_pct" | tr -d '-')
if awk "BEGIN {exit !($abs_change > $ALERT_PCT)}"; then
    alert=true
fi

# --- Build trigger (only when alert threshold crossed) ---
trigger=""
if [ "$alert" = "true" ]; then
    if echo "$change_pct > 0" | bc -l | grep -q 1; then
        trigger="\"trigger\": {
    \"indicator\": \"📈\",
    \"quips\": [\"AAPL +${change_str}!\", \"Apple is flying!\", \"stonks!\"],
    \"mood\": \"🤑\",
    \"eyeOverride\": \"$\",
    \"duration\": 30
  },"
    else
        trigger="\"trigger\": {
    \"indicator\": \"📉\",
    \"quips\": [\"AAPL ${change_str}...\", \"Apple is dropping...\", \"pain.\"],
    \"mood\": \"😰\",
    \"eyeOverride\": \".\",
    \"duration\": 30
  },"
    fi
fi

# --- Adjust poll interval ---
# Poll more frequently during trading hours
if [ "$is_trading" = "true" ]; then
    POLL_INTERVAL=30
else
    POLL_INTERVAL=300   # 5 min when market closed
fi

cat <<EOF
{
  "name": "AAPL ${change_str}",
  "interval": ${POLL_INTERVAL},
  ${trigger}
  "metrics": [
    { "label": "AAPL", "value": "${price_str}", "alert": ${alert}, "trend": "${trend}" }
  ]
}
EOF
