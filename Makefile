# Makefile for Lottery project

# load .env variables:
include .env
export $(shell sed 's/=.*//' .env)

# Default target
all: build test

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

anvil:
	@anvil_pid=$$(lsof -ti:8545); \
	if [ -z "$$anvil_pid" ]; then \
		echo "No Anvil detected on port 8545. Starting Anvil..."; \
		anvil -p 8545 & \
		anvil_pid=$$!; \
		sleep 2; \
	else \
		echo "Anvil already running (PID $$anvil_pid)"; \
	fi

# Run all tests
test-nv: test-local-nv test-sepolia test-ethereum

test: test-local test-sepolia test-ethereum

# Local test (no verbosity unless VERBOSE is set)
test-local-nv:
	@echo "Running local tests..."
	@$(MAKE) _run-local FORGE_ARGS="$(ARGS)"

# Local test (always with high verbosity)
test-local:
	@echo "Running local tests (verbose)..."
	@$(MAKE) _run-local FORGE_ARGS="$(ARGS) -vvvv"

# Shared local runner
_run-local:
	@anvil_pid=$$(lsof -ti:8545); \
	if [ -z "$$anvil_pid" ]; then \
		echo "No Anvil detected on port 8545. Starting Anvil..."; \
		anvil -p 8545 & \
		anvil_pid=$$!; \
		sleep 2; \
		kill_anvil=true; \
	else \
		echo "Anvil already running (PID $$anvil_pid)"; \
		kill_anvil=false; \
	fi; \
	forge test --fork-url http://127.0.0.1:8545 $(FORGE_ARGS); \
	if [ "$$kill_anvil" = true ]; then \
		echo "Stopping Anvil..."; \
		kill $$anvil_pid; \
	fi

# Sepolia fork test
test-sepolia:
ifeq ($(RPC_SEPOLIA),)
	@echo "⚠️ RPC_SEPOLIA not set! Skipping Sepolia fork tests."
else
	@echo "Testing on Sepolia fork..."
	forge test --fork-url ${RPC_SEPOLIA} $(ARGS) -vvvv
endif

# Ethereum fork test
test-ethereum:
ifeq ($(RPC_MAINNET),)
	@echo "⚠️ RPC_MAINNET not set! Skipping Ethereum fork tests."
else
	@echo "Testing on Ethereum fork..."
	forge test --fork-url ${RPC_MAINNET} $(ARGS) -vvvv
endif


.PHONY: clean lib install build all
