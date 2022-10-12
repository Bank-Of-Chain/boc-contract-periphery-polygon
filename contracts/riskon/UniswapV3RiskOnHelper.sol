// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';
import "boc-contract-core/contracts/access-control/AccessControlMixin.sol";
import "./../external/uniswap/IUniswapV3.sol";
import './../external/uniswapv3/INonfungiblePositionManager.sol';
import './../external/uniswapv3/libraries/LiquidityAmounts.sol';
import './../enums/ProtocolEnum.sol';
import 'hardhat/console.sol';
import "../utils/actions/AaveLendActionMixin.sol";
import "../utils/actions/UniswapV3LiquidityActionsMixin.sol";
import "../external/aave/ILendingPoolAddressesProvider.sol";
import "../external/aave/IPriceOracleGetter.sol";
import "../../library/RiskOnConstant.sol";

/// @title UniswapV3RiskOnHelper
/// @author Bank of Chain Protocol Inc
contract UniswapV3RiskOnHelper {

    /// @notice Gets the specifie ranges of `_tick`
    /// @param _tick The input number of tick
    /// @param _tickSpacing The tick spacing
    /// @param _baseThreshold The base threshold
    /// @return _tickFloor The nearest tick which LTE `_tick`
    /// @return _tickCeil The nearest tick which GTE `_tick`
    /// @return _tickLower  `_tickFloor` subtrace `baseThreshold`
    /// @return _tickUpper  `_tickFloor` add `baseThreshold`
    function getSpecifiedRangesOfTick(int24 _tick, int24 _tickSpacing, int24 _baseThreshold) public view returns (int24 _tickFloor, int24 _tickCeil, int24 _tickLower, int24 _tickUpper) {
        int24 _compressed = _tick / _tickSpacing;
        if (_tick < 0 && _tick % _tickSpacing != 0) _compressed--;
        _tickFloor = _compressed * _tickSpacing;
        _tickCeil = _tickFloor + _tickSpacing;
        _tickLower = _tickFloor - _baseThreshold;
        _tickUpper = _tickCeil + _baseThreshold;
    }

    function borrowInfo(address _user) public view returns (
        uint256 _totalCollateralETH,
        uint256 _totalDebtETH,
        uint256 _availableBorrowsETH,
        uint256 _currentLiquidationThreshold,
        uint256 _ltv,
        uint256 _healthFactor
    )
    {
        return ILendingPool(RiskOnConstant.LENDING_POOL).getUserAccountData(_user);
    }

    function getAToken(address _asset) public view returns (address) {
        return ILendingPool(RiskOnConstant.LENDING_POOL).getReserveData(_asset).aTokenAddress;
    }

    function getDebtToken(address _borrowToken, uint256 _interestRateMode) public view returns (address) {
        console.log('----------------getDebtToken _borrowToken: %s, _interestRateMode: %d', _borrowToken, _interestRateMode);
        DataTypes.ReserveData memory reserveData = ILendingPool(RiskOnConstant.LENDING_POOL).getReserveData(_borrowToken);

        console.log('----------------reserveData reserveData.stableDebtTokenAddress: %s, reserveData.variableDebtTokenAddress: %s', reserveData.stableDebtTokenAddress, reserveData.variableDebtTokenAddress);

        if (_interestRateMode == 1) {
            return reserveData.stableDebtTokenAddress;
        } else {
            return reserveData.variableDebtTokenAddress;
        }
    }

    function getCurrentBorrow(address _borrowToken, uint256 _interestRateMode, address _account) public view returns (uint256) {
        return IERC20(getDebtToken(_borrowToken, _interestRateMode)).balanceOf(_account);
    }
}
