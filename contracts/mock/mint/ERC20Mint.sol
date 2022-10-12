// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ERC20Mint is ERC20 { 
    constructor(string memory name,string memory symbol) ERC20(name,symbol) {
        _mint(msg.sender,1e9*1e18);
    }
}

