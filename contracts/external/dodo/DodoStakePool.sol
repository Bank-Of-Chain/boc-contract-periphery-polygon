// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface DodoStakePool {
    function claimReward(address _lpToken) external;

    function claimAllRewards() external;

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function balanceOf(address addr) external view returns (uint256);
}
