// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../external/dodo/DodoStakePoolV2.sol";

abstract contract DodoPoolV2ActionsMixin {
    function getBaseStakePoolAddress() internal pure virtual returns (address);

    function getQuoteStakePoolAddress() internal pure virtual returns (address);
    
    address internal constant DODO = address(0xe4Bf2864ebeC7B7fDf6Eeca9BaCAe7cDfDAffe78);
    address internal constant WMATIC = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    // _i: rewardToken index, 0-DODO, 1-WMATIC
    function __claimRewards(address _stakePool, uint _i) internal {
        DodoStakePoolV2(_stakePool).claimReward(_i);
    }

    function __withdrawLpToken(address _stakePool, uint256 _amount) internal {
        DodoStakePoolV2(_stakePool).withdraw(_amount);
    }

    function balanceOfBaseLpToken() internal view returns (uint256 lpAmount) {
        lpAmount = DodoStakePoolV2(getBaseStakePoolAddress()).balanceOf(
            address(this)
        );
    }

    function balanceOfQuoteLpToken() internal view returns (uint256 lpAmount) {
        lpAmount = DodoStakePoolV2(getQuoteStakePoolAddress()).balanceOf(
            address(this)
        );
    }

    function getPendingReward(address _rewardToken) internal view returns (uint256 rewardAmount) {
        rewardAmount = DodoStakePoolV2(getBaseStakePoolAddress()).getPendingRewardByToken(
            address(this),
            _rewardToken
        );
        rewardAmount += DodoStakePoolV2(getQuoteStakePoolAddress()).getPendingRewardByToken(
            address(this),
            _rewardToken
        );
    }
}
