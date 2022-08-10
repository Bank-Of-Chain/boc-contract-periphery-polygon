// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Balancer4UBaseStrategy.sol";

contract BalancerUsdcDaiMaiUsdtStrategy is Balancer4UBaseStrategy {
    bytes32 constant POOL_ID = 0x06df3b2bbb68adc8b0e302443692037ed9f91b42000000000000000000000012;
    address constant USDT = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    address constant QI = address(0x580A84C73811E1839F75d86d75d88cCa0c241fF4);
    address constant POOL_LP_TOKEN = 0x06Df3b2bbB68adc8B0e302443692037ED9f91b42;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name
    ) public initializer {
        address[] memory _extraRewardTokens = new address[](1);
        _extraRewardTokens[0] = QI;
        address[] memory _wants = new address[](4);
        _wants[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        _wants[1] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        _wants[2] = 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1;
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
        return 0x72843281394E68dE5d55BCF7072BB9B2eBc24150;
    }

    function getVersion() external pure override returns (string memory) {
        return "1.0.0";
    }
}
