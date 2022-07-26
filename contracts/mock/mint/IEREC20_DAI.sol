// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface IEREC20_DAI is IERC20MetadataUpgradeable {
    function deposit(address user, bytes calldata depositData) external;
}
