// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./SushiPairBaseStrategy.sol";

contract SushiUsdcUsdtStrategy is SushiPairBaseStrategy {
    address private constant PAIR = address(0x4B1F1e2435A9C96f7330FAea190Ef6A7C8D70001);
    uint256 public constant POOL_ID = 8;

    function initialize(address _vault, address _harvster) public initializer {
        super._initialize(_vault, _harvster, POOL_ID, PAIR);
    }

    function name() public pure override returns (string memory) {
        return "SushiUsdcUsdtStrategy";
    }
}
