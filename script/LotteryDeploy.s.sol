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

    function run() public returns (Lottery) {
        vm.startBroadcast(msg.sender);
        NetworkConfig config = new NetworkConfig();
        Register register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()), AutomationRegistrarInterface(config.i_registrarAddress())
        );
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
        register.registerAndPredictID(config.getRegisterParams());
        vm.stopBroadcast();
        deployedContractsNotFunded[address(lottery)] = address(config);
        return lottery;
    }

    //this function should be called by same user who called run,
    // once they have min link amount minted to their account
    function fundAndStartLottery(address lotteryAddress) external {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0) || NetworkConfig(configAddress).owner() != msg.sender) {
            revert Deploy__noLotteryToFund();
        }
        delete deployedContractsNotFunded[lotteryAddress];
        address lintTokenAddress = NetworkConfig(configAddress).i_linkTokenAddress();
        LinkToken(lintTokenAddress).approve(lotteryAddress, LotteryConstants.MIN_LINK_AMOUNT);
        Lottery(lotteryAddress).fundAndStartLottery(lintTokenAddress, LotteryConstants.MIN_LINK_AMOUNT);
    }
}
