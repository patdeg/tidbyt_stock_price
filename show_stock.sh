#!/bin/bash
export PATH=$PATH:/bin:/usr/bin
cd ~/patdeg/tidbyt_stock_price
source .env
TARGET=$(pixlet devices | grep Desk | awk '{print $1}') 
#for TICKER in UNH AMZN GOOG MSFT TQQQ WANT TECL ; do
#for TICKER in UNH AMZN GOOG MSFT TQQQ WANT TECL ; do
#for TICKER in UNH GOOG WANT TQQQ SPXL ; do
#for TICKER in UNH TQQQ SPXL ; do
for TICKER in UNH `/home/pdeglon/patdeg/alpaca_trader/get_list.sh` ; do
  echo Showing $TICKER on $TARGET
  pixlet render stock_price.star symbol=$TICKER alpaca_key=$ALPACA_KEY alpaca_secret=$ALPACA_SECRET
  pixlet push --installation-id $TICKER $TARGET stock_price.webp
  sleep 5
done
TARGET=$(pixlet devices | grep -v Desk | awk '{print $1}') 
for TICKER in UNH ; do
  echo Showing $TICKER on $TARGET
  pixlet render stock_price.star symbol=$TICKER alpaca_key=$ALPACA_KEY alpaca_secret=$ALPACA_SECRET
  pixlet push --installation-id $TICKER $TARGET stock_price.webp
done

