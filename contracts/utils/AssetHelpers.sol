// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title AssetHelpers Contract
/// @notice A util contract for common token actions
abstract contract AssetHelpers {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Helper to approve a target account with the max amount of an asset.
    /// This is helpful for fully trusted contracts, such as adapters that
    /// interact with external protocol like Uniswap, Compound, etc.
    function __approveAssetMaxAsNeeded(
        address _asset,
        address _target,
        uint256 _neededAmount
    ) internal {
        if (IERC20Upgradeable(_asset).allowance(address(this), _target) < _neededAmount) {
            IERC20Upgradeable(_asset).safeApprove(_target, type(uint256).max);
        }
    }

    /// @dev Helper to get the balances of specified assets for a target
    function __getAssetBalances(address _target, address[] memory _assets)
        internal
        view
        returns (uint256[] memory balances_)
    {
        balances_ = new uint256[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            balances_[i] = IERC20Upgradeable(_assets[i]).balanceOf(_target);
        }

        return balances_;
    }

    /// @dev Helper to transfer full asset balances from a target to the current contract.
    /// Requires an adequate allowance for each asset granted to the current contract for the target.
    function __pullFullAssetBalances(address _target, address[] memory _assets)
        internal
        returns (uint256[] memory amountsTransferred_)
    {
        amountsTransferred_ = new uint256[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            IERC20Upgradeable assetContract = IERC20Upgradeable(_assets[i]);
            amountsTransferred_[i] = assetContract.balanceOf(_target);
            if (amountsTransferred_[i] > 0) {
                assetContract.safeTransferFrom(_target, address(this), amountsTransferred_[i]);
            }
        }

        return amountsTransferred_;
    }

    /// @dev Helper to transfer partial asset balances from a target to the current contract.
    /// Requires an adequate allowance for each asset granted to the current contract for the target.
    function __pullPartialAssetBalances(
        address _target,
        address[] memory _assets,
        uint256[] memory _amountsToExclude
    ) internal returns (uint256[] memory amountsTransferred_) {
        amountsTransferred_ = new uint256[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            IERC20Upgradeable assetContract = IERC20Upgradeable(_assets[i]);
            amountsTransferred_[i] = assetContract.balanceOf(_target) - _amountsToExclude[i];
            if (amountsTransferred_[i] > 0) {
                assetContract.safeTransferFrom(_target, address(this), amountsTransferred_[i]);
            }
        }

        return amountsTransferred_;
    }

    /// @dev Helper to transfer full asset balances from the current contract to a target
    function __pushFullAssetBalances(address _target, address[] memory _assets)
        internal
        returns (uint256[] memory amountsTransferred_)
    {
        amountsTransferred_ = new uint256[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            IERC20Upgradeable assetContract = IERC20Upgradeable(_assets[i]);
            amountsTransferred_[i] = assetContract.balanceOf(address(this));
            if (amountsTransferred_[i] > 0) {
                assetContract.safeTransfer(_target, amountsTransferred_[i]);
            }
        }

        return amountsTransferred_;
    }
}
