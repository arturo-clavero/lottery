// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

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
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/// @notice Parameters required to register a Chainlink Automation upkeep
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

/// @notice Interface for Chainlink Automation Registrar
interface AutomationRegistrarInterface {
    /// @notice Registers a new upkeep
    /// @param requestParams Struct containing all registration parameters
    /// @return uint256 The upkeep ID assigned
    function registerUpkeep(RegistrationParams calldata requestParams) external returns (uint256);
}

/// @notice Mock implementation of AutomationRegistrarInterface for testing
contract MockRegistrar is AutomationRegistrarInterface {
    uint256 public upkeepId = 1;

    /// @notice Simulates registration of an upkeep
    /// @param requestParams Ignored in mock
    /// @return uint256 Incremented upkeep ID
    function registerUpkeep(RegistrationParams calldata) external override returns (uint256) {
        upkeepId++;
        return upkeepId;
    }
}

/// @title Contract to approve LINK and register Automation upkeeps
/// @notice Handles LINK approval and calls registrar to register an upkeep
contract Register {
    /// @notice LINK token interface
    LinkTokenInterface public immutable i_link;

    /// @notice Automation registrar interface
    AutomationRegistrarInterface public immutable i_registrar;

    /// @notice Error thrown if LINK approve fails
    error Register__approveFailed();

    /// @param link LINK token address
    /// @param registrar Automation registrar address
    constructor(LinkTokenInterface link, AutomationRegistrarInterface registrar) {
        i_link = link;
        i_registrar = registrar;
    }

    /// @notice Approves LINK and registers an upkeep
    /// @param params Registration parameters
    function registerAndPredictID(RegistrationParams memory params) public {
        bool success = i_link.approve(address(i_registrar), params.amount);
        if (!success) {
            revert Register__approveFailed();
        }

        uint256 upkeepID = i_registrar.registerUpkeep(params);
        if (upkeepID == 0) {
            revert Register__approveFailed();
        }
    }
}
