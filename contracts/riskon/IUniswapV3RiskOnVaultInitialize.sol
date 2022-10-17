// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV3RiskOnVaultInitialize {

    /// @notice Initialize variables of this vault
    function initialize(address _owner, address _wantToken, address _uniswapV3RiskOnHelper, address _treasury, address _accessControlProxy) external;
}
