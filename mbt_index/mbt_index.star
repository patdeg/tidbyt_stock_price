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

Each pillar is an equal-weight basket rebased to 100 at the start of the window.
MBT is the equal-weight average of the three pillars (so a 2-stock pillar and a
3-stock pillar count the same). One multi-symbol Alpaca call feeds a whole
basket, so a render makes two HTTP requests regardless of basket size.

Choose the index with `index=minds|bodies|terawatts|mbt`.
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
    "minds": ["SMH", "NVDA", "TSM"],
    "bodies": ["KOID", "ISRG"],
    "terawatts": ["VRT", "GEV", "NUKZ"],
}

# Short labels so "LABEL 103 +1.2%" fits the 64px width.
LABELS = {
    "minds": "MIND",
    "bodies": "BODY",
    "terawatts": "TERA",
    "mbt": "MBT",
}

DAYS = 7

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

def fetch_bars(symbols, key, secret):
    """Daily bars for all symbols in one call: {symbol: [bar, ...]} sorted by time."""
    csv = ",".join(symbols)
    cache_key = "mbt_bars_%s_%d" % (csv, DAYS)
    cached = cache.get(cache_key)
    if cached != None:
        return json.decode(cached)

    end_time = time.now() - time.hour * 24
    start_time = end_time - time.hour * 24 * (1 + DAYS)
    url = ("https://data.alpaca.markets/v2/stocks/bars?symbols=%s&timeframe=1Day&start=%s&end=%s&limit=1000" %
           (csv, start_time.format("2006-01-02T15:04:05Z"), end_time.format("2006-01-02T15:04:05Z")))
    res = fetch_with_retry(url, auth_headers(key, secret))
    if res == None:
        return None
    bars = res.json().get("bars")
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

def pillar_series(symbols, bars, dates):
    """Equal-weight basket rebased to 100 on dates[0], carrying prior closes
    forward over days a thin ETF did not trade. Returns a list aligned to dates,
    or None if no symbol has data."""
    per_symbol = []
    for sym in symbols:
        sym_bars = bars.get(sym)
        if not sym_bars:
            print("no bars for %s; excluded" % sym)
            continue
        by_date = {}
        for b in sym_bars:
            by_date[b.get("t")[:10]] = float(b.get("c"))
        first = float(sym_bars[0].get("c"))
        last = first
        line = []
        for d in dates:
            if d in by_date:
                last = by_date[d]
            line.append(last / first * 100.0)
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

def latest_level(symbols, bars, latest):
    """Today's live basket level on the same base as pillar_series, or None."""
    levels = []
    for sym in symbols:
        sym_bars = bars.get(sym)
        if not sym_bars or sym not in latest:
            continue
        levels.append(latest[sym] / float(sym_bars[0].get("c")) * 100.0)
    if len(levels) == 0:
        return None
    return mean(levels)

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

    names = ["minds", "bodies", "terawatts"] if index == "mbt" else [index]
    symbols = []
    for n in names:
        for s in PILLARS[n]:
            if s not in symbols:
                symbols.append(s)

    bars = fetch_bars(symbols, key, secret)
    if bars == None:
        return message("No data %s" % LABELS[index])

    # Union of trading dates across the whole basket, oldest first.
    seen = {}
    for sym in symbols:
        for b in bars.get(sym, []):
            seen[b.get("t")[:10]] = True
    dates = sorted(seen.keys())
    if len(dates) < 2:
        return message("Too little data")

    latest = fetch_latest(symbols, key, secret)

    pillar_lines = {}
    pillar_now = {}
    for n in names:
        s = pillar_series(PILLARS[n], bars, dates)
        if s == None:
            return message("No data %s" % n)
        pillar_lines[n] = s
        pillar_now[n] = latest_level(PILLARS[n], bars, latest)

    # MBT = equal-weight mean of the pillar levels; a pillar alone is itself.
    series = []
    for i in range(len(dates)):
        total = 0.0
        for n in names:
            total += pillar_lines[n][i]
        series.append(total / len(names))

    live = None
    live_parts = [pillar_now[n] for n in names if pillar_now[n] != None]
    if len(live_parts) == len(names):
        live = mean(live_parts)

    prev_close = series[-1]
    if live != None:
        series.append(live)
        level = live
        day_pct = (live - prev_close) / prev_close * 100.0
        color = "#00FF00" if day_pct >= 0 else "#FF0000"
        sign = "+" if day_pct >= 0 else "-"
    else:
        level = prev_close
        day_pct = (prev_close - series[-2]) / series[-2] * 100.0
        color = "#FFFFFF"
        sign = ""

    pct_x10 = int(abs(day_pct) * 10 + 0.5)
    pct_str = "%s%d.%d%%" % (sign, pct_x10 // 10, pct_x10 % 10)

    points = []
    for i, v in enumerate(series):
        points.append((float(i), v - series[0]))

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
                ),
            ],
        ),
    )
