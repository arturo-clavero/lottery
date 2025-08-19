// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LotteryMockTest} from "../test/mocks/LotteryMock.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

contract LotteryMockDeploy is Script {
    NetworkConfig public config;

    function run(address deployer) public returns (LotteryMockTest) {
        vm.startBroadcast(deployer);

        if (address(config) == address(0)) {
            config = new NetworkConfig();
        }

        Register register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()), AutomationRegistrarInterface(config.i_registrarAddress())
        );

        if (config.i_isLocalAnvil() == true) {
            vm.roll(1);
        } //pass createsubscription (else current block n - 1 underflows)
 
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

        config.mintLinkToken(deployer);
        LinkToken(config.i_linkTokenAddress()).approve(address(lotteryMock), LotteryConstants.MIN_LINK_AMOUNT);
        lotteryMock.fundAndStartLottery(config.i_linkTokenAddress(), LotteryConstants.MIN_LINK_AMOUNT);

        vm.stopBroadcast();

        config.updateUpkeepContract(address(lotteryMock));
        register.registerAndPredictID(config.getRegisterParams());
        return lotteryMock;
    }
}
