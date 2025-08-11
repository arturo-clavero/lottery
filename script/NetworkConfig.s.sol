// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import {MockRegistrar, RegistrationParams} from "../src/Register.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

// import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
// import {AutomationRegistryInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface2_0.sol";
// import {MockAutomationRegistrar} from "../test/mocks/MockAutomationRegistrar.sol";

// struct RegistrationParams {
//     string name;
//     bytes encryptedEmail;
//     address upkeepContract;
//     uint32 gasLimit;
//     address adminAddress;
//     uint8 triggerType;
//     bytes checkData;
//     bytes triggerConfig;
//     bytes offchainConfig;
//     uint96 amount;
// }

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
        //add only owner guard!
        registerParams.upkeepContract = newAddress;
    }

    function getRegisterParams() public view returns (RegistrationParams memory) {
        return registerParams;
    }
}

// contract NetworkConfig is Script {
//     uint256 public chainId;
//     LinkTokenInterface public link;
//     RegistrationParams public params;
//     AutomationRegistryInterface public registrar;
//     uint256 public minLinkFee;

//     constructor(){
//         chainId = block.chainid;
//         if (chainId == LotteryConstants.ETHEREUM_CHAIN_ID)
//         {
//             link = LinkTokenInterface(LotteryConstants.LINK_TOKEN_ETHEREUM);
//             registrar = AutomationRegistryInterface(LotteryConstants.AUTOMATION_ETHEREUM);
//             minLinkFee = 5 ether;
//         }
//         else if (chainId == LotteryConstants.SEPOLIA_CHAIN_ID)
//         {
//             link = LinkTokenInterface(LotteryConstants.LINK_TOKEN_SEPOLIA);
//             registrar = AutomationRegistryInterface(LotteryConstants.AUTOMATION_SEPOLIA);
//             minLinkFee = 1 ether;
//         }
//         else{
//             MockLinkToken mockLink = new MockLinkToken();
//             MockAutomationRegistrar mockRegistrar = new MockAutomationRegistrar();
//             link = LinkTokenInterface(address(mockLink));
//             registrar = AutomationRegistryInterface(address(mockRegistrar));
//             minLinkFee = 1 ether;
//             mockLink.transferAndCall(address(mockLink), 10 ether, "");
//         }
//         params = RegistrationParams({
//                 name: "MyUpkeep",
//                 encryptedEmail: "",
//                 gasLimit: LotteryConstants.GAS_LIMIT,
//                 adminAddress: msg.sender,
//                 triggerType: 1,
//                 checkData: "",
//                 triggerConfig: "",
//                 offchainConfig: "",
//                 amount: 1 ether,
//                 upkeepContract: address(0)
//             });
//     }

//     function registerUpKeep() external{

//     }

//     function addUppkeepAddress(address upKeepContract) external {
//         params.upkeepContract = upKeepContract;
//     }
// }
