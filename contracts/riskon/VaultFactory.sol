// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Clones } from '@openzeppelin/contracts/proxy/Clones.sol';
import 'boc-contract-core/contracts/access-control/AccessControlMixin.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import './IUniswapV3RiskOnVaultInitialize.sol';
import './IUniswapV3RiskOnVault.sol';
import 'boc-contract-core/contracts/library/BocRoles.sol';
import '../../library/RiskOnConstant.sol';

contract VaultFactory is Initializable, AccessControlMixin, ReentrancyGuardUpgradeable{

    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// @notice The address list of vault implementation contract
    address[] public vaultImplList;

    address public uniswapV3RiskOnHelper;

    address public treasury;

    // @notice key is vaultImpl and value is an index of vaultImplList
    mapping(address => uint256) public vaultImpl2Index;

    /// @notice The total vault list
    IUniswapV3RiskOnVaultInitialize[] public totalVaultAddrList;

    /// @notice key is user and vault impl address, and value is a vault address list
    // user => vault implementation contract address => VaultList[2] == [wethVault,stablecoinVault]
    mapping(address => mapping(address => address[2])) public vaultAddressMap;

    EnumerableSetUpgradeable.AddressSet internal wethInvestorSet;
    EnumerableSetUpgradeable.AddressSet internal stablecoinInvestorSet;

    /// @param _owner The owner of new vault
    /// @param _newVault The new vault created
    /// @param _wantToken The token wanted by this new  vault
    event CreateNewVault(address indexed _owner,address indexed _newVault,address indexed _wantToken);

    /// @notice constructor
    /// @param _vaultImplList The address list of implementation contract 
    /// @param _accessControlProxy The address of access control proxy contract
    /// @param _uniswapV3RiskOnHelper The address of 'UniswapV3RiskOnHelper' contract
    /// @param _treasury The address of Treasury
    function initialize(
        address[] memory _vaultImplList,
        address _accessControlProxy,
        address _uniswapV3RiskOnHelper,
        address _treasury
    ) public initializer {
        _initAccessControl(_accessControlProxy);

        for(uint256 i = 0; i < _vaultImplList.length; i++) {
            vaultImplList.push(_vaultImplList[i]);
            vaultImpl2Index[_vaultImplList[i]] = vaultImplList.length;
        }

        uniswapV3RiskOnHelper = _uniswapV3RiskOnHelper;
        treasury = _treasury;
    }

    receive() external payable {}

    fallback() external payable {}

    /// @notice Create new vault by the clone factory pattern
    /// @param _wantToken The token wanted by this new vault
    /// @param _vaultImpl The vault implementation to create new vault proxy
    function createNewVault(address _wantToken, address _vaultImpl) public nonReentrant{
        
        require(
            _wantToken == IUniswapV3RiskOnVault(_vaultImpl).token0() || 
            _wantToken == IUniswapV3RiskOnVault(_vaultImpl).token1(),
            'The wantToken is not WETH or stablecoin'
        );
        require(vaultImpl2Index[_vaultImpl] > 0,'Vault Impl is invalid');
        uint256 _index = 0;
        if(_wantToken != RiskOnConstant.WETH) _index = 1;
        require(vaultAddressMap[msg.sender][_vaultImpl][_index] == address(0), 'Already created');

        //Creating a new vault contract
        IUniswapV3RiskOnVaultInitialize newVault = IUniswapV3RiskOnVaultInitialize(Clones.clone(_vaultImpl));

        // since the clone create a proxy, the constructor is redundant and you have to use the initialize function
        newVault.initialize(msg.sender, _wantToken, uniswapV3RiskOnHelper, treasury, address(accessControlProxy));

        emit CreateNewVault(msg.sender, address(newVault), _wantToken);

        //Add the new vault to total vault list
        totalVaultAddrList.push(newVault);

        if(_index == 0) {
            if(!wethInvestorSet.contains(msg.sender)) wethInvestorSet.add(msg.sender);
        }else {//_index == 1
            if(!stablecoinInvestorSet.contains(msg.sender)) stablecoinInvestorSet.add(msg.sender);
        }

        //Add the new vault to user vault list 
        vaultAddressMap[msg.sender][_vaultImpl][_index] = address(newVault);
    }

    /// @notice Add new vault implementation
    /// @param _vaultImpl The new vault implementation
    function addVaultImpl(address _vaultImpl) external onlyRole(BocRoles.GOV_ROLE){
        require(vaultImpl2Index[_vaultImpl] == 0,'Vault Impl existed');
        vaultImplList.push(_vaultImpl);
        vaultImpl2Index[_vaultImpl] = vaultImplList.length;
    }

    /// @notice Gets the length of `totalVaultAddrList`
    function getVaultsLen() external view returns(uint256){
        return totalVaultAddrList.length;
    }

    /// @notice Gets the address list  of vault implementations
    function getVaultImplList() external view returns(address[] memory) {
        return vaultImplList;
    }

    /// @notice Gets all address list of vaults created
    function getTotalVaultAddrList() external view returns(IUniswapV3RiskOnVaultInitialize[] memory) {
        return totalVaultAddrList;
    }

    /// @notice Gets two address list of weth investors and usd investors
    function getTwoInvestorlist() external view returns(address[] memory _wethInvestorSet,address[] memory _usdInvestorSet){
        _wethInvestorSet = wethInvestorSet.values();
        _usdInvestorSet = stablecoinInvestorSet.values();
    }

    /// @notice Gets two length of weth investor list and usd investor list
    function getTwoInvestorlistLen() external view returns(uint256 _wethInvestorSetLen,uint256 _stablecoinInvestorSetLen){
        _wethInvestorSetLen = wethInvestorSet.length();
        _stablecoinInvestorSetLen = stablecoinInvestorSet.length();
    }

    /// @notice Gets one WETH investor by `_index`
    /// @param _index The index of return investor on `wethInvestorSet`
    /// @return The investor address
    function getWethInvestorByIndex(uint256 _index) external view returns(address) {
        return wethInvestorSet.at(_index);
    }

    /// @notice Gets one stablecoin investor by `_index`
    /// @param _index The index of return investor on `stablecoinInvestorSet`
    /// @return The investor address
    function getStablecoinInvestorByIndex(uint256 _index) external view returns(address) {
        return stablecoinInvestorSet.at(_index);
    }

    /// @notice Only for test.
    ///         To be deleted before merge to master branch
    function deleteVaultAddressMapForDebug(address _user, address _vaultImpl, uint256 _index) external {
        //delete vaultAddressMap fro debug 
        delete vaultAddressMap[_user][_vaultImpl][_index];
    }
}
