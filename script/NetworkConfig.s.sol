// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {MockRegistrar, RegistrationParams} from "../src/Register.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract NetworkConfig is Script {
    uint256 public chainId;
    RegistrationParams public registerParams;
    address public immutable i_linkTokenAddress;
    address public immutable i_registrarAddress;

    constructor() {
        chainId = block.chainid;
        registerParams = RegistrationParams({
            name: "test upkeep",
            encryptedEmail: "",
            upkeepContract: address(0),
            gasLimit: 500000,
            adminAddress: msg.sender,
            triggerType: 0,
            checkData: "",
            triggerConfig: "",
            offchainConfig: "",
            amount: 1000000000000000000
        });
        if (chainId == LotteryConstants.CHAIN_ID_ETHEREUM) {
            i_linkTokenAddress = LotteryConstants.LINK_TOKEN_ADDRESS_ETHEREUM;
            i_registrarAddress = LotteryConstants.REGISTRAR_ADDRESS_ETHEREUM;
        } else if (chainId == LotteryConstants.CHAIN_ID_SEPOLIA) {
            i_linkTokenAddress = LotteryConstants.LINK_TOKEN_ADDRESS_SEPOLIA;
            i_registrarAddress = LotteryConstants.REGISTRAR_ADDRESS_SEPOLIA;
        } else {
            i_linkTokenAddress = address(new MockLinkToken());
            i_registrarAddress = address(new MockRegistrar());
        }
    }

    function updateUpkeepContract(address newAddress) external {
        registerParams.upkeepContract = newAddress;
    }

    function getRegisterParams() public view returns (RegistrationParams memory) {
        return registerParams;
    }
}
