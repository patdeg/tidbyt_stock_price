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
This Tidbyt application retrieves and displays the latest stock price and historical stock data
for a given symbol using the Alpaca Market API. It fetches historical price data over 7 days and
displays the latest trade price, along with percentage changes, graphically on a Tidbyt device.

The app uses caching to avoid redundant API calls, ensuring efficient usage of the API service.
"""


# Load necessary modules
load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("encoding/json.star", "json")
load("time.star", "time")
load("schema.star", "schema")

def get_schema():
    """
    Defines the configuration schema for the application, allowing users to set
    the stock symbol, timeframe for historical data, and their Alpaca API credentials.
    """
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "symbol",
                name = "Stock Symbol",
                desc = "Enter the stock ticker symbol (e.g., AAPL)",
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

def fetch_with_retry(url, headers, retries=3):
    """
    Fetches data from the given URL with a retry mechanism.

    Args:
        url (str): The API endpoint URL.
        headers (dict): Headers to include in the HTTP request.
        retries (int): Number of retry attempts.

    Returns:
        http.Response or None: The HTTP response object, or None if all attempts fail.
    """
    for attempt in range(retries):
        res = http.get(url, headers=headers)
        if res.status_code == 200:
            return res
        else:
            print("Attempt %d: Failed to fetch data from %s (Status code: %d)" % (attempt + 1, url, res.status_code))
    print("Failed to fetch data from %s after %d attempts" % (url, retries))
    return None

def fetch_latest_price(symbol, alpaca_key, alpaca_secret):
    """
    Fetches the latest trade price for the given stock symbol using the Alpaca Market API.

    Args:
        symbol (str): The stock ticker symbol.
        alpaca_key (str): Alpaca API key.
        alpaca_secret (str): Alpaca API secret.

    Returns:
        float or None: The latest trade price, or None if an error occurs.
    """
    url = "https://data.alpaca.markets/v2/stocks/trades/latest?symbols=%s&feed=iex" % symbol
    headers = {
        'APCA-API-KEY-ID': alpaca_key,
        'APCA-API-SECRET-KEY': alpaca_secret,
        'accept': 'application/json',
    }

    res = fetch_with_retry(url, headers)
    if res == None:
        print("Error fetching latest price: No response")
        return None
    data = res.json()
    trade_info = data.get("trades", {}).get(symbol)
    if trade_info == None:
        print("No trade data found for symbol %s" % symbol)
        return None
    latest_price = float(trade_info.get("p"))    
    return latest_price

def fetch_historical_data(symbol, alpaca_key, alpaca_secret, days):
    """
    Fetches historical stock data for the given symbol and timeframe.

    Args:
        symbol (str): The stock ticker symbol.
        alpaca_key (str): Alpaca API key.
        alpaca_secret (str): Alpaca API secret.
        days (int): Number of days of historical data to fetch.

    Returns:
        list or None: A list of bar data sorted by date, or None if an error occurs.
    """
    cache_key = "data_%s_%d" % (symbol, days)
    cached_data = cache.get(cache_key)

    if cached_data != None:
        return json.decode(cached_data)

    end_time = time.now() - time.hour*24
    start_time = end_time - time.hour*24*(1+days)

    end_date = end_time.format("2006-01-02T15:04:05Z")
    start_date = start_time.format("2006-01-02T15:04:05Z")

    url = "https://data.alpaca.markets/v2/stocks/%s/bars?timeframe=1Day&start=%s&end=%s&limit=100" % (symbol, start_date, end_date)
    headers = {
        'APCA-API-KEY-ID': alpaca_key,
        'APCA-API-SECRET-KEY': alpaca_secret,
        'accept': 'application/json',
    }

    res = fetch_with_retry(url, headers)
    if res == None:
        print("Error fetching historical data: No response")
        return None
    data = res.json()
    bars = data.get("bars")
    if not bars:
        print("No historical data found for symbol %s" % symbol)
        return None
    sorted_bars = sorted(bars, key=lambda x: time.parse_time(x.get("t"), "2006-01-02T15:04:05Z"))
    # Cache the data, adjust TTL based on market hours
    now_hour = time.now().hour
    # Assume market hours are 9 AM to 4 PM Eastern Time
    if (9 <= now_hour) and (now_hour <= 16):
        ttl_seconds = 300  # 5 minutes during market hours
    else:
        ttl_seconds = 3600  # 1 hour outside market hours
    cache.set(cache_key, json.encode(sorted_bars), ttl_seconds=ttl_seconds)
    return sorted_bars

def main(config):
    """
    Main function to render the stock price application.

    Args:
        config (dict): Configuration parameters provided by the user.

    Returns:
        render.Root: The root render object for the Tidbyt app.
    """
    # Get configuration parameters
    symbol = config.get("symbol", "AAPL")    
    alpaca_key = config.get("alpaca_key")
    alpaca_secret = config.get("alpaca_secret")

    # Set timeframe    
    timeframe_days = 7

    # Ensure API keys are provided
    if alpaca_key == None or alpaca_secret == None:
        return render.Root(
            child=render.Text("Missing Alpaca API keys"),
        )

    # Fetch historical data
    bars = fetch_historical_data(symbol, alpaca_key, alpaca_secret, timeframe_days)
    if bars == None:
        return render.Root(
            child=render.Text("No data available for %s" % symbol),
        )

    # Prepare data for plotting
    data_points = []
    min_change = None
    max_change = None
    baseline_price = None

    for index, bar in enumerate(bars):        
        close_price = float(bar.get('c'))
        if baseline_price == None:
            baseline_price = close_price
        price_change = close_price - baseline_price
        data_points.append((float(index), price_change))
        if min_change == None or price_change < min_change:
            min_change = price_change
        if max_change == None or price_change > max_change:
            max_change = price_change

    # Fetch latest price
    latest_price = fetch_latest_price(symbol, alpaca_key, alpaca_secret)
    previous_close = float(bars[-1].get('c'))
    if latest_price != None:
        current_price_change = latest_price - baseline_price        
        data_points.append((float(len(bars)), current_price_change))
        if min_change == None or current_price_change < min_change:
            min_change = current_price_change
        if max_change == None or current_price_change > max_change:
            max_change = current_price_change
    
    # Calculate percentage change
    if latest_price != None:        
        price_diff = latest_price - previous_close
        percent_change = (price_diff / previous_close) * 100
        change_sign = "+" if percent_change >= 0 else "-"
        change_color = "#00FF00" if percent_change >= 0 else "#FF0000"
        display_price = latest_price
    else:
        price_diff = previous_close - baseline_price
        percent_change = (price_diff / baseline_price) * 100
        change_sign = ""
        change_color = "#FFFFFF"
        display_price = previous_close

    print("UNH:",latest_price)

    # Format percentage change with one decimal place
    percent_change_str = "%s" % abs(int(percent_change * 10) / 10)

    # Format display_price with no decimal place
    display_price_str = "%s" % int(display_price)

    # Render the app
    return render.Root(
        render.Column(
            expanded=True,
            main_align="space_around",
            cross_align="center",
            children=[
                render.Row(
                    children=[
                        render.Text("%s %s " % (symbol.upper(), display_price_str),
                            #color=change_color,
                            font="CG-pixel-4x5-mono",
                        ),                        
                        render.Text("%s%s%%" % (change_sign, percent_change_str),
                            color=change_color,
                            font="CG-pixel-3x5-mono",
                        ),
                    ],
                ),     
                render.Plot(
                    data = data_points,  # Plot the stock price change data
                    width = 64,
                    height = 20,
                    color = "#0f0",  # Green color for positive trend
                    color_inverted = "#f00",  # Red color for negative trend                    
                    fill = True,  # Fill the plot area
                ),           
            ],
        ),
    )
