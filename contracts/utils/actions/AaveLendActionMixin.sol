// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../external/aave/ILendingPool.sol";
import "../../external/aave/IWETHGateway.sol";
import "../../external/aave/IAToken.sol";
import {DataTypes} from "../../external/aave/DataTypes.sol";

import "hardhat/console.sol";

abstract contract AaveLendActionMixin {
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // aave lending pool address
    address internal constant LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    // native token gateway
    address internal constant WETH_GATEWAY = 0xEFFC18fC3b7eb8E676dac549E0c693ad50D1Ce31;
    //interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
    uint256 internal interestRateMode;

    address internal collateralToken;
    address internal borrowToken;

    // address internal aBorrowToken;

    function borrowInfo()
    public
    view
    returns (
        uint256 _totalCollateralETH,
        uint256 _totalDebtETH,
        uint256 _availableBorrowsETH,
        uint256 _currentLiquidationThreshold,
        uint256 _ltv,
        uint256 _healthFactor
    )
    {
        return ILendingPool(LENDING_POOL).getUserAccountData(address(this));
    }

    function getAToken(address _asset) public view returns (address) {
        if (_asset == NATIVE_TOKEN) {
            _asset = WETH;
        }
        return ILendingPool(LENDING_POOL).getReserveData(_asset).aTokenAddress;
    }

    function getDebtToken() public view returns (address) {
        address _borrowToken = borrowToken;
        if (_borrowToken == NATIVE_TOKEN) {
            _borrowToken = WETH;
        }
        DataTypes.ReserveData memory reserveData = ILendingPool(LENDING_POOL).getReserveData(_borrowToken);
        if (interestRateMode == 1) {
            return reserveData.stableDebtTokenAddress;
        } else if (interestRateMode == 2) {
            return reserveData.variableDebtTokenAddress;
        }
    }

    function getCurrentBorrow() public view returns (uint256) {
        return IERC20(getDebtToken()).balanceOf(address(this));
    }

    function __initLendConfigation(
        uint256 _interestRateMode,
        address _collateralToken,
        address _borrowToken
    ) internal {
        require(
            _interestRateMode == 1 || _interestRateMode == 2,
            "Invalid interest rate parameter"
        );
        interestRateMode = _interestRateMode;
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
    }

    function __addCollateral(uint256 _collateralAmount) internal {
        // saving gas
        address _collateralToken = collateralToken;
        if (_collateralToken == NATIVE_TOKEN) {
            IWETHGateway(WETH_GATEWAY).depositETH{value : _collateralAmount}(LENDING_POOL, address(this), 0);
        } else {
            IERC20(_collateralToken).approve(LENDING_POOL, _collateralAmount);
            ILendingPool(LENDING_POOL).deposit(_collateralToken, _collateralAmount, address(this), 0);
        }
    }

    function __removeCollateral(uint256 _collateralAmount) internal {
        // saving gas
        address _collateralToken = collateralToken;
        address _aCollateralToken = getAToken(_collateralToken);
        if (_collateralToken == NATIVE_TOKEN) {
            IERC20(_aCollateralToken).approve(WETH_GATEWAY, _collateralAmount);
            IWETHGateway(WETH_GATEWAY).withdrawETH(
                LENDING_POOL,
                _collateralAmount,
                address(this)
            );
        } else {
            IERC20(_aCollateralToken).approve(LENDING_POOL, _collateralAmount);
            ILendingPool(LENDING_POOL).withdraw(
                _collateralToken,
                _collateralAmount,
                address(this)
            );
        }
    }

    function __borrow(uint256 _borrowAmount) internal {
        if (borrowToken == NATIVE_TOKEN) {
            IWETHGateway(WETH_GATEWAY).borrowETH(LENDING_POOL, _borrowAmount, interestRateMode, 0);
        } else {
            ILendingPool(LENDING_POOL).borrow(
                borrowToken,
                _borrowAmount,
                interestRateMode,
                0,
                address(this)
            );
        }
    }

    function __repay(uint256 _repayAmount) internal {
        if (borrowToken == NATIVE_TOKEN) {
            IERC20(WETH).approve(LENDING_POOL, _repayAmount);
            IWETHGateway(WETH_GATEWAY).repayETH(
                LENDING_POOL,
                _repayAmount,
                interestRateMode,
                address(this)
            );
        } else {
            IERC20(borrowToken).approve(LENDING_POOL, _repayAmount);
            ILendingPool(LENDING_POOL).repay(
                borrowToken,
                _repayAmount,
                interestRateMode,
                address(this)
            );
        }
    }
}
