
# Tidbyt Stock Price Display with Alpaca Market API

This project displays stock prices on a Tidbyt device using data from the [Alpaca Market API](https://alpaca.markets/). It retrieves historical stock data over a configurable number of days and displays the latest trade price, along with percentage changes, graphically on a Tidbyt device.

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup and Configuration](#setup-and-configuration)
  - [Clone the Repository](#clone-the-repository)
  - [Install Pixlet](#install-pixlet)
  - [Alpaca API Keys](#alpaca-api-keys)
  - [Environment Variables](#environment-variables)
- [Usage](#usage)
  - [Rendering the App](#rendering-the-app)
  - [Pushing to Tidbyt](#pushing-to-tidbyt)
  - [Serving Locally](#serving-locally)
- [Makefile Commands](#makefile-commands)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Dependencies](#dependencies)
- [Acknowledgments](#acknowledgments)
- [License](#license)

## Introduction

[Tidbyt](https://tidbyt.com/) is a smart display that allows you to run custom apps, showing information ranging from weather updates to stock prices. This project uses [Pixlet](https://github.com/tidbyt/pixlet), a command-line tool for developing Tidbyt apps, to display stock price information retrieved from the Alpaca Market API.

## Features

- Displays the latest stock price and percentage change.
- Shows a graph of historical stock data over a configurable timeframe.
- Color-coded indicators for price movements (green for positive, red for negative).
- Configurable stock symbol and timeframe.
- Caching mechanism to reduce redundant API calls.

## Prerequisites

- A Tidbyt device.
- [Pixlet CLI](https://github.com/tidbyt/pixlet) installed (version 0.14.0 or later recommended).
- An Alpaca API account (sign up [here](https://alpaca.markets/)) and API keys (`ALPACA_KEY` and `ALPACA_SECRET`).

## Setup and Configuration

### Clone the Repository

```bash
git clone https://github.com/yourusername/tidbyt-stock-price.git
cd tidbyt-stock-price
```

### Install Pixlet

Follow the installation instructions for Pixlet [here](https://github.com/tidbyt/pixlet#installation).

### Alpaca API Keys

1. Sign up for an account at [Alpaca Markets](https://alpaca.markets/).
2. Generate your API keys (`ALPACA_KEY` and `ALPACA_SECRET`).

### Environment Variables

Create a `.env` file in the root directory to store your Alpaca API credentials:

```bash
ALPACA_KEY=your-alpaca-api-key
ALPACA_SECRET=your-alpaca-api-secret
```

**Important**: Ensure your `.env` file is included in `.gitignore` to prevent accidental commits of sensitive information.

## Usage

### Rendering the App

To render the app with default settings:

```bash
make render
```

To specify a different stock symbol or timeframe:

```bash
make render SYMBOL=MSFT TIMEFRAME=14
```

### Pushing to Tidbyt

```bash
make push
```

This command will push the rendered app to all registered Tidbyt devices.

### Serving Locally

To serve the app locally for development and preview:

```bash
make serve
```

You can specify custom settings:

```bash
make serve SYMBOL=GOOGL TIMEFRAME=30
```

Visit `http://localhost:8080` in your browser to view the app.

## Makefile Commands

- **Render the App**:

  ```bash
  make render
  ```
  This command renders the `stock_price.star` file into a `.webp` image using Pixlet and passes the required API credentials and stock symbol.

  ```bash
  make push
  ```

- **Serve Locally**:

  ```bash
  make serve
  ```

- **List Devices**:

  ```bash
  make list
  ```

## Customization

You can customize the stock symbol and timeframe by setting the `SYMBOL` and `TIMEFRAME` variables when running `make` commands.

```bash
# Render the stock price for UNH (UnitedHealth Group)
make stock_price.webp

# Push the rendered stock price app to your Tidbyt device
make push
```

## Resources

- [Pixlet CLI Documentation](https://github.com/tidbyt/pixlet)
- [Alpaca Market API - Stock Bars](https://docs.alpaca.markets/reference/stockbars)
- [Alpaca Market API - Stock Latest Trades](https://docs.alpaca.markets/reference/stocklatesttrades-1)
