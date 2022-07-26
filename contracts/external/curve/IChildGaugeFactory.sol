// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/// @title ChildGaugeFactory interface
interface IChildGaugeFactory {
    function mint(address _gauge) external;
}
