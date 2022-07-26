// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./QuickswapBaseStrategy.sol";

contract QuickswapUsdcUsdtStrategy is QuickswapBaseStrategy {
    address public constant pair = address(0x2cF7252e74036d1Da831d11089D326296e64a728);
    address public constant stakingPool = address(0xAFB76771C98351Aa7fCA13B130c9972181612b54);

    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(_vault, _harvester, pair, stakingPool);
    }

    function name() public pure override returns (string memory) {
        return "QuickswapUsdcUsdtStrategy";
    }
}
