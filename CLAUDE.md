# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tidbyt application that displays real-time stock prices and 7-day historical trends on Tidbyt smart display devices. Uses the Alpaca Market API for stock data and the Pixlet framework for rendering.

## Build and Run Commands

```bash
make render              # Render stock app to WebP
make render SYMBOL=MSFT  # Render specific stock symbol
make push                # Render and push to both configured devices (default target)
make serve               # Local dev server at http://localhost:8080
make serve SYMBOL=TSLA   # Serve with specific symbol
make list                # List registered Tidbyt devices (needs interactive pixlet auth)
make clean               # Remove generated WebP files
```

Shell scripts:
- `./refresh.sh` - Cron job script that cleans, renders, and pushes
- `./show_stock.sh` - Pushes different stocks to different Tidbyt devices

## Device Ticker Assignment

`show_stock.sh` is the single source of truth for which symbol appears on which
device. There are two devices, each with its own list:

| Device | `.env` vars | Tickers |
|--------|-------------|---------|
| Desk | `TIDBYT_API_TOKEN_DESK` + `TIDBYT_DEVICE_ID_DESK` | `GEHC NVDA ISRG GEV SPCX` |
| Shelf | `TIDBYT_API_TOKEN_SHELF` + `TIDBYT_DEVICE_ID_SHELF` | *(none — last ticker, GEHC, removed 2026-09-03)* |

Both desk variables are spelled `..._DESK`. Until 2026-08-21 the device id was
`TIDBYT_DEVICE_ID_DECK` -- a typo the scripts worked around with a
`${TIDBYT_DEVICE_ID_DESK:-${TIDBYT_DEVICE_ID_DECK:-}}` fallback. Both the
fallback and the typo are gone; `..._DECK` is no longer read anywhere.

**Each ticker is its own installation-id.** A device does not show one stock; it
cycles every pushed ticker as a separate app in its rotation, alongside whatever
else is installed (`clock`, `sunrise-sunset`, `aistatus`, `cloudstatus`). So a
longer list means each ticker is on screen proportionally less. Keep lists short.

### Adding or removing a ticker

1. Edit the relevant `for TICKER in ...` loop in `show_stock.sh`.
2. **Verify the symbol renders first** — see the data-source limit below:
   `pixlet render stock_price.star symbol=XXX alpaca_key=$ALPACA_KEY alpaca_secret=$ALPACA_SECRET`
3. **Removing a ticker requires deleting its installation.** Dropping it from the
   loop only stops updates; the installation stays on the device and freezes on
   its last frame, displaying a stale price indefinitely. Delete it explicitly:
   ```bash
   pixlet delete --api-token "$TIDBYT_API_TOKEN_SHELF" "$TIDBYT_DEVICE_ID_SHELF" TICKER
   ```
   `pixlet list --api-token ... <device-id>` shows what is actually installed.

### Data-source limit on which symbols work

`stock_price.star` reads Alpaca's **IEX feed**, which covers US exchange listings
only. OTC-traded ADRs return no data and render nothing — confirmed failing:
`SMMNY` (Siemens Healthineers), `FUJIY` (Fujifilm). NYSE-listed ADRs such as
`PHG` (Philips) work normally. Displaying an OTC symbol would require a second
data provider alongside Alpaca.

## Rotating device credentials

Replacing a Tidbyt changes **both** its device id and its API token, and the
token is scoped to the device: a new id paired with an old token returns
`404 device not found` -- indistinguishable from a simply wrong id. Confirm the
pair matches before debugging anything else. The token is a JWT whose `device`
claim must equal the id:

```bash
source .env
python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); \
  print(json.loads(base64.urlsafe_b64decode(p))['device'])" "$TIDBYT_API_TOKEN_DESK"
# must print the value of TIDBYT_DEVICE_ID_DESK
```

### Quoting: two consumers, two behaviours

`.env` is read two different ways, and only one of them strips quotes:

| Consumer | Mechanism | Strips `"` ? |
|---|---|---|
| `show_stock.sh`, `refresh.sh` | bash `source` | yes |
| `Makefile` | GNU make `include` | **no** |

So a `KEY="value"` entry reaches `make push` with the quotes still attached and
the API rejects it as `404 device not found` -- the same symptom as a wrong id,
which makes it easy to misdiagnose as a bad credential. The Makefile strips them
explicitly via the `unquote` function; leave that in place and either style
works.

### `.env` lives on three hosts and drifts

alfred is master and runs the cron. patrick and nasdaq hold dormant copies with
no crons, so nothing there fails loudly when they go stale -- on 2026-08-21
nasdaq was still pointing at a device that had already been replaced. After
rotating, sync the replica:

```bash
scp .env nasdaq:~/patdeg/tidbyt_stock_price/.env
```

**Sync code and credentials together, never credentials alone.** An out-of-date
`show_stock.sh` on a replica carries a different ticker list, so running it
re-installs tickers that were deliberately deleted from a device.

### Verify against a real cron cycle, not a manual run

Manual runs can pass while cron fails (different PATH and environment). Isolate
the most recent cycle -- a plain `tail` reaches back into pre-fix lines and will
show stale errors that are already resolved:

```bash
awk '/\[tidbyt_stock_price\].*Starting/{b=""} {b=b $0 "\n"} END{printf "%s", b}' \
  /home/pdeglon/logs/tidbyt_stock_price.log
```

Two error classes, only one of which is actionable:

- **Real:** `404`, `device not found`, `push failed after 3 attempts`.
- **Routine:** `context deadline exceeded` from Alpaca. A transient upstream
  timeout that the 3-attempt retry absorbs; the render succeeds on a later
  attempt and the push still lands. Present in healthy cycles.

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
- `TIDBYT_DEVICE_ID_DESK` / `TIDBYT_DEVICE_ID_SHELF` - Device identifiers

## Technology Stack

- **Starlark**: Python-like DSL for Tidbyt apps
- **Pixlet**: CLI for rendering and deploying Tidbyt apps
- **Alpaca Market API**: Stock data provider
