// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV3RiskOnVaultInitialize {
    
    function initialize(address _owner, address _wantToken, address _uniswapV3RiskOnHelper) external;
}
