// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

contract LotteryDeploy is Script {
    //mapping lottery to -> config address...
    mapping(address => address) private deployedContractsNotFunded;

    error Deploy__noLotteryToFund();
    error Deploy__registerNotInitialiazed();
    error Deploy__registerNotFunded();

    function run() public returns (Lottery) {
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

   
    //call after run() ...
    function deployRegister(address lotteryAddress) public returns (address) {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert Deploy__noLotteryToFund();
        }
        NetworkConfig config = NetworkConfig(configAddress);
        Register register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()), AutomationRegistrarInterface(config.i_registrarAddress())
        );
        address registerAddress = address(register);
        config.setRegisterAddress(registerAddress);
        return registerAddress;
    }

    //call after deployRegister() and funding the register address with Link Tokens
    function setRegisterAfterFunding(address lotteryAddress) public {
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

    //this function should be called by same user who called run,
    // once they have min link amount minted to their account
    // and they have created and minted the register
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
        if (registerAddress.balance == 0)
        {
            revert Deploy__registerNotFunded();
        }
        delete deployedContractsNotFunded[lotteryAddress];
        address lintTokenAddress = config.i_linkTokenAddress();
        LinkToken(lintTokenAddress).approve(lotteryAddress, LotteryConstants.MIN_LINK_AMOUNT);
        Lottery(lotteryAddress).fundAndStartLottery(lintTokenAddress, LotteryConstants.MIN_LINK_AMOUNT);
    }
}
