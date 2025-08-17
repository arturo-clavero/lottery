# Makefile for Lottery project

# Default target
all: build

# Clean everything
clean:
	rm -rf lib
	rm -rf out cache
	rm -rf .forge

# Build project
build: install
	forge build

# Install dependencies only if missing
install:
	@test -d lib/forge-std || forge install foundry-rs/forge-std
	@test -d lib/chainlink-evm || forge install smartcontractkit/chainlink-evm
	@test -d lib/solady || forge install Vectorized/solady
	@test -d lib/openzeppelin-contracts || forge install openzeppelin/openzeppelin-contracts                          

.PHONY: clean lib install build all
