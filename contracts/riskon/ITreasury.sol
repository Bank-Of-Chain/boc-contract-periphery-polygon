// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import 'boc-contract-core/contracts/access-control/AccessControlMixin.sol';
import 'boc-contract-core/contracts/library/BocRoles.sol';

/// @title ITreasury
/// @author Bank of Chain Protocol Inc
interface ITreasury {

    /// @notice Return the '_token' balance of this contract.
    function balance(address _token) external view returns (uint256);

    /// @notice Withdraw '_amount' '_token' from this contract to '_receiver'
    /// @param _token The token to withdraw
    /// @param _receiver The receiver address to withdraw`
    /// @param _amount The amount of token to withdraw
    /// Requirements: only governance role can call
    function withdrawToken(
        address _token,
        address _receiver,
        uint256 _amount
    ) external;

    /// @notice Withdraw ETH from this contract to '_receiver'
    /// @param _receiver The receiver address to withdraw
    /// @param _amount The amount of ETH to withdraw
    /// Requirements: only governance role can call
    function withdrawETH(address payable _receiver, uint256 _amount) external payable;

    /// @notice take 20% profit
    function receiveProfitFromVault(address _token, uint256 _profitAmount) external;

    /// @notice Sets 'takeProfitFlag'
    function setTakeProfitFlag (bool _newFlag) external;

}
