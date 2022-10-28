// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './UniswapV3RiskOnVault.sol';
import './IUniswapV3RiskOnVaultInitialize.sol';

contract UniswapV3UsdcWeth500RiskOnVault is IUniswapV3RiskOnVaultInitialize, UniswapV3RiskOnVault {

    function initialize(address _owner, address _wantToken, address _uniswapV3RiskOnHelper, address _treasury, address _accessControlProxy) public override initializer {
        super._initialize(
            _owner,
            _wantToken,
        // WETH-USDC-UniswapV3Pool on polygon
        // https://info.uniswap.org/#/polygon/pools/0x45dda9cb7c25131df268515131f647d726f50608
            address(0x45dDa9cb7c25131DF268515131f647d726f50608),
            2,
            1300,
            400,
        // ~12 hours
            41400,
            0,
        // 1%
            100,
        // 60 seconds
            60,
            10,
            _uniswapV3RiskOnHelper,
            _treasury,
            _accessControlProxy
        );
    }

    // name
    function name() external pure returns (string memory) {
        return 'UniswapV3UsdcWeth500';
    }

    // USDC
    function token0() public pure override returns (address) {
        return address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    }

    // WETH
    function token1() public pure override returns (address) {
        return address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    }

    // DefaultToken0MinLendAmount
    function getDefaultToken0MinLendAmount() internal pure override returns (uint256) {
        return 1e9;
    }

    // DefaultToken1MinLendAmount
    function getDefaultToken1MinLendAmount() internal pure override returns (uint256) {
        return 1e19;
    }
}
