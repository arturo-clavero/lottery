// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {MockRegistrar, RegistrationParams} from "../src/Register.sol";
import {VRFv2PlusSubscriptionManager} from "../src/VRFSubscriptionManager.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @title NetworkConfig
 * @notice Configures chain-specific parameters for Lottery deployment, including LINK, VRF, and Automation
 * @dev Supports Ethereum, Sepolia, and local Anvil networks
 */
contract NetworkConfig is Script {

    /// @notice Flag for local Anvil network
    bool public immutable i_isLocalAnvil = false;

    /// @notice Number of confirmations to wait for VRF
    uint16 public immutable REQUEST_CONFIRMATIONS = 3;

    /// @notice Key hash for VRF requests
    bytes32 public immutable i_keyHash;

    /// @notice Gas limit for VRF callback
    uint32 public immutable i_callbackGasLimit;

    /// @notice Number of random words requested
    uint32 public constant NUM_WORDS = 1;

    /// @notice Owner of this config contract
    address public immutable owner;

    /// @notice Automation registrar address
    address public immutable i_registrarAddress;

    /// @notice LINK token address
    address public immutable i_linkTokenAddress;

    /// @notice VRF Coordinator address
    address public immutable i_vrfCoordinatorV2PlusAddress;

    /// @notice Current chain ID
    uint256 public chainId;

    /// @notice Address of deployed Register contract
    address public registerAddress;

    /// @notice Default registration parameters for Chainlink Automation upkeep
    RegistrationParams public registerParams;

    /**
     * @notice Initializes network-specific parameters for Lottery deployment
     * @dev Deploys mocks for local Anvil network and sets up LINK and VRF addresses
     */
    constructor() {
        chainId = block.chainid;
        owner = msg.sender;

        // Default registration parameters
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
            amount: 1 ether
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
            // Local Anvil network: deploy mocks
            uint96 baseFee = 0.25 ether;
            uint96 gasPrice = 1 gwei;
            int256 weiPerUnitLink = 1e18;

            i_registrarAddress = address(new MockRegistrar());
            i_linkTokenAddress = address(new LinkToken());
            i_vrfCoordinatorV2PlusAddress = address(
                new VRFCoordinatorV2_5Mock(baseFee, gasPrice, weiPerUnitLink)
            );
            i_keyHash = LotteryConstants.KEYHASH_LOCAL;
            i_callbackGasLimit = LotteryConstants.CALLBACK_GAS_LIMIT_ANVIL;
            // Minting enabled for local testing
            LinkToken(i_linkTokenAddress).grantMintRole(address(this));
        }
    }

    /// @notice Mint LINK tokens for a receiver (local Anvil only)
    /// @param receiver Address to receive minted LINK
    function mintLinkToken(address receiver) external {
        if (i_isLocalAnvil) {
            LinkToken(i_linkTokenAddress).mint(receiver, 100 ether);
        }
    }

    /// @notice Update the upkeep contract address in registration parameters
    /// @param newAddress New upkeep contract address
    function updateUpkeepContract(address newAddress) external {
        registerParams.upkeepContract = newAddress;
    }

    /// @notice Set the deployed Register contract address
    /// @param _registerAddress Address of Register contract
    function setRegisterAddress(address _registerAddress) external {
        registerAddress = _registerAddress;
    }

    /// @notice Get the current registration parameters
    /// @return RegistrationParams struct
    function getRegisterParams() public view returns (RegistrationParams memory) {
        return registerParams;
    }

}
