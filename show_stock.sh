#!/bin/bash
export PATH=$PATH:/bin:/usr/bin
cd ~/patdeg/tidbyt_stock_price
source .env

# Render with up to 3 attempts; transient Alpaca timeouts ("context deadline
# exceeded") are common and usually clear within seconds.
render_ticker() {
  local ticker=$1
  for attempt in 1 2 3; do
    if pixlet render stock_price.star symbol="$ticker" alpaca_key="$ALPACA_KEY" alpaca_secret="$ALPACA_SECRET"; then
      return 0
    fi
    [ "$attempt" -lt 3 ] && sleep 5
  done
  return 1
}

# Push only on successful render. Skipping prevents stale-frame errors and
# ensures we never push a previous ticker's image under the wrong installation-id.
push_ticker() {
  local ticker=$1 token=$2 device=$3
  echo "Showing $ticker on $device"
  rm -f stock_price.webp
  if render_ticker "$ticker"; then
    pixlet push --installation-id "$ticker" --api-token "$token" "$device" stock_price.webp
  else
    echo "[$ticker] render failed after 3 attempts; skipping push"
  fi
  sleep 1
}

for TICKER in VOO GEHC; do
  push_ticker "$TICKER" "$TIDBYT_API_TOKEN_DESK" "$TIDBYT_DEVICE_ID_DECK"
done

for TICKER in AMZN GOOG MSFT NVDA GEHC; do
  push_ticker "$TICKER" "$TIDBYT_API_TOKEN_SHELF" "$TIDBYT_DEVICE_ID_SHELF"
done

