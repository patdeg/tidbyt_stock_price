# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tidbyt application that displays real-time stock prices and 7-day historical trends on Tidbyt smart display devices. Uses the Alpaca Market API for stock data and the Pixlet framework for rendering.

## Build and Run Commands

```bash
make render              # Render stock app to WebP
make render SYMBOL=MSFT  # Render specific stock symbol
make push                # Render and push to all Tidbyt devices (default target)
make serve               # Local dev server at http://localhost:8080
make serve SYMBOL=TSLA   # Serve with specific symbol
make list                # List registered Tidbyt devices
make clean               # Remove generated WebP files
```

Shell scripts:
- `./refresh.sh` - Cron job script that cleans, renders, and pushes
- `./show_stock.sh` - Pushes different stocks to different Tidbyt devices

## Architecture

**stock_price.star** - Main Starlark application containing:
- `main(config)` - Entry point that orchestrates data fetching and rendering
- `get_schema()` - Defines UI configuration fields (symbol, API credentials)
- `fetch_latest_price()` - Gets current trade price from Alpaca API
- `fetch_historical_data()` - Gets 7-day daily bars with caching
- `fetch_with_retry()` - HTTP client with 3-retry mechanism

**Key Design Decisions:**
- **Market-aware caching**: 5-minute TTL during market hours (9-16), 1-hour TTL outside
- **Alpaca Data API v2**: Uses latest trade endpoint for current price, bars endpoint for history
- **IEX feed**: Latest prices sourced from IEX feed for reliability
- **Visual encoding**: Green for positive price movement, red for negative

## Environment Configuration

Requires `.env` file with:
- `ALPACA_KEY` / `ALPACA_SECRET` - Alpaca Market API credentials
- `TIDBYT_API_TOKEN_DESK` / `TIDBYT_API_TOKEN_SHELF` - Device JWT tokens
- `TIDBYT_DEVICE_ID_DECK` / `TIDBYT_DEVICE_ID_SHELF` - Device identifiers

## Technology Stack

- **Starlark**: Python-like DSL for Tidbyt apps
- **Pixlet**: CLI for rendering and deploying Tidbyt apps
- **Alpaca Market API**: Stock data provider
