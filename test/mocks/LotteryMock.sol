// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Lottery} from "../../src/Lottery.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {LotteryConstants} from "../../src/lib/LotteryConstants.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title LotteryMockTest
 * @notice Mock version of Lottery contract for testing purposes
 * @dev Overrides certain functions to emit events and support testing with Forge
 */
contract LotteryMockTest is Lottery, Test {

    /// @notice Events for testing winner payout
    event WinnerPaidPrice(address indexed winner, uint256 price);
    event WinnerInvalidPayment(address indexed winner, uint256 price);
    
    /**
     * @notice Constructor initializes the Lottery with parameters
     */
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

    /**
     * @notice Mock version of fulfillRandomWords to emit events for testing
     * @param randomWords Array of random numbers
     * @dev Uses `vm.deal()` to simulate ETH transfer in test environments like Sepolia/Mainnet forks
     */
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

    /**
     * @notice Fund the lottery and start it
     * @param token LINK token address
     * @param amount Amount of LINK to fund
     * @dev Overrides parent function to skip actual VRF top-up for testing
     */
    function fundAndStartLottery(address token, uint256 amount) external override {
        if (funded) {
            revert Lottery__alreadyInitialized();
        }
        funded = true;
        LinkToken(token).transferFrom(msg.sender, address(this), amount);
        // skip mockTopUpSubscription for testing
        startLottery();
    }

    // -------------------------
    // View functions for testing
    // -------------------------

    /// @notice Get the current entry deadline
    function getEntryDeadline() external view returns (uint256) {
        return entryDeadline;
    }

    /// @notice Get the current pick winner deadline
    function getPickWinnerDeadline() external view returns (uint256) {
        return pickWinnerDeadline;
    }

    /// @notice Get the total number of players
    function getTotalPlayers() external view returns (uint256) {
        return players.length;
    }

    /// @notice Get the entry price
    function getEntryPrice() external view returns (uint256) {
        return i_entryPrice;
    }

    /// @notice Get the lottery length
    function getLength() external view returns (uint256) {
        return i_length;
    }

    /// @notice Get the grace period
    function getGracePeriod() external view returns (uint256) {
        return i_gracePeriod;
    }
}
