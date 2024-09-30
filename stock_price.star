"""
This Tidbyt application retrieves and displays the latest stock price and historical stock data
for a given symbol using the Alpaca API. It fetches historical price data for the last 7 days,
calculates the relative change, and plots a graph representing the stock's price trend. The app
also displays the latest trade price and updates it if it deviates from the historical data.

The app uses caching to avoid redundant API calls, ensuring efficient usage of the API service.
"""

# Load necessary modules for rendering, HTTP requests, caching, JSON handling, time parsing, and schema creation
load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("encoding/json.star", "json")
load("time.star", "time")
load("schema.star", "schema")

# Define the schema for configuring the app, including symbol, Alpaca key, and secret
def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "symbol",
                name = "Symbol",
                desc = "Stock Ticker",
                icon = "money-bill",
            ),     
            schema.Text(
                id = "alpaca_key",
                name = "Alpaca Key",
                desc = "Alpaca Key",
                icon = "key",
            ),
            schema.Text(
                id = "alpaca_secret",
                name = "Alpaca Secret",
                desc = "Alpaca Secret",
                icon = "key",
            ),
        ],
    )

# Fetch the latest trade price for a given stock symbol using Alpaca API
def get_price(symbol, alpaca_key, alpaca_secret):
    url = "https://data.alpaca.markets/v2/stocks/trades/latest?symbols=%s&feed=iex" % (symbol)
    res = http.get(url, headers = {
          'APCA-API-KEY-ID': alpaca_key,
          'APCA-API-SECRET-KEY': alpaca_secret,
          'accept': 'application/json',
        })
    
    # Check if the request was successful, otherwise fail with an error message
    if res.status_code != 200:
        fail("GET %s failed with status %d: %s", url, res.status_code, res.body())
        return None

    # Return the latest trade price for the requested symbol
    return res.json().get("trades").get(symbol).get("p")

# Fetch historical stock data (last 7 days) from Alpaca API
def get_data(symbol, alpaca_key, alpaca_secret):
    data = cache.get("data")  # Check if the data is already cached

    if data == None:  # If data is not cached, fetch it from the API
        # Calculate the current date and 7 days ago in RFC-3339 format
        end_date = time.now().format("2006-01-02T15:04:05Z")
        start_date = (time.now() - time.hour * 24 * 7).format("2006-01-02T15:04:05Z")
        
        # URL for fetching historical bars (1-day intervals) for the given symbol
        url = "https://data.alpaca.markets/v2/stocks/%s/bars?timeframe=1Day&start=%s&end=%s&limit=100" % (symbol, start_date, end_date)
        res = http.get(url, headers = {
            'APCA-API-KEY-ID': alpaca_key,
            'APCA-API-SECRET-KEY': alpaca_secret,
            'accept': 'application/json',
        })
        
        # Check if the request was successful, otherwise fail with an error message
        if res.status_code != 200:
            fail("GET %s failed with status %d: %s", url, res.status_code, res.body())
            return None
        
        resJson = res.json()

        # If no bars data is found, log and fail the process
        if resJson.get("bars") == None or len(resJson.get("bars")) == 0:
            print("No bars found in the response:", resJson)
            fail("No data")
        
        # Sort the bars by date in ascending order (oldest to most recent)
        sorted_bars = sorted(resJson.get("bars"), key=lambda x: time.parse_time(x.get("t"), "2006-01-02T15:04:05Z"))

        # Cache the sorted bars data for 1 hour to avoid redundant API calls
        cache.set("data", json.encode(sorted_bars), ttl_seconds=3600)

    else:  # Use the cached data if available
        sorted_bars = json.decode(data)
        
    return sorted_bars

# Main function to render the app and plot the stock price changes
def main(config):
    # Get Ticker symbol from the configuration or default to "UNH"
    symbol = config.get("symbol", "UNH")

    # Alpaca API Key and Secret from the configuration
    alpaca_key = config.get("alpaca_key")
    alpaca_secret = config.get("alpaca_secret")

    # Fetch the historical data using Alpaca API
    bars = get_data(symbol, alpaca_key, alpaca_secret)

    # Prepare lists for plotting stock price data
    data = []        
    x = 0
    ymin = 999
    ymax = -999
    x0 = -999
    
    # Loop through each bar to collect the closing price and calculate the change
    for bar in bars: 
        close = float(bar.get('c'))  # Get the closing price
        if x0 == -999:
            x0 = close  # Set the baseline price
        value = close - x0  # Calculate the relative price change
        data.append((float(x), value))  # Append data for plotting
        if value < ymin:
            ymin = value  # Track the minimum value for y-axis
        if value > ymax:
            ymax = value  # Track the maximum value for y-axis
        x += 1

    # Fetch the current price from the Alpaca API
    current_price = get_price(symbol, alpaca_key, alpaca_secret)
    
    # If there's a significant difference between the last recorded price and the current price
    if abs(close - current_price) > 0.05:
        value = current_price - x0  # Calculate the relative change with the current price
        if value < ymin:
            ymin = value
        if value > ymax:
            ymax = value        
        data.append((float(x), value))  # Append the current price to the data
        x += 1

    # Render the data as a plot on Tidbyt
    return render.Root(
        child = render.Column(
            children=[
                render.Row(
                    children = [                         
                        render.Text(symbol + " " + str(current_price)),  # Display the symbol and current price
                    ],
                ),
                render.Row(
                    expanded=True,  # Expand to use full horizontal space
                    main_align="space_evenly",  # Distribute space evenly between elements
                    cross_align="center",  # Center vertically
                    children = [
                        render.Plot(
                            data = data,  # Plot the stock price change data
                            width = 64,
                            height = 24,
                            color = "#0f0",  # Green color for positive trend
                            color_inverted = "#f00",  # Red color for negative trend
                            x_lim = (0, x-1),  # Set x-axis limits
                            y_lim = (ymin, ymax),  # Set y-axis limits
                            fill = True,  # Fill the plot area
                        ),
                    ],
                ),
            ],
        ),
    )
