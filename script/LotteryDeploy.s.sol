// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
// import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {AutomationRegistryInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface2_0.sol";

contract LotteryDeploy is Script {
    Lottery public lottery;
    // NetworkConfig public config;

    error Lottery__autoApproveDisabled();

    function run() public returns (Lottery) {
        // if (address(config) == address(0))
        //     config = new NetworkConfig();
        vm.startBroadcast();

        lottery = new Lottery(LotteryConstants.ENTRY_PRICE, LotteryConstants.LENGTH, LotteryConstants.GRACE_PERIOD);

        // config.addUppkeepAddress(address(lottery));
        // config.registerUpKeep();
        //checkRegistry(config.registrar());

        vm.stopBroadcast();

        return lottery;
    }

    //   function checkRegistry(AutomationRegistryInterface params) private{
    //         config.link().approve(address(registrar), params.amount);
    //         uint256 upkeepID = registrar.registerUpkeep(params);
    //         // if (upkeepID != 0) {
    //         //     // DEV - Use the upkeepID however you see fit
    //         // } else {
    //         //     revert Lottery__autoApproveDisabled();
    //         // }
    //         if (upkeepID == 0) {
    //             revert Lottery__autoApproveDisabled();
    //         }
    //     }
}
