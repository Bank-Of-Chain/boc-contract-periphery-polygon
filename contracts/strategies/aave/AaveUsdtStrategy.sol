// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./AaveBaseStrategy.sol";

contract AaveUsdtStrategy is AaveBaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(
            _vault,
            _harvester,
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F, //USDT
            0x60D55F02A771d515e077c9C2403a1ef324885CeC, //AToken
            0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf, //lendingPool
            0x357D51124f59836DeD84c8a1730D72B749d8BC23
        ); //IncentivesController
    }

    function name() public pure override returns (string memory) {
        return "AaveUsdtStrategy";
    }
}
