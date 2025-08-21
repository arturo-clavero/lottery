# Lottery Smart Contract

> All contracts are fully **unit tested**, **fuzz tested**, and **gas-optimized**. Reports available in `gas-optimizations/`.

A decentralized, automated lottery contract on Ethereum (and testnets) leveraging **Chainlink VRF v2 Plus** for secure randomness and **Chainlink Automation** for fully automated winner selection. Built with safety in mind, using **ReentrancyGuard** and **SafeTransferLib**.

---

## Features

* **Secure randomness** via Chainlink VRF v2 Plus.
* **Automated winner selection** via Chainlink Automation (no manual intervention).
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

## Deploy Live

### Prerequisites

* Forge/Foundry installed
* ETH for gas and LINK tokens for funding
* `.env` with deployer private key

### Deployment Steps

1. **Deploy Lottery and store its config**

```bash
forge script script/LotteryDeploy.s.sol:LotteryDeploy --rpc-url <NETWORK_RPC_URL> --private-key $PRIVATE_KEY --broadcast
```

2. **Deploy Register**

```solidity
deployRegister(lotteryAddress)
```

*Returns the Register address.*

3. **Fund Register**
   *Send at least `MIN_LINK_AMOUNT` of LINK to the Register address.*

4. **Register the Lottery with Chainlink Automation**

```solidity
setRegisterAfterFunding(lotteryAddress)
```

5. **Fund and Start Lottery**

```solidity
fundAndStartLottery(lotteryAddress)
```

*Approves LINK and starts the Lottery. Must be called by the deployer.*

> ⚠️ Follow steps in order: deploy Lottery → deploy Register → fund Register → initialize Register → fund & start Lottery.

---

## Testing / Local Deploy

Set up your `.env` with the required RPC addresses:

```env
RPC_MAINNET=<your_rpc_url>
RPC_SEPOLIA=<your_rpc_url>
```

Run tests:

```bash
make test          # all networks
make test-local    # local only
make test-sepolia  # Sepolia fork only
make test-ethereum # Mainnet fork only
```

* Foundry tests simulate random words and automate ETH transfers.
* **Cheatcodes** (`vm.deal`, `vm.prank`) are only available in tests, not in production.

---

## Usage

### Enter the Lottery

```solidity
lottery.enterLottery{value: entryPrice}();
```

### Winner Selection

* Triggered automatically by Chainlink Automation when the lottery period ends.
* Uses **Chainlink VRF v2 Plus** for a provably fair winner.

### Withdraw Fallback

```solidity
lottery.winnerFallbackWithdrawal();
```

*Use if a direct ETH transfer fails.*

---

## Events

* `WinnerWithdrawnPrice(address indexed winner, uint256 price)` – emitted on fallback withdrawal.
* Additional events for logging winner payments in MockLottery tests.

---

## Security

* **ReentrancyGuard** protects against reentrancy attacks.
* **SafeTransferLib** ensures safe ETH transfers, preventing stuck ETH in the contract.
* ETH payouts are **atomic**, and failed payments can be recovered via fallback withdrawal.

---

## Notes on Chainlink Integration

1. **VRF v2 Plus**: provides secure randomness for winner selection.
2. **Automation**: automates upkeep without external scripts.
3. Programmatically, the contract can:

   * Create VRF subscriptions
   * Fund VRF subscriptions with LINK
   * Register with Automation registry
4. Reduces manual setup and ensures the lottery is fully autonomous once deployed.

---

## License

Unlicensed (UNLICENSED).

---
