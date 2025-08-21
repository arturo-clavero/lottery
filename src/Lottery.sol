// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {VRFv2PlusSubscriptionManager} from "./VRFSubscriptionManager.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

/// @title A simple Lottery contract using Chainlink VRF and Automation
/// @notice Users can enter by paying the entry fee. Chainlink VRF picks a winner.
contract Lottery is ReentrancyGuard, AutomationCompatibleInterface, VRFv2PlusSubscriptionManager {

    /// @notice Entry fee for the lottery
    uint256 internal immutable i_entryPrice;

    /// @notice Duration of each lottery round in seconds
    uint256 internal immutable i_length;

    /// @notice Extra time after lottery ends to pick winner
    uint256 internal immutable i_gracePeriod;

    /// @notice Indicates if lottery has been funded
    bool internal funded;

    /// @notice Timestamp until which players can enter
    uint256 internal entryDeadline;

    /// @notice Timestamp by which winner must be picked
    uint256 internal pickWinnerDeadline;

    /// @notice List of players in the current lottery
    address[] internal players;

    /// @notice Tracks ETH owed to winners if transfer fails
    mapping(address => uint256) internal pending_payouts;

    /// @notice Maps Chainlink VRF request IDs to addresses (if needed)
    mapping(uint256 => address) private s_requests;

    /// @notice Emitted when a winner withdraws their prize
    event WinnerWithdrawnPrice(address indexed winner, uint256 price);

    /// @notice Error for sending incorrect entry fee
    error Lottery__invalidPrice(uint256 amount);

    /// @notice Error when trying to enter after lottery ended
    error Lottery__alreadyEnded();

    /// @notice Error when lottery is not over yet
    error Lottery__notOver();

    /// @notice Error when caller has no winnings to withdraw
    error Lottery__noWinningsToWithdraw();

    /// @notice Error when there are not enough players
    error Lottery__notEnoughPlayers();

    /// @notice Error when funding lottery twice
    error Lottery__alreadyInitialized();

    /// @param entryPrice Entry fee in ETH
    /// @param length Duration of lottery in seconds
    /// @param gracePeriod Extra time to pick winner
    /// @param link_token_contract LINK token address for VRF subscription
    /// @param vrfCoordinatorV2Plus VRF coordinator address
    /// @param keyHash VRF key hash
    /// @param callbackGasLimit Gas limit for VRF callback
    /// @param requestConfirmations Number of VRF confirmations
    /// @param numWords Number of random words requested
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
    }

    /// @notice Fund lottery with LINK and start the first round
    /// @param token LINK token address
    /// @param amount Amount of LINK to fund VRF subscription
    function fundAndStartLottery(address token, uint256 amount) external virtual {
        if (funded) revert Lottery__alreadyInitialized();
        funded = true;
        LinkToken(token).transferFrom(msg.sender, address(this), amount);
        topUpSubscription(amount);
        startLottery();
    }

    /// @notice Enter the lottery by sending exact entry fee in ETH
    function enterLottery() external payable {
        if (msg.value != i_entryPrice) revert Lottery__invalidPrice(msg.value);
        if (block.timestamp >= entryDeadline) revert Lottery__alreadyEnded();
        players.push(msg.sender);
    }

    /// @notice Chainlink Automation callback to request randomness if lottery is over
    function performUpkeep(bytes calldata) external override {
        if (!isLotteryOver()) revert Lottery__notOver();
        requestRandomWords();
    }

    /// @notice Withdraw pending winnings if automatic transfer failed
    function winnerFallbackWithdrawal() external nonReentrant {
        uint256 price = pending_payouts[msg.sender];
        if (price == 0) revert Lottery__noWinningsToWithdraw();
        delete pending_payouts[msg.sender];
        SafeTransferLib.safeTransferETH(payable(msg.sender), price);
        emit WinnerWithdrawnPrice(msg.sender, price);
    }

    /// @notice Chainlink Automation view to check if upkeep is needed
    function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
        return (isLotteryOver(), "");
    }

    /// @notice Returns true if lottery is over and enough players exist
    function isLotteryOver() public view returns (bool) {
        uint256 total_players = players.length;
        return !(block.timestamp < pickWinnerDeadline || total_players < 2);
    }

    /// @notice Chainlink VRF callback: determines winner and distributes prize
    /// @param randomWords Array of random words provided by VRF
    function fulfillRandomWords(
        uint256,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 playersLength = players.length;
        address winner = players[randomWords[0] % playersLength];
        uint256 price = playersLength * i_entryPrice;
        startLottery();
        (bool success,) = payable(winner).call{value: price}("");
        if (!success) {
            pending_payouts[winner] += price;
        }
    }

    /// @notice Starts a new lottery round
    function startLottery() internal {
        delete players;
        uint256 cacheEntryDeadline = block.timestamp + i_length;
        pickWinnerDeadline = cacheEntryDeadline + i_gracePeriod;
        entryDeadline = cacheEntryDeadline;
    }
}
