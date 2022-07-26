// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./AaveBaseStrategy.sol";

contract AaveUsdcStrategy is AaveBaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(
            _vault,
            _harvester,
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, //USDC
            0x1a13F4Ca1d028320A707D99520AbFefca3998b7F, //AToken
            0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf, //lendingPool
            0x357D51124f59836DeD84c8a1730D72B749d8BC23
        ); //IncentivesController
    }

    function name() public pure override returns (string memory) {
        return "AaveUsdcStrategy";
    }
}
