// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Clones } from '@openzeppelin/contracts/proxy/Clones.sol';
import "boc-contract-core/contracts/access-control/AccessControlMixin.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import './IUniswapV3RiskOnVaultInitialize.sol';
import "boc-contract-core/contracts/library/BocRoles.sol";

contract VaultFactory is AccessControlMixin, ReentrancyGuardUpgradeable{

    address public constant WETH_ADDRESS = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address public constant USDC_ADDRESS = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    /// @notice The address list of vault implementation contract
    address[] public vaultImplList;

    // @notice key is vaultImpl and value is an index of vaultImplList
    mapping(address => uint256) public vaultImpl2Index;

    /// @notice The total vault list
    IUniswapV3RiskOnVaultInitialize[] public totalVaultAddrList;

    /// @notice key is user and vault impl address, and value is a vault address list
    // user1 => UniswapV3UsdcWeth500RiskOnVault（基础合约地址） => VaultList[2] == [wethVault,usdcVault]
    mapping(address => mapping(address => address[2])) public vaultAddressMap;

    /// @param _owner The owner of new vault
    /// @param _newVault The new vault created
    /// @param _wantToken The token wanted by this new  vault
    event CreateNewVault(address indexed _owner,address indexed _newVault,address indexed _wantToken);

    /// @notice constructor
    /// @param _vaultImplList The address list of implementation contract 
    constructor(
        address[] memory _vaultImplList,
        address _accessControlProxy
    ){
        _initAccessControl(_accessControlProxy);

        for(uint256 i = 0; i < _vaultImplList.length; i++) {
            vaultImplList.push(_vaultImplList[i]);
            vaultImpl2Index[_vaultImplList[i]] = vaultImplList.length;

        }
    }

    /// @notice Create new vault by the clone factory pattern
    /// @param _wantToken The token wanted by this new vault
    /// @param _uniswapV3RiskOnHelper The uniswapV3-RiskOn helper contract
    /// @param _vaultImpl The vault implementation to create new vault proxy
    function createNewVault(address _wantToken, address _uniswapV3RiskOnHelper, address _vaultImpl)  public nonReentrant{
        require(_wantToken == WETH_ADDRESS || _wantToken == USDC_ADDRESS,'The wantToken is not WETH or USDC');
        require(vaultImpl2Index[_vaultImpl] > 0,'Vault Impl is invalid');
        uint256 index = 0;
        if(_wantToken == USDC_ADDRESS) index = 1;
        require(vaultAddressMap[msg.sender][_vaultImpl][index] == address(0), 'Already created');
        
        //Creating a new vault contract
        IUniswapV3RiskOnVaultInitialize newVault = IUniswapV3RiskOnVaultInitialize(Clones.clone(_vaultImpl));

        // since the clone create a proxy, the constructor is redundant and you have to use the initialize function
        newVault.initialize(msg.sender, _wantToken, _uniswapV3RiskOnHelper); 

        emit CreateNewVault(msg.sender,address(newVault), _wantToken);

        //Add the new vault to total vault list
        totalVaultAddrList.push(newVault);

        //Add the new vault to user vault list 
        vaultAddressMap[msg.sender][_vaultImpl][index] = address(newVault);
    }

    /// @notice Add new vault implementation
    /// @param _vaultImpl The new vault implementation
    function addVaultImpl(address _vaultImpl) external onlyRole(BocRoles.GOV_ROLE){
        require(vaultImpl2Index[_vaultImpl] == 0,'Vault Impl existed');
        vaultImplList.push(_vaultImpl);
        vaultImpl2Index[_vaultImpl] = vaultImplList.length;
    }

    function getVaultsLen() public view returns(uint256){
        return totalVaultAddrList.length;
    }

    function getVaultImplList() external view returns(address[] memory) {
        return vaultImplList;
    } 
}