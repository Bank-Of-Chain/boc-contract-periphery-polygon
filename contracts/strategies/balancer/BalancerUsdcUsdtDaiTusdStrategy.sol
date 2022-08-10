// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Balancer4UBaseStrategy.sol";

contract BalancerUsdcUsdtDaiTusdStrategy is Balancer4UBaseStrategy {
    bytes32 constant POOL_ID = 0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f000000000000000000000068;
    address constant USDT = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    address constant TUSD = address(0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756);
    address constant POOL_LP_TOKEN = 0x0d34e5dD4D8f043557145598E4e2dC286B35FD4f;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name
    ) public initializer {
        address[] memory _extraRewardTokens = new address[](1);
        _extraRewardTokens[0] = TUSD;
        address[] memory _wants = new address[](4);
        _wants[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        _wants[1] = 0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756;
        _wants[2] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        _wants[3] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        super.initialize(
            _vault,
            _harvester,
            _name,
            _wants,
            USDT,
            POOL_ID,
            POOL_LP_TOKEN,
            _extraRewardTokens
        );
    }

    function getPoolGauge() public pure override returns (address) {
        return 0x6B0068a4408F2aDB633CeB90E6dF6De28ba73696;
    }

    function getVersion() external pure override returns (string memory) {
        return "1.0.1";
    }
}
