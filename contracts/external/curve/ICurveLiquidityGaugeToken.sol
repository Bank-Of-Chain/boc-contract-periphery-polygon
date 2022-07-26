// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title ICurveLiquidityGaugeToken interface
/// @notice Common interface functions for all Curve liquidity gauge token contracts
interface ICurveLiquidityGaugeToken {
    function lp_token() external view returns (address);
}
