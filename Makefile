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

# Default values for stock symbol and timeframe
SYMBOL ?= UNH

# By default render the stock_price.star file and deploy to all devices
all: stock_price.webp push

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
