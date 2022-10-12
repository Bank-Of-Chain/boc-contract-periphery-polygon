// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Clones } from '@openzeppelin/contracts/proxy/Clones.sol';
import "boc-contract-core/contracts/access-control/AccessControlMixin.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import './IUniswapV3RiskOnVaultInitialize.sol';

contract VaultFactory is AccessControlMixin, ReentrancyGuardUpgradeable{

    /// @notice The implementation contract address of RiskOn vault
    address public vaultImplementation;
    /// @notice  An array of vault addresses
    IUniswapV3RiskOnVaultInitialize[] public vaultAddrList;

    // user => wantToken => RiskOnVault
    mapping(address => mapping(address => address)) public vaultAddressMap;

    /// @notice Create New Vault Event
    /// @param _owner The owner of new vault
    /// @param _newVault The new vault created
    /// @param _wantToken The token wanted by this new RiskOn vault
    event CreateNewVault(address indexed _owner,address indexed _newVault,address indexed _wantToken);

    /// @notice constructor
    /// @param _vaultImplementation The implementation contract address
    constructor(address _vaultImplementation) {
        vaultImplementation = _vaultImplementation;
    }

    /// @notice Create new RiskOn vault by the clone factory pattern
    /// @param _wantToken The token wanted by this new RiskOn vault
    /// @param _uniswapV3RiskOnHelper The uniswapV3-RiskOn helper contract
    function createNewVault(address _wantToken, address _uniswapV3RiskOnHelper) public nonReentrant{
        require(vaultAddressMap[msg.sender][_wantToken] == address(0), 'Already created');
        //Creating a new vault contract
        IUniswapV3RiskOnVaultInitialize newVault = IUniswapV3RiskOnVaultInitialize(Clones.clone(vaultImplementation));

        // since the clone create a proxy, the constructor is redundant and you have to use the initialize function
        newVault.initialize(msg.sender, _wantToken, _uniswapV3RiskOnHelper); 

        emit CreateNewVault(msg.sender,address(newVault), _wantToken);

        //Adding the new vault to our list of vault addresses
        vaultAddrList.push(newVault);

        vaultAddressMap[msg.sender][_wantToken] = address(newVault);
    }

    function getVaultsLen() public view returns(uint256){
        return vaultAddrList.length;
    }
}