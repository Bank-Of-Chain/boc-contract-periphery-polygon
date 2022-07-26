// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IStakingPools {
    /**
     * @dev get pending reward token for address
     * @param _user the user for whom unclaimed tokens will be shown
     * @return total amount of withdrawable reward tokens
     */
    function pendingReward(address _user) external view returns (uint256);

    // Deposit LP tokens to Farm for ERC20 allocation. _amount传0时，是收割矿币
    function deposit(uint256 _amount) external;

    // View function to see deposited LP for a user.
    function deposited(address _user) external view returns (uint256);

    // Withdraw LP tokens from Farm.
    function withdraw(uint256 _amount) external;

    function userInfo(address _user) external view returns (UserInfo calldata);

    struct UserInfo {
        uint256 amount; // LP tokens provided.
        uint256 rewardDebt; // Reward debt.
    }
}
