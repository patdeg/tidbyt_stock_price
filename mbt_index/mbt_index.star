# Copyright 2024 Patrick Deglon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Custom thematic indexes for the Tidbyt: Minds, Bodies, Terawatts, and the
combined MBT index.

Choose the index with `index=minds|bodies|terawatts|mbt`.

BASE: 100 = the close on 2025-12-18, the day the book Unscarcity was published
("day zero"). Fixed; changing it is a new version of the index. A symbol that
did not yet trade on the base date (e.g. SPCX, listed 2026-06-12) is held flat at
100 until its first bar, then rebased on that first close, so a new listing never
makes a basket jump. Membership and base mirror the public index on unscarcity.ai
(unscarcity/scripts/mbt_index_build.py); keep the two in step.

CHART: all four tiles share the same vertical SPAN (amplitude), not the same
absolute axis. Every render computes all four series (one Alpaca call, so it
costs nothing extra), takes the largest (max - min) of the change-from-base
among them, pads it 10%, and gives every tile that span, centred on the tile's
own data (y_lim). So one percentage point is the same number of pixels on every
tile and the shapes compare honestly, while each tile still shows its own
level. Do not "autoscale per tile" again: that is what made a 0.1% wiggle look
like a crash. Colour follows the sign of the change from base (green above the
base line, red below), so a tile whose window sits entirely above or below the
base is a single colour.

WEIGHTING (decided 2026-10-06): equal weight everywhere, deliberately.
  - Inside a pillar: every stock counts the same (the question the tile answers
    is "is the theme working", not "what did the biggest company do").
  - MBT: each pillar counts one third, regardless of basket size.
  Known limit: an ETF such as SMH or KOID counts as one stock, and a thin ETF
  (NUKZ) moves its pillar as much as NVDA does.
  PLANNED, NOT BUILT: market-cap weighting *inside* each pillar (the underlying
  indexes), with MBT staying equal-weight across the three pillars. Keep MBT
  equal-weight when that lands -- it is the cross-theme gauge, and cap-weighting
  it would let the largest pillar dominate. That change belongs in
  pillar_series() / latest_level() (they need a per-symbol weight, which will
  need market caps from a second data source; Alpaca bars do not carry them).
"""

load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("encoding/json.star", "json")
load("time.star", "time")
load("schema.star", "schema")

# The only place the basket membership lives. Symbols must be US exchange
# listings: Alpaca's IEX feed returns nothing for OTC ADRs.
PILLARS = {
    "minds": ["NVDA", "TSM", "ASML", "MU", "SPCX"],
    "bodies": ["KOID", "ISRG", "ROK", "TSLA", "AGLT"],
    "terawatts": ["GEV", "GRID", "CCJ", "CEG", "FSLR"],
}

# Members announced but not trading yet under their ticker: held flat at 100
# (the new-listing rule). When one starts trading, set the date of its FIRST
# close under this ticker; earlier bars are dropped, since after a SPAC merger
# the feed may carry the SPAC's history over. While "", all bars are ignored.
# Keep in step with PENDING_LISTINGS in plaid_trans/mbt-index/update.py.
PENDING_LISTINGS = {
    "AGLT": "",  # Agility Robotics, via merger with Churchill Capital Corp XI (CCXI); close expected Q4 2026
}

# Day zero: the day the book Unscarcity was published. Fixed for the life of the
# index (the same date and 15 names as the public page on unscarcity.ai).
BASE_DATE = "2025-12-18"

PILLAR_ORDER = ["minds", "bodies", "terawatts"]

# Short labels so "LABEL 103 +1.2%" fits the 64px width.
LABELS = {
    "minds": "MIND",
    "bodies": "BODY",
    "terawatts": "WATT",
    "mbt": "MBT",
}

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "index",
                name = "Index",
                desc = "minds, bodies, terawatts or mbt",
                icon = "chart-line",
            ),
            schema.Text(
                id = "alpaca_key",
                name = "Alpaca API Key",
                desc = "Your Alpaca API Key",
                icon = "key",
            ),
            schema.Text(
                id = "alpaca_secret",
                name = "Alpaca API Secret",
                desc = "Your Alpaca API Secret",
                icon = "key",
            ),
        ],
    )

def fetch_with_retry(url, headers, retries = 3):
    for attempt in range(retries):
        res = http.get(url, headers = headers)
        if res.status_code == 200:
            return res
        print("Attempt %d: failed %s (status %d)" % (attempt + 1, url, res.status_code))
    return None

def auth_headers(key, secret):
    return {
        "APCA-API-KEY-ID": key,
        "APCA-API-SECRET-KEY": secret,
        "accept": "application/json",
    }

def base_date():
    return BASE_DATE

def fetch_bars(symbols, key, secret, base):
    """Daily bars from a week before the base date to yesterday, all symbols in
    one call: {symbol: [bar, ...]} sorted by time."""
    csv = ",".join(symbols)
    cache_key = "mbt_bars_%s_%s" % (csv, base)
    cached = cache.get(cache_key)
    if cached != None:
        return json.decode(cached)

    end_time = time.now() - time.hour * 24
    # Ten days of slack so the base date's bar is found across holidays/weekends.
    start = "2025-12-08T00:00:00Z"
    # limit=10000 is Alpaca's maximum: ~8 symbols x ~250 days fits in one page.
    url = ("https://data.alpaca.markets/v2/stocks/bars?symbols=%s&timeframe=1Day&start=%s&end=%s&limit=10000" %
           (csv, start, end_time.format("2006-01-02T15:04:05Z")))
    res = fetch_with_retry(url, auth_headers(key, secret))
    if res == None:
        return None
    body = res.json()
    if body.get("next_page_token"):
        print("WARNING: bars response was paginated; later days are missing")
    bars = body.get("bars")
    if not bars:
        return None

    # time.now() is UTC; use ET so the market-hours window is right.
    now_et = time.now().in_location("America/New_York")
    ttl = 300 if (9 <= now_et.hour and now_et.hour <= 16) else 3600
    cache.set(cache_key, json.encode(bars), ttl_seconds = ttl)
    return bars

def fetch_latest(symbols, key, secret):
    """Latest trade price per symbol: {symbol: float}. Missing symbols are omitted."""
    url = "https://data.alpaca.markets/v2/stocks/trades/latest?symbols=%s&feed=iex" % ",".join(symbols)
    res = fetch_with_retry(url, auth_headers(key, secret))
    out = {}
    if res == None:
        return out
    for sym, t in res.json().get("trades", {}).items():
        if t != None and t.get("p") != None:
            out[sym] = float(t.get("p"))
    return out

def symbol_base(sym_bars, base):
    """Close on the last bar on/before the base date; if the symbol listed after
    the base date, its first close. Returns None if there are no bars."""
    if not sym_bars:
        return None
    chosen = float(sym_bars[0].get("c"))
    for b in sym_bars:
        if b.get("t")[:10] <= base:
            chosen = float(b.get("c"))
    return chosen

def pillar_series(symbols, bars, dates, base):
    """Equal-weight basket level (100 = base) for each date in `dates`, carrying
    the previous close forward over days a thin ETF did not trade. Returns None
    if no symbol has data."""
    per_symbol = []
    for sym in symbols:
        sym_bars = bars.get(sym)
        if not sym_bars:
            if sym in PENDING_LISTINGS:
                per_symbol.append([100.0 for _ in dates])
            else:
                print("no bars for %s; excluded" % sym)
            continue
        sb = symbol_base(sym_bars, base)
        by_date = {}
        for b in sym_bars:
            by_date[b.get("t")[:10]] = float(b.get("c"))
        last = sb
        line = []
        for d in dates:
            if d in by_date:
                last = by_date[d]
            line.append(last / sb * 100.0)
        per_symbol.append(line)
    if len(per_symbol) == 0:
        return None
    series = []
    for i in range(len(dates)):
        total = 0.0
        for line in per_symbol:
            total += line[i]
        series.append(total / len(per_symbol))
    return series

def latest_level(symbols, bars, latest, base):
    """Live basket level on the same base as pillar_series, or None."""
    levels = []
    for sym in symbols:
        sym_bars = bars.get(sym)
        if not sym_bars and sym in PENDING_LISTINGS:
            levels.append(100.0)
            continue
        if not sym_bars or sym not in latest:
            continue
        levels.append(latest[sym] / symbol_base(sym_bars, base) * 100.0)
    if len(levels) == 0:
        return None
    return mean(levels)

def drop_pending_bars(bars):
    """Copy of bars without the bars a pending listing must ignore."""
    out = {}
    for sym, sym_bars in bars.items():
        if sym in PENDING_LISTINGS:
            listed = PENDING_LISTINGS[sym]
            if listed == "":
                sym_bars = []
            else:
                sym_bars = [b for b in sym_bars if b.get("t")[:10] >= listed]
        out[sym] = sym_bars
    return out

def mean(xs):
    total = 0.0
    for x in xs:
        total += x
    return total / len(xs)

def message(text):
    return render.Root(child = render.Text(text))

def main(config):
    index = config.get("index", "mbt").lower()
    key = config.get("alpaca_key")
    secret = config.get("alpaca_secret")
    if key == None or secret == None:
        return message("Missing Alpaca keys")
    if index != "mbt" and index not in PILLARS:
        return message("Bad index %s" % index)

    # Always load the whole universe: the shared y-axis needs all four series.
    symbols = []
    for n in PILLAR_ORDER:
        for s in PILLARS[n]:
            if s not in symbols:
                symbols.append(s)

    base = base_date()
    bars = fetch_bars(symbols, key, secret, base)
    if bars == None:
        return message("No data %s" % LABELS[index])
    bars = drop_pending_bars(bars)

    # Trading dates from the base date forward, oldest first. The base date
    # itself (or the last trading day before it) is the first point = 100.
    seen = {}
    for sym in symbols:
        for b in bars.get(sym, []):
            seen[b.get("t")[:10]] = True
    all_dates = sorted(seen.keys())
    start_date = all_dates[0]
    for d in all_dates:
        if d <= base:
            start_date = d
    dates = [d for d in all_dates if d >= start_date]
    if len(dates) < 2:
        return message("Too little data")

    latest = fetch_latest(symbols, key, secret)

    lines = {}
    live = {}
    for n in PILLAR_ORDER:
        s = pillar_series(PILLARS[n], bars, dates, base)
        if s == None:
            return message("No data %s" % n)
        lines[n] = s
        live[n] = latest_level(PILLARS[n], bars, latest, base)

    # MBT = equal-weight mean of the three pillars.
    mbt = []
    for i in range(len(dates)):
        mbt.append(mean([lines[n][i] for n in PILLAR_ORDER]))
    lines["mbt"] = mbt
    live_parts = [live[n] for n in PILLAR_ORDER if live[n] != None]
    live["mbt"] = mean(live_parts) if len(live_parts) == len(PILLAR_ORDER) else None

    # Append today's live point where we have one. Then find each index's own
    # range (change from base) and the LARGEST range among the four: every tile
    # gets that same vertical span (same amplitude per pixel, so shapes compare)
    # but is centred on its own data (values are NOT forced onto one shared axis).
    full = {}
    lo = {}
    hi = {}
    span = 0.0
    for name in ["minds", "bodies", "terawatts", "mbt"]:
        s = list(lines[name])
        if live[name] != None:
            s.append(live[name])
        full[name] = s
        lo[name] = s[0] - 100.0
        hi[name] = s[0] - 100.0
        for v in s:
            if v - 100.0 < lo[name]:
                lo[name] = v - 100.0
            if v - 100.0 > hi[name]:
                hi[name] = v - 100.0
        if hi[name] - lo[name] > span:
            span = hi[name] - lo[name]
    span = span * 1.1
    if span < 1.0:
        span = 1.0  # percentage points; avoids a degenerate axis on a flat year
    centre = (lo[index] + hi[index]) / 2.0
    y_lim = (centre - span / 2.0, centre + span / 2.0)

    series = full[index]
    prev_close = lines[index][-1]
    if live[index] != None:
        level = live[index]
        day_pct = (level - prev_close) / prev_close * 100.0
        color = "#00FF00" if day_pct >= 0 else "#FF0000"
        sign = "+" if day_pct >= 0 else "-"
    else:
        level = prev_close
        day_pct = (prev_close - lines[index][-2]) / lines[index][-2] * 100.0
        color = "#FFFFFF"
        sign = ""

    pct_x10 = int(abs(day_pct) * 10 + 0.5)
    pct_str = "%s%d.%d%%" % (sign, pct_x10 // 10, pct_x10 % 10)

    points = []
    for i, v in enumerate(series):
        points.append((float(i), v - 100.0))

    return render.Root(
        render.Column(
            expanded = True,
            main_align = "space_around",
            cross_align = "center",
            children = [
                render.Row(
                    children = [
                        render.Text("%s %d " % (LABELS[index], int(level + 0.5)), font = "CG-pixel-4x5-mono"),
                        render.Text(pct_str, color = color, font = "CG-pixel-3x5-mono"),
                    ],
                ),
                render.Plot(
                    data = points,
                    width = 64,
                    height = 20,
                    color = "#0f0",
                    color_inverted = "#f00",
                    fill = True,
                    x_lim = (0.0, float(len(series) - 1)),
                    y_lim = y_lim,
                ),
            ],
        ),
    )
