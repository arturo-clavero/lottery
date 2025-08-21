// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Lottery} from "../../src/Lottery.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {LotteryConstants} from "../../src/lib/LotteryConstants.sol";
import {Test, console} from "forge-std/Test.sol";

contract LotteryMockTest is Lottery, Test {
    constructor(
        uint256 entryPrice_,
        uint256 length_,
        uint256 gracePeriod_,
        address linkToken_,
        address vrfCoordinatorV2Plus_,
        bytes32 keyHash_,
        uint32 callbackGasLimit_,
        uint16 requestConfirmations_,
        uint32 numWords_
    )
        Lottery(
            entryPrice_,
            length_,
            gracePeriod_,
            linkToken_,
            vrfCoordinatorV2Plus_,
            keyHash_,
            callbackGasLimit_,
            requestConfirmations_,
            numWords_
        )
    {}

    event WinnerPaidPrice(address indexed winner, uint256 price);
    event WinnerInvalidPayment(address indexed winner, uint256 price);

    //same as super.fulfillRandomWords(),
    // but we emit events for testing, unnecessary gas in real contract
    // when forking sepolia/mainnet we vm.deal() the price to the winner as call doesnt increase the balance of our fake address winner
    function testFulfillRandomWords(uint256[] calldata randomWords) external {
        uint256 playersLength = players.length;
        address winner = players[randomWords[0] % playersLength];
        uint256 price = playersLength * i_entryPrice;
        require(address(this).balance >= price, "Not enough funds in contract");
        startLottery();

        (bool success,) = payable(winner).call{value: price}("");
        if (!success) {
            pending_payouts[winner] += price;
            emit WinnerInvalidPayment(winner, price);
        } else {
            if (
                block.chainid == LotteryConstants.CHAIN_ID_SEPOLIA
                    || block.chainid == LotteryConstants.CHAIN_ID_ETHEREUM
            ) {
                vm.deal(winner, price);
            }
            emit WinnerPaidPrice(winner, price);
        }
    }

    function fundAndStartLottery(address token, uint256 amount) external override {
        if (funded == true) {
            revert Lottery__alreadyInitialized();
        }
        funded = true;
        LinkToken(token).transferFrom(msg.sender, address(this), amount);
        //  mockTopUpSubscription(amount); !
        startLottery();
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

    function getEntryPrice() external view returns (uint256) {
        return i_entryPrice;
    }

    function getLength() external view returns (uint256) {
        return i_length;
    }

    function getGracePeriod() external view returns (uint256) {
        return i_gracePeriod;
    }
}
