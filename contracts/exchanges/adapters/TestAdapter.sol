// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "boc-contract-core/contracts/exchanges/IExchangeAdapter.sol";
import "boc-contract-core/contracts/price-feeds/IValueInterpreter.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract TestAdapter is IExchangeAdapter {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address private valueInterpreter;

    constructor(address _valueInterpreter) {
        valueInterpreter = _valueInterpreter;
    }

    function identifier() external pure override returns (string memory identifier_) {
        return "testAdapter";
    }

    function swap(
        uint8 _method,
        bytes calldata _encodedCallArgs,
        IExchangeAdapter.SwapDescription calldata _sd
    ) external override payable returns (uint256) {
        uint256 _amount = IValueInterpreter(valueInterpreter).calcCanonicalAssetValue(
            _sd.srcToken,
            _sd.amount,
            _sd.dstToken
        );
        console.log("[TestAdapter] swap:_sd._amount=%s, _amount=%s", _sd.amount, _amount);
        // Mock exchange
        uint256 _expectAmount = (_amount * 1000) / 1000;
        IERC20Upgradeable(_sd.dstToken).safeTransfer(_sd.receiver, _expectAmount);
        return _expectAmount;
    }
}
