// SPDX-License-Identifier: MIT
// An example of a consumer contract that also owns and manages the subscription
pragma solidity ^0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Lottery} from "./Lottery.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract VRFv2PlusSubscriptionManager is VRFConsumerBaseV2Plus {
    LinkTokenInterface private immutable I_LINKTOKEN;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private immutable i_requestConfirmations = 3;
    uint32 private immutable i_numWords = 2;
    Lottery lottery;

    // Storage parameters
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint256 public s_subscriptionId;

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
        //Create a new subscription when you deploy the contract.
        _createNewSubscription();
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() internal onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: i_numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal virtual override {
        s_randomWords = randomWords;
    }

    // Create a new subscription when the contract is initially deployed.
    function _createNewSubscription() private onlyOwner {
        s_subscriptionId = s_vrfCoordinator.createSubscription();
        // Add this contract as a consumer of its own subscription.
        s_vrfCoordinator.addConsumer(s_subscriptionId, address(this));
    }

    // Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) internal onlyOwner {
        I_LINKTOKEN.transferAndCall(address(s_vrfCoordinator), amount, abi.encode(s_subscriptionId));
    }

    function mockTopUpSubscription(uint256 amount) internal onlyOwner {
        VRFCoordinatorV2_5Mock(address(s_vrfCoordinator)).fundSubscription(s_subscriptionId, amount);

        // s_vrfCoordinator.fundSubscription(s_subscriptionId, amount);
    }

    function addConsumer(address consumerAddress) external onlyOwner {
        // Add a consumer contract to the subscription.
        s_vrfCoordinator.addConsumer(s_subscriptionId, consumerAddress);
    }

    function removeConsumer(address consumerAddress) external onlyOwner {
        // Remove a consumer contract from the subscription.
        s_vrfCoordinator.removeConsumer(s_subscriptionId, consumerAddress);
    }

    function cancelSubscription(address receivingWallet) external onlyOwner {
        // Cancel the subscription and send the remaining LINK to a wallet address.
        s_vrfCoordinator.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    // Transfer this contract's funds to an address.
    // 1000000000000000000 = 1 LINK
    function withdraw(uint256 amount, address to) external onlyOwner {
        I_LINKTOKEN.transfer(to, amount);
    }
}
