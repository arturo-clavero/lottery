// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {MockRegistrar, RegistrationParams} from "../src/Register.sol";
import {VRFv2PlusSubscriptionManager} from "../src/VRFSubscriptionManager.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract NetworkConfig is Script {
    uint256 public chainId;
    //automation :
    RegistrationParams public registerParams;
    address public immutable i_registrarAddress;
    //automation && random number
    address public immutable i_linkTokenAddress;
    //random number
    address public immutable i_vrfCoordinatorV2PlusAddress;
    bytes32 public immutable i_keyHash;
    uint32 public immutable i_callbackGasLimit;
    uint16 public immutable REQUEST_CONFIRMATIONS = 3;
    uint32 public constant NUM_WORDS = 1;
    // VRFv2PlusSubscriptionManager private immutable s_manager;
    // Deploy the SubscriptionManager contract.
    // On deployment, the contract creates a new subscription and adds itself as a consumer to the new subscription.
    //vfr :

    constructor() {
        chainId = block.chainid;
        registerParams = RegistrationParams({
            name: "test upkeep",
            encryptedEmail: "",
            upkeepContract: address(0),
            gasLimit: 500000,
            adminAddress: msg.sender,
            triggerType: 0,
            checkData: "",
            triggerConfig: "",
            offchainConfig: "",
            amount: 1000000000000000000
        });
        if (chainId == LotteryConstants.CHAIN_ID_ETHEREUM) {
            i_registrarAddress = LotteryConstants.REGISTRAR_ADDRESS_ETHEREUM;
            i_linkTokenAddress = LotteryConstants.LINK_TOKEN_ADDRESS_ETHEREUM;
            i_vrfCoordinatorV2PlusAddress = LotteryConstants.VRF_COORDINATOR_V2_PLUS_ETHEREUM;
            i_keyHash = LotteryConstants.KEYHASH_ETHEREUM;
            i_callbackGasLimit = LotteryConstants.CALLBACK_GAS_LIMIT_ETHEREUM;
        } else if (chainId == LotteryConstants.CHAIN_ID_SEPOLIA) {
            i_registrarAddress = LotteryConstants.REGISTRAR_ADDRESS_SEPOLIA;
            i_linkTokenAddress = LotteryConstants.LINK_TOKEN_ADDRESS_SEPOLIA;
            i_vrfCoordinatorV2PlusAddress = LotteryConstants.VRF_COORDINATOR_V2_PLUS_SEPOLIA;
            i_keyHash = LotteryConstants.KEYHASH_SEPOLIA;
            i_callbackGasLimit = LotteryConstants.CALLBACK_GAS_LIMIT_SEPOLIA;
        } else {
            uint96 baseFee = 0.25 ether; // 0.25 LINK (since LINK has 18 decimals, same as ETH)
            uint96 gasPrice = 1e9; // 1 gwei
            int256 weiPerUnitLink = 1e18; // 1 LINK = 1 ETH
            i_registrarAddress = address(new MockRegistrar());
            i_linkTokenAddress = address(new LinkToken());
            i_vrfCoordinatorV2PlusAddress = address(new VRFCoordinatorV2_5Mock(baseFee, gasPrice, weiPerUnitLink));
            i_keyHash = LotteryConstants.KEYHASH_LOCAL;
            i_callbackGasLimit = LotteryConstants.CALLBACK_GAS_LIMIT_ANVIL;
        }
    }

    function updateUpkeepContract(address newAddress) external {
        registerParams.upkeepContract = newAddress;
    }

    function getRegisterParams() public view returns (RegistrationParams memory) {
        return registerParams;
    }
}
