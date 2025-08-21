// SPDX-License-Identifier: MIT
// An example consumer contract that owns and manages a Chainlink VRF subscription
pragma solidity ^0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Lottery} from "./Lottery.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @notice Example contract demonstrating a VRFv2 subscription manager
 * @dev Uses hardcoded values for clarity and is not audited. Do not use in production.
 */
contract VRFv2PlusSubscriptionManager is VRFConsumerBaseV2Plus {

    /// @notice Number of confirmations to wait for VRF
    uint16 private immutable i_requestConfirmations = 3;

    /// @notice Key hash for VRF requests
    bytes32 private immutable i_keyHash;

    /// @notice Gas limit for VRF callback
    uint32 private immutable i_callbackGasLimit;

    /// @notice Number of random words requested
    uint32 private immutable i_numWords = 2;

    /// @notice LINK token interface
    LinkTokenInterface private immutable I_LINKTOKEN;

    /// @notice VRF Coordinator request ID
    uint256 public s_requestId;

    /// @notice Subscription ID for VRF
    uint256 public s_subscriptionId;

    /// @notice Random words returned by VRF
    uint256[] public s_randomWords;
        
    /// @notice Associated lottery contract
    Lottery lottery;

    /**
     * @param vrfCoordinatorV2Plus VRF Coordinator address
     * @param link_token_contract LINK token address
     * @param keyHash VRF key hash
     * @param callbackGasLimit Gas limit for fulfillRandomWords
     * @param requestConfirmations Number of VRF confirmations
     * @param numWords Number of random words to request
     */
    constructor(
        address vrfCoordinatorV2Plus,
        address link_token_contract,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2Plus) {
        s_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinatorV2Plus);
        I_LINKTOKEN = LinkTokenInterface(link_token_contract);
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_requestConfirmations = requestConfirmations;
        i_numWords = numWords;

        // Create a new subscription at deployment
        _createNewSubscription();
    }

    /// @notice Adds a consumer contract to the subscription
    /// @param consumerAddress Address of consumer contract
    function addConsumer(address consumerAddress) external onlyOwner {
        s_vrfCoordinator.addConsumer(s_subscriptionId, consumerAddress);
    }

    /// @notice Removes a consumer contract from the subscription
    /// @param consumerAddress Address of consumer contract
    function removeConsumer(address consumerAddress) external onlyOwner {
        s_vrfCoordinator.removeConsumer(s_subscriptionId, consumerAddress);
    }

    /// @notice Cancels the subscription and sends remaining LINK to a wallet
    /// @param receivingWallet Address to receive remaining LINK
    function cancelSubscription(address receivingWallet) external onlyOwner {
        s_vrfCoordinator.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    /// @notice Withdraw LINK from this contract
    /// @param amount Amount of LINK to withdraw
    /// @param to Recipient address
    function withdraw(uint256 amount, address to) external onlyOwner {
        I_LINKTOKEN.transfer(to, amount);
    }


    /// @notice Requests random words from Chainlink VRF
    /// @dev Reverts if subscription is not funded
    function requestRandomWords() internal onlyOwner {
        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: i_numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /// @notice VRF callback to receive random words
    /// @param randomWords Array of random numbers returned by VRF
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] calldata randomWords
    ) internal virtual override {
        s_randomWords = randomWords;
    }

    /// @notice Fund the subscription with LINK
    /// @param amount Amount of LINK to fund (in wei, 1 LINK = 10**18)
    function topUpSubscription(uint256 amount) internal onlyOwner {
        I_LINKTOKEN.transferAndCall(address(s_vrfCoordinator), amount, abi.encode(s_subscriptionId));
    }

    /// @notice Mock top-up function for testing with VRFCoordinatorV2_5Mock
    /// @param amount Amount to fund
    function mockTopUpSubscription(uint256 amount) internal onlyOwner {
        VRFCoordinatorV2_5Mock(address(s_vrfCoordinator)).fundSubscription(s_subscriptionId, amount);
    }

    /// @notice Creates a new VRF subscription and adds this contract as consumer
    function _createNewSubscription() private onlyOwner {
        s_subscriptionId = s_vrfCoordinator.createSubscription();
        s_vrfCoordinator.addConsumer(s_subscriptionId, address(this));
    }
}
