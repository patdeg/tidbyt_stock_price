#!/bin/bash
export PATH=$PATH:/bin:/usr/bin
cd ~/patdeg/tidbyt_stock_price
date +"%Y/%m/%d %H:%M:%S"
make clean
make
