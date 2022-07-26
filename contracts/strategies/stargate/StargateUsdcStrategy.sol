// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./StargateBaseStrategy.sol";

contract StargateUsdcStrategy is StargateBaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(_vault, _harvester);
    }

    function name() public pure override returns (string memory) {
        return "StargateUsdcStrategy";
    }

    function getStakePoolInfoId() internal pure override returns (uint256) {
        return 0;
    }

    function getLpToken() internal pure override returns (address){
        return 0x1205f31718499dBf1fCa446663B532Ef87481fe1;
    }

    function getRouter() internal pure override returns (address){
        return 0x45A01E4e04F14f7A4a6702c74187c5F6222033cd;
    }

    function getPoolId() internal pure override returns (uint256){
        return 1;
    }

    function getStargateWants() internal pure override returns (address[] memory){
        address[] memory _wants = new address[](1);
        _wants[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        return _wants;
    }

}
