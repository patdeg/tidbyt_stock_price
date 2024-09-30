# Makefile for Tidbyt Stock Price Display with Alpaca API integration

include .env
export $(shell sed 's/=.*//' .env)

# Default values for stock symbol and timeframe
SYMBOL ?= UNH

# Render the .webp image from the stock_price.star file
render: stock_price.webp

# Render the stock_price.star app to .webp image using Pixlet
stock_price.webp: stock_price.star
	pixlet render stock_price.star symbol=$(SYMBOL) alpaca_key=$(ALPACA_KEY) alpaca_secret=$(ALPACA_SECRET)

# List all Tidbyt devices linked to your account
list:
	pixlet devices

# Push the rendered app to all registered Tidbyt devices
push: stock_price.webp
	@for target in $$(pixlet devices | awk '{print $$1}'); do \
		echo pushing to "$$target"; \
		pixlet push --installation-id $(SYMBOL) $$target stock_price.webp; \
	done

# Serve the Tidbyt app locally for development and preview
serve:
	pixlet serve stock_price.star symbol=$(SYMBOL) alpaca_key=$(ALPACA_KEY) alpaca_secret=$(ALPACA_SECRET)

# Show code of all files in the project
showcode:
	@{ \
		for f in `git ls-files` ; do \
			echo "// $$f"; \
			cat "$$f"; \
			echo; \
			echo "----------------------------------------------"; \
			echo; \
		done; \
	} | xclip -selection clipboard
	@echo "All code copied to clipboard"

# Clean up any generated files
clean:
	rm -f stock_price.webp
