// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

/**
 * @title LotteryDeploy
 * @notice Handles deployment and funding of Lottery contracts with LINK and associated Register contracts
 * @dev Works with NetworkConfig to manage LINK, VRF, and Automation setup
 */
contract LotteryDeploy is Script {
    /// @notice Maps a deployed lottery to its NetworkConfig address
    mapping(address => address) private deployedContractsNotFunded;

    /// @notice Deployment-related errors
    error Deploy__noLotteryToFund();
    error Deploy__registerNotInitialiazed();
    error Deploy__registerNotFunded();

    /**
     * @notice Deploys a Lottery contract and updates its upkeep contract in NetworkConfig
     * @return lottery Deployed Lottery contract instance
     */
    function run() external returns (Lottery) {
        vm.startBroadcast(msg.sender);

        NetworkConfig config = new NetworkConfig();

        Lottery lottery = new Lottery(
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

        config.updateUpkeepContract(address(lottery));

        vm.stopBroadcast();

        deployedContractsNotFunded[address(lottery)] = address(config);

        return lottery;
    }

    /**
     * @notice Deploys a Register contract for a given Lottery
     * @param lotteryAddress Address of the deployed Lottery
     * @return registerAddress Address of the deployed Register contract
     */
    function deployRegister(address lotteryAddress) external returns (address) {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert Deploy__noLotteryToFund();
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
     * @notice Registers upkeep after funding the Register contract with LINK
     * @param lotteryAddress Address of the lottery associated with the Register
     */
    function setRegisterAfterFunding(address lotteryAddress) external {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert Deploy__noLotteryToFund();
        }

        NetworkConfig config = NetworkConfig(configAddress);

        address registerAddress = config.registerAddress();
        if (registerAddress == address(0)) {
            revert Deploy__registerNotInitialiazed();
        }

        Register(registerAddress).registerAndPredictID(config.getRegisterParams());
    }

    /**
     * @notice Funds and starts a deployed Lottery contract
     * @param lotteryAddress Address of the deployed Lottery
     * @dev Requires the caller to be the owner and the Register to be funded
     */
    function fundAndStartLottery(address lotteryAddress) external {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0) || NetworkConfig(configAddress).owner() != msg.sender) {
            revert Deploy__noLotteryToFund();
        }

        NetworkConfig config = NetworkConfig(configAddress);

        address registerAddress = config.registerAddress();
        if (registerAddress == address(0)) {
            revert Deploy__registerNotInitialiazed();
        }

        if (registerAddress.balance == 0) {
            revert Deploy__registerNotFunded();
        }

        delete deployedContractsNotFunded[lotteryAddress];

        address linkTokenAddress = config.i_linkTokenAddress();
        LinkToken(linkTokenAddress).approve(lotteryAddress, LotteryConstants.MIN_LINK_AMOUNT);
        Lottery(lotteryAddress).fundAndStartLottery(linkTokenAddress, LotteryConstants.MIN_LINK_AMOUNT);
    }
}
