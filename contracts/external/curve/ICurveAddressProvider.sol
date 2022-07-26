// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title ICurveAddressProvider interface
interface ICurveAddressProvider {
    function get_address(uint256) external view returns (address);

    function get_registry() external view returns (address);
}
