// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LotteryMockTest} from "../test/mocks/LotteryMock.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

/**
 * @title LotteryMockDeploy
 * @notice Deploys a mock Lottery contract and associated Register contract for testing
 * @dev Handles funding with LINK tokens and updating upkeep contract addresses
 */
contract LotteryMockDeploy is Script {
    /// @notice Maps a lottery address to its NetworkConfig for internal tracking
    mapping(address => address) private deployedContractsNotFunded;

    /// @notice Errors for deployment and configuration issues
    error MockDeploy__registerNotInitialiazed();
    error MockDeploy__configNotInitialiazed();

    /**
     * @notice Deploys a LotteryMockTest contract, funds it with LINK, and updates config
     * @param deployer Address that will deploy and fund the contracts
     * @return lotteryMock Deployed LotteryMockTest instance
     */
    function run(address deployer) public returns (LotteryMockTest) {
        vm.startBroadcast(deployer);

        NetworkConfig config = new NetworkConfig();

        // Roll the block in local Anvil to avoid underflows in subscription creation
        if (config.i_isLocalAnvil() == true) {
            vm.roll(1);
        }

        LotteryMockTest lotteryMock = new LotteryMockTest(
            LotteryConstants.ENTRY_PRICE,
            LotteryConstants.LENGTH,
            LotteryConstants.GRACE_PERIOD,
            config.i_linkTokenAddress(),
            config.i_vrfCoordinatorV2PlusAddress(),
            config.i_keyHash(),
            config.i_callbackGasLimit(),
            config.REQUEST_CONFIRMATIONS(),
            config.NUM_WORDS()
        );

        // Fund lottery with LINK tokens for subscription
        config.mintLinkToken(deployer);
        address lotteryMockAddress = address(lotteryMock);
        LinkToken(config.i_linkTokenAddress()).approve(lotteryMockAddress, LotteryConstants.MIN_LINK_AMOUNT);
        lotteryMock.fundAndStartLottery(config.i_linkTokenAddress(), LotteryConstants.MIN_LINK_AMOUNT);

        vm.stopBroadcast();

        // Update upkeep contract in config and track deployment
        config.updateUpkeepContract(lotteryMockAddress);
        deployedContractsNotFunded[lotteryMockAddress] = address(config);

        return lotteryMock;
    }

    /**
     * @notice Deploys a Register contract for a given lottery
     * @param lotteryAddress Address of the deployed lottery
     * @return registerAddress Address of the deployed Register contract
     */
    function deployRegister(address lotteryAddress) public returns (address) {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert MockDeploy__configNotInitialiazed();
        }

        NetworkConfig config = NetworkConfig(configAddress);
        Register register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()),
            AutomationRegistrarInterface(config.i_registrarAddress())
        );

        address registerAddress = address(register);
        config.setRegisterAddress(registerAddress);

        return registerAddress;
    }

    /**
     * @notice Registers the upkeep after funding the Register contract with LINK
     * @param lotteryAddress Address of the lottery associated with the Register
     */
    function setRegisterAfterFunding(address lotteryAddress) public {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert MockDeploy__configNotInitialiazed();
        }

        NetworkConfig config = NetworkConfig(configAddress);
        address registerAddress = config.registerAddress();
        if (registerAddress == address(0)) {
            revert MockDeploy__registerNotInitialiazed();
        }

        Register(registerAddress).registerAndPredictID(config.getRegisterParams());

        delete deployedContractsNotFunded[lotteryAddress];
    }

    /**
     * @notice Returns the NetworkConfig associated with a given lottery
     * @param lotteryAddress Lottery address
     * @return NetworkConfig instance
     */
    function getConfig(address lotteryAddress) public returns (NetworkConfig) {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert MockDeploy__configNotInitialiazed();
        }
        return NetworkConfig(configAddress);
    }
}
