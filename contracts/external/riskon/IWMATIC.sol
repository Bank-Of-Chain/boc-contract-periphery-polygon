// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

interface IWMATIC {
    
    function withdraw(uint _amount) external;

    function balanceOf(address _user) external;
}

