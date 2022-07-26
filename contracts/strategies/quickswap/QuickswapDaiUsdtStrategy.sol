// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./QuickswapBaseStrategy.sol";

contract QuickswapDaiUsdtStrategy is QuickswapBaseStrategy {
    address public constant pair = address(0x59153f27eeFE07E5eCE4f9304EBBa1DA6F53CA88);
    address public constant stakingPool = address(0xc45aB79526Dd16B00505EB39222E6B1Aed0Ef079);

    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(_vault, _harvester, pair, stakingPool);
    }

    function name() public pure override returns (string memory) {
        return "QuickswapDaiUsdtStrategy";
    }
}
