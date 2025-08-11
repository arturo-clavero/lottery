// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

interface AutomationRegistrarInterface {
    function registerUpkeep(RegistrationParams calldata requestParams) external returns (uint256);
}

contract MockRegistrar {
    function registerUpkeep(RegistrationParams calldata requestParams) external returns (uint256) {
        return 123;
    }
}

contract Register {
    LinkTokenInterface public immutable i_link;
    AutomationRegistrarInterface public immutable i_registrar;

    constructor(LinkTokenInterface link, AutomationRegistrarInterface registrar) {
        i_link = link;
        i_registrar = registrar;
    }

    function registerAndPredictID(RegistrationParams memory params) public {
        i_link.approve(address(i_registrar), params.amount);
        uint256 upkeepID = i_registrar.registerUpkeep(params);
        if (upkeepID == 0) {
            revert("auto-approve disabled");
        }
    }
}
