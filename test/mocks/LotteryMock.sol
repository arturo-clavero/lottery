// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Lottery} from "../../src/Lottery.sol";

contract LotteryMockTest is Lottery{

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
    ) Lottery(
        entryPrice_,
        length_,
        gracePeriod_,
        linkToken_,
        vrfCoordinatorV2Plus_,
        keyHash_,
        callbackGasLimit_,
        requestConfirmations_,
        numWords_
    ) {
    }

    function testFulfillRandomWords(uint256[] calldata randomWords) external {
        fulfillRandomWords(0, randomWords);
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

    function getGracePeriod() external view returns (uint256){
        return i_gracePeriod;
    }

}
