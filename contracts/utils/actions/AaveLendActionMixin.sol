// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../external/aave/ILendingPool.sol";
import "../../external/aave/IWETHGateway.sol";
import "../../external/aave/IAToken.sol";
import {DataTypes} from "../../external/aave/DataTypes.sol";

import "hardhat/console.sol";

abstract contract AaveLendActionMixin {
    // aave lending pool address
    address internal constant LENDING_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    //interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
    uint256 internal interestRateMode;
    address internal collateralToken;
    address public borrowToken;

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
        return ILendingPool(LENDING_POOL).getReserveData(_asset).aTokenAddress;
    }

    function getDebtToken() public view returns (address) {
        address _borrowToken = borrowToken;
        DataTypes.ReserveData memory reserveData = ILendingPool(LENDING_POOL).getReserveData(_borrowToken);
        if (interestRateMode == 1) {
            return reserveData.stableDebtTokenAddress;
        } else {
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
        IERC20(collateralToken).approve(LENDING_POOL, _collateralAmount);
        ILendingPool(LENDING_POOL).deposit(collateralToken, _collateralAmount, address(this), 0);
    }

    function __removeCollateral(address _aCollateralToken, uint256 _collateralAmount) internal {
        IERC20(_aCollateralToken).approve(LENDING_POOL, _collateralAmount);
        ILendingPool(LENDING_POOL).withdraw(
            collateralToken,
            _collateralAmount,
            address(this)
        );
    }

    function __borrow(uint256 _borrowAmount) internal {
        ILendingPool(LENDING_POOL).borrow(
            borrowToken,
            _borrowAmount,
            interestRateMode,
            0,
            address(this)
        );
    }

    function __repay(uint256 _repayAmount) internal {
        IERC20(borrowToken).approve(LENDING_POOL, _repayAmount);
        ILendingPool(LENDING_POOL).repay(
            borrowToken,
            _repayAmount,
            interestRateMode,
            address(this)
        );
    }
}