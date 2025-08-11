// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract Lottery is ReentrancyGuard, AutomationCompatibleInterface {
    uint256 public immutable i_entryPrice;
    uint256 public immutable i_length;
    uint256 private entryDeadline;
    uint256 private pickWinnerDeadline;
    uint256 public immutable i_gracePeriod;
    address[] private players;
    mapping(address => uint256) private pending_payouts;

    error Lottery__invalidPrice(uint256 amount);
    error Lottery__alreadyEnded();
    error Lottery__notOver();
    error Lottery__noWinningsToWithdraw();
    error Lottery__notEnoughPlayers();

    event WinnerPaidPrice(address indexed winner, uint256 price);
    event WinnerInvalidPayment(address indexed winner, uint256 price);
    event WinnerWithdrawnPrice(address indexed winner, uint256 price);

    constructor(uint256 entryPrice, uint256 length, uint256 gracePeriod) {
        i_entryPrice = entryPrice;
        i_length = length;
        i_gracePeriod = gracePeriod;
        startLottery();
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = isLotteryOver();
    }

    function performUpkeep(bytes calldata) external override {
        payWinner();
    }

    function getEntryDeadline() external view returns (uint256) {
        return entryDeadline;
    }

    function getPickWinnerDeadline() external view returns (uint256) {
        return pickWinnerDeadline;
    }

    function enterLottery() external payable {
        if (msg.value != i_entryPrice) {
            revert Lottery__invalidPrice(msg.value);
        }
        if (block.timestamp >= entryDeadline) {
            revert Lottery__alreadyEnded();
        }
        players.push(msg.sender);
    }

    function winnerFallbackWithdrawal() external nonReentrant {
        uint256 price = pending_payouts[msg.sender];
        if (price == 0) {
            revert Lottery__noWinningsToWithdraw();
        }

        delete pending_payouts[msg.sender];

        SafeTransferLib.safeTransferETH(payable(msg.sender), price);
        emit WinnerWithdrawnPrice(msg.sender, price);
    }

    function payWinner() public nonReentrant {
        if (isLotteryOver() == false) {
            revert Lottery__notOver();
        }
        uint256 playersLength = players.length;
        address winner = get_winner_address(playersLength);
        uint256 price = playersLength * i_entryPrice;
        startLottery();

        (bool success,) = payable(winner).call{value: price}("");
        if (!success) {
            pending_payouts[winner] += price;
            emit WinnerInvalidPayment(winner, price);
        } else {
            emit WinnerPaidPrice(winner, price);
        }
    }

    function isLotteryOver() public view returns (bool) {
        uint256 total_players = players.length;
        if (block.timestamp < pickWinnerDeadline || total_players < 2) {
            return false;
        }
        //add to calldata get_winner_index(); or get_winner_Address();
        // payWinner(get_winner_address());
        return true;
    }

    function startLottery() private {
        delete players;

        uint256 cacheEntryDeadline = block.timestamp + i_length;
        pickWinnerDeadline = cacheEntryDeadline + i_gracePeriod;
        entryDeadline = cacheEntryDeadline;
    }

    function get_winner_address(uint256 playersLength) public view returns (address) {
        if (playersLength < 2) {
            revert Lottery__notEnoughPlayers();
        }
        return players[getRandomNumber() % playersLength];
    }

    function getRandomNumber() private pure returns (uint256) {
        return 5;
    }

    function getTotalPlayers() external view returns (uint256) {
        return players.length;
    }
}
