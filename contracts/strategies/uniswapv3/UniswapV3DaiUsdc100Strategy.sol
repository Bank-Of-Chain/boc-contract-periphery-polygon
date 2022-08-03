// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UniswapV3BaseStrategy.sol';

contract UniswapV3DaiUsdc100Strategy is UniswapV3BaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(
            _vault,
            _harvester,
            // https://info.uniswap.org/#/polygon/pools/0x5645dcb64c059aa11212707fbf4e7f984440a8cf
            address(0x5645dCB64c059aa11212707fbf4E7F984440a8Cf),
            5,
            2,
            41400,
            0,
            100,
            60
        );
    }

    function name() public pure override returns (string memory) {
        return 'UniswapV3DaiUsdc100Strategy';
    }

    function getTickSpacing() override internal pure returns (int24){
        return 1;
    }
}
