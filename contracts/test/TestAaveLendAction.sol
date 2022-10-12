// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.
    (c) Enzyme Council <council@enzyme.finance>
    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/actions/AaveLendActionMixin.sol";

contract TestAaveLendAction is AaveLendActionMixin {
    constructor(
        uint256 _interestRateMode,
        address _collateralToken,
        address _borrowToken
    ) {
        __initLendConfigation(_interestRateMode, _collateralToken, _borrowToken);
    }

    receive() external payable {}

    fallback() external payable {}

    function addCollateral(uint256 _collateralAmount) external payable {
        IERC20(collateralToken).transferFrom(msg.sender, address(this), _collateralAmount);
        __addCollateral(_collateralAmount);
    }

    function removeCollateral(uint256 _collateralAmount) external {
        __removeCollateral(getAToken(collateralToken), _collateralAmount);
    }

    function borrow(uint256 _borrowAmount) external {
        __borrow(_borrowAmount);
    }

    function repay(uint256 _repayAmount) external {
        __repay(_repayAmount);
    }
}
