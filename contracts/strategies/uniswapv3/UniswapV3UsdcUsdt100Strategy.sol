// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UniswapV3BaseStrategy.sol';

contract UniswapV3UsdcUsdt100Strategy is UniswapV3BaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(
            _vault,
            _harvester,
            // https://info.uniswap.org/#/polygon/pools/0xdac8a8e6dbf8c690ec6815e0ff03491b2770255d
            address(0xDaC8A8E6DBf8c690ec6815e0fF03491B2770255D),
            5,
            2,
            41400,
            0,
            100,
            60
        );
    }

    function name() public pure override returns (string memory) {
        return 'UniswapV3UsdcUsdt100Strategy';
    }

    function getTickSpacing() override internal pure returns (int24){
        return 1;
    }
}
