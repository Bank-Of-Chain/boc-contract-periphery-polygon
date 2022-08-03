// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UniswapV3BaseStrategy.sol';

contract UniswapV3UsdcUsdt500Strategy is UniswapV3BaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(
            _vault,
            _harvester,
            // https://info.uniswap.org/#/polygon/pools/0x3f5228d0e7d75467366be7de2c31d0d098ba2c23
            address(0x3F5228d0e7D75467366be7De2c31D0d098bA2C23),
            10,
            10,
            41400,
            0,
            100,
            60
        );
    }

    function name() public pure override returns (string memory) {
        return 'UniswapV3UsdcUsdt500Strategy';
    }

    function getTickSpacing() override internal pure returns (int24){
        return 10;
    }
}
