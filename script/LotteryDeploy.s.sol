// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract LotteryDeploy is Script {
    Lottery public lottery;
    Register public register;
    NetworkConfig public config;
    address public owner;

    error Lottery__autoApproveDisabled();

    function run() public returns (Lottery) {
        if (address(config) == address(0)) {
            config = new NetworkConfig();
        }
        vm.startBroadcast();

        register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()), AutomationRegistrarInterface(config.i_registrarAddress())
        );

        lottery = new Lottery(
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

        return lottery;
    }
}
