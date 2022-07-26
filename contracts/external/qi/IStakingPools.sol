// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IStakingPools {
    // View function to see pending ERC20s for a user.
    function pending(uint256 _pid, address _user) external view returns (uint256);

    // Deposit LP tokens to Farm for ERC20 allocation. _amount传0时，是收割矿币
    function deposit(uint256 _pid, uint256 _amount) external;

    // View function to see deposited LP for a user.
    function deposited(uint256 _pid, address _user) external view returns (uint256);

    // Withdraw LP tokens from Farm.
    function withdraw(uint256 _pid, uint256 _amount) external;
}
