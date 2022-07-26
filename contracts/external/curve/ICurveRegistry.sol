// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title ICurveRegistry interface
interface ICurveRegistry {
    function get_gauges(address) external view returns (address[10] memory, int128[10] memory);

    function get_lp_token(address) external view returns (address);

    function get_pool_from_lp_token(address) external view returns (address);
}
