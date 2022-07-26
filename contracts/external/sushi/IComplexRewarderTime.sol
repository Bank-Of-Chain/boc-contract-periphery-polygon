// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IComplexRewarderTime {
    function pendingToken(uint256 _pid, address _user) external view returns (uint256);
}
