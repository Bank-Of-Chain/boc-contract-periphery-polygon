// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UniswapV3RiskOnVault.sol';

contract UniswapV3UsdcWeth500RiskOnVault is UniswapV3RiskOnVault {
    function initialize(address _owner, address _wantToken, address _uniswapV3RiskOnHelper, address _valueInterpreter) public initializer {
        super._initialize(
            _owner,
            'UniswapV3UsdcWeth500',
            _wantToken,
        // https://info.uniswap.org/#/polygon/pools/0x45dda9cb7c25131df268515131f647d726f50608
            address(0x45dDa9cb7c25131DF268515131f647d726f50608),
            _uniswapV3RiskOnHelper,
            _valueInterpreter,
            3600,
            1200,
        // ~12 hours
            41400,
            0,
        // 1%
            100,
        // 60 seconds
            60,
            10
        );
    }
}
