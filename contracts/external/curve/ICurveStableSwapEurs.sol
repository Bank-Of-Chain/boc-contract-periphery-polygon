// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title ICurveStableSwapEurs interface
interface ICurveStableSwapEurs {
    function add_liquidity(uint256[2] calldata, uint256) external returns (uint256);

    function remove_liquidity(uint256, uint256[2] calldata) external returns (uint256[2] memory);

    function remove_liquidity_one_coin(
        uint256,
        int128,
        uint256
    ) external returns (uint256);
}