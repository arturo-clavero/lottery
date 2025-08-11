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
    uint256 public uppKeepId = 1;

    function registerUpkeep(RegistrationParams calldata) external returns (uint256) {
        uppKeepId++;
        return uppKeepId;
    }
}

contract Register {
    LinkTokenInterface public immutable i_link;
    AutomationRegistrarInterface public immutable i_registrar;

    error Register__approveFailed();

    constructor(LinkTokenInterface link, AutomationRegistrarInterface registrar) {
        i_link = link;
        i_registrar = registrar;
    }

    function registerAndPredictID(RegistrationParams memory params) public {
        bool success = i_link.approve(address(i_registrar), params.amount);
        if (success == false) {
            revert Register__approveFailed();
        }
        require(success, "Approve failed");
        uint256 upkeepID = i_registrar.registerUpkeep(params);
        if (upkeepID == 0) {
            revert Register__approveFailed();
        }
    }
}
