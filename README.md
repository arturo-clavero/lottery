# Lottery Smart Contract

A decentralized, automated lottery contract on Ethereum (and testnets) leveraging **Chainlink VRF v2 Plus** for secure randomness and **Chainlink Automation** for fully automated winner selection. Built with safety in mind, using **ReentrancyGuard** and **SafeTransferLib**.

---

## Features

* **Secure randomness** via Chainlink VRF v2 Plus.
* **Automated winner selection** via Chainlink Automation (no manual intervention needed).
* **ETH payouts with fallback withdrawal** for failed transfers.
* **Configurable lottery parameters**: entry price, lottery duration, and grace period.
* **Supports ERC677 LINK funding** programmatically.
* **Simple entry**: users just send the correct amount of ETH.

---

## Installation

```bash
git clone <repo-url>
cd lottery
forge install
```


---

## Deployment

--> TODO

---

### Testing / Local Deploy
Set up your `.env` file with the required RPC addresses for testing on sepolia and mainnent:

```env
RPC_MAINNET=<your_rpc_url>
RPC_SEPOLIA=<your_rpc_url>
```

For testing locally, in sepolia fork and in mainnet fork:
```bash
make test
```

local testing only:
```bash
make test-local
```

sepolia testing only:
```bash
make test-sepolia
```

mainnet testing only:
```bash
make test-ethereum
```

* Foundry tests can simulate random words and automate ETH transfers.
* **Important**: cheatcodes (`vm.deal`, `vm.prank`) are only available in tests and cannot be used in production contracts.

---

## Usage

### Enter the Lottery

Send exactly the entry price in ETH:

```solidity
lottery.enterLottery{value: entryPrice}();
```

### Winner Selection

* Automatically triggered by Chainlink Automation when the lottery period ends.
* Uses **Chainlink VRF v2 Plus** for a provably fair winner.

### Withdraw Fallback

If a direct ETH transfer fails:

```solidity
lottery.winnerFallbackWithdrawal();
```

---

## Events

* `WinnerWithdrawnPrice(address indexed winner, uint256 price)` – emitted on fallback withdrawal.
* Other events are added for success/failure logging of winner payments in MockLottery for testing.

---

## Security

* **ReentrancyGuard** protects against reentrancy attacks.
* **SafeTransferLib** ensures safe ETH transfers, preventing stuck ETH in the contract.
* ETH payouts are **atomic**, and any failed payments are recoverable via fallback withdrawal.

---

## Notes on Chainlink Integration

1. **VRF v2 Plus**: provides secure randomness for winner selection.
2. **Automation**: automates upkeep without external scripts.
3. The contract can **programmatically**:

   * Create VRF subscriptions
   * Fund VRF subscriptions with LINK
   * Register with Automation registry
4. This reduces manual setup and ensures the lottery is fully autonomous once deployed.

---

## License

Unlicensed (UNLICENSED).

---
