// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IMiniChef {
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        address to
    ) external;

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;

    function userInfo(uint256 _pid, address _user) external view returns (UserInfo memory);

    function pendingSushi(uint256 _pid, address _user) external view returns (uint256);
}
