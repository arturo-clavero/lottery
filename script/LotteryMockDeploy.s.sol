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
    //mapping lottery to -> config address...
    mapping(address => address) private deployedContractsNotFunded;

    error MockDeploy__registerNotInitialiazed();
    error MockDeploy__configNotInitialiazed();

    function run(address deployer) public returns (LotteryMockTest) {
        vm.startBroadcast(deployer);
        NetworkConfig config = new NetworkConfig();
        
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
        address lotteryMockAddress = address(lotteryMock);
        LinkToken(config.i_linkTokenAddress()).approve(lotteryMockAddress, LotteryConstants.MIN_LINK_AMOUNT);
        lotteryMock.fundAndStartLottery(config.i_linkTokenAddress(), LotteryConstants.MIN_LINK_AMOUNT);
        vm.stopBroadcast();
        config.updateUpkeepContract(lotteryMockAddress);
        deployedContractsNotFunded[lotteryMockAddress] = address(config);
        return lotteryMock;
    }

    //call after run() ...
    function deployRegister(address lotteryAddress) public returns (address) {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert MockDeploy__configNotInitialiazed();
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

    function getConfig(address lotteryAddress) public returns (NetworkConfig) {
        address configAddress = deployedContractsNotFunded[lotteryAddress];
        if (configAddress == address(0)) {
            revert MockDeploy__configNotInitialiazed();
        }
        return NetworkConfig(configAddress);
    }
}