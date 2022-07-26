// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./StargateBaseStrategy.sol";

contract StargateUsdtStrategy is StargateBaseStrategy {
    function initialize(address _vault, address _harvester) public initializer {
        super._initialize(_vault, _harvester);
    }

    function name() public pure override returns (string memory) {
        return "StargateUsdtStrategy";
    }

    function getStakePoolInfoId() internal pure override returns (uint256) {
        return 1;
    }

    function getLpToken() internal pure override returns (address){
        return 0x29e38769f23701A2e4A8Ef0492e19dA4604Be62c;
    }

    function getRouter() internal pure override returns (address){
        return 0x45A01E4e04F14f7A4a6702c74187c5F6222033cd;
    }

    function getPoolId() internal pure override returns (uint256){
        return 2;
    }

    function getStargateWants() internal pure override returns (address[] memory){
        address[] memory _wants = new address[](1);
        _wants[0] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        return _wants;
    }
}
