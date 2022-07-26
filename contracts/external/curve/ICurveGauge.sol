// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface ICurveGauge {
    function deposit(uint256 _value) external;

    function balanceOf(address arg0) external view returns (uint256);

    function withdraw(uint256 _value) external;

    function claimed_reward(address, address) external view returns (uint256);

    function claimable_reward(address, address) external view returns (uint256);

    function claimable_reward_write(address, address) external returns (uint256);

    function claim_rewards(address addr) external;
}
