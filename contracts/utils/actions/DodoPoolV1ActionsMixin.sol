// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../external/dodo/DodoStakePoolV1.sol";

contract DodoPoolV1ActionsMixin {
    address internal stakePoolV1Address;

    address internal baseLPToken;

    address internal quoteLPToken;

    function __claimRewards(address _lpToken) internal {
        DodoStakePoolV1(stakePoolV1Address).claim(_lpToken);
    }

    function __deposit(address _lpToken, uint256 _amount) internal {
        DodoStakePoolV1(stakePoolV1Address).deposit(_lpToken, _amount);
    }

    function __withdrawLpToken(address _lpToken, uint256 _amount) internal {
        DodoStakePoolV1(stakePoolV1Address).withdraw(_lpToken, _amount);
    }

    function balanceOfBaseLpToken() internal view returns (uint256 _lpAmount) {
        _lpAmount = DodoStakePoolV1(stakePoolV1Address).getUserLpBalance(
            baseLPToken,
            address(this)
        );
    }

    function balanceOfQuoteLpToken() internal view returns (uint256 _lpAmount) {
        _lpAmount = DodoStakePoolV1(stakePoolV1Address).getUserLpBalance(
            quoteLPToken,
            address(this)
        );
    }

    function getPendingReward() internal view returns (uint256 _rewardAmount) {
        _rewardAmount = DodoStakePoolV1(stakePoolV1Address).getPendingReward(
            baseLPToken,
            address(this)
        );
        _rewardAmount += DodoStakePoolV1(stakePoolV1Address).getPendingReward(
            quoteLPToken,
            address(this)
        );
    }
}
