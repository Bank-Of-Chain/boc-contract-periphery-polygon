// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UniswapV3RiskOnVaultInitialize{

    address public owner;

    function initialize(address _owner, address _wantToken, address _uniswapV3RiskOnHelper) public {
        require(owner == address(0), "already initialized");
        owner = _owner;
    }

    function welcomeCrew() public pure returns (string memory _greeting) {
        return "Welcome to the truth...";
    }
}