// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {VRFv2PlusSubscriptionManager} from "./VRFSubscriptionManager.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

interface ILottery {

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
    ){}

    function fundAndStartLottery(address token, uint256 amount) external virtual {}

    function enterLottery() external payable {}

    function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {}

    function performUpkeep(bytes calldata) external override {}

    function winnerFallbackWithdrawal() external nonReentrant {}

    function isLotteryOver() public view returns (bool) {}

    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    ) internal virtual override {}

    function startLottery() internal {}

}
