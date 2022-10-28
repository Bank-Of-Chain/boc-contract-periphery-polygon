// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV3RiskOnVault {

    /// @param tokenId The tokenId of V3 LP NFT minted
    /// @param _tickLower The lower tick of the position in which to add liquidity
    /// @param _tickUpper The upper tick of the position in which to add liquidity
    struct MintInfo {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
    }

    event Rebalance();

    event BorrowRebalance();

    /// @param _rewardTokens The reward tokens
    /// @param _claimAmounts The claim amounts
    event StrategyReported(address[] _rewardTokens, uint256[] _claimAmounts);

    /// @param _wantToken The want token
    /// @param _amount The amount list of token wanted
    event LendToStrategy(address _wantToken, uint256 _amount);

    /// @param _wantToken The want token
    /// @param _redeemAmount The amount of redeem
    event Redeem(address _wantToken, uint256 _redeemAmount);

    /// @param _redeemAmount The amount of redeem
    event RedeemToVault(uint256 _redeemAmount);

    /// @notice Emergency shutdown
    function emergencyShutdown() external view returns (bool);

    /// @notice Net market making amount
    function netMarketMakingAmount() external view returns (uint256);

    /// @notice Version of strategy
    function getVersion() external pure returns (string memory);

    /// @notice Get token0 address of uniswap V3 pool invested by this vault
    function token0() external pure returns (address);

    /// @notice Get token1 address of uniswap V3 pool invested by this vault
    function token1() external pure returns (address);

    /// @notice Gets the statuses about uniswap V3
    function getStatus() external view returns (address _owner, address _wantToken, int24 _baseThreshold, int24 _limitThreshold, int24 _minTickMove, int24 _maxTwapDeviation, int24 _lastTick, int24 _tickSpacing, uint256 _period, uint256 _lastTimestamp, uint32 _twapDuration);

    /// @notice Gets the info of LP V3 NFT minted
    function getMintInfo() external view returns (uint256 _baseTokenId, int24 _baseTickUpper, int24 _baseTickLower, uint256 _limitTokenId, int24 _limitTickUpper, int24 _limitTickLower);

    /// @notice Total assets
    function estimatedTotalAssets() external view returns (uint256 _totalAssets);

    /// @notice Deposit to 3rd pool total assets
    function depositTo3rdPoolTotalAssets() external view returns (uint256 _totalAssets);

    /// @notice Harvests the Strategy
    function harvest() external returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts);

    /// @notice Allocate funds in Vault to strategies
    function lend(uint256 _amount) external;

    /// @notice Withdraw the funds from specified strategy.
    function redeem(uint256 _redeemShares, uint256 _totalShares) external returns (uint256 _redeemBalance);

    /// @notice Withdraw the funds from specified strategy.
    function redeemToVaultByKeeper(uint256 _redeemShares, uint256 _totalShares) external returns (uint256 _redeemBalance);

    /// @notice Borrow Rebalance.
    function borrowRebalance() external;

    /// @notice Rebalance the position of this strategy
    function rebalanceByKeeper() external;

    /// @notice Check if rebalancing is possible
    function shouldRebalance(int24 _tick) external view returns (bool);

    /// @notice Shutdown the vault when an emergency occurs
    function setEmergencyShutdown(bool _active) external;

    /// @notice Sets the manageFeeBps to the percentage of deposit that should be received in basis points
    function setManageFeeBps(uint256 _basis) external;

    /// @notice Sets the profitFeeBps to the percentage of yield that should be received in basis points
    function setProfitFeeBps(uint256 _basis) external;

    /// @notice Sets the token0MinLendAmount to lend.
    function setToken0MinLendAmount(uint256 _minLendAmount) external;

    /// @notice Sets the token1MinLendAmount to lend.
    function setToken1MinLendAmount(uint256 _minLendAmount) external;

    /// @notice Sets `baseThreshold` state variable
    /// Requirements: only vault manager  can call
    function setBaseThreshold(int24 _baseThreshold) external;

    /// @notice Sets `limitThreshold` state variable
    /// Requirements: only vault manager  can call
    function setLimitThreshold(int24 _limitThreshold) external;

    /// @notice Sets `period` state variable
    /// Requirements: only vault manager  can call
    function setPeriod(uint256 _period) external;

    /// @notice Sets `minTickMove` state variable
    /// Requirements: only vault manager  can call
    function setMinTickMove(int24 _minTickMove) external;

    /// @notice Sets `maxTwapDeviation` state variable
    /// Requirements: only vault manager  can call
    function setMaxTwapDeviation(int24 _maxTwapDeviation) external;

    /// @notice Sets `twapDuration` state variable
    function setTwapDuration(uint32 _twapDuration) external;
}
