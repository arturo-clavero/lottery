// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
// import {AutomationRegistrarInterface} from "@chainlink/contracts/src/v0.8/automation/v2_1/AutomationRegistrar2_1.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract LotteryDeploy is Script {
    Lottery public lottery;
    Register public register;
    NetworkConfig public config;

    error Lottery__autoApproveDisabled();

    function run() public returns (Lottery) {
        if (address(config) == address(0)) {
            config = new NetworkConfig();
        }
        vm.startBroadcast();

        // register = new Register(
        //     LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789),
        //     AutomationRegistrarInterface(0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976)
        // );
        register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()), AutomationRegistrarInterface(config.i_registrarAddress())
        );

        lottery = new Lottery(LotteryConstants.ENTRY_PRICE, LotteryConstants.LENGTH, LotteryConstants.GRACE_PERIOD);
        config.updateUpkeepContract(address(lottery));
        //
        //    RegistrationParams memory params = RegistrationParams({
        //     name: "test upkeep",
        //     encryptedEmail: "",
        //     upkeepContract: address(lottery),
        //     gasLimit: 500000,
        //     adminAddress: msg.sender,
        //     triggerType: 0,
        //     checkData: "",
        //     triggerConfig: "",
        //     offchainConfig: "",
        //     amount: 1000000000000000000
        // });

        // register.registerAndPredictID(params);
        register.registerAndPredictID(config.getRegisterParams());

        vm.stopBroadcast();

        return lottery;
    }
}
