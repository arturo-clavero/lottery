# Gas Optimization & Test Results Report — *Lottery.sol*

**Date:** 2025-08-11
**Testing Tool:** Foundry `forge test --gas-report`
**Context:**

* Tested with \~10 players entering lottery
* Key functions tested: `enterLottery()`, `winnerFallbackWithdrawal()`, `startLottery()`, `payWinner()`, etc.
* Scenarios cover revert logic combinations, private attribute usage, event emission impact, and dynamic vs fixed-size arrays

---

## 1. Resetting Mapping Value in `winnerFallbackWithdrawal()`

| Version | Code                                  | Avg Gas | Difference | Notes                                   |
| ------- | ------------------------------------- | ------- | ---------- | --------------------------------------- |
| **V1**  | `delete pending_payouts[msg.sender];` | 31,081  | —          | Slightly cheaper and clearer            |
| **V2**  | `pending_payouts[msg.sender] = 0;`    | 31,083  | +2 gas     | Functionally same but slightly costlier |

**Conclusion:** Prefer `delete` for resetting mappings due to minor gas savings and better readability.

---

## 2. Clearing Players Array in `startLottery()`

| Version | Code                      | Avg Gas     | Difference | Notes                                    |
| ------- | ------------------------- | ----------- | ---------- | ---------------------------------------- |
| **V1**  | `players = new address ;` | 364,624     | —          | Creates new empty array (more expensive) |
| **V2**  | `delete players;`         | **364,530** | -94 gas    | Clears array in place, slightly cheaper  |

**Conclusion:** Using `delete players;` is a more gas-efficient and clear approach for clearing dynamic arrays.

---

## 3. Caching State Variables to Avoid Multiple SLOADs (Cases 2–4)

| Case  | Change                                                                                  | Avg Gas (startLotteryValues) | Difference | Notes                                        |
| ----- | --------------------------------------------------------------------------------------- | ---------------------------- | ---------- | -------------------------------------------- |
| **2** | Cache `entryDeadline` in a local variable in `startLottery()`                           | \~364,478                    | \~-52 gas  | Reduces redundant storage reads              |
| **3** | Cache `players.length` in `get_winner_address()`                                        | \~364,420                    | \~-58 gas  | Avoid repeated array length reads            |
| **4** | Cache `players.length` in `payWinner()` and pass as parameter to `get_winner_address()` | \~364,418                    | \~-2 gas   | Minor additional saving, improves modularity |

**Conclusion:**
Caching frequently-read state variables in memory or passing them as parameters reduces expensive SLOAD operations, leading to consistent gas savings across calls.

---

## 4. Combined Reverts in `enterLottery()` — Case 5

* **Test Result:** 15 passed, 1 failed (`testEnterLotteryAtDeadline()` failed due to revert error mismatch: expected `Lottery__alreadyEnded()` but got `Lottery__invalidPrice(1)`).
* **Gas:** Average `enterLottery()` cost \~54,935 gas
* **Deployment Size:** 3,868 bytes

**Notes:**
Combining revert conditions without careful ordering can cause revert error conflicts. Explicit separation or prioritization of revert checks is recommended for reliable error handling.

---

## 5. Private Attributes Usage — Case 6

* **Test Result:** All 16 tests passed successfully.
* **Gas:** Average `enterLottery()` \~54,900 gas
* **Deployment Size:** 3,788 bytes (slightly smaller than Case 5)

**Notes:**
Using private state variables improves encapsulation and results in minor gas and deployment size improvements.

---

## 6. Omitting Meaningless Event Emissions — Case 7

* Removed event emission in `startLottery()`.
* All tests passed (16/16).
* Deployment size decreased to 3,700 bytes.
* `enterLottery()` gas cost stable.

**Recommendation:** Omit events that do not provide meaningful value to listeners to save gas and reduce contract bytecode size.

---

## 7. Dynamic vs Fixed-Size Arrays — Case 8

* All tests passed (16/16).
* Deployment size increased from \~3,700 bytes (dynamic) to 3,968 bytes (fixed-size).
* Average `enterLottery()` gas increased slightly to \~55,048 gas compared to dynamic array versions.

**Observation:** Fixed-size arrays noticeably increase deployment size and gas costs with no evident benefit in this context. The dynamic array version is generally preferable for this contract.

---

# **Summary & Recommendations**

| Optimization Aspect     | Recommendation                                         | Notes                                                                               |
| ----------------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| Resetting mappings      | Use `delete` keyword                                   | Small gas savings, clearer intent                                                   |
| Clearing dynamic arrays | Use `delete array;` instead of new instance            | Cheaper and clearer                                                                 |
| SLOAD optimization      | Cache state vars locally or pass as parameters         | Reduces expensive storage reads, saves gas                                          |
| Revert logic            | Separate and order revert conditions carefully         | Avoid conflicting error messages                                                    |
| Private variables       | Use private visibility                                 | Minor gas & size improvement, better encapsulation                                  |
| Event emissions         | Remove meaningless events                              | Saves gas and reduces bytecode size                                                 |
| Array sizing            | Prefer dynamic arrays over fixed-size in this contract | Fixed-size arrays increase gas and deployment size noticeably without clear benefit |

---
