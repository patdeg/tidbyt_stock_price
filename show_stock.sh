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
# Retry on transient Tidbyt API errors (503, connection reset): a single
# silent push failure was leaving the device on the previous frame for hours,
# which is how stale prices ended up on display.
push_ticker() {
  local ticker=$1 token=$2 device=$3
  echo "Showing $ticker on $device"
  rm -f stock_price.webp
  if render_ticker "$ticker"; then
    local pushed=0
    for attempt in 1 2 3; do
      if pixlet push --installation-id "$ticker" --api-token "$token" "$device" stock_price.webp; then
        pushed=1
        break
      fi
      echo "[$ticker] push attempt $attempt failed"
      [ "$attempt" -lt 3 ] && sleep 5
    done
    if [ "$pushed" -eq 0 ]; then
      echo "[$ticker] push failed after 3 attempts; device will keep previous frame"
    fi
  else
    echo "[$ticker] render failed after 3 attempts; skipping push"
  fi
  sleep 1
}

# Each device gets its own ticker list. Keep both lists short: every ticker is
# a separate installation-id, so it takes an equal slice of the device's app
# rotation, and these devices also run clock, sunrise-sunset, aistatus and
# cloudstatus. More tickers means each one is on screen less often.
#
# Ticker availability is limited by the data source: stock_price.star reads
# Alpaca's IEX feed, which covers US exchange listings only. OTC-traded ADRs
# return no data and render nothing -- verify a new symbol with
# `pixlet render stock_price.star symbol=XXX ...` before adding it here.

# Thematic indexes come from mbt_index.star (basket membership lives there), not
# stock_price.star. Same render/push discipline as a single ticker.
push_index() {
  local idx=$1 id=$2 token=$3 device=$4
  echo "Showing index $idx ($id) on $device"
  rm -f mbt_index.webp
  local ok=0
  for attempt in 1 2 3; do
    if pixlet render mbt_index/mbt_index.star index="$idx" alpaca_key="$ALPACA_KEY" alpaca_secret="$ALPACA_SECRET" -o mbt_index.webp; then
      ok=1; break
    fi
    [ "$attempt" -lt 3 ] && sleep 5
  done
  if [ "$ok" -eq 1 ]; then
    for attempt in 1 2 3; do
      pixlet push --installation-id "$id" --api-token "$token" "$device" mbt_index.webp && return 0
      echo "[$id] push attempt $attempt failed"
      [ "$attempt" -lt 3 ] && sleep 5
    done
    echo "[$id] push failed after 3 attempts; device will keep previous frame"
  else
    echo "[$id] render failed after 3 attempts; skipping push"
  fi
}

for TICKER in GEHC SPCX; do
  push_ticker "$TICKER" "$TIDBYT_API_TOKEN_DESK" "$TIDBYT_DEVICE_ID_DESK"
done

push_index minds     MIND "$TIDBYT_API_TOKEN_DESK" "$TIDBYT_DEVICE_ID_DESK"
push_index bodies    BODY "$TIDBYT_API_TOKEN_DESK" "$TIDBYT_DEVICE_ID_DESK"
push_index terawatts TERA "$TIDBYT_API_TOKEN_DESK" "$TIDBYT_DEVICE_ID_DESK"
push_index mbt       MBT  "$TIDBYT_API_TOKEN_DESK" "$TIDBYT_DEVICE_ID_DESK"

