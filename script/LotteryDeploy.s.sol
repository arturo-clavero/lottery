// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryMockTest} from "../test/mocks/LotteryMock.sol";
import {Register, RegistrationParams, AutomationRegistrarInterface} from "../src/Register.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

contract LotteryDeploy is Script {
    Lottery public lottery;
    LotteryMockTest public lotteryMock;
    Register public register;
    NetworkConfig public config;
    address deployer = vm.addr(2);

    function run() public returns (Lottery) {
        _setUp();
        return _deploy();
    }

    function runTest() public returns (LotteryMockTest) {
        _setUp();
        return _deployMock();
    }

    function _setUp() internal {
        vm.startBroadcast(deployer);

        if (address(config) == address(0)) {
            config = new NetworkConfig();
        }


        // Register
        register = new Register(
            LinkTokenInterface(config.i_linkTokenAddress()),
            AutomationRegistrarInterface(config.i_registrarAddress())
        );

        if (config.i_isLocalAnvil() == true)
            vm.roll(1);
    }

    function _deploy() internal returns(Lottery){
        Lottery deployed = new Lottery(
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
        // LinkToken(config.i_linkTokenAddress()).approve(address(deployed), type(uint256).max);
        // deployed.fundAndStartLottery(config.i_linkTokenAddress(), LotteryConstants.MIN_LINK_AMOUNT);
        config.updateUpkeepContract(address(deployed));
        register.registerAndPredictID(config.getRegisterParams());
        vm.stopBroadcast();
        return deployed;
    }

    function _deployMock() internal returns (LotteryMockTest){
        address owner = msg.sender;
        LotteryMockTest deployedMock = new LotteryMockTest(
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
        vm.stopBroadcast();
        vm.startPrank(address(config));
        config.mintLinkToken(deployer); // mint to deployer/owner
        vm.stopPrank();
        // LinkToken(config.i_linkTokenAddress()).approve(address(config), type(uint256).max);
        // vm.startPrank(owner);
        // LinkToken(config.i_linkTokenAddress()).transferFrom(owner, address(deployedMock),  LotteryConstants.MIN_LINK_AMOUNT);
        // vm.stopPrank();
        // vm.prank(owner);
        vm.startBroadcast(deployer);
        LinkToken(config.i_linkTokenAddress()).approve(address(deployedMock), LotteryConstants.MIN_LINK_AMOUNT * 2);
        deployedMock.fundAndStartLottery(config.i_linkTokenAddress(), deployer, LotteryConstants.MIN_LINK_AMOUNT);
        vm.stopBroadcast();
        // vm.stopPrank();
        // deployedMock.fundAndStartLottery(LotteryConstants.MIN_LINK_AMOUNT);
        config.updateUpkeepContract(address(deployedMock));
        register.registerAndPredictID(config.getRegisterParams());
        return deployedMock;
    }
}
