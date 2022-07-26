// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./QuickswapBaseStrategy.sol";

contract QuickswapUsdcDaiStrategy is QuickswapBaseStrategy {
    address public constant pair = address(0xf04adBF75cDFc5eD26eeA4bbbb991DB002036Bdd);
    address public constant stakingPool = address(0xACb9EB5B52F495F09bA98aC96D8e61257F3daE14);

    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(_vault, _harvester, pair, stakingPool);
    }

    function name() public pure override returns (string memory) {
        return "QuickswapUsdcDaiStrategy";
    }
}
