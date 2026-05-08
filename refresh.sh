#!/bin/bash
set -e
export PATH=$HOME/.local/bin:$PATH:/bin:/usr/bin
cd ~/patdeg/tidbyt_stock_price

# Keep-1 log rotation. Path must match the cron redirect target.
# Truncate-in-place preserves cron's open fd (O_APPEND writes resume at offset 0).
LOG=/home/pdeglon/logs/tidbyt_stock_price.log
MAX_BYTES=$((10 * 1024 * 1024))
if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG")" -gt "$MAX_BYTES" ]; then
  cp "$LOG" "$LOG.1" && : > "$LOG"
fi

echo "[tidbyt_stock_price] $(date '+%Y/%m/%d %H:%M:%S') Starting"
echo "--------------------------------------------------"

make clean
./show_stock.sh

echo "[tidbyt_stock_price] $(date '+%Y/%m/%d %H:%M:%S') Done"
