// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UniswapV3BaseStrategy.sol';

contract UniswapV3DaiUsdc500Strategy is UniswapV3BaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(
            _vault,
            _harvester,
            // https://info.uniswap.org/#/polygon/pools/0x5f69c2ec01c22843f8273838d570243fd1963014
            address(0x5f69C2ec01c22843f8273838d570243fd1963014),
            10,
            10,
            41400,
            0,
            100,
            60
        );
    }

    function name() public pure override returns (string memory) {
        return 'UniswapV3DaiUsdc500Strategy';
    }

    function getTickSpacing() override internal pure returns (int24){
        return 10;
    }
}
