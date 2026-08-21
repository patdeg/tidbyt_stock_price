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

# Makefile for Tidbyt Stock Price Display with Alpaca API integration

include .env
export $(shell sed 's/=.*//' .env)

# GNU make's `include` does not strip quotes the way bash's `source` does. A
# .env written as KEY="value" therefore reaches pixlet with the quotes still
# attached, and the API rejects it as an unknown device (404) -- the same
# symptom as a genuinely wrong device id. Strip them so `make push` behaves
# like show_stock.sh regardless of how the .env was written.
unquote = $(patsubst "%",%,$(1))

ALPACA_KEY             := $(call unquote,$(ALPACA_KEY))
ALPACA_SECRET          := $(call unquote,$(ALPACA_SECRET))
TIDBYT_API_TOKEN_DESK  := $(call unquote,$(TIDBYT_API_TOKEN_DESK))
TIDBYT_DEVICE_ID_DESK  := $(call unquote,$(TIDBYT_DEVICE_ID_DESK))
TIDBYT_API_TOKEN_SHELF := $(call unquote,$(TIDBYT_API_TOKEN_SHELF))
TIDBYT_DEVICE_ID_SHELF := $(call unquote,$(TIDBYT_DEVICE_ID_SHELF))

# Default values for stock symbol and timeframe
SYMBOL ?= GEHC

# By default render the stock_price.star file and deploy to all devices
default: push

# Render the .webp image from the stock_price.star file
render: stock_price.webp

# Render the stock_price.star app to .webp image using Pixlet
stock_price.webp: stock_price.star
	pixlet render stock_price.star symbol=$(SYMBOL) alpaca_key=$(ALPACA_KEY) alpaca_secret=$(ALPACA_SECRET)

# List all Tidbyt devices linked to your account
list:
	@pixlet devices

# Push the rendered app to all registered Tidbyt devices
push: stock_price.webp
	@echo "pushing to DESK ($(TIDBYT_DEVICE_ID_DESK))"
	@pixlet push --api-token $(TIDBYT_API_TOKEN_DESK) --installation-id $(SYMBOL) $(TIDBYT_DEVICE_ID_DESK) stock_price.webp
	@echo "pushing to SHELF ($(TIDBYT_DEVICE_ID_SHELF))"
	@pixlet push --api-token $(TIDBYT_API_TOKEN_SHELF) --installation-id $(SYMBOL) $(TIDBYT_DEVICE_ID_SHELF) stock_price.webp

# Serve the Tidbyt app locally for development and preview
serve:
	@pixlet serve stock_price.star symbol=$(SYMBOL) alpaca_key=$(ALPACA_KEY) alpaca_secret=$(ALPACA_SECRET)

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
	@rm -f stock_price.webp
