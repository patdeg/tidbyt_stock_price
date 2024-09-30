include .env
export $(shell sed 's/=.*//' .env)

all:	stock_price.webp push
    	
stock_price.webp:	stock_price.star
	pixlet render stock_price.star symbol=UNH alpaca_key=$(ALPACA_KEY) alpaca_secret=$(ALPACA_SECRET)

list:
	pixlet devices

push:
	@for target in $$(pixlet devices | awk '{print $$1}'); do \
		echo pushing to "$$target"; \
		pixlet push --installation-id unh $$target stock_price.webp; \
	done

serve:
	pixlet serve stock_price.star 
