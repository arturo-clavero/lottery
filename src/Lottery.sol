// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Lottery is ReentrancyGuard {
    uint256 public immutable i_entryPrice;
    uint256 public immutable i_length;
    uint256 public entryDeadline;
    uint256 public pickWinnerDeadline;
    uint256 public immutable i_gracePeriod;
    address[] public players;
    mapping(address => uint256) private pending_payouts;

    error Lottery__invalidPrice(uint256 amount);
    error Lottery__alreadyEnded();
    error Lottery__notOver();
    error Lottery__noWinningsToWithdraw();
    error Lottery__notEnoughPlayers();

    event WinnerPaidPrice(address indexed winner, uint256 price);
    event WinnerInvalidPayment(address indexed winner, uint256 price);
    event WinnerWithdrawnPrice(address indexed winner, uint256 price);
    event NewLotteryStarted();

    constructor(uint256 entryPrice, uint256 length, uint256 gracePeriod) {
        i_entryPrice = entryPrice;
        i_length = length;
        i_gracePeriod = gracePeriod;
        startLottery();
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

    function payWinner() external nonReentrant {
        if (isLotteryOver() == false) {
            revert Lottery__notOver();
        }
        // address winner;
        address winner = get_winner_address();
        uint256 price = players.length * i_entryPrice;
        //is this a safe way to calculate price ?
        startLottery();

        (bool success,) = payable(winner).call{value: price}("");
        if (!success) {
            pending_payouts[winner] += price;
            emit WinnerInvalidPayment(winner, price);
        } else {
            emit WinnerPaidPrice(winner, price);
        }
    }

    function winnerFallbackWithdrawal() external nonReentrant {
        uint256 price = pending_payouts[msg.sender];
        if (price == 0) {
            revert Lottery__noWinningsToWithdraw();
        }

        //check which is cheaper in gas opt
        // pending_payouts[msg.sender] = 0;
        delete pending_payouts[msg.sender];

        SafeTransferLib.safeTransferETH(payable(msg.sender), price);
        emit WinnerWithdrawnPrice(msg.sender, price);
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
        players = new address[](0);
        //check is delete players cheaper....

        entryDeadline = block.timestamp + i_length;
        pickWinnerDeadline = entryDeadline + i_gracePeriod;
        emit NewLotteryStarted();
    }

    function get_winner_address() public view returns (address) {
        if (players.length < 2) {
            revert Lottery__notEnoughPlayers();
        }
        return players[getRandomNumber() % players.length];
    }

    function getRandomNumber() private pure returns (uint256) {
        return 5;
    }

    function getTotalPlayers() external view returns (uint256) {
        return players.length;
    }

}
