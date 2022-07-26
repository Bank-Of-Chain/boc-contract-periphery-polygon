// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title IUniswapV2Factory Interface
/// @notice Minimal interface for our interactions with the Uniswap V2's Factory contract
interface IUniswapV2Factory {
    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}
