// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./SushiPairBaseStrategy.sol";

contract SushiUsdcDaiStrategy is SushiPairBaseStrategy {
    address private constant PAIR = address(0xCD578F016888B57F1b1e3f887f392F0159E26747);
    uint256 public constant POOL_ID = 11;

    function initialize(address _vault, address _harvster) public initializer {
        super._initialize(_vault, _harvster, POOL_ID, PAIR);
    }

    function name() public pure override returns (string memory) {
        return "SushiUsdcDaiStrategy";
    }
}
