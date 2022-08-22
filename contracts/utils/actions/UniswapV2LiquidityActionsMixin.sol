// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../external/uniswap/IUniswapV2Router2.sol";
import "../AssetHelpers.sol";

/// @title UniswapV2ActionsMixin Contract
/// @notice Mixin contract for interacting with Uniswap v2
abstract contract UniswapV2LiquidityActionsMixin is AssetHelpers {
    address internal uniswapV2Router2;

    function _initializeUniswapV2(address _uniswapV2Router2) internal {
        uniswapV2Router2 = _uniswapV2Router2;
    }

    /// @dev Helper to add liquidity
    function __uniswapV2Lend(
        address _recipient,
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal returns (uint256 _liquidity) {
        __approveAssetMaxAsNeeded(_tokenA, uniswapV2Router2, _amountADesired);
        __approveAssetMaxAsNeeded(_tokenB, uniswapV2Router2, _amountBDesired);

        // Execute lend on Uniswap
        (, , _liquidity) = IUniswapV2Router2(uniswapV2Router2).addLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin,
            _recipient,
            __uniswapV2GetActionDeadline()
        );
    }

    /// @dev Helper to remove liquidity
    function __uniswapV2Redeem(
        address _recipient,
        address _poolToken,
        uint256 _poolTokenAmount,
        address _tokenA,
        address _tokenB,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal returns (uint256, uint256) {
        __approveAssetMaxAsNeeded(_poolToken, uniswapV2Router2, _poolTokenAmount);

        // Execute redeem on Uniswap
        return
            IUniswapV2Router2(uniswapV2Router2).removeLiquidity(
                _tokenA,
                _tokenB,
                _poolTokenAmount,
                _amountAMin,
                _amountBMin,
                _recipient,
                __uniswapV2GetActionDeadline()
            );
    }

    /// @dev Helper to get the deadline for a Uniswap V2 action in a standardized way
    function __uniswapV2GetActionDeadline() private view returns (uint256) {
        return block.timestamp + 1;
    }
}
