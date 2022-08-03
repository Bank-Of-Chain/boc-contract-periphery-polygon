// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface DodoStakePoolV2 {
    function claimReward(uint256 _i) external;

    function deposit(uint256 _amount) external;

    function balanceOf(address _user) external view returns (uint256);

    function withdraw(uint256 _amount) external;

    function getPendingRewardByToken(address _user, address _rewardToken) external view returns (uint256);
}
