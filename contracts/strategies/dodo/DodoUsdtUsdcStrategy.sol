// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DodoBaseStrategy.sol";

contract DodoUsdtUsdcStrategy is DodoBaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        address _lpTokenPool = address(0x813FddecCD0401c4Fa73B092b074802440544E52);
        address _stakingPool = address(0xB14dA65459DB957BCEec86a79086036dEa6fc3AD);

        super._initialize(_vault, _harvester, _lpTokenPool, _stakingPool);
    }

    function name() public pure override returns (string memory) {
        return "DodoUsdtUsdcStrategy";
    }
}
