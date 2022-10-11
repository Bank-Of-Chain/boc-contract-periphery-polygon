// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Clones } from '@openzeppelin/contracts/proxy/Clones.sol';
import "boc-contract-core/contracts/access-control/AccessControlMixin.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract VaultFactory is AccessControlMixin, ReentrancyGuardUpgradeable{

    /// @notice The implementation contract address of riskOn vault
    address public implementationAddress;
    /// @notice  An array of vault addresses
    IRiskOnVault[] public VaultAddresses;

    // user => wantToken => RiskOnVault
    mapping(address => mapping(address => address)) public vaultAddressMap;

    constructor(address _implementationAddress) {
        implementationAddress = _implementationAddress;
    }

    /// @notice Create new riskOn vault by the clone factory pattern
    /// @param _wantToken The token wanted by this new riskOn vault
    function createNewVault(address _wantToken) public nonReentrant{

        //Creating a new vault contract
        IRiskOnVault newVault = IRiskOnVault(Clones.clone(implementationAddress));

        // since the clone create a proxy, the constructor is redundant and you have to use the initialize function
        newVault.initialize(); 

        //Adding the new vault to our list of vault addresses
        VaultAddresses.push(newVault);

        vaultAddressMap[msg.sender][_wantToken] = address(newVault);
    }
}

interface IRiskOnVault{
    function initialize() external;
}