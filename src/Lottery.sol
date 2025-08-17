// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {VRFv2PlusSubscriptionManager} from "./VRFSubscriptionManager.sol";

contract Lottery is ReentrancyGuard, AutomationCompatibleInterface, VRFv2PlusSubscriptionManager {
    uint256 private constant SUBSCRIPTION_AMOUNT = 5;
    uint256 public immutable i_entryPrice;
    uint256 public immutable i_length;
    uint256 private entryDeadline;
    uint256 private pickWinnerDeadline;
    uint256 public immutable i_gracePeriod;

    uint256 private requestId;

    address[] private players;
    mapping(address => uint256) private pending_payouts;
    mapping(uint256 => address) private s_requests;

    error Lottery__invalidPrice(uint256 amount);
    error Lottery__alreadyEnded();
    error Lottery__notOver();
    error Lottery__noWinningsToWithdraw();
    error Lottery__notEnoughPlayers();

    event WinnerPaidPrice(address indexed winner, uint256 price);
    event WinnerInvalidPayment(address indexed winner, uint256 price);
    event WinnerWithdrawnPrice(address indexed winner, uint256 price);

    constructor(
        uint256 entryPrice,
        uint256 length,
        uint256 gracePeriod,
        address link_token_contract,
        address vrfCoordinatorV2Plus,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords
    )
        VRFv2PlusSubscriptionManager(
            vrfCoordinatorV2Plus,
            link_token_contract,
            keyHash,
            callbackGasLimit,
            requestConfirmations,
            numWords
        )
    {
        i_entryPrice = entryPrice;
        i_length = length;
        i_gracePeriod = gracePeriod;
        topUpSubscription(SUBSCRIPTION_AMOUNT);
        startLottery();
    }

    function startLottery() private {
        delete players;

        uint256 cacheEntryDeadline = block.timestamp + i_length;
        pickWinnerDeadline = cacheEntryDeadline + i_gracePeriod;
        entryDeadline = cacheEntryDeadline;
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

    function isLotteryOver() public view returns (bool) {
        uint256 total_players = players.length;
        if (block.timestamp < pickWinnerDeadline || total_players < 2) {
            return false;
        }
        return true;
    }

    function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
        return (isLotteryOver(), "");
    }

    function performUpkeep(bytes calldata) external override {
        if (isLotteryOver() == false) {
            revert Lottery__notOver();
        }
        requestRandomWords();
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        uint256 playersLength = players.length;
        address winner = players[randomWords[0] % playersLength];
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

    function winnerFallbackWithdrawal() external nonReentrant {
        uint256 price = pending_payouts[msg.sender];
        if (price == 0) {
            revert Lottery__noWinningsToWithdraw();
        }

        delete pending_payouts[msg.sender];

        SafeTransferLib.safeTransferETH(payable(msg.sender), price);
        emit WinnerWithdrawnPrice(msg.sender, price);
    }

    function getEntryDeadline() external view returns (uint256) {
        return entryDeadline;
    }

    function getPickWinnerDeadline() external view returns (uint256) {
        return pickWinnerDeadline;
    }

    function getTotalPlayers() external view returns (uint256) {
        return players.length;
    }
}
