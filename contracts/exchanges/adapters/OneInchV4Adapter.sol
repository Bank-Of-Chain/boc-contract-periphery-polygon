// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "boc-contract-core/contracts/exchanges/IExchangeAdapter.sol";
import "boc-contract-core/contracts/library/RevertReasonParser.sol";
import "../../external/oneinch/IOneInchV4.sol";

import "@openzeppelin/contracts~v3/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts~v3/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts~v3/math/SafeMath.sol";

contract OneInchV4Adapter is IExchangeAdapter {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes4[] private SWAP_METHOD_SELECTOR = [
    bytes4(keccak256('swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)')),
    bytes4(keccak256('unoswap(address,uint256,uint256,bytes32[])')),
    bytes4(keccak256('unoswapWithPermit(address,uint256,uint256,bytes32[],bytes)')),
    bytes4(keccak256('uniswapV3Swap(uint256,uint256,uint256[])')),
    bytes4(keccak256('uniswapV3SwapTo(address,uint256,uint256,uint256[])')),
    bytes4(keccak256('uniswapV3SwapToWithPermit(address,address,uint256,uint256,uint256[],bytes)')),
    bytes4(keccak256('clipperSwap(address,address,uint256,uint256)')),
    bytes4(keccak256('clipperSwapTo(address,address,address,uint256,uint256)')),
    bytes4(keccak256('clipperSwapToWithPermit(address,address,address,uint256,uint256,bytes)'))
    ];

    address private constant AGGREGATION_ROUTER_V4 = 0x1111111254fb6c44bAC0beD2854e76F90643097d;

    receive() external payable {
    }

    /// @notice Provides a constant string identifier for an adapter
    /// @return identifier_ An identifier string
    function identifier() external pure override returns (string memory) {
        return "oneInchV4";
    }


    function swap(
        uint8,
        bytes calldata _data,
        SwapDescription calldata _sd
    ) external payable override returns (uint256) {
        console.log("[OneInchV4Adapter] start safeApprove");
        IERC20(_sd.srcToken).safeApprove(AGGREGATION_ROUTER_V4, 0);
        IERC20(_sd.srcToken).safeApprove(AGGREGATION_ROUTER_V4, _sd.amount);
        console.log("[OneInchV4Adapter] start swap");
        uint256 _toTokenBefore = IERC20(_sd.dstToken).balanceOf(address(this));
        bytes memory _callData = _getCallData(_data, _sd);
        (bool _success, bytes memory _result) = AGGREGATION_ROUTER_V4.call(_callData);

        if (!_success) {
            revert(RevertReasonParser.parse(_result, "1inch V4 swap failed: "));
        }
        console.log("[OneInchV4Adapter] swap ok");
        uint256 _exchangeAmount = IERC20(_sd.dstToken).balanceOf(address(this)) - _toTokenBefore;
        console.log("[OneInchV4Adapter] swap receive target amount:", _exchangeAmount);
        IERC20(_sd.dstToken).safeTransfer(_sd.receiver, _exchangeAmount);
        console.log("[OneInchV4Adapter] transfer ok");
        return _exchangeAmount;
    }

    function _getCallData(bytes calldata _data, SwapDescription calldata _sd) private view returns(bytes memory){
        bytes memory _callData;
        bytes4 _sig = _getSig(_data);
        bytes4[] memory _selector = SWAP_METHOD_SELECTOR;
        if(_sig == _selector[0]){
            (address _caller,
            IOneInchV4.OneInchSwapDescription memory _desc,
            bytes memory _tempCallData) = abi.decode(_data[4:], (address, IOneInchV4.OneInchSwapDescription, bytes));
            _desc.minReturnAmount = _desc.minReturnAmount.mul(_sd.amount).div(_desc.amount);
            _desc.amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.swap.selector, _caller, _desc, _tempCallData);
        }else if(_sig == _selector[1]){
            (address _srcToken,
            uint256 _amount,
            uint256 _minReturn,
            bytes32[] memory _pools) = abi.decode(_data[4:], (address, uint256, uint256, bytes32[]));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.unoswap.selector, _srcToken, _amount, _minReturn, _pools);
        }else if(_sig == _selector[2]){
            (address _srcToken,
            uint256 _amount,
            uint256 _minReturn,
            bytes32[] memory _pools,
            bytes memory _permit
            ) = abi.decode(_data[4:], (address, uint256, uint256, bytes32[], bytes));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.unoswapWithPermit.selector, _srcToken, _amount, _minReturn, _pools, _permit);
        }else if(_sig == _selector[3]){
            (uint256 _amount,
            uint256 _minReturn,
            uint256[] memory _pools
            ) = abi.decode(_data[4:], (uint256,uint256,uint256[]));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.uniswapV3Swap.selector, _amount, _minReturn, _pools);
        }else if(_sig == _selector[4]){
            (
            address _recipient,
            uint256 _amount,
            uint256 _minReturn,
            uint256[] memory _pools
            ) = abi.decode(_data[4:], (address,uint256,uint256,uint256[]));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.uniswapV3SwapTo.selector, _recipient, _amount, _minReturn, _pools);
        }else if(_sig == _selector[5]){
            (
            address _recipient,
            address _srcToken,
            uint256 _amount,
            uint256 _minReturn,
            uint256[] memory _pools,
            bytes memory _permit
            ) = abi.decode(_data[4:], (address,address,uint256,uint256,uint256[],bytes));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.uniswapV3SwapToWithPermit.selector, _recipient, _srcToken, _amount, _minReturn, _pools, _permit);
        }else if(_sig == _selector[6]){
            (
            address _srcToken,
            address _dstToken,
            uint256 _amount,
            uint256 _minReturn
            ) = abi.decode(_data[4:], (address,address,uint256,uint256));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.clipperSwap.selector, _srcToken, _dstToken, _amount, _minReturn);
        }else if(_sig == _selector[7]){
            (
            address _recipient,
            address _srcToken,
            address _dstToken,
            uint256 _amount,
            uint256 _minReturn
            ) = abi.decode(_data[4:], (address,address,address,uint256,uint256));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.clipperSwapTo.selector, _recipient, _srcToken, _dstToken, _amount, _minReturn);
        }else if(_sig == _selector[8]){
            (
            address _recipient,
            address _srcToken,
            address _dstToken,
            uint256 _amount,
            uint256 _minReturn,
            bytes memory _permit
            ) = abi.decode(_data[4:], (address,address,address,uint256,uint256,bytes));
            _minReturn = _minReturn.mul(_sd.amount).div(_amount);
            _amount = _sd.amount;
            _callData = abi.encodeWithSelector(IOneInchV4.clipperSwapToWithPermit.selector, _recipient, _srcToken, _dstToken, _amount, _minReturn,_permit);
        }else{
            _callData = _data;
        }
        return _callData;
    }

    function _getSig(bytes calldata _data) private pure returns(bytes4 _sig){
        bytes memory _tempData = _data;
        assembly {
            _sig := mload(add(_tempData, 32))
        }
    }
}
