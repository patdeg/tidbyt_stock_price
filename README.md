# Tidbyt Stock Price Display with Alpaca Market API

This project displays stock prices on a Tidbyt device using data from the [Alpaca Market API](https://alpaca.markets/). The project retrieves historical stock data (over the last 7 days) and the latest trade price, displaying them graphically on a Tidbyt device.

## Introduction to Tidbyt and Pixlet

[Tidbyt](https://tidbyt.com/) is a smart display that allows you to run custom apps, showing information ranging from weather updates to stock prices. Apps for Tidbyt are created using [Pixlet](https://github.com/tidbyt/pixlet), a command-line tool that renders apps and allows you to push them to your Tidbyt device.

### Pixlet Command Line Usage

- **Render**: The `pixlet render` command takes your `.star` file and renders it to a `.webp` image.
- **Push**: The `pixlet push` command sends your rendered app to a Tidbyt device.
- **Serve**: The `pixlet serve` command runs your `.star` app locally, which is useful for development and previewing your app before pushing it to the device.

This project makes use of Pixlet to generate and push a stock price display app using stock data retrieved from the Alpaca Market API.

## Alpaca Market API

[Alpaca](https://alpaca.markets/) offers market data and trading APIs for stocks and cryptocurrencies. This project uses two key endpoints from the Alpaca API:

1. **[Stock Bars](https://docs.alpaca.markets/reference/stockbars)**:
   - This endpoint provides historical stock data aggregated into bars (open, high, low, close prices) over various timeframes.
   - In this project, we retrieve daily bars for the past 7 days to display recent stock price trends.

2. **[Stock Latest Trades](https://docs.alpaca.markets/reference/stocklatesttrades-1)**:
   - This endpoint provides the latest trade data for a given stock symbol.
   - The project retrieves the most recent trade price to display along with the historical data.

## Setup and Configuration

### Prerequisites

- A Tidbyt device
- [Pixlet CLI](https://github.com/tidbyt/pixlet) installed
- An Alpaca API account (sign up [here](https://alpaca.markets/)) and API keys (both `ALPACA_KEY` and `ALPACA_SECRET`)

### `.env` File

Create a `.env` file in the root directory to store your Alpaca API credentials:

```bash
ALPACA_KEY=your-alpaca-api-key
ALPACA_SECRET=your-alpaca-api-secret
```

### Running the Application

The project uses a `Makefile` to simplify common tasks. The following commands are available:

- **Render the app**:
  ```bash
  make stock_price.webp
  ```
  This command renders the `stock_price.star` file into a `.webp` image using Pixlet and passes the required stock symbol and API credentials from the file .env.

- **Push the app to your Tidbyt device**:
  ```bash
  make push
  ```
  This command pushes the rendered `.webp` image to your Tidbyt device.

- **List available Tidbyt devices**:
  ```bash
  make list
  ```
  This command lists your registered Tidbyt devices.

- **Serve the app locally**:
  ```bash
  make serve
  ```
  This command serves the app locally, allowing you to preview it before pushing it to a device.

## How It Works

The project retrieves stock data using the Alpaca Market API and displays it on a Tidbyt device:

1. **Stock Data**:
   - Historical daily stock bars for the last 7 days are retrieved and plotted on a graph to show the recent stock price trend.
   - The most recent trade price is retrieved and displayed alongside the stock ticker symbol.

2. **Pixlet Rendering**:
   - Pixlet renders this data into a `.webp` image, which is then pushed to your Tidbyt device.

## Example

```bash
# Render the stock price for UNH (UnitedHealth Group)
# Push the rendered stock price app to your Tidbyt device
make
```

## Resources

- [Pixlet CLI Documentation](https://github.com/tidbyt/pixlet)
- [Alpaca Market API - Stock Bars](https://docs.alpaca.markets/reference/stockbars)
- [Alpaca Market API - Stock Latest Trades](https://docs.alpaca.markets/reference/stocklatesttrades-1)
