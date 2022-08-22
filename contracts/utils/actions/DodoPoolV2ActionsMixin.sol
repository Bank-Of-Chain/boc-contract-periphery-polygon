// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../external/dodo/DodoStakePoolV2.sol";

abstract contract DodoPoolV2ActionsMixin {
    address public baseStakePool;
    address public quoteStakePool;

    function __initStakePool(address _baseStakePool, address _quoteStakePool) internal {
        baseStakePool = _baseStakePool;
        quoteStakePool = _quoteStakePool;
    }

    address internal constant DODO = 0xe4Bf2864ebeC7B7fDf6Eeca9BaCAe7cDfDAffe78;
    address internal constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    // _i: rewardToken index, 0-DODO, 1-WMATIC
    function __claimRewards(address _stakePool, uint256 _i) internal {
        DodoStakePoolV2(_stakePool).claimReward(_i);
    }

    function __withdrawLpToken(address _stakePool, uint256 _amount) internal {
        DodoStakePoolV2(_stakePool).withdraw(_amount);
    }

    function balanceOfBaseLpToken() internal view returns (uint256 _lpAmount) {
        _lpAmount = DodoStakePoolV2(baseStakePool).balanceOf(address(this));
    }

    function balanceOfQuoteLpToken() internal view returns (uint256 _lpAmount) {
        _lpAmount = DodoStakePoolV2(quoteStakePool).balanceOf(address(this));
    }

    function getPendingReward(address _rewardToken) internal view returns (uint256 _rewardAmount) {
        _rewardAmount = DodoStakePoolV2(baseStakePool).getPendingRewardByToken(
            address(this),
            _rewardToken
        );
        _rewardAmount += DodoStakePoolV2(quoteStakePool).getPendingRewardByToken(
            address(this),
            _rewardToken
        );
    }
}
