// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import 'boc-contract-core/contracts/access-control/AccessControlMixin.sol';
import 'boc-contract-core/contracts/library/BocRoles.sol';
import '../../library/RiskOnConstant.sol';
import './../external/uniswap/IUniswapV3.sol';
import './ITreasury.sol';
import '../external/riskon/IWMATIC.sol';

/// @title Treasury
/// @notice Treasury contract mainly used to keep the portion of profit transfered to treasury
/// @author Bank of Chain Protocol Inc
contract Treasury is
    ITreasury,
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlMixin
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // vault => token => total manage fee amount
    mapping(address => mapping(address => uint256)) public accManageFee;

    // vault => token => accumulate profitAmount
    mapping(address => mapping(address => uint256)) public accVaultProfit;

    // token => bool
    mapping(address => bool) public isReceivableToken;

    /// @notice The flag of taking profit
    bool public takeProfitFlag;

    /// @notice The keeper to receive manage fee
    address payable public keeper;

    /// @notice The total Matic amount transfered to keeper
    uint256 public totalManageFeeInMatic2Keeper;

    /// @param _vault The vault with profits
    /// @param _token The fee token
    /// @param _feeAmount The fee amount
    event ReceiveManageFee(address indexed _vault, address indexed _token, uint256 _feeAmount);
    
    /// @param _vault The vault with profits
    /// @param _token The profit token
    /// @param _profitAmount The profit amount
    event ReceiveProfit(address indexed _vault, address indexed _token, uint256 _profitAmount);

    /// @param _newFlag The new flag
    event TakeProfitFlagChanged(bool _newFlag);

    /// @param _token The token set
    /// @param _newBool The new bool value
    event ReceiveTokenChanged(address indexed _token, bool _newBool);

    /// @notice Initialize
    /// @param _accessControlProxy The access control proxy address
    /// @param _weth The WETH address
    /// @param _usdc The USDC address
    function initialize(
        address _accessControlProxy, 
        address _weth, 
        address _usdc,
        address payable _keeper
    ) public initializer {
        isReceivableToken[_weth]= true;
        isReceivableToken[_usdc]= true;
        keeper = _keeper;
        _initAccessControl(_accessControlProxy);
    }

    receive() external payable {}

    fallback() external payable {}

    /// @notice Return the current version of this contract.
    function version() public pure returns (string memory) {
        return 'V1.0.0';
    }

    /// @inheritdoc ITreasury
    function balance(address _token) public view override returns (uint256) {
        return IERC20Upgradeable(_token).balanceOf(address(this));
    }

    /// Requirements: only keeper role can call
    /// @inheritdoc ITreasury
    function withdrawToken(
        address _token,
        address _receiver,
        uint256 _amount
    ) external override onlyRole(BocRoles.KEEPER_ROLE) {
        require(_amount <= balance(_token), '!insufficient');
        IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
    }

    /// Requirements: only keeper role can call
    /// @inheritdoc ITreasury
    function withdrawETH(address payable _receiver, uint256 _amount)
        external
        payable
        override
        nonReentrant
        onlyRole(BocRoles.KEEPER_ROLE)
    {
        require(_amount <= address(this).balance, '!insufficient');
        _receiver.transfer(_amount);
    }

    /// @inheritdoc ITreasury
    function receiveManageFeeFromVault(address _token, uint256 _feeAmount) external override{
        require(isReceivableToken[_token],'Not receivable token');

        if (_feeAmount > 0) {
            // receive manage fee
            IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _feeAmount);
            accManageFee[msg.sender][_token] += _feeAmount;
            emit ReceiveManageFee(msg.sender, _token, _feeAmount);

            // swap from `_token` to Matic, the recipient is keeper
            IERC20Upgradeable(_token).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, 0);
            IERC20Upgradeable(_token).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, _feeAmount);
            uint256 amountOutMatic = IUniswapV3(RiskOnConstant.UNISWAP_V3_ROUTER).exactInputSingle(
                IUniswapV3.ExactInputSingleParams(
                    _token, 
                    RiskOnConstant.WMATIC, 
                    500, // fee
                    address(this), 
                    block.timestamp, 
                    _feeAmount, 
                    0, 
                    0
                )
            );
            totalManageFeeInMatic2Keeper += amountOutMatic;

            // withdraw wmatic to matic, then transfer matic to keeper
            IWMATIC(RiskOnConstant.WMATIC).withdraw(amountOutMatic);
            keeper.transfer(amountOutMatic);
        }
    }
    
    /// @inheritdoc ITreasury
    function receiveProfitFromVault(address _token, uint256 _profitAmount) external override {
        require(isReceivableToken[_token],'Not receivable token');
        if(takeProfitFlag) {
            IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _profitAmount);
            accVaultProfit[msg.sender][_token] += _profitAmount;
            emit ReceiveProfit(msg.sender, _token, _profitAmount); 
        }
    }

    /// Requirements: only governance role can call
    /// @inheritdoc ITreasury
    function setTakeProfitFlag (bool _newFlag) external override onlyRole(BocRoles.GOV_ROLE){
        takeProfitFlag = _newFlag;
        emit TakeProfitFlagChanged(_newFlag);
    }

    /// @notice Sets `_token` is receivable token or not
    /// @param _token The token set
    /// @param _newBool The new bool value
    /// Requirements: only governance role can call
    function setIsReceivableToken(address _token, bool _newBool) external onlyRole(BocRoles.GOV_ROLE) {
        isReceivableToken[_token] = _newBool;
        emit ReceiveTokenChanged(_token, _newBool);
    }

}
